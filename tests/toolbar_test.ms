-- Toolbar test: run after Reload Alec Tools. Prints PASS/FAIL.
-- Then by hand: dock the toolbar to each edge, restart Max, check it comes back on the last edge;
-- click MidBetween and MeasureAngle with Shift held and check the caddy/dialog opens.
(
	python.Execute "
import AlecToolbar
from PySide6 import QtWidgets
from qtmax import GetQMaxMainWindow
w = GetQMaxMainWindow()
bars = [b for b in w.findChildren(QtWidgets.QToolBar) if b.objectName() == 'AlecToolsToolbar']
acts = [a for a in bars[0].actions() if not a.isSeparator() and a.data() not in AlecToolbar.FIELDS and a.data() not in AlecToolbar.MENUS] if bars else []
noIcon = [a.text() for a in acts if a.icon().isNull()]
known = AlecToolbar.macro_info()
want = [n for n in AlecToolbar.load_config()['buttons'] if n in known]
print('toolbar count: %d (%s)' % (len(bars), 'PASS' if len(bars) == 1 else 'FAIL'))
print('buttons: %d (%s)' % (len(acts), 'PASS' if [a.data() for a in acts] == want else 'FAIL'))
print('text-only buttons: %s' % noIcon)
print('area: %s, visible: %s' % (w.toolBarArea(bars[0]) if bars else None, bars[0].isVisible() if bars else None))
"
	AlecTools_reload()
	python.Execute "
from PySide6 import QtWidgets
from qtmax import GetQMaxMainWindow
n = len([b for b in GetQMaxMainWindow().findChildren(QtWidgets.QToolBar) if b.objectName() == 'AlecToolsToolbar'])
print('after reload count: %d (%s)' % (n, 'PASS' if n == 1 else 'FAIL'))
"
	format "ini area: %\n" (getINISetting (AlecTools_iniFile()) "Toolbar" "area")
)

-- AlecTools_wantsOptions: the toolbar right click flag is read once (run without Shift held)
(
	AlecTools_optionsClick = true
	local first = AlecTools_wantsOptions()
	local second = AlecTools_wantsOptions()
	format "% wantsOptions: the right click flag is read once\n" (if first and not second then "PASS" else "FAIL")
)

-- the editor (tools/toolbarEditor.py): Apply shows a change, Cancel puts the saved toolbar back, OK saves it to AlecTools.toolbar.json.
-- The user's own file is kept and written back at the end
python.ExecuteFile (AlecTools_path "tools/toolbarEditor.py")
python.Execute "
import os, shutil
import AlecToolbar
from PySide6 import QtWidgets
from qtmax import GetQMaxMainWindow
def check(label, ok):
    print(('PASS ' if ok else 'FAIL ') + label)
def bar_names():
    bar = GetQMaxMainWindow().findChild(QtWidgets.QToolBar, AlecToolbar.OBJECT_NAME)
    return [a.data() for a in bar.actions() if not a.isSeparator()]
# removes the first entry of the editor's toolbar list that is not a separator
def remove_first(ed):
    row = next(i for i in range(ed.toolbar.count()) if ed.toolbar.item(i).data(0x0100) != AlecToolbar.SEPARATOR)
    ed.toolbar.setCurrentRow(row)
    ed.remove()
path = AlecToolbar.config_file()
keep = path + '.testkeep'
had = os.path.isfile(path)
if had:
    shutil.copy(path, keep)
before = bar_names()
ed = [d for d in GetQMaxMainWindow().findChildren(QtWidgets.QDialog, AlecToolbar.EDITOR_NAME) if d.isVisible()][0]
check('editor: opens with the toolbar buttons', ed is not None and ed.toolbar.count() == len(ed.saved['buttons']))
remove_first(ed)
ed.mark_size.setValue(14)
ed.apply()
check('editor: Apply shows the change (first button gone)', bar_names() == before[1:])
ed.close()
check('editor: Cancel puts the saved toolbar back', bar_names() == before)
AlecToolbar.open_editor()
ed = [d for d in GetQMaxMainWindow().findChildren(QtWidgets.QDialog, AlecToolbar.EDITOR_NAME) if d.isVisible()][0]
remove_first(ed)
ed.ok()
check('editor: OK saves it and the toolbar keeps it', before[0] not in AlecToolbar.load_config()['buttons'] and bar_names() == before[1:])
if had:
    shutil.move(keep, path)
else:
    os.remove(path)
AlecToolbar.create()
check('editor: the toolbar is back as it was', bar_names() == before)
"
