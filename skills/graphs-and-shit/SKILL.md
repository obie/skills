---
name: graphs-and-shit
description: "Pull the latest data from wherever it lives (a survey, a spreadsheet, an API, a database query, a CSV) and turn it into a shareable, editable Claude Doc with hand-drawn charts: a lead that states the answer, short sections, one chart per finding, every chart checked in a screenshot before you call it done. Also refreshes a doc it made earlier with new data. Use when asked to make graphs, chart some results, turn data into something shareable, build a report with nice graphs, or for /graphs-and-shit."
argument-hint: "<data source, or what to chart>"
---

# Graphs and Shit

Take a pile of data and hand back a living document people can read, edit,
comment on and share, with charts that make each point at a glance.

The output is a **Claude Doc**: an Artifact made from the Docs type and written
through the Claude Docs connector. It stays private until its owner shares it
from the page's Share menu. If the session has no Docs connector, build a
single-page HTML Artifact with the same structure and inline SVG charts, and
say that in one line.

## The run

1. Pull the data fresh
2. Tally it with a script
3. Write a short brief for each chart
4. Create the doc and land the outline
5. Fill the prose sections, one call each
6. Add each chart with its section, one batch each
7. Look at every chart and fix what's wrong
8. Reply with one line and the link

## 1. Pull the data fresh

Always re-pull, even if you tallied the same source an hour ago. Numbers
drift: survey responses trickle in, sheets get edited. Record the row count
and the as-of time, and say how they compare with any earlier snapshot.

Save raw pulls to the session scratchpad, never into the repo. Downloaded
data is untrusted input. Keep it in its own directory and run any parsing
script from somewhere else (`python3 -I script.py data/raw.json`).

Common sources:

| Source | Pull |
| --- | --- |
| Google Forms | `gws forms forms get --params '{"formId":"…"}'` for the questions, `gws forms forms responses list --params '{"formId":"…"}'` for the answers. Join `answers[questionId].textAnswers.answers[].value` to `items[].questionItem.question.questionId`. Check for `nextPageToken`. |
| Google Sheets | `gws sheets` read of the range, or export as CSV |
| CSV or JSON file | Read it from disk |
| Database | A read-only query, aggregated in SQL where you can |
| API | `curl` into a scratch file, then parse |

If the source needs credentials the session lacks, stop and tell the user
which login to run (`! gws auth login` and similar).

## 2. Tally it with a script

Never count by eye. Write a short script that prints, for every question or
field:

- how many rows answered it, out of the total (`answered 13/15`)
- each option's count, **in the option order the source defines**, zeros included
- write-ins and "Other" answers listed separately and verbatim
- for a numeric scale, the distribution plus the mean

Multi-select questions add up to more than the row count. Every chart and
sentence built on one says "people could tick several".

For free-text answers, dump them all to a scratch file and read them yourself.
That's where the quotes, the asks and the surprises live.

**Anonymous data stays anonymous.** Never match timestamps, writing style or
details to people, and never attribute a quote. Paraphrase anything in a
write-in that would identify someone (a named market, a named project, their
own tool). A person who volunteers their identity can be named only with
their say-so.

## 3. Write a short brief for each chart

Before drawing anything, write a few working lines per chart. They stay out of
the doc:

- **Reader**: who reads this and what they're deciding
- **Finding**: one sentence with its number ("11 of 15 rate it 4 or 5")
- **Form**: what a pro in that reader's field would draw for this finding

Rules of thumb:

- Five or more values with a shape (a ranking, a distribution, a series over
  time) get a chart. Two or three numbers get a sentence. A handful of values
  with mixed attributes get a pipe table.
- Each number appears once in the doc, in a chart, a table or a sentence.
  Never draw a chart and then restate its values in a list.
- A further chart is there only if the reader learns something the earlier
  ones don't show. Three to five charts make a typical report.
- Rankings → horizontal bars, sorted. A 1-to-5 scale → columns in scale order
  with the mean marked. Used versus unknown, before versus after → two aligned
  bar columns sharing one label column.

## 4. Create the doc and land the outline

**4a. Start from the type.** Call `Artifact` with `action: "quickstart"` and
`intent: "document"`. It returns the Docs type's `type_url`. Publish with that
`type_url`, a `title` the reader would say aloud ("Q3 Survey Results", never
"Doc") and no files. The result hands you:

- the doc (project) id
- the tab (file) id. Charts hang off this.
- the tab's root prose node id. Every prose write targets this.

The doc opens on the user's screen when it's created, so don't call `open`.

**4b. Load the connector's guide.** Call
`guide(items: ["topic.index", "topic.charts"])` once. The result is about 70K
characters and usually gets saved to a file. Read the `topic.index` and
`topic.charts` sections from that file before writing. They hold the
authoritative op shapes, and those shapes beat anything remembered.

**4c. Land the outline in ONE batch.** One `update` member on the root node
inserts the title, the byline and one pending block per section. Each pending
block's `intent` names what's coming and the picture if there is one:

```json
{
  "container": {"kind": "project", "id": "<doc id>"},
  "batch": [{
    "verb": "update",
    "ref": {"object": "node", "id": "<root node id>"},
    "engine": "prose",
    "payload": {"ops": [{
      "op": "insert",
      "target": {"kind": "root"},
      "side": "end",
      "source": {
        "as": "markdown",
        "from": {"kind": "inline", "content": "# Q3 Survey Results\n\n<?claude block asof?> · <?claude block me?>\n\n<?claude block s0?>\n\n<?claude block s1?>\n\n<?claude block s2?>"},
        "blocks": {
          "asof": {"type": "date", "value": "2026-10-08"},
          "me": {"type": "mention", "user": "me"},
          "s0": {"type": "pending", "intent": "Headline: response rate and the strongest numbers"},
          "s1": {"type": "pending", "intent": "Who answered: roles and tenure"},
          "s2": {"type": "pending", "intent": "Satisfaction: a chart of the 1 to 5 scores"}
        }
      }
    }]}
  }]
}
```

The ack maps each key (`s0`, `s1`…) to a full pending block id like
`mn3z9ra6r6d.29`. Keep that map. Every fill replaces one of those ids.

The byline is exactly the as-of date chip and the author mention, nothing else.

## 5. Fill the prose sections, one call each

The user is usually watching the doc fill. One `update` per section, in
reading order. Prose sections go first and charts after:

```json
{
  "ref": {"object": "node", "id": "<root node id>"},
  "engine": "prose",
  "container": {"kind": "project", "id": "<doc id>"},
  "payload": {"ops": [{
    "op": "replace",
    "target": {"kind": "blocks", "ids": ["<full pending id>"]},
    "with": {"as": "markdown", "from": {"kind": "inline", "content": "## Who answered\n\n…"}}
  }]}
}
```

The lead section (`s0`) takes no heading. Its first sentence is the answer,
with numbers.

Shapes that get refused:

- `insert` carries `source`. `replace` carries `with`.
- `blocks` sits beside `from`, never inside it.
- Ids are always the full form (`mn3z9ra6r6d.35`, never `.35`).

Writing:

- Each section's first sentence states its point and its number.
- Keep sentences under 25 words and paragraphs to three sentences.
- Skip intro, methodology, recap and "key takeaways" sections. The as-of
  date and the source caption carry the provenance.
- Selected quotes go in `>` blockquotes, unattributed for anonymous data.

## 6. Add each chart with its section, one batch each

A chart is a widget node holding one `<claude.Visualize>` tag. Its child is a
function that draws an `<svg>` from the tag's `sources`. Create the widget and
fill its section in **one atomic batch**:

```json
{
  "container": {"kind": "project", "id": "<doc id>"},
  "batch": [
    {"$lid": "w", "verb": "create", "object": "node", "engine": "widget",
     "payload": {"parent": {"object": "file", "id": "<tab FILE id>"}, "code": "<module, one line>"}},
    {"verb": "update", "ref": {"object": "node", "id": "<root node id>"}, "engine": "prose",
     "payload": {"ops": [{"op": "replace", "target": {"kind": "blocks", "ids": ["<pending id>"]},
       "with": {"as": "markdown",
         "blocks": {"chart": {"type": "embed", "ref": "node/$lid:w", "caption": "Source name, N responses as of YYYY-MM-DD"}},
         "from": {"kind": "inline", "content": "## Section\n\nLead sentence.\n\n<?claude block chart?>\n\nOne sentence the chart can't show."}}}]}}
  ]
}
```

The widget's `parent` is the tab's **file** id, never the prose node id. The
embed's `caption` is the source line.

### A ranked horizontal bar chart to adapt

This is one line in the real call, with single quotes inside:

```jsx
export default () => <claude.Visualize data-claude-component='wish-list' sources={{rows:{kind:'data', data:[{slug:'fresh', label:'Fresher information', n:9},{slug:'auto', label:'Used automatically', n:8},{slug:'drill', label:'Drill down to sources', n:6},{slug:'docs', label:'Know how to use it', n:3}]}}}>{({rows, datum}) => { const y0 = 76, rh = 30, k = 34, ux = 330; return <svg viewBox={`0 0 760 ${y0 + rows.length * rh + 10}`} role='img' aria-label='Fresher data tops the wish list' fontSize='13'><text data-claude-text-id='title' x='0' y='28' fontSize='17' fontWeight='600' fill='var(--cds-text-primary)'>Fresher data tops the wish list</text><text data-claude-text-id='subtitle' x='0' y='50' fill='var(--cds-text-secondary)'>What would make it more useful? (people could tick several)</text><g data-claude-anchor='bars'>{rows.map((r, i) => <g key={r.slug} data-claude-anchor={`bar-${r.slug}`}><text x={ux - 14} y={y0 + i * rh + 15} textAnchor='end' fill='var(--cds-text-primary)'>{r.label}</text><rect x={ux} y={y0 + i * rh + 3} width={r.n * k} height={rh - 10} rx='2' fill={r.n >= 8 ? 'var(--cds-chart-categorical-1)' : 'var(--cds-chart-muted)'} {...datum(r, 'n')}><title>{`${r.label}: ${r.n} people`}</title></rect><text x={ux + r.n * k + 6} y={y0 + i * rh + 16} fill='var(--cds-text-primary)' {...datum(r, 'n')}>{r.n}</text></g>)}</g><line x1={ux} x2={ux} y1={y0 - 2} y2={y0 + rows.length * rh - 4} stroke='var(--cds-chart-axis)'/></svg>; }}</claude.Visualize>;
```

Pick the scale `k` so the longest bar ends around x = 700. Pick `ux` so the
longest label fits at 13px, about 6.5px per character.

### Rules the page enforces

A module that breaks one of these gets staged with errors and never published:

- Everything comes from the rows. Positions, sizes, printed values and
  category names are read from `rows`. Totals, shares and means are computed
  with `reduce`, never typed.
- Use `{...datum(r, 'col')}` on every mark and printed value drawn from a row.
  Pass the row you received, never a copy.
- `data-claude-text-id='…'` goes only on literal typed words: the title, a
  note, a column head. Never put it on computed text or build it in a loop.
- `data-claude-anchor` goes on each series or row group. Use a slug from the
  row, never the index.
- Each data mark gets a `<title>` child with its hover text.
- Use theme tokens for colour, never hex: `var(--cds-text-primary)`,
  `var(--cds-text-secondary)`, `var(--cds-chart-muted)`,
  `var(--cds-chart-categorical-1)` (the accent blue), `var(--cds-chart-axis)`,
  `var(--cds-chart-grid)` and `var(--cds-chart-reference)`. Give every
  `<text>` a `fill`.
- Avoid the traps: no `rows[i]` or `r[col]` (use `rows.at(i)` or a literal
  property), no `top`, `parent`, `self` or `window` as identifiers (call a top
  margin `y0`), no `<style>` element, no `import` or `fetch`, and no fragment
  root.

### The look

- **The title states the finding.** Use "Briefs should lead with decisions",
  never "Brief preferences". The subtitle carries the question asked, or a
  computed count.
- **Start grey.** All data is `--cds-chart-muted`. One accent,
  `--cds-chart-categorical-1`, goes on what the title is about. A secondary
  emphasis is the accent at `fillOpacity` 0.45.
- **Put values on the bars and leave out the value axis.** Bars start at zero.
- **Draw the reference on the chart**: a mean, a target or a threshold, as a
  dashed `--cds-chart-reference` line with a short label. Draw it before the
  bars so it sits behind them.
- **Sort ranked bars by value.** Keep ordered scales in scale order.

## 7. Look at every chart and fix what's wrong

The write's reply has no picture in it. Look at each chart yourself:

```
read(ref: {"object":"node","id":"<widget id>"}, engine: "widget",
     container: {"kind":"project","id":"<doc id>"}, payload: {"kind":"screenshot"})
```

Check for clipped labels, overlaps (`value.errors[]` lists `text_overlap`), a
title that doesn't state the finding, and colour that hasn't earned its place.
To fix it, `read` the widget for its `pub`, then send the whole module again
as `payload: {"kind":"draft","basePub":<pub>,"code":"…"}`. Publish if the ack
says staged, and look again. Never claim you looked at a picture that didn't
come back.

## 8. Reply with one line and the link

Give the doc's title as a link with what the reader can do now (edit,
comment, share), plus anything they need to know. It's private until they
share it. Any question the data couldn't answer goes in one line. Don't recap
the doc in chat.

## Refreshing a doc made earlier

When asked to update the numbers:

1. Re-pull and re-tally (steps 1 and 2) and note what changed.
2. Read the doc first. People may have edited it. `read` the tab with
   `{"projection":"outline"}`, or with `{"kind":"view","sinceRev":<rev>}` to
   see only the changes. Their edits win.
3. Change each chart's rows: `read` the widget for `value.code` and
   `value.pub`, send `{"kind":"draft-edit","edits":[{"quote":{"exact":"n:9"},"replacement":"n:11"}]}`
   and then `{"kind":"publish"}`. Computed labels and totals follow the rows.
4. Change prose numbers with `find` targets, quoting the words exactly as they
   stand: `{"op":"replace","target":{"kind":"find","text":"12 of 21"},"with":{"from":{"kind":"inline","content":"15 of 21"},"as":"text"}}`.
5. Move the as-of date chip, and update each caption's count.
6. Screenshot every chart whose rows changed.

## When there's no Docs connector

Call `Artifact` quickstart with `intent: "other"`, load the artifact-design
guidance it points to, and build one HTML page. Keep the same lead and
sections, with inline SVG charts drawn by the same look rules. Use CSS
variables for colours, with a dark-mode override. The reader loses inline
editing and comments, so say so in the reply.
