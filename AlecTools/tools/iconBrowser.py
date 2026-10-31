"""Icon Browser: the icons Max ships with. Pick a source, type to filter by name, click an icon to copy its reference
(it is also printed to the Listener). Opened by the Icon Browser macro.

Qt resources are copied as a path (":/Icons/..."), for Qt widgets; the .rcc themes as the same path Max uses. The icon folders hold bitmap strips (several square
icons side by side) and single images; a strip icon is copied as "file.bmp #n" (n from 1), the form macroScript icons use.
"""

import os

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

IMAGE_EXT = (".png", ".svg", ".bmp", ".ico")


# (label, function giving the icons) for the dropdown
def sources():
    root = rt.getDir(rt.Name("maxroot"))
    ui = os.path.join(root, "UI_ln")
    return [
        ("Qt resources (Max + plugins)", lambda: qt_icons(":/", skip=(":/qt-project.org", ":/AlecIcons"))),
        ("IconsDark.rcc", lambda: rcc_icons(os.path.join(ui, "IconsDark.rcc"), "/AlecIconsDark", ":/Icons")),
        ("IconsLight.rcc", lambda: rcc_icons(os.path.join(ui, "IconsLight.rcc"), "/AlecIconsLight", None)),
        (":/qt-project.org", lambda: qt_icons(":/qt-project.org")),
        ("UI_ln/IconsDark", lambda: folder_icons(os.path.join(ui, "IconsDark"))),
        ("UI_ln/Icons (light)", lambda: folder_icons(os.path.join(ui, "Icons"))),
        ("User icons", lambda: folder_icons(rt.getDir(rt.Name("userIcons")))),
    ]


# (label, QIcon, reference to copy) for every image under a Qt resource root;
# with replace = (old, new) the copied path starts with new instead of old
def qt_icons(root, skip=None, replace=None):
    paths = []
    it = QtCore.QDirIterator(root, QtCore.QDirIterator.Subdirectories)
    while it.hasNext():
        path = it.next()
        if path.lower().endswith((".png", ".svg")) and not (skip and path.startswith(skip)):
            paths.append(path)
    return [(path, QtGui.QIcon(path), replace[1] + path[len(replace[0]):] if replace else path) for path in sorted(paths)]


# an .rcc file registered under its own root, so the theme Max did not load shows too. Max maps the active theme's .rcc
# at ":/Icons", so native = ":/Icons" copies the path Max uses; native = None copies the path under map_root,
# which a tool can use after registering the same .rcc under the same root
def rcc_icons(path, map_root, native):
    if not QtCore.QDir(":" + map_root).exists() and not QtCore.QResource.registerResource(path, map_root):
        print("Icon Browser: cannot load", path)
        return []
    return qt_icons(":" + map_root, replace=(":" + map_root, native) if native else None)


# the "_a" bitmaps are the alpha masks of the "_i" ones, not icons of their own
def is_mask(name):
    stem = os.path.splitext(name)[0].lower()
    return stem.endswith("_a") or stem.endswith("a") and stem[:-1].endswith(("_16", "_24", "_32"))


# a wide bitmap is a strip of square icons; anything else is one icon
def image_icons(path):
    name = os.path.basename(path)
    pix = QtGui.QPixmap(path)
    if pix.isNull():
        return []
    h = pix.height()
    count = pix.width() // h if h and pix.width() > h and pix.width() % h == 0 else 1
    if count == 1:
        return [(name, QtGui.QIcon(pix), path)]
    return [("%s #%d" % (name, i + 1), QtGui.QIcon(pix.copy(i * h, 0, h, h)), "%s #%d" % (name, i + 1)) for i in range(count)]


def folder_icons(folder):
    icons = []
    for dirpath, _, files in os.walk(folder):
        for name in sorted(files):
            if name.lower().endswith(IMAGE_EXT) and not is_mask(name):
                icons.extend(image_icons(os.path.join(dirpath, name)))
    return icons


class IconBrowser(QtWidgets.QDialog):
    def __init__(self, parent):
        super().__init__(parent)
        self.setAttribute(QtCore.Qt.WA_DeleteOnClose)
        self.sources = sources()

        self.source = QtWidgets.QComboBox()
        self.source.addItems([label for label, _ in self.sources])
        self.source.currentIndexChanged.connect(self.load)
        self.search = QtWidgets.QLineEdit(placeholderText="filtru dupa nume, ex. layer")
        self.search.textChanged.connect(self.apply_filter)
        self.icons = QtWidgets.QListWidget(viewMode=QtWidgets.QListView.IconMode, resizeMode=QtWidgets.QListView.Adjust)
        self.icons.setIconSize(QtCore.QSize(24, 24))
        self.icons.setGridSize(QtCore.QSize(44, 44))
        self.icons.setUniformItemSizes(True)
        self.icons.itemClicked.connect(self.copy_reference)
        self.status = QtWidgets.QLabel("click pe o iconita copiaza referinta")
        self.status.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)

        top = QtWidgets.QHBoxLayout()
        top.addWidget(self.source)
        top.addWidget(self.search, 1)
        layout = QtWidgets.QVBoxLayout(self)
        layout.addLayout(top)
        layout.addWidget(self.icons)
        layout.addWidget(self.status)
        self.resize(900, 700)
        self.load(0)

    def load(self, index):
        label, loader = self.sources[index]
        entries = loader()
        self.icons.clear()
        for name, icon, reference in entries:
            item = QtWidgets.QListWidgetItem(icon, "")
            item.setToolTip(name)
            item.setData(QtCore.Qt.UserRole, reference)
            self.icons.addItem(item)
        self.setWindowTitle("Max icons: %s (%d)" % (label, len(entries)))
        self.apply_filter(self.search.text())

    def apply_filter(self, text):
        text = text.lower()
        for i in range(self.icons.count()):
            item = self.icons.item(i)
            item.setHidden(text not in item.toolTip().lower())

    def copy_reference(self, item):
        reference = item.data(QtCore.Qt.UserRole)
        QtWidgets.QApplication.clipboard().setText(reference)
        self.status.setText(reference)
        print(reference)


IconBrowser(GetQMaxMainWindow()).show()
