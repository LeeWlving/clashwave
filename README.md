# ClashWave

基于 Flutter 与 [Mihomo](https://github.com/MetaCubeX/mihomo) 的多平台代理客户端。

- 官网：[clashwave.wenyun.qzz.io](https://clashwave.wenyun.qzz.io)
- Android application ID：`org.eu.liwenyun`
- 当前版本：`2.0.0+4`
- Android 内核：Mihomo `1.19.31`

> ClashWave 不提供代理节点或订阅服务。配置文件、订阅地址及代理服务器均由用户自行选择和管理。

## 功能

- 从订阅 URL 或本地 YAML 文件导入配置
- 查看并切换 Mihomo 代理组与节点
- 延迟测试、活动连接和实时日志
- 持久化应用设置与订阅信息
- Android 系统 VPN、TUN 转发和前台服务通知
- 支持 `clash://install-config` 深链导入
- 支持 `https://clashwave.wenyun.qzz.io` Android App Links
- 桌面端系统代理、托盘和开机启动能力

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

## 平台状态

macOS 本地构建（先准备 Mihomo 双架构内核，再打包）：

```bash
sh macos/prepare_core.sh
flutter build macos --release
```

应用位于 `build/macos/Build/Products/Release/ClashWave.app`。构建会将内核放入
`Contents/MacOS/mihomo`；缺少内核时会直接终止构建，避免生成无法启动的应用。

GeoIP（MMDB / DAT）和 GeoSite 数据随应用打包，首次启动会先释放缺失的数据文件，
无需联网下载，已有数据不会被覆盖。设置中的“规则数据下载镜像”用于后续更新和
内核缺失数据时的下载，默认采用 Mihomo 文档列出的 jsDelivr 镜像。
切换订阅会保留应用的代理端口与规则数据下载地址。

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Android | 主要支持 | 已集成 Mihomo、VpnService、TUN 与 App Links |
| Windows | 支持 | 系统代理、托盘与桌面打包配置 |
| Linux | 支持 | 系统代理与 AppImage 打包配置 |
| macOS | 支持 | 桌面构建与 DMG 配置 |
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

完整的签名、VPN/前台服务申报、Data safety 和上线检查参见
[Google Play 发布清单](docs/google-play-release.md)。

## App Links

HTTPS App Links 需要在网站部署：

```text
https://clashwave.wenyun.qzz.io/.well-known/assetlinks.json
```

其中必须包含正式发布证书的 SHA-256 指纹和 application ID `org.eu.liwenyun`，否则 Android
无法自动验证该域名。自定义 `clash://` 链接无需网站验证。

## 项目结构

```text
android/                 Android VpnService、Mihomo bridge 与构建配置
lib/app/                 页面、模型、状态与 Clash-compatible API
lib/app/utils/app_json.dart
                         API 与持久化数据的显式 JSON 编解码
lib/core_control.dart    Flutter 与原生 Mihomo 的 MethodChannel
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
