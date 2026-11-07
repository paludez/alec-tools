"""Measure Angle caddy (Shift + click on the button, or a toolbar right click): what to measure and on which plane; Start
begins it (AlecMeasureAngle_dialogStart in tools/measureAngleDialog.ms), the result line follows the angle while measuring.
The choices are kept for this scene (lib/settings.ms).
"""

from pymxs import runtime as rt

import AlecTools_caddy

# (label, number AlecMeasureAngle_dialogStart takes), in the order of the buttons
WHAT = [("Points", 1), ("Edges", 2), ("Faces", 3)]
PLANES = [("World XY", 2), ("World XZ", 3), ("World YZ", 4), ("3D", 1), ("3 points", 5), ("Pick face", 6)]
HELP = "\n".join([
    "Measure: Points = 4 clicks with snaps, 2 for each line; a fifth starts a new measure.",
    "    Edges = hover an object, its nearest edge lights up; click 2 edges, from any objects.",
    "    Faces = hover, the face lights up; click 2 faces: the angle between the faces.",
    "    Edges, Faces: a third click starts a new measure.",
    "Plane: the angle as seen looking straight at it: World XY / XZ / YZ,",
    "    3 points = click 3 points of the plane first, Pick face = click a face first;",
    "    3D = no plane.",
    "Start, or Enter: begins measuring; the yellow line here shows the angle.",
    "While measuring: Ctrl = plane on / off (3D: World XY); right click or Esc = end and clear.",
    "Close, or the button / shortcut again: closes the caddy.",
    "The choices are kept for this scene.",
])


class MeasureAngleCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("MeasureAngle", "Measure Angle", "Start measuring", "Close", ok_text="Start", cancel_text="Close")

    def build(self):
        saved = rt.execute('AlecTools_recallSettings "MeasureAngle" #(2, 1)')
        self.what = self.add_choice("Measure", WHAT, saved[0], 3, self.store)
        self.plane = self.add_choice("Plane", PLANES, saved[1], 3, self.store)
        self.result = self.add_result()
        self.add_help(HELP)
        # the running command writes the angle here itself (AlecMeasureAngle_showResult); the last one stays after it ends

    def store(self):
        rt.execute('AlecTools_rememberSettings "MeasureAngle" #({}, {})'.format(self.what.checkedId(), self.plane.checkedId()))

    def ok(self):
        rt.AlecMeasureAngle_dialogStart(self.what.checkedId(), self.plane.checkedId())


rt.fileIn(rt.AlecTools_path("tools/measureAngleDialog.ms"))
AlecTools_caddy.show(MeasureAngleCaddy())
