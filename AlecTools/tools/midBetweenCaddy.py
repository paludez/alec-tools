"""Mid Between caddy, opened by AlecMidBetween_run (tools/midBetween.ms) every time the tool starts, just before the picking starts; it
stays open while the points are picked:
- left clicks in a viewport pick (the pickPoint / pickObject loop of tools/midBetween.ms runs while the caddy is open);
- OK, or Enter (also in a viewport: Caddy.ENTER_WATCH), moves and closes (AlecMidBetween_accept);
- Cancel, a right click in a viewport (the loop closes the caddy) or on the caddy, and the macro's button or shortcut again cancel
  (AlecMidBetween_end), nothing moves;
- Reset puts the options back to their defaults;
- every option applies at once (AlecMidBetween_change) and the preview follows; the pick waiting in the viewport goes on, or starts
  again when the kind of pick changes.
- the selection follows the points live; OK keeps it, every cancel puts it back.
Esc does nothing.
"""

from pymxs import runtime as rt
from PySide6 import QtWidgets

import AlecTools_caddy

# (text, id, tooltip)
PICK = [("Object pivots", 1, "Left click objects in a viewport: the pivot of each one is a point.\n"
                             "The objects being moved cannot be picked."),
        ("Snap points", 2, "Left click anywhere in a viewport: each click is a point, snapped with Max's snap settings\n"
                           "(the snap toggle is on while picking, and put back after).")]
MIDDLE = [("Average", 1, "The average of the picked points: every point weighs the same."),
          ("Bounding box", 2, "The center of the box around the picked points: only the outermost points count.")]
CENTER = [("Average", 1, "The average of the pivots of the selected objects,\nor of the selected vertices (edges and faces by their vertices)."),
          ("Bounding box", 2, "The center of the tight bounding box of the selected objects,\nor of the selected vertices.")]

HELP = "\n".join([
    "Mid Between moves the selection so its center lands in the middle of the points you pick.",
    "What moves: the selected objects (a selected child goes with its selected parent), or at a",
    "    sub-object level the selected vertices, edges or faces of an Editable Poly or Edit Poly.",
    "Left click in a viewport: picks a point (object pivots or snap points, see Pick).",
    "Yellow markers: the picked points. The selection moves live as you pick.",
    "Pick, Middle of points, Selection center, Move along: apply at once, the picking goes on.",
    "Clear points: drops the points picked so far.",
    "Reset: every option back to its default.",
    "OK, or Enter: keeps the move, one undo step.",
    "Cancel, a right click, or the button / shortcut again: the selection goes back.",
])


def tip_label(text, tip):
    label = QtWidgets.QLabel(text)
    label.setToolTip(tip)
    return label


class MidBetweenCaddy(AlecTools_caddy.Caddy):
    # the picking keeps the keyboard in the viewport
    ENTER_WATCH = True

    def __init__(self):
        super().__init__("MidBetween", "Mid Between", "OK: move the selection", "Cancel")

    # a row of joined buttons with a tooltip on its label and one on each button
    def choice(self, label, tip, items, checked, on_change):
        group = self.add_choice(tip_label(label, tip), [(text, key) for text, key, _ in items], checked, 2, on_change)
        for _, key, button_tip in items:
            group.button(key).setToolTip(button_tip)
        return group

    def build(self):
        s = rt.AlecMidBetween_active.settings
        self.pick = self.choice("Pick", "What a left click in a viewport picks. Each pick adds one point.", PICK,
                                1 if s.fromObjects else 2, self.store)
        self.middle = self.choice("Middle of points", "Where the middle of the picked points is.", MIDDLE,
                                  2 if s.targetBounds else 1, self.store)
        self.center = self.choice("Selection center", "Which center of what moves lands on the middle of the points.", CENTER,
                                  2 if s.bounds else 1, self.store)
        self.axes = self.add_toggles(tip_label("Move along", "The world axes along which the selection moves;\n"
                                                             "an axis switched off keeps its position."),
                                     ["X", "Y", "Z"], [s.x, s.y, s.z], self.store)
        for axis, button in zip("XYZ", self.axes):
            button.setToolTip("Move along world {}: pressed = yes".format(axis))
        self.add_button("", "Clear points", "Drop the points picked so far; the picking goes on from nothing.", self.clear)
        self.add_footer_button("reset", "Reset", "Back to the defaults", self.reset)
        self.add_help(HELP)

    def store(self):
        rt.AlecMidBetween_change(self.center.checkedId() == 2, self.middle.checkedId() == 2, self.pick.checkedId() == 1,
                                 self.axes[0].isChecked(), self.axes[1].isChecked(), self.axes[2].isChecked())

    def clear(self):
        rt.AlecMidBetween_clear()

    def reset(self):
        d = rt.AlecMidBetween_Settings()
        self.pick.button(1 if d.fromObjects else 2).setChecked(True)
        self.middle.button(2 if d.targetBounds else 1).setChecked(True)
        self.center.button(2 if d.bounds else 1).setChecked(True)
        for b, v in zip(self.axes, [d.x, d.y, d.z]):
            b.setChecked(v)
        self.store()

    def ok(self):
        rt.AlecMidBetween_accept()
        self.close()

    def closed(self):
        rt.AlecMidBetween_end()


AlecTools_caddy.show(MidBetweenCaddy())
