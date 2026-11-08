"""Shared Max-style caddy for Alec Tools: frameless and dark, it opens in the active viewport, at the spot it was left in a viewport
(the first time the middle), with a title band, rows of options and OK / Cancel buttons at the bottom. The help is a small info icon
whose tooltip explains the caddy (add_help: at the right end of the title band, help_icon: an icon to place in a row of one's own).
A tool subclasses Caddy, adds its rows in build(), overrides ok()
and, when closing must undo something (a preview), closed(). Only one caddy is open at a time; AlecTools_caddyOpen holds its section
("" when none), so MAXScript can tell, and AlecTools_closeCaddy (lib/common.ms) closes it.
Imported by a tool file; lib/common.ms puts lib/ on sys.path and reloads this module at every load, so Reload Alec Tools picks up changes.

Esc does nothing on a caddy: it crashed Max (see without_escape). Enter runs ok() while the caddy has the focus.
"""

import ast
import ctypes
import html
import json
import operator
import os
import time
from xml.etree import ElementTree

import pymxs
from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

# one palette for every caddy of the tools; a tool takes its colors from here, not its own hex values
COLORS = {
    "panel": "#444444",      # the caddy's background, Max's panel gray
    "border": "#222222",
    "chip": "#3a3a3a",       # a button or a box at rest
    "chip_hover": "#555555",
    "text": "#cccccc",
    "value": "#ffffff",      # what is typed or chosen
    "title_band": "#303030", # the band across the top with the title
    "title": "#e6e6e6",
    "muted": "#aaaaaa",
    "disabled": "#666666",
    "accent": "#5b8fc7",     # a pressed choice, the selection in a box
    "ok": "#7fd36b",
    "error": "#e06060",
    "result": "#f0c040",     # a result line, the pick tag
    "dark_text": "#202020",  # text on a light fill (the pick tag, a hovered OK)
}
# the colors of Max's transform gizmo, and the one for all three axes
AXIS_COLORS = {"x": "#e05050", "y": "#60c060", "z": "#5080e0", "all": "#777777"}

# one look for every text box of the tools (caddies, the Grab caddy, the toolbar's fields): dark, rounded, white text
INPUT_STYLE = """
QLineEdit {{ background: {chip}; color: {value}; border: none; border-radius: 3px; padding: 2px 4px;
    selection-background-color: {accent}; selection-color: {value}; }}
QLineEdit:disabled {{ color: {disabled}; }}
""".format(**COLORS)

# one button look, the Scale caddy's chips: flat, rounded, filled with a color when pressed or hovered
STYLE = INPUT_STYLE + """
#AlecToolsCaddy {{ background: {panel}; border: 1px solid {border}; border-radius: 4px; }}
#titleBand, #title {{ background: {title_band}; border-top-left-radius: 3px; border-top-right-radius: 3px; }}
#title {{ color: {title}; font-weight: bold; padding: 4px 7px; }}
QToolTip {{ background: {chip}; color: {text}; border: 1px solid {border}; padding: 4px; }}
QLabel {{ color: {text}; }}
QLabel#drag:hover {{ color: {value}; }}
QPushButton {{ background: {chip}; color: {text}; border: none; border-radius: 3px; padding: 2px 7px; outline: none; }}
QPushButton:hover {{ background: {chip_hover}; }}
QPushButton:checked {{ background: {accent}; color: {value}; }}
QPushButton:disabled {{ background: transparent; color: {disabled}; }}
QPushButton#ok, QPushButton#cancel, QPushButton#reset {{ min-width: 52px; padding: 3px 10px; }}
QPushButton#ok {{ color: {ok}; font-weight: bold; }}
QPushButton#ok:hover {{ background: {ok}; color: {dark_text}; }}
QPushButton#cancel:hover {{ background: {error}; color: {value}; }}
#section {{ color: {title}; font-weight: bold; padding: 4px 1px 0px 1px; }}
#result {{ color: {result}; padding: 1px 2px; }}
""".format(**COLORS)

# the help icon: Qt's own information icon, small, dimmed until the mouse is on it; its tooltip is the caddy's help
HELP_ICON = ":/qt-project.org/styles/commonstyle/images/information-32.png"
HELP_ICON_SIZE = 14
HELP_ICON_DIM = 0.6

PICK_TAG_NAME = "AlecToolsPickTag"
PICK_TAG_STYLE = """
#AlecToolsPickTag {{ background: {result}; border: 1px solid {border}; border-radius: 4px; }}
#AlecToolsPickTag QLabel {{ color: {dark_text}; font-weight: bold; padding: 1px 6px; }}
""".format(**COLORS)
# pixels between the top of the viewport and the pick tag, past the viewport's labels
PICK_TAG_TOP = 30

OBJECT_NAME = "AlecToolsCaddy"
# pixels between the chips of a row
CHIP_GAP = 2
ESC_WAIT = 2.0
# how long a hint (show_hint) stays in the viewport
HINT_MS = 2000
VK_RETURN = 0x0D
# how often the Enter watcher (Caddy.ENTER_WATCH) reads the key
ENTER_MS = 50
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


# where the toolbar editor saves its settings; the caddies read the mini help choice from it
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


# Esc does nothing on a window of the tools that would close on it (a Qt popup, a dialog, a menu): first in the bases, e.g.
# class Picker(AlecTools_caddy.NoEscape, QtWidgets.QWidget). A child that does not use Esc (a text box, a tree) passes it up to the window
class NoEscape:
    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            event.accept()
        else:
            super().keyPressEvent(event)


# every menu of the tools (a submenu too: menu.addMenu(Menu(title, menu)))
class Menu(NoEscape, QtWidgets.QMenu):
    pass


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
            p.fillRect(rect, QtGui.QColor(COLORS["accent"] if i == self.row else COLORS["chip"]))
            p.setPen(QtGui.QColor(COLORS["border"]))
            p.drawRect(rect.adjusted(0, 0, -1, -1))
            p.setPen(QtGui.QColor(COLORS["value"]))
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
        # leaving the box with Esc down (Esc closing the caddy) drops the edit: MAXScript run from Qt then crashed Max
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


# the value box of a caddy's row, as on the toolbar: type a value or arithmetic, middle drag for the ladder, right click runs on_reset.
# Every change made by the user runs on_change(); Enter stays on the caddy (with the focus gone, the next Enter runs ok())
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

    # the caddy's preview already shows it; its OK keeps it
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


# the keys and modifiers down now, as (set of Windows keys, Qt modifiers): the shortcut a macro was just run with (none when a button ran it)
def pressed_shortcut():
    keys = {vk for vk in range(0x08, 0xFF) if vk not in NOT_SHORTCUT_KEYS and key_down(vk)}
    modifiers = QtCore.Qt.NoModifier
    for vk, modifier in VK_MODIFIERS.items():
        if key_down(vk):
            modifiers |= modifier
    return keys, modifiers


# the caddies that give way to each other (section: macro name). Opening one accepts the one that is open first, its typed change kept
SWITCH_MACROS = {"Grab": "Grab", "Rotate": "Rotate", "Scale": "Scale", "Transform Popup": "TransformPopup", "Create Popup": "CreatePopup"}
# section: (keys, modifiers) of the shortcut its macro was last run with, learned by note_shortcut
SHORTCUTS = {}
# the action table of the macroScripts in Max's hotkey file: an action's Id there is "647394-<macro>`<category>"
MACRO_TABLE = "647394"
# the Windows keys of the keys Qt names that are no character (a character's key comes from the keyboard layout, VkKeyScanW)
QT_KEY_VK = {QtCore.Qt.Key_Tab: 0x09, QtCore.Qt.Key_Backspace: 0x08, QtCore.Qt.Key_Return: 0x0D, QtCore.Qt.Key_Enter: 0x0D,
             QtCore.Qt.Key_Insert: 0x2D, QtCore.Qt.Key_Delete: 0x2E, QtCore.Qt.Key_Home: 0x24, QtCore.Qt.Key_End: 0x23,
             QtCore.Qt.Key_PageUp: 0x21, QtCore.Qt.Key_PageDown: 0x22, QtCore.Qt.Key_Left: 0x25, QtCore.Qt.Key_Up: 0x26,
             QtCore.Qt.Key_Right: 0x27, QtCore.Qt.Key_Down: 0x28}
SHORTCUT_MODIFIERS = QtCore.Qt.ShiftModifier | QtCore.Qt.ControlModifier | QtCore.Qt.AltModifier


# called by AlecTools_switchTool when a macro of SWITCH_MACROS runs: the keys down are its shortcut. The hotkey file already gives
# the shortcuts (file_shortcuts); this one also knows a shortcut changed in the Hotkey Editor and not saved yet. A button leaves it
def note_shortcut(section):
    keys, modifiers = pressed_shortcut()
    if keys:
        SHORTCUTS[section] = (keys, modifiers)


# the Windows key of a Qt key, None for a key it cannot be
def qt_key_vk(key):
    if QtCore.Qt.Key_F1.value <= key.value <= QtCore.Qt.Key_F24.value:
        return 0x70 + key.value - QtCore.Qt.Key_F1.value
    if key in QT_KEY_VK:
        return QT_KEY_VK[key]
    if key.value < 0x10000:
        vk = ctypes.windll.user32.VkKeyScanW(key.value) & 0xFF
        return None if vk == 0xFF else vk
    return None


# a shortcut as Max's hotkey file writes it ("Alt+W", "Ctrl+Shift+M", "Space", "/", "F12") as (set of Windows keys, Qt modifiers);
# None when it is no single key
def parse_shortcut(text):
    sequence = QtGui.QKeySequence(text, QtGui.QKeySequence.PortableText)
    if sequence.count() != 1:
        return None
    vk = qt_key_vk(sequence[0].key())
    return None if vk is None else ({vk}, sequence[0].keyboardModifiers() & SHORTCUT_MODIFIERS)


# Max's active hotkey file: the folder and file 3dsMax.ini names in [CuiConfiguration] (tests/checks/hotkeyFile_check.ms), None
# when there is none
def hotkey_file():
    ini = rt.getMAXIniFile()
    folder = rt.getINISetting(ini, "CuiConfiguration", "CurrentHotkeyDir")
    name = rt.getINISetting(ini, "CuiConfiguration", "CurrentHotkeyFile")
    path = os.path.join(folder, name)
    return path if name and os.path.isfile(path) else None


# section: the shortcuts of the macros of SWITCH_MACROS in Max's active hotkey file
def file_shortcuts():
    path = hotkey_file()
    return {} if path is None else shortcuts_in(path)


# section: the shortcuts of the macros of SWITCH_MACROS in a hotkey file. The file lists changes to Max's defaults in order: an
# Assign_Hotkey gives a Shortcut to an action Id, an Unassign_Hotkey takes it away again
def shortcuts_in(path):
    ids = {"{}-{}`alec tools".format(MACRO_TABLE, macro.lower()): section for section, macro in SWITCH_MACROS.items()}
    try:
        items = list(ElementTree.parse(path).getroot())
    except ElementTree.ParseError as error:
        print("Alec Tools: the hotkey file {} cannot be read ({}), the shortcuts are learned as the macros run".format(path, error))
        return {}
    assigned = []
    for item in items:
        pair = (item.get("Shortcut", ""), ids.get(item.get("Id", "").lower()))
        if pair[1] is None:
            continue
        if item.tag == "Assign_Hotkey" and pair not in assigned:
            assigned.append(pair)
        elif item.tag == "Unassign_Hotkey" and pair in assigned:
            assigned.remove(pair)
    found = {}
    for text, section in assigned:
        shortcut = parse_shortcut(text)
        if shortcut is not None:
            found.setdefault(section, []).append(shortcut)
    return found


# section: every shortcut known for it, from the hotkey file and the one learned this session
def known_shortcuts():
    found = file_shortcuts()
    for section, shortcut in SHORTCUTS.items():
        found.setdefault(section, []).append(shortcut)
    return found


# accepts (ok(), then closes) the caddy of SWITCH_MACROS that is open, so the next one opens with its change kept
def accept_group():
    for caddy in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, OBJECT_NAME):
        if caddy.isVisible() and caddy.section in SWITCH_MACROS:
            without_escape(caddy.ok)()
            if caddy.isVisible():
                caddy.close()


# Max turns its shortcuts off while a text box has the focus, so the macro cannot close a caddy that is being typed in. The keys down when
# the caddy opens are the macro's shortcut: the same keys pressed again on the caddy cancel it. Opened by a button, there are none.
# A caddy of SWITCH_MACROS also knows its own and the others' shortcuts from the hotkey file (known_shortcuts): its own cancels it,
# another one accepts this caddy and runs that macro. Any other key, and a plain key of the caddy's OWN_KEYS, is typed as usual
class ToggleKey(QtCore.QObject):
    def __init__(self, caddy):
        super().__init__(caddy)
        self.caddy = caddy
        self.own = [pressed_shortcut()]
        # macro: its shortcuts
        self.others = {}
        if caddy.section in SWITCH_MACROS:
            for section, shortcuts in known_shortcuts().items():
                if section == caddy.section:
                    self.own += shortcuts
                else:
                    self.others[SWITCH_MACROS[section]] = shortcuts

    def pressed(self, event, shortcuts):
        return any(event.nativeVirtualKey() in keys and event.modifiers() & SHORTCUT_MODIFIERS == modifiers for keys, modifiers in shortcuts)

    # a key without modifiers the caddy uses itself (Grab's X, Y, Z) is never a shortcut there
    def own_key(self, event):
        text = event.text().upper()
        return bool(text) and text in self.caddy.OWN_KEYS and event.modifiers() & SHORTCUT_MODIFIERS == QtCore.Qt.NoModifier

    def eventFilter(self, watched, event):
        if event.type() != QtCore.QEvent.KeyPress or event.isAutoRepeat() or self.own_key(event):
            return False
        if self.pressed(event, self.own):
            self.caddy.cancel()
            return True
        macro = next((m for m, shortcuts in self.others.items() if self.pressed(event, shortcuts)), None)
        if macro is None:
            return False
        accept_group()
        without_escape(lambda: rt.macros.run("Alec Tools", macro))()
        return True


VK_LBUTTON = 0x01
VK_RBUTTON = 0x02
# how often ViewportClicks reads the mouse buttons, and how many reads after both are up it waits for Max to handle the release
CLICK_MS = 40
CLICK_SETTLE = 2
# the event ViewportClicks posts to run the accept or the cancel
CLICK_EVENT = QtCore.QEvent.Type(QtCore.QEvent.registerEventType())


# read from Windows: Max's mouse.buttonStates misses the release of a click that closed a caddy and stays down for the next one
def button_down(vk):
    return bool(ctypes.windll.user32.GetAsyncKeyState(vk) & 0x8000)


# Grab, Rotate, Scale and Transform Popup (before Caddy in the bases, with CLICK_AWAY): a left click away from the caddy (a viewport)
# accepts, ok(); a right click away cancels, cancel(); a right click on the caddy runs right_on_caddy() (cancel unless a subclass
# uses it). The click is seen when the caddy loses the focus (clicked_away) or by a timer that reads the buttons from Windows and
# runs only Python. Once the buttons are up the timer posts CLICK_EVENT, and its handler runs the MAXScript (docs/max-verified.md:
# no MAXScript from a Qt timer). An accepting click is no selection: the selection is put back as it was when the caddy opened,
# before ok(). Neither stops Max's own handling of the click (the quad menu of a right click in a viewport)
class ViewportClicks:
    # a right click on the caddy goes to right_on_caddy below, not to Caddy.mousePressEvent
    RIGHT_CLICK_CANCELS = False
    # True while the caddy runs a pick in a viewport: those clicks belong to the pick
    paused = False

    def showEvent(self, event):
        super().showEvent(event)
        self.selection = list(rt.getCurrentSelection())
        self.click = None
        self.settle = 0
        self.was_down = {VK_LBUTTON: True, VK_RBUTTON: True}
        self.click_timer = QtCore.QTimer(self)
        self.click_timer.timeout.connect(self.watch_clicks)
        self.click_timer.start(CLICK_MS)

    def right_on_caddy(self):
        self.cancel()

    def over_caddy(self):
        return self.frameGeometry().contains(QtGui.QCursor.pos())

    # pure Python, from the timer: notes a new click, then posts the event once both buttons are up
    def watch_clicks(self):
        if self.paused:
            self.was_down = {vk: button_down(vk) for vk in self.was_down}
            self.click = None
            self.settle = 0
            return
        fresh = {vk: button_down(vk) and not self.was_down[vk] for vk in self.was_down}
        self.was_down = {vk: button_down(vk) for vk in self.was_down}
        if self.click is None and fresh[VK_RBUTTON]:
            self.click = "right_on_caddy" if self.over_caddy() else "cancel"
        elif self.click is None and fresh[VK_LBUTTON] and not self.over_caddy():
            self.click = "accept"
        if self.click is None or any(self.was_down.values()):
            self.settle = 0
            return
        self.settle += 1
        if self.settle >= CLICK_SETTLE:
            self.click_timer.stop()
            QtCore.QCoreApplication.postEvent(self, QtCore.QEvent(CLICK_EVENT))

    # the focus went to another window: a button down there is the click; without one (Alt+Tab) the caddy stays
    def clicked_away(self):
        if self.paused:
            return
        if self.click is None and button_down(VK_RBUTTON):
            self.click = "cancel"
        elif self.click is None and button_down(VK_LBUTTON):
            self.click = "accept"

    def event(self, event):
        if event.type() != CLICK_EVENT:
            return super().event(event)
        click, self.click = self.click, None
        if self.isVisible():
            without_escape(getattr(self, click))()
        if self.isVisible():
            self.settle = 0
            self.click_timer.start(CLICK_MS)
        return True

    def accept(self):
        self.keep_selection()
        self.ok()

    # the selection as it was when the caddy opened, without an undo step: the click's own one stays in the undo list
    def keep_selection(self):
        nodes = [n for n in self.selection if rt.isValidNode(n)]
        if {rt.getHandleByAnim(n) for n in rt.getCurrentSelection()} == {rt.getHandleByAnim(n) for n in nodes}:
            return
        with pymxs.undo(False):
            if nodes:
                rt.select(nodes)
            else:
                rt.clearSelection()


# the help text as the tooltip's rich text, kept as written (one line per "\n", not wrapped); what a line that is not indented
# names before its first ": " is bold, so the rows and buttons stand out
def help_html(text):
    lines = []
    for line in text.split("\n"):
        head, colon, rest = line.partition(": ")
        if colon and not line.startswith(" "):
            lines.append("<b>" + html.escape(head) + "</b>: " + html.escape(rest))
        else:
            lines.append(html.escape(line))
    return '<p style="white-space:pre">' + "\n".join(lines) + "</p>"


# the help of a caddy: a small information icon, dimmed until the mouse is on it, the help in its tooltip
class HelpIcon(QtWidgets.QLabel):
    def __init__(self, text):
        super().__init__()
        self.setObjectName("helpIcon")
        self.setPixmap(QtGui.QIcon(HELP_ICON).pixmap(HELP_ICON_SIZE))
        self.setToolTip(help_html(text))
        self.dim = QtWidgets.QGraphicsOpacityEffect(self)
        self.dim.setOpacity(HELP_ICON_DIM)
        self.setGraphicsEffect(self.dim)

    # a click shows the tooltip at once, next to the icon
    def mousePressEvent(self, event):
        QtWidgets.QToolTip.showText(event.globalPosition().toPoint(), self.toolTip(), self)

    def enterEvent(self, event):
        self.dim.setOpacity(1.0)
        super().enterEvent(event)

    def leaveEvent(self, event):
        self.dim.setOpacity(HELP_ICON_DIM)
        super().leaveEvent(event)


class Caddy(QtWidgets.QFrame):
    # True in a subclass: a click anywhere else (a viewport, another window) runs clicked_away()
    CLICK_AWAY = False
    was_active = False
    # True in a subclass with text boxes: its macro's shortcut pressed again cancels it (see ToggleKey)
    KEY_TOGGLES = False
    # the letters a subclass takes itself when typed without a modifier (Grab's X, Y, Z): never a shortcut of another caddy there
    OWN_KEYS = ""
    # True in a subclass whose tool keeps the keyboard in a viewport (a pick, a mouse tool): Enter pressed there runs ok() too
    ENTER_WATCH = False
    # a right click on an empty part of the caddy, or on a button, cancels
    RIGHT_CLICK_CANCELS = True
    # what the Enter watcher posts to accept
    ACCEPT_EVENT = QtCore.QEvent.Type(QtCore.QEvent.registerEventType())

    # section: the caddy's name in AlecTools.ini (where it was left) and in AlecTools_caddyOpen.
    # OK and Cancel are buttons at the bottom (ok_text / cancel_text for other words, e.g. Start).
    # bare: no title band and no OK / Cancel (a keyboard-only caddy such as Grab's), opened at the mouse.
    # buttons=False: the title band but no OK / Cancel (a caddy whose own buttons do the work, such as Max Settings)
    def __init__(self, section, title, ok_tip, cancel_tip, bare=False, ok_text="OK", cancel_text="Cancel", buttons=True):
        super().__init__(GetQMaxMainWindow(), QtCore.Qt.Tool | QtCore.Qt.FramelessWindowHint)
        self.setObjectName(OBJECT_NAME)
        self.section = section
        self.setAttribute(QtCore.Qt.WA_DeleteOnClose)
        self.setStyleSheet(STYLE)
        self.drag = None
        self.bare = bare
        self.value_fields = []

        self.rows = QtWidgets.QGridLayout()
        self.rows.setHorizontalSpacing(6)
        self.rows.setVerticalSpacing(3)
        self.footer = QtWidgets.QHBoxLayout()
        self.footer.setSpacing(4)
        # a full caddy: the title as a band across the top, edge to edge, and the rest inside the margins under it
        self.body = QtWidgets.QVBoxLayout() if not bare else QtWidgets.QVBoxLayout(self)
        # under the band as much room as under OK / Cancel
        self.body.setContentsMargins(6, 6 if not bare else 4, 6, 6)
        self.body.setSpacing(4)
        # the band's row: the title, then room for the help icon at its right end (add_help); None on a bare caddy
        self.title_row = None
        if not bare:
            outer = QtWidgets.QVBoxLayout(self)
            outer.setContentsMargins(1, 1, 1, 0)
            outer.setSpacing(0)
            band = QtWidgets.QFrame()
            band.setObjectName("titleBand")
            self.title_row = QtWidgets.QHBoxLayout(band)
            self.title_row.setContentsMargins(0, 0, 6, 0)
            self.title_row.setSpacing(4)
            heading = QtWidgets.QLabel(title)
            heading.setObjectName("title")
            self.title_row.addWidget(heading)
            self.title_row.addStretch()
            outer.addWidget(band)
            outer.addLayout(self.body)
            if buttons:
                self.footer.addStretch()
                self.footer.addWidget(self.footer_button("ok", ok_text, ok_tip, self.ok))
                self.footer.addWidget(self.footer_button("cancel", cancel_text, cancel_tip, self.cancel))
        self.body.addLayout(self.rows)
        self.build()
        if not bare and buttons:
            self.body.addSpacing(2)
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

    def footer_button(self, name, text, tip, slot):
        b = QtWidgets.QPushButton()
        b.setObjectName(name)
        b.setText(text)
        b.setToolTip(tip)
        # the click takes the focus, so a value still being typed is entered before the button runs
        b.setFocusPolicy(QtCore.Qt.ClickFocus)
        b.clicked.connect(slot)
        return b

    # a button at the bottom, on the left, away from OK and Cancel (e.g. Reset)
    def add_footer_button(self, name, text, tip, slot):
        b = self.footer_button(name, text, tip, slot)
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
        grid.setSpacing(CHIP_GAP)
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
        row.setSpacing(CHIP_GAP)
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

    # a button that picks an object in the viewport and a × that clears it. Gives (pick button, clear button); the tool sets their text and enabled state
    def add_pick(self, label, tip, clear_tip, on_pick, on_clear):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(CHIP_GAP)
        pick = QtWidgets.QPushButton()
        pick.setToolTip(tip)
        pick.clicked.connect(lambda c: on_pick())
        clear = QtWidgets.QPushButton("×")
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
        self.value_fields.append(field)
        return field

    # a wide button on its own row
    def add_button(self, label, text, tip, slot):
        b = QtWidgets.QPushButton(text)
        b.setToolTip(tip)
        b.clicked.connect(lambda c: slot())
        self.add_row(label, b)
        return b

    # the help icon with text ("\n" between its lines) as its tooltip, for the caddy to place itself; None when the mini help is
    # turned off in the toolbar editor
    def help_icon(self, text):
        return HelpIcon(text) if help_shown() else None

    # the help icon at the right end of the title band; on a bare caddy at the top right corner, on a small row of its own.
    # Gives the icon, or None when the mini help is off
    def add_help(self, text):
        icon = self.help_icon(text)
        if icon is None:
            return None
        if self.title_row is not None:
            self.title_row.addWidget(icon, 0, QtCore.Qt.AlignVCenter)
        else:
            row = QtWidgets.QHBoxLayout()
            row.addStretch()
            row.addWidget(icon)
            self.body.insertLayout(0, row)
        return icon

    # a highlighted line of text under the rows
    def add_result(self):
        result = QtWidgets.QLabel("")
        result.setObjectName("result")
        self.body.addWidget(result)
        return result

    def showEvent(self, event):
        rt.AlecTools_caddyOpen = self.section
        if self.ENTER_WATCH:
            self.enter_was_down = button_down(VK_RETURN)
            self.enter_timer = QtCore.QTimer(self)
            self.enter_timer.timeout.connect(self.check_enter)
            self.enter_timer.start(ENTER_MS)

    # a new Enter while the Max window is the active one (a viewport has the keyboard); the caddy takes its own Enter as a key.
    # Only Python here: the accept runs from the posted event
    def check_enter(self):
        down = button_down(VK_RETURN)
        fresh = down and not self.enter_was_down
        self.enter_was_down = down
        if fresh and QtWidgets.QApplication.activeWindow() == GetQMaxMainWindow():
            self.enter_timer.stop()
            QtCore.QCoreApplication.postEvent(self, QtCore.QEvent(self.ACCEPT_EVENT))

    def event(self, event):
        if event.type() != self.ACCEPT_EVENT:
            return super().event(event)
        if self.isVisible():
            without_escape(self.ok)()
        if self.isVisible():
            self.enter_timer.start(ENTER_MS)
        return True

    def closeEvent(self, event):
        if rt.AlecTools_caddyOpen == self.section:
            rt.AlecTools_caddyOpen = ""
        # closing drops what was typed and not entered, so the box losing the focus runs nothing after closed()
        for field in self.value_fields:
            field.edited = False
        # an Esc down while it closes would interrupt the undoing of the preview, or Max's own button checks right after it
        without_escape(self.closed, until_released=True)()

    # taken here, so Esc goes no further
    def keyPressEvent(self, event):
        if event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
            self.ok()

    # dragged by any empty part of the caddy
    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.RightButton and self.RIGHT_CLICK_CANCELS:
            self.cancel()
            return
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
    hide_pick_tag()
    for old in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, OBJECT_NAME):
        if old.isVisible():
            old.close()


# called from MAXScript (a tool's own mouse handling, not a timer): the result line of the open caddy shows the text
def show_result(text):
    for caddy in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, OBJECT_NAME):
        result = caddy.findChild(QtWidgets.QLabel, "result")
        if caddy.isVisible() and result is not None:
            result.setText(text)


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
class PickTag(QtWidgets.QFrame):
    def __init__(self, text):
        super().__init__(GetQMaxMainWindow(), QtCore.Qt.Tool | QtCore.Qt.FramelessWindowHint | QtCore.Qt.WindowTransparentForInput
                         | QtCore.Qt.WindowDoesNotAcceptFocus)
        self.setObjectName(PICK_TAG_NAME)
        self.setAttribute(QtCore.Qt.WA_DeleteOnClose)
        self.setAttribute(QtCore.Qt.WA_ShowWithoutActivating)
        self.setStyleSheet(PICK_TAG_STYLE)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)
        self.label = QtWidgets.QLabel(text)
        self.label.setAlignment(QtCore.Qt.AlignCenter)
        layout.addWidget(self.label)


# the tag is no caddy: showing it closes no caddy and sets no AlecTools_caddyOpen; hide_pick_tag removes only the tag.
# A tag still there is replaced. hint is the second line (a loop that ends with a right click says "done")
def show_pick_tag(text, hint="right click or Esc = cancel"):
    hide_pick_tag()
    tag = PickTag(text + ("\n" + hint if hint else ""))
    tag.adjustSize()
    view = view_rect()
    tag.move(view.center().x() - tag.width() // 2, view.top() + PICK_TAG_TOP)
    tag.show()


# a short message in the viewport for HINT_MS (e.g. "Select objects first"), then it goes; pure Qt, so a timer may close it
def show_hint(text):
    show_pick_tag(text, hint="")
    QtCore.QTimer.singleShot(HINT_MS, lambda: hide_hint(text))


def hide_hint(text):
    for tag in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, PICK_TAG_NAME):
        if tag.findChild(QtWidgets.QLabel).text() == text:
            tag.close()


def hide_pick_tag():
    for old in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, PICK_TAG_NAME):
        old.close()
