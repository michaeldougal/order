local Beta = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local require = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Forklift")).require

local Alpha = require("Alpha")
local Omega = require("Omega")
local Filler = require("Filler")
local Subtask = require(script:WaitForChild("Subtask"))

function Beta:Test()
	print("Beta test successful")
end

function Beta:Init()
	print("Initializing Beta")

	Omega:Test()
	Alpha:Test()
	Filler:Test()
	Subtask:Test()

	print("Alpha SomeValue:", Alpha.SomeValue)
end

return Beta