-- The last choices made in a tool's dialog (its settings struct), kept for the current scene only: a new, reset or opened scene,
-- a new Max session and a reload start again from each tool's defaults. Dialog positions are not settings, they stay in AlecTools.ini.

global AlecTools_settings = Dictionary #string

fn AlecTools_rememberSettings section s = putDictValue AlecTools_settings section s

-- the settings remembered for section in this scene, or default
fn AlecTools_recallSettings section default = if hasDictValue AlecTools_settings section then getDictValue AlecTools_settings section else default

fn AlecTools_forgetSettings = AlecTools_settings = Dictionary #string

callbacks.removeScripts id:#AlecTools_settings
for ev in #(#systemPostNew, #systemPostReset, #filePostOpen) do
	callbacks.addScript ev "AlecTools_forgetSettings()" id:#AlecTools_settings
