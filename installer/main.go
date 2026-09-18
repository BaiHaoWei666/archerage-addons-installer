package main

import (
	"embed"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/windows"
)

//go:embed all:frontend/dist
var assets embed.FS

// 由 scripts/build-release.ps1 以 -ldflags "-X main.xxx=..." 注入
var version = "0.0.0"

const (
	appName    = "ArcheRage Addon Installer"
	appDirName = "ArcheRageAddonInstaller"
	exeName    = "ArcheRageAddonInstaller.exe"
	repo       = "BaiHaoWei666/archerage-addons-installer"
)

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--version" {
		fmt.Println(version)
		return
	}
	if err := waitForUpdateParent(); err != nil {
		log.Fatal(err)
	}

	// 測試用參數：
	//   --source <資料夾或網址>  改從本機 dist 資料夾或其他網址讀取
	//   --addon-dir <資料夾>     暫時改用這個插件資料夾（不會存進設定）
	var sourceArg, addonDirArg string
	args := os.Args[1:]
	for i := 0; i < len(args)-1; i++ {
		switch args[i] {
		case "--source":
			sourceArg = args[i+1]
		case "--addon-dir":
			addonDirArg = args[i+1]
		}
	}

	cleanupOldVersion()
	app := NewApp(sourceArg, addonDirArg)

	err := wails.Run(&options.App{
		Title:            appName,
		Width:            1120,
		Height:           720,
		MinWidth:         920,
		MinHeight:        560,
		BackgroundColour: &options.RGBA{R: 0x16, G: 0x18, B: 0x1b, A: 255},
		AssetServer: &assetserver.Options{
			Assets:  assets,
			Handler: http.HandlerFunc(app.serveHTTP),
		},
		OnStartup:  app.startup,
		OnShutdown: app.shutdown,
		Bind:       []interface{}{app},
		Windows: &windows.Options{
			Theme:               windows.Dark,
			WebviewUserDataPath: filepath.Join(os.Getenv("LOCALAPPDATA"), appDirName, "WebView2"),
		},
	})
	if err != nil {
		log.Fatal(err)
	}
}
