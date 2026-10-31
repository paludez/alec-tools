-- Runs every tests/*_test.ms one after the other. Run in Max (press Reload Alec Tools first):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\run_all.ms"
-- Each test prints its own PASS/FAIL lines and "<name>: N failure(s)"; a test that stops on an error is reported and the next one runs.

(
	local dir = getFilenamePath (getThisScriptFilename())
	local files = getFiles (dir + "*_test.ms")
	sort files
	local crashed = #()
	for f in files do
	(
		format "\n===== %\n" (filenameFromPath f)
		try (fileIn f)
		catch
		(
			format "ERROR in %: %\n" (filenameFromPath f) (getCurrentException())
			append crashed (filenameFromPath f)
		)
	)
	format "\n===== run_all: % test file(s), % stopped on an error%\n" files.count crashed.count \
		(if crashed.count == 0 then "" else ": " + (crashed as string))
)
