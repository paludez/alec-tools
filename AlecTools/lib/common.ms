-- Shared helpers for Alec Tools. Every lib/*.ms is loaded by AlecTools_load before the macros.

-- BitArray from a BitArray, an array of indices, or undefined
fn AlecTools_bits items =
(
	local bits = #{}
	if classOf items == BitArray then items
	else
	(
		if items != undefined do for i in items do bits[i] = true
		bits
	)
)

-- array of the set indices of a BitArray
fn AlecTools_indices bits =
(
	local idxs = #()
	for i in bits do append idxs i
	idxs
)
