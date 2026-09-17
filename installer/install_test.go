package main

import (
	"archive/zip"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFixture(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
}

func makeArchive(t *testing.T, path string, files map[string]string) {
	t.Helper()
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	z := zip.NewWriter(f)
	for name, body := range files {
		w, err := z.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err = w.Write([]byte(body)); err != nil {
			t.Fatal(err)
		}
	}
	if err := z.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
}

func TestInstallUpdateUninstall(t *testing.T) {
	source, target := t.TempDir(), filepath.Join(t.TempDir(), "文件", "Addon")
	if err := os.MkdirAll(target, 0755); err != nil {
		t.Fatal(err)
	}
	makeArchive(t, filepath.Join(source, "demo.zip"), map[string]string{"demo/main.lua": "new", "demo/version.txt": "1.0.0", "demo/nested/data.lua": "data"})
	src := NewReleaseSource(source, func() string { return "" })
	addon := &AddonInfo{Name: "demo", Version: "1.0.0"}
	backed, err := installAddon(context.Background(), src, target, addon, nil)
	if err != nil || backed {
		t.Fatalf("fresh install: %v %v", backed, err)
	}
	if v := installedVersion(target, "demo"); v == nil || *v != "1.0.0" {
		t.Fatal("missing installed version")
	}
	writeFixture(t, filepath.Join(target, "demo", "main.lua"), "old")
	writeFixture(t, filepath.Join(target, "demo", "custom.txt"), "keep")
	backed, err = installAddon(context.Background(), src, target, addon, nil)
	if err != nil || !backed {
		t.Fatalf("update: %v %v", backed, err)
	}
	backups, _ := filepath.Glob(filepath.Join(target, "Backup", "demo_*"))
	if len(backups) != 1 {
		t.Fatalf("backup count %d", len(backups))
	}
	old, _ := os.ReadFile(filepath.Join(backups[0], "main.lua"))
	if string(old) != "old" {
		t.Fatal("backup lost original")
	}
	kept, _ := os.ReadFile(filepath.Join(target, "demo", "custom.txt"))
	if string(kept) != "keep" {
		t.Fatal("custom data lost")
	}
	if err := uninstallAddon(target, "demo"); err != nil {
		t.Fatal(err)
	}
	if isInstalled(target, "demo") {
		t.Fatal("uninstall did not remove addon")
	}
	backups, _ = filepath.Glob(filepath.Join(target, "Backup", "demo_*"))
	if len(backups) != 2 {
		t.Fatal("backups collide")
	}
	if err := uninstallAddon(target, "Backup"); err == nil {
		t.Fatal("backup folder must be protected")
	}
}

func TestArchiveTraversal(t *testing.T) {
	for _, name := range []string{"../escape.lua", `..\escape.lua`, "demo/../../escape.lua"} {
		t.Run(strings.ReplaceAll(name, "/", "_"), func(t *testing.T) {
			dir := t.TempDir()
			archive := filepath.Join(dir, "bad.zip")
			makeArchive(t, archive, map[string]string{name: "bad"})
			if err := extractZip(archive, filepath.Join(dir, "out")); err == nil {
				t.Fatal("accepted traversal")
			}
			if _, err := os.Stat(filepath.Join(dir, "escape.lua")); !os.IsNotExist(err) {
				t.Fatal("escaped destination")
			}
		})
	}
}

func TestTokenOnlyFromUserSettings(t *testing.T) {
	const plain = "test-only-not-a-real-token"
	protected, err := protectString(plain)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(protected, plain) {
		t.Fatal("stored plaintext")
	}
	decoded, err := unprotectString(protected)
	if err != nil || decoded != plain {
		t.Fatal("DPAPI roundtrip failed")
	}
	t.Setenv("ARCHERAGE_INSTALLER_TOKEN", "environment-must-be-ignored")
	t.Setenv("INSTALLER_GITHUB_TOKEN", "build-token-must-be-ignored")
	value, info := resolveToken(&Settings{Token: protected})
	if value != plain || info.Source != "settings" {
		t.Fatal("settings precedence")
	}
	value, info = resolveToken(&Settings{})
	if value != "" || info.Source != "" {
		t.Fatal("only user settings may supply a token")
	}
}

func TestVersionsAndBOM(t *testing.T) {
	dir := t.TempDir()
	writeFixture(t, filepath.Join(dir, "demo", "version.txt"), "\uFEFF1.0.0\r\n")
	current := installedVersion(dir, "demo")
	if current == nil || *current != "1.0.0" || isNewer("1.0", current) || !isNewer("1.0.1", current) {
		t.Fatal("version comparison failed")
	}
}
