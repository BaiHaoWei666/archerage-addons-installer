package main

import (
	"regexp"
	"strconv"
	"strings"
)

// Manifest 對應 GitHub Release 上的 manifest.json。
type Manifest struct {
	Installer struct {
		Version string `json:"version"`
	} `json:"installer"`
	Addons []AddonInfo `json:"addons"`
}

type AddonInfo struct {
	// Name 是插件資料夾名稱，也是 zip、圖示（.png）、說明（.md）的檔名。
	Name        string           `json:"name"`
	DisplayName string           `json:"displayName"`
	Version     string           `json:"version"`
	Description string           `json:"description"`
	Category    string           `json:"category"`
	Author      string           `json:"author"`
	Changelog   []ChangelogEntry `json:"changelog"`
}

type ChangelogEntry struct {
	Version string   `json:"version"`
	Date    string   `json:"date"`
	Notes   []string `json:"notes"`
}

func (a AddonInfo) Title() string {
	if strings.TrimSpace(a.DisplayName) != "" {
		return a.DisplayName
	}
	return a.Name
}

func (m *Manifest) find(name string) *AddonInfo {
	for i := range m.Addons {
		if m.Addons[i].Name == name {
			return &m.Addons[i]
		}
	}
	return nil
}

var safeNamePattern = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

// safeName 檢查是否為單純的檔名（不含路徑，也不是 . 或 ..）。
func safeName(name string) bool {
	return safeNamePattern.MatchString(name) && name != "." && name != ".."
}

// isNewer 判斷 latest 是否比 current 新；current 為 nil（版本不明）時視為需要更新。
func isNewer(latest string, current *string) bool {
	if current == nil {
		return true
	}
	l, okL := parseVersion(latest)
	c, okC := parseVersion(*current)
	if !okL || !okC {
		return !strings.EqualFold(latest, *current)
	}
	for i := range l {
		if l[i] != c[i] {
			return l[i] > c[i]
		}
	}
	return false
}

func parseVersion(s string) ([4]int, bool) {
	var v [4]int
	parts := strings.Split(strings.TrimPrefix(strings.TrimSpace(s), "v"), ".")
	if len(parts) == 0 || len(parts) > 4 {
		return v, false
	}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil || n < 0 {
			return v, false
		}
		v[i] = n
	}
	return v, true
}
