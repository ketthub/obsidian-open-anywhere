# Obsidian Open Anywhere

> **在 macOS 上，双击任何 `.md` 文件都自动用 Obsidian 打开，哪怕文件不在 Vault 里。**
> 零依赖 · 一个 shell 脚本 + 一个极小的 `.app`。

[English README →](./README.md)

---

## 这工具解决什么问题

Obsidian 只能打开 Vault 里的文件。你在 Mac 上双击别处的 `.md`（下载的、其他工具导出的、代码仓库里的 README），Obsidian 完全没反应。

绕过的办法是"先手动把文件挪进 Vault，再从 Vault 里打开它"。这个工具就是把这一步在你每次双击时自动做掉。

## 工具做了什么

它在 macOS 上注册一个极小的 `.app` 作为 `.md` 文件的处理程序。双击任何 markdown 文件时：

1. **复制** 一份到 Vault 内可配置的收件箱文件夹（默认 `Inbox/`）。
2. **永不覆盖**——同名冲突自动加时间戳后缀，原文件绝对安全。
3. **打开** 复制出来的那份，走的是 `obsidian://open` URL Scheme，反向链接、图谱、插件全部正常工作。
4. **原文件保持原状**，留在原来的位置不动。

支持双击、拖拽到 app、Finder 的"打开方式"，可一次处理多个文件。

## 演示

![demo](docs/screenshots/demo.gif)

```
~/Downloads/some-paper.md   ── 双击 ──▶   Vault/Inbox/some-paper.md   ──▶   在 Obsidian 中打开
```

如果 `Inbox/some-paper.md` 已存在，新副本会变成 `some-paper-2026-06-04-1530.md`。

## 系统要求

- macOS（在 macOS 13+ 上测试，理论上一直兼容到 10.15）
- 已安装 [Obsidian](https://obsidian.md/)，至少有一个 Vault
- Python 3（现代 macOS 自带，仅用于对文件名做 URL 编码）
- 不需要 Homebrew，不需要 node，不需要任何后台守护进程

## 安装

```bash
git clone https://github.com/ketthub/obsidian-open-anywhere.git
cd obsidian-open-anywhere

# 1. 创建你自己的配置
cp config.sh.example config.sh
# 编辑 config.sh，把 VAULT_PATH 改成你 Obsidian Vault 的实际路径。

# 2. 编译并安装
./install.sh
```

`install.sh` 会自动完成：

- 把 AppleScript 编译成 `ObsidianOpenAnywhere.app`
- 把 shell 脚本和你的 config 一起打包进 .app
- 安装到 `/Applications/`
- 通过 LaunchServices 注册成 `.md` 文件的处理程序

### 设为默认打开方式（只做一次）

安装完成后，告诉 Finder 用它来打开所有 `.md`：

1. 右键任意 `.md` 文件 → **显示简介**
2. 在 **打开方式** 里选 **Obsidian Open Anywhere**
3. 点 **全部更改…**

之后双击就直接生效。

> 第一次启动可能会被 Gatekeeper 拦（"无法验证开发者"）。打开 **系统设置 → 隐私与安全性**，在底部点 **仍要打开**。只需一次。

## 配置项

所有设置都在 `config.sh` 里（从 `config.sh.example` 复制而来）：

| 变量 | 默认值 | 含义 |
|---|---|---|
| `VAULT_PATH` | *（必填）* | Obsidian Vault 根目录的绝对路径，支持 `~` |
| `VAULT_NAME` | `VAULT_PATH` 的目录名 | 在 `obsidian://` URL 里用的 vault 名。如果你在 Obsidian 里改过 vault 名字，这里要明确写 |
| `INBOX_SUBPATH` | `Inbox` | Vault 内的收件箱子目录，会自动创建 |
| `LOG_FILE` | `~/Library/Logs/obsidian-open-anywhere.log` | 日志文件路径 |
| `ALLOWED_EXTENSIONS` | `md markdown txt` | 允许处理的扩展名列表，空格分隔，全小写不带点。其他扩展名会被跳过 |
| `SHOW_NOTIFICATIONS` | `1` | 改成 `0` 静音 macOS 通知（错误仍会写日志） |

改完 `config.sh` 后需要重新运行 `./install.sh`，让新配置打包进 .app。

## 工作原理

整个工具只有两个文件：

- **`src/open-in-obsidian.sh`**：负责复制 + 调用 `obsidian://open` 的 bash 脚本
- **`src/ObsidianOpenAnywhere.applescript`**：一个二十行的 AppleScript droplet，编译成 .app 后 macOS 会把它当成可以接收文件 Open 事件的真正应用

`.app` 通过 [`lsregister`](https://eclecticlight.co/2017/12/20/lsregister-launchservices/) 注册到系统，所以会出现在 Finder 的"打开方式"菜单里。收件箱文件夹内的同名冲突用 `YYYY-MM-DD-HHMM` 时间戳后缀解决；时间戳还冲突就再加数字后缀。原文件永远不会被移动或修改。

## 卸载

```bash
./uninstall.sh
```

移除 .app 并取消注册。`config.sh`、日志文件、以及已经复制到 Vault 里的文件都不会被删。如果卸载后 `.md` 仍默认用这个 app 打开，按上面"全部更改…"那一步把目标切回 Obsidian（或别的应用）即可。

## FAQ

**Q：为什么不直接把 Obsidian 设为 `.md` 的默认打开方式？**
A：可以试试。Obsidian 完全没反应——它只打开 Vault 内的文件。

**Q：这会把我打开过的所有 markdown 都复制一份吗？**
A：会，这就是设计目的——只有文件在 Vault 内 Obsidian 才能正常索引。所有副本都集中在一个文件夹（默认 `Inbox/`），方便你后续整理或批量删除。Vault 外的原文件不会被动。

**Q：能改成移动而不是复制吗？**
A：默认不行（太容易丢东西）。如果你确定想要移动语义，把 `src/open-in-obsidian.sh` 里的 `cp -p` 改成 `mv`，然后重跑 `./install.sh`。

**Q：Linux / Windows 上能用吗？**
A：这套实现只支持 macOS（依赖 AppleScript + LaunchServices）。shell 脚本本身是可移植的，Linux 可以包装成 `.desktop` 文件（`MimeType=text/markdown`），Windows 可以用注册表 + `.bat`。欢迎 PR。

**Q：能支持多 Vault 吗？**
A：当前一次只指向一个 Vault（`config.sh` 里那个）。如果要多 Vault，需要 fork 出几份独立的 .app，每个用不同的 bundle identifier——没做成内置功能，但 fork 一份很容易改。

**Q：和 iCloud / Dropbox / Syncthing 同步会不会冲突？**
A：脚本只是 `cp` 到 Vault 文件夹里，同步工具会照常同步新文件，不会冲突。

**Q：会保留原文件的修改时间吗？**
A：会（`cp -p`）。

## 排错

- **双击没反应** → 看 `~/Library/Logs/obsidian-open-anywhere.log`。最常见的原因是 `VAULT_PATH` 指向了一个不存在的路径
- **打开了错误的 vault** → 在 `config.sh` 里显式设置 `VAULT_NAME`，名字要和 Obsidian 自己的 vault 切换器里显示的一致
- **被 Gatekeeper 拦** → 系统设置 → 隐私与安全性 → "仍要打开"，只需一次
- **"打开方式"菜单里看不到这个 app** → 重跑一遍 `./install.sh`，会强制 `lsregister -f` 刷新一次

## 贡献

欢迎 issue 和 PR。优先考虑小而聚焦的改进：更干净的 Info.plist 处理、Linux/Windows 移植、一个真正的 app 图标、把"移动而非复制"做成可选配置等。

## 协议

MIT，详见 [LICENSE](./LICENSE)。
