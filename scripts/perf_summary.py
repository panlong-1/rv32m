#!/usr/bin/env python3
"""Summarize [PERF] lines from TORV regression or build directories.

Usage:
  ./scripts/perf_summary.py
  ./scripts/perf_summary.py regress/results/20260523_053218
  ./scripts/perf_summary.py --csv perf.csv build/sim/soc/perf_alu_chain
"""

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PERF_RE = re.compile(
    r"\[PERF\] cycles=(\d+) instr=(\d+) ipc=([\d.]+)"
)
PERF_TYPE_RE = re.compile(
    r"\[PERF\] type alu=(\d+) load=(\d+) store=(\d+) branch=(\d+) "
    r"branch_taken=(\d+) jump=(\d+) muldiv=(\d+) lui_auipc=(\d+)"
)
PERF_STALL_RE = re.compile(
    r"\[PERF\] stall if=(\d+) id=(\d+) ex=(\d+) flush=(\d+) "
    r"dbus_r=(\d+) dbus_w=(\d+) sbus_r=(\d+) sbus_w=(\d+)"
)


def find_sim_logs(root):
    logs = sorted(root.glob("**/soc/*/*.sim.log"))
    if logs:
        return logs
    return sorted(root.glob("**/*.sim.log"))


def parse_log(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    if "[PASS]" not in text and "[PERF]" not in text:
        return None
    row = {"case": path.parent.name, "log": str(path)}
    m = PERF_RE.search(text)
    if m:
        row.update(zip(["cycles", "instr", "ipc"], m.groups()))
    m = PERF_TYPE_RE.search(text)
    if m:
        keys = ["alu", "load", "store", "branch", "branch_taken", "jump", "muldiv", "lui_auipc"]
        row.update(zip(keys, m.groups()))
    m = PERF_STALL_RE.search(text)
    if m:
        keys = ["stall_if", "stall_id", "stall_ex", "flush", "dbus_r", "dbus_w", "sbus_r", "sbus_w"]
        row.update(zip(keys, m.groups()))
    if "PASS" in text:
        row["status"] = "PASS"
    elif "TIMEOUT" in text or "FAIL" in text:
        row["status"] = "FAIL"
    else:
        row["status"] = "?"
    return row if "ipc" in row else None


def latest_results_dir():
    base = ROOT / "regress" / "results"
    if not base.is_dir():
        return None
    dirs = sorted([p for p in base.iterdir() if p.is_dir()], reverse=True)
    return dirs[0] if dirs else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, help="Result dir(s) or case build dir(s)")
    parser.add_argument("--csv", type=Path, help="Write CSV to this path")
    parser.add_argument("--perf-only", action="store_true", help="Only rows with [PERF] ipc line")
    args = parser.parse_args()

    search_roots = list(args.paths) if args.paths else []
    if not search_roots:
        latest = latest_results_dir()
        if latest:
            search_roots.append(latest)
        else:
            search_roots.append(ROOT / "build" / "sim")

    rows = []
    for root in search_roots:
        root = root.resolve()
        if (root / f"{root.name}.sim.log").is_file():
            logs = [root / f"{root.name}.sim.log"]
        else:
            logs = find_sim_logs(root)
        for log in logs:
            row = parse_log(log)
            if row is None:
                continue
            if args.perf_only and "ipc" not in row:
                continue
            rows.append(row)

    if not rows:
        print("No [PERF] logs found.", file=sys.stderr)
        return 1

    fieldnames = []
    for row in rows:
        for k in row:
            if k not in fieldnames:
                fieldnames.append(k)

    if args.csv:
        with args.csv.open("w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
            w.writeheader()
            w.writerows(rows)
        print(f"Wrote {args.csv} ({len(rows)} rows)")
    else:
        w = csv.DictWriter(sys.stdout, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
