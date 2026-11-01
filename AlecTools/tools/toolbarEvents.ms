-- What tells the Alec Tools toolbar (AlecToolbar.py) to refresh its checked buttons and fields: Max's own node events (selection,
-- transform, geometry) and a unit change. No Qt timer: MAXScript run from a Qt timer crashed Max while Esc was held in a viewport,
-- and node events run from Max. Use Center has no event; the toolbar also refreshes when the mouse enters it.

global AlecToolbar_events = undefined

fn AlecToolbar_refresh = python.Execute "import AlecToolbar\nAlecToolbar.refresh_all()"

-- a node event callback takes the event name and the anim handles
fn AlecToolbar_onEvent ev handles = AlecToolbar_refresh()

fn AlecToolbar_unwatch =
(
	callbacks.removeScripts id:#AlecToolbar
	AlecToolbar_events = undefined
	gc light:true
)

-- delay: one refresh once the events stop, not one per step of a drag
fn AlecToolbar_watch =
(
	AlecToolbar_unwatch()
	AlecToolbar_events = NodeEventCallback delay:100 selectionChanged:AlecToolbar_onEvent controllerOtherEvent:AlecToolbar_onEvent geometryChanged:AlecToolbar_onEvent
	for ev in #(#unitsChange, #filePostOpen, #systemPostReset, #systemPostNew) do
		callbacks.addScript ev "AlecToolbar_refresh()" id:#AlecToolbar
)
