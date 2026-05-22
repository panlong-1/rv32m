# RV32IM 5-Stage Pipelined CPU Current Implementation Specification

This document is the Markdown specification for the RTL currently present under `open_rv32m/rtl`. It replaces the older docx architecture description as the working implementation reference. The original docx described a broader target architecture; this file records what is implemented now, what has been verified, and what remains provisional.

## 1. Scope

The current core is a 32-bit in-order RISC-V core with a classic five-stage pipeline:

- IF: instruction fetch through `IBUS`
- ID: decode, register read, immediate generation, hazard decision
- EX: ALU, branch target/condition, JAL/JALR target, RV32M result generation
- MEM: load/store routing through `DBUS` or `SBUS`
- WB: ALU/load/PC+4 writeback to the integer register file

The top-level module is `rv32im_core`.

The implementation is intended for simulation and early synthesis exploration. It is not yet a production-ready ASIC microarchitecture.

## 2. Implemented ISA Subset

### 2.1 RV32I Integer Instructions

The decoder recognizes these opcode classes:

- R-type: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLT`, `SLTU`, `SLL`, `SRL`, `SRA`
- I-type ALU: `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLTIU`, `SLLI`, `SRLI`, `SRAI`
- Loads: `LB`, `LH`, `LW`, `LBU`, `LHU`
- Stores: `SB`, `SH`, `SW`
- Branches: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- Jumps: `JAL`, `JALR`
- Upper immediates: `LUI`, `AUIPC`

Unsupported opcodes assert the internal decoder `illegal` signal, but there is no exception, trap, CSR, or architectural error handling path.

### 2.2 RV32M Instructions

The decoder identifies RV32M when `opcode == 7'b0110011` and `funct7 == 7'b0000001`.

The implemented operations are:

- `MUL`: low 32 bits of signed x signed product
- `MULH`: high 32 bits of signed x signed product
- `MULHSU`: high 32 bits of signed x unsigned product
- `MULHU`: high 32 bits of unsigned x unsigned product
- `DIV`: signed quotient
- `DIVU`: unsigned quotient
- `REM`: signed remainder
- `REMU`: unsigned remainder

RISC-V divide corner cases are implemented:

- Divide by zero:
  - `DIV`/`DIVU` return `32'hFFFF_FFFF`
  - `REM`/`REMU` return the dividend
- Signed overflow `32'h8000_0000 / 32'hFFFF_FFFF`:
  - `DIV` returns `32'h8000_0000`
  - `REM` returns `0`

Current implementation note: `muldiv_unit` uses one shared combinational 33x33 multiplier for `MUL*`. `DIV/REM` use a multi-cycle restoring divider. `busy` stalls the pipeline while the divider iterates, and `ready` releases the result for EX/MEM capture.

## 3. Top-Level Interface

`rv32im_core` has three Harvard-style external buses.

### 3.1 IBUS

IBUS is used only for instruction fetch.

- `ibus_valid`: always asserted in the current implementation
- `ibus_ready`: stalls PC and front-end when low
- `ibus_addr`: current PC
- `ibus_rdata`: fetched instruction word

Instruction fetch is little-endian in the simulation memory model.

### 3.2 DBUS

DBUS is used for ordinary data memory accesses.

- `dbus_valid`: asserted for load/store when `addr_decode` selects DBUS
- `dbus_ready`: stalls the pipeline when a DBUS transaction is pending and not ready
- `dbus_addr`: byte address
- `dbus_we`: store enable
- `dbus_be`: byte enables
- `dbus_wdata`: store data aligned to byte lanes
- `dbus_rdata`: read data word

### 3.3 SBUS

SBUS is used for MMIO/system/debug regions.

- `sbus_valid`: asserted for load/store when `addr_decode` selects SBUS
- `sbus_ready`: stalls the pipeline when an SBUS transaction is pending and not ready
- `sbus_addr`: byte address
- `sbus_we`: store enable
- `sbus_be`: byte enables
- `sbus_wdata`: store data aligned to byte lanes
- `sbus_rdata`: read data word

The LSU drives exactly one of `dbus_valid` or `sbus_valid` for an active memory operation.

## 4. Address Map

`addr_decode` selects SBUS for:

- `0x4000_0000` through `0x4FFF_FFFF`
- `0xF000_0000` through `0xFFFF_FFFF`

All other load/store addresses use DBUS.

IBUS is independent and always uses the PC value as the instruction address.

## 5. Pipeline Registers

The implementation contains explicit pipeline state:

- IF/ID: `pc`, `inst`, `pc_plus4`
- ID/EX: PC, PC+4, immediate, rs1/rs2 data, rs1/rs2/rd addresses, funct fields, opcode, control bits
- EX/MEM: register write, memory controls, writeback select, rd, ALU/MULDIV result, store data, PC+4, load/store `funct3`
- MEM/WB: register write, rd, ALU result, load result, writeback select, PC+4

The inserted bubble instruction is `ADDI x0, x0, 0` (`32'h0000_0013`).

## 6. Control and Decode

`decoder.sv` generates:

- `reg_write`
- `mem_read`
- `mem_write`
- `wb_sel`
- `alu_src`
- `alu_op`
- `branch`
- `jump`
- `imm_type`
- `muldiv`
- `is_lui`
- `is_auipc`
- `is_jalr`
- `illegal`

Writeback select encoding:

- `2'b00`: ALU/MULDIV result
- `2'b01`: load data
- `2'b10`: PC+4 for `JAL` and `JALR`

Immediate types:

- I-type: `{{20{inst[31]}}, inst[31:20]}`
- S-type: `{{20{inst[31]}}, inst[31:25], inst[11:7]}`
- B-type: `{{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0}`
- U-type: `{inst[31:12], 12'b0}`
- J-type: `{{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0}`

## 7. Execute Stage

### 7.1 ALU

`alu.sv` implements:

- Add/subtract
- Bitwise AND/OR/XOR
- Signed and unsigned set-less-than
- Logical/arithmetic shifts
- Pass-through B for `LUI`

The ALU is structured following the `sm-LN.pdf` datapath notes:

- ADD/SUB share one add-sub datapath. SUB is implemented as `a + ~b + 1`.
- `SLT` and `SLTU` reuse the subtract result rather than instantiating independent comparators.
- Unsigned less-than uses the subtract carry-out.
- Signed less-than uses operand sign comparison plus the subtract result sign.
- Shift operations use an explicit five-stage 32-bit barrel shifter controlled by `b[4:0]`.
- `zero` is produced as a zero detector on the selected ALU result.

`AUIPC` uses `id_ex_pc` as ALU operand A. `LUI` selects pass-through B and writes the U-type immediate.

### 7.2 RV32M Unit

`muldiv_unit.sv` implements RV32M with separate multiplier and iterative divider paths.

Multiplier:

- A single 33x33 signed multiplier is shared by `MUL`, `MULH`, `MULHSU`, and `MULHU`.
- Operand extension is selected by operation:
  - signed x signed for `MUL`/`MULH`
  - signed x unsigned for `MULHSU`
  - unsigned x unsigned for `MULHU`
- `MUL` remains single-cycle from the pipeline point of view.

Divider:

- `DIV`, `DIVU`, `REM`, and `REMU` use a 32-cycle restoring division core.
- Signed operations convert operands to absolute values, run the unsigned divider, then restore quotient/remainder signs.
- Divide-by-zero and signed-overflow corner cases are detected up front and complete without running the 32-cycle iteration.
- `busy` is asserted while the divider is active.
- `ready` marks the cycle where the result can be captured by the EX/MEM pipeline register.

### 7.3 Branch and Jump

Branches are resolved in EX.

Implemented branch conditions:

- `BEQ`: `rs1 == rs2`
- `BNE`: `rs1 != rs2`
- `BLT`: signed `<`
- `BGE`: signed `>=`
- `BLTU`: unsigned `<`
- `BGEU`: unsigned `>=`

Target generation:

- Branch/JAL: `id_ex_pc + id_ex_imm`
- JALR: `(rs1 + imm) & 32'hFFFF_FFFE`

Taken branches and jumps flush IF/ID and ID/EX when the pipeline is not stalled on that stage.

## 8. Memory Stage

`lsu.sv` supports byte-enable generation and aligned write data for:

- `SB`: single byte enable based on `addr[1:0]`
- `SH`: halfword byte enable based on `addr[1]`
- `SW`: all byte lanes enabled

Load data extension is performed in `rv32im_core`:

- `LB`: sign-extend selected byte
- `LH`: sign-extend selected halfword
- `LW`: full word
- `LBU`: zero-extend selected byte
- `LHU`: zero-extend selected halfword

Misaligned access exceptions are not implemented. The current logic selects byte or halfword lanes from the returned word according to low address bits.

## 9. Hazard Handling

`forwarding_unit.sv` implements forwarding into EX:

- EX/MEM to EX when the EX/MEM instruction writes a register and is not a load
- MEM/WB to EX when the MEM/WB instruction writes a matching register
- `x0` is never forwarded as a writable destination

`hazard_unit.sv` handles:

- IF/ID source-use decoding
- load-use bubble insertion when ID/EX is a load used by IF/ID
- IBUS wait-state stall
- DBUS/SBUS wait-state stall
- branch/jump flush (`flush = ex_branch_taken && !stall_mem`)
- `div_busy` from multi-cycle divide in EX

`stall_mem` is **only** `mem_bus_stall` (DBUS/SBUS wait). `div_busy` stalls the front end via `stall_front`, not MEM — so MEM/WB can drain while divide runs in EX.

`rv32im_core` masks `dbus_valid` / `sbus_valid` after a completed handshake while `stall_ex_mem` is active (`dbus_completed` / `sbus_completed`). This prevents the AHB bridge from re-issuing the same store when EX/MEM is held for IBUS stall or other front-end stalls (AHB memory-replay fix).

Priority in the current combinational hazard logic is:

1. MEM bus stall (full pipeline hold; **no flush** while active)
2. Taken branch/jump flush (only when not in item 1)
3. ID/EX load-use bubble
4. Front-end stall (`ibus_stall`, `load_use`, `div_busy`, etc.)
   - `stall_id_ex` is always asserted in item 4
   - If the pending DBUS/SBUS beat is not done: hold EX/MEM
   - Else if completed beat is a load: allow EX/MEM to advance into MEM/WB so load-use consumers can release
   - Else if completed beat is a store during `ibus_stall`: bubble EX/MEM after `rv32im_core` masks valid to avoid replay
   - Else if `ibus_stall`: hold EX/MEM
   - Else: bubble EX/MEM for a completed beat while the front end is stalled

`rv32im_core` complements the hazard unit:

- IF/ID and ID/EX flush only when `flush && !stall_if_id` / `flush && !stall_id_ex`
- MEM/WB captures EX/MEM only when `!stall_ex_mem && !bubble_ex_mem` (no writeback on bubble cycles)

Directed bus-overlap tests (require testbench plusargs in `tests/core/asm/*.plusargs`):

- `hazard_branch_mem_stall.S` — taken branch in EX while SBUS store stalls MEM (`+stall_sbus_writes`)
- `hazard_ibus_store_dup.S` — IBUS stall during store in MEM (`+stall_ibus_during_mem_write`)
- `hazard_sbus_replay_smoke.S` — IBUS stall during one TORV UART store at `0x4000_1000`; TB checks `+replay_expect=1`

The core also includes a WB-to-ID register read bypass in `rv32im_core`. This models write-first register file behavior for same-cycle writeback/decode dependencies and avoids X propagation when an instruction in ID reads the register being written in WB.

### 9.1 TORV SoC simulation top

`torv_soc_top` wraps `rv32im_ahb_top` (three `rv32im_ahb_bridge` masters) plus `torv_ahb_sram` for IMEM/DBUS/SBUS SRAM and the APB UART peripheral window.

Peripheral window `0x4000_1000`–`0x4000_1FFF` uses third-party IP only (see `ip/README.md`):

- [shalan/SoCBUS](https://github.com/shalan/SoCBUS) `AHB_APB_BRIDGE`
- [pulp-platform/apb_uart_sv](https://github.com/pulp-platform/apb_uart_sv) on APB

Tests: `tests/periph/<ip>/` (currently `apb_uart_sv/`). Unified entry: `./scripts/run_case.sh …`, `./scripts/regress.sh` (default list `regress/cases/soc.list`).

## 10. Register File

`regfile.sv` implements:

- 32 architectural registers
- two asynchronous read ports
- one synchronous write port
- `x0` hardwired to zero by read muxing and ignored writes

The physical storage is `mem[31:1]`; there is no reset initialization for x1 through x31.

## 11. Verification Status

The current self-checking Verilator/VCS testbench is `sim/tb_torv_soc.sv`.

It provides:

- byte-addressed instruction memory
- byte-addressed DBUS memory
- byte-addressed SBUS memory
- little-endian instruction/data read model
- byte-enable-aware DBUS/SBUS writes
- optional VCD dump with `+vcd`
- optional trace with `+trace`
- optional external memory images with `+imem=<file>` and `+dmem=<file>`
- `TOHOST_ADDR = 32'hF000_0000` for program-controlled pass/fail when using external hex images

Built-in self-checks currently cover:

- `ADDI` dependency chain with forwarding/writeback
- `MUL` result generation

Toolchain-driven assembly tests currently cover:

- smoke control-flow and arithmetic (`tests/core/asm/smoke.S`)
- directed ALU add/sub/logic/compare/shift behavior (`tests/core/asm/alu.S`)
- RV32M multiply/divide/remainder including corner cases (`tests/core/asm/muldiv.S`)
- load-use, load-branch, byte/halfword load extension, and load-to-store-data hazards (`tests/core/asm/hazard.S`)
- branch flush vs MEM bus stall (`tests/core/asm/hazard_branch_mem_stall.S`)
- IBUS stall vs store / ID/EX freeze (`tests/core/asm/hazard_ibus_store_dup.S`)
- SBUS replay smoke with non-idempotent peripheral model (`tests/core/asm/hazard_sbus_replay_smoke.S`)

TORV SoC Verilator regression (`regress/cases/soc.list`): **29** asm cases (core directed/perf plus `tests/periph/apb_uart_sv/*`).

Current observed result:

```text
regress/results/20260523_031941/summary.rpt
PASS 29
```

The tests do not yet cover all supported instruction forms, divide/remainder corner cases, randomized bus wait states, or long C-program execution.

## 12. Synthesis Status

The Design Compiler flow is under `open_rv32m/dc`.

Files:

- `dc/scripts/run_dc.tcl`
- `dc/constraints.sdc`
- `scripts/dc_build.sh`
- `dc/PDK_setup.txt`

The local TSMC 0.13 µm setup is expected to use:

```bash
export TSMC013_TARGET_LIB=$HOME/PDK/TSMC_013/synopsys/slow.db
cd open_rv32m   # or your clone path
./scripts/dc_build.sh
```

Current DC status:

- `dc_shell` successfully reads RTL and the TSMC slow library.
- `compile_ultra` completes after replacing combinational DIV/REM with the iterative divider.
- `dc/outputs/rv32im_core_mapped.v` is generated.
- At `slow.db` with a 10 ns clock constraint, reported WNS/TNS are 0.
- Reported total cell area is approximately `131030.79`.

Most area remains in `regfile` and `muldiv_unit`; further work should decide whether the multiplier should be pipelined, sequential, or mapped to a macro.

## 13. Current Module List

RTL modules:

- `rv32im_core.sv`
- `pc_unit.sv`
- `regfile.sv`
- `decoder.sv`
- `imm_gen.sv`
- `alu_control.sv`
- `alu.sv`
- `muldiv_unit.sv`
- `forwarding_unit.sv`
- `hazard_unit.sv`
- `addr_decode.sv`
- `lsu.sv`
- `bus_if.sv`

`bus_if.sv` currently contains typedef-only bus bundle definitions and is included in the VCS file list. The DC script omits it from analysis because it has no synthesizable module.

## 14. Known Limitations

- No exceptions, interrupts, privilege modes, or CSRs.
- No trap handling for illegal instructions.
- No misaligned memory exception handling.
- No memory protection, cache, MMU, or bus error handling.
- `ibus_valid` is permanently asserted.
- Register file nonzero registers are not reset.
- Built-in simulation tests are still minimal.
- ASIC synthesis timing/area are first-pass only and still use ideal clocks/no extracted interconnect.

## 15. Recommended Next Steps

1. Add self-checking tests for all implemented RV32I instructions, including `JAL`, `JALR`, `AUIPC`, all branch types, and byte/halfword loads/stores.
2. Add divide/remainder corner-case tests.
3. Decide whether RV32M divide/remainder should be multi-cycle RTL, DesignWare, or a macro.
4. Add a synthesis configuration that can stub DIV/REM for quick top-level timing exploration.
5. Decide whether unsupported instructions remain NOP-like/ignored or gain a trap path in a later milestone.
