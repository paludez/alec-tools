macroScript UseSelectionCenter
category:"Alec Tools"
toolTip:"Use Selection Center"
buttonText:"Use Selection Center"
(
	on isChecked do getCoordCenter() == #selection
	on execute do setCoordCenter #selection
)
