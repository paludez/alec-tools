"""BBox caddy (Shift + click on the button, or a toolbar right click), opened by AlecBBox_run (tools/bbox.ms) once the session
and its preview are up. Every change goes to AlecBBox_change, which saves it and rebuilds the preview; OK keeps the
cages in one undo step (AlecBBox_accept), Cancel or closing drops them (AlecBBox_end).
"""

from pymxs import runtime as rt

import AlecTools_caddy

CAGES = [("Combined", 1), ("Each object", 2)]
AXES = [("World", 1), ("Local", 2)]
HELP = "\n".join([
    "The cages show live in the viewports while the caddy is open.",
    "Cages: one cage around the whole selection, or one per object.",
    "Axes: along the world axes, or Local = in the axes of an object.",
    "Axes of (Local only): click, then pick the object whose axes every cage takes;",
    "    × goes back to each object's own axes (combined: the first object's).",
    "Offset: added on every side. Type a value or arithmetic (15+2), then Enter;",
    "    middle drag on the box or its name: up / down changes it, left / right picks the step;",
    "    right click: back to the default.",
    "+ copy: a tight cage plus a copy of it with the offset.",
    "Layer: the cages go into the \"BBox helpers\" layer, else into their object's layer.",
    "Reset: every option back to its default.",
    "OK, or Enter with no value being typed: keeps the cages, in one undo step.",
    "Cancel, or the button / shortcut again: removes them.",
])


class BBoxCaddy(AlecTools_caddy.Caddy):
    # it has value boxes: the macro's shortcut pressed while typing still closes it
    KEY_TOGGLES = True

    def __init__(self):
        super().__init__("BBox", "BBox", "OK: keep the cages", "Cancel")

    def build(self):
        s = rt.AlecBBox_active.settings
        self.cages = self.add_choice("Cages", CAGES, 2 if s.each else 1, 2, self.store)
        self.axes = self.add_choice("Axes", AXES, 2 if s.localAxes else 1, 2, self.store)
        self.anchor, self.clear_anchor = self.add_pick("Axes of", "Pick the object whose axes the cages take",
                                                       "Back to the axes of each object (or of the first one, combined)",
                                                       self.pick_anchor, self.clear)
        self.offset = self.add_value("Offset", s.offset, 2, AlecTools_caddy.unit_suffix(), lambda: self.store(refit=True), on_reset=self.reset_offset)
        self.copy = self.add_toggle("", "+ copy: tight and with offset", s.addCopy, self.store)
        self.layer = self.add_toggle("", "Layer \"BBox helpers\"", s.useLayer, self.store)
        self.copy.setToolTip("A tight cage, plus a copy of it with the offset")
        self.layer.setToolTip("On: the cages go into the \"BBox helpers\" layer. Off: into the layer of their object")
        self.add_footer_button("reset", "Reset", "Back to the defaults", self.reset)
        self.add_help(HELP)
        self.show_anchor()

    def show_anchor(self):
        local = self.axes.checkedId() == 2
        self.anchor.setText(str(rt.AlecBBox_anchorText()))
        self.anchor.setEnabled(local)
        self.clear_anchor.setEnabled(local and rt.AlecBBox_active.anchor is not None)

    def store(self, refit=False):
        rt.AlecBBox_change(self.cages.checkedId() == 2, self.axes.checkedId() == 2, self.offset.value,
                           self.copy.isChecked(), self.layer.isChecked(), refit=refit)
        self.show_anchor()

    def pick_anchor(self):
        rt.AlecBBox_pickAnchor()
        self.show_anchor()

    def clear(self):
        rt.AlecBBox_clearAnchor()
        self.show_anchor()

    def reset_offset(self):
        self.offset.show_value(rt.AlecBBox_Settings().offset)
        self.store(refit=True)

    # the defaults of AlecBBox_Settings, set without a rebuild for each control, then one store
    def reset(self):
        d = rt.AlecBBox_Settings()
        self.cages.button(2 if d.each else 1).setChecked(True)
        self.axes.button(2 if d.localAxes else 1).setChecked(True)
        self.offset.show_value(d.offset)
        AlecTools_caddy.set_quietly(self.copy, self.copy.setChecked, d.addCopy)
        AlecTools_caddy.set_quietly(self.layer, self.layer.setChecked, d.useLayer)
        self.store()

    def ok(self):
        rt.AlecBBox_accept()
        self.close()

    def closed(self):
        rt.AlecBBox_end()


AlecTools_caddy.show(BBoxCaddy())
