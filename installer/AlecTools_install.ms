-- Alec Tools installer. Runs when AlecTools.mzp is dragged into 3ds Max (mzp.run "drop").
-- Per-user only, no admin rights: copies the tools to <userScripts>/AlecTools and the
-- loader to <userStartupScripts>.

global AlecTools_copyTree
fn AlecTools_copyTree srcDir dstDir =
(
	local dirIO = dotNetClass "System.IO.Directory"
	local fileIO = dotNetClass "System.IO.File"
	dirIO.CreateDirectory dstDir
	local n = 0
	for f in (dirIO.GetFiles srcDir) do
	(
		fileIO.Copy f (dstDir + "/" + (filenameFromPath f)) true
		n += 1
	)
	for d in (dirIO.GetDirectories srcDir) do
		n += AlecTools_copyTree d (dstDir + "/" + (filenameFromPath d))
	n
)

(
	local pkgDir = getFilenamePath (getThisScriptFilename())
	local scriptsDir = getDir #userScripts
	local startupDir = getDir #userStartupScripts
	local dest = scriptsDir + "/AlecTools"
	local override = scriptsDir + "/AlecTools.root.txt"
	local ver = "?"

	local vf = pkgDir + "AlecTools/version.txt"
	if doesFileExist vf do
	(
		local f = openFile vf
		if f != undefined do (ver = readLine f; close f)
	)

	try
	(
		-- fresh copy, so tools removed from the package do not linger
		local dirIO = dotNetClass "System.IO.Directory"
		if dirIO.Exists dest do dirIO.Delete dest true

		local n = AlecTools_copyTree (pkgDir + "AlecTools") dest
		(dotNetClass "System.IO.File").Copy (pkgDir + "AlecTools_Load.ms") (startupDir + "/AlecTools_Load.ms") true

		fileIn (startupDir + "/AlecTools_Load.ms")

		local msg = "Alec Tools installed (" + (n as string) + " files)\nVersion: " + ver + "\nFolder: " + dest
		if doesFileExist override do
			msg += "\n\nNOTE: AlecTools.root.txt exists, so this PC loads from its override, not from the installed copy."
		msg += "\n\nAssign shortcuts/buttons in Customize User Interface, category 'Alec Tools'."
		messageBox msg title:"Alec Tools"
	)
	catch
	(
		messageBox ("Alec Tools install failed:\n" + (getCurrentException())) title:"Alec Tools"
	)
)
