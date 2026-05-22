#!/usr/bin/env python3
"""Check directed hazard dup cases using pc_trace.tsv WB columns.

Counts register x1 writebacks (+1 increments) to catch duplicate addi execution
without parsing waveforms. Requires simulation with --pc-trace (see run_case.sh).

Usage:
  ./scripts/check_hazard_dup_trace.py --case hazard_ibus_insn_dup
  ./scripts/check_hazard_dup_trace.py --trace build/sim/soc/hazard_ibus_load_dup/pc_trace.tsv \\
      --expect-final 1 --max-plus1 1
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CASE_DEFAULTS = {
    "hazard_ibus_insn_dup": {"expect_final": 2, "max_plus1": 2},
    "hazard_ibus_load_dup": {"expect_final": 1, "max_plus1": 1},
}


def parse_pc_trace(path):
    """Return (time_ps, wdata) for each WB write to x1."""
    writes = []
    header = path.read_text(encoding="utf-8").splitlines()
    if not header:
        raise ValueError(f"empty trace: {path}")
    for line in header[1:]:
        if not line.strip():
            continue
        cols = line.split("\t")
        if len(cols) < 8:
            raise ValueError(f"expected 8 columns in {path}, got: {line}")
        wb_we = int(cols[5], 10)
        wb_rd = int(cols[6], 16)
        wb_wdata = int(cols[7], 16)
        if wb_we and wb_rd == 1:
            writes.append((int(cols[0], 10), wb_wdata))
    return writes


def count_plus1_steps(writes):
    if len(writes) < 2:
        return 0
    steps = 0
    for i in range(1, len(writes)):
        if writes[i][1] == writes[i - 1][1] + 1:
            steps += 1
    return steps


def run_case(case, build_dir=None):
    build = build_dir or (ROOT / "build" / "sim" / "soc" / case)
    trace = build / "pc_trace.tsv"
    cmd = [
        str(ROOT / "scripts" / "run_case.sh"),
        "--pc-trace",
        "--pc-trace-file",
        str(trace),
        "--pc-trace-each-cycle",
        str(ROOT / "tests" / "core" / "asm" / f"{case}.S"),
    ]
    print("+ " + " ".join(cmd))
    rc = subprocess.call(cmd, cwd=str(ROOT))
    if rc != 0:
        raise SystemExit(rc)
    return trace


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=sorted(CASE_DEFAULTS.keys()))
    parser.add_argument("--trace", type=Path, help="Existing pc_trace.tsv (skip re-run)")
    parser.add_argument("--build-dir", type=Path)
    parser.add_argument("--expect-final", type=int)
    parser.add_argument("--max-plus1", type=int, help="Max +1 steps between consecutive x1 writes")
    parser.add_argument("--run", action="store_true", help="Re-run simulation with --pc-trace")
    args = parser.parse_args()

    if args.case:
        defaults = CASE_DEFAULTS[args.case]
        expect_final = args.expect_final if args.expect_final is not None else defaults["expect_final"]
        max_plus1 = args.max_plus1 if args.max_plus1 is not None else defaults["max_plus1"]
        if args.run or args.trace is None:
            trace = run_case(args.case, args.build_dir)
        else:
            trace = args.trace
    else:
        if args.trace is None or args.expect_final is None or args.max_plus1 is None:
            parser.error("--trace, --expect-final, and --max-plus1 required without --case")
        trace = args.trace
        expect_final = args.expect_final
        max_plus1 = args.max_plus1

    if not trace.is_file():
        print(f"error: missing {trace}", file=sys.stderr)
        return 1

    writes = parse_pc_trace(trace)
    if not writes:
        print(f"FAIL: no x1 writebacks in {trace}")
        return 1

    final = writes[-1][1]
    plus1 = count_plus1_steps(writes)
    ok = final == expect_final and plus1 <= max_plus1

    print(f"trace: {trace}")
    print(f"x1 writes: {len(writes)}  values: {[w[1] for w in writes]}")
    print(f"final x1: {final} (expect {expect_final})")
    print(f"+1 steps: {plus1} (max allowed {max_plus1})")
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
