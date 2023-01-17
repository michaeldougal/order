---@author ChiefWildin

--[[

	order.

	A lightweight module loading framework for Roblox.
	Documentation - https://michaeldougal.github.io/order/

]]--

-- Configuration

local Order = {
	_VERSION = "1.0.0",
	-- Verbose loading in the output window
	DebugMode = false,
	-- Disables regular output (does not disable warnings)
	SilentMode = not game:GetService("RunService"):IsStudio(),
	-- If true, runs all init functions unprotected. Can be useful to debug init
	-- functions, as this will cause any errors to give a complete stack trace.
	UnprotectedInit = false,
	-- Forces all task initializers to run synchronously. This is useful when
	-- you need to guarantee initialization order for the whole project, but it
	-- is slower if you have any yielding in your tasks.
	ForceSyncInit = true,
	-- If a task is initializing for longer than this amount of seconds, Order
	-- will warn you that you have a slow module
	SlowInitWarnTime = 5,
}

-- Override debug mode if silent mode is active
if Order.SilentMode then Order.DebugMode = false end

-- The metatable that provides functionality for detecting bare code referencing
-- cyclic dependencies
local CYCLE_METATABLE = require(script:WaitForChild("CycleMetatable"))

-- Output formatting

local standardPrint = print
local function print(...)
	standardPrint("[Order]", ...)
end

local standardWarn = warn
local function warn(...)
	standardWarn("[Order]", ...)
end

-- Initialization

if not Order.SilentMode then
	print("Framework initializing...")
	print("Version:", Order._VERSION)
end

-- A dictionary of known module aliases and the ModuleScripts they point to
local Modules: {[string]: ModuleScript} = {}
-- A dictionary of loaded ModuleScripts and the values they returned
local LoadedModules: {[ModuleScript]: any} = {}
-- The set of all currently loading modules
local ModulesLoading: {[ModuleScript]: boolean} = {}
-- An array that contains all currently loaded task module data
local Tasks: {any} = {}
-- The total number of discovered (but not necessarily loaded) modules
local TotalModules = 0
-- The current number of ancestry levels that have been indexed
local AncestorLevelsExpanded = 0

-- Private functions

-- Adds a metatable to a temporary module table to let access operations fall
-- through to the original module table.
local function replaceTempModule(moduleName: string, moduleData: any)
	LoadedModules[Modules[moduleName]].IsFakeModule = nil
	if typeof(moduleData) == "table" then
		-- print("Linking", moduleName)
		setmetatable(LoadedModules[Modules[moduleName]], {
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
		LoadedModules[Modules[moduleName]] = moduleData
	end
end

-- Loads the given ModuleScript with error handling. Returns the loaded data.
local function load(module: ModuleScript): any?
	local moduleData: any?

	shared._OrderCurrentModuleLoading = module.Name

	local loadSuccess, loadMessage = pcall(function()
		moduleData = require(module)
	end)
	if not loadSuccess then
		warn("Failed to load module", module.Name, "-", loadMessage)
	end

	-- This part has to be done in pcall because sometimes developers set their
	-- modules to be read-only
	local renameSuccess, renameMessage = pcall(function()
		if typeof(moduleData) == "table" then
			moduleData._OrderNameInternal = module.Name
		end
	end)
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

-- Adds all available aliases for a ModuleScript to the internal index registry,
-- up to the specified number of ancestors (0 refers to the script itself,
-- indexes all ancestors if no cap specified)
local function indexNames(child: ModuleScript, levelCap: number?)
	-- TODO: Figure out why tables are sometimes getting passed in here
	if typeof(child) ~= "Instance" then return end

	if Order.DebugMode then
		print("Indexing names for", child.Name, "up to", levelCap or "all levels")
	end

	local function indexName(index: string)
		if Modules[index] and Modules[index] ~= child then
			local existing = Modules[index]
			if typeof(existing) == "table" and not table.find(existing, child) then
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
	for level: number, ancestor: Instance in pairs(ancestors) do
		if levelCap and level > levelCap then break end

		currentIndex = ancestor.Name .. "/" .. currentIndex
		indexName(currentIndex)

		if ancestor.Name == "ServerScriptService" or ancestor.Name == "PlayerScripts" or ancestor.Name == "Common" then
			break
		end
	end
end

local function expandNameIndex(levelCap: number)
	if levelCap <= AncestorLevelsExpanded then return end

	if Order.DebugMode then
		print("Expanding ancestry name index to level", levelCap)
	end

	for _, moduleData in pairs(Modules) do
		if typeof(moduleData) == "table" then
			for _, module in pairs(moduleData) do
				indexNames(module, levelCap)
			end
		elseif typeof(moduleData) == "Instance" then
			indexNames(moduleData, levelCap)
		end
	end

	AncestorLevelsExpanded = levelCap
end

-- Public functions

-- Metatable override to load modules when calling the Order table as a
-- function.
function Order.__call(_: {}, module: string | ModuleScript): any?
	if Order.DebugMode then
		print("\tRequest to load", module)
	end

	if typeof(module) == "Instance" then
		return load(module)
	end

	if Modules[module] and LoadedModules[Modules[module]] then
		return LoadedModules[Modules[module]]
	end

	if Modules[module] and not ModulesLoading[Modules[module]] then
		if typeof(Modules[module]) == "table" then
			local trace = debug.traceback()
			local trim = string.sub(trace,  string.find(trace, "__call") + 7, string.len(trace) - 1)
			local warning = trim .. ": Multiple modules found for '" .. module .. "' - please be more specific:\n"
			local numDuplicates = #Modules[module]

			for index, duplicate in ipairs(Modules[module]) do
				if typeof(duplicate) == "table" then continue end
				local formattedName = string.gsub(duplicate:GetFullName(), "[.]", '/')
				warning ..= "\t\t\t\t\t\t- " .. formattedName .. if index ~= numDuplicates then "\n" else ""
			end

			warn(warning)

			return
		end

		ModulesLoading[Modules[module]] = true
		local moduleData = load(Modules[module])

		if LoadedModules[Modules[module]] then
			-- Found temporary placeholder due to cyclic dependency
			replaceTempModule(module, moduleData)
		else
			LoadedModules[Modules[module]] = moduleData
			if Order.DebugMode then
				print("\tLoaded", module)
			end
		end

		ModulesLoading[Modules[module]] = nil
	else
		if not Modules[module] then
			if Order.DebugMode then
				print("Cache miss for", module)
			end

			local _, ancestorLevels = string.gsub(module, "/", "")
			if ancestorLevels > AncestorLevelsExpanded then
				-- Expand the number of name aliases for known modules to
				-- include number of levels potentially referenced and retry
				expandNameIndex(ancestorLevels)
				return Order:__call(module)
			else
				-- Ancestor index expansion has already reached all possibly
				-- referenced levels, so we just don't know where the module is
				local trace = debug.traceback()
				local trim = string.sub(trace,  string.find(trace, "__call") + 7, string.len(trace) - 1)
				warn(trim .. ": Attempt to require unknown module '" .. module .. "'")
				return
			end
		end

		local fakeModule = {
			IsFakeModule = true,
			Name = module
		}
		setmetatable(fakeModule, CYCLE_METATABLE)
		LoadedModules[Modules[module]] = fakeModule

		if Order.DebugMode then
			print("\tSet", module, "to fake module")
		end
	end

	return LoadedModules[Modules[module]]
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
			indexNames(child, 0)
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
				-- Tasks might have duplicates, so we find its shortest unique
				-- path name
				local taskName = child.Name
				local nextParent = child.Parent

				while Modules[taskName] and typeof(Modules[taskName]) == "table" do
					taskName = nextParent.Name .. "/" .. taskName
					nextParent = nextParent.Parent
				end

				local taskData = Order:__call(taskName)
				if taskData then
					table.insert(Tasks, taskData)
				else
					warn("Task", child, "failed to load")
				end
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

	local function initialize(moduleData)
		if not moduleData._OrderInitialized then
			moduleData._OrderInitialized = true
		else
			return
		end

		local startTime = os.clock()
		local finished = not (Order.ForceSyncInit or moduleData.SyncInit)
		task.spawn(function()
			while not finished do
				task.wait()
				if os.clock() - startTime > Order.SlowInitWarnTime then
					warn("Slow module detected -", moduleData._OrderNameInternal, "has been initializing for more than",
						Order.SlowInitWarnTime, "seconds")
					break
				end
			end
		end)

		local success, message
		if Order.UnprotectedInit then
			moduleData:Init()
			success = true
		else
			success, message = pcall(function()
				moduleData:Init()
			end)
		end

		finished = true

		if not success then
			warn("Failed to initialize module", moduleData._OrderNameInternal, "-", message)
		elseif Order.DebugMode then
			print("\tInitialized", moduleData._OrderNameInternal)
		end
	end

	local tasksInitializing = 0
	for _: number, moduleData: {} in pairs(Tasks) do
		if moduleData.Init then
			tasksInitializing += 1
			if Order.ForceSyncInit or moduleData.SyncInit then
				initialize(moduleData)
				tasksInitializing -= 1
			else
				task.spawn(function()
					initialize(moduleData)
					tasksInitializing -= 1
				end)
			end
		end
	end

	while tasksInitializing > 0 do task.wait() end

	table.clear(Tasks)

	if not Order.SilentMode then
		print("All tasks initialized.")
	end
end

-- Keyword linking

-- Enables shared keyword to act as require
setmetatable(shared, Order)
-- Enables this module to act as require when required
setmetatable(Order, Order)

-- Auto initialization

do
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local SharedContext = ReplicatedStorage:WaitForChild("Common")
	local LocalContext
	if RunService:IsClient() then
		local LocalPlayer = game:GetService("Players").LocalPlayer
		if LocalPlayer then
			LocalContext = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
		else
			LocalContext = game:GetService("StarterPlayer").StarterPlayerScripts.Client
		end
	else
		LocalContext = game:GetService("ServerScriptService"):WaitForChild("Server")
	end

	Order.IndexModulesOf(LocalContext)
	Order.IndexModulesOf(SharedContext)

	Order.LoadTasks(LocalContext:WaitForChild("tasks"))
	Order.LoadTasks(SharedContext:WaitForChild("tasks"))

	Order.InitializeTasks()
end

if not Order.SilentMode then
	print("Framework initialized.")
end

shared._OrderInitialized = true

return Order
