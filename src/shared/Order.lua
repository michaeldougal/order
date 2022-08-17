local standardPrint = print
function print(...)
	standardPrint("[Order]", ...)
end

local standardWarn = warn
function warn(...)
	standardWarn("[Order]", ...)
end

print("Framework intializing...")

local Order = {
	IndexSubmodules = true, -- Whether or not to discover submodules for requiring by name
	DebugMode = false -- Verbose loading in the output window
}

local Modules = {}
local LoadedModules = {}
local ModulesLoading = {}

local function replaceTempModule(moduleName, moduleData)
	LoadedModules[moduleName].IsFakeModule = nil
	if typeof(moduleData) == "table" then
		setmetatable(LoadedModules[moduleName], {
			__index = function(_, requestedKey)
				return moduleData[requestedKey]
			end,
			__newindex = function(_, requestedKey, requestedValue)
				moduleData[requestedKey] = requestedValue
			end
		})
	else
		LoadedModules[moduleName] = moduleData
	end
end

local function load(module: ModuleScript)
	local moduleData
	local success, message = pcall(function()
		moduleData = require(module)
	end)
	if not success then
		warn("Failed to load module", module.Name, "-", message)
	elseif Order.DebugMode then
		print("Loaded module", module.Name, moduleData)
	end
	return moduleData
end

function Order.__call(_: {}, module: string | ModuleScript)
	if Order.DebugMode then
		print("Request to load", module)
	end

	if typeof(module) == "Instance" then
		return load(module)
	end

	if not LoadedModules[module] then
		if Modules[module] and not ModulesLoading[module] then
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
			LoadedModules[module] = {IsFakeModule = true}
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
	local discoveredModuleCount = 0
	for _, child: Instance in ipairs(location:GetChildren()) do
		if child:IsA("ModuleScript") and child ~= script then
			discoveredModuleCount += 1
			if Modules[child.Name] then
				warn("Duplicate modules found:", child, Modules[child.Name])
				continue
			end
			Modules[child.Name] = child
			if Order.IndexSubmodules then
				Order.IndexModulesOf(child)
			end
		elseif child:IsA("Folder") then
			Order.IndexModulesOf(child)
		end
	end
	if Order.DebugMode and discoveredModuleCount > 0 then
		print("Discovered", discoveredModuleCount, if discoveredModuleCount == 1 then "module" else "modules")
	end
end

function Order.LoadTasks(location: Folder)
	for _, child: ModuleScript | Folder in ipairs(location:GetChildren()) do
		if child:IsA("ModuleScript") then
			shared(child.Name)
		elseif child:IsA("Folder") then
			Order.LoadTasks(child)
		end
	end
end

function Order.InitializeTasks()
	local tasksInitializing = 0
	for moduleName: string, module: any in pairs(LoadedModules) do
		if typeof(module) == "table" and module.Init then
			tasksInitializing += 1
			task.spawn(function()
				local success, message = pcall(function()
					module:Init()
				end)
				if not success then
					warn("Failed to initialize module", moduleName, "-", message)
				end
				tasksInitializing -= 1
			end)
		end
	end
	while tasksInitializing > 0 do task.wait() end
end

setmetatable(shared, Order)

print("Framework initialized.")

return Order
