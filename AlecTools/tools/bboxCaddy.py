"""BBox caddy (Shift + click on the button, or a toolbar right click), opened by AlecBBox_run (tools/bbox.ms) once the session
and its preview are up. Every change goes to AlecBBox_change, which saves it and rebuilds the preview; the check button keeps the
cages in one undo step (AlecBBox_accept), the cross, Esc or closing drops them (AlecBBox_end).
"""

import importlib
import sys

from pymxs import runtime as rt

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

CAGES = [("Combined", 1), ("Each object", 2)]
AXES = [("World", 1), ("Local", 2)]


class BBoxCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("BBox", "BBox", "OK: keep the cages", "Cancel")

    def build(self):
        s = rt.AlecBBox_active.settings
        self.cages = self.add_choice("Cages", CAGES, 2 if s.each else 1, 2, self.store)
        self.axes = self.add_choice("Axes", AXES, 2 if s.localAxes else 1, 2, self.store)
        self.anchor, self.clear_anchor = self.add_pick("Axes of", "Pick the object whose axes the cages take",
                                                       "Back to the axes of each object (or of the first one, combined)",
                                                       self.pick_anchor, self.clear)
        self.offset = self.add_value("Offset", s.offset, 0.5, 2, AlecTools_caddy.unit_suffix(), lambda: self.store(refit=True))
        self.copy = self.add_toggle("", "+ copy: tight and with offset", s.addCopy, self.store)
        self.layer = self.add_toggle("", "Layer \"BBox helpers\"", s.useLayer, self.store)
        self.add_footer_button("reset", "↺", "Reset to the defaults", self.reset)
        self.show_anchor()

    def show_anchor(self):
        local = self.axes.checkedId() == 2
        self.anchor.setText(str(rt.AlecBBox_anchorText()))
        self.anchor.setEnabled(local)
        self.clear_anchor.setEnabled(local and rt.AlecBBox_active.anchor is not None)

    def store(self, refit=False):
        rt.AlecBBox_change(self.cages.checkedId() == 2, self.axes.checkedId() == 2, self.offset.value(),
                           self.copy.isChecked(), self.layer.isChecked(), refit=refit)
        self.show_anchor()

    def pick_anchor(self):
        rt.AlecBBox_pickAnchor()
        self.show_anchor()

    def clear(self):
        rt.AlecBBox_clearAnchor()
        self.show_anchor()

    # the defaults of AlecBBox_Settings, set without a rebuild for each control, then one store
    def reset(self):
        d = rt.AlecBBox_Settings()
        self.cages.button(2 if d.each else 1).setChecked(True)
        self.axes.button(2 if d.localAxes else 1).setChecked(True)
        AlecTools_caddy.set_quietly(self.offset, self.offset.setValue, d.offset)
        AlecTools_caddy.set_quietly(self.copy, self.copy.setChecked, d.addCopy)
        AlecTools_caddy.set_quietly(self.layer, self.layer.setChecked, d.useLayer)
        self.store()

    def ok(self):
        rt.AlecBBox_accept()
        self.close()

    def closed(self):
        rt.AlecBBox_end()


AlecTools_caddy.show(BBoxCaddy())
