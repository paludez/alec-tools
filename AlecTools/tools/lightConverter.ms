-- LightConverter: converts lights between Arnold and V-Ray, in the direction chosen.
-- Arnold_Light -> VRayLight, VRayIES, Target/Free Spot, Target/Free Direct (VRayShadow); VRayLight, VRayIES and standard Spot/Direct -> Arnold_Light.
-- A click converts with the last settings, Shift or a toolbar right click opens the caddy (tools/lightConverterCaddy.py).
-- Each source is read into one record (tools/lightConverterRead.ms) and the target is written from it (tools/lightConverterWrite.ms).
-- Instances stay instances. Sun and sky are not converted, only listed. What did not map is listed per light in the Listener.

fileIn (AlecTools_path "tools/lightConverterRead.ms")
fileIn (AlecTools_path "tools/lightConverterWrite.ms")

-- settings: the last choice is the next default, for this scene (lib/settings.ms)
struct AlecLightConverter_Settings
(
	input = 1,    -- 1 selected lights, 2 scene
	target = 1,   -- 1 V-Ray, 2 Arnold
	units = 1,    -- 1 look at the current size, 2 independent of size
	setRenderer = false  -- also make the target's GPU renderer the production renderer
)

-- one run: the Listener lines, the counts and the new nodes
struct AlecLightConverter_Job (settings, log = #(), converted = 0, portals = 0, skies = 0, skipped = 0, news = #())

-- which lights a run reads

fn AlecLightConverter_isSource s node =
(
	local c = classOf node.baseObject
	if s.target == 1 then c == Arnold_Light
	else c == VRayLight or c == VRayIES or c == targetSpot or c == freeSpot or c == TargetDirectionallight or c == Directionallight
)

fn AlecLightConverter_inputNodes s =
(
	local all = if s.input == 1 then selection as array else objects as array
	for n in all where superClassOf n.baseObject == light collect n
)

-- the old node's instances with the same scale: the size comes from the scale, so another scale is another light
fn AlecLightConverter_sameScale node =
(
	local all = #()
	InstanceMgr.GetInstances node &all
	for n in all where distance n.scale node.scale < 0.001 collect n
)

-- what a new node keeps of the old one

fn AlecLightConverter_keepNode old new =
(
	new.name = old.name
	old.layer.addNode new
	new.wirecolor = old.wirecolor
	new.isHidden = old.isHidden
	new.isFrozen = old.isFrozen
	new.parent = old.parent
	if isGroupMember old do setGroupMember new true
	for c in (for k in old.children collect k) do c.parent = new
)

-- a mesh light sits on its mesh. A Cylinder has its pivot at the base and its axis along Z, an Arnold cylinder its pivot at the center
-- and its axis along Y
fn AlecLightConverter_frame old r =
(
	case of
	(
		(r.cylinder != undefined):
		(
			local frame = AlecTools_localFrame r.cylinder
			frame.row4 += frame.row3 * r.height / 2.0
			preRotateX frame -90
			frame
		)
		(r.shape != undefined):
		(
			local frame = AlecTools_localFrame old
			preRotateX frame 90
			frame.row4 -= frame.row3 * r.height / 2.0
			frame
		)
		(r.kind == #mesh and r.source != undefined): AlecTools_localFrame r.source
		default: AlecTools_localFrame old
	)
)

fn AlecLightConverter_setTarget old new =
(
	local hasTarget = old.target != undefined
	if isProperty new.baseObject #targeted do new.baseObject.targeted = hasTarget
	if hasTarget do
	(
		if new.target == undefined do new.target = Targetobject()
		new.target.pos = old.target.pos
		new.target.name = old.target.name
		if old.target.pos.isAnimated do new.target.pos.controller = old.target.pos.controller
	)
)

-- the keyed movement goes with the node; a light that hangs on anything else is listed
fn AlecLightConverter_keepMotion old new r =
(
	if classOf old.controller == prs then
	(
		if old.pos.isAnimated do new.pos.controller = old.pos.controller
		if old.target == undefined and old.rotation.isAnimated do new.rotation.controller = old.rotation.controller
	)
	else AlecLightConverter_noteIf r (old.target == undefined) "transform controller not copied"
)

-- instances share one shape, placed once. It is not linked to the light: the light references it, so a link would be a dependency loop
fn AlecLightConverter_placeShape new r frame =
(
	if not matchPattern r.shape.name pattern:"*_shape" do
	(
		r.shape.transform = frame
		r.shape.name = new.name + "_shape"
	)
)

fn AlecLightConverter_place old new r =
(
	AlecLightConverter_keepNode old new
	local frame = AlecLightConverter_frame old r
	new.transform = frame
	if r.shape != undefined do AlecLightConverter_placeShape new r frame
	AlecLightConverter_setTarget old new
	AlecLightConverter_keepMotion old new r
)

-- light groups

fn AlecLightConverter_lightSelects =
(
	local mgr = maxOps.GetCurRenderElementMgr()
	local found = #()
	for i = 0 to mgr.NumRenderElements() - 1 do
	(
		local e = mgr.GetRenderElement i
		if classOf e == VRayLightSelect do append found e
	)
	found
)

-- Arnold's AOV name is the VRayLightSelect with that name
fn AlecLightConverter_aovToSelect new r =
(
	if r.aov != "default" and r.aov != "" do
	(
		local selects = for e in AlecLightConverter_lightSelects() where e.elementName == r.aov collect e
		local e = if selects.count > 0 then selects[1] else VRayLightSelect elementName:r.aov
		if selects.count == 0 do (maxOps.GetCurRenderElementMgr()).AddRenderElement e
		local list = e.lights as array
		append list new
		e.lights = list
	)
)

-- a light in one VRayLightSelect takes its name as the Arnold AOV
fn AlecLightConverter_selectToAov old r =
(
	local mine = for e in AlecLightConverter_lightSelects() where findItem (e.lights as array) old > 0 collect e
	if mine.count > 0 do r.aov = mine[1].elementName
	AlecLightConverter_noteIf r (mine.count > 1) "extra VRayLightSelect not copied: Arnold has one AOV per light"
)

-- one light

-- a double-sided V-Ray light is two Arnold lights with opposite normals, the back one instanced
fn AlecLightConverter_addBack old new r =
(
	local back = instance new
	AlecLightConverter_keepNode old back
	back.name = old.name + "_back"
	local frame = copy new.transform
	preRotateX frame 180
	back.transform = frame
	if old.target != undefined do
	(
		if back.target == undefined do back.target = Targetobject()
		back.target.pos = new.pos - (old.target.pos - new.pos)
	)
	AlecLightConverter_note r "Double-sided: two Arnold lights with opposite normals"
	back
)

fn AlecLightConverter_log job node result r =
(
	job.converted += 1
	append job.log (node.name + ": " + r.label + " -> " + (classOf result.baseObject) as string + ", gain " + r.gain as string)
	for n in r.notes do append job.log ("    " + n)
)

fn AlecLightConverter_skip job node s =
(
	job.skipped += 1
	local why = if s.target == 1 then "not an Arnold light" else "not a V-Ray light or a standard Spot or Direct"
	append job.log (node.name + ": skipped, " + why + " (" + (classOf node.baseObject) as string + ")")
)

-- the new node for a record, undefined for a portal: Arnold's portal is V-Ray's Adaptive dome
fn AlecLightConverter_writeLight job node r =
(
	local s = job.settings
	if s.target == 1 then
		if r.portal then undefined
		else AlecLightConverter_writeVRay r (node.target != undefined) (s.units == 2)
	else AlecLightConverter_writeArnold r
)

fn AlecLightConverter_convertOne job nodes =
(
	local first = nodes[1]
	local r = AlecLightConverter_read first
	if job.settings.target == 2 do AlecLightConverter_selectToAov first r
	local new = AlecLightConverter_writeLight job first r
	if new == undefined then
	(
		job.portals += 1
		append job.log (first.name + ": " + r.label + " portal removed, the Domes get Adaptive dome on")
	)
	else
	(
		for i = 1 to nodes.count do
		(
			local one = if i == 1 then new else instance new
			AlecLightConverter_place nodes[i] one r
			append job.news one
			if job.settings.target == 1 then AlecLightConverter_aovToSelect one r
			else if r.doubleSided do append job.news (AlecLightConverter_addBack nodes[i] one r)
		)
		AlecLightConverter_log job first new r
	)
	for n in nodes where isValidNode n do delete n
	-- the shape of a mesh light that never rendered is not needed by the Arnold cylinder
	if r.cylinder != undefined and isValidNode r.cylinder and not r.cylinder.renderable do delete r.cylinder
)

-- sun and sky are only listed

fn AlecLightConverter_listSky job node =
(
	job.skies += 1
	append job.log (node.name + ": sun or sky, left as it is: rebuild it by hand")
)

fn AlecLightConverter_listEnvironment job =
(
	if AlecLightConverter_isSky environmentMap do
	(
		job.skies += 1
		append job.log ("environment: " + (classOf environmentMap) as string + " left as it is: rebuild it by hand")
	)
)

fn AlecLightConverter_setAdaptive job =
(
	if job.portals > 0 and job.settings.target == 1 do
		for n in job.news where classOf n.baseObject == VRayLight and n.type == 1 do n.dome_adaptive = true
)

fn AlecLightConverter_convertAll job =
(
	local s = job.settings
	local done = #()
	for node in AlecLightConverter_inputNodes s where findItem done node == 0 do
		if AlecLightConverter_isSunOrSky node then AlecLightConverter_listSky job node
		else if AlecLightConverter_isSource s node then
		(
			local nodes = AlecLightConverter_sameScale node
			join done nodes
			AlecLightConverter_convertOne job nodes
		)
		else AlecLightConverter_skip job node s
	AlecLightConverter_setAdaptive job
	AlecLightConverter_listEnvironment job
	AlecLightConverter_endKelvin()
	if s.input == 1 and job.news.count > 0 do select job.news
)

-- the renderer

-- V-Ray and V-Ray GPU have these class IDs (V-Ray's own vrayCheckProductionRenderer); GPU is the one that is not VRay
fn AlecLightConverter_vrayGpuClass =
(
	local found = for c in RendererClass.classes where c != VRay and (c.classID[1] == 1941615238 or c.classID[1] == 1770671000) collect c
	if found.count > 0 then found[1] else undefined
)

-- the Render Setup dialog is closed while the renderer changes. A renderer already in place keeps its settings
fn AlecLightConverter_setProduction rendererClass =
(
	if classOf renderers.production != rendererClass do
	(
		local wasOpen = renderSceneDialog.isOpen()
		if wasOpen do renderSceneDialog.close()
		renderers.production = rendererClass()
		if wasOpen do renderSceneDialog.open()
	)
)

fn AlecLightConverter_setRenderer job target =
(
	if target == 2 then
	(
		AlecLightConverter_setProduction Arnold
		renderers.production.render_device = 1
		append job.log "renderer: Arnold, Render Device GPU"
	)
	else
	(
		local c = AlecLightConverter_vrayGpuClass()
		if c == undefined then append job.log "renderer: V-Ray GPU not found, not changed"
		else
		(
			AlecLightConverter_setProduction c
			append job.log ("renderer: " + c as string)
		)
	)
)

fn AlecLightConverter_report job =
(
	local summary = "Lights: " + job.converted as string + " converted, " + job.portals as string + " portals, " \
		+ job.skies as string + " sun/sky listed, " + job.skipped as string + " skipped"
	AlecTools_report summary job.log
)

fn AlecLightConverter_execute s =
(
	if not (AlecTools_hasVRay() and AlecTools_hasArnold()) then displayTempPrompt "Lights: needs both V-Ray and Arnold installed" 4000
	else if (AlecLightConverter_inputNodes s).count == 0 then displayTempPrompt "Lights: no lights to convert" 3000
	else
	(
		local job = AlecLightConverter_Job settings:s
		undo "Lights" on (AlecLightConverter_convertAll job)
		if s.setRenderer do AlecLightConverter_setRenderer job s.target
		AlecLightConverter_report job
	)
)

-- what the caddy (tools/lightConverterCaddy.py) calls

fn AlecLightConverter_lastSettings = AlecTools_recallSettings "LightConverter" (AlecLightConverter_Settings())

-- OK in the caddy: the settings are kept for this scene, then the conversion runs
fn AlecLightConverter_apply input target units setRenderer =
(
	local s = AlecLightConverter_Settings input:input target:target units:units setRenderer:setRenderer
	AlecTools_rememberSettings "LightConverter" s
	AlecLightConverter_execute s
)

-- run

fn AlecLightConverter_run showCaddy:true =
(
	AlecTools_closeCaddy()
	if showCaddy then python.ExecuteFile (AlecTools_path "tools/lightConverterCaddy.py")
	else AlecLightConverter_execute (AlecLightConverter_lastSettings())
)
