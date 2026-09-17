package main

import (
	"archive/zip"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

// versionFileName 是發佈時寫進每個插件資料夾的版本檔，遊戲不會讀取它。
const versionFileName = "version.txt"

func defaultAddonDir() string {
	docs, err := windows.KnownFolderPath(windows.FOLDERID_Documents, windows.KF_FLAG_DEFAULT)
	if err != nil {
		home, _ := os.UserHomeDir()
		docs = filepath.Join(home, "Documents")
	}
	return filepath.Join(docs, "ArcheRage", "Addon")
}

func isInstalled(addonDir, name string) bool {
	return isDir(filepath.Join(addonDir, name))
}

func installedVersion(addonDir, name string) *string {
	data, err := os.ReadFile(filepath.Join(addonDir, name, versionFileName))
	if err != nil {
		return nil
	}
	v := strings.TrimSpace(strings.TrimPrefix(string(data), "\uFEFF"))
	return &v
}

func isGameRunning() bool {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return false
	}
	defer windows.CloseHandle(snap)

	var pe windows.ProcessEntry32
	pe.Size = uint32(unsafe.Sizeof(pe))
	for err = windows.Process32First(snap, &pe); err == nil; err = windows.Process32Next(snap, &pe) {
		if strings.EqualFold(windows.UTF16ToString(pe.ExeFile[:]), "archeage.exe") {
			return true
		}
	}
	return false
}

// installAddon 下載並安裝插件。已安裝時先備份到 Addon\Backup\名稱_時間，再覆蓋檔案；
// 不刪除任何本機檔案。回傳是否有備份。
func installAddon(ctx context.Context, src *ReleaseSource, addonDir string, addon *AddonInfo, progress func(float64)) (bool, error) {
	if !safeName(addon.Name) || strings.EqualFold(addon.Name, "Backup") {
		return false, fmt.Errorf("manifest.json 裡的插件名稱不合法：「%s」", addon.Name)
	}

	work, err := os.MkdirTemp("", appDirName+"-")
	if err != nil {
		return false, err
	}
	defer os.RemoveAll(work)

	zipPath := filepath.Join(work, addon.Name+".zip")
	if err := src.Download(ctx, addon.Name+".zip", zipPath, progress); err != nil {
		return false, err
	}

	extractDir := filepath.Join(work, "extract")
	if err := extractZip(zipPath, extractDir); err != nil {
		return false, err
	}
	newDir := filepath.Join(extractDir, addon.Name)
	if !isDir(newDir) {
		return false, fmt.Errorf("%s.zip 裡找不到 %s 資料夾", addon.Name, addon.Name)
	}

	target := filepath.Join(addonDir, addon.Name)
	backedUp := false
	if isDir(target) {
		if _, err := backupAddon(addonDir, addon.Name); err != nil {
			return false, fmt.Errorf("備份失敗：%w", err)
		}
		backedUp = true
	}
	return backedUp, copyDir(newDir, target)
}

// uninstallAddon 先備份到 Addon\Backup 再刪除插件資料夾。
func uninstallAddon(addonDir, name string) error {
	if !safeName(name) || strings.EqualFold(name, "Backup") {
		return fmt.Errorf("插件名稱不合法：「%s」", name)
	}
	target := filepath.Join(addonDir, name)
	if !isDir(target) {
		return fmt.Errorf("%s 沒有安裝", name)
	}
	if _, err := backupAddon(addonDir, name); err != nil {
		return fmt.Errorf("備份失敗：%w", err)
	}
	return os.RemoveAll(target)
}

func backupAddon(addonDir, name string) (string, error) {
	root := filepath.Join(addonDir, "Backup")
	if err := os.MkdirAll(root, 0o755); err != nil {
		return "", err
	}
	backup, err := os.MkdirTemp(root, name+"_"+time.Now().Format("20060102_150405")+"_")
	if err != nil {
		return "", err
	}
	return backup, copyDir(filepath.Join(addonDir, name), backup)
}

func extractZip(zipPath, dest string) error {
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return fmt.Errorf("zip 檔損壞：%w", err)
	}
	defer r.Close()

	root := filepath.Clean(dest) + string(os.PathSeparator)
	for _, f := range r.File {
		path := filepath.Join(dest, filepath.FromSlash(strings.ReplaceAll(f.Name, `\`, "/")))
		if !strings.HasPrefix(path, root) {
			return fmt.Errorf("zip 檔含有不合法的路徑：%s", f.Name)
		}
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(path, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := extractFile(f, path); err != nil {
			return err
		}
	}
	return nil
}

func extractFile(f *zip.File, path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	in, err := f.Open()
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(path)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func copyDir(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		return copyFile(path, target)
	})
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
