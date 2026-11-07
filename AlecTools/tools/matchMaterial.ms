-- Match Material: assigns the material of a picked object to the selected objects (one undo step). All of them share that one material.
-- A picked closed group gives the material of its first member that has one. A source without a material changes nothing; the status bar says so.

-- the material of an object, or of the first member of a group that has one; undefined when there is none
fn AlecMatchMaterial_sourceMaterial source =
(
	local found = for p in AlecTools_parts source where p.material != undefined collect p.material
	found[1]
)

-- returns false (and changes nothing) when the source has no material
fn AlecMatchMaterial_assign targets source =
(
	local mat = AlecMatchMaterial_sourceMaterial source
	if mat != undefined do
	(
		undo "Match Material" on
			for obj in targets do obj.material = mat
		completeRedraw()
	)
	mat != undefined
)

fn AlecMatchMaterial_pickSource = pickObject message:"Match Material: pick the source object"

fn AlecMatchMaterial_run =
(
	if selection.count == 0 then
		displayTempPrompt "Match Material: select something first" 3000
	else
	(
		local targets = selection as array
		local source = AlecTools_withPickTag "Match Material: click the source object" AlecMatchMaterial_pickSource
		if source != undefined do
		(
			local mat = AlecMatchMaterial_sourceMaterial source
			displayTempPrompt (
				if AlecMatchMaterial_assign targets source then ("Match Material: " + mat.name + " assigned to " + targets.count as string + " objects")
				else "Match Material: the picked object has no material") 3000
		)
	)
)
