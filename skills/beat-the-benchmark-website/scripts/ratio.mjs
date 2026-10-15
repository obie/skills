#!/usr/bin/env node
// Decoded-file upscale ratio for every rendered <img>.
// ratio = (rendered CSS px x DPR) / (width of the candidate the browser actually decoded)
// > 1.15 means visibly soft (upscaled). < 1 means oversampled, which is fine.
// Usage: node ratio.mjs <urls.txt> [--engine chromium|webkit] [--limit 1.15]
import { chromium, webkit } from 'playwright';
import fs from 'node:fs';

const [urlsFile, ...rest] = process.argv.slice(2);
if (!urlsFile) { console.error('usage: node ratio.mjs <urls.txt> [--engine chromium] [--limit 1.15]'); process.exit(1); }
const opt = (k, d) => { const i = rest.indexOf(k); return i >= 0 ? rest[i + 1] : d; };
const engine = opt('--engine', 'chromium');
const limit = Number(opt('--limit', '1.15'));
const configs = [{ w: 1920, h: 1080, dpr: 2 }, { w: 1440, h: 900, dpr: 2 }, { w: 1440, h: 900, dpr: 1 }, { w: 768, h: 1024, dpr: 2 }, { w: 390, h: 844, dpr: 3 }, { w: 360, h: 780, dpr: 3 }];
const urls = fs.readFileSync(urlsFile, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
const browser = await ({ chromium, webkit })[engine].launch();
let worst = { r: 0 }; let fails = 0; let total = 0;

for (const c of configs) {
  const ctx = await browser.newContext({ viewport: { width: c.w, height: c.h }, deviceScaleFactor: c.dpr, isMobile: c.w < 768 });
  const page = await ctx.newPage();
  for (const url of urls) {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
    await page.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 400) { window.scrollTo(0, y); await new Promise((r) => setTimeout(r, 80)); } });
    await page.waitForTimeout(500);
    const rows = await page.evaluate(async () => {
      const out = [];
      for (const img of document.images) {
        const r = img.getBoundingClientRect();
        if (r.width < 40 || !img.currentSrc || !img.complete || !img.naturalWidth) continue;
        // decode the actual chosen file to learn its true pixel width
        const probe = new Image(); probe.src = img.currentSrc;
        try { await probe.decode(); } catch { continue; }
        // object-fit: cover draws the image larger than its box on one axis
        const fit = getComputedStyle(img).objectFit;
        let drawnW = r.width;
        if (fit === 'cover') drawnW = Math.max(r.width, r.height * (probe.naturalWidth / probe.naturalHeight));
        out.push({ src: img.currentSrc.split('/').pop(), drawnW, srcW: probe.naturalWidth });
      }
      return out;
    });
    for (const row of rows) {
      total++;
      const ratio = (row.drawnW * c.dpr) / row.srcW;
      if (ratio > worst.r) worst = { r: ratio, url, c: `${c.w}@${c.dpr}`, src: row.src };
      if (ratio > limit) { fails++; console.log(`SOFT ${ratio.toFixed(2)}x  ${c.w}@${c.dpr}  ${url}  ${row.src}`); }
    }
  }
  await ctx.close();
}
await browser.close();
console.log(`\n${total} image renders, ${fails} over ${limit}x. Worst ${worst.r.toFixed(3)}x at ${worst.c} ${worst.url ?? ''} ${worst.src ?? ''}`);
process.exit(fails ? 1 : 0);
