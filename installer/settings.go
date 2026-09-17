package main

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// Settings 存在 %AppData%\ArcheRageAddonInstaller\settings.json，exe 放哪裡都不影響。
type Settings struct {
	AddonDir string `json:"addonDir,omitempty"`
	// Token 是以 Windows DPAPI 加密（只有同一個 Windows 使用者能解開）後的 base64
	Token string `json:"token,omitempty"`
}

func settingsPath() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = os.Getenv("APPDATA")
	}
	return filepath.Join(dir, appDirName, "settings.json")
}

func loadSettings() *Settings {
	s := &Settings{}
	if data, err := os.ReadFile(settingsPath()); err == nil {
		_ = json.Unmarshal(data, s) // 設定檔壞掉就用預設值
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
