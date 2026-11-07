"""Opens the toolbar editor (Edit Toolbar macro); the code is in AlecToolbarEditor.py."""

import importlib

import AlecToolbarEditor

importlib.reload(AlecToolbarEditor)
AlecToolbarEditor.open_editor()
