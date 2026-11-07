"""Creates the Alec Tools toolbar (AlecTools_load, at every start and reload); the code is in AlecToolbar.py. The editor module is
reloaded here too, so a Reload picks up its changes before anything imports it."""

import importlib

import AlecToolbar
import AlecToolbarEditor

importlib.reload(AlecToolbar)
importlib.reload(AlecToolbarEditor)
AlecToolbar.create()
