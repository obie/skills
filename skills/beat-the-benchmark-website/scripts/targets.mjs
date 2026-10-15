#!/usr/bin/env node
// Tap-target size and above-the-fold check for selectors at phone sizes.
// Usage: node targets.mjs <url> "<css selector>" [--fold] [--min 44] [--open "<selector to click first>"]
// Example: node targets.mjs https://example.com/es/ ".hero a, .hero button" --fold
//          node targets.mjs https://example.com/es/ ".menu .social a" --open ".menu-button" --fold
import { chromium, webkit } from 'playwright';

const [url, selector, ...rest] = process.argv.slice(2);
if (!url || !selector) { console.error('usage: node targets.mjs <url> "<selector>" [--fold] [--min 44] [--open "<selector>"]'); process.exit(1); }
const has = (k) => rest.includes(k);
const opt = (k, d) => { const i = rest.indexOf(k); return i >= 0 ? rest[i + 1] : d; };
const min = Number(opt('--min', '44'));
const open = opt('--open', null);
const sizes = [{ w: 390, h: 844 }, { w: 375, h: 667 }, { w: 360, h: 780 }];
let fails = 0;

for (const [name, type] of [['chromium', chromium], ['webkit', webkit]]) {
  const browser = await type.launch();
  for (const s of sizes) {
    const ctx = await browser.newContext({ viewport: { width: s.w, height: s.h }, deviceScaleFactor: 3, isMobile: true, hasTouch: true });
    const page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'networkidle' });
    if (open) { await page.click(open); await page.waitForTimeout(600); }
    const boxes = await page.$$eval(selector, (els) => els.filter((e) => e.offsetParent !== null).map((e) => {
      const r = e.getBoundingClientRect();
      return { label: (e.getAttribute('aria-label') || e.textContent || '').trim().slice(0, 30), w: r.width, h: r.height, right: r.right, bottom: r.bottom };
    }));
    for (const b of boxes) {
      const small = b.w < min || b.h < min;
      const below = has('--fold') && b.bottom > s.h;
      const edge = b.right > s.w - 8;
      if (small || below || edge) {
        fails++;
        console.log(`${name} ${s.w}x${s.h} "${b.label}" ${b.w.toFixed(0)}x${b.h.toFixed(0)}${small ? ' SMALL' : ''}${below ? ' BELOW-FOLD' : ''}${edge ? ' AT-EDGE' : ''}`);
      }
    }
    if (!boxes.length) { fails++; console.log(`${name} ${s.w}x${s.h}: no visible matches for ${selector}`); }
    await ctx.close();
  }
  await browser.close();
}
console.log(fails ? `\n${fails} problems` : '\nall targets pass');
process.exit(fails ? 1 : 0);
