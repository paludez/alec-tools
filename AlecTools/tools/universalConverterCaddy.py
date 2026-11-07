"""UniversalConverter caddy (Shift + click on the button, or a toolbar right click), opened by AlecUniversalConverter_run (tools/universalConverter.ms).
No preview: OK converts with the chosen settings (AlecUniversalConverter_apply, which keeps them for this scene), Cancel
closes without converting. The VRayMtl mode row is greyed out when the target is OpenPBR.
"""

from pymxs import runtime as rt

import AlecTools_caddy

INPUTS = [("Selected objects", 1), ("Scene", 2), ("Editor slots", 3)]
TARGETS = [("VRayMtl", 1), ("OpenPBR", 2)]
MODES = [("Auto", 1), ("Natural", 2), ("Roughness", 3)]
MODE_TIPS = {1: "Roughness, but a VRayMtl keeps its own mode and a Standard source gets Natural",
             2: "Glossiness instead of roughness", 3: "Roughness instead of glossiness"}
RESULTS = [("Replace in scene", 1), ("Copy to Slate", 2)]
VRAY = 1
HELP = "\n".join([
    "Materials of: the selected objects, every material of the scene,",
    "    or the Material Editor slots.",
    "Convert to: VRayMtl or OpenPBR. Read: VRayMtl, OpenPBR, Physical, Standard,",
    "    Arnold Standard Surface, USD Preview Surface; other materials are left as they are.",
    "    Multi/Sub, Blend, Double Sided, ... stay; their sub-materials are converted.",
    "VRayMtl (only converting to VRayMtl): Auto = Roughness, but a VRayMtl keeps its mode",
    "    and a Standard source gets Natural; Natural = glossiness; Roughness.",
    "Result: Replace in scene = everything using a material gets the new one, in one undo step;",
    "    Copy to Slate = copies go to the Slate view \"UniversalConverter\", the scene stays.",
    "OK, or Enter: converts and keeps these settings for this scene.",
    "    What did not map is listed in the Listener.",
    "Cancel, or the button / shortcut again: closes without converting.",
    "A plain click on the button converts with the last settings.",
])


class ConverterCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("UniversalConverter", "Universal Converter", "OK: convert the materials", "Cancel")

    def build(self):
        s = rt.AlecUniversalConverter_lastSettings()
        self.input = self.add_choice("Materials of", INPUTS, s.input, 3, self.show_state)
        self.target = self.add_choice("Convert to", TARGETS, s.target, 2, self.show_state)
        self.mode = self.add_choice("VRayMtl", MODES, s.vrayMode, 2, self.show_state)
        self.result = self.add_choice("Result", RESULTS, 2 if s.copyMode else 1, 2, self.show_state)
        for id, tip in MODE_TIPS.items():
            self.mode.button(id).setToolTip(tip)
        self.add_help(HELP)
        self.show_state()

    def show_state(self):
        for b in self.mode.buttons():
            b.setEnabled(self.target.checkedId() == VRAY)

    def ok(self):
        rt.AlecUniversalConverter_apply(self.input.checkedId(), self.target.checkedId(), self.mode.checkedId(),
                                        self.result.checkedId() == 2)
        self.close()


AlecTools_caddy.show(ConverterCaddy())
