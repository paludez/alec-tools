"""Distribute caddy, opened by AlecDistribute_run (tools/distribute.ms) every time the tool starts, once the
session and its preview are up. Every change goes to tools/distribute.ms (AlecDistribute_change, AlecDistribute_setStep, ...), which saves it and
moves the preview again; when fewer than 2 objects are left the caddy closes. OK moves them in one undo step
(AlecDistribute_accept), Cancel or closing puts them back (AlecDistribute_end).
"""

from pymxs import runtime as rt

import AlecTools_caddy

MODES = [("Positions (steps)", 1), ("Gaps (space)", 2)]
AXIS = [("X", 1), ("Y", 2), ("Z", 3)]
SPACE = [("World", 1), ("Local", 2)]
POINTS = [("Min", 1), ("Center", 2), ("Pivot", 3), ("Max", 4)]
HELP = "\n".join([
    "The objects move live while the caddy is open; the viewports show a box around each,",
    "    the line along the axis and the length of every step or gap.",
    "Mode: Positions = equal steps between the same point of each object;",
    "    Gaps = equal space between their bounding boxes.",
    "Along: the axis they are spread on.",
    "Axes: World, or Local = the axes of the object picked in Axes of, else of the anchor.",
    "Axes of (Local only): click, then pick any object; × clears it.",
    "Reference (Positions only): the point of each object that gets the equal steps.",
    "Step / Gap: start at the value that keeps the two end objects in place.",
    "    Type a value or arithmetic (15+2), then Enter: it stays until Mode, Along, Axes",
    "    or Reference change. A negative gap overlaps the objects.",
    "    Middle drag on the box or its name: up / down changes it, left / right picks the step;",
    "    right click: Auto.",
    "Auto: works the step and the gap out again, the two ends in place.",
    "Anchor: click, then pick one of the objects: it stays in place, the others go on both",
    "    sides of it; × = no anchor, the lowest object stays.",
    "Align on X Y Z, Align to (need an anchor): the chosen point of each object goes onto",
    "    the same point of the anchor on these axes (not the one along).",
    "Blend rotations (needs an anchor): from the lowest object to the anchor to the highest.",
    "Show dimensions: the boxes, the line and the lengths in the viewports.",
    "Reset: every option back to its default.",
    "OK, Enter with no value being typed, or a left click in a viewport: moves the objects, one undo step.",
    "Cancel, Esc, a right click, or the button / shortcut again: puts them back.",
])


class DistributeCaddy(AlecTools_caddy.Caddy):
    ENTER_WATCH = True
    # it has value boxes: the macro's shortcut pressed while typing still closes it
    KEY_TOGGLES = True

    def __init__(self):
        super().__init__("Distribute", "Distribute", "OK: move the objects", "Cancel")

    def build(self):
        s = rt.AlecDistribute_active.settings
        suffix = AlecTools_caddy.unit_suffix()
        self.mode = self.add_choice("Mode", MODES, 2 if s.gaps else 1, 2, lambda: self.store(refill=True))
        self.axis = self.add_choice("Along", AXIS, s.axis, 3, lambda: self.store(refill=True))
        self.space = self.add_choice("Axes", SPACE, 2 if s.localAxes else 1, 2, lambda: self.store(refill=True))
        self.axes_of, self.clear_axes = self.add_pick("Axes of", "Pick the object whose axes Local takes", "Back to the axes of the anchor",
                                                      lambda: self.pick(rt.AlecDistribute_pickAxes),
                                                      lambda: self.update(rt.AlecDistribute_setAxesOf(None)))
        self.reference = self.add_choice("Reference", POINTS, s.reference, 4, lambda: self.store(refill=True))
        self.step = self.add_value("Step", 0.0, 2, suffix, lambda: self.update(rt.AlecDistribute_setStep(self.step.value)), minimum=0.0, on_reset=self.auto_values)
        self.gap = self.add_value("Gap", 0.0, 2, suffix, lambda: self.update(rt.AlecDistribute_setGap(self.gap.value)), on_reset=self.auto_values)
        self.auto = self.add_button("", "Auto: keep the two ends in place", "Work the step and the gap out again", self.auto_values)
        self.anchor, self.clear_anchor = self.add_pick("Anchor", "Pick the anchor among the objects: it stays in place",
                                                       "No anchor: the lowest object stays in place",
                                                       lambda: self.pick(rt.AlecDistribute_pickAnchor),
                                                       lambda: self.update(rt.AlecDistribute_setAnchor(None)))
        self.align = self.add_toggles("Align on", ["X", "Y", "Z"], [s.alignX, s.alignY, s.alignZ], self.store)
        self.align_reference = self.add_choice("Align to", POINTS, s.alignReference, 4, self.store)
        self.blend = self.add_toggle("", "Blend rotations: lowest > anchor > highest", s.blend, self.store)
        self.dims = self.add_toggle("", "Show dimensions in the viewports", s.showDims, self.store)
        self.add_footer_button("reset", "Reset", "Back to the defaults", self.reset)
        self.add_help(HELP)
        self.show_state()

    # what applies right now is enabled; the value fields show the step and the gap in use
    def show_state(self):
        sess = rt.AlecDistribute_active
        s = sess.settings
        has_anchor = sess.anchor is not None
        self.step.show_value(sess.step)
        self.gap.show_value(sess.gap)
        self.step.setEnabled(not s.gaps)
        self.gap.setEnabled(s.gaps)
        for b in self.reference.buttons():
            b.setEnabled(not s.gaps)
        self.axes_of.setText(str(rt.AlecDistribute_axesText()))
        self.axes_of.setEnabled(s.localAxes)
        self.clear_axes.setEnabled(s.localAxes and sess.axesOf is not None)
        self.anchor.setText(str(rt.AlecDistribute_anchorText()))
        self.clear_anchor.setEnabled(has_anchor)
        for i, b in enumerate(self.align):
            b.setEnabled(has_anchor and s.axis != i + 1)
        for b in self.align_reference.buttons():
            b.setEnabled(has_anchor)
        self.blend.setEnabled(has_anchor)

    # the viewport clicks of the caddy are paused while a pick runs
    def pick(self, run):
        rt.AlecTools_clickPause()
        self.update(run())

    def auto_values(self):
        self.update(rt.AlecDistribute_auto())

    # enough = what the change gave: false when fewer than 2 objects are left
    def update(self, enough):
        if enough:
            self.show_state()
        else:
            rt.displayTempPrompt("Distribute: fewer than 2 objects left", 3000)
            self.close()

    def store(self, refill=False):
        self.update(rt.AlecDistribute_change(self.mode.checkedId() == 2, self.axis.checkedId(), self.space.checkedId() == 2,
                                       self.reference.checkedId(), self.align[0].isChecked(), self.align[1].isChecked(),
                                       self.align[2].isChecked(), self.align_reference.checkedId(), self.blend.isChecked(),
                                       self.dims.isChecked(), refill=refill))

    # the defaults of AlecDistribute_Settings, then one store that works the step and the gap out again
    def reset(self):
        d = rt.AlecDistribute_Settings()
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
        rt.AlecDistribute_accept()
        self.close()

    def closed(self):
        rt.AlecTools_clickEnd()
        rt.AlecDistribute_end()


AlecTools_caddy.show(DistributeCaddy())
