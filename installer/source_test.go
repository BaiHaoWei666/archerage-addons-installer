package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
)

type testTransport func(*http.Request) (*http.Response, error)

func (f testTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func releaseFixture(repository, tag string, names ...string) string {
	assets := []map[string]string{}
	for _, name := range names {
		assets = append(assets, map[string]string{"name": name, "browser_download_url": "https://github.com/" + repository + "/releases/download/" + tag + "/" + name})
	}
	data, _ := json.Marshal(map[string]interface{}{"tag_name": tag, "assets": assets})
	return string(data)
}
func publicFixture(t *testing.T, urls []string, change func(string, string) (string, int)) *ReleaseSource {
	t.Helper()
	src := NewReleaseSource("")
	registry, _ := json.Marshal(urls)
	data := map[string]string{
		"https://api.github.com/repos/" + repo + "/releases/tags/registry":             releaseFixture(repo, "registry", "repositories.json"),
		"https://github.com/" + repo + "/releases/download/registry/repositories.json": string(registry),
		"https://api.github.com/repos/" + repo + "/releases/latest":                    releaseFixture(repo, "v2.0.0", exeName),
	}
	for _, raw := range urls {
		repository := strings.TrimPrefix(raw, "https://github.com/")
		data["https://api.github.com/repos/"+repository+"/releases/latest"] = releaseFixture(repository, "v1.2.3", "manifest.json", "demo.zip", "demo.md", "demo.png")
		data["https://github.com/"+repository+"/releases/download/v1.2.3/manifest.json"] = `{"schemaVersion":1,"name":"demo","version":"1.2.3","sha256":"` + strings.Repeat("a", 64) + `"}`
	}
	src.client.Transport = testTransport(func(r *http.Request) (*http.Response, error) {
		if r.Header.Get("Authorization") != "" {
			t.Fatal("公開下載不應傳送憑證")
		}
		if strings.Contains(r.URL.Path, "/contents/") || strings.Contains(r.URL.Host, "raw.") {
			t.Fatal("不應讀取 Git 檔案")
		}
		body, ok := data[r.URL.String()]
		status := 200
		if !ok {
			status = 404
		}
		if change != nil {
			body, status = change(r.URL.String(), body)
		}
		return &http.Response{StatusCode: status, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}, nil
	})
	return src
}
func TestPublicReleaseSnapshot(t *testing.T) {
	src := publicFixture(t, []string{"https://github.com/example/plugin"}, nil)
	m, err := src.LoadManifest(context.Background())
	if err != nil || len(m.Addons) != 1 || m.Installer.Version != "2.0.0" || len(m.Warnings) != 0 {
		t.Fatalf("公開來源失敗：%+v %v", m, err)
	}
	for _, ext := range []string{".zip", ".md", ".png"} {
		location, err := src.assetURL(context.Background(), "demo"+ext)
		if err != nil || location != "https://github.com/example/plugin/releases/download/v1.2.3/demo"+ext {
			t.Fatalf("附件未固定版本：%s %v", location, err)
		}
	}
	location, err := src.assetURL(context.Background(), exeName)
	if err != nil || !strings.Contains(location, "/v2.0.0/") {
		t.Fatal("安裝器版本未獨立解析")
	}
}
func TestInvalidPluginDoesNotBlockOthers(t *testing.T) {
	src := publicFixture(t, []string{"https://github.com/example/broken", "https://github.com/example/working"}, func(location, body string) (string, int) {
		if strings.Contains(location, "example/broken") {
			return "", 404
		}
		return body, 200
	})
	m, err := src.LoadManifest(context.Background())
	if err != nil || len(m.Addons) != 1 || len(m.Warnings) != 1 {
		t.Fatalf("來源失敗未隔離：%+v %v", m, err)
	}
}
func TestDuplicatePluginNamesAreRejected(t *testing.T) {
	src := publicFixture(t, []string{"https://github.com/example/first", "https://github.com/example/second"}, nil)
	if _, err := src.LoadManifest(context.Background()); err == nil {
		t.Fatal("接受重複的安裝目錄")
	}
}
func TestReleaseValidation(t *testing.T) {
	for _, test := range []struct{ name, old, replacement string }{
		{"版本不一致", `"version":"1.2.3"`, `"version":"1.2.4"`},
		{"格式不支援", `"schemaVersion":1`, `"schemaVersion":99`},
		{"目錄不合法", `"name":"demo"`, `"name":"../demo"`},
		{"保留目錄", `"name":"demo"`, `"name":"Backup"`},
		{"缺少雜湊", strings.Repeat("a", 64), "bad"},
	} {
		t.Run(test.name, func(t *testing.T) {
			src := publicFixture(t, []string{"https://github.com/example/plugin"}, func(location, body string) (string, int) {
				if strings.HasSuffix(location, "/manifest.json") {
					body = strings.ReplaceAll(body, test.old, test.replacement)
				}
				return body, 200
			})
			m, err := src.LoadManifest(context.Background())
			if err != nil || len(m.Addons) != 0 || len(m.Warnings) != 1 {
				t.Fatalf("未拒絕不合法插件：%+v %v", m, err)
			}
		})
	}
}
func TestReleaseAssetMustBelongToSelectedRepository(t *testing.T) {
	src := publicFixture(t, []string{"https://github.com/example/plugin"}, func(location, body string) (string, int) {
		if strings.Contains(location, "/example/plugin/releases/latest") {
			body = strings.ReplaceAll(body, "https://github.com/example/plugin/", "https://example.com/")
		}
		return body, 200
	})
	m, err := src.LoadManifest(context.Background())
	if err != nil || len(m.Addons) != 0 || len(m.Warnings) != 1 {
		t.Fatal("接受外部附件網址")
	}
}
func TestInstallerFailureDoesNotBlockPlugins(t *testing.T) {
	src := publicFixture(t, []string{"https://github.com/example/plugin"}, func(location, body string) (string, int) {
		if location == "https://api.github.com/repos/"+repo+"/releases/latest" {
			return "", 404
		}
		return body, 200
	})
	m, err := src.LoadManifest(context.Background())
	if err != nil || len(m.Addons) != 1 || m.Installer.Version != "" || len(m.Warnings) != 1 {
		t.Fatal("安裝器來源失敗阻擋插件")
	}
}
func TestRepositoryURLValidation(t *testing.T) {
	for _, raw := range []string{"http://github.com/a/b", "https://evil.test/a/b", "https://github.com/a/b/tree/main", "https://user@github.com/a/b", "https://github.com/a/b?x=1", "https://github.com/a/.."} {
		if _, err := repositoryName(raw); err == nil {
			t.Fatal("接受不合法來源：" + raw)
		}
	}
}
func TestRegistryFailurePreservesExistingDownloadSnapshot(t *testing.T) {
	src := publicFixture(t, []string{"https://github.com/example/plugin"}, nil)
	if _, err := src.LoadManifest(context.Background()); err != nil {
		t.Fatal(err)
	}
	src.client.Transport = testTransport(func(r *http.Request) (*http.Response, error) { return nil, fmt.Errorf("離線") })
	if _, err := src.LoadManifest(context.Background()); err == nil {
		t.Fatal("離線卻成功")
	}
	if _, err := src.assetURL(context.Background(), "demo.zip"); err != nil {
		t.Fatal("失敗重新整理破壞既有快照")
	}
}
