"""Mid Between caddy (Shift + click on the button, or a toolbar right click), opened by AlecMid_run (tools/midBetween.ms) just before
the picking starts, so it stays open while the points are clicked. Every change goes to AlecMid_change and the red dummy follows;
a change of Points, or Pick again, starts a new picking. The check button moves (AlecMid_accept), the cross, Esc or closing drops it (AlecMid_end).
"""

import importlib
import sys

from pymxs import runtime as rt

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

CENTER = [("Average", 1), ("Bounding box", 2)]
POINTS = [("Snap clicks", 1), ("Object pivots", 2)]


class MidBetweenCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("MidBetween", "Mid Between", "OK: move", "Cancel")

    def build(self):
        s = rt.AlecMid_active.settings
        self.source = self.add_choice("Selection", CENTER, 2 if s.bounds else 1, 2, self.store)
        self.target = self.add_choice("Move to", CENTER, 2 if s.targetBounds else 1, 2, self.store)
        self.points = self.add_choice("Points", POINTS, 2 if s.fromObjects else 1, 2, self.points_changed)
        self.axes = self.add_toggles("Axes", ["X", "Y", "Z"], [s.x, s.y, s.z], self.store)
        self.add_button("", "Pick other points", "Start the picking again from nothing", self.repick)

    def store(self):
        rt.AlecMid_change(self.source.checkedId() == 2, self.target.checkedId() == 2, self.points.checkedId() == 2,
                          self.axes[0].isChecked(), self.axes[1].isChecked(), self.axes[2].isChecked())

    def points_changed(self):
        self.store()
        self.repick()

    def repick(self):
        self.while_busy(rt.AlecMid_repick)

    def ok(self):
        rt.AlecMid_accept()
        self.close()

    def closed(self):
        rt.AlecMid_end()


AlecTools_caddy.show(MidBetweenCaddy())
