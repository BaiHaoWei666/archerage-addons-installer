"""以 Lua 5.1 檢查 addons 下所有 Lua 檔案的語法並執行 Lua 回歸測試。"""
import os
from pathlib import Path

from lupa.lua51 import LuaRuntime


def main():
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    runtime = LuaRuntime()
    assert runtime.eval("_VERSION") == "Lua 5.1"
    sources = sorted((root / "addons").rglob("*.lua"))
    tests = sorted((root / "tests").glob("*.lua"))
    if not sources or not tests:
        raise RuntimeError("找不到 Lua 原始碼或測試檔案")
    for path in sources:
        runtime.execute("assert(loadstring(...))", path.read_text(encoding="utf-8"), "@" + path.as_posix())
    print(f"PASS: {len(sources)} 個 Lua 檔案語法檢查", flush=True)
    for path in tests:
        print(f"執行：{path.relative_to(root)}", flush=True)
        # 每個測試檔使用獨立執行環境，避免全域模擬資料互相影響。
        LuaRuntime().execute(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
