# gh-workflows

Shared reusable GitHub Actions workflows — the actual logic lives here once;
consuming repos get a thin caller file. Public repo so any of my other repos
(private or public) can reference it without cross-repo Actions-access
configuration.

## estimate-story-points.yml

Auto-estimates a GitHub issue on the Fibonacci scale (1/2/3/5/8/13) using
Claude Haiku, writes the value into a GitHub Projects v2 "Estimate" field,
and posts a one-line justification comment. Triggers: issue opened, an
`estimate` label added, an issue comment containing `/estimate`, or manual
dispatch with an issue number.

Ported from `proverbed/tradekeys.co`'s original (non-reusable) version.

### Consuming it from another repo

1. Copy this caller into the consuming repo as
   `.github/workflows/estimate-story-points.yml`:

   ```yaml
   name: Estimate Story Points

   on:
     issues:
       types: [opened, labeled]
     issue_comment:
       types: [created]
     workflow_dispatch:
       inputs:
         issue_number:
           description: 'Issue number to estimate'
           required: true
           type: number

   # Load-bearing, not optional — see "Gotchas" below.
   permissions:
     issues: write

   jobs:
     estimate:
       uses: proverbed/gh-workflows/.github/workflows/estimate-story-points.yml@main
       with:
         issue_number: ${{ inputs.issue_number }}
         # Name (or unique substring) of the Projects v2 board to write the
         # Estimate field to. Omit to fall back to the first project linked
         # to this repo.
         project_title: "TradeBotMonitor"
       secrets:
         GH_PAT: ${{ secrets.GH_PAT }}
         ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
   ```

2. Set two repo secrets (Settings → Secrets and variables → Actions) —
   secrets never inherit automatically across repos, even for reusable
   workflows, so this is a one-time step per consuming repo:
   - `GH_PAT` — a personal access token with `repo` + `project` scopes. The
     default `GITHUB_TOKEN` cannot read/write a user-level (non-org)
     Projects v2 board.
   - `ANTHROPIC_API_KEY` — an Anthropic API key (separate from any Claude
     Code subscription — this calls the Messages API directly).

3. Make sure the target Projects v2 board has a field literally named
   `Estimate` (any type — `SINGLE_SELECT` with numeric-string options, or
   `NUMBER`, are both handled).

That's the whole per-repo footprint — the ~330 lines of actual prompt/schema/
Projects-field-resolution logic exist only in this repo, at
`.github/workflows/estimate-story-points.yml`.

### Gotchas (found the hard way — both cause a silent `startup_failure` with zero jobs created and no readable log)

- **The caller must declare `permissions:` matching (or exceeding) whatever
  the reusable workflow's job declares.** A reusable workflow's job can only
  *narrow* the permissions available to it, never grant beyond what the
  caller already has — declaring `permissions: issues: write` only in the
  reusable workflow, with no matching grant in the caller, fails validation
  before a single job is created. The caller template above already
  includes this; if you add a step to the reusable workflow that needs a
  new permission, every consuming repo's caller needs the matching grant
  too.
- **Any `number`-typed input must be `string` instead if its value is ever
  forwarded from the caller's own `workflow_dispatch` input via an
  expression** (`${{ inputs.issue_number }}`). `workflow_dispatch` inputs
  are always delivered as strings at runtime regardless of their declared
  type — a literal number in `with:` works fine, but forwarding a
  caller-side numeric input through an expression into a reusable
  workflow's `number`-typed input fails. `issue_number` is `type: string`
  in this workflow for exactly this reason, even though it's numeric — the
  script only ever interpolates it into bash/`gh` calls, never arithmetic.
