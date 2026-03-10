# ShiftInputSwitch

ShiftInputSwitch 是一个 macOS 菜单栏工具，用于把左右 `Shift` 映射为固定的输入源切换动作：

- 左 `Shift` 轻点切到英文输入源
- 右 `Shift` 轻点切到中文输入源

它不依赖系统的循环切换逻辑，而是始终切到预先指定的那一对输入源。

## 功能

- 区分左 `Shift` 和右 `Shift`
- 左 `Shift` 固定切英文，右 `Shift` 固定切中文
- 菜单栏显示当前输入状态
- 菜单中可手动选择英文输入源和中文输入源
- 启动时自动识别可用输入源
- 对已安装但未启用、且系统允许启用的输入源尝试自动启用
- 支持开机自动启动

## 系统要求

- macOS 14 或更高版本
- Xcode 或 Command Line Tools
- Swift 6

## 安装

克隆仓库并执行安装脚本：

```bash
git clone https://github.com/liumengdi/shift-input-switch.git
cd shift-input-switch
bash scripts/install-current-mac.sh
```

脚本会构建并安装 `.app`。默认优先安装到：

```bash
/Applications/Shift Input Switch.app
```

如果当前终端没有写入 `/Applications` 的权限，会回退到：

```bash
~/Applications/Shift Input Switch.app
```

## 使用

首次启动后需要完成以下设置：

1. 在“系统设置 -> 隐私与安全性 -> 输入监控”中允许 `Shift Input Switch`
2. 点击菜单栏图标，确认英文输入源和中文输入源配置正确
3. 如需开机自动启动，在菜单中启用“开启开机自动启动”

完成后即可使用：

- 轻点左 `Shift` 切到英文输入源
- 轻点右 `Shift` 切到中文输入源

只有单独轻点 `Shift` 时才会触发切换；和其它键组合使用时不会触发。

## 开发运行

直接运行：

```bash
bash scripts/dev-run.sh
```

手动构建 `.app`：

```bash
bash scripts/build-app.sh release
```

构建产物位于：

```bash
dist/Shift Input Switch.app
```
