# CI 发布签名配置

GitHub Actions 只从仓库 Secrets 读取签名凭据。Android 发布构建在凭据不完整时会失败。Windows 在可信签名接入前仍会生成安装包，但文件名和 Release 说明会明确标记为 `unsigned`。Pull Request 不会使用仓库 Secrets，也不会发布 Release。

## Android

ClashWave 在 Google Play 中的包名是 `org.eu.liwenyun`。CI 会强制检查上传证书的 SHA-1：

```text
89:5E:59:2D:BE:68:4F:CE:85:77:6D:3B:F3:72:39:B2:09:B0:C8:3F
```

先在本地验证 JKS，确认结果与上面的指纹完全一致：

```powershell
keytool -list -v -keystore C:\path\to\upload-keystore.jks -alias upload
```

然后在仓库的 **Settings → Secrets and variables → Actions** 中添加：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 上传密钥 JKS 文件的 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | JKS 密码 |
| `ANDROID_KEY_PASSWORD` | 私钥密码 |
| `ANDROID_KEY_ALIAS` | 私钥 alias |

PowerShell 可用以下方式生成 Base64，并直接写入 GitHub Secret：

```powershell
$value = [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\upload-keystore.jks'))
$value | gh secret set ANDROID_KEYSTORE_BASE64 --repo LeeWlving/clashwave
```

CI 会生成并验证：

- `ClashWave-android.aab`：上传 Google Play。
- `ClashWave-android.apk`：直接安装测试。

该指纹对应当前 `build/upload-keystore.jks`，并已在 Google Play 中登记为新的上传密钥。

## Windows

Windows 需要一个包含私钥且可用于 Code Signing 的 PFX。要让 Windows SmartScreen 正常识别发布者，应使用受信任 CA 签发的代码签名证书；自签名证书虽然能产生数字签名，但用户设备默认不信任。当前可先发布带 `unsigned` 标记的 Windows 构建，待 SignPath 审核通过后再接入可信签名。

添加以下 Secrets：

| Secret | 内容 |
| --- | --- |
| `WINDOWS_CERTIFICATE_BASE64` | Authenticode PFX 文件的 Base64 |
| `WINDOWS_CERTIFICATE_PASSWORD` | PFX 密码 |

配置完成后，CI 会先签名并验证应用主程序与特权服务，再生成、签名并验证：

- `ClashWave-windows-x64-portable.zip`
- `ClashWave-windows-x64-setup.exe`
- `ClashWave-windows-x64.msi`

MSI 使用 WiX Toolset 构建，具有固定 UpgradeCode，可在后续版本中执行标准升级和卸载。

未配置 Windows Secrets 时，同一批产物仍会生成，但名称会变为 `ClashWave-windows-x64-unsigned-*`，避免用户误认为它们已经过可信发布者签名。

## 触发发布

配置 Android Secrets 后，即可推送到 `master` 更新 `nightly` Release，或创建正式版本标签：

```powershell
git tag v2.0.1
git push github v2.0.1
```

不要把 JKS、PFX、密码或它们的 Base64 文本提交到仓库。
