#!/usr/bin/env bash
# Holds the contract callers rely on: every reusable workflow here takes a
# `runs_on` input and runs every job on `${{ inputs.runs_on }}`.
#
# proverbed/agentic's check-ci-runner guard lets a call to this repo through
# only when it passes the self-hosted runner as `runs_on`, because it cannot
# read this repo to see where the job actually runs. If a workflow here ever
# hardcoded `runs-on:` again, that caller would silently bill GitHub-hosted
# minutes with nothing on its side able to notice. This check is that side.
set -euo pipefail

dir="${1:-.github/workflows}"
expected='runs-on: ${{ inputs.runs_on }}'
problems=0

for f in "$dir"/*.yml "$dir"/*.yaml; do
  [ -e "$f" ] || continue
  grep -qE '^\s+workflow_call:' "$f" || continue

  if ! awk '/^ {4}inputs:/{i=1;next} i&&/^ {4}[a-z]/{i=0} i&&/^ {6}runs_on:/{found=1} END{exit !found}' "$f"; then
    echo "::error file=$f::declares no \`runs_on\` input under workflow_call.inputs"
    problems=$((problems + 1))
  fi

  runs_on_lines=$(grep -nE '^\s*runs-on:' "$f" || true)
  if [ -z "$runs_on_lines" ]; then
    echo "::error file=$f::has no \`runs-on:\` line to hold to \`$expected\`"
    problems=$((problems + 1))
  fi
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    line="${hit%%:*}"
    text=$(echo "${hit#*:}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if [ "$text" != "$expected" ]; then
      echo "::error file=$f,line=$line::\`$text\` — every job must use \`$expected\`, or callers that pass a self-hosted runner silently run on paid hosted minutes"
      problems=$((problems + 1))
    fi
  done <<< "$runs_on_lines"
done

if [ "$problems" -gt 0 ]; then
  echo "$problems problem(s)"
  exit 1
fi
echo "every reusable workflow runs on \`$expected\`"
