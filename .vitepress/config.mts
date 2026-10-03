import { defineConfig } from "vitepress";

const repository = "https://github.com/LeeWlving/clashwave";

export default defineConfig({
  base: "/clashwave/",
  cleanUrls: true,
  srcExclude: ["README.md"],
  lastUpdated: true,
  title: "ClashWave",
  description: "A user-controlled, cross-platform Mihomo VPN and proxy client.",
  head: [
    ["link", { rel: "icon", href: "/clashwave/logo.svg", type: "image/svg+xml" }],
    ["meta", { name: "theme-color", content: "#176B78" }],
    ["meta", { property: "og:site_name", content: "ClashWave" }],
  ],
  sitemap: {
    hostname: "https://leewlving.github.io/clashwave/",
  },
  locales: {
    root: {
      label: "简体中文",
      lang: "zh-CN",
      title: "ClashWave",
      description: "由用户自主配置的跨平台 Mihomo VPN 与代理客户端。",
    },
    en_us: {
      label: "English",
      lang: "en-US",
      link: "/en_us/",
      title: "ClashWave",
      description: "A user-controlled, cross-platform Mihomo VPN and proxy client.",
      themeConfig: {
        nav: [
          { text: "Home", link: "/en_us/" },
          { text: "Privacy", link: "/en_us/privacy" },
          { text: "Support", link: "/en_us/support" },
          { text: "Source", link: repository },
        ],
        editLink: {
          pattern: `${repository}/edit/main/:path`,
          text: "Edit this page on GitHub",
        },
        lastUpdated: {
          text: "Last updated",
          formatOptions: { dateStyle: "long", timeStyle: "short" },
        },
        footer: {
          message: "ClashWave does not provide proxy nodes or subscription services.",
          copyright: "Released under the GPL-3.0 license.",
        },
      },
    },
  },
  themeConfig: {
    logo: "/logo.svg",
    siteTitle: "ClashWave",
    nav: [
      { text: "首页", link: "/" },
      { text: "隐私政策", link: "/privacy" },
      { text: "支持", link: "/support" },
      { text: "源代码", link: repository },
    ],
    socialLinks: [{ icon: "github", link: repository }],
    search: { provider: "local" },
    editLink: {
      pattern: `${repository}/edit/main/:path`,
      text: "在 GitHub 上编辑此页",
    },
    lastUpdated: {
      text: "最后更新",
      formatOptions: { dateStyle: "long", timeStyle: "short" },
    },
    footer: {
      message: "ClashWave 不提供代理节点或订阅服务。",
      copyright: "Released under the GPL-3.0 license.",
    },
  },
  markdown: {
    image: { lazyLoading: true },
  },
});
