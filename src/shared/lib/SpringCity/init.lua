--[[
	SpringCity.lua
	ChiefWildin
	Created: 07/10/2022 @ 14:43:31

	Description:
		Dedicated to Larry. He is a good man that has no love for Tweentown. But
		everybody needs a home. So I built a new city for him. SpringCity. He
		doesn't like it yet. But we'll get there. Eventually.

	Dependencies:
		Server:
		Shared:
		Client:
		Children:
			Spring

	Documentation:
		SpringInfo
			A dictionary of spring properties to property values. There no
			required elements.

		SpringChain
			An object that allows chaining of multiple final callbacks. Use
			:AndThen() on the SpringChain to link a callback to be run when the
			spring comes to rest.
			Ex.
				SpringCity:Impulse(textButton, {Speed = 30, Damper = 0.1}, {Rotation = 30}):AndThen(function()
					textButton.Text = "Hello"
				end)

		::Register(springName: string, springInfo: SpringInfo): Spring
			Registers a new spring in SpringCity. Returns the new spring created.

		::Get(springName: string): Spring
			Returns the spring with the provided name. If it does not exist,
			errors or warns based on policy and returns nil.

		::Inquire(springName: string): Spring
			Alias for :Get().

		::Impulse(object: Instance, springInfo: SpringInfo, properties: {}, waitToKill: boolean?): SpringChain
			Behaves like Tweentown:Tween(), using springs instead of tweens.
			If springs are already influencing the provided object, they are
			adjusted to match the new SpringInfo and reused.
			Ex.
				SpringCity:Impulse(textButton, {Speed = 30, Damper = 0.1}, {Rotation = 30})

		::Target(object: Instance, springInfo: SpringInfo, properties: {}, waitToKill: boolean?)
			Behaves like :Impulse(), but sets the spring target instead of
			applying temporary force. If springs are already influencing the
			provided object, they are adjusted to match the new SpringInfo and
			reused.
			Ex.
				SpringCity:Target(textButton, {Speed = 30, Damper = 0.1}, {Rotation = 30})
--]]

-- Main job table
local SpringCity = {}

-- Services
local RunService = game:GetService("RunService")

-- Dependencies
---@module Spring
local Blueprint = require(script:WaitForChild("Spring"))

-- Constants
local ERROR_POLICY: "Warn" | "Error" = if RunService:IsStudio() then "Error" else "Warn"
local EPSILON = 1e-4
local SUPPORTED_TYPES = {
	number = true,
	Vector2 = true,
	Vector3 = true,
	UDim2 = true,
	UDim = true,
	CFrame = true,
	Color3 = true
}
local ZEROS = {
	number = 0,
	Vector2 = Vector2.zero,
	Vector3 = Vector3.zero,
	UDim2 = UDim2.new(),
	UDim = UDim.new(),
	CFrame = CFrame.identity,
	Color3 = Color3.new()
}

-- Aliases (for super speeeeeeeeed)
local abs = math.abs
local vector3 = Vector3.new

-- Overloads
local StdError = error
local function error(message: string)
	if ERROR_POLICY == "Warn" then
		warn(message)
	else
		StdError(message)
	end
end

-- Classes and types
type Arithmetic = number | Vector2 | Vector3
type Spring = Blueprint.Spring

export type SpringInfo = {
	Position: Arithmetic?,
	Velocity: number?,
	Target: Arithmetic?,
	Damper: number?,
	Speed: number?,
	Initial: Arithmetic?,
	Clock: (() -> number)?,
}

export type SpringChain = {
	_spring: Spring,
	AndThen: (SpringChain, callback: () -> ()) -> SpringChain
}

-- Taken from Quenty's SpringUtils
local function springAnimating(spring, epsilon)
	epsilon = epsilon or EPSILON

	local position = spring.Position
	local velocity = spring.Velocity
	local target = spring.Target

	local animating
	if spring.Type == "number" then
		animating = abs(position - target) > epsilon or abs(velocity) > epsilon
	elseif spring.Type == "Vector3" or spring.Type == "Vector2" then
		animating = (position - target).Magnitude > epsilon or velocity.Magnitude > epsilon
	elseif spring.Type == "UDim2" then
		animating = abs(position.X.Scale - target.X.Scale) > epsilon or abs(velocity.X.Scale) > epsilon or
			abs(position.X.Offset - target.X.Offset) > epsilon or abs(velocity.X.Offset) > epsilon or
			abs(position.Y.Scale - target.Y.Scale) > epsilon or abs(velocity.Y.Scale) > epsilon or
			abs(position.Y.Offset - target.Y.Offset) > epsilon or abs(velocity.Y.Offset) > epsilon
	elseif spring.Type == "UDim" then
		animating = abs(position.Scale - target.Scale) > epsilon or abs(velocity.Scale) > epsilon or
			abs(position.Offset - target.Offset) > epsilon or abs(velocity.Offset) > epsilon
	elseif spring.Type == "CFrame" then
		local startAngleVector, startAngleRot = position:ToAxisAngle()
		local velocityAngleVector, velocityAngleRot = velocity:ToAxisAngle()
		local targetAngleVector, targetAngleRot = target:ToAxisAngle()
		animating = (position.Position - target.Position).Magnitude > epsilon or velocity.Position.Magnitude > epsilon or
			(startAngleVector - targetAngleVector).Magnitude > epsilon or velocityAngleVector.Magnitude > epsilon or
			abs(startAngleRot - targetAngleRot) > epsilon or abs(velocityAngleRot) > epsilon
	elseif spring.Type == "Color3" then
		local startVector = vector3(position.R, position.G, position.B)
		local velocityVector = vector3(velocity.R, velocity.G, velocity.B)
		local targetVector = vector3(target.R, target.G, target.B)
		animating = (startVector - targetVector).Magnitude > epsilon or velocityVector.Magnitude > epsilon
	else
		error("Unknown type")
	end

	if animating then
		return true, position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the spring is asleep)
		return false, target
	end
end

local SpringChain: SpringChain = {}
SpringChain.__index = SpringChain

function SpringChain.new(originalSpring: Spring?): SpringChain
	local this = setmetatable({}, SpringChain)
	this._spring = originalSpring

	return this
end

function SpringChain:AndThen(callback: () -> ()): SpringChain
	if self._spring then
		task.spawn(function()
			while springAnimating(self._spring) do task.wait() end
			callback()
		end)
	end
	return self :: SpringChain
end

-- Global variables
local Directory: {[string]: Spring} = {}
local Events: {[Instance]: {[string]: Spring}} = {}

-- Objects

-- Private functions
local function createSpringFromInfo(springInfo: SpringInfo): Spring
	local spring = Blueprint.new(springInfo.Initial, springInfo.Clock)
	for key, value in pairs(springInfo) do
		if key ~= "Initial" and key ~= "Clock" then
			spring[key] = value
		end
	end
	return spring
end

local function updateSpringFromInfo(spring: Spring, springInfo: SpringInfo): Spring
	for key, value in pairs(springInfo) do
		if key ~= "Initial" and key ~= "Clock" and key ~= "Position" then
			spring[key] = value
		end
	end
end

local function animate(spring, object, property)
	local animating, position = springAnimating(spring)
	while animating do
		object[property] = position
		task.wait()
		animating, position = springAnimating(spring)
	end
	if Events[object] then
		Events[object][property] = nil
		local stillHasSprings = false
		for _, _ in pairs(Events[object]) do
			stillHasSprings = true
			break
		end
		if not stillHasSprings then
			Events[object] = nil
		end
	end
end

-- Public functions
function SpringCity:Register(springName: string, springInfo: SpringInfo): Spring
	local newSpring = createSpringFromInfo(springInfo)
	Directory[springName] = newSpring
	return newSpring
end

function SpringCity:Get(springName: string): Spring?
	if Directory[springName] then
		return Directory[springName]
	else
		error(string.format("Spring '%s' does not exist", springName))
	end
end

function SpringCity:Impulse(object: Instance, springInfo: SpringInfo, properties: {[string]: any}, waitToKill: boolean?): SpringChain
	if not object then
		warn("Spring failure - invalid object passed\n" .. debug.traceback())
		return SpringChain.new()
	end

	local springChain
	local trackingPropertyForYield = false
	for property, impulse in pairs(properties) do
		local impulseType = typeof(impulse)
		if SUPPORTED_TYPES[impulseType] then
			local needsAnimationLink = true
			springInfo.Initial = object[property]

			if not Events[object] then
				Events[object] = {}
			end
			if not Events[object][property] then
				Events[object][property] = createSpringFromInfo(springInfo)
			else
				updateSpringFromInfo(Events[object][property], springInfo)
				needsAnimationLink = false
			end

			local newSpring = Events[object][property]

			if not springChain then
				springChain = SpringChain.new(newSpring)
			end

			newSpring:Impulse(impulse)
			if needsAnimationLink then
				if waitToKill and not trackingPropertyForYield and springChain then
					trackingPropertyForYield = true
					animate(newSpring, object, property)
				else
					task.spawn(animate, newSpring, object, property)
				end
			end
		else
			error(string.format("Spring failure - invalid impulse type '%s' for property '%s'", impulseType, property))
		end
	end

	return springChain :: SpringChain
end

function SpringCity:Target(object: Instance, springInfo: SpringInfo, properties: {[string]: any}, waitToKill: boolean?)
	local yieldStarted = false
	for property, target in pairs(properties) do
		local targetType = typeof(target)
		if not ZEROS[targetType] then
			error("Spring failure - unsupported target type '" .. targetType .. "' passed\n" .. debug.traceback())
			continue
		end
		springInfo.Target = target
		SpringCity:Impulse(object, springInfo, {[property] = ZEROS[targetType]}, waitToKill and not yieldStarted)
		yieldStarted = waitToKill
	end
end

-- Aliases
SpringCity.Inquire = SpringCity.Get

return SpringCity
