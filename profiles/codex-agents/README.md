# Codex custom-agent templates

Copy these files into `~/.codex/agents/` for a personal install or `.codex/agents/` for one
project. The model pins are an example roster, not Prompt Relay's portable policy. Change them to
models your account exposes and prove each pair with a live canary plus
`verify/check-routing-codex.sh`.

All five agents are leaves: `[agents] enabled = false` removes nested delegation from their tool
surface. The lead remains the interactive session and is configured separately.

After copying or changing these files, start a new Codex task so the lead default, instructions,
and custom-agent registry load together. The installer must show which roles are merely configured
and which have a live transcript receipt; one successful canary does not verify the roster.

| File | Shipped pin | Authority |
|---|---|---|
| `coder-low.toml` | Terra medium | edits and verifies a bounded implementation |
| `coder-high.toml` | Terra high | edits when local implementation judgment is required |
| `advisor.toml` | Astra medium | read-only advice, manual invocation |
| `qa.toml` | Luna medium | runs named checks, never fixes |
| `runner.toml` | Luna medium | bounded searches/transforms, never codes |
