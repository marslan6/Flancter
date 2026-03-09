# Flancter -- Cross-Clock-Domain Interrupt Handshake (VHDL)

![Language](https://img.shields.io/badge/Language-VHDL-blue) ![Platform](https://img.shields.io/badge/Platform-FPGA-orange) ![Tool](https://img.shields.io/badge/Tool-Vivado-green) ![Pattern](https://img.shields.io/badge/Pattern-CDC_Handshake-red) ![Architecture](https://img.shields.io/badge/Architecture-RTL-yellow)

A hardware implementation of the **Flancter circuit** -- a robust cross-clock-domain signaling mechanism for generating and clearing interrupt requests between an FPGA and a microprocessor (uP).

---

## What Is a Flancter?

A Flancter is a **set/clear flip-flop pair** that safely passes an event across two independent clock domains without metastability hazards. It uses a `FLAG` output (XOR of two flip-flops) to indicate interrupt status:

| `FLAG` | Meaning |
|--------|---------|
| `1` | Interrupt pending -- FPGA has requested attention |
| `0` | No interrupt -- uP has acknowledged and cleared |

---

## Project Structure

```
sources_1/new/
+-- Flancter.vhd          # Core Flancter cell (FF1 + FF2 + XOR)
+-- Flancter_uP_FPGA.vhd  # Top-level: sync chain, address decode, SET_CE logic
+-- Flancter_App_Note.pdf  # Reference application note
+-- readme.md              # This file
```

---

## Module Descriptions

### `Flancter.vhd` -- Core Cell

The basic Flancter primitive with two flip-flops in separate clock domains.

| Port | Dir | Description |
|------|-----|-------------|
| `sys_clk` | in | Fast clock domain (FPGA) -- drives FF1 |
| `reset_clk` | in | Slow clock domain (uP read strobe) -- drives FF2 |
| `set_ce` | in | Clock enable for FF1 (set the flag) |
| `reset_ce` | in | Clock enable for FF2 (clear the flag) |
| `reset_async` | in | Asynchronous active-high reset |
| `flag` | out | `ff1_o XOR ff2_o` -- HIGH when interrupt is pending |

### `Flancter_uP_FPGA.vhd` -- Top-Level Wrapper

Wraps the Flancter cell with synchronization, address decode, and set-enable logic.

| Port | Dir | Domain | Description |
|------|-----|--------|-------------|
| `GEN_INTERRUPT_TO_uC` | in | FPGA | Request to generate an interrupt |
| `SYS_CLK` | in | FPGA | System clock |
| `RESET` | in | -- | Async active-high reset |
| `INT` | out | -- | Interrupt output to uP |
| `RD_L` | in | uP | Read strobe (active-low, rising edge clocks FF2) |
| `ADDRESS` | in | uP | Address bus from uP |

| Generic | Default | Description |
|---------|---------|-------------|
| `ADDRESS_W` | 32 | Address bus width |
| `TARGET_ADDRESS` | `0xABCD00A5` | Address the uP reads to clear the interrupt |

**Internal signals:**
- **FF3, FF4** -- Double-synchronizer chain bringing `FLAG` into `SYS_CLK` domain
- **SET_CE** -- Asserted when `FLAG = ff4_o` (settled) and `GEN_INTERRUPT_TO_uC = '1'`
- **RESET_CE** -- Asserted when `ADDRESS = TARGET_ADDRESS`

---

## Circuit Diagrams

### Core Flancter Cell (`Flancter.vhd`)

![Core Flancter Cell](flancter.png)

**Logic:**
- `FF1.D = NOT(Q2)` -- FF1 toggles relative to FF2
- `FF2.D = Q1` -- FF2 copies FF1 to clear
- `OUT = Q1 XOR Q2` -- mismatch = interrupt pending

---

### Full Top-Level Design (`Flancter_uP_FPGA.vhd`)

![Flancter Top-Level Design](flancter_top.png)

---

### Timing Diagrams

![Timing Diagram 1](flancter_timing_1.png)

![Timing Diagram 2](flancter_timing_2.png)

---

## Operation Flowchart

```mermaid
flowchart TD
    A["IDLE STATE\nff1=ff2, FLAG=0\nff4_o=0"] --> B{"GEN_INTERRUPT\n= 1 ?"}
    B -- No --> A
    B -- Yes --> C{"FLAG = ff4_o ?\n(settled)"}
    C -- No --> C
    C -- Yes --> D["SET_CE = 1\n(next SYS_CLK edge)"]
    D --> E["FF1 = NOT FF2\nFLAG goes HIGH"]
    E --> F["INT asserted to uP"]
    F --> G["FF3 = FLAG (1 clk)\nFF4 = FF3 (2 clk)\nSynchronizer settling"]
    G --> H{"uP reads\nTARGET_ADDRESS ?"}
    H -- No --> H
    H -- Yes --> I["RESET_CE = 1\n(address decode)"]
    I --> J["RD_L rising edge\nFF2 = FF1"]
    J --> K["FLAG goes LOW\nINT deasserted"]
    K --> L["FF3 = 0 (1 clk)\nFF4 = 0 (2 clk)\nSync settles"]
    L --> A
```

---

## Timing Diagram

```
              SET                              CLEAR
              event                            event
               |                                |
               v                                v
SYS_CLK   ----+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--
              |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
              +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+

SET_CE    ----+  +------------------------------------------------
           ___|  |________________________________________________

ff1_o     --------+                                    +----------
           _______|  (set to NOT ff2_o = 1)            |__________

FLAG      --------+                              +----+
           _______|  (ff1 XOR ff2 = 1)           |________________

ff3_o     ---------------+                          +-------------
           ______________|  (+1 SYS_CLK)            |_____________

ff4_o     ----------------------+                       +---------
           _____________________|  (+2 SYS_CLK)        |_________

INT       --------+                              +----------------
           _______|  (= FLAG)                    |________________

RD_L      -------------------------------------+  +---------------
           (uP reads target addr)              |  |  (rising edge)
                                               +--+

ff2_o     -------------------------------------------+
           __________________________________________|  (copies ff1)

RESET_CE  ---------------------------------+        +-----------------
           ________________________________|________|
                                           (addr match)
```

---

## Clock Domain Crossing Safety

| Mechanism | Purpose |
|-----------|---------|
| FF1 on `SYS_CLK`, FF2 on `RD_L` | Flancter toggle-handshake avoids CDC issues |
| FF3 -> FF4 double-sync | Safely brings `FLAG` into `SYS_CLK` domain |
| `FLAG = ff4_o` guard | Prevents re-triggering during synchronizer settling |

## Quick Start

1. Add both `.vhd` files to your Vivado project
2. Set `Flancter_uP_FPGA` as the top module
3. Configure generics (`ADDRESS_W`, `TARGET_ADDRESS`) for your system
4. Connect `INT` to uP interrupt input, `RD_L` and `ADDRESS` to uP bus
5. Drive `GEN_INTERRUPT_TO_uC` from your FPGA logic when an event occurs
