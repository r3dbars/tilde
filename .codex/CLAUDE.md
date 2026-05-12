# Claude Code Guide

This folder configures Codex app behavior for the repo.

Start here when changing local run actions or Codex workspace setup:

- `.codex/environments/environment.toml`
- `.codex/environments/AGENTS.md`
- `.codex/environments/CLAUDE.md`

Rules:

- Keep commands repo-local and script-backed.
- Do not put app source, tests, generated diagnostics, or model assets here.
- Keep this folder about operator setup, not product behavior.
