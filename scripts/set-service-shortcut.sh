#!/usr/bin/env bash
# Configure default service shortcut (⌃⌘↑) for all localized menu titles.
set -euo pipefail

python3 <<'PY'
import os
import plistlib

pbs_path = os.path.expanduser("~/Library/Preferences/pbs.plist")
shortcut = "^@" + "\uf700"  # Control + Command + Up Arrow

keys = [
    "com.acode.finder-go-up - Go Up - finderGoUp",
    "com.acode.finder-go-up - 返回上一级 - finderGoUp",
    "com.acode.finder-go-up - 返回上一層 - finderGoUp",
    "com.acode.finder-go-up - 上のフォルダへ - finderGoUp",
    "com.acode.finder-go-up - 상위 폴더로 - finderGoUp",
    "com.acode.finder-go-up - Ebene höher - finderGoUp",
    "com.acode.finder-go-up - Dossier parent - finderGoUp",
    "com.acode.finder-go-up - Subir nivel - finderGoUp",
]

entry = {
    "enabled": True,
    "enabled_context_menu": True,
    "enabled_services_menu": True,
    "key_equivalent": shortcut,
}

data = {}
if os.path.exists(pbs_path):
    with open(pbs_path, "rb") as handle:
        data = plistlib.load(handle)

status = data.get("NSServicesStatus", {})
for key in keys:
    status[key] = entry
data["NSServicesStatus"] = status

with open(pbs_path, "wb") as handle:
    plistlib.dump(data, handle)

print("Set service shortcut to Control+Command+Up Arrow")
PY

/System/Library/CoreServices/pbs -flush 2>/dev/null || true
