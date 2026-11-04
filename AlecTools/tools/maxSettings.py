"""Max Settings (Max Settings macro): a panel in the middle of the screen with the three settings transfer commands, Export, Import and
Restore (code in tools/settingsTransfer.ms). Each has its path, kept in AlecTools.ini between sessions; Import and Restore have a
tick to use the Export path instead (Import: the AlecSettings.zip in it, Restore: that folder, where an import of that zip leaves its
backups, AlecSettings-backup-<date and time>.zip; the last three are kept). The macro run again closes it, also while typing in a path (KEY_TOGGLES).
"""

import importlib
import os
import sys

from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

LIB = rt.AlecTools_path("lib")
if LIB not in sys.path:
    sys.path.append(LIB)
import AlecTools_caddy

importlib.reload(AlecTools_caddy)

SECTION = "Max Settings"
ZIP_NAME = "AlecSettings.zip"
LINE_WIDTH = 340
STYLE = """
QCheckBox { color: #cccccc; }
QLineEdit { background: #2b2b2b; color: #dddddd; border: 1px solid #222222; padding: 1px 2px; }
QLineEdit:disabled { color: #888888; }
QLabel#result { padding: 2px 4px; }
QLabel#help { color: #999999; padding: 2px 4px 6px 4px; }
"""
HELP = ("Before Import or Restore, untick \"Save UI configuration on exit\" in Customize > Preferences > General, "
        "or Max overwrites the new settings when it closes. Restart Max after to see them.")
UI_ON_EXIT = '"Save UI configuration on exit" (Customize > Preferences > General) is on: Max would overwrite the new settings when it closes.\n\nUntick it first. Go on anyway?'


def ini_get(key):
    return str(rt.getINISetting(rt.AlecTools_iniFile(), SECTION, key))


def ini_set(key, value):
    rt.setINISetting(rt.AlecTools_iniFile(), SECTION, key, value)


class MaxSettingsCaddy(AlecTools_caddy.Caddy):
    KEY_TOGGLES = True

    def __init__(self):
        super().__init__(SECTION, SECTION, "", "", bare=True)

    def build(self):
        self.setStyleSheet(self.styleSheet() + STYLE)
        # the panel follows its content, so a message under the rows pushes the rest down instead of being drawn over it
        self.body.setSizeConstraint(QtWidgets.QLayout.SetFixedSize)
        title = QtWidgets.QLabel(SECTION)
        title.setObjectName("title")
        self.body.addWidget(title)
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
        help_text = self.add_help(HELP)
        if help_text is not None:
            help_text.setWordWrap(True)
            help_text.setMaximumWidth(LINE_WIDTH + 160)

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
        browse.setToolTip("Browse")
        browse.clicked.connect(lambda checked=False: self.browse(line, key, same_key))
        grid.addWidget(browse, row, 3)
        if same_key is None:
            return line
        tick = QtWidgets.QCheckBox("Export path")
        tick.setToolTip("Use the Export path")
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

    def browse(self, line, key, same_key):
        start = line.text().strip() or self.export_line.text().strip()
        if key == "importFile":
            path, _ = QtWidgets.QFileDialog.getOpenFileName(self, "AlecSettings.zip", start, "Alec settings (*.zip)")
        else:
            path = QtWidgets.QFileDialog.getExistingDirectory(self, "Folder", start)
        if path:
            path = os.path.normpath(path)
            if same_key:
                tick = self.import_same if key == "importFile" else self.restore_same
                tick.setChecked(False)
            line.setText(path)
            ini_set(key, path)
            self.follow_export()

    def say(self, text, color="#f0c040"):
        self.result.setStyleSheet("color: " + color + ";")
        self.result.setText(text)
        self.adjustSize()
        center(self)

    # fn runs a MAXScript function that throws a message when it cannot go on; its result is #(files, backup folder)
    def attempt(self, what, fn):
        try:
            done = fn()
        except Exception as e:
            self.say(what + " failed: " + str(e).replace("-- Runtime error: ", ""), "#e06060")
            return
        self.say("{} {} files. Restart Max to see them.\nThe ones before are backed up in {}".format(what, int(done[0]), done[1]), "#7fd36b")

    def ui_on_exit_ok(self):
        if str(rt.AlecSettings_saveUiOnExit()) == "0":
            return True
        answer = QtWidgets.QMessageBox.question(self, SECTION, UI_ON_EXIT)
        return answer == QtWidgets.QMessageBox.Yes

    def export(self):
        folder = self.export_line.text().strip()
        if not os.path.isdir(folder):
            self.say("Export: choose an existing folder first")
            return
        ini_set("exportDir", folder)
        try:
            count = rt.AlecSettings_exportTo(folder, rt.AlecSettings_defaultDirs())
        except Exception as e:
            self.say("Export failed: " + str(e).replace("-- Runtime error: ", ""), "#e06060")
            return
        self.say("Exported {} files to {}".format(int(count), os.path.join(folder, ZIP_NAME)), "#7fd36b")

    def import_zip(self):
        path = self.import_line.text().strip()
        if not os.path.isfile(path):
            self.say("Import: choose an existing AlecSettings.zip first")
        elif self.ui_on_exit_ok():
            self.attempt("Imported", lambda: rt.AlecSettings_importZip(path, rt.AlecSettings_defaultDirs()))

    def restore(self):
        path = self.restore_line.text().strip()
        if not os.path.exists(path):
            self.say("Restore: choose an existing backup zip, or a folder of backups, first")
        elif self.ui_on_exit_ok():
            self.attempt("Restored", lambda: rt.AlecSettings_restoreFrom(path, rt.AlecSettings_defaultDirs()))


def center(caddy):
    screen = QtGui.QGuiApplication.screenAt(GetQMaxMainWindow().geometry().center()) or QtGui.QGuiApplication.primaryScreen()
    caddy.move(screen.availableGeometry().center() - QtCore.QPoint(caddy.width() // 2, caddy.height() // 2))


if str(rt.AlecTools_caddyOpen) == SECTION:
    AlecTools_caddy.close_all()
else:
    rt.fileIn(rt.AlecTools_path("tools/settingsTransfer.ms"))
    panel = MaxSettingsCaddy()
    AlecTools_caddy.show(panel)
    center(panel)
