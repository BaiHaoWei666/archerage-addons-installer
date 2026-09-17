package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// 安裝工具自己的更新：執行中的 exe 不能覆蓋但可以改名，
// 所以先把自己改名成 .old.exe，放上新版後重新啟動，新版啟動時再刪掉 .old.exe。

func exePath() (string, error) {
	p, err := os.Executable()
	if err != nil {
		return "", err
	}
	return filepath.EvalSymlinks(p)
}

func siblingPath(exe, suffix string) string {
	return strings.TrimSuffix(exe, filepath.Ext(exe)) + suffix
}

func cleanupOldVersion() {
	exe, err := exePath()
	if err != nil {
		return
	}
	old := siblingPath(exe, ".old.exe")
	if _, err := os.Stat(old); err != nil {
		return
	}
	// 舊版程序可能還沒完全結束，背景重試幾次
	go func() {
		for i := 0; i < 20; i++ {
			if err := os.Remove(old); err == nil || os.IsNotExist(err) {
				return
			}
			time.Sleep(500 * time.Millisecond)
		}
	}()
}

func installerIsNewer(latest string) bool {
	current := version
	return isNewer(latest, &current)
}

// replaceSelf 下載新版、換掉自己並啟動新版；成功後呼叫端要結束程式。
func replaceSelf(ctx context.Context, src *ReleaseSource, progress func(DownloadProgress)) error {
	exe, err := exePath()
	if err != nil {
		return err
	}
	newPath := siblingPath(exe, ".new.exe")
	if err := src.Download(ctx, exeName, newPath, nil, progress); err != nil {
		os.Remove(newPath)
		return err
	}

	old := siblingPath(exe, ".old.exe")
	_ = os.Remove(old)
	if err := os.Rename(exe, old); err != nil {
		os.Remove(newPath)
		return err
	}
	if err := os.Rename(newPath, exe); err != nil {
		_ = os.Rename(old, exe)
		return err
	}

	if err := exec.Command(exe, os.Args[1:]...).Start(); err != nil {
		_ = os.Remove(exe)
		_ = os.Rename(old, exe)
		return err
	}
	return nil
}
