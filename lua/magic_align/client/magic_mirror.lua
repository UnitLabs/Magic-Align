MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local core = client.ToolCore or include("magic_align/tool_config.lua")
local MagicMirror = M.MagicMirror or include("magic_align/magic_mirror.lua")

local copyVec = M.CopyVectorPrecise
local copyAng = M.CopyAnglePrecise

local mirrorClient = client.MagicMirror or {}
client.MagicMirror = mirrorClient
MagicMirror.Client = mirrorClient

local function playFeedback(tool, kind, wouldAffect, trace, options)
    local effects = M.ToolgunEffects
    if not effects or not isfunction(effects.DispatchFeedback) then return end

    if isfunction(effects.ResolveFeedbackKind) then
        kind = effects.ResolveFeedbackKind(kind, wouldAffect)
    elseif wouldAffect == false then
        kind = "fail"
    end

    return effects.DispatchFeedback(kind, tool, trace, nil, options)
end

local function shapeMirrorState(state)
    state = istable(state) and state or {}

    state.sessionId = tonumber(state.sessionId) or M.NextSessionId()
    state.toolMode = M.TOOL_MODE_MAGIC_MIRROR
    state._magicAlignTransientState = true
    state.activeSpace = M.MIRROR_SPACE
    state.source = state.source or {}
    state.target = state.target or {}
    state.linked = state.linked or {}
    state.anchorSelection = state.anchorSelection or {}
    state.mirror = state.mirror or {}
    state.mirror.points = state.mirror.points or {}
    state.mirror.enabled = true
    state.bounds = state.bounds or {}
    state.compatGhosts = state.compatGhosts or { linked = {} }
    state.compatGhosts.linked = state.compatGhosts.linked or {}
    state.linkedGhosts = state.linkedGhosts or {}

    return state
end

local function newMirrorState()
    return shapeMirrorState({
        sessionId = M.NextSessionId(),
        prop1 = nil,
        prop2 = nil,
        hover = nil,
        targetPose = nil,
        pending = nil,
        press = nil
    })
end

local function ensureState()
    local state = mirrorClient.ClientState or M.MagicMirrorClientState
    if not istable(state) then
        state = newMirrorState()
    end

    state = shapeMirrorState(state)

    if core.registerSessionState then
        core.registerSessionState(state)
    end

    mirrorClient.ClientState = state
    M.MagicMirrorClientState = state
    return state
end

function mirrorClient.state()
    return ensureState()
end

local function removeMirrorGhosts(state)
    if not istable(state) then return end

    if IsValid(state.ghost) then
        state.ghost:Remove()
    end
    state.ghost = nil

    if istable(state.linkedGhosts) then
        for ent, ghost in pairs(state.linkedGhosts) do
            if IsValid(ghost) then
                ghost:Remove()
            end
            state.linkedGhosts[ent] = nil
        end
    end

    if core.compatGhosts and isfunction(core.compatGhosts.clearAll) then
        core.compatGhosts.clearAll(state)
    end
end

local function dropHoverTarget(state)
    state.hover = nil
    state.prop1 = nil
    state.targetPose = nil
end

function mirrorClient.reset()
    local old = mirrorClient.ClientState or M.MagicMirrorClientState
    removeMirrorGhosts(old)

    local nextState = newMirrorState()
    mirrorClient.ClientState = nextState
    M.MagicMirrorClientState = nextState

    if core.registerSessionState then
        core.registerSessionState(nextState)
    end

    return nextState
end

local function activeToolState()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local getter = M.GetActiveMagicAlignFamilyTool or M.GetActiveMagicAlignTool
    local tool = getter and getter(ply) or nil
    if not tool or tool.Mode ~= M.TOOL_MODE_MAGIC_MIRROR then return end

    return tool, ensureState(), ply
end

mirrorClient.activeToolState = activeToolState

local function mirrorSettings(_, state)
    local settings = state._magicMirrorHoverSettings or {}
    state._magicMirrorHoverSettings = settings

    settings.shift = true
    settings.alt = false
    settings.gridA = 2
    settings.gridAMin = 2
    settings.gridB = 2
    settings.gridBMin = 2
    settings.gridBEnabled = false
    settings.minLength = 0
    settings.traceSnapLength = 0
    settings.translationSnap = 0
    settings.worldTarget = false
    settings.worldBspSnap = false
    settings.worldBspGridMode = "global"
    settings.worldBspGridSize = 16
    settings.worldBspBudgetMs = 0
    settings.worldBspIgnoreBrushBlockers = false
    settings.worldBspShowBlockers = false
    settings.worldBspFullGrid = false
    return settings
end

local function updateTargetPoseForZone(state, ent, candidate, zone)
    local targetPose = MagicMirror.TargetPose(ent, zone.axis, state.targetPose or {})
    if not targetPose or not M.IsFiniteVector(targetPose.pos) or not M.IsFiniteAngle(targetPose.ang) then
        state.targetPose = nil
        return false
    end

    targetPose.faceCandidate = candidate
    targetPose.zone = zone
    targetPose.linked = targetPose.linked or {}
    local linkedCount = 0
    for i = 1, #(state.linked or {}) do
        local linkedEnt = state.linked[i]
        if IsValid(linkedEnt) and linkedEnt ~= ent and M.IsProp(linkedEnt) then
            local linkedPose = MagicMirror.TargetPose(linkedEnt, zone.axis)
            if linkedPose and M.IsFiniteVector(linkedPose.pos) and M.IsFiniteAngle(linkedPose.ang) then
                linkedCount = linkedCount + 1
                local entry = targetPose.linked[linkedCount]
                if not istable(entry) then
                    entry = {}
                    targetPose.linked[linkedCount] = entry
                end

                entry.ent = linkedEnt
                entry.pos = copyVec(linkedPose.pos)
                entry.ang = copyAng(linkedPose.ang)
                entry.entityMirrorAxis = linkedPose.entityMirrorAxis
                entry.entityMirrorPreviewAxis = linkedPose.entityMirrorPreviewAxis
            end
        end
    end
    for i = linkedCount + 1, #targetPose.linked do
        targetPose.linked[i] = nil
    end

    state.prop1 = ent
    state.targetPose = targetPose
    return true
end

local function updateHover(tool, state)
    local ply = LocalPlayer()
    local tr = IsValid(ply) and ply:GetEyeTrace() or nil
    local ent = tr and tr.Entity or nil

    if not M.IsProp(ent) then
        dropHoverTarget(state)
        return
    end

    if core.requestBounds then
        core.requestBounds(state, ent)
    end

    local box = core.boundsFor and core.boundsFor(state, ent) or nil
    local candidate = box and core.faceCandidate and core.faceCandidate(ent, tr, mirrorSettings(tool, state), box) or nil
    local zone = MagicMirror.ClassifyCandidate(candidate)

    if not (candidate and zone and zone.axis and zone.axis ~= M.ENTITY_MIRROR_NONE) then
        dropHoverTarget(state)
        return
    end

    local hover = state._magicMirrorHover or {}
    state._magicMirrorHover = hover
    hover.rawTrace = tr
    hover.trace = tr
    hover.ent = ent
    hover.box = box
    hover.candidate = candidate
    hover.face = candidate.face
    hover.zone = zone
    hover.axis = zone.axis
    hover.axisLabel = zone.label
    state.hover = hover

    updateTargetPoseForZone(state, ent, candidate, zone)
end

local function buildSessionSnapshot(state)
    return M.CreateSessionSnapshot(state, {
        activeSpace = M.MIRROR_SPACE,
        lastNonMirrorTab = M.ClientLastNonMirrorSpace,
        actionType = "mirror",
        isMirrorAction = true,
        mode = M.COMMIT_MOVE,
        entityMirrorEnabled = true
    })
end

local function buildPayload(tool, state)
    local ent = state.hover and state.hover.ent
    local targetPose = state.targetPose
    if not IsValid(ent) or not istable(targetPose) then return end
    if not M.IsFiniteVector(targetPose.pos) or not M.IsFiniteAngle(targetPose.ang) then return end

    local ply = LocalPlayer()
    local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil
    if not IsValid(weapon) then return end

    local linked = {}
    local linkedTargets = {}
    local maxLinked = M.GetMaxLinkedProps()
    for i = 1, math.min(#(targetPose.linked or {}), maxLinked) do
        local entry = targetPose.linked[i]
        local linkedEnt = entry and entry.ent
        if IsValid(linkedEnt) and linkedEnt ~= ent and M.IsProp(linkedEnt)
            and M.IsFiniteVector(entry.pos) and M.IsFiniteAngle(entry.ang) then
            linked[#linked + 1] = linkedEnt
            linkedTargets[#linkedTargets + 1] = {
                pos = copyVec(entry.pos),
                ang = copyAng(entry.ang)
            }
        end
    end

    return {
        prop1 = ent,
        prop2 = nil,
        toolEnt = weapon,
        startPos = copyVec(ent:GetPos()),
        startAng = copyAng(ent:GetAngles()),
        pos = copyVec(targetPose.pos),
        ang = copyAng(targetPose.ang),
        source = {},
        target = {},
        linked = linked,
        linkedTargets = linkedTargets,
        absoluteLinked = true,
        sessionSnapshot = buildSessionSnapshot(state),
        weld = false,
        nocollide = false,
        parent = false,
        mode = M.COMMIT_MOVE,
        entityMirrorAxis = targetPose.entityMirrorAxis or M.ENTITY_MIRROR_NONE
    }
end

local function commit(tool, state, trace)
    if not (state and state.hover and state.targetPose) then
        playFeedback(tool, "fail", false, trace)
        return false
    end

    local payload = buildPayload(tool, state)
    if not payload then
        playFeedback(tool, "fail", false, trace)
        return false
    end

    if not (isfunction(core.beginCommitUpload) and core.beginCommitUpload(tool, payload, true)) then
        playFeedback(tool, "fail", false, trace)
        return false
    end

    playFeedback(tool, "mirrorCommit", true, trace or state.hover.trace)
    return true
end

function mirrorClient.queueClick(tool, trace)
    local state = ensureState()
    state.leftClickQueued = true
    state.leftClickQueuedAt = RealTime()
    state.leftClickTrace = trace
    return true
end

function mirrorClient.handleClientAction(_, trace)
    local tool, state = activeToolState()
    if not tool or not state then return false end

    state.leftClickQueued = true
    state.leftClickQueuedAt = RealTime()
    state.leftClickTrace = trace
    return true
end

local function consumeQueuedClick(tool, state)
    local queued = state.leftClickQueued == true
        and RealTime() - (tonumber(state.leftClickQueuedAt) or 0) <= 0.25
    local trace = state.leftClickTrace

    state.leftClickQueued = false
    state.leftClickQueuedAt = nil
    state.leftClickTrace = nil

    if not queued then return end
    if core.uiBlocked and core.uiBlocked() then
        playFeedback(tool, "fail", false, trace)
        return
    end

    commit(tool, state, trace)
end

function TOOL:Think()
    local tool, state = activeToolState()
    if tool ~= self or not state then return end

    updateHover(self, state)
    consumeQueuedClick(self, state)
end

function TOOL:Holster()
    removeMirrorGhosts(mirrorClient.ClientState)
end

hook.Remove("Think", "MagicMirrorHideGhostWhenInactive")
hook.Remove("Think", "MagicMirrorCleanupGhostWhenInactive")
hook.Add("Think", "MagicMirrorCleanupGhostWhenInactive", function()
    local tool, state = activeToolState()
    if tool and state then return end

    state = mirrorClient.ClientState or M.MagicMirrorClientState
    removeMirrorGhosts(state)
end)

hook.Remove("EntityRemoved", "MagicMirrorResetOnPropRemove")
hook.Add("EntityRemoved", "MagicMirrorResetOnPropRemove", function(ent)
    local state = mirrorClient.ClientState or M.MagicMirrorClientState
    if not state or ent ~= state.prop1 then return end

    mirrorClient.reset()
end)

return mirrorClient
