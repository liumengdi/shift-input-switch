# ShiftInputSwitch

一个针对 macOS 的菜单栏小工具：

- 左 `Shift` 轻点，强制切到固定的英文输入源
- 右 `Shift` 轻点，强制切到固定的中文输入源
- 不依赖系统“轮流切换输入法”的状态
- 尽量减少用户设置，只需要首启授权和确认一次输入源

这个仓库的目标不是替代系统输入法，而是提供“确定性的中英文切换”。

## 为什么这样做

macOS 默认的输入法切换有一个常见痛点：

- 你知道自己按了切换键
- 但你不一定确定下一次输入出来的是中文还是英文

`ShiftInputSwitch` 的策略不是“在所有输入法之间循环切换”，而是固定一对输入源：

- 左 `Shift` -> 英文
- 右 `Shift` -> 中文

这样输入时的心智模型会简单很多。

## 功能特点

- 菜单栏常驻运行
- 自动识别一个英文输入源和一个中文输入源
- 可在菜单中手动改绑
- 支持区分左 `Shift` / 右 `Shift`
- 只在“轻点 Shift”时切换，避免干扰正常大写和快捷键
- 会优先使用已经启用的输入源
- 如果目标输入源已安装但未启用，会尝试自动启用再切换

## 环境要求

- macOS 14 或更高版本
- 安装 Xcode 或 Command Line Tools
- Swift 6 工具链

## 仓库结构

- [Package.swift](/Users/liumengdi/Developer/playground/Package.swift): Swift Package 定义
- [main.swift](/Users/liumengdi/Developer/playground/Sources/ShiftKeyIMESwitch/main.swift): 主应用逻辑
- [build-app.sh](/Users/liumengdi/Developer/playground/scripts/build-app.sh): 构建 `.app` 包
- [install-local.sh](/Users/liumengdi/Developer/playground/scripts/install-local.sh): 安装到本地 `~/Applications`
- [list-input-sources.swift](/Users/liumengdi/Developer/playground/scripts/list-input-sources.swift): 打印系统输入源，方便调试

## 快速开始

先克隆仓库：

```bash
git clone git@github.com:liumengdi/shift-input-switch.git
cd shift-input-switch
```

直接开发运行：

```bash
bash scripts/dev-run.sh
```

构建成 `.app`：

```bash
bash scripts/build-app.sh release
```

构建完成后，产物会在：

```bash
dist/Shift Input Switch.app
```

安装到当前用户目录：

```bash
bash scripts/install-local.sh
```

默认安装位置：

```bash
~/Applications/Shift Input Switch.app
```

## 另一台 Mac 怎么用

最推荐的方式不是直接拿别人打好的 `.app`，而是：

1. 在另一台 Mac 上克隆这个仓库
2. 本地运行 `bash scripts/install-local.sh`
3. 打开应用并授权“输入监控”

这样有两个好处：

- 本地构建的应用通常不会遇到“未识别开发者”的 Gatekeeper 拦截
- 代码也能直接在另一台电脑上继续编辑

如果你只是把未签名的预编译 `.app` 传给另一台 Mac，系统通常仍然会要求用户手动放行。

## 首次使用

首次启动后，请做这两件事：

1. 允许应用监听键盘事件
2. 确认菜单里左 `Shift` 和右 `Shift` 分别绑定到了你想要的英文/中文输入源

需要的系统权限是：

- 系统设置 -> 隐私与安全性 -> 输入监控

## 菜单栏说明

菜单栏状态会显示：

- `EN`: 当前输入源就是配置的英文源
- `中`: 当前输入源就是配置的中文源
- 其它缩写: 当前输入源不是配置的那一对

如果菜单里某个输入源显示：

- `未启用，可自动启用`：应用会尽量自动启用它
- `未启用`：系统不一定允许程序自动启用，可能仍需手动到系统设置里开启

## 触发规则

只有满足下面条件时才会切换：

- 单独轻点左或右 `Shift`
- 没有和其它字符键一起使用
- 没有同时按住 `Command` / `Control` / `Option`
- 按住时间不超过约 `0.3s`

这样可以避免影响：

- 输入大写字母
- 选择文本
- 常用快捷键

## 常用开发命令

编译：

```bash
swift build
```

运行：

```bash
swift run ShiftInputSwitch
```

打印当前系统输入源：

```bash
swift scripts/list-input-sources.swift
```

构建 `.app`：

```bash
bash scripts/build-app.sh release
```

## 关于签名

这个仓库默认不依赖 Apple Developer 签名证书。

当前策略是：

- 开发和自用：本地编译、本地安装
- 少量测试：让测试者自行 clone 后本地构建
- 正式分发：再补 `Developer ID` 签名和 notarization

## 后续可以继续补的能力

- 开机自启
- 首启配置向导
- 更好的冲突检测
- 自定义提示音或屏幕提示
- `.dmg` / 发布流程

