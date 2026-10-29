"""Module placement map from a LibreLane DEF.

Flops keep their RTL register names (net names after synthesis); they seed the labels,
and combinational cells take the label of the nearest seeded cell through the netlist
(BFS, ignoring high-fanout nets). Output: binned SVG heat map, coloured by module.
"""
import re, sys, collections, json

def_path, svg_path = sys.argv[1], sys.argv[2]
txt = open(def_path).read()
dbu = int(re.search(r'UNITS DISTANCE MICRONS (\d+)', txt).group(1))
die = list(map(int, re.search(r'DIEAREA \( (\d+) (\d+) \) \( (\d+) (\d+) \)', txt).groups()))

comp_sec = txt[txt.index('\nCOMPONENTS'):txt.index('END COMPONENTS')]
cells = {}
for m in re.finditer(r'- (\S+) (\S+)[^;]*?\+ (?:PLACED|FIXED) \( (\d+) (\d+) \)', comp_sec):
    name, ref, x, y = m.group(1), m.group(2), int(m.group(3)), int(m.group(4))
    if re.search(r'fill|tap|decap|antenna', ref):
        continue
    cells[name] = (ref, x, y)

GROUPS = [  # (label, colour, regex on register net name)
    ('Register file',        '#2a78d6', r'^u_core\.u_rf\.'),
    ('MUL/DIV unit',         '#eb6834', r'^u_core\.u_md\.'),
    ('IF/ID + PC',           '#e87ba4', r'^u_core\.(if_id_|pc|u_pc)'),
    ('ID/EX',                '#6250d6', r'^u_core\.id_ex_'),
    ('EX/MEM, MEM/WB',       '#1baf7a', r'^u_core\.(ex_mem_|mem_wb_)'),
    ('Other core control',   '#008300', r'^u_core\.'),
    ('AHB masters (I/D/S)',  '#eda100', r'^u_(i_fetch|d_port|s_port)\.'),
]

net_sec = txt[txt.index('\nNETS'):txt.index('END NETS')]
adj = collections.defaultdict(list)
seed = {}
for m in re.finditer(r'- (\S+)(.*?);', net_sec, re.S):
    net = m.group(1).replace('\\', '')
    pins = [p for p in re.findall(r'\( (\S+) (\S+) \)', m.group(2)) if p[0] in cells]
    insts = [p[0] for p in pins]
    if net.startswith('u_'):
        drv = [i for i, pin in pins if pin in ('Q', 'Q_N')]
        for g, (_, _, rx) in enumerate(GROUPS):
            if re.match(rx, net):
                for i in drv:
                    seed.setdefault(i, g)
                break
    if 2 <= len(insts) <= 12:
        for a in insts:
            adj[a].extend(b for b in insts if b != a)

label = dict(seed)
frontier = list(seed)
while frontier:
    nxt = []
    for a in frontier:
        for b in adj[a]:
            if b not in label:
                label[b] = label[a]
                nxt.append(b)
    frontier = nxt

UNL = len(GROUPS)
CLK = UNL + 1
counts = collections.Counter()
for name, (ref, x, y) in cells.items():
    g = label.get(name, UNL)
    if ref.startswith('sg13g2_buf') and name.startswith('clkbuf') or 'clk' in name and 'buf' in ref:
        g = CLK
    label[name] = g
    counts[g] += 1

names = [g[0] for g in GROUPS] + ['Unlabelled', 'Clock tree']
colours = [g[1] for g in GROUPS] + ['#9D9D9D', '#222222']
for g in range(len(names)):
    print(f'{names[g]:22s} {counts[g]:6d}')

# bin
B = 8.0  # um per bin
W, H = (die[2] - die[0]) / dbu, (die[3] - die[1]) / dbu
nx, ny = int(W // B) + 1, int(H // B) + 1
bins = collections.defaultdict(collections.Counter)
for name, (ref, x, y) in cells.items():
    bins[(int(x / dbu // B), int(y / dbu // B))][label[name]] += 1
peak = max(sum(c.values()) for c in bins.values())

S = 1.0  # px per um
LEG = 230
out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W*S+LEG:.0f} {H*S+40:.0f}" '
       f'font-family="Helvetica,Arial,sans-serif" font-size="13">',
       f'<rect width="100%" height="100%" fill="#ffffff"/>',
       f'<g transform="translate(10,30)">',
       f'<rect x="0" y="0" width="{W*S:.1f}" height="{H*S:.1f}" fill="#f4f4f4" stroke="#333" stroke-width="1"/>']
for (bx, by), c in sorted(bins.items()):
    g, n = c.most_common(1)[0]
    if g == CLK and len(c) > 1:
        g = c.most_common(2)[1][0]
    tot = sum(c.values())
    op = 0.35 + 0.65 * min(1.0, tot / (0.7 * peak))
    out.append(f'<rect x="{bx*B*S:.0f}" y="{(H-(by+1)*B)*S:.0f}" width="{B*S:.0f}" height="{B*S:.0f}" '
               f'fill="{colours[g]}" fill-opacity="{op:.2f}"/>')
out.append('</g>')
out.append(f'<text x="10" y="20" font-weight="bold">torv_cpu placement by module '
           f'({W:.0f} × {H:.0f} µm)</text>')
lx = W * S + 25
for g in range(len(names)):
    if counts[g] == 0:
        continue
    yy = 50 + g * 24
    out.append(f'<rect x="{lx}" y="{yy-12}" width="16" height="16" fill="{colours[g]}"/>')
    out.append(f'<text x="{lx+24}" y="{yy+1}">{names[g]} ({counts[g]})</text>')
yy = 50 + len(names) * 24 + 10
for line in ['Each 8×8 µm tile shows its majority', 'module; opacity = cell density.',
             'Flops seed labels from register', 'names; logic inherits the nearest',
             'flop label through the netlist.']:
    out.append(f'<text x="{lx}" y="{yy}" font-size="11" fill="#555">{line}</text>')
    yy += 15
out.append('</svg>')
open(svg_path, 'w').write('\n'.join(out))
print('bins', len(bins), 'peak', peak)
