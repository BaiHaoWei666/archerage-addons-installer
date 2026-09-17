package main

import (
	"context"
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

// ReleaseSource 是發佈檔案的來源：
//   - 有權杖：透過 GitHub API 讀取最新 Release 的附件（private repo 必須這樣）
//   - 沒有權杖：要求使用者先在設定頁貼上，不發送線上請求
//   - --source 指定本機資料夾或網址：測試用
type ReleaseSource struct {
	localDir string
	baseURL  string
	custom   bool
	token    func() string
	client   *http.Client

	mu         sync.Mutex
	assets     map[string]string // 附件名稱 → API 下載網址（權杖模式）
	releaseTag string
	files      map[string][]byte // 小檔案快取；nil 代表找不到
}

type httpError struct {
	Status int
	File   string
}

func (e *httpError) Error() string { return fmt.Sprintf("HTTP %d：%s", e.Status, e.File) }

var errAssetNotFound = errors.New("asset not found")
var errTokenRequired = errors.New("請先在設定頁貼上存取權杖，才能讀取私有插件清單。")

func NewReleaseSource(override string, token func() string) *ReleaseSource {
	s := &ReleaseSource{
		token:  token,
		client: &http.Client{Timeout: 10 * time.Minute},
		files:  map[string][]byte{},
	}
	switch {
	case override == "":
		s.baseURL = "https://github.com/" + repo + "/releases/latest/download/"
	case isDir(override):
		s.localDir, _ = filepath.Abs(override)
	default:
		s.baseURL = strings.TrimSuffix(override, "/") + "/"
		s.custom = true
	}
	return s
}

func isDir(p string) bool {
	info, err := os.Stat(p)
	return err == nil && info.IsDir()
}

func (s *ReleaseSource) IsLocal() bool    { return s.localDir != "" }
func (s *ReleaseSource) Location() string { return s.localDir }
func (s *ReleaseSource) NeedsToken() bool { return s.localDir == "" && !s.custom && s.token() == "" }

func (s *ReleaseSource) useAPI() bool {
	return s.localDir == "" && !s.custom && s.token() != ""
}

// LoadManifest 重新讀取 manifest.json，並清除快取。
func (s *ReleaseSource) LoadManifest(ctx context.Context) (*Manifest, error) {
	s.mu.Lock()
	s.assets = nil
	s.releaseTag = ""
	s.files = map[string][]byte{}
	s.mu.Unlock()

	body, _, err := s.open(ctx, "manifest.json")
	if err != nil {
		return nil, err
	}
	defer body.Close()
	var m Manifest
	if err := json.NewDecoder(body).Decode(&m); err != nil {
		return nil, fmt.Errorf("manifest.json 格式錯誤：%w", err)
	}
	return &m, nil
}

// TryGetFile 讀取小檔案（圖示、說明），找不到或失敗時回傳 nil。
func (s *ReleaseSource) TryGetFile(ctx context.Context, name string) []byte {
	s.mu.Lock()
	data, cached := s.files[name]
	s.mu.Unlock()
	if cached {
		return data
	}

	body, _, err := s.open(ctx, name)
	if err != nil {
		if isNotFound(err) {
			s.cacheFile(name, nil)
		}
		return nil // 連線失敗之類的錯誤不快取，下次重試
	}
	defer body.Close()
	data, err = io.ReadAll(io.LimitReader(body, 20<<20))
	if err != nil {
		return nil
	}
	s.cacheFile(name, data)
	return data
}

func (s *ReleaseSource) cacheFile(name string, data []byte) {
	s.mu.Lock()
	s.files[name] = data
	s.mu.Unlock()
}

func isNotFound(err error) bool {
	var he *httpError
	return (errors.As(err, &he) && he.Status == http.StatusNotFound) ||
		errors.Is(err, errAssetNotFound) ||
		errors.Is(err, os.ErrNotExist)
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
	if s.NeedsToken() {
		return nil, 0, errTokenRequired
	}
	if s.localDir != "" {
		f, err := os.Open(filepath.Join(s.localDir, name))
		if err != nil {
			return nil, 0, err
		}
		info, _ := f.Stat()
		return f, info.Size(), nil
	}

	if !s.useAPI() {
		return s.get(ctx, s.baseURL+name, name, "")
	}

	url, err := s.assetURL(ctx, name)
	if err != nil {
		return nil, 0, err
	}
	accept := "application/octet-stream"
	if name != exeName {
		accept = "application/vnd.github.raw+json"
	}
	return s.get(ctx, url, name, accept)
}

// assetURL 從最新 Release 的附件清單找出檔案的 API 網址。
func (s *ReleaseSource) assetURL(ctx context.Context, name string) (string, error) {
	s.mu.Lock()
	assets := s.assets
	tag := s.releaseTag
	s.mu.Unlock()

	if assets == nil {
		body, _, err := s.get(ctx, "https://api.github.com/repos/"+repo+"/releases/latest", "releases/latest", "application/vnd.github+json")
		if err != nil {
			return "", err
		}
		defer body.Close()
		var release struct {
			TagName string `json:"tag_name"`
			Assets  []struct {
				Name string `json:"name"`
				URL  string `json:"url"`
			} `json:"assets"`
		}
		if err := json.NewDecoder(body).Decode(&release); err != nil {
			return "", fmt.Errorf("GitHub 回應格式錯誤：%w", err)
		}
		assets = map[string]string{}
		tag = release.TagName
		if tag == "" {
			return "", fmt.Errorf("GitHub Release 缺少版本標籤")
		}
		for _, a := range release.Assets {
			assets[a.Name] = a.URL
		}
		s.mu.Lock()
		s.assets = assets
		s.releaseTag = tag
		s.mu.Unlock()
	}

	if name != exeName {
		if !safeName(name) {
			return "", fmt.Errorf("Invalid catalog filename")
		}
		return "https://api.github.com/repos/" + repo + "/contents/catalog/" + url.PathEscape(name) + "?ref=" + url.QueryEscape(tag), nil
	}
	url, ok := assets[name]
	if !ok {
		return "", fmt.Errorf("%w：%s", errAssetNotFound, name)
	}
	return url, nil
}

func (s *ReleaseSource) get(ctx context.Context, url, name, accept string) (io.ReadCloser, int64, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("User-Agent", "ArcheRageAddonInstaller/"+version)
	if accept != "" {
		req.Header.Set("Accept", accept)
	}
	if strings.HasPrefix(url, "https://api.github.com/") {
		req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
		if t := s.token(); t != "" {
			// 轉址到下載伺服器時，Go 會自動拿掉這個標頭
			req.Header.Set("Authorization", "Bearer "+t)
		}
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

// describeError 把錯誤轉成給使用者看的訊息。
func (s *ReleaseSource) describeError(err error) string {
	hasToken := s.token() != ""
	var he *httpError
	switch {
	case errors.As(err, &he) && he.Status == http.StatusUnauthorized:
		return "存取權杖無效或已過期，請到「設定」貼上新的權杖。"
	case errors.As(err, &he) && (he.Status == http.StatusForbidden || he.Status == http.StatusTooManyRequests):
		return "GitHub 拒絕存取：權杖權限不足，或查詢次數已達上限，請稍後再試。"
	case s.localDir == "" && isNotFound(err):
		if hasToken {
			return "找不到發佈檔案：可能還沒有發佈任何版本，或權杖沒有這個 repo 的讀取權限。"
		}
		return "找不到發佈檔案。repo 是私人的話，請到「設定」貼上存取權杖。"
	case errors.As(err, &he):
		return fmt.Sprintf("GitHub 回應錯誤（HTTP %d）。", he.Status)
	case errors.Is(err, context.DeadlineExceeded):
		return "連線逾時，請稍後再試。"
	case errors.Is(err, os.ErrNotExist):
		return "找不到檔案：" + err.Error()
	case errors.Is(err, os.ErrPermission):
		return "沒有寫入權限：" + err.Error()
	}
	var ue interface{ Timeout() bool }
	if errors.As(err, &ue) {
		return "無法連線到 GitHub：" + err.Error()
	}
	return err.Error()
}
