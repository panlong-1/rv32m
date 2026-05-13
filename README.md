# open_rv32m

`open_rv32m` 与 `rv32m` 同源，是面向**开源仿真 / 综合工具链**的工程副本（目录名 `open_rv32m`，**独立 Git**）。当前仍以 SystemVerilog RV32IM 五级流水 RTL、VCS/Verdi、DC 为主；后续可在此目录演进 Verilator、Icarus 等流程，而不影响 `rv32m/`。当前重点：RTL 仿真、core/AHB directed case、回归自动化、FSDB/Verdi 调试、基础 DC 综合。

## 当前状态

- ISA：RV32I 子集 + RV32M 乘除法。
- 流水线：IF / ID / EX / MEM / WB。
- 总线：Harvard 风格 `IBUS`、`DBUS`、`SBUS`，并提供 AHB 顶层封装。
- 仿真：VCS。
- 波形：VCD / FSDB，FSDB 通过 Verdi VCS PLI。
- 调试：每个 case 自动生成独立仿真目录和 `open_verdi.sh`。
- PC 轨迹：testbench 直接写 `pc_trace.tsv`，不依赖波形解析。
- 性能统计：asm case PASS 时打印 cycles、指令数、IPC、指令类型、stall/flush 和总线访问计数。
- 回归：core 和 AHB 均支持同一批 asm case。

最近一次验证：

```text
core regress: /home/ic/project/open_rv32m/regress/results/20260513_080708
  builtin + 19 asm: PASS

AHB regress:  /home/ic/project/open_rv32m/regress/results/20260513_080752
  builtin: SKIP
  19 asm: PASS

performance smoke:
  core: /home/ic/project/open_rv32m/regress/results/20260513_173555
  AHB:  /home/ic/project/open_rv32m/regress/results/20260513_173617
  4 perf asm: PASS
```

## 目录架构

```text
/home/ic/project/
  open_rv                    本仓库环境入口：source open_rv
  riscv_toolchain/           RISC-V bare-metal toolchain
  open_rv32m/
    README.md                项目总览和标准流程
    rtl/
      *.sv                   CPU RTL
      filelist.f             VCS RTL filelist，使用 $RV32M_ROOT 路径
    sim/
      Makefile               仿真快捷入口
      SIM_README.md          仿真、波形、PC trace、Verdi 细节
      tb_rv32im_top.sv       core testbench
      tb_rv32im_ahb_top.sv   AHB testbench
      ahb_sram_model.sv      AHB SRAM 模型
      filelists/
        verdi_core.f
        verdi_ahb.f
    tests/core/
      README.md
      link.ld
      asm/
        *.S
        test_macros.inc      PASS/FAIL tohost 宏
    scripts/
      run_case.sh            单 case 统一入口
      regress.sh             regress wrapper
      toolchain_test.sh      core 单 case 兼容入口
      ahb_toolchain_test.sh  AHB 单 case 兼容入口
      vcs_build.sh
    regress/
      README.md
      env.sh                 兼容入口，内部 source /home/ic/project/open_rv
      cases/core.list        core/AHB 共用 case list
      bin/run_regress.py
      results/
    build/sim/               单 case 输出
    dc/
    spec/
```

## 环境

每次进入项目建议先执行：

```bash
cd /home/ic/project
source open_rv
cd open_rv32m
```

`source open_rv` 会设置 `RV32M_ROOT`（指向本目录）、`TOOLCHAIN`、`PREFIX`、`VCS_HOME`、`VERDI_HOME`、`NOVAS_HOME`、`DC_HOME`、`SNPSLMD_LICENSE_FILE`、`RV32M_FILELIST_CORE`、`RV32M_FILELIST_AHB`。

兼容旧习惯：

```bash
cd /home/ic/project/open_rv32m
source regress/env.sh
```

`regress/env.sh` 现在只是 wrapper，会 source `/home/ic/project/open_rv`。

## 标准入口

只推荐记两条入口：

```text
单 case： ./scripts/run_case.sh
回归：    ./scripts/regress.sh
```

`sim/Makefile` 只是薄封装，不另起流程。

## 单 Case 仿真

```bash
# core
./scripts/run_case.sh tests/core/asm/smoke.S

# AHB
./scripts/run_case.sh --target ahb tests/core/asm/sbus.S

# 常用调试
./scripts/run_case.sh --fsdb tests/core/asm/hazard.S
./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S
./scripts/run_case.sh --target ahb --fsdb --pc-trace tests/core/asm/sbus.S
```

默认输出：

```text
build/sim/core/<case>/
build/sim/ahb/<case>/
```

单 case 默认重建输出目录。需要保留旧目录：

```bash
RV32M_KEEP_BUILD=1 ./scripts/run_case.sh tests/core/asm/smoke.S
```

## sim/Makefile

```bash
cd /home/ic/project/open_rv32m/sim

make run CASE=smoke
make ahb CASE=sbus
make run CASE=smoke FSDB=1 PC_TRACE=1
make regress-one CASE=alu
make regress-ahb REGRESS_CASE=sbus PC_TRACE=1
make list
make env
```

常用变量：

```text
TARGET=core|ahb
CASE=<tests/core/asm 下的文件 stem>
ASM=<显式 .S 路径>
FSDB=1 VCD=1 TRACE=1 PC_TRACE=1 PC_TRACE_EACH_CYCLE=1 KDB=1
MAX_CYCLES=N BUILD_DIR=<dir> PC_TRACE_FILE=<file>
REGRESS_CASE=<case>
```

## 回归

```bash
# core 全量
./scripts/regress.sh

# AHB 全量
./scripts/regress.sh --target ahb

# 单 case
./scripts/regress.sh --case alu
./scripts/regress.sh --target ahb --case sbus

# 波形/PC trace
./scripts/regress.sh --fsdb
./scripts/regress.sh --waves
./scripts/regress.sh --pc-trace

# 性能小基准
./scripts/regress.sh --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
./scripts/regress.sh --target ahb --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
```

case list：

```text
regress/cases/core.list
```

这个 list 同时供 core 和 AHB 使用。AHB 模式跳过 `builtin`，跑所有 asm case。

性能 case 已加入默认 list：

```text
perf_alu_chain       依赖 ALU 链，观察普通数据相关和分支开销
perf_branch_loop     紧分支循环，观察 taken branch / flush 开销
perf_loadstore_loop  DBUS load/store 循环，观察访存 stall
perf_mul_loop        RV32M multiply 循环，观察 M 扩展吞吐
```

每个 asm case PASS 前会打印三行 `[PERF]`：

```text
[PERF] cycles=<N> instr=<N> ipc=<N>
[PERF] type alu=<N> load=<N> store=<N> branch=<N> branch_taken=<N> jump=<N> muldiv=<N> lui_auipc=<N>
[PERF] stall if=<N> id=<N> ex=<N> flush=<N> dbus_r=<N> dbus_w=<N> sbus_r=<N> sbus_w=<N>
```

`instr` 的口径是 testbench 观察到的有效非 NOP 指令进入 EX，作为当前 in-order core 的 retired 近似值；被 flush 的指令不计入。

回归输出：

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt
  open_verdi.sh
  core/<case>/
  ahb/<case>/
```

## Case 终止机制

asm case 不靠仿真时间判断 PASS/FAIL，而是主动写固定地址：

```text
TOHOST_ADDR = 0xF0000000
write 1     = PASS
write != 1  = FAIL/error flag
```

core/AHB testbench 都会监控该地址，看到写入后立即 `$finish`。`MAX_CYCLES` 只是 watchdog。

新增 asm case 建议：

```asm
  .include "tests/core/asm/test_macros.inc"

pass:
  RVTEST_PASS

fail:
  RVTEST_FAIL
```

## 产物目录

单 case：

```text
build/sim/<target>/<case>/
  <case>.elf
  <case>.hex
  <case>.dump
  <case>.sim.log 或 <case>.ahb.sim.log
  <case>.fsdb       # 使用 FSDB 时
  <case>.vcd        # 使用 VCD 时
  pc_trace.tsv      # 使用 PC_TRACE 时
  vcs/
    simv
    compile.log
    csrc/
    simv.daidir/
  open_verdi.sh
```

回归：

```text
regress/results/<timestamp>/<target>/<case>/
  同单 case 目录结构
  run_case.log
```

## Verdi

```bash
# 单 case
cd build/sim/core/smoke
./open_verdi.sh

# 回归
regress/results/<timestamp>/open_verdi.sh smoke
```

filelist 使用环境相关路径：

```bash
verdi -nologo -sv -f "$RV32M_FILELIST_CORE" -top tb_rv32im_top
verdi -nologo -sv -f "$RV32M_FILELIST_AHB"  -top tb_rv32im_ahb_top
```

`open_verdi.sh` 会自动加载对应 top、filelist、`vcs/simv.daidir`、FSDB/VCD。

## PC Trace

```bash
./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S
./scripts/regress.sh --case smoke --pc-trace
```

输出 `pc_trace.tsv`：

```text
time_ps  pc_hex  ibus_inst_hex  if_id_pc_hex  if_id_inst_hex
```

后续做 Keil 式工具时，可以用 ELF/objdump 地址对齐 `pc_hex` 或 `if_id_pc_hex`。

## Design Compiler

```bash
source /home/ic/project/open_rv
cd /home/ic/project/open_rv32m
make -C dc
```

或：

```bash
./scripts/dc_build.sh
```

主要输出：

```text
dc/logs/dc.log
dc/reports/qor.rpt
dc/reports/timing_max.rpt
dc/reports/area.rpt
dc/outputs/rv32im_core_mapped.v
```

## 子文档

- 仿真细节：[sim/SIM_README.md](sim/SIM_README.md)
- 回归细节：[regress/README.md](regress/README.md)
- directed case：[tests/core/README.md](tests/core/README.md)
- 当前实现说明：[spec/RV32IM_Current_Implementation.md](spec/RV32IM_Current_Implementation.md)
