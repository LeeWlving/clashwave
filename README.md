# ClashWave website

This branch contains the VitePress source for the public ClashWave website:

<https://leewlving.github.io/clashwave/>

The application source is maintained on the `master` branch. Pushes to `main` deploy this site through GitHub Actions.

## Local preview

```bash
pnpm install
pnpm dev
```

## Production build

```bash
pnpm install --frozen-lockfile
pnpm build
```
