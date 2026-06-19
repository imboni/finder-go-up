#!/usr/bin/env bash
# Point iRightMouse Pro toolbox item to Finder-go-up.app
set -uo pipefail

APP_DIR="${APP_DIR:-$HOME/Applications}"
APP_PATH="$APP_DIR/Finder-go-up.app"
PLIST="$HOME/Library/Group Containers/4K6FWZU8C4.group.cn.better365.iRightMouse/Library/Preferences/4K6FWZU8C4.group.cn.better365.iRightMouse.plist"
BUNDLE_ID="com.acode.finder-go-up"
ITEM_NAME="返回上一级"

manual_hint() {
  echo ""
  echo "请手动配置超级右键："
  echo "  1. iRightMouse Pro → 偏好设置 → 工具箱"
  echo "  2. 添加/编辑「打开 App」→ 选择："
  echo "     $APP_PATH"
  echo "  3. 名称：$ITEM_NAME"
}

[[ -d "$APP_PATH" ]] || {
  echo "App not found: $APP_PATH" >&2
  echo "Run: bash scripts/install.sh" >&2
  exit 1
}

CONFIGURED=0
if [[ -f "$PLIST" ]]; then
  export PLIST APP_PATH BUNDLE_ID ITEM_NAME
  if python3 <<'PY'
import os, plistlib, copy, sys

plist_path = os.environ["PLIST"]
app_path = os.path.expanduser(os.environ["APP_PATH"])
bundle_id = os.environ["BUNDLE_ID"]
item_name = os.environ["ITEM_NAME"]

try:
    with open(plist_path, "rb") as handle:
        data = plistlib.load(handle)
except PermissionError:
    sys.exit(2)

def patch_item(item):
    if not isinstance(item, dict):
        return False
    name = str(item.get("name") or item.get("appName") or "")
    bid = str(item.get("bundleId") or "")
    if item_name not in name and bundle_id not in bid and "finder-go-up" not in bid.lower():
        return False
    item["enable"] = True
    item["name"] = item_name
    item["appName"] = item_name
    item["type"] = item.get("type", 2)
    item["bundleId"] = bundle_id
    item["appPath"] = app_path
    item["path"] = app_path
    return True

def walk(obj):
    changed = False
    if isinstance(obj, dict):
        if patch_item(obj):
            changed = True
        for value in obj.values():
            if walk(value):
                changed = True
    elif isinstance(obj, list):
        for value in obj:
            if walk(value):
                changed = True
    return changed

new_item = {
    "enable": True,
    "name": item_name,
    "appName": item_name,
    "type": 2,
    "bundleId": bundle_id,
    "appPath": app_path,
    "path": app_path,
    "selectOptionIndex": -1,
    "icon": "Finder.png",
}

changed = walk(data)
if not changed:
    for key, value in data.items():
        if isinstance(value, list) and "tool" in key.lower():
            value.append(copy.deepcopy(new_item))
            changed = True
            break

if not changed:
    sys.exit(1)

backup = plist_path + ".finder-go-up.bak"
if not os.path.exists(backup):
    with open(plist_path, "rb") as src, open(backup, "wb") as dst:
        dst.write(src.read())

with open(plist_path, "wb") as handle:
    plistlib.dump(data, handle)

print(f"Updated iRightMouse toolbox → {app_path}")
PY
  then
    CONFIGURED=1
  elif [[ $? -eq 2 ]]; then
    echo "无法自动写入 iRightMouse 配置（系统权限限制）。"
    manual_hint
  else
    echo "未能自动定位工具箱配置。"
    manual_hint
  fi
else
  echo "未找到 iRightMouse Pro 配置文件。"
  manual_hint
fi

killall "iRightMouse Pro" 2>/dev/null || true
sleep 1
open -a "iRightMouse Pro" 2>/dev/null || true
open -R "$APP_PATH"

if [[ "$CONFIGURED" -eq 1 ]]; then
  echo "已重启 iRightMouse Pro。"
else
  echo "已在 Finder 中定位 Finder-go-up.app，请按上方说明手动选择。"
fi
