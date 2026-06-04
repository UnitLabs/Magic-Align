MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local geometry = client.geometry or {}
client.geometry = geometry
local core = client.ToolCore or include("magic_align/tool_config.lua")
local isvector = M.IsVectorLike
local isangle = M.IsAngleLike
local toAngle = M.ToAngle
local compatGhosts = core.compatGhosts
local TOOL_UI = core.TOOL_UI
local PICK_CONFIG = core.PICK_CONFIG
local SESSION_CONFIG = core.SESSION_CONFIG

local function pointWorldCacheForAction(...)
    if isfunction(core.pointWorldCache) then
        return core.pointWorldCache(...)
    end
end
local function writeClientActionTrace(trace)
    local ent = trace and trace.Entity or NULL
    local hitPos = trace and trace.HitPos or nil
    local hitNormal = trace and trace.HitNormal or nil
    local hitWorld = trace ~= nil and (trace.HitWorld == true or (IsValid(ent) and ent.IsWorld and ent:IsWorld())) or false
    local physBone = math.Clamp(math.floor(tonumber(trace and trace.PhysicsBone) or 0), 0, 65535)

    net.WriteEntity(IsValid(ent) and ent or NULL)
    net.WriteBool(trace ~= nil and trace.Hit == true or isvector(hitPos))
    net.WriteBool(isvector(hitPos))
    if isvector(hitPos) then
        net.WritePreciseVector(hitPos)
    end
    net.WriteBool(isvector(hitNormal))
    if isvector(hitNormal) then
        net.WritePreciseVector(hitNormal)
    end
    net.WriteBool(hitWorld)
    net.WriteUInt(physBone, 16)
end

local function sendClientAction(ply, action, trace)
    if CLIENT or not IsValid(ply) then return end

    net.Start(M.NET_CLIENT_ACTION)
        net.WriteUInt(action, 2)
        writeClientActionTrace(trace)
    net.Send(ply)
end

function client.activeSpace()
    if not CLIENT then return end

    local ply = LocalPlayer()
    local getter = M.GetActiveClassicMagicAlignTool or M.GetActiveMagicAlignTool
    local tool = IsValid(ply) and getter(ply) or nil
    if tool and tool.GetClientInfo then
        return tool:GetClientInfo("space")
    end
end

local function isMirrorSpace(space)
    return M.IsMirrorMode and M.IsMirrorMode(space) or space == M.MIRROR_SPACE
end

local function isUiSpace(space)
    for i = 1, #(M.UI_SPACES or M.SPACES or {}) do
        if (M.UI_SPACES or M.SPACES)[i] == space then
            return true
        end
    end

    return false
end

local function rememberNonMirrorSpace(state, space)
    if not isUiSpace(space) or isMirrorSpace(space) then return end

    M.ClientLastNonMirrorSpace = space
    if istable(state) then
        state.lastNonMirrorSpace = space
    end
end

local function setClientActiveSpace(space, state)
    if not isUiSpace(space) then return false end

    RunConsoleCommand("magic_align_space", space)
    rememberNonMirrorSpace(state or M.ClientState, space)

    if IsValid(M.ClientSheet) and M.ClientTabs then
        local activeTab = M.ClientTabs[space]
        if IsValid(activeTab) then
            M.ClientSheet:SetActiveTab(activeTab)
        end
    end

    return true
end

local function clearSessionVisuals(state)
    if state and IsValid(state.ghost) then
        state.ghost:Remove()
    end
    if state and istable(state.linkedGhosts) then
        for _, ghost in pairs(state.linkedGhosts) do
            if IsValid(ghost) then
                ghost:Remove()
            end
        end
    end
    if state then
        compatGhosts.clearAll(state)
    end
end

local function editable(state, ent, tr, space)
    if M.IsMirrorMode and M.IsMirrorMode(space) then
        if not IsValid(state.prop1) then return end

        state.mirror = state.mirror or { points = {} }
        state.mirror.points = state.mirror.points or {}

        if IsValid(ent) and M.IsProp(ent) then
            return "mirror", ent, state.mirror.points
        end

        if geometry.traceHitsWorld(tr) then
            return "mirror", M.WORLD_TARGET, state.mirror.points
        end

        return
    end

    if IsValid(ent) and ent == state.prop1 then
        return "source", state.prop1, state.source
    end

    if geometry.hasTargetEntity(state.prop2) then
        if IsValid(ent) and M.IsProp(ent) and ent ~= state.prop1 then
            return "target", ent, state.target
        end

        if geometry.traceHitsWorld(tr) then
            return "target", M.WORLD_TARGET, state.target
        end
    end

    if IsValid(state.prop1) then
        return "source", state.prop1, state.source
    end
end


client.RightClick = client.RightClick or {}

function client.RightClick.toggleLinkedProp(state, ent)
    if not IsValid(state and state.prop1)
        or not M.IsProp(ent)
        or ent == state.prop1
        or ent == state.prop2 then
        return false
    end

    local linked = state.linked or {}
    state.linked = linked
    local existing

    for i = 1, #linked do
        if linked[i] == ent then
            existing = i
            break
        end
    end

    if existing then
        table.remove(linked, existing)

        local ghost = state.linkedGhosts and state.linkedGhosts[ent] or nil
        if IsValid(ghost) then
            ghost:Remove()
        end
        state.linkedGhosts[ent] = nil
        compatGhosts.clear(state, ent)
    elseif #linked < M.GetMaxLinkedProps() then
        linked[#linked + 1] = ent
    end

    return true
end

function client.RightClick.removeEditablePointAtTrace(state, trace, space)
    local side, ent, points = editable(state, trace and trace.Entity or nil, trace, space)
    if not trace or not ent or not geometry.traceMatchesEntity(trace, ent) or not isvector(trace.HitPos) then return false end

    local best, bestDist
    local fallbackEnt = side == "target" and state.prop2 or ent
    local cache = pointWorldCacheForAction(state)
    for i = 1, #points do
        local ref = M.ResolvePointReference and M.ResolvePointReference(points[i], fallbackEnt) or fallbackEnt
        local refMatches = geometry.isWorldTarget(ent)
            and geometry.isWorldTarget(ref)
            or (IsValid(ent) and ref == ent)
        local world = refMatches
            and (cache and M.ResolvePointWorldPositionCached(cache, points[i], fallbackEnt) or M.ResolvePointWorldPosition(points[i], fallbackEnt))
            or nil
        if isvector(world) then
            local dist = world:DistToSqr(trace.HitPos)
            if not bestDist or dist < bestDist then
                best = i
                bestDist = dist
            end
        end
    end

    if not best or bestDist > PICK_CONFIG.pointRemoveRadius ^ 2 then
        return false
    end

    table.remove(points, best)

    local worldPoints = client.WorldPoints
    if worldPoints then
        if points == state.target
            and isfunction(worldPoints.onTargetPointRemoved) then
            worldPoints.onTargetPointRemoved(state, best)
        elseif state.mirror
            and points == state.mirror.points
            and isfunction(worldPoints.onPointRemoved) then
            worldPoints.onPointRemoved(state, "mirror", best)
        end
    end

    state.pending = nil
    M.RefreshState(state)
    return true
end

local function performClientRightClick(trace)
    local state = M.ClientState
    if not state then return true end

    state.linked = state.linked or {}
    state.linkedGhosts = state.linkedGhosts or {}

    local activeSpace = client.activeSpace()
    local mirrorTabActive = M.IsMirrorMode and M.IsMirrorMode(activeSpace)

    if mirrorTabActive then
        if client.RightClick.removeEditablePointAtTrace(state, trace, activeSpace) then
            return true
        end

        if trace and client.RightClick.toggleLinkedProp(state, trace.Entity) then
            return true
        end
        return true
    end

    if trace and client.RightClick.toggleLinkedProp(state, trace.Entity) then
        return true
    end

    client.RightClick.removeEditablePointAtTrace(state, trace, activeSpace)
    return true
end

local function pointRemovalAtTraceWouldAffect(state, trace, space)
    local side, ent, points = editable(state, trace and trace.Entity or nil, trace, space)
    if not trace or not ent or not geometry.traceMatchesEntity(trace, ent) or not isvector(trace.HitPos) then return false end

    local fallbackEnt = side == "target" and state.prop2 or ent
    local cache = pointWorldCacheForAction(state)

    for i = 1, #(points or {}) do
        local point = points[i]
        local ref = M.ResolvePointReference and M.ResolvePointReference(point, fallbackEnt) or fallbackEnt
        local refMatches = geometry.isWorldTarget(ent)
            and geometry.isWorldTarget(ref)
            or (IsValid(ent) and ref == ent)
        local world = refMatches
            and (cache and M.ResolvePointWorldPositionCached(cache, point, fallbackEnt) or M.ResolvePointWorldPosition(point, fallbackEnt))
            or nil
        if isvector(world) and world:DistToSqr(trace.HitPos) <= PICK_CONFIG.pointRemoveRadius ^ 2 then
            return true
        end
    end

    return false
end

local function leftClickWouldAffect()
    if SERVER then return true end

    local state = M.ClientState
    local hover = state and state.hover
    if not hover then return false end

    if hover.gizmo and hover.gizmo.hover then return true end
    if hover.point and hover.side then return true end
    if hover.pickSource or hover.pickTarget then return true end

    if hover.side
        and hover.ent
        and hover.trace
        and hover.candidate
        and geometry.traceMatchesEntity(hover.trace, hover.ent) then
        local points = hover.points
        return not istable(points) or #points < M.MAX_POINTS
    end

    return false
end

local function rightClickWouldAffect(trace)
    if SERVER then return true end

    local state = M.ClientState
    if not state or not trace then return false end

    if IsValid(state.prop1)
        and M.IsProp(trace.Entity)
        and trace.Entity ~= state.prop1
        and trace.Entity ~= state.prop2 then
        local linked = state.linked or {}
        for i = 1, #linked do
            if linked[i] == trace.Entity then
                return true
            end
        end

        return #linked < M.GetMaxLinkedProps()
    end

    return pointRemovalAtTraceWouldAffect(state, trace, client.activeSpace())
end

local function reloadWouldAffect()
    if SERVER then return true end

    local state = M.ClientState
    if not state then return false end

    return IsValid(state.prop1)
        or geometry.hasTargetEntity(state.prop2)
        or #(state.source or {}) > 0
        or #(state.target or {}) > 0
        or #(state.linked or {}) > 0
        or (state.mirror and #(state.mirror.points or {}) > 0)
        or state.preview ~= nil
        or state.pending ~= nil
        or state.press ~= nil
end

local function toolgunFeedbackKind(action, wouldAffect)
    local effects = M.ToolgunEffects
    if effects and isfunction(effects.ResolveFeedbackKind) then
        return effects.ResolveFeedbackKind(action, wouldAffect)
    end

    if wouldAffect == false then return "fail" end
    if action == "reset" then return "reset" end
    if action == "fail" or action == "commit" or action == "mirrorCommit" then return action end
    return "normal"
end

local function playToolgunFeedback(tool, action, wouldAffect, trace, weapon, options)
    local effects = M.ToolgunEffects
    if not effects then return end

    local kind = toolgunFeedbackKind(action, wouldAffect)

    if isfunction(effects.DispatchFeedback) then
        return effects.DispatchFeedback(kind, tool, trace, weapon, options)
    end

    if CLIENT and (not options or options.direct ~= false) then
        if isfunction(effects.PlayFeedback) then
            return effects.PlayFeedback(kind, tool, trace, weapon)
        end
        return
    end

    if isfunction(effects.MarkFeedback) then
        return effects.MarkFeedback(kind, tool, weapon)
    end
end

local function markToolgunFeedback(tool, wouldAffect, trace, weapon)
    return playToolgunFeedback(tool, "normal", wouldAffect, trace, weapon)
end

local function markReloadFeedback(tool, wouldAffect, trace, weapon)
    return playToolgunFeedback(tool, "reset", wouldAffect, trace, weapon)
end

local function playNoEffectFeedback(tool, weapon)
    return playToolgunFeedback(tool, "fail", false, nil, weapon)
end

local function canCommitState(state)
    return state
        and state.preview
        and IsValid(state.prop1)
        and M.IsFiniteVector(state.preview.pos)
        and M.IsFiniteAngle(state.preview.ang)
end

local function resetSessionConVars()
    for _, space in ipairs(M.SPACES) do
        for _, suffix in ipairs(SESSION_CONFIG.convarSuffixes) do
            RunConsoleCommand("magic_align_" .. space .. "_" .. suffix, "0")
        end
    end

    if M.Client and M.Client.updateSessionTabTitles then
        M.Client.updateSessionTabTitles()
    end
end

local function performClientReload(tool)
    local state = M.ClientState
    clearSessionVisuals(state)

    resetSessionConVars()

    if tool then
        local currentSpace = tool:GetClientInfo("space")
        setClientActiveSpace(currentSpace)
    end

    local nextState = M.NewSession()
    if CLIENT and input then
        nextState.attackDown = input.IsMouseDown(MOUSE_LEFT)
        nextState.useDown = input.IsKeyDown(KEY_E)
    end

    M.ClientState = nextState

    return true
end

local function resetClientSession(tool)
    return performClientReload(tool)
end

local function validateClientState(tool, state)
    if not state then return true end

    if state.prop1 ~= nil and (not IsValid(state.prop1) or not M.IsProp(state.prop1)) then
        resetClientSession(tool)
        return false
    end

    if state.prop2 ~= nil and not geometry.isWorldTarget(state.prop2) and (not IsValid(state.prop2) or not M.IsProp(state.prop2)) then
        resetClientSession(tool)
        return false
    end

    return true
end

function client.setPlayerViewAngles(ply, ang)
    if not IsValid(ply) or not isangle(ang) then return end

    ply:SetEyeAngles(toAngle(ang))

    if game.SinglePlayer() then
        net.Start(M.NET_VIEW_ANGLES)
            net.WritePreciseAngle(ang)
        net.SendToServer()
    end
end

function TOOL:LeftClick(trace)
    if SERVER then
        if game.SinglePlayer() then
            sendClientAction(self:GetOwner(), M.CLIENT_ACTION_LEFTCLICK, trace)
        else
            playToolgunFeedback(self, "normal", true, trace, nil, { direct = false })
        end

        return true
    end

    if game.SinglePlayer() then
        return true
    end

    playToolgunFeedback(self, "normal", leftClickWouldAffect(trace), trace, nil, { direct = false })

    if isfunction(core.queueClientLeftClick) then
        return core.queueClientLeftClick(self)
    end

    return true
end

function TOOL:RightClick(trace)
    if SERVER then
        if game.SinglePlayer() then
            sendClientAction(self:GetOwner(), M.CLIENT_ACTION_RIGHTCLICK, trace)
        else
            playToolgunFeedback(self, "normal", true, trace, nil, { direct = false })
        end

        return true
    end

    if game.SinglePlayer() then
        return true
    end

    playToolgunFeedback(self, "normal", rightClickWouldAffect(trace), trace, nil, { direct = false })

    return performClientRightClick(trace)
end

function TOOL:Reload(trace)
    if SERVER then
        if game.SinglePlayer() then
            sendClientAction(self:GetOwner(), M.CLIENT_ACTION_RESET, trace)
        else
            playToolgunFeedback(self, "reset", true, trace, nil, { direct = false })
        end

        return true
    end

    if game.SinglePlayer() then
        return true
    end

    playToolgunFeedback(self, "reset", reloadWouldAffect(trace), trace, nil, { direct = false })

    return performClientReload(self)
end

if SERVER then
    hook.Add("AllowPlayerPickup", "MagicAlignBlockUsePickup", function(ply, ent)
        if not M.IsProp(ent) then return end
        if not M.GetActiveMagicAlignTool(ply) then return end

        return false
    end)
end

core.sendClientAction = sendClientAction
core.isMirrorSpace = isMirrorSpace
core.isUiSpace = isUiSpace
core.rememberNonMirrorSpace = rememberNonMirrorSpace
core.setClientActiveSpace = setClientActiveSpace
core.clearSessionVisuals = clearSessionVisuals
core.editable = editable
core.performClientRightClick = performClientRightClick
core.pointRemovalAtTraceWouldAffect = pointRemovalAtTraceWouldAffect
core.leftClickWouldAffect = leftClickWouldAffect
core.rightClickWouldAffect = rightClickWouldAffect
core.reloadWouldAffect = reloadWouldAffect
core.playToolgunFeedback = playToolgunFeedback
core.markToolgunFeedback = markToolgunFeedback
core.markReloadFeedback = markReloadFeedback
core.playNoEffectFeedback = playNoEffectFeedback
core.canCommitState = canCommitState
core.resetSessionConVars = resetSessionConVars
core.performClientReload = performClientReload
core.resetClientSession = resetClientSession
core.validateClientState = validateClientState

return core
