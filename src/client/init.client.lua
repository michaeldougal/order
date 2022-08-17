local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Order = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Order"))

local LocalContext = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local SharedContext = ReplicatedStorage:WaitForChild("Common")

Order.IndexModulesOf(LocalContext)
Order.IndexModulesOf(SharedContext)

Order.LoadTasks(LocalContext:WaitForChild("tasks"))
Order.LoadTasks(SharedContext:WaitForChild("tasks"))

Order.InitializeTasks()
