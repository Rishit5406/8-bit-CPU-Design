# 8-bit CPU Design

A small, single-accumulator CPU written in Verilog and verified in simulation. It has a
program ROM, an 8-bit ALU, a 5-state control FSM, and an output port. 

---

## What it does

The CPU fetches 16-bit instructions from a hard-coded ROM, decodes them, executes them on an
8-bit accumulator, and can push the accumulator value out on an 8-bit output port. The demo
program in `ROM.v` is an infinite up-counter: it loads 1, prints it, adds 1, prints it, and
jumps back to loop forever.

```
Address   Instruction   Meaning
0x00      LOAD 0x01     ACC = 1
0x01      OUT           out_port = ACC
0x02      ADD  0x01     ACC = ACC + 1
0x03      OUT           out_port = ACC
0x04      JMP  0x01     PC = 1   -> loop back
```

So `out_port` walks up 1, 2, 3, 4, ... and wraps around at 255 because ACC is only 8 bits.

---

## Files

| File | What's inside |
|------|---------------|
| `cpu_top.v` | The top module. Holds PC, IR, ACC, zero flag, the FSM, and instantiates ROM + ALU. |
| `ALU.v` | Purely combinational 8-bit ALU. 5 operations plus a zero-detect output. |
| `ROM.v` | Combinational instruction memory. The program lives here as a `case` statement. |
| `testbench.v` | Clock generator, reset sequence, and a `$monitor` that prints PC/IR/ACC/ZF/OUT. |
| `waveform.png` | Screenshot of the simulation waveform showing `out_port` counting up. |

---

## Architecture

```
                +-----------+
     PC ------->|    ROM    |----- 16-bit instruction ---> IR
     ^          +-----------+                               |
     |                                                      |
     |                                       +--------------+--------------+
     |                                       |                             |
     |                                  opcode [15:12]                 imm [7:0]
     |                                       |                             |
     |                                       v                             v
     |                                +-------------+                +-----------+
     +------ branch target -----------|  FSM +      |--- alu_sel --->|    ALU    |
                                      |  control    |                |  a = ACC  |
                                      +-------------+                |  b = imm  |
                                             |                       +-----------+
                                             |                          |     |
                                             |                          y     z
                                             v                          |     |
                                        out_port <---- ACC <------------+     |
                                                        ZF <------------------+
```

**Registers**

| Register | Width | Purpose |
|----------|-------|---------|
| `pc` | 8 | Program counter — points at the next instruction in ROM. |
| `ir` | 16 | Instruction register — holds the instruction currently being worked on. |
| `acc` | 8 | Accumulator — the one and only general-purpose register. Every ALU result lands here. |
| `zf` | 1 | Zero flag — set when the last ALU result was zero. Only `JZ` reads it. |
| `out_port` | 8 | Output port — the CPU's only way of showing the outside world anything. |

---

## Instruction format

Every instruction is 16 bits wide:

```
 15    12 11     8 7            0
+--------+--------+--------------+
| opcode |reserved|  immediate   |
+--------+--------+--------------+
    4        4           8
```

- **opcode [15:12]** — which instruction this is.
- **reserved [11:8]** — currently unused, always written as `0000`. Space for future flags,
  addressing modes, or a second operand field.
- **immediate [7:0]** — either an 8-bit constant (for ALU ops) or an 8-bit ROM address
  (for jumps).

---

## Instruction set

| Opcode | Mnemonic | Operation | FSM path |
|--------|----------|-----------|----------|
| `0x0` | `NOP` | Do nothing | FETCH → DECODE → FETCH |
| `0x1` | `LOAD imm` | `ACC = imm` | via `EXEC_ALU` |
| `0x2` | `ADD imm` | `ACC = ACC + imm` | via `EXEC_ALU` |
| `0x3` | `SUB imm` | `ACC = ACC - imm` | via `EXEC_ALU` |
| `0x4` | `AND imm` | `ACC = ACC & imm` | via `EXEC_ALU` |
| `0x5` | `OR imm` | `ACC = ACC \| imm` | via `EXEC_ALU` |
| `0x6` | `JMP addr` | `PC = addr` | via `EXEC_BR` |
| `0x7` | `JZ addr` | `PC = addr` if `ZF == 1` | via `EXEC_BR` |
| `0x8` | `OUT` | `out_port = ACC` | via `EXEC_OUT` |

Opcodes `0x9`–`0xF` are unmapped and fall through to the default case, which behaves like a
`NOP`.

`LOAD` is a nice trick worth pointing out: it isn't a separate datapath at all. It's just an
ALU operation where `sel = 000` makes the ALU pass `b` (the immediate) straight through to `y`,
ignoring `a`. Same wires, same write-back path, zero extra hardware.

### ALU select encoding

| `sel` | Result `y` | Hardware it maps to |
|-------|-----------|---------------------|
| `000` | `b` | Pass-through (a mux input) |
| `001` | `a + b` | 8-bit ripple/carry adder |
| `010` | `a - b` | Same adder with 2's-complement of `b` |
| `011` | `a & b` | 8 parallel AND gates |
| `100` | `a \| b` | 8 parallel OR gates |
| other | `8'h00` | Default — see note below |

The `z` output is just `y == 0`, i.e. an 8-input NOR across the result.

---

## Control FSM

Five states, and every instruction takes **3 clock cycles** (except `NOP`, which takes 2):

```
                 +-----------+
        +------->|   FETCH   |  ir <= ROM[pc];  pc <= pc + 1
        |        +-----------+
        |              |
        |              v
        |        +-----------+
        |        |  DECODE   |  look at opcode, pick the execute state
        |        +-----------+
        |         /    |    \
        |        /     |     \
        |       v      v      v
        | +--------+ +------+ +--------+
        | |EXEC_ALU| |EXEC_ | |EXEC_OUT|
        | |        | | BR   | |        |
        | | acc<=y | |pc<=  | |out_port|
        | | zf <=z | |  imm | | <= acc |
        | +--------+ +------+ +--------+
        |       \      |      /
        +--------+-----+-----+
```

- **FETCH** — grab the instruction ROM is already presenting at address `pc`, latch it into
  `IR`, and bump the PC. Because ROM is combinational, the data is sitting there ready; no
  wait states needed.
- **DECODE** — the opcode is now visible on `ir[15:12]`, so the next-state logic routes to the
  right execute state. Nothing is written this cycle.
- **EXEC_ALU** — write the ALU result into ACC and the zero flag into ZF.
- **EXEC_BR** — for `JMP`, overwrite PC with the immediate. For `JZ`, only overwrite it if ZF
  is set. Note this overwrites the `pc + 1` that FETCH already did, which is exactly what you
  want.
- **EXEC_OUT** — copy ACC to the output port.

At 100 MHz (10 ns clock), one instruction = 30 ns, and one pass through the counter loop
(`OUT`, `ADD`, `OUT`, `JMP` = 4 instructions) = 120 ns.

---

## How to simulate

### Vivado

1. Create a new RTL project (no board/part constraints needed — this is simulation only).
2. Add `cpu_top.v`, `ALU.v`, and `ROM.v` as design sources.
3. Add `testbench.v` as a simulation source and set `test_bench` as the simulation top.
4. Run Behavioral Simulation.
5. Add `out_port`, `clk`, `rst_n`, and internal signals `uut.pc`, `uut.acc`, `uut.state` to the
   waveform window, then re-run for 400 ns.

### Icarus Verilog (command line)

```bash
iverilog -o cpu_sim testbench.v cpu_top.v ALU.v ROM.v
vvp cpu_sim
```

### What you should see

`$monitor` prints a table of `Time / PC / IR / ACC / ZF / OUT`. Reset is held low for 12 ns,
so the first real instruction executes after that. On the waveform, `out_port` steps through
`01`, `02`, `03`, `04`, ... every 120 ns.

You'll notice some values look like they're held twice as long as others. That's not a bug —
after the `JMP` sends PC back to address `0x01`, the `OUT` there re-outputs the *same* ACC
value that the previous `OUT` already wrote, so the port doesn't change and the waveform just
holds. See `waveform.png` for the reference run.

---

## Design notes

A few things in the code that are deliberate rather than accidental:

**Every `case` has a `default`.** In a combinational `always @(*)` block, if some input
combination doesn't assign the output, Verilog has to *remember* the old value — and the
synthesizer builds a latch to do that. Latches in a synchronous design are bad news: they're
level-sensitive, they wreck static timing analysis, and they cause simulation-vs-hardware
mismatches. Adding a `default` guarantees every branch assigns every output, so you get pure
combinational logic.

**Reset is synchronous and active-low.** The `if (!rst_n)` sits *inside* `always @(posedge clk)`,
so reset only takes effect on a clock edge. Active-low is the usual convention because it's
noise-tolerant — a floating or shorted-to-ground line puts the chip into reset rather than
letting it run wild.

**ZF is initialized to 1 on reset.** Zero flag high means "the last result was zero," and after
reset ACC is indeed zero, so this keeps the flag honest from cycle 0.

**Separate combinational and sequential blocks.** Next-state logic and ALU control live in
`always @(*)` blocks with blocking assignments (`=`); all register updates live in a single
`always @(posedge clk)` block with non-blocking assignments (`<=`). Mixing these is the single
most common source of simulation race conditions in Verilog, so keeping them apart is worth the
extra lines.
