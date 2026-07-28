# Atmosphere, production, and cargo machine fidelity research

## Record

- Canonical task:
  `/root/architecture_scope/atmos_prod_cargo_research`
- Display name: not available
- Parent task: `/root/architecture_scope`
- Assigned date: 2026-07-28
- Last observable status: completed
- Report availability: normalized visible final report
- Assignment availability: reconstructed from the parent task and delivered
  report
- Upstream revision:
  `1b2b250abb5be747d55e274de0203a59cfc8da78`
- Files changed by the agent: none

### Assignment

The exact assignment message is no longer visible. The observable scope was a
read-only source-fidelity investigation of Atlas atmosphere machines,
manufacturers, reclaimers, nanofabs, and cargo flow. It was to identify raw
placements, defaults, transfers, physical inventories, interactions, power,
maintenance, map grammar, deterministic adaptations, and pinned source
citations.

### Observable chronology

1. The agent was spawned by `/root/architecture_scope`.
2. It researched Atlas placements and pinned atmosphere, material,
   manufacturing, supply-console, shipping-market, barcode, and
   transception sources.
3. It delivered the report below and completed without changing files or
   sparse-checkout state.
4. Its preliminary count of two portable scrubbers was later corrected to
   three by the exact Atlas importer/re-parse. All other selected family
   counts in the visible matrix were retained.

## Visible report

### Corrected Atlas matrix

| Family | Exact Atlas presence | Required fidelity |
| --- | ---: | --- |
| passive vent | 3 | Zero-power 250 L pipe/room equalizer; never gas generation |
| fixed vent pump | 1 | Tox-lab siphon; bounded bidirectional pipe transfer and radio control |
| fixed vent scrubber | 0 | Define for later maps/construction; place none in Atlas |
| portable scrubber | 3 | Powered mobile collector with internal gas/reagent storage |
| manufacturer | 20 | 20-item queue, physical materials, recipes, speed/power, damage, wires, drives |
| portable reclaimer | 7 | Physical sequential recycling with conserved fractional remainder |
| nanofab | 2 | Exact material-slot binding and inherited material properties |
| Atlas cargo | 2 supply consoles, 1 QM barcode computer, freight areas | Edge-fling delivery and physical export |
| transception | 0 | Non-Atlas system; deferred |

The visible report originally listed two portable scrubbers and a
selected-family total of 133. An exact subsequent source parse found three,
bringing the selected baseline to 134. That correction is a post-report
evidence update, not an alteration of the agent's original claim.

Manufacturer subtype counts were: gas 3, mining 3, general 2, hangar 2,
medical 2, robotics 2, and one each of engineering, science, QM, uniform,
hop-and-uniform, and mechanic.

The prior scenario was materially lossy: it collapsed three passive vents and
the tox pump into a generic powered magic-fill fixture, deleted gases at
scrubbers, omitted both nanofabs plus mechanic and hop-and-uniform
manufacturers, and omitted Atlas cargo-management/freight machinery.

### Atmosphere contracts

#### Passive vent

`/obj/machinery/atmospherics/unary/vent` contains 250 L of pipe gas and
passively equalizes with its turf or gas group. It has no on/off state, UI,
access, radio, wires, deconstruction contract, explicit power draw, or
`NOPOWER` gate. Its Sim Station behavior must conserve gas and must never
synthesize oxygen or nitrogen.

#### Fixed vent pump

The fixed vent pump defaults on in release mode, with an external bound of one
atmosphere plus 20, internal bound zero, and separate external/internal bound
flags. Each process moves ideal-gas moles between room and pipe, honors bounds,
and limits the pressure-delta step to 10,000.

Radio commands cover power, direction, purge, stabilization, bound checks,
thresholds from 0 through 50 atmospheres, status, and help. Atlas's tox-lab
subtype starts siphoning with external bound zero, internal bound 4,000, and
internal-only checking.

#### Fixed vent scrubber

Although Atlas has none, the constructible/future-map contract defaults on in
selective scrubbing mode with per-gas flags and volume rate 120. It moves
selected contaminants into a pipe and returns unselected gas, or siphons the
whole mixture. It conserves gas; it does not delete contaminants. Its source
control is radio rather than a direct access UI.

#### Portable scrubber

Portable scrubbers are a different machine family:

- 1,000 L internal gas storage;
- inlet flow adjustable from 0% through 100%;
- oxygen and nitrogen retained in the environment while other gases move into
  storage;
- the current tile and adjacent tiles are processed;
- airborne reagents can be collected;
- a tank or portable pipe connection may be attached;
- environmental APC power is required;
- draw is `1 kW + inlet% × 10 W + filtered moles × 70 W`, plus liquid work;
- TGUI controls expose flow, pressure, tank, and reagent state;
- wrench, tank, atmosporter, screwdriver, and welder interactions cover
  connection and deconstruction.

Strict parity retains the source's lack of explicit metered draw on fixed
pumps/scrubbers. A balance profile may add draw, but must not silently change
the parity profile.

### Manufacturing and materials

#### Manufacturer

The manufacturer base has:

- queue and output caps of 20;
- ready, working, and halted modes;
- normal speeds 1–3, hacked maximum 5, and damaged maximum 8;
- idle draw 200 W plus active draw `750 × speed²` W;
- health, malfunction, electrification, wires, repair, and staged dismantling;
- physical material-piece storage and optional shared storage;
- free initial resources, recipe sets, blueprint/manudrive/hidden recipes,
  banking, and Rockbox purchasing.

Humans operate the machine adjacently; AI and borgs may use its remote UI.
Operations expose queue/progress, stored materials, recipe producibility,
speed, repeat, bank/card, drive uses, and blueprint deletion. Physical
interactions cover material loading, blueprint/drive insertion, repair, and
tool-based dismantling.

Four wires control hidden-recipe extension, shock, malfunction, and power.
Recipes are content datums with exact or predicate material requirements, not
hard-coded family branches. Inputs are checked at start, then rechecked and
consumed at completion. Outputs may be items or reagents and may inherit
selected material properties.

Planner reservations can prevent routine NPC double-booking, but the machine
must still revalidate at completion so theft, sabotage, or a blocked output
can halt production.

#### Portable reclaimer

The portable reclaimer has no power, UI, access, wires, or radio. Crew load
individual items or containers and activate it. It anchors while processing
the contents sequentially and recovers their material composition.

Cable preserves sheath and conductor separately. Fractional leftovers persist
per material and later become bars, pieces, or sheets. The machine warns about
intelligent contents and tanks/reagent vessels; accepted open reagents spill
onto the turf. This is physical composition-aware recycling, not a generic
inventory conversion.

#### Nanofab

The refining and mining nanofabs bind exact contained stacks into typed
material, property, and component slots. The selected main material propagates
to output. Source fabrication is immediate and its displayed queue is
explicitly unimplemented. Nanofabs have no power, access, or wire checks,
block silicon loading, and allow broad tool deconstruction.

This needs a distinct material-fabrication capability; it must not be treated
as a standardized manufacturer or as the portable reclaimer.

### Atlas cargo contract

Atlas inherits `SHIPPING_METHOD_EDGE_FLING`; it does not use transception.

The supply console is supply-access controlled and exposes packs, commodity
quotes, traders, carts, requisitions, budget, order history, and Rockbox fees.
Approval debits the station account and creates a physical shipment.

The shipping market owns commodity fluctuations, hot demand, traders,
contracts, mail, import delivery, and export appraisal. Export may credit the
station or split proceeds with a barcode-associated personal account.

The QM barcode computer prints one through five labels after 1.75 seconds.
Atlas offers only the Shipping Market destination. Moving physical freight
into the sell region triggers appraisal.

The experimental Nadir transception implementation is a later, separate
system. It must not be substituted for Atlas freight or conflated with
`/obj/submachine/cargopad`.

The five Atlas cargo pads are simple unpowered receiver endpoints. Enabling a
pad registers it as a destination. The separate paired transporter spends 25
cell units and takes three seconds; the pad itself does not consume grid
power.

### Proposed native composition and work

The report proposed ordinary data-defined composition:

- machine, power-load, damage, maintenance, access, and wire components;
- gas reservoirs/ports with passive equalizer, bounded pump, selective
  scrubber, and portable-scrubber actuator profiles;
- physical inventory, material composition, reagent containers,
  reservations, and output targets;
- production machines/orders, recipe sets, blueprints, and manudrives;
- fixed-point per-material reclaimer remainders;
- material fabricator slot binding and material propagation;
- cargo market, ledger, order, shipment, manifest, freight endpoint, and
  export contract.

Player commands should state policies or authorize work at tick boundaries:
atmos modes/bounds/species, production and stock policy, purchase/requisition
approval, export contracts, and cargo routing. NPC work actions perform the
physical operations: configure, load, unload, bind material, insert drives,
repair, manipulate wires, select output, print labels, haul, and launch.

Typed deterministic events should cover gas transfer/stalls, production
lifecycle, physical transfer, power/fault/repair/hack state, market quotes,
ledger transactions, freight dispatch/delivery/export, and control messages.

## Decision disposition

### Accepted

- Corrected raw Atlas counts and exact manufacturer subtype coverage.
- Distinct passive vent, fixed pump, portable scrubber, manufacturer,
  reclaimer, and nanofab behavior.
- Gas, material, reagent, cargo, energy, and money conservation.
- Physical Atlas freight with supply, label, haul, and sell-region stages.
- Source-style completion revalidation even when planners reserve inputs.

### Adapted

- Source interfaces become serializable policy commands and NPC work verbs.
- Source floating/random operations become fixed-point and named deterministic
  RNG state.
- Strict parity keeps source power semantics; optional balancing belongs to a
  separately named profile.

### Rejected

- Powered magic vents that generate oxygen/nitrogen.
- Scrubbers that delete contaminants.
- A generic refinery abstraction for three materially different families.
- Nadir transception as Atlas cargo.
- Grid power draw on the cargo-pad receiver.

### Unresolved

- Full pipe topology and gas/reagent transfer execution.
- Physical item/material entity model, output placement, and deconstruction.
- Complete recipe catalogs, drives, blueprints, banking, and Rockbox.
- Market, account, shipment, export, and barcode execution.
- Non-Atlas fixed scrubber and transception milestones.

## Sources

- [Passive vent](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/atmospherics/machinery/unary/vent.dm#L1-L71)
- [Fixed vent pump](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/atmospherics/machinery/unary/vent_pump.dm#L11-L218)
- [Atlas tox-lab pump subtype](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/atmospherics/machinery/unary/vent_pump.dm#L233-L306)
- [Fixed vent scrubber](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/atmospherics/machinery/unary/vent_scrubber.dm#L6-L201)
- [Portable scrubber](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/atmospherics/portable/scrubber.dm#L4-L197)
- [Manufacturer base and state](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/manufacturer.dm#L1-L129)
- [Manufacturer UI and actions](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/manufacturer.dm#L328-L807)
- [Manufacturer physical interactions](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/manufacturer.dm#L904-L1148)
- [Manufacturer wires](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/manufacturer.dm#L1544-L1613)
- [Manufacturing recipe schema](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/manufacturing.dm#L3-L67)
- [Manufacturing requirements](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/datums/manufacturing_requirements.dm#L1-L359)
- [Atlas manufacturer subtypes](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/manufacturer_subtypes.dm#L4-L730)
- [Portable reclaimer](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/item/material.dm#L905-L1243)
- [Refining and mining nanofabs](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/materials/Mat_Fabrication.dm#L1-L104)
- [Default edge-fling shipping method](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/map.dm#L145-L159)
- [Atlas map settings](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/map.dm#L641-L685)
- [Supply console](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/computer/QM_supply.dm#L23-L380)
- [Shipping market](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/economy/shippingmarket.dm#L20-L721)
- [QM barcode computer](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/obj/machinery/launcherloader.dm#L338-L468)
- [Sell-region behavior](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/modules/economy/supply_misc.dm#L1-L42)
- [Deferred Nadir transception](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/code/WorkInProgress/nadir_antenna.dm#L1-L1049)
