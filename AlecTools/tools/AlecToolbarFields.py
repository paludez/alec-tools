"""Alec Tools toolbar fields: the rows of X / Y / Z boxes (Move, Rotate, Scale, Size) with their ladder drag and right click reset,
used by the toolbar (AlecToolbar.py) and the Transform Popup caddy (transformPopup.py). Their logic is in tools/transformFields.ms."""

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets

import AlecTools_caddy

# entries that are rows of X/Y/Z fields, not macro buttons; their logic is in tools/transformFields.ms. "get" gives the shown
# values (undefined: the row is off); a World row has "set" (goes to the values), a Local row "move" (moves or turns by them)
LADDER_TIP = "middle drag: ladder (on the name: X, Y, Z together)"
# Max's own Move and Rotate icons, after the W / L of a row
MOVE_ICON = ":/Icons/MainUI/Move_24.png"
ROTATE_ICON = ":/Icons/Common/RotateCW_24.png"
# Scale and Size
SCALE_ICON = ":/Icons/MainUI/UniformScale_24.png"
SIZE_ICON = ":/Icons/MainUI/InheritContainer_24.png"
LABEL_ICON_SIZE = 18
# what a field shows where the selected objects differ
VARIES = "—"
FIELDS = {
    "WorldPosition": {
        "label": "W", "icon": MOVE_ICON, "title": "World Position",
        "get": "AlecTransformFields_worldPosition", "set": "AlecTransformFields_setWorldPosition",
        "tip": "World position of the selection (one object: its pivot, several: the center of their bounds).\n"
               "Type a value or + - * / and Enter, " + LADDER_TIP + ", right click: 0"},
    "LocalOffset": {
        "label": "L", "icon": MOVE_ICON, "local": True, "title": "Local Position",
        "get": "AlecTransformFields_relative", "move": "AlecTransformFields_moveLocal", "reset_like": "WorldPosition",
        "tip": "Moves each object along its own axes.\nType a value or + - * / and Enter to move by it, " + LADDER_TIP + ", right click: world position 0"},
    "WorldRotation": {
        "label": "W", "icon": ROTATE_ICON, "title": "World Rotation", "angles": True,
        "get": "AlecTransformFields_worldRotation", "set": "AlecTransformFields_setWorldRotation", "move": "AlecTransformFields_rotateWorld",
        "tip": "World XYZ angles as Max shows them, about the Use Center. Pivot Point Center: each object about its own pivot\n"
               "(" + VARIES + " where they differ). Selection or Transform Coordinate Center with several objects: turns them as one\n"
               "by what is entered. Type a value or + - * / and Enter, " + LADDER_TIP + ", Shift: 180, 90, 45… steps, right click: 0"},
    "Scale": {
        "label": "%", "icon": SCALE_ICON, "title": "Scale", "reset": 100.0,
        "get": "AlecTransformFields_scale", "set": "AlecTransformFields_setScale",
        "tip": "Scale of each selected object in percent (100 = unscaled), along its own axes (" + VARIES + " where they differ).\n"
               "Type a value or + - * / and Enter, " + LADDER_TIP + ", right click: 100"},
    "Size": {
        "label": "Size", "icon": SIZE_ICON, "title": "Size", "reset": None, "unit": "length",
        "get": "AlecTransformFields_size", "set": "AlecTransformFields_setSize", "reset_like": "Scale",
        "tip": "Size of each selected object along its own axes, in scene units (" + VARIES + " where they differ).\n"
               "Typing or dragging scales the object. Type a value or + - * / and Enter, " + LADDER_TIP + ", right click: scale 100%"},
    "LocalRotation": {
        "label": "L", "icon": ROTATE_ICON, "local": True, "title": "Local Rotation", "angles": True,
        "get": "AlecTransformFields_relative", "move": "AlecTransformFields_rotateLocal", "reset_like": "WorldRotation",
        "tip": "Turns each object around its own axes, about its pivot.\n"
               "Type an angle or + - * / and Enter to turn by it, " + LADDER_TIP + ", Shift: 180, 90, 45… steps, right click: world rotation 0"},
}
FIELD_WIDTH = 58
FIELD_DECIMALS = 3


def ancestor(widget, kind):
    while widget is not None and not isinstance(widget, kind):
        widget = widget.parentWidget()
    return widget


# a right click on a field or a row's name resets it; True when it was one
def reset_fields(widget):
    field = ancestor(widget, Field)
    if field is not None:
        field.clearFocus()
        field.fields.reset_axis(field.axis)
        return True
    label = ancestor(widget, FieldsLabel)
    if label is not None:
        label.drag.fields.reset()
        return True
    return False


# Max opens its own toolbar menu on a right click before the widget sees it, so the right clicks on the toolbar and on the
# Transform Popup caddy are taken on the application: a field goes to 0 (on the name of a row: all three). A subclass says which
# widgets it handles (root) and can do more (click). Installed last, it runs before Max's filter; it goes with the toolbar.
# Keeps nothing on self: Python may drop this wrapper while Qt (its parent is the toolbar) keeps the filter
class RightClicks(QtCore.QObject):
    # the toolbar or caddy a widget belongs to when this filter handles its right clicks, else None
    def root(self, obj):
        return None

    def click(self, root, obj):
        reset_fields(obj)

    def eventFilter(self, obj, event):
        kind = event.type()
        if kind == QtCore.QEvent.ContextMenu:
            pass
        elif kind in (QtCore.QEvent.MouseButtonPress, QtCore.QEvent.MouseButtonRelease, QtCore.QEvent.MouseButtonDblClick):
            if event.button() != QtCore.Qt.RightButton:
                return False
        else:
            return False
        if not isinstance(obj, QtWidgets.QWidget):
            return False
        root = self.root(obj)
        if root is None:
            return False
        if kind == QtCore.QEvent.MouseButtonPress:
            self.click(root, obj)
        return True


# a right click reaching the widget resets it (RightClicks takes it first)
class FieldMouse(AlecTools_caddy.LadderMouse):
    def right_clicked(self):
        reset_fields(self)


# a value box of a row: middle drag for the ladder, right click for 0 (see RightClicks)
class Field(FieldMouse, AlecTools_caddy.TypedField):
    decimals = FIELD_DECIMALS

    def __init__(self, fields, axis):
        super().__init__()
        self.fields = fields
        self.axis = axis
        self.drag = AlecTools_caddy.LadderDrag(self, fields, [axis])
        self.setFixedWidth(FIELD_WIDTH)
        self.setStyleSheet(AlecTools_caddy.INPUT_STYLE)

    # None: the selected objects differ
    def format_value(self, value):
        return VARIES if value is None else super().format_value(value)

    def enter(self, value):
        self.fields.enter(self.axis, value)


# the name of a row of fields: a middle drag on it changes X, Y and Z together, as on a Houdini parameter's name
# (its letter and icon let the mouse through to it). The icon is tinted with the World or Local color
class FieldsLabel(FieldMouse, QtWidgets.QWidget):
    # text: the name shown instead of the spec's, with no icon (the Transform Popup caddy, which draws the icon on its group)
    def __init__(self, spec, fields, tint, text=None):
        super().__init__()
        self.drag = AlecTools_caddy.LadderDrag(self, fields, [1, 2, 3])
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(2)
        name = QtWidgets.QLabel(spec["label"] if text is None else text)
        layout.addWidget(name)
        pixmap = label_icon(spec["icon"], tint) if text is None else None
        if pixmap is not None:
            icon = QtWidgets.QLabel()
            icon.setPixmap(pixmap)
            layout.addWidget(icon)


# the icon (a path, or a list of paths of which the first that exists is used) tinted, or None when none exists
def label_icon(paths, tint):
    for path in [paths] if isinstance(paths, str) else paths:
        pixmap = QtGui.QIcon(path).pixmap(LABEL_ICON_SIZE, LABEL_ICON_SIZE)
        if not pixmap.isNull():
            p = QtGui.QPainter(pixmap)
            p.setCompositionMode(QtGui.QPainter.CompositionMode_SourceIn)
            p.fillRect(pixmap.rect(), QtGui.QColor(tint))
            p.end()
            return pixmap
    return None


# a label and X/Y/Z fields. A World row shows the values (— where the selected objects differ) and goes to what is entered;
# a Local row, or World Rotate turning several objects as one, shows 0 and moves or turns by what is entered. X, Y and Z
# change in one call, so changing them together is one undo step
class TransformFields(QtWidgets.QWidget):
    # caption: a compact row for the Transform Popup caddy, named by it (and tinted by tint), with no axis letters, icon or unit; the
    # X, Y, Z boxes are told apart by their frame color there
    def __init__(self, name, config, caption=None, tint=None):
        super().__init__()
        self.spec = FIELDS[name]
        self.pixels = config["ladderPixels"]
        self.relative = "set" not in self.spec
        self.starts = []
        self.setToolTip(self.spec["tip"])
        self.setSizePolicy(QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Fixed)
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(4, 0, 4, 0)
        layout.setSpacing(2)
        if caption is None:
            tint = config["localColor"] if self.spec.get("local") else config["worldColor"]
        self.label = FieldsLabel(self.spec, self, tint, caption)
        layout.addWidget(self.label)
        self.boxes = []
        for axis, text in enumerate("XYZ", 1):
            if caption is None:
                layout.addWidget(QtWidgets.QLabel(" " + text))
            box = Field(self, axis)
            box.setObjectName("field" + text)
            layout.addWidget(box)
            self.boxes.append(box)
        unit = self.spec.get("unit")
        if unit and caption is None:
            layout.addWidget(QtWidgets.QLabel(AlecTools_caddy.unit_suffix().strip() if unit == "length" else unit))
        self.refresh()

    # applies a change on the given axes: a relative row moves or turns by it; a World row goes to it, or adds it to each
    # object's own value (add)
    def apply(self, axes, value, add, undoable):
        if self.relative:
            values = [value if axis in axes else 0.0 for axis in (1, 2, 3)]
            getattr(rt, self.spec["move"])(rt.Point3(*values), undoable=undoable)
        else:
            values = [value if axis in axes else None for axis in (1, 2, 3)]
            getattr(rt, self.spec["set"])(values, add=add, undoable=undoable)
        rt.redrawViews()

    # a typed (or right click 0) value: a World row goes to it, a relative row moves by it
    def enter(self, axis, value):
        if not (self.relative and value == 0):
            self.apply([axis], value, False, True)
        self.refresh()

    # a right click on a box: the row's reset value (0, Scale 100). A Local row, which has no value of its own, and Size reset
    # what their World / Scale row does ("reset_like")
    def reset_axis(self, axis):
        self.reset_axes([axis])

    # a right click on the name: all three
    def reset(self):
        self.reset_axes([1, 2, 3])

    def reset_axes(self, axes):
        spec = FIELDS[self.spec["reset_like"]] if "reset_like" in self.spec else self.spec
        value = spec.get("reset", 0.0)
        if spec is self.spec:
            if self.relative:
                return
            self.apply(axes, value, False, True)
        else:
            values = [value if axis in axes else None for axis in (1, 2, 3)]
            getattr(rt, spec["set"])(values, add=False, undoable=True)
            rt.redrawViews()
        self.refresh()

    def dragging(self):
        return self.label.drag.active() or any(box.drag.active() for box in self.boxes)

    def drag_start(self):
        self.starts = [box.value for box in self.boxes]
        rt.AlecTransformFields_hold()

    # what the ladder shows: the value of the one field dragged, or the change when it has none or all three are dragged
    def drag_text(self, axes, delta):
        if len(axes) == 1 and self.starts[axes[0] - 1] is not None:
            return "{:.{}f}".format(self.starts[axes[0] - 1] + delta, FIELD_DECIMALS)
        return "{:+.{}f}".format(delta, FIELD_DECIMALS)

    # every step starts again from where the objects were when the drag began
    def drag_preview(self, axes, delta):
        rt.AlecTransformFields_restore()
        self.apply(axes, delta, True, False)
        for axis in axes:
            start = self.starts[axis - 1]
            self.boxes[axis - 1].show_value(None if start is None else start + delta)

    # back to where the drag started, then the whole change as one undo step
    def drag_end(self, axes, delta):
        rt.AlecTransformFields_restore()
        if delta != 0:
            self.apply(axes, delta, True, True)
        self.refresh()

    # a field being typed in (focus and an edit not yet entered) or a drag is left alone
    def refresh(self):
        if self.dragging():
            return
        value = getattr(rt, self.spec["get"])()
        self.relative = "set" not in self.spec or value == rt.Name("relative")
        values = [value[i] for i in range(3)] if value is not None and not self.relative else [0.0, 0.0, 0.0]
        for box, v in zip(self.boxes, values):
            box.setEnabled(value is not None)
            if box.hasFocus():
                continue
            box.show_value(v)
            if value is None:
                box.clear()


# every row of fields under a widget: the toolbar's and the Transform Popup caddy's
def refresh_fields(parent):
    for fields in parent.findChildren(TransformFields):
        fields.refresh()
