local Omega = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local require = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Forklift")).require

local Alpha = require("Alpha")
local Filler = require("Filler")
local Beta = require("Beta")

function Omega:Test()
	print("Omega test successful")

	Alpha:Test()
	Filler:Test()
end

return Omega