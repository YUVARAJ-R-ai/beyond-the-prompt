#!/usr/bin/env bash
# agy-dispatch.sh — run one Antigravity (agy) worker headlessly and emit a compact summary.
#
# Usage:
#   agy-dispatch.sh run    <task-id> <workdir> <prompt-file> [model] [timeout-secs]
#   agy-dispatch.sh resume <task-id> <workdir> <conversation-id> <prompt-file> [timeout-secs] [model]
# Model defaults to $AGY_MODEL or gemini-3.8-flash-high. Claude models are refused unless AGY_ALLOW_CLAUDE=1.
#
# Artifacts (inside <workdir>/.agy/):
#   <task-id>.json       raw agy JSON result
#   <task-id>.err        agy stderr
#   <task-id>.summary    compact summary (what the manager should read)
#   <task-id>.before     git status snapshot taken before the run
#
# Exit codes: 0 worker finished with status SUCCESS; 10 worker ran but status != SUCCESS;
#             11 timeout; 12 agy produced no parseable JSON; 2 usage/setup error.
set -u
export _ZO_DOCTOR=0   # silence zoxide banner that pollutes output

mode="${1:-}"; task="${2:-}"; workdir="${3:-}"
case "$mode" in
  run)    prompt_file="${4:-}"; model="${5:-}"; tmo="${6:-900}"; conv="" ;;
  resume) conv="${4:-}"; prompt_file="${5:-}"; model="${7:-}"; tmo="${6:-900}" ;;
  *) echo "usage: see header of $0" >&2; exit 2 ;;
esac

[ -n "$task" ] && [ -d "$workdir" ] && [ -f "$prompt_file" ] || { echo "bad args: task/workdir/prompt-file" >&2; exit 2; }
command -v agy >/dev/null || { echo "agy not on PATH" >&2; exit 2; }
case "$task" in *[!A-Za-z0-9._-]*) echo "task-id must match [A-Za-z0-9._-]" >&2; exit 2 ;; esac

# Workers must be Gemini unless explicitly overridden: never fall back to agy's own default (may be Claude).
model="${model:-${AGY_MODEL:-gemini-3.8-flash-high}}"
case "$model" in
  claude*|*opus*|*sonnet*) [ "${AGY_ALLOW_CLAUDE:-0}" = 1 ] || { echo "refusing Claude model '$model' for a worker (set AGY_ALLOW_CLAUDE=1 to override)" >&2; exit 2; } ;;
esac

workdir="$(cd "$workdir" && pwd)"
out="$workdir/.agy"; mkdir -p "$out"
is_git=0; git -C "$workdir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && is_git=1
[ $is_git -eq 1 ] && git -C "$workdir" status --porcelain=v1 -uall > "$out/$task.before" 2>/dev/null

args=(-p "$(cat "$prompt_file")" --add-dir "$workdir" --dangerously-skip-permissions
      --output-format json --print-timeout "${tmo}s")
args+=(--model "$model")
[ -n "$conv" ]  && args+=(--conversation "$conv")

# Hard outer timeout slightly above agy's own so agy can fail gracefully first.
( cd "$workdir" && timeout --kill-after=10 "$((tmo + 30))" agy "${args[@]}" ) \
  > "$out/$task.json" 2> "$out/$task.err"
rc=$?

changed=""
if [ $is_git -eq 1 ]; then
  git -C "$workdir" status --porcelain=v1 -uall 2>/dev/null | grep -v ' \.agy/' > "$out/$task.after" || true
  changed="$(diff <(grep -v ' \.agy/' "$out/$task.before" 2>/dev/null) "$out/$task.after" | grep '^[<>]' | sed 's/^[<>] *//' | sort -u)"
fi

python3 -I - "$out/$task.json" "$rc" "$task" "$changed" "$model" > "$out/$task.summary" <<'PY'
import json, sys
path, rc, task, changed = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
try:
    d = json.load(open(path))
except Exception as e:
    print(f"TASK {task}\nSTATUS NO_JSON (rc={rc}) — see .agy/{task}.err\nCHANGED\n{changed}")
    sys.exit(0)
u = d.get("usage", {})
print(f"TASK {task}")
print(f"STATUS {d.get('status')}  rc={rc}  turns={d.get('num_turns')}  secs={round(d.get('duration_seconds',0))}  tokens={u.get('total_tokens')}")
print(f"MODEL {sys.argv[5]}")
print(f"CONVERSATION {d.get('conversation_id')}")
print("CHANGED_FILES")
print(changed or "(none detected)")
print("WORKER_REPLY")
print((d.get("response") or "")[:3000])
PY

cat "$out/$task.summary"
[ $rc -eq 124 ] || [ $rc -eq 137 ] && exit 11
grep -q '"status":"SUCCESS"' "$out/$task.json" 2>/dev/null && exit 0
[ -s "$out/$task.json" ] && exit 10
exit 12
