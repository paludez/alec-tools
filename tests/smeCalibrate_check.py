"""Check: can the SME's pan and zoom be measured by diffing screenshots of its graph widget?
Adds a node at [0, 0] and one at [300, 150] in a temporary Slate view, grabs the graph widget before and after each, and prints the
node rectangles found and the scale and origin they give (screen pixel = origin + scale * node position)."""

import time

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets


def graph_widget():
    dock = next(w for w in QtWidgets.QApplication.topLevelWidgets() if w.isVisible() and w.windowTitle() == "Slate Material Editor")
    page = dock.findChildren(QtWidgets.QTabWidget)[0].currentWidget()
    return max((c for c in page.findChildren(QtWidgets.QWidget) if c.isVisible()), key=lambda c: c.width() * c.height())


# the widget's own grab() is black (the graph is drawn natively), so the pixels come from the screen; the widget is found again
# at every grab because Max rebuilds the tab's widgets when the view changes
def snap():
    QtWidgets.QApplication.processEvents()
    time.sleep(0.3)
    QtWidgets.QApplication.processEvents()
    widget = graph_widget()
    top = widget.mapToGlobal(QtCore.QPoint(0, 0))
    image = widget.screen().grabWindow(0, top.x(), top.y(), widget.width(), widget.height()).toImage().convertToFormat(QtGui.QImage.Format_RGB32)
    return image, bytes(image.constBits()), image.bytesPerLine()


def diff_box(a, b):
    (image, bytes_a, stride), bytes_b = a, b[1]
    rows = [y for y in range(image.height()) if bytes_a[y * stride:(y + 1) * stride] != bytes_b[y * stride:(y + 1) * stride]]
    if not rows:
        return None
    cols = []
    for y in (rows[0], rows[-1]):
        row_a, row_b = bytes_a[y * stride:(y + 1) * stride], bytes_b[y * stride:(y + 1) * stride]
        cols += [x for x in range(image.width()) if row_a[x * 4:x * 4 + 4] != row_b[x * 4:x * 4 + 4]]
    for y in rows[1:-1:max(1, len(rows) // 20)]:
        row_a, row_b = bytes_a[y * stride:(y + 1) * stride], bytes_b[y * stride:(y + 1) * stride]
        cols += [x for x in range(image.width()) if row_a[x * 4:x * 4 + 4] != row_b[x * 4:x * 4 + 4]]
    return (min(cols), rows[0], max(cols), rows[-1]) if cols else None


def run():
    s0 = snap()
    widget = graph_widget()
    print("graph widget:", type(widget).__name__, widget.size(), "global top-left:", widget.mapToGlobal(widget.rect().topLeft()))
    rt.AlecCal_add(0, 0)
    s1 = snap()
    rt.AlecCal_add(300, 150)
    s2 = snap()
    a, b = diff_box(s0, s1), diff_box(s1, s2)
    print("node at [0, 0]:    ", a)
    print("node at [300, 150]:", b)
    if a and b:
        print("scale x:", (b[0] - a[0]) / 300.0, "scale y:", (b[1] - a[1]) / 150.0)
        print("origin (screen of node position [0, 0]):", a[0], a[1])


run()
