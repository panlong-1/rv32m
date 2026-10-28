#!/usr/bin/env python3
"""Print QoR for a LibreLane run directory (librelane/runs/<tag>).

Works for both `make synth` (pre-PnR) and `make flow` (full RTL-to-GDS);
signoff rows are printed when the run reached DRC/LVS.
"""
import json
import sys
from pathlib import Path

run = Path(sys.argv[1] if len(sys.argv) > 1 else "runs/synth")
metrics = run / "final" / "metrics.json"
if not metrics.is_file():
    sys.exit(f"qor.py: no {metrics}; run 'make synth' or 'make flow' first")
m = json.loads(metrics.read_text())
cfg = json.loads((run / "resolved.json").read_text())
design = cfg.get("DESIGN_NAME")
full = "magic__drc_error__count" in m


def first(pattern):
    hits = sorted(run.glob(pattern))
    return hits[-1] if hits else None


corners = ("nom_slow_1p08V_125C", "nom_typ_1p20V_25C", "nom_fast_1p32V_m40C")
rows = [
    ("Clock period (ns)", cfg.get("CLOCK_PERIOD")),
    ("Std-cell area (um^2)", m.get("design__instance__area__stdcell", m.get("design__instance__area"))),
]
if full:
    rows += [
        ("Die area (um^2)", m.get("design__die__area")),
        ("Utilization", m.get("design__instance__utilization")),
    ]
rows += [
    ("Setup WNS (ns)", m.get("timing__setup__ws")),
    ("Setup TNS (ns)", m.get("timing__setup__tns")),
    ("Setup violators", m.get("timing__setup_vio__count")),
    ("Hold WNS (ns)", m.get("timing__hold__ws")),
    ("Hold violators", m.get("timing__hold_vio__count")),
]
rows += [(f"  setup WS {c}", m.get(f"timing__setup__ws__corner:{c}")) for c in corners]
rows += [
    ("Max slew violations", m.get("design__max_slew_violation__count")),
    ("Max cap violations", m.get("design__max_cap_violation__count")),
    ("Max fanout violations", m.get("design__max_fanout_violation__count")),
    ("Total power (W, default activity)", m.get("power__total")),
]
if full:
    rows += [
        ("Magic DRC errors", m.get("magic__drc_error__count")),
        ("KLayout DRC errors", m.get("klayout__drc_error__count")),
        ("LVS errors", m.get("design__lvs_error__count")),
        ("Antenna violating nets", m.get("antenna__violating__nets")),
    ]

stage = "full flow" if full else "pre-PnR"
print(f"==== QoR: {run.name} ({design}, IHP SG13G2, {stage}) ====")
for name, val in rows:
    if isinstance(val, float):
        val = f"{val:.4g}"
    print(f"{name:<34} {val}")

print(f"Netlist : {run}/final/nl/{design}.nl.v")
sta = first("*-openroad-stapostpnr") if full else first("*-openroad-staprepnr")
if sta:
    print(f"Timing  : {sta}/<corner>/max.rpt, violator_list.rpt")
if full:
    print(f"GDS     : {run}/final/gds/{design}.gds")
    print(f"Render  : {run}/final/render/{design}.png")
    rpt = first("*-misc-reportmanufacturability/manufacturability.rpt")
    if rpt:
        print(f"Signoff : {rpt}")
