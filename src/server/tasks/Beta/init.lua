local Beta = {}

local Alpha = shared("Alpha")
local Omega = shared("Omega")
local Filler = shared("Filler")
local Subtask = shared(script:WaitForChild("Subtask"))

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