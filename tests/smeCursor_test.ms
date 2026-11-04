-- Test for tools/smeCursor.py: the Slate Material Editor's right click menu makes the placeholder node at a click. Run in Max with the
-- editor open, visible and on top (the Navigator is not needed):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\smeCursor_test.ms"
-- It is the one to run again after a Max update or on another language of Max: it tells at once if the menu entries are still there.
-- Makes a Slate view "AlecCursorTest" (empty, so the middle of it is an empty spot) and deletes it at the end. Does not save the scene.
-- Prints PASS/FAIL lines, then the number of failures and one FAIL line per failed check as the last lines.

fileIn (AlecTools_path "tools/create.ms")

(
	if not sme.isOpen() do sme.Open()
	local old = sme.GetViewByName "AlecCursorTest"
	if old != 0 do sme.DeleteView old false
	local index = sme.CreateView "AlecCursorTest"
	sme.activeView = index
	python.ExecuteFile ((getFilenamePath (getSourceFileName())) + "smeCursor_test.py")
	sme.DeleteView index false
)
