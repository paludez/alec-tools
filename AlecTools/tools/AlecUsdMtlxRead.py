"""USD MaterialX, the reading side (pxr only, nothing from 3ds Max), for tools/usdMaterialX.py.

Blender's USD export with "MaterialX Network" ticked writes each material's MaterialX network inline, as UsdShade prims.
A Principled BSDF becomes an ND_open_pbr_surface_surfaceshader; its inputs are read here as constants or as a small tree of
records (Image, Channel, Mix, Normal) that AlecUsdMtlxBuild.py turns into 3ds Max maps. A node the tree cannot follow is
noted and its input keeps the 3ds Max default. Other Blender shaders (Diffuse BSDF, Mix Shader, ...) come out as ND_surface
networks and are skipped.
"""

import os
from dataclasses import dataclass, field

from pxr import Gf, Usd, UsdGeom, UsdShade

OPENPBR_ID = "ND_open_pbr_surface_surfaceshader"

# MaterialX colour spaces to the Uber Bitmap's Filename_ColorSpace choices
COLOR_SPACES = {
    "srgb_texture": "sRGB",
    "lin_rec709": "scene-linear Rec.709-sRGB",
    "lin_srgb": "scene-linear Rec.709-sRGB",
    "acescg": "ACEScg",
    "lin_ap1": "ACEScg",
    "raw": "Raw",
}
# MaterialX address modes to the Uber Bitmap's WrapMode ("constant" gives the default colour, black)
WRAP_MODES = {"periodic": "periodic", "clamp": "clamp", "mirror": "mirror", "constant": "black"}
# the Uber Bitmap's outputs as MultiOutputChannelTexmapToTexmap counts them: Col, R, G, B, A
COL, R = 1, 2
UV_NAMES = ("st", "UVMap")
# Blender writes them always, for its Anisotropic Rotation
TANGENTS = ("geometry_tangent", "geometry_coat_tangent")


@dataclass
class Image:
    file: str
    color_space: str
    wrap: str
    uv_set: int = 1
    tiling: tuple = (1.0, 1.0)
    offset: tuple = (0.0, 0.0)


@dataclass
class Channel:
    image: Image
    index: int


# MaterialX mix: bg * (1 - mix) + fg * mix; each part is a constant or a record
@dataclass
class Mix:
    bg: object
    fg: object
    mix: object


@dataclass
class Normal:
    map: object
    scale: float


@dataclass
class Material:
    name: str
    inputs: dict = field(default_factory=dict)
    notes: list = field(default_factory=list)


@dataclass
class UsdFile:
    meters_per_unit: float
    materials: list = field(default_factory=list)
    skipped: list = field(default_factory=list)


class Reader:
    def __init__(self, stage):
        self.dir = os.path.dirname(stage.GetRootLayer().realPath)
        self.nodes = {}
        self.material = None

    def note(self, text):
        self.material.notes.append(text)

    def read_material(self, material):
        self.material = Material(material.GetPrim().GetName())
        for inp in surface_shader(material).GetInputs():
            if inp.GetBaseName() in TANGENTS:
                continue
            value = self.read_input(inp, inp.GetBaseName())
            if value is not None:
                self.material.inputs[inp.GetBaseName()] = value
        inputs = self.material.inputs
        if inputs.get("specular_roughness_anisotropy", 0.0) != 0.0 or inputs.get("coat_roughness_anisotropy", 0.0) != 0.0:
            self.note("anisotropy direction (Anisotropic Rotation) not mapped")
        self.fix_metal()
        return self.material

    # Blender writes its IOR Level as specular_weight (0.5 -> 1), but in Blender it leaves metals alone and in OpenPBR it
    # scales the metal's reflection too: a full metal gets 1, a partial or mapped one keeps it with a note
    def fix_metal(self):
        inputs = self.material.inputs
        weight, metal = inputs.get("specular_weight", 1.0), inputs.get("base_metalness", 0.0)
        if weight == 1.0 or metal == 0.0 or not isinstance(weight, float):
            return
        if metal == 1.0:
            inputs["specular_weight"] = 1.0
            self.note("metal: specular_weight {0:g} set to 1 (Blender's IOR Level does not change metals)".format(weight))
        else:
            self.note("partly metal: specular_weight {0:g} kept, in OpenPBR it scales the metal too".format(weight))

    # a constant, a record, or None (no value, or a node that was not followed)
    def read_input(self, inp, label):
        sources = inp.GetValueProducingAttributes(True)
        if sources:
            return self.read_node(UsdShade.Shader(sources[0].GetPrim()), label)
        return constant(inp.Get())

    def upstream(self, shader, name, label):
        inp = shader.GetInput(name)
        return self.read_input(inp, label) if inp else None

    # one record per node, shared by every input that reads it
    def read_node(self, shader, label):
        key = str(shader.GetPath())
        if key not in self.nodes:
            self.nodes[key] = self.new_node(shader, label)
        return self.nodes[key]

    def new_node(self, shader, label):
        node_id = shader.GetIdAttr().Get() or ""
        if node_id.startswith(("ND_image_", "ND_tiledimage_")):
            image = self.read_image(shader, node_id)
            return Channel(image, R) if node_id.endswith("_float") else image
        if node_id.startswith("ND_extract_"):
            return self.read_extract(shader, label)
        if node_id.startswith("ND_convert_"):
            return self.upstream(shader, "in", label)
        if node_id == "ND_clamp_float":
            return self.read_clamp(shader, label)
        if node_id in ("ND_mix_color3", "ND_mix_float"):
            return Mix(*(self.upstream(shader, n, label) for n in ("bg", "fg", "mix")))
        if node_id.startswith("ND_normalmap"):
            return self.read_normal(shader, label)
        self.note("{0}: {1} not mapped".format(label, node_id or shader.GetPath().name))
        return None

    def read_extract(self, shader, label):
        src = self.upstream(shader, "in", label)
        index = input_value(shader, "index", 0)
        if isinstance(src, Image):
            return Channel(src, R + index)
        if src is not None:
            self.note("{0}: channel {1} of a node other than an image not mapped".format(label, index))
        return None

    # on texture data (0 - 1) a 0 - 1 clamp changes nothing
    def read_clamp(self, shader, label):
        low, high = input_value(shader, "low", 0.0), input_value(shader, "high", 1.0)
        if (low, high) != (0.0, 1.0):
            self.note("{0}: clamp {1} - {2} dropped".format(label, low, high))
        return self.upstream(shader, "in", label)

    def read_normal(self, shader, label):
        if input_value(shader, "space", "tangent") != "tangent":
            self.note(label + ": object-space normal map read as tangent space")
        scale = input_value(shader, "scale", 1.0)
        return Normal(self.upstream(shader, "in", label), scale[0] if isinstance(scale, tuple) else scale)

    def read_image(self, shader, node_id):
        image = Image(self.image_file(shader), self.color_space(shader), self.wrap(shader), self.uv_set(shader))
        if node_id.startswith("ND_tiledimage_"):
            tiling = input_value(shader, "uvtiling", (1.0, 1.0))
            offset = input_value(shader, "uvoffset", (0.0, 0.0))
            # MaterialX takes uv * tiling - offset, the Uber Bitmap (uv - Offset) * Tiling
            image.tiling = tiling
            image.offset = tuple(o / t if t else 0.0 for o, t in zip(offset, tiling))
        return image

    def image_file(self, shader):
        asset = input_value(shader, "file", None)
        if asset is None:
            self.note(shader.GetPath().name + ": image without a file")
            return ""
        path = asset.resolvedPath or os.path.normpath(os.path.join(self.dir, asset.path))
        if "<UDIM>" in path:
            self.note("UDIM textures not mapped: " + path)
        elif not os.path.isfile(path):
            self.note("texture not found: " + path)
        return path

    def color_space(self, shader):
        inp = shader.GetInput("file")
        name = inp.GetAttr().GetColorSpace() if inp and inp.GetAttr().HasColorSpace() else ""
        if name not in COLOR_SPACES:
            self.note("{0}: colour space '{1}' unknown, set to auto".format(shader.GetPath().name, name))
        return COLOR_SPACES.get(name, "auto")

    def wrap(self, shader):
        u = input_value(shader, "uaddressmode", "periodic")
        v = input_value(shader, "vaddressmode", "periodic")
        if u != v or u not in WRAP_MODES:
            self.note("{0}: address modes {1} / {2} read as periodic".format(shader.GetPath().name, u, v))
            return "periodic"
        return WRAP_MODES[u]

    def uv_set(self, shader):
        inp = shader.GetInput("texcoord")
        sources = inp.GetValueProducingAttributes(True) if inp else []
        if not sources:
            return 1
        coords = UsdShade.Shader(sources[0].GetPrim())
        node_id = coords.GetIdAttr().Get() or ""
        if node_id == "ND_texcoord_vector2":
            return input_value(coords, "index", 0) + 1
        if node_id == "ND_geompropvalue_vector2" and input_value(coords, "geomprop", "") in UV_NAMES:
            return 1
        self.note("{0}: texture coordinates from {1} read as map channel 1".format(shader.GetPath().name, node_id))
        return 1


def constant(value):
    if isinstance(value, (Gf.Vec2f, Gf.Vec3f, Gf.Vec4f, Gf.Vec2d, Gf.Vec3d)):
        return tuple(float(x) for x in value)
    return value


def input_value(shader, name, default):
    inp = shader.GetInput(name)
    value = constant(inp.Get()) if inp else None
    return default if value is None else value


# the shader behind the material's MaterialX surface output, or None
def surface_shader(material):
    output = material.GetSurfaceOutput("mtlx")
    sources = output.GetValueProducingAttributes(True) if output else []
    return UsdShade.Shader(sources[0].GetPrim()) if sources else None


def read(path):
    stage = Usd.Stage.Open(path)
    out = UsdFile(UsdGeom.GetStageMetersPerUnit(stage))
    reader = Reader(stage)
    for prim in stage.Traverse():
        if not prim.IsA(UsdShade.Material):
            continue
        material = UsdShade.Material(prim)
        shader = surface_shader(material)
        node_id = shader.GetIdAttr().Get() if shader else None
        if node_id == OPENPBR_ID:
            out.materials.append(reader.read_material(material))
        elif shader is None:
            out.skipped.append((prim.GetName(), "no MaterialX surface"))
        else:
            out.skipped.append((prim.GetName(), "{0}, not a Principled BSDF".format(node_id)))
    return out
