package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Settings 存在 %AppData%\ArcheRageAddonInstaller\settings.json，exe 放哪裡都不影響。
type Settings struct {
	migrationWarning string
	AddonDir         string `json:"addonDir,omitempty"`
}

func settingsPath() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = os.Getenv("APPDATA")
	}
	return filepath.Join(dir, appDirName, "settings.json")
}

func loadSettings() *Settings { return readSettings(settingsPath()) }

// 啟動時移除舊憑證欄位，保留資料夾與尚未識別的其他設定。
func readSettings(path string) *Settings {
	s := &Settings{}
	data, err := os.ReadFile(path)
	if err != nil {
		return s
	}
	if json.Unmarshal(data, s) != nil {
		return &Settings{}
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(data, &fields) != nil {
		return s
	}
	if _, exists := fields["token"]; !exists {
		return s
	}
	delete(fields, "token")
	cleaned, err := json.MarshalIndent(fields, "", "  ")
	if err == nil {
		err = os.WriteFile(path, cleaned, 0600)
	}
	if err != nil {
		s.migrationWarning = fmt.Sprintf("舊版權杖清理失敗，請檢查設定檔寫入權限：%s", path)
	}
	return s
}

func (s *Settings) save() error {
	path := settingsPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o600)
}
