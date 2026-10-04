#!/usr/bin/env bash
# P7 worker-restart 实机验证（v2）：小集 pool 跑 + 击杀一个在途重请求的
# worker 引擎树。判定：heartbeat state=busy 且 wall_ms>12s（琐碎请求 ~1s）。
set -u
cd "$(dirname "$0")/../.."
OUT=".scratch/solver-p7-01/sweep-pool-kill4"

python tools/run_acceptance.py --sweep --sweep-mode pool --concurrency 6 \
  --pool-watchdog-ms 2000 \
  --only test_hit_profiles,test_solver_cache,test_solver_growth,test_solver_index_equiv \
  --output "$OUT" --cache "$OUT/cache.cache" > "$OUT.log" 2>&1 &
RUNNER=$!

python - "$OUT" <<'PYEOF'
import json, subprocess, sys, time
from pathlib import Path

out = Path(sys.argv[1])
pool = out / "sweep" / "workers" / "pool"
killed = None
deadline = time.time() + 900
while time.time() < deadline and killed is None:
    time.sleep(1)
    events = out / "sweep" / "workers" / "pool-events.jsonl"
    if not events.exists():
        continue
    slots = {}
    for line in events.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if row.get("event") == "spawn":
            slots[row["slot"]] = row["pid"]
    for wdir in sorted(pool.glob("worker-*")):
        hb = wdir / "heartbeat.json"
        if not hb.exists():
            continue
        try:
            state = json.loads(hb.read_text(encoding="utf-8", errors="replace"))
        except (OSError, ValueError):
            continue
        if state.get("state") != "running":
            continue
        if not str(state.get("digest", "")).startswith(("134fcb97a336", "ae21e60649b4")):
            continue
        slot = int(wdir.name.split("-")[1])
        pid = slots.get(slot)
        if pid is None:
            continue
        print(f"kill target pid={pid} slot={slot} digest={state.get('digest','')[:16]} hb={json.dumps(state)[:200]}", flush=True)
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], capture_output=True)
        killed = pid
        break
print("killed:", killed, flush=True)
PYEOF

wait $RUNNER
echo "runner exit=$?" > "$OUT.status"
