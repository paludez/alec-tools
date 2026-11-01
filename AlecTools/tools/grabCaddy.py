"""Grab / Rotate / Scale panel, opened by AlecGrab_run (tools/grab.ms) at the mouse for the selection it took. Keyboard only: X, Y, Z pick
the axis at any time (in Scale the same key again goes back to all three), digits and + - * / ( ) . , make the value in a text box drawn
as plain text (Max turns its shortcuts off for a text box). Every change transforms the selection as a preview (AlecGrab_preview).
Enter or a right click (on the panel or in a viewport) accepts (AlecGrab_accept), Esc puts it back (AlecGrab_end).
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
VK_RBUTTON = 0x02


class GrabCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        self.mode = str(rt.AlecGrab_mode)
        self.axis = rt.AlecGrab_lastAxis()
        self.empty = 100.0 if self.mode == "scale" else 0.0
        self.value = self.empty
        self.suffix = {"rotate": "°", "scale": "%"}.get(self.mode, AlecTools_caddy.unit_suffix())
        name = str(rt.AlecGrab_name())
        super().__init__(name, name, "", "", bare=True)

    # the value is typed in a text box drawn as plain text: Max turns its shortcuts off while a text box has the focus, so X, Y,
    # Z and - reach it (a plain widget only gets the keys that are no Max shortcut). X, Y, Z are taken out for the axis
    def build(self):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(8)
        title = QtWidgets.QLabel(self.section)
        title.setStyleSheet("color: #aaaaaa;")
        self.axis_label = QtWidgets.QLabel()
        self.line = QtWidgets.QLineEdit()
        self.line.setMinimumWidth(80)
        self.line.setFrame(False)
        self.line.setPlaceholderText("{:g}".format(self.empty))
        self.line.setStyleSheet("background: transparent; color: #ffffff; font-size: 14px; border: none;")
        self.line.setValidator(QtGui.QRegularExpressionValidator(QtCore.QRegularExpression(VALUE_TEXT), self.line))
        self.line.installEventFilter(self)
        # a right click is an OK (the timer sees it), not the edit menu
        self.line.setContextMenuPolicy(QtCore.Qt.NoContextMenu)
        self.line.textChanged.connect(self.changed)
        self.result = QtWidgets.QLabel()
        self.result.setObjectName("result")
        for widget in (title, self.axis_label, self.line, self.result):
            row.addWidget(widget)
        self.rows.addLayout(row, 0, 0)
        axes = "X Y Z axis (again: all)" if self.mode == "scale" else "X Y Z axis"
        hint = QtWidgets.QLabel(axes + "   Enter / right click OK   Esc cancel")
        hint.setStyleSheet("color: #888888; font-size: 10px;")
        self.rows.addWidget(hint, 1, 0)
        self.show_state()

    def show_state(self, error=False):
        self.axis_label.setText(AXES[self.axis - 1].upper() if self.axis else "XYZ")
        self.axis_label.setStyleSheet("background: {}; color: #ffffff; font-weight: bold; border-radius: 3px; padding: 1px 6px;"
                                      .format(AXIS_COLORS[self.axis - 1] if self.axis else ALL_COLOR))
        self.result.setText("= " + ("not a value" if error else "{:g}{}".format(self.value, self.suffix)))

    # an unreadable value (e.g. "15+" while typing) keeps the last good preview
    def changed(self):
        text = self.line.text()
        error = False
        try:
            self.value = AlecTools_caddy.evaluate(text) if text.strip() else self.empty
        except (SyntaxError, ValueError, ZeroDivisionError):
            error = True
        rt.AlecGrab_preview(self.axis, self.value)
        self.show_state(error)

    # in Scale the axis already in use goes back to all three
    def pick_axis(self, axis):
        self.axis = 0 if self.mode == "scale" and axis == self.axis else axis
        self.changed()

    # X, Y, Z change the axis instead of being typed; Esc and Enter close
    def eventFilter(self, watched, event):
        if event.type() != QtCore.QEvent.KeyPress:
            return False
        char = event.text().lower()
        if event.key() == QtCore.Qt.Key_Escape:
            self.cancel()
        elif event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
            self.run_ok()
        elif char and char in AXES:
            self.pick_axis(AXES.index(char) + 1)
        else:
            return False
        return True

    def showEvent(self, event):
        super().showEvent(event)
        self.activateWindow()
        self.line.setFocus()
        self.right_was_down = True
        self.right_timer = QtCore.QTimer(self)
        self.right_timer.timeout.connect(self.check_right)
        self.right_timer.start(AlecTools_caddy.ESC_MS)

    # a new right click in a viewport accepts too (a right click on the panel comes as a mouse event). The button is read from
    # Windows: Max's mouse.buttonStates misses the release of a click that closed the panel and stays down for the next one
    def check_right(self):
        down = bool(ctypes.windll.user32.GetAsyncKeyState(VK_RBUTTON) & 0x8000)
        fresh = down and not self.right_was_down
        self.right_was_down = down
        if fresh:
            self.right_timer.stop()
            self.run_ok()

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.RightButton:
            self.run_ok()
        else:
            super().mousePressEvent(event)

    def ok(self):
        rt.AlecGrab_accept(self.axis, self.value)
        self.close()

    def closed(self):
        rt.AlecGrab_end()


AlecTools_caddy.show(GrabCaddy())
