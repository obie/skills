#!/usr/bin/env node
// Parse every JSON-LD block on every URL; report parse failures, types and sameAs.
// Usage: node jsonld.mjs <urls.txt> [--expect-sameas https://a,https://b]
import fs from 'node:fs';

const [urlsFile, ...rest] = process.argv.slice(2);
if (!urlsFile) { console.error('usage: node jsonld.mjs <urls.txt> [--expect-sameas a,b]'); process.exit(1); }
const i = rest.indexOf('--expect-sameas');
const expect = i >= 0 ? rest[i + 1].split(',').sort() : null;
const urls = fs.readFileSync(urlsFile, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
let failures = 0; const types = {};

for (const url of urls) {
  const html = await (await fetch(url)).text();
  const blocks = [...html.matchAll(/<script[^>]+type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
  if (!blocks.length) { failures++; console.log(`NONE  ${url}`); continue; }
  for (const b of blocks) {
    let data;
    try { data = JSON.parse(b); } catch (e) { failures++; console.log(`PARSE ${url}: ${e.message}`); continue; }
    const nodes = Array.isArray(data) ? data : data['@graph'] || [data];
    for (const n of nodes) {
      const t = [].concat(n['@type'] || 'unknown').join('|'); types[t] = (types[t] || 0) + 1;
      if (expect && n.sameAs) {
        const got = [].concat(n.sameAs).sort();
        if (JSON.stringify(got) !== JSON.stringify(expect)) { failures++; console.log(`SAMEAS ${url}: ${got.join(', ')}`); }
      }
    }
  }
}
console.log('\nnode types:', types);
console.log(failures ? `${failures} problems across ${urls.length} pages` : `all ${urls.length} pages parse`);
process.exit(failures ? 1 : 0);
