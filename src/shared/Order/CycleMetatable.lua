return {
	__index = function(self, key)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to read key '" .. key .. "'. Please revise.", debug.traceback(1))
	end,
	__newindex = function(self, key, value)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to set key '" .. key .. "' to " .. tostring(value) .. ". Please revise.", debug.traceback(1))
	end,
	__call = function(self, ...)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to call module. Please revise.", debug.traceback(1))
	end,
	__concat = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to concatenate module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__unm = function(self)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to use unary operator on module. Please revise.", debug.traceback(1))
	end,
	__add = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to add module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__sub = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to subtract module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__mul = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to multiply module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__div = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to divide module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__mod = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to modulo module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__pow = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to raise module to power of " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__tostring = function(self)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to convert module to string. Please revise.", debug.traceback(1))
	end,
	__eq = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to compare module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__lt = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to compare module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__le = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to compare module with " .. tostring(other) .. ". Please revise.", debug.traceback(1))
	end,
	__len = function(self)
		warn("Detected bare code referencing a cyclic dependency (" .. tostring(shared._OrderCurrentModuleLoading) .. " -> " .. tostring(self.Name) .. "). Attempt to get length of module. Please revise.", debug.traceback(1))
	end
}