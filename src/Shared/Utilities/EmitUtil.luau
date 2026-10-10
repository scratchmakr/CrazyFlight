local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local AttributeType = require(ReplicatedStorage.Shared.Types.AttributeType)

local emit = {}

local ongoingEmissions: {[ParticleEmitter]: number} = {}
local hydratedEmitters: {[ParticleEmitter]: boolean} = {}

local heartbeatConnection: RBXScriptConnection?

local function maybeDisconnectHeartbeat()
	if heartbeatConnection and next(ongoingEmissions) == nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function ensureHeartbeat()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		local toRemove: {ParticleEmitter} = {}

		for particleEmitter, timeLeft in ongoingEmissions do
			if particleEmitter.Parent == nil or not particleEmitter:IsDescendantOf(game) then
				table.insert(toRemove, particleEmitter)
			else
				local newTime = timeLeft - dt

				if newTime <= 0 then
					particleEmitter.Enabled = false
					table.insert(toRemove, particleEmitter)
				else
					ongoingEmissions[particleEmitter] = newTime
					particleEmitter.Enabled = true
				end
			end
		end

		for _, particleEmitter in toRemove do
			ongoingEmissions[particleEmitter] = nil
		end

		maybeDisconnectHeartbeat()
	end)
end

function emit.oneTimeEmit(particleEmitter: ParticleEmitter, emitAmount: number)
	-- print("oneTimeEmit", particleEmitter, emitAmount)
	particleEmitter:Emit(emitAmount)
end

function emit.longEmit(particleEmitter: ParticleEmitter, length: number)
	if not hydratedEmitters[particleEmitter] then
		hydratedEmitters[particleEmitter] = true

		Fusion.Hydrate(particleEmitter) {
			[Fusion.Cleanup] = function()
				hydratedEmitters[particleEmitter] = nil
				ongoingEmissions[particleEmitter] = nil

				maybeDisconnectHeartbeat()

				if particleEmitter.Parent then
					particleEmitter.Enabled = false
				end
			end,
		}
	end

	ongoingEmissions[particleEmitter] = (ongoingEmissions[particleEmitter] or 0) + length
	particleEmitter.Enabled = true

	ensureHeartbeat()
end

function emit.emitDescendants(
	ancestor: Instance,
	emitFunction: "oneTime" | "long"
): (number?) -> nil
	assert(typeof(ancestor) == "Instance", "ancestor must be an Instance")

	local correspondingFunction = emitFunction == "oneTime"
		and emit.oneTimeEmit
		or emit.longEmit

	assert(
		typeof(correspondingFunction) == "function",
		'emitFunction must be "oneTime" or "long"'
	)

	return function(setting: number?)
		for _, particleEmitter in ancestor:GetDescendants() do
			if particleEmitter:IsA("ParticleEmitter") then
				local emitCount = setting or particleEmitter:GetAttribute(AttributeType.EmitCount)
				correspondingFunction(particleEmitter, emitCount)
			end
		end
	end
end

function emit.stopEmit(particleEmitter: ParticleEmitter)
	if ongoingEmissions[particleEmitter] ~= nil then
		ongoingEmissions[particleEmitter] = nil
		particleEmitter.Enabled = false

		maybeDisconnectHeartbeat()
	end
end

function emit.stopEmitDescendants(ancestor: Instance)
	for _, particleEmitter in ancestor:GetDescendants() do
		if particleEmitter:IsA("ParticleEmitter") then
			emit.stopEmit(particleEmitter)
		end
	end
end

function emit.unpackEmitters(ancestor: Instance, target: Instance)
	for _, particleEmitter in ancestor:GetDescendants() do
		if particleEmitter:IsA("ParticleEmitter") then
			local newParticleEmitter = particleEmitter:Clone()
			newParticleEmitter.Parent = target
		end
	end
end

return emit