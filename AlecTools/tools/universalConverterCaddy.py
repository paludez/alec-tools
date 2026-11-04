"""UniversalConverter caddy (Shift + click on the button, or a toolbar right click), opened by AlecConv_run (tools/universalConverter.ms).
No preview: the check button converts with the chosen settings (AlecConv_apply, which keeps them for this scene), the cross
closes without converting. Rows that do not apply to the chosen target are greyed out.
"""

import importlib
import sys

from pymxs import runtime as rt

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

INPUTS = [("Selected objects", 1), ("Scene", 2), ("Editor slots", 3)]
TARGETS = [("VRayMtl", 1), ("OpenPBR", 2), ("Standard", 3)]
MODES = [("Auto", 1), ("Natural", 2), ("Roughness", 3)]
RESULTS = [("Replace in scene", 1), ("Copy to Slate", 2)]
VRAY, STANDARD = 1, 3


class ConverterCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("UniversalConverter", "UniversalConverter", "OK: convert", "Cancel")

    def build(self):
        s = rt.AlecConv_lastSettings()
        self.input = self.add_choice("Materials of", INPUTS, s.input, 3, self.show_state)
        self.target = self.add_choice("Convert to", TARGETS, s.target, 3, self.show_state)
        self.mode = self.add_choice("VRayMtl", MODES, s.vrayMode, 2, self.show_state)
        self.tint = self.add_toggle("", "Tint specular on metals", s.tintMetals, self.show_state)
        self.result = self.add_choice("Result", RESULTS, 2 if s.copyMode else 1, 2, self.show_state)
        self.add_help("Greyed rows do not apply to the chosen target\n"
                      "Check converts, cross closes")
        self.show_state()

    def show_state(self):
        target = self.target.checkedId()
        for b in self.mode.buttons():
            b.setEnabled(target == VRAY)
        self.tint.setEnabled(target == STANDARD)

    def ok(self):
        rt.AlecConv_apply(self.input.checkedId(), self.target.checkedId(), self.mode.checkedId(), self.tint.isChecked(),
                          self.result.checkedId() == 2)
        self.close()


AlecTools_caddy.show(ConverterCaddy())
