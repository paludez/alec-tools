"""The Python half of tests/usdMaterialX_test.ms (run that file, not this one)."""

import importlib
import os
import shutil
import struct
import sys
import tempfile
import zlib

from pymxs import runtime as rt

USDA = """#usda 1.0
(
    metersPerUnit = 1
    upAxis = "Z"
)

def Scope "root"
{
    def Scope "_materials"
    {
        def Material "AT_mtlxA"
        {
            token outputs:mtlx:surface.connect = </root/_materials/AT_mtlxA/pbr.outputs:surface>

            def Shader "pbr"
            {
                uniform token info:id = "ND_open_pbr_surface_surfaceshader"
                color3f inputs:base_color.connect = </root/_materials/AT_mtlxA/NodeGraphs.outputs:mix_out>
                float inputs:specular_roughness.connect = </root/_materials/AT_mtlxA/NodeGraphs.outputs:rough_out>
                float inputs:specular_weight = 2
                float inputs:base_metalness = 0
                float inputs:coat_weight = 0.25
                float3 inputs:geometry_normal.connect = </root/_materials/AT_mtlxA/NodeGraphs.outputs:normal_out>
                float3 inputs:geometry_tangent.connect = </root/_materials/AT_mtlxA/NodeGraphs.outputs:tangent_out>
                color3f inputs:emission_color = (1, 0.5, 0)
                float inputs:emission_luminance = 2
                float inputs:subsurface_radius = 0.05
                float inputs:geometry_opacity = 0.5
                bool inputs:geometry_thin_walled = 1
                token outputs:surface
            }

            def NodeGraph "NodeGraphs"
            {
                color3f outputs:mix_out.connect = </root/_materials/AT_mtlxA/NodeGraphs/mix.outputs:out>
                float outputs:rough_out.connect = </root/_materials/AT_mtlxA/NodeGraphs/rough_r.outputs:out>
                float3 outputs:normal_out.connect = </root/_materials/AT_mtlxA/NodeGraphs/nmap.outputs:out>
                float3 outputs:tangent_out.connect = </root/_materials/AT_mtlxA/NodeGraphs/tangent.outputs:out>

                def Shader "uv"
                {
                    uniform token info:id = "ND_texcoord_vector2"
                    int inputs:index = 1
                    float2 outputs:out
                }
                def Shader "base"
                {
                    uniform token info:id = "ND_image_color4"
                    asset inputs:file = @./AT_tex/base.png@ (colorSpace = "srgb_texture")
                    float2 inputs:texcoord.connect = </root/_materials/AT_mtlxA/NodeGraphs/uv.outputs:out>
                    string inputs:uaddressmode = "constant"
                    string inputs:vaddressmode = "constant"
                    color4f outputs:out
                }
                def Shader "base_rgb"
                {
                    uniform token info:id = "ND_convert_color4_color3"
                    color4f inputs:in.connect = </root/_materials/AT_mtlxA/NodeGraphs/base.outputs:out>
                    color3f outputs:out
                }
                def Shader "base_a"
                {
                    uniform token info:id = "ND_extract_color4"
                    color4f inputs:in.connect = </root/_materials/AT_mtlxA/NodeGraphs/base.outputs:out>
                    int inputs:index = 3
                    float outputs:out
                }
                def Shader "base_a_clamp"
                {
                    uniform token info:id = "ND_clamp_float"
                    float inputs:in.connect = </root/_materials/AT_mtlxA/NodeGraphs/base_a.outputs:out>
                    float inputs:low = 0
                    float inputs:high = 1
                    float outputs:out
                }
                def Shader "mix"
                {
                    uniform token info:id = "ND_mix_color3"
                    color3f inputs:bg = (1, 1, 1)
                    color3f inputs:fg.connect = </root/_materials/AT_mtlxA/NodeGraphs/base_rgb.outputs:out>
                    float inputs:mix.connect = </root/_materials/AT_mtlxA/NodeGraphs/base_a_clamp.outputs:out>
                    color3f outputs:out
                }
                def Shader "rough"
                {
                    uniform token info:id = "ND_image_color4"
                    asset inputs:file = @./AT_tex/rough_missing.png@ (colorSpace = "raw")
                    color4f outputs:out
                }
                def Shader "rough_r"
                {
                    uniform token info:id = "ND_extract_color4"
                    color4f inputs:in.connect = </root/_materials/AT_mtlxA/NodeGraphs/rough.outputs:out>
                    int inputs:index = 0
                    float outputs:out
                }
                def Shader "ntex"
                {
                    uniform token info:id = "ND_image_vector3"
                    asset inputs:file = @./AT_tex/base.png@ (colorSpace = "lin_rec709")
                    float3 outputs:out
                }
                def Shader "nmap"
                {
                    uniform token info:id = "ND_normalmap"
                    float3 inputs:in.connect = </root/_materials/AT_mtlxA/NodeGraphs/ntex.outputs:out>
                    float inputs:scale = 0.5
                    float3 outputs:out
                }
                def Shader "tangent"
                {
                    uniform token info:id = "ND_tangent_vector3"
                    float3 outputs:out
                }
            }
        }

        def Material "AT_mtlxB"
        {
            token outputs:mtlx:surface.connect = </root/_materials/AT_mtlxB/surf.outputs:surface>

            def Shader "surf"
            {
                uniform token info:id = "ND_surface"
                token outputs:surface
            }
        }

        def Material "AT_mtlxC"
        {
            token outputs:mtlx:surface.connect = </root/_materials/AT_mtlxC/pbr.outputs:surface>

            def Shader "pbr"
            {
                uniform token info:id = "ND_open_pbr_surface_surfaceshader"
                token outputs:surface
            }
        }

        def Material "AT_mtlxD"
        {
            token outputs:mtlx:surface.connect = </root/_materials/AT_mtlxD/pbr.outputs:surface>

            def Shader "pbr"
            {
                uniform token info:id = "ND_open_pbr_surface_surfaceshader"
                float inputs:base_metalness = 1
                float inputs:specular_weight = 0
                token outputs:surface
            }
        }
    }
}
"""

failures = 0


def check(label, ok):
    global failures
    if not ok:
        failures += 1
    print(("PASS " if ok else "FAIL ") + label)


def near(a, b):
    return abs(a - b) < 0.001


def write_png(path):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    header = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(b"\x00\xff\x80\x00\x80"))
                + chunk(b"IEND", b""))


def class_name(x):
    return str(rt.classOf(x)).lower()


def osl_file(t):
    return class_name(t) == "oslmap" and os.path.basename(t.OSLPath).lower()


def handle(x):
    return rt.getHandleByAnim(x)


def make_file(folder):
    os.makedirs(os.path.join(folder, "AT_tex"))
    write_png(os.path.join(folder, "AT_tex", "base.png"))
    path = os.path.join(folder, "AT_mtlx.usda")
    with open(path, "w") as f:
        f.write(USDA)
    return path


def check_report(report):
    built = {rec.name: count for rec, count in report.built}
    check("built A (2 scene materials, names ignore case) and D", built == {"AT_mtlxA": 2, "AT_mtlxD": 1})
    check("B skipped as ND_surface", [n for n, reason in report.skipped if "ND_surface" in reason] == ["AT_mtlxB"])
    check("C not in the scene", report.missing == ["AT_mtlxC"])
    a, d = (next(rec for rec, _ in report.built if rec.name == name) for name in ("AT_mtlxA", "AT_mtlxD"))
    print("  AT_mtlxA notes: " + " | ".join(a.notes))
    check("the missing texture is noted", any("rough_missing.png" in n for n in a.notes))
    check("geometry_tangent is not noted", not any("tangent" in n for n in a.notes))
    check("full metal: specular_weight 0 set to 1, noted", any(n.startswith("metal:") for n in d.notes))


def check_maps(m):
    mix = m.base_color_map
    check("base_color: Mix (color)", osl_file(mix) == "mixcolor.osl")
    check("mix A (bg) white", near(mix.A.r, 255) and near(mix.A.b, 255))
    bitmap = mix.B_map
    check("mix B (fg): Uber Bitmap of base.png", osl_file(bitmap) == "uberbitmap2.osl" and bitmap.filename.lower().endswith("base.png"))
    check("base.png: sRGB, black wrap, map channel 2", bitmap.Filename_ColorSpace == "sRGB" and bitmap.WrapMode == "black"
          and bitmap.UVSet == 2)
    alpha = mix.Mix_map
    check("mix Mix: alpha channel (5) of the same bitmap", class_name(alpha) == "multioutputchanneltexmaptotexmap"
          and alpha.outputChannelIndex == 5 and handle(alpha.sourceMap) == handle(bitmap))
    rough = m.specular_roughness_map
    check("specular_roughness: red channel (2) of a Raw bitmap", rough.outputChannelIndex == 2
          and rough.sourceMap.Filename_ColorSpace == "Raw")
    normal = m.geometry_normal_map
    check("geometry_normal: Normal Bump at 0.5", class_name(normal) == "normal_bump" and near(normal.mult_spin, 0.5))
    check("normal texture: scene-linear Rec.709", normal.normal_map.Filename_ColorSpace == "scene-linear Rec.709-sRGB")
    opacity = m.geometry_opacity_map
    check("opacity 0.5: Color Value grey", osl_file(opacity) == "setcolor.osl" and near(opacity.In.r, 127.5))


def check_values(m):
    print("  specular_weight 2 read back as {0}".format(m.specular_weight))
    check("coat_weight 0.25, thin walled", near(m.coat_weight, 0.25) and m.geometry_thin_walled)
    check("emission on: weight 1, 2000 nits, orange", near(m.emission_weight, 1.0) and near(m.emission_luminance, 2000.0)
          and near(m.emission_color.g, 127.5))
    if str(rt.units.SystemType).lstrip("#").lower() == "centimeters" and near(rt.units.SystemScale, 1.0):
        check("subsurface_radius 0.05 m = 5 cm", near(m.subsurface_radius, 5.0))
    else:
        print("SKIP subsurface_radius: system units are not 1 cm")


def run():
    tools = rt.AlecTools_path("tools")
    if tools not in sys.path:
        sys.path.append(tools)
    rt.pluginManager.loadClass(rt.USDImporter)
    import AlecUsdMtlxRead
    import AlecUsdMtlxBuild
    importlib.reload(AlecUsdMtlxRead)
    importlib.reload(AlecUsdMtlxBuild)
    folder = tempfile.mkdtemp(prefix="AlecUsdMtlx_")
    boxes = list(rt.ATusd_boxes)
    try:
        report = AlecUsdMtlxBuild.apply(make_file(folder))
        report.print()
        check_report(report)
        a = boxes[1].material
        check("box 2 has an OpenPBR_Material AT_mtlxA", class_name(a) == "openpbr_material" and a.name == "AT_mtlxA")
        check("Multi/Sub ID 1 got the same material", handle(rt.getSubMtl(boxes[0].material, 1)) == handle(a))
        check("Multi/Sub ID 2 (ND_surface) kept", class_name(rt.getSubMtl(boxes[0].material, 2)) == "standardmaterial")
        check("D: specular_weight 1", near(boxes[2].material.specular_weight, 1.0))
        check_maps(a)
        check_values(a)
    finally:
        shutil.rmtree(folder)
    rt.ATusd_failures = failures


run()
