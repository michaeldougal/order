local standardPrint = print
function print(...)
	standardPrint("[Forklift]", ...)
end

local standardWarn = warn
function warn(...)
	standardWarn("[Forklift]", ...)
end

print("Framework intializing...")

local Forklift = {
	IndexSubmodules = true, -- Whether or not to discover submodules for requiring by name
	DebugMode = false -- Verbose loading in the output window
}

local Modules = {}
local LoadedModules = {}
local ModulesLoading = {}

local function replaceTempModule(moduleName, moduleData)
	LoadedModules[moduleName].IsFakeModule = nil
	setmetatable(LoadedModules[moduleName], {
		__index = function(_, requestedKey)
			return moduleData[requestedKey]
		end,
		__newindex = function(_, requestedKey, requestedValue)
			moduleData[requestedKey] = requestedValue
		end
	})
end

function Forklift.require(module: string | ModuleScript)
	if Forklift.DebugMode then
		print("Request to load", module)
	end

	if typeof(module) == "Instance" then
		return require(module)
	end

	if not LoadedModules[module] then
		if Modules[module] and not ModulesLoading[module] then
			ModulesLoading[module] = true
			local moduleData = require(Modules[module])
			if LoadedModules[module] then -- Found temporary placeholder due to cyclic dependency
				replaceTempModule(module, moduleData)
			else
				LoadedModules[module] = moduleData
				if Forklift.DebugMode then
					print("Loaded", module)
				end
			end
		else
			if not Modules[module] then
				warn("Tried to require unknown module '" .. module .. "'")
				return
			end
			LoadedModules[module] = {IsFakeModule = true}
			if Forklift.DebugMode then
				print("Set", module, "to fake module")
			end
		end
	end

	return LoadedModules[module]
end

function Forklift.IndexModulesOf(location: Instance)
	if Forklift.DebugMode then
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
			if Forklift.IndexSubmodules then
				Forklift.IndexModulesOf(child)
			end
		elseif child:IsA("Folder") then
			Forklift.IndexModulesOf(child)
		end
	end
	if Forklift.DebugMode and discoveredModuleCount > 0 then
		print("Discovered", discoveredModuleCount, if discoveredModuleCount == 1 then "module" else "modules")
	end
end

function Forklift.LoadTasks(location: Folder)
	for _, child: ModuleScript | Folder in ipairs(location:GetChildren()) do
		if child:IsA("ModuleScript") then
			Forklift.require(child.Name)
		elseif child:IsA("Folder") then
			Forklift.LoadTasks(child)
		end
	end
end

function Forklift.InitializeTasks()
	for _, module: {} in pairs(LoadedModules) do
		if module.Init then
			module:Init()
		end
	end
end

print("Framework initialized")

return Forklift
