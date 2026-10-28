# RV32IM 5-Stage Pipelined CPU Current Implementation Specification

This document is the specification for the RTL currently in `rtl/`. It records what is implemented now, what has been verified, and what remains provisional. It reflects tag `v0.7-open-flow`.

## 1. Scope

The current core is a 32-bit in-order RISC-V core with a classic five-stage pipeline:

- IF: instruction fetch through `IBUS`
- ID: decode, register read, immediate generation, hazard decision
- EX: ALU, AGU, branch target/condition, JAL/JALR target, RV32M result generation, AHB address phase for loads/stores
- MEM: AHB data phase for loads/stores (`DBUS` or `SBUS`), load data extension
- WB: writeback of the pre-selected result to the integer register file

Module hierarchy:

- `rv32im_core` — the pipeline, with valid/ready-style IBUS/DBUS/SBUS ports (§3).
- `rv32im_ahb_top` — `rv32im_core` plus three pipelined AHB-Lite masters: `rv32im_ahb_fetch` (IBUS) and two `rv32im_ahb_dport` (DBUS, SBUS). This is the block implemented with LibreLane (§12).
- `torv_soc_top` — the TORV SoC: `rv32im_ahb_top`, three `torv_ahb_sram` (IHP SRAM macros), SoCBUS `AHB_APB_BRIDGE` and the PULP UART (§9.1).

The implementation is verified in simulation and taken through an open-source RTL-to-GDS flow on IHP SG13G2. It is not yet a production-ready ASIC microarchitecture (no traps, CSRs or bus error handling).

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

Current implementation note: `muldiv_unit` computes `MUL*` in two EX cycles with one shared 33x33 multiplier (operand registers, then multiply). `DIV/REM` use a multi-cycle restoring divider. The hazard unit holds the front end while either is not `ready` (§7.2, §9).

## 3. Core Interface (`rv32im_core`)

`rv32im_core` has three Harvard-style buses. `rv32im_ahb_top` turns each one into an AHB-Lite master. On the data buses, the address-phase signals come from EX and the data-phase signals belong to MEM.

### 3.1 IBUS

IBUS is used only for instruction fetch.

- `ibus_next_addr`: PC of the next cycle (`stall_pc ? pc : pc_next`). `rv32im_ahb_fetch` issues it as the AHB address phase, with `HTRANS = NONSEQ` whenever `HREADY` is high.
- `ibus_addr`: current PC. Its data phase is the current cycle.
- `ibus_ready`: the fetched word for `ibus_addr` is valid. It is HREADY, no error, and a data-phase address that matches the PC. When low, the PC holds and IF/ID gets a bubble.
- `ibus_rdata`: fetched instruction word (HRDATA).

One instruction is fetched per cycle from a zero-wait slave.

### 3.2 DBUS / SBUS

DBUS carries ordinary data memory accesses. SBUS carries the SoC system/MMIO window and `tohost` (§4). The two ports have the same signals:

- `*_valid`: address phase (EX). Asserted for a load/store routed to this bus, and only while the other data bus is ready (§9).
- `*_addr`, `*_we`, `*_be`: address-phase byte address (from the AGU), write enable and byte enables. `rv32im_ahb_dport` converts `be` into `HSIZE`.
- `*_ready`: bus HREADY. A load/store in EX, or an active data phase with `*_ready` low, freezes the pipeline (`bus_stall`).
- `*_dph`: from the AHB port; an accepted address phase is now in its data phase.
- `*_wdata`: data-phase store data, aligned to byte lanes (from `ex_mem_store_data`).
- `*_rdata`: data-phase read data (HRDATA).

The LSU drives at most one of `dbus_valid` or `sbus_valid` for an active memory operation.

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
- Forwarding selects `forward_a` / `forward_b` (registered alongside ID/EX, §9)
- EX/MEM: register write, memory controls, writeback select, rd, ALU/MULDIV result, byte-lane store data, PC+4, load/store `funct3`, `use_sbus_exmem` (which bus the data phase belongs to)
- MEM/WB: register write, rd, `mem_wb_result` (load data, ALU result or PC+4, selected in MEM)

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
- `MUL*` takes two cycles in EX. In the first cycle the extended operands and the high/low select are registered (`mul_a_r`, `mul_b_r`, `mul_hi_r`). In the second cycle the product is computed from those registers and `ready` is asserted. This keeps the forwarding muxes and the multiplier in different register-to-register paths.
- LibreLane synthesizes the multiplier with Yosys' Booth pass (`SYNTH_MUL_BOOTH`).

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

Taken branches and jumps flush IF/ID and ID/EX when the pipeline is not stalled on that stage, so a taken branch or jump costs two cycles. There is no branch prediction (fall-through fetch).

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

The forwarding selects are registered: `rv32im_core` evaluates `forwarding_unit` on the next-state values of the ID/EX source fields and the EX/MEM and MEM/WB `rd`/write-enable fields, and registers `forward_a`/`forward_b`. This is cycle-identical to the combinational decision (a simulation-only check, `u_fwd_chk`, stops the run on any mismatch) and keeps the register-number compare out of the EX operand → branch target / AGU → AHB output paths. MEM/WB holds a single pre-selected `mem_wb_result` (load data, ALU result or PC+4, selected in MEM), so the WB forwarding source has no `wb_sel` mux.

The load/store address comes from a dedicated AGU in EX (`fa_val + id_ex_imm`), not from the ALU. `MUL*` takes two EX cycles: operands are registered in the first, multiplied in the second.

All three buses are pipelined AHB-Lite masters:

- IBUS (`rv32im_ahb_fetch`): the core exports `ibus_next_addr = stall_pc ? pc : pc_next`, issued as the address phase; its data phase lines up with `pc` one cycle later (one fetch per cycle).
- DBUS/SBUS (`rv32im_ahb_dport`): the address phase is issued from EX (AGU address, `addr_decode`, `lsu` in EX); the data phase is the MEM stage (store data from `ex_mem_store_data`, load data captured into MEM/WB). A zero-wait slave completes a load/store without stalling.
- A request is presented only when the instruction leaves EX on the accepting edge, so each load/store is issued exactly once (no AHB/APB replay of UART THR/RBR side effects).
- A data-bus request is presented only while the other data bus is ready, and a load/store in EX stalls while either data bus is not ready, so `bus_stall` does not depend on the EX address decode.

`hazard_unit.sv` handles:

- IF/ID source-use decoding
- load-use bubble insertion when ID/EX is a load used by IF/ID
- bus wait states (`bus_stall`: HREADY low on a bus with an active address or data phase)
- branch/jump flush (`flush = ex_branch_taken && !bus_stall`)
- `div_busy` (driven by `md_stall = id_ex_muldiv && !md_ready`): a `MUL*` (first cycle) or `DIV/REM` (all iterations) in EX
- IBUS not ready (no instruction fetched this cycle)

Priority in the combinational hazard logic is:

1. `bus_stall`: freeze the whole pipeline including MEM/WB; **no flush** while active
2. Taken branch/jump flush
3. `div_busy`: hold PC, IF/ID, ID/EX; bubble EX/MEM
4. load-use: hold PC, IF/ID; bubble ID/EX
5. IBUS not ready: hold PC; bubble IF/ID

Only item 1 stops MEM/WB, so the back end always drains and EX never waits on a producer that retires underneath it.

`rv32im_core` complements the hazard unit:

- IF/ID and ID/EX flush only when `flush && !stall_if_id` / `flush && !stall_id_ex`
- MEM/WB captures EX/MEM whenever `!stall_mem_wb`

Directed bus-overlap tests (require testbench plusargs in `tests/core/asm/*.plusargs`):

- `hazard_branch_mem_stall.S` — taken branch in EX while SBUS store stalls MEM (`+stall_sbus_writes`)
- `hazard_ibus_store_dup.S`, `hazard_ibus_insn_dup.S`, `hazard_ibus_load_dup.S` — IBUS stall while a store/ALU op/load is in MEM (`+stall_ibus_during_mem_write`). `scripts/check_hazard_dup_trace.py` checks from the PC/WB trace that no writeback is duplicated.
- `hazard_sbus_replay_smoke.S` — IBUS stall during one TORV UART store at `0x4000_1000`; the TB checks `+replay_expect=1`
- `hazard_sbus_rx_replay_smoke.S` — the same for a UART RBR read (`+replay_expect_rbr=1`)

The core also includes a WB-to-ID register read bypass in `rv32im_core`. This models write-first register file behavior for same-cycle writeback/decode dependencies and avoids X propagation when an instruction in ID reads the register being written in WB.

### 9.1 TORV SoC simulation top

`torv_soc_top` wraps `rv32im_ahb_top` (pipelined masters: `rv32im_ahb_fetch` for IBUS, two `rv32im_ahb_dport` for DBUS/SBUS) plus `torv_ahb_sram` for IMEM/DBUS/SBUS SRAM and the APB UART peripheral window. The SBUS HRDATA/HREADY mux and APB PSEL use the data-phase slave select `s_periph_dph`.

`torv_ahb_sram` is a zero-wait AHB-Lite wrapper around one IHP SG13G2 `RM_IHPSG13_1P_<WORDS>x32_c2_bm_bist` macro (`WORDS` = 256/512/1024; `IMEM_WORDS`/`DMEM_WORDS`/`SBMEM_WORDS` default to 1024 = 4 KiB):

- Read: the accepted address phase (`HSEL && HREADY && NONSEQ`) drives the macro address directly, and the registered `A_DOUT` is the data-phase HRDATA.
- Write: HWDATA arrives in the data phase. If no read address phase needs the single port that cycle, the wrapper writes directly with a byte mask (`A_BM`). Otherwise it parks the write in a one-entry write buffer and drains it on the next free cycle.
- A read that hits the buffered write, or a write completing in the same cycle, gets those bytes merged (store-then-load stays coherent). A simulation `$error` flags a buffer overrun.
- BIST ports are tied off, `A_DLY = 1`. The SBUS SRAM is deselected for the UART page and `0xF000_0000`.

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

The self-checking Verilator testbench is `sim/tb_torv_soc.sv`, around `torv_soc_top`. It provides:

- program/data images loaded into the IHP SRAM macro arrays before reset (`+imem=<hex>`, optional `+dmem=<hex>`). The image goes through a byte buffer, and an image that does not fit is an error.
- program-controlled pass/fail through a store to `tohost` (`0xF000_0000`), sampled when SBUS HREADY is high
- bus back-pressure plusargs (`+stall_sbus_writes`, `+stall_ibus_during_mem_write`) and UART replay checks (`+replay_expect`, `+replay_expect_rbr`, `+uart_rx_byte`)
- `[PERF]` counters (cycles, instructions, IPC, instruction mix, stalls, flushes, bus transfers)
- optional VCD (`+vcd`), testbench trace (`+trace`) and PC/WB trace TSV (`+pc_trace`)

The assembly tests (`tests/core/asm/`, `tests/periph/apb_uart_sv/`) cover:

- every RV32I instruction class, with compare/shift edge cases, `x0`, jumps and flushes
- RV32M including divide-by-zero and signed overflow, and dependent consumers after MUL/DIV
- byte/halfword/word loads and stores on DBUS and SBUS, offsets, and interleaved DBUS/SBUS traffic
- forwarding and load-use, plus directed bus-stall hazard and replay cases (§9)
- the SRAM wrapper write buffer and read merge (`sram_wbuf.S`)
- the UART through the AHB→APB bridge
- performance loops (`perf_alu_chain`, `perf_branch_loop`, `perf_loadstore_loop`, `perf_mul_loop`)

TORV SoC regression (`regress/cases/soc.list`): **33** cases, all PASS (Verilator 5.020). In simulation only, `u_fwd_chk` cross-checks the registered forwarding selects every cycle.

Not covered yet: randomized bus wait states, long C programs (no `crt0`/C runtime yet) and formal checks.

## 12. Implementation Status (IHP SG13G2, LibreLane)

The open-source flow in `librelane/` implements `rv32im_ahb_top` (core + AHB masters; the SRAM macros and peripherals are outside the block):

- LibreLane 3.0.16 Classic flow in Docker: Yosys (slang frontend, ABC buffering, Booth multiplier) → OpenROAD floorplan/placement/CTS/routing with post-CTS and post-global-route timing repair → RC extraction → multi-corner STA → Magic/KLayout DRC, Netgen LVS, antenna check.
- `make -C librelane` runs synthesis and pre-PnR STA. `make -C librelane flow` runs RTL-to-GDS. See `docs/open_source_flow.md`.
- Constraints (`librelane/constraints.sdc`): 10 ns clock, 2 ns input/output delay budget, 0.3/0.1 ns setup/hold uncertainty.

Results at 10 ns (v0.6 RTL):

| Metric | Value |
|--------|-------|
| Std-cell area | 266.7k µm² (die 0.508 mm², 56% utilization) |
| Setup WNS typ / fast | +2.35 ns / +4.12 ns |
| Setup WNS slow (1.08 V, 125 °C) | −0.73 ns (26 endpoints: 24 register→output, 2 register→register at ≈ −0.07 ns) |
| Hold | met (all corners) |
| DRC / LVS / antenna | clean |

The remaining slow-corner paths start at `ex_mem_wb_sel` (the EX/MEM forwarding source mux, PC+4 vs ALU), pass through the EX operand mux and the branch-target/AGU adders, and end at `i_haddr`, `s/d_htrans` and `s/d_hwrite` under the 2 ns output budget. The architecture issues the AHB address phase from EX, so these paths are inherent. Options are listed in `docs/TODO_LIST.md`.

One IHP 1024x32 SRAM macro is 416.6 x 336.5 µm (≈ 140k µm²), so the three default 4 KiB SRAMs are about 1.6x the core area.

## 13. Current Module List

Core and bus masters (`rv32im_ahb_top`):

- `rv32im_ahb_top.sv` — core + AHB-Lite masters
- `rv32im_ahb_fetch.sv` — pipelined IBUS master
- `rv32im_ahb_dport.sv` — pipelined DBUS/SBUS master
- `rv32im_core.sv` — pipeline, AGU, forwarding/MEM-WB registers, load extension
- `pc_unit.sv`, `regfile.sv`, `decoder.sv`, `imm_gen.sv`, `alu_control.sv`, `alu.sv`
- `muldiv_unit.sv`, `forwarding_unit.sv`, `hazard_unit.sv`, `addr_decode.sv`, `lsu.sv`
- `bus_if.sv` — typedef-only bus bundle definitions (in `rtl/filelist.f`, not in the LibreLane file list)

SoC:

- `torv_soc_top.sv` — TORV SoC integration
- `torv_ahb_sram.sv` — AHB-Lite wrapper for the IHP SRAM macro
- third-party: SoCBUS `AHB_APB_BRIDGE`, PULP `apb_uart_sv` (`ip/filelist.f`)
- PDK models: `RM_IHPSG13_1P_*` from `$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_sram/verilog`

## 14. Known Limitations

- No exceptions, interrupts, privilege modes, or CSRs.
- No trap handling for illegal instructions.
- No misaligned memory exception handling.
- No memory protection, cache, MMU, or bus error handling (`HRESP` errors are not reported).
- Register file nonzero registers are not reset.
- No branch prediction (2-cycle taken-branch penalty).
- The slow-corner timing at 10 ns is not closed (§12). The SRAM macros are not yet part of a placed SoC layout.

## 15. Recommended Next Steps

1. Close the slow corner: pre-select the EX/MEM forwarding value in EX, set the I/O budgets from the real SoC/SRAM timing, or accept 12.5 ns at the slow corner.
2. Implement `torv_soc_top` with the SRAM macros (macro placement, power) for a full SoC GDS.
3. Add `crt0`, a C linker script and CoreMark/Dhrystone for published IPC.
4. Add randomized HREADY back-pressure and SVA on the hazard/replay rules.
5. Decide whether unsupported instructions remain NOP-like/ignored or gain a trap path in a later milestone.
