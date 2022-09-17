--[[
class Spring

Description:
	A physical model of a spring, useful in many applications. Properties only
	evaluate upon index making this model good for lazy applications. Originally
	by Quenty, modified by TactBacon and ChiefWildin for additional type support
	and to make it more readable.

API:
	Spring.new(position: Vector3 | Vector2 | number | UDim2 | UDim | CFrame | Color3)
		Creates a new spring

	Spring.Position
		Returns the current position
	Spring.Velocity
		Returns the current velocity
	Spring.Target
		Returns the target
	Spring.Damper
		Returns the damper
	Spring.Speed
		Returns the speed

	Spring.Target: Vector3 | Vector2 | number | UDim2 | UDim | CFrame | Color3
		Sets the target
	Spring.Position: Vector3 | Vector2 | number | UDim2 | UDim | CFrame | Color3
		Sets the position
	Spring.Velocity: Vector3 | Vector2 | number | UDim2 | UDim | CFrame | Color3
		Sets the velocity
	Spring.Damper = number [0, 1]
		Sets the spring damper, defaults to 1
	Spring.Speed = number [0, infinity)
		Sets the spring speed, defaults to 1

	Spring:TimeSkip(number DeltaTime)
		Instantly skips the spring forwards by that amount of now
	Spring:Impulse(velocity: Vector3 | Vector2 | number | UDim2 | UDim | CFrame | Color3)
		Impulses the spring, increasing velocity by the amount given

Visualization (by Defaultio):
	https://www.desmos.com/calculator/hn2i9shxbz
]]


local Spring = {}

type Springable = Vector3 | Vector2 | number | UDim2 | UDim | CFrame | Color3
export type Spring = {
	Position: Springable,
	Velocity: Springable,
	Target: Springable,
	Damper: number,
	Speed: number,
	Clock: () -> number,
	Type: string,
	Impulse: (Spring, force: Springable) -> (),
	TimeSkip: (Spring, delta: number) -> (),
	_positionVelocity: (Spring, number) -> (Springable, Springable)
}

local EULER = 2.7182818284590452353602874713527
local ZEROS = {
	["number"] = 0,
	["Vector2"] = Vector2.zero,
	["Vector3"] = Vector3.zero,
	["UDim2"] = UDim2.new(),
	["UDim"] = UDim.new(),
	["CFrame"] = CFrame.identity,
	["Color3"] = Color3.new(),
}

-- Aliases (for super speeeeeeeeed)
local clamp = math.clamp
local cos = math.cos
local sin = math.sin
local udim2 = UDim2.new
local udim = UDim.new
local color3 = Color3.new
local cframe = CFrame.new
local cframeFromAxis = CFrame.fromAxisAngle

local function directConversion(a, b, sine, cosH, damperSin, speed, start, velocity, target)
	return a * start + (1 - a) * target + (sine / speed) * velocity,
		-b * start + b * target + (cosH - damperSin) * velocity
end

local Converters = {
	["number"] = directConversion,
	["Vector2"] = directConversion,
	["Vector3"] = directConversion,
	["UDim2"] = function(a, b, sin, cosH, damperSin, speed, start, velocity, target)
		local c = 1 - a
		local d = sin / speed
		local e = cosH - damperSin
		return
			udim2(
				a * start.X.Scale + c * target.X.Scale + d * velocity.X.Scale,
				a * start.X.Offset + c * target.X.Offset + d * velocity.X.Offset,
				a * start.Y.Scale + c * target.Y.Scale + d * velocity.Y.Scale,
				a * start.Y.Offset + c * target.Y.Offset + d * velocity.Y.Offset
			),
			udim2(
				-b * start.X.Scale + b * target.X.Scale + e * velocity.X.Scale,
				-b * start.X.Offset + b * target.X.Offset + e * velocity.X.Offset,
				-b * start.Y.Scale + b * target.Y.Scale + e * velocity.Y.Scale,
				-b * start.X.Offset + b * target.X.Offset + e * velocity.X.Offset
			)
	end,
	["UDim"] = function(a, b, sine, cosH, damperSin, speed, start, velocity, target)
		local c = 1 - a
		local d = sine / speed
		local e = cosH - damperSin
		return
			udim(
				a * start.Scale + c * target.Scale + d * velocity.Scale,
				a * start.Offset + c * target.Offset + d * velocity.Offset
			),
			udim(
				-b * start.Scale + b * target.Scale + e * velocity.Scale,
				-b * start.Offset + b * target.Offset + e * velocity.Offset
			)
	end,
	["CFrame"] = function(a, b, sine, cosH, damperSin, speed, start: CFrame, velocity: CFrame, target: CFrame)
		local c = 1 - a
		local d = sine / speed
		local e = cosH - damperSin
		local startAngleVector, startAngleRot = start:ToAxisAngle()
		local velocityAngleVector, velocityAngleRot = velocity:ToAxisAngle()
		local targetAngleVector, targetAngleRot = target:ToAxisAngle()
		return
			cframe(a * start.Position + c * target.Position + d * velocity.Position) *
			cframeFromAxis(
				a * startAngleVector + c * targetAngleVector + d * velocityAngleVector,
				a * startAngleRot + c * targetAngleRot + d * velocityAngleRot
			),
			cframe(-b * start.Position + b * target.Position + e * velocity.Position) *
			cframeFromAxis(
				-b * startAngleVector + b * targetAngleVector + e * velocityAngleVector,
				-b * startAngleRot + b * targetAngleRot + e * velocityAngleRot
			)
	end,
	["Color3"] = function(a, b, sine, cosH, damperSin, speed, start: Color3, velocity: Color3, target: Color3)
		local c = 1 - a
		local d = sine / speed
		local e = cosH - damperSin
		return
			color3(
				clamp(a * start.R + c * target.R + d * velocity.R, 0, 1),
				clamp(a * start.G + c * target.G + d * velocity.G, 0, 1),
				clamp(a * start.B + c * target.B + d * velocity.B, 0, 1)
			),
			color3(
				clamp(-b * start.R + b * target.R + e * velocity.R, 0, 1),
				clamp(-b * start.G + b * target.G + e * velocity.G, 0, 1),
				clamp(-b * start.B + b * target.B + e * velocity.B, 0, 1)
			)
	end
}

local function directVelocity(self, velocity)
	self.Velocity += velocity
end

local VelocityConverters = {
	["number"] = directVelocity,
	["Vector2"] = directVelocity,
	["Vector3"] = directVelocity,
	["UDim2"] = directVelocity,
	["UDim"] = directVelocity,
	["CFrame"] = function(self, velocity)
		self.Velocity *= velocity
	end,
	["Color3"] = function(self, velocity)
		self.Velocity = color3(
			self.Velocity.R + velocity.R,
			self.Velocity.G + velocity.G,
			self.Velocity.B + velocity.B
		)
	end
}

--- Creates a new spring
-- @param initial A number or Vector3 (anything with * number and addition/subtraction defined)
-- @param [opt=os.clock] clock function to use to update spring
function Spring.new(initial, clock)
	local target = initial or 0
	clock = clock or os.clock
	return setmetatable({
		_clock = clock,
		_time0 = clock(),
		_position0 = target,
		_velocity0 = ZEROS[typeof(initial)],
		_target = target,
		_damper = 1,
		_speed = 1,
		_type = typeof(initial)
	}, Spring)
end

--- Impulse the spring with a change in velocity
-- @param velocity The velocity to impulse with
function Spring:Impulse(velocity)
	VelocityConverters[self.Type](self, velocity)
end

--- Skip forwards in now
-- @param delta now to skip forwards
function Spring:TimeSkip(delta)
	local now = self._clock()
	local position, velocity = self:_positionVelocity(now+delta)
	self._position0 = position
	self._velocity0 = velocity
	self._time0 = now
end

function Spring:__index(index)
	if Spring[index] then
		return Spring[index]
	elseif index == "Value" or index == "Position" or index == "p" then
		local position, _ = self:_positionVelocity(self._clock())
		return position
	elseif index == "Velocity" or index == "v" then
		local _, velocity = self:_positionVelocity(self._clock())
		return velocity
	elseif index == "Target" or index == "t" then
		return self._target
	elseif index == "Damper" or index == "d" then
		return self._damper
	elseif index == "Speed" or index == "s" then
		return self._speed
	elseif index == "Clock" then
		return self._clock
	elseif index == "Type" then
		return self._type
	else
		error(("%q is not a valid member of Spring"):format(tostring(index)), 2)
	end
end

function Spring:__newindex(index, value)
	local now = self._clock()

	if index == "Value" or index == "Position" or index == "p" then
		local _, velocity = self:_positionVelocity(now)
		self._position0 = value
		self._velocity0 = velocity
		self._time0 = now
	elseif index == "Velocity" or index == "v" then
		local position, _ = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = value
		self._time0 = now
	elseif index == "Target" or index == "t" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._target = value
		self._time0 = now
	elseif index == "Damper" or index == "d" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._damper = value
		self._time0 = now
	elseif index == "Speed" or index == "s" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._speed = value < 0 and 0 or value
		self._time0 = now
	elseif index == "Clock" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._clock = value
		self._time0 = value()
	else
		error(("%q is not a valid member of Spring"):format(tostring(index)), 2)
	end
end

function Spring:_positionVelocity(now)
	local damper = self._damper
	local speed = self._speed

	local t = speed * (now - self._time0)
	local damperSquared = damper * damper

	local h, sine, cosine
	if damperSquared < 1 then
		h = (1 - damperSquared) ^ 0.5
		local ep = EULER ^ ((-damper * t)) / h
		cosine = ep * cos(h * t)
		sine = ep * sin(h * t)
	elseif damperSquared == 1 then
		h = 1
		local ep = EULER ^ ((-damper * t)) / h
		cosine = ep
		sine = ep * t
	else
		h = (damperSquared - 1) ^ 0.5
		local u = EULER ^ (((-damper + h) * t)) / (2 * h)
		local v = EULER ^ (((-damper - h) * t)) / (2 * h)
		cosine = u + v
		sine = u - v
	end

	local cosH = h * cosine
	local damperSin = damper * sine

	local a = cosH + damperSin
	local b = speed * sine

	return Converters[self._type](a, b, sine, cosH, damperSin, speed, self._position0, self._velocity0, self._target)
end

return Spring
