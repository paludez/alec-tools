-- Test for tools/smartVisibility.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\smartVisibility_test.ms"
-- Creates temporary objects, checks hide / unhide, deletes them. Prints PASS/FAIL lines to the Listener.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/smartVisibility.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	local a = box name:"ATtest_A"
	local b = box name:"ATtest_B" pos:[100,0,0]

	-- object level: hide selected
	subObjectLevel = 0
	select a
	AlecSmartVis_execute #hide
	if not (check "object level: #hide hides the selection" a.isHidden) do failures += 1
	if not (check "object level: #hide leaves the other object" (not b.isHidden)) do failures += 1

	-- object level: unhide all
	AlecSmartVis_execute #unhideAll
	if not (check "object level: #unhideAll unhides" (not a.isHidden)) do failures += 1

	-- object level: hide unselected
	select a
	AlecSmartVis_execute #hideUnselected
	if not (check "object level: #hideUnselected hides the others" b.isHidden) do failures += 1
	if not (check "object level: #hideUnselected keeps the selection" (not a.isHidden)) do failures += 1
	AlecSmartVis_execute #unhideAll

	-- shared helpers
	-- == on arrays compares references, so compare a BitArray by value and an array element by element
	if not (check "AlecTools_bits from array" ((AlecTools_bits #(1,3)) == #{1,3})) do failures += 1
	local idxs = AlecTools_indices #{2,5}
	if not (check "AlecTools_indices from BitArray" (idxs.count == 2 and idxs[1] == 2 and idxs[2] == 5)) do failures += 1

	delete a
	delete b
	format "smartVisibility_test: % failure(s)\n" failures
)
