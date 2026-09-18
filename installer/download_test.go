package main

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestDownloadStatistics(t *testing.T) {
	for _, known := range []bool{true, false} {
		t.Run(fmt.Sprint(known), func(t *testing.T) {
			payload := strings.Repeat("x", 4096)
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if known {
					w.Header().Set("Content-Length", fmt.Sprint(len(payload)*2))
				}
				fmt.Fprint(w, payload)
				w.(http.Flusher).Flush()
				time.Sleep(250 * time.Millisecond)
				fmt.Fprint(w, payload)
			}))
			defer server.Close()
			src := NewReleaseSource(server.URL)
			dest := filepath.Join(t.TempDir(), "download.bin")
			var reports []DownloadProgress
			err := src.Download(context.Background(), "test.bin", dest, nil, func(p DownloadProgress) { reports = append(reports, p) })
			if err != nil {
				t.Fatal(err)
			}
			if len(reports) < 3 {
				t.Fatalf("回報次數不足：%d", len(reports))
			}
			if reports[0].Received != 0 {
				t.Fatal("起始進度不是零")
			}
			last := reports[len(reports)-1]
			if last.Received != int64(len(payload)*2) {
				t.Fatalf("下載量錯誤：%+v", last)
			}
			positiveSpeed := false
			for i, p := range reports {
				if p.BytesPerSecond > 0 {
					positiveSpeed = true
				}
				if p.BytesPerSecond < 0 {
					t.Fatal("速度為負數")
				}
				if i > 0 && p.Received < reports[i-1].Received {
					t.Fatal("下載量倒退")
				}
				if known && p.Total != int64(len(payload)*2) {
					t.Fatal("總大小錯誤")
				}
				if !known && p.Total > 0 {
					t.Fatal("未知總大小被誤判")
				}
			}
			if !positiveSpeed {
				t.Fatal("缺少下載速度")
			}
			got, err := os.ReadFile(dest)
			if err != nil || string(got) != payload+payload {
				t.Fatal("下載內容不一致", err)
			}
		})
	}
}

func TestDownloadTruncated(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", "100")
		fmt.Fprint(w, "short")
	}))
	defer server.Close()
	src := NewReleaseSource(server.URL)
	err := src.Download(context.Background(), "test.bin", filepath.Join(t.TempDir(), "out"), nil, func(p DownloadProgress) {
		if p.Received >= p.Total {
			t.Fatal("中斷下載不應回報完成")
		}
	})
	if err == nil {
		t.Fatal("未回報下載中斷")
	}
}
