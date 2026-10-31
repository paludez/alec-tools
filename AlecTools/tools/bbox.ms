-- BBox: box cages around the selected objects, drawn as boxes (Display as Box) and not rendered.
-- The button always opens a caddy (AlecBBox_rollout). The cages are a preview rebuilt with undo off on every change; OK makes them again in one undo step, Cancel drops them.
-- One cage for the whole selection, or one per object (Each). World: along the world axes. Local: in the axes of an object (rotation without scale):
-- its own with Each, the first one combined; an object picked in the caddy (the anchor) gives its axes to every cage instead.
-- Sizes come from nodeGetBoundingBox in the frame of the cage, which is tight on the evaluated geometry.
-- A closed group counts as one object, in the axes of its head; members of an open group count one by one. Helpers, lights, cameras and targets are skipped.

-- the macro loads this file on every press: a caddy still open from the last press closes first (its preview goes with it),
-- before its rollout and AlecBBox_active are defined again and lose track of it
if AlecBBox_rollout != undefined and AlecBBox_rollout.open do destroyDialog AlecBBox_rollout

-- settings: kept in AlecTools.ini, so the last choice is the next default
struct AlecBBox_Settings
(
	each = false,      -- one cage per object instead of one for the selection
	localAxes = false, -- the axes of an object instead of the world
	offset = 0.0,      -- added on every side; with addCopy it goes on the copy only
	addCopy = false,   -- a tight cage plus a copy with the offset
	useLayer = true    -- the cages go into the "BBox helpers" layer instead of the layer of their object
)

-- one run of the tool: the objects to measure (a closed group head stands for its group), the picked object whose axes the Local cages take
-- (undefined until one is picked), and the preview cages
struct AlecBBox_Session (settings, sources = #(), anchor, cages = #())

global AlecBBox_active = undefined

fn AlecBBox_readSetting key default =
(
	local text = getINISetting (AlecTools_iniFile()) "BBox" key
	if text == "" then default else if classOf default == BooleanClass then text == "true" else text as float
)

fn AlecBBox_loadSettings =
(
	AlecBBox_Settings each:(AlecBBox_readSetting "each" false) localAxes:(AlecBBox_readSetting "localAxes" false) \
		offset:(AlecBBox_readSetting "offset" 0.0) addCopy:(AlecBBox_readSetting "addCopy" false) useLayer:(AlecBBox_readSetting "useLayer" true)
)

fn AlecBBox_saveSettings s =
(
	local f = AlecTools_iniFile()
	setINISetting f "BBox" "each" (s.each as string)
	setINISetting f "BBox" "localAxes" (s.localAxes as string)
	setINISetting f "BBox" "offset" (s.offset as string)
	setINISetting f "BBox" "addCopy" (s.addCopy as string)
	setINISetting f "BBox" "useLayer" (s.useLayer as string)
)

-- what gets measured

-- the objects of the selection that get a cage: closed groups through their outermost head, other geometry and shapes as they are
fn AlecBBox_sources nodes =
(
	local sources = #()
	for n in nodes where not (AlecTools_inClosedGroup n) do
	(
		if AlecTools_isClosedHead n then (if (AlecTools_parts n).count > 0 do append sources n)
		else if not (isGroupHead n) and AlecTools_isMeasurable n do append sources n
	)
	sources
)

-- cages

fn AlecBBox_copyColor = color 0 231 255

fn AlecBBox_helpersLayer =
(
	local lay = LayerManager.getLayerFromName "BBox helpers"
	if lay == undefined then LayerManager.newLayerFromName "BBox helpers" else lay
)

fn AlecBBox_freeName nm = if getNodeByName nm == undefined then nm else uniqueName nm

-- a Box around b (in frame) grown by offset on every side; no side gets under 0.1, so a flat object still gets a box.
-- The pivot of a Box is at the center of its base, so it goes half the height under the center.
fn AlecBBox_makeCage b frame offset nm col lay =
(
	local size = b[2] - b[1] + 2 * [offset, offset, offset]
	size = [amax size.x 0.1, amax size.y 0.1, amax size.z 0.1]
	local center = (b[1] + b[2]) / 2
	local tm = copy frame
	tm.row4 = [center.x, center.y, center.z - size.z / 2] * frame
	local cage = Box name:(AlecBBox_freeName nm) width:size.x length:size.y height:size.z wirecolor:col
	cage.transform = tm
	cage.boxmode = true
	cage.renderable = false
	cage.castShadows = false
	cage.receiveShadows = false
	lay.addNode cage
	cage
)

-- the cage with the offset, or with addCopy a tight cage plus the copy with the offset (when there is one), named after the cage it was made for
fn AlecBBox_cagesFor b frame nm lay s =
(
	if not s.addCopy then #(AlecBBox_makeCage b frame s.offset nm green lay)
	else
	(
		local cages = #(AlecBBox_makeCage b frame 0 nm green lay)
		if s.offset != 0 do append cages (AlecBBox_makeCage b frame s.offset (cages[1].name + "_p") (AlecBBox_copyColor()) lay)
		cages
	)
)

-- the Local axes for a cage: those of the picked anchor, or else of node
fn AlecBBox_axesFrame sess node = AlecTools_localFrame (if sess.anchor != undefined then sess.anchor else node)

-- all the cages of a session with its settings
fn AlecBBox_build sess =
(
	local s = sess.settings
	local cages = #()
	if s.each then
	(
		for n in sess.sources do
		(
			local frame = if s.localAxes then AlecBBox_axesFrame sess n else matrix3 1
			local nm = n.name + (if s.localAxes then "_bbox_L" else "_bbox_W")
			local lay = if s.useLayer then AlecBBox_helpersLayer() else n.layer
			join cages (AlecBBox_cagesFor (AlecTools_bounds (AlecTools_parts n) frame) frame nm lay s)
		)
	)
	else
	(
		local parts = #()
		for n in sess.sources do join parts (AlecTools_parts n)
		local frame = if s.localAxes then AlecBBox_axesFrame sess sess.sources[1] else matrix3 1
		local lay = if s.useLayer then AlecBBox_helpersLayer() else LayerManager.current
		cages = AlecBBox_cagesFor (AlecTools_bounds parts frame) frame "BBox" lay s
	)
	cages
)

-- session

fn AlecBBox_removePreview sess =
(
	with undo off (for c in sess.cages where isValidNode c do delete c)
	sess.cages = #()
)

fn AlecBBox_updatePreview sess =
(
	AlecBBox_removePreview sess
	with undo off (sess.cages = AlecBBox_build sess)
	redrawViews()
)

fn AlecBBox_end =
(
	if AlecBBox_active != undefined do
	(
		AlecBBox_removePreview AlecBBox_active
		AlecBBox_active = undefined
		redrawViews()
	)
)

-- the preview goes and the same cages are made again in one undo step, so Ctrl+Z removes them all
fn AlecBBox_accept =
(
	local sess = AlecBBox_active
	AlecBBox_removePreview sess
	undo "BBox" on (AlecBBox_build sess)
	AlecBBox_active = undefined
	redrawViews()
)

-- caddy

rollout AlecBBox_rollout "BBox"
(
	checkbox chkEach "One cage per object (Each)" align:#left
	radiobuttons rdoAxes "Axes:" labels:#("World", "Local") columns:2 align:#left
	fn notPreview node = findItem AlecBBox_active.cages node == 0
	pickbutton pckAnchor "Local axes of: " width:214 filter:notPreview align:#left across:2
	button btnClearAnchor "x" width:20 align:#right tooltip:"Back to the axes of each object (or of the first one, combined)"
	spinner spnOffset "Offset: " range:[-1e6, 1e6, 0] type:#worldunits fieldWidth:70 align:#left
	checkbox chkCopy "+ copy: tight cage and one with the offset" align:#left
	checkbox chkLayer "Layer \"BBox helpers\"" align:#left
	button btnReset "Reset" width:240
	button btnOk "OK" width:116 across:2
	button btnCancel "Cancel" width:116
	-- Esc does not reach a dialog on its own, so the key is polled; it also works when the viewport has the focus
	timer tmrEsc interval:100

	-- the anchor matters only in Local axes; without one, each cage takes its own object (Each) or the first object (combined)
	fn showAnchor =
	(
		local sess = AlecBBox_active
		pckAnchor.text = "Local axes of: " + (if sess.anchor != undefined then sess.anchor.name \
			else if sess.settings.each then "(each its own)" else sess.sources[1].name)
		pckAnchor.enabled = sess.settings.localAxes
		btnClearAnchor.enabled = sess.settings.localAxes and sess.anchor != undefined
	)

	fn fill s =
	(
		chkEach.checked = s.each
		rdoAxes.state = if s.localAxes then 2 else 1
		spnOffset.value = s.offset
		chkCopy.checked = s.addCopy
		chkLayer.checked = s.useLayer
	)

	-- reads the controls, saves them and rebuilds the preview
	fn store =
	(
		local s = AlecBBox_Settings each:chkEach.checked localAxes:(rdoAxes.state == 2) offset:spnOffset.value \
			addCopy:chkCopy.checked useLayer:chkLayer.checked
		AlecBBox_saveSettings s
		AlecBBox_active.settings = s
		showAnchor()
		AlecBBox_updatePreview AlecBBox_active
	)

	on AlecBBox_rollout open do
	(
		fill AlecBBox_active.settings
		showAnchor()
	)
	on pckAnchor picked node do
	(
		AlecBBox_active.anchor = node
		showAnchor()
		AlecBBox_updatePreview AlecBBox_active
	)
	on btnClearAnchor pressed do
	(
		AlecBBox_active.anchor = undefined
		showAnchor()
		AlecBBox_updatePreview AlecBBox_active
	)
	on chkEach changed v do store()
	on rdoAxes changed v do store()
	on spnOffset changed v do store()
	on chkCopy changed v do store()
	on chkLayer changed v do store()
	on btnReset pressed do
	(
		fill (AlecBBox_Settings())
		store()
	)
	on btnOk pressed do
	(
		AlecBBox_accept()
		destroyDialog AlecBBox_rollout
	)
	on btnCancel pressed do destroyDialog AlecBBox_rollout
	on tmrEsc tick do if keyboard.escPressed do destroyDialog AlecBBox_rollout
	on AlecBBox_rollout moved p do AlecTools_saveDialogPos "BBox" p
	on AlecBBox_rollout close do AlecBBox_end()
)

-- run

-- what can be clicked when nothing usable is selected: a closed group is picked through its head
fn AlecBBox_isPickable node = AlecTools_isMeasurable node or AlecTools_isClosedHead node

-- the sources of the selection; with none, waits in the prompt line for the user to click an object (right click or Esc gives up)
fn AlecBBox_waitForSources =
(
	local sources = AlecBBox_sources (selection as array)
	if sources.count == 0 do
	(
		pickObject prompt:"BBox: pick an object (geometry, shape or closed group), right click or Esc = cancel" filter:AlecBBox_isPickable select:true
		sources = AlecBBox_sources (selection as array)
	)
	sources
)

-- a caddy that is already open closes first (its preview goes with it), then the tool starts again from the current selection
fn AlecBBox_run =
(
	if AlecBBox_rollout.open do destroyDialog AlecBBox_rollout
	local sources = AlecBBox_waitForSources()
	if sources.count == 0 then
		displayTempPrompt "BBox: nothing to put a cage around" 3000
	else
	(
		AlecBBox_active = AlecBBox_Session settings:(AlecBBox_loadSettings()) sources:sources
		AlecBBox_updatePreview AlecBBox_active
		createDialog AlecBBox_rollout 260 230 pos:(AlecTools_dialogPos "BBox" 260 230) style:#(#style_toolwindow, #style_sysmenu)
	)
)
