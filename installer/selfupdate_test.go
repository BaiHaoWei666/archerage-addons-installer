package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// Runs in a disposable copy of this test executable, never the installed app.
func TestSelfUpdateHelper(t *testing.T) {
	mode := os.Getenv("AR_TEST_SELF_MODE")
	if mode == "" {
		return
	}
	dir := os.Getenv("AR_TEST_SELF_DIR")
	if mode == "new" {
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
					t.Fatal("new process did not restart")
				}
			}
			if _, err := os.Stat(filepath.Join(dir, "app.old.exe")); !os.IsNotExist(err) {
				t.Fatal("old exe remains")
			}
			got, err := os.Stat(app)
			if err != nil {
				t.Fatal(err)
			}
			want, _ := os.Stat(current)
			if got.Size() != want.Size() {
				t.Fatal("executable not preserved")
			}
		})
	}
}
