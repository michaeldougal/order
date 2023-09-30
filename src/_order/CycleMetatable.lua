local CycleMetatable

local function warning(self, message: string)
	warn("Detected bare code referencing a cyclic dependency ("
		.. tostring(CycleMetatable.CurrentModuleLoading) .. " -> "
		.. tostring(self.Name)
		.. ").",
		message,
		debug.traceback(1))
end

CycleMetatable = {
	__index = function(self, key)
		warning(self, "Attempt to read key '" .. key .. "'. Please revise.")
	end,
	__newindex = function(self, key, value)
		warning(self, "Attempt to set key '" .. key .. "' to " .. tostring(value) .. ". Please revise.")
	end,
	__call = function(self, ...)
		warning(self, "Attempt to call module. Please revise.")
	end,
	__concat = function(self, other)
		warning(self, "Attempt to concatenate module with " .. tostring(other) .. ". Please revise.")
	end,
	__unm = function(self)
		warning(self, "Attempt to use unary operator on module. Please revise.")
	end,
	__add = function(self, other)
		warning(self, "Attempt to add module with " .. tostring(other) .. ". Please revise.")
	end,
	__sub = function(self, other)
		warning(self, "Attempt to subtract module with " .. tostring(other) .. ". Please revise.")
	end,
	__mul = function(self, other)
		warning(self, "Attempt to multiply module with " .. tostring(other) .. ". Please revise.")
	end,
	__div = function(self, other)
		warning(self, "Attempt to divide module with " .. tostring(other) .. ". Please revise.")
	end,
	__mod = function(self, other)
		warning(self, "Attempt to modulo module with " .. tostring(other) .. ". Please revise.")
	end,
	__pow = function(self, other)
		warning(self, "Attempt to raise module to power of " .. tostring(other) .. ". Please revise.")
	end,
	__tostring = function(self)
		warning(self, "Attempt to convert module to string. Please revise.")
	end,
	__eq = function(self, other)
		warning(self, "Attempt to compare module with " .. tostring(other) .. ". Please revise.")
	end,
	__lt = function(self, other)
		warning(self, "Attempt to compare module with " .. tostring(other) .. ". Please revise.")
	end,
	__le = function(self, other)
		warning(self, "Attempt to compare module with " .. tostring(other) .. ". Please revise.")
	end,
	__len = function(self)
		warning(self, "Attempt to get length of module. Please revise.")
	end,

	CurrentModuleLoading = "Unknown",
}

return CycleMetatable
