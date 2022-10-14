--[[
	Author: ChiefWildin
	Module: AnimNation
	Created: 10/12/2022
	Version: 1.0.0

	An animation library that allows for easy one-shot object animation using
	springs and tweens.
--]]

-- Services

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")


-- Module Declaration

local AnimNation = {}


-- Dependencies

---@module Spring
local Spring = require(script:WaitForChild("Spring"))


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

-- Aliases

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

-- Classes and Types

type Arithmetic = number | Vector2 | Vector3
type Spring = Spring.Spring

export type SpringInfo = {
	Position: Arithmetic?,
	Velocity: number?,
	Target: Arithmetic?,
	Damper: number?,
	Speed: number?,
	Initial: Arithmetic?,
	Clock: (() -> number)?,
}

export type AnimChain = {
	_anim: Spring | Tween,
	_type: "Spring" | "Tween",
	AndThen: (AnimChain, callback: () -> ()) -> AnimChain
}

local AnimChain: AnimChain = {}
AnimChain.__index = AnimChain

function AnimChain.new(original: Spring | Tween)
	local self = setmetatable({}, AnimChain)
	self._anim = original
	self._type = if typeof(original) == "Instance" then "Tween" else "Spring"
	return self
end

function AnimChain:AndThen(callback: () -> ()): AnimChain
	if self._type == "Spring" then
		task.spawn(function()
			while AnimNation.springAnimating(self._anim) do task.wait() end
			callback()
		end)
	elseif self._type == "Tween" then
		if self._anim then
			if self._anim.PlaybackState == Enum.PlaybackState.Completed then
				task.spawn(callback)
			else
				self._anim.Completed:Connect(function(playbackState)
					if playbackState == Enum.PlaybackState.Completed then
						callback()
					end
				end)
			end
		else
			callback()
		end
	end
	return self :: AnimChain
end


-- Global Variables

-- A dictionary that keeps track of custom springs by name.
local SpringDirectory: {[string]: Spring} = {}

-- A dictionary that keeps track of the internal springs controlling instance
-- properties.
local SpringEvents: {[Instance]: {[string]: Spring}} = {}

-- A dictionary that keeps track of the last tween played on each instance.
local TweenDirectory: {[Instance]: Tween} = {}

-- A dictionary that keeps track of the states of NumberSequence/ColorSequence
-- values.
local ActiveSequences: {[Instance]: {[string]: {[string]: NumberValue | Color3Value}}} = {}


-- Objects


-- Private Functions

local function murderTweenWhenDone(tween: Tween)
	tween.Completed:Wait()
	tween:Destroy()

	-- Clean up if this was the last tween played on the instance, might not be
	-- if another property was changed before this one finished.
	if TweenDirectory[tween.Instance] == tween then
		TweenDirectory[tween.Instance] = nil
	end
end

local function tweenByPrimaryPart(object: Model, tweenInfo: TweenInfo, properties: {}, waitToKill: boolean?): AnimChain
	if not object or not object:IsA("Model") then
		warn("Tween by primary part failure - invalid object passed\n" .. debug.traceback())
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return AnimChain.new()
	end

	-- Keep setting by PrimaryPartCFrame if PrimaryPart exists, until :PivotTo()
	-- is proven to be faster. My own testing has been inconclusive so far.
	local fakeCenter = Instance.new("Part")
	if object.PrimaryPart then
		fakeCenter.CFrame = object.PrimaryPart.CFrame
		fakeCenter:GetPropertyChangedSignal("CFrame"):Connect(function()
			object:SetPrimaryPartCFrame(fakeCenter.CFrame)
		end)
	else
		fakeCenter.CFrame = object:GetPivot()
		fakeCenter:GetPropertyChangedSignal("CFrame"):Connect(function()
			object:PivotTo(fakeCenter.CFrame)
		end)
	end

	task.delay(tweenInfo.Time, function()
		fakeCenter:Destroy()
	end)

	return AnimNation.tween(fakeCenter, tweenInfo, properties, waitToKill)
end

local function tweenSequence(object: Instance, sequenceName: string, tweenInfo: TweenInfo, newSequence: NumberSequence | ColorSequence, waitToKill: boolean?): AnimChain
	local originalSequence = object[sequenceName]
	local sequenceType = typeof(originalSequence)
	local numPoints = #originalSequence.Keypoints
	if numPoints ~= #newSequence.Keypoints then
		warn("Tween sequence failure - keypoint count mismatch\n" .. debug.traceback())
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return AnimChain.new()
	end

	local function updateSequence()
		local newKeypoints = table.create(numPoints)
		for index, point in pairs(ActiveSequences[object][sequenceName]) do
			if sequenceType == "NumberSequence" then
				newKeypoints[index] = NumberSequenceKeypoint.new(point.Time.Value, point.Value.Value, point.Envelope.Value)
			else
				newKeypoints[index] = ColorSequenceKeypoint.new(point.Time.Value, point.Value.Value)
			end
		end
		object[sequenceName] = if sequenceType == "NumberSequence" then NumberSequence.new(newKeypoints) else ColorSequence.new(newKeypoints)
	end

	if not ActiveSequences[object] then
		ActiveSequences[object] = {}
	end
	if not ActiveSequences[object][sequenceName] then
		ActiveSequences[object][sequenceName] = table.create(numPoints)

		for index, keypoint in pairs(originalSequence.Keypoints) do
			local point
			if sequenceType == "NumberSequence" then
				point = {
					Time = Instance.new("NumberValue"),
					Value = Instance.new("NumberValue"),
					Envelope = Instance.new("NumberValue")
				}

				point.Envelope.Value = keypoint.Envelope
				point.Envelope:GetPropertyChangedSignal("Value"):Connect(updateSequence)
			elseif sequenceType == "ColorSequence" then
				point = {
					Time = Instance.new("NumberValue"),
					Value = Instance.new("Color3Value")
				}
			end

			point.Value.Value = keypoint.Value
			point.Time.Value = keypoint.Time

			point.Value:GetPropertyChangedSignal("Value"):Connect(updateSequence)
			point.Time:GetPropertyChangedSignal("Value"):Connect(updateSequence)

			ActiveSequences[object][sequenceName][index] = point
		end
	end

	for index, _ in pairs(originalSequence.Keypoints) do
		local point = ActiveSequences[object][sequenceName][index]
		local isLast = index == numPoints
		local shouldWait = isLast and waitToKill
		if sequenceType == "NumberSequence" then
			AnimNation.tween(point.Envelope, tweenInfo, {Value = newSequence.Keypoints[index].Envelope})
		end
		AnimNation.tween(point.Value, tweenInfo, {Value = newSequence.Keypoints[index].Value})
		local tweenObject = AnimNation.tween(point.Time, tweenInfo, {Value = newSequence.Keypoints[index].Time}, shouldWait):AndThen(function()
			if index == numPoints then
				for _, pointData in pairs(ActiveSequences[object][sequenceName]) do
					pointData.Value:Destroy()
					pointData.Time:Destroy()
					if sequenceType == "NumberSequence" then
						pointData.Envelope:Destroy()
					end
				end

				ActiveSequences[object][sequenceName] = nil

				local remainingTweens = 0
				for _, _ in pairs(ActiveSequences[object]) do
					remainingTweens += 1
					break
				end
				if remainingTweens == 0 then
					ActiveSequences[object] = nil
				end

				object[sequenceName] = newSequence
			end
		end)

		if isLast then return tweenObject end
	end
end

local function createSpringFromInfo(springInfo: SpringInfo): Spring
	local spring = Spring.new(springInfo.Initial, springInfo.Clock)
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
	local animating, position = AnimNation.springAnimating(spring)
	while animating do
		object[property] = position
		task.wait()
		animating, position = AnimNation.springAnimating(spring)
	end

	object[property] = spring.Target

	if SpringEvents[object] then
		SpringEvents[object][property] = nil

		local stillHasSprings = false
		for _, _ in pairs(SpringEvents[object]) do
			stillHasSprings = true
			break
		end
		if not stillHasSprings then
			SpringEvents[object] = nil
		end
	end
end

-- Public Functions

-- Asynchronously performs a tween on the given object. Parameters are idential
-- to `TweenService:Create()`, with the addition of `waitToKill`, which will make
-- the operation synchronous if true. `:AndThen()` can be used to link another
-- function that will be called when the tween completes.
function AnimNation.tween(object: Instance, tweenInfo: TweenInfo, properties: {}, waitToKill: boolean?): AnimChain
	if not object then
		warn("Tween failure - invalid object passed\n" .. debug.traceback())
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return AnimChain.new()
	end

	local isModel = object:IsA("Model")
	local alternativeAnimChain: AnimChain?
	local normalCount = 0

	for property, newValue in pairs(properties) do
		if isModel and property == "CFrame" then
			alternativeAnimChain = tweenByPrimaryPart(object, tweenInfo, {CFrame = newValue})
			properties[property] = nil
		else
			local propertyType = typeof(object[property])
			if propertyType == "ColorSequence" or propertyType == "NumberSequence" then
				alternativeAnimChain = tweenSequence(object, property, tweenInfo, newValue)
				properties[property] = nil
			else
				normalCount += 1
			end
		end
	end

	if normalCount == 0 then
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return alternativeAnimChain or AnimChain.new()
	end

	local thisTween = TweenService:Create(object, tweenInfo, properties)
	local tweenChain = AnimChain.new(thisTween)

	thisTween:Play()
	TweenDirectory[object] = thisTween

	if waitToKill then
		murderTweenWhenDone(thisTween)
	else
		task.spawn(murderTweenWhenDone, thisTween)
	end

	return tweenChain :: AnimChain
end

-- Returns the last tween played on the given object, or `nil` if none exists.
function AnimNation.getTweenFromInstance(object: Instance): Tween?
	return TweenDirectory[object]
end

-- Asynchronously performs a spring impulse on the given object. `SpringInfo` is
-- a table of spring properties such as `{s = 10, d = 0.5}`. The optional
-- `waitToKill` flag will make the operation synchronous if true. `:AndThen()`
-- can be used on this function's return value to link another function that
-- will be called when the spring completes (reaches epsilon).
function AnimNation.impulse(object: Instance, springInfo: SpringInfo, properties: {[string]: any}, waitToKill: boolean?): AnimChain
	if not object then
		warn("Spring failure - invalid object passed\n" .. debug.traceback())
		return AnimChain.new()
	end

	local animChain: AnimChain
	local trackingPropertyForYield = false
	for property, impulse in pairs(properties) do
		local impulseType = typeof(impulse)
		if SUPPORTED_TYPES[impulseType] then
			local needsAnimationLink = true
			springInfo.Initial = object[property]

			if not SpringEvents[object] then
				SpringEvents[object] = {}
			end
			if not SpringEvents[object][property] then
				SpringEvents[object][property] = createSpringFromInfo(springInfo)
			else
				updateSpringFromInfo(SpringEvents[object][property], springInfo)
				needsAnimationLink = false
			end

			local newSpring = SpringEvents[object][property]

			if not animChain then
				animChain = AnimChain.new(newSpring)
			end

			newSpring:Impulse(impulse)
			if needsAnimationLink then
				if waitToKill and not trackingPropertyForYield and animChain then
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

	return animChain :: AnimChain
end

-- Asynchronously uses a spring to transition the given object's properties to
-- the specified values. `SpringInfo` is a table of spring properties such as
-- `{s = 10, d = 0.5}`. The optional `waitToKill` flag will make the operation
-- synchronous if true. `:AndThen()` can be used on this function's return value
-- to link another function that will be called when the spring completes
-- (reaches epsilon).
function AnimNation.target(object: Instance, springInfo: SpringInfo, properties: {[string]: any}, waitToKill: boolean?)
	local yieldStarted = false
	for property, target in pairs(properties) do
		local targetType = typeof(target)
		if not ZEROS[targetType] then
			error("Spring failure - unsupported target type '" .. targetType .. "' passed\n" .. debug.traceback())
			continue
		end
		springInfo.Target = target
		AnimNation.impulse(object, springInfo, {[property] = ZEROS[targetType]}, waitToKill and not yieldStarted)
		yieldStarted = waitToKill
	end
end

-- Creates a new spring with the given properties. `SpringInfo` is a table of
-- spring properties such as `{s = 10, d = 0.5}`.
function AnimNation.createSpring(name: string, springInfo: SpringInfo): Spring
	local newSpring = createSpringFromInfo(springInfo)
	SpringDirectory[name] = newSpring
	return newSpring
end

-- Returns the spring with the given name. If none exists, it will return `nil`
-- with a warning, or an error depending on the set `ERROR_POLICY`.
function AnimNation.getSpring(name: string): Spring?
	if SpringDirectory[name] then
		return SpringDirectory[name]
	else
		error(string.format("Spring '%s' does not exist", name))
	end
end

-- Modified from Quenty's SpringUtils. Returns whether the given spring is
-- currently animating (has not reached epsilon) and its current position.
function AnimNation.springAnimating(spring: Spring, epsilon: number?): (boolean, Vector3)
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

-- Public Function Aliases

AnimNation.inquire = AnimNation.getSpring
AnimNation.register = AnimNation.createSpring

return AnimNation
