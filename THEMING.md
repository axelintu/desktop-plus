# Themed builds (fork notes)

This fork builds upstream [Desktop Plus](https://github.com/desktop-plus/desktop-plus)
releases with a custom dark palette. Default: **Tokyo Night Storm**.

## What's added

| File | Purpose |
| --- | --- |
| `app/styles/themes/palettes/_*.scss` | Palettes. Plain CSS overrides of the dark theme's variables. |
| `app/styles/themes/_palette.scss` | Which palette gets compiled in (managed by the script). |
| `app/styles/desktop.scss` | One added line: `@import 'themes/palette';` |
| `script/desktop-theme.sh` | Palette switcher. |
| `.github/workflows/themed-build.yml` | Daily: builds new upstream releases and publishes them here. |

Palettes only apply when **Settings > Appearance > Theme** is **Dark**
(or System on a dark desktop).

## Installing

Grab the `.deb` (or AppImage) from this fork's
[Releases](../../releases) and install it:

```sh
sudo apt install ./desktop-plus_*_amd64.deb
```

If you previously added the official Desktop Plus apt repository, remove
`/etc/apt/sources.list.d/desktop-plus.list`. Otherwise `apt upgrade` will
replace this build with the stock one.

## Switching palettes

On an installed copy (no rebuild; restart the app afterwards):

```sh
tar xzf desktop-theme.tar.gz            # from the release assets
desktop-theme/desktop-theme.sh list
desktop-theme/desktop-theme.sh installed stock
desktop-theme/desktop-theme.sh installed tokyo-night-storm
```

This also works on the official package (it appends the palette to the app's
`renderer.css`), but package updates overwrite that file, so re-run it after
updating.

For the builds this fork publishes, set a repository variable named
`THEME_PALETTE` (Settings > Secrets and variables > Actions > Variables), or
run the workflow by hand and type a palette name.

## Adding a palette

1. Copy `app/styles/themes/palettes/_tokyo-night-storm.scss` to, for example,
   `_one-dark.scss`.
2. Change the colors. Keep it plain CSS, with no Sass functions, so the switcher
   can inject it as-is.
3. Commit, then run **Themed Linux build** from the Actions tab with
   `palette: one-dark`.

## Building locally

```sh
script/desktop-theme.sh source tokyo-night-storm
corepack enable && yarn && yarn build:prod && yarn package   # output in dist/
```
