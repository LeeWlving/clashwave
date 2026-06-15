# Vitepress Template

For self-use mainly.

Preview: [vitepress-template.wyf9.top](https://vitepress-template.wyf9.top)

## Quick start

[Use this template](https://github.com/new?template_name=vitepress-template&template_owner=wyf9)

```bash
pnpm install
pnpm update # Must do update before use
```

## Customize

Delete these files:

```bash
rm api-examples.md
rm markdown-examples.md
rm en_us/api-examples.md
rm en_us/markdown-examples.md
```

And edit these files:

```url
.vitepress/config.mts
index.md
en_us/index.md
README.md
```

### GitHub Pages deploy

If you need github pages deployment, simply go `Settings` -> `Pages` -> `Source`, select `GitHub Actions`, then enable the `Deploy VitePress site to Pages` workflow.

> [!IMPORTANT]
> Remember to change the `base` setting in `.vitepress/config.mts`, if you want to deploy your site to a sub path.

*If you don't need it, just remove `.github/workflows/deploy.yml` file.*

## Commands

```bash
pnpm dev # Start development server
pnpm build # Build site (.vitepress/dist/)
pnpm preview # Preview built site
```

## Credits

The Unlicense.
