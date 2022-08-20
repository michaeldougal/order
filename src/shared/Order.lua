---@author ChiefWildin

local standardPrint = print
function print(...)
	standardPrint("[Order]", ...)
end

local standardWarn = warn
function warn(...)
	standardWarn("[Order]", ...)
end

local Order = {
	_VERSION = "0.3.2",
	DebugMode = false, -- Verbose loading in the output window
	SilentMode = false -- Disables regular output
}

if Order.SilentMode then Order.DebugMode = false end -- Override debug mode if silent mode active

if not Order.SilentMode then
	print("Framework initializing...")
	print("Version: " .. Order._VERSION)
end

local Modules = {}
local LoadedModules = {}
local ModulesLoading = {}
local Tasks = {}
local TotalModules = 0
local CurrentModuleLoading = "Unknown"

local FAKE_MODULE_METATABLE = {
	__index = function(self, key)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to read key '" .. key .. "'. Please revise.")
		return nil
	end,
	__newindex = function(self, key, value)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to set key '" .. key .. "' to " .. tostring(value) .. ". Please revise.")
		return nil
	end,
	__call = function(self, ...)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to call module. Please revise.")
		return nil
	end,
	__concat = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to concatenate module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__unm = function(self)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to use unary operator on module. Please revise.")
		return nil
	end,
	__add = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to add module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__sub = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to subtract module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__mul = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to multiply module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__div = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to divide module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__mod = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to modulo module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__pow = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to raise module to power of " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__tostring = function(self)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to convert module to string. Please revise.")
		return nil
	end,
	__eq = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to compare module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__lt = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to compare module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__le = function(self, other)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to compare module with " .. tostring(other) .. ". Please revise.")
		return nil
	end,
	__len = function(self)
		warn("Detected bare code referencing a cyclic dependency (" .. CurrentModuleLoading .. " -> " .. tostring(self.Name) .. "). Attempt to get length of module. Please revise.")
		return nil
	end
}

local function replaceTempModule(moduleName: string, moduleData: any)
	LoadedModules[moduleName].IsFakeModule = nil
	if typeof(moduleData) == "table" then
		setmetatable(LoadedModules[moduleName], {
			__index = function(_, requestedKey)
				return moduleData[requestedKey]
			end,
			__newindex = function(_, requestedKey, requestedValue)
				moduleData[requestedKey] = requestedValue
			end,
			__tostring = function(_)
				local result = "\nModule " .. moduleName .. ":\n"
				for key, value in pairs(moduleData) do
					result = result .. "\t" .. tostring(key) .. ": " .. tostring(value) .. "\n"
				end
				return result
			end
		})
	else
		LoadedModules[moduleName] = moduleData
	end
end

local function load(module: ModuleScript): any?
	local moduleData
	CurrentModuleLoading = module.Name
	local success, message = pcall(function()
		moduleData = require(module)
		moduleData.Name = module.Name
	end)
	if not success then
		warn("Failed to load module", module.Name, "-", message)
	end
	CurrentModuleLoading = "Unknown"
	return moduleData
end

local function getAncestors(descendant: Instance): {Instance}
	local ancestors = {}
	local current = descendant.Parent
	while current do
		table.insert(ancestors, current)
		current = current.Parent
	end
	return ancestors
end

local function indexNames(child: ModuleScript)
	local function indexName(index: string)
		if Modules[index] then
			if Order.DebugMode then
				warn("Duplicate module names found:", child, Modules[index])
			end
			local existing = Modules[index]
			if typeof(existing) == "table" then
				table.insert(existing, child)
			else
				Modules[index] = {existing, child}
			end
		else
			Modules[index] = child
		end
	end
	indexName(child.Name)
	local ancestors = getAncestors(child)
	local currentIndex = child.Name
	for _: number, ancestor: Instance in pairs(ancestors) do
		currentIndex = ancestor.Name .. "/" .. currentIndex
		indexName(currentIndex)
		if ancestor.Name == "ServerScriptService" or ancestor.Name == "PlayerScripts" or ancestor.Name == "Common" then
			break
		end
	end
end

function Order.__call(_: {}, module: string | ModuleScript): {}
	if Order.DebugMode then
		print("Request to load", module)
	end

	if typeof(module) == "Instance" then
		return load(module)
	end

	if not LoadedModules[module] then
		if Modules[module] and not ModulesLoading[module] then
			if typeof(Modules[module]) == "table" then
				local trace = debug.traceback()
				local trim = string.sub(trace,  string.find(trace, "__call") + 7, string.len(trace) - 1)
				local warning = trim .. ": Multiple modules found for '" .. module .. "' - please be more specific:\n"
				local numDuplicates = #Modules[module]
				for index, duplicate in ipairs(Modules[module]) do
					local formattedName = string.gsub(duplicate:GetFullName(), "[.]", '/')
					warning ..= "\t- " .. formattedName .. if index ~= numDuplicates then "\n" else ""
				end
				warn(warning)
				return
			end
			ModulesLoading[module] = true
			local moduleData = load(Modules[module])
			if LoadedModules[module] then -- Found temporary placeholder due to cyclic dependency
				replaceTempModule(module, moduleData)
			else
				LoadedModules[module] = moduleData
				if Order.DebugMode then
					print("Loaded", module)
				end
			end
		else
			if not Modules[module] then
				warn("Tried to require unknown module '" .. module .. "'")
				return
			end
			local fakeModule = {
				IsFakeModule = true,
				Name = module
			}
			setmetatable(fakeModule, FAKE_MODULE_METATABLE)
			LoadedModules[module] = fakeModule
			if Order.DebugMode then
				print("Set", module, "to fake module")
			end
		end
	end

	return LoadedModules[module]
end

function Order.IndexModulesOf(location: Instance)
	if Order.DebugMode then
		print("Locating modules in", location:GetFullName())
	end
	local discovered = 0
	for _: number, child: Instance in ipairs(location:GetDescendants()) do
		if child:IsA("ModuleScript") and child ~= script then
			discovered += 1
			TotalModules += 1
			indexNames(child)
		end
	end
	if Order.DebugMode and discovered > 0 then
		print("Discovered", discovered, if discovered == 1 then "module" else "modules", "in", location:GetFullName())
	end
end

function Order.LoadTasks(location: Folder)
	for _: number, child: ModuleScript | Folder in ipairs(location:GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(Tasks, shared(child.Name))
		elseif child:IsA("Folder") then
			Order.LoadTasks(child)
		end
	end
end

function Order.InitializeTasks()
	table.sort(Tasks, function(a, b)
		local aPriority = a.Priority or 0
		local bPriority = b.Priority or 0
		return aPriority > bPriority
	end)

	if Order.DebugMode then
		print("Initializing tasks. Current order:")
		for index: number, moduleData: {} in pairs(Tasks) do
			print("    " .. index .. ')', moduleData.Name)
		end
	elseif not Order.SilentMode then
		print("Initializing tasks...")
	end

	local tasksInitializing = 0
	for _: number, module: any in pairs(LoadedModules) do
		if typeof(module) == "table" and module.Init then
			tasksInitializing += 1
			task.spawn(function()
				local success, message = pcall(function()
					module:Init()
				end)
				if not success then
					warn("Failed to initialize module", module.Name, "-", message)
				elseif Order.DebugMode then
					print("Initialized", module.Name)
				end
				tasksInitializing -= 1
			end)
		end
	end

	while tasksInitializing > 0 do task.wait() end

	if not Order.SilentMode then
		print("All tasks initialized.")
	end
end

setmetatable(shared, Order)

if not Order.SilentMode then
	print("Framework initialized.")
end

return Order
