# Scripts

Setup, in a scratch directory (not the site repo):

```bash
npm init -y && npm i playwright@1.60.0 && npx playwright install chromium webkit
```

Pin 1.60.0: newer Playwright WebKit builds fail on some macOS versions.
Run the scripts from that directory (`node /path/to/shoot.mjs …`), or set
`NODE_PATH` to its `node_modules`.

| Script | What it answers | Exit code |
|---|---|---|
| `shoot.mjs urls.txt out/` | What does every page look like at every width in both engines? Any overflow, broken images, console errors, failed requests? | always 0; read `report.json` |
| `ratio.mjs urls.txt` | Is any image upscaled past 1.15× on any screen? | 1 if any image is soft |
| `targets.mjs url "sel" --fold` | Are these tap targets ≥44px, on screen, and clear of the edge on phones? | 1 on any failure |
| `sweep.mjs urls.txt rules.json` | Do forbidden tokens appear in text or attributes? | 1 on any hit |
| `jsonld.mjs urls.txt` | Does structured data parse everywhere, with the right `sameAs`? | 1 on any failure |
| `parity.sh prod verified paths…` | Is production byte-identical to the build that passed review? | 1 if not |

Build `urls.txt` from the sitemap:

```bash
curl -s https://<preview>/sitemap.xml | grep -o '<loc>[^<]*' | sed 's/<loc>//' \
  | sed 's#https://<prod-domain>#https://<preview-host>#' > urls.txt
```

Tile full-page shots into montages to read them yourself:

```bash
magick shot.jpg -resize 600x -crop 600x1500 +repage +append -resize x1500 montage.jpg
```
