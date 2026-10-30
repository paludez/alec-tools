macroScript PickMaterialToSelection
category:"Alec Tools"
toolTip:"Pick Mat"
buttonText:"Pick Mat"
(
	on execute do
	(
		if selection.count == 0 then
		(
			messageBox "Selecteaza obiectele tinta in viewport mai intai!" title:"Alec Tools"
		)
		else
		(
			local targets = selection as array
			local source = pickObject message:"Alec Tools: pick obiectul sursa (material)" filter:PickMaterialToSelection_filter

			if source == undefined then
			(
				select targets
			)
			else
			(
				local srcMat = source.material
				if srcMat == undefined then
				(
					messageBox "Obiectul ales nu are material!" title:"Alec Tools"
					select targets
				)
				else
				(
					undo "Pick Material to Selection" on
					(
						for obj in targets do obj.material = srcMat
					)
					select targets
				)
			)
		)
	)
)

fn PickMaterialToSelection_filter obj =
(
	isValidNode obj and obj.material != undefined
)
