MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local geometry = client.geometry or {}
client.geometry = geometry
local core = client.ToolCore or include("magic_align/tool_config.lua")
local VectorP = M.VectorP
local AngleP = M.AngleP
local isvector = M.IsVectorLike
local isangle = M.IsAngleLike
local toVector = M.ToVector
local toAngle = M.ToAngle
local compatGhosts = core.compatGhosts
local TOOL_UI = core.TOOL_UI
local PICK_CONFIG = core.PICK_CONFIG
local ROTATION_CONFIG = core.ROTATION_CONFIG
local SMARTSNAP_CONFIG = core.SMARTSNAP_CONFIG
local GHOST_REFRESH_INTERVAL = core.GHOST_REFRESH_INTERVAL
local performClientRightClick = core.performClientRightClick
local performClientReload = core.performClientReload
local setClientActiveSpace = core.setClientActiveSpace
local clearSessionVisuals = core.clearSessionVisuals
local resetSessionConVars = core.resetSessionConVars

local queuedClientActionFeedback

local colors = {
    source = Color(255, 190, 80),
    target = Color(80, 220, 255),
    cursorSource = Color(255, 190, 80),
    cursorTarget = Color(80, 220, 255),
    axis = Color(92, 220, 148),
    mirror = Color(176, 112, 235),
    preview = Color(80, 240, 255),
    pending = Color(120, 255, 120),
    corner = Color(255, 120, 255),
    x = Color(255, 100, 100),
    y = Color(120, 255, 120),
    z = Color(120, 160, 255),
    dim = Color(255, 255, 255, 80)
}

colors.xy = Color(255, 210, 80, 150)
colors.xz = Color(255, 130, 210, 150)
colors.yz = Color(110, 240, 255, 150)

local sessionStates = client.SessionStates or setmetatable({}, { __mode = "v" })
client.SessionStates = sessionStates

local function registerSessionState(state)
    if not istable(state) then return end

    local sessionId = tonumber(state.sessionId)
    if not sessionId then return end

    sessionStates[sessionId] = state
    return state
end

local function ensureStateShape(state)
    state = state or M.NewSession()

    state.sessionId = tonumber(state.sessionId) or M.NextSessionId()
    state.linked = state.linked or {}
    state.anchorSelection = state.anchorSelection or {}
    state.source = state.source or {}
    state.target = state.target or {}
    state.mirror = state.mirror or {}
    state.mirror.points = state.mirror.points or {}
    state.mirror.enabled = state.mirror.enabled == true
    state.bounds = state.bounds or {}
    state.compatGhosts = state.compatGhosts or { linked = {} }
    state.compatGhosts.linked = state.compatGhosts.linked or {}
    state.linkedGhosts = state.linkedGhosts or {}
    state.attackDown = state.attackDown == true
    state.useDown = state.useDown == true

    registerSessionState(state)

    return state
end

local function ensureRegisteredStateShape(state)
    if istable(state) and state._magicAlignTransientState == true then
        state.sessionId = tonumber(state.sessionId) or M.NextSessionId()
        state.bounds = state.bounds or {}
        state.linked = state.linked or {}
        state.compatGhosts = state.compatGhosts or { linked = {} }
        state.compatGhosts.linked = state.compatGhosts.linked or {}
        state.linkedGhosts = state.linkedGhosts or {}

        registerSessionState(state)
        return state
    end

    return ensureStateShape(state)
end

local function stateBySessionId(sessionId)
    sessionId = tonumber(sessionId)
    if not sessionId then return end

    local registered = sessionStates[sessionId]
    if istable(registered) and tonumber(registered.sessionId) == sessionId then
        return ensureRegisteredStateShape(registered)
    end

    if istable(M.ClientState) and tonumber(M.ClientState.sessionId) == sessionId then
        return ensureRegisteredStateShape(M.ClientState)
    end

    local magicMirror = client.MagicMirror or (M.MagicMirror and M.MagicMirror.Client)
    local mirrorState = magicMirror and magicMirror.ClientState or M.MagicMirrorClientState
    if istable(mirrorState) and tonumber(mirrorState.sessionId) == sessionId then
        return ensureRegisteredStateShape(mirrorState)
    end
end

local function state()
    if not M.ClientSessionConVarsInitialized then
        resetSessionConVars()
        M.ClientSessionConVarsInitialized = true
    end

    M.ClientState = ensureStateShape(M.ClientState)
    return M.ClientState
end

function core.queueClientLeftClick()
    local currentState = state()
    currentState.leftClickQueued = true
    currentState.leftClickQueuedAt = RealTime()
    return true
end

local function comp(v, key)
    return key == "x" and v.x or key == "y" and v.y or v.z
end

local copyVec = M.CopyVectorPrecise
local copyAng = M.CopyAnglePrecise
local ZERO_VEC = VectorP(0, 0, 0)
local ZERO_ANG = AngleP(0, 0, 0)
local LocalToWorldPosPrecise = M.LocalToWorldPosPrecise
local WorldToLocalPosPrecise = M.WorldToLocalPosPrecise

local function setVec(out, value)
    if not isvector(value) then return end

    if not isvector(out) then
        return VectorP(value.x, value.y, value.z)
    end

    out.x, out.y, out.z = value.x, value.y, value.z
    return out
end

local function setAng(out, value)
    if not isangle(value) then return end

    if not isangle(out) then
        return AngleP(value.p, value.y, value.r)
    end

    out.p, out.y, out.r = value.p, value.y, value.r
    return out
end

local function normalizedVec(v)
    return M.NormalizeVectorPrecise(v, M.COMPUTE_VECTOR_EPSILON_SQR)
end

local function clientNumber(tool, name, fallback)
    local value

    if tool and isfunction(tool.GetClientInfo) then
        local raw = tool:GetClientInfo(name)
        if raw ~= nil then
            value = tonumber(raw)
        end
    end

    if value == nil and tool and isfunction(tool.GetClientNumber) then
        local raw = tool:GetClientNumber(name)
        if raw ~= nil then
            value = tonumber(raw)
        end
    end

    if not M.IsFiniteNumber(value) then
        value = tonumber(fallback) or 0
    end

    return value
end

local function exactNormalKey(v)
    local n = normalizedVec(v)
    if not n then return end

    return ("%.17g|%.17g|%.17g"):format(
        n.x,
        n.y,
        n.z
    )
end

local function buildTraceSample(ent, worldPos, worldNormal, tr)
    if not geometry.hasTargetEntity(ent) then return end

    if tr then
        if not geometry.traceMatchesEntity(tr, ent) then return end
        worldPos = copyVec(tr.HitPos)
        worldNormal = isvector(tr.HitNormal) and copyVec(tr.HitNormal) or tr.HitNormal
    end

    if not isvector(worldPos) then return end

    local localPos = geometry.localPointFromWorldPos(ent, worldPos)
    if not isvector(localPos) then return end
    localPos = copyVec(localPos)

    local localNormal
    local localNormalKey

    if isvector(worldNormal) then
        localNormal = geometry.localNormalFromWorld(ent, worldPos, worldNormal)
        if localNormal then
            localNormalKey = exactNormalKey(localNormal)
        else
            localNormal = nil
        end
    end

    return {
        localPos = localPos,
        localNormal = localNormal,
        localNormalKey = localNormalKey,
        surfaceHit = tr ~= nil
    }
end

local function sampleWorldPos(ent, sample)
    if not istable(sample) then return end

    if geometry.hasTargetEntity(ent) and isvector(sample.localPos) then
        return geometry.worldPosFromLocalPoint(ent, sample.localPos)
    end

    return isvector(sample.pos) and sample.pos or nil
end

local function sampleLocalPos(sample)
    if not istable(sample) or not isvector(sample.localPos) then return end
    return copyVec(sample.localPos)
end

local function sampleLocalNormal(sample)
    return normalizedVec(sample and sample.localNormal)
end

local function aggregateTraceProbes(samples)
    local probes = {}

    for i = 1, #samples do
        local sample = samples[i]
        if istable(sample) and sample.surfaceHit == true then
            local localPos = sampleLocalPos(sample)
            local localNormal = sampleLocalNormal(sample)
            local normalKey = sample.localNormalKey

            if localPos and localNormal then
                normalKey = normalKey or exactNormalKey(localNormal)
            end

            if localPos and localNormal and isstring(normalKey) and normalKey ~= "" then
                local probe

                for j = 1, #probes do
                    local existing = probes[j]
            if isvector(existing.localNormal) and M.DotVectorsPrecise(existing.localNormal, localNormal) >= PICK_CONFIG.traceProbeNormalDotMin then
                probe = existing
                break
            end
                end

                if not probe then
                    probe = {
                        normalKey = normalKey,
                        localNormal = localNormal,
                        normalSum = VectorP(0, 0, 0),
                        localPos = VectorP(0, 0, 0),
                        planeDistance = 0,
                        count = 0
                    }
                    probes[#probes + 1] = probe
                end

                probe.count = probe.count + 1
                probe.normalSum = probe.normalSum + localNormal
                probe.localNormal = normalizedVec(probe.normalSum) or probe.localNormal
                probe.localPos = probe.localPos + localPos
            end
        end
    end

    for i = 1, #probes do
        local probe = probes[i]
        probe.localPos = probe.localPos / probe.count
        probe.localNormal = normalizedVec(probe.normalSum) or normalizedVec(probe.localNormal)
        probe.planeDistance = probe.localNormal:Dot(probe.localPos)
        probe.normalSum = nil
        probe.normalKey = probe.normalKey or exactNormalKey(probe.localNormal)
    end

    table.sort(probes, function(a, b)
        if a.count == b.count then
            return a.normalKey < b.normalKey
        end

        return a.count > b.count
    end)

    return probes
end

local function buildTraceProbeCandidate(ent, localPos, localNormal, mode, probes, axisLocalDir)
    if not geometry.hasTargetEntity(ent) or not isvector(localPos) then return end

    local worldPos = geometry.worldPosFromLocalPoint(ent, localPos)
    if not isvector(worldPos) then return end

    local storedLocalNormal = normalizedVec(localNormal)
    local worldNormal = geometry.worldNormalFromLocal(ent, localPos, storedLocalNormal)
    local worldAxisDir = geometry.worldNormalFromLocal(ent, localPos, axisLocalDir)

    return {
        ent = ent,
        localPos = copyVec(localPos),
        worldPos = worldPos,
        localNormal = storedLocalNormal and copyVec(storedLocalNormal) or nil,
        normal = worldNormal or worldAxisDir or (geometry.isWorldTarget(ent) and VectorP(0, 0, 1) or ent:GetUp()),
        mode = mode,
        probes = probes,
        axisLocalDir = isvector(axisLocalDir) and copyVec(axisLocalDir) or nil,
        axisWorldDir = worldAxisDir
    }
end

local function ghostAlpha(alpha)
    return 158
end

local function linkedGhostAlpha(alpha)
    return 158
end

local modelScale = M.GetEntityModelScale
local SCALE_IDENTITY = VectorP(1, 1, 1)
local SCALE_ZERO = VectorP(0, 0, 0)

local function handlerVisualScale(ent)
    local handler = M.FindSizeHandler(ent)
    if not IsValid(handler) or not isfunction(handler.GetVisualScale) then return end

    local scale = M.ParseScaleVector(handler:GetVisualScale())
    if not isvector(scale) or M.VectorApprox(scale, SCALE_ZERO) or M.VectorApprox(scale, SCALE_IDENTITY) then
        return
    end

    return scale
end

local function applyGhostScale(ghost, src, mirrorAxis)
    if not IsValid(ghost) or not IsValid(src) then return end

    local changed = false
    local currentModelScale = M.GetEntityModelScale(src)
    if ghost._magicAlignModelScale ~= currentModelScale then
        ghost:SetModelScale(currentModelScale, 0)
        ghost._magicAlignModelScale = currentModelScale
        changed = true
    end

    mirrorAxis = tonumber(mirrorAxis) or M.ENTITY_MIRROR_NONE
    local scale = handlerVisualScale(src)
    local hasMirrorScale = M.EntityMirror
        and mirrorAxis ~= M.ENTITY_MIRROR_NONE
        and mirrorAxis >= M.ENTITY_MIRROR_X
        and mirrorAxis <= M.ENTITY_MIRROR_Z

    if scale or hasMirrorScale then
        local matrixScale = ghost._magicAlignMatrixScale or Vector(1, 1, 1)
        ghost._magicAlignMatrixScale = matrixScale
        matrixScale.x = scale and scale.x or 1
        matrixScale.y = scale and scale.y or 1
        matrixScale.z = scale and scale.z or 1

        if hasMirrorScale then
            local mirrorScale = M.EntityMirror.ScaleForAxis(mirrorAxis, ghost._magicAlignMirrorScale)
            ghost._magicAlignMirrorScale = mirrorScale
            matrixScale.x = matrixScale.x * mirrorScale.x
            matrixScale.y = matrixScale.y * mirrorScale.y
            matrixScale.z = matrixScale.z * mirrorScale.z
        end

        local lastScale = ghost._magicAlignVisualScale
        if not isvector(lastScale) or not M.VectorApprox(lastScale, matrixScale) then
            local matrix = Matrix()
            matrix:Scale(toVector(matrixScale))
            ghost:EnableMatrix("RenderMultiply", matrix)
            ghost._magicAlignVisualScale = copyVec(matrixScale)
            changed = true
        end
    elseif isvector(ghost._magicAlignVisualScale) then
        ghost:DisableMatrix("RenderMultiply")
        ghost._magicAlignVisualScale = nil
        changed = true
    end

    local mins, maxs = src:GetRenderBounds()
    if isvector(mins) and isvector(maxs)
        and (not isvector(ghost._magicAlignRenderMins)
            or not isvector(ghost._magicAlignRenderMaxs)
            or not M.VectorApprox(ghost._magicAlignRenderMins, mins)
            or not M.VectorApprox(ghost._magicAlignRenderMaxs, maxs)) then
        ghost:SetRenderBounds(mins, maxs)
        ghost._magicAlignRenderMins = copyVec(mins)
        ghost._magicAlignRenderMaxs = copyVec(maxs)
        changed = true
    end

    return changed
end

local function angleApprox(a, b, eps)
    if not isangle(a) or not isangle(b) then return false end

    eps = tonumber(eps) or M.UI_COMPARE_EPSILON
    return math.abs(math.AngleDifference(a.p, b.p)) <= eps
        and math.abs(math.AngleDifference(a.y, b.y)) <= eps
        and math.abs(math.AngleDifference(a.r, b.r)) <= eps
end

local function revisionValue(value, depth)
    if isvector(value) or isangle(value) then
        return tostring(value)
    end

    if istable(value) and (tonumber(depth) or 0) < 2 then
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end

        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)

        local parts = {}
        for i = 1, #keys do
            local key = keys[i]
            parts[#parts + 1] = tostring(key) .. "=" .. revisionValue(value[key], (depth or 0) + 1)
        end

        return "{" .. table.concat(parts, ",") .. "}"
    end

    return tostring(value)
end

local function resizeRevision(ent)
    local parts = {}
    local modifierData = istable(ent.EntityMods) and ent.EntityMods.advr or nil

    if istable(modifierData) then
        for i = 1, 7 do
            parts[#parts + 1] = revisionValue(modifierData[i])
        end
    else
        parts[#parts + 1] = "noadvr"
    end

    local handler = M.FindSizeHandler(ent)
    if IsValid(handler) then
        parts[#parts + 1] = isfunction(handler.GetActualPhysicsScale) and tostring(handler:GetActualPhysicsScale()) or "nophys"
        parts[#parts + 1] = isfunction(handler.GetVisualScale) and tostring(handler:GetVisualScale()) or "novis"
    else
        parts[#parts + 1] = "nohandler"
    end

    return table.concat(parts, "|")
end

local function primitiveRevision(ent)
    if not M.IsPrimitive(ent) then return "notprimitive" end

    local parts = { ent:GetClass() }

    if isfunction(ent.PrimitiveGetKeys) then
        local keys = ent:PrimitiveGetKeys()
        if istable(keys) then
            local names = {}
            for name in pairs(keys) do
                names[#names + 1] = name
            end

            table.sort(names)

            for i = 1, #names do
                local name = names[i]
                parts[#parts + 1] = tostring(name) .. "=" .. revisionValue(keys[name])
            end
        else
            parts[#parts + 1] = "nokeys"
        end
    else
        parts[#parts + 1] = "nogetter"
    end

    return table.concat(parts, "|")
end

local function mirrorBoundsRevision(ent)
    return M.EntityMirror.BoundsRevisionForEntity(ent)
end

local function boundsRevision(ent)
    if not IsValid(ent) then return "invalid" end

    local collisionMins, collisionMaxs = ent:GetCollisionBounds()
    local renderMins, renderMaxs = ent:GetRenderBounds()

    return table.concat({
        tostring(modelScale(ent)),
        isvector(collisionMins) and tostring(collisionMins) or "nil",
        isvector(collisionMaxs) and tostring(collisionMaxs) or "nil",
        isvector(renderMins) and tostring(renderMins) or "nil",
        isvector(renderMaxs) and tostring(renderMaxs) or "nil",
        resizeRevision(ent),
        primitiveRevision(ent),
        mirrorBoundsRevision(ent)
    }, "|")
end

local function resetBoundsEntry(entry)
    if not istable(entry) then return end

    entry.pending = false
    entry.ready = false
    entry.size = nil
    entry.mins = nil
    entry.maxs = nil
    entry.center = nil
    entry.requestRevision = nil
    entry.mirrorRevision = nil
    entry.nextRevisionCheck = nil
end

local function refreshBoundsEntry(ent, entry)
    if not IsValid(ent) or not istable(entry) then return end

    local revision = boundsRevision(ent)
    local mirrorRevision = mirrorBoundsRevision(ent)
    if entry.revision == revision and entry.mirrorRevision == mirrorRevision then
        return revision
    end

    resetBoundsEntry(entry)
    entry.requestedAt = 0
    entry.revision = revision
    entry.mirrorRevision = mirrorRevision

    return revision
end

local READY_BOUNDS_REVISION_INTERVAL = 1

local function maybeRefreshBoundsEntry(ent, entry, force)
    if not istable(entry) then return end

    if entry.ready and not force then
        if entry.mirrorRevision ~= mirrorBoundsRevision(ent) then
            return refreshBoundsEntry(ent, entry)
        end

        local now = RealTime()
        if now < (entry.nextRevisionCheck or 0) then
            return entry.revision
        end
        entry.nextRevisionCheck = now + READY_BOUNDS_REVISION_INTERVAL
    end

    return refreshBoundsEntry(ent, entry)
end

local function linkedPropIndex(state, ent)
    if not IsValid(ent) then return end

    for i = 1, #(state.linked or {}) do
        if state.linked[i] == ent then
            return i
        end
    end
end

local function isLinkedProp(state, ent)
    return linkedPropIndex(state, ent) ~= nil
end

local function removeLinkedGhost(state, ent)
    local ghosts = state.linkedGhosts or {}
    local ghost = ghosts[ent]
    if IsValid(ghost) then
        ghost:Remove()
    end
    ghosts[ent] = nil
    compatGhosts.clear(state, ent)
end

local function resetLinkedProps(state)
    if istable(state.linkedGhosts) then
        for ent, ghost in pairs(state.linkedGhosts) do
            if IsValid(ghost) then
                ghost:Remove()
            end
            state.linkedGhosts[ent] = nil
            compatGhosts.clear(state, ent)
        end
    end

    local compatLinked = state.compatGhosts and state.compatGhosts.linked or nil
    if istable(compatLinked) then
        for ent in pairs(compatLinked) do
            compatGhosts.clear(state, ent)
        end
    end

    state.linked = {}
end

local function removeLinkedProp(state, ent)
    local index = linkedPropIndex(state, ent)
    if not index then return false end

    table.remove(state.linked, index)
    removeLinkedGhost(state, ent)

    return true
end

local function cleanupLinkedProps(state)
    state.linked = state.linked or {}
    state.linkedGhosts = state.linkedGhosts or {}

    for i = #state.linked, 1, -1 do
        local ent = state.linked[i]
        if not IsValid(ent) or not M.IsProp(ent) or ent == state.prop1 or ent == state.prop2 then
            table.remove(state.linked, i)
            removeLinkedGhost(state, ent)
        end
    end

    for ent, ghost in pairs(state.linkedGhosts) do
        if not IsValid(ent) or not isLinkedProp(state, ent) then
            if IsValid(ghost) then
                ghost:Remove()
            end
            state.linkedGhosts[ent] = nil
        end
    end
end

local function cleanupTargetPointReferences(state)
    if not istable(state) or not istable(state.target) then return end

    local removed = {}
    for i = #state.target, 1, -1 do
        local point = state.target[i]
        local valid = M.IsPointReferenceValid
            and M.IsPointReferenceValid(point, state.prop2, {
                allowWorld = true,
                requireProp = true
            })
            or isvector(point)
        if not valid then
            table.remove(state.target, i)
            removed[#removed + 1] = i
        end
    end

    if #removed < 1 then return end

    local worldPoints = client.WorldPoints
    if worldPoints and isfunction(worldPoints.onTargetPointRemoved) then
        for i = 1, #removed do
            worldPoints.onTargetPointRemoved(state, removed[i])
        end
    end

    state.pending = nil
end

local function commitMode()
    local ctrl = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
    local shift = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

    if ctrl then
        return shift and M.COMMIT_COPY_MOVE or M.COMMIT_COPY, true
    end

    return M.COMMIT_MOVE, shift
end

local lastToolDescription
local lastToolShowsUse
local lastToolShowsWorldPointHint
local lastToolShowsMirrorHint

local function targetDisplayLabel(state)
    if geometry.isWorldTarget(state and state.prop2) then
        return TOOL_UI.spaceLabels.world or "World"
    end

    return TOOL_UI.spaceLabels.prop2 or "Prop 2"
end

local function updateToolHelp(tool, state)
    if not tool then return end

    local stateName = istable(state) and state.state or nil
    local description = TOOL_UI.statusDescriptions[stateName] or TOOL_UI.defaultDescription
    if stateName == "target_points" and geometry.hasTargetEntity(state and state.prop2) then
        description = "Place target points on Prop 2, World, or other props."
    end

    local showUse = istable(state) and state.preview ~= nil
    local worldPoints = client.WorldPoints
    local showWorldPointHint = worldPoints
        and isfunction(worldPoints.hasToggleHint)
        and worldPoints.hasToggleHint(state)
        or false
    local showMirrorHint = tool.GetClientInfo and M.IsMirrorMode(tool:GetClientInfo("space"))

    if lastToolDescription ~= description then
        language.Add("tool.magic_align.desc", description)
        lastToolDescription = description
    end

    if lastToolShowsUse ~= showUse
        or lastToolShowsWorldPointHint ~= showWorldPointHint
        or lastToolShowsMirrorHint ~= showMirrorHint then
        if showUse then
            tool.Information = showMirrorHint and TOOL_UI.information.readyMirror
                or showWorldPointHint and TOOL_UI.information.readyWorldPoint
                or TOOL_UI.information.ready
        else
            tool.Information = showMirrorHint and TOOL_UI.information.idleMirror
                or showWorldPointHint and TOOL_UI.information.idleWorldPoint
                or TOOL_UI.information.idle
        end
        lastToolShowsUse = showUse
        lastToolShowsWorldPointHint = showWorldPointHint
        lastToolShowsMirrorHint = showMirrorHint
    end
end

local function ensureGhostModel(ghost, model)
    if not model or model == "" then
        if IsValid(ghost) then
            ghost:Remove()
        end
        return
    end

    if not IsValid(ghost) or ghost:GetModel() ~= model then
        if IsValid(ghost) then
            ghost:Remove()
        end

        ghost = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
        if not IsValid(ghost) then return end

        ghost:SetNoDraw(true)
        ghost:SetRenderMode(RENDERMODE_TRANSCOLOR)
        ghost:DrawShadow(false)
        local materials = ghost:GetMaterials()
        ghost._magicAlignSubMaterialSlots = materials and #materials or 0
        ghost._magicAlignNeedsBoneSetup = true
    elseif ghost._magicAlignSubMaterialSlots == nil then
        local materials = ghost:GetMaterials()
        ghost._magicAlignSubMaterialSlots = materials and #materials or 0
    end

    return ghost
end

local function applyGhostAppearance(ghost, src, pos, ang, alphaFn, mirrorAxis)
    if not IsValid(ghost) or not IsValid(src) then return end

    local needsBoneSetup = ghost._magicAlignNeedsBoneSetup == true

    if not isvector(ghost._magicAlignPos) or not M.VectorApprox(ghost._magicAlignPos, pos) then
        ghost:SetPos(toVector(pos))
        ghost._magicAlignPos = setVec(ghost._magicAlignPos, pos)
    end
    if not angleApprox(ghost._magicAlignAng, ang) then
        ghost:SetAngles(toAngle(ang))
        ghost._magicAlignAng = setAng(ghost._magicAlignAng, ang)
    end

    local skin = src:GetSkin() or 0
    if ghost._magicAlignSkin ~= skin then
        ghost:SetSkin(skin)
        ghost._magicAlignSkin = skin
        needsBoneSetup = true
    end

    local material = src:GetMaterial() or ""
    if ghost._magicAlignMaterial ~= material then
        ghost:SetMaterial(material)
        ghost._magicAlignMaterial = material
    end

    local bodygroups = ghost._magicAlignBodygroups or {}
    ghost._magicAlignBodygroups = bodygroups
    for i = 0, src:GetNumBodyGroups() - 1 do
        local bodygroup = src:GetBodygroup(i)
        if bodygroups[i] ~= bodygroup then
            ghost:SetBodygroup(i, bodygroup)
            bodygroups[i] = bodygroup
            needsBoneSetup = true
        end
    end

    local subMaterials = ghost._magicAlignSubMaterials or {}
    ghost._magicAlignSubMaterials = subMaterials
    local subCount = math.max(
        ghost._magicAlignSubMaterialSlots or 0,
        ghost._magicAlignSubMaterialCount or 0
    )
    for i = 0, subCount - 1 do
        local subMaterial = src:GetSubMaterial(i) or ""
        if subMaterials[i] ~= subMaterial then
            ghost:SetSubMaterial(i, subMaterial)
            subMaterials[i] = subMaterial
            needsBoneSetup = true
        end
    end
    ghost._magicAlignSubMaterialCount = subCount

    local srcColor = src:GetColor()
    local alpha = alphaFn(srcColor.a)
    if ghost._magicAlignColorR ~= srcColor.r
        or ghost._magicAlignColorG ~= srcColor.g
        or ghost._magicAlignColorB ~= srcColor.b
        or ghost._magicAlignColorA ~= alpha then
        ghost:SetColor(Color(srcColor.r, srcColor.g, srcColor.b, alpha))
        ghost._magicAlignColorR = srcColor.r
        ghost._magicAlignColorG = srcColor.g
        ghost._magicAlignColorB = srcColor.b
        ghost._magicAlignColorA = alpha
    end

    if applyGhostScale(ghost, src, mirrorAxis) then
        needsBoneSetup = true
    end
    M.EntityMirror.ApplyVisualCullPreview(ghost, mirrorAxis or M.ENTITY_MIRROR_NONE)

    if needsBoneSetup then
        ghost:SetupBones()
        ghost._magicAlignNeedsBoneSetup = false
    end
    if ghost.GetNoDraw and ghost:GetNoDraw() then
        ghost:SetNoDraw(false)
    end
end

local function hideGhosts(state)
    if IsValid(state.ghost) then
        state.ghost:SetNoDraw(true)
    end

    for _, ghost in pairs(state.linkedGhosts or {}) do
        if IsValid(ghost) then
            ghost:SetNoDraw(true)
        end
    end

    compatGhosts.clearAll(state)
    state._magicAlignGhostPreviewRevision = nil
    state._magicAlignNextGhostRefreshAt = nil
end

hook.Remove("Think", "MagicAlignHideGhostsWhenInactive")
hook.Add("Think", "MagicAlignHideGhostsWhenInactive", function()
    local state = M.ClientState
    if not istable(state) then return end

    local ply = LocalPlayer()
    local activeClassic = IsValid(ply)
        and M.GetActiveClassicMagicAlignTool(ply)
    if activeClassic then return end

    hideGhosts(state)
end)

local smartSnapSuppression = M.SmartSnapSuppression or {}
M.SmartSnapSuppression = smartSnapSuppression

local function restoreSmartSnap()
    if not smartSnapSuppression.active then return end

    local restoreValue = smartSnapSuppression.restoreValue
    smartSnapSuppression.active = false
    smartSnapSuppression.restoreValue = nil

    local cvar = GetConVar(SMARTSNAP_CONFIG.enabledCvar)
    if cvar and restoreValue ~= nil and cvar:GetString() ~= restoreValue then
        RunConsoleCommand(SMARTSNAP_CONFIG.enabledCvar, restoreValue)
    end
end

local function shouldSuppressSmartSnap()
    local setting = GetConVar(SMARTSNAP_CONFIG.disableCvar)
    if not setting or not setting:GetBool() then return false end

    local ply = LocalPlayer()
    return IsValid(ply) and M.GetActiveMagicAlignTool(ply) ~= nil
end

local function updateSmartSnapSuppression()
    local cvar = GetConVar(SMARTSNAP_CONFIG.enabledCvar)
    if not cvar then return end

    if shouldSuppressSmartSnap() then
        if not smartSnapSuppression.active then
            smartSnapSuppression.active = true
            smartSnapSuppression.restoreValue = cvar:GetString()
        end

        if cvar:GetBool() then
            RunConsoleCommand(SMARTSNAP_CONFIG.enabledCvar, "0")
        end

        return
    end

    restoreSmartSnap()
end

hook.Remove("Think", "MagicAlignSmartSnapSuppression")
hook.Add("Think", "MagicAlignSmartSnapSuppression", updateSmartSnapSuppression)
hook.Remove("ShutDown", "MagicAlignSmartSnapRestore")
hook.Add("ShutDown", "MagicAlignSmartSnapRestore", restoreSmartSnap)

local function ringCoords(key, localPos)
    if key == "roll" then
        return -localPos.y, localPos.z
    elseif key == "pitch" then
        return localPos.x, localPos.z
    end

    return localPos.x, -localPos.y
end

local function ringAngle(key, localPos)
    local u, v = ringCoords(key, localPos)
    return math.atan2(v, u)
end

local function ringRotationDeltaSign(key)
    -- Die sichtbare Ring-Geometrie fuer Roll/Yaw braucht die gespiegelte lokale
    -- Y-Achse, RotateAroundAxis erwartet fuer diese beiden Achsen aber weiterhin
    -- das urspruengliche Vorzeichen des Drag-Deltas.
    return key == "pitch" and 1 or -1
end

local function clampRotationSnapIndex(index)
    return math.Clamp(math.Round(tonumber(index) or ROTATION_CONFIG.defaultSnapIndex), 1, #ROTATION_CONFIG.snapDivisors)
end

local function clampTranslationSnapStep(step)
    return tonumber(step) or 0 --math.Clamp(tonumber(step) or 0, 0, 62) --nonono --TODO Remove unnecessary clamps
end

local function rotationSnapDivisions(tool)
    local index = clampRotationSnapIndex(clientNumber(tool, "rotation_snap", ROTATION_CONFIG.defaultSnapIndex))
    return ROTATION_CONFIG.snapDivisors[index], index
end

local function rotationSnapStep(tool)
    local divisions = rotationSnapDivisions(tool)
    return 360 / math.max(divisions or ROTATION_CONFIG.snapDivisors[ROTATION_CONFIG.defaultSnapIndex], 1)
end

local function translationSnapStep(tool)
    return clampTranslationSnapStep(clientNumber(tool, "translation_snap", 0))
end

local function normalizeDegrees(angle)
    angle = tonumber(angle) or 0
    angle = angle % 360
    if angle < 0 then
        angle = angle + 360
    end

    return angle
end

local function snapRotationAngle(angle, step)
    if step <= M.COMPUTE_EPSILON then
        return normalizeDegrees(angle)
    end

    return normalizeDegrees(math.Round(normalizeDegrees(angle) / step) * step)
end

local function isAngleMultiple(angle, interval)
    local remainder = normalizeDegrees(angle) % interval
    return remainder <= M.UI_COMPARE_EPSILON or math.abs(remainder - interval) <= M.UI_COMPARE_EPSILON
end

local function isMajorRotationTick(angle)
    return isAngleMultiple(angle, 30) or isAngleMultiple(angle, 45)
end

local function readClientActionTrace()
    local ent = net.ReadEntity()
    local hit = net.ReadBool()
    local hasHitPos = net.ReadBool()
    local hitPos = hasHitPos and net.ReadPreciseVector() or nil
    local hasHitNormal = net.ReadBool()
    local hitNormal = hasHitNormal and net.ReadPreciseVector() or nil
    local hitWorld = net.ReadBool()
    local physBone = net.ReadUInt(16)

    return {
        Entity = ent,
        Hit = hit,
        HitPos = hitPos,
        HitNormal = hitNormal,
        HitWorld = hitWorld,
        PhysicsBone = physBone
    }
end

local function clientActionWouldAffect(action, trace)
    if action == M.CLIENT_ACTION_LEFTCLICK and isfunction(core.leftClickWouldAffect) then
        return core.leftClickWouldAffect(trace)
    elseif action == M.CLIENT_ACTION_RIGHTCLICK and isfunction(core.rightClickWouldAffect) then
        return core.rightClickWouldAffect(trace)
    elseif action == M.CLIENT_ACTION_RESET and isfunction(core.reloadWouldAffect) then
        return core.reloadWouldAffect(trace)
    end

    return true
end

local function playClientActionFeedback(action, trace)
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    local getter = M.GetActiveClassicMagicAlignTool or M.GetActiveMagicAlignTool
    local tool, weapon = getter(ply)
    if not tool or not IsValid(weapon) then return false end

    local wouldAffect = clientActionWouldAffect(action, trace)
    local feedbackAction = action == M.CLIENT_ACTION_RESET and "reset" or "normal"
    local feedbackTrace = {
        Entity = trace and trace.Entity or NULL,
        Hit = trace and trace.Hit == true,
        HitPos = trace and trace.HitPos or nil,
        HitNormal = trace and trace.HitNormal or nil,
        HitWorld = trace and trace.HitWorld == true,
        PhysicsBone = math.max(math.floor(tonumber(trace and trace.PhysicsBone) or 0), 0)
    }

    queuedClientActionFeedback = {
        action = feedbackAction,
        wouldAffect = wouldAffect,
        trace = feedbackTrace,
        queuedAt = RealTime()
    }
    return true
end

function core.consumeClientActionFeedback()
    local feedback = queuedClientActionFeedback
    queuedClientActionFeedback = nil

    if not feedback then return end
    if RealTime() - (tonumber(feedback.queuedAt) or 0) > 0.25 then return end

    return feedback
end

net.Receive(M.NET_CLIENT_ACTION, function()
    local action = net.ReadUInt(2)
    local trace = readClientActionTrace()

    if action == M.CLIENT_ACTION_MAGIC_MIRROR_LEFTCLICK then
        local mirrorClient = client.MagicMirror
        if mirrorClient and isfunction(mirrorClient.handleClientAction) then
            mirrorClient.handleClientAction(action, trace)
        end
        return
    end

    playClientActionFeedback(action, trace)

    if action == M.CLIENT_ACTION_LEFTCLICK and isfunction(core.queueClientLeftClick) then
        core.queueClientLeftClick()
    elseif action == M.CLIENT_ACTION_RIGHTCLICK and isfunction(performClientRightClick) then
        performClientRightClick(trace)
    elseif action == M.CLIENT_ACTION_RESET and isfunction(performClientReload) then
        performClientReload()
    end
end)

net.Receive(M.NET_BOUNDS_REPLY, function()
    local ent = net.ReadEntity()
    local sessionId = net.ReadUInt(32)
    local hasBounds = net.ReadBool()
    local mins = hasBounds and net.ReadPreciseVector() or nil
    local maxs = hasBounds and net.ReadPreciseVector() or nil
    local state = stateBySessionId(sessionId)

    if not state or not IsValid(ent) or state.sessionId ~= sessionId then return end

    local entry = state.bounds[ent]
    if not istable(entry) then
        entry = {}
        state.bounds[ent] = entry
    end

    local revision = boundsRevision(ent)
    if entry.requestRevision and revision ~= entry.requestRevision then
        resetBoundsEntry(entry)
        entry.revision = revision
        return
    end

    resetBoundsEntry(entry)
    entry.revision = revision
    entry.mirrorRevision = mirrorBoundsRevision(ent)

    if isvector(mins) and isvector(maxs) then
        entry.size = maxs - mins
        entry.mins = mins
        entry.maxs = maxs
        entry.center = (mins + maxs) * 0.5
        entry.ready = true
    end
end)

local function boundsEntry(state, ent)
    if not IsValid(ent) then return end

    local entry = state.bounds[ent]
    if istable(entry) and entry.pending ~= nil then
        return entry
    end

    entry = {
        requestedAt = 0,
        pending = false,
        ready = false,
        size = nil,
        mins = nil,
        maxs = nil,
        center = nil
    }
    state.bounds[ent] = entry

    return entry
end

local function requestBounds(state, ent)
    state = ensureStateShape(state)
    local entry = boundsEntry(state, ent)
    if not entry then return end
    local revision = maybeRefreshBoundsEntry(ent, entry)

    local now = RealTime()
    if entry.ready then return true end
    if now - entry.requestedAt < M.AABB_REQUEST_COOLDOWN then return false end

    entry.pending = true
    entry.requestedAt = now
    entry.requestRevision = revision or boundsRevision(ent)

    net.Start(M.NET_BOUNDS_REQUEST)
        net.WriteEntity(ent)
        net.WriteUInt(state.sessionId, 32)
    net.SendToServer()

    return false
end

local function boundsFor(state, ent)
    local entry = IsValid(ent) and state.bounds[ent] or nil
    maybeRefreshBoundsEntry(ent, entry)
    return istable(entry) and entry.ready and entry or nil
end

local function activeTool()
    local ply = LocalPlayer()
    local getter = M.GetActiveClassicMagicAlignTool or M.GetActiveMagicAlignTool
    local tool = IsValid(ply) and getter(ply) or nil
    if not tool then return end

    return tool, state()
end

local function uiBlocked()
    return vgui.CursorVisible() and (IsValid(vgui.GetHoveredPanel()) or IsValid(vgui.GetKeyboardFocus()))
end

local function cycleReferenceSpace(tool, step)
    if not tool then return end

    local currentSpace = tool:GetClientInfo("space")
    local currentIndex = 1
    local spaces = M.UI_SPACES or M.SPACES

    for i = 1, #spaces do
        if spaces[i] == currentSpace then
            currentIndex = i
            break
        end
    end

    local nextIndex = currentIndex + (tonumber(step) or 1)
    while nextIndex < 1 do
        nextIndex = nextIndex + #spaces
    end
    while nextIndex > #spaces do
        nextIndex = nextIndex - #spaces
    end

    local nextSpace = spaces[nextIndex]
    if not nextSpace then return end

    setClientActiveSpace(nextSpace, M.ClientState)
end

local referenceSpaceSelectorHeld = false
local referenceSpaceSelectorScrolled = false

local function setReferenceSpaceSelectorHeld(bindName, pressed)
    if string.sub(bindName, 1, 1) == "+" then
        referenceSpaceSelectorHeld = pressed == true
        if referenceSpaceSelectorHeld then
            referenceSpaceSelectorScrolled = false
        end
    elseif string.sub(bindName, 1, 1) == "-" or pressed == false then
        referenceSpaceSelectorHeld = false
    end
end

local function referenceSpaceSelectorDown()
    if referenceSpaceSelectorHeld then return true end
    return input.IsKeyDown(KEY_TAB)
end

local function wheelReferenceSpaceStep(bindName)
    if string.find(bindName, "invnext", 1, true) then return -1 end
    if string.find(bindName, "invprev", 1, true) then return 1 end
end

local function referenceSpaceSelectorReleased(bindName, pressed)
    return string.sub(bindName, 1, 1) == "-" or pressed == false
end

local function withReferenceSpaceDirectionModifiers(step)
    if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
        return -step
    end

    return step
end

hook.Add("PlayerBindPress", "MagicAlignCycleReferenceSpace", function(ply, bind, pressed)
    local bindName = string.lower(tostring(bind or ""))
    local isReferenceSpaceSelector = string.find(bindName, "showscores", 1, true) ~= nil
    local wheelStep = wheelReferenceSpaceStep(bindName)

    if isReferenceSpaceSelector then
        setReferenceSpaceSelectorHeld(bindName, pressed)
    end

    if not isReferenceSpaceSelector and not wheelStep then return end

    local getter = M.GetActiveClassicMagicAlignTool or M.GetActiveMagicAlignTool
    local tool = getter(ply)
    if not tool then return end

    if isReferenceSpaceSelector then
        if referenceSpaceSelectorReleased(bindName, pressed)
            and not referenceSpaceSelectorScrolled
            and not uiBlocked() then
            cycleReferenceSpace(tool, withReferenceSpaceDirectionModifiers(1))
        end

        return true
    end

    if wheelStep and referenceSpaceSelectorDown() then
        if pressed ~= false then
            referenceSpaceSelectorScrolled = true
            if not uiBlocked() then
                cycleReferenceSpace(tool, withReferenceSpaceDirectionModifiers(wheelStep))
            end
        end

        return true
    end
end)

net.Receive(M.NET_COMMIT_RESULT, function()
    local commitId = net.ReadUInt(32)
    local accepted = net.ReadBool()
    local reason = net.ReadUInt(4)

    M.EntityMirror.ResolveVisualPrediction(commitId, accepted)

    local upload = M.CommitUpload
    if istable(upload) and upload.id == commitId then
        upload.resultAccepted = accepted
        upload.resultReason = reason
        upload.resultAt = RealTime()

        if accepted and not upload.primitivePointsMigrated then
            upload.primitivePointsMigrated = true
            local mirrorClient = client.Mirror
            if mirrorClient and isfunction(mirrorClient.migrateCommittedPrimitivePoints) then
                mirrorClient.migrateCommittedPrimitivePoints(upload.payload)
            end
        end

        if not accepted then
            upload.phase = "rejected"
            upload.finishedAt = RealTime()
        end
    end
end)

local function restoreSessionOnUndoEnabled()
    local cvar = GetConVar("magic_align_restore_session_on_undo")
    return not cvar or cvar:GetBool()
end

local function applyRestoredOffsets(offsets)
    offsets = istable(offsets) and offsets or {}

    for i = 1, #(M.SPACES or {}) do
        local space = M.SPACES[i]
        local offset = offsets[space]
        if istable(offset) then
            if M.IsFiniteVector(offset.pos) then
                RunConsoleCommand("magic_align_" .. space .. "_px", M.FormatConVarNumber(offset.pos.x))
                RunConsoleCommand("magic_align_" .. space .. "_py", M.FormatConVarNumber(offset.pos.y))
                RunConsoleCommand("magic_align_" .. space .. "_pz", M.FormatConVarNumber(offset.pos.z))
            end
            if M.IsFiniteAngle(offset.rot) then
                RunConsoleCommand("magic_align_" .. space .. "_pitch", M.FormatConVarNumber(offset.rot.p))
                RunConsoleCommand("magic_align_" .. space .. "_yaw", M.FormatConVarNumber(offset.rot.y))
                RunConsoleCommand("magic_align_" .. space .. "_roll", M.FormatConVarNumber(offset.rot.r))
            end
        end
    end

    if M.Client and M.Client.updateSessionTabTitles then
        M.Client.updateSessionTabTitles()
    end
end

local function applyRestoredAnchorSide(prefix, side)
    side = istable(side) and side or {}
    local options = M.NormalizeAnchorOptions(side.options)
    local selected = string.lower(tostring(side.selected or ""))
    local priority = tostring(side.priority or "")

    if selected ~= "" then
        RunConsoleCommand("magic_align_" .. prefix .. "_anchor", selected)
    end
    if priority ~= "" then
        RunConsoleCommand("magic_align_" .. prefix .. "_priority", priority)
    end

    RunConsoleCommand("magic_align_" .. prefix .. "_mid12_pct", M.FormatConVarNumber(options.mid12_pct))
    RunConsoleCommand("magic_align_" .. prefix .. "_mid23_pct", M.FormatConVarNumber(options.mid23_pct))
    RunConsoleCommand("magic_align_" .. prefix .. "_mid13_pct", M.FormatConVarNumber(options.mid13_pct))
end

local function applyRestoredAnchors(anchors)
    anchors = istable(anchors) and anchors or {}
    applyRestoredAnchorSide("from", anchors.from)
    applyRestoredAnchorSide("to", anchors.to)
end

local function applyUndoSessionSnapshot(snapshot)
    if not restoreSessionOnUndoEnabled() then return false end

    local tool = select(1, activeTool())
    local currentSpace = tool and client.activeSpaceForTool(tool) or client.activeSpace()
    local restored, meta = M.RestoreSessionSnapshot(snapshot, {
        currentSpace = currentSpace
    })
    if not restored then return false end

    clearSessionVisuals(M.ClientState)
    M.ClientState = ensureStateShape(restored)
    applyRestoredOffsets(meta and meta.offsets)
    applyRestoredAnchors(meta and meta.anchors)

    if meta and meta.entityMirrorEnabled ~= nil then
        RunConsoleCommand("magic_align_mirror_entity_mirror", meta.entityMirrorEnabled and "1" or "0")
    end

    setClientActiveSpace((meta and meta.activeSpace) or restored.activeSpace, restored)
    M.RefreshState(restored)

    return true
end

net.Receive(M.NET_UNDO_RESTORE, function()
    local count = net.ReadUInt(8)
    local poses = {}

    for i = 1, count do
        local ent = net.ReadEntity()
        local fromPos = net.ReadPreciseVector()
        local fromAng = net.ReadPreciseAngle()
        local toPos = net.ReadPreciseVector()
        local toAng = net.ReadPreciseAngle()

        if IsValid(ent)
            and M.IsPrimitive
            and M.IsPrimitive(ent)
            and isvector(fromPos)
            and isangle(fromAng)
            and isvector(toPos)
            and isangle(toAng) then
            poses[ent] = {
                fromPos = fromPos,
                fromAng = fromAng,
                toPos = toPos,
                toAng = toAng
            }
        end
    end

    local snapshot = M.ReadSessionSnapshot()
    if snapshot then
        applyUndoSessionSnapshot(snapshot)
        return
    end

    local mirrorClient = client.Mirror
    if mirrorClient and isfunction(mirrorClient.rebasePrimitivePointsForUndo) then
        mirrorClient.rebasePrimitivePointsForUndo(poses)
    end
end)

core.colors = colors
client.colors = colors
core.registerSessionState = registerSessionState
core.stateBySessionId = stateBySessionId
core.ensureStateShape = ensureStateShape
core.comp = comp
core.copyVec = copyVec
core.copyAng = copyAng
core.ZERO_VEC = ZERO_VEC
core.ZERO_ANG = ZERO_ANG
core.LocalToWorldPosPrecise = LocalToWorldPosPrecise
core.WorldToLocalPosPrecise = WorldToLocalPosPrecise
core.setVec = setVec
core.normalizedVec = normalizedVec
core.clientNumber = clientNumber
core.buildTraceSample = buildTraceSample
core.sampleWorldPos = sampleWorldPos
core.sampleLocalPos = sampleLocalPos
core.sampleLocalNormal = sampleLocalNormal
core.aggregateTraceProbes = aggregateTraceProbes
core.buildTraceProbeCandidate = buildTraceProbeCandidate
core.ghostAlpha = ghostAlpha
core.linkedGhostAlpha = linkedGhostAlpha
core.isLinkedProp = isLinkedProp
core.removeLinkedGhost = removeLinkedGhost
core.resetLinkedProps = resetLinkedProps
core.removeLinkedProp = removeLinkedProp
core.cleanupLinkedProps = cleanupLinkedProps
core.cleanupTargetPointReferences = cleanupTargetPointReferences
core.commitMode = commitMode
core.updateToolHelp = updateToolHelp
core.ensureGhostModel = ensureGhostModel
core.applyGhostAppearance = applyGhostAppearance
core.hideGhosts = hideGhosts
core.ringCoords = ringCoords
core.ringAngle = ringAngle
core.ringRotationDeltaSign = ringRotationDeltaSign
core.rotationSnapDivisions = rotationSnapDivisions
core.rotationSnapStep = rotationSnapStep
core.translationSnapStep = translationSnapStep
core.snapRotationAngle = snapRotationAngle
core.isMajorRotationTick = isMajorRotationTick
core.requestBounds = requestBounds
core.boundsFor = boundsFor
core.activeTool = activeTool
core.uiBlocked = uiBlocked

return core
