-- Test for lib/nodes.ms: group members, parts, bounds and average of points. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\nodes_test.ms"
-- Creates and deletes its own objects (names start with ATtest_). Prints PASS/FAIL lines to the Listener.

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = distance a b < 0.001

	local pb = AlecTools_pointsBounds #([1, 5, -2], [3, -1, 4], [2, 2, 2])
	if not (check "pointsBounds: min and max per axis" (near pb[1] [1, -1, -2] and near pb[2] [3, 5, 4])) do failures += 1
	if not (check "average: of the points" (near (AlecTools_average #([0, 0, 0], [2, 4, 6])) [1, 2, 3])) do failures += 1

	local a = Box name:"ATtest_a" length:10 width:10 height:10 pos:[0, 0, 0]
	local b = Box name:"ATtest_b" length:10 width:10 height:10 pos:[100, 0, 0]
	local inner = group #(a, b) name:"ATtest_inner"
	local c = Sphere name:"ATtest_c" radius:5 pos:[0, 50, 0]
	local d = Dummy name:"ATtest_d" pos:[0, -50, 0]
	local outer = group #(inner, c, d) name:"ATtest_outer"

	local members = AlecTools_groupMembers outer
	if not (check "groupMembers: every member, nested heads too" (members.count == 5 and findItem members inner > 0 and findItem members a > 0 and findItem members d > 0)) do failures += 1
	local parts = AlecTools_parts outer
	if not (check "parts: only geometry and shapes of the group" (parts.count == 3 and findItem parts inner == 0 and findItem parts d == 0)) do failures += 1
	if not (check "parts: a plain node is itself" ((AlecTools_parts c).count == 1)) do failures += 1

	local bb = AlecTools_bounds #(a, b) (matrix3 1)
	if not (check "bounds: of two boxes in world" (near bb[1] [-5, -5, 0] and near bb[2] [105, 5, 10])) do failures += 1

	delete (for o in objects where matchPattern o.name pattern:"ATtest_*" collect o)
	format "nodes_test: % failure(s)\n" failures
)
