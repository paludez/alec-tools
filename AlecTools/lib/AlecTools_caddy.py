"""Shared Max-style caddy for Alec Tools: a frameless dark panel that opens in the active viewport, at the spot it was left in a viewport
(the first time the middle), rows of options and check / cross buttons. A tool subclasses Caddy, adds its rows in build(), overrides ok()
and, when closing must undo something (a preview), closed(). Only one caddy is open at a time; AlecTools_caddyOpen holds its section
("" when none), so MAXScript can tell, and AlecTools_closeCaddy (lib/common.ms) closes it.
Imported by a tool file (lib/ is put on sys.path and the module reloaded, so Reload Alec Tools picks up changes).

Esc does nothing on a panel: it crashed Max (see without_escape). Enter runs ok() while the panel has the focus.
"""

import ast
import ctypes
import json
import operator
import os
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
QLineEdit#value { background: #2b2b2b; color: #dddddd; border: 1px solid #222222; padding: 1px 2px; selection-background-color: #1f6fd6; selection-color: white; }
QLineEdit#value:disabled { color: #666666; }
#result { color: #f0c040; padding: 2px 4px; }
#help { color: #888888; font-size: 10px; }
QToolButton { background: #555555; color: #dddddd; border: 1px solid #222222; border-radius: 3px; min-width: 26px; min-height: 22px; font-size: 13px; }
QToolButton:hover { background: #6a6a6a; }
QToolButton:disabled { color: #777777; }
QToolButton#ok { color: #7fd36b; }
QToolButton#cancel { color: #e06060; }
"""

PICK_TAG_STYLE = """
#AlecToolsCaddy { background: #f0c040; border: 1px solid #222222; border-radius: 4px; }
#result { color: #202020; font-weight: bold; }
"""
# pixels between the top of the viewport and the pick tag, past the viewport's labels
PICK_TAG_TOP = 30

OBJECT_NAME = "AlecToolsCaddy"
ESC_WAIT = 2.0
VK_ESCAPE = 0x1B
# the Windows keys of the modifiers and what Qt calls them
VK_MODIFIERS = {0x10: QtCore.Qt.ShiftModifier, 0x11: QtCore.Qt.ControlModifier, 0x12: QtCore.Qt.AltModifier}
# the keys that cannot be the key of a shortcut: mouse buttons, modifiers (also their left and right ones), Win keys, Esc
NOT_SHORTCUT_KEYS = {0x01, 0x02, 0x04, 0x05, 0x06, 0x10, 0x11, 0x12, 0x5B, 0x5C, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, VK_ESCAPE}
# the ladder's steps, left to right; it opens with LADDER_START under the mouse
LADDER_STEPS = [100, 10, 1, 0.1, 0.01, 0.001]
# the steps of a rotation row's ladder while Shift is held, as many as LADDER_STEPS
ANGLE_STEPS = [180, 90, 45, 15, 5, 1]
# how many times more drag a step of ANGLE_STEPS takes than the pixels per step setting
ANGLE_PIXELS = 10
LADDER_START = 2
LADDER_CELL = QtCore.QSize(64, 44)
# pixels of vertical drag per step of a ladder, unless the toolbar editor's file says otherwise
LADDER_PIXELS = 8


# where the toolbar editor saves its settings; the panels read the mini help choice from it
def toolbar_config_file():
    return os.path.join(rt.getDir(rt.Name("userScripts")), "AlecTools.toolbar.json")


# on until it is turned off in the toolbar editor
def toolbar_setting(name, default):
    if not os.path.isfile(toolbar_config_file()):
        return default
    with open(toolbar_config_file(), encoding="utf-8") as f:
        return json.load(f).get(name, default)


def help_shown():
    return toolbar_setting("showHelp", True)


# the folders set in the toolbar editor where texture dialogs start, the ones that exist on this machine
def map_folders():
    return [folder for folder in toolbar_setting("mapFolders", []) if os.path.isdir(folder)]


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


# a value ladder laid out in a row (Houdini's stands up): the steps around the mouse, the one in use highlighted, and the value
class Ladder(QtWidgets.QWidget):
    def __init__(self, parent, lost):
        super().__init__(parent, QtCore.Qt.ToolTip | QtCore.Qt.FramelessWindowHint)
        self.lost = lost
        self.setMouseTracking(True)
        self.row = LADDER_START
        self.steps = LADDER_STEPS
        self.text = ""
        self.resize(LADDER_CELL.width() * len(LADDER_STEPS), LADDER_CELL.height())

    # opens with its LADDER_START cell under pos, kept inside the screen (the toolbar may be at its bottom edge); returns
    # where that cell's middle ended up, where the mouse is put
    def open(self, pos, screen):
        w, h = LADDER_CELL.width(), LADDER_CELL.height()
        x = max(screen.left(), min(screen.right() - self.width(), pos.x() - w * LADDER_START - w // 2))
        y = max(screen.top(), min(screen.bottom() - self.height(), pos.y() - h // 2))
        self.move(x, y)
        self.show()
        return QtCore.QPoint(x + w * LADDER_START + w // 2, y + h // 2)

    # the step under a screen point while it is over the ladder's row, else None
    def row_at(self, pos):
        if not self.geometry().top() <= pos.y() <= self.geometry().bottom():
            return None
        return max(0, min(len(LADDER_STEPS) - 1, (pos.x() - self.x()) // LADDER_CELL.width()))

    def set(self, row, text, steps):
        self.row, self.text, self.steps = row, text, steps
        self.update()

    def paintEvent(self, event):
        p = QtGui.QPainter(self)
        for i, step in enumerate(self.steps):
            rect = QtCore.QRect(QtCore.QPoint(i * LADDER_CELL.width(), 0), LADDER_CELL)
            p.fillRect(rect, QtGui.QColor("#5a7aa0" if i == self.row else "#3a3a3a"))
            p.setPen(QtGui.QColor("#1e1e1e"))
            p.drawRect(rect.adjusted(0, 0, -1, -1))
            p.setPen(QtGui.QColor("#e0e0e0"))
            text = "{:g}".format(step)
            if i == self.row:
                text += "\n" + self.text
            p.drawText(rect, QtCore.Qt.AlignCenter, text)

    # during a drag the mouse goes to the dragged widget, so the mouse reaching the ladder means that widget missed the release
    # (Alt+Tab, a dialog): touching the ladder closes it
    def mouseMoveEvent(self, event):
        if not event.buttons() & QtCore.Qt.MiddleButton:
            self.lost()

    def mousePressEvent(self, event):
        self.lost()

    def mouseReleaseEvent(self, event):
        self.lost()


# a middle drag on a widget: up/down changes the value by the step in use, like a Max spinner; the step is picked by going
# left/right over the ladder (away from it the step stays, however the mouse drifts), as in Houdini. The mouse is followed
# as a pointer of its own, and the cursor stays on the ladder's row as if pushing against it: up/down never takes it up the
# screen, and left/right moves it along the ladder only while the pointer is on the row. It reports the total change since
# the press
class LadderDrag:
    def __init__(self, widget, fields, axes):
        self.fields = fields
        self.axes = axes
        self.ladder = Ladder(widget, self.finish)
        self.state = None

    def active(self):
        return self.state is not None

    def press(self, event):
        if event.button() != QtCore.Qt.MiddleButton:
            return False
        self.finish()
        press = event.globalPosition().toPoint()
        screen = QtGui.QGuiApplication.screenAt(press).geometry()
        # before the ladder opens, so that a failure here leaves nothing open
        self.fields.drag_start()
        pos = self.ladder.open(press, screen)
        QtGui.QCursor.setPos(pos)
        self.state = {"cursor": pos, "pointer": QtCore.QPoint(pos), "pixels": 0, "row": LADDER_START, "base": 0.0,
                      "delta": 0.0, "steps": LADDER_STEPS}
        self.ladder.set(LADDER_START, self.fields.drag_text(self.axes, 0.0), LADDER_STEPS)
        return True

    # moves the pointer by what the mouse moved since the cursor was last placed; the cursor goes back to the ladder's row,
    # under the pointer while it is on the row, else where it was
    def follow(self, pos):
        s = self.state
        moved = pos - s["cursor"]
        s["pointer"] += moved
        s["pixels"] -= moved.y()
        x = s["cursor"].x()
        if self.ladder.row_at(s["pointer"]) is not None:
            x = max(self.ladder.x(), min(self.ladder.geometry().right(), s["pointer"].x()))
        cursor = QtCore.QPoint(x, self.ladder.geometry().center().y())
        if cursor != pos:
            QtGui.QCursor.setPos(cursor)
        s["cursor"] = cursor

    def move(self, event):
        if self.state is None:
            return False
        if not event.buttons() & QtCore.Qt.MiddleButton:
            self.finish()
            return True
        s = self.state
        self.follow(event.globalPosition().toPoint())
        row = self.ladder.row_at(s["pointer"])
        # a new step, or Shift switching the steps of a rotation, goes on from the change reached
        steps = ANGLE_STEPS if self.fields.spec.get("angles") and event.modifiers() & QtCore.Qt.ShiftModifier else LADDER_STEPS
        if steps is not s["steps"]:
            s.update(steps=steps, base=s["delta"], pixels=0)
        if row is not None and row != s["row"]:
            s.update(row=row, base=s["delta"], pixels=0)
        pixels = self.fields.pixels * (ANGLE_PIXELS if steps is ANGLE_STEPS else 1)
        delta = s["base"] + int(s["pixels"] / pixels) * steps[s["row"]]
        if delta != s["delta"]:
            s["delta"] = delta
            self.fields.drag_preview(self.axes, delta)
        self.ladder.set(s["row"], self.fields.drag_text(self.axes, delta), steps)
        return True

    def release(self, event):
        if self.state is None or event.button() != QtCore.Qt.MiddleButton:
            return False
        self.finish()
        return True

    # also when the release was missed: what the drag reached stays, as one undo step
    def finish(self):
        if self.state is None:
            return
        delta, self.state = self.state["delta"], None
        self.ladder.hide()
        self.fields.drag_end(self.axes, delta)


# forwards a widget's mouse to its LadderDrag; whatever the drag does not take goes to the widget as usual
class LadderMouse:
    def right_clicked(self):
        pass

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.RightButton:
            self.right_clicked()
        elif not self.drag.press(event):
            super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if not self.drag.move(event):
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if not self.drag.release(event):
            super().mouseReleaseEvent(event)


# a box to type a value or arithmetic in: Enter or leaving it enters what was typed (enter(value)), a click selects all of it.
# A subclass sets decimals and drag (its LadderDrag)
class TypedField(LadderMouse, QtWidgets.QLineEdit):
    decimals = 2

    def __init__(self):
        super().__init__()
        self.value = 0.0
        self.edited = False
        self.textEdited.connect(self.mark_edited)
        # Enter and leaving the box (Tab, a click elsewhere) both enter what was typed
        self.editingFinished.connect(self.typed)

    def enter(self, value):
        pass

    # a click into the box selects all of it, as Tab does; after the click's own cursor placement, which would undo it
    def focusInEvent(self, event):
        super().focusInEvent(event)
        if event.reason() == QtCore.Qt.MouseFocusReason:
            QtCore.QTimer.singleShot(0, self.selectAll)

    def mark_edited(self):
        self.edited = True

    def format_value(self, value):
        return "{:.{}f}".format(value, self.decimals)

    def show_value(self, value):
        self.value = value
        self.edited = False
        text = self.format_value(value)
        if text != self.text():
            self.setText(text)

    def typed(self):
        if not self.edited:
            self.clearFocus()
            return
        # leaving the box with Esc down (Esc closing the popup) drops the edit: MAXScript run from Qt then crashed Max
        if escape_down():
            self.show_value(self.value)
            return
        self.edited = False
        try:
            value = evaluate(self.text())
        except (SyntaxError, ValueError, ZeroDivisionError):
            without_escape(lambda: rt.displayTempPrompt("Alec Tools: not a value: " + self.text(), 3000))()
            value = None
        self.clearFocus()
        if value is None:
            self.show_value(self.value)
        else:
            without_escape(lambda: self.enter(value))()


# the value box of a panel's row, as on the toolbar: type a value or arithmetic, middle drag for the ladder, right click runs on_reset.
# Every change made by the user runs on_change(); Enter stays on the panel (with the focus gone, the next Enter runs ok())
class ValueField(TypedField):
    # what LadderDrag reads of a row of fields: not a rotation
    spec = {}

    def __init__(self, value, decimals, minimum, on_change, on_reset):
        super().__init__()
        self.setObjectName("value")
        self.setContextMenuPolicy(QtCore.Qt.NoContextMenu)
        self.decimals = decimals
        self.minimum = minimum
        self.on_change = on_change
        self.on_reset = on_reset
        self.pixels = toolbar_setting("ladderPixels", LADDER_PIXELS)
        self.start = 0.0
        self.drag = LadderDrag(self, self, [1])
        self.show_value(value)

    def enter(self, value):
        self.show_value(max(self.minimum, value))
        self.on_change()

    def right_clicked(self):
        if self.on_reset is not None:
            self.clearFocus()
            self.on_reset()

    def keyPressEvent(self, event):
        super().keyPressEvent(event)
        if event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
            event.accept()

    def drag_start(self):
        self.edited = False
        self.start = self.value

    def drag_text(self, axes, delta):
        return self.format_value(max(self.minimum, self.start + delta))

    def drag_preview(self, axes, delta):
        self.enter(self.start + delta)

    # the panel's preview already shows it; its check button keeps it
    def drag_end(self, axes, delta):
        pass


# the name of a value: a middle drag or a right click on it works as on the box
class ValueLabel(LadderMouse, QtWidgets.QLabel):
    def __init__(self, text, field):
        super().__init__()
        self.setText(text)
        self.setObjectName("drag")
        self.drag = LadderDrag(self, field, [1])

    def right_clicked(self):
        self.drag.fields.right_clicked()

    def mousePressEvent(self, event):
        if self.drag.fields.isEnabled():
            super().mousePressEvent(event)


# GetKeyState: the state when the message being handled came, so a shortcut released before Python got here still counts
def key_down(vk):
    return bool((ctypes.windll.user32.GetKeyState(vk) | ctypes.windll.user32.GetAsyncKeyState(vk)) & 0x8000)


# Max turns its shortcuts off while a text box has the focus, so the macro cannot close a panel that is being typed in. The keys down when
# the panel opens are the macro's shortcut: the same keys pressed again on the panel cancel it. Opened by a button, there are none
class ToggleKey(QtCore.QObject):
    MODIFIERS = QtCore.Qt.ShiftModifier | QtCore.Qt.ControlModifier | QtCore.Qt.AltModifier

    def __init__(self, caddy):
        super().__init__(caddy)
        self.caddy = caddy
        self.keys = {vk for vk in range(0x08, 0xFF) if vk not in NOT_SHORTCUT_KEYS and key_down(vk)}
        self.modifiers = QtCore.Qt.NoModifier
        for vk, modifier in VK_MODIFIERS.items():
            if key_down(vk):
                self.modifiers |= modifier

    def eventFilter(self, watched, event):
        if (event.type() != QtCore.QEvent.KeyPress or event.isAutoRepeat() or event.nativeVirtualKey() not in self.keys
                or event.modifiers() & self.MODIFIERS != self.modifiers):
            return False
        self.caddy.cancel()
        return True


class Caddy(QtWidgets.QFrame):
    # True in a subclass: a click anywhere else (a viewport, another window) runs clicked_away()
    CLICK_AWAY = False
    was_active = False
    # True in a subclass with text boxes: its macro's shortcut pressed again cancels it (see ToggleKey)
    KEY_TOGGLES = False

    # section: the caddy's name in AlecTools.ini (where it was left) and in AlecTools_caddyOpen.
    # bare: no title and no check / cross buttons (a keyboard-only panel such as Grab's), opened at the mouse
    def __init__(self, section, title, ok_tip, cancel_tip, bare=False):
        super().__init__(GetQMaxMainWindow(), QtCore.Qt.Tool | QtCore.Qt.FramelessWindowHint)
        self.setObjectName(OBJECT_NAME)
        self.section = section
        self.setAttribute(QtCore.Qt.WA_DeleteOnClose)
        self.setStyleSheet(STYLE)
        self.drag = None
        self.bare = bare
        self.values = []

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
            self.footer.addWidget(self.tool_button("ok", "✔", ok_tip, self.ok))
            self.footer.addWidget(self.tool_button("cancel", "✖", cancel_tip, self.cancel))
        self.body.addLayout(self.rows)
        self.build()
        self.body.addLayout(self.footer)

    def build(self):
        pass

    def ok(self):
        pass

    def closed(self):
        pass

    def cancel(self):
        self.close()

    def clicked_away(self):
        self.cancel()

    # only after it has been active once, because showing it fires an activation change before it holds the focus; only once,
    # because closing it fires another
    def changeEvent(self, event):
        if self.CLICK_AWAY and event.type() == QtCore.QEvent.ActivationChange:
            if self.isActiveWindow():
                self.was_active = True
            elif self.was_active:
                self.was_active = False
                self.clicked_away()
        super().changeEvent(event)

    def tool_button(self, name, text, tip, slot):
        b = QtWidgets.QToolButton()
        b.setObjectName(name)
        b.setText(text)
        b.setToolTip(tip)
        # the click takes the focus, so a value still being typed is entered before the button runs
        b.setFocusPolicy(QtCore.Qt.ClickFocus)
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

    # a button that picks an object in the viewport and an x that clears it. Gives (pick button, clear button); the tool sets their text and enabled state
    def add_pick(self, label, tip, clear_tip, on_pick, on_clear):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(0)
        pick = QtWidgets.QPushButton()
        pick.setToolTip(tip)
        pick.clicked.connect(lambda c: on_pick())
        clear = QtWidgets.QPushButton("x")
        clear.setToolTip(clear_tip)
        clear.clicked.connect(lambda c: on_clear())
        row.addWidget(pick, 1)
        row.addWidget(clear)
        self.add_row(label, row)
        return pick, clear

    # a value box with its unit (see ValueField). Gives the box: .value is the value, show_value() sets it without on_change()
    def add_value(self, label, value, decimals, suffix, on_change, minimum=-1e6, on_reset=None):
        field = ValueField(value, decimals, minimum, on_change, on_reset)
        row = QtWidgets.QHBoxLayout()
        row.addWidget(field, 1)
        if suffix:
            row.addWidget(QtWidgets.QLabel(suffix.strip()))
        self.add_row(ValueLabel(label, field), row)
        self.values.append(field)
        return field

    # a wide button on its own row
    def add_button(self, label, text, tip, slot):
        b = QtWidgets.QPushButton(text)
        b.setToolTip(tip)
        b.clicked.connect(lambda c: slot())
        self.add_row(label, b)
        return b

    # the mini help under the rows, unless it is turned off in the toolbar editor. Gives the label, or None when it is off
    def add_help(self, text):
        if not help_shown():
            return None
        label = QtWidgets.QLabel(text)
        label.setObjectName("help")
        self.body.addWidget(label)
        return label

    # a highlighted line of text under the rows
    def add_result(self):
        result = QtWidgets.QLabel("")
        result.setObjectName("result")
        self.body.addWidget(result)
        return result

    def showEvent(self, event):
        rt.AlecTools_caddyOpen = self.section

    def closeEvent(self, event):
        if rt.AlecTools_caddyOpen == self.section:
            rt.AlecTools_caddyOpen = ""
        # closing drops what was typed and not entered, so the box losing the focus runs nothing after closed()
        for field in self.values:
            field.edited = False
        # an Esc down while it closes would interrupt the undoing of the preview, or Max's own button checks right after it
        without_escape(self.closed, until_released=True)()

    # taken here, so Esc goes no further
    def keyPressEvent(self, event):
        if event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
            self.ok()

    # dragged by any empty part of the panel
    def mousePressEvent(self, event):
        self.drag = event.globalPosition().toPoint() - self.pos()

    def mouseMoveEvent(self, event):
        if self.drag is not None:
            self.move(event.globalPosition().toPoint() - self.drag)

    # the place is kept relative to the active viewport, so it opens at the same spot of whichever viewport is active (a bare one opens at
    # the mouse, so it keeps none)
    def mouseReleaseEvent(self, event):
        if self.drag is not None and not self.bare:
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


# beside the mouse, kept on its screen
def at_mouse(caddy):
    mouse = QtGui.QCursor.pos()
    area = (QtGui.QGuiApplication.screenAt(mouse) or QtGui.QGuiApplication.primaryScreen()).availableGeometry()
    caddy.move(max(area.left(), min(mouse.x() + 16, area.right() - caddy.width())),
               max(area.top(), min(mouse.y() + 16, area.bottom() - caddy.height())))


# closes a caddy still open (from this tool or another), then shows the new one in the active viewport
def show(caddy):
    if caddy.KEY_TOGGLES:
        caddy.toggle_key = ToggleKey(caddy)
        for widget in [caddy] + caddy.findChildren(QtWidgets.QWidget):
            widget.installEventFilter(caddy.toggle_key)
    close_all()
    caddy.adjustSize()
    if caddy.bare:
        at_mouse(caddy)
    else:
        place(caddy)
    caddy.show()
    caddy.activateWindow()


# a bright tag at the top of the active viewport while a tool waits for an object to be clicked (AlecTools_showPickTag, lib/common.ms), so
# the wait cannot be missed. It takes no clicks and no focus, and stays where it is: following the mouse with a timer made the picking very slow
class PickTag(Caddy):
    def __init__(self, text):
        self.text = text
        super().__init__("Pick Tag", "", "", "", bare=True)

    def build(self):
        self.setWindowFlag(QtCore.Qt.WindowTransparentForInput)
        self.setWindowFlag(QtCore.Qt.WindowDoesNotAcceptFocus)
        self.setAttribute(QtCore.Qt.WA_ShowWithoutActivating)
        self.setStyleSheet(self.styleSheet() + PICK_TAG_STYLE)
        self.add_result().setText(self.text + "\nright click or Esc = cancel")


def show_pick_tag(text):
    tag = PickTag(text)
    show(tag)
    view = view_rect()
    tag.move(view.center().x() - tag.width() // 2, view.top() + PICK_TAG_TOP)
