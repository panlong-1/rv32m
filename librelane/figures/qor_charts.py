"""QoR charts (SVG) from LibreLane full-flow runs.

usage: qor_charts.py OUT_DIR LABEL=RUN_DIR [LABEL=RUN_DIR ...]

timing_area.svg    slow-corner setup WNS and std-cell area per run (needs >= 2 runs)
area_breakdown.svg std-cell area by cell class of the last run
"""
import json, sys
out = sys.argv[1]
VER = [a.split("=", 1) for a in sys.argv[2:]]
M = {t: json.load(open(f"{r}/final/metrics.json")) for t, r in VER}
CLK = json.load(open(f"{VER[-1][1]}/resolved.json"))["CLOCK_PERIOD"]

STYLE = """<style>
.bg{fill:#fcfcfb}.t{fill:#0b0b0b}.s{fill:#52514e}.m{fill:#8a8984}.g{stroke:#e4e3de;stroke-width:1}
.ax{stroke:#8a8984;stroke-width:1}.b{fill:#2a78d6}.z{stroke:#0b0b0b;stroke-width:1.2}
@media (prefers-color-scheme:dark){.bg{fill:#1a1a19}.t{fill:#f0efec}.s{fill:#c3c2b7}.g{stroke:#33332f}.b{fill:#3987e5}.z{stroke:#f0efec}}
</style>"""

def hbar(x0, y0, w, title, rows, fmt, unit, vmax=None, vmin=0.0):
    """Horizontal bars; rows = [(label, value, note)]. Negative values grow left from zero."""
    lw, bh, gap = 120, 22, 12
    vmax = vmax if vmax is not None else max(v for _, v, _ in rows)
    vmin = min(vmin, min(v for _, v, _ in rows))
    pw = w - lw - 90
    sx = lambda v: x0 + lw + (v - vmin) / (vmax - vmin) * pw
    o = [f'<text class="t" x="{x0}" y="{y0}" font-weight="bold">{title}</text>']
    y = y0 + 18
    zx = sx(0)
    for lab, v, note in rows:
        a, b = sorted((sx(0), sx(v)))
        # 4px rounded end on the data side, square on the baseline
        r = min(4, b - a)
        if v >= 0:
            d = f'M{a:.1f},{y} H{b-r:.1f} Q{b:.1f},{y} {b:.1f},{y+r} V{y+bh-r} Q{b:.1f},{y+bh} {b-r:.1f},{y+bh} H{a:.1f} Z'
            tx, anc = b + 6, "start"
        else:
            d = f'M{b:.1f},{y} H{a+r:.1f} Q{a:.1f},{y} {a:.1f},{y+r} V{y+bh-r} Q{a:.1f},{y+bh} {a+r:.1f},{y+bh} H{b:.1f} Z'
            tx, anc = sx(0) + 6, "start"
        o.append(f'<text class="s" x="{x0}" y="{y+15}">{lab}</text>')
        o.append(f'<path class="b" d="{d}"><title>{lab}: {fmt(v)} {unit}{note}</title></path>')
        o.append(f'<text class="t" x="{tx:.1f}" y="{y+15}" text-anchor="{anc}">{fmt(v)}{note}</text>')
        y += bh + gap
    if vmin < 0:
        o.append(f'<line class="z" x1="{zx:.1f}" y1="{y0+12}" x2="{zx:.1f}" y2="{y-gap+6}"/>')
    o.append(f'<text class="m" x="{x0+lw}" y="{y+6}" font-size="11">{unit}</text>')
    return o, y + 10

if len(VER) >= 2:
    p1, h1 = hbar(20, 40, 430, "Setup WNS, slow corner (1.08 V, 125 °C)",
                  [(t, M[t]["timing__setup__ws"], f'  ({M[t]["timing__setup_vio__count"]} viol.)') for t, _ in VER],
                  lambda v: f"{v:+.2f}", f"ns · {CLK:g} ns clock", vmax=max(3.0, max(M[t]["timing__setup__ws"] for t, _ in VER) + 1))
    p2, h2 = hbar(470, 40, 400, "Standard-cell area",
                  [(t, M[t]["design__instance__area__stdcell"] / 1000, "k") for t, _ in VER],
                  lambda v: f"{v:.1f}", "k µm²", vmax=1.2 * max(M[t]["design__instance__area__stdcell"] for t, _ in VER) / 1000)
    H = max(h1, h2)
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 {H}" font-family="Helvetica,Arial,sans-serif" font-size="12">',
           STYLE, f'<rect class="bg" width="880" height="{H}"/>'] + p1 + p2 + ['</svg>']
    open(f"{out}/timing_area.svg", "w").write("\n".join(svg))

last = VER[-1][0]
m = M[last]
cls = [("Combinational logic", "multi_input_combinational_cell"), ("Flip-flops", "sequential_cell"),
       ("Timing-repair buffers", "timing_repair_buffer"), ("Buffers", "buffer"),
       ("Clock tree", None), ("Inverters", "inverter")]
rows = []
for lab, k in cls:
    if k is None:
        a = m["design__instance__area__class:clock_buffer"] + m["design__instance__area__class:clock_inverter"]
        n = m["design__instance__count__class:clock_buffer"] + m["design__instance__count__class:clock_inverter"]
    else:
        a, n = m[f"design__instance__area__class:{k}"], m[f"design__instance__count__class:{k}"]
    rows.append((lab, a / 1000, f"k  · {n} cells"))
p3, h3 = hbar(20, 40, 640, "%s standard-cell area by class (total %.1fk µm², %d cells)" %
              (last, m["design__instance__area__stdcell"] / 1000, m["design__instance__count__stdcell"]),
              rows, lambda v: f"{v:.1f}", "k µm²", vmax=1.4 * max(r[1] for r in rows))
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 660 {h3}" font-family="Helvetica,Arial,sans-serif" font-size="12">',
       STYLE, f'<rect class="bg" width="660" height="{h3}"/>'] + p3 + ['</svg>']
open(f"{out}/area_breakdown.svg", "w").write("\n".join(svg))
