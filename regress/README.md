# rv32m Regression

回归入口：

```bash
cd /home/ic/project
source rv
cd rv32m
./scripts/regress.sh
```

`scripts/regress.sh` 是 wrapper，实际调用 `regress/bin/run_regress.py`。

## Target

- `--target core`：默认，使用 `sim/tb_rv32im_top.sv`。
- `--target ahb`：使用 `sim/tb_rv32im_ahb_top.sv` + `sim/ahb_sram_model.sv`。
- `--target soc`：预留。

AHB 模式跳过 `builtin`，其余 asm case 与 core 共用 `regress/cases/core.list`。

## 命令

```bash
./scripts/regress.sh
./scripts/regress.sh --target ahb
./scripts/regress.sh --case alu
./scripts/regress.sh --target ahb --case sbus
./scripts/regress.sh --fsdb
./scripts/regress.sh --waves
./scripts/regress.sh --pc-trace
./scripts/regress.sh --pc-trace-each-cycle
./scripts/regress.sh --trace
```

`sim/Makefile` 快捷入口：

```bash
cd sim
make regress
make regress-one CASE=alu
make regress-ahb REGRESS_CASE=sbus
make regress PC_TRACE=1 FSDB=1
```

## Case List

默认：

```text
regress/cases/core.list
```

格式：

```text
name type source max_cycles
```

类型：

- `builtin`：core testbench 内置自检。
- `asm`：编译 `tests/core/asm/*.S` 并通过 `+imem=<hex>` 加载。

`max_cycles` 是 watchdog，不是正常 PASS/FAIL 判断。case 应主动写 `0xF0000000`：

```text
1       PASS
non-1   FAIL/error flag
```

## 输出

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt
  open_verdi.sh
  core/
    <case>/
  ahb/
    <case>/
```

每个 case：

```text
<case>/
  <case>.elf
  <case>.hex
  <case>.dump
  <case>.sim.log           # core
  <case>.ahb.sim.log       # AHB
  <case>.fsdb              # --fsdb
  <case>.vcd               # --waves
  pc_trace.tsv             # --pc-trace
  run_case.log
  vcs/
    simv
    compile.log
    csrc/
    simv.daidir/
  open_verdi.sh
```

`summary.rpt`：

```text
case,status,detail
smoke,PASS,/home/ic/project/rv32m/regress/results/.../core/smoke
```

## Verdi

```bash
regress/results/<run>/open_verdi.sh <case>
```

或：

```bash
cd regress/results/<run>/core/smoke
./open_verdi.sh
```

## 最近验证

```text
core: /home/ic/project/rv32m/regress/results/20260513_080708
  builtin + 19 asm PASS

AHB:  /home/ic/project/rv32m/regress/results/20260513_080752
  builtin SKIP
  19 asm PASS
```
