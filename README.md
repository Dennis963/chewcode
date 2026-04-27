# ChewCode

ChewCode v1.1.0 是面向 GitHub Release 发布的非官方 OpenCode 移动端伴侣项目。它包含一个 Android 移动端应用和一个运行在主机侧的 HTTP Bridge，让手机可以连接到你已有的 OpenCode 运行环境。

本 README 面向公开 GitHub 仓库和 v1.1.0 发布页使用，默认读者希望直接安装 APK、安装 Debian Bridge 包、修改配置文件，然后从手机连接到本机或可信网络中的 OpenCode 工作流。

## 项目简介

ChewCode 的目标是把已有 OpenCode 工作流扩展到手机端，而不是替代 OpenCode 本身。移动端应用负责显示连接入口、会话列表和发送输入，Bridge 负责在手机端和主机侧 OpenCode 运行环境之间转发请求。

项目由三类名称组成，请在文档、包管理和源码中按场景区分：

1. `ChewCode` 是产品名称，用于 README、发布说明、移动端应用和对外介绍。
2. `chewcode_bridge` 是 Bridge 的内部、npm 和源码侧名称。
3. `chewcode-bridge` 是 Debian 包名和 systemd user service 名称，服务完整名称为 `chewcode-bridge.service`。

ChewCode v1.1.0 的发布文件只面向 GitHub Release 分发。Android APK 是侧载测试包，不是应用商店发布版本。Debian 包用于安装 Bridge 服务文件和 `chewcode_bridge` 运行所需的项目依赖，但不会安装 Node.js，也不会安装 OpenCode CLI。

## 与 OpenCode 的关系/免责声明

ChewCode 是 OpenCode 的非官方移动端和 Bridge 伴侣项目。它没有修改 OpenCode 本体，也不代表 OpenCode 上游项目。

ChewCode 未与 OpenCode 上游建立官方从属关系，未获得 OpenCode 上游赞助、背书或认可。README 中出现的 OpenCode 名称和兼容性说明，只用于描述与 OpenCode 的互操作关系。

使用 ChewCode 前，请先自行安装并配置 OpenCode CLI。ChewCode 不包含 OpenCode，不分发 OpenCode，也不替代 OpenCode 的许可、配置和安全要求。若你重新分发任何来自 OpenCode 的材料，请保留适用的 OpenCode MIT 许可证和版权声明，并避免暗示 ChewCode 是 OpenCode 官方项目。

## 发布文件

ChewCode v1.1.0 的 GitHub Release 应包含以下文件：

1. Android APK：`chewcode-v1.1.0.apk`
2. Debian Bridge 包：`chewcode-bridge_1.1.0-1_all.deb`

发布安全说明：

1. `chewcode-v1.1.0.apk` 是 Android 侧载测试文件，不声明应用商店签名、应用商店审核或应用商店发布状态。
2. `chewcode-bridge_1.1.0-1_all.deb` 用于 Debian 兼容系统上的 Bridge 安装。
3. Node.js >=22 是外部前置条件，不包含在 APK 或 deb 包中。
4. `opencode` CLI 是外部前置条件，不包含在 APK 或 deb 包中。
5. 不要手动修改发布文件后继续使用原文件名分发。如果需要自定义版本，请从源码重新构建并使用清晰的新版本标识。

## 快速开始

下面是最短安装路径。后续章节会展开每一步的细节。

1. 在将运行 Bridge 的主机上安装 Node.js >=22。
2. 在同一台主机上安装并确认可运行 `opencode` CLI。
3. 从 GitHub Release 下载 `chewcode-bridge_1.1.0-1_all.deb`。
4. 安装 Bridge deb 包。

   ```bash
   sudo apt install ./chewcode-bridge_1.1.0-1_all.deb
   ```

5. 创建用户配置目录，复制示例配置，限制权限，然后编辑配置。

   ```bash
   install -d -m 700 ~/.config/chewcode
   cp /usr/share/doc/chewcode-bridge/examples/bridge.env.example ~/.config/chewcode/bridge.env
   chmod 600 ~/.config/chewcode/bridge.env
   editor ~/.config/chewcode/bridge.env
   ```

6. 至少修改 `BRIDGE_BEARER_TOKEN` 和 `OPENCODE_BASE_URL`。如果 `node` 或 `opencode` 不在 systemd user service 能找到的 PATH 中，也要修改 `CHEWCODE_NODE_BIN` 和 `CHEWCODE_OPENCODE_BIN`。
7. 启动 Bridge 服务。

   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now chewcode-bridge.service
   systemctl --user status chewcode-bridge.service
   ```

8. 从 GitHub Release 下载 `chewcode-v1.1.0.apk`，安装到 Android 设备。
9. 在手机端填写 Bridge URL 和 `BRIDGE_BEARER_TOKEN`，连接到 Bridge。

## 安装 Android APK

`chewcode-v1.1.0.apk` 是 Android 侧载测试包。它适合公开测试和个人使用验证，不代表已经进入任何应用商店，也不声明应用商店签名状态。

安装步骤：

1. 在 Android 设备上下载或传入 `chewcode-v1.1.0.apk`。
2. 按系统提示允许当前文件管理器或浏览器安装未知来源应用。
3. 打开 APK 文件并完成安装。
4. 首次打开 ChewCode 后，进入连接设置，填写 Bridge URL 和 bearer token。

也可以通过 Android 调试工具安装：

```bash
adb install chewcode-v1.1.0.apk
```

如果系统提示已有旧版本，请先按 Android 系统提示处理旧版本。公开发布时请不要把测试 token、内部 URL 或私人路径写入截图。

## 安装 Bridge deb

Bridge 运行在 Linux 主机上，负责把手机端请求转发到同一台主机或可信网络中的 OpenCode 运行环境。

安装前置条件：

1. Debian 兼容系统，且可使用 `apt` 安装本地 deb 文件。
2. Node.js >=22 已安装，并且 Bridge 服务能找到 Node.js 可执行文件。
3. `opencode` CLI 已安装，并且 Bridge 服务能找到 `opencode` 可执行文件。
4. 已下载发布文件 `chewcode-bridge_1.1.0-1_all.deb`。

安装命令：

```bash
sudo apt install ./chewcode-bridge_1.1.0-1_all.deb
```

安装后请继续创建并修改 `~/.config/chewcode/bridge.env`。deb 包不会替你生成私人 token，也不会猜测你的 OpenCode 地址。

## 如何修改配置文件

Bridge 的用户配置文件路径固定为：

```text
~/.config/chewcode/bridge.env
```

首次安装后，从 deb 包提供的示例配置复制：

```bash
install -d -m 700 ~/.config/chewcode
cp /usr/share/doc/chewcode-bridge/examples/bridge.env.example ~/.config/chewcode/bridge.env
chmod 600 ~/.config/chewcode/bridge.env
editor ~/.config/chewcode/bridge.env
```

必须保留 `chmod 600` 这一步，因为配置文件中会保存 `BRIDGE_BEARER_TOKEN`。这个 token 相当于手机访问 Bridge 的口令，不能公开到 issue、日志、截图或聊天记录里。

一个安全的本机测试配置示例：

```bash
CHEWCODE_NODE_BIN=node
CHEWCODE_OPENCODE_BIN=opencode
HOST=127.0.0.1
PORT=8091
OPENCODE_BASE_URL=http://127.0.0.1:4096
BRIDGE_BEARER_TOKEN=<replace-with-a-strong-random-token>
PROJECT_ALLOWED_ROOTS=${HOME}/code
PROJECT_REGISTRY_FILE=${HOME}/.local/state/chewcode/projects-registry.json
```

请把 `<replace-with-a-strong-random-token>` 换成足够长、随机、不可猜测的字符串。不要直接使用示例值。`OPENCODE_BASE_URL` 要指向你的 OpenCode 运行环境。若 OpenCode 与 Bridge 在同一台主机上运行，通常可以先使用 `127.0.0.1` 地址进行本机测试。

修改配置后，重启服务让新配置生效：

```bash
systemctl --user restart chewcode-bridge.service
systemctl --user status chewcode-bridge.service
```

## 配置项说明

`CHEWCODE_NODE_BIN`

: Node.js 可执行文件。默认可以写 `node`。如果 systemd user service 找不到 Node.js，请改成你的 Node.js 可执行文件路径。Node.js 必须是 >=22，且由用户自行安装。

`CHEWCODE_OPENCODE_BIN`

: OpenCode CLI 可执行文件。默认可以写 `opencode`。OpenCode CLI 是外部前置条件，ChewCode 不会安装或打包它。

`HOST`

: Bridge 监听地址。安全默认值建议使用 `127.0.0.1`，这表示只允许本机访问。若手机需要通过局域网直接访问 Bridge，可以改为可信网络中的主机地址或明确的监听地址，但必须配合强 token 和防火墙限制。

`PORT`

: Bridge 监听端口。示例使用 `8091`。手机端填写 Bridge URL 时需要使用同一个端口。

`OPENCODE_BASE_URL`

: Bridge 访问 OpenCode 运行环境的基础 URL。示例为 `http://127.0.0.1:4096`。请根据你的 OpenCode 启动方式修改它。手机端不直接访问这个地址，手机端只访问 Bridge URL。

`BRIDGE_BEARER_TOKEN`

: 手机端连接 Bridge 时使用的 bearer token。必须替换为强随机值。任何知道 Bridge URL 和这个 token 的客户端都可能访问 Bridge 暴露的能力，所以请妥善保存。

`PROJECT_ALLOWED_ROOTS`

: 允许 Bridge 暴露给手机端的项目根目录。示例使用 `${HOME}/code`。只填写你确实希望从手机端访问的目录，不要填过大的范围。

`PROJECT_REGISTRY_FILE`

: 项目注册表 JSON 文件路径。示例使用 `${HOME}/.local/state/chewcode/projects-registry.json`。这个文件用于保存或读取项目列表相关数据，请把它放在用户私有状态目录中。

## 启动/停止/查看日志

ChewCode Bridge 使用 systemd user service 运行，服务名称是 `chewcode-bridge.service`。

重新加载用户服务配置：

```bash
systemctl --user daemon-reload
```

启动并设置为用户服务自动启动：

```bash
systemctl --user enable --now chewcode-bridge.service
```

查看状态：

```bash
systemctl --user status chewcode-bridge.service
```

重启服务：

```bash
systemctl --user restart chewcode-bridge.service
```

停止服务：

```bash
systemctl --user stop chewcode-bridge.service
```

查看实时日志：

```bash
journalctl --user -u chewcode-bridge.service -f
```

排查问题时，先确认 Node.js >=22 和 `opencode` CLI 可以被服务找到，再检查 `~/.config/chewcode/bridge.env` 中的 `OPENCODE_BASE_URL`、`HOST`、`PORT` 和 `BRIDGE_BEARER_TOKEN`。

## 手机端连接方式

手机端需要填写两个核心信息：

1. Bridge URL
2. 与 `~/.config/chewcode/bridge.env` 中一致的 `BRIDGE_BEARER_TOKEN`

常见连接方式：

1. 本机或 USB 调试测试

   如果 Bridge 只监听 `localhost`，Android 设备不能直接通过局域网访问主机的 localhost。使用 USB 调试时，可以先建立端口转发：

   ```bash
   adb reverse tcp:8091 tcp:8091
   ```

   然后在手机端填写：

   ```text
   http://127.0.0.1:8091
   ```

2. 可信局域网连接

   如果手机和 Bridge 主机在同一个可信网络中，可以让 Bridge 监听可信局域网地址，并在手机端填写：

   ```text
   http://<bridge-host-lan-ip>:8091
   ```

   这里的 `<bridge-host-lan-ip>` 是 Bridge 主机在该网络中的地址。不要把 Bridge 直接暴露到公共互联网。若必须跨网络访问，请使用可信 VPN 或可信反向代理，并继续启用强 bearer token。

3. 本机浏览器或同主机测试

   如果客户端和 Bridge 在同一台主机上，可以使用：

   ```text
   http://localhost:8091
   ```

连接失败时，请检查四件事：Bridge 服务是否正在运行，手机端 URL 是否指向 Bridge 而不是 OpenCode，token 是否完全一致，主机防火墙是否允许对应端口在可信网络中访问。

## 从源码构建

从源码构建适合开发者或需要自定义发布文件的用户。普通安装建议直接使用 GitHub Release 中的 `chewcode-v1.1.0.apk` 和 `chewcode-bridge_1.1.0-1_all.deb`。

构建移动端 APK：

```bash
cd apps/mobile
flutter pub get
flutter build apk --release
```

构建 Bridge 和 Debian 包：

```bash
cd services/bridge
npm ci
npm run build
npm run package:deb
```

源码、内部包名和 npm 相关命名使用 `chewcode_bridge`。Debian 安装包、服务名和系统管理命令使用 `chewcode-bridge`。

从源码构建不会改变外部前置条件：运行 Bridge 的主机仍需要用户自行安装 Node.js >=22 和 OpenCode CLI。

## 已实现功能

ChewCode v1.1.0 已实现以下能力：

1. Android 移动端应用，可配置 Bridge URL 和 bearer token。
2. 通过 Bridge 向 OpenCode 运行环境提交手机端输入。
3. 支持连续发送输入，便于在当前移动端上下文中继续工作。
4. 支持 `/compact` 相关路径，将压缩或总结请求按专门流程处理，而不是当作普通提示词提交。
5. 会话列表行为与桌面 OpenCode 的 root、directory、archive、limit 过滤思路保持一致。
6. 主机侧 HTTP Bridge，用于隔离手机端请求和 OpenCode 运行边界。
7. Bridge 的 Debian `.deb` 打包，包名和服务名使用 `chewcode-bridge`。

## 待实现功能/限制

ChewCode v1.1.0 仍有以下限制：

1. 它是移动端伴侣工具，不是完整的 OpenCode 桌面或 TUI 替代品。
2. 移动端交互能力仍以发送输入和查看基础信息为主，更完整的交互控制还需要继续验证。
3. 当前 APK 只声明为侧载测试文件，不声明应用商店发布、应用商店审核或应用商店签名状态。
4. Bridge 的跨发行版安装验证仍有限，v1.1.0 主要面向 Debian 兼容环境。
5. 更丰富的实时视图、回放、差异查看和高级项目管理仍属于后续工作。
6. 安全边界依赖用户正确配置监听地址、token、项目根目录和网络访问策略。

## 安全注意事项

请在使用 ChewCode 前理解以下安全边界：

1. `~/.config/chewcode/bridge.env` 包含 `BRIDGE_BEARER_TOKEN`，权限应保持为 `600`。
2. `BRIDGE_BEARER_TOKEN` 必须替换为强随机值，不要复用公开示例或短口令。
3. 默认建议让 Bridge 监听 `localhost`。如果需要手机通过网络访问，请只在可信网络、可信 VPN 或可信反向代理后使用。
4. 不要把 Bridge 直接暴露到公共互联网。
5. `PROJECT_ALLOWED_ROOTS` 只应包含确实需要从手机端访问的项目目录。
6. 分享 issue、日志或截图前，请移除 token、Bridge URL、项目路径、注册表路径和任何私人信息。
7. Node.js 和 OpenCode CLI 由用户自行安装和维护，请及时跟进它们各自的安全更新。

## 目录结构

主要源码目录：

```text
apps/mobile
  ChewCode Flutter Android 移动端应用

packages/opencode_remote
  共享 Dart 模型和 Bridge 客户端代码

services/bridge
  ChewCode Bridge 源码，内部、npm 和源码侧名称为 chewcode_bridge
```

发布命名对应关系：

1. 产品名称：`ChewCode`
2. Android 发布文件：`chewcode-v1.1.0.apk`
3. Bridge 源码和内部名称：`chewcode_bridge`
4. Debian 包名：`chewcode-bridge`
5. Debian 发布文件：`chewcode-bridge_1.1.0-1_all.deb`
6. systemd user service：`chewcode-bridge.service`

## 许可证

ChewCode 使用 MIT License 发布。请查看仓库中的许可证文件以获取完整条款。

OpenCode 名称、兼容性描述和相关引用仅用于说明互操作关系。ChewCode 不声明自己是 OpenCode 官方项目，也不声明获得 OpenCode 上游赞助、背书或认可。若你分发任何 OpenCode 相关材料，请保留适用的 OpenCode MIT 许可证和版权声明。
