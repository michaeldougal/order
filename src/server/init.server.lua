local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Order = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Order"))

local LocalContext = game:GetService("ServerScriptService"):WaitForChild("Server")
local SharedContext = ReplicatedStorage:WaitForChild("Common")

Order.IndexModulesOf(LocalContext)
Order.IndexModulesOf(SharedContext)

Order.LoadTasks(LocalContext:WaitForChild("tasks"))
Order.LoadTasks(SharedContext:WaitForChild("tasks"))

Order.InitializeTasks()
