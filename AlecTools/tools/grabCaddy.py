"""Grab / Rotate / Scale panel, opened by AlecGrab_run (tools/grab.ms) at the mouse for the selection it took. Keyboard only: one text box
per axis, drawn as plain text (Max turns its shortcuts off for a text box), taking digits and + - * / ( ) . , and all applied together.
Tab and Shift+Tab go through the boxes, X, Y, Z jump to one (in Scale the same key again goes to XYZ). Scale opens on an XYZ box: it
holds for every axis left empty, so X, Y, Z show its value until they are typed in. Every change transforms the selection as a preview
(AlecGrab_preview). Enter or a right click (on the panel or in a viewport) accepts (AlecGrab_accept), a left click elsewhere or the
macro's shortcut again puts it back (AlecGrab_end). Esc does nothing: it crashed Max.
"""

import ctypes
import importlib
import sys

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

AXES = "xyz"
# the colors of Max's transform gizmo; all three axes (scale only) in grey
AXIS_COLORS = ["#e05050", "#60c060", "#5080e0"]
ALL_COLOR = "#777777"
VALUE_TEXT = r"[0-9.,+*/() -]*"
FIELD_WIDTH = 56
VK_RBUTTON = 0x02
RIGHT_MS = 100


# read from Windows: Max's mouse.buttonStates misses the release of a click that closed the panel and stays down for the next one
def right_down():
    return bool(ctypes.windll.user32.GetAsyncKeyState(VK_RBUTTON) & 0x8000)


class GrabCaddy(AlecTools_caddy.Caddy):
    CLICK_AWAY = True
    KEY_TOGGLES = True

    def __init__(self):
        # lower: MAXScript names are case-insensitive and keep the spelling they were first seen with (the macro is called Rotate)
        self.mode = str(rt.AlecGrab_mode).lower()
        # the fields, in Tab order: axis 1-3 and, in Scale, 0 (XYZ) first; the panel always opens on the first one
        self.axes = [0, 1, 2, 3] if self.mode == "scale" else [1, 2, 3]
        self.axis = self.axes[0]
        self.empty = 100.0 if self.mode == "scale" else 0.0
        # what each field holds, None while it is empty
        self.typed = dict.fromkeys(self.axes)
        self.suffix = {"rotate": "°", "scale": "%"}.get(self.mode, AlecTools_caddy.unit_suffix())
        name = str(rt.AlecGrab_name())
        super().__init__(name, name, "", "", bare=True)

    # a value is typed in a text box drawn as plain text: Max turns its shortcuts off while a text box has the focus, so Tab, X, Y, Z
    # and - reach it (a plain widget only gets the keys that are no Max shortcut). Only this panel moves the focus: a click leaves it
    def field(self, axis):
        line = QtWidgets.QLineEdit()
        line.setFixedWidth(FIELD_WIDTH)
        line.setFrame(False)
        line.setFocusPolicy(QtCore.Qt.NoFocus)
        line.setStyleSheet("background: transparent; color: #ffffff; font-size: 14px; border: none;")
        line.setValidator(QtGui.QRegularExpressionValidator(QtCore.QRegularExpression(VALUE_TEXT), line))
        line.installEventFilter(self)
        # a right click is an OK (the timer sees it), not the edit menu
        line.setContextMenuPolicy(QtCore.Qt.NoContextMenu)
        line.textChanged.connect(lambda text: self.changed(axis, text))
        return line

    def build(self):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(6)
        title = QtWidgets.QLabel(self.section)
        title.setStyleSheet("color: #aaaaaa;")
        row.addWidget(title)
        self.chips = {}
        self.lines = {}
        for axis in self.axes:
            self.chips[axis] = QtWidgets.QLabel(AXES[axis - 1].upper() if axis else "XYZ")
            self.lines[axis] = self.field(axis)
            row.addWidget(self.chips[axis])
            row.addWidget(self.lines[axis])
        self.result = QtWidgets.QLabel()
        self.result.setObjectName("result")
        row.addWidget(self.result)
        self.rows.addLayout(row, 0, 0)
        self.add_help("Tab or X Y Z axis   Enter / right click OK   Click elsewhere / shortcut cancel")
        self.show_state()

    # what an empty field counts as: in Scale an axis follows XYZ
    def fallback(self, axis):
        return self.value(0) if axis and self.mode == "scale" else self.empty

    def value(self, axis):
        return self.fallback(axis) if self.typed[axis] is None else self.typed[axis]

    def values(self):
        return rt.Point3(self.value(1), self.value(2), self.value(3))

    # the chip of the current field is filled with its color, the others only have their letters in it
    def show_state(self, error=False):
        for axis in self.axes:
            color = AXIS_COLORS[axis - 1] if axis else ALL_COLOR
            look = "background: {}; color: #ffffff;".format(color) if axis == self.axis else "background: transparent; color: {};".format(color)
            self.chips[axis].setStyleSheet(look + " font-weight: bold; border-radius: 3px; padding: 1px 6px;")
            self.lines[axis].setPlaceholderText("{:g}".format(self.fallback(axis)))
        self.result.setText("= " + ("not a value" if error else "{:g}{}".format(self.value(self.axis), self.suffix)))

    # an unreadable value (e.g. "15+" while typing) keeps the last good preview
    def changed(self, axis, text):
        error = False
        try:
            self.typed[axis] = AlecTools_caddy.evaluate(text) if text.strip() else None
        except (SyntaxError, ValueError, ZeroDivisionError):
            error = True
        rt.AlecGrab_preview(self.values())
        self.show_state(error)

    def go_to(self, axis):
        self.axis = axis
        self.lines[axis].setFocus()
        self.lines[axis].selectAll()
        self.show_state()

    def step(self, by):
        self.go_to(self.axes[(self.axes.index(self.axis) + by) % len(self.axes)])

    # in Scale the axis already in use goes back to XYZ
    def jump(self, axis):
        self.go_to(0 if self.mode == "scale" and axis == self.axis else axis)

    # Tab, X, Y, Z change the field instead of being typed; Enter closes
    def eventFilter(self, watched, event):
        if event.type() != QtCore.QEvent.KeyPress:
            return False
        char = event.text().lower()
        if event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
            self.ok()
        elif event.key() == QtCore.Qt.Key_Tab:
            self.step(1)
        elif event.key() == QtCore.Qt.Key_Backtab:
            self.step(-1)
        elif char and char in AXES:
            self.jump(AXES.index(char) + 1)
        else:
            return False
        return True

    def showEvent(self, event):
        super().showEvent(event)
        self.activateWindow()
        self.lines[self.axis].setFocus()
        self.right_was_down = True
        self.right_timer = QtCore.QTimer(self)
        self.right_timer.timeout.connect(self.check_right)
        self.right_timer.start(RIGHT_MS)

    # a new right click in a viewport accepts too (a right click on the panel comes as a mouse event)
    def check_right(self):
        down = right_down()
        fresh = down and not self.right_was_down
        self.right_was_down = down
        if fresh:
            self.right_timer.stop()
            self.ok()

    # a right click in a viewport takes the focus away too, before the timer sees it: that one still accepts
    def clicked_away(self):
        if right_down():
            self.right_timer.stop()
            self.ok()
        else:
            self.cancel()

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.RightButton:
            self.ok()
        else:
            super().mousePressEvent(event)

    def ok(self):
        rt.AlecGrab_accept(self.values())
        self.close()

    def closed(self):
        rt.AlecGrab_end()


AlecTools_caddy.show(GrabCaddy())
