#!/usr/bin/env bash
# deny-env-bash.sh — PreToolUse Bash hook that blocks commands referencing
# secret-bearing .env files.
#
# Permission rules (Bash(prefix*)) only do prefix-wildcard matching, so they
# can't catch the long tail of forms (grep, awk, tail, source, xargs cat,
# input redirection, command substitution, ...). This hook regex-greps the
# rendered bash command for any path-like .env reference and denies via
# permissionDecision JSON.
#
# Allow-list: ".env.example" is treated as safe (template file, no secrets).
# Block: ".env", ".env.local", ".env.production", "infra/.env", "~/.env",
# "$HOME/.env", "<.env" (input redirect), etc.
#
# Reads the hook input JSON on stdin and prints the decision JSON on stdout.
# Exits 0 in all cases — Claude reads the permission decision from stdout.

set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')

# Allowlist: git subcommands that take .env* as an identifier (path argument
# or text in a -m message) without ever reading file content. These would
# otherwise false-positive on `git check-ignore -v .env` and
# `git commit -m "...mentions .env..."`. Constraints:
#   - line must START with `git` (no `cd … &&` chain prefix; if you need a
#     chain, run the cd separately).
#   - line must NOT contain `;`, `&&`, or `|` after the safe subcommand
#     (this prevents a `git status; cat .env` bypass — the chain after the
#     separator would fall through to the existing block logic if we didn't
#     anchor with $).
git_safe_re='^[[:space:]]*git[[:space:]]+(-[^[:space:]]+([[:space:]]+[^[:space:]]+)?[[:space:]]+)*(check-ignore|commit|add|rm|mv|status)\b[^;&|]*$'
if echo "$cmd" | grep -qE "$git_safe_re"; then
  exit 0
fi

# Match `.env` when it appears as a path-component token: preceded by start,
# whitespace, path separator, redirection, assignment, quote, $, (, or :,
# AND followed by either non-alphanumeric (so `.env.local`, `.env.production`
# also match) or end-of-line.
env_ref_pattern='(^|[[:space:]/=<>:"\(\$])\.env([^a-zA-Z0-9_]|$)'

# `.env.example` and `.env.tpl` are safe by design — example files contain
# placeholder values; templates contain only secret-store references (whether
# `{{ op://... }}`, `{{ keychain://... }}`, sops-encrypted, etc.) and non-secret
# literals. Strip both before the regex test.
stripped=$(echo "$cmd" | sed -E 's|\.env\.example||g; s|\.env\.tpl||g')

if ! echo "$stripped" | grep -qE "$env_ref_pattern"; then
  exit 0
fi

reason='Blocked: Bash command references a .env file (.env, .env.local, .env.production, etc). Reading secrets into the conversation transcript is forbidden by CLAUDE.md secret-handling rules. Use the Read tool for non-secret files like .env.example, or use file-on-disk handoff for actual secrets. To bypass for a legitimate non-read use (e.g. modifying secrets via anchored sed pattern), restructure the command to avoid the literal .env reference, or temporarily disable this hook in settings.json.'

jq -nc --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
