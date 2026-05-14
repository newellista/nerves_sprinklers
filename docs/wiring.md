# Sprinkler Controller Wiring Guide

## System Overview

Two physically separate controllers managed as a single system over your local network.

```
  ┌──────────────────────────────────┐         ┌──────────────────────────────┐
  │  GARAGE  —  Pi 3                 │         │  BASEMENT  —  Pi Zero W      │
  │                                  │         │                              │
  │  Coordinator                     │◄── LAN ►│  Worker                      │
  │  Zones 1–10                      │         │  Zones 11–12                 │
  │  Phoenix / LiveView web UI       │         │  GPIO only, no web UI        │
  └──────────────────────────────────┘         └──────────────────────────────┘
```

Both devices run the same codebase. Config determines role, zone ownership, and node name.

---

## Bill of Materials

### Garage Controller (Zones 1–10)

| Component | Part | Notes |
|-----------|------|-------|
| Microcontroller | Raspberry Pi 3 | Runs coordinator + Phoenix/LiveView |
| Relay boards | 2× Tongling JQC-3FF-S-Z 8-channel (boards you already have) | Only 10 of 16 channels used |
| 5V supply | Facmogu 5V 2A DC wall adapter | 5.5×2.5mm barrel jack — cut to bare wires |
| 24VAC supply | Jameco Reliapro ADU240100 | 24VAC @ 1A — cut barrel jack to bare wires |
| Solenoid valves | Any standard 24VAC irrigation solenoid | 10 zones |

### Basement Controller (Zones 11–12)

| Component | Part | Notes |
|-----------|------|-------|
| Microcontroller | Raspberry Pi Zero W | Worker node — no web UI |
| Relay board | 4-channel 5V relay module | See options below |
| 5V supply | Facmogu 5V 2A DC wall adapter | Use spare from 2-pack |
| 24VAC supply | Jameco Reliapro ADU240100 | Second unit required |
| Solenoid valves | Any standard 24VAC irrigation solenoid | 2 zones |

#### Basement Relay Module Options

Any of these are electrically compatible with your existing boards (5VDC coil, active-LOW, optoisolated):

| Channels | Product | Amazon ASIN | Search string |
|----------|---------|-------------|---------------|
| 4-channel | JBtek 4 Channel DC 5V Relay Module | B00KTEN3TM | "JBtek 4 Channel DC 5V Relay Module Raspberry Pi" |
| 2-channel | SunFounder 2 Channel 5V Relay Module | B00E0NTPP4 | "SunFounder 2 Channel DC 5V Relay Module Optocoupler" |

> **Recommendation:** Buy the 4-channel board. It's usually the same price as the 2-channel and leaves room for a 3rd zone without rewiring.

> **Important:** The 24V supply is **AC**, not DC. Standard irrigation solenoids require 24VAC. Do not substitute a 24VDC supply.

---

## Tools and Materials Needed

Before starting, gather:

- **Female-to-female jumper wires** (Dupont, 2.54mm pitch) — for connecting Pi GPIO pins to the relay board control header. A 40-piece assortment is ~$5. Search: `"female to female jumper wires dupont"`
- **Small flathead screwdriver** — for the relay board screw terminals
- **Wire stripper** — for the power supply barrel jack wires
- **Multimeter** — to verify 5V supply polarity before connecting (red probe = positive)
- **Electrical tape or heat shrink** — to insulate any bare wire ends that won't be in a terminal
- **Drill + 3mm bit** — for standoff mounting holes
- **M2.5 standoff kit** — for mounting the Pi. Search: `"M2.5 standoff assortment kit"` (~$8)
- **M3 standoff kit** — for mounting relay boards. Search: `"M3 standoff assortment kit"` (~$8)
- **Zip ties + screw-in cable clips** — for wire management. Search: `"screw mount cable clips"` (~$5)
- **Label maker or sticky labels** — label every wire and component before powering on

---

## Mounting Backboards

Both stations are mounted on a piece of **3/4" plywood** screwed to the wall. This is simpler than an enclosure, gives you easy access to everything, and costs almost nothing if you have scrap wood available.

> ⚠️ **The relay screw terminals carrying 24VAC will be exposed.** 24VAC is low voltage but will give an unpleasant shock. Label the terminals clearly and be careful when the system is powered on.

The two wall adapters (Facmogu 5V and Jameco 24VAC) plug into nearby wall outlets — their output wires run to the backboard. You are only mounting the Pi and relay boards on the plywood.

---

### Garage Backboard

**Suggested plywood size: 16"×12" (400×300mm)**

The two relay boards side by side are the dominant size. Leave a few inches of clearance on all sides for wiring.

**Component layout:**

```
  ┌────────────────────────────────────────────────────────────┐  ← plywood
  │                                                            │
  │   ┌──────────────────────┐   ┌──────────────────────┐     │
  │   │   RELAY BOARD 1      │   │   RELAY BOARD 2      │     │
  │   │   Zones 1–8          │   │   Zones 9–10         │     │
  │   │   screw terminals ↑  │   │   screw terminals ↑  │     │
  │   └──────────────────────┘   └──────────────────────┘     │
  │                                                            │
  │   ┌──────────────┐                                         │
  │   │    Pi 3      │                                         │
  │   └──────────────┘                                         │
  │                                                            │
  │   [zip-tied wire bundle along bottom edge]                 │
  └────────────────────────────────────────────────────────────┘
        │  │  │  │  │  │  │  │  │  │  │  │
        └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
        solenoid wires (zones 1–10) + power supply wires
```

Mount relay boards near the top so their screw terminals (where solenoid wires connect) are easy to reach. Mount the Pi below. Bundle and zip-tie all wires along the bottom edge before they leave the board.

---

### Basement Backboard

**Suggested plywood size: 8"×6" (200×150mm)**

```
  ┌──────────────────────────────────────┐  ← plywood
  │                                      │
  │   ┌──────────────────────┐           │
  │   │   RELAY BOARD        │           │
  │   │   Zones 11–12        │           │
  │   │   screw terminals ↑  │           │
  │   └──────────────────────┘           │
  │                                      │
  │   ┌──────────┐                       │
  │   │ Pi Zero W│                       │
  │   └──────────┘                       │
  │                                      │
  │   [zip-tied wire bundle]             │
  └──────────────────────────────────────┘
        │  │  │  │
        solenoid wires (zones 11–12) + power supply wires
```

---

### Mounting Steps (same for both backboards)

1. **Cut plywood** to size and screw it to the wall
2. **Lay out components** on the board and trace the PCB corner mounting holes with a pencil
3. **Drill 3mm pilot holes** at each marked location
4. **Install M2.5 standoffs** at Pi mounting holes, **M3 standoffs** at relay board holes — thread them in by hand, then snug with pliers. Add a nut on the back of the plywood for a solid hold.
5. **Seat PCBs** on standoffs and secure with screws from above
6. **Install screw-in cable clips** along the bottom edge for wire management
7. **Label everything** — each relay board (Board 1 / Board 2), each screw terminal group (Zone 1, Zone 2, etc.), and each wire before connecting

---

## Understanding Your Hardware

### The Relay Board

Your Tongling 8-channel board has two sets of connections:

**Bottom edge — Control header (10 pins):**
This is where the Pi connects. The pins are labeled on the PCB silkscreen:

```
  [ GND | IN1 | IN2 | IN3 | IN4 | IN5 | IN6 | IN7 | IN8 | VCC ]
```

- **GND** — connect to Pi GND
- **IN1–IN8** — connect to Pi GPIO pins (one per zone)
- **VCC** — connect to 5V supply positive

**Top edge — Screw terminals (24 screws, 3 per relay):**
Each group of 3 is labeled on the PCB:

```
  [ COM | NO | NC ]  ← repeated 8 times across the board
```

- **COM** — Common. Connect 24VAC wire here.
- **NO** — Normally Open. Connect solenoid wire here. Circuit is OPEN (off) until relay activates.
- **NC** — Normally Closed. Leave this unconnected.

When the relay activates, it closes the connection between **COM** and **NO**, allowing 24VAC to flow to the solenoid.

### Pi GPIO Header

Both the Pi 3 and Pi Zero W have the same 40-pin header. Pin 1 is marked with a small triangle or square pad on the board. With the board in front of you, USB ports facing away, pin 1 is top-left.

```
  Pi 3 / Pi Zero W — 40-pin GPIO header
  (viewed from above, USB ports facing away from you)

  Pin 1 is marked with a ▼ on the board

       3.3V  [1 ][2 ]  5V
  GPIO2/SDA  [3 ][4 ]  5V
  GPIO3/SCL  [5 ][6 ]  GND  ← relay board GND
      GPIO4  [7 ][8 ]  GPIO14
        GND  [9 ][10]  GPIO15
    ★GPIO17  [11][12]  GPIO18
    ★GPIO27  [13][14]  GND
    ★GPIO22  [15][16]  ★GPIO23
       3.3V  [17][18]  ★GPIO24
     GPIO10  [19][20]  GND
      GPIO9  [21][22]  ★GPIO25
     GPIO11  [23][24]  GPIO8
        GND  [25][26]  GPIO7
      GPIO0† [27][28]  GPIO0†
     ★GPIO5  [29][30]  GND
     ★GPIO6  [31][32]  GPIO12
     GPIO13  [33][34]  GND
     GPIO19  [35][36]  ★GPIO16
    ★GPIO26  [37][38]  GPIO20
        GND  [39][40]  GPIO21

  ★ = used for relay control in this project
  † = reserved — do not use
```

---

## GPIO Pin Assignments

### Garage Controller — 10 zones, 2 boards

**Relay Board 1** (zones 1–8):

| Zone | GPIO (BCM) | Physical Pin | Board 1 pin |
|------|-----------|--------------|-------------|
| 1    | GPIO 17   | Pin 11       | IN1         |
| 2    | GPIO 27   | Pin 13       | IN2         |
| 3    | GPIO 22   | Pin 15       | IN3         |
| 4    | GPIO 23   | Pin 16       | IN4         |
| 5    | GPIO 24   | Pin 18       | IN5         |
| 6    | GPIO 25   | Pin 22       | IN6         |
| 7    | GPIO 5    | Pin 29       | IN7         |
| 8    | GPIO 6    | Pin 31       | IN8         |

**Relay Board 2** (zones 9–10, only 2 of 8 channels used):

| Zone | GPIO (BCM) | Physical Pin | Board 2 pin |
|------|-----------|--------------|-------------|
| 9    | GPIO 16   | Pin 36       | IN1         |
| 10   | GPIO 26   | Pin 37       | IN2         |

IN3–IN8 on Board 2 are unused. Leave them unconnected.

### Basement Controller — 2 zones

| Zone | GPIO (BCM) | Physical Pin | Board pin |
|------|-----------|--------------|-----------|
| 11   | GPIO 17   | Pin 11       | IN1       |
| 12   | GPIO 27   | Pin 13       | IN2       |

---

## Wiring — Step by Step

Complete these steps in order. Work with all power supplies **unplugged** until the checklist at the end.

---

### Step 1 — Connect GPIO pins to relay board control header

Use **female-to-female jumper wires**. Push one end onto the Pi header pin, the other onto the relay board header pin.

**Garage — Board 1:**
```
  Pi Pin 11 (GPIO17) ──► Board 1 IN1
  Pi Pin 13 (GPIO27) ──► Board 1 IN2
  Pi Pin 15 (GPIO22) ──► Board 1 IN3
  Pi Pin 16 (GPIO23) ──► Board 1 IN4
  Pi Pin 18 (GPIO24) ──► Board 1 IN5
  Pi Pin 22 (GPIO25) ──► Board 1 IN6
  Pi Pin 29 (GPIO5)  ──► Board 1 IN7
  Pi Pin 31 (GPIO6)  ──► Board 1 IN8
  Pi Pin 6  (GND)    ──► Board 1 GND
```

**Garage — Board 2:**
```
  Pi Pin 36 (GPIO16) ──► Board 2 IN1
  Pi Pin 37 (GPIO26) ──► Board 2 IN2
  Pi Pin 6  (GND)    ──► Board 2 GND   ← use a second jumper from Pi Pin 6,
                                          or daisy-chain from Board 1 GND
```

**Basement:**
```
  Pi Pin 11 (GPIO17) ──► Board IN1
  Pi Pin 13 (GPIO27) ──► Board IN2
  Pi Pin 6  (GND)    ──► Board GND
```

> **Tip:** Label each jumper wire with a small piece of tape and a zone number so you can trace them later.

---

### Step 2 — Connect the 5V supply to the relay board

Cut the barrel jack off the Facmogu adapter. Strip ~8mm of insulation from each wire. Verify polarity with a multimeter before connecting (red probe on red wire should read +5V when plugged in).

```
  Facmogu red wire  (+5V) ──► relay board VCC
  Facmogu black wire (GND) ──► relay board GND
                                (use the same GND rail as Pi GND from Step 1)
```

**Garage:** Both Board 1 and Board 2 VCC connect to the same +5V wire. Both GND pins connect to the same ground rail.

> ⚠️ **Do not connect the 5V supply to the Pi's 5V pins (Pin 2 or Pin 4).** The relay coils draw too much current and will damage the Pi.

---

### Step 3 — Connect the 24VAC transformer to the relay screw terminals

Cut the barrel jack off the Jameco ADU240100. Strip ~8mm of insulation from each wire.

**24VAC has no polarity — either wire can go to either terminal.**

Connect one wire to all COM terminals (daisy-chain with short wire segments between each COM):

```
  Jameco wire 1 ──► COM (relay 1)
                    COM (relay 2)
                    COM (relay 3)
                    ... (all COM terminals on all boards)
```

Leave the second Jameco wire aside for now — it connects to the solenoid returns in Step 4.

> ⚠️ **Keep 24VAC wiring completely separate from the Pi and 5V wiring.** The transformer output is isolated by the relay contacts — do not let 24VAC wires touch the control header or Pi GPIO pins.

---

### Step 4 — Connect solenoids

Each solenoid has two wires and no polarity (24VAC).

```
  Solenoid zone 1:   one wire ──► NO (relay 1)
                     other wire ──┐
  Solenoid zone 2:   one wire ──► NO (relay 2)   │
                     other wire ──┤               │ all return wires
  ...                             │               │ joined together
  Solenoid zone 10:  one wire ──► NO (relay 10)  │
                     other wire ──┘               │
                                                  └──► Jameco wire 2
```

All solenoid "return" wires bundle together and connect to the second wire from the Jameco transformer.

---

## Wiring Overview Diagrams

### Control Circuit

```
  ┌─────────────────────────┐         ┌──────────────────────────────────┐
  │   RASPBERRY PI 3 / 0W   │         │   TONGLING RELAY BOARD(S)        │
  │                         │         │                                  │
  │  Pin 11  GPIO17  ───────┼────────►│ IN1                              │
  │  Pin 13  GPIO27  ───────┼────────►│ IN2                              │
  │  Pin 15  GPIO22  ───────┼────────►│ IN3                              │
  │  Pin 16  GPIO23  ───────┼────────►│ IN4                              │
  │  Pin 18  GPIO24  ───────┼────────►│ IN5         (Board 1, zones 1–8) │
  │  Pin 22  GPIO25  ───────┼────────►│ IN6                              │
  │  Pin 29  GPIO5   ───────┼────────►│ IN7                              │
  │  Pin 31  GPIO6   ───────┼────────►│ IN8                              │
  │  Pin 36  GPIO16  ───────┼────────►│ IN1                              │
  │  Pin 37  GPIO26  ───────┼────────►│ IN2         (Board 2, zones 9–10)│
  │                         │         │                                  │
  │  Pin 6   GND     ───────┼────┬───►│ GND (both boards)                │
  └─────────────────────────┘    │    │ VCC ◄── FACMOGU (+) (both boards)│
                                 │    └──────────────────────────────────┘
                            FACMOGU 5V 2A
                            (−) ── Pi GND (same wire)
                            (+) ── relay board VCC
```

### Load Circuit *(24VAC — isolated from control circuit)*

```
  ┌──────────────────────┐
  │   JAMECO ADU240100   │
  │   24VAC @ 1A         │
  │   (no polarity)      │
  │                      │
  │   wire 1  ───────────┼──┬──► COM relay 1  ──[closes]──► NO relay 1  ──► Zone 1  wire A
  │                      │  ├──► COM relay 2  ──[closes]──► NO relay 2  ──► Zone 2  wire A
  │                      │  ├──► COM relay 3  ──[closes]──► NO relay 3  ──► Zone 3  wire A
  │                      │  ├──► COM relay 4  ──[closes]──► NO relay 4  ──► Zone 4  wire A
  │                      │  ├──► COM relay 5  ──[closes]──► NO relay 5  ──► Zone 5  wire A
  │                      │  ├──► COM relay 6  ──[closes]──► NO relay 6  ──► Zone 6  wire A
  │                      │  ├──► COM relay 7  ──[closes]──► NO relay 7  ──► Zone 7  wire A
  │                      │  ├──► COM relay 8  ──[closes]──► NO relay 8  ──► Zone 8  wire A
  │                      │  ├──► COM relay 9  ──[closes]──► NO relay 9  ──► Zone 9  wire A
  │                      │  └──► COM relay 10 ──[closes]──► NO relay 10 ──► Zone 10 wire A
  │                      │
  │   wire 2  ◄──────────┼──── all zones wire B (return wires bundled together)
  └──────────────────────┘

  NC terminals on all relays: leave unconnected
```

---

## Active-LOW Behavior

Both relay boards activate when the IN pin is pulled **LOW**. The software initializes all GPIO pins HIGH at boot so all valves are off until commanded.

| GPIO state | Relay | Solenoid |
|-----------|-------|----------|
| HIGH (3.3V) | OFF — contacts open | No water |
| LOW (0V)    | ON — contacts closed | Water flows |

---

## Pre-Power Checklist

Complete independently for each controller before plugging anything in.

**Control circuit:**
- [ ] Each GPIO pin connected to the correct IN pin per the table above
- [ ] Pi GND (Pin 6) connected to relay board GND
- [ ] 5V supply (+) connected to relay board VCC — NOT to Pi 5V pins
- [ ] 5V supply (−) connected to the same GND rail as Pi GND
- [ ] Jumper wires seated firmly on both ends

**Load circuit:**
- [ ] 24VAC transformer isolated from Pi/5V wiring — no shared ground
- [ ] All COM terminals connected to 24VAC transformer wire 1
- [ ] Each NO terminal connected to one solenoid wire
- [ ] All solenoid return wires bundled and connected to 24VAC transformer wire 2
- [ ] NC terminals left unconnected

**Final check:**
- [ ] No bare 24VAC wires touching control circuit components
- [ ] All screw terminals tightened (tug each wire gently — it should not pull free)
- [ ] Multimeter reads ~5V between relay board VCC and GND before connecting Pi
