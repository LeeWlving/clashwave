---
layout: home

hero:
  name: "ClashWave"
  text: "安静地连接世界"
  tagline: "基于 Flutter 与 Mihomo 的跨平台 VPN 与代理客户端。配置、订阅和连接始终由你掌控。"
  image:
    src: /logo.svg
    alt: ClashWave 猫猫与波浪标志
  actions:
    - theme: brand
      text: 查看源代码
      link: https://github.com/LeeWlving/clashwave
    - theme: alt
      text: 隐私政策
      link: /privacy
    - theme: alt
      text: 获取支持
      link: /support

features:
  - title: 用户自主配置
    details: 从订阅 URL 或本地 YAML 导入配置。ClashWave 不提供、出售或托管代理节点。
  - title: 设备级 VPN
    details: Android 使用系统 VpnService 建立由用户主动启用的 VPN 通道，并持续显示前台服务通知。
  - title: 现代 Mihomo 内核
    details: 支持规则分流、代理组、延迟测试、活动连接、订阅更新和网络切换恢复。
  - title: 多平台体验
    details: 面向 Android、Windows、macOS 与 Linux，提供统一的 ClashWave 界面与状态控制。
---

## ClashWave 是什么？

ClashWave 是一款开源的 Mihomo 客户端。它根据用户导入并选择的配置处理网络连接，适合需要规则分流、代理组管理和设备级 VPN 的用户。

ClashWave 不创建用户账号，不提供代理节点或订阅服务，也不会为了广告或获利目的操纵网络流量。配置文件、订阅信息、日志和流量统计默认保存在用户设备本地。

## Android VPN 用途

在 Android 上，ClashWave 仅在用户点击“开始接管”、阅读应用内说明并批准 Android 系统 VPN 权限后启动 `VpnService`。该服务创建本地虚拟网络接口，并将流量交给设备上的 Mihomo 内核，按照用户选择的配置进行路由。

VPN 运行时会显示持续通知，用户可以随时从应用或通知中断开连接。ClashWave 不将 `VpnService` 用于广告、用户跟踪或未经请求的数据收集。

## 项目信息

- Android application ID：`org.eu.liwenyun`
- 源代码：[github.com/LeeWlving/clashwave](https://github.com/LeeWlving/clashwave)
- 发布版本：[GitHub Releases](https://github.com/LeeWlving/clashwave/releases)
- 隐私政策：[公开阅读](/privacy)
- 问题反馈：[GitHub Issues](https://github.com/LeeWlving/clashwave/issues)

> 请只使用你信任的订阅和代理服务。第三方订阅或代理服务会依据其自己的隐私政策处理提供连接所必需的信息。
