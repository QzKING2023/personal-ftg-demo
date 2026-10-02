import io, json, sys
# Ticket 07 final Tier B, by-name alignment (08 gate.sh subset_compare adapted):
# restrict both sides to the 21 job names present in the 02 serial baseline
# (test_delay_prefix_restore is a post-baseline ticket-04 addition, gated by its
# own differential harness); synthesize the baseline's solver_report_keys from
# its ACCEPTANCE_SOLVER_METRICS_JSON log lines (the field postdates the baseline).
baseline_path, log_dir, cold_path, baseline_out, cold_out = sys.argv[1:6]
with io.open(baseline_path, encoding='utf-8-sig') as h:
    baseline = json.load(h)
with io.open(cold_path, encoding='utf-8-sig') as h:
    cold = json.load(h)
prefix = 'ACCEPTANCE_SOLVER_METRICS_JSON='

def metrics_of(name):
    payload = None
    with io.open('%s/%s.log' % (log_dir, name), encoding='utf-8', errors='replace') as h:
        for line in h:
            if line.startswith(prefix):
                payload = line[len(prefix):]
    return json.loads(payload) if payload else None

# Ticket 06 precedent (cache-06/gate/gate-06.sh): analyze_manifest() became
# cache-visible after the baseline, so test_move_table's calls/fps legitimately
# grew (6→9 calls). Field equality excludes it; its oracle is the separate
# fingerprint-containment check (tierb-move-table.out).
EXCLUDE_JOBS = ['test_move_table']
names = [r['test'] for r in baseline['tests'] if r['test'] not in EXCLUDE_JOBS]
missing = [n for n in names if not any(r['test'] == n for r in cold['tests'])]
assert not missing, 'baseline jobs missing from cold run: %s' % missing
extra = [r['test'] for r in cold['tests'] if r['test'] not in names]
print('jobs compared: %d; post-baseline jobs excluded: %s' % (len(names), extra))

def subset(summary, synth_keys):
    rows = [dict(r) for r in summary['tests'] if r['test'] in names]
    if synth_keys:
        for row in rows:
            reports = (metrics_of(row['test']) or {}).get('reports') or []
            row['solver_report_keys'] = [[str(k) for k in (r.get('keys') or [])] for r in reports]
    calls = sum(r['solver_calls'] for r in rows)
    return {
        'mode': summary['mode'],
        'total_seconds': sum(r['seconds'] for r in rows),
        'total_assertions': sum(r['assertions'] for r in rows),
        'total_solver_calls': calls,
        'total_solver_underlying_calls': sum(r['solver_underlying_calls'] for r in rows),
        'total_solver_reuse_hits': sum(r['solver_reuse_hits'] for r in rows),
        'solver_reuse_hit_rate': sum(r['solver_reuse_hits'] for r in rows) / calls if calls else 0.0,
        'tests': rows,
    }

with io.open(baseline_out, 'w', encoding='utf-8') as h:
    json.dump(subset(baseline, True), h, indent=2, ensure_ascii=True)
with io.open(cold_out, 'w', encoding='utf-8') as h:
    json.dump(subset(cold, False), h, indent=2, ensure_ascii=True)
print('wrote %s / %s' % (baseline_out, cold_out))
