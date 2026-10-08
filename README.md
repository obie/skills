# Claude Code Skills by Obie

Production-ready skills for enhanced Claude Code development workflows.

## Installation

Add this marketplace to your Claude Code:

```shell
/plugin marketplace add obie/skills
```

Then install individual skills:

```shell
/plugin install better-stimulus@obie-skills
```

## Available Skills

### Better Stimulus

Apply opinionated best practices from [betterstimulus.com](https://betterstimulus.com/) when writing or refactoring Stimulus controllers.

**When to use:**
- Writing new Stimulus controllers
- Refactoring existing Stimulus code
- Reviewing Stimulus controller architecture
- Debugging inter-controller communication

**Key patterns:**
- Values API for reactive state management
- Static classes for configurable CSS
- Single Responsibility Principle
- Minimal connect() usage
- Declarative event registration

**Invoke with:** `/better-stimulus` or Claude invokes automatically when working with Stimulus code

### MCP OAuth Setup

Implement zero-configuration OAuth for MCP (Model Context Protocol) server connections using Dynamic Client Registration (RFC 7591) and Authorization Server Metadata Discovery (RFC 8414). Battle-tested with Linear, Sentry, and Granola.

**When to use:**
- Building admin UIs for managing MCP server connections with OAuth
- Integrating with third-party MCP providers
- Implementing MCP Streamable HTTP transport with authenticated tool sync
- Adding OAuth to an existing MCP connector management system

**What it covers:**
- RFC 8414 metadata discovery + RFC 7591 dynamic client registration
- PKCE (S256) authorization flow with signed state
- Token exchange, storage, and refresh (shared + per-agent modes)
- MCP Streamable HTTP tool sync (session handshake, SSE parsing)
- UI patterns (Stimulus forms, Connect vs Sync logic)
- Common failure modes and fixes (Turbo Drive, route helpers, SSE)

**Invoke with:** `/mcp-oauth-setup` or Claude invokes automatically when implementing MCP OAuth

### Deletion Test

Run the deletion test from Chad Fowler's *Regenerative Software* on one component: could we delete this and rebuild it from what the system holds outside the code? Extracts intent and decision records from code, history, and tickets; writes a durable contract spec that asserts promises rather than pinned numbers; mutation-tests both oracles; deletes the implementation and regenerates it in isolated arms from the intent alone; scores every candidate by behavioral diff; reports what the code knew that nothing else did.

**When to use:**
- Making a component safely replaceable, or finding out whether it already is
- Extracting the reasons buried in a legacy module's comments, commits, and tickets
- Checking whether a test suite is an oracle or a museum of the current implementation
- Establishing a baseline before adopting regeneration tooling

**What it covers:**
- Intent document and decision-record formats, with the sparse variant for a decisions-withheld arm
- Durable contract specs: properties over grids, the language-change membership test, degenerate inputs
- mutant two-pass scoring with a survivor classification table
- Isolated regeneration arms in git worktrees with a regenerator brief
- Behavioral-diff scoring scripts and a findings template
- Optional survivor triage with a calibrated decision model (feelings / Jev)

**Invoke with:** `/deletion-test` or Claude invokes automatically when asked to regenerate a module from spec or make a component replaceable

### Graphs and Shit

Pull the latest data from wherever it lives and turn it into a shareable, editable Claude Doc with hand-drawn charts. The lead states the answer with its numbers. Each section gets one chart for one finding, and every chart is checked in a screenshot before the doc is called done. Run it again later and it refreshes the same doc with new numbers.

**When to use:**
- Survey results that need to go in front of a team
- A spreadsheet or query result that people will discuss and comment on
- Numbers that keep changing, such as responses trickling in, where the doc should be refreshed rather than rebuilt

**What it covers:**
- Pulling fresh data (Google Forms, Sheets, CSV, a database, an API) and tallying it with a script
- A short brief per chart: the reader, the finding, the form a pro would draw
- Creating the doc from the Docs Artifact type and landing an outline the reader can watch fill
- Hand-rolled `claude.Visualize` charts: grey first, one accent, values on the marks, everything computed from rows
- Screenshot review and redraws
- Keeping anonymous data anonymous
- Refreshing chart rows and prose numbers without clobbering people's edits

Requires the Artifact tool and the Claude Docs connector. Without the connector it falls back to a single HTML Artifact.

**Invoke with:** `/graphs-and-shit <data source>` or Claude invokes automatically when asked to chart results into something shareable

## How It Works

Skills are stored in `skills/<skill-name>/SKILL.md` format. Each skill:
- Contains YAML frontmatter describing when to use it
- Includes comprehensive instructions for Claude
- May reference supporting documentation files
- Can be invoked manually with `/skill-name` or automatically by Claude

## Contributing

Want to add your own skills to this marketplace?

1. Fork this repository
2. Create a new skill directory under `skills/`
3. Write your `SKILL.md` following the [Agent Skills standard](https://agentskills.io)
4. Add an entry to `.claude-plugin/marketplace.json`
5. Submit a pull request

## License

MIT - See LICENSE file for details
