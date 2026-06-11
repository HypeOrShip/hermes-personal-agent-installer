# Agent rules — hermes-personal-agent-installer

For ANY coding agent (Claude, Codex, other) working in this repo:

1. Branch + worktree per task; PR-only; no pushes to main; no force-push anywhere.
2. CI must be green before merge is even requested (compile-gate: build + tests-if-present).
3. You may not edit: .github/workflows/*, branch protection, repo settings. Flag instead.
4. Reviewer is never the implementer. If you wrote it, you don't approve it.
5. Quote receipts: PR URL, CI run link, deploy tag. No receipt = it didn't happen.
6. See CLAUDE.md for build/deploy specifics.
