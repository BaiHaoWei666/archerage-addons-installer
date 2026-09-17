package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"mime"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"github.com/wailsapp/wails/v2/pkg/runtime"
	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/extension"
)

// App 是給網頁呼叫的後端。網頁用 window.go.main.App.Handle(訊息) 傳指令，
// 後端用 "msg" 事件回傳狀態、進度、通知。
type App struct {
	ctx              context.Context
	source           *ReleaseSource
	settings         *Settings
	addonDirOverride string

	mu                sync.Mutex
	manifest          *Manifest
	generation        int
	manifestErr       string
	busy              bool
	busyText          string
	busyPercent       int
	busyDownload      *DownloadProgress
	cancelBusy        context.CancelFunc
	selfUpdateOffered bool
	token             string
	tokenInfo         tokenInfo

	confirmMu   sync.Mutex
	confirms    map[int]chan bool
	nextConfirm int
}

var errBusy = errors.New("busy")

var markdown = goldmark.New(goldmark.WithExtensions(extension.GFM)) // 預設不輸出原始 HTML

func NewApp(sourceArg, addonDirArg string) *App {
	a := &App{
		settings:         loadSettings(),
		addonDirOverride: addonDirArg,
		confirms:         map[int]chan bool{},
	}
	a.reloadToken()
	a.source = NewReleaseSource(sourceArg, a.currentToken)
	return a
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

func (a *App) shutdown(context.Context) {
	a.mu.Lock()
	if a.cancelBusy != nil {
		a.cancelBusy()
	}
	a.mu.Unlock()
	a.confirmMu.Lock()
	for id, ch := range a.confirms {
		close(ch)
		delete(a.confirms, id)
	}
	a.confirmMu.Unlock()
}

func (a *App) currentToken() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.token
}

func (a *App) reloadToken() {
	t, info := resolveToken(a.settings)
	a.mu.Lock()
	a.token, a.tokenInfo = t, info
	a.mu.Unlock()
}

func (a *App) addonDir() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	switch {
	case a.addonDirOverride != "":
		return a.addonDirOverride
	case a.settings.AddonDir != "":
		return a.settings.AddonDir
	}
	return defaultAddonDir()
}

// ---------- 網頁傳來的指令 ----------

// Handle 是網頁唯一呼叫的方法，每次呼叫在各自的 goroutine 執行。
func (a *App) Handle(msg map[string]interface{}) {
	defer func() {
		if r := recover(); r != nil {
			a.toast("error", fmt.Sprint("發生錯誤：", r))
		}
	}()

	str := func(key string) string {
		s, _ := msg[key].(string)
		return s
	}

	switch str("type") {
	case "ready":
		a.postState()
		a.refresh()
	case "state":
		a.postState()
	case "refresh":
		a.refresh()
	case "install":
		var names []string
		if list, ok := msg["names"].([]interface{}); ok {
			for _, n := range list {
				if s, ok := n.(string); ok {
					names = append(names, s)
				}
			}
		}
		a.install(names)
	case "uninstall":
		a.uninstall(str("name"))
	case "details":
		a.sendDetails(str("name"))
	case "browseDir":
		a.browseDir()
	case "resetDir":
		a.setAddonDir("")
	case "openDir":
		a.openDir(str("name"))
	case "openUrl":
		a.openURL(str("url"))
	case "selfUpdate":
		a.selfUpdate()
	case "saveToken":
		a.saveToken(str("token"))
	case "clearToken":
		a.saveToken("")
	case "confirmReply":
		id, _ := msg["id"].(float64)
		ok, _ := msg["ok"].(bool)
		a.confirmMu.Lock()
		ch := a.confirms[int(id)]
		delete(a.confirms, int(id))
		a.confirmMu.Unlock()
		if ch != nil {
			ch <- ok
		}
	}
}

func (a *App) emit(payload map[string]interface{}) {
	if a.ctx != nil {
		runtime.EventsEmit(a.ctx, "msg", payload)
	}
}

func (a *App) toast(kind, text string) {
	a.emit(map[string]interface{}{"type": "toast", "kind": kind, "text": text})
}

func (a *App) confirm(title, text, okText string, danger bool) bool {
	ch := make(chan bool, 1)
	a.confirmMu.Lock()
	a.nextConfirm++
	id := a.nextConfirm
	a.confirms[id] = ch
	a.confirmMu.Unlock()

	a.emit(map[string]interface{}{
		"type": "confirm", "id": id, "title": title, "text": text, "okText": okText, "danger": danger,
	})
	select {
	case ok := <-ch:
		return ok
	case <-a.ctx.Done():
		return false
	}
}

// ---------- 狀態 ----------

type addonView struct {
	Name         string           `json:"name"`
	Title        string           `json:"title"`
	Description  string           `json:"description"`
	Category     string           `json:"category"`
	Author       string           `json:"author"`
	Version      string           `json:"version"`
	LocalVersion *string          `json:"localVersion"`
	Installed    bool             `json:"installed"`
	Status       string           `json:"status"` // notInstalled | latest | unknown | update
	Updated      string           `json:"updated"`
	Changelog    []ChangelogEntry `json:"changelog"`
}

func (a *App) postState() {
	dir := a.addonDir()
	dirOK := isDir(dir)

	a.mu.Lock()
	manifest := a.manifest
	state := map[string]interface{}{
		"type":         "state",
		"addonDir":     dir,
		"dirOk":        dirOK,
		"isDefaultDir": a.addonDirOverride == "" && a.settings.AddonDir == "",
		"repo":         repo,
		"loaded":       manifest != nil,
		"generation":   a.generation,
		"error":        a.manifestErr,
		"busy":         a.busyText,
		"busyProgress": a.busyPercent,
		"download":     a.busyDownload,
		"token":        a.tokenInfo,
	}
	a.mu.Unlock()

	if a.source.IsLocal() {
		state["source"] = a.source.Location()
	}

	latest := ""
	addons := []addonView{}
	if manifest != nil {
		latest = manifest.Installer.Version
		for _, m := range manifest.Addons {
			v := addonView{
				Name: m.Name, Title: m.Title(), Description: m.Description, Category: m.Category,
				Author: m.Author, Version: m.Version, Changelog: m.Changelog,
			}
			if v.Changelog == nil {
				v.Changelog = []ChangelogEntry{}
			} else if len(v.Changelog) > 0 {
				v.Updated = v.Changelog[0].Date
			}
			v.Installed = dirOK && isInstalled(dir, m.Name)
			if v.Installed {
				v.LocalVersion = installedVersion(dir, m.Name)
			}
			switch {
			case !v.Installed:
				v.Status = "notInstalled"
			case !isNewer(m.Version, v.LocalVersion):
				v.Status = "latest"
			case v.LocalVersion == nil:
				v.Status = "unknown"
			default:
				v.Status = "update"
			}
			addons = append(addons, v)
		}
	}
	state["addons"] = addons
	state["needsToken"] = a.source.NeedsToken()
	state["installer"] = map[string]interface{}{
		"current":   version,
		"latest":    latest,
		"hasUpdate": latest != "" && installerIsNewer(latest),
	}
	a.emit(state)
}

// ---------- 忙碌狀態 ----------

// runBusy 同一時間只允許一件工作，執行期間回報進度給網頁。
func (a *App) runBusy(text string, work func(ctx context.Context, progress func(float64)) error) error {
	a.mu.Lock()
	if a.busy {
		a.mu.Unlock()
		a.toast("warn", "正在處理中，請稍候。")
		return errBusy
	}
	ctx, cancel := context.WithCancel(a.ctx)
	a.busy, a.cancelBusy = true, cancel
	a.mu.Unlock()

	a.setBusy(text, 0)
	defer func() {
		cancel()
		a.mu.Lock()
		a.busy, a.cancelBusy = false, nil
		a.mu.Unlock()
		a.setBusy("", 0)
	}()

	last := -1
	progress := func(p float64) {
		percent := int(p * 100)
		if percent < 0 {
			percent = 0
		} else if percent > 100 {
			percent = 100
		}
		if percent != last {
			last = percent
			a.mu.Lock()
			current := a.busyText
			a.mu.Unlock()
			a.setBusy(current, percent)
		}
	}
	return work(ctx, progress)
}

func (a *App) setBusy(text string, percent int) {
	a.mu.Lock()
	a.busyText, a.busyPercent = text, percent
	a.busyDownload = nil
	a.mu.Unlock()
	a.emit(map[string]interface{}{"type": "busy", "text": text, "progress": percent})
}

func (a *App) setDownloadProgress(p DownloadProgress) {
	percent := 0
	if p.Total > 0 {
		percent = int(float64(p.Received) / float64(p.Total) * 100)
	}
	if percent > 100 {
		percent = 100
	}
	a.mu.Lock()
	a.busyPercent, a.busyDownload = percent, &p
	text := a.busyText
	a.mu.Unlock()
	a.emit(map[string]interface{}{"type": "busy", "text": text, "progress": percent, "download": p})
}

func (a *App) isBusy() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.busy {
		go a.toast("warn", "正在處理中，請稍候。")
	}
	return a.busy
}

// ---------- 指令實作 ----------

func (a *App) refresh() {
	err := a.runBusy("正在檢查更新…", func(ctx context.Context, _ func(float64)) error {
		m, err := a.source.LoadManifest(ctx)
		if err != nil {
			return err
		}
		a.mu.Lock()
		a.manifest = m
		a.generation++
		a.mu.Unlock()
		return nil
	})
	if errors.Is(err, errBusy) {
		return
	}

	manifestErr := ""
	if err != nil {
		manifestErr = a.source.describeError(err) // 會讀取權杖，不能在持有 a.mu 時呼叫
	}
	a.mu.Lock()
	hadManifest := a.manifest != nil
	if err != nil {
		a.manifest = nil
	}
	a.manifestErr = manifestErr
	a.mu.Unlock()

	if err != nil && hadManifest {
		a.toast("error", manifestErr)
	}
	a.postState()

	a.mu.Lock()
	offer := a.manifest != nil && !a.selfUpdateOffered && installerIsNewer(a.manifest.Installer.Version)
	latest := ""
	if offer {
		a.selfUpdateOffered = true
		latest = a.manifest.Installer.Version
	}
	a.mu.Unlock()

	if offer && a.confirm("安裝工具有新版本",
		fmt.Sprintf("新版本 v%s（目前是 v%s）。\n要現在更新嗎？更新完會自動重新開啟。", latest, version),
		"立即更新", false) {
		a.selfUpdate()
	}
}

func (a *App) install(names []string) {
	a.mu.Lock()
	manifest := a.manifest
	a.mu.Unlock()
	if manifest == nil || a.isBusy() {
		return
	}

	var addons []*AddonInfo
	for _, n := range names {
		if addon := manifest.find(n); addon != nil {
			addons = append(addons, addon)
		}
	}
	if len(addons) == 0 {
		return
	}
	dir := a.addonDir()
	if !isDir(dir) {
		a.toast("error", "找不到插件資料夾，請到「設定」選擇。")
		return
	}
	if isGameRunning() && !a.confirm("遊戲正在執行",
		"安裝或更新後，要在遊戲裡重新載入插件（或重新登入）才會生效。\n要繼續嗎？", "繼續", false) {
		return
	}

	var done, failed []string
	anyBackup := false
	err := a.runBusy("正在安裝…", func(ctx context.Context, progress func(float64)) error {
		for i, addon := range addons {
			a.setBusy(fmt.Sprintf("正在安裝 %s（%d/%d）…", addon.Title(), i+1, len(addons)), 0)
			index := i
			backedUp, err := installAddon(ctx, a.source, dir, addon, func(p float64) {
				progress((float64(index) + p) / float64(len(addons)))
			})
			if ctx.Err() != nil {
				return nil
			}
			if err != nil {
				failed = append(failed, addon.Title()+"："+a.source.describeError(err))
				continue
			}
			anyBackup = anyBackup || backedUp
			done = append(done, addon.Title()+" v"+addon.Version)
		}
		return nil
	})
	if errors.Is(err, errBusy) {
		return
	}
	a.postState()

	if len(done) > 0 {
		text := "完成：" + strings.Join(done, "、")
		if anyBackup {
			text += "\n舊版已備份到 Addon\\Backup。"
		}
		a.toast("ok", text+"\n請在遊戲裡重新載入插件，或重新登入。")
	}
	if len(failed) > 0 {
		a.toast("error", "失敗：\n"+strings.Join(failed, "\n"))
	}
}

func (a *App) uninstall(name string) {
	a.mu.Lock()
	var addon *AddonInfo
	if a.manifest != nil {
		addon = a.manifest.find(name)
	}
	a.mu.Unlock()
	if addon == nil || a.isBusy() {
		return
	}

	if err := uninstallAddon(a.addonDir(), addon.Name); err != nil {
		a.toast("error", fmt.Sprintf("解除安裝 %s 失敗：%s", addon.Title(), a.source.describeError(err)))
	} else {
		a.toast("ok", fmt.Sprintf("已解除安裝 %s。\n備份在 Addon\\Backup，需要時可以搬回來。", addon.Title()))
	}
	a.postState()
}

func (a *App) sendDetails(name string) {
	if !safeName(name) {
		return
	}
	data := a.source.TryGetFile(a.ctx, name+".md")
	if data == nil {
		// 發佈來源沒有說明時，改讀本機已安裝的 README
		data, _ = os.ReadFile(filepath.Join(a.addonDir(), name, "README.md"))
	}

	var html interface{}
	if data != nil {
		var buf bytes.Buffer
		if err := markdown.Convert(bytes.TrimPrefix(data, []byte("\uFEFF")), &buf); err == nil {
			html = buf.String()
		}
	}
	a.emit(map[string]interface{}{"type": "details", "name": name, "html": html})
}

func (a *App) selfUpdate() {
	a.mu.Lock()
	latest := ""
	if a.manifest != nil {
		latest = a.manifest.Installer.Version
	}
	a.mu.Unlock()
	if latest == "" || !installerIsNewer(latest) {
		a.toast("ok", "安裝工具已是最新版本。")
		return
	}

	err := a.runBusy("正在下載新版安裝工具…", func(ctx context.Context, progress func(float64)) error {
		return replaceSelf(ctx, a.source, a.setDownloadProgress)
	})
	switch {
	case errors.Is(err, errBusy):
	case err != nil:
		a.toast("error", "安裝工具更新失敗："+a.source.describeError(err))
	default:
		runtime.Quit(a.ctx)
	}
}

func (a *App) browseDir() {
	current := a.addonDir()
	opts := runtime.OpenDialogOptions{Title: "選擇 ArcheRage 的 Addon 資料夾（通常在 文件\\ArcheRage\\Addon）"}
	if isDir(current) {
		opts.DefaultDirectory = current
	}
	dir, err := runtime.OpenDirectoryDialog(a.ctx, opts)
	if err != nil || dir == "" {
		return
	}
	a.setAddonDir(dir)
}

func (a *App) setAddonDir(dir string) {
	a.mu.Lock()
	a.addonDirOverride = ""
	a.settings.AddonDir = dir
	err := a.settings.save()
	a.mu.Unlock()
	if err != nil {
		a.toast("error", "設定儲存失敗："+err.Error())
	}
	a.postState()
}

func (a *App) openDir(name string) {
	if name != "" && !safeName(name) {
		return
	}
	path := a.addonDir()
	if name != "" {
		path = filepath.Join(path, name)
	}
	if !isDir(path) {
		a.toast("warn", "找不到這個資料夾。")
		return
	}
	_ = exec.Command("explorer.exe", path).Start()
}

func (a *App) openURL(raw string) {
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") {
		return
	}
	runtime.BrowserOpenURL(a.ctx, u.String())
}

func (a *App) saveToken(token string) {
	token = strings.TrimSpace(token)
	a.mu.Lock()
	if token == "" {
		a.settings.Token = ""
	} else if enc, err := protectString(token); err != nil {
		a.mu.Unlock()
		a.toast("error", "權杖加密失敗："+err.Error())
		return
	} else {
		a.settings.Token = enc
	}
	err := a.settings.save()
	a.mu.Unlock()
	if err != nil {
		a.toast("error", "設定儲存失敗："+err.Error())
		return
	}

	a.reloadToken()
	a.mu.Lock()
	a.manifest = nil
	a.generation++
	a.mu.Unlock()
	if token == "" {
		a.toast("ok", "已清除設定頁的權杖。")
	} else {
		a.toast("ok", "已儲存權杖，正在重新檢查更新。")
	}
	a.refresh()
}

// ---------- /remote/ 檔案 ----------

// ServeHTTP 提供 /remote/檔名（插件圖示等），內容來自發佈來源。
func (a *App) serveHTTP(w http.ResponseWriter, r *http.Request) {
	name, ok := strings.CutPrefix(r.URL.Path, "/remote/")
	if !ok || !safeName(name) {
		http.NotFound(w, r)
		return
	}
	data := a.source.TryGetFile(r.Context(), name)
	if data == nil {
		http.NotFound(w, r)
		return
	}
	if ct := mime.TypeByExtension(filepath.Ext(name)); ct != "" {
		w.Header().Set("Content-Type", ct)
	}
	w.Header().Set("Cache-Control", "no-cache")
	_, _ = w.Write(data)
}
