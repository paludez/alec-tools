-- Node helpers shared by the tools: groups, the frame of a node and tight bounds.

-- geometry and shapes; camera and light targets are geometry too, so they are left out by class
fn AlecTools_isMeasurable node =
(
	local sc = superClassOf node
	(sc == GeometryClass or sc == shape) and classOf node != Targetobject
)

fn AlecTools_inClosedGroup node = isGroupMember node and not (isOpenGroupMember node)

-- the head of a group whose members are not open
fn AlecTools_isClosedHead node = isGroupHead node and node.children.count > 0 and not (isOpenGroupMember node.children[1])

-- every geometry and shape inside a group, nested groups included
fn AlecTools_collectGroupParts head parts =
(
	for c in head.children where isGroupMember c do
	(
		if AlecTools_isMeasurable c do append parts c
		AlecTools_collectGroupParts c parts
	)
)

-- the nodes whose geometry makes up an object: the members of a group, or the node itself
fn AlecTools_parts node =
(
	local parts = #()
	if isGroupHead node then AlecTools_collectGroupParts node parts else append parts node
	parts
)

-- the rotation and position of a node, without its scale
fn AlecTools_localFrame node =
(
	local frame = node.transform.rotation as matrix3
	frame.row4 = node.transform.row4
	frame
)

-- #(min, max) of all the nodes, expressed in frame
fn AlecTools_bounds nodes frame =
(
	local b = nodeGetBoundingBox nodes[1] frame
	local lo = b[1]
	local hi = b[2]
	for n in nodes do
	(
		b = nodeGetBoundingBox n frame
		lo = [amin lo.x b[1].x, amin lo.y b[1].y, amin lo.z b[1].z]
		hi = [amax hi.x b[2].x, amax hi.y b[2].y, amax hi.z b[2].z]
	)
	#(lo, hi)
)

-- the object a node belongs to: the head of its closed group, or the node itself
fn AlecTools_groupObject node =
(
	while AlecTools_inClosedGroup node do node = node.parent
	node
)

-- the closest visible geometry hit by a ray, as #(node, hit ray) with the hit ray's dir the surface normal, or undefined.
-- intersectRayScene does not hit back faces, and from very far (100000) it hits nothing
fn AlecTools_rayHit r =
(
	local best = undefined
	local bestDist = 1e30
	for hit in intersectRayScene r where not hit[1].isHidden and AlecTools_isMeasurable hit[1] do
	(
		local d = distance r.pos hit[2].pos
		if d < bestDist do
		(
			bestDist = d
			best = hit
		)
	)
	best
)

-- the surface under a screen point, as AlecTools_rayHit gives it
fn AlecTools_surfaceAt screenPoint = AlecTools_rayHit (mapScreenToWorldRay screenPoint)

-- the object under a screen point (the head of its closed group), or undefined; only surfaces a ray hits count
fn AlecTools_objectAt screenPoint =
(
	local hit = AlecTools_surfaceAt screenPoint
	if hit == undefined then undefined else AlecTools_groupObject hit[1]
)
