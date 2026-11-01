macroScript EditToolbar
category:"Alec Tools"
toolTip:"Edit Toolbar - the buttons of the Alec Tools toolbar, their order, separators and the option marks"
buttonText:"Edit Toolbar"
iconName:":/Icons/Common/Settings_24.png"
(
	on execute do python.ExecuteFile (AlecTools_path "tools/toolbarEditor.py")
)
