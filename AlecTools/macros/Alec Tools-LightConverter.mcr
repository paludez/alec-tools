macroScript LightConverter
category:"Alec Tools"
toolTip:"LightConverter - lights between Arnold and V-Ray"
buttonText:"Lights"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/lightConverter.ms")
		execute "AlecLight_run()"
	)
)
