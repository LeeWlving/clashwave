# ClashWave

基于 Flutter 与 [Mihomo](https://github.com/MetaCubeX/mihomo) 的多平台代理客户端。

- 官网：[leewlving.github.io/clashwave](https://leewlving.github.io/clashwave/)
- 源码：[github.com/LeeWlving/clashwave](https://github.com/LeeWlving/clashwave)
- Android application ID：`org.eu.liwenyun`
- 当前版本：`2.0.1+5`
- Android 内核：Mihomo `1.19.31`

> ClashWave 不提供代理节点或订阅服务。配置文件、订阅地址及代理服务器均由用户自行选择和管理。

## 功能

- 从订阅 URL 或本地 YAML 文件导入配置，下载后校验并原子替换
- 可配置订阅 User-Agent，支持重复检测、定时更新及失败回滚
- 查看并切换 Mihomo 代理组与节点
- 延迟测试、活动连接和实时日志
- 持久化应用设置与订阅信息
- Android 系统 VPN、快捷设置磁贴、Always-on VPN、网络切换恢复和前台服务通知
- 支持 `clash://install-config` 深链导入
- 桌面端系统代理、状态托盘，以及普通权限 GUI 与 Windows SCM/macOS LaunchDaemon 特权内核服务

## macOS 菜单栏使用

默认启动时仅显示菜单栏图标并运行内核，仪表板页面在点击“打开仪表板”时才加载。
关闭仪表板后继续代理，并释放仪表板页面及其数据订阅。再次打开 App 不会自动弹出仪表板。
“设置 → 启动时打开仪表板”可改变启动偏好，临时打开界面不改变此设置。

代理组直接列在菜单主层，按配置顺序显示；选择组支持切换节点，自动组显示当前节点，
负载均衡组不标记单一当前节点。各组提供延迟测试，可开启按延迟排序；全局模式显示 GLOBAL。
“订阅 / 配置”可导入本地 YAML 或 URL、切换、更新、重命名、修改更新间隔、移除配置。
文件导入使用系统文件选择器，订阅输入和错误提示使用 macOS 原生对话框，无需打开仪表板。
菜单还提供系统代理、TUN、规则/全局/直连、局域网连接、日志等级、菜单栏网速、代理命令、
关闭连接、配置目录和内核重启。登录时启动使用系统登录项 API（macOS 13 及以上）。

## 技术栈

| 组件 | 版本或说明 |
| --- | --- |
| Flutter | 3.47.5 |
| Dart | 3.13.4 |
| Android | compile/target SDK 36、Java 17、AGP 9.1.0 |
| Android NDK | 29.0.14033849 |
| Mihomo | 1.19.31 |
| Android bridge | `libmihomo-android` 0.3.5 |
| Android ABI | `arm64-v8a`、`armeabi-v7a`、`x86_64` |

Android 端通过 `VpnService` 获取系统 VPN 授权，将 TUN 文件描述符交给 Mihomo 处理；
应用界面通过 Mihomo 提供的 Clash-compatible REST API 管理配置、代理、连接和日志。
桌面端默认以普通权限启动 Mihomo；首次开启 TUN 或在设置中安装内核服务时才请求系统管理员
授权。Windows 使用 `ClashWaveCore` SCM 服务，macOS 使用
`io.qzz.wenyun.clashwave-core` LaunchDaemon，界面本身始终保持普通权限。GUI 与内核通过只监听
`127.0.0.1` 的 REST/WebSocket 控制端通信，端口和 256-bit 随机令牌持久化在用户应用数据目录，
REST 使用 Bearer 鉴权，WebSocket 使用 token 鉴权。设置页可显式安装或卸载服务。
为避免高权限服务引用可被普通用户替换的二进制，Windows 必须先用安装包装入 `Program Files`，
macOS 必须先把 `ClashWave.app` 移入 `/Applications`，便携目录中不会允许注册系统服务。

## 平台状态

macOS 本地构建（先准备 Mihomo 双架构内核，再打包）：

```bash
sh macos/prepare_core.sh
flutter build macos --release
```

应用位于 `build/macos/Build/Products/Release/ClashWave.app`。构建会将内核放入
`Contents/MacOS/mihomo`；缺少内核时会直接终止构建，避免生成无法启动的应用。

构建完成后可生成 DMG 安装镜像：

```bash
bash scripts/create-macos-dmg.sh 2.0.1
```

输出为 `dist/ClashWave-2.0.1-macos-universal.dmg`。打开镜像后，将 `ClashWave.app`
拖入 `Applications` 即可安装。打包脚本会校验镜像，并挂载检查应用、Mihomo 内核与安装入口。

Linux 构建前先准备对应架构的 Mihomo：

```bash
sh linux/prepare_core.sh
flutter build linux --release
```

GeoIP（MMDB / DAT）和 GeoSite 数据随应用打包，首次启动会先释放缺失的数据文件，
无需联网下载，已有数据不会被覆盖。设置中的“规则数据下载镜像”用于后续更新和
内核缺失数据时的下载，默认采用 Mihomo 文档列出的 jsDelivr 镜像。
切换订阅会保留应用的代理端口与规则数据下载地址。

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Android | 主要支持 | 已集成 Mihomo、VpnService、TUN 与 App Links |
| Windows | 支持 | 系统代理、状态托盘、SCM 特权内核服务与安装包 |
| Linux | 支持 | 系统代理、pkexec 按需提权与 AppImage 配置 |
| macOS | 支持 | 系统代理、LaunchDaemon 特权内核服务与 DMG 配置 |
| iOS | 实验性 | 工程配置已迁移，发布前仍需在真实设备验证 |

## 开发环境

安装 Flutter 3.47.5，并确保 `flutter doctor` 中目标平台所需工具可用。Android 构建需要：

- Android SDK 36
- JDK 17
- Android NDK 29.0.14033849

在需要本地代理的 Windows PowerShell 中执行：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:7897"
$env:HTTPS_PROXY="http://127.0.0.1:7897"
$env:NO_PROXY="127.0.0.1,localhost"

flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter run
```

项目已为 Android Gradle 配置国内镜像。网络受限时可直接执行：

```powershell
cd android
.\gradlew.bat app:bundleRelease --init-script gradle/init-mirrors.gradle
```

## Android 发布

Google Play 使用 Android App Bundle。首次构建正式包之前，请先创建自己的上传密钥：

```powershell
keytool -genkeypair -v `
  -keystore upload-keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

复制 `android/key.properties.example` 为 `android/key.properties`，填写密钥路径及密码，然后执行：

```powershell
flutter build appbundle --release
```

AAB 输出位置：

```text
build/app/outputs/bundle/release/app-release.aab
```

`android/key.properties`、JKS/keystore、`build/`、`.dart_tool/` 及本地迁移目录均已加入
`.gitignore`，不得提交到版本库。

GitHub Actions 使用以下加密变量。密钥内容必须是 JKS/PFX 文件的 Base64，不要把任何密码
或密钥文件提交到仓库：

| 变量 | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 上传密钥 JKS 的 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_KEY_ALIAS` | key alias |
| `WINDOWS_CERTIFICATE_BASE64` | Windows Authenticode PFX 的 Base64（GitHub） |
| `WINDOWS_CERTIFICATE_PASSWORD` | PFX 密码（GitHub） |

GitHub 的源码流水线监听 `master`、面向 `master` 的 Pull Request 以及 `v*` tag。普通分支
构建会运行静态分析和测试，并生成 Android AAB、Windows 安装包/便携包、macOS 通用 DMG 和
Linux x64 便携包。全部平台成功后统一汇总产物，并生成 `SHA256SUMS.txt`。

- `master` 推送或在 `master` 上手动运行：自动创建或更新 GitHub Releases 中的 `nightly`
  开发版，下载地址保持不变。开发版可能没有 Android/Windows 正式签名，macOS 尚未公证。
- Pull Request：只构建并上传 Actions artifacts，不发布 Release。
- `v*` tag：发布对应正式版；Android 与 Windows 缺少对应签名变量时会直接失败。

Actions artifacts 与 GitHub Releases 是两个不同的下载入口。没有推送 `v*` 标签时，旧流程
只会生成 artifacts，不会创建 Release。新流程的开发版入口为
[nightly Release](https://github.com/LeeWlving/clashwave/releases/tag/nightly)。所有平台均固定
Flutter 版本，Mihomo 下载文件会先校验 SHA-256 再参与构建。

完整的签名、VPN/前台服务申报、Data safety 和上线检查参见
[Google Play 发布清单](docs/google-play-release.md)。

## 深链导入

Android 支持 `clash://install-config` 自定义深链导入。项目型 GitHub Pages 无法在
`leewlving.github.io` 主机根目录部署 Android App Links 所需的 `/.well-known/assetlinks.json`，
因此当前版本不声明未经验证的 HTTPS App Link。

## 项目结构

```text
android/                 Android VpnService、Mihomo bridge 与构建配置
.github/workflows/       GitHub 检查及 Android/Windows/macOS/Linux 发布
lib/app/                 页面、模型、状态与 Clash-compatible API
lib/app/utils/app_json.dart
                         API 与持久化数据的显式 JSON 编解码
lib/core_control.dart    移动端 MethodChannel 与桌面内核权限/生命周期控制
docs/                    使用说明与 Google Play 发布文档
test/                    配置及 JSON 兼容测试
```

## 隐私与开源许可

- 隐私政策：[PRIVACY_POLICY.md](PRIVACY_POLICY.md)
- 第三方许可：[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

Mihomo 与 Android bridge 使用 GPL-3.0 许可证。分发 APK/AAB 时，发布者需要同时履行 GPL
规定的源码、许可证和构建信息提供义务。仓库中集成的 AAR 版本及 SHA-256 已记录在第三方许可文件中。

## 截图

| 主页 | 代理节点 |
| --- | --- |
| ![主页](docs/images/home_page.png) | ![代理节点](docs/images/proxy_page.png) |

| 订阅 | 活动连接 |
| --- | --- |
| ![订阅](docs/images/profile_page.png) | ![活动连接](docs/images/connect_page.png) |

## 致谢

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)
- [oviron/libmihomo-android](https://github.com/oviron/libmihomo-android)
- [Flutter](https://flutter.dev)
