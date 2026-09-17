package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"
	"time"
)

// 僅在拋棄式測試執行檔中執行，不修改已安裝的程式。
func TestSelfUpdateHelper(t *testing.T) {
	mode := os.Getenv("AR_TEST_SELF_MODE")
	if mode == "" {
		return
	}
	dir := os.Getenv("AR_TEST_SELF_DIR")
	if mode == "new" {
		if err := waitForUpdateParent(); err != nil {
			os.Exit(8)
		}
		if err := os.WriteFile(filepath.Join(dir, "started.txt"), []byte("ok"), 0600); err != nil {
			os.Exit(7)
		}
		cleanupOldVersion()
		for i := 0; i < 50; i++ {
			if _, err := os.Stat(filepath.Join(dir, "app.old.exe")); os.IsNotExist(err) {
				break
			}
			time.Sleep(100 * time.Millisecond)
		}
		if err := os.WriteFile(filepath.Join(dir, "restarted.txt"), []byte("ok"), 0600); err != nil {
			os.Exit(3)
		}
		os.Exit(0)
	}
	os.Setenv("AR_TEST_SELF_MODE", "new")
	src := NewReleaseSource(filepath.Join(dir, "release"), func() string { return "" })
	err := replaceSelf(context.Background(), src, nil)
	if mode == "bad" {
		if err == nil {
			os.Exit(4)
		}
		os.Exit(0)
	}
	if err != nil {
		os.Exit(5)
	}
	// 模擬舊視窗尚在結束，這段期間新版不可開始初始化 UI。
	time.Sleep(800 * time.Millisecond)
	if _, err := os.Stat(filepath.Join(dir, "started.txt")); err == nil {
		os.Exit(6)
	}
	os.Exit(0)
}

func TestSelfUpdateRestartAndRollback(t *testing.T) {
	for _, mode := range []string{"old", "bad"} {
		t.Run(mode, func(t *testing.T) {
			dir := t.TempDir()
			release := filepath.Join(dir, "release")
			if err := os.MkdirAll(release, 0755); err != nil {
				t.Fatal(err)
			}
			current, err := os.Executable()
			if err != nil {
				t.Fatal(err)
			}
			app := filepath.Join(dir, "app.exe")
			if err := copyFile(current, app); err != nil {
				t.Fatal(err)
			}
			asset := filepath.Join(release, exeName)
			if mode == "bad" {
				writeFixture(t, asset, "invalid executable")
			} else if err := copyFile(current, asset); err != nil {
				t.Fatal(err)
			}
			cmd := exec.Command(app, "-test.run=^TestSelfUpdateHelper$")
			cmd.Env = append(os.Environ(), "AR_TEST_SELF_MODE="+mode, "AR_TEST_SELF_DIR="+dir)
			if output, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("helper: %v %s", err, output)
			}
			if mode == "old" {
				deadline := time.Now().Add(8 * time.Second)
				for time.Now().Before(deadline) {
					if _, err := os.Stat(filepath.Join(dir, "restarted.txt")); err == nil {
						break
					}
					time.Sleep(100 * time.Millisecond)
				}
				if _, err := os.Stat(filepath.Join(dir, "restarted.txt")); err != nil {
					t.Fatal("新版程序未重新啟動")
				}
			}
			if _, err := os.Stat(filepath.Join(dir, "app.old.exe")); !os.IsNotExist(err) {
				t.Fatal("舊版執行檔未清除")
			}
			got, err := os.Stat(app)
			if err != nil {
				t.Fatal(err)
			}
			want, _ := os.Stat(current)
			if got.Size() != want.Size() {
				t.Fatal("執行檔未正確保留")
			}
		})
	}
}

func TestWaitForUpdateParentInput(t *testing.T) {
	t.Setenv(updateParentEnv, "")
	if err := waitForUpdateParent(); err != nil {
		t.Fatal(err)
	}
	for _, value := range []string{"invalid", "0", "-1", strconv.Itoa(os.Getpid())} {
		t.Setenv(updateParentEnv, value)
		if err := waitForUpdateParent(); err == nil {
			t.Fatalf("應拒絕無效程序編號：%q", value)
		}
		if os.Getenv(updateParentEnv) != "" {
			t.Fatal("交接參數不應繼續傳給其他子程序")
		}
	}
}
