"""The checks of tests/smeCursor_test.ms: each placeholder entry makes exactly one node at the click, a missing entry makes nothing and
leaves no menu open."""

import importlib
import sys

from pymxs import runtime as rt
from PySide6 import QtCore, QtWidgets

TOOLS = rt.AlecTools_path("tools")
if TOOLS not in sys.path:
    sys.path.append(TOOLS)
import smeCursor

importlib.reload(smeCursor)

failed = []


def check(label, ok):
    print("PASS" if ok else "FAIL", label)
    if not ok:
        failed.append(label)


def middle(dock):
    page = dock.findChildren(QtWidgets.QTabWidget)[0].currentWidget()
    host = [c for c in page.findChildren(QtWidgets.QWidget) if c.isVisible() and c.metaObject().className() == "MaxSDK::QMaxWinHost"][0]
    return host.mapToGlobal(QtCore.QPoint(host.width() // 2, host.height() // 2))


# the nodes of the active view that are not the ones in before
def new_nodes(before):
    rt.AlecTestKeep = before
    return list(rt.execute("for r in AlecCreate_nodeRefs() where findItem AlecTestKeep r == 0 collect r"))


def remove_nodes():
    rt.execute("(local v = AlecCreate_activeView(); local f = for r in AlecCreate_nodeRefs() where findItem AlecTestKeep r == 0 collect r; v.SetSelectedNodes f; v.DeleteSelection())")


def run():
    dock = smeCursor.sme_dock()
    check("the editor is found by its object name", dock is not None)
    if dock is None:
        return
    check("a widget inside the editor is known as part of it", smeCursor.in_sme(dock.findChildren(QtWidgets.QWidget)[0]))
    check("the graph window is found", smeCursor.graph_window(dock) is not None)
    point = middle(dock)
    for path in smeCursor.PLACEHOLDERS:
        before = rt.AlecCreate_nodeRefs()
        ok = smeCursor.create_at(path, point)
        check("placeholder " + " > ".join(path) + " is made", ok and len(new_nodes(before)) == 1)
        remove_nodes()
    # an Uber Bitmap made at the point takes the menu's Hide All of its maps, and comes out shorter
    before = rt.AlecCreate_nodeRefs()
    smeCursor.create_at(smeCursor.PLACEHOLDERS[0], point)
    rt.AlecCreate_replacePlaceholder(before, "map", "osl_UberBitmap2b")
    new_nodes(before)
    rt.AlecCreate_setTopHideUnused(False)
    node = rt.execute("((AlecCreate_activeView()).GetSelectedNodes())[1]")
    full_height = node.height
    check("Hide All of the maps is chosen on the node", smeCursor.hide_all_maps(point))
    check("Hide All makes the node shorter", node.height < full_height)
    check("Hide All leaves no menu open", QtWidgets.QApplication.activePopupWidget() is None)
    remove_nodes()
    before = rt.AlecCreate_nodeRefs()
    ok = smeCursor.create_at(("Maps", "General", "NoSuchEntry"), point)
    check("a missing entry gives False", not ok)
    check("a missing entry makes no node", len(new_nodes(before)) == 0)
    check("a missing entry leaves no menu open", QtWidgets.QApplication.activePopupWidget() is None)
    check("a point outside the editor gives False", not smeCursor.create_at(smeCursor.PLACEHOLDERS[0], QtCore.QPoint(-5000, -5000)))


run()
print("failures:", len(failed))
for label in failed:
    print("FAIL", label)
