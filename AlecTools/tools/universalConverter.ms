-- UniversalConverter: converts materials to VRayMtl (Natural or Roughness) or OpenPBR_Material.
-- A VRayMtl in OpenPBR mode is read, but never written: it comes out in Roughness (Auto) or the chosen mode.
-- Sources: VRayMtl, OpenPBR_Material, Physical, Standard, Arnold Standard Surface and USD Preview Surface; other classes are kept.
-- Click: converts with the last settings. Shift + click (or a toolbar right click) opens the caddy (tools/universalConverterCaddy.py).
-- Each source is read into one record (tools/universalConverterRead.ms) and the target is written from it (tools/universalConverterWrite.ms).
-- A material with sub-materials (Multi/Sub-Object, Blend, Double Sided, Shell, ...) stays as it is; its sub-materials are converted in place.
-- A material is converted once per run, however many times it is used. Replace: every user of a converted material gets the new one
-- (replaceInstances, Material Editor slots included), in one undo step. Copy: copies with a suffix go to the Slate view "UniversalConverter"
-- and the scene stays as it is. What did not map is listed in the Listener.

-- the macro loads this file on every press: a caddy still open from the last press closes first
AlecTools_closeCaddy()

fileIn (AlecTools_path "tools/universalConverterRead.ms")
fileIn (AlecTools_path "tools/universalConverterWrite.ms")

-- defined further down, called by AlecUniversalConverter_container before it
global AlecUniversalConverter_convert

-- settings: the last choice is the next default, for this scene (lib/settings.ms)
struct AlecUniversalConverter_Settings
(
	input = 1,          -- 1 selected objects, 2 scene, 3 Material Editor slots
	target = 1,         -- 1 VRayMtl, 2 OpenPBR_Material
	vrayMode = 1,       -- 1 auto (Roughness, a VRayMtl keeps Natural or Roughness, a Standard source gets Natural), 2 Natural, 3 Roughness
	copyMode = false    -- copies in the Slate Material Editor instead of replacing in the scene
)

-- one run: srcs[i] was converted to outs[i]; the Listener lines and the counts
struct AlecUniversalConverter_Job (settings, srcs = #(), outs = #(), log = #(), converted = 0, unchanged = 0, kept = 0, containers = 0)

fn AlecUniversalConverter_targetClass s = (#("vraymtl", "openpbr_material"))[s.target]

fn AlecUniversalConverter_suffix s = (#("_VRay", "_OpenPBR"))[s.target]

-- log

fn AlecUniversalConverter_converted job m out notes =
(
	job.converted += 1
	append job.log (m.name + ": " + (classOf m) as string + " -> " + (classOf out) as string)
	for n in notes do append job.log ("    " + n)
)

fn AlecUniversalConverter_unchanged job m =
(
	job.unchanged += 1
	append job.log (m.name + ": unchanged, already " + (classOf m) as string)
)

-- VRayMtl target

fn AlecUniversalConverter_vrayTargetMode s cls m =
(
	case s.vrayMode of
	(
		2: #natural
		3: #rough
		default: if (cls == "vraymtl" and AlecUniversalConverter_vrayMode m == #natural) or cls == "standardmaterial" then #natural else #rough
	)
)

-- VRayMtl to VRayMtl: a copy with only the mode and the glossiness values (and maps) that change with it
fn AlecUniversalConverter_vrayModeChange job m mode =
(
	local srcMode = AlecUniversalConverter_vrayMode m
	if mode == srcMode then (AlecUniversalConverter_unchanged job m; m)
	else
	(
		local out = copy m
		local notes = AlecUniversalConverter_Rec()
		for lobe in #(#reflection, #refraction, #coat, #sheen) do
		(
			local rough = AlecUniversalConverter_vrayRough m srcMode lobe
			AlecUniversalConverter_setVRayRough notes out mode lobe rough[1] rough[2] mapRough:(AlecUniversalConverter_holdsRough srcMode lobe)
		)
		out.option_openPBRMode = false
		out.brdf_useRoughness = mode == #rough
		out.name = m.name
		AlecUniversalConverter_converted job m out (join #("mode " + srcMode as string + " -> " + mode as string) notes.notes)
		out
	)
)

-- one material without sub-materials, or one with sub-materials that has no reader
fn AlecUniversalConverter_leaf job m =
(
	local s = job.settings
	local cls = AlecUniversalConverter_className m
	local reader = AlecUniversalConverter_reader cls
	if reader == undefined then
	(
		job.kept += 1
		append job.log (m.name + ": kept, " + (classOf m) as string + " is not converted")
		m
	)
	else if cls == "vraymtl" and s.target == 1 then AlecUniversalConverter_vrayModeChange job m (AlecUniversalConverter_vrayTargetMode s cls m)
	else if cls == AlecUniversalConverter_targetClass s then (AlecUniversalConverter_unchanged job m; m)
	else
	(
		local r = AlecUniversalConverter_newRec()
		reader r m
		local out = case s.target of
		(
			1: AlecUniversalConverter_writeVRay r (AlecUniversalConverter_vrayTargetMode s cls m)
			2: AlecUniversalConverter_writeOpenPBR r
		)
		out.name = m.name
		AlecUniversalConverter_converted job m out r.notes
		out
	)
)

-- a material with sub-materials that is not a source (a VRayMtl or OpenPBR_Material is read, whatever its sub-materials)
fn AlecUniversalConverter_isContainer m =
	AlecUniversalConverter_reader (AlecUniversalConverter_className m) == undefined and getNumSubMtls m > 0

-- a material with sub-materials: it stays (a copy of it in copy mode, so the original is never changed), each sub-material is
-- converted and set back in its slot
fn AlecUniversalConverter_container job m =
(
	local c = if job.settings.copyMode then copy m else m
	job.containers += 1
	append job.log (m.name + ": " + (classOf m) as string + " kept, " + (getNumSubMtls m) as string + " sub-materials walked")
	for i = 1 to getNumSubMtls c do
	(
		local sub = getSubMtl c i
		if sub != undefined do
		(
			local out = AlecUniversalConverter_convert job sub
			if out != sub do setSubMtl c i out
		)
	)
	c
)

fn AlecUniversalConverter_convertNew job m =
(
	if AlecUniversalConverter_isContainer m then AlecUniversalConverter_container job m
	else AlecUniversalConverter_leaf job m
)

-- m converted, or what it was converted to earlier in this run
fn AlecUniversalConverter_convert job m =
(
	if m == undefined then undefined
	else
	(
		local i = findItem job.srcs m
		if i > 0 then job.outs[i]
		else
		(
			local out = AlecUniversalConverter_convertNew job m
			append job.srcs m
			append job.outs out
			out
		)
	)
)

-- scene

fn AlecUniversalConverter_roots s =
(
	local mats = case s.input of
	(
		1: for o in selection where o.material != undefined collect o.material
		2: for m in sceneMaterials where superClassOf m == material collect m
		3: for i = 1 to meditMaterials.count where superClassOf meditMaterials[i] == material collect meditMaterials[i]
	)
	makeUniqueArray mats
)

fn AlecUniversalConverter_replaceAll job roots =
(
	for root in roots do
	(
		local out = AlecUniversalConverter_convert job root
		if out != undefined and out != root do replaceInstances root out
	)
)

fn AlecUniversalConverter_copyOne job root =
(
	local out = AlecUniversalConverter_convert job (if AlecUniversalConverter_isContainer root then root else copy root)
	if out != undefined do out.name = root.name + AlecUniversalConverter_suffix job.settings
	out
)

fn AlecUniversalConverter_copyAll job roots =
(
	local copies = for root in roots collect AlecUniversalConverter_copyOne job root
	local view = AlecTools_smeView "UniversalConverter"
	for m in copies where m != undefined do view.CreateNode m [0, 0]
	view.LayoutAll()
)

fn AlecUniversalConverter_report job =
(
	AlecTools_report ("Converter: " + job.converted as string + " converted, " + job.unchanged as string + " unchanged, " 		+ job.kept as string + " kept, " + job.containers as string + " with sub-materials walked") job.log
)

fn AlecUniversalConverter_execute s =
(
	local roots = AlecUniversalConverter_roots s
	if s.target == 1 and not AlecTools_hasVRay() then displayTempPrompt "Converter: V-Ray is not installed, no VRayMtl can be made" 4000
	else if roots.count == 0 then displayTempPrompt "Converter: no materials to convert" 3000
	else
	(
		local job = AlecUniversalConverter_Job settings:s
		undo "Universal Converter" on
		(
			if s.copyMode then AlecUniversalConverter_copyAll job roots
			else AlecUniversalConverter_replaceAll job roots
		)
		AlecUniversalConverter_report job
	)
)

-- what the caddy (tools/universalConverterCaddy.py) calls

fn AlecUniversalConverter_lastSettings = AlecTools_recallSettings "UniversalConverter" (AlecUniversalConverter_Settings())

-- OK in the caddy: the settings are kept for this scene, then the conversion runs
fn AlecUniversalConverter_apply input target vrayMode copyMode =
(
	local s = AlecUniversalConverter_Settings input:input target:target vrayMode:vrayMode copyMode:copyMode
	AlecTools_rememberSettings "UniversalConverter" s
	AlecUniversalConverter_execute s
)

-- run

fn AlecUniversalConverter_run showCaddy:true =
(
	AlecTools_closeCaddy()
	if showCaddy then AlecTools_runPython "universalConverterCaddy.py"
	else AlecUniversalConverter_execute (AlecUniversalConverter_lastSettings())
)
