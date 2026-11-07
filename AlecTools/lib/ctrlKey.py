"""Run by lib/ctrlKey.ms when a viewport tool with a Ctrl switch starts or ends. A tool does not receive keys and no MAXScript may run
from a timer (docs/max-verified.md), so a Qt timer that runs only Python reads Ctrl from Windows; when it goes down or up over a Max
window, it moves the cursor 1 pixel right and, at the next tick, back. Max hands those real moves to the running tool, whose freeMove /
mouseMove calls AlecTools_ctrlSeen: the switch runs from Max's own mouse handling, without the user having to move the mouse.
(A mouse move posted to the viewport window was ignored by Max.)
Each run stops the timer of an earlier one (found by name, so a reload cannot orphan it) and starts a new one while a tool has a switch.
"""

import ctypes
import ctypes.wintypes as wt
import os

from pymxs import runtime as rt
from PySide6 import QtCore
from qtmax import GetQMaxMainWindow

NAME = "AlecToolsCtrlWatch"
TICK_MS = 30
VK_CONTROL = 0x11

# a private copy of user32: the argument types set here do not change the ones other scripts rely on
user32 = ctypes.WinDLL("user32")
user32.WindowFromPoint.argtypes = [wt.POINT]
user32.WindowFromPoint.restype = wt.HWND
user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]


def ctrl_down():
    return bool(user32.GetAsyncKeyState(VK_CONTROL) & 0x8000)


def cursor():
    point = wt.POINT()
    user32.GetCursorPos(ctypes.byref(point))
    return point


def over_max(point):
    hwnd = user32.WindowFromPoint(point)
    pid = wt.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return bool(hwnd) and pid.value == os.getpid()


def start():
    timer = QtCore.QTimer(GetQMaxMainWindow())
    timer.setObjectName(NAME)
    # moved: where the cursor was put 1 pixel right, to put it back unless the user moved it since
    state = {"down": ctrl_down(), "moved": None}

    def tick():
        if state["moved"] is not None:
            x, y = state["moved"]
            state["moved"] = None
            point = cursor()
            if (point.x, point.y) == (x + 1, y):
                user32.SetCursorPos(x, y)
        down = ctrl_down()
        if down != state["down"]:
            state["down"] = down
            point = cursor()
            if over_max(point):
                user32.SetCursorPos(point.x + 1, point.y)
                state["moved"] = (point.x, point.y)

    timer.timeout.connect(tick)
    timer.start(TICK_MS)


for old in GetQMaxMainWindow().findChildren(QtCore.QTimer, NAME):
    old.stop()
    old.deleteLater()
if rt.AlecTools_ctrlAction is not None:
    start()
