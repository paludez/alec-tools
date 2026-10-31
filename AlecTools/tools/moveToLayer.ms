-- Move to Layer: the scene side of the popup in moveToLayer.py. Moves the selection into a layer (one undo step)
-- and creates layers. A closed group always moves whole.

-- the nodes that really move: each node lifted to the head of its closed group, plus every member of the groups
fn AlecMoveLayer_targets nodes =
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
fn AlecMoveLayer_move nodes layer =
(
	local targets = AlecMoveLayer_targets nodes
	undo "Move to Layer" on
		for n in targets do layer.addNode n
	targets.count
)

-- the layer called name (created when missing, under parent when parent is not undefined)
fn AlecMoveLayer_layer name parent =
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
fn AlecMoveLayer_moveToNew nodes name parent =
(
	local layer
	undo "Move to Layer" on
	(
		layer = AlecMoveLayer_layer name parent
		AlecMoveLayer_move nodes layer
	)
	layer
)
