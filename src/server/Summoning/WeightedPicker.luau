--!strict
-- ServerScriptService/Summoning/WeightedPicker.luau
local WeightedPicker = {}

-- Picks one entry from a list, given a function that returns each entry's weight.
-- Generic: works on units, loot, anything.
function WeightedPicker.Pick<T>(
	entries: { T },
	getWeight: (T) -> number,
	rng: Random
): T?
	local total = 0
	for _, entry in entries do
		total += getWeight(entry)
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber() * total
	local cursor = 0
	for _, entry in entries do
		cursor += getWeight(entry)
		if roll <= cursor then
			return entry
		end
	end
	return entries[#entries] -- float-safety fallback
end

return WeightedPicker