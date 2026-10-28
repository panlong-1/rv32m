# Program loading (software view)

How binaries reach TORV in **simulation** vs **silicon**. No RTL knowledge required.

## Simulation (today)

```text
  .S or .c  →  gcc + tests/core/link.ld  →  .elf
                                         →  objcopy  →  .hex
                                         →  +imem=...  (testbench loads instruction RAM @ reset)
                                         →  CPU runs from PC = 0x0
```

| File | Role |
|------|------|
| **`.elf`** | Build and debug (`objdump`, GDB) |
| **`.hex`** | Verilog memory image for sim (auto-created by `run_case.sh`) |
| **`.dump`** | Disassembly for review |

Default command:

```bash
./scripts/run_case.sh path/to/test.S
# outputs: build/sim/soc/<case>/{case.elf, case.hex, case.dump, case.sim.log}
```

Optional: `+dmem=<file>.hex` preloads data SRAM. Most tests only use `+imem`.

The images are written into the IHP SRAM macro arrays before reset. Each SRAM is
`IMEM_WORDS` / `DMEM_WORDS` / `SBMEM_WORDS` words (default 1024 = **4 KiB**). A program that
does not fit is reported as an error, not silently truncated. Unused IMEM words read as NOP
(`0x0000_0013`).

## Link addresses (current `tests/core/link.ld`)

| Region | Address | Bus (in SoC) |
|--------|---------|----------------|
| Code / `.text` | `0x0000_0000` | Instruction SRAM (IBUS) |
| Data (convention in asm tests) | `0x2000_0000` | Data SRAM (DBUS) |
| UART registers | `0x4000_1000` | SBUS → APB |
| Pass/fail (sim only) | `0xF000_0000` | Testbench monitor (not on-chip) |

C projects will need an extended linker script (`.data` / `.bss` / stack in DMEM) and `crt0` — not in the minimal asm `link.ld` yet.

## Silicon / FPGA (planned)

| Stage | Typical file | Loader |
|-------|----------------|--------|
| Manufacturing / flash | **`.bin`** | Programmed into external or internal Flash |
| Bring-up | same **`.bin`** | BootROM, UART download, or host MCU (e.g. badge RP2350) writes SRAM |
| FPGA bitstream | **`.hex` / `.mem` init** | BRAM initialization in synthesis |

The core still does **not** read ELF on chip. Host tools convert **ELF → `.bin` or init image`**.

## Integrating an external ELF

1. Link with the same memory map (or share your `link.ld`).
2. For sim: `riscv64-unknown-elf-objcopy -O verilog prog.elf prog.hex`
3. Run: `./scripts/run_case.sh` for a `.S` source, or run an already built simulator by hand:
   `build/sim/soc/<case>/verilator/obj_dir/Vtb_torv_soc +imem=$PWD/prog.hex`
4. For silicon: `objcopy -O binary prog.elf prog.bin` + your boot flow

Contact the integration owner to align maps and CI (`ELF → hex` for sim, `ELF → bin` for tapeout).

See also: [sim/SIM_README.md](../sim/SIM_README.md), [torv_address_map.md](torv_address_map.md).
