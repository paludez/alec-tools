macroScript ExportSettings
category:"Alec Tools"
toolTip:"Export Settings - shortcuts, quad menus, menus and toolbars of this Max, to a folder for another PC"
buttonText:"Export Settings"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/settingsTransfer.ms")
		execute "AlecSettings_export()"
	)
)

macroScript ImportSettings
category:"Alec Tools"
toolTip:"Import Settings - replaces the shortcuts, quad menus, menus and toolbars with the ones from a folder (applies when Max closes)"
buttonText:"Import Settings"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/settingsTransfer.ms")
		execute "AlecSettings_import()"
	)
)
