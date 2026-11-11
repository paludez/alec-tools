"""Create Popup (Create Popup macro): a small panel at the mouse with three groups, Materials, Maps and Misc, each with its buttons in two
columns. The logic is tools/create.ms. Over the Slate Material Editor a button makes the node at the mouse (a placeholder from the
editor's own right click menu gives the position); what takes the selected nodes (see AlecCreate_composeTip in create.ms) goes next to
them instead, and its button is highlighted with a tip saying what it does. Over a viewport it assigns a material to the selection. A
button is off when its class is not installed, and maps are off over a viewport. The files buttons make a material from textures chosen
in a dialog, wired by their file names; VRayBitmap and UberBitmap ask for their files too, with a node for each. Swap order turns round the inputs of the selected OSL
Mix or CompTex. A click anywhere else, Esc or the macro run again closes it.
"""

import importlib

import pymxs
from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow

import AlecTools_caddy
import smeCursor

importlib.reload(smeCursor)

SECTION = "Create Popup"
# the Add buttons of a group in this many columns
COLUMNS = 2

# the groups: (title, kind, buttons, actions), a button being (text, class name), an action (text, MAXScript function, the MAXScript
# function that tells if it can run, tip when it can, tip when it cannot); kind is "material" or "map" (what the buttons make; a map
# needs the Slate Material Editor). FILE_BUTTONS come after the buttons of the group they name
GROUPS = [
    ("Materials", "material", [("VRayMtl", "VRayMtl"), ("OpenPBR", "OpenPBR_Material")], []),
    ("Maps", "map", [("VRayBitmap", "VRayBitmap"), ("UberBitmap", "osl_UberBitmap2b"), ("VRayColor", "VRayColor"),
                     ("NormalMap", "VRayNormalMap"), ("CompTex", "VRayCompTex"), ("OSL Mix", "osl_MixColor"),
                     ("EdgesTex", "VRayEdgesTex"), ("Triplanar", "VRayTriplanarTex"), ("Multi/Sub", "VRayMultiSubTex")], []),
    ("Misc", "material", [("Multi/Sub", "Multimaterial")],
     [("Swap order", "AlecCreate_swapInputs", "AlecCreate_canSwap", "Swaps the two inputs of the selected OSL Mix or CompTex",
       "Select an OSL Mix or a CompTex in the Slate Material Editor, then open the popup over it")]),
]
# buttons that open a file dialog and make a material from the chosen textures: (text, class name), in the group Materials
FILE_BUTTONS = [("VRayMtl files", "VRayMtl"), ("OpenPBR files", "OpenPBR_Material")]
FILE_FILTER = "Images (*.png *.jpg *.jpeg *.tif *.tiff *.exr *.hdr *.tga *.bmp *.tx);;All files (*)"
FILE_TIP = "Pick textures: they make a material, each going to the slot its file name says (albedo, roughness, normal, ...)"
FILE_FILL_TIP = "Pick textures: they go into the empty slots of the selected material, no new material is made"
# the map buttons that ask for their files first
UBER = "osl_UberBitmap2b"
BITMAPS = ("VRayBitmap", UBER)
BITMAP_TIP = "Pick textures: a node for each file"
# a button that takes the selected nodes
STYLE = "QPushButton#composes {{ color: {result}; }}".format(**AlecTools_caddy.COLORS)
HELP = "\n".join([
    "Opened over the Slate Material Editor: a button makes its node where the mouse was",
    "    (next to the selected nodes when that spot cannot be used).",
    "Opened over a viewport: Materials and Misc assign a new material to the selected objects",
    "    (the files buttons too).",
    "Yellow buttons use what is selected in Slate: the selected maps or materials become",
    "    the new node's inputs, or it goes into the selected material's empty slot;",
    "    hover one for what it does.",
    "Maps: only over Slate.",
    "VRayBitmap, UberBitmap: pick files, a node for each file.",
    "VRayMtl files, OpenPBR files: pick textures, a new material gets each one in the slot",
    "    its file name says (albedo, roughness, normal, ...);",
    "    yellow: they fill the empty slots of the selected material instead.",
    "Swap order (Slate only): swaps the two inputs of the selected OSL Mix or CompTex.",
    "Grey buttons: not installed, or not usable here; hover for why.",
    "Esc, a click elsewhere, or the macro again: closes it.",
])


# true when the mouse is over the Slate Material Editor
def over_sme():
    return smeCursor.in_sme(QtWidgets.QApplication.widgetAt(QtGui.QCursor.pos()))


# the editor's right click menu makes a placeholder node at the point, with undo off: the nodes before it and whether it was made
def make_placeholder(cursor):
    before = rt.AlecCreate_nodeRefs()
    with pymxs.undo(False):
        placed = any(smeCursor.create_at(path, cursor) for path in smeCursor.PLACEHOLDERS)
    return before, placed


# where the mouse was in the editor's view, None when the menu could not be used there
def mouse_spot(cursor):
    before, placed = make_placeholder(cursor)
    return rt.AlecCreate_takePlaceholder(before) if placed else None


# the top selected node, just made at the point, gets the editor's own Hide All of its maps in place of hidden unused slots, which it keeps
# when the menu cannot be used. Not in the undo list, like the placeholder
def hide_maps_at(cursor):
    rt.AlecCreate_setTopHideUnused(False)
    with pymxs.undo(False):
        hidden = smeCursor.hide_all_maps(cursor)
    if not hidden:
        rt.AlecCreate_setTopHideUnused(True)


# the folder a texture dialog starts in: the map folder set in the toolbar editor, with several a menu at the mouse asks which; "" with none
# set, None when the menu is left without a choice
def pick_folder():
    folders = AlecTools_caddy.map_folders()
    if len(folders) < 2:
        return folders[0] if folders else ""
    menu = QtWidgets.QMenu(GetQMaxMainWindow())
    for folder in folders:
        menu.addAction(folder)
    chosen = menu.exec(QtGui.QCursor.pos())
    return chosen.text() if chosen else None


# the textures chosen in the Windows file dialog
def pick_textures(title):
    folder = pick_folder()
    return [] if folder is None else QtWidgets.QFileDialog.getOpenFileNames(GetQMaxMainWindow(), title, folder, FILE_FILTER)[0]


class CreatePopup(AlecTools_caddy.Caddy):
    CLICK_AWAY = True

    def __init__(self, in_sme):
        self.in_sme = in_sme
        self.cursor = QtGui.QCursor.pos()
        super().__init__(SECTION, SECTION, "", "", bare=True)
        # the floating Slate Material Editor is a window of its own and would cover a panel that belongs to the Max window
        self.setWindowFlag(QtCore.Qt.WindowStaysOnTopHint, True)

    def build(self):
        self.setStyleSheet(self.styleSheet() + STYLE)
        for title, kind, buttons, actions in GROUPS:
            heading = QtWidgets.QLabel(title)
            heading.setObjectName("section")
            self.rows.addWidget(heading, self.rows.rowCount(), 0, 1, COLUMNS)
            row = self.rows.rowCount()
            widgets = [self.button(text, kind, class_name) for text, class_name in buttons] + [self.action(*a) for a in actions]
            if title == "Materials":
                widgets += [self.file_button(text, class_name) for text, class_name in FILE_BUTTONS]
            for i, widget in enumerate(widgets):
                self.rows.addWidget(widget, row + i // COLUMNS, i % COLUMNS)
        # the help icon at the right end of the first heading's row, which is empty past its short title
        icon = self.help_icon(HELP)
        if icon is not None:
            self.rows.addWidget(icon, 0, COLUMNS - 1, QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)

    # why a button cannot be used here, "" when it can
    def why_off(self, kind, class_name):
        if not rt.AlecCreate_installed(kind, class_name):
            return class_name + " is not installed"
        if kind == "map" and not self.in_sme:
            return "Needs the Slate Material Editor: open the popup with the mouse over it"
        return ""

    def button(self, text, kind, class_name):
        button = QtWidgets.QPushButton(text)
        reason = self.why_off(kind, class_name)
        button.setEnabled(not reason)
        button.setToolTip(reason or (BITMAP_TIP if class_name in BITMAPS else ""))
        compose_tip = rt.AlecCreate_composeTip(class_name) if not reason and self.in_sme else ""
        if compose_tip:
            button.setObjectName("composes")
            button.setToolTip(compose_tip)
        if class_name in BITMAPS:
            button.clicked.connect(lambda c=0, n=class_name: self.add_bitmaps(n))
        else:
            button.clicked.connect(lambda c=0, k=kind, n=class_name: self.add(k, n))
        return button

    # a button that works on what is selected in the Slate Material Editor
    def action(self, text, function, can_run, tip, off_tip):
        usable = self.in_sme and getattr(rt, can_run)()
        button = QtWidgets.QPushButton(text)
        button.setEnabled(usable)
        button.setToolTip(tip if usable else off_tip)
        button.clicked.connect(lambda c=0, f=function: self.act(f))
        return button

    def act(self, function):
        self.close()
        getattr(rt, function)()

    def file_button(self, text, class_name):
        button = QtWidgets.QPushButton(text)
        reason = self.why_off("material", class_name)
        button.setEnabled(not reason)
        button.setToolTip(reason or FILE_TIP)
        if not reason and self.in_sme and rt.AlecCreate_filesTarget() is not None:
            button.setObjectName("composes")
            button.setToolTip(FILE_FILL_TIP)
        button.clicked.connect(lambda c=0, n=class_name: self.from_files(n))
        return button

    # the popup closes, then the dialog; over the editor the selected material takes the files, or a new one goes where the mouse was when
    # the popup opened
    def from_files(self, class_name):
        in_sme, cursor = self.in_sme, self.cursor
        self.close()
        files = pick_textures("Create " + class_name + " from textures")
        if files:
            new_at_mouse = in_sme and rt.AlecCreate_filesTarget() is None
            spot = mouse_spot(cursor) if new_at_mouse else None
            rt.AlecCreate_fromFiles(class_name, files, in_sme, spot)

    # the popup closes, then the dialog; a cancelled dialog makes nothing. The node goes where the mouse was when the popup opened, or next to
    # what it takes
    def add_bitmaps(self, class_name):
        cursor = self.cursor
        self.close()
        files = pick_textures("Create " + class_name)
        if files:
            spot = None if rt.AlecCreate_composes(class_name) else mouse_spot(cursor)
            rt.AlecCreate_addBitmaps(class_name, files, spot)
            if class_name == UBER and spot is not None:
                hide_maps_at(cursor)

    # the popup closes first, so what the button does runs with nothing of it left. Over the editor the right click menu makes a
    # placeholder node at the mouse (smeCursor, with undo off) and the node is made at its position, as one undo step. What takes the
    # selected nodes goes next to them instead, and when the menu does not
    # work the node is put next to the selection
    def add(self, kind, class_name):
        in_sme, cursor = self.in_sme, self.cursor
        self.close()
        if not in_sme or rt.AlecCreate_composes(class_name):
            rt.AlecCreate_add(kind, class_name, in_sme)
            return
        before, placed = make_placeholder(cursor)
        if not (placed and rt.AlecCreate_replacePlaceholder(before, kind, class_name)):
            rt.AlecCreate_add(kind, class_name, True)
            rt.displayTempPrompt("Create: the mouse was not on an empty spot of the view, the node is next to the selection", 4000)


def run():
    in_sme = over_sme()
    AlecTools_caddy.close_all()
    rt.fileIn(rt.AlecTools_path("tools/create.ms"))
    AlecTools_caddy.show(CreatePopup(in_sme))


run()
