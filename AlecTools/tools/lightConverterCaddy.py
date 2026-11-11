"""LightConverter caddy, opened by Shift+click or a toolbar right click through AlecLightConverter_run (tools/lightConverter.ms).
No preview: OK converts with the chosen settings (AlecLightConverter_apply, which keeps them for this scene), Cancel
closes without converting. Units only apply going to V-Ray, so they are greyed out going to Arnold.
"""

from pymxs import runtime as rt

import AlecTools_caddy

INPUTS = [("Selected objects", 1), ("Scene", 2)]
TARGETS = [("V-Ray", 1), ("Arnold", 2)]
UNITS = [("Look", 1), ("Independent of size", 2)]
VRAY = 1
HELP = "\n".join([
    "Lights of: the selected lights, or every light in the scene.",
    "Convert to V-Ray: Arnold lights become VRayLight, VRayIES, Spot or Direct lights.",
    "Convert to Arnold: VRayLight, VRayIES and standard Spot / Direct become Arnold lights.",
    "Units (V-Ray only): Look = the light looks the same at its current size;",
    "    Independent of size = power units: the brightness stays when the size changes,",
    "    like Arnold's Normalize.",
    "Set renderer: also makes V-Ray GPU, or Arnold on the GPU, the production renderer.",
    "OK, or Enter: converts, in one undo step, and keeps these settings for this scene.",
    "    Instances stay instances; sun and sky are only listed.",
    "    What did not map is listed in the Listener.",
    "Cancel, Esc, or the button / shortcut again: closes without converting.",
    "A plain click on the button converts with the last settings. Needs V-Ray and Arnold.",
])


class LightCaddy(AlecTools_caddy.Caddy):
    def __init__(self):
        super().__init__("LightConverter", "Light Converter", "OK: convert the lights", "Cancel")

    def build(self):
        s = rt.AlecLightConverter_lastSettings()
        self.input = self.add_choice("Lights of", INPUTS, s.input, 2, self.show_state)
        self.target = self.add_choice("Convert to", TARGETS, s.target, 2, self.show_state)
        self.units = self.add_choice("Units", UNITS, s.units, 2, self.show_state)
        self.renderer = self.add_toggle("", "", s.setRenderer, self.show_state)
        self.units.button(1).setToolTip("The light looks the same at its current size")
        self.units.button(2).setToolTip("Power units: the brightness stays when the light's size changes, like Normalize")
        self.renderer.setToolTip("Also makes this the production renderer")
        self.add_help(HELP)
        self.show_state()

    def show_state(self):
        self.renderer.setText("Set renderer: V-Ray GPU" if self.target.checkedId() == VRAY else "Set renderer: Arnold GPU")
        for b in self.units.buttons():
            b.setEnabled(self.target.checkedId() == VRAY)

    def ok(self):
        rt.AlecLightConverter_apply(self.input.checkedId(), self.target.checkedId(), self.units.checkedId(), self.renderer.isChecked())
        self.close()


AlecTools_caddy.show(LightCaddy())
