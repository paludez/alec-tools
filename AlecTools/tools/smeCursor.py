"""Makes a node in the Slate Material Editor where the mouse was, by doing what a right click there does: the editor's own context menu
(Materials / Maps / ...) creates the node at the click. A right click is posted to the graph window at the saved screen point (the real
mouse does not move), the menu is walked by keys, one level per timer tick, and the entry is chosen. The timer only runs Qt: the menu's
own code makes the node. The menu opens inside the posted click, so create_at() waits in a loop that keeps Qt running until the entry
is chosen; a deadline closes every menu, so Max cannot be left in the menu.
Over a node the editor shows another menu (no Materials / Maps), then nothing is made and create_at() gives False.
"""

import ctypes
import ctypes.wintypes as wt
import time

from PySide6 import QtCore, QtGui, QtWidgets
from PySide6.QtTest import QTest

# the editor's window is found by its object name, which does not depend on the language of Max
SME_NAME = "SME MainWindowDockWidget"
GRAPH_CLASS = "DragDropWindow"
# the entries of the editor's right click menu that make a placeholder node at the click, tried in this order: plain Max entries
# (a map, then a material), which every Max has and which open no dialog
PLACEHOLDERS = [("Maps", "General", "Checker"), ("Maps", "General", "Noise"), ("Materials", "General", "OpenPBR Material")]
# the entry of the right click menu over a node that hides its map slots; a script has no call for it
HIDE_ALL_MAPS = ("Show/Hide Slots", "Maps", "Hide All")
# a timer tick, and the longest the whole menu walk may take (seconds)
TICK_MS = 10
DEADLINE = 4.0
# a menu that does not show the next entry within this long (seconds) is not the one expected
LEVEL_WAIT = 1.0
# a run longer than this (seconds) prints when each step happened to the Listener, to see what was slow
SLOW = 0.4

WM_RBUTTONDOWN = 0x0204
WM_RBUTTONUP = 0x0205
MK_RBUTTON = 0x0002

user32 = ctypes.windll.user32
WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)


def sme_dock():
    return next((w for w in QtWidgets.QApplication.topLevelWidgets() if w.isVisible() and w.objectName() == SME_NAME), None)


# true when the widget is the editor or inside it
def in_sme(widget):
    while widget is not None:
        if widget.objectName() == SME_NAME:
            return True
        widget = widget.parentWidget()
    return False


# the window of the active view's graph: a child of the widget that hosts it, found by its class
def graph_window(dock):
    page = dock.findChildren(QtWidgets.QTabWidget)[0].currentWidget()
    hosts = [c for c in page.findChildren(QtWidgets.QWidget) if c.isVisible() and c.metaObject().className() == "MaxSDK::QMaxWinHost"]
    found = []

    def match(hwnd, _):
        name = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(hwnd, name, 64)
        if name.value == GRAPH_CLASS:
            found.append(hwnd)
        return True

    if hosts:
        user32.EnumChildWindows(wt.HWND(int(hosts[0].winId())), WNDENUMPROC(match), 0)
    return found[0] if found else None


# the point of the screen (a QPoint) in Windows' pixels: Qt scales each screen around its own corner, by its own ratio
def native_point(screen_point):
    screen = QtGui.QGuiApplication.screenAt(screen_point) or QtGui.QGuiApplication.primaryScreen()
    corner = screen.geometry().topLeft()
    ratio = screen.devicePixelRatio()
    return wt.POINT(corner.x() + int((screen_point.x() - corner.x()) * ratio), corner.y() + int((screen_point.y() - corner.y()) * ratio))


# the point of the screen (a QPoint) in the window's own pixels, None when it is not over the window
def client_point(hwnd, screen_point):
    point = native_point(screen_point)
    user32.ScreenToClient(hwnd, ctypes.byref(point))
    rect = wt.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    return (point.x, point.y) if 0 <= point.x < rect.right and 0 <= point.y < rect.bottom else None


# true when the menu has the entries of the path, each in the submenu of the one before (the submenus are filled before they open)
def has_path(menu, path):
    for name in path:
        action = next((a for a in menu.actions() if a.text() == name), None)
        if action is None:
            return False
        if action.menu():
            menu = action.menu()
    return True


def close_menus():
    menu = QtWidgets.QApplication.activePopupWidget()
    while menu is not None:
        menu.close()
        QtWidgets.QApplication.processEvents()
        menu = QtWidgets.QApplication.activePopupWidget()


# one step of the walk: the open menu has the entry of this level, so it is made the active one and opened (Right) or chosen (Return).
# The menus are rebuilt when they open, so they are looked up again at every tick (the innermost open menu is the active popup)
class MenuWalk:
    def __init__(self, path):
        self.path = path
        self.level = 0
        self.chosen = False
        self.failed = False
        self.started = time.monotonic()
        self.deadline = self.started + DEADLINE
        self.level_since = self.started
        self.steps = []

    def step(self):
        # the menu runs its own loop inside the posted click, so only the timer can end it: closing every menu lets the click return
        if time.monotonic() > self.deadline:
            self.failed = True
            close_menus()
            return
        menu = QtWidgets.QApplication.activePopupWidget()
        if menu is None:
            return
        # the first menu must have the whole path (it is not the one over a node, and the render or plugin is there), or nothing is pressed
        if self.level == 0 and not has_path(menu, self.path):
            self.failed = True
            close_menus()
            return
        action = next((a for a in menu.actions() if a.text() == self.path[self.level]), None)
        if action is None:
            # the next submenu is not open yet, but not for long
            if time.monotonic() - self.level_since > LEVEL_WAIT:
                self.failed = True
                close_menus()
            return
        self.steps.append((self.path[self.level], round((time.monotonic() - self.started) * 1000)))
        menu.setActiveAction(action)
        if self.level < len(self.path) - 1:
            QTest.keyClick(menu, QtCore.Qt.Key_Right)
            self.level += 1
            self.level_since = time.monotonic()
        else:
            QTest.keyClick(menu, QtCore.Qt.Key_Return)
            self.chosen = True


# right clicks at the screen point (a QPoint) in the active view and chooses the menu entry given by path, e.g. ("Maps", "V-Ray",
# "VRayColor"): True when it was chosen. The editor makes the node centered on the point
def create_at(path, screen_point):
    dock = sme_dock()
    hwnd = graph_window(dock) if dock else None
    point = client_point(hwnd, screen_point) if hwnd else None
    if point is None:
        return False
    walk = MenuWalk(path)
    timer = QtCore.QTimer()
    timer.setInterval(TICK_MS)
    timer.timeout.connect(walk.step)
    timer.start()
    position = (point[1] << 16) | (point[0] & 0xFFFF)
    user32.PostMessageW(hwnd, WM_RBUTTONDOWN, MK_RBUTTON, position)
    user32.PostMessageW(hwnd, WM_RBUTTONUP, 0, position)
    while not (walk.chosen or walk.failed) and time.monotonic() < walk.deadline + 1:
        QtWidgets.QApplication.processEvents()
        time.sleep(0.01)
    timer.stop()
    QtWidgets.QApplication.processEvents()
    close_menus()
    if time.monotonic() - walk.started > SLOW:
        print("Create: slow menu, entries reached after (ms):", walk.steps, "total", round((time.monotonic() - walk.started) * 1000))
    return walk.chosen


# the map slots of the node at the screen point (a QPoint) hidden, as Show/Hide Slots > Maps > Hide All: True when it was chosen
def hide_all_maps(screen_point):
    return create_at(HIDE_ALL_MAPS, screen_point)
