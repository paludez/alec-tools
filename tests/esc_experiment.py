"""Esc experiment: which of the Esc rules are really needed. Run in Max and follow the steps in the window.

It uses none of the guards of lib/AlecTools_caddy.py on purpose. Every step is written to AlecTools.esc_experiment.log in the
user scripts folder before it runs, so after a crash the last line names what was running. It changes nothing in the scene.
"""
import ctypes
import os
import time

import qtmax
from PySide6 import QtCore, QtWidgets
from pymxs import runtime as rt

NAME = "AlecEscExperiment"
LOG = os.path.join(rt.getDir(rt.Name("userScripts")), "AlecTools.esc_experiment.log")
# about a tenth of a second of MAXScript, long enough for Esc to land inside it
WORK = "(local s = 0; for i = 1 to 400000 do s += i; s)"
TIMER_MS = 250
REOPEN_MS = 1000
VK_ESCAPE = 0x1B

STEPS = "\n".join([
    "Do the steps in order. After each one, tell Claude what happened.",
    "",
    "1. Press 'Timer' on. Click in a viewport, hold Esc for 10 s, then tap it 20 times.",
    "    Also click around in the Scene Explorer while tapping. Then press 'Timer' off.",
    "2. Tick 'Esc closes'. Click this window, press Esc (it hides and comes back). 20 times,",
    "    some of them with Esc held down for a second.",
    "3. Press 'Pick a point', then end the pick with Esc. 10 times.",
    "4. Control, expected to crash: save your scene, tick 'Esc interrupts MAXScript',",
    "    then repeat step 1.",
])


def log(text):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write("%s  %s\n" % (time.strftime("%H:%M:%S"), text))
        f.flush()
        os.fsync(f.fileno())


def escape_down():
    return bool(ctypes.windll.user32.GetAsyncKeyState(VK_ESCAPE) & 0x8000)


def run_maxscript(label):
    log("%s: start, esc %s, escapeEnable %s" % (label, "down" if escape_down() else "up", rt.escapeEnable))
    try:
        rt.execute(WORK)
        log("%s: end" % label)
    except Exception as error:
        log("%s: Python exception: %s" % (label, error))


class EscExperiment(QtWidgets.QWidget):
    def __init__(self):
        super().__init__(qtmax.GetQMaxMainWindow(), QtCore.Qt.Tool)
        self.setObjectName(NAME)
        self.setWindowTitle("Esc experiment")
        self.setFocusPolicy(QtCore.Qt.StrongFocus)
        qtmax.DisableMaxAcceleratorsOnFocus(self, True)
        self.initial = rt.escapeEnable
        self.ticks = 0
        self.closes = 0
        self.picks = 0
        self.timer = QtCore.QTimer(self)
        self.timer.timeout.connect(self.tick)
        self.timer_button = QtWidgets.QPushButton("Timer: MAXScript every 250 ms")
        self.timer_button.setCheckable(True)
        self.timer_button.toggled.connect(self.set_timer)
        self.close_check = QtWidgets.QCheckBox("Esc closes this window and runs MAXScript")
        self.pick_button = QtWidgets.QPushButton("Pick a point")
        self.pick_button.clicked.connect(self.pick)
        self.interrupt_check = QtWidgets.QCheckBox("Esc interrupts MAXScript (escapeEnable)")
        self.interrupt_check.setChecked(bool(self.initial))
        self.interrupt_check.toggled.connect(self.set_interrupts)
        self.counts = QtWidgets.QLabel()
        layout = QtWidgets.QVBoxLayout(self)
        for item in (QtWidgets.QLabel(STEPS), self.timer_button, self.close_check, self.pick_button, self.interrupt_check, self.counts):
            layout.addWidget(item)
        self.show_counts()
        log("opened, escapeEnable %s" % self.initial)

    def show_counts(self):
        self.counts.setText("timer ticks %d, Esc closes %d, picks %d" % (self.ticks, self.closes, self.picks))

    def set_timer(self, on):
        log("timer %s" % ("on" if on else "off"))
        if on:
            self.timer.start(TIMER_MS)
        else:
            self.timer.stop()

    def tick(self):
        run_maxscript("timer tick %d" % self.ticks)
        self.ticks += 1
        self.show_counts()

    def set_interrupts(self, on):
        rt.escapeEnable = on
        log("escapeEnable set to %s" % on)

    def pick(self):
        log("pick %d: start, escapeEnable %s" % (self.picks, rt.escapeEnable))
        try:
            log("pick %d: end, result %s" % (self.picks, rt.pickPoint()))
        except Exception as error:
            log("pick %d: Python exception: %s" % (self.picks, error))
        self.picks += 1
        self.show_counts()

    def reopen(self):
        self.show()
        self.activateWindow()
        self.setFocus()

    def keyPressEvent(self, event):
        if event.key() != QtCore.Qt.Key_Escape or not self.close_check.isChecked():
            super().keyPressEvent(event)
            return
        self.hide()
        run_maxscript("Esc close %d" % self.closes)
        self.closes += 1
        self.show_counts()
        QtCore.QTimer.singleShot(REOPEN_MS, self.reopen)

    def closeEvent(self, event):
        self.timer.stop()
        rt.escapeEnable = self.initial
        log("closed, escapeEnable back to %s" % self.initial)
        super().closeEvent(event)


for old in qtmax.GetQMaxMainWindow().findChildren(QtWidgets.QWidget, NAME):
    old.close()
    old.deleteLater()
EscExperiment().show()
