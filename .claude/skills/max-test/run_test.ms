-- Runs one Alec Tools test inside Max and returns only the non-PASS lines it printed.
-- Usage through MCP: fileIn "<this file>" then AlecTest_run "<absolute path of tests/x_test.ms>"
global AlecTest_readFrom = fn readFrom logFile offset =
(
	local fs = dotNetObject "System.IO.FileStream" logFile (dotNetClass "System.IO.FileMode").Open \
		(dotNetClass "System.IO.FileAccess").Read (dotNetClass "System.IO.FileShare").ReadWrite
	fs.Seek offset (dotNetClass "System.IO.SeekOrigin").Begin
	local text = (dotNetObject "System.IO.StreamReader" fs).ReadToEnd()
	fs.Close()
	text
)

-- A tool still running (startTool) would hold the test until a right click: the Select command ends it. The user's scene is held,
-- then the test runs in an empty scene (nothing of the user's is hit or changed); the user fetches the scene back when needed.
global AlecTest_run = fn run testFile =
(
	max select
	holdMaxFile()
	resetMaxFile #noPrompt
	AlecTools_reload()
	local logFile = getDir #userScripts + "/AlecTools.listener.log"
	local offset = if doesFileExist logFile then getFileSize logFile else 0
	local crash = undefined
	try (fileIn testFile) catch (crash = getCurrentException())
	flushLog()
	local out = ""
	for line in filterString (AlecTest_readFrom logFile offset) "\r\n" splitEmptyTokens:false \
		where not (matchPattern line pattern:"PASS*") do out += line + "\n"
	if crash != undefined do out += "EXCEPTION " + crash + "\n"
	if out == "" then "no output" else out
)
