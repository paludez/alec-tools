-- Match Material: copies the material of a picked object to the selected objects (one undo step).
-- A picked object without a material changes nothing; the status bar says so.

-- returns false (and changes nothing) when the source has no material
fn AlecMatchMat_assign targets source =
(
	local hasMaterial = source.material != undefined
	if hasMaterial do
		undo "Match Material" on
			for obj in targets do obj.material = source.material
	hasMaterial
)

fn AlecMatchMat_execute =
(
	if selection.count == 0 then
		displayTempPrompt "Match Material: selecteaza obiectele tinta mai intai" 3000
	else
	(
		local targets = selection as array
		local source = pickObject message:"Alec Tools: pick obiectul sursa"
		if source != undefined do
			displayTempPrompt (if AlecMatchMat_assign targets source then "Match Material: material copiat" else "Match Material: obiectul ales nu are material") 3000
	)
)
