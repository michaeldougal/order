---@author ChiefWildin

--[[

	order.

	A lightweight module loading framework for Roblox.
	Documentation - https://michaeldougal.github.io/order/

]]--


-- Configuration


local Order = {
	_VERSION = "0.4.0",
	DebugMode = false, -- Verbose loading in the output window
	SilentMode = not game:GetService("RunService"):IsStudio() -- Disables regular output
}

if Order.SilentMode then Order.DebugMode = false end -- Override debug mode if silent mode is active


-- Output formatting


local standardPrint = print
function print(...)
	standardPrint("[Order]", ...)
end

local standardWarn = warn
function warn(...)
	standardWarn("[Order]", ...)
end


-- Initialization


if not Order.SilentMode then
	print("Framework initializing...")
	print("Version:", Order._VERSION)
end

local Modules = {}
local LoadedModules = {}
local ModulesLoading = {}
local Tasks = {}
local TotalModules = 0

local CYCLE_METATABLE = require(script:WaitForChild("CycleMetatable"))


-- Private functions


-- Adds a metatable to a temporary module table to let access operations fall
-- through to the original module table.
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

-- Loads the given ModuleScript with error handling. Returns the loaded data.
local function load(module: ModuleScript): any?
	local moduleData
	shared._OrderCurrentModuleLoading = module.Name
	local loadSuccess, loadMessage = pcall(function()
		moduleData = require(module)
	end)
	local renameSuccess, renameMessage = pcall(function()
		if typeof(moduleData) == "table" then
			moduleData._OrderNameInternal = module.Name
		end
	end)
	if not loadSuccess then
		warn("Failed to load module", module.Name, "-", loadMessage)
	end
	if not renameSuccess then
		warn("Failed to add internal name to module", module.Name, "-", renameMessage)
	end
	shared._OrderCurrentModuleLoading = nil
	return moduleData
end

-- Returns a table of all of the provided Instance's ancestors in ascending
-- order
local function getAncestors(descendant: Instance): {Instance}
	local ancestors = {}
	local current = descendant.Parent
	while current do
		table.insert(ancestors, current)
		current = current.Parent
	end
	return ancestors
end

-- Adds all available aliases for a ModuleScript to the internal index registry
local function indexNames(child: ModuleScript)
	local function indexName(index: string)
		if Modules[index] then
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


-- Public functions


-- Metatable override to load modules through the shared global table when
-- calling the table as a function.
function Order.__call(_: {}, module: string | ModuleScript): {}
	if Order.DebugMode then
		print("\tRequest to load", module)
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
					print("\tLoaded", module)
				end
			end
		else
			if not Modules[module] then
				local trace = debug.traceback()
				local trim = string.sub(trace,  string.find(trace, "__call") + 7, string.len(trace) - 1)
				warn(trim .. ": Attempt to require unknown module '" .. module .. "'")
				return
			end
			local fakeModule = {
				IsFakeModule = true,
				Name = module
			}
			setmetatable(fakeModule, CYCLE_METATABLE)
			LoadedModules[module] = fakeModule
			if Order.DebugMode then
				print("\tSet", module, "to fake module")
			end
		end
	end

	return LoadedModules[module]
end

-- Indexes any ModuleScript children of the specified Instance
function Order.IndexModulesOf(location: Instance)
	if Order.DebugMode then
		print("Indexing modules -", location:GetFullName())
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
		print("\tDiscovered", discovered, if discovered == 1 then "module" else "modules")
	end
end

-- Asynchronously loads all ModuleScript children of the specified task Folder,
-- and queues them for initialization. Recursively loads all children of any
-- discovered Folders as well.
function Order.LoadTasks(location: Folder)
	if Order.DebugMode then
		print("Loading tasks -", location:GetFullName())
	end
	local tasksLoading = 0
	for _: number, child: ModuleScript | Folder in ipairs(location:GetChildren()) do
		if child:IsA("ModuleScript") then
			tasksLoading += 1
			task.spawn(function()
				table.insert(Tasks, shared(child.Name))
				tasksLoading -= 1
			end)
		elseif child:IsA("Folder") then
			Order.LoadTasks(child)
		end
	end
	while tasksLoading > 0 do task.wait() end
end

-- Initializes all currently loaded tasks. Clears the task initialization queue
-- after all tasks have been initialized.
function Order.InitializeTasks()
	if not Order.SilentMode then
		print("Initializing tasks...")
	end

	table.sort(Tasks, function(a, b)
		local aPriority = a.Priority or 0
		local bPriority = b.Priority or 0
		return aPriority > bPriority
	end)

	if Order.DebugMode then
		print("\tCurrent initialization order:")
		for index: number, moduleData: {} in pairs(Tasks) do
			print("\t\t" .. index .. ')', moduleData._OrderNameInternal)
		end
	end

	local tasksInitializing = 0
	for _: number, moduleData: {} in pairs(Tasks) do
		if moduleData.Init then
			tasksInitializing += 1
			task.spawn(function()
				local success, message = pcall(function()
					moduleData:Init()
				end)
				if not success then
					warn("Failed to initialize module", moduleData._OrderNameInternal, "-", message)
				elseif Order.DebugMode then
					print("\tInitialized", moduleData._OrderNameInternal)
				end
				tasksInitializing -= 1
			end)
		end
	end

	while tasksInitializing > 0 do task.wait() end

	table.clear(Tasks)

	if not Order.SilentMode then
		print("All tasks initialized.")
	end
end


-- Finalization


setmetatable(shared, Order)

if not Order.SilentMode then
	print("Framework initialized.")
end

return Order
