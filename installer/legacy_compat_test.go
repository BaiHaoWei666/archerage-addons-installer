package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestLegacyCatalogOnlyAdvertisesInstaller(t *testing.T) {
	root, err := os.ReadFile("../manifest.json")
	if err != nil {
		t.Fatal(err)
	}
	bridge, err := os.ReadFile("../catalog/manifest.json")
	if err != nil {
		t.Fatal(err)
	}
	var current, legacy Manifest
	if json.Unmarshal(root, &current) != nil || json.Unmarshal(bridge, &legacy) != nil {
		t.Fatal("版本檔格式錯誤")
	}
	if legacy.Installer.Version != current.Installer.Version {
		t.Fatal("相容清單與安裝器版本不一致")
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(bridge, &fields) != nil || len(fields) != 2 || string(fields["addons"]) != "[]" {
		t.Fatal("相容清單只能包含安裝器版本及空插件陣列")
	}
}
func TestLegacyCredentialRemovedWithoutLosingSettings(t *testing.T) {
	path := filepath.Join(t.TempDir(), "settings.json")
	original := `{"addonDir":"C:/Game/Addon","token":"obsolete-test-value","futureOption":true}`
	if err := os.WriteFile(path, []byte(original), 0600); err != nil {
		t.Fatal(err)
	}
	settings := readSettings(path)
	if settings.AddonDir != "C:/Game/Addon" || settings.migrationWarning != "" {
		t.Fatal("資料夾設定遷移失敗")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var stored map[string]json.RawMessage
	if err := json.Unmarshal(data, &stored); err != nil {
		t.Fatal(err)
	}
	if _, exists := stored["token"]; exists {
		t.Fatal("殘留舊憑證欄位")
	}
	if string(stored["futureOption"]) != "true" {
		t.Fatal("遺失其他設定")
	}
	if string(stored["addonDir"]) != `"C:/Game/Addon"` {
		t.Fatal("遺失資料夾設定")
	}
}
func TestSettingsWithoutLegacyCredentialRemainUnchanged(t *testing.T) {
	path := filepath.Join(t.TempDir(), "settings.json")
	original := []byte("{  \"addonDir\": \"C:/Game/Addon\" }")
	if err := os.WriteFile(path, original, 0600); err != nil {
		t.Fatal(err)
	}
	readSettings(path)
	data, _ := os.ReadFile(path)
	if string(data) != string(original) {
		t.Fatal("無舊憑證時不應重寫設定")
	}
}

func TestLegacyCleanupFailureKeepsSettingsAndReportsWarning(t *testing.T) {
	path := filepath.Join(t.TempDir(), "settings.json")
	if err := os.WriteFile(path, []byte(`{"addonDir":"C:/Game/Addon","token":"obsolete-test-value"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(path, 0400); err != nil {
		t.Fatal(err)
	}
	defer os.Chmod(path, 0600)
	settings := readSettings(path)
	if settings.AddonDir != "C:/Game/Addon" || settings.migrationWarning == "" {
		t.Fatal("清理失敗應保留設定並回報")
	}
}
