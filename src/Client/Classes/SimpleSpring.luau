export type ValueType = number | Vector3

export type Context = {
	targetValue: ValueType,
	currentValue: ValueType,

	speed: number,
	damping: number,

	velocity: ValueType?,
}

local SimpleSpring = {}
SimpleSpring.__index = SimpleSpring

local function zeroValue(value: ValueType): ValueType
	if typeof(value) == "Vector3" then
		return Vector3.zero
	end

	return 0
end

function SimpleSpring.new(context: Context)
	assert(
		typeof(context.targetValue) == typeof(context.currentValue),
		"targetValue and currentValue must be the same type"
	)

	local damping = math.clamp(context.damping, 0, 1)

	local self = setmetatable({
		targetValue = context.targetValue,
		currentValue = context.currentValue,

		velocity = context.velocity or zeroValue(context.currentValue),

		speed = context.speed,
		damping = damping,

		_startValue = context.currentValue,
		_startVelocity = context.velocity or zeroValue(context.currentValue),
		_startTime = os.clock(),
	}, SimpleSpring)

	return self
end

export type Self = typeof(SimpleSpring.new(...))

function SimpleSpring._calculate(self: Self, elapsedTime: number): (ValueType, ValueType)
	local target = self.targetValue :: any
	local startValue = self._startValue :: any
	local startVelocity = self._startVelocity :: any

	local speed = self.speed
	local damping = self.damping

	if speed <= 0 then
		return startValue, startVelocity
	end

	local displacement = startValue - target

	-- Critical damping
	if damping >= 1 then
		local exponential = math.exp(-speed * elapsedTime)

		local a = displacement
		local b = startVelocity + speed * displacement

		local position =
			target
			+ (a + b * elapsedTime) * exponential

		local velocity =
			(
				b
				- speed * (a + b * elapsedTime)
			) * exponential

		return position, velocity
	end

	-- Underdamped spring
	local dampedFrequency =
		speed * math.sqrt(1 - damping * damping)

	local exponential =
		math.exp(-damping * speed * elapsedTime)

	local cosine =
		math.cos(dampedFrequency * elapsedTime)

	local sine =
		math.sin(dampedFrequency * elapsedTime)

	local a = displacement

	local b =
		(
			startVelocity
				+ damping * speed * displacement
		)
		/ dampedFrequency

	local position =
		target
		+ exponential
			* (
				a * cosine
					+ b * sine
			)

	local velocity =
		exponential
		* (
			-damping
				* speed
				* (a * cosine + b * sine)
			+ dampedFrequency
				* (-a * sine + b * cosine)
		)

	return position, velocity
end

function SimpleSpring.update(self: Self): ValueType
	local elapsedTime = os.clock() - self._startTime

	local position, velocity =
		self:_calculate(elapsedTime)

	self.currentValue = position
	self.velocity = velocity

	return position
end

function SimpleSpring.setTarget(self: Self, targetValue: ValueType)
	if targetValue == self.targetValue then
		return
	end

	self:update()

	self._startValue = self.currentValue
	self._startVelocity = self.velocity

	self.targetValue = targetValue
	self._startTime = os.clock()
end

function SimpleSpring.setValue(self: Self, value: ValueType)
	assert(
		typeof(value) == typeof(self.targetValue),
		"value must match spring value type"
	)

	local zero = zeroValue(value)

	self.currentValue = value
	self.targetValue = value

	self.velocity = zero

	self._startValue = value
	self._startVelocity = zero

	self._startTime = os.clock()
end

function SimpleSpring.impulse(self: Self, velocity: ValueType)
	assert(
		typeof(velocity) == typeof(self.velocity),
		"impulse must match spring value type"
	)

	self:update()

	self.velocity = (self.velocity :: any) + (velocity :: any)

	self._startValue = self.currentValue
	self._startVelocity = self.velocity
	self._startTime = os.clock()
end

return SimpleSpring