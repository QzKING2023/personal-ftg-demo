#!/usr/bin/env python3
"""Render the ticket 03 profile report from job logs and the default-table run.

Inputs: after-run job logs (ACCEPTANCE_SOLVER_METRICS_JSON with profiles) and
the default-table runner log (SOLVER_PROFILE_JSON lines). Output: markdown
report for tickets 04/05 (prefix-restore investment decision data).
"""

import json
import sys
from pathlib import Path

BUCKETS = ["delay_leaf", "edge_probe", "gap_enum", "route_walk", "other"]
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent


def read_lines(path):
    return path.read_bytes().decode("utf-8", errors="replace").splitlines()


def job_profiles(log_path):
    metrics = None
    for line in read_lines(log_path):
        if line.startswith("ACCEPTANCE_SOLVER_METRICS_JSON="):
            metrics = json.loads(line.split("=", 1)[1])
    if not metrics:
        return None, None
    rows = []
    for p in metrics.get("profiles", []):
        rows.append(p)
    return metrics.get("test"), rows


def fmt_ms(value):
    return "%.0f" % value if value >= 100 else "%.1f" % value


def request_row(p):
    total = p.get("total_ms", 0.0)
    cells = [p.get("key", "?"), p.get("fingerprint", "")[:8]]
    for bucket in BUCKETS:
        ms = p.get(bucket + "_ms", 0.0)
        share = (100.0 * ms / total) if total > 0 else 0.0
        cells.append("%s (%.0f%%, %dr)" % (fmt_ms(ms), share, p.get(bucket + "_runs", 0)))
    cells.append(fmt_ms(total))
    return "| " + " | ".join(cells) + " |"


def main(argv):
    if len(argv) < 2:
        print("usage: render_report.py OUT.md LOG [LOG ...]")
        return 2
    out_path = Path(argv[0])
    sections = []
    grand = {b + "_ms": 0.0 for b in BUCKETS}
    grand_total = 0.0
    for log in argv[1:]:
        path = Path(log)
        if not path.is_absolute():
            path = ROOT / path
        test, rows = job_profiles(path)
        if rows is None:
            sections.append("## %s\n\n(no metrics line)\n" % (test or path.name))
            continue
        heavy = [p for p in rows if p.get("total_ms", 0.0) >= 1000.0]
        light_total = sum(p.get("total_ms", 0.0) for p in rows if p.get("total_ms", 0.0) < 1000.0)
        parts = ["## %s — %d 请求,重请求(≥1s)%d 个,轻请求合计 %.0fms" % (
            test, len(rows), len(heavy), light_total)]
        if heavy:
            parts.append("")
            parts.append("| 请求 | fp | delay_leaf | edge_probe | gap_enum | route_walk | other | total_ms |")
            parts.append("|---|---|---|---|---|---|---|---|")
            for p in sorted(heavy, key=lambda x: -x.get("total_ms", 0.0)):
                parts.append(request_row(p))
        totals = {b + "_ms": sum(p.get(b + "_ms", 0.0) for p in rows) for b in BUCKETS}
        for b in BUCKETS:
            grand[b + "_ms"] += totals[b + "_ms"]
        grand_total += sum(p.get("total_ms", 0.0) for p in rows)
        parts.append("")
        parts.append("测试级合计:" + " ".join(
            "%s=%sms" % (b, fmt_ms(totals[b + "_ms"])) for b in BUCKETS))
        sections.append("\n".join(parts) + "\n")

    header = ["# 票据 03:Solver 耗时 profile 报告", "",
              "分类口径与插桩说明见 issues/03 Comments。`*_ms` 为墙钟测量;`%` 为占请求总耗时比,`r` 为该类 `_run_schedule` 次数。", ""]
    if grand_total > 0:
        header.append("全部输入日志的桶合计:" + " ".join(
            "%s=%sms(%.0f%%)" % (b, fmt_ms(grand[b + "_ms"]), 100.0 * grand[b + "_ms"] / grand_total)
            for b in BUCKETS) + ",合计 %.0fms" % grand_total)
        header.append("")
    out_path.write_text("\n".join(header) + "\n" + "\n".join(sections), encoding="utf-8")
    print("wrote %s" % out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
