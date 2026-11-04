"""LightConverter caddy, opened by the button through AlecLight_run (tools/lightConverter.ms).
No preview: the check button converts with the chosen settings (AlecLight_apply, which keeps them for this scene), the cross
closes without converting. Units only apply going to V-Ray, so they are greyed out going to Arnold.
"""

import importlib
import sys

from pymxs import runtime as rt

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

INPUTS = [("Selected", 1), ("Scene", 2)]
TARGETS = [("To V-Ray", 1), ("To Arnold", 2)]
UNITS = [("Look", 1), ("Independent of size", 2)]
VRAY = 1


class LightCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("LightConverter", "LightConverter", "OK: convert", "Cancel")

    def build(self):
        s = rt.AlecLight_lastSettings()
        self.input = self.add_choice("Lights", INPUTS, s.input, 2, self.show_state)
        self.target = self.add_choice("Convert", TARGETS, s.target, 2, self.show_state)
        self.units = self.add_choice("Units", UNITS, s.units, 2, self.show_state)
        self.renderer = self.add_toggle("", "", s.setRenderer, self.show_state)
        self.add_help("Units only apply going to V-Ray\n"
                      "Check converts, cross closes")
        self.show_state()

    def show_state(self):
        self.renderer.setText("Set renderer: V-Ray GPU" if self.target.checkedId() == VRAY else "Set renderer: Arnold GPU")
        for b in self.units.buttons():
            b.setEnabled(self.target.checkedId() == VRAY)

    def ok(self):
        rt.AlecLight_apply(self.input.checkedId(), self.target.checkedId(), self.units.checkedId(), self.renderer.isChecked())
        self.close()


AlecTools_caddy.show(LightCaddy())
