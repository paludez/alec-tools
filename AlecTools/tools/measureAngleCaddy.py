"""Measure Angle caddy (Shift + click on the button, or a toolbar right click): what to measure and on which plane; the check button
starts it (AlecAngle_dialogStart in tools/measureAngleDialog.ms), the result line follows the angle while measuring.
The choices are kept for this scene (lib/settings.ms).
"""

import importlib
import sys

from pymxs import runtime as rt
from PySide6 import QtCore

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

# (label, number AlecAngle_dialogStart takes), in the order of the buttons
WHAT = [("Points", 1), ("Edges", 2), ("Faces", 3)]
PLANES = [("World XY", 2), ("World XZ", 3), ("World YZ", 4), ("3D", 1), ("3P plane", 5), ("Pick face", 6)]
RESULT_MS = 100


class MeasureAngleCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("MeasureAngle", "Measure Angle", "Start", "Close")

    def build(self):
        saved = rt.execute('AlecTools_recallSettings "MeasureAngle" #(2, 1)')
        self.what = self.add_choice("Measure", WHAT, saved[0], 3, self.store)
        self.plane = self.add_choice("Plane", PLANES, saved[1], 3, self.store)
        self.result = self.add_result()
        # the angle is read from the overlay of the running command; the last one stays after it ends
        timer = QtCore.QTimer(self)
        timer.timeout.connect(self.show_result)
        timer.start(RESULT_MS)

    def store(self):
        rt.execute('AlecTools_rememberSettings "MeasureAngle" #({}, {})'.format(self.what.checkedId(), self.plane.checkedId()))

    def ok(self):
        rt.AlecAngle_dialogStart(self.what.checkedId(), self.plane.checkedId())

    def show_result(self):
        ov = rt.AlecAngle_overlay
        if ov is not None and len(ov.labels) > 0:
            self.result.setText(str(ov.labels[len(ov.labels) - 1][1]))


rt.fileIn(rt.AlecTools_path("tools/measureAngle.ms"))
rt.fileIn(rt.AlecTools_path("tools/measureAngleDialog.ms"))
AlecTools_caddy.show(MeasureAngleCaddy())
