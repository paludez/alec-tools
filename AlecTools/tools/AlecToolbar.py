"""Alec Tools toolbar: a dockable QToolBar on the Max main window, one button per macro, and its editor.
tools/toolbar.py creates it (AlecTools_load, at every start and reload); an existing one (found by objectName) is replaced, so a
reload does not duplicate it. tools/toolbarEditor.py (the Edit Toolbar macro) opens the editor.

What is on it, in which order, and how the option marks and separators look is kept in AlecTools.toolbar.json in the user scripts
folder (missing keys take the defaults below). The dock edge is saved in AlecTools.ini ([Toolbar] area) when the toolbar is moved.
"""

import glob
import importlib
import json
import os
import re
import sys

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

CATEGORY = "Alec Tools"
OBJECT_NAME = "AlecToolsToolbar"
EDITOR_NAME = "AlecToolsToolbarEditor"
SECTION = "Toolbar"
SEPARATOR = "|"

DEFAULTS = {
    # macro names in order, SEPARATOR = a separator
    "buttons": [
        "ConvertersMenu",
        SEPARATOR, SEPARATOR,
        "ReloadAlecTools", "EditToolbar", "IconBrowser", "MaxSettings",
        SEPARATOR,
        "MidBetween", "Distribute", "BBox",
        SEPARATOR,
        "SME_GetFromSelection", "MatchMaterial",
        SEPARATOR,
        "MeasureClearance", "MeasureGap", "MeasureAngle", "MeasureBBox", "Measure",
        SEPARATOR,
        "UsePivotPointCenter", "UseSelectionCenter", "UseTransformCoordinateCenter",
        SEPARATOR,
        "Scale", "Size",
    ],
    "markSize": 8,
    "markColor": "#ff007f",
    "separatorColor": "#242424",
    "separatorWidth": 2,
    "separatorMargin": 2,
    # pixels of vertical drag per step of a field's ladder
    "ladderPixels": AlecTools_caddy.LADDER_PIXELS,
    # the colors of the World and Local rows' icons, so they are told apart at a glance
    "worldColor": "#00aaff",
    "localColor": "#55ff7f",
    # the mini help on the tools' panels (read by AlecTools_caddy.help_shown)
    "showHelp": True,
    # folders texture dialogs start in: with several, a menu asks which (read by AlecTools_caddy.map_folders)
    "mapFolders": [],
}

# buttons shown pressed while getCoordCenter() returns this value, as the macros' own isChecked
COORD_CENTER = {
    "UsePivotPointCenter": "local",
    "UseSelectionCenter": "selection",
    "UseTransformCoordinateCenter": "system",
}

# how often the pressed state is read again: Max has no callback for a coordinate center change
# macros that open their caddy when they read AlecTools_wantsOptions(): right click on their button
WITH_OPTIONS = {"MeasureAngle", "BBox", "Distribute", "MidBetween", "UniversalConverter"}

# entries that are one button opening a drop-down list of macros; an item that opens its caddy on a right click opens it here too
MENUS = {
    # an item that is a dict is a submenu; one with no items yet is shown disabled
    "ConvertersMenu": {"title": "Converters", "icon": "CreateTransitionFromTo_32.png", "items": [
        {"title": "Materials", "items": ["UniversalConverter"]},
        {"title": "Maps", "items": []},
        {"title": "Lights", "items": ["LightConverter"]},
        {"title": "USD", "items": ["UsdMaterialX"]},
    ]},
}

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
        "get": "AlecFields_worldPosition", "set": "AlecFields_setWorldPosition",
        "tip": "World position of the selection (one object: its pivot, several: the center of their bounds).\n"
               "Type a value or + - * / and Enter, " + LADDER_TIP + ", right click: 0"},
    "LocalOffset": {
        "label": "L", "icon": MOVE_ICON, "local": True, "title": "Local Position",
        "get": "AlecFields_relative", "move": "AlecFields_moveLocal", "reset_like": "WorldPosition",
        "tip": "Moves each object along its own axes.\nType a value or + - * / and Enter to move by it, " + LADDER_TIP + ", right click: world position 0"},
    "WorldRotation": {
        "label": "W", "icon": ROTATE_ICON, "title": "World Rotation", "angles": True,
        "get": "AlecFields_worldRotation", "set": "AlecFields_setWorldRotation", "move": "AlecFields_rotateWorld",
        "tip": "World XYZ angles as Max shows them, about the Use Center. Pivot Point Center: each object about its own pivot\n"
               "(" + VARIES + " where they differ). Selection or Transform Coordinate Center with several objects: turns them as one\n"
               "by what is entered. Type a value or + - * / and Enter, " + LADDER_TIP + ", Shift: 180, 90, 45... steps, right click: 0"},
    "Scale": {
        "label": "%", "icon": SCALE_ICON, "title": "Scale", "reset": 100.0,
        "get": "AlecFields_scale", "set": "AlecFields_setScale",
        "tip": "Scale of each selected object in percent (100 = unscaled), along its own axes (" + VARIES + " where they differ).\n"
               "Type a value or + - * / and Enter, " + LADDER_TIP + ", right click: 100"},
    "Size": {
        "label": "Size", "icon": SIZE_ICON, "title": "Size", "reset": None, "unit": "length",
        "get": "AlecFields_size", "set": "AlecFields_setSize", "reset_like": "Scale",
        "tip": "Size of each selected object along its own axes, in scene units (" + VARIES + " where they differ).\n"
               "Typing or dragging scales the object. Type a value or + - * / and Enter, " + LADDER_TIP + ", right click: scale 100%"},
    "LocalRotation": {
        "label": "L", "icon": ROTATE_ICON, "local": True, "title": "Local Rotation", "angles": True,
        "get": "AlecFields_relative", "move": "AlecFields_rotateLocal", "reset_like": "WorldRotation",
        "tip": "Turns each object around its own axes, about its pivot.\n"
               "Type an angle or + - * / and Enter to turn by it, " + LADDER_TIP + ", Shift: 180, 90, 45... steps, right click: world rotation 0"},
}
FIELD_WIDTH = 58
FIELD_DECIMALS = 3

AREAS = {
    "top": QtCore.Qt.TopToolBarArea,
    "bottom": QtCore.Qt.BottomToolBarArea,
    "left": QtCore.Qt.LeftToolBarArea,
    "right": QtCore.Qt.RightToolBarArea,
}

MACRO_RE = re.compile(r"^macroScript\s+(\w+)(.*?)^\(", re.M | re.S)
FIELD_RE = r'^{}:"([^"]*)"'


# settings

def config_file():
    return AlecTools_caddy.toolbar_config_file()


def default_names():
    return [name for name in DEFAULTS["buttons"] if name != SEPARATOR]


# a saved toolbar keeps its buttons, but a default added since it was saved ("known" lists the defaults it has seen)
# comes after a separator at the end, so an update brings new tools to a toolbar the user already edited
def menu_macros(items):
    names = []
    for item in items:
        names += menu_macros(item["items"]) if isinstance(item, dict) else [item]
    return names


def load_config():
    config = json.loads(json.dumps(DEFAULTS))
    if os.path.isfile(config_file()):
        with open(config_file(), encoding="utf-8") as f:
            config.update(json.load(f))
        known = config.get("known", config["buttons"])
        new = [name for name in default_names() if name not in known]
        # a menu that is new goes to the start and takes the place of its items, if the saved toolbar has them as buttons of their own
        menus = [n for n in new if n in MENUS]
        for menu in menus:
            config["buttons"] = [n for n in config["buttons"] if n not in menu_macros(MENUS[menu]["items"])]
        if menus:
            config["buttons"] = menus + [SEPARATOR] + config["buttons"]
        rest = [n for n in new if n not in MENUS]
        if rest:
            config["buttons"] += [SEPARATOR] + rest
    return config


def save_config(config):
    config["known"] = default_names()
    with open(config_file(), "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)


# {macro name: (buttonText, iconName or None)} read from the macro files
def macro_info():
    info = {}
    for path in glob.glob(os.path.join(rt.AlecTools_path("macros"), "*.mcr")):
        with open(path, encoding="utf-8") as f:
            for name, header in MACRO_RE.findall(f.read()):
                text = re.search(FIELD_RE.format("buttonText"), header, re.M)
                icon = re.search(FIELD_RE.format("iconName"), header, re.M)
                info[name] = (text.group(1) if text else name, icon.group(1) if icon else None)
    return info


# dock edge

def saved_area():
    name = rt.getINISetting(rt.AlecTools_iniFile(), SECTION, "area")
    return AREAS.get(name, QtCore.Qt.BottomToolBarArea)


def save_area(bar):
    area = GetQMaxMainWindow().toolBarArea(bar)
    for name, value in AREAS.items():
        if value == area:
            rt.setINISetting(rt.AlecTools_iniFile(), SECTION, "area", name)


# saves the dock edge whenever the toolbar is moved while docked. Keeps nothing on self: Python may drop this
# wrapper while Qt (its parent is the toolbar) keeps the filter, and Python attributes go with the wrapper
class AreaWatcher(QtCore.QObject):
    def eventFilter(self, obj, event):
        if event.type() == QtCore.QEvent.Move and not obj.isFloating():
            save_area(obj)
        # Use Center has no Max event: Max's own flyout or a shortcut may have changed it, so it is read when the mouse comes
        elif event.type() == QtCore.QEvent.Enter:
            refresh_checked(obj)
        return False


# buttons

def add_button(bar, name, info):
    text, icon = info.get(name, (name, None))
    action = bar.addAction(text)
    action.setToolTip(text + ("\nRight click: options" if name in WITH_OPTIONS else ""))
    if icon:
        action.setIcon(QtGui.QIcon(icon))
    action.triggered.connect(lambda checked=False, n=name: run(bar, n))
    action.setData(name)
    action.setCheckable(name in COORD_CENTER)


# the path of a Max icon by its file name: the resource folders are not known, so ":/Icons" is searched
def resource_icon(file_name):
    found = QtCore.QDirIterator(":/Icons", [file_name], QtCore.QDir.Files, QtCore.QDirIterator.Subdirectories)
    return QtGui.QIcon(found.next()) if found.hasNext() else QtGui.QIcon()


def fill_menu(bar, menu, items, info):
    for item in items:
        if isinstance(item, dict):
            sub = menu.addMenu(item["title"])
            sub.setEnabled(bool(item["items"]))
            fill_menu(bar, sub, item["items"], info)
            continue
        text, icon = info.get(item, (item, None))
        action = menu.addAction(QtGui.QIcon(icon) if icon else QtGui.QIcon(), text)
        action.triggered.connect(lambda checked=False, n=item: run_with_options(n) if n in WITH_OPTIONS else run(bar, n))


def add_menu(bar, name, info):
    spec = MENUS[name]
    menu = QtWidgets.QMenu(bar)
    fill_menu(bar, menu, spec["items"], info)
    action = bar.addAction(spec["title"])
    action.setMenu(menu)
    action.setToolTip(spec["title"])
    action.setIcon(resource_icon(spec["icon"]))
    action.setData(name)
    bar.widgetForAction(action).setPopupMode(QtWidgets.QToolButton.InstantPopup)


def run(bar, name):
    rt.macros.run(CATEGORY, name)
    refresh_checked(bar)


def run_with_options(name):
    rt.AlecTools_optionsClick = True
    rt.macros.run(CATEGORY, name)


# a triangle in the bottom-right corner of a button that has options, like the flyout mark on Max's own buttons.
# It covers the button, lets the mouse through and follows its size
class OptionsMark(QtWidgets.QWidget):
    def __init__(self, button, size, color):
        super().__init__(button)
        self.size = size
        self.color = QtGui.QColor(color)
        self.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        button.installEventFilter(self)
        self.resize(button.size())

    def eventFilter(self, obj, event):
        if event.type() == QtCore.QEvent.Resize:
            self.resize(obj.size())
        return False

    def paintEvent(self, event):
        corner = self.rect().adjusted(0, 0, -1, -1).bottomRight()
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.Antialiasing)
        p.setPen(QtGui.QPen(QtGui.QColor("#1e1e1e"), 1))
        p.setBrush(self.color)
        p.drawPolygon(QtGui.QPolygon([corner, corner - QtCore.QPoint(self.size, 0), corner - QtCore.QPoint(0, self.size)]))


# the buttons a right click runs with their options get a corner mark
def add_option_marks(bar, config):
    for action in bar.actions():
        if action.data() in WITH_OPTIONS:
            OptionsMark(bar.widgetForAction(action), config["markSize"], config["markColor"])


def ancestor(widget, kind):
    while widget is not None and not isinstance(widget, kind):
        widget = widget.parentWidget()
    return widget


# Max opens its own toolbar menu on a right click before the widget sees it, so the right clicks on the toolbar are taken
# on the application: a button with options runs with them, a field goes to 0 (on the name of a row: all three), anything else
# does nothing.
# Installed last, it runs before Max's filter; it goes with the toolbar. Keeps nothing on self (see AreaWatcher)
class RightClicks(QtCore.QObject):
    # the panel a widget belongs to when this filter handles its right clicks (the toolbar), else None
    def root(self, obj):
        bar = ancestor(obj, QtWidgets.QToolBar)
        return bar if bar is not None and bar.objectName() == OBJECT_NAME else None

    def click(self, root, obj):
        right_click(root, obj)

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


def right_click(bar, widget):
    if reset_fields(widget):
        return
    for action in bar.actions():
        if action.data() in WITH_OPTIONS and bar.widgetForAction(action) is widget:
            run_with_options(action.data())


def refresh_checked(bar):
    center = str(rt.getCoordCenter())
    for action in bar.actions():
        name = action.data()
        if name in COORD_CENTER:
            action.setChecked(COORD_CENTER[name] == center)


# what tools/toolbarEvents.ms calls when Max reports a change (selection, transform, geometry, units)
def refresh_all():
    window = GetQMaxMainWindow()
    bar = window.findChild(QtWidgets.QToolBar, OBJECT_NAME)
    if bar is not None:
        refresh_checked(bar)
    refresh_fields(window)


# position fields


# a right click reaching the widget resets it (on the toolbar RightClicks takes it first)
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
        self.setStyleSheet("selection-background-color: #1f6fd6; selection-color: white;")

    # None: the selected objects differ
    def format_value(self, value):
        return VARIES if value is None else super().format_value(value)

    def enter(self, value):
        self.fields.enter(self.axis, value)


# the name of a row of fields: a middle drag on it changes X, Y and Z together, as on a Houdini parameter's name
# (its letter and icon let the mouse through to it). The icon is tinted with the World or Local color
class FieldsLabel(FieldMouse, QtWidgets.QWidget):
    # text: the name shown instead of the spec's, with no icon (the Transform Popup, which draws the icon on its group)
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
    # caption: a compact row for the Transform Popup, named by it (and tinted by tint), with no axis letters, icon or unit; the
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
        rt.AlecFields_hold()

    # what the ladder shows: the value of the one field dragged, or the change when it has none or all three are dragged
    def drag_text(self, axes, delta):
        if len(axes) == 1 and self.starts[axes[0] - 1] is not None:
            return "{:.{}f}".format(self.starts[axes[0] - 1] + delta, FIELD_DECIMALS)
        return "{:+.{}f}".format(delta, FIELD_DECIMALS)

    # every step starts again from where the objects were when the drag began
    def drag_preview(self, axes, delta):
        rt.AlecFields_restore()
        self.apply(axes, delta, True, False)
        for axis in axes:
            start = self.starts[axis - 1]
            self.boxes[axis - 1].show_value(None if start is None else start + delta)

    # back to where the drag started, then the whole change as one undo step
    def drag_end(self, axes, delta):
        rt.AlecFields_restore()
        if delta != 0:
            self.apply(axes, delta, True, True)
        self.refresh()

    # a field being typed in (focus and an edit not yet entered) or a drag is left alone
    def refresh(self):
        # during a reload the old toolbar's timer can fire after the purge removed the functions and before they are loaded again
        if self.dragging() or not hasattr(rt, self.spec["get"]):
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


# every row of fields under a widget: the toolbar's and the Transform Popup's
def refresh_fields(parent):
    for fields in parent.findChildren(TransformFields):
        fields.refresh()


# Max's theme draws toolbar separators almost invisible
def separator_style(config):
    return "QToolBar::separator {{ background: {}; width: {w}px; height: {w}px; margin: 4px {m}px; }}".format(
        config["separatorColor"], w=config["separatorWidth"], m=config["separatorMargin"])


def build(window, config):
    bar = QtWidgets.QToolBar("Alec Tools", window)
    bar.setObjectName(OBJECT_NAME)
    bar.setIconSize(QtCore.QSize(24, 24))
    bar.setToolButtonStyle(QtCore.Qt.ToolButtonFollowStyle)
    bar.setStyleSheet(separator_style(config))
    info = macro_info()
    if any(name in FIELDS for name in config["buttons"]):
        rt.fileIn(rt.AlecTools_path("tools/transformFields.ms"))
    for name in config["buttons"]:
        if name == SEPARATOR:
            bar.addSeparator()
        elif name in FIELDS:
            bar.addWidget(TransformFields(name, config)).setData(name)
        elif name in MENUS:
            add_menu(bar, name, info)
        elif name in info:
            add_button(bar, name, info)
    # a macro without an icon shows its text
    for action in bar.actions():
        if action.icon().isNull() and not action.isSeparator() and action.data() not in FIELDS:
            bar.widgetForAction(action).setToolButtonStyle(QtCore.Qt.ToolButtonTextOnly)
    add_option_marks(bar, config)
    # on the toolbar's own widgets only: a filter on the whole application runs Python for every event in Max, and with it a held
    # Esc in a viewport crashed Max
    clicks = RightClicks(bar)
    for widget in [bar] + bar.findChildren(QtWidgets.QWidget):
        widget.installEventFilter(clicks)
    refresh_checked(bar)
    return bar


def create(config=None):
    window = GetQMaxMainWindow()
    old = window.findChild(QtWidgets.QToolBar, OBJECT_NAME)
    area = window.toolBarArea(old) if old else saved_area()
    if old:
        window.removeToolBar(old)
        old.setParent(None)
        old.deleteLater()
    bar = build(window, config or load_config())
    window.addToolBar(area, bar)
    bar.installEventFilter(AreaWatcher(bar))
    bar.show()
    rt.fileIn(rt.AlecTools_path("tools/toolbarEvents.ms"))
    rt.AlecToolbar_watch()


# editor: the macros on one side, the toolbar on the other; Apply rebuilds the toolbar with the changes, OK saves them,
# Cancel puts back what was saved

SEPARATOR_TEXT = "──── separator ────"


# a color swatch that opens the color picker; changed fires while a color is picked, so the toolbar follows it live,
# and the picker's Cancel goes back to the color it started from
class ColorButton(QtWidgets.QPushButton):
    changed = QtCore.Signal()

    def __init__(self, color):
        super().__init__()
        self.setFixedWidth(60)
        self.set_color(color)
        self.clicked.connect(self.pick)

    def set_color(self, color):
        self.color = color
        self.setStyleSheet("background: {}; border: 1px solid #222222;".format(color))

    def pick_live(self, color):
        self.set_color(color)
        self.changed.emit()

    def pick(self):
        start = self.color
        dialog = QtWidgets.QColorDialog(QtGui.QColor(start), self)
        dialog.currentColorChanged.connect(lambda c: self.pick_live(c.name()))
        if not dialog.exec():
            self.pick_live(start)


class Editor(QtWidgets.QDialog):
    def __init__(self):
        super().__init__(GetQMaxMainWindow())
        self.setObjectName(EDITOR_NAME)
        self.setWindowTitle("Edit Alec Tools Toolbar")
        self.setAttribute(QtCore.Qt.WA_DeleteOnClose)
        self.info = macro_info()
        self.info.update({name: (spec["title"], None) for name, spec in FIELDS.items()})
        self.info.update({name: (spec["title"], None) for name, spec in MENUS.items()})
        self.saved = load_config()

        self.macros = QtWidgets.QListWidget()
        self.macros.itemDoubleClicked.connect(lambda item: self.add())
        for name in sorted(self.info, key=lambda n: self.info[n][0].lower()):
            self.macros.addItem(self.item(name))
        self.toolbar = QtWidgets.QListWidget()
        self.toolbar.setDragDropMode(QtWidgets.QAbstractItemView.InternalMove)
        self.toolbar.itemDoubleClicked.connect(lambda item: self.remove())

        middle = QtWidgets.QVBoxLayout()
        middle.addStretch()
        for text, slot in (("Add →", self.add), ("← Remove", self.remove), ("Separator", self.add_separator),
                           ("Up", lambda: self.move(-1)), ("Down", lambda: self.move(1))):
            b = QtWidgets.QPushButton(text)
            b.clicked.connect(slot)
            middle.addWidget(b)
        middle.addStretch()

        lists = QtWidgets.QHBoxLayout()
        lists.addLayout(self.titled("Macros (double click adds)", self.macros))
        lists.addLayout(middle)
        lists.addLayout(self.titled("Toolbar (drag to reorder, double click removes)", self.toolbar))

        self.mark_size = self.spin(4, 24)
        self.mark_color = ColorButton("#000000")
        self.sep_color = ColorButton("#000000")
        self.sep_width = self.spin(1, 6)
        self.sep_margin = self.spin(0, 20)
        self.ladder_pixels = self.spin(1, 40)
        self.world_color = ColorButton("#000000")
        self.local_color = ColorButton("#000000")
        self.show_help = QtWidgets.QCheckBox()
        looks = QtWidgets.QFormLayout()
        looks.addRow("Options mark size", self.mark_size)
        looks.addRow("Options mark color", self.mark_color)
        looks.addRow("Separator color", self.sep_color)
        looks.addRow("Separator thickness", self.sep_width)
        looks.addRow("Space around separators", self.sep_margin)
        looks.addRow("Ladder drag: pixels per step", self.ladder_pixels)
        looks.addRow("World icon color", self.world_color)
        looks.addRow("Local icon color", self.local_color)
        looks.addRow("Mini help on the tools' panels", self.show_help)
        self.map_folders = QtWidgets.QListWidget()
        self.map_folders.setDragDropMode(QtWidgets.QAbstractItemView.InternalMove)
        self.map_folders.setMaximumHeight(70)
        self.map_folders.setToolTip("Where texture dialogs start; with several folders a menu asks which. Drag to reorder")
        folder_buttons = QtWidgets.QVBoxLayout()
        for text, slot in (("Add folder", self.add_map_folder), ("Remove", self.remove_map_folder)):
            b = QtWidgets.QPushButton(text)
            b.clicked.connect(slot)
            folder_buttons.addWidget(b)
        folders = QtWidgets.QHBoxLayout()
        folders.addWidget(self.map_folders)
        folders.addLayout(folder_buttons)
        looks.addRow("Map folders", folders)

        buttons = QtWidgets.QHBoxLayout()
        for text, slot in (("Defaults", lambda: self.fill(json.loads(json.dumps(DEFAULTS)))), (None, None),
                           ("Apply", self.apply), ("OK", self.ok), ("Cancel", self.close)):
            if text is None:
                buttons.addStretch()
                continue
            b = QtWidgets.QPushButton(text)
            b.clicked.connect(slot)
            buttons.addWidget(b)

        layout = QtWidgets.QVBoxLayout(self)
        layout.addLayout(lists)
        layout.addLayout(looks)
        layout.addLayout(buttons)
        self.fill(self.saved)
        # the looks show on the toolbar as they change, like Apply; OK keeps them, Cancel puts the saved ones back
        for spin in (self.mark_size, self.sep_width, self.sep_margin):
            spin.valueChanged.connect(self.apply)
        for color in (self.mark_color, self.sep_color, self.world_color, self.local_color):
            color.changed.connect(self.apply)
        self.resize(640, 640)

    def titled(self, title, widget):
        box = QtWidgets.QVBoxLayout()
        box.addWidget(QtWidgets.QLabel(title))
        box.addWidget(widget)
        return box

    def spin(self, low, high):
        s = QtWidgets.QSpinBox()
        s.setRange(low, high)
        return s

    # a list row for a macro (its text and icon) or a separator; the macro name is kept in the item's data
    def item(self, name):
        if name == SEPARATOR:
            it = QtWidgets.QListWidgetItem(SEPARATOR_TEXT)
        else:
            text, icon = self.info.get(name, (name, None))
            it = QtWidgets.QListWidgetItem(QtGui.QIcon(icon) if icon else QtGui.QIcon(), text)
        it.setData(QtCore.Qt.UserRole, name)
        return it

    def fill(self, config):
        self.toolbar.clear()
        for name in config["buttons"]:
            if name == SEPARATOR or name in self.info:
                self.toolbar.addItem(self.item(name))
        self.mark_size.setValue(config["markSize"])
        self.mark_color.set_color(config["markColor"])
        self.sep_color.set_color(config["separatorColor"])
        self.sep_width.setValue(config["separatorWidth"])
        self.sep_margin.setValue(config["separatorMargin"])
        self.ladder_pixels.setValue(config["ladderPixels"])
        self.world_color.set_color(config["worldColor"])
        self.local_color.set_color(config["localColor"])
        self.show_help.setChecked(config["showHelp"])
        self.map_folders.clear()
        self.map_folders.addItems(config["mapFolders"])

    def config(self):
        return {
            "buttons": [self.toolbar.item(i).data(QtCore.Qt.UserRole) for i in range(self.toolbar.count())],
            "markSize": self.mark_size.value(),
            "markColor": self.mark_color.color,
            "separatorColor": self.sep_color.color,
            "separatorWidth": self.sep_width.value(),
            "separatorMargin": self.sep_margin.value(),
            "ladderPixels": self.ladder_pixels.value(),
            "worldColor": self.world_color.color,
            "localColor": self.local_color.color,
            "showHelp": self.show_help.isChecked(),
            "mapFolders": [self.map_folders.item(i).text() for i in range(self.map_folders.count())],
        }

    def add_map_folder(self):
        folder = QtWidgets.QFileDialog.getExistingDirectory(self, "Map folder")
        if folder and not self.map_folders.findItems(folder, QtCore.Qt.MatchExactly):
            self.map_folders.addItem(folder)

    def remove_map_folder(self):
        row = self.map_folders.currentRow()
        if row >= 0:
            self.map_folders.takeItem(row)

    # a new row goes after the selected one, or at the end
    def insert(self, name):
        row = self.toolbar.currentRow() + 1 if self.toolbar.currentRow() >= 0 else self.toolbar.count()
        self.toolbar.insertItem(row, self.item(name))
        self.toolbar.setCurrentRow(row)

    def add(self):
        it = self.macros.currentItem()
        if it:
            self.insert(it.data(QtCore.Qt.UserRole))

    def add_separator(self):
        self.insert(SEPARATOR)

    def remove(self):
        row = self.toolbar.currentRow()
        if row >= 0:
            self.toolbar.takeItem(row)

    def move(self, step):
        row = self.toolbar.currentRow()
        if 0 <= row + step < self.toolbar.count() and row >= 0:
            self.toolbar.insertItem(row + step, self.toolbar.takeItem(row))
            self.toolbar.setCurrentRow(row + step)

    def apply(self):
        create(self.config())

    def ok(self):
        self.saved = self.config()
        save_config(self.saved)
        create(self.saved)
        self.close()

    # closing without OK puts back the saved toolbar (Apply only shows the changes)
    def closeEvent(self, event):
        create(self.saved)


def open_editor():
    old = GetQMaxMainWindow().findChild(QtWidgets.QDialog, EDITOR_NAME)
    if old:
        old.close()
    Editor().show()
