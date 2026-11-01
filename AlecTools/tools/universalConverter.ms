-- UniversalConverter: converts materials to VRayMtl (Natural or Roughness), OpenPBR_Material or Standard (legacy).
-- A VRayMtl in OpenPBR mode is read, but never written: it comes out in Roughness (Auto) or the chosen mode.
-- Sources: VRayMtl, OpenPBR_Material, Physical, Standard, Arnold Standard Surface and USD Preview Surface; other classes are kept.
-- Click: converts with the last settings. Shift + click (or a toolbar right click) opens the caddy (tools/universalConverterCaddy.py).
-- Each source is read into one record (tools/universalConverterRead.ms) and the target is written from it (tools/universalConverterWrite.ms).
-- A Multi/Sub-Object stays, with its IDs; its sub-materials are converted in place.
-- A material is converted once per run, however many times it is used. Replace: every user of a converted material gets the new one
-- (replaceInstances, Material Editor slots included), in one undo step. Copy: copies with a suffix go to the Slate view "UniversalConverter"
-- and the scene stays as it is. What did not map is listed in the Listener.

-- the macro loads this file on every press: a caddy still open from the last press closes first
AlecTools_closeCaddy()

fileIn (AlecTools_path "tools/universalConverterRead.ms")
fileIn (AlecTools_path "tools/universalConverterWrite.ms")

-- defined further down, called by AlecConv_multi before it
global AlecConv_convert

-- settings: the last choice is the next default, for this scene (lib/settings.ms)
struct AlecConv_Settings
(
	input = 1,          -- 1 selected objects, 2 scene, 3 Material Editor slots
	target = 1,         -- 1 VRayMtl, 2 OpenPBR_Material, 3 Standard
	vrayMode = 1,       -- 1 auto (Roughness, a VRayMtl keeps Natural or Roughness, Standard gets Natural), 2 Natural, 3 Roughness
	tintMetals = true,  -- Standard target: metals get the base colour as specular and a darker diffuse
	copyMode = false    -- copies in the Slate Material Editor instead of replacing in the scene
)

-- one run: srcs[i] was converted to outs[i]; the Listener lines and the counts
struct AlecConv_Job (settings, srcs = #(), outs = #(), log = #(), converted = 0, unchanged = 0, kept = 0)

fn AlecConv_targetClass s = (#("vraymtl", "openpbr_material", "standardmaterial"))[s.target]

fn AlecConv_suffix s = (#("_VRay", "_OpenPBR", "_Standard"))[s.target]

-- log

fn AlecConv_converted job m out notes =
(
	job.converted += 1
	append job.log (m.name + ": " + (classOf m) as string + " -> " + (classOf out) as string)
	for n in notes do append job.log ("    " + n)
)

fn AlecConv_unchanged job m =
(
	job.unchanged += 1
	append job.log (m.name + ": unchanged, already " + (classOf m) as string)
)

-- VRayMtl target

fn AlecConv_vrayTargetMode s cls m =
(
	case s.vrayMode of
	(
		2: #natural
		3: #rough
		default: if (cls == "vraymtl" and AlecConv_vrayMode m == #natural) or cls == "standardmaterial" then #natural else #rough
	)
)

-- VRayMtl to VRayMtl: a copy with only the mode and the glossiness values (and maps) that change with it
fn AlecConv_vrayModeChange job m mode =
(
	local srcMode = AlecConv_vrayMode m
	if mode == srcMode then (AlecConv_unchanged job m; m)
	else
	(
		local out = copy m
		local notes = AlecConv_Rec()
		for lobe in #(#reflection, #refraction, #coat, #sheen) do
		(
			local rough = AlecConv_vrayRough m srcMode lobe
			AlecConv_setVRayRough notes out mode lobe rough[1] rough[2] mapRough:(AlecConv_holdsRough srcMode lobe)
		)
		out.option_openPBRMode = false
		out.brdf_useRoughness = mode == #rough
		out.name = m.name
		AlecConv_converted job m out (join #("mode " + srcMode as string + " -> " + mode as string) notes.notes)
		out
	)
)

-- one material that is not a Multi/Sub-Object
fn AlecConv_leaf job m =
(
	local s = job.settings
	local cls = AlecConv_className m
	local reader = AlecConv_reader cls
	if reader == undefined then
	(
		job.kept += 1
		append job.log (m.name + ": kept, " + (classOf m) as string + " is not converted")
		m
	)
	else if cls == "vraymtl" and s.target == 1 then AlecConv_vrayModeChange job m (AlecConv_vrayTargetMode s cls m)
	else if cls == AlecConv_targetClass s then (AlecConv_unchanged job m; m)
	else
	(
		local r = AlecConv_newRec()
		reader r m
		local out = case s.target of
		(
			1: AlecConv_writeVRay r (AlecConv_vrayTargetMode s cls m)
			2: AlecConv_writeOpenPBR r
			3: AlecConv_writeStandard r s.tintMetals
		)
		out.name = m.name
		AlecConv_converted job m out r.notes
		out
	)
)

-- Multi/Sub-Object

fn AlecConv_multi job m =
(
	for i = 1 to m.materialList.count do m.materialList[i] = AlecConv_convert job m.materialList[i]
	m
)

fn AlecConv_convertNew job m = if AlecConv_isA m "multimaterial" then AlecConv_multi job m else AlecConv_leaf job m

-- m converted, or what it was converted to earlier in this run
fn AlecConv_convert job m =
(
	if m == undefined then undefined
	else
	(
		local i = findItem job.srcs m
		if i > 0 then job.outs[i]
		else
		(
			local out = AlecConv_convertNew job m
			append job.srcs m
			append job.outs out
			out
		)
	)
)

-- scene

fn AlecConv_roots s =
(
	local mats = case s.input of
	(
		1: for o in selection where o.material != undefined collect o.material
		2: for m in sceneMaterials where superClassOf m == material collect m
		3: for i = 1 to meditMaterials.count where superClassOf meditMaterials[i] == material collect meditMaterials[i]
	)
	makeUniqueArray mats
)

fn AlecConv_replaceAll job roots =
(
	for root in roots do
	(
		local out = AlecConv_convert job root
		if out != undefined and out != root do replaceInstances root out
	)
)

fn AlecConv_copyOne job root =
(
	local out = AlecConv_convert job (copy root)
	if out != undefined do out.name = root.name + AlecConv_suffix job.settings
	out
)

fn AlecConv_copyAll job roots =
(
	local copies = for root in roots collect AlecConv_copyOne job root
	local view = AlecTools_smeView "UniversalConverter"
	for m in copies where m != undefined do view.CreateNode m [0, 0]
	view.LayoutAll()
)

fn AlecConv_report job =
(
	local summary = "UniversalConverter: " + job.converted as string + " converted, " + job.unchanged as string + " unchanged, " \
		+ job.kept as string + " kept"
	format "%\n" summary
	for line in job.log do format "  %\n" line
	displayTempPrompt (summary + " (details in the Listener)") 5000
)

fn AlecConv_execute s =
(
	local roots = AlecConv_roots s
	if s.target == 1 and VRayMtl == undefined then displayTempPrompt "UniversalConverter: V-Ray is not installed, no VRayMtl can be made" 4000
	else if roots.count == 0 then displayTempPrompt "UniversalConverter: no materials to convert" 3000
	else
	(
		local job = AlecConv_Job settings:s
		if s.copyMode then AlecConv_copyAll job roots
		else undo "UniversalConverter" on (AlecConv_replaceAll job roots)
		AlecConv_report job
	)
)

-- what the caddy (tools/universalConverterCaddy.py) calls

fn AlecConv_lastSettings = AlecTools_recallSettings "UniversalConverter" (AlecConv_Settings())

-- OK in the caddy: the settings are kept for this scene, then the conversion runs
fn AlecConv_apply input target vrayMode tintMetals copyMode =
(
	local s = AlecConv_Settings input:input target:target vrayMode:vrayMode tintMetals:tintMetals copyMode:copyMode
	AlecTools_rememberSettings "UniversalConverter" s
	AlecConv_execute s
)

-- run

fn AlecConv_run showCaddy:true =
(
	AlecTools_closeCaddy()
	if showCaddy then python.ExecuteFile (AlecTools_path "tools/universalConverterCaddy.py")
	else AlecConv_execute (AlecConv_lastSettings())
)
