MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local worldPoints = client.WorldPoints or {}
client.WorldPoints = worldPoints
local geometry = client.geometry or {}
client.geometry = geometry

local VectorP = M.VectorP
local AngleP = M.AngleP
local isvector = M.IsVectorLike
local isWorldTarget = M.IsWorldTarget
local LocalToWorldPosPrecise = M.LocalToWorldPosPrecise
local snapGizmoPosition = client.snapGizmoPosition
local gizmoShared = client.gizmoShared or {}

local WORLD_POINT_DRAG_DEADZONE = 1
local TARGET_POINT_KIND = "target"
local MIRROR_POINT_KIND = "mirror"
local POINT_GIZMO_SPACES = {
    target = "world_point",
    mirror = "mirror_point"
}
local POINT_GIZMO_SCRATCH_KEYS = {
    target = "_magicAlignWorldPointGizmoScratch",
    mirror = "_magicAlignMirrorPointGizmoScratch"
}

local copyVec = M.CopyVectorPrecise
local copyAng = M.CopyAnglePrecise
local ZERO_VEC = VectorP(0, 0, 0)
local ZERO_ANG = AngleP(0, 0, 0)

local function setVec(out, value)
    if not isvector(value) then return end

    if not isvector(out) then
        return VectorP(value.x, value.y, value.z)
    end

    out.x, out.y, out.z = value.x, value.y, value.z
    return out
end

local function normalizedVec(value)
    return M.NormalizeVectorPrecise(value, M.COMPUTE_VECTOR_EPSILON_SQR)
end

local function targetPoints(state)
    return istable(state) and istable(state.target) and state.target or {}
end

local function mirrorActive(state)
    return M.IsMirrorMode(state)
end

local function mirrorState(state)
    if not istable(state) then return {} end
    if client.Mirror and isfunction(client.Mirror.state) then
        return client.Mirror.state(state)
    end

    state.mirror = state.mirror or {}
    state.mirror.points = state.mirror.points or {}
    return state.mirror
end

local function mirrorPoints(state)
    local mirror = mirrorState(state)
    return istable(mirror.points) and mirror.points or {}
end

local function activePointKind(state)
    if not istable(state) then return end
    if mirrorActive(state) then return MIRROR_POINT_KIND end
    if M.HasTargetEntity(state.prop2) then return TARGET_POINT_KIND end
end

local function isPointKindActive(state, kind)
    if kind == MIRROR_POINT_KIND then
        return mirrorActive(state)
    elseif kind == TARGET_POINT_KIND then
        return istable(state)
            and not mirrorActive(state)
            and M.HasTargetEntity(state.prop2)
    end
end

local function sideForKind(kind)
    return kind == MIRROR_POINT_KIND and "mirror" or "target"
end

local function pointsForKind(state, kind)
    if kind == MIRROR_POINT_KIND then
        return mirrorPoints(state)
    elseif kind == TARGET_POINT_KIND then
        return targetPoints(state)
    end

    return {}
end

local function selectionStore(state, kind)
    if not istable(state) then return end

    if kind == MIRROR_POINT_KIND then
        return mirrorState(state), "selectedPointIndex"
    elseif kind == TARGET_POINT_KIND then
        return state, "selectedWorldPointIndex"
    end
end

local function selectedFallbackEnt(state, kind)
    if kind ~= MIRROR_POINT_KIND then return end

    local mirror = mirrorState(state)
    local ent = mirror.selectedPointFallbackEnt
    if isWorldTarget(ent) or IsValid(ent) then
        return ent
    end
end

local function pointWorldCache(state)
    if not istable(state) then return end

    local cache = state._magicAlignPointWorldCache
    if not istable(cache) then
        cache = {}
        state._magicAlignPointWorldCache = cache
    end

    return cache
end

local function pointWorldPosition(state, kind, point, fallbackEnt)
    if not isvector(point) then return end

    local cache = pointWorldCache(state)
    if kind == MIRROR_POINT_KIND then
        local ent = fallbackEnt or selectedFallbackEnt(state, kind)
        return cache
            and M.ResolvePointWorldPositionCached(cache, point, ent)
            or M.ResolvePointWorldPosition(point, ent)
    elseif kind == TARGET_POINT_KIND then
        local ent = state and state.prop2
        return cache
            and M.ResolvePointWorldPositionCached(cache, point, ent)
            or M.ResolvePointWorldPosition(point, ent)
    end
end

local function selectedIndex(state, kind)
    kind = kind or activePointKind(state)
    if not kind or not isPointKindActive(state, kind) then return end

    local store, key = selectionStore(state, kind)
    local index = tonumber(store and store[key])
    if index == nil then return end

    index = math.floor(index)
    if index < 1 then return end

    local points = pointsForKind(state, kind)
    if index > #points or not isvector(points[index]) then return end
    if not isvector(pointWorldPosition(state, kind, points[index])) then return end

    return index
end

local function setSelectedIndex(state, index, kind, fallbackEnt)
    if not istable(state) then return end

    kind = kind or activePointKind(state) or TARGET_POINT_KIND
    local store, key = selectionStore(state, kind)
    if not store or not key then return end

    if index == nil then
        store[key] = nil
        if kind == MIRROR_POINT_KIND then
            store.selectedPointFallbackEnt = nil
        end
        return
    end

    index = math.floor(tonumber(index) or 0)
    if index < 1 or not isPointKindActive(state, kind) then
        store[key] = nil
        return
    end

    local points = pointsForKind(state, kind)
    if index > #points or not isvector(points[index]) then
        store[key] = nil
        return
    end

    if not isvector(pointWorldPosition(state, kind, points[index], fallbackEnt)) then
        store[key] = nil
        return
    end

    store[key] = index
    if kind == MIRROR_POINT_KIND then
        store.selectedPointFallbackEnt = (isWorldTarget(fallbackEnt) or IsValid(fallbackEnt)) and fallbackEnt or nil
    end
end

local function pressPointKind(press)
    if not istable(press) then return end
    if press.pointGizmoKind == MIRROR_POINT_KIND or press.pointGizmoKind == TARGET_POINT_KIND then
        return press.pointGizmoKind
    end
    if press.worldPoint == true then
        return TARGET_POINT_KIND
    end
    if press.side == "mirror"
        and (press.kind == "world_point_press" or press.kind == "drag_point" or press.kind == "gizmo") then
        return MIRROR_POINT_KIND
    end
end

local function pressPointIndex(press)
    if not istable(press) then return 0 end
    return math.floor(tonumber(press.pointGizmoIndex or press.worldPointIndex or press.index) or 0)
end

local function clearPointPress(state, kind)
    if not istable(state) or not istable(state.press) then return end

    local pressKind = pressPointKind(state.press)
    if (state.press.kind == "world_point_press" and (not kind or pressKind == kind))
        or (pressKind and (not kind or pressKind == kind)) then
        state.press = nil
    end
end

local function adjustPressIndex(press, removedIndex, kind)
    if not istable(press) then return end
    local pressKind = pressPointKind(press)
    if kind and pressKind ~= kind then return end

    local key
    if press.kind == "world_point_press" then
        key = "index"
    elseif press.pointGizmoIndex ~= nil then
        key = "pointGizmoIndex"
    elseif press.worldPoint == true then
        key = "worldPointIndex"
    end

    if not key then return end

    local index = math.floor(tonumber(press[key]) or 0)
    if index < 1 then return end

    if removedIndex == index then
        return false
    elseif removedIndex < index then
        index = index - 1
        press[key] = index
        if press.index ~= nil then
            press.index = index
        end
        if press.worldPointIndex ~= nil then
            press.worldPointIndex = index
        end
    end

    return true
end

local function selectedPoint(state, kind)
    kind = kind or activePointKind(state)
    local index = selectedIndex(state, kind)
    local point = index and pointsForKind(state, kind)[index] or nil
    return index, point, pointWorldPosition(state, kind, point)
end

local function referenceForPoint(state, kind, point, fallbackEnt)
    if kind == MIRROR_POINT_KIND then
        return M.ResolvePointReference(point, fallbackEnt or selectedFallbackEnt(state, kind))
    elseif kind == TARGET_POINT_KIND then
        return M.ResolvePointReference(point, fallbackEnt or (state and state.prop2))
    end
end

local function pointFromWorldPosition(state, kind, currentPoint, worldPos, worldNormal, referenceEnt)
    if not isvector(currentPoint) or not isvector(worldPos) then return end

    local ref = referenceEnt or referenceForPoint(state, kind, currentPoint)
    local point
    local localNormal

    if isWorldTarget(ref) then
        point = copyVec(worldPos)
        point.world = true
        localNormal = normalizedVec(worldNormal)
    elseif IsValid(ref) then
        point = geometry.localPointFromWorldPos(ref, worldPos)
        localNormal = geometry.localNormalFromWorld(ref, worldPos, worldNormal)
    end

    if not isvector(point) then return end

    M.SetPointReference(point, ref)

    if localNormal then
        point.normal = copyVec(localNormal)
    elseif isvector(currentPoint.normal) then
        point.normal = copyVec(currentPoint.normal)
    end

    return point
end

local function updatePoint(state, kind, index, worldPos, worldNormal, referenceEnt, selectPoint)
    local points = pointsForKind(state, kind)
    local currentPoint = points[index]
    if not isvector(currentPoint) or not isvector(worldPos) then return false end

    local wasSelected = selectedIndex(state, kind) == index
    local point = pointFromWorldPosition(state, kind, currentPoint, worldPos, worldNormal, referenceEnt)
    if not point then return false end

    points[index] = point
    if selectPoint ~= false or wasSelected then
        setSelectedIndex(state, index, kind, referenceEnt)
    end
    M.RefreshState(state)
    return true
end

local function updatePointFromCandidate(state, kind, index, candidate, selectPoint)
    if not istable(candidate) or not isvector(candidate.worldPos) then return false end

    if kind == MIRROR_POINT_KIND or kind == TARGET_POINT_KIND then
        local points = pointsForKind(state, kind)
        local wasSelected = selectedIndex(state, kind) == index
        local point = geometry.pointFromCandidate(candidate, true)
        if not point then return false end

        points[index] = point
        if selectPoint ~= false or wasSelected then
            setSelectedIndex(state, index, kind, candidate.ent)
        end
        M.RefreshState(state)
        return true
    end

    local worldNormal = isvector(candidate.normal) and candidate.normal or candidate.localNormal
    return updatePoint(state, kind, index, candidate.worldPos, worldNormal, candidate.ent, selectPoint)
end

local function gizmoSize(state)
    if isfunction(gizmoShared.sizeForProp) then
        return gizmoShared.sizeForProp(state and state.prop1)
    end

    return math.Clamp(IsValid(state and state.prop1) and state.prop1:BoundingRadius() * 0.42 or 32, 18, 72)
end

local function worldBasis()
    return AngleP(0, 0, 0)
end

local function pointGizmoBasis(state, kind, point, fallbackEnt)
    if kind == MIRROR_POINT_KIND then
        local ref = referenceForPoint(state, kind, point, fallbackEnt)
        if IsValid(ref) then
            return copyAng(ref:GetAngles()), ref
        end

        return worldBasis(), ref
    end

    local ref = referenceForPoint(state, kind, point, fallbackEnt)
    if IsValid(ref) then
        return copyAng(ref:GetAngles()), ref
    end

    return worldBasis(), ref or M.WORLD_TARGET
end

local function modifierState()
    return input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
end

local function buildGizmo(state, kind)
    kind = kind or activePointKind(state)
    local index, point, worldPos = selectedPoint(state, kind)
    if not index or not isvector(worldPos) then return end

    local press = state.press
    if press and (press.kind == "world_point_press" or (press.kind == "drag_point" and pressPointKind(press) == kind)) then
        return
    end

    local space = POINT_GIZMO_SPACES[kind]
    if not space then return end

    local origin = copyVec(worldPos)
    local basis, referenceEnt = pointGizmoBasis(state, kind, point)
    local referenceBasis = copyAng(basis)

    if press
        and press.kind == "gizmo"
        and pressPointKind(press) == kind
        and pressPointIndex(press) == index
        and press.space == space then
        local currentOrigin = isvector(press.currentGizmoPos)
            and LocalToWorldPosPrecise(press.currentGizmoPos, press.origin, press.basis)
            or press.origin
        origin = copyVec(currentOrigin)
        basis = copyAng(press.basis)
        referenceBasis = copyAng(press.referenceBasis or basis)
    end

    local size = gizmoSize(state)
    local handles, metrics, basisForward, basisRight, basisUp, scratch
    if isfunction(gizmoShared.linearHandles) then
        local scratchKey = POINT_GIZMO_SCRATCH_KEYS[kind] or POINT_GIZMO_SCRATCH_KEYS.target
        scratch = state[scratchKey] or {}
        state[scratchKey] = scratch
        handles, basisForward, basisRight, basisUp, metrics = gizmoShared.linearHandles(origin, basis, size, scratch)
    end

    local best
    if handles and metrics and isfunction(gizmoShared.pickHoveredHandle) then
        best = gizmoShared.pickHoveredHandle(handles, metrics.pickRadius, metrics.ringRadius, metrics.ringPadding, origin, basis)
    end

    local out = scratch and scratch.result or {}
    if scratch then
        scratch.result = out
    end

    out.origin = origin
    out.basis = basis
    out.referenceBasis = referenceBasis
    out.size = size
    out.planeOffset = metrics and metrics.planeOffset or size * 0.2
    out.ringRadius = metrics and metrics.ringRadius or size * 0.82
    out.ringPadding = metrics and metrics.ringPadding or 0.5
    out.hover = press
        and press.kind == "gizmo"
        and pressPointKind(press) == kind
        and pressPointIndex(press) == index
        and press.space == space
        and press.gizmo
        or best
    out.space = space
    out.disableRotation = true
    out.pointGizmo = true
    out.pointGizmoKind = kind
    out.pointGizmoIndex = index
    out.pointGizmoReference = referenceEnt
    out.worldPoint = kind == TARGET_POINT_KIND or nil
    out.worldPointIndex = kind == TARGET_POINT_KIND and index or nil
    out.handles = handles
    out.basisForward = basisForward
    out.basisRight = basisRight
    out.basisUp = basisUp

    return out
end

local function beginPointPress(state, hover, kind)
    if not istable(state) or not istable(hover) then return false end

    kind = kind or activePointKind(state)
    if not kind then return false end

    local hoverPoint = hover.point
    if not istable(hoverPoint) then return false end

    local index = math.floor(tonumber(hoverPoint.index) or 0)
    local points = pointsForKind(state, kind)
    if index < 1 or index > #points or not isvector(points[index]) then return false end

    local startWorldPos = hover.candidate and hover.candidate.worldPos
        or hover.trace and hover.trace.HitPos
        or hoverPoint.worldPos
    if not isvector(startWorldPos) then
        startWorldPos = pointWorldPosition(state, kind, points[index], hover.ent)
    end
    if not isvector(startWorldPos) then return false end

    state.press = {
        kind = "world_point_press",
        side = sideForKind(kind),
        pointGizmo = true,
        pointGizmoKind = kind,
        pointGizmoIndex = index,
        pointGizmoReference = referenceForPoint(state, kind, points[index], hover.ent),
        worldPoint = kind == TARGET_POINT_KIND or nil,
        worldPointIndex = kind == TARGET_POINT_KIND and index or nil,
        index = index,
        startWorldPos = copyVec(startWorldPos)
    }

    return true
end

local function beginPointGizmoDrag(state, handle)
    if not istable(state) or not istable(handle) or not istable(handle.hover) then return false end

    local kind = handle.pointGizmoKind or (handle.worldPoint and TARGET_POINT_KIND) or activePointKind(state)
    if not kind or not POINT_GIZMO_SPACES[kind] then return false end

    local index = math.floor(tonumber(handle.pointGizmoIndex or handle.worldPointIndex) or 0)
    local points = pointsForKind(state, kind)
    if index < 1 or index > #points or not isvector(points[index]) then return false end
    local referenceEnt = handle.pointGizmoReference or referenceForPoint(state, kind, points[index])

    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    local eye = ply:GetShootPos()
    local dir = ply:GetAimVector()
    local origin = copyVec(handle.origin)
    local basis = copyAng(handle.basis or worldBasis())
    local item = isfunction(gizmoShared.copyHandle) and gizmoShared.copyHandle(handle.hover) or handle.hover
    if not istable(item) then return false end
    if item.kind ~= "move" and item.kind ~= "plane" then
        return false
    end

    local normal = isfunction(gizmoShared.linearDragNormal)
        and gizmoShared.linearDragNormal(origin, basis, item, eye)
        or nil
    normal = normalizedVec(normal)
    if not normal then return false end

    local lookDir = M.SubtractVectorsPrecise(origin, eye)
    if M.VectorLengthSqrPrecise(lookDir) > M.PICKING_VECTOR_EPSILON_SQR then
        client.setPlayerViewAngles(ply, lookDir:Angle())
        dir = normalizedVec(lookDir) or dir
    end

    local lineScratch = state._magicAlignPointGizmoLinePlaneScratch or {}
    state._magicAlignPointGizmoLinePlaneScratch = lineScratch
    local worldPos, localPos = M.LinePlaneIntersectionInto(lineScratch.world, lineScratch.localPos, dir, eye, normal, origin, basis)
    lineScratch.world, lineScratch.localPos = worldPos, localPos
    if not isvector(worldPos) or not isvector(localPos) then return false end

    state.press = {
        kind = "gizmo",
        side = sideForKind(kind),
        pointGizmo = true,
        pointGizmoKind = kind,
        pointGizmoIndex = index,
        pointGizmoReference = referenceEnt,
        worldPoint = kind == TARGET_POINT_KIND or nil,
        worldPointIndex = kind == TARGET_POINT_KIND and index or nil,
        gizmo = item,
        origin = copyVec(origin),
        basis = copyAng(basis),
        referenceBasis = copyAng(handle.referenceBasis or basis),
        normal = copyVec(normal),
        startWorld = copyVec(worldPos),
        startLocal = copyVec(localPos),
        dragStartLocal = VectorP(0, 0, 0),
        currentGizmoPos = VectorP(0, 0, 0),
        referenceDelta = VectorP(0, 0, 0),
        rotationDelta = 0,
        space = POINT_GIZMO_SPACES[kind]
    }

    setSelectedIndex(state, index, kind, referenceEnt)
    return true
end

local function traceSnapNormal(press)
    local trace = press and press.lastTraceSnapHit and press.lastTraceSnapHit.trace or nil
    if not trace or not isvector(trace.HitNormal) then return end

    return trace.HitNormal
end

local function updatePointGizmoDrag(state)
    local press = state.press
    local kind = pressPointKind(press)
    if not istable(press) or press.kind ~= "gizmo" or not kind then return false end

    local ply = LocalPlayer()
    if not IsValid(ply) then return true end

    local eye = ply:GetShootPos()
    local dir = ply:GetAimVector()
    local lineScratch = press.linePlaneScratch or {}
    press.linePlaneScratch = lineScratch
    local _, localPos
    lineScratch.world, localPos = M.LinePlaneIntersectionInto(lineScratch.world, lineScratch.localPos, dir, eye, press.normal, press.origin, press.basis)
    lineScratch.localPos = localPos
    if not isvector(localPos) then return true end

    local dragStartLocal = press.dragStartLocal or press.startLocal or ZERO_VEC
    local currentGizmoPos = isfunction(gizmoShared.translationLocalPos)
        and gizmoShared.translationLocalPos(press.gizmo, dragStartLocal, localPos, press.currentGizmoPos)
        or nil
    if not isvector(currentGizmoPos) then
        return true
    end

    if isfunction(snapGizmoPosition) then
        currentGizmoPos = snapGizmoPosition(state, press, currentGizmoPos) or currentGizmoPos
    end

    press.currentGizmoPos = setVec(press.currentGizmoPos, currentGizmoPos)
    press.referenceDelta = setVec(press.referenceDelta, currentGizmoPos - dragStartLocal)
    press.rotationDelta = 0

    local worldPos = LocalToWorldPosPrecise(currentGizmoPos, press.origin, press.basis)
    if isvector(worldPos) then
        updatePoint(state, kind, pressPointIndex(press), worldPos, traceSnapNormal(press), press.pointGizmoReference)
    end

    return true
end

local function altStateStore(state, kind)
    if kind == MIRROR_POINT_KIND then
        return mirrorState(state), "pointAltDown"
    end

    return state, "worldPointAltDown"
end

local function hoverReferenceForToggle(state, kind, hover)
    if not istable(hover) or not istable(hover.point) then return end

    local points = pointsForKind(state, kind)
    local index = math.floor(tonumber(hover.point.index) or 0)
    local point = points[index]
    if index < 1 or not isvector(point) or hover.points ~= points then return end
    if hover.side ~= sideForKind(kind) then return end
    if not isvector(hover.point.worldPos) then return end

    local ref = referenceForPoint(state, kind, point, hover.ent)
    if kind == TARGET_POINT_KIND
        and M.IsPointReferenceValid
        and not M.IsPointReferenceValid(point, state and state.prop2, {
            allowWorld = true,
            requireProp = true
        }) then
        return
    end

    return index, ref
end

local function hoverStableForToggle(state, kind, hover, store)
    if not store then return false end

    local index, ref = hoverReferenceForToggle(state, kind, hover)
    local stable = index ~= nil
        and store.pointAltHoverIndex == index
        and store.pointAltHoverRef == ref

    store.pointAltHoverIndex = index
    store.pointAltHoverRef = ref

    return stable, index, ref
end

function worldPoints.clearSelection(state, kind)
    setSelectedIndex(state, nil, kind or activePointKind(state) or TARGET_POINT_KIND)
end

function worldPoints.getSelectedIndex(state, kind)
    return selectedIndex(state, kind)
end

function worldPoints.isSelected(state, index, kind)
    return selectedIndex(state, kind) == math.floor(tonumber(index) or 0)
end

function worldPoints.toggleSelection(state, index, kind, fallbackEnt)
    kind = kind or activePointKind(state) or TARGET_POINT_KIND
    index = math.floor(tonumber(index) or 0)
    if index < 1 then
        setSelectedIndex(state, nil, kind)
        return
    end

    if selectedIndex(state, kind) == index then
        setSelectedIndex(state, nil, kind)
    else
        setSelectedIndex(state, index, kind, fallbackEnt)
    end
end

function worldPoints.hasToggleHint(state, kind)
    kind = kind or activePointKind(state)
    return istable(state) and isPointKindActive(state, kind) and #pointsForKind(state, kind) > 0
end

function worldPoints.handleModifierToggle(state, blocked, kind)
    if not istable(state) then return false end
    kind = kind or activePointKind(state)
    if not kind then return false end

    local altDown = modifierState()
    local altStore, altKey = altStateStore(state, kind)
    local altPressed = altDown and not (altStore and altStore[altKey] == true)
    local hover = state.hover
    local hoverStable, hoverIndex, hoverRef = hoverStableForToggle(state, kind, hover, altStore)

    if altStore and altKey then
        altStore[altKey] = altDown
    end

    if blocked or not worldPoints.hasToggleHint(state, kind) or istable(state.press) then
        return false
    end

    if not istable(hover)
        or hover.side ~= sideForKind(kind)
        or not hover.point
        or hover.points ~= pointsForKind(state, kind) then
        return false
    end

    if not altPressed or not hoverStable or not hoverIndex then
        return false
    end

    worldPoints.toggleSelection(state, hoverIndex, kind, hoverRef or hover.ent)
    return true
end

local function sanitizePointKind(state, kind)
    local store, key = selectionStore(state, kind)
    if not store or not key then return end

    if not isPointKindActive(state, kind) then
        store[key] = nil
        if kind == MIRROR_POINT_KIND then
            store.selectedPointFallbackEnt = nil
        end
        clearPointPress(state, kind)
        return
    end

    local index = selectedIndex(state, kind)
    store[key] = index

    local press = state.press
    if not istable(press) or pressPointKind(press) ~= kind then return end

    local points = pointsForKind(state, kind)
    local pointIndex = pressPointIndex(press)
    if pointIndex < 1 or pointIndex > #points or not isvector(points[pointIndex]) then
        state.press = nil
    end
end

function worldPoints.sanitizeState(state)
    if not istable(state) then return end

    sanitizePointKind(state, TARGET_POINT_KIND)
    sanitizePointKind(state, MIRROR_POINT_KIND)
end

function worldPoints.onPointRemoved(state, kind, removedIndex)
    if not istable(state) then return end
    kind = kind or TARGET_POINT_KIND

    removedIndex = math.floor(tonumber(removedIndex) or 0)
    if removedIndex < 1 then return end

    local store, key = selectionStore(state, kind)
    local index = math.floor(tonumber(store and store[key]) or 0)
    if index >= 1 then
        if removedIndex == index then
            setSelectedIndex(state, nil, kind)
        elseif removedIndex < index then
            setSelectedIndex(state, index - 1, kind)
        end
    end

    if adjustPressIndex(state.press, removedIndex, kind) == false then
        state.press = nil
    end
end

function worldPoints.onTargetPointRemoved(state, removedIndex)
    return worldPoints.onPointRemoved(state, TARGET_POINT_KIND, removedIndex)
end

function worldPoints.getGizmo(_, state)
    if not istable(state) then return end

    local kind = activePointKind(state)
    if not kind then return end

    return buildGizmo(state, kind)
end

function worldPoints.shouldSuppressDefaultGizmo(state)
    if not istable(state) then return false end

    local press = state.press
    if not istable(press) then return false end

    return press.kind == "world_point_press"
        or (press.kind == "drag_point" and pressPointKind(press) ~= nil)
end

function worldPoints.beginMousePress(_, state)
    if not istable(state) then return false end
    local kind = activePointKind(state)
    if not kind then return false end

    local hover = state.hover
    if not istable(hover) then return false end

    if hover.gizmo and hover.gizmo.pointGizmo and hover.gizmo.hover then
        return beginPointGizmoDrag(state, hover.gizmo)
    end

    if hover.side == sideForKind(kind) and hover.point and hover.points == pointsForKind(state, kind) then
        return beginPointPress(state, hover, kind)
    end

    return false
end

function worldPoints.updateActivePress(_, state)
    if not istable(state) or not istable(state.press) then return false end

    local press = state.press
    if press.kind == "world_point_press" then
        state.corner = nil
        local kind = pressPointKind(press)

        local hover = state.hover
        local candidate = hover and hover.candidate or nil
        if hover
            and kind
            and hover.side == sideForKind(kind)
            and istable(candidate)
            and isvector(candidate.worldPos)
            and isvector(press.startWorldPos)
            and press.startWorldPos:Distance(candidate.worldPos) >= WORLD_POINT_DRAG_DEADZONE then
            state.press = {
                kind = "drag_point",
                side = sideForKind(kind),
                index = press.index,
                pointGizmo = true,
                pointGizmoKind = kind,
                pointGizmoIndex = press.index,
                pointGizmoReference = press.pointGizmoReference,
                worldPoint = kind == TARGET_POINT_KIND or nil,
                worldPointIndex = kind == TARGET_POINT_KIND and press.index or nil
            }
            updatePointFromCandidate(state, kind, press.index, candidate, false)
        end

        return true
    end

    if press.kind == "gizmo" and pressPointKind(press) then
        state.corner = nil
        updatePointGizmoDrag(state)
        return true
    end

    return false
end

function worldPoints.handleMouseRelease(_, state, press)
    if not istable(state) or not istable(press) or press.kind ~= "world_point_press" then
        return false
    end

    return true
end
