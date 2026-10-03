---
title: ClashWave 隐私政策
description: ClashWave 的数据处理与 Android VPN 权限说明。
---

# ClashWave 隐私政策

**更新日期：2026 年 10 月 3 日**

ClashWave 是一款由用户自行配置的开源网络代理与 VPN 客户端。本政策说明 ClashWave 如何处理数据，以及 Android `VpnService` 的用途。

## 数据处理

- ClashWave 不创建用户账号，不出售个人信息，也不会向 ClashWave 开发者上传浏览历史、DNS 查询、流量内容或 VPN 配置。
- 配置、订阅信息、运行日志、连接信息和流量统计默认保存在用户设备本地。
- 当用户添加订阅地址、代理服务器或延迟测试地址时，应用会按用户指示连接这些第三方服务。相应服务可能依据其自己的隐私政策处理 IP 地址、连接元数据和提供服务所必需的网络信息。
- 应用可能按照用户配置下载 Mihomo 规则数据或地理数据库。这些请求会发送到配置中指定的下载服务。
- ClashWave 不包含广告 SDK，不使用 VPN 流量进行广告投放、分析或获利。

## Android VpnService

ClashWave 仅在用户明确点击启用、阅读应用内披露并接受 Android 系统 VPN 授权后启动 `VpnService`。该权限用于在设备本地创建虚拟网络接口，并将流量交给本地 Mihomo 内核，按照用户选择的配置路由。

VPN 启用期间，ClashWave 会显示持续的前台服务通知。用户可以随时从应用或通知中停止 VPN。ClashWave 不会在未经用户操作和系统授权的情况下建立 VPN。

## 权限

- **网络访问**：下载用户指定的订阅和规则数据，并连接用户选择的代理服务。
- **VPN 服务**：创建设备级虚拟网络接口。
- **通知**：在 VPN 活动期间显示连接状态和断开操作。
- **前台服务**：在用户离开应用界面后维持已主动启用的 VPN 通道。

## 数据保留与删除

ClashWave 不要求账号。用户可以在应用内删除订阅和配置，也可以通过 Android 的应用信息页面清除全部本地数据。卸载应用会删除 Android 为 ClashWave 保存的本地应用数据。

## 儿童隐私

ClashWave 不以儿童为目标用户，也不会有意收集儿童的个人信息。

## 联系方式

如对本政策或 ClashWave 的数据处理有疑问，请通过 [GitHub Issues](https://github.com/LeeWlving/clashwave/issues) 联系项目维护者。

English version: [Privacy Policy](/en_us/privacy)
