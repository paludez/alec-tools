"""Move to Layer: a popup at the cursor with the layer tree, like Blender's M.

Click a name (or Enter) to move the selection there and close; with nothing selected it makes the layer current.
Click the hide / freeze / render icons to toggle them, the current-layer column to make a layer current; the popup stays open.
Type to filter.
The scene changes go through tools/moveToLayer.ms, loaded by the macro before this file.
"""

import os

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

COL_HIDE, COL_FREEZE, COL_RENDER, COL_CURRENT, COL_NAME = range(5)
STATE_COLS = (COL_HIDE, COL_FREEZE, COL_RENDER)
ICON_COLS = STATE_COLS + (COL_CURRENT,)
VISIBLE_ICON, HIDDEN_ICON = ":/Icons/StateSets/Visible_24.png", ":/Icons/StateSets/hidden_24.png"
FREEZE_ICON, RENDER_ICON = ":/Icons/MainUI/Snow_24.png", ":/Icons/MainUI/Teapot_24.png"
# the light theme's SetLayer for the other layers: Max loads only the active theme, so its .rcc is registered here
CURRENT_ICON, OTHER_LAYER_ICON = ":/Icons/Layers/SetLayer_48.png", ":/AlecIconsLight/Layers/SetLayer_24.png"
OFF = "–"
WIDTH, MAX_HEIGHT = 340, 520


# the icon of a state column, or None for a dash: the eye is always shown, freeze and render only when on
def state_icon(layer, col):
    if col == COL_HIDE:
        return HIDDEN_ICON if layer.isHidden else VISIBLE_ICON
    if col == COL_FREEZE:
        return FREEZE_ICON if layer.isFrozen else None
    return RENDER_ICON if layer.renderable else None


def toggle_state(layer, col):
    if col == COL_HIDE:
        layer.isHidden = not layer.isHidden
    elif col == COL_FREEZE:
        layer.isFrozen = not layer.isFrozen
    else:
        layer.renderable = not layer.renderable


def child_layers(layer):
    children = [layer.getChild(i) for i in range(1, layer.getNumChildren() + 1)]
    return sorted(children, key=lambda l: str(l.name).lower())


def top_layers():
    layers = [rt.LayerManager.getLayer(i) for i in range(rt.LayerManager.count)]
    return sorted((l for l in layers if l.getParent() is None), key=lambda l: str(l.name).lower())


def register_light_icons():
    if not QtCore.QDir(":/AlecIconsLight").exists():
        QtCore.QResource.registerResource(os.path.join(rt.getDir(rt.Name("maxroot")), "UI_ln", "IconsLight.rcc"), "/AlecIconsLight")


def color_icon(c):
    pix = QtGui.QPixmap(12, 12)
    pix.fill(QtGui.QColor(int(c.r), int(c.g), int(c.b)))
    return QtGui.QIcon(pix)


def ask_new_layer(default, parent_layer):
    name, ok = QtWidgets.QInputDialog.getText(GetQMaxMainWindow(), "New Layer", "Nume:", text=default)
    name = name.strip()
    if not (ok and name):
        return
    existing = rt.LayerManager.getLayerFromName(name) is not None
    if rt.selection.count == 0:
        rt.AlecMoveLayer_layer(name, parent_layer).current = True
        message = "layer curent " + name
    else:
        rt.AlecMoveLayer_moveToNew(rt.selection, name, parent_layer)
        message = "selectia mutata in " + name
    if existing:
        message += " (exista deja, a ramas unde era)"
    rt.displayTempPrompt("Move to Layer: " + message, 4000)
    rt.redrawViews()


class MoveToLayerPopup(QtWidgets.QWidget):
    def __init__(self, parent):
        super().__init__(parent, QtCore.Qt.Popup)
        self.setAttribute(QtCore.Qt.WA_DeleteOnClose)
        self.layers = []
        self.selection_layers = {str(n.layer.name) for n in rt.selection}

        self.search = QtWidgets.QLineEdit(placeholderText="caută layer...")
        self.search.textChanged.connect(self.apply_filter)
        self.search.installEventFilter(self)
        new_button = QtWidgets.QPushButton("+ New Layer…")
        new_button.clicked.connect(lambda: self.new_layer(None))

        self.tree = QtWidgets.QTreeWidget(columnCount=5, headerHidden=True)
        self.tree.setTreePosition(COL_NAME)
        self.tree.setIndentation(16)
        self.tree.setRootIsDecorated(True)
        self.tree.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        self.tree.customContextMenuRequested.connect(self.context_menu)
        self.tree.itemClicked.connect(self.item_clicked)
        header = self.tree.header()
        for col in ICON_COLS:
            header.setSectionResizeMode(col, QtWidgets.QHeaderView.ResizeToContents)
        header.setStretchLastSection(True)

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.addWidget(self.search)
        layout.addWidget(new_button)
        layout.addWidget(self.tree)

        self.fill_tree()
        self.search.setFocus()

    def fill_tree(self):
        self.tree.clear()
        self.layers = []
        for layer in top_layers():
            self.add_item(self.tree.invisibleRootItem(), layer)
        self.tree.expandAll()

    def add_item(self, parent_item, layer):
        item = QtWidgets.QTreeWidgetItem(parent_item)
        item.setData(COL_NAME, QtCore.Qt.UserRole, len(self.layers))
        self.layers.append(layer)
        item.setText(COL_NAME, str(layer.name))
        item.setIcon(COL_NAME, color_icon(layer.wireColor))
        self.update_item(item)
        for child in child_layers(layer):
            self.add_item(item, child)

    def layer_of(self, item):
        return self.layers[item.data(COL_NAME, QtCore.Qt.UserRole)]

    def update_item(self, item):
        layer = self.layer_of(item)
        for col in STATE_COLS:
            path = state_icon(layer, col)
            item.setIcon(col, QtGui.QIcon(path) if path else QtGui.QIcon())
            item.setText(col, "" if path else OFF)
            item.setTextAlignment(col, QtCore.Qt.AlignCenter)
        font = item.font(COL_NAME)
        font.setBold(str(layer.name) in self.selection_layers)
        item.setFont(COL_NAME, font)
        dim = layer.isHidden or layer.isFrozen
        item.setForeground(COL_NAME, self.palette().color(QtGui.QPalette.Disabled if dim else QtGui.QPalette.Active, QtGui.QPalette.Text))
        item.setIcon(COL_CURRENT, QtGui.QIcon(CURRENT_ICON if layer.current else OTHER_LAYER_ICON))

    def apply_filter(self, text):
        text = text.lower()
        first = None
        for item in self.iter_items():
            match = text in item.text(COL_NAME).lower()
            item.setHidden(not match)
            if match:
                if first is None:
                    first = item
                parent = item.parent()
                while parent:
                    parent.setHidden(False)
                    parent = parent.parent()
        self.tree.setCurrentItem(first if text else None)

    def item_clicked(self, item, col):
        layer = self.layer_of(item)
        if col == COL_NAME:
            self.pick(layer)
            return
        if col == COL_CURRENT:
            layer.current = True
            for other in self.iter_items():
                self.update_item(other)
            return
        toggle_state(layer, col)
        self.update_item(item)
        rt.redrawViews()

    def pick(self, layer):
        self.close()
        if rt.selection.count == 0:
            layer.current = True
            rt.displayTempPrompt("Move to Layer: layer curent " + str(layer.name), 3000)
        else:
            count = rt.AlecMoveLayer_move(rt.selection, layer)
            rt.displayTempPrompt("Move to Layer: %d obiecte in %s" % (count, layer.name), 3000)
        rt.redrawViews()

    # the popup closes first: a Qt popup closes (and is deleted) anyway as soon as the name dialog opens
    def new_layer(self, parent_layer):
        default = self.search.text() or (str(rt.selection[0].name) if rt.selection.count else "")
        self.close()
        ask_new_layer(default, parent_layer)

    def context_menu(self, pos):
        item = self.tree.itemAt(pos)
        if item is None:
            return
        menu = QtWidgets.QMenu(self)
        menu.addAction("New Sublayer…", lambda: self.new_layer(self.layer_of(item)))
        menu.exec(self.tree.viewport().mapToGlobal(pos))

    def eventFilter(self, obj, event):
        if obj is self.search and event.type() == QtCore.QEvent.KeyPress:
            key = event.key()
            if key in (QtCore.Qt.Key_Up, QtCore.Qt.Key_Down):
                self.move_current(-1 if key == QtCore.Qt.Key_Up else 1)
                return True
            if key in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
                item = self.tree.currentItem()
                if item:
                    self.pick(self.layer_of(item))
                return True
            if key == QtCore.Qt.Key_Escape:
                self.close()
                return True
        return super().eventFilter(obj, event)

    def move_current(self, step):
        current = self.tree.currentItem()
        if current is None:
            nxt = self.tree.topLevelItem(0)
        else:
            nxt = self.tree.itemBelow(current) if step > 0 else self.tree.itemAbove(current)
        if nxt:
            self.tree.setCurrentItem(nxt)

    def show_at_cursor(self):
        rows = sum(1 for _ in self.iter_items())
        height = min(MAX_HEIGHT, 90 + rows * self.tree.sizeHintForRow(0))
        self.resize(WIDTH, height)
        pos = QtGui.QCursor.pos()
        area = QtGui.QGuiApplication.screenAt(pos).availableGeometry()
        x = max(area.left(), min(pos.x() - 20, area.right() - WIDTH))
        y = max(area.top(), min(pos.y() - 20, area.bottom() - height))
        self.move(x, y)
        self.show()
        self.search.setFocus()

    def iter_items(self):
        it = QtWidgets.QTreeWidgetItemIterator(self.tree)
        while it.value():
            yield it.value()
            it += 1


register_light_icons()
popup = MoveToLayerPopup(GetQMaxMainWindow())
popup.show_at_cursor()
