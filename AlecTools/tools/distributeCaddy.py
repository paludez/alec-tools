"""Distribute caddy (Shift + click on the button, or a toolbar right click), opened by AlecDist_run (tools/distribute.ms) once the
session and its preview are up. Every change goes to tools/distribute.ms (AlecDist_change, AlecDist_setStep, ...), which saves it and
moves the preview again; when fewer than 2 objects are left the caddy closes. The check button moves them in one undo step
(AlecDist_accept), the cross or closing puts them back (AlecDist_end).
"""

import importlib
import sys

from pymxs import runtime as rt

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

MODES = [("Positions (steps)", 1), ("Gaps (space)", 2)]
AXIS = [("X", 1), ("Y", 2), ("Z", 3)]
SPACE = [("World", 1), ("Local", 2)]
POINTS = [("Min", 1), ("Center", 2), ("Pivot", 3), ("Max", 4)]


class DistributeCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("Distribute", "Distribute", "OK: move them", "Cancel")

    def build(self):
        s = rt.AlecDist_active.settings
        suffix = AlecTools_caddy.unit_suffix()
        self.mode = self.add_choice("Mode", MODES, 2 if s.gaps else 1, 2, lambda: self.store(refill=True))
        self.axis = self.add_choice("Axis", AXIS, s.axis, 3, lambda: self.store(refill=True))
        self.space = self.add_choice("Axes", SPACE, 2 if s.localAxes else 1, 2, lambda: self.store(refill=True))
        self.axes_of, self.clear_axes = self.add_pick("Axes of", "Pick the object whose axes Local takes", "Back to the axes of the anchor",
                                                      lambda: self.update(rt.AlecDist_pickAxes()),
                                                      lambda: self.update(rt.AlecDist_setAxesOf(None)))
        self.reference = self.add_choice("Reference", POINTS, s.reference, 4, lambda: self.store(refill=True))
        self.step = self.add_value("Step", 0.0, 2, suffix, lambda: self.update(rt.AlecDist_setStep(self.step.value)), minimum=0.0, on_reset=self.auto_values)
        self.gap = self.add_value("Gap", 0.0, 2, suffix, lambda: self.update(rt.AlecDist_setGap(self.gap.value)), on_reset=self.auto_values)
        self.auto = self.add_button("", "Auto: keep the two ends in place", "Work the step and the gap out again", self.auto_values)
        self.anchor, self.clear_anchor = self.add_pick("Anchor", "Pick the anchor among the objects: it stays in place",
                                                       "No anchor: the lowest object stays in place",
                                                       lambda: self.update(rt.AlecDist_pickAnchor()),
                                                       lambda: self.update(rt.AlecDist_setAnchor(None)))
        self.align = self.add_toggles("Align on", ["X", "Y", "Z"], [s.alignX, s.alignY, s.alignZ], self.store)
        self.align_reference = self.add_choice("Align ref.", POINTS, s.alignReference, 4, self.store)
        self.blend = self.add_toggle("", "Blend rotations: lowest > anchor > highest", s.blend, self.store)
        self.dims = self.add_toggle("", "Show dimensions in the viewports", s.showDims, self.store)
        self.add_footer_button("reset", "↺", "Reset to the defaults", self.reset)
        self.add_help("Changes show live. Step, Gap: type a value or + - * /,\n"
                      "middle drag: ladder, right click: Auto\n"
                      "Anchor: stays in place (none: the lowest object does)\n"
                      "Align and Blend need an anchor\n"
                      "Check moves them, cross puts them back")
        self.show_state()

    # what applies right now is enabled; the value fields show the step and the gap in use
    def show_state(self):
        sess = rt.AlecDist_active
        s = sess.settings
        has_anchor = sess.anchor is not None
        self.step.show_value(sess.step)
        self.gap.show_value(sess.gap)
        self.step.setEnabled(not s.gaps)
        self.gap.setEnabled(s.gaps)
        for b in self.reference.buttons():
            b.setEnabled(not s.gaps)
        self.axes_of.setText(str(rt.AlecDist_axesText()))
        self.axes_of.setEnabled(s.localAxes)
        self.clear_axes.setEnabled(s.localAxes and sess.axesOf is not None)
        self.anchor.setText(str(rt.AlecDist_anchorText()))
        self.clear_anchor.setEnabled(has_anchor)
        for i, b in enumerate(self.align):
            b.setEnabled(has_anchor and s.axis != i + 1)
        for b in self.align_reference.buttons():
            b.setEnabled(has_anchor)
        self.blend.setEnabled(has_anchor)

    def auto_values(self):
        self.update(rt.AlecDist_auto())

    # enough = what the change gave: false when fewer than 2 objects are left
    def update(self, enough):
        if enough:
            self.show_state()
        else:
            rt.displayTempPrompt("Distribute: fewer than 2 objects left", 3000)
            self.close()

    def store(self, refill=False):
        self.update(rt.AlecDist_change(self.mode.checkedId() == 2, self.axis.checkedId(), self.space.checkedId() == 2,
                                       self.reference.checkedId(), self.align[0].isChecked(), self.align[1].isChecked(),
                                       self.align[2].isChecked(), self.align_reference.checkedId(), self.blend.isChecked(),
                                       self.dims.isChecked(), refill=refill))

    # the defaults of AlecDist_Settings, then one store that works the step and the gap out again
    def reset(self):
        d = rt.AlecDist_Settings()
        self.mode.button(2 if d.gaps else 1).setChecked(True)
        self.axis.button(d.axis).setChecked(True)
        self.space.button(2 if d.localAxes else 1).setChecked(True)
        self.reference.button(d.reference).setChecked(True)
        for b, v in zip(self.align, [d.alignX, d.alignY, d.alignZ]):
            b.setChecked(v)
        self.align_reference.button(d.alignReference).setChecked(True)
        self.blend.setChecked(d.blend)
        self.dims.setChecked(d.showDims)
        self.store(refill=True)

    def ok(self):
        rt.AlecDist_accept()
        self.close()

    def closed(self):
        rt.AlecDist_end()


AlecTools_caddy.show(DistributeCaddy())
