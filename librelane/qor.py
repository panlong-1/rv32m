#!/usr/bin/env python3
"""Print synthesis QoR for a LibreLane run directory (librelane/runs/<tag>)."""
import json
import sys
from pathlib import Path

run = Path(sys.argv[1] if len(sys.argv) > 1 else "runs/synth")
metrics = run / "final" / "metrics.json"
if not metrics.is_file():
    sys.exit(f"qor.py: no {metrics}; run 'make synth' first")
m = json.loads(metrics.read_text())
cfg = json.loads((run / "resolved.json").read_text())

corners = ("nom_slow_1p08V_125C", "nom_typ_1p20V_25C", "nom_fast_1p32V_m40C")
rows = [
    ("Clock period (ns)", cfg.get("CLOCK_PERIOD")),
    ("Cells", m.get("design__instance__count")),
    ("Cell area (um^2)", m.get("design__instance__area")),
    ("Setup WNS (ns)", m.get("timing__setup__ws")),
    ("Setup TNS (ns)", m.get("timing__setup__tns")),
    ("Hold WNS (ns)", m.get("timing__hold__ws")),
]
rows += [(f"  setup WS {c}", m.get(f"timing__setup__ws__corner:{c}")) for c in corners]
rows += [
    ("Max slew violations", m.get("design__max_slew_violation__count")),
    ("Max fanout violations", m.get("design__max_fanout_violation__count")),
    ("Max cap violations", m.get("design__max_cap_violation__count")),
    ("Total power (W)", m.get("power__total")),
]

print(f"==== QoR: {run.name} ({cfg.get('DESIGN_NAME')}, IHP SG13G2, pre-PnR) ====")
for name, val in rows:
    if isinstance(val, float):
        val = f"{val:.4g}"
    print(f"{name:<34} {val}")
print(f"Netlist : {run}/final/nl/{cfg.get('DESIGN_NAME')}.nl.v")
print(f"Cells   : {run}/06-yosys-synthesis/reports/stat.rpt")
print(f"Timing  : {run}/12-openroad-staprepnr/<corner>/max.rpt")
