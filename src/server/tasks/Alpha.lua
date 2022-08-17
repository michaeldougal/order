local Alpha = {
	SomeValue = {25, 87, 20}
}

local Omega = shared("Omega")
local Filler = shared("Filler")
local Beta = shared("Beta")
local Set = shared("Set")
local Store = shared("Store")
---@module Tweentown
local Tweentown = shared("Tweentown")
---@module Number
local Number = shared("Number")

function Alpha:Test(someCallback: (string) -> number)
	print("Alpha test successful")
	Alpha.SomeValue = 90
end

function Alpha:Init()
	print("Initializing Alpha")

	Omega:Test()

	local newSet = Set.new({1, 2, 3, 4, 5})
	print(newSet:contains(4), newSet:contains(6))

	print(Number)
end

return Alpha