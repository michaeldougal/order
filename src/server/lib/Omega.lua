local Omega = {}

---@module Alpha
local Alpha = shared("Alpha")
local Filler = shared("Filler")
local Beta = shared("Beta")

function Omega:Test()
	print("Omega test successful")

	Alpha:Test()
	Filler:Test()
end

return Omega