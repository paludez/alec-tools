macroScript MaxSettings
category:"Alec Tools"
toolTip:"Max Settings - Export, Import and Restore the shortcuts, toolbars and menus of this Max; Esc or run again closes it"
buttonText:"Max Settings"
iconName:":/Icons/CommandPanel/Motion/BipedRollout/MotionMixer/ReloadFiles_32.png"
(
	on execute do AlecTools_runPython "maxSettings.py"
)
