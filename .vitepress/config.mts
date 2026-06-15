import { defineConfig } from "vitepress";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Vitepress 模板",
  description: "一个 VitePress 站点",
  // base: "/", // always ends with slash
  cleanUrls: true,
  head: [
    ["link", { rel: "icon", href: "https://icons.siiway.org/siiway/icon.svg" }],
  ],
  lastUpdated: true,
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [{ text: "主页", link: "/" }],

    sidebar: {
      ["/"]: [
        { text: "回到主页", link: "/" },
        {
          text: "示例文档",
          items: [
            { text: "Markdown 示例", link: "/markdown-examples" },
            { text: "API 示例", link: "/api-examples" },
          ],
        },
        { text: "外链示例", link: "https://not-exist.wss.moe/outlink-zh" },
      ],
      ["/en_us/"]: [
        { text: "Back to homepage", link: "/en_us/" },
        {
          text: "Example docs",
          items: [
            { text: "Markdown Examples", link: "/en_us/markdown-examples" },
            { text: "API Examples", link: "/en_us/api-examples" },
          ],
        },
        { text: "Outlink Test", link: "https://not-exist.wss.moe/outlink-en" },
      ],
    },

    socialLinks: [
      { icon: "github", link: "https://github.com/vuejs/vitepress" },
      { icon: "qq", link: "https://not-exist.wss.moe/qq" },
      { icon: "discord", link: "https://not-exist.wss.moe/discord" },
    ],

    editLink: {
      pattern: "https://github.com/wyf9/vitepress-template/edit/main/:path",
      text: "在 GitHub 上编辑本页",
    },

    lastUpdated: {
      text: "最后更新于",
      formatOptions: {
        dateStyle: "full",
        timeStyle: "full",
      },
    },
  },

  locales: {
    root: {
      label: "简体中文",
      lang: "zh",
    },
    en_us: {
      label: "English",
      lang: "en",
      link: "/en_us/",

      title: "Vitepress Template",
      description: "A VitePress Site",

      themeConfig: {
        nav: [{ text: "Home", link: "/en_us/" }],

        socialLinks: [
          { icon: "github", link: "https://github.com/vuejs/vitepress" },
          { icon: "discord", link: "https://not-exist.wss.moe/discord" },
        ],

        editLink: {
          pattern: "https://github.com/wyf9/vitepress-template/edit/main/:path",
          text: "Edit this page on GitHub",
        },

        lastUpdated: {
          text: "Last updated at",
          formatOptions: {
            dateStyle: "full",
            timeStyle: "full",
          },
        },
      },
    },
  },
  markdown: {
    image: {
      lazyLoading: true,
    },
  },
});
