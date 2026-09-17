package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"golang.org/x/sys/windows"
)

// 安裝工具自己的更新：執行中的 exe 不能覆蓋但可以改名，
// 所以先把自己改名成 .old.exe，放上新版後重新啟動，新版啟動時再刪掉 .old.exe。

const updateParentEnv = "ARCHERAGE_UPDATE_PARENT_PID"

// 新版在建立視窗與 WebView2 前等待舊程序結束，避免兩個版本同時使用 UI 資料。
func waitForUpdateParent() error {
	value := os.Getenv(updateParentEnv)
	if value == "" {
		return nil
	}
	os.Unsetenv(updateParentEnv)
	pid, err := strconv.ParseUint(value, 10, 32)
	if err != nil || pid == 0 || pid == uint64(os.Getpid()) {
		return fmt.Errorf("更新交接的舊程序編號無效：%q", value)
	}
	handle, err := windows.OpenProcess(windows.SYNCHRONIZE, false, uint32(pid))
	// 舊程序已在新版開始等待前結束。
	if errors.Is(err, windows.ERROR_INVALID_PARAMETER) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("無法等待舊版安裝器：%w", err)
	}
	defer windows.CloseHandle(handle)
	result, err := windows.WaitForSingleObject(handle, 30000)
	if err != nil {
		return fmt.Errorf("等待舊版安裝器失敗：%w", err)
	}
	if result != windows.WAIT_OBJECT_0 {
		return fmt.Errorf("舊版安裝器未在 30 秒內關閉，停止啟動新版")
	}
	return nil
}

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

	cmd := exec.Command(exe, os.Args[1:]...)
	cmd.Env = append(os.Environ(), updateParentEnv+"="+strconv.Itoa(os.Getpid()))
	if err := cmd.Start(); err != nil {
		_ = os.Remove(exe)
		_ = os.Rename(old, exe)
		return err
	}
	return nil
}
