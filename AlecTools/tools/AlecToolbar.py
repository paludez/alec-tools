"""Alec Tools toolbar: a dockable QToolBar on the Max main window, one button per macro. The rows of fields on it are in
AlecToolbarFields.py, the editor in AlecToolbarEditor.py.
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

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

import AlecToolbarFields
import AlecTools_caddy

importlib.reload(AlecToolbarFields)

CATEGORY = "Alec Tools"
OBJECT_NAME = "AlecToolsToolbar"
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
    # the mini help on the tools' caddies (read by AlecTools_caddy.help_shown)
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

# macros that open their caddy when they read AlecTools_wantsOptions(): right click on their button
WITH_OPTIONS = {"MeasureAngle", "BBox", "Distribute", "UniversalConverter", "LightConverter"}

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
            sub = AlecTools_caddy.Menu(item["title"], menu)
            menu.addMenu(sub)
            sub.setEnabled(bool(item["items"]))
            fill_menu(bar, sub, item["items"], info)
            continue
        text, icon = info.get(item, (item, None))
        action = menu.addAction(QtGui.QIcon(icon) if icon else QtGui.QIcon(), text)
        action.triggered.connect(lambda checked=False, n=item: run_with_options(n) if n in WITH_OPTIONS else run(bar, n))


def add_menu(bar, name, info):
    spec = MENUS[name]
    menu = AlecTools_caddy.Menu(bar)
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


def right_click(bar, widget):
    if AlecToolbarFields.reset_fields(widget):
        return
    for action in bar.actions():
        if action.data() in WITH_OPTIONS and bar.widgetForAction(action) is widget:
            run_with_options(action.data())


# on the toolbar a right click also runs a button that has options with them; anything else does nothing
class ToolbarClicks(AlecToolbarFields.RightClicks):
    def root(self, obj):
        bar = AlecToolbarFields.ancestor(obj, QtWidgets.QToolBar)
        return bar if bar is not None and bar.objectName() == OBJECT_NAME else None

    def click(self, root, obj):
        right_click(root, obj)


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
    AlecToolbarFields.refresh_fields(window)



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
    if any(name in AlecToolbarFields.FIELDS for name in config["buttons"]):
        rt.fileIn(rt.AlecTools_path("tools/transformFields.ms"))
    for name in config["buttons"]:
        if name == SEPARATOR:
            bar.addSeparator()
        elif name in AlecToolbarFields.FIELDS:
            bar.addWidget(AlecToolbarFields.TransformFields(name, config)).setData(name)
        elif name in MENUS:
            add_menu(bar, name, info)
        elif name in info:
            add_button(bar, name, info)
    # a macro without an icon shows its text
    for action in bar.actions():
        if action.icon().isNull() and not action.isSeparator() and action.data() not in AlecToolbarFields.FIELDS:
            bar.widgetForAction(action).setToolButtonStyle(QtCore.Qt.ToolButtonTextOnly)
    add_option_marks(bar, config)
    # on the toolbar's own widgets only: a filter on the whole application runs Python for every event in Max, and with it a held
    # Esc in a viewport crashed Max
    clicks = ToolbarClicks(bar)
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

