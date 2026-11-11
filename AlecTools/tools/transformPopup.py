"""Transform Popup (Transform Popup macro): the rows of the toolbar's transform fields in a small caddy at the mouse, like Max's
Transform Type-In. It looks like three caddies stacked with a small gap, Move (W, L), Rotate (W, L) and Scale (% and Size in the scene
unit), each with its frame and its icon (no title band), but it is one caddy: one toggle, one click away, one position. The rows are
AlecToolbarFields.TransformFields, so typing, arithmetic, the middle-drag ladder and the right click reset of a box work as on the
toolbar, and they follow the selection through AlecToolbar.refresh_all. X, Y, Z have no letters: the frame of their box is red, green
and blue, as Max's gizmo.
A value is applied when it is entered (Tab, or leaving the box). Enter or a left click in a viewport enters what is typed and closes
(accept; the click selects nothing). A right click in a viewport or on an empty part of the caddy, Esc, the macro run again or its shortcut
cancels: the objects go back to the transforms they had when the popup opened (ViewportClicks in lib/AlecTools_caddy.py).
The shortcut of Grab, Rotate, Scale or Create Popup accepts and opens that one (AlecTools_switchTool, AlecTools_caddy.ToggleKey). It
opens without the focus: click a box to type, Tab goes on. The help is the info icon at the top right of the Move frame.
"""

import pymxs
from pymxs import runtime as rt
from PySide6 import QtCore, QtWidgets

import AlecToolbar
import AlecToolbarFields
import AlecTools_caddy


SECTION = "Transform Popup"
HELP = "\n".join([
    "Click a box and type a value; + - * / ( ) work, e.g. 15+28",
    "W: world, the selection goes to the value",
    "L: local, each object moves or turns by the value along its own axes",
    "%: scale in percent; the row under it: size in scene units",
    "Tab / Shift+Tab: enter the value, next / previous box",
    "Enter: enter the value and close (accept)",
    "Left click in a viewport: enter the value and close (the click selects nothing)",
    "Right click in a viewport or on an empty part: cancel, the objects go back to how they were when it opened",
    "Esc, or this tool's shortcut again: cancel",
    "Shortcut of Grab, Rotate, Scale or Create Popup: accept and open that one",
    "Right click on a box: reset it (0, scale 100%); on a row's icon or letter: X, Y, Z together",
    "Middle drag on a box: ladder, left / right picks the step, up / down changes the value",
    "Middle drag on a row's icon or letter: X, Y, Z together",
    "Shift during a rotation row's ladder: steps of 180, 90, 45, 15, 5, 1",
])

# ---- settings to change by hand ----

# the color of the group icons (the icon files are white; this tints them): the caddies' accent
GROUP_TINT = AlecTools_caddy.COLORS["accent"]
# the icon's place: the left end of the first row's name, before its W / % letter (a row's name is: icon, then the letter).
# Its size is LABEL_ICON_SIZE in AlecToolbarFields.py (the same as on the toolbar). The rows after the first keep the same width blank
# space under it, so the boxes line up; to move the icon, change where it is inserted in group() (insertWidget(0, mark))
# the space at the left of the icon and the right of the last box (inside the active area of the name: a middle drag or a right
# click there works)
NAME_PAD = 4
# the space above the first row and below the last row of a group (not active: nothing is there)
EDGE_PAD = 0
# the space above and below each row, inside its name's active area; two rows are twice this apart
ROW_PAD = 2
# the space between the three frames
GROUP_GAP = 4
# the space around the rows inside a frame
GROUP_PAD = 3
# the height of the boxes
FIELD_HEIGHT = 20
# the space between the help icon and the frame's top right corner
HELP_PAD = 3

# the caddies' look (lib/AlecTools_caddy.py): each group is a frame of the shared palette; the caddy's own window is transparent, so
# only the three frames show, with the gap between them
STYLE = """
#AlecToolsCaddy {{ background: transparent; border: none; }}
QFrame#group {{ background: {panel}; border: 1px solid {border}; border-radius: 4px; }}
QFrame#group QLabel {{ background: transparent; }}
""".format(**AlecTools_caddy.COLORS)


# right clicks on the caddy's fields reset them, as on the toolbar (the same filter, with the caddy as its root); anywhere else on the
# caddy a right click cancels
class PopupClicks(AlecToolbarFields.RightClicks):
    def root(self, obj):
        popup = AlecToolbarFields.ancestor(obj, TransformPopup)
        return popup if popup is not None and popup.isVisible() else None

    def click(self, root, obj):
        if not AlecToolbarFields.reset_fields(obj):
            root.cancel()


# the groups: (icon, rows), a row being (field name, its caption)
def groups():
    unit = AlecTools_caddy.unit_suffix().strip() or "units"
    return [
        (AlecToolbarFields.MOVE_ICON, [("WorldPosition", " W"), ("LocalOffset", " L")]),
        (AlecToolbarFields.ROTATE_ICON, [("WorldRotation", " W"), ("LocalRotation", " L")]),
        (AlecToolbarFields.SCALE_ICON, [("Scale", " %"), ("Size", unit)]),
    ]


# a transform is the same as another (a cancel leaves an object that was not changed alone)
def same_transform(a, b):
    return all(rt.distance(getattr(a, row), getattr(b, row)) < 1e-5 for row in ("row1", "row2", "row3", "row4"))


class TransformPopup(AlecTools_caddy.ViewportClicks, AlecTools_caddy.Caddy):
    CLICK_AWAY = True
    KEY_TOGGLES = True

    def __init__(self):
        super().__init__(SECTION, SECTION, "", "", bare=True)

    # a frame with the rows; info: the help icon, put at its top right
    def group(self, icon, rows, config, info=None):
        frame = QtWidgets.QFrame()
        frame.setObjectName("group")
        outer = QtWidgets.QHBoxLayout(frame)
        outer.setContentsMargins(1, EDGE_PAD + GROUP_PAD, 1, EDGE_PAD + GROUP_PAD)
        outer.setSpacing(0)
        column = QtWidgets.QVBoxLayout()
        column.setSpacing(0)
        outer.addLayout(column)
        if info is not None:
            outer.addStretch()
            outer.addWidget(info, 0, QtCore.Qt.AlignTop)
            outer.addSpacing(HELP_PAD)
        pixmap = AlecToolbarFields.label_icon(icon, GROUP_TINT)
        for i, (name, caption) in enumerate(rows):
            fields = AlecToolbarFields.TransformFields(name, config, caption, GROUP_TINT)
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
        # handle: (node, its transform before the popup changed it)
        self.starts = {}
        self.accepted = False
        self.hold()
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground)
        self.setStyleSheet(self.styleSheet() + STYLE)
        self.rows.setVerticalSpacing(GROUP_GAP)
        self.body.setSpacing(GROUP_GAP)
        for row, (icon, rows) in enumerate(groups()):
            self.rows.addWidget(self.group(icon, rows, config, self.help_icon(HELP) if row == 0 else None), row, 0)
        # the same width for every name, so the boxes line up across the groups
        width = max(f.label.sizeHint().width() for f in self.fields)
        for fields in self.fields:
            fields.label.setMinimumWidth(width)
        clicks = PopupClicks(self)
        widgets = [self] + self.findChildren(QtWidgets.QWidget)
        for widget in widgets:
            widget.installEventFilter(clicks)
        # after PopupClicks, so it runs first: the objects are held before a right click resets a box
        for widget in widgets:
            widget.installEventFilter(self)

    # the objects the boxes work on now and not held yet, at their transform now: what a cancel puts back. Run before every key and
    # click on the popup, so objects selected while it is open are held before it changes them
    def hold(self):
        for node in rt.AlecTransformFields_movers():
            self.starts.setdefault(rt.getHandleByAnim(node), (node, node.transform))

    # every key and click is held first; Enter in a box accepts
    def eventFilter(self, watched, event):
        if event.type() not in (QtCore.QEvent.KeyPress, QtCore.QEvent.MouseButtonPress):
            return False
        self.hold()
        if event.type() == QtCore.QEvent.KeyPress and event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
            self.ok()
            return True
        return False

    # PopupClicks takes the right clicks on the popup: a box resets, elsewhere it cancels
    def right_on_caddy(self):
        pass

    # accepted (Enter, a left click in a viewport, or another tool of the group opens, see AlecTools_switchTool): the box being typed
    # in is entered, then it closes
    def ok(self):
        for fields in self.fields:
            for box in fields.boxes:
                if box.edited:
                    box.typed()
        self.accepted = True
        self.close()

    # closing drops what was typed and not entered, so leaving the boxes runs no MAXScript
    def closeEvent(self, event):
        for fields in self.fields:
            for box in fields.boxes:
                box.edited = False
        super().closeEvent(event)

    # closed without accepting (a right click, Esc, the shortcut or the macro again): the held objects go back, as one undo step
    def closed(self):
        if self.accepted:
            return
        changed = [(node, start) for node, start in self.starts.values() if rt.isValidNode(node) and not same_transform(node.transform, start)]
        if not changed:
            return
        with pymxs.undo(True, "Transform Popup Cancel"):
            for node, start in changed:
                node.transform = start
        rt.redrawViews()

    # it opens without taking the focus, so the shortcut still reaches Max (Max's shortcuts are off while a box has the focus,
    # then the caddy sees the shortcut itself) and closes it
    def showEvent(self, event):
        super().showEvent(event)
        # the caddy itself holds the focus: left alone, Qt gives it to the first box when the window is activated
        self.setFocusPolicy(QtCore.Qt.StrongFocus)
        self.setFocus()


def run():
    AlecTools_caddy.close_all()
    rt.fileIn(rt.AlecTools_path("tools/transformFields.ms"))
    AlecTools_caddy.show(TransformPopup())


run()
