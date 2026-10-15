#!/usr/bin/env node
// Full-page screenshot matrix: every URL x width x engine.
// Usage: node shoot.mjs <urls.txt> <outdir> [--engines chromium,webkit] [--widths 1440,390x844]
// urls.txt: one absolute URL per line. Phones (width < 768) use isMobile + DPR 3.
// Also records per-page overflow, console errors and failed requests to <outdir>/report.json.
import { chromium, webkit } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const [urlsFile, outDir, ...rest] = process.argv.slice(2);
if (!urlsFile || !outDir) { console.error('usage: node shoot.mjs <urls.txt> <outdir> [--engines ..] [--widths ..]'); process.exit(1); }
const opt = (k, d) => { const i = rest.indexOf(k); return i >= 0 ? rest[i + 1] : d; };
const engines = opt('--engines', 'chromium,webkit').split(',');
const widths = opt('--widths', '1920,1440,1280,1024,768,390x844,360x780').split(',').map((w) => {
  const [W, H] = w.split('x').map(Number); return { w: W, h: H || 900 };
});
const urls = fs.readFileSync(urlsFile, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
fs.mkdirSync(outDir, { recursive: true });
const slug = (u) => new URL(u).pathname.replace(/^\/|\/$/g, '').replace(/\//g, '_') || 'root';
const report = [];

for (const name of engines) {
  const browser = await ({ chromium, webkit })[name].launch();
  for (const { w, h } of widths) {
    const phone = w < 768;
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: phone ? 3 : 1, isMobile: phone, reducedMotion: 'reduce' });
    const page = await ctx.newPage();
    for (const url of urls) {
      const errors = []; const failed = [];
      page.removeAllListeners('console'); page.removeAllListeners('requestfailed');
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('requestfailed', (r) => failed.push(r.url()));
      let status = 0;
      try { const res = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 }); status = res?.status() ?? 0; }
      catch (e) { errors.push(String(e)); }
      // scroll to settle lazy images and reveals
      await page.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 500) { window.scrollTo(0, y); await new Promise((r) => setTimeout(r, 60)); } window.scrollTo(0, 0); });
      await page.waitForTimeout(400);
      const m = await page.evaluate(() => ({
        overflow: document.documentElement.scrollWidth - window.innerWidth,
        broken: [...document.images].filter((i) => i.complete && i.naturalWidth === 0).map((i) => i.currentSrc || i.src),
        height: document.documentElement.scrollHeight,
      }));
      const file = path.join(outDir, `${name}-${w}-${slug(url)}.jpg`);
      await page.screenshot({ path: file, fullPage: true, type: 'jpeg', quality: 60 });
      report.push({ engine: name, width: w, url, status, ...m, errors, failed, file });
      const flag = m.overflow > 0 || m.broken.length || errors.length || failed.length ? ' !' : '';
      console.log(`${name} ${w} ${status} ${url}${flag}`);
    }
    await ctx.close();
  }
  await browser.close();
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify(report, null, 2));
const bad = report.filter((r) => r.overflow > 0 || r.broken.length || r.errors.length || r.failed.length);
console.log(`\n${report.length} loads, ${bad.length} flagged. See ${path.join(outDir, 'report.json')}`);
