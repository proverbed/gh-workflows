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
