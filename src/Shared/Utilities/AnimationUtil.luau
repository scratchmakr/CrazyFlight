local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local ImpactFrame = require(StarterPlayer.StarterPlayerScripts.Client.Classes.Effects.ImpactFrame)
local EmitUtil = require(script.Parent.EmitUtil)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Assets = ReplicatedStorage.Assets
local AnimationAssets = Assets.Animations

local AnimationUtil = {
    _eventConnections = {} :: { [AnimationTrack]: { [string]: RBXScriptConnection } },
    _completionThreads = {} :: { [AnimationTrack]: thread },
}

local ANIMATION_LOAD_TIMEOUT = 5

local ANIMATION_EVENT_TYPES = {
    VFX_SHORT = "vfx:short",
    VFX_LONG_START = "vfx:longstart",
    VFX_LONG_END = "vfx:longend",
    IMPACT_FRAME = "impactframe",
}

AnimationUtil.ANIMATION_EVENT_TYPES = ANIMATION_EVENT_TYPES

local ANIMATION_EVENT_CALLBACKS = {
    [ANIMATION_EVENT_TYPES.VFX_SHORT] = function(vfxName: any, ancestor: Model)
        local vfxAttachment = ancestor:FindFirstChild(vfxName, true)
        if not vfxAttachment then
            return
        end

        EmitUtil.emitDescendants(vfxAttachment, "oneTime")()
    end,

    [ANIMATION_EVENT_TYPES.VFX_LONG_START] = function(vfxName: any, ancestor: Model)
        local vfxAttachment = ancestor:FindFirstChild(vfxName, true)
        if not vfxAttachment then
            return
        end

        EmitUtil.emitDescendants(vfxAttachment, "long")(math.huge)
    end,

    [ANIMATION_EVENT_TYPES.VFX_LONG_END] = function(vfxName: any, ancestor: Model)
        local vfxAttachment = ancestor:FindFirstChild(vfxName, true)
        if not vfxAttachment then
            return
        end

        EmitUtil.stopEmitDescendants(vfxAttachment)
    end,

    [ANIMATION_EVENT_TYPES.IMPACT_FRAME] = function(presetType: string)
        local impactFrame = ImpactFrame.new({
            preset = presetType,
        })

        impactFrame:start()

        task.delay(1, function()
            impactFrame:destroy()
        end)
    end,
}

export type AnimationContext = {
    animationTrack: AnimationTrack,
    ancestor: Model?,
    speed: number?,
    fadeTime: number?,
    freezeOnComplete: boolean?,
    onComplete: (() -> ())?,
    override: boolean?,
}

function AnimationUtil.getAnimation(id: string): Animation?
    local animation = AnimationAssets:FindFirstChild(id, true)

    if not animation or not animation:IsA("Animation") then
        return nil
    end

    return animation
end

function AnimationUtil.loadAnimation(
    model: Model,
    animation: Animation,
    looped: boolean?
): AnimationTrack
    local animationController =
        model:FindFirstChildOfClass("AnimationController")
        or model:FindFirstChildOfClass("Humanoid")
        or Fusion.New("AnimationController") {
            Parent = model,
        }

    local animator =
        animationController:FindFirstChildOfClass("Animator")
        or Fusion.New("Animator") {
            Parent = animationController,
        }

    local animationTrack = animator:LoadAnimation(animation)
    animationTrack.Looped = looped == true

    Fusion.Hydrate(animationTrack) {
        [Fusion.Cleanup] = function()
            AnimationUtil.cleanup(animationTrack)

            if animationTrack then
                animationTrack:Destroy()
            end
        end,
    }

    return animationTrack
end

function AnimationUtil.cleanupEventConnections(animationTrack: AnimationTrack)
    local connections = AnimationUtil._eventConnections[animationTrack]
    if not connections then
        return
    end

    -- Remove the AnimationTrack key itself.
    -- This is important so AnimationUtil doesn't retain old tracks forever.
    AnimationUtil._eventConnections[animationTrack] = nil

    for _, connection in connections do
        if connection.Connected then
            connection:Disconnect()
        end
    end

    table.clear(connections)
end

function AnimationUtil.cleanupCompletionThread(animationTrack: AnimationTrack)
    local completionThread = AnimationUtil._completionThreads[animationTrack]
    if not completionThread then
        return
    end

    AnimationUtil._completionThreads[animationTrack] = nil

    if coroutine.status(completionThread) ~= "dead" then
        task.cancel(completionThread)
    end
end

function AnimationUtil.cleanup(animationTrack: AnimationTrack)
    AnimationUtil.cleanupEventConnections(animationTrack)
    AnimationUtil.cleanupCompletionThread(animationTrack)
end

function AnimationUtil.listenForEvent(
    animationTrack: AnimationTrack,
    eventType: string,
    callback: ((parameter: any) -> ())?
): RBXScriptConnection?
    if not animationTrack then
        warn("Animation track is nil!")
        return nil
    end

    local desiredCallback = callback or ANIMATION_EVENT_CALLBACKS[eventType]

    if not desiredCallback then
        warn(`Could not find callback for event type {eventType}!`)
        return nil
    end

    return animationTrack:GetMarkerReachedSignal(eventType):Connect(function(parameter: any)
        desiredCallback(parameter)
    end)
end

function AnimationUtil.setupEventConnections(
    animationTrack: AnimationTrack,
    ancestor: Model
)
    AnimationUtil.cleanupEventConnections(animationTrack)

    local connections = {}
    AnimationUtil._eventConnections[animationTrack] = connections

    for _, eventType in ANIMATION_EVENT_TYPES do
        local callback = ANIMATION_EVENT_CALLBACKS[eventType]
        if not callback then
            continue
        end

        local eventConnection = AnimationUtil.listenForEvent(
            animationTrack,
            eventType,
            function(parameter: any)
                if not ancestor.Parent then
                    return
                end

                callback(parameter, ancestor)
            end
        )

        if eventConnection then
            connections[eventType] = eventConnection
        end
    end

    -- IMPORTANT:
    -- Automatically release marker connections when playback stops.
    connections._stopped = animationTrack.Stopped:Connect(function()
        AnimationUtil.cleanupEventConnections(animationTrack)
    end)
end

local function waitForAnimationLength(animationTrack: AnimationTrack): number?
    local startTime = os.clock()

    while animationTrack.Length <= 0 do
        if os.clock() - startTime >= ANIMATION_LOAD_TIMEOUT then
            warn(
                `Animation failed to load within {ANIMATION_LOAD_TIMEOUT} seconds`,
                animationTrack.Animation
            )

            return nil
        end

        task.wait()
    end

    return animationTrack.Length
end

function AnimationUtil.playAnimation(context: AnimationContext)
    local animationTrack = context.animationTrack
    local speed = context.speed or 1
    local fadeTime = context.fadeTime or 0
    local ancestor = context.ancestor

    if not animationTrack then
        warn("Animation track is nil!")
        return
    end

    -- If this track was already being used, remove anything left over from
    -- its previous playback before starting it again.
    AnimationUtil.cleanup(animationTrack)

    if ancestor then
        AnimationUtil.setupEventConnections(animationTrack, ancestor)
    end

    animationTrack:Play(fadeTime, 1, speed)

    local requiresCompletionThread =
        typeof(context.onComplete) == "function"
        or context.freezeOnComplete == true

    if not requiresCompletionThread then
        return
    end

    local completionThread

    completionThread = task.spawn(function()
        local loadStartTime = os.clock()
        local animationLength = waitForAnimationLength(animationTrack)

        if not animationLength then
            if AnimationUtil._completionThreads[animationTrack] == completionThread then
                AnimationUtil._completionThreads[animationTrack] = nil
            end

            return
        end

        -- Account for however much time was spent waiting for the asset
        -- to report its length.
        local loadTime = os.clock() - loadStartTime

        -- AnimationTrack.Length is based on speed 1.
        local absoluteSpeed = math.abs(speed)

        if absoluteSpeed <= 0 then
            absoluteSpeed = 1
        end

        local playbackDuration = animationLength / absoluteSpeed
        local timeUntilComplete = math.max(playbackDuration - loadTime, 0)

        if context.freezeOnComplete then
            local freezeDelay = timeUntilComplete * 0.95

            if freezeDelay > 0 then
                task.wait(freezeDelay)
            end

            -- Make sure this is still the current completion task.
            if AnimationUtil._completionThreads[animationTrack] ~= completionThread then
                return
            end

            animationTrack:AdjustSpeed(0)

            local remainingTime = math.max(timeUntilComplete - freezeDelay, 0)

            if remainingTime > 0 then
                task.wait(remainingTime)
            end
        else
            if timeUntilComplete > 0 then
                task.wait(timeUntilComplete)
            end
        end

        -- The track might have been replayed/stopped while we were waiting.
        if AnimationUtil._completionThreads[animationTrack] ~= completionThread then
            return
        end

        AnimationUtil._completionThreads[animationTrack] = nil

        if typeof(context.onComplete) == "function" then
            context.onComplete()
        end

        -- For non-looped animations we no longer need marker connections
        -- after playback completes.
        if not animationTrack.Looped then
            AnimationUtil.cleanupEventConnections(animationTrack)
        end
    end)

    AnimationUtil._completionThreads[animationTrack] = completionThread
end

function AnimationUtil.stopAnimation(
    animationTrack: AnimationTrack,
    fadeTime: number?
)
    if not animationTrack then
        warn("Animation track is nil!")
        return
    end

    -- Cancel callbacks/listeners first so nothing belonging to this playback
    -- continues running after Stop().
    AnimationUtil.cleanup(animationTrack)

    animationTrack:Stop(fadeTime or 0)
end

return AnimationUtil