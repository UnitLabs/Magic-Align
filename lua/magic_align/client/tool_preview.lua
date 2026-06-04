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
local GHOST_REFRESH_INTERVAL = core.GHOST_REFRESH_INTERVAL
local colors = core.colors
local copyVec = core.copyVec
local copyAng = core.copyAng
local ZERO_VEC = core.ZERO_VEC
local ZERO_ANG = core.ZERO_ANG
local LocalToWorldPosPrecise = core.LocalToWorldPosPrecise
local WorldToLocalPosPrecise = core.WorldToLocalPosPrecise
local setVec = core.setVec
local normalizedVec = core.normalizedVec
local clientNumber = core.clientNumber
local ensureStateShape = core.ensureStateShape
local boundsFor = core.boundsFor
local cachedOffsets = core.cachedOffsets
local cachedAnchorOptions = core.cachedAnchorOptions
local selectedAnchorState = core.selectedAnchorState
local anchorResultCache = core.anchorResultCache
local currentFrameNumber = core.currentFrameNumber
local pointWorldCache = core.pointWorldCache
local buildTraceSample = core.buildTraceSample
local sampleWorldPos = core.sampleWorldPos
local aggregateTraceProbes = core.aggregateTraceProbes
local requestBounds = core.requestBounds
local rememberNonMirrorSpace = core.rememberNonMirrorSpace
local editable = core.editable
local isLinkedProp = core.isLinkedProp
local removeLinkedGhost = core.removeLinkedGhost
local commitMode = core.commitMode
local ensureGhostModel = core.ensureGhostModel
local applyGhostAppearance = core.applyGhostAppearance
local hideGhosts = core.hideGhosts
local ghostAlpha = core.ghostAlpha
local linkedGhostAlpha = core.linkedGhostAlpha
local cfg = core.cfg
local faceCandidate = core.faceCandidate
local worldCandidateFromTrace = core.worldCandidateFromTrace
local hoverPoint = core.hoverPoint
local targetPointPressActive = core.targetPointPressActive
local gizmo = core.gizmo
local function clearHover(hover)
    hover.rawTrace = nil
    hover.trace = nil
    hover.settings = nil
    hover.gizmo = nil
    hover.side = nil
    hover.points = nil
    hover.ent = nil
    hover.point = nil
    hover.candidate = nil
    hover.box = nil
    hover.pickSource = nil
    hover.pickTarget = nil
    hover.overlayBox = nil
    hover.overlay = nil
    hover.worldBspBlockers = nil
    hover.worldBspCandidateCache = nil
    hover.worldBspStableCandidateCache = nil
end

local function markPointSnapshot(cache, prefix, points)
    local count = #points
    local changed = cache[prefix .. "Count"] ~= count
    cache[prefix .. "Count"] = count

    for i = 1, M.MAX_POINTS do
        local point = points[i]
        local base = prefix .. i
        if isvector(point) then
            if cache[base .. "x"] ~= point.x or cache[base .. "y"] ~= point.y or cache[base .. "z"] ~= point.z then
                changed = true
                cache[base .. "x"], cache[base .. "y"], cache[base .. "z"] = point.x, point.y, point.z
            end

            local normal = point.normal
            if isvector(normal) then
                if cache[base .. "nx"] ~= normal.x or cache[base .. "ny"] ~= normal.y or cache[base .. "nz"] ~= normal.z then
                    changed = true
                    cache[base .. "nx"], cache[base .. "ny"], cache[base .. "nz"] = normal.x, normal.y, normal.z
                end
            elseif cache[base .. "nx"] ~= nil then
                changed = true
                cache[base .. "nx"], cache[base .. "ny"], cache[base .. "nz"] = nil, nil, nil
            end

            local world = point.world == true or nil
            if cache[base .. "world"] ~= world then
                changed = true
                cache[base .. "world"] = world
            end

            local ref = point.reference
            local refKind = istable(ref) and ref.kind or nil
            local refEnt = istable(ref) and ref.ent or nil
            if cache[base .. "refKind"] ~= refKind or cache[base .. "refEnt"] ~= refEnt then
                changed = true
                cache[base .. "refKind"] = refKind
                cache[base .. "refEnt"] = refEnt
            end
        elseif cache[base .. "x"] ~= nil then
            changed = true
            cache[base .. "x"], cache[base .. "y"], cache[base .. "z"] = nil, nil, nil
            cache[base .. "nx"], cache[base .. "ny"], cache[base .. "nz"] = nil, nil, nil
            cache[base .. "world"] = nil
            cache[base .. "refKind"] = nil
            cache[base .. "refEnt"] = nil
        end
    end

    return changed
end

local function markPoseSnapshot(cache, prefix, ent)
    if not IsValid(ent) then
        local changed = cache[prefix .. "Ent"] ~= ent or cache[prefix .. "mirrorAxis"] ~= nil
        cache[prefix .. "Ent"] = ent
        cache[prefix .. "mirrorAxis"] = nil
        return changed
    end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local mirrorAxis = M.EntityMirror and M.EntityMirror.GetAxis and M.EntityMirror.GetAxis(ent) or nil
    local changed = cache[prefix .. "Ent"] ~= ent
        or cache[prefix .. "px"] ~= pos.x or cache[prefix .. "py"] ~= pos.y or cache[prefix .. "pz"] ~= pos.z
        or cache[prefix .. "ap"] ~= ang.p or cache[prefix .. "ay"] ~= ang.y or cache[prefix .. "ar"] ~= ang.r
        or cache[prefix .. "mirrorAxis"] ~= mirrorAxis

    cache[prefix .. "Ent"] = ent
    cache[prefix .. "px"], cache[prefix .. "py"], cache[prefix .. "pz"] = pos.x, pos.y, pos.z
    cache[prefix .. "ap"], cache[prefix .. "ay"], cache[prefix .. "ar"] = ang.p, ang.y, ang.r
    cache[prefix .. "mirrorAxis"] = mirrorAxis

    return changed
end

local function markLinkedSnapshot(cache, state)
    local linked = state.linked or {}
    local changed = cache.linkedCount ~= #linked
    cache.linkedCount = #linked

    for i = 1, #linked do
        if markPoseSnapshot(cache, "linked" .. i, linked[i]) then
            changed = true
        end
    end

    local staleIndex = #linked + 1
    while cache["linked" .. staleIndex .. "Ent"] ~= nil do
        changed = true
        cache["linked" .. staleIndex .. "Ent"] = nil
        cache["linked" .. staleIndex .. "mirrorAxis"] = nil
        staleIndex = staleIndex + 1
    end

    return changed
end

function client.markMirrorSnapshot(cache, state)
    local mirror = state.mirror or {}
    local changed = false

    local active = M.IsMirrorMode and M.IsMirrorMode(state)
    if cache.mirrorActive ~= active then
        cache.mirrorActive = active
        changed = true
    end

    if markPointSnapshot(cache, "mirror", mirror.points or {}) then
        changed = true
    end

    local seenRefs = {}
    local refCount = 0
    for i = 1, #(mirror.points or {}) do
        local ref = M.ResolvePointReference(mirror.points[i])
        if IsValid(ref) and not seenRefs[ref] then
            seenRefs[ref] = true
            refCount = refCount + 1
            if markPoseSnapshot(cache, "mirrorRef" .. refCount, ref) then
                changed = true
            end
        end
    end

    if cache.mirrorRefCount ~= refCount then
        cache.mirrorRefCount = refCount
        changed = true
    end

    local staleRef = refCount + 1
    while cache["mirrorRef" .. staleRef .. "Ent"] ~= nil do
        changed = true
        cache["mirrorRef" .. staleRef .. "Ent"] = nil
        staleRef = staleRef + 1
    end

    return changed
end

function client.markTargetReferenceSnapshot(cache, state, pointsOverride)
    local changed = false
    local points = pointsOverride or state.target or {}
    local seenRefs = {}
    local refCount = 0

    for i = 1, #points do
        local ref = M.ResolvePointReference and M.ResolvePointReference(points[i], state.prop2) or state.prop2
        if IsValid(ref) and ref ~= state.prop2 and not seenRefs[ref] then
            seenRefs[ref] = true
            refCount = refCount + 1
            if markPoseSnapshot(cache, "targetRef" .. refCount, ref) then
                changed = true
            end
        end
    end

    if cache.targetRefCount ~= refCount then
        cache.targetRefCount = refCount
        changed = true
    end

    local staleRef = refCount + 1
    while cache["targetRef" .. staleRef .. "Ent"] ~= nil do
        changed = true
        cache["targetRef" .. staleRef .. "Ent"] = nil
        cache["targetRef" .. staleRef .. "mirrorAxis"] = nil
        staleRef = staleRef + 1
    end

    return changed
end

local function previewInputsChanged(state, cache, offsetRevision, sourceAnchorRevision, targetAnchorRevision, sourceAnchorId, sourcePriority, targetAnchorId, targetPriority)
    local changed = false

    if markPoseSnapshot(cache, "prop1", state.prop1) then changed = true end
    if markPoseSnapshot(cache, "prop2", state.prop2) then changed = true end
    if markPointSnapshot(cache, "source", state.source) then changed = true end
    if markPointSnapshot(cache, "target", state.target) then changed = true end
    if client.markTargetReferenceSnapshot(cache, state) then changed = true end
    if client.markMirrorSnapshot(cache, state) then changed = true end
    if markLinkedSnapshot(cache, state) then changed = true end

    if cache.offsetRevision ~= offsetRevision then cache.offsetRevision = offsetRevision; changed = true end
    if cache.sourceAnchorRevision ~= sourceAnchorRevision then cache.sourceAnchorRevision = sourceAnchorRevision; changed = true end
    if cache.targetAnchorRevision ~= targetAnchorRevision then cache.targetAnchorRevision = targetAnchorRevision; changed = true end
    if cache.sourceAnchorId ~= sourceAnchorId then cache.sourceAnchorId = sourceAnchorId; changed = true end
    if cache.targetAnchorId ~= targetAnchorId then cache.targetAnchorId = targetAnchorId; changed = true end
    if cache.sourcePriority ~= sourcePriority then cache.sourcePriority = sourcePriority; changed = true end
    if cache.targetPriority ~= targetPriority then cache.targetPriority = targetPriority; changed = true end

    return changed
end

local function markVecSnapshot(cache, prefix, value)
    if isvector(value) then
        local changed = cache[prefix .. "x"] ~= value.x or cache[prefix .. "y"] ~= value.y or cache[prefix .. "z"] ~= value.z
        cache[prefix .. "x"], cache[prefix .. "y"], cache[prefix .. "z"] = value.x, value.y, value.z
        return changed
    end

    if cache[prefix .. "x"] ~= nil or cache[prefix .. "y"] ~= nil or cache[prefix .. "z"] ~= nil then
        cache[prefix .. "x"], cache[prefix .. "y"], cache[prefix .. "z"] = nil, nil, nil
        return true
    end

    return false
end

local function markPendingCandidateSnapshot(cache, prefix, candidate)
    local changed = false
    local isWorld = geometry.isWorldTarget(candidate.ent) or nil
    local face = candidate.face
    local hasFace = istable(face)
    local surface = hasFace and face.surface or nil
    local snapMode = hasFace and face.snapMode or nil
    local uSnap = hasFace and face.uSnap or nil
    local vSnap = hasFace and face.vSnap or nil
    local gridUId = hasFace and face.snapGridUId or nil
    local gridVId = hasFace and face.snapGridVId or nil
    local indexU = hasFace and face.snapIndexU or nil
    local indexV = hasFace and face.snapIndexV or nil

    if cache[prefix .. "Ent"] ~= candidate.ent then cache[prefix .. "Ent"] = candidate.ent; changed = true end
    if cache[prefix .. "Mode"] ~= candidate.mode then cache[prefix .. "Mode"] = candidate.mode; changed = true end
    if cache[prefix .. "World"] ~= isWorld then cache[prefix .. "World"] = isWorld; changed = true end
    if markVecSnapshot(cache, prefix .. "LocalPos", candidate.localPos) then changed = true end
    if markVecSnapshot(cache, prefix .. "LocalNormal", candidate.localNormal) then changed = true end
    if markVecSnapshot(cache, prefix .. "WorldPos", candidate.worldPos) then changed = true end
    if markVecSnapshot(cache, prefix .. "Normal", candidate.normal) then changed = true end

    if cache[prefix .. "Surface"] ~= surface then cache[prefix .. "Surface"] = surface; changed = true end
    if cache[prefix .. "SnapMode"] ~= snapMode then cache[prefix .. "SnapMode"] = snapMode; changed = true end
    if cache[prefix .. "USnap"] ~= uSnap then cache[prefix .. "USnap"] = uSnap; changed = true end
    if cache[prefix .. "VSnap"] ~= vSnap then cache[prefix .. "VSnap"] = vSnap; changed = true end
    if cache[prefix .. "GridUId"] ~= gridUId then cache[prefix .. "GridUId"] = gridUId; changed = true end
    if cache[prefix .. "GridVId"] ~= gridVId then cache[prefix .. "GridVId"] = gridVId; changed = true end
    if cache[prefix .. "IndexU"] ~= indexU then cache[prefix .. "IndexU"] = indexU; changed = true end
    if cache[prefix .. "IndexV"] ~= indexV then cache[prefix .. "IndexV"] = indexV; changed = true end

    return changed
end

local function pendingPreviewInputsChanged(state, cache, candidate, offsetRevision, sourceAnchorRevision, targetAnchorRevision, sourceAnchorId, sourcePriority, targetAnchorId, targetPriority)
    local changed = false

    if markPoseSnapshot(cache, "prop1", state.prop1) then changed = true end
    if markPoseSnapshot(cache, "prop2", state.prop2) then changed = true end
    if markPointSnapshot(cache, "source", state.source) then changed = true end
    if markPointSnapshot(cache, "target", state.target) then changed = true end
    if client.markTargetReferenceSnapshot(cache, state) then changed = true end
    if client.markMirrorSnapshot(cache, state) then changed = true end
    if markPendingCandidateSnapshot(cache, "pendingCandidate", candidate) then changed = true end

    if cache.offsetRevision ~= offsetRevision then cache.offsetRevision = offsetRevision; changed = true end
    if cache.sourceAnchorRevision ~= sourceAnchorRevision then cache.sourceAnchorRevision = sourceAnchorRevision; changed = true end
    if cache.targetAnchorRevision ~= targetAnchorRevision then cache.targetAnchorRevision = targetAnchorRevision; changed = true end
    if cache.sourceAnchorId ~= sourceAnchorId then cache.sourceAnchorId = sourceAnchorId; changed = true end
    if cache.targetAnchorId ~= targetAnchorId then cache.targetAnchorId = targetAnchorId; changed = true end
    if cache.sourcePriority ~= sourcePriority then cache.sourcePriority = sourcePriority; changed = true end
    if cache.targetPriority ~= targetPriority then cache.targetPriority = targetPriority; changed = true end

    return changed
end

client.Mirror = client.Mirror or {}

function client.Mirror.pendingPreviewInputsChanged(state, cache, candidate, mirrorState, sourceAnchorRevision, sourceAnchorId, sourcePriority)
    local changed = false

    if cache.previewMode ~= M.TRANSFORM_MODE_MIRROR then
        cache.previewMode = M.TRANSFORM_MODE_MIRROR
        changed = true
    end
    if markPoseSnapshot(cache, "prop1", state.prop1) then changed = true end
    if markPointSnapshot(cache, "source", state.source) then changed = true end
    if markLinkedSnapshot(cache, state) then changed = true end
    if markPendingCandidateSnapshot(cache, "pendingCandidate", candidate) then changed = true end

    if cache.sourceAnchorRevision ~= sourceAnchorRevision then cache.sourceAnchorRevision = sourceAnchorRevision; changed = true end
    if cache.sourceAnchorId ~= sourceAnchorId then cache.sourceAnchorId = sourceAnchorId; changed = true end
    if cache.sourcePriority ~= sourcePriority then cache.sourcePriority = sourcePriority; changed = true end

    local mirrorRevision = mirrorState and mirrorState.revision or nil
    if cache.baseMirrorRevision ~= mirrorRevision then
        cache.baseMirrorRevision = mirrorRevision
        changed = true
    end

    local entityMirrorEnabled = GetConVar("magic_align_mirror_entity_mirror")
    entityMirrorEnabled = entityMirrorEnabled and entityMirrorEnabled:GetBool() or false
    if cache.entityMirrorEnabled ~= entityMirrorEnabled then
        cache.entityMirrorEnabled = entityMirrorEnabled
        changed = true
    end

    return changed
end

local function markPreviewChangedFrame(state)
    state._magicAlignPreviewChangedFrame = currentFrameNumber()
    state._magicAlignPreviewRevision = (tonumber(state._magicAlignPreviewRevision) or 0) + 1
end

function client.activeSpaceForTool(tool)
    local space = tool and tool.GetClientInfo and tool:GetClientInfo("space") or "prop1"
    rememberNonMirrorSpace(M.ClientState, space)
    return space
end

function client.Mirror.state(state)
    state.mirror = state.mirror or {}
    state.mirror.points = state.mirror.points or {}
    state.mirror.enabled = state.mirror.enabled == true
    return state.mirror
end

function client.Mirror.isActive(tool, state)
    local activeSpace = istable(state) and state.activeSpace or nil
    if not activeSpace then
        activeSpace = client.activeSpaceForTool(tool)
    end

    return M.IsMirrorMode and M.IsMirrorMode(activeSpace) or activeSpace == M.MIRROR_SPACE
end

function client.Mirror.syncEnabled(tool, state)
    local mirror = client.Mirror.state(state)
    local active = client.Mirror.isActive(tool, state)
    mirror.enabled = active
    return active
end

function client.Mirror.cache(state, key)
    if M.GetMirrorStateCache then
        return M.GetMirrorStateCache(state, key)
    end

    local mirror = client.Mirror.state(state)
    key = key or "_magicAlignMirrorCache"
    mirror[key] = mirror[key] or {}
    return mirror[key]
end

function client.Mirror.resolve(state, pointsOverride, key)
    local mirror = client.Mirror.state(state)
    local cache = client.Mirror.cache(state, key)
    local activeSpace = state and state.activeSpace
    local frame = pointsOverride == nil and key == nil and currentFrameNumber() or nil
    if frame ~= nil
        and state._magicAlignMirrorResolveFrame == frame
        and state._magicAlignMirrorResolveCache == cache
        and state._magicAlignMirrorResolveActiveSpace == activeSpace then
        return state._magicAlignMirrorResolveState
    end

    local resolved = M.ResolveMirrorState and M.ResolveMirrorState(mirror, cache, {
        activeSpace = activeSpace,
        points = pointsOverride
    }) or nil

    if frame ~= nil then
        state._magicAlignMirrorResolveFrame = frame
        state._magicAlignMirrorResolveCache = cache
        state._magicAlignMirrorResolveActiveSpace = activeSpace
        state._magicAlignMirrorResolveState = resolved
    end

    return resolved
end

function client.Mirror.reference(state, pointsOverride, key)
    local resolved = client.Mirror.resolve(state, pointsOverride, key)
    local reference = resolved and resolved.reference or nil
    if pointsOverride == nil then
        client.Mirror.state(state).classification = reference and reference.label or nil
    end
    return reference
end

function client.Mirror.classificationLabel(state)
    local resolved = istable(state) and client.Mirror.resolve(state) or nil
    return resolved and resolved.label or "Point"
end

function client.Mirror.handleModifierToggle(tool, state, blocked)
    local worldPoints = client.WorldPoints
    if not (worldPoints and isfunction(worldPoints.handleModifierToggle)) then
        return false
    end

    local handled = worldPoints.handleModifierToggle(state, blocked, "mirror")
    if client.Mirror.isActive(tool, state) then
        worldPoints.handleModifierToggle(state, true, "target")
    end

    return handled
end

function client.Mirror.entityMirrorAxis(reference)
    local enabled = GetConVar("magic_align_mirror_entity_mirror")
    if not (enabled and enabled:GetBool()) then return M.ENTITY_MIRROR_NONE end
    if not (M.EntityMirror and M.EntityMirror.AxisForMirrorReference) then return M.ENTITY_MIRROR_NONE end

    return M.EntityMirror.AxisForMirrorReference(reference)
end

function client.Mirror.previewEntityMirrorAxis(ent, deltaAxis)
    deltaAxis = tonumber(deltaAxis) or M.ENTITY_MIRROR_NONE
    if not (M.EntityMirror and M.EntityMirror.ComposeAxis and M.EntityMirror.GetAxis) then
        return deltaAxis
    end

    return M.EntityMirror.ComposeAxis(M.EntityMirror.GetAxis(ent), deltaAxis)
end

local function copyMirrorReference(reference)
    if not istable(reference) then return end

    local out = {
        kind = reference.kind,
        label = reference.label
    }
    if isvector(reference.point) then out.point = copyVec(reference.point) end
    if isvector(reference.axis) then out.axis = copyVec(reference.axis) end
    if isvector(reference.normal) then out.normal = copyVec(reference.normal) end

    return out
end

local function pointReferenceEntity(point, fallbackEnt)
    if not isvector(point) or point.world == true then return end

    if M.ResolvePointReference then
        return M.ResolvePointReference(point, fallbackEnt)
    end

    return fallbackEnt
end

local function mirrorWorldPoint(worldPos, reference)
    if not isvector(worldPos) or not istable(reference) or not M.MirrorPose then return end

    local mirroredPos = M.MirrorPose(worldPos, ZERO_ANG, reference)
    return isvector(mirroredPos) and mirroredPos or nil
end

function client.Mirror.migrateCommittedPrimitivePoints(payload)
    if not istable(payload) or payload.mode == M.COMMIT_COPY then return false end

    local deltaAxis = math.Clamp(
        math.floor(tonumber(payload.entityMirrorAxis) or M.ENTITY_MIRROR_NONE),
        M.ENTITY_MIRROR_NONE,
        M.ENTITY_MIRROR_Z
    )
    if deltaAxis == M.ENTITY_MIRROR_NONE then return false end

    -- Stored Magic Align points remain unmirrored model-local coordinates.
    -- The committed mirror axis is now part of the shared entity transform, so
    -- mutating session points here would apply the same mirror twice.
    return false
end

local function rebasePrimitivePointByPose(point, pose)
    if not isvector(point) or not istable(pose) then return false end
    if not isvector(pose.fromPos) or not isangle(pose.fromAng)
        or not isvector(pose.toPos) or not isangle(pose.toAng) then
        return false
    end

    local oldLocal = copyVec(point)
    local oldNormal = isvector(point.normal) and copyVec(point.normal) or nil
    local world = LocalToWorldPosPrecise(oldLocal, pose.fromPos, pose.fromAng)
    local newLocal = isvector(world) and WorldToLocalPosPrecise(world, pose.toPos, pose.toAng) or nil
    if not isvector(newLocal) then return false end

    setVec(point, newLocal)

    if oldNormal then
        local oldTipWorld = LocalToWorldPosPrecise(oldLocal + oldNormal, pose.fromPos, pose.fromAng)
        local newTipLocal = isvector(oldTipWorld)
            and WorldToLocalPosPrecise(oldTipWorld, pose.toPos, pose.toAng)
            or nil
        local newNormal = isvector(newTipLocal) and normalizedVec(newTipLocal - newLocal) or nil
        if newNormal then
            point.normal = setVec(point.normal, newNormal)
        else
            point.normal = nil
        end
    end

    return true
end

local function rebasePrimitivePointList(points, fallbackEnt, poses)
    if not istable(points) or not istable(poses) then return false end

    local changed = false
    for i = 1, #points do
        local point = points[i]
        local ent = pointReferenceEntity(point, fallbackEnt)
        local pose = ent and poses[ent] or nil
        if pose and rebasePrimitivePointByPose(point, pose) then
            changed = true
        end
    end

    return changed
end

function client.Mirror.rebasePrimitivePointsForUndo(poses)
    if not istable(poses) or next(poses) == nil then return false end

    local state = ensureStateShape(M.ClientState)
    local changed = false
    changed = rebasePrimitivePointList(state.source, state.prop1, poses) or changed
    changed = rebasePrimitivePointList(state.target, state.prop2, poses) or changed
    changed = rebasePrimitivePointList(client.Mirror.state(state).points, nil, poses) or changed
    if not changed then return false end

    state._magicAlignPreviewCache = nil
    state._magicAlignPendingPreviewCache = nil
    state._magicAlignPendingPreview = nil
    state._magicAlignPendingPoints = nil
    state.pending = nil

    if istable(state.mirror) then
        state.mirror._magicAlignMirrorCache = nil
        state.mirror._magicAlignPendingMirrorCache = nil
    end

    markPreviewChangedFrame(state)
    M.RefreshState(state)

    return true
end

local function applyMirrorAxisToLocalPoint(point, axis)
    local out = isvector(point) and copyVec(point) or copyVec(ZERO_VEC)
    axis = math.Clamp(
        math.floor(tonumber(axis) or M.ENTITY_MIRROR_NONE),
        M.ENTITY_MIRROR_NONE,
        M.ENTITY_MIRROR_Z
    )

    if axis ~= M.ENTITY_MIRROR_NONE
        and M.EntityMirror
        and M.EntityMirror.ApplyAxisToVector then
        M.EntityMirror.ApplyAxisToVector(out, out, axis)
    end

    return out
end

function client.Mirror.sourceAnchorLocal(state, deltaAxis, selected, priority, anchorOptions, reference, targetPos, targetAng)
    local anchorId, anchor = M.ResolveAnchorCached(
        anchorResultCache(state),
        state.source or {},
        selected or "p1",
        priority,
        anchorOptions,
        { copy = true }
    )
    if not isvector(anchor) then
        anchorId = "p1"
        anchor = state.source and state.source[1]
    end

    local mirroredWorld
    if isvector(anchor) and IsValid(state.prop1) and istable(reference) then
        local sourceWorld = M.EntityMirror and M.EntityMirror.LocalPointToWorld
            and M.EntityMirror.LocalPointToWorld(state.prop1, anchor)
        mirroredWorld = mirrorWorldPoint(sourceWorld, reference)
    end

    local mirroredLocal = isvector(mirroredWorld)
        and isvector(targetPos)
        and isangle(targetAng)
        and WorldToLocalPosPrecise(mirroredWorld, targetPos, targetAng)
        or applyMirrorAxisToLocalPoint(anchor, deltaAxis)

    return anchorId, mirroredLocal, mirroredWorld
end

function client.Mirror.previewSolve(state, pos, ang, reference, mirrorState, sourceAnchorId, sourcePriority, sourceAnchorOptions)
    local deltaAxis = client.Mirror.entityMirrorAxis(reference)
    local previewAxis = client.Mirror.previewEntityMirrorAxis(state.prop1, deltaAxis)
    local resolvedSourceAnchorId, sourceAnchorLocal, sourceAnchorWorld = client.Mirror.sourceAnchorLocal(
        state,
        previewAxis,
        sourceAnchorId,
        sourcePriority,
        sourceAnchorOptions,
        reference,
        pos,
        ang
    )
    return {
        mode = M.TRANSFORM_MODE_MIRROR,
        partial = false,
        pos = pos,
        ang = ang,
        axisAng = ang,
        sourceAnchorId = resolvedSourceAnchorId,
        sourceAnchorLocal = sourceAnchorLocal,
        sourceAnchorWorld = sourceAnchorWorld,
        sourceContextLocal = { pos = sourceAnchorLocal },
        sourceContextWorld = sourceAnchorWorld,
        targetAnchorWorld = reference and reference.point or pos,
        sourceCount = #(state.source or {}),
        targetCount = mirrorState and mirrorState.pointCount or #(state.mirror and state.mirror.points or {}),
        hasTarget = true,
        entityMirrorAxis = deltaAxis,
        entityMirrorPreviewAxis = previewAxis,
        mirrorReference = reference
    }
end

function client.Mirror.applyPreview(state, reference, preview, mirrorState, sourceAnchorId, sourcePriority, sourceAnchorOptions)
    local transformed = M.ApplyTransformModeToPropSet(M.TRANSFORM_MODE_MIRROR, state.prop1, state.linked, reference, {
        linked = preview and preview.linked or {}
    })
    if not transformed then return end

    preview = preview or {}
    local deltaAxis = client.Mirror.entityMirrorAxis(reference)
    preview.solve = client.Mirror.previewSolve(
        state,
        transformed.pos,
        transformed.ang,
        reference,
        mirrorState,
        sourceAnchorId,
        sourcePriority,
        sourceAnchorOptions
    )
    preview.pos = transformed.pos
    preview.ang = transformed.ang
    preview.spaceBasis = {}
    preview.referenceBasis = {}
    preview.basePos = transformed.pos
    preview.baseAng = transformed.ang
    preview.linked = transformed.linked or {}
    preview.transformMode = M.TRANSFORM_MODE_MIRROR
    preview.mirrorReference = reference
    preview.absoluteLinked = true
    preview.entityMirrorAxis = deltaAxis
    preview.entityMirrorPreviewAxis = client.Mirror.previewEntityMirrorAxis(state.prop1, preview.entityMirrorAxis)

    for i = 1, #(preview.linked or {}) do
        local entry = preview.linked[i]
        if istable(entry) then
            entry.entityMirrorPreviewAxis = client.Mirror.previewEntityMirrorAxis(entry.ent, preview.entityMirrorAxis)
        end
    end

    return preview
end

function client.Mirror.displayContext(tool, state)
    if not istable(state) or not client.Mirror.isActive(tool, state) then return end

    local mirrorState = client.Mirror.resolve(state)
    local context = state._magicAlignMirrorDisplayContext or {}
    state._magicAlignMirrorDisplayContext = context

    context.active = true
    context.label = TOOL_UI.spaceLabels.mirror or "Mirror"
    context.accent = colors.mirror
    context.pointCount = mirrorState and mirrorState.pointCount or 0
    context.pointText = nil
    context.targetWorldPos = mirrorState and mirrorState.hasMidpoint and mirrorState.midpoint or nil
    context.reference = mirrorState and mirrorState.reference or nil
    context.classification = mirrorState and mirrorState.label or "Point"

    return context
end

function client.Mirror.previewInputsChanged(state, cache, mirrorState, sourceAnchorRevision, sourceAnchorId, sourcePriority)
    local changed = false

    if cache.previewMode ~= M.TRANSFORM_MODE_MIRROR then
        cache.previewMode = M.TRANSFORM_MODE_MIRROR
        changed = true
    end
    if markPoseSnapshot(cache, "prop1", state.prop1) then changed = true end
    if markPointSnapshot(cache, "source", state.source) then changed = true end
    if markLinkedSnapshot(cache, state) then changed = true end

    if cache.sourceAnchorRevision ~= sourceAnchorRevision then cache.sourceAnchorRevision = sourceAnchorRevision; changed = true end
    if cache.sourceAnchorId ~= sourceAnchorId then cache.sourceAnchorId = sourceAnchorId; changed = true end
    if cache.sourcePriority ~= sourcePriority then cache.sourcePriority = sourcePriority; changed = true end

    local mirrorRevision = mirrorState and mirrorState.revision or nil
    if cache.mirrorRevision ~= mirrorRevision then
        cache.mirrorRevision = mirrorRevision
        changed = true
    end

    local entityMirrorEnabled = GetConVar("magic_align_mirror_entity_mirror")
    entityMirrorEnabled = entityMirrorEnabled and entityMirrorEnabled:GetBool() or false
    if cache.entityMirrorEnabled ~= entityMirrorEnabled then
        cache.entityMirrorEnabled = entityMirrorEnabled
        changed = true
    end

    return changed
end

local function solvePreview(tool, state)
    if not IsValid(state.prop1) then
        if state.preview ~= nil then
            markPreviewChangedFrame(state)
        end

        state.preview = nil
        state.pending = nil
        state._magicAlignPreviewCache = nil
        return
    end

    local cache = state._magicAlignPreviewCache or {}
    state._magicAlignPreviewCache = cache

    if client.Mirror.isActive(tool, state) then
        local sourceAnchorOptions, sourceAnchorRevision = cachedAnchorOptions(tool, state, "from")
        local sourceAnchorId, sourcePriority = selectedAnchorState(tool, state, "from")
        local mirrorState = client.Mirror.resolve(state)
        local changed = client.Mirror.previewInputsChanged(
            state,
            cache,
            mirrorState,
            sourceAnchorRevision,
            sourceAnchorId,
            sourcePriority
        )
        if state.preview and state.preview.transformMode == M.TRANSFORM_MODE_MIRROR and not changed then
            return
        end

        local reference = mirrorState and mirrorState.reference or nil
        local preview = mirrorState and mirrorState.valid and reference
            and client.Mirror.applyPreview(
                state,
                reference,
                state.preview,
                mirrorState,
                sourceAnchorId,
                sourcePriority,
                sourceAnchorOptions
            )
            or nil

        if not preview then
            if state.preview ~= nil then
                markPreviewChangedFrame(state)
            end

            state.preview = nil
            state.pending = nil
            return
        end

        state.preview = preview
        markPreviewChangedFrame(state)
        return
    end

    local sourceAnchorOptions, sourceAnchorRevision = cachedAnchorOptions(tool, state, "from")
    local targetAnchorOptions, targetAnchorRevision = cachedAnchorOptions(tool, state, "to")
    local offsetTable, offsetRevision = cachedOffsets(tool, state)
    local sourceAnchorId, sourcePriority = selectedAnchorState(tool, state, "from")
    local targetAnchorId, targetPriority = selectedAnchorState(tool, state, "to")
    local normalInputsChanged = previewInputsChanged(state, cache, offsetRevision, sourceAnchorRevision, targetAnchorRevision, sourceAnchorId, sourcePriority, targetAnchorId, targetPriority)
    if cache.previewMode ~= "normal" then
        cache.previewMode = "normal"
        normalInputsChanged = true
    end

    if state.preview and state.preview.transformMode ~= M.TRANSFORM_MODE_MIRROR and not normalInputsChanged then
        return
    end

    local solve = M.Solve(
        state.prop1,
        state.source,
        state.prop2,
        state.target,
        sourceAnchorId,
        sourcePriority,
        targetAnchorId,
        targetPriority,
        sourceAnchorOptions,
        targetAnchorOptions,
        {
            pointWorldCache = pointWorldCache(state),
            anchorCache = anchorResultCache(state),
            sourceAnchorRevision = sourceAnchorRevision,
            targetAnchorRevision = targetAnchorRevision
        }
    )

    if not solve then
        if state.preview ~= nil then
            markPreviewChangedFrame(state)
        end

        state.preview = nil
        state.pending = nil
        return
    end

    local rawPos, rawAng, spaceBasis, referenceBasis = M.ComposePose(solve, offsetTable, state.prop2)
    local pos, ang = rawPos, rawAng
    local preview = state.preview or {}
    local linkedPreview = preview.linked or {}
    local linkedCount = 0
    local sourcePos = copyVec(state.prop1:GetPos())
    local sourceAng = copyAng(state.prop1:GetAngles())

    for i = 1, #state.linked do
        local ent = state.linked[i]
        if IsValid(ent) and ent ~= state.prop1 and ent ~= state.prop2 and M.IsProp(ent) then
            local worldPos, worldAng = M.TransformPoseRelativePrecise(ent:GetPos(), ent:GetAngles(), sourcePos, sourceAng, pos, ang)
            if isvector(worldPos) and isangle(worldAng) then
                linkedCount = linkedCount + 1
                local entry = linkedPreview[linkedCount]
                if not istable(entry) then
                    entry = {}
                    linkedPreview[linkedCount] = entry
                end
                entry.ent = ent
                entry.pos = worldPos
                entry.ang = worldAng
                entry.entityMirrorPreviewAxis = client.Mirror.previewEntityMirrorAxis(ent, M.ENTITY_MIRROR_NONE)
            end
        end
    end
    for i = linkedCount + 1, #linkedPreview do
        linkedPreview[i] = nil
    end

    preview.solve = solve
    preview.pos = pos
    preview.ang = ang
    preview.spaceBasis = spaceBasis
    preview.referenceBasis = referenceBasis
    preview.basePos = rawPos
    preview.baseAng = rawAng
    preview.linked = linkedPreview
    preview.transformMode = nil
    preview.mirrorReference = nil
    preview.absoluteLinked = nil
    preview.entityMirrorAxis = M.ENTITY_MIRROR_NONE
    preview.entityMirrorPreviewAxis = client.Mirror.previewEntityMirrorAxis(state.prop1, M.ENTITY_MIRROR_NONE)
    state.preview = preview
    markPreviewChangedFrame(state)
    previewInputsChanged(state, cache, offsetRevision, sourceAnchorRevision, targetAnchorRevision, sourceAnchorId, sourcePriority, targetAnchorId, targetPriority)
end

local function ensureGhost(state)
    if not state.preview or not IsValid(state.prop1) then
        hideGhosts(state)
        return
    end

    local previewRevision = tonumber(state._magicAlignPreviewRevision) or 0
    local now = RealTime()
    if state._magicAlignGhostPreviewRevision == previewRevision
        and now < (tonumber(state._magicAlignNextGhostRefreshAt) or 0) then
        return
    end

    state._magicAlignGhostPreviewRevision = previewRevision
    state._magicAlignNextGhostRefreshAt = now + GHOST_REFRESH_INTERVAL

    if compatGhosts.set(state, state.prop1, state.preview.pos, state.preview.ang, ghostAlpha, false) then
        if IsValid(state.ghost) then
            state.ghost:SetNoDraw(true)
        end
    else
        compatGhosts.clear(state)

        local model = state.prop1:GetModel()
        state.ghost = ensureGhostModel(state.ghost, model)
        if not IsValid(state.ghost) then return end

        applyGhostAppearance(
            state.ghost,
            state.prop1,
            state.preview.pos,
            state.preview.ang,
            ghostAlpha,
            state.preview.entityMirrorPreviewAxis or M.ENTITY_MIRROR_NONE
        )
    end

    local activeLinked = state._magicAlignActiveLinked or {}
    state._magicAlignActiveLinked = activeLinked
    for ent in pairs(activeLinked) do
        activeLinked[ent] = nil
    end
    for i = 1, #(state.preview.linked or {}) do
        local preview = state.preview.linked[i]
        if IsValid(preview.ent) then
            activeLinked[preview.ent] = true

            if compatGhosts.set(state, preview.ent, preview.pos, preview.ang, linkedGhostAlpha, true) then
                local ghost = state.linkedGhosts[preview.ent]
                if IsValid(ghost) then
                    ghost:SetNoDraw(true)
                end
            else
                compatGhosts.clear(state, preview.ent)

                local ghost = ensureGhostModel(state.linkedGhosts[preview.ent], preview.ent:GetModel())
                state.linkedGhosts[preview.ent] = ghost
                if IsValid(ghost) then
                    applyGhostAppearance(
                        ghost,
                        preview.ent,
                        preview.pos,
                        preview.ang,
                        linkedGhostAlpha,
                        preview.entityMirrorPreviewAxis or M.ENTITY_MIRROR_NONE
                    )
                end
            end
        end
    end

    for ent, ghost in pairs(state.linkedGhosts) do
        if not activeLinked[ent] then
            if IsValid(ghost) then
                ghost:SetNoDraw(true)
            end

            if not IsValid(ent) or not isLinkedProp(state, ent) then
                removeLinkedGhost(state, ent)
            end
        end
    end

    local compatLinked = state.compatGhosts and state.compatGhosts.linked or nil
    if istable(compatLinked) then
        for ent in pairs(compatLinked) do
            if not activeLinked[ent] then
                compatGhosts.clear(state, ent)
            end
        end
    end
end

local function hoverState(tool, state)
    local rawTrace = LocalPlayer():GetEyeTrace()
    local settings = cfg(tool, state._magicAlignHoverSettings or {})
    state._magicAlignHoverSettings = settings
    local candidateCache = state._magicAlignWorldBspCandidateCache or {}
    state._magicAlignWorldBspCandidateCache = candidateCache
    candidateCache.count = 0
    local stableCandidateCache = state._magicAlignWorldBspStableCandidateCache or {}
    state._magicAlignWorldBspStableCandidateCache = stableCandidateCache

    local worldBSP = client.WorldBSP
    if worldBSP and isfunction(worldBSP.update) then
        worldBSP.update(settings)
    end

    local tr = rawTrace
    local worldBspBlockers
    if settings.worldTarget and settings.worldBspSnap then
        local traceScratch = state._magicAlignWorldBspTraceScratch or {}
        state._magicAlignWorldBspTraceScratch = traceScratch
        tr, worldBspBlockers = client.worldBspTraceThroughBlockers(rawTrace, settings, traceScratch)
    end

    local hover = state._magicAlignHover or {}
    state._magicAlignHover = hover
    clearHover(hover)
    hover.rawTrace = rawTrace
    hover.trace = tr
    hover.settings = settings
    hover.worldBspBlockers = worldBspBlockers
    hover.worldBspCandidateCache = candidateCache
    hover.worldBspStableCandidateCache = stableCandidateCache
    local activeSpace = client.activeSpaceForTool(tool)
    local mirrorActive = M.IsMirrorMode and M.IsMirrorMode(activeSpace)
    local side, ent, points = editable(state, tr.Entity, tr, activeSpace)
    local pointCache = pointWorldCache(state)

    if IsValid(state.prop1) then requestBounds(state, state.prop1) end
    if IsValid(state.prop2) then requestBounds(state, state.prop2) end
    if IsValid(ent) then requestBounds(state, ent) end

    if state.preview then
        hover.gizmo = gizmo(tool, state)
    end

    if side and ent then
        hover.side = side
        hover.points = points
        hover.ent = ent

        if geometry.traceMatchesEntity(tr, ent) then
            hover.point = hoverPoint(ent, points, side == "target" and state.prop2 or ent, pointCache)

            if side == "source"
                and ent == state.prop1
                and geometry.hasTargetEntity(state.prop2) then
                local targetHoverPoint = hoverPoint(ent, state.target, state.prop2, pointCache)
                if targetHoverPoint or targetPointPressActive(state) then
                    hover.side = "target"
                    hover.points = state.target
                    hover.ent = ent
                    hover.point = targetHoverPoint
                    side = "target"
                    points = state.target
                end
            end

            if geometry.isWorldTarget(ent) then
                hover.candidate = worldCandidateFromTrace(tr, settings, candidateCache, stableCandidateCache)
            else
                hover.box = boundsFor(state, ent)
                hover.candidate = faceCandidate(ent, tr, settings, hover.box)
            end
        end
    end

    if not hover.candidate
        and settings.worldBspIgnoreBrushBlockers
        and istable(worldBspBlockers)
        and #worldBspBlockers > 0
        and not mirrorActive
        and geometry.hasTargetEntity(state.prop2) then
        local candidate = worldCandidateFromTrace(rawTrace, settings, candidateCache, stableCandidateCache)
        if candidate then
            hover.side = "target"
            hover.points = state.target
            hover.ent = M.WORLD_TARGET
            hover.candidate = candidate
        end
    end

    if not IsValid(state.prop1) and M.IsProp(tr.Entity) then
        hover.pickSource = tr.Entity
    elseif not mirrorActive
        and not geometry.hasTargetEntity(state.prop2)
        and #state.source > 0
        and ((M.IsProp(tr.Entity) and tr.Entity ~= state.prop1 and not isLinkedProp(state, tr.Entity))
            or (settings.worldTarget and geometry.traceHitsWorld(tr))) then
        hover.pickTarget = M.IsProp(tr.Entity) and tr.Entity or M.WORLD_TARGET
    end

    if not hover.candidate and M.IsProp(tr.Entity) then
        requestBounds(state, tr.Entity)
        hover.overlayBox = boundsFor(state, tr.Entity)
        hover.overlay = faceCandidate(tr.Entity, tr, settings, hover.overlayBox)
    elseif not mirrorActive
        and not hover.candidate
        and not hover.overlay
        and settings.worldTarget
        and geometry.traceHitsWorld(tr)
        and #state.source > 0 then
        hover.overlay = worldCandidateFromTrace(tr, settings, candidateCache, stableCandidateCache)
    elseif not hover.candidate
        and not hover.overlay
        and settings.worldTarget
        and settings.worldBspIgnoreBrushBlockers
        and istable(worldBspBlockers)
        and #worldBspBlockers > 0
        and not mirrorActive
        and #state.source > 0 then
        hover.overlay = worldCandidateFromTrace(rawTrace, settings, candidateCache, stableCandidateCache)
        if hover.overlay then
            if geometry.hasTargetEntity(state.prop2) then
                hover.side = "target"
                hover.points = state.target
                hover.ent = M.WORLD_TARGET
                hover.candidate = hover.overlay
            else
                hover.pickTarget = M.WORLD_TARGET
            end
        end
    end

    local prepareWorldBspRender = client.prepareWorldBspRenderCandidate
    if isfunction(prepareWorldBspRender) then
        prepareWorldBspRender(hover.candidate)
        if hover.overlay ~= hover.candidate then
            prepareWorldBspRender(hover.overlay)
        end
    end

    return hover
end

local function pointFromCandidateInto(candidate, out, keepReference)
    if not istable(candidate) or not isvector(candidate.localPos) then return end

    if not isvector(out) or out._magicAlignPendingPointScratch ~= true then
        out = VectorP(0, 0, 0)
        out._magicAlignPendingPointScratch = true
    end

    out = setVec(out, candidate.localPos)
    if not out then return end

    local localNormal = normalizedVec(candidate.localNormal)
    if not localNormal and isvector(candidate.normal) then
        local worldPos = isvector(candidate.worldPos) and candidate.worldPos or geometry.worldPosFromLocalPoint(candidate.ent, candidate.localPos)
        localNormal = geometry.localNormalFromWorld(candidate.ent, worldPos, candidate.normal)
    end

    if localNormal then
        out.normal = setVec(out.normal, localNormal)
    else
        out.normal = nil
    end

    out.world = geometry.isWorldTarget(candidate.ent) or nil
    if keepReference and M.SetPointReference then
        M.SetPointReference(out, candidate.ent)
    else
        out.reference = nil
    end
    return out
end

local function copyPointIntoPendingScratch(out, point)
    if not isvector(point) then return end

    if not isvector(out) or out._magicAlignPendingPointScratch ~= true then
        out = VectorP(0, 0, 0)
        out._magicAlignPendingPointScratch = true
    end

    setVec(out, point)

    if isvector(point.normal) then
        out.normal = setVec(out.normal, point.normal)
    else
        out.normal = nil
    end

    out.world = point.world == true or nil
    out.reference = M.CopyPointReference and M.CopyPointReference(point.reference) or nil

    return out
end

local function copyPendingPointList(out, points)
    out = istable(out) and out or {}
    points = istable(points) and points or {}

    local count = #points
    for i = 1, count do
        out[i] = copyPointIntoPendingScratch(out[i], points[i])
    end

    for i = count + 1, #out do
        out[i] = nil
    end

    return out, count
end

local function invalidatePendingPreview(state)
    state.pending = nil

    local cache = state._magicAlignPendingPreviewCache
    if cache then
        cache.valid = false
        cache.hasPending = false
    end
end

local function pendingPreview(tool, state)
    local hoverSide = state.hover and state.hover.side
    local mirrorPending = hoverSide == "mirror"
    local activePoints = mirrorPending and client.Mirror.state(state).points or state.target

    if not IsValid(state.prop1)
        or not state.hover
        or (hoverSide ~= "target" and not mirrorPending)
        or state.hover.point
        or not state.hover.candidate
        or #activePoints >= M.MAX_POINTS then
        invalidatePendingPreview(state)
        return
    end

    local candidate = state.hover.candidate
    if not istable(candidate) or not isvector(candidate.localPos) then
        invalidatePendingPreview(state)
        return
    end

    if mirrorPending then
        local cache = state._magicAlignPendingPreviewCache or {}
        state._magicAlignPendingPreviewCache = cache
        local sourceAnchorOptions, sourceAnchorRevision = cachedAnchorOptions(tool, state, "from")
        local sourceAnchorId, sourcePriority = selectedAnchorState(tool, state, "from")
        local baseMirrorState = client.Mirror.resolve(state)
        local inputsChanged = client.Mirror.pendingPreviewInputsChanged(
            state,
            cache,
            candidate,
            baseMirrorState,
            sourceAnchorRevision,
            sourceAnchorId,
            sourcePriority
        )

        if cache.valid and not inputsChanged then
            if cache.hasPending == false then
                state.pending = nil
                return
            end

            local pending = state._magicAlignPendingPreview
            if pending then
                state.pending = pending
                return
            end
        end

        local points, targetCount = copyPendingPointList(state._magicAlignPendingPoints, activePoints)
        state._magicAlignPendingPoints = points

        local pendingPoint = pointFromCandidateInto(state.hover.candidate, points[targetCount + 1], true)
        if not pendingPoint then
            cache.valid = true
            cache.hasPending = false
            state.pending = nil
            return
        end

        points[targetCount + 1] = pendingPoint

        local mirrorState = client.Mirror.resolve(state, points, "_magicAlignPendingMirrorCache")
        local reference = mirrorState and mirrorState.reference or nil
        local pending = mirrorState and mirrorState.valid and reference
            and client.Mirror.applyPreview(
                state,
                reference,
                state._magicAlignPendingPreview or {},
                mirrorState,
                sourceAnchorId,
                sourcePriority,
                sourceAnchorOptions
            )
            or nil
        if pending then
            state._magicAlignPendingPreview = pending
            state.pending = pending
            cache.valid = true
            cache.hasPending = true
            cache.mirrorRevision = mirrorState.revision
        else
            state.pending = nil
            cache.valid = true
            cache.hasPending = false
            cache.mirrorRevision = mirrorState and mirrorState.revision or nil
        end

        return
    end

    local sourceAnchorOptions, sourceAnchorRevision = cachedAnchorOptions(tool, state, "from")
    local targetAnchorOptions, targetAnchorRevision = cachedAnchorOptions(tool, state, "to")
    local offsetTable, offsetRevision = cachedOffsets(tool, state)
    local sourceAnchorId, sourcePriority = selectedAnchorState(tool, state, "from")
    local targetAnchorId, targetPriority = selectedAnchorState(tool, state, "to")
    local cache = state._magicAlignPendingPreviewCache or {}
    state._magicAlignPendingPreviewCache = cache
    local inputsChanged = pendingPreviewInputsChanged(
        state,
        cache,
        candidate,
        offsetRevision,
        sourceAnchorRevision,
        targetAnchorRevision,
        sourceAnchorId,
        sourcePriority,
        targetAnchorId,
        targetPriority
    )
    if cache.previewMode ~= "normal" then
        cache.previewMode = "normal"
        inputsChanged = true
    end

    if cache.valid and not inputsChanged then
        if cache.hasPending == false then
            state.pending = nil
            return
        end

        local pending = state._magicAlignPendingPreview
        if pending then
            state.pending = pending
            return
        end
    end

    local points, targetCount = copyPendingPointList(state._magicAlignPendingPoints, activePoints)
    state._magicAlignPendingPoints = points

    local pendingPoint = pointFromCandidateInto(state.hover.candidate, points[targetCount + 1], true)
    if not pendingPoint then
        cache.valid = true
        cache.hasPending = false
        state.pending = nil
        return
    end

    points[targetCount + 1] = pendingPoint

    local solve = M.Solve(
        state.prop1,
        state.source,
        state.prop2,
        points,
        sourceAnchorId,
        sourcePriority,
        targetAnchorId,
        targetPriority,
        sourceAnchorOptions,
        targetAnchorOptions,
        {
            pointWorldCache = pointWorldCache(state),
            anchorCache = anchorResultCache(state),
            sourceAnchorRevision = sourceAnchorRevision,
            targetAnchorRevision = targetAnchorRevision
        }
    )

    if solve then
        local rawPos, rawAng, spaceBasis, referenceBasis = M.ComposePose(solve, offsetTable, state.prop2)
        local pending = state._magicAlignPendingPreview or {}
        state._magicAlignPendingPreview = pending
        pending.solve = solve
        pending.pos = rawPos
        pending.ang = rawAng
        pending.spaceBasis = spaceBasis
        pending.referenceBasis = referenceBasis
        pending.transformMode = nil
        pending.mirrorReference = nil
        pending.absoluteLinked = nil
        pending.entityMirrorAxis = M.ENTITY_MIRROR_NONE
        pending.linked = nil
        state.pending = pending
        cache.valid = true
        cache.hasPending = true
    else
        state.pending = nil
        cache.valid = true
        cache.hasPending = false
    end
end

core.copyMirrorReference = copyMirrorReference
core.solvePreview = solvePreview
core.ensureGhost = ensureGhost
core.hoverState = hoverState
core.invalidatePendingPreview = invalidatePendingPreview
core.pendingPreview = pendingPreview

return core
