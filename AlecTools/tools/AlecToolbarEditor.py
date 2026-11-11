"""Alec Tools toolbar editor (Edit Toolbar macro, tools/toolbarEditor.py): a caddy with the macros on one side, the toolbar on the other;
Apply rebuilds the toolbar with the changes, OK saves them, Cancel puts back what was saved. A click elsewhere or Esc is Cancel, except while
its color or folder dialog is open; the macro run again closes it too."""

import json

from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

import AlecToolbar
import AlecToolbarFields
import AlecTools_caddy

EDITOR_NAME = "Toolbar Editor"

SEPARATOR_TEXT = "──── separator ────"

# the lists in the look of the caddies' boxes
STYLE = """
QListWidget {{ background: {chip}; color: {text}; border: none; border-radius: 3px; outline: none; }}
QListWidget::item:hover {{ background: {chip_hover}; }}
QListWidget::item:selected {{ background: {accent}; color: {value}; }}
QScrollBar:vertical {{ background: transparent; width: 8px; margin: 0; }}
QScrollBar::handle:vertical {{ background: {chip_hover}; border-radius: 4px; min-height: 20px; }}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{ height: 0; }}
""".format(**AlecTools_caddy.COLORS)


# a color swatch that opens the color picker; changed fires while a color is picked, so the toolbar follows it live,
# and the picker's Cancel goes back to the color it started from
class ColorButton(QtWidgets.QPushButton):
    changed = QtCore.Signal()

    def __init__(self, color):
        super().__init__()
        self.setFixedWidth(60)
        self.set_color(color)
        self.clicked.connect(self.pick)

    def set_color(self, color):
        self.color = color
        self.setStyleSheet("background: {}; border: 1px solid {}; border-radius: 3px;".format(color, AlecTools_caddy.COLORS["border"]))

    def pick_live(self, color):
        self.set_color(color)
        self.changed.emit()

    def pick(self):
        start = self.color
        dialog = QtWidgets.QColorDialog(QtGui.QColor(start), self)
        dialog.currentColorChanged.connect(lambda c: self.pick_live(c.name()))
        if not dialog.exec():
            self.pick_live(start)


class Editor(AlecTools_caddy.Caddy):
    KEY_TOGGLES = True
    CLICK_AWAY = True
    # True while a dialog of its own is open (the native folder dialog is no Qt widget, so it cannot be looked for)
    dialog_open = False

    def __init__(self):
        super().__init__(EDITOR_NAME, "Edit Alec Tools Toolbar", "Keep the changes", "Put the saved toolbar back")

    def build(self):
        self.setStyleSheet(self.styleSheet() + STYLE)
        self.info = AlecToolbar.macro_info()
        self.info.update({name: (spec["title"], None) for name, spec in AlecToolbarFields.FIELDS.items()})
        self.info.update({name: (spec["title"], None) for name, spec in AlecToolbar.MENUS.items()})
        self.saved = AlecToolbar.load_config()

        self.macros = QtWidgets.QListWidget()
        self.macros.itemDoubleClicked.connect(lambda item: self.add())
        for name in sorted(self.info, key=lambda n: self.info[n][0].lower()):
            self.macros.addItem(self.item(name))
        self.toolbar = QtWidgets.QListWidget()
        self.toolbar.setDragDropMode(QtWidgets.QAbstractItemView.InternalMove)
        self.toolbar.itemDoubleClicked.connect(lambda item: self.remove())
        for lst in (self.macros, self.toolbar):
            lst.setMinimumSize(230, 300)

        middle = QtWidgets.QVBoxLayout()
        middle.addStretch()
        for text, slot in (("Add →", self.add), ("← Remove", self.remove), ("Separator", self.add_separator),
                           ("Up", lambda: self.move_item(-1)), ("Down", lambda: self.move_item(1))):
            middle.addWidget(self.chip(text, slot))
        middle.addStretch()

        lists = QtWidgets.QHBoxLayout()
        lists.addLayout(self.titled("Macros (double click adds)", self.macros))
        lists.addLayout(middle)
        lists.addLayout(self.titled("Toolbar (drag to reorder, double click removes)", self.toolbar))
        self.body.insertLayout(0, lists)

        # the looks show on the toolbar as they change, like Apply; OK keeps them, Cancel puts the saved ones back
        self.mark_size = self.spin("Options mark size", 4, 24, self.apply)
        self.mark_color = self.color("Options mark color")
        self.sep_color = self.color("Separator color")
        self.sep_width = self.spin("Separator thickness", 1, 6, self.apply)
        self.sep_margin = self.spin("Space around separators", 0, 20, self.apply)
        self.ladder_pixels = self.spin("Ladder drag: pixels per step", 1, 40, None)
        self.world_color = self.color("World icon color")
        self.local_color = self.color("Local icon color")
        self.show_help = self.add_toggle("Mini help on the tools' caddies", "Show", True, lambda: None)
        self.map_folders = QtWidgets.QListWidget()
        self.map_folders.setDragDropMode(QtWidgets.QAbstractItemView.InternalMove)
        self.map_folders.setMaximumHeight(70)
        self.map_folders.setToolTip("Where texture dialogs start; with several folders a menu asks which. Drag to reorder")
        folder_buttons = QtWidgets.QVBoxLayout()
        folder_buttons.addWidget(self.chip("Add folder", self.add_map_folder))
        folder_buttons.addWidget(self.chip("Remove", self.remove_map_folder))
        folders = QtWidgets.QHBoxLayout()
        folders.addWidget(self.map_folders)
        folders.addLayout(folder_buttons)
        self.add_row("Map folders", folders)

        self.add_footer_button("reset", "Apply", "Show the changes on the toolbar", self.apply)
        self.add_footer_button("reset", "Defaults", "Fill in the default toolbar (OK keeps it)",
                               lambda: self.fill(json.loads(json.dumps(AlecToolbar.DEFAULTS))))
        self.fill(self.saved)

    def chip(self, text, slot):
        b = QtWidgets.QPushButton(text)
        b.clicked.connect(lambda checked=False: slot())
        return b

    def titled(self, title, widget):
        box = QtWidgets.QVBoxLayout()
        box.addWidget(QtWidgets.QLabel(title))
        box.addWidget(widget)
        return box

    def color(self, label):
        button = ColorButton("#000000")
        button.changed.connect(self.apply)
        row = QtWidgets.QHBoxLayout()
        row.addWidget(button)
        row.addStretch()
        self.add_row(label, row)
        return button

    # a whole number box with the ladder; typing past the range keeps the nearest end
    def spin(self, label, low, high, on_change):
        def changed():
            field.show_value(min(high, field.value))
            if on_change is not None:
                on_change()
        field = self.add_value(label, low, 0, "", changed, minimum=low)
        return field

    # a click elsewhere closes it as Cancel, but not the one that goes to its own dialog (color, folder), nor the focus coming back from it
    def clicked_away(self):
        if self.dialog_open or QtWidgets.QApplication.activeModalWidget() is not None:
            return
        if any(d.isVisible() for d in self.findChildren(QtWidgets.QDialog)):
            return
        super().clicked_away()

    # a list row for a macro (its text and icon) or a separator; the macro name is kept in the item's data
    def item(self, name):
        if name == AlecToolbar.SEPARATOR:
            it = QtWidgets.QListWidgetItem(SEPARATOR_TEXT)
        else:
            text, icon = self.info.get(name, (name, None))
            it = QtWidgets.QListWidgetItem(QtGui.QIcon(icon) if icon else QtGui.QIcon(), text)
        it.setData(QtCore.Qt.UserRole, name)
        return it

    def fill(self, config):
        self.toolbar.clear()
        for name in config["buttons"]:
            if name == AlecToolbar.SEPARATOR or name in self.info:
                self.toolbar.addItem(self.item(name))
        self.mark_size.show_value(config["markSize"])
        self.mark_color.set_color(config["markColor"])
        self.sep_color.set_color(config["separatorColor"])
        self.sep_width.show_value(config["separatorWidth"])
        self.sep_margin.show_value(config["separatorMargin"])
        self.ladder_pixels.show_value(config["ladderPixels"])
        self.world_color.set_color(config["worldColor"])
        self.local_color.set_color(config["localColor"])
        self.show_help.setChecked(config["showHelp"])
        self.map_folders.clear()
        self.map_folders.addItems(config["mapFolders"])

    def config(self):
        return {
            "buttons": [self.toolbar.item(i).data(QtCore.Qt.UserRole) for i in range(self.toolbar.count())],
            "markSize": int(self.mark_size.value),
            "markColor": self.mark_color.color,
            "separatorColor": self.sep_color.color,
            "separatorWidth": int(self.sep_width.value),
            "separatorMargin": int(self.sep_margin.value),
            "ladderPixels": int(self.ladder_pixels.value),
            "worldColor": self.world_color.color,
            "localColor": self.local_color.color,
            "showHelp": self.show_help.isChecked(),
            "mapFolders": [self.map_folders.item(i).text() for i in range(self.map_folders.count())],
        }

    def add_map_folder(self):
        self.dialog_open = True
        try:
            folder = QtWidgets.QFileDialog.getExistingDirectory(self, "Map folder")
        finally:
            self.dialog_open = False
        if folder and not self.map_folders.findItems(folder, QtCore.Qt.MatchExactly):
            self.map_folders.addItem(folder)

    def remove_map_folder(self):
        row = self.map_folders.currentRow()
        if row >= 0:
            self.map_folders.takeItem(row)

    # a new row goes after the selected one, or at the end
    def insert(self, name):
        row = self.toolbar.currentRow() + 1 if self.toolbar.currentRow() >= 0 else self.toolbar.count()
        self.toolbar.insertItem(row, self.item(name))
        self.toolbar.setCurrentRow(row)

    def add(self):
        it = self.macros.currentItem()
        if it:
            self.insert(it.data(QtCore.Qt.UserRole))

    def add_separator(self):
        self.insert(AlecToolbar.SEPARATOR)

    def remove(self):
        row = self.toolbar.currentRow()
        if row >= 0:
            self.toolbar.takeItem(row)

    def move_item(self, step):
        row = self.toolbar.currentRow()
        if 0 <= row + step < self.toolbar.count() and row >= 0:
            self.toolbar.insertItem(row + step, self.toolbar.takeItem(row))
            self.toolbar.setCurrentRow(row + step)

    def apply(self):
        AlecToolbar.create(self.config())

    def ok(self):
        self.saved = self.config()
        AlecToolbar.save_config(self.saved)
        AlecToolbar.create(self.saved)
        self.close()

    # closing without OK puts back the saved toolbar (Apply only shows the changes)
    def closed(self):
        AlecToolbar.create(self.saved)


# the visible editor, or None (by section: a reload makes a new Editor class)
def current():
    found = [w for w in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, AlecTools_caddy.OBJECT_NAME) if w.section == EDITOR_NAME and w.isVisible()]
    return found[0] if found else None


# the macro pressed again closes it, as Cancel does
def open_editor():
    if current() is not None:
        current().cancel()
    else:
        AlecTools_caddy.show(Editor())
