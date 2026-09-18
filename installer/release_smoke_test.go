package main

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// 手動驗證已發布附件；一般 CI 不依賴外部網路或實際收錄內容。
func TestPublishedReleaseSmoke(t *testing.T) {
	if os.Getenv("ARCHERAGE_RELEASE_SMOKE") != "1" {
		t.Skip("需明確啟用線上 Release 驗證")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	src := NewReleaseSource("")
	m, err := src.LoadManifest(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(m.Warnings) != 0 || len(m.Addons) == 0 || m.Installer.Version == "" {
		t.Fatalf("發布來源未就緒：%+v", m)
	}
	dir := t.TempDir()
	for i := range m.Addons {
		addon := &m.Addons[i]
		if _, err := installAddon(ctx, src, dir, addon, nil); err != nil {
			t.Fatal(err)
		}
		v := installedVersion(dir, addon.Name)
		if v == nil || *v != addon.Version {
			t.Fatal("安裝後版本不一致")
		}
		if _, err := os.Stat(filepath.Join(dir, addon.Name, "toc.g")); err != nil {
			t.Fatal(err)
		}
		if src.TryGetFile(ctx, addon.Name+".md") == nil {
			t.Fatal("缺少發布說明")
		}
	}
	t.Logf("匿名 Release 驗證成功：安裝器 %s，插件 %d 個", m.Installer.Version, len(m.Addons))
}
