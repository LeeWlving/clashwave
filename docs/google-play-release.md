# Google Play 发布清单

## 1. 应用身份

- 应用名称：ClashWave
- Android application ID：`org.eu.liwenyun`
- 官网：`https://leewlving.github.io/clashwave/`
- 隐私政策：`https://leewlving.github.io/clashwave/privacy`
- 当前版本：`2.0.0 (4)`

首次上传后不要再修改 application ID。后续每次发布必须增加 `versionCode`。

## 2. 创建并保存上传密钥

在项目外或安全备份位置创建上传密钥：

```powershell
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

复制 `android/key.properties.example` 为 `android/key.properties`，填写真实密码和
密钥路径。`key.properties`、JKS 和 keystore 已被 Git 忽略。建议启用 Google
Play App Signing，并离线备份上传密钥。

## 3. 构建 AAB

```powershell
$env:HTTP_PROXY="http://127.0.0.1:7897"
$env:HTTPS_PROXY="http://127.0.0.1:7897"
$env:NO_PROXY="127.0.0.1,localhost"
flutter clean
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build appbundle --release
```

产物位于 `build/app/outputs/bundle/release/app-release.aab`。发布版本必须使用上传
密钥签名；不要把调试签名或未签名的 AAB 上传到 Play Console。

如果 Maven Central 在国内网络把大文件重定向到 GitHub 后超时，可先执行以下
等价的 Gradle 构建来启用项目自带镜像配置：

```powershell
cd android
.\gradlew.bat app:bundleRelease --init-script gradle/init-mirrors.gradle
```

## 4. Play Console 申报

- 在“应用内容”中如实声明使用 VPN 服务，并说明核心用途是用户配置的网络
  代理/VPN；应用不会出售或以广告用途利用流量数据。
- 前台服务类型为 `specialUse`，用途说明是“保持用户主动启用的 VPN 隧道持续
  运行，并显示不可隐藏的前台通知”。
- 在商店资料和应用内清楚披露 VPN 功能；在首次建立 VPN 前由 Android 系统弹窗
  获取用户授权。
- 根据实际运营情况填写 Data safety。当前代码不向 ClashWave 运营者上传个人数据，
  但用户选择的订阅、代理及测试服务器属于第三方端点。
- 将 `PRIVACY_POLICY.md` 发布到上述隐私政策网址，并在 Play Console 填写公开可
  访问的 HTTPS 链接。
- GPL 组件随 APK/AAB 分发；发布时同时提供对应源代码和构建说明，并保留
  `THIRD_PARTY_NOTICES.md` 中的版权和许可信息。

## 5. 上线前验证

- 在至少一台 Android 8、Android 13 和 Android 15+ 设备上验证 VPN 授权、连接、
  断开、重启和订阅导入。
- 使用 Play Console 内部测试轨道验证从 Play 安装的拆分 APK。
- 检查通知权限被拒绝时 VPN 前台服务的行为。
- 在 16 KB 页大小设备或 Play 预发布报告中检查原生库兼容性。
