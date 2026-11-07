"""Mid Between caddy, opened by AlecMidBetween_run (tools/midBetween.ms) every time the macro runs, just before the picking starts; it
stays open while the points are picked. No OK / Cancel, the keyboard and the mouse decide (like Grab):
- left clicks in a viewport pick (the pickPoint / pickObject loop of tools/midBetween.ms runs while the caddy is open);
- Enter moves and closes (AlecMidBetween_accept). On the caddy it comes as a key; in a viewport it goes to Max, so a timer reads it from
  Windows and posts an event, and the accept runs from that event (a timer runs no MAXScript: docs/max-verified.md);
- a right click in a viewport ends the pick and the loop closes the caddy, a right click on the caddy closes it, and so does the macro's
  button or shortcut again (AlecTools_toggleTool): all cancel (AlecMidBetween_end), nothing moves;
- every option applies at once (AlecMidBetween_change) and the preview follows; the pick waiting in the viewport goes on, or starts
  again when the kind of pick changes.
Esc does nothing.
"""

import ctypes

from pymxs import runtime as rt
from PySide6 import QtCore, QtWidgets
from qtmax import GetQMaxMainWindow

import AlecTools_caddy

VK_RETURN = 0x0D
ENTER_MS = 50

# (text, id, tooltip)
PICK = [("Object pivots", 1, "Left click objects in a viewport: the pivot of each one is a point.\n"
                             "The objects being moved cannot be picked."),
        ("Snap points", 2, "Left click anywhere in a viewport: each click is a point, snapped with Max's snap settings\n"
                           "(the snap toggle is on while picking, and put back after).")]
MIDDLE = [("Average", 1, "The average of the picked points: every point weighs the same."),
          ("Bounding box", 2, "The center of the box around the picked points: only the outermost points count.")]
CENTER = [("Average", 1, "The average of the pivots of the selected objects,\nor of the selected vertices (edges and faces by their vertices)."),
          ("Bounding box", 2, "The center of the tight bounding box of the selected objects,\nor of the selected vertices.")]

HELP = ("Mid Between moves the selection so its center lands in the middle of the points you pick.\n"
        "What moves: the selected objects (a selected child goes with its selected parent), or at a sub-object level\n"
        "the selected vertices, edges or faces of an Editable Poly or Edit Poly.\n"
        "\n"
        "Left click in a viewport: pick a point (object pivots or snap points, see Pick).\n"
        "With nothing selected, the first click picks the object to move.\n"
        "Orange boxes: the picked points. Red box and line: where the center of the selection will land.\n"
        "\n"
        "Enter: move and close (one undo step).\n"
        "Right click (in a viewport or on this caddy), or the Mid Between button or shortcut again: cancel, nothing moves.\n"
        "Every option applies at once and the picking goes on. Esc does nothing.")


def enter_down():
    return bool(ctypes.windll.user32.GetAsyncKeyState(VK_RETURN) & 0x8000)


def tip_label(text, tip):
    label = QtWidgets.QLabel(text)
    label.setToolTip(tip)
    return label


class MidBetweenCaddy(AlecTools_caddy.Caddy):
    # what the Enter watcher posts to accept
    ACCEPT_EVENT = QtCore.QEvent.Type(QtCore.QEvent.registerEventType())

    def __init__(self):
        super().__init__("MidBetween", "Mid Between", "", "", buttons=False)

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
        self.add_help(HELP)

    def store(self):
        rt.AlecMidBetween_change(self.center.checkedId() == 2, self.middle.checkedId() == 2, self.pick.checkedId() == 1,
                                 self.axes[0].isChecked(), self.axes[1].isChecked(), self.axes[2].isChecked())

    def clear(self):
        rt.AlecMidBetween_clear()

    def showEvent(self, event):
        super().showEvent(event)
        self.enter_was_down = enter_down()
        self.enter_timer = QtCore.QTimer(self)
        self.enter_timer.timeout.connect(self.check_enter)
        self.enter_timer.start(ENTER_MS)

    # a new Enter while the Max window is the active one (a viewport has the keyboard); the caddy takes its own Enter as a key.
    # Only Python here: the accept runs from the posted event
    def check_enter(self):
        down = enter_down()
        fresh = down and not self.enter_was_down
        self.enter_was_down = down
        if fresh and QtWidgets.QApplication.activeWindow() == GetQMaxMainWindow():
            self.enter_timer.stop()
            QtCore.QCoreApplication.postEvent(self, QtCore.QEvent(self.ACCEPT_EVENT))

    def event(self, event):
        if event.type() == self.ACCEPT_EVENT:
            if self.isVisible():
                AlecTools_caddy.without_escape(self.ok)()
            return True
        return super().event(event)

    # a right click anywhere on the caddy (its buttons pass it on) cancels; a left press drags it
    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.RightButton:
            self.cancel()
        else:
            super().mousePressEvent(event)

    def ok(self):
        rt.AlecMidBetween_accept()
        self.close()

    def closed(self):
        rt.AlecMidBetween_end()


AlecTools_caddy.show(MidBetweenCaddy())
