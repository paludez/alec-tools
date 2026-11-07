"""Grab / Rotate / Scale caddy, opened by AlecGrab_run (tools/grab.ms) at the mouse for the selection it took. Keyboard only: one text box
per axis, styled like every text box of the tools (Max turns its shortcuts off for a text box), taking digits and + - * / ( ) . , and all applied together.
Tab and Shift+Tab go through the boxes, X, Y, Z jump to one (in Scale the same key again goes to XYZ). Scale opens on an XYZ box: it
holds for every axis left empty, so X, Y, Z show its value until they are typed in. Every change transforms the selection as a preview
(AlecGrab_preview). Enter or a left click away (in a viewport) accepts (AlecGrab_accept; the click selects nothing), a right click (in a
viewport or on the caddy) or the macro's shortcut again puts it back (AlecGrab_end); see AlecTools_caddy.ViewportClicks. The shortcut of
another caddy of the group accepts and opens that one (AlecTools_caddy.ToggleKey). Esc does nothing: it crashed Max. The help is the
info icon at the end of the row.
"""

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets

import AlecTools_caddy

AXES = "xyz"
# the colors of Max's transform gizmo, from the shared palette; all three axes (scale only) in grey
AXIS_COLORS = [AlecTools_caddy.AXIS_COLORS[a] for a in "xyz"]
ALL_COLOR = AlecTools_caddy.AXIS_COLORS["all"]
VALUE_TEXT = r"[0-9.,+*/() -]*"
FIELD_WIDTH = 56
# the padding of an axis chip around its letter
CHIP_PAD = "1px 3px"

WHAT = {"move": "Type the distance in scene units", "rotate": "Type the angle in degrees (X first, then Y, then Z)",
        "scale": "Type the scale in percent (100 = unchanged)"}


# every key and click of the caddy, one per line ("what: does", see AlecTools_caddy.help_html)
def help_text(mode):
    axes = ("X, Y, Z: go to that axis (the same letter again: back to XYZ, which holds for every axis left empty)" if mode == "scale"
            else "X, Y, Z: go to that axis")
    return "\n".join([
        WHAT[mode] + "; + - * / ( ) work, e.g. 15+28. The selection follows as you type.",
        "Tab / Shift+Tab: next / previous axis",
        axes,
        "Enter: accept",
        "Left click in a viewport: accept (the click selects nothing)",
        "Right click (in a viewport or on the caddy): cancel",
        "This tool's shortcut again: cancel",
        "Shortcut of Grab, Rotate, Scale, Transform Popup or Create Popup: accept and open that one",
        "Axes: Max's reference coordinate system" + ("; center: Max's Use Center" if mode != "move" else ""),
    ])


class GrabCaddy(AlecTools_caddy.ViewportClicks, AlecTools_caddy.Caddy):
    CLICK_AWAY = True
    KEY_TOGGLES = True
    OWN_KEYS = "XYZ"

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

    # a value is typed in a text box: Max turns its shortcuts off while a text box has the focus, so Tab, X, Y, Z
    # and - reach it (a plain widget only gets the keys that are no Max shortcut). Only this caddy moves the focus: a click leaves it
    def field(self, axis):
        line = QtWidgets.QLineEdit()
        line.setFixedWidth(FIELD_WIDTH)
        line.setFrame(False)
        line.setFocusPolicy(QtCore.Qt.NoFocus)
        line.setValidator(QtGui.QRegularExpressionValidator(QtCore.QRegularExpression(VALUE_TEXT), line))
        line.installEventFilter(self)
        # a right click cancels (ViewportClicks sees it), it opens no edit menu
        line.setContextMenuPolicy(QtCore.Qt.NoContextMenu)
        line.textChanged.connect(lambda text: self.changed(axis, text))
        return line

    # a label only as wide as its text: the row never stretches it
    def tight(self, label):
        label.setSizePolicy(QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Fixed)
        return label

    def build(self):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(4)
        title = self.tight(QtWidgets.QLabel(self.section))
        title.setStyleSheet("color: {};".format(AlecTools_caddy.COLORS["muted"]))
        row.addWidget(title)
        self.chips = {}
        self.lines = {}
        for axis in self.axes:
            self.chips[axis] = self.tight(QtWidgets.QLabel(AXES[axis - 1].upper() if axis else "XYZ"))
            self.chips[axis].setAlignment(QtCore.Qt.AlignCenter)
            self.lines[axis] = self.field(axis)
            row.addWidget(self.chips[axis])
            row.addWidget(self.lines[axis])
        self.result = self.tight(QtWidgets.QLabel())
        self.result.setObjectName("result")
        row.addWidget(self.result)
        icon = self.help_icon(help_text(self.mode))
        if icon is not None:
            row.addWidget(icon)
        self.rows.addLayout(row, 0, 0)
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
            look = "background: {}; color: {};".format(color, AlecTools_caddy.COLORS["value"]) if axis == self.axis else "background: transparent; color: {};".format(color)
            self.chips[axis].setStyleSheet(look + " font-weight: bold; border-radius: 3px; padding: {};".format(CHIP_PAD))
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

    # Tab, X, Y, Z change the field instead of being typed; Enter accepts
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

    def ok(self):
        rt.AlecGrab_accept(self.values())
        self.close()

    def closed(self):
        rt.AlecGrab_end()


AlecTools_caddy.show(GrabCaddy())
