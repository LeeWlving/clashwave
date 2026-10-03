---
layout: home

hero:
  name: "ClashWave"
  text: "Connect quietly to the world"
  tagline: "A cross-platform VPN and proxy client powered by Flutter and Mihomo. Your profiles, subscriptions, and connections remain under your control."
  image:
    src: /logo.svg
    alt: ClashWave cat and wave logo
  actions:
    - theme: brand
      text: View source
      link: https://github.com/LeeWlving/clashwave
    - theme: alt
      text: Privacy policy
      link: /en_us/privacy
    - theme: alt
      text: Support
      link: /en_us/support

features:
  - title: User-controlled profiles
    details: Import a subscription URL or local YAML file. ClashWave does not provide, sell, or host proxy nodes.
  - title: Device-level VPN
    details: Android uses VpnService for a user-initiated VPN tunnel and shows an ongoing foreground-service notification.
  - title: Modern Mihomo core
    details: Rule-based routing, proxy groups, delay tests, active connections, subscription updates, and network recovery.
  - title: Cross-platform experience
    details: A consistent ClashWave interface and status controls for Android, Windows, macOS, and Linux.
---

## What is ClashWave?

ClashWave is an open-source Mihomo client. It processes network connections according to profiles explicitly imported and selected by the user, providing rule-based routing, proxy-group management, and a device-level VPN.

ClashWave does not create user accounts, provide proxy nodes or subscriptions, or manipulate network traffic for advertising or monetization. Profiles, subscription details, logs, and traffic statistics are stored locally on the user's device by default.

## Android VPN usage

On Android, ClashWave starts `VpnService` only after the user taps Start, reviews the in-app disclosure, and approves Android's system VPN permission. The service creates a local virtual network interface and sends traffic to the on-device Mihomo core for routing under the selected profile.

An ongoing notification is displayed while the VPN is active. The user can disconnect at any time from the app or notification. ClashWave does not use `VpnService` for advertising, user tracking, or unsolicited data collection.

## Project information

- Android application ID: `org.eu.liwenyun`
- Source code: [github.com/LeeWlving/clashwave](https://github.com/LeeWlving/clashwave)
- Releases: [GitHub Releases](https://github.com/LeeWlving/clashwave/releases)
- Privacy policy: [Read online](/en_us/privacy)
- Support: [GitHub Issues](https://github.com/LeeWlving/clashwave/issues)

> Use only subscription and proxy services that you trust. Third-party providers process information required to establish a connection under their own privacy practices.
