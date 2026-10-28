# Render a GDS window to PNG with the PDK layer properties (run inside the LibreLane image):
#   klayout -zz -rd gds=<gds> -rd lyp=<lyp> -rd out=<png> -rd box=x1,y1,x2,y2 -rd w=<px> -r render_gds.py
import pya

lv = pya.LayoutView()
lv.set_config("background-color", "#ffffff")
lv.set_config("grid-visible", "false")
lv.set_config("text-visible", "false")
lv.load_layout(gds, 0)
lv.load_layer_props(lyp)
lv.max_hier()
x1, y1, x2, y2 = map(float, box.split(","))
lv.zoom_box(pya.DBox(x1, y1, x2, y2))
W = int(w)
H = int(W * (y2 - y1) / (x2 - x1))
lv.save_image(out, W, H)
