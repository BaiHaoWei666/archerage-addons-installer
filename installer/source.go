package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ReleaseSource 將公開 Release 附件解析成安裝器使用的檔案清單。
type ReleaseSource struct {
	localDir string
	baseURL  string
	client   *http.Client
	mu       sync.Mutex
	assets   map[string]string
	files    map[string][]byte
}
type httpError struct {
	Status int
	File   string
}

func (e *httpError) Error() string { return fmt.Sprintf("HTTP %d：%s", e.Status, e.File) }

var errAssetNotFound = errors.New("找不到 Release 附件")

func NewReleaseSource(override string) *ReleaseSource {
	s := &ReleaseSource{client: &http.Client{Timeout: 10 * time.Minute}, assets: map[string]string{}, files: map[string][]byte{}}
	if isDir(override) {
		s.localDir, _ = filepath.Abs(override)
	} else if override != "" {
		s.baseURL = strings.TrimSuffix(override, "/") + "/"
	}
	return s
}
func isDir(p string) bool                 { info, err := os.Stat(p); return err == nil && info.IsDir() }
func (s *ReleaseSource) IsLocal() bool    { return s.localDir != "" }
func (s *ReleaseSource) Location() string { return s.localDir }

type githubRelease struct {
	Tag        string `json:"tag_name"`
	Draft      bool   `json:"draft"`
	Prerelease bool   `json:"prerelease"`
	Assets     []struct {
		Name string `json:"name"`
		URL  string `json:"browser_download_url"`
	} `json:"assets"`
}

func repositoryName(raw string) (string, error) {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.Host != "github.com" || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
		return "", fmt.Errorf("插件來源必須是公開 GitHub repo 網址：%s", raw)
	}
	parts := strings.Split(strings.Trim(strings.TrimSuffix(u.Path, ".git"), "/"), "/")
	if len(parts) != 2 || !safeName(parts[0]) || !safeName(parts[1]) {
		return "", fmt.Errorf("GitHub repo 網址格式錯誤：%s", raw)
	}
	return strings.Join(parts, "/"), nil
}
func (s *ReleaseSource) readJSON(ctx context.Context, location string, out interface{}) error {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	body, _, err := s.get(ctx, location, location, "application/vnd.github+json")
	if err != nil {
		return err
	}
	defer body.Close()
	if err := json.NewDecoder(io.LimitReader(body, 2<<20)).Decode(out); err != nil {
		return fmt.Errorf("JSON 格式錯誤：%w", err)
	}
	return nil
}
func (s *ReleaseSource) release(ctx context.Context, repository, selector string, stable bool) (*githubRelease, map[string]string, error) {
	var r githubRelease
	if err := s.readJSON(ctx, "https://api.github.com/repos/"+repository+"/releases/"+selector, &r); err != nil {
		return nil, nil, err
	}
	if r.Tag == "" || r.Draft || (stable && r.Prerelease) {
		return nil, nil, fmt.Errorf("%s 沒有有效的正式 Release", repository)
	}
	assets := map[string]string{}
	for _, a := range r.Assets {
		u, err := url.Parse(a.URL)
		prefix := "/" + repository + "/releases/download/" + r.Tag + "/"
		if err != nil || u.Scheme != "https" || u.Host != "github.com" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || !strings.HasPrefix(u.Path, prefix) {
			return nil, nil, fmt.Errorf("%s 的 Release 附件網址不合法", repository)
		}
		if _, exists := assets[a.Name]; exists {
			return nil, nil, fmt.Errorf("Release 附件名稱重複：%s", a.Name)
		}
		assets[a.Name] = a.URL
	}
	return &r, assets, nil
}

// LoadManifest 固定本次各 repo 的 Release；直到下次重新整理才切換版本。
func (s *ReleaseSource) LoadManifest(ctx context.Context) (*Manifest, error) {
	if s.localDir != "" || s.baseURL != "" {
		body, _, err := s.open(ctx, "manifest.json")
		if err != nil {
			return nil, err
		}
		defer body.Close()
		var m Manifest
		if err := json.NewDecoder(io.LimitReader(body, 2<<20)).Decode(&m); err != nil {
			return nil, err
		}
		s.mu.Lock()
		s.files = map[string][]byte{}
		s.mu.Unlock()
		return &m, nil
	}
	_, registryAssets, err := s.release(ctx, repo, "tags/registry", false)
	if err != nil {
		return nil, err
	}
	registryURL, ok := registryAssets["repositories.json"]
	if !ok {
		return nil, fmt.Errorf("%w：repositories.json", errAssetNotFound)
	}
	var repositories []string
	if err := s.readJSON(ctx, registryURL, &repositories); err != nil {
		return nil, err
	}
	if repositories == nil {
		return nil, fmt.Errorf("收錄清單必須是 URL 陣列")
	}
	m := &Manifest{Addons: []AddonInfo{}}
	assets := map[string]string{}
	if r, files, err := s.release(ctx, repo, "latest", true); err != nil {
		m.Warnings = append(m.Warnings, "安裝器更新檢查失敗："+s.describeError(err))
	} else if _, valid := parseVersion(r.Tag); !valid || files[exeName] == "" {
		m.Warnings = append(m.Warnings, "安裝器 Release 缺少有效版本或執行檔")
	} else {
		m.Installer.Version = strings.TrimPrefix(r.Tag, "v")
		assets[exeName] = files[exeName]
	}
	seenRepos := map[string]bool{}
	seenNames := map[string]bool{}
	for _, raw := range repositories {
		repository, err := repositoryName(raw)
		if err != nil {
			return nil, err
		}
		key := strings.ToLower(repository)
		if seenRepos[key] {
			return nil, fmt.Errorf("收錄清單重複：%s", repository)
		}
		seenRepos[key] = true
		addon, files, err := s.loadAddon(ctx, repository)
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		if err != nil {
			m.Warnings = append(m.Warnings, repository+"："+s.describeError(err))
			continue
		}
		key = strings.ToLower(addon.Name)
		if seenNames[key] {
			return nil, fmt.Errorf("不同來源使用相同插件名稱：%s", addon.Name)
		}
		seenNames[key] = true
		m.Addons = append(m.Addons, *addon)
		for _, ext := range []string{".zip", ".md", ".png"} {
			name := addon.Name + ext
			if location := files[name]; location != "" {
				assets[name] = location
			}
		}
	}
	s.mu.Lock()
	s.assets = assets
	s.files = map[string][]byte{}
	s.mu.Unlock()
	return m, nil
}
func (s *ReleaseSource) loadAddon(ctx context.Context, repository string) (*AddonInfo, map[string]string, error) {
	r, assets, err := s.release(ctx, repository, "latest", true)
	if err != nil {
		return nil, nil, err
	}
	location := assets["manifest.json"]
	if location == "" {
		return nil, nil, fmt.Errorf("%w：manifest.json", errAssetNotFound)
	}
	var a AddonInfo
	if err := s.readJSON(ctx, location, &a); err != nil {
		return nil, nil, err
	}
	if a.SchemaVersion != 1 || !safeName(a.Name) || strings.EqualFold(a.Name, "Backup") {
		return nil, nil, fmt.Errorf("插件 manifest 格式或名稱不合法")
	}
	if _, valid := parseVersion(a.Version); !valid || r.Tag != "v"+a.Version {
		return nil, nil, fmt.Errorf("Release tag 與 manifest 版本不一致")
	}
	hash, err := hex.DecodeString(a.SHA256)
	if err != nil || len(hash) != 32 {
		return nil, nil, fmt.Errorf("插件 manifest 缺少有效的 SHA-256")
	}
	if assets[a.Name+".zip"] == "" {
		return nil, nil, fmt.Errorf("%w：%s.zip", errAssetNotFound, a.Name)
	}
	return &a, assets, nil
}

// TryGetFile 讀取圖示與說明；不存在時讓介面使用預設內容。
func (s *ReleaseSource) TryGetFile(ctx context.Context, name string) []byte {
	s.mu.Lock()
	data, cached := s.files[name]
	s.mu.Unlock()
	if cached {
		return data
	}
	body, _, err := s.open(ctx, name)
	if err != nil {
		return nil
	}
	defer body.Close()
	data, err = io.ReadAll(io.LimitReader(body, (20<<20)+1))
	if err != nil || len(data) > 20<<20 {
		return nil
	}
	s.mu.Lock()
	s.files[name] = data
	s.mu.Unlock()
	return data
}

// DownloadProgress 記錄已寫入的位元組數；Total <= 0 代表來源未提供總大小。
type DownloadProgress struct {
	Received       int64   `json:"received"`
	Total          int64   `json:"total"`
	BytesPerSecond float64 `json:"bytesPerSecond"`
}

// Download 下載檔案到 dest，progress 會收到 0～1 的進度；detail 額外回報大小與速度。
func (s *ReleaseSource) Download(ctx context.Context, name, dest string, progress func(float64), detail ...func(DownloadProgress)) error {
	body, size, err := s.open(ctx, name)
	if err != nil {
		return err
	}
	defer body.Close()

	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer f.Close()

	buf := make([]byte, 128<<10)
	var received int64
	lastTime, lastBytes := time.Now(), int64(0)
	lastSpeed := float64(0)
	report := func(force bool) {
		now := time.Now()
		elapsed := now.Sub(lastTime).Seconds()
		if !force && elapsed < 0.2 {
			return
		}
		speed := lastSpeed
		if elapsed > 0 && received > lastBytes {
			speed = float64(received-lastBytes) / elapsed
		}
		for _, callback := range detail {
			if callback != nil {
				callback(DownloadProgress{received, size, speed})
			}
		}
		lastTime, lastBytes = now, received
		lastSpeed = speed
	}
	report(true)
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		n, rerr := body.Read(buf)
		if n > 0 {
			if _, werr := f.Write(buf[:n]); werr != nil {
				return werr
			}
			received += int64(n)
			report(false)
			if size > 0 && progress != nil {
				progress(float64(received) / float64(size))
			}
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			return rerr
		}
	}
	if err := f.Close(); err != nil {
		return err
	}
	report(true)
	return nil
}

func (s *ReleaseSource) open(ctx context.Context, name string) (io.ReadCloser, int64, error) {
	if !safeName(name) {
		return nil, 0, fmt.Errorf("不合法的附件名稱：%s", name)
	}
	if s.localDir != "" {
		f, err := os.Open(filepath.Join(s.localDir, name))
		if err != nil {
			return nil, 0, err
		}
		info, err := f.Stat()
		if err != nil {
			f.Close()
			return nil, 0, err
		}
		return f, info.Size(), nil
	}
	location := s.baseURL + name
	if s.baseURL == "" {
		var err error
		location, err = s.assetURL(ctx, name)
		if err != nil {
			return nil, 0, err
		}
	}
	return s.get(ctx, location, name, "")
}
func (s *ReleaseSource) assetURL(_ context.Context, name string) (string, error) {
	s.mu.Lock()
	location := s.assets[name]
	s.mu.Unlock()
	if location == "" {
		return "", fmt.Errorf("%w：%s", errAssetNotFound, name)
	}
	return location, nil
}
func (s *ReleaseSource) get(ctx context.Context, location, name, accept string) (io.ReadCloser, int64, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, location, nil)
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("User-Agent", "ArcheRageAddonInstaller/"+version)
	if accept != "" {
		req.Header.Set("Accept", accept)
	}
	if req.URL.Host == "api.github.com" {
		req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, 0, err
	}
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		return nil, 0, &httpError{Status: resp.StatusCode, File: name}
	}
	return resp.Body, resp.ContentLength, nil
}
func (s *ReleaseSource) describeError(err error) string {
	var he *httpError
	switch {
	case errors.As(err, &he):
		switch he.Status {
		case http.StatusForbidden, http.StatusTooManyRequests:
			return "GitHub 暫時拒絕存取或查詢次數已達上限，請稍後再試。"
		case http.StatusNotFound:
			return "找不到公開 Release 或附件，請確認專案已公開並完成發布。"
		default:
			return fmt.Sprintf("下載失敗（HTTP %d）。", he.Status)
		}
	case errors.Is(err, context.DeadlineExceeded):
		return "連線逾時，請稍後再試。"
	case errors.Is(err, os.ErrNotExist):
		return "找不到檔案：" + err.Error()
	case errors.Is(err, os.ErrPermission):
		return "沒有寫入權限：" + err.Error()
	}
	var ue *url.Error
	if errors.As(err, &ue) {
		return "無法連線到下載來源：" + err.Error()
	}
	return err.Error()
}
