# Changelog

## 0.0.3 — 2026-06-19

- **无界面**：打开 App 即返回上一级，移除设置窗口与 onboarding 流程
- **单一 App**：仅 `Finder-go-up.app`，不再单独安装 helper
- **服务菜单修复**：后台常驻 + `KeepAlive` LaunchAgent，右键「服务 → 返回上一级」与 ⌃⌘↑ 稳定可用
- **性能**：Unix socket 进程间通信；AppleScript 预编译与 Finder 连接预热
- **超级右键**：工具箱「打开 App」直接选 `~/Applications/Finder-go-up.app`
- **安装/清理**：`purge.sh` 全量清理旧版产物；`configure-irightmouse.sh` 辅助配置
- **DMG**：恢复带背景与 128px 图标的安装界面

## 0.0.2 — 2026-06-15

- 后台 LaunchAgent 与 NSServices 集成
- 设置窗口（已在 0.0.3 移除）

## 0.0.1 — 2026-06-12

- 初始发布
