"""Transform Popup (Transform Popup macro): the rows of the toolbar's transform fields on a small panel at the mouse, like Max's
Transform Type-In. Three boxes: Move (W, L), Rotate (W, L) and Scale / Size (% and the scene unit), each with its icon at the top
left. The rows are AlecToolbar.TransformFields, so typing, arithmetic, the middle-drag ladder and the right click reset work as on
the toolbar, and they follow the selection through AlecToolbar.refresh_all. X, Y, Z have no letters: the frame of their box is
red, green and blue, as Max's gizmo. The macro run again or a click elsewhere closes it (no Esc). It opens without the focus: click a box to type, Tab goes on.
A mini help under the boxes, unless it is turned off in the toolbar editor.
"""

import importlib
import sys

from pymxs import runtime as rt
from PySide6 import QtCore, QtWidgets

TOOLS = rt.AlecTools_path("tools")
if TOOLS not in sys.path:
    sys.path.append(TOOLS)
LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecToolbar
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

SECTION = "Transform Popup"
HELP = ("Type a value or + - * /, Enter applies, Tab: next\n"
        "Middle drag: ladder (on the name: X Y Z)\n"
        "Rotate, Shift: 180, 90, 45... steps\n"
        "Right click: reset (on the name: X Y Z)\n"
        "W world, L local\n"
        "A click elsewhere or the shortcut closes")

# ---- settings to change by hand ----

# the color of the group icons (the icon files are white; this tints them)
GROUP_TINT = "#2E81C2"
# the icon's place: the left end of the first row's name, before its W / % letter (a row's name is: icon, then the letter).
# Its size is LABEL_ICON_SIZE in AlecToolbar.py (the same as on the toolbar). The rows after the first keep the same width blank
# space under it, so the boxes line up; to move the icon, change where it is inserted in group() (insertWidget(0, mark))
# the space at the left of the icon and the right of the last box (inside the active area of the name: a middle drag or a right
# click there works)
NAME_PAD = 7
# the space above the first row and below the last row of a group (not active: nothing is there)
EDGE_PAD = 4
# the space above and below each row, inside its name's active area; two rows are twice this apart
ROW_PAD = 3
# the space between the three groups, and around all of them (the panel itself has no background)
GROUP_GAP = 6
OUTER_PAD = 8
# the height of the boxes: the height of Max's own X / Y / Z spinners, measured on a screenshot
FIELD_HEIGHT = 18

# colors of the panel (Qt style sheet; border-radius 0 = square corners):
#   QFrame#group  the three groups: Max's panel gray #444444 and its border
#   QLabel        the letters W / L / % / unit
#   QLineEdit     the boxes: Max's spinner colors (fill #646464, border #3e3e3e, text #dcdcdc); :disabled is nothing selected
#   fieldX/Y/Z    the border of the X, Y and Z boxes, faintly red, green and blue; :focus is the box being typed in
#   #help         the mini help: a box like the groups, the panel has no background to read it on
STYLE = """
#AlecToolsCaddy { background: transparent; border: none; }
QFrame#group { background: #444444; border: 1px solid #222222; border-radius: 0px; }
QLabel { color: #b4b8be; background: transparent; }
QLineEdit { background: #646464; color: #dcdcdc; border: 1px solid #3e3e3e; border-radius: 0px; padding: 0px 3px; }
QLineEdit:disabled { color: #8a8a8a; background: #505050; }
QLineEdit#fieldX { border-color: #6b4444; }
QLineEdit#fieldY { border-color: #446b44; }
QLineEdit#fieldZ { border-color: #44546b; }
QLineEdit#fieldX:focus { border-color: #b07a7a; }
QLineEdit#fieldY:focus { border-color: #7ab07a; }
QLineEdit#fieldZ:focus { border-color: #7a90b0; }
QLabel#help { color: #a0a0a0; background: #444444; border: 1px solid #222222; padding: 3px 7px; }
"""


# right clicks on the popup's fields reset them, as on the toolbar (the same filter, with the popup as its panel)
class PopupClicks(AlecToolbar.RightClicks):
    def root(self, obj):
        popup = AlecToolbar.ancestor(obj, TransformPopup)
        return popup if popup is not None and popup.isVisible() else None

    def click(self, root, obj):
        AlecToolbar.reset_fields(obj)


# the groups: (icon, rows), a row being (field name, its caption)
def groups():
    unit = AlecTools_caddy.unit_suffix().strip() or "units"
    return [
        (AlecToolbar.MOVE_ICON, [("WorldPosition", " W"), ("LocalOffset", " L")]),
        (AlecToolbar.ROTATE_ICON, [("WorldRotation", " W"), ("LocalRotation", " L")]),
        (AlecToolbar.SCALE_ICON, [("Scale", " %"), ("Size", unit)]),
    ]


class TransformPopup(AlecTools_caddy.Caddy):
    CLICK_AWAY = True
    KEY_TOGGLES = True

    def __init__(self):
        super().__init__(SECTION, SECTION, "", "", bare=True)

    def group(self, icon, rows, config):
        frame = QtWidgets.QFrame()
        frame.setObjectName("group")
        column = QtWidgets.QVBoxLayout(frame)
        column.setContentsMargins(1, EDGE_PAD, 1, EDGE_PAD)
        column.setSpacing(0)
        pixmap = AlecToolbar.label_icon(icon, GROUP_TINT)
        for i, (name, caption) in enumerate(rows):
            fields = AlecToolbar.TransformFields(name, config, caption, GROUP_TINT)
            # the icon is part of the first row's name, so everything left of the boxes works on that row (middle drag: X, Y, Z
            # together, right click: reset); the next row keeps the same space blank
            if i == 0 and pixmap is not None:
                mark = QtWidgets.QLabel()
                mark.setPixmap(pixmap)
            else:
                mark = QtWidgets.QWidget()
                mark.setFixedWidth(pixmap.width() if pixmap is not None else 0)
            fields.label.layout().insertWidget(0, mark)
            # the margins are inside the name, so its active area reaches the box's edge and the next row
            fields.layout().setContentsMargins(0, 0, NAME_PAD, 0)
            fields.label.layout().setContentsMargins(NAME_PAD, ROW_PAD, 0, ROW_PAD)
            for box in fields.boxes:
                box.setFixedHeight(FIELD_HEIGHT)
            self.fields.append(fields)
            column.addWidget(fields)
        return frame

    def build(self):
        config = AlecToolbar.load_config()
        self.fields = []
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground)
        self.setStyleSheet(self.styleSheet() + STYLE)
        self.body.setContentsMargins(OUTER_PAD, OUTER_PAD, OUTER_PAD, OUTER_PAD)
        self.rows.setVerticalSpacing(GROUP_GAP)
        self.body.setSpacing(GROUP_GAP)
        for row, (icon, rows) in enumerate(groups()):
            self.rows.addWidget(self.group(icon, rows, config), row, 0)
        self.add_help(HELP)
        # the same width for every name, so the boxes line up across the groups
        width = max(f.label.sizeHint().width() for f in self.fields)
        for fields in self.fields:
            fields.label.setMinimumWidth(width)
        clicks = PopupClicks(self)
        for widget in [self] + self.findChildren(QtWidgets.QWidget):
            widget.installEventFilter(clicks)

    # closing drops what was typed and not entered, so leaving the boxes runs no MAXScript
    def closeEvent(self, event):
        for fields in self.fields:
            for box in fields.boxes:
                box.edited = False
        super().closeEvent(event)

    # it opens without taking the focus, so the shortcut still reaches Max (Max's shortcuts are off while a box has the focus,
    # then the panel sees the shortcut itself) and closes it
    def showEvent(self, event):
        super().showEvent(event)
        # the panel itself holds the focus: left alone, Qt gives it to the first box when the window is activated
        self.setFocusPolicy(QtCore.Qt.StrongFocus)
        self.setFocus()


def run():
    if rt.AlecTools_caddyOpen == SECTION:
        AlecTools_caddy.close_all()
        return
    AlecTools_caddy.close_all()
    rt.fileIn(rt.AlecTools_path("tools/transformFields.ms"))
    AlecTools_caddy.show(TransformPopup())


run()
