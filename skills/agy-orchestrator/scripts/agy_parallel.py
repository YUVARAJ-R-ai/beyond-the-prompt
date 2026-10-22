#!/usr/bin/env python3
"""agy_parallel.py — run independent agy workers concurrently, each isolated in its own git worktree.

Commands (all take --manifest PATH, default <cwd>/.agy/manifest.json):
  check                 validate manifest, show dependency waves and file-overlap serialization
  run [--only id,id]    run every READY task now (deps merged, no file overlap inside the batch),
                        concurrently up to max_parallel; blocks until the batch finishes
  status                show per-task state
  merge ID [ID...]      commit the worker's in-scope changes and merge branch agy/ID into the base branch
  discard ID [ID...]    drop a task's worktree+branch (for rejected work) and reset it to 'pending'
  cleanup               remove all worktrees/branches of merged or discarded tasks

Manifest (JSON):
{
  "workdir": "/abs/project",              # git repo (preferred) or plain dir
  "max_parallel": 4,
  "default_model": "gemini-3.8-flash-high",
  "default_timeout": 900,
  "tasks": [
    {"id": "posts", "prompt_file": "/abs/prompts/posts.txt",   # may contain {{WORKDIR}} placeholder
     "files": ["app/routers/posts.py", "tests/test_posts.py"],   # exhaustive allowed paths (files or dirs)
     "depends": [], "model": null, "timeout": null}
  ]
}
Task states (in <workdir>/.agy/state.json): pending -> running -> done|failed -> merged|discarded.
Claude must review (scope, diff, acceptance commands) between 'run' and 'merge'.
"""
import argparse, json, os, shutil, subprocess, sys, threading, time
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
DISPATCH = os.path.join(HERE, "agy-dispatch.sh")
LOCK = threading.Lock()


def sh(args, cwd=None, check=False):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, check=check)


def say(msg):
    with LOCK:
        print(msg, flush=True)


def load(path):
    with open(path) as f:
        m = json.load(f)
    m["workdir"] = os.path.abspath(m["workdir"])
    m.setdefault("max_parallel", 4)
    m.setdefault("default_model", "gemini-3.8-flash-high")
    m.setdefault("default_timeout", 900)
    return m


def state_path(m):
    return os.path.join(m["workdir"], ".agy", "state.json")


def load_state(m):
    try:
        with open(state_path(m)) as f:
            return json.load(f)
    except FileNotFoundError:
        return {t["id"]: {"state": "pending"} for t in m["tasks"]}


def save_state(m, st):
    os.makedirs(os.path.dirname(state_path(m)), exist_ok=True)
    tmp = state_path(m) + ".tmp"
    with open(tmp, "w") as f:
        json.dump(st, f, indent=2)
    os.replace(tmp, state_path(m))


def is_git(wd):
    return sh(["git", "rev-parse", "--is-inside-work-tree"], cwd=wd).returncode == 0


def norm(p):
    return os.path.normpath(p).rstrip("/")


def overlaps(a, b):
    """True if any path in a equals / contains / is contained by any path in b."""
    for x in a:
        for y in b:
            x, y = norm(x), norm(y)
            if x == y or x.startswith(y + "/") or y.startswith(x + "/"):
                return True
    return False


def validate(m):
    errs, ids = [], set()
    for t in m["tasks"]:
        if not t.get("id") or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" for c in t["id"]):
            errs.append(f"bad id: {t.get('id')!r}")
        if t["id"] in ids:
            errs.append(f"duplicate id: {t['id']}")
        ids.add(t["id"])
        if not os.path.isfile(t.get("prompt_file", "")):
            errs.append(f"{t['id']}: prompt_file missing")
        if not t.get("files"):
            errs.append(f"{t['id']}: 'files' (allowed paths) is required")
        for f in t.get("files", []):
            if os.path.isabs(f) or ".." in norm(f).split("/"):
                errs.append(f"{t['id']}: file path must be relative and inside workdir: {f}")
    for t in m["tasks"]:
        for d in t.get("depends", []):
            if d not in ids:
                errs.append(f"{t['id']}: unknown dependency {d}")
    # cycle detection
    deps = {t["id"]: set(t.get("depends", [])) for t in m["tasks"]}
    seen, stack = set(), set()

    def dfs(n):
        if n in stack:
            return True
        if n in seen:
            return False
        seen.add(n); stack.add(n)
        if any(dfs(d) for d in deps.get(n, ())):
            return True
        stack.discard(n)
        return False

    if any(dfs(n) for n in deps):
        errs.append("dependency cycle detected")
    if not os.path.isdir(m["workdir"]):
        errs.append("workdir does not exist")
    return errs


def pick_batch(m, st, only=None):
    """Ready = pending & all deps merged. Then drop tasks whose files overlap an already-picked one."""
    byid = {t["id"]: t for t in m["tasks"]}
    ready = [t for t in m["tasks"]
             if st[t["id"]]["state"] == "pending"
             and all(st[d]["state"] == "merged" for d in t.get("depends", []))
             and (only is None or t["id"] in only)]
    # tasks already running/done-but-unmerged also reserve their files
    reserved = [byid[i]["files"] for i, s in st.items() if s["state"] in ("running", "done", "failed")]
    batch, deferred = [], []
    for t in ready:
        if any(overlaps(t["files"], r) for r in reserved) or any(overlaps(t["files"], b["files"]) for b in batch):
            deferred.append(t["id"])
        else:
            batch.append(t)
    return batch, deferred


def worktree_dir(m, tid):
    return os.path.join(m["workdir"], ".agy", "wt", tid)


def ensure_ignored(wd):
    if not is_git(wd):
        return
    p = sh(["git", "rev-parse", "--git-path", "info/exclude"], cwd=wd).stdout.strip()
    p = p if os.path.isabs(p) else os.path.join(wd, p)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    try:
        cur = open(p).read()
    except FileNotFoundError:
        cur = ""
    if ".agy/" not in cur.split():
        with open(p, "a") as f:
            f.write("\n.agy/\n")


def run_one(m, t, git):
    tid = t["id"]
    wd = m["workdir"]
    isolated = wd
    if git:
        isolated = worktree_dir(m, tid)
        if os.path.isdir(isolated):
            sh(["git", "worktree", "remove", "--force", isolated], cwd=wd)
        r = sh(["git", "worktree", "add", "-B", f"agy/{tid}", isolated, "HEAD"], cwd=wd)
        if r.returncode != 0:
            return tid, 12, f"worktree add failed: {r.stderr.strip()}", isolated
    prompt = open(t["prompt_file"]).read().replace("{{WORKDIR}}", isolated)
    pf = os.path.join(m["workdir"], ".agy", f"{tid}.prompt.txt")
    os.makedirs(os.path.dirname(pf), exist_ok=True)
    with open(pf, "w") as f:
        f.write(prompt)
    model = t.get("model") or m["default_model"]
    tmo = str(t.get("timeout") or m["default_timeout"])
    say(f"[start] {tid} model={model} dir={isolated}")
    t0 = time.time()
    r = sh([DISPATCH, "run", tid, isolated, pf, model, tmo])
    say(f"[end]   {tid} rc={r.returncode} {round(time.time()-t0)}s")
    return tid, r.returncode, r.stdout, isolated


def cmd_check(m):
    errs = validate(m)
    if errs:
        print("INVALID:\n  " + "\n  ".join(errs)); return 2
    st = load_state(m)
    git = is_git(m["workdir"])
    print(f"workdir={m['workdir']} git={git} max_parallel={m['max_parallel']}")
    if not git:
        print("WARNING: not a git repo — no isolation, no merge. Only safe if file sets are disjoint; consider `git init`.")
    done, wave, rem = set(), 1, {t["id"]: t for t in m["tasks"]}
    while rem:
        ready = [t for t in rem.values() if set(t.get("depends", [])) <= done]
        if not ready:
            break
        batch = []
        for t in ready:
            if not any(overlaps(t["files"], b["files"]) for b in batch):
                batch.append(t)
        print(f"wave {wave}: {', '.join(t['id'] for t in batch)}")
        ser = [t["id"] for t in ready if t not in batch]
        if ser:
            print(f"   (serialized due to file overlap: {', '.join(ser)})")
        for t in batch:
            done.add(t["id"]); rem.pop(t["id"])
        wave += 1
    total = len(m["tasks"])
    print(f"{total} tasks in {wave-1} sequential step(s); parallel width up to {m['max_parallel']}")
    return 0


def cmd_run(m, only):
    errs = validate(m)
    if errs:
        print("INVALID:\n  " + "\n  ".join(errs)); return 2
    if not os.path.exists(DISPATCH):
        print("agy-dispatch.sh missing"); return 2
    git = is_git(m["workdir"])
    if git and sh(["git", "status", "--porcelain", "-uall"], cwd=m["workdir"]).stdout.replace(".agy/", "").strip():
        # tracked/untracked changes in base would be absent from worktrees -> workers would see a stale tree
        dirty = [l for l in sh(["git", "status", "--porcelain", "-uall"], cwd=m["workdir"]).stdout.splitlines() if ".agy/" not in l]
        if dirty:
            print("REFUSING: base tree has uncommitted changes (workers branch from HEAD and wouldn't see them). Commit first:\n  " + "\n  ".join(dirty[:10]))
            return 2
    if not git:
        print("WARNING: no git — running in place; relying on disjoint file sets.")
    ensure_ignored(m["workdir"])
    st = load_state(m)
    batch, deferred = pick_batch(m, st, set(only) if only else None)
    if not batch:
        print("nothing ready. " + (f"deferred (overlap): {deferred}" if deferred else "Check `status`: deps may be unmerged."))
        return 0
    if deferred:
        print(f"deferred to a later run (file overlap): {', '.join(deferred)}")
    for t in batch:
        st[t["id"]] = {"state": "running", "started": time.time()}
    save_state(m, st)
    n = max(1, min(int(m["max_parallel"]), len(batch)))
    say(f"running {len(batch)} task(s), {n} at a time: {', '.join(t['id'] for t in batch)}")
    results = {}
    try:
        with ThreadPoolExecutor(max_workers=n) as ex:
            futs = {ex.submit(run_one, m, t, git): t for t in batch}
            for f in as_completed(futs):
                t = futs[f]
                try:
                    tid, rc, out, wd = f.result()
                except Exception as e:  # never lose the batch to one crash
                    tid, rc, out, wd = t["id"], 12, f"orchestrator error: {e}", m["workdir"]
                results[tid] = (rc, out, wd)
                st[tid] = {"state": "done" if rc == 0 else "failed", "rc": rc, "dir": wd, "ended": time.time()}
                save_state(m, st)
    except KeyboardInterrupt:
        for t in batch:
            if st[t["id"]]["state"] == "running":
                st[t["id"]]["state"] = "failed"
        save_state(m, st)
        print("interrupted; running tasks marked failed (workers may still be finishing — check `ps` for agy)")
        return 130
    print("\n===== BATCH RESULTS =====")
    for tid, (rc, out, wd) in results.items():
        print(f"\n--- {tid} (rc={rc}, dir={wd}) ---\n{out.strip()}")
    bad = [t for t, (rc, _, _) in results.items() if rc != 0]
    print(f"\n{len(results)-len(bad)} ok, {len(bad)} failed" + (f": {', '.join(bad)}" if bad else ""))
    print("NEXT: review each (scope, diff, acceptance cmds) -> `merge ID` or `discard ID`; then `run` again for dependents.")
    return 0


def cmd_status(m):
    st = load_state(m)
    for t in m["tasks"]:
        s = st[t["id"]]
        print(f"{t['id']:20} {s['state']:10} deps={t.get('depends', [])} {s.get('dir', '')}")
    return 0


def in_scope(path, allowed):
    path = norm(path)
    return any(path == norm(a) or path.startswith(norm(a) + "/") for a in allowed)


def cmd_merge(m, ids):
    st, wd = load_state(m), m["workdir"]
    if not is_git(wd):
        print("not a git repo; nothing to merge (in-place mode)");
        for i in ids: st[i]["state"] = "merged"
        save_state(m, st); return 0
    rc_all = 0
    for tid in ids:
        t = next((x for x in m["tasks"] if x["id"] == tid), None)
        if not t or st.get(tid, {}).get("state") != "done":
            print(f"{tid}: not in 'done' state (is {st.get(tid, {}).get('state')}); skipping"); rc_all = 1; continue
        wt = worktree_dir(m, tid)
        lines = [l for l in sh(["git", "status", "--porcelain", "-uall"], cwd=wt).stdout.splitlines() if ".agy/" not in l]
        paths = [l[3:].split(" -> ")[-1].strip('"') for l in lines]
        out = [p for p in paths if not in_scope(p, t["files"])]
        junk = [p for p in out if p.endswith((".pyc",)) or "__pycache__" in p or p.endswith(".log")]
        out = [p for p in out if p not in junk]
        if out:
            print(f"{tid}: OUT-OF-SCOPE changes, refusing merge: {out}\n  fix: revert them in {wt} (git checkout -- / rm), or discard and tighten the prompt")
            rc_all = 1; continue
        ins = [p for p in paths if in_scope(p, t["files"])]
        if ins:
            sh(["git", "add", "--"] + ins, cwd=wt)
            r = sh(["git", "-c", "user.name=agy-worker", "-c", "user.email=agy@localhost", "commit", "-q", "-m", f"agy({tid}): worker changes"], cwd=wt)
            if r.returncode != 0:
                print(f"{tid}: commit failed: {r.stderr.strip()}"); rc_all = 1; continue
        r = sh(["git", "merge", "--no-ff", "--no-edit", "-m", f"merge agy/{tid}", f"agy/{tid}"], cwd=wd)
        if r.returncode != 0:
            sh(["git", "merge", "--abort"], cwd=wd)
            print(f"{tid}: MERGE CONFLICT (aborted cleanly). Resolve manually: git merge agy/{tid}\n{r.stdout.strip()}")
            rc_all = 1; continue
        st[tid]["state"] = "merged"; save_state(m, st)
        print(f"{tid}: merged ({len(ins)} file(s))")
    return rc_all


def drop(m, tid):
    wd = m["workdir"]
    if is_git(wd):
        sh(["git", "worktree", "remove", "--force", worktree_dir(m, tid)], cwd=wd)
        sh(["git", "branch", "-D", f"agy/{tid}"], cwd=wd)


def cmd_discard(m, ids):
    st = load_state(m)
    for tid in ids:
        drop(m, tid); st[tid] = {"state": "pending"}; print(f"{tid}: discarded -> pending")
    save_state(m, st); return 0


def cmd_cleanup(m):
    st = load_state(m)
    for tid, s in st.items():
        if s["state"] in ("merged",):
            drop(m, tid)
    if is_git(m["workdir"]):
        sh(["git", "worktree", "prune"], cwd=m["workdir"])
    print("cleaned merged worktrees/branches (logs in .agy/ kept; rm -rf .agy when finished)")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", default=os.path.join(os.getcwd(), ".agy", "manifest.json"))
    ap.add_argument("cmd", choices=["check", "run", "status", "merge", "discard", "cleanup"])
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    try:
        m = load(a.manifest)
    except Exception as e:
        print(f"cannot load manifest {a.manifest}: {e}"); return 2
    if a.cmd == "check": return cmd_check(m)
    if a.cmd == "run": return cmd_run(m, [x for x in a.only.split(",") if x])
    if a.cmd == "status": return cmd_status(m)
    if a.cmd == "merge": return cmd_merge(m, a.ids)
    if a.cmd == "discard": return cmd_discard(m, a.ids)
    return cmd_cleanup(m)


if __name__ == "__main__":
    sys.exit(main())
