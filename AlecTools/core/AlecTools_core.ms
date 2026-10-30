-- Alec Tools core. Loaded by AlecTools_Load.ms (startup), which sets AlecTools_root first.
-- Everything lives under AlecTools_root: core/, macros/, lib/ (and python/ later).

global AlecTools_root

fn AlecTools_path rel =
(
	AlecTools_root + "/" + rel
)

-- fileIn lib/*.ms (shared helpers) and then every macro file;
-- returns an array of error strings (empty = all ok)
fn AlecTools_load =
(
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
