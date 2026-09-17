package main

import (
	"encoding/base64"
	"unsafe"

	"golang.org/x/sys/windows"
)

// 權杖只能由使用者在設定頁貼上，以 DPAPI 加密儲存。

type tokenInfo struct {
	Source string `json:"source"` // settings | ""
	Hint   string `json:"hint"`   // 末四碼
}

func resolveToken(s *Settings) (string, tokenInfo) {
	if s.Token != "" {
		if t, err := unprotectString(s.Token); err == nil && t != "" {
			return t, tokenInfo{"settings", hint(t)}
		}
	}
	return "", tokenInfo{}
}

func hint(t string) string {
	if len(t) <= 4 {
		return ""
	}
	return t[len(t)-4:]
}

// ---------- DPAPI ----------

func protectString(plain string) (string, error) {
	data := []byte(plain)
	in := windows.DataBlob{Size: uint32(len(data)), Data: &data[0]}
	var out windows.DataBlob
	if err := windows.CryptProtectData(&in, nil, nil, 0, nil, windows.CRYPTPROTECT_UI_FORBIDDEN, &out); err != nil {
		return "", err
	}
	defer windows.LocalFree(windows.Handle(unsafe.Pointer(out.Data)))
	return base64.StdEncoding.EncodeToString(unsafe.Slice(out.Data, out.Size)), nil
}

func unprotectString(encoded string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil || len(data) == 0 {
		return "", err
	}
	in := windows.DataBlob{Size: uint32(len(data)), Data: &data[0]}
	var out windows.DataBlob
	if err := windows.CryptUnprotectData(&in, nil, nil, 0, nil, windows.CRYPTPROTECT_UI_FORBIDDEN, &out); err != nil {
		return "", err
	}
	defer windows.LocalFree(windows.Handle(unsafe.Pointer(out.Data)))
	return string(unsafe.Slice(out.Data, out.Size)), nil
}
