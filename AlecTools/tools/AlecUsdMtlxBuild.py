"""USD MaterialX, the 3ds Max side, for tools/usdMaterialX.py: an OpenPBR_Material for each OpenPBR network that
AlecUsdMtlxRead.py read, given to every scene material of the same name (the ones the USD import made), in one undo step.

Textures are Max's OSL Uber Bitmap (as the USD import makes them), one per image node, a single channel through
MultiOutputChannelTexmapToTexmap; MaterialX mix is OSL Mix (color), a normal map is Normal Bump. V-Ray goes through the
UniversalConverter afterwards. What did not map is listed in the Listener.
"""

import os

import pymxs
from pymxs import runtime as rt

import AlecUsdMtlxRead as mtlx

UNDO_NAME = "USD MaterialX"
OSL_DIR = os.path.join(rt.getDir(rt.Name("maxRoot")), "OSL")
# lengths, given in the stage's units
LENGTHS = ("subsurface_radius", "transmission_depth")
NORMALS = ("geometry_normal", "geometry_coat_normal")
METERS = {"inches": 0.0254, "feet": 0.3048, "miles": 1609.344, "millimeters": 0.001, "centimeters": 0.01, "meters": 1.0,
          "kilometers": 1000.0}
# cd/m2 for Blender's emission strength 1; not measured, the UniversalConverter's factor (the OpenPBR_Material default)
NITS_PER_STRENGTH = 1000.0


def system_meters():
    return METERS[str(rt.units.SystemType).lstrip("#").lower()] * rt.units.SystemScale


def color(value):
    if isinstance(value, tuple):
        return rt.Color(*(c * 255.0 for c in value[:3]))
    return rt.Color(value * 255.0, value * 255.0, value * 255.0)


def osl_map(file_name):
    t = rt.OSLMap()
    t.OSLPath = os.path.join(OSL_DIR, file_name)
    t.OSLAutoUpdate = True
    return t


class Builder:
    def __init__(self, usd):
        self.length_scale = usd.meters_per_unit / system_meters()
        self.maps = {}
        self.notes = None

    def material(self, rec):
        self.notes = rec.notes
        m = rt.OpenPBR_Material(name=rec.name)
        for name, value in rec.inputs.items():
            if not name.startswith("emission_"):
                self.set_input(m, name, value)
        self.set_emission(m, rec.inputs)
        return m

    def set_input(self, m, name, value):
        if name in NORMALS:
            self.set_normal(m, name, value)
        elif name == "geometry_opacity":
            self.set_opacity(m, value)
        elif not rt.isProperty(m, rt.Name(name)):
            self.notes.append(name + " is not an OpenPBR_Material parameter")
        elif isinstance(value, (mtlx.Image, mtlx.Channel, mtlx.Mix, mtlx.Normal)):
            setattr(m, name + "_map", self.texmap(value))
        elif value is not None:
            self.set_value(m, name, value * self.length_scale if name in LENGTHS else value)

    # a float Max keeps in a narrower range is noted
    def set_value(self, m, name, value):
        setattr(m, name, color(value) if isinstance(value, tuple) else value)
        kept = getattr(m, name)
        if isinstance(value, float) and abs(kept - value) > 1e-4:
            self.notes.append("{0} {1:g} became {2:g}".format(name, value, kept))

    def set_normal(self, m, name, value):
        if isinstance(value, mtlx.Normal):
            setattr(m, name + "_map", self.texmap(value))
        else:
            self.notes.append(name + ": not a normal map node, not mapped")

    # OpenPBR_Material has only the cutout map: a constant opacity under 1 becomes OSL Color Value (SetColor.osl)
    def set_opacity(self, m, value):
        if isinstance(value, float):
            if value < 1.0:
                grey = osl_map("SetColor.osl")
                grey.In = color(value)
                m.geometry_opacity_map = grey
        else:
            m.geometry_opacity_map = self.texmap(value)

    def set_emission(self, m, inputs):
        c, strength = inputs.get("emission_color", (1.0, 1.0, 1.0)), inputs.get("emission_luminance", 0.0)
        if not isinstance(strength, float):
            self.notes.append("emission_luminance: map not mapped")
            strength = 1.0
        lit = strength > 0.0 and (not isinstance(c, tuple) or max(c) > 0.0)
        m.emission_weight = 1.0 if lit else 0.0
        if not lit:
            return
        if isinstance(c, tuple):
            m.emission_color = color(c)
        else:
            m.emission_color_map = self.texmap(c)
        m.emission_luminance = strength * NITS_PER_STRENGTH
        self.notes.append("emission: strength {0:g} = {1:g} nits, factor not calibrated".format(strength, m.emission_luminance))

    # one map per record, shared by every slot (and material) that uses it
    def texmap(self, rec):
        if rec is None:
            return None
        key = (id(rec.image), rec.index) if isinstance(rec, mtlx.Channel) else id(rec)
        if key not in self.maps:
            self.maps[key] = self.new_map(rec)
        return self.maps[key]

    def new_map(self, rec):
        if isinstance(rec, mtlx.Image):
            return self.bitmap(rec)
        if isinstance(rec, mtlx.Channel):
            return self.channel(rec)
        if isinstance(rec, mtlx.Mix):
            return self.mix(rec)
        bump = rt.Normal_Bump()
        bump.normal_map = self.texmap(rec.map)
        bump.mult_spin = rec.scale
        return bump

    def bitmap(self, rec):
        t = osl_map("UberBitmap2.osl")
        t.filename = rec.file
        t.Filename_ColorSpace = rec.color_space
        t.WrapMode = rec.wrap
        t.UVSet = rec.uv_set
        t.Tiling = rt.Point3(rec.tiling[0], rec.tiling[1], 1.0)
        t.Offset = rt.Point3(rec.offset[0], rec.offset[1], 0.0)
        t.name = os.path.basename(rec.file)
        return t

    def channel(self, rec):
        source = self.texmap(rec.image)
        c = rt.MultiOutputChannelTexmapToTexmap()
        c.sourceMap = source
        c.outputChannelIndex = rec.index
        c.name = "{0}:{1}".format(source.name, "RGBA"[rec.index - mtlx.R])
        return c

    # MaterialX bg / fg / mix to Mix (color)'s A / B / Mix: mix(A, B, Mix)
    def mix(self, rec):
        t = osl_map("MixColor.osl")
        for param, value in (("A", rec.bg), ("B", rec.fg), ("Mix", rec.mix)):
            if isinstance(value, (int, float, tuple)):
                setattr(t, param, value if param == "Mix" else color(value))
            elif value is not None:
                setattr(t, param + "_map", self.texmap(value))
        return t


# every material on a scene object, sub-materials included, once each
def scene_materials():
    found = {}
    stack = [n.material for n in rt.objects if n.material is not None]
    while stack:
        m = stack.pop()
        key = rt.getHandleByAnim(m)
        if key in found:
            continue
        found[key] = m
        subs = (rt.getSubMtl(m, i) for i in range(1, rt.getNumSubMtls(m) + 1))
        stack.extend(s for s in subs if s is not None)
    return list(found.values())


class Report:
    def __init__(self, path, usd):
        self.path = path
        self.skipped = usd.skipped
        self.built = []
        self.missing = []

    def summary(self):
        return "USD MaterialX: {0} built, {1} skipped, {2} not in the scene (see the Listener)".format(
            len(self.built), len(self.skipped), len(self.missing))

    def print(self):
        print("USD MaterialX: " + self.path)
        for rec, count in self.built:
            print("  {0}: OpenPBR_Material, given to {1} scene material(s)".format(rec.name, count))
            for note in rec.notes:
                print("      " + note)
        for name, reason in self.skipped:
            print("  {0}: skipped, {1}; kept as imported".format(name, reason))
        for name in self.missing:
            print("  {0}: no scene material with this name, not built".format(name))
        # the USD plugin's MaterialX reader takes every OpenPBR shader, finds no .mtlx file and leaves those objects bare
        if self.missing and not self.built:
            print("  The objects need the import's USD Preview Surface materials: import the USD again without MaterialX"
                  " in the import options' Materials section, then run this again.")
        print(self.summary())


def apply(path):
    usd = mtlx.read(path)
    by_name = {}
    for m in scene_materials():
        by_name.setdefault(str(m.name).lower(), []).append(m)
    report = Report(path, usd)
    builder = Builder(usd)
    with pymxs.undo(True, UNDO_NAME):
        for rec in usd.materials:
            olds = by_name.get(rec.name.lower(), [])
            if not olds:
                report.missing.append(rec.name)
                continue
            new = builder.material(rec)
            for old in olds:
                rt.replaceInstances(old, new)
            report.built.append((rec, len(olds)))
    return report


def run():
    last = rt.AlecTools_recallSettings("UsdMaterialX", "")
    path = rt.getOpenFileName(caption="USD MaterialX: the USD file the scene was imported from", filename=last,
                              types="USD (*.usd;*.usda;*.usdc)|*.usd;*.usda;*.usdc|")
    if path is None:
        return
    rt.AlecTools_rememberSettings("UsdMaterialX", path)
    report = apply(path)
    report.print()
    rt.displayTempPrompt(report.summary(), 5000)
