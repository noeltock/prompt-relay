# Hook eval — 17 cases

Unlike the routing eval, this one needs no model and no judgment call: each case feeds a
synthetic `PreToolUse` payload straight to a hook script and checks its decision against a fixed
expected result. Run it with `bash evals/run-hook-evals.sh` — see `README.md` in this folder.

Fixtures: a 600-line text file (`big.txt`), a 100-line text file (`small.txt`), and a `.png`.

## `read-scope-guard.sh`

| # | Input | Expected |
|---|---|---|
| 1 | Read, no `limit`/`offset`, `big.txt` | deny |
| 2 | Read, `limit` set, `big.txt` | allow |
| 3 | Read, `offset` set, `big.txt` | allow |
| 4 | Read, no `limit`/`offset`, `small.txt` | allow |
| 5 | Read, no `limit`/`offset`, `image.png` | allow (binary exemption) |
| 6 | Read, `big.txt`, `agent_id` present | allow (subagent exemption) |
| 7 | Read, `big.txt`, `RELAY_MIN_LINES=1000` | allow (threshold raised past file size) |

## `bash-read-guard.sh`

| # | Input | Expected |
|---|---|---|
| 8 | `cat big.txt` | deny |
| 9 | `cat big.txt \| grep x` | allow (pipe passes through) |
| 10 | `head -n 20 big.txt` | allow (explicit count) |
| 11 | `sed -n 1,50p big.txt` | allow (`sed` isn't a guarded command) |
| 12 | `cat small.txt` | allow (under threshold) |
| 13 | `cat big.txt`, `agent_id` present | allow (subagent exemption) |

## `scout-model-pin.sh`

| # | Input | Expected |
|---|---|---|
| 14 | `subagent_type: Explore`, no `model` | `updatedInput.model` = `sonnet` (default) |
| 15 | `subagent_type: Explore`, `model: opus` already set | unchanged (no mutation) |
| 16 | `subagent_type: coder-low` | unchanged (not a built-in scout type) |
| 17 | `subagent_type: Explore`, `RELAY_SCOUT_MODEL=haiku` | `updatedInput.model` = `haiku` |
