# open_rv32m Simulation

仿真只保留两类入口：

```text
单 case： ./scripts/run_case.sh
回归：    ./scripts/regress.sh
```

`sim/Makefile` 是这两条入口的快捷封装。

## 环境

在项目根目录：

```bash
cd /home/ic/project
source open_rv
cd open_rv32m
```

关键变量：

- `RV32M_ROOT=/home/ic/project/open_rv32m`
- `TOOLCHAIN=/home/ic/project/riscv_toolchain/bin`
- `VCS_HOME`
- `VERDI_HOME` / `NOVAS_HOME`
- `SNPSLMD_LICENSE_FILE`
- `RV32M_FILELIST_CORE`
- `RV32M_FILELIST_AHB`

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
CASE=<asm stem>
ASM=<显式 .S 路径>
FSDB=1 VCD=1 TRACE=1 PC_TRACE=1 PC_TRACE_EACH_CYCLE=1 KDB=1
MAX_CYCLES=N BUILD_DIR=<dir> PC_TRACE_FILE=<file>
REGRESS_CASE=<case>
```

## 单 Case

统一入口：

```bash
./scripts/run_case.sh [options] tests/core/asm/smoke.S
```

常用例子：

```bash
# core，默认不带波形
./scripts/run_case.sh tests/core/asm/alu.S

# core，生成 FSDB
./scripts/run_case.sh --fsdb tests/core/asm/hazard.S

# AHB，生成 FSDB
./scripts/run_case.sh --target ahb --fsdb tests/core/asm/sbus.S

# 指定输出目录
./scripts/run_case.sh --target ahb --fsdb --build-dir build/debug/sbus_ahb tests/core/asm/sbus.S
```

默认输出目录：

```text
build/sim/core/<case>/
build/sim/ahb/<case>/
```

典型内容：

```text
<case>.elf
<case>.hex
<case>.dump
<case>.sim.log           # core
<case>.ahb.sim.log       # ahb
<case>.fsdb              # 使用 --fsdb 时
<case>.vcd               # 使用 --vcd 时
vcs/
  simv
  compile.log
  csrc/
  simv.daidir/
open_verdi.sh
run_case.log             # regress 调用单 case 时生成
```

单 case 选项：

- `--target core|ahb`：选择不带 AHB 的 core testbench，或 AHB 顶层 testbench。
- `--fsdb`：生成 FSDB。
- `--vcd`：生成 VCD。
- `--trace`：传 `+trace` 给 testbench。
- `--pc-trace`：生成 testbench 直接写出的 `pc_trace.tsv`。
- `--pc-trace-file FILE`：指定 PC 轨迹输出路径。
- `--pc-trace-each-cycle`：每拍写一行；默认只在 PC 变化时写。
- `--kdb`：VCS 编译加 KDB，方便 Verdi 跟源码。
- `--max-cycles N`：覆盖最大仿真周期。
- `--build-dir DIR`：覆盖输出目录。

单 case 默认会重建输出目录，避免旧 log 和旧波形混在一起。需要保留目录时可设 `RV32M_KEEP_BUILD=1`。

## 跑回归

统一入口：

```bash
./scripts/regress.sh [options]
```

常用例子：

```bash
# core 全量回归
./scripts/regress.sh

# core 只跑一个 case
./scripts/regress.sh --case alu

# core 回归并给每个 case 生成 FSDB
./scripts/regress.sh --fsdb

# AHB 回归，只跑 sbus，并生成 FSDB
./scripts/regress.sh --target ahb --case sbus --fsdb

# core 只跑 smoke，并生成 pc_trace.tsv
./scripts/regress.sh --case smoke --pc-trace

# core 性能小基准
./scripts/regress.sh --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop

# AHB 性能小基准
./scripts/regress.sh --target ahb --case perf_alu_chain --case perf_branch_loop \
  --case perf_loadstore_loop --case perf_mul_loop
```

默认 case list：

```text
regress/cases/core.list
```

回归输出目录：

```text
regress/results/YYYYMMDD_HHMMSS/
  summary.rpt
  open_verdi.sh
  core/
    <case>/
      <case>.elf
      <case>.hex
      <case>.dump
      <case>.sim.log
      <case>.fsdb
      pc_trace.tsv
      vcs/
      open_verdi.sh
  ahb/
    <case>/
      <case>.elf
      <case>.hex
      <case>.dump
      <case>.ahb.sim.log
      <case>.fsdb
      pc_trace.tsv
      vcs/
      open_verdi.sh
```

说明：

- 每个 case 都有自己的目录，调试时不需要在平铺日志里找文件。
- `summary.rpt` 是本次回归汇总。
- AHB 模式会跳过 `builtin`，因为 `builtin` 只属于 core testbench。

## 性能统计

`tb_rv32im_top` 和 `tb_rv32im_ahb_top` 会在 asm case 写 `tohost=1` 时打印性能摘要。日志里搜索 `[PERF]` 即可：

```text
[PERF] cycles=<N> instr=<N> ipc=<N>
[PERF] type alu=<N> load=<N> store=<N> branch=<N> branch_taken=<N> jump=<N> muldiv=<N> lui_auipc=<N>
[PERF] stall if=<N> id=<N> ex=<N> flush=<N> dbus_r=<N> dbus_w=<N> sbus_r=<N> sbus_w=<N>
```

字段口径：

- `cycles`：复位释放后的时钟周期数，到 PASS 的 tohost 写入为止。
- `instr`：有效非 NOP 指令进入 EX 的次数。当前 core 是 in-order 五级流水，这个值作为 retired 指令数的近似；flush、stall、bubble 和 `addi x0,x0,0` 不计入。
- `ipc`：`instr / cycles`。
- `type`：按 opcode/funct7 粗分类，便于快速判断 workload 构成。
- `stall`：testbench 直接观察 core stall/flush 信号；AHB 模式下这些值能反映 bridge/memory 握手造成的流水停顿。
- `dbus_*` / `sbus_*`：core 模式按 valid/ready 计数，AHB 模式按非 IDLE transfer 计数。

内置性能 case：

| case | 目的 |
|------|------|
| `perf_alu_chain` | 依赖 ALU 链，观察普通数据相关和分支开销 |
| `perf_branch_loop` | 紧分支循环，观察 taken branch / flush 开销 |
| `perf_loadstore_loop` | DBUS load/store 循环，观察访存 stall |
| `perf_mul_loop` | RV32M multiply 循环，观察 M 扩展吞吐 |

快速提取结果：

```bash
rg "\\[PERF\\]" regress/results/<run>/<target>/*/*.sim.log
rg "\\[PERF\\]" regress/results/<run>/<target>/*/*.ahb.sim.log
```

## Case 终止协议

case 不依赖仿真时间判断 PASS/FAIL，而是主动写指定地址：

```text
TOHOST_ADDR = 0xF0000000
write 1     = PASS，testbench 立即 $finish(0)
write != 1  = FAIL/error flag，testbench 立即 $finish(1)
```

`MAX_CYCLES` / `--max-cycles` 只作为 watchdog，防止 case 卡死时仿真无限跑。新增 asm case 建议包含公共宏：

```asm
  .include "tests/core/asm/test_macros.inc"

pass:
  RVTEST_PASS

fail:
  RVTEST_FAIL
```

## PC Trace

不必从 VCD/FSDB 里解析波形：`tb_rv32im_top` / `tb_rv32im_ahb_top` 直接用 `$fopen` / `$fwrite` 写 TSV，供后续 Keil 式工具或脚本做 ELF 反汇编对齐。

入口脚本可直接打开：

```bash
./scripts/run_case.sh --pc-trace tests/core/asm/smoke.S
./scripts/run_case.sh --target ahb --pc-trace tests/core/asm/sbus.S
./scripts/regress.sh --case smoke --pc-trace
```

需要手工调用 `simv` 时，也可以增加 plusarg：

| Plusarg | 含义 |
|---------|------|
| `+pc_trace` | 打开 PC 轨迹文件 |
| `+pc_trace_file=<path>` | 输出路径（默认 `pc_trace.tsv`） |
| `+pc_trace_each_cycle` | 每个时钟周期写一行；**不加**则仅在 **`pc` 变化** 时写（行数更少） |

TSV 列（制表符分隔）：

`time_ps` · `pc_hex` · `ibus_inst_hex`（当前 IBUS 读出的指令字）· `if_id_pc_hex` · `if_id_inst_hex`

示例（在 case 工作目录、`simv` 同目录下跑）：

```bash
./vcs/simv +imem="$PWD/smoke.hex" +max_cycles=5000 \
  +pc_trace +pc_trace_file="$PWD/pc.tsv"
head pc.tsv
```

说明：**`ibus_inst_hex`** 与 **`if_id_inst_hex`** 在流水线上会差一拍，对齐反汇编时以 **`pc_hex` / `if_id_pc_hex`** 与 `objdump` 里地址行为准。

## 波形

VCD：

```bash
./scripts/run_case.sh --vcd tests/core/asm/smoke.S
./scripts/regress.sh --waves
```

FSDB：

```bash
./scripts/run_case.sh --fsdb tests/core/asm/smoke.S
./scripts/regress.sh --fsdb
```

FSDB 编译期需要 Verdi VCS PLI：

```text
$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab
$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a
```

脚本也会尝试 `LINUXAMD64`。

## Verdi

单 case 目录里直接执行：

```bash
cd build/sim/core/alu
./open_verdi.sh
```

回归目录也有一个索引脚本：

```bash
regress/results/<run>/open_verdi.sh alu
```

`open_verdi.sh` 会自动选择：

- core：`$RV32M_FILELIST_CORE`，top 为 `tb_rv32im_top`
- AHB：`$RV32M_FILELIST_AHB`，top 为 `tb_rv32im_ahb_top`
- 如果目录里有 `<case>.fsdb`，自动用 `-ssf`
- 否则如果有 `<case>.vcd`，自动用 `-vcd`
- 如果目录里有 `vcs/simv.daidir`，自动加 `-dbdir`

## 兼容旧入口

旧脚本仍可用，但建议只把它们当兼容层：

- `scripts/toolchain_test.sh`：core 单 case
- `scripts/ahb_toolchain_test.sh`：AHB 单 case
- `tests/core/asm/Makefile`：asm 目录下的旧 Makefile 流程

新调试请优先使用：

```bash
./scripts/run_case.sh ...
./scripts/regress.sh ...
```

## 常见问题

- **没有 FSDB**：确认使用了 `--fsdb`，并检查 `VERDI_HOME` / `NOVAS_HOME` 和 Verdi PLI 路径。
- **Verdi 不能跟源码**：使用 `--kdb` 重新跑单 case 或回归。
- **License 问题**：检查站点的 `SNPSLMD_LICENSE_FILE` 等 license 环境变量。
