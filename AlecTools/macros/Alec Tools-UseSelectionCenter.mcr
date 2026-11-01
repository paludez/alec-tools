macroScript UseSelectionCenter
category:"Alec Tools"
toolTip:"Use Selection Center"
buttonText:"Use Selection Center"
iconName:":/Icons/MainUI/UseSelectionCenter_24.png"
(
	on isChecked do getCoordCenter() == #selection
	on execute do setCoordCenter #selection
)
