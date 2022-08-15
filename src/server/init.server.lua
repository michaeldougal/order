local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Forklift = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Forklift"))

local LocalContext = game:GetService("ServerScriptService"):WaitForChild("Server")
local SharedContext = ReplicatedStorage:WaitForChild("Common")

Forklift.IndexModulesOf(LocalContext)
Forklift.IndexModulesOf(SharedContext)

Forklift.LoadTasks(LocalContext:WaitForChild("tasks"))
Forklift.LoadTasks(SharedContext:WaitForChild("tasks"))

Forklift.InitializeTasks()
