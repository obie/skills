#!/usr/bin/env node
// Forbidden-token sweep over rendered HTML: visible text AND every attribute,
// meta tags, JSON-LD and raw text endpoints (llms.txt, /api/*.json).
// Usage: node sweep.mjs <urls.txt> <rules.json>
// rules.json: { "forbidden": ["regex", ...], "allow": ["exact phrase allowed despite a match", ...] }
// Example forbidden: internal ids "\\b[A-Z]\\d{1,3}[a-z]?\\b", "--profile", vendor names,
// and lyric lines (in every language) that may not appear in written copy.
import fs from 'node:fs';

const [urlsFile, rulesFile] = process.argv.slice(2);
if (!urlsFile || !rulesFile) { console.error('usage: node sweep.mjs <urls.txt> <rules.json>'); process.exit(1); }
const rules = JSON.parse(fs.readFileSync(rulesFile, 'utf8'));
const forbidden = rules.forbidden.map((s) => new RegExp(s, 'giu'));
const allow = (rules.allow || []).map((s) => s.toLowerCase());
const urls = fs.readFileSync(urlsFile, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
let hits = 0;

const decode = (s) => s.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');

for (const url of urls) {
  const res = await fetch(url);
  let body = await res.text();
  // ignore hashed asset filenames, which produce random false positives
  body = body.replace(/\/_astro\/[^"'\s)]+/g, '').replace(/\/_next\/[^"'\s)]+/g, '');
  // sweep everything (aria-hidden markup included); hits inside it are tagged HIDDEN below
  const text = decode(body);
  for (const re of forbidden) {
    re.lastIndex = 0;
    for (const m of text.matchAll(re)) {
      const ctx = text.slice(Math.max(0, m.index - 60), m.index + m[0].length + 60).replace(/\s+/g, ' ');
      if (allow.some((a) => ctx.toLowerCase().includes(a))) continue;
      const inHidden = /aria-hidden="true"[^>]*>[^<]*$/.test(text.slice(Math.max(0, m.index - 300), m.index));
      hits++;
      console.log(`${inHidden ? 'HIDDEN ' : ''}${url}\n   /${re.source}/ → …${ctx}…`);
    }
  }
}
console.log(hits ? `\n${hits} hits (review each; HIDDEN = inside aria-hidden markup)` : '\nclean');
process.exit(hits ? 1 : 0);
