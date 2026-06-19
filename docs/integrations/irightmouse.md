# iRightMouse Pro / 超级右键 集成

超级右键通过 **打开 App** 调用，直接选择主 App 即可：

```
~/Applications/Finder-go-up.app
```

打开后会立即返回上一级，无设置界面。

## 手动配置

1. 安装 **Finder-go-up**（拖入 Applications 后打开一次，允许控制「访达」）
2. **iRightMouse Pro → 偏好设置 → 工具箱 → 打开 App**
3. 选择 `~/Applications/Finder-go-up.app`
4. 名称：**返回上一级**
5. 重启 iRightMouse Pro，或从源码运行 `bash scripts/configure-irightmouse.sh`

## 其他调用方式

```bash
finder-go-up
open finder-go-up://go-up
open ~/Applications/Finder-go-up.app
```
