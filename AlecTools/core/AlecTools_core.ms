-- Alec Tools core. Loaded by AlecTools_Load.ms (startup), which sets AlecTools_root first.
-- Everything lives under AlecTools_root: core/, macros/, lib/ (and python/ later).

global AlecTools_root

fn AlecTools_path rel =
(
	AlecTools_root + "/" + rel
)

-- removes every Alec* global except the core ones, so a function deleted from the code does not outlive a reload
fn AlecTools_purge =
(
	local core = #(#AlecTools_root, #AlecTools_path, #AlecTools_purge, #AlecTools_removeSavedMacros, #AlecTools_load, #AlecTools_reload)
	for name in globalVars.gather() where matchPattern (name as string) pattern:"Alec*" and findItem core name == 0 do
		globalVars.remove name
)

-- Max saves every macroScript it loads into usermacros and loads that copy at startup, so a renamed or deleted
-- macro would come back as a stale duplicate. The macros loaded below are saved again.
fn AlecTools_removeSavedMacros =
(
	for f in getFiles (getDir #userMacros + "/Alec Tools-*") do deleteFile f
)

-- purges stale globals and saved macro copies, then fileIn lib/*.ms (shared helpers) and every macro file;
-- returns an array of error strings (empty = all ok)
fn AlecTools_load =
(
	AlecTools_purge()
	AlecTools_removeSavedMacros()
	local errors = #()
	local files = getFiles (AlecTools_root + "/lib/*.ms")
	sort files
	local macroFiles = getFiles (AlecTools_root + "/macros/*.mcr")
	join macroFiles (getFiles (AlecTools_root + "/macros/*.ms"))
	sort macroFiles
	join files macroFiles
	for f in files do
	(
		try (fileIn f)
		catch (append errors ((filenameFromPath f) + ": " + (getCurrentException())))
	)
	errors
)

fn AlecTools_reload =
(
	local errors = AlecTools_load()
	if errors.count == 0 then
		format "Alec Tools reloaded from %\n" AlecTools_root
	else
	(
		local msg = "Alec Tools: errors while loading:\n"
		for e in errors do msg += e + "\n"
		format "%" msg
		messageBox msg title:"Alec Tools"
	)
)
