--[[
class Spring

Description:
	A physical model of a spring, useful in many applications. Properties only evaluate
	upon index making this model good for lazy applications

API:
	Spring = Spring.new(number position)
		Creates a new spring in 1D
	Spring = Spring.new(Vector3 position)
		Creates a new spring in 3D

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

	Spring.Target = number/Vector3
		Sets the target
	Spring.Position = number/Vector3
		Sets the position
	Spring.Velocity = number/Vector3
		Sets the velocity
	Spring.Damper = number [0, 1]
		Sets the spring damper, defaults to 1
	Spring.Speed = number [0, infinity)
		Sets the spring speed, defaults to 1

	Spring:TimeSkip(number DeltaTime)
		Instantly skips the spring forwards by that amount of now
	Spring:Impulse(number/Vector3 velocity)
		Impulses the spring, increasing velocity by the amount given

Visualization (by Defaultio):
	https://www.desmos.com/calculator/hn2i9shxbz
]]


local Spring = {}

local EULER = 2.7182818284590452353602874713527

--- Creates a new spring
-- @param initial A number or Vector3 (anything with * number and addition/subtraction defined)
-- @param[opt=os.clock] clock function to use to update spring
function Spring.new(initial, clock)
	local target = initial or 0
	clock = clock or os.clock
	return setmetatable({
		_clock = clock;
		_time0 = clock();
		_position0 = target;
		_velocity0 = 0*target;
		_target = target;
		_damper = 1;
		_speed = 1;
	}, Spring)
end

--- Impulse the spring with a change in velocity
-- @param velocity The velocity to impulse with
function Spring:Impulse(velocity)
	self.Velocity = self.Velocity + velocity
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
	local startPosition = self._position0
	local startVelocity = self._velocity0
	local targetPosition = self._target
	local damper = self._damper
	local speed = self._speed

	local t = speed*(now - self._time0)
	local damperSquared = damper * damper

	local h, sin, cosine
	if damperSquared < 1 then
		h = (1 - damperSquared) ^ 0.5
		local ep = EULER ^ ((-damper * t)) / h
		cosine, sin = ep * math.cos(h * t), ep * math.sin(h * t)
	elseif damperSquared == 1 then
		h = 1
		local ep = EULER ^ ((-damper * t)) / h
		cosine, sin = ep, ep*t
	else
		h = (damperSquared - 1) ^ 0.5
		local u = EULER ^ (((-damper + h) * t)) / (2 * h)
		local v = EULER ^ (((-damper - h) * t)) / (2 * h)
		cosine, sin = u + v, u - v
	end

	local cosH = h * cosine
	local damperSin = damper * sin

	local a = cosH + damperSin
	local b = speed * sin

	return
		a * startPosition + (1 - a) * targetPosition + (sin / speed) * startVelocity,
		-b * startPosition + b * targetPosition + (cosH - damperSin) * startVelocity
end

return Spring
