-- Test for tools/smartVisibility.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\smartVisibility_test.ms"
-- Creates temporary objects, checks hide / unhide at object level and at sub-object level on
-- Editable Poly, Edit Poly, Editable Mesh, Edit Mesh, Line and Edit Spline, then deletes them. Prints PASS/FAIL lines to the Listener.
-- Max has no query for hidden spline knots or Edit Poly sub-objects, so for those only "runs without error" is checked.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/smartVisibility.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	-- hidden vertices of a mesh, or of the mesh an Edit Mesh modifier produces
	fn hiddenVerts node =
	(
		local m = snapshotAsMesh node
		local hidden = meshop.getHiddenVerts m
		delete m
		hidden
	)

	-- runs the operations in order and passes if none of them throws
	fn runs label ops =
	(
		local ok = true
		try (for op in ops do AlecSmartVis_execute op)
		catch
		(
			format "%\n" (getCurrentException())
			ok = false
		)
		check label ok
	)

	-- object level
	local a = box name:"ATtest_A"
	local b = box name:"ATtest_B" pos:[100,0,0]
	subObjectLevel = 0
	select a
	AlecSmartVis_execute #hide
	if not (check "object level: #hide hides the selection" a.isHidden) do failures += 1
	if not (check "object level: #hide leaves the other object" (not b.isHidden)) do failures += 1
	AlecSmartVis_execute #unhideAll
	if not (check "object level: #unhideAll unhides" (not a.isHidden)) do failures += 1
	select a
	AlecSmartVis_execute #hideUnselected
	if not (check "object level: #hideUnselected hides the others" b.isHidden) do failures += 1
	if not (check "object level: #hideUnselected keeps the selection" (not a.isHidden)) do failures += 1
	AlecSmartVis_execute #unhideAll
	delete a
	delete b

	-- sub-object level needs the modify panel
	max modify mode

	-- Editable Poly, face level
	local p = convertToPoly (box name:"ATtest_P")
	select p
	subObjectLevel = 4
	p.EditablePoly.SetSelection #Face #{1}
	AlecSmartVis_execute #hide
	if not (check "Editable Poly: #hide hides the selected face" ((polyop.getHiddenFaces p) == #{1})) do failures += 1
	AlecSmartVis_execute #unhideAll
	if not (check "Editable Poly: #unhideAll shows all faces" ((polyop.getHiddenFaces p).numberSet == 0)) do failures += 1
	p.EditablePoly.SetSelection #Face #{1}
	AlecSmartVis_execute #hideUnselected
	if not (check "Editable Poly: #hideUnselected hides the other faces" ((polyop.getHiddenFaces p).numberSet == 5)) do failures += 1
	subObjectLevel = 0
	delete p

	-- Edit Poly modifier, vertex and face level
	local ep = box name:"ATtest_EP"
	addModifier ep (Edit_Poly())
	select ep
	for level in #(1, 4) do
	(
		subObjectLevel = level
		ep.modifiers[1].SetSelection (if level == 1 then #Vertex else #Face) #{1}
		if not (runs ("Edit Poly level " + level as string + ": hide, unhide, hide unselected run") #(#hide, #unhideAll, #hideUnselected, #unhideAll)) do failures += 1
	)
	subObjectLevel = 2
	if not (check "Edit Poly edge level is left alone" (not ep.isHidden)) do failures += 1
	subObjectLevel = 0
	delete ep

	-- Editable Mesh, vertex level
	local m = convertToMesh (box name:"ATtest_M")
	select m
	subObjectLevel = 1
	setVertSelection m #{1,2}
	AlecSmartVis_execute #hide
	if not (check "Editable Mesh: #hide hides the selected vertices" ((hiddenVerts m) == #{1,2})) do failures += 1
	AlecSmartVis_execute #unhideAll
	if not (check "Editable Mesh: #unhideAll shows all vertices" ((hiddenVerts m).numberSet == 0)) do failures += 1
	setVertSelection m #{1,2}
	AlecSmartVis_execute #hideUnselected
	if not (check "Editable Mesh: #hideUnselected hides the other vertices" ((hiddenVerts m).numberSet == 6)) do failures += 1
	subObjectLevel = 0
	delete m

	-- Edit Mesh modifier, vertex level: select all hides all, nothing selected makes hide unselected hide all
	local em = box name:"ATtest_EM"
	addModifier em (Edit_Mesh())
	select em
	subObjectLevel = 1
	max select all
	AlecSmartVis_execute #hide
	if not (check "Edit Mesh: #hide hides the selected vertices" ((hiddenVerts em).numberSet == 8)) do failures += 1
	AlecSmartVis_execute #unhideAll
	if not (check "Edit Mesh: #unhideAll shows all vertices" ((hiddenVerts em).numberSet == 0)) do failures += 1
	max select none
	AlecSmartVis_execute #hideUnselected
	if not (check "Edit Mesh: #hideUnselected hides the unselected vertices" ((hiddenVerts em).numberSet == 8)) do failures += 1
	AlecSmartVis_execute #unhideAll
	subObjectLevel = 0
	delete em

	-- Line, knot level
	local ln = convertToSplineShape (circle name:"ATtest_L")
	select ln
	subObjectLevel = 1
	setKnotSelection ln 1 #(1,2)
	if not (runs "Line: hide, unhide, hide unselected run at knot level" #(#hide, #unhideAll, #hideUnselected, #unhideAll)) do failures += 1
	subObjectLevel = 0
	delete ln

	-- Edit Spline modifier, knot level
	local es = circle name:"ATtest_ES"
	addModifier es (Edit_Spline())
	select es
	subObjectLevel = 1
	max select all
	if not (runs "Edit Spline: hide, unhide, hide unselected run at knot level" #(#hide, #unhideAll, #hideUnselected, #unhideAll)) do failures += 1
	subObjectLevel = 0
	delete es

	-- not supported: an Editable Patch is left alone at sub-object level
	local pt = convertTo (box name:"ATtest_PT") Editable_Patch
	select pt
	subObjectLevel = 1
	AlecSmartVis_execute #hide
	if not (check "unsupported object type is not hidden" (not pt.isHidden)) do failures += 1
	subObjectLevel = 0
	delete pt

	format "smartVisibility_test: % failure(s)\n" failures
)
