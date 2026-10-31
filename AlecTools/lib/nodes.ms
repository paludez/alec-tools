-- Node helpers shared by the tools: groups, the frame of a node, tight bounds, and bounds and average of points.

-- geometry and shapes; camera and light targets are geometry too, so they are left out by class
fn AlecTools_isMeasurable node =
(
	local sc = superClassOf node
	(sc == GeometryClass or sc == shape) and classOf node != Targetobject
)

fn AlecTools_inClosedGroup node = isGroupMember node and not (isOpenGroupMember node)

-- the head of a group whose members are not open
fn AlecTools_isClosedHead node = isGroupHead node and node.children.count > 0 and not (isOpenGroupMember node.children[1])

-- every member of a group, nested groups (their heads and members) included
fn AlecTools_groupMembers head =
(
	local members = #()
	for c in head.children where isGroupMember c do
	(
		append members c
		join members (AlecTools_groupMembers c)
	)
	members
)

-- the nodes whose geometry makes up an object: the geometry and shapes of a group, or the node itself
fn AlecTools_parts node =
(
	if not (isGroupHead node) then #(node)
	else
	(
		local parts = #()
		for m in AlecTools_groupMembers node where AlecTools_isMeasurable m do append parts m
		parts
	)
)

-- the rotation and position of a node, without its scale
fn AlecTools_localFrame node =
(
	local frame = node.transform.rotation as matrix3
	frame.row4 = node.transform.row4
	frame
)

-- #(min, max) of points, per axis
fn AlecTools_pointsBounds points =
(
	local lo = points[1]
	local hi = points[1]
	for p in points do
	(
		lo = [amin lo.x p.x, amin lo.y p.y, amin lo.z p.z]
		hi = [amax hi.x p.x, amax hi.y p.y, amax hi.z p.z]
	)
	#(lo, hi)
)

fn AlecTools_average points =
(
	local sum = [0, 0, 0]
	for p in points do sum += p
	sum / points.count
)

-- #(min, max) of all the nodes, expressed in frame
fn AlecTools_bounds nodes frame =
(
	local corners = #()
	for n in nodes do join corners (nodeGetBoundingBox n frame)
	AlecTools_pointsBounds corners
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
