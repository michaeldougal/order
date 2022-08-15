--[[
	Tweentown.lua
	ChiefWildin
	Created: 04/13/2022 @ 09:29:27

	Description:
		We takin a one-way trip to Tweentown, baby.

	Dependencies:
		Server:
		Shared:
		Client:

	Documentation:
		::Tween(object: Instance, tweenInfo: TweenInfo, properties: {}, yielding: boolean?): TweenObject
			Instantly tweens the provided object according to tweenInfo	and the
			properties table. Parameters are exactly like TweenService:Create(),
			except for the added yielding property which determines whether it
			will yield until the tween has completed.

			Allows tweens on NumberSequences and ColorSequences, as long as the
			original sequence and target sequence share the same number of
			keypoints.

			Also allows tweens on the PrimaryPart CFrame of Models. To do so,
			pass a model as the object and use CFrame in the properties table.

		::GetTweenFromInstance(instance: Instance)
			Returns the last tween played on the provided instance, if it
			exists. Otherwise, returns nil.
--]]

-- Services
local TweenService = game:GetService("TweenService")

-- Module table
local Tweentown = {}

-- Global Variables
local TweentownBank = {}
local ActiveWireTransfers: {[Instance]: {[string]: {[string]: NumberValue | Color3Value}}} = {}

-- Classes
export type TweenChain = {
	_tween: Tween,
	AndThen: (TweenChain, callback: () -> ()) -> TweenChain
}

local TweenChain: TweenChain = {}
TweenChain.__index = TweenChain

function TweenChain.new(originalTween: Tween?): TweenChain
	local this = setmetatable({}, TweenChain)
	this._tween = originalTween

	return this
end

function TweenChain:AndThen(callback: () -> ()): TweenChain
	if self._tween then
		if self._tween.PlaybackState == Enum.PlaybackState.Completed then
			task.spawn(callback)
		else
			self._tween.Completed:Connect(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed then
					callback()
				end
			end)
		end
	else
		callback()
	end
	return self :: TweenChain
end

-- Private functions
local function murderTweenWhenDone(tween: Tween)
	tween.Completed:Wait()
	tween:Destroy()
	TweentownBank[tween.Instance] = nil
end

local function tweenByPrimaryPart(object: Model, tweenInfo: TweenInfo, properties: {}, waitToKill: boolean?): TweenChain
	if not object or not object:IsA("Model") or not object.PrimaryPart then
		warn("Tween by primary part failure - invalid object passed\n" .. debug.traceback())
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return TweenChain.new()
	end

	local fakeCenter = Instance.new("Part")
	fakeCenter.CFrame = object.PrimaryPart.CFrame
	fakeCenter:GetPropertyChangedSignal("CFrame"):Connect(function()
		object:SetPrimaryPartCFrame(fakeCenter.CFrame)
	end)

	task.delay(tweenInfo.Time, function()
		fakeCenter:Destroy()
	end)

	return Tweentown:Tween(fakeCenter, tweenInfo, properties, waitToKill)
end

local function tweenSequence(object: Instance, sequenceName: string, tweenInfo: TweenInfo, newSequence: NumberSequence | ColorSequence, waitToKill: boolean?): TweenChain
	local originalSequence = object[sequenceName]
	local sequenceType = typeof(originalSequence)
	local numPoints = #originalSequence.Keypoints
	if numPoints ~= #newSequence.Keypoints then
		warn("Tween sequence failure - keypoint count mismatch\n" .. debug.traceback())
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return TweenChain.new()
	end

	local function updateSequence()
		local newKeypoints = table.create(numPoints)
		for index, point in pairs(ActiveWireTransfers[object][sequenceName]) do
			if sequenceType == "NumberSequence" then
				newKeypoints[index] = NumberSequenceKeypoint.new(point.Time.Value, point.Value.Value, point.Envelope.Value)
			else
				newKeypoints[index] = ColorSequenceKeypoint.new(point.Time.Value, point.Value.Value)
			end
		end
		object[sequenceName] = if sequenceType == "NumberSequence" then NumberSequence.new(newKeypoints) else ColorSequence.new(newKeypoints)
	end

	if not ActiveWireTransfers[object] then
		ActiveWireTransfers[object] = {}
	end
	if not ActiveWireTransfers[object][sequenceName] then
		ActiveWireTransfers[object][sequenceName] = table.create(numPoints)

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

			ActiveWireTransfers[object][sequenceName][index] = point
		end
	end

	for index, _ in pairs(originalSequence.Keypoints) do
		local point = ActiveWireTransfers[object][sequenceName][index]
		local isLast = index == numPoints
		local shouldWait = isLast and waitToKill
		if sequenceType == "NumberSequence" then
			Tweentown:Tween(point.Envelope, tweenInfo, {Value = newSequence.Keypoints[index].Envelope})
		end
		Tweentown:Tween(point.Value, tweenInfo, {Value = newSequence.Keypoints[index].Value})
		local tweenObject = Tweentown:Tween(point.Time, tweenInfo, {Value = newSequence.Keypoints[index].Time}, shouldWait):AndThen(function()
			if index == numPoints then
				for _, pointData in pairs(ActiveWireTransfers[object][sequenceName]) do
					pointData.Value:Destroy()
					pointData.Time:Destroy()
					if sequenceType == "NumberSequence" then
						pointData.Envelope:Destroy()
					end
				end

				ActiveWireTransfers[object][sequenceName] = nil

				local remainingTweens = 0
				for _, _ in pairs(ActiveWireTransfers[object]) do
					remainingTweens += 1
					break
				end
				if remainingTweens == 0 then
					ActiveWireTransfers[object] = nil
				end

				object[sequenceName] = newSequence
			end
		end)

		if isLast then return tweenObject end
	end
end

-- Public functions
function Tweentown:GetTweenFromInstance(object: Instance): Tween?
	return TweentownBank[object]
end

function Tweentown:Tween(object: Instance, tweenInfo: TweenInfo, properties: {}, waitToKill: boolean?): TweenChain
	if not object then
		warn("Tween failure - invalid object passed\n" .. debug.traceback())
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return TweenChain.new()
	end

	local isModel = object:IsA("Model")
	local alternativeTweenObject
	local normalCount = 0

	for property, newValue in pairs(properties) do
		local propertyType = typeof(object[property])
		if isModel and property == "CFrame" then
			alternativeTweenObject = tweenByPrimaryPart(object, tweenInfo, {CFrame = newValue})
			properties[property] = nil
		elseif propertyType == "ColorSequence" or propertyType == "NumberSequence" then
			alternativeTweenObject = tweenSequence(object, property, tweenInfo, newValue)
			properties[property] = nil
		else
			normalCount += 1
		end
	end

	if normalCount == 0 then
		if waitToKill then
			task.wait(tweenInfo.Time)
		end
		return alternativeTweenObject or TweenChain.new()
	end

	local thisTween = TweenService:Create(object, tweenInfo, properties)
	local tweenChain = TweenChain.new(thisTween)

	thisTween:Play()
	TweentownBank[object] = thisTween

	if waitToKill then
		murderTweenWhenDone(thisTween)
	else
		task.spawn(murderTweenWhenDone, thisTween)
	end

	return tweenChain :: TweenChain
end

return Tweentown
