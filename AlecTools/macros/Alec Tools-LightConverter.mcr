macroScript LightConverter
category:"Alec Tools"
toolTip:"Light Converter - lights between Arnold and V-Ray. Click: convert with the last settings, Shift+Click or toolbar right click: caddy"
buttonText:"Lights"
(
	on execute do AlecTools_runCaddyTool "LightConverter" "lightConverter.ms" "AlecLightConverter_run"
)
