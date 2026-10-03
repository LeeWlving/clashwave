---
title: ClashWave Privacy Policy
description: Data handling and Android VPN permission disclosure for ClashWave.
---

# ClashWave Privacy Policy

**Last updated: October 3, 2026**

ClashWave is an open-source network proxy and VPN client configured by the user. This policy explains how ClashWave handles data and why it uses Android `VpnService`.

## Data handling

- ClashWave does not create user accounts, sell personal information, or upload browsing history, DNS queries, traffic content, or VPN profiles to the ClashWave developer.
- Profiles, subscription details, runtime logs, connection information, and traffic statistics are stored locally on the user's device by default.
- When the user adds a subscription URL, proxy server, or delay-test URL, the app connects to that third-party service as instructed. The provider may process IP addresses, connection metadata, and network information required to provide its service under its own privacy policy.
- The app may download Mihomo rule data or geolocation databases from sources specified by the user's configuration.
- ClashWave contains no advertising SDK and does not use VPN traffic for advertising, analytics, or monetization.

## Android VpnService

ClashWave starts `VpnService` only after the user explicitly enables it, reviews the in-app disclosure, and accepts Android's system VPN permission. It creates a local virtual network interface and passes traffic to the on-device Mihomo core for routing according to the profile selected by the user.

While the VPN is active, ClashWave displays an ongoing foreground-service notification. The user can stop the VPN at any time from the app or notification. ClashWave does not establish a VPN without user action and system consent.

## Permissions

- **Network access:** Downloads user-specified subscriptions and rule data and connects to user-selected proxy services.
- **VPN service:** Creates a device-level virtual network interface.
- **Notifications:** Shows connection status and a disconnect action while the VPN is active.
- **Foreground service:** Maintains the user-initiated VPN tunnel after the app leaves the foreground.

## Retention and deletion

ClashWave does not require an account. Users can remove subscriptions and profiles in the app or clear all locally stored data from Android's App info screen. Uninstalling the app deletes local application data stored by Android for ClashWave.

## Children's privacy

ClashWave is not directed to children and does not knowingly collect personal information from children.

## Contact

For questions about this policy or ClashWave's data handling, contact the maintainers through [GitHub Issues](https://github.com/LeeWlving/clashwave/issues).

中文版：[隐私政策](/privacy)
