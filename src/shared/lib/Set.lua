local Set = {}
Set.__index = Set

-- Function to construct a set from an optional list of items
function Set.new(items)
	local newSet = {}
	for key, value in ipairs(items or {}) do
		newSet[value] = true
	end
	return setmetatable(newSet, Set)
end

-- Function to add an item to a set
function Set:add(item)
	self[item] = true
end

-- Function to remove an item from a set
function Set:remove(item)
	self[item] = nil
end

-- Function to check if a set contains an item
function Set:contains(item)
	return self[item] == true
end

-- Function to output set as a comma-delimited list for debugging
function Set:output()
	local elems = {}
	for key, value in pairs(self) do
		table.insert(elems, tostring(key))
	end
	print(table.concat(elems, ", "))
end

return Set
