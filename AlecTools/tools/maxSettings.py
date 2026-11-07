"""Max Settings (Max Settings macro): a caddy in the middle of the screen with the three settings transfer commands, Export, Import and
Restore (code in tools/maxSettings.ms). Each has its path, kept in AlecTools.ini between sessions; Import and Restore have a
tick to use the Export path instead (Import: the AlecSettings.zip in it, Restore: that folder, where an import of that zip leaves its
backups, AlecSettings-backup-<date and time>.zip; the last three are kept). The macro run again closes it, also while typing in a path (KEY_TOGGLES);
so does a click elsewhere (CLICK_AWAY), except while its folder / file dialog or its question is open.
"""

import os

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

import AlecTools_caddy

SECTION = "Max Settings"
ZIP_NAME = "AlecSettings.zip"
LINE_WIDTH = 340
STYLE = "QCheckBox {{ color: {text}; }}".format(**AlecTools_caddy.COLORS)
HELP = "\n".join([
    "Export…: saves the shortcuts, toolbars and menus of this Max",
    "    as AlecSettings.zip in the folder of its row.",
    "Import…: replaces them with the ones in the AlecSettings.zip of its row.",
    "Restore…: puts a backup back: the zip of its row, or the newest backup",
    "    in the folder of its row.",
    "Import and Restore first back up what this Max has, as AlecSettings-backup-<date>.zip",
    "    next to the zip they read; the newest three backups are kept.",
    "Export path: the row takes the Export folder (Import: its AlecSettings.zip)",
    "    and cannot be edited.",
    "… at the end of a row: browse for the folder or the zip.",
    "A typed path is kept for the next time.",
    "Before Import or Restore, untick \"Save UI configuration on exit\"",
    "    (Customize > Preferences > General), or Max overwrites the new settings when it closes.",
    "    Restart Max after, to see them.",
    "The macro again, or a click elsewhere: closes the caddy.",
])
UI_ON_EXIT = '"Save UI configuration on exit" (Customize > Preferences > General) is on: Max would overwrite the new settings when it closes.\n\nUntick it first. Go on anyway?'


def ini_get(key):
    return str(rt.getINISetting(rt.AlecTools_iniFile(), SECTION, key))


# the folders are kept in AlecTools.ini: the user allowed this exception to the ini rule
def ini_set(key, value):
    rt.setINISetting(rt.AlecTools_iniFile(), SECTION, key, value)


# Esc does nothing on the question (it crashed Max on this caddy): Yes or No
class Question(AlecTools_caddy.NoEscape, QtWidgets.QMessageBox):
    pass


class MaxSettingsCaddy(AlecTools_caddy.Caddy):
    KEY_TOGGLES = True
    CLICK_AWAY = True
    # True while a dialog of its own is open (the native file dialog is no Qt widget, so it cannot be looked for)
    dialog_open = False

    def __init__(self):
        super().__init__(SECTION, SECTION, "", "", buttons=False)

    def build(self):
        self.setStyleSheet(self.styleSheet() + STYLE)
        # the caddy follows its content, so a message under the rows pushes the rest down instead of being drawn over it
        self.layout().setSizeConstraint(QtWidgets.QLayout.SetFixedSize)
        grid = QtWidgets.QGridLayout()
        grid.setHorizontalSpacing(6)
        self.body.addLayout(grid)

        self.export_line = self.path_row(grid, 0, "Export…", "exportDir", None, self.export,
                                         "Saves the shortcuts, toolbars and menus of this Max in AlecSettings.zip in this folder")
        self.import_same, self.import_line = self.path_row(grid, 1, "Import…", "importFile", "importSame", self.import_zip,
                                                           "Replaces them with the ones in this AlecSettings.zip (a backup is kept); restart Max after")
        self.restore_same, self.restore_line = self.path_row(grid, 2, "Restore…", "restoreDir", "restoreSame", self.restore,
                                                             "Puts back a backup: this zip, or the newest AlecSettings-backup zip in this folder; restart Max after")
        self.export_line.textChanged.connect(self.follow_export)
        self.follow_export()
        self.result = self.add_result()
        self.result.setWordWrap(True)
        self.result.setMaximumWidth(LINE_WIDTH + 160)
        self.add_help(HELP)

    # one row: the command's button, the tick to use the Export path (not on Export), the path and its browse button;
    # returns the line, with the tick first when there is one
    def path_row(self, grid, row, text, key, same_key, action, tip):
        button = QtWidgets.QPushButton(text)
        button.setToolTip(tip)
        button.clicked.connect(lambda checked=False: action())
        grid.addWidget(button, row, 0)
        line = QtWidgets.QLineEdit(ini_get(key))
        line.setMinimumWidth(LINE_WIDTH)
        line.editingFinished.connect(lambda: ini_set(key, line.text().strip()))
        grid.addWidget(line, row, 2)
        browse = QtWidgets.QPushButton("…")
        browse.setFixedWidth(26)
        browse.setToolTip("Browse for the zip" if key == "importFile" else "Browse for the folder")
        browse.clicked.connect(lambda checked=False: self.browse(line, key, same_key))
        grid.addWidget(browse, row, 3)
        if same_key is None:
            return line
        tick = QtWidgets.QCheckBox("Export path")
        tick.setToolTip("Use the Export folder: Import reads the AlecSettings.zip in it, Restore the newest backup in it")
        tick.setChecked(ini_get(same_key) == "1")
        tick.toggled.connect(lambda on: (ini_set(same_key, "1" if on else "0"), self.follow_export()))
        grid.addWidget(tick, row, 1)
        return tick, line

    # with the tick on, a line shows the path made from the Export one and cannot be edited
    def follow_export(self):
        folder = self.export_line.text().strip()
        for tick, line, path, key in ((self.import_same, self.import_line, os.path.join(folder, ZIP_NAME) if folder else "", "importFile"),
                                      (self.restore_same, self.restore_line, folder, "restoreDir")):
            if tick.isChecked():
                line.setText(path)
            else:
                line.setText(ini_get(key))
            line.setEnabled(not tick.isChecked())

    # a click elsewhere closes it, but not the one that goes to its own dialog, nor the focus coming back from it
    def clicked_away(self):
        if self.dialog_open or QtWidgets.QApplication.activeModalWidget() is not None:
            return
        if any(d.isVisible() for d in self.findChildren(QtWidgets.QDialog)):
            return
        super().clicked_away()

    def with_dialog(self, show):
        self.dialog_open = True
        try:
            return show()
        finally:
            self.dialog_open = False

    def browse(self, line, key, same_key):
        start = line.text().strip() or self.export_line.text().strip()
        if key == "importFile":
            path, _ = self.with_dialog(lambda: QtWidgets.QFileDialog.getOpenFileName(self, "AlecSettings.zip", start, "Alec settings (*.zip)"))
        else:
            path = self.with_dialog(lambda: QtWidgets.QFileDialog.getExistingDirectory(self, "Folder", start))
        if path:
            path = os.path.normpath(path)
            if same_key:
                tick = self.import_same if key == "importFile" else self.restore_same
                tick.setChecked(False)
            line.setText(path)
            ini_set(key, path)
            self.follow_export()

    # color: a key of the shared palette (lib/AlecTools_caddy.py)
    def say(self, text, color="result"):
        self.result.setStyleSheet("color: " + AlecTools_caddy.COLORS[color] + ";")
        self.result.setText(text)
        self.adjustSize()
        center(self)

    # fn runs a MAXScript function that throws a message when it cannot go on; its result is #(files, backup folder)
    def attempt(self, what, fn):
        try:
            done = fn()
        except Exception as e:
            self.say(what + " failed: " + str(e).replace("-- Runtime error: ", ""), "error")
            return
        self.say("{} {} files. Restart Max to see them.\nThe ones before are backed up in {}".format(what, int(done[0]), done[1]), "ok")

    def ui_on_exit_ok(self):
        if str(rt.AlecMaxSettings_saveUiOnExit()) == "0":
            return True
        box = Question(QtWidgets.QMessageBox.Question, SECTION, UI_ON_EXIT, QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No, self)
        return self.with_dialog(box.exec) == QtWidgets.QMessageBox.Yes

    def export(self):
        folder = self.export_line.text().strip()
        if not os.path.isdir(folder):
            self.say("Export: choose an existing folder first")
            return
        ini_set("exportDir", folder)
        try:
            count = rt.AlecMaxSettings_exportTo(folder, rt.AlecMaxSettings_defaultDirs())
        except Exception as e:
            self.say("Export failed: " + str(e).replace("-- Runtime error: ", ""), "error")
            return
        self.say("Exported {} files to {}".format(int(count), os.path.join(folder, ZIP_NAME)), "ok")

    def import_zip(self):
        path = self.import_line.text().strip()
        if not os.path.isfile(path):
            self.say("Import: choose an existing AlecSettings.zip first")
        elif self.ui_on_exit_ok():
            self.attempt("Imported", lambda: rt.AlecMaxSettings_importZip(path, rt.AlecMaxSettings_defaultDirs()))

    def restore(self):
        path = self.restore_line.text().strip()
        if not os.path.exists(path):
            self.say("Restore: choose an existing backup zip, or a folder of backups, first")
        elif self.ui_on_exit_ok():
            self.attempt("Restored", lambda: rt.AlecMaxSettings_restoreFrom(path, rt.AlecMaxSettings_defaultDirs()))


def center(caddy):
    screen = QtGui.QGuiApplication.screenAt(GetQMaxMainWindow().geometry().center()) or QtGui.QGuiApplication.primaryScreen()
    caddy.move(screen.availableGeometry().center() - QtCore.QPoint(caddy.width() // 2, caddy.height() // 2))


if str(rt.AlecTools_caddyOpen) == SECTION:
    AlecTools_caddy.close_all()
else:
    rt.fileIn(rt.AlecTools_path("tools/maxSettings.ms"))
    panel = MaxSettingsCaddy()
    AlecTools_caddy.show(panel)
    center(panel)
