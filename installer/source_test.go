package main

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestNoTokenMakesNoOnlineRequest(t *testing.T) {
	src := NewReleaseSource("", func() string { return "" })
	src.client.Transport = testTransport(func(r *http.Request) (*http.Response, error) {
		t.Fatal("unexpected network request without token")
		return nil, nil
	})
	_, err := src.LoadManifest(context.Background())
	if !errors.Is(err, errTokenRequired) {
		t.Fatalf("expected token prompt, got %v", err)
	}
}

type testTransport func(*http.Request) (*http.Response, error)

func (f testTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestPrivateReleaseDownload(t *testing.T) {
	src := NewReleaseSource("", func() string { return "test-token" })
	calls := 0
	src.client.Transport = testTransport(func(r *http.Request) (*http.Response, error) {
		calls++
		if r.URL.Host != "api.github.com" || r.Header.Get("Authorization") != "Bearer test-token" {
			t.Fatal("missing scoped API auth")
		}
		body := `{"assets":[{"name":"manifest.json","url":"https://api.github.com/repos/` + repo + `/releases/assets/1"}]}`
		if strings.HasSuffix(r.URL.Path, "/assets/1") {
			if r.Header.Get("Accept") != "application/octet-stream" {
				t.Fatal("asset download accept header")
			}
			body = `{"installer":{"version":"1.0.0"},"addons":[{"name":"demo","version":"1.0.0"}]}`
		}
		return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header), Request: r}, nil
	})
	manifest, err := src.LoadManifest(context.Background())
	if err != nil || len(manifest.Addons) != 1 || calls != 2 {
		t.Fatalf("private manifest: %v calls=%d", err, calls)
	}
}

func TestCredentialsStayOnGitHubAPI(t *testing.T) {
	src := NewReleaseSource("https://example.test/download/", func() string { return "test-token" })
	src.client.Transport = testTransport(func(r *http.Request) (*http.Response, error) {
		if r.Header.Get("Authorization") != "" {
			t.Fatal("credential sent to custom source")
		}
		return &http.Response{StatusCode: 401, Body: io.NopCloser(strings.NewReader("")), Header: make(http.Header), Request: r}, nil
	})
	_, err := src.LoadManifest(context.Background())
	if err == nil || !strings.Contains(src.describeError(err), "權杖") || strings.Contains(src.describeError(err), "test-token") {
		t.Fatal("authentication error handling")
	}
}
