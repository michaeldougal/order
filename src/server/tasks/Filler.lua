local Filler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local require = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Forklift")).require

local Alpha = require("Alpha")
local Omega = require("Omega")
local Beta = require("Beta")
local Subtask = require("Subtask")

function Filler:Test()
	print("Filler test successful")
end

return Filler