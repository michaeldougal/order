--[[

	order.

	A configurable module-based framework for Roblox, written by @ChiefWildin.
	Full documentation - https://michaeldougal.github.io/order/

]]--

-- Setup

local Order = {
	Version = "2.1.1",
}

-- The metatable that provides functionality for detecting bare code referencing
-- cyclic dependencies
local CycleMetatable = require(script:WaitForChild("CycleMetatable")) ---@module CycleMetatable
-- The configuration for this instance of the framework
local Settings = require(script:WaitForChild("Settings")) ---@module Settings

type Initializer = Settings.Initializer

-- Override debug mode if silent mode is active
if Settings.SilentMode then Settings.DebugMode = false end

-- Output formatting

local standardPrint = print
local function print(...)
	standardPrint("[Order]", ...)
end
-- Debug print (print if debug mode is active)
local function dprint(...)
	if Settings.DebugMode then
		standardPrint("[Order] [Debug] ", ...)
	end
end
-- Verbose print (print if not on silent mode)
local function vprint(...)
	if not Settings.SilentMode then
		print(...)
	end
end

local standardWarn = warn
local function warn(...)
	standardWarn("[Order]", ...)
end

-- Initialization

vprint("Framework initializing...")
vprint("Version:", Order.Version)

-- The current number of ancestry levels that have been indexed
local AncestorLevelsExpanded = 0
-- A dictionary of loaded ModuleScripts and the values they returned
local LoadedModules: {[ModuleScript]: any} = {}
-- A dictionary of known module aliases and the ModuleScripts they point to
local Modules: {[string]: ModuleScript} = {}
-- The set of all currently loading modules
local ModulesLoading: {[ModuleScript]: boolean} = {}
-- A dictionary that relates module data tables to the modules' names
local NameRegistry: {[{}]: string} = {}
-- An array that contains all currently loaded task module data
local Tasks: {any} = {}
-- The total number of discovered (but not necessarily loaded) modules
local TotalModules = 0

-- Private functions

-- Adds a metatable to a temporary module table to let access operations fall
-- through to the original module table.
local function replaceTempModule(moduleName: string, moduleData: any)
	LoadedModules[Modules[moduleName]].IsFakeModule = nil
	if typeof(moduleData) == "table" then
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

	CycleMetatable.CurrentModuleLoading = module.Name

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
			NameRegistry[moduleData] = module.Name
		end
	end)
	if not renameSuccess then
		warn("Failed to add internal name to module", module.Name, "-", renameMessage)
	end

	CycleMetatable.CurrentModuleLoading = nil

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

	dprint("Indexing names for", child.Name, "up to", levelCap or "all levels")

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

		if ancestor.Name == "ServerScriptService" or ancestor.Name == "PlayerScripts" or ancestor.Name == "Shared" then
			break
		end
	end
end

local function expandNameIndex(levelCap: number)
	if levelCap <= AncestorLevelsExpanded then return end

	dprint("Expanding ancestry name index to level", levelCap)

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
	dprint("\tRequest to load", module)

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
			dprint("\tLoaded", module)
		end

		ModulesLoading[Modules[module]] = nil
	else
		if not Modules[module] then
			dprint("Cache miss for", module)

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
		setmetatable(fakeModule, CycleMetatable)
		LoadedModules[Modules[module]] = fakeModule

		dprint("\tSet", module, "to fake module")
	end

	return LoadedModules[Modules[module]]
end

-- Indexes any ModuleScript children of the specified Instance
function Order.IndexModulesOf(location: Instance)
	dprint("Indexing modules -", location:GetFullName())

	local discovered = 0
	for _: number, child: Instance in ipairs(location:GetDescendants()) do
		if child:IsA("ModuleScript") and child ~= script then
			discovered += 1
			TotalModules += 1
			indexNames(child, 0)
		end
	end

	if discovered > 0 then
		dprint("\tDiscovered", discovered, if discovered == 1 then "module" else "modules")
	end
end

-- Asynchronously loads all ModuleScript children of the specified task Folder,
-- and queues them for initialization. Recursively loads all children of any
-- discovered Folders as well.
function Order.LoadTasks(location: Folder)
	dprint("Loading tasks -", location:GetFullName())

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
	vprint("Initializing tasks...")

	table.sort(Tasks, function(a, b)
		local aPriority = a.Priority or 0
		local bPriority = b.Priority or 0
		return aPriority > bPriority
	end)

	-- Don't use dprint to avoid too much unnecessary work
	if Settings.DebugMode then
		print("\tCurrent initialization order:")
		for index: number, moduleData: {} in pairs(Tasks) do
			print("\t\t" .. index .. ')', NameRegistry[moduleData] or moduleData)
		end
	end

	local function initialize(moduleData: {}, initializer: Initializer)
		if moduleData[initializer.Name] then
			local finished = false
			local success = true
			local message

			if not initializer.Async then
				local startTime = os.clock()
				task.spawn(function()
					while not finished do
						task.wait()
						if os.clock() - startTime > initializer.WarnDelay then
							warn(
								"Slow module detected -",
								NameRegistry[moduleData] or moduleData,
								"has been initializing for more than",
								initializer.WarnDelay,
								"seconds"
							)
							break
						end
					end
				end)

				if initializer.Protected then
					success, message = pcall(moduleData[initializer.Name], moduleData)
				else
					moduleData[initializer.Name](moduleData)
				end
			else
				task.spawn(moduleData[initializer.Name], moduleData)
			end

			finished = true

			if not success then
				warn(
					"Failed to execute initializer '" .. initializer.Name .. "' for module",
					NameRegistry[moduleData] or moduleData,
					"-",
					message
				)
			else
				dprint(
					"\t::" .. initializer.Name .. "() executed successfully for",
					NameRegistry[moduleData] or moduleData
				)
			end
		end
	end

	if Settings.InitOrder == "Individual" then
		for _: number, moduleData: {} in ipairs(Tasks) do
			local config = moduleData.InitConfigOverride or Settings.InitFunctionConfig
			for _, initializer: Initializer in ipairs(config) do
				initialize(moduleData, initializer)
			end
			dprint("Initialized task -", NameRegistry[moduleData] or moduleData)
		end
	elseif Settings.InitOrder == "Project" then
		-- Figure out how many total stages there are since tasks can
		-- individually specify more than the global config does
		local maxInitStages = #Settings.InitFunctionConfig
		for _: number, moduleData: {} in ipairs(Tasks) do
			maxInitStages = math.max(maxInitStages, moduleData.InitConfigOverride and #moduleData.InitConfigOverride or 0)
		end
		dprint("Initializing tasks in", maxInitStages, "stages...")

		-- Execute each stage
		for i = 1, maxInitStages do
			for _: number, moduleData: {} in ipairs(Tasks) do
				local config = moduleData.InitConfigOverride or Settings.InitFunctionConfig
				local initializer = config[i]
				if initializer then
					initialize(moduleData, initializer)
				end
			end
			dprint("Initialization stage", i, "complete.")
		end
	else
		warn("Cannot initialize tasks - unsupported initialization order specified:", Settings.InitOrder)
	end

	table.clear(Tasks)

	vprint("All tasks initialized.")
end

-- Keyword linking

-- Enables shared keyword to act as require()
if not Settings.PortableMode then
	setmetatable(shared, Order)
end
-- Enables this module to act as require() when required
setmetatable(Order, Order)

-- Auto initialization

if not Settings.PortableMode then
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local SharedContext = ReplicatedStorage:WaitForChild("Shared")
	local LocalContext
	if RunService:IsClient() then
		local LocalPlayer = game:GetService("Players").LocalPlayer
		if LocalPlayer and RunService:IsRunning() then
			LocalContext = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
		else
			LocalContext = game:GetService("StarterPlayer").StarterPlayerScripts.Client
		end
	else
		LocalContext = game:GetService("ServerScriptService"):WaitForChild("Server")
	end

	Order.IndexModulesOf(LocalContext)
	Order.IndexModulesOf(SharedContext)

	if RunService:IsRunning() then
		Order.LoadTasks(LocalContext:WaitForChild("tasks"))
		Order.LoadTasks(SharedContext:WaitForChild("tasks"))

		Order.InitializeTasks()
	end

	shared._OrderInitialized = true
end

vprint("Framework initialized.")

return Order
