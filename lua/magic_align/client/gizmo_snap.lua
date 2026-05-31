MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local geometry = client.geometry or {}
client.geometry = geometry

local VectorP = M.VectorP
local isvector = M.IsVectorLike
local toVector = M.ToVector
local copyVec = M.CopyVectorPrecise
local LocalToWorldPosPrecise = M.LocalToWorldPosPrecise
local WorldToLocalPosPrecise = M.WorldToLocalPosPrecise

local function comp(v, key)
    return key == "x" and v.x or key == "y" and v.y or v.z
end

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

function client.axisVectorForKey(basis, key)
    if key == "x" then
        return M.AngleForwardPrecise(basis)
    elseif key == "y" then
        return M.AngleRightPrecise(basis)
    end

    return M.AngleUpPrecise(basis)
end

local function markSnapAxis(axes, key)
    if axes and key then
        axes[key] = true
    end
end

local function mergeSnapAxes(target, source)
    if not target or type(source) ~= "table" then return target end

    if source.x then
        target.x = true
    end
    if source.y then
        target.y = true
    end
    if source.z then
        target.z = true
    end

    return target
end

local function applyHandleSnap(item, currentGizmoPos, snapLocalPos, snapAxes)
    if not item or not isvector(currentGizmoPos) or not isvector(snapLocalPos) then return currentGizmoPos end

    local out = VectorP(currentGizmoPos.x, currentGizmoPos.y, currentGizmoPos.z)
    if item.kind == "move" then
        if item.key == "x" then
            out.x = snapLocalPos.x
            markSnapAxis(snapAxes, "x")
        elseif item.key == "y" then
            out.y = snapLocalPos.y
            markSnapAxis(snapAxes, "y")
        else
            out.z = snapLocalPos.z
            markSnapAxis(snapAxes, "z")
        end

        return out
    end

    if item.kind ~= "plane" then return out end

    local first = item.key:sub(1, 1)
    local second = item.key:sub(2, 2)

    if first == "x" or second == "x" then
        out.x = snapLocalPos.x
        markSnapAxis(snapAxes, "x")
    end
    if first == "y" or second == "y" then
        out.y = snapLocalPos.y
        markSnapAxis(snapAxes, "y")
    end
    if first == "z" or second == "z" then
        out.z = snapLocalPos.z
        markSnapAxis(snapAxes, "z")
    end

    return out
end

local function handleUsesAxis(item, key)
    if not item or not key then return false end

    if item.kind == "move" then
        return item.key == key
    elseif item.kind == "plane" then
        return item.key:find(key, 1, true) ~= nil
    end

    return false
end

local function snapTranslationValue(value, step, origin)
    if step <= 0 then
        return tonumber(value) or 0
    end

    local current = tonumber(value) or 0
    local base = tonumber(origin) or 0
    return base + math.Round((current - base) / step) * step
end

local function snapGizmoTranslation(item, startLocal, currentGizmoPos, step, blockedAxes)
    if not item or not isvector(currentGizmoPos) or step <= 0 then return currentGizmoPos end

    local out = VectorP(currentGizmoPos.x, currentGizmoPos.y, currentGizmoPos.z)
    local base = isvector(startLocal) and startLocal or VectorP(0, 0, 0)

    if handleUsesAxis(item, "x") and not (blockedAxes and blockedAxes.x) then
        out.x = snapTranslationValue(out.x, step, base.x)
    end
    if handleUsesAxis(item, "y") and not (blockedAxes and blockedAxes.y) then
        out.y = snapTranslationValue(out.y, step, base.y)
    end
    if handleUsesAxis(item, "z") and not (blockedAxes and blockedAxes.z) then
        out.z = snapTranslationValue(out.z, step, base.z)
    end

    return out
end

local function applyAxisSnap(out, key, snapLocalPos, snapAxes)
    if not isvector(out) or not isvector(snapLocalPos) then return out end

    if key == "x" then
        out.x = snapLocalPos.x
        markSnapAxis(snapAxes, "x")
    elseif key == "y" then
        out.y = snapLocalPos.y
        markSnapAxis(snapAxes, "y")
    else
        out.z = snapLocalPos.z
        markSnapAxis(snapAxes, "z")
    end

    return out
end

local function worldToGizmoLocal(worldPos, press)
    if not isvector(worldPos) or not press then return end

    local localPos = WorldToLocalPosPrecise(worldPos, press.origin, press.basis)
    return isvector(localPos) and localPos or nil
end

local function gizmoWorldOrigin(press, currentGizmoPos)
    if not press or not isvector(currentGizmoPos) then return end

    local dragStartLocal = press.dragStartLocal or press.startLocal
    local delta = currentGizmoPos - dragStartLocal
    local worldPos = LocalToWorldPosPrecise(delta, press.origin, press.basis)

    return isvector(worldPos) and worldPos or nil
end

local function gizmoTraceDirectionForAxis(press, currentGizmoPos, key)
    if not press or not press.gizmo or not isvector(currentGizmoPos) then return end
    if not handleUsesAxis(press.gizmo, key) then return end

    local dragStartLocal = press.dragStartLocal or press.startLocal
    local delta = comp(currentGizmoPos, key) - comp(dragStartLocal, key)
    if math.abs(delta) <= M.COMPUTE_EPSILON then return end

    local axis = client.axisVectorForKey(press.basis, key)
    if not isvector(axis) or M.VectorLengthSqrPrecise(axis) < M.COMPUTE_VECTOR_EPSILON_SQR then return end

    axis = normalizedVec(axis)
    if not axis then return end

    return delta >= 0 and axis or -axis
end

local function gizmoTraceFilter(state, filter)
    filter = filter or {}
    for i = 1, #filter do
        filter[i] = nil
    end

    local ply = LocalPlayer()
    local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil

    if IsValid(ply) then
        filter[#filter + 1] = ply
    end
    if IsValid(weapon) then
        filter[#filter + 1] = weapon
    end
    if IsValid(state.prop1) then
        filter[#filter + 1] = state.prop1
    end
    if IsValid(state.ghost) then
        filter[#filter + 1] = state.ghost
    end

    for i = 1, #(state.linked or {}) do
        local ent = state.linked[i]
        if IsValid(ent) then
            filter[#filter + 1] = ent
        end
    end

    for _, ghost in pairs(state.linkedGhosts or {}) do
        if IsValid(ghost) then
            filter[#filter + 1] = ghost
        end
    end

    return filter
end

local function traceSnapStartWorldPos(state, press, currentGizmoPos, dir)
    return gizmoWorldOrigin(press, currentGizmoPos)
end

local function traceSnapWorldPos(startPos, dir, traceLength, filter)
    if not isvector(startPos) or not isvector(dir) or M.VectorLengthSqrPrecise(dir) < M.PICKING_VECTOR_EPSILON_SQR or traceLength <= 0 then return end

    local traceDir = normalizedVec(dir)
    if not traceDir then return end

    local tr = util.TraceLine({
        start = toVector(startPos),
        endpos = toVector(startPos + traceDir * traceLength),
        filter = filter
    })
    if not tr then return end

    local fractionLeftSolid = tonumber(tr.FractionLeftSolid) or 0
    if tr.StartSolid or tr.AllSolid then
        if not tr.AllSolid and fractionLeftSolid > 0 then
            return startPos + traceDir * (traceLength * fractionLeftSolid), tr
        end

        return nil, tr
    end

    if tr.Hit and isvector(tr.HitPos) then
        return copyVec(tr.HitPos), tr
    end
end

local function traceSnapAxisResult(origin, dir, traceLength, filter, out)
    if not isvector(origin) or not isvector(dir) or M.VectorLengthSqrPrecise(dir) < M.PICKING_VECTOR_EPSILON_SQR or traceLength <= 0 then return end

    local traceDir = normalizedVec(dir)
    if not traceDir then return end

    local limit = traceLength * traceLength + M.UI_COMPARE_EPSILON

    local positiveWorldPos, positiveTrace = traceSnapWorldPos(origin, traceDir, traceLength, filter)
    local positiveHit = isvector(positiveWorldPos) and positiveWorldPos:DistToSqr(origin) <= limit

    local negativeDir = -traceDir
    local negativeWorldPos, negativeTrace = traceSnapWorldPos(origin, negativeDir, traceLength, filter)
    local negativeHit = isvector(negativeWorldPos) and negativeWorldPos:DistToSqr(origin) <= limit

    local worldPos
    local side
    if positiveHit then
        worldPos = positiveWorldPos
        side = "positive"
    elseif negativeHit then
        worldPos = negativeWorldPos
        side = "negative"
    end

    out = out or {}
    out.direction = traceDir
    out.positiveHit = positiveHit == true
    out.positiveWorldPos = positiveHit and setVec(out.positiveWorldPos, positiveWorldPos) or nil
    out.positiveTrace = positiveHit and positiveTrace or nil
    out.negativeHit = negativeHit == true
    out.negativeWorldPos = negativeHit and setVec(out.negativeWorldPos, negativeWorldPos) or nil
    out.negativeTrace = negativeHit and negativeTrace or nil
    out.hit = positiveHit or negativeHit
    out.worldPos = isvector(worldPos) and setVec(out.worldPos, worldPos) or nil
    out.side = side
    out.trace = side == "positive" and positiveTrace or side == "negative" and negativeTrace or nil

    return out
end

local function traceSnapFromGizmo(state, press, currentGizmoPos, traceLength)
    if not press or not press.gizmo or traceLength <= 0 then
        if press then
            press.traceSnapAxes = nil
            press.lastTraceSnapHit = nil
        end
        return
    end
    if press.gizmo.kind ~= "move" and press.gizmo.kind ~= "plane" then
        press.traceSnapAxes = nil
        press.lastTraceSnapHit = nil
        return
    end

    local filter = gizmoTraceFilter(state, press._magicAlignTraceFilter)
    press._magicAlignTraceFilter = filter
    local snapped = setVec(press._magicAlignTraceSnapped, currentGizmoPos)
    press._magicAlignTraceSnapped = snapped
    local didSnap = false
    local snappedAxes = press._magicAlignTraceSnappedAxes or {}
    press._magicAlignTraceSnappedAxes = snappedAxes
    snappedAxes.x, snappedAxes.y, snappedAxes.z = nil, nil, nil
    local traceSnapAxes = press._magicAlignTraceSnapAxes or {}
    press._magicAlignTraceSnapAxes = traceSnapAxes
    traceSnapAxes.x, traceSnapAxes.y, traceSnapAxes.z = nil, nil, nil
    local axisResults = press._magicAlignTraceAxisResults or {}
    press._magicAlignTraceAxisResults = axisResults
    local lastTraceSnapHit = press._magicAlignLastTraceSnapHit or {}
    press._magicAlignLastTraceSnapHit = lastTraceSnapHit
    local function snapAxis(key)
        local direction = gizmoTraceDirectionForAxis(press, currentGizmoPos, key)
        if not isvector(direction) or M.VectorLengthSqrPrecise(direction) < M.PICKING_VECTOR_EPSILON_SQR then return end

        local traceStart = traceSnapStartWorldPos(state, press, currentGizmoPos, direction)
        if not isvector(traceStart) then return end

        axisResults[key] = axisResults[key] or {}
        local axisResult = traceSnapAxisResult(traceStart, direction, traceLength, filter, axisResults[key])
        if not axisResult then return end

        local snapWorldPos = axisResult.worldPos
        axisResult.start = setVec(axisResult.start, traceStart)
        traceSnapAxes[key] = axisResult
        if not isvector(snapWorldPos) then return end

        local snapLocalPos = worldToGizmoLocal(snapWorldPos, press)
        if not snapLocalPos then return end

        lastTraceSnapHit.key = key
        lastTraceSnapHit.worldPos = setVec(lastTraceSnapHit.worldPos, snapWorldPos)
        lastTraceSnapHit.trace = axisResult.trace
        applyAxisSnap(snapped, key, snapLocalPos, snappedAxes)
        didSnap = true
    end

    snapAxis("x")
    snapAxis("y")
    snapAxis("z")

    press.traceSnapAxes = next(traceSnapAxes) and traceSnapAxes or nil
    press.lastTraceSnapHit = didSnap and lastTraceSnapHit or nil

    return didSnap and snapped or nil, didSnap and snappedAxes or nil
end

local function candidateIsDirectGizmoSnapTarget(candidate)
    if not istable(candidate) or not isvector(candidate.worldPos) then return false end
    return not geometry.isWorldTarget(candidate.ent)
end

function client.snapGizmoPosition(state, press, currentGizmoPos)
    if not press or not press.gizmo or not isvector(currentGizmoPos) then return currentGizmoPos end

    local translationStep = state.hover and state.hover.settings and state.hover.settings.translationSnap or 0
    local priorityAxes = press._magicAlignPriorityAxes or {}
    press._magicAlignPriorityAxes = priorityAxes
    priorityAxes.x, priorityAxes.y, priorityAxes.z = nil, nil, nil
    local function snapToTranslation(localPos)
        if not isvector(localPos) or translationStep <= 0 then return localPos end
        -- Grid-, Anchor- und Trace-Snaps duerfen die bereits festgelegten Achsen
        -- behalten; Translation-Snap ergaenzt nur noch die restlichen Gizmo-Achsen.
        return snapGizmoTranslation(press.gizmo, press.dragStartLocal, localPos, translationStep, priorityAxes)
    end

    local function snapToWorldPos(worldPos)
        if not isvector(worldPos) then return end

        local snapLocalPos = worldToGizmoLocal(worldPos, press)
        if not snapLocalPos then return end

        return applyHandleSnap(press.gizmo, currentGizmoPos, snapLocalPos, priorityAxes)
    end

    local suppressShiftSnap = (state.hover and state.hover.settings and state.hover.settings.shift)
        or input.IsKeyDown(KEY_LSHIFT)
        or input.IsKeyDown(KEY_RSHIFT)

    if suppressShiftSnap then
        press.traceSnapAxes = nil
        press.lastTraceSnapHit = nil
    end

    local hoverPointIsWorld = state.hover and state.hover.point and geometry.isWorldTarget(state.hover.ent)
    local hoverPointIsEditedPoint = press.pointGizmo == true
        and state.hover
        and state.hover.point
        and state.hover.side == press.side
        and math.floor(tonumber(state.hover.point.index) or 0) == math.floor(tonumber(press.pointGizmoIndex or press.worldPointIndex or press.index) or 0)
    if not suppressShiftSnap
        and not hoverPointIsWorld
        and not hoverPointIsEditedPoint
        and state.hover
        and state.hover.point
        and isvector(state.hover.point.worldPos) then
        press.traceSnapAxes = nil
        press.lastTraceSnapHit = nil
        return snapToTranslation(snapToWorldPos(state.hover.point.worldPos) or currentGizmoPos)
    end

    local hoverCandidate = state.hover and (state.hover.candidate or state.hover.overlay)
    local traceLength = state.hover and state.hover.settings and state.hover.settings.traceSnapLength or 0

    if hoverCandidate and isvector(hoverCandidate.worldPos) then
        if not suppressShiftSnap and traceLength > 0 then
            traceSnapFromGizmo(state, press, currentGizmoPos, traceLength)
        else
            press.traceSnapAxes = nil
            press.lastTraceSnapHit = nil
        end

        if candidateIsDirectGizmoSnapTarget(hoverCandidate) then
            return snapToTranslation(snapToWorldPos(hoverCandidate.worldPos) or currentGizmoPos)
        end
    end

    if suppressShiftSnap then
        return currentGizmoPos
    end

    local traceSnapPos, traceSnapAxes = traceSnapFromGizmo(state, press, currentGizmoPos, traceLength)
    if traceSnapPos then
        mergeSnapAxes(priorityAxes, traceSnapAxes)
        return snapToTranslation(traceSnapPos)
    end

    return snapToTranslation(currentGizmoPos)
end

return client.snapGizmoPosition
