local Alpha = {
	SomeValue = {25, 87, 20}
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local require = require(ReplicatedStorage:WaitForChild("Common"):WaitForChild("Forklift")).require

local Omega = require("Omega")
local Filler = require("Filler")
local Beta = require("Beta")
local Set = require("Set")
local Store = require("Store")
---@module Tweentown
local Tweentown = require("Tweentown")

function Alpha:Test()
	print("Alpha test successful")
	Alpha.SomeValue = 90
end

function Alpha:Init()
	print("Initializing Alpha")

	Omega:Test()

	local newSet = Set.new({1, 2, 3, 4, 5})
	print(newSet:contains(4), newSet:contains(6))
end

return Alpha