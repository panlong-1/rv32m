#!/usr/bin/env python3
"""open_rv32m regression driver.

This follows the same high-level model as wujian100_open/tools/run_case:
clean/create a work area, compile software cases, build the simulator,
run cases, then emit per-case logs and a summary report.
"""

import argparse
import datetime as _dt
import os
import shutil
import subprocess
import sys
from collections import namedtuple
from pathlib import Path


Case = namedtuple("Case", ["name", "kind", "source", "max_cycles"])


def run(cmd, cwd, log=None, env=None):
    print("+ " + " ".join(cmd))
    if log is None:
        return subprocess.call(cmd, cwd=str(cwd), env=env)

    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as fh:
        proc = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            bufsize=1,
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            sys.stdout.write(line)
            fh.write(line)
        return proc.wait()


def load_cases(path):
    cases = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 4:
            raise ValueError(f"Bad case line in {path}: {raw}")
        cases.append(Case(parts[0], parts[1], parts[2], int(parts[3])))
    return cases


def write_verdi_index(root: Path, result_dir: Path) -> None:
    """Emit an index helper that opens any per-case open_verdi.sh."""
    script = result_dir / "open_verdi.sh"
    body = f"""#!/usr/bin/env bash
set -euo pipefail
RESULT_DIR="{result_dir}"
case_name="${{1:-}}"
if [[ -z "$case_name" ]]; then
  echo "Usage: $0 <case-name>" >&2
  echo "Available cases:" >&2
  find "$RESULT_DIR" -mindepth 3 -maxdepth 3 -name open_verdi.sh -printf '  %h\\n' | sed "s#^$RESULT_DIR/##" >&2
  exit 2
fi
helper=$(find "$RESULT_DIR" -mindepth 3 -maxdepth 3 -path "*/$case_name/open_verdi.sh" | head -1)
if [[ -z "$helper" ]]; then
  echo "No open_verdi.sh found for case: $case_name" >&2
  exit 1
fi
exec "$helper"
"""
    script.write_text(body, encoding="utf-8")
    script.chmod(0o755)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run open_rv32m regression")
    parser.add_argument("--target", choices=["core", "ahb", "soc"], default="soc")
    parser.add_argument("--sim", choices=["vcs", "verilator"], default="verilator")
    parser.add_argument(
        "--case-list",
        default=None,
        help="Case list file (default: regress/cases/<target>.list)",
    )
    parser.add_argument("--case", action="append", dest="case_filter", help="Run only this case name")
    parser.add_argument("--waves", action="store_true", help="Pass +vcd to simv")
    parser.add_argument(
        "--fsdb",
        action="store_true",
        help="Build with Verdi PLI and dump FSDB per case (+fsdb +fsdbfile=...); set VERDI_HOME",
    )
    parser.add_argument("--trace", action="store_true", help="Pass +trace to simv")
    parser.add_argument("--pc-trace", action="store_true", help="Write per-case pc_trace.tsv from the testbench")
    parser.add_argument(
        "--pc-trace-each-cycle",
        action="store_true",
        help="With --pc-trace, write one row every clock instead of only when PC changes",
    )
    parser.add_argument("--dc", action="store_true", help="Run Design Compiler after simulation")
    parser.add_argument("--keep", action="store_true", help="Keep existing per-case directories")
    args = parser.parse_args()

    if args.fsdb and args.sim == "verilator":
        print("ERROR: --fsdb requires VCS/Verdi; use --sim vcs or drop --fsdb.", file=sys.stderr)
        return 2

    root = Path(__file__).resolve().parents[2]
    env = os.environ.copy()
    env["RV32M_SIMULATOR"] = args.sim
    project_root = root.parent
    env.setdefault("TOOLCHAIN", str(project_root / "riscv_toolchain" / "bin"))
    env.setdefault("PREFIX", "riscv64-unknown-elf-")
    env["PATH"] = env["TOOLCHAIN"] + os.pathsep + env.get("PATH", "")

    sim_target = args.target
    if sim_target in ("core", "ahb"):
        print(f"NOTE: --target {sim_target} is deprecated; running TORV SoC (soc).")
        sim_target = "soc"

    case_list = args.case_list or f"regress/cases/{args.target}.list"
    case_list_path = root / case_list
    if not case_list_path.is_file():
        print(f"ERROR: case list not found: {case_list_path}", file=sys.stderr)
        return 2

    stamp = _dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    result_dir = root / "regress" / "results" / stamp
    target_dir = result_dir / sim_target
    target_dir.mkdir(parents=True, exist_ok=True)

    print(f"Case list: {case_list}")
    cases = load_cases(case_list_path)
    if args.case_filter:
        wanted = set(args.case_filter)
        cases = [c for c in cases if c.name in wanted]
    if not cases:
        raise RuntimeError("No cases selected")

    summary: list[tuple[str, str, str]] = []

    if args.fsdb:
        env["RUN_FSDB"] = "1"
    if args.waves:
        env["RV32M_WAVE_VCD"] = "1"
    if args.trace:
        env["RV32M_TRACE"] = "1"
    if args.pc_trace or args.pc_trace_each_cycle:
        env["RV32M_PC_TRACE"] = "1"
    if args.pc_trace_each_cycle:
        env["RV32M_PC_TRACE_EACH_CYCLE"] = "1"

    for case in cases:
        if sim_target == "soc" and case.kind == "builtin":
            summary.append((case.name, "SKIP", "builtin is legacy Harvard TB only"))
            continue

        print(f"\n=== CASE {case.name} ({case.kind}) ===")
        case_dir = target_dir / case.name
        if case_dir.exists() and not args.keep:
            for child in case_dir.iterdir():
                if child.is_dir():
                    shutil.rmtree(child)
                else:
                    child.unlink()
        case_dir.mkdir(parents=True, exist_ok=True)

        if case.kind == "builtin":
            summary.append((case.name, "SKIP", "builtin removed; use TORV asm tests (soc.list)"))
            continue
        if case.kind == "asm":
            case_env = env.copy()
            case_env["BUILD_DIR"] = str(case_dir)
            case_env["MAX_CYCLES"] = str(case.max_cycles)
            case_env["RV32M_KEEP_BUILD"] = "1"
            if args.pc_trace or args.pc_trace_each_cycle:
                case_env["RV32M_PC_TRACE_FILE"] = str(case_dir / "pc_trace.tsv")
            cmd = [
                str(root / "scripts/run_case.sh"),
                "--target",
                sim_target,
                "--sim",
                args.sim,
                str(root / case.source),
            ]
            rc = run(cmd, root, case_dir / "run_case.log", case_env)
            ok = rc == 0
        else:
            summary.append((case.name, "FAIL", f"unknown case type {case.kind}"))
            continue

        summary.append((case.name, "PASS" if ok else "FAIL", str(case_dir)))

    if args.dc:
        rc = run([str(root / "scripts/dc_build.sh")], root, result_dir / "dc_build.log", env)
        summary.append(("dc", "PASS" if rc == 0 else "FAIL", str(result_dir / "dc_build.log")))

    write_verdi_index(root, result_dir)
    write_summary(result_dir, summary)
    failed = [row for row in summary if row[1] == "FAIL"]
    print(f"\nResult directory: {result_dir}")
    print(f"Summary: {result_dir / 'summary.rpt'}")
    print(f"Per-case directories: {target_dir}/<case>")
    print(f"Verdi helper: {result_dir / 'open_verdi.sh'} <case>")
    if args.fsdb:
        print("FSDB: see regress/results/.../<target>/<case>/<case>.fsdb")
    perf_script = root / "scripts" / "perf_summary.py"
    if perf_script.is_file() and not failed:
        perf_csv = result_dir / "perf_summary.csv"
        run(
            [sys.executable, str(perf_script), str(result_dir), "--csv", str(perf_csv)],
            root,
            result_dir / "perf_summary.log",
            env,
        )
        print(f"PERF CSV: {perf_csv}")
    return 1 if failed else 0


def write_summary(result_dir, summary):
    result_dir.mkdir(parents=True, exist_ok=True)
    lines = ["case,status,detail"]
    lines += [",".join(row) for row in summary]
    (result_dir / "summary.rpt").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
