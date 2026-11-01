-- Toolbar position fields test: run after Reload Alec Tools. Prints PASS/FAIL; the user's toolbar file is kept.
-- Then by hand: type 15+28 in a World box and Enter, middle drag a box (ladder), right click a World box (0), Ctrl+Z after each.
python.Execute "
import json, os, shutil
import AlecToolbar
from PySide6 import QtWidgets
from qtmax import GetQMaxMainWindow
def check(label, ok):
    print(('PASS ' if ok else 'FAIL ') + label)
e = AlecToolbar.evaluate
check('evaluate: 15+28', e('15+28') == 43)
check('evaluate: 30/2', e('30/2') == 15)
check('evaluate: -(2+3)*1,5', e('-(2+3)*1,5') == -7.5)
for bad in ('abc', '2**3', '1/0', ''):
    try:
        e(bad)
        check('evaluate refuses ' + repr(bad), False)
    except (SyntaxError, ValueError, ZeroDivisionError):
        check('evaluate refuses ' + repr(bad), True)

path = AlecToolbar.config_file()
keep = path + '.testkeep'
had = os.path.isfile(path)
if had:
    shutil.copy(path, keep)
with open(path, 'w') as f:
    json.dump({'buttons': ['Measure']}, f)
c = AlecToolbar.load_config()
check('a saved toolbar from before gets the new defaults after a separator', c['buttons'][:2] == ['Measure', '|'] and 'LocalOffset' in c['buttons'])
AlecToolbar.save_config({'buttons': ['Measure']})
check('a default removed after the update stays removed', AlecToolbar.load_config()['buttons'] == ['Measure'])
if had:
    shutil.move(keep, path)
else:
    os.remove(path)

bar = GetQMaxMainWindow().findChild(QtWidgets.QToolBar, AlecToolbar.OBJECT_NAME)
names = [n for n, s in AlecToolbar.FIELDS.items() for f in bar.findChildren(AlecToolbar.TransformFields) if f.spec is s]
check('all six rows of fields on the toolbar', sorted(names) == sorted(AlecToolbar.FIELDS))

# the World Rotate row with two objects under Pivot Point Center: the differing Z shows as VARIES, a typed Z goes to both
rows = {n: f for n, s in AlecToolbar.FIELDS.items() for f in bar.findChildren(AlecToolbar.TransformFields) if f.spec is s}
row = rows['WorldRotation']
center = rt.getCoordCenter()
a = rt.box()
b = rt.box(pos=rt.Point3(50, 0, 0))
rt.rotate(b, rt.eulerAngles(0, 0, 30))
rt.select(rt.Array(a, b))
# Max may switch the Use Center when several objects get selected, so it is set after the selection
rt.setCoordCenter(rt.Name('local'))
row.refresh()
check('World Rotate, two objects: equal X shown, differing Z as ' + AlecToolbar.VARIES,
      row.boxes[0].text() == '0.000' and row.boxes[2].text() == AlecToolbar.VARIES)
row.enter(3, 45.0)
check('World Rotate, two objects: a typed Z goes to both',
      abs(rt.AlecFields_angles(a).z - 45) < 0.001 and abs(rt.AlecFields_angles(b).z - 45) < 0.001)
rt.setCoordCenter(rt.Name('selection'))
row.refresh()
check('World Rotate, two objects, Selection Center: the row shows 0 and turns them as one', row.relative and row.boxes[2].text() == '0.000')
rt.delete(rt.Array(a, b))
rt.setCoordCenter(center)
"
