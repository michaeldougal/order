local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Forklift = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Forklift"))

local LocalContext = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local SharedContext = ReplicatedStorage:WaitForChild("Common")

Forklift.IndexModulesOf(LocalContext)
Forklift.IndexModulesOf(SharedContext)

Forklift.LoadTasks(LocalContext:WaitForChild("tasks"))
Forklift.LoadTasks(SharedContext:WaitForChild("tasks"))

Forklift.InitializeTasks()
