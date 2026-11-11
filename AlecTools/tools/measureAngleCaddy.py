"""Measure Angle caddy, opened by AlecMeasureAngle_run (tools/measureAngle.ms) every time the tool starts: what to measure and on which
plane. The measurement starts at once (AlecMeasureAngle_dialogStart in tools/measureAngleDialog.ms) and starts again whenever an option
changes (AlecMeasureAngle_restart); the result line follows the angle while measuring. OK and Cancel end the measurement and close the
caddy, Reset puts the options back to their defaults. The choices are kept for this scene (lib/settings.ms).
"""

from pymxs import runtime as rt

import AlecTools_caddy

# (label, number AlecMeasureAngle_dialogStart takes), in the order of the buttons
WHAT = [("Points", 1), ("Edges", 2), ("Faces", 3)]
PLANES = [("World XY", 2), ("World XZ", 3), ("World YZ", 4), ("3D", 1), ("3 points", 5), ("Pick face", 6)]
DEFAULT = (2, 1)
HELP = "\n".join([
    "Measure: Points = 4 clicks with snaps, 2 for each line; a fifth starts a new measure.",
    "    Edges = hover an object, its nearest edge lights up; click 2 edges, from any objects.",
    "    Faces = hover, the face lights up; click 2 faces: the angle between the faces.",
    "    Edges, Faces: a third click starts a new measure.",
    "Plane: the angle as seen looking straight at it: World XY / XZ / YZ,",
    "    3 points = click 3 points of the plane first, Pick face = click a face first;",
    "    3D = no plane.",
    "Changing an option starts the measurement again; the yellow line here shows the angle.",
    "While measuring: Ctrl = plane on / off (3D: World XY).",
    "Reset: both options back to their defaults.",
    "OK, Enter, Cancel, Esc, a right click, or the button / shortcut again: end the measurement and close.",
    "The choices are kept for this scene.",
])


class MeasureAngleCaddy(AlecTools_caddy.Caddy):
    # the measuring tool keeps the keyboard in the viewport
    ENTER_WATCH = True

    def __init__(self):
        super().__init__("MeasureAngle", "Measure Angle", "OK: end the measurement", "Cancel")

    def build(self):
        saved = rt.execute('AlecTools_recallSettings "MeasureAngle" #({}, {})'.format(*DEFAULT))
        self.what = self.add_choice("Measure", WHAT, saved[0], 3, self.store)
        self.plane = self.add_choice("Plane", PLANES, saved[1], 3, self.store)
        self.result = self.add_result()
        self.add_footer_button("reset", "Reset", "Back to the defaults", self.reset)
        self.add_help(HELP)
        # the running command writes the angle here itself (AlecMeasureAngle_showResult); the last one stays after it ends

    # the choices are kept and the measurement starts again
    def store(self):
        rt.execute('AlecTools_rememberSettings "MeasureAngle" #({}, {})'.format(self.what.checkedId(), self.plane.checkedId()))
        rt.AlecMeasureAngle_restart(self.what.checkedId(), self.plane.checkedId())

    def reset(self):
        self.what.button(DEFAULT[0]).setChecked(True)
        self.plane.button(DEFAULT[1]).setChecked(True)
        self.store()

    def ok(self):
        self.close()

    def closed(self):
        rt.AlecMeasureAngle_end()


rt.fileIn(rt.AlecTools_path("tools/measureAngleDialog.ms"))
AlecTools_caddy.show(MeasureAngleCaddy())
