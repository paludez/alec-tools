-- Check for the Create popup: can the SME's pan and zoom be measured from screenshots of its graph widget? Prints facts only.
-- Makes a temporary Slate view "AlecCalCheck" with two nodes and deletes it at the end. Leave the SME visible and docked as you use it.

global AlecCal_view

fn AlecCal_add x y =
(
	AlecCal_view.CreateNode (VRayMtl()) [x, y]
)

(
	if not sme.isOpen() do sme.Open()
	local old = sme.GetViewByName "AlecCalCheck"
	if old != 0 do sme.DeleteView old false
	local index = sme.CreateView "AlecCalCheck"
	sme.activeView = index
	AlecCal_view = sme.GetView index
	python.ExecuteFile ((getFilenamePath (getSourceFileName())) + "smeCalibrate_check.py")
	sme.DeleteView index false
)
