macroScript CreatePopup
category:"Alec Tools"
toolTip:"Create Popup - add materials and maps at the mouse: in the Slate Material Editor as nodes, in a viewport on the selection; run again closes it"
buttonText:"Create Popup"
(
	on execute do python.ExecuteFile (AlecTools_path "tools/createPopup.py")
)
