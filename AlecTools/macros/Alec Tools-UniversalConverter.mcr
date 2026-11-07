macroScript UniversalConverter
category:"Alec Tools"
toolTip:"Universal Converter - materials to VRayMtl or OpenPBR. Click: convert with the last settings, Shift+Click or toolbar right click: caddy"
buttonText:"Converter"
(
	on execute do AlecTools_runCaddyTool "UniversalConverter" "universalConverter.ms" "AlecUniversalConverter_run"
)
