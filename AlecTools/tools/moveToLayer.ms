-- Move to Layer: the scene side of the popup in moveToLayer.py. Moves the selection into a layer (one undo step)
-- and creates layers. A closed group always moves whole.

-- the nodes that really move: each node lifted to the head of its closed group, plus every member of the groups
fn AlecMoveToLayer_targets nodes =
(
	local out = #()
	for n in nodes do
	(
		local obj = AlecTools_groupObject n
		appendIfUnique out obj
		if isGroupHead obj do for m in AlecTools_groupMembers obj do appendIfUnique out m
	)
	out
)

-- returns how many nodes moved
fn AlecMoveToLayer_move nodes layer =
(
	local targets = AlecMoveToLayer_targets nodes
	undo "Move to Layer" on
		for n in targets do layer.addNode n
	targets.count
)

-- one of the popup's switches, undoable: what is #hide, #freeze or #render
fn AlecMoveToLayer_toggle layer what =
	undo "Move to Layer" on
	(
		case what of
		(
			#hide: layer.isHidden = not layer.isHidden
			#freeze: layer.isFrozen = not layer.isFrozen
			#render: layer.renderable = not layer.renderable
		)
	)

-- the layer made current, undoable
fn AlecMoveToLayer_makeCurrent layer =
	undo "Move to Layer" on layer.current = true

-- the layer called name (created when missing, under parent when parent is not undefined)
fn AlecMoveToLayer_layer name parent =
(
	local layer = LayerManager.getLayerFromName name
	if layer == undefined do
	(
		layer = LayerManager.newLayerFromName name
		if parent != undefined do layer.setParent parent
	)
	layer
)

-- moves nodes into the layer called name (created when missing) in one undo step with the creation; returns the layer
fn AlecMoveToLayer_moveToNew nodes name parent =
(
	local layer
	undo "Move to Layer" on
	(
		layer = AlecMoveToLayer_layer name parent
		AlecMoveToLayer_move nodes layer
	)
	layer
)

-- the entry point: opens the popup (a second run closes it)
fn AlecMoveToLayer_run = AlecTools_runPython "moveToLayer.py"
