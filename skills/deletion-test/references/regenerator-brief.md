# Regenerator brief

One agent per arm, a cheap model (Sonnet class), its own git worktree.
Arms run in parallel. The brief below is what worked; adapt the paths and
the worked example. Keep the isolation rules verbatim.

## Preparing an arm

```bash
git worktree add -q --detach /path/agentus-arm-A HEAD
cp app/config/master.key /path/agentus-arm-A/app/config/   # if Rails needs it
cp spec/.../component_contract_spec.rb /path/agentus-arm-A/app/spec/.../
# verify the contract spec runs there against the ORIGINAL first
rm /path/agentus-arm-A/app/app/.../component.rb
rm /path/agentus-arm-A/app/spec/.../component_spec.rb
mkdir /path/agentus-arm-A/app/regeneration
cp intent.md /path/agentus-arm-A/app/regeneration/intent.md        # or intent-sparse.md for arm C
```

Worktrees carry only committed files. Anything you wrote on the
experiment branch without committing has to be copied in.

## The brief

> You are regenerating a deleted Ruby module from its intent document and
> its contract spec. This is a controlled experiment; the rules of
> isolation matter as much as the result.
>
> WORKING DIRECTORY: `<worktree>/app`. Everything you read and write stays
> under `<worktree>`.
>
> ISOLATION RULES (violating any of these voids the experiment; if you find
> yourself about to, stop and say so in your notes instead):
> - Do NOT run any `git` command of any kind. The git history contains the
>   previous implementation.
> - Do NOT read anything under `<main checkout>` or any directory outside
>   your worktree.
> - Do NOT search the web or any external source for this module.
> - Do NOT read `spec/.../component_spec.rb` if it exists anywhere; the only
>   spec you use is the contract spec named below.
> - Do NOT modify the contract spec.
>
> INPUTS, all inside your worktree:
> 1. `regeneration/intent.md`. Read it fully first.
> 2. `spec/.../component_contract_spec.rb`: the durable evaluations your
>    implementation must pass.
> 3. Call sites: `<path>` (whole file), `<path>` lines N-M, and the
>    dependency `<path>`.
> 4. Repo conventions: `CLAUDE.md`, `.rubocop.yml`.
>
> TASK: write `app/.../component.rb` implementing `Namespace::Component`
> per the intent: the public surface in section 3, every invariant in
> section 4, every decision in section 5 [sparse arm: "section 5 is
> withheld; where a value is a choice rather than a fact, choose one that
> satisfies every invariant and record why"]. Frozen string literal, YARD
> on public methods, and comments that carry the reason for every constant
> so a reader of your file does not need the intent doc.
>
> Then run: `<ruby PATH export>`; `bundle exec rspec <contract spec>`;
> `bundle exec rubocop <file>`. Iterate until green and clean. Cap yourself
> at 6 spec runs; if still red, stop and report.
>
> Verify by hand that your implementation reproduces the worked example in
> intent.md section 5 [sparse arm: "compute and report what your
> implementation emits for `<shape>`"]. Do not hit the network.
>
> Finally write `regeneration/notes.md` with: your reading of what the
> module must do in five lines; every place the intent was ambiguous,
> incomplete, or contradictory, and what you chose; every value or behavior
> you had to decide yourself; anything that looked arbitrary or that you
> would question in review; an attempt log; questions you would ask the
> human who wrote the intent.
>
> Report back with the final spec summary line, rubocop result, the
> worked-example check, and the full notes.

## What to read in the notes

The notes are half the result. Every question a regenerator asks is a
sentence the intent should have contained. In the first run all three
arms asked the same three questions, which said more about the intent
document than about the arms. The sparse arm's notes also disclosed, on
its own, that it had reverse-solved a withheld value from a comment in a
caller, which became the most useful finding of the day.

## Arms

Two arms with the full intent measure variance. One arm with the sparse
intent measures what a regenerator chooses when decisions are missing,
and it mostly measures leakage, which is worth knowing. More arms give
real variance numbers; three is the minimum that says anything.
