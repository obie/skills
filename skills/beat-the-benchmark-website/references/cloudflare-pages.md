# Cloudflare Pages: previews, ship, gotchas

## Deploy flow

```bash
# preview only, for review
cd site && npm run build && \
CLOUDFLARE_ACCOUNT_ID=<id> npx wrangler@4 pages deploy dist \
  --project-name <project> --branch preview --commit-dirty=true
# -> https://<hash>.<project>.pages.dev  (immutable; review THIS)
# -> https://preview.<project>.pages.dev (alias; moves; don't review this)

# ship the exact verified dist
CLOUDFLARE_ACCOUNT_ID=<id> npx wrangler@4 pages deploy dist \
  --project-name <project> --branch main --commit-dirty=true
scripts/parity.sh https://<domain> https://<hash>.<project>.pages.dev /es/ /en/ ...
```

Before shipping, confirm local `dist` is byte-identical to the verified
preview for a few pages; a stray rebuild in between invalidates the review.

## Gotchas

- **No `account_id` in a Pages `wrangler.toml`.** Pages config validation
  rejects it. Pass `CLOUDFLARE_ACCOUNT_ID` in the environment, especially
  when wrangler sees several accounts.
- **Wrangler OAuth can't edit DNS.** Apex custom domains need a proxied
  CNAME `@` → `<project>.pages.dev`. Remove registrar parking A/CNAME
  records first. The owner (or a token with DNS edit) has to do it.
- **Managed robots.txt.** Cloudflare's AI Crawl Control "Bot Preference
  Sync" prepends a Content-Signal block that Lighthouse marks invalid (SEO
  92) and blocks AI crawlers. Turn it off if the site wants agents.
- **Stale removed pages.** A page removed from the build may keep serving
  from cache for days, and a zone purge may not clear it. Add `_redirects`
  rules (`/old/* /new/ 301`) for retired URLs.
- **Pages limits.** 20,000 files and 25 MiB per file per deployment. Image
  pipelines that emit many widths × formats × locales get close; count
  `dist` before deploying and drop JPEG fallbacks if WebP/AVIF suffice.
- **Video in Pages Functions + R2.** Safari needs HTTP 206 range responses;
  `wrangler pages dev` doesn't serve ranges for static mp4s, so test video
  in WebKit on a real preview, not locally. Prefer YouTube for full films
  (privacy-enhanced, click-to-load facade) and keep short silent loops small
  enough to ship as static files with immutable cache headers.
- **Local servers die.** `wrangler pages dev` processes get killed by other
  agents. For QC, always use deployed immutable previews.
- **Other sessions deploy too.** Check production and `git log` before
  every deploy; never assume you are the only writer.
