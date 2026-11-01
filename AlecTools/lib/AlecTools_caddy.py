"""Shared Max-style caddy for Alec Tools: a frameless dark panel that opens in the active viewport, at the spot it was left in a viewport
(the first time the middle), rows of options and check / cross buttons. A tool subclasses Caddy, adds its rows in build(), overrides ok()
and, when closing must undo something (a preview), closed(). Only one caddy is open at a time; AlecTools_caddyOpen holds its section
("" when none), so MAXScript can tell, and AlecTools_closeCaddy (lib/common.ms) closes it.
Imported by a tool file (lib/ is put on sys.path and the module reloaded, so Reload Alec Tools picks up changes).

Esc closes it, also when the viewport has the focus, but not the Esc that ends a command started from it (busy) or cancels a pick
(read from Windows, see without_escape). Enter runs ok() while the panel has the focus.
"""

import ast
import ctypes
import operator
import time

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

STYLE = """
#AlecToolsCaddy { background: #444444; border: 1px solid #222222; border-radius: 4px; }
#title { color: #dddddd; font-weight: bold; padding: 2px 4px; }
QLabel { color: #cccccc; }
QLabel#drag { color: #cccccc; }
QLabel#drag:hover { color: #ffffff; }
QPushButton { background: #2b2b2b; color: #bbbbbb; border: 1px solid #222222; padding: 2px 6px; }
QPushButton:hover { background: #3a3a3a; }
QPushButton:checked { background: #5b8fc7; color: #ffffff; }
QPushButton:disabled { color: #666666; }
QDoubleSpinBox { background: #2b2b2b; color: #dddddd; border: 1px solid #222222; padding: 1px 2px; }
#result { color: #f0c040; padding: 2px 4px; }
QToolButton { background: #555555; color: #dddddd; border: 1px solid #222222; border-radius: 3px; min-width: 26px; min-height: 22px; font-size: 13px; }
QToolButton:hover { background: #6a6a6a; }
QToolButton:disabled { color: #777777; }
QToolButton#ok { color: #7fd36b; }
QToolButton#cancel { color: #e06060; }
"""

OBJECT_NAME = "AlecToolsCaddy"
ESC_MS = 100
ESC_WAIT = 2.0
VK_ESCAPE = 0x1B
# a drag on a value's label changes it by its step per this many pixels
DRAG_PIXELS = 2


# Esc while MAXScript runs from Qt (a timer, a close) crashes Max sooner or later, also with escapeEnable off: MAXScript keeps the
# interrupt and throws it in the next MAXScript Max itself runs from Qt (its button checks). So no MAXScript runs from a Qt callback
# while Esc is down: a timer tick is skipped, a close waits for the key to come up (at most ESC_WAIT seconds)
def escape_down():
    return bool(ctypes.windll.user32.GetAsyncKeyState(VK_ESCAPE) & 0x8000)


def wait_for_escape_up():
    end = time.monotonic() + ESC_WAIT
    while escape_down() and time.monotonic() < end:
        time.sleep(0.01)


def without_escape(callback, until_released=False):
    def run():
        if until_released:
            wait_for_escape_up()
        elif escape_down():
            return
        escape = rt.escapeEnable
        rt.escapeEnable = False
        try:
            callback()
        finally:
            rt.escapeEnable = escape
    return run


ARITHMETIC = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv}


# a typed value: a number or + - * / of numbers with brackets ("15+28", "30/2"), a decimal comma taken as a point
def evaluate(text):
    def walk(node):
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return float(node.value)
        if isinstance(node, ast.BinOp) and type(node.op) in ARITHMETIC:
            return ARITHMETIC[type(node.op)](walk(node.left), walk(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            return -walk(node.operand) if isinstance(node.op, ast.USub) else walk(node.operand)
        raise ValueError(text)
    return walk(ast.parse(text.replace(",", "."), mode="eval").body)


# the label of a value: a drag up or down on it changes the value, as on the arrows of a Max spinner
class DragLabel(QtWidgets.QLabel):
    def __init__(self, text, spin):
        super().__init__(text)
        self.setObjectName("drag")
        self.setCursor(QtCore.Qt.SizeVerCursor)
        self.spin = spin
        self.start = None

    def mousePressEvent(self, event):
        self.start = (event.globalPosition().y(), self.spin.value())

    def mouseMoveEvent(self, event):
        if self.start is not None:
            steps = int((self.start[0] - event.globalPosition().y()) / DRAG_PIXELS)
            self.spin.setValue(self.start[1] + steps * self.spin.singleStep())

    def mouseReleaseEvent(self, event):
        self.start = None


class Caddy(QtWidgets.QFrame):
    # section: the caddy's name in AlecTools.ini (where it was left) and in AlecTools_caddyOpen.
    # bare: no title and no check / cross buttons (a keyboard-only panel such as Grab's), opened at the mouse
    def __init__(self, section, title, ok_tip, cancel_tip, bare=False):
        super().__init__(GetQMaxMainWindow(), QtCore.Qt.Tool | QtCore.Qt.FramelessWindowHint)
        self.setObjectName(OBJECT_NAME)
        self.section = section
        self.setAttribute(QtCore.Qt.WA_DeleteOnClose)
        self.setStyleSheet(STYLE)
        self.drag = None
        self.busy = False
        self.bare = bare

        self.rows = QtWidgets.QGridLayout()
        self.footer = QtWidgets.QHBoxLayout()
        self.footer.addStretch()
        self.body = QtWidgets.QVBoxLayout(self)
        self.body.setContentsMargins(6, 4, 6, 6)
        self.body.setSpacing(4)
        if not bare:
            heading = QtWidgets.QLabel(title)
            heading.setObjectName("title")
            self.body.addWidget(heading)
            self.footer.addWidget(self.tool_button("ok", "✔", ok_tip, self.run_ok))
            self.footer.addWidget(self.tool_button("cancel", "✖", cancel_tip, self.cancel))
        self.body.addLayout(self.rows)
        self.build()
        self.body.addLayout(self.footer)

        # Esc as a new press only, read from Windows: this timer calls no MAXScript (from a Qt timer it crashed Max while Esc was held)
        self.esc_was_down = True
        self.esc_timer = QtCore.QTimer(self)
        self.esc_timer.timeout.connect(self.check_esc)
        self.esc_timer.start(ESC_MS)

    def build(self):
        pass

    def ok(self):
        pass

    def closed(self):
        pass

    def cancel(self):
        self.close()

    def tool_button(self, name, text, tip, slot):
        b = QtWidgets.QToolButton()
        b.setObjectName(name)
        b.setText(text)
        b.setToolTip(tip)
        b.clicked.connect(slot)
        return b

    # a button left of the check / cross ones (e.g. Reset)
    def add_footer_button(self, name, text, tip, slot):
        b = self.tool_button(name, text, tip, slot)
        self.footer.insertWidget(0, b)
        return b

    # a row: the label on the left, a widget or a layout on the right
    def add_row(self, label, item):
        row = self.rows.rowCount()
        self.rows.addWidget(label if isinstance(label, QtWidgets.QWidget) else QtWidgets.QLabel(label), row, 0, QtCore.Qt.AlignTop)
        if isinstance(item, QtWidgets.QLayout):
            self.rows.addLayout(item, row, 1)
        else:
            self.rows.addWidget(item, row, 1)

    # a row of joined buttons, one pressed at a time; items are (label, id), columns buttons per line.
    # Gives the QButtonGroup: checkedId() is the choice, on_change() runs after a click
    def add_choice(self, label, items, checked, columns, on_change):
        group = QtWidgets.QButtonGroup(self)
        grid = QtWidgets.QGridLayout()
        grid.setSpacing(0)
        for i, (text, id) in enumerate(items):
            b = QtWidgets.QPushButton(text)
            b.setCheckable(True)
            b.setChecked(id == checked)
            group.addButton(b, id)
            grid.addWidget(b, i // columns, i % columns)
        group.idClicked.connect(lambda i: on_change())
        self.add_row(label, grid)
        return group

    # a button that stays pressed (on) or not; on_change() runs after a click
    def add_toggle(self, label, text, checked, on_change):
        b = QtWidgets.QPushButton(text)
        b.setCheckable(True)
        b.setChecked(checked)
        b.clicked.connect(lambda c: on_change())
        self.add_row(label, b)
        return b

    # joined buttons that each stay pressed or not (e.g. X Y Z); on_change() runs after a click. Gives the buttons
    def add_toggles(self, label, texts, states, on_change):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(0)
        buttons = []
        for text, checked in zip(texts, states):
            b = QtWidgets.QPushButton(text)
            b.setCheckable(True)
            b.setChecked(checked)
            b.clicked.connect(lambda c: on_change())
            row.addWidget(b)
            buttons.append(b)
        self.add_row(label, row)
        return buttons

    # a button that picks an object in the viewport (on_pick runs while busy, so the Esc that cancels the pick does not
    # close the caddy) and an x that clears it. Gives (pick button, clear button); the tool sets their text and enabled state
    def add_pick(self, label, tip, clear_tip, on_pick, on_clear):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(0)
        pick = QtWidgets.QPushButton()
        pick.setToolTip(tip)
        pick.clicked.connect(lambda c: self.while_busy(on_pick))
        clear = QtWidgets.QPushButton("x")
        clear.setToolTip(clear_tip)
        clear.clicked.connect(lambda c: on_clear())
        row.addWidget(pick, 1)
        row.addWidget(clear)
        self.add_row(label, row)
        return pick, clear

    # a value field; a drag up or down on its label changes it too. on_change() runs on every change made by the user
    def add_value(self, label, value, step, decimals, suffix, on_change, minimum=-1e6):
        spin = QtWidgets.QDoubleSpinBox()
        spin.setRange(minimum, 1e6)
        spin.setDecimals(decimals)
        spin.setSingleStep(step)
        spin.setSuffix(suffix)
        spin.setValue(value)
        spin.valueChanged.connect(lambda v: on_change())
        self.add_row(DragLabel(label, spin), spin)
        return spin

    # a wide button on its own row
    def add_button(self, label, text, tip, slot):
        b = QtWidgets.QPushButton(text)
        b.setToolTip(tip)
        b.clicked.connect(lambda c: slot())
        self.add_row(label, b)
        return b

    # a highlighted line of text under the rows
    def add_result(self):
        result = QtWidgets.QLabel("")
        result.setObjectName("result")
        self.body.addWidget(result)
        return result

    # fn may start a Max command or a pick that runs until it ends: its Esc does not close the caddy
    def while_busy(self, fn):
        self.busy = True
        try:
            return fn()
        finally:
            self.busy = False
            self.esc_was_down = True

    def run_ok(self):
        self.while_busy(self.ok)

    # a pick started from the caddy runs while busy, and the Esc that cancels it is still down when it ends (see while_busy)
    def check_esc(self):
        down = escape_down()
        fresh = down and not self.esc_was_down and not self.busy
        self.esc_was_down = down
        if fresh:
            self.cancel()

    def showEvent(self, event):
        rt.AlecTools_caddyOpen = self.section

    def closeEvent(self, event):
        self.esc_timer.stop()
        if rt.AlecTools_caddyOpen == self.section:
            rt.AlecTools_caddyOpen = ""
        # the Esc that closed it is still down: without this MAXScript would interrupt the undoing of the preview, or Max's own
        # button checks right after it
        without_escape(self.closed, until_released=True)()

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.cancel()
        elif event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
            self.run_ok()

    # dragged by any empty part of the panel
    def mousePressEvent(self, event):
        self.drag = event.globalPosition().toPoint() - self.pos()

    def mouseMoveEvent(self, event):
        if self.drag is not None:
            self.move(event.globalPosition().toPoint() - self.drag)

    # the place is kept relative to the active viewport, so it opens at the same spot of whichever viewport is active
    def mouseReleaseEvent(self, event):
        if self.drag is not None:
            offset = self.pos() - view_rect().topLeft()
            rt.setINISetting(rt.AlecTools_iniFile(), self.section, "caddyX", str(offset.x()))
            rt.setINISetting(rt.AlecTools_iniFile(), self.section, "caddyY", str(offset.y()))
        self.drag = None


# the active viewport in Qt coordinates (Max gives pixels, Qt divides them by the screen scale); the Max window when none is found
def view_rect():
    window = GetQMaxMainWindow()
    r = rt.AlecTools_activeViewRect()
    if r is None:
        return window.geometry()
    scale = window.screen().devicePixelRatio()
    corner, size = r[0], r[1]
    return QtCore.QRect(int(corner.x / scale), int(corner.y / scale), int(size.x / scale), int(size.y / scale))


# where the caddy was left in the active viewport, the first time its middle; kept fully inside the viewport
def place(caddy):
    view = view_rect()
    x = rt.getINISetting(rt.AlecTools_iniFile(), caddy.section, "caddyX")
    y = rt.getINISetting(rt.AlecTools_iniFile(), caddy.section, "caddyY")
    if x and y:
        pos = view.topLeft() + QtCore.QPoint(int(x), int(y))
    else:
        pos = view.center() - caddy.rect().center()
    caddy.move(max(view.left(), min(pos.x(), view.right() - caddy.width())),
               max(view.top(), min(pos.y(), view.bottom() - caddy.height())))


# sets widgets to new values without their change signals (the tool updates once after)
def set_quietly(widget, setter, value):
    widget.blockSignals(True)
    setter(value)
    widget.blockSignals(False)


# the suffix of a length in the system units, for add_value
UNIT_SUFFIX = {"millimeters": " mm", "centimeters": " cm", "meters": " m", "kilometers": " km", "inches": " in", "feet": " ft", "miles": " mi"}


def unit_suffix():
    return UNIT_SUFFIX.get(str(rt.units.SystemType), "")


def close_all():
    for old in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, OBJECT_NAME):
        if old.isVisible():
            old.close()


# closes a caddy still open (from this tool or another), then shows the new one in the active viewport
def show(caddy):
    close_all()
    caddy.adjustSize()
    if caddy.bare:
        mouse = QtGui.QCursor.pos()
        area = (QtGui.QGuiApplication.screenAt(mouse) or QtGui.QGuiApplication.primaryScreen()).availableGeometry()
        caddy.move(max(area.left(), min(mouse.x() + 16, area.right() - caddy.width())),
                   max(area.top(), min(mouse.y() + 16, area.bottom() - caddy.height())))
    else:
        place(caddy)
    caddy.show()
    caddy.activateWindow()
