-- Test for the mini help on the tools' panels (AlecTools_caddy.add_help) and its tick in the toolbar editor. Run in Max after Reload Alec Tools:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\miniHelp_test.ms"
-- Creates and deletes its own box; the user's AlecTools.toolbar.json is kept and written back at the end.
-- Prints PASS/FAIL lines, then the number of failures and the failed ones.
-- By hand: how each help looks (the Transform Popup's box under its groups), and Mid Between's panel with Shift + click.

global AlecHelpTest_failed = #()

fn AlecHelpTest_check label ok =
(
	format "% %\n" (if ok then "PASS" else "FAIL") label
	if not ok do append AlecHelpTest_failed label
)

-- python.Execute gives #success, not the value: the results come back through a temporary global
fn AlecHelpTest_python code =
(
	python.Execute ("rt.ATtest_value = " + code)
	local value = globalVars.get #ATtest_value
	globalVars.remove #ATtest_value
	value
)

-- every panel that opens by its macro has a mini help or not; the second list opens with the toolbar's right click. Mid Between is
-- left out: its panel opens on a picking that waits for clicks
fn AlecHelpTest_panels state expected =
(
	local plain = #("TransformPopup", "Grab", "Rotate", "Scale", "CreatePopup", "MaxSettings", "LightConverter")
	local options = #("BBox", "Distribute", "MeasureAngle", "UniversalConverter")
	for macro in (plain + options) do
	(
		AlecTools_optionsClick = (findItem options macro) > 0
		macros.run "Alec Tools" macro
		AlecHelpTest_check (state + ": " + macro + (if expected then " has the help" else " has no help")) ((AlecHelpTest_python "help_on_panel()") == expected)
		AlecTools_closeCaddy()
	)
)

python.ExecuteFile (AlecTools_path "tools/toolbarEditor.py")
python.Execute "
import os, shutil
import AlecToolbar
import AlecTools_caddy
from pymxs import runtime as rt
from PySide6 import QtWidgets
from qtmax import GetQMaxMainWindow
help_path = AlecToolbar.config_file()
help_keep = help_path + '.testkeep'
help_had = os.path.isfile(help_path)
if help_had:
    shutil.copy(help_path, help_keep)
def help_on_panel():
    panel = [w for w in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, AlecTools_caddy.OBJECT_NAME) if w.isVisible()][0]
    return panel.findChild(QtWidgets.QLabel, 'help') is not None
def help_editor():
    return [d for d in GetQMaxMainWindow().findChildren(QtWidgets.QDialog, AlecToolbar.EDITOR_NAME) if d.isVisible()][0]
def help_tick(on):
    AlecToolbar.open_editor()
    help_editor().show_help.setChecked(on)
    help_editor().ok()
def help_restore():
    if help_had:
        shutil.move(help_keep, help_path)
    elif os.path.isfile(help_path):
        os.remove(help_path)
    AlecToolbar.create()
"

(
	AlecHelpTest_failed = #()
	-- two objects: Distribute needs them
	local b = box name:"ATtest_miniHelp"
	local b2 = box name:"ATtest_miniHelp2" pos:[50, 0, 0]
	select #(b, b2)

	AlecHelpTest_check "the editor has the tick" ((AlecHelpTest_python "help_editor().show_help is not None") == true)
	python.Execute "help_editor().close()"

	python.Execute "help_tick(True)"
	AlecHelpTest_check "ticked: saved as on" ((AlecHelpTest_python "AlecTools_caddy.help_shown()") == true)
	AlecHelpTest_panels "ticked" true

	python.Execute "help_tick(False)"
	AlecHelpTest_check "unticked: saved as off" ((AlecHelpTest_python "AlecTools_caddy.help_shown()") == false)
	python.Execute "AlecToolbar.open_editor()"
	AlecHelpTest_check "unticked: the editor opens unticked" ((AlecHelpTest_python "help_editor().show_help.isChecked()") == false)
	python.Execute "help_editor().close()"
	AlecHelpTest_panels "unticked" false

	python.Execute "help_restore()"
	delete #(b, b2)

	format "miniHelp_test: % failure(s)\n" AlecHelpTest_failed.count
	for f in AlecHelpTest_failed do format "FAIL %\n" f
)
