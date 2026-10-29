# Contributing to TORV

TORV is maintained by the ASIC Task Force of [SemiTO-V](https://semitov.github.io)
(`@semitov/asic-task-force`). Contributions from team members and from outside are welcome.

## Getting started

1. Set up the open-source tools by following [docs/open_source_flow.md](docs/open_source_flow.md)
   (RISC-V GNU toolchain, Verilator, IHP SG13G2 PDK, LibreLane).
2. From the repository root:

   ```bash
   ./scripts/fetch_ip.sh        # third-party IP into ip/third_party/
   source scripts/env.sh        # sets TORV_* and tool paths
   ./scripts/regress.sh         # full regression, must end with all cases PASS
   ```

3. Per-machine paths go in `scripts/env.local.sh` (copy `scripts/env.local.sh.example`);
   that file is gitignored.

## Workflow

- `main` is always green. Never push to it directly; every change goes through a pull request.
- Branch from `main` and name the branch `<type>/<short-topic>`:
  `feat/`, `fix/`, `perf/`, `flow/`, `test/`, `docs/`, `ci/`, `refactor/`
  (for example `fix/sbus-replay`, `perf/booth-mul`).
- Keep pull requests small and focused; split refactors from functional changes.
- A pull request needs one approving review from a code owner and green CI (`lint`, `regress`).
- Pull requests are squash-merged, so the PR title must follow the commit format below.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<scope>): <imperative summary, at most 72 characters, no period>

<optional body: what and why; for timing/area changes include the QoR delta>

<optional footer: Fixes #12>
```

- Types: `feat`, `fix`, `perf`, `flow`, `test`, `docs`, `ci`, `refactor`, `chore`.
- Scopes: `core`, `alu`, `muldiv`, `hazard`, `fwd`, `lsu`, `bus`, `soc`, `sram`, `uart`, `tb`,
  `regress`, `librelane`, `sdc`, `env`.
- Examples:
  - `perf(core): register the forwarding selects`
  - `fix(bus): stop IBUS duplicating an instruction under stall_front`
  - `flow(librelane): enable post-GRT resizer timing repair`

## What a change must include

- **RTL change:** the full regression passes; new behaviour has a directed test in
  `tests/core/asm/` (or `tests/periph/`) listed in `regress/cases/soc.list`; a bug fix adds a case
  that reproduces the bug.
- **RTL or flow change:** run `make -C librelane synth` and put the QoR delta (cell area, cell count,
  WNS/TNS per corner) in the PR description.
- **User-visible change:** update the docs and add a line under *Unreleased* in `CHANGELOG.md`.

## RTL conventions

- SystemVerilog, one module per file, file name = module name.
- Every module carries the `torv_` prefix (`torv_alu`, not `alu`). Third-party IP under
  `ip/third_party/` keeps its own names and is never edited in place.
- `always_ff` / `always_comb`, no latches; active-low reset (`hresetn` on AHB, `rst_ni` elsewhere).
- Instances `u_<name>`, generate blocks `g_<name>`, parameters `UPPER_CASE`,
  signals `lower_snake_case`.
- New internal ports use `_i` / `_o` suffixes; AMBA ports keep their standard names
  (`haddr`, `htrans`, `hready`, ...).
- Keep instance names stable: testbenches, trace scripts and `librelane/figures/placement_map.py`
  use hierarchical paths such as `u_cpu.u_core.u_rf`.
- English comments that explain *why*.

## Repository content

- Do not commit build or run output (`build/`, `regress/results/`, `librelane/runs/`, waveforms,
  GDS/DEF/netlists). Large results go to GitHub Release assets.
- Only open PDKs and open-licensed IP. Never commit anything under NDA (commercial PDKs, standard-cell
  libraries, vendor tool files). If unsure, ask a maintainer before pushing.

## Versions

Annotated SemVer tags `vMAJOR.MINOR.PATCH`, created by maintainers on `main` only and never moved.
Tags before `v0.8.0` (`v0.1-baseline` ... `v0.7.1-readme-figs`) predate the rename from `rv32m` and
keep their original names.

## Questions

Open an issue, or ask in the SemiTO-V ASIC Task Force channel.
