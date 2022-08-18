local Set = {}
Set.__index = Set

export type Set = {
	add: (self: Set, item: any) -> (),
	remove: (self: Set, item: any) -> (),
	contains: (self: Set, item: any) -> boolean,
	output: (self: Set) -> (),
	getIntersectionWith: (self: Set, otherSet: Set) -> Set,
	__add: (self: Set, otherSet: Set) -> Set,
	__sub: (self: Set, otherSet: Set) -> Set,
}

-- Function to construct a set from an optional list of items
function Set.new(items: {any}?): Set
	local newSet = {}
	for _, value: any in ipairs(items or {}) do
		newSet[value] = true
	end
	return setmetatable(newSet, Set)
end

-- Function to add an item to a set
function Set:add(item: any)
	self[item] = true
end

-- Function to remove an item from a set
function Set:remove(item: any)
	self[item] = nil
end

-- Function to check if a set contains an item
function Set:contains(item: any)
	return self[item] == true
end

-- Function to output set as a comma-delimited list for debugging
function Set:output()
	local elems = {}
	for key: any in pairs(self) do
		table.insert(elems, tostring(key))
	end
	print(table.concat(elems, ", "))
end

function Set:getIntersectionWith(otherSet: Set): Set
	local result = Set.new()
	for key: any in pairs(self) do
		if otherSet:contains(key) then
			result:add(key)
		end
	end
	return result
end

function Set:__add(otherSet)
	local result = Set.new()
	for entry: any in pairs(self) do
		result[entry] = true
	end
	for entry: any in pairs(otherSet) do
		result[entry] = true
	end
	return result
end

function Set:__sub(otherSet)
	local result = Set.new()
	for entry: any in pairs(self) do
		result[entry] = true
	end
	for entry: any in pairs(otherSet) do
		result[entry] = nil
	end
	return result
end

return Set
