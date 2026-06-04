local M = MAGIC_ALIGN
if not M then return end

local VectorP = M.VectorP
local isvector = M.IsVectorLike
local isangle = M.IsAngleLike
local copyVec = M.CopyVectorPrecise
local copyAng = M.CopyAnglePrecise
local DEG_TO_RAD = math.pi / 180

local publicResolveCache = {}
local publicClassifyCache = {}

local function numberOrZero(value)
    value = tonumber(value)
    if value ~= nil and value == value and value ~= math.huge and value ~= -math.huge then
        return value
    end

    return 0
end

local function mirrorLabel(kind)
    if kind == M.MIRROR_PLANE then
        return "Plane"
    elseif kind == M.MIRROR_AXIS then
        return "Axis"
    end

    return "Point"
end

local function setVec(out, x, y, z)
    if not isvector(out) then
        return VectorP(x, y, z)
    end

    out.x, out.y, out.z = numberOrZero(x), numberOrZero(y), numberOrZero(z)
    return out
end

local function copyVecInto(out, value)
    if not isvector(value) then return end
    return setVec(out, value.x, value.y, value.z)
end

local function clearVectorList(list, first)
    for i = first, #list do
        list[i] = nil
    end
end

local function distSqr(a, b)
    local dx = numberOrZero(a.x) - numberOrZero(b.x)
    local dy = numberOrZero(a.y) - numberOrZero(b.y)
    local dz = numberOrZero(a.z) - numberOrZero(b.z)
    return dx * dx + dy * dy + dz * dz
end

local function dot(a, b)
    return numberOrZero(a.x) * numberOrZero(b.x)
        + numberOrZero(a.y) * numberOrZero(b.y)
        + numberOrZero(a.z) * numberOrZero(b.z)
end

local function subtractInto(out, a, b)
    return setVec(
        out,
        numberOrZero(a.x) - numberOrZero(b.x),
        numberOrZero(a.y) - numberOrZero(b.y),
        numberOrZero(a.z) - numberOrZero(b.z)
    )
end

local function scaleInto(out, value, scale)
    scale = numberOrZero(scale)
    return setVec(out, numberOrZero(value.x) * scale, numberOrZero(value.y) * scale, numberOrZero(value.z) * scale)
end

local function addScaledInto(out, origin, axisA, scaleA, axisB, scaleB, axisC, scaleC)
    local x = numberOrZero(origin.x)
    local y = numberOrZero(origin.y)
    local z = numberOrZero(origin.z)

    if isvector(axisA) then
        scaleA = numberOrZero(scaleA)
        x, y, z = x + numberOrZero(axisA.x) * scaleA, y + numberOrZero(axisA.y) * scaleA, z + numberOrZero(axisA.z) * scaleA
    end
    if isvector(axisB) then
        scaleB = numberOrZero(scaleB)
        x, y, z = x + numberOrZero(axisB.x) * scaleB, y + numberOrZero(axisB.y) * scaleB, z + numberOrZero(axisB.z) * scaleB
    end
    if isvector(axisC) then
        scaleC = numberOrZero(scaleC)
        x, y, z = x + numberOrZero(axisC.x) * scaleC, y + numberOrZero(axisC.y) * scaleC, z + numberOrZero(axisC.z) * scaleC
    end

    return setVec(out, x, y, z)
end

local function crossInto(out, a, b)
    local ax, ay, az = numberOrZero(a.x), numberOrZero(a.y), numberOrZero(a.z)
    local bx, by, bz = numberOrZero(b.x), numberOrZero(b.y), numberOrZero(b.z)

    return setVec(out, ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
end

local function normalizeInto(out, value, epsilonSqr)
    if not isvector(value) then return end

    local lengthSqr = dot(value, value)
    if lengthSqr <= (tonumber(epsilonSqr) or M.COMPUTE_VECTOR_EPSILON_SQR) then return end

    return scaleInto(out, value, 1 / math.sqrt(lengthSqr))
end

local function projectOntoPlaneInto(out, value, normal, epsilonSqr)
    if not isvector(value) or not isvector(normal) then return end

    local d = dot(value, normal)
    setVec(
        out,
        numberOrZero(value.x) - numberOrZero(normal.x) * d,
        numberOrZero(value.y) - numberOrZero(normal.y) * d,
        numberOrZero(value.z) - numberOrZero(normal.z) * d
    )

    return normalizeInto(out, out, epsilonSqr)
end

local function localToWorldPosInto(out, localPos, originPos, originAng)
    originPos = isvector(originPos) and originPos or M.ZERO
    originAng = isangle(originAng) and originAng or M.ZERO_ANGLE

    local x = numberOrZero(localPos.x)
    local y = numberOrZero(localPos.y)
    local z = numberOrZero(localPos.z)
    local pitch = numberOrZero(originAng.p)
    local yaw = numberOrZero(originAng.y)
    local roll = numberOrZero(originAng.r)
    local sp, sy, sr = math.sin(pitch * DEG_TO_RAD), math.sin(yaw * DEG_TO_RAD), math.sin(roll * DEG_TO_RAD)
    local cp, cy, cr = math.cos(pitch * DEG_TO_RAD), math.cos(yaw * DEG_TO_RAD), math.cos(roll * DEG_TO_RAD)

    return setVec(
        out,
        numberOrZero(originPos.x) + (cp * cy) * x + (sp * sr * cy - cr * sy) * y + (sp * cr * cy + sr * sy) * z,
        numberOrZero(originPos.y) + (cp * sy) * x + (sp * sr * sy + cr * cy) * y + (sp * cr * sy - sr * cy) * z,
        numberOrZero(originPos.z) + (-sp) * x + (sr * cp) * y + (cr * cp) * z
    )
end

local function resolvedReference(point, fallbackEnt)
    if M.ResolvePointReference then
        return M.ResolvePointReference(point, fallbackEnt)
    end

    return fallbackEnt
end

local function resolvePointWorldInto(point, fallbackEnt, out, options)
    if not isvector(point) then return end

    if options and options.worldPoints == true then
        return copyVecInto(out, point), M.WORLD_TARGET, nil, nil, M.ENTITY_MIRROR_NONE or 0
    end

    local ent = resolvedReference(point, fallbackEnt)
    if M.IsWorldTarget and M.IsWorldTarget(ent) then
        return copyVecInto(out, point), ent, nil, nil, M.ENTITY_MIRROR_NONE or 0
    end

    if IsValid(ent) then
        if M.ResolvePointWorldPositionInto then
            local world, ref, refPos, refAng, refMirrorAxis = M.ResolvePointWorldPositionInto(out, point, fallbackEnt)
            if isvector(world) then
                return world, ref or ent, refPos, refAng, refMirrorAxis
            end
        end

        local pos = ent:GetPos()
        local ang = ent:GetAngles()
        local mirrorAxis = M.ENTITY_MIRROR_NONE or 0
        if M.EntityMirror and M.EntityMirror.AxisForEntity then
            mirrorAxis = M.EntityMirror.AxisForEntity(ent)
        elseif M.EntityMirror and M.EntityMirror.GetAxis then
            mirrorAxis = M.EntityMirror.GetAxis(ent)
        end
        if M.EntityMirror and M.EntityMirror.LocalPointToWorld then
            local world = M.EntityMirror.LocalPointToWorld(ent, point, out)
            if isvector(world) then
                return world, ent, pos, ang, mirrorAxis
            end
        end

        return localToWorldPosInto(out, point, pos, ang), ent, pos, ang, mirrorAxis
    end
end

local function markPointSignature(cache, index, point, ref, world, refPos, refAng, refMirrorAxis)
    local signatures = cache.signatures or {}
    cache.signatures = signatures

    local sig = signatures[index]
    if not sig then
        sig = {}
        signatures[index] = sig
    end

    local refKind = istable(point.reference) and point.reference.kind or nil
    local refEnt = istable(point.reference) and point.reference.ent or nil
    local changed = sig.present ~= true
        or sig.point ~= point
        or sig.x ~= point.x or sig.y ~= point.y or sig.z ~= point.z
        or sig.world ~= (point.world == true)
        or sig.refKind ~= refKind
        or sig.refEnt ~= refEnt
        or sig.resolvedRef ~= ref
        or sig.refMirrorAxis ~= refMirrorAxis
        or sig.wx ~= world.x or sig.wy ~= world.y or sig.wz ~= world.z
        or sig.rpx ~= (refPos and refPos.x) or sig.rpy ~= (refPos and refPos.y) or sig.rpz ~= (refPos and refPos.z)
        or sig.rap ~= (refAng and refAng.p) or sig.ray ~= (refAng and refAng.y) or sig.rar ~= (refAng and refAng.r)

    sig.present = true
    sig.point = point
    sig.x, sig.y, sig.z = point.x, point.y, point.z
    sig.world = point.world == true
    sig.refKind = refKind
    sig.refEnt = refEnt
    sig.resolvedRef = ref
    sig.refMirrorAxis = refMirrorAxis
    sig.wx, sig.wy, sig.wz = world.x, world.y, world.z
    sig.rpx, sig.rpy, sig.rpz = refPos and refPos.x or nil, refPos and refPos.y or nil, refPos and refPos.z or nil
    sig.rap, sig.ray, sig.rar = refAng and refAng.p or nil, refAng and refAng.y or nil, refAng and refAng.r or nil

    return changed
end

local function clearStaleSignatures(cache, first)
    local signatures = cache.signatures
    if not signatures then return false end

    local changed = false
    for i = first, #signatures do
        local sig = signatures[i]
        if sig and sig.present then
            sig.present = false
            sig.point = nil
            sig.refKind = nil
            sig.refEnt = nil
            sig.resolvedRef = nil
            sig.refMirrorAxis = nil
            sig.rpx, sig.rpy, sig.rpz = nil, nil, nil
            sig.rap, sig.ray, sig.rar = nil, nil, nil
            changed = true
        end
    end

    return changed
end

local function farthestPair(points, count)
    local bestA, bestB, bestDist = points[1], points[2], -1

    for i = 1, count - 1 do
        for j = i + 1, count do
            local dist = distSqr(points[i], points[j])
            if dist > bestDist then
                bestA, bestB, bestDist = points[i], points[j], dist
            end
        end
    end

    return bestA, bestB, bestDist
end

local function planeAxesInto(normal, axisA, axisB, scratch)
    if not isvector(normal) then return end

    scratch = scratch or {}
    local candidate = scratch.candidate

    candidate = setVec(candidate, 0, 0, 1)
    scratch.candidate = candidate
    if not projectOntoPlaneInto(axisA, candidate, normal, M.COMPUTE_VECTOR_EPSILON_SQR) then
        setVec(candidate, 0, 1, 0)
        if not projectOntoPlaneInto(axisA, candidate, normal, M.COMPUTE_VECTOR_EPSILON_SQR) then
            setVec(candidate, 1, 0, 0)
            if not projectOntoPlaneInto(axisA, candidate, normal, M.COMPUTE_VECTOR_EPSILON_SQR) then
                return
            end
        end
    end

    crossInto(axisB, normal, axisA)
    if not normalizeInto(axisB, axisB, M.COMPUTE_VECTOR_EPSILON_SQR) then return end

    return axisA, axisB
end

local function updateMidpoint(cache)
    local points = cache.worldPoints or {}
    local count = tonumber(cache.pointCount) or 0
    local midpoint = cache.midpoint

    if count <= 0 then
        cache.hasMidpoint = false
        return
    end

    local x, y, z = 0, 0, 0
    for i = 1, count do
        local point = points[i]
        x, y, z = x + numberOrZero(point.x), y + numberOrZero(point.y), z + numberOrZero(point.z)
    end

    cache.midpoint = setVec(midpoint, x / count, y / count, z / count)
    cache.hasMidpoint = true
end

local function updatePlaneRenderData(cache, reference)
    if not reference or reference.kind ~= M.MIRROR_PLANE then
        cache.planeHalfSize = nil
        return
    end

    local origin = reference.point
    local axisA = reference.tangentA
    local axisB = reference.tangentB
    if not isvector(origin) or not isvector(axisA) or not isvector(axisB) then
        cache.planeHalfSize = nil
        return
    end

    local points = cache.worldPoints or {}
    local count = tonumber(cache.pointCount) or 0
    local minU, maxU, minV, maxV
    local scratch = cache.scratch or {}
    cache.scratch = scratch
    local delta = scratch.planeDelta

    for i = 1, count do
        local point = points[i]
        if isvector(point) then
            delta = subtractInto(delta, point, origin)
            scratch.planeDelta = delta
            local u = dot(delta, axisA)
            local v = dot(delta, axisB)

            minU = minU and math.min(minU, u) or u
            maxU = maxU and math.max(maxU, u) or u
            minV = minV and math.min(minV, v) or v
            maxV = maxV and math.max(maxV, v) or v
        end
    end

    if not minU then
        cache.planeHalfSize = nil
        return
    end

    local midU = (minU + maxU) * 0.5
    local midV = (minV + maxV) * 0.5
    local halfSize = math.max(maxU - minU, maxV - minV, 0.01) * 1.5
    local center = addScaledInto(cache.planeCenter, origin, axisA, midU, axisB, midV)
    cache.planeCenter = center
    cache.planeAxisA = copyVecInto(cache.planeAxisA, axisA)
    cache.planeAxisB = copyVecInto(cache.planeAxisB, axisB)
    cache.planeHalfSize = halfSize

    local corners = cache.planeCorners or {}
    cache.planeCorners = corners
    local push = 0.06
    corners[1] = addScaledInto(corners[1], center, axisA, -halfSize, axisB, -halfSize, reference.normal, push)
    corners[2] = addScaledInto(corners[2], center, axisA, halfSize, axisB, -halfSize, reference.normal, push)
    corners[3] = addScaledInto(corners[3], center, axisA, halfSize, axisB, halfSize, reference.normal, push)
    corners[4] = addScaledInto(corners[4], center, axisA, -halfSize, axisB, halfSize, reference.normal, push)
end

local function clearReference(reference)
    reference.kind = nil
    reference.label = nil
    reference.point = nil
    reference.axisA = nil
    reference.axisB = nil
    reference.axis = nil
    reference.normal = nil
    reference.tangentA = nil
    reference.tangentB = nil
    reference.points = nil
end

local function classifyCache(cache)
    local worldPoints = cache.worldPoints or {}
    local unique = cache.uniquePoints or {}
    cache.uniquePoints = unique

    local uniqueCount = 0
    local epsilonSqr = tonumber(M.MIRROR_EPSILON_SQR) or M.COMPUTE_VECTOR_EPSILON_SQR
    for i = 1, math.min(tonumber(cache.pointCount) or 0, M.MAX_POINTS) do
        local world = worldPoints[i]
        if isvector(world) then
            local duplicate = false
            for j = 1, uniqueCount do
                if distSqr(world, unique[j]) <= epsilonSqr then
                    duplicate = true
                    break
                end
            end

            if not duplicate then
                uniqueCount = uniqueCount + 1
                unique[uniqueCount] = copyVecInto(unique[uniqueCount], world)
            end
        end
    end
    clearVectorList(unique, uniqueCount + 1)

    local reference = cache.reference or {}
    cache.reference = reference
    clearReference(reference)
    cache.uniqueCount = uniqueCount

    if uniqueCount < 1 then
        cache.valid = false
        cache.kind = nil
        cache.label = nil
        cache.planeHalfSize = nil
        return
    end

    reference.points = unique

    if uniqueCount == 1 then
        reference.kind = M.MIRROR_POINT
        reference.label = mirrorLabel(M.MIRROR_POINT)
        reference.point = unique[1]

        cache.valid = true
        cache.kind = reference.kind
        cache.label = reference.label
        cache.planeHalfSize = nil
        return reference
    end

    local scratch = cache.scratch or {}
    cache.scratch = scratch

    if uniqueCount == 2 then
        local dir = subtractInto(reference.axis or scratch.axis, unique[2], unique[1])
        reference.axis = normalizeInto(dir, dir, epsilonSqr)
        if not reference.axis then
            reference.kind = M.MIRROR_POINT
            reference.label = mirrorLabel(M.MIRROR_POINT)
            reference.point = unique[1]
        else
            reference.kind = M.MIRROR_AXIS
            reference.label = mirrorLabel(M.MIRROR_AXIS)
            reference.point = unique[1]
            reference.axisA = unique[1]
            reference.axisB = unique[2]
        end

        cache.valid = true
        cache.kind = reference.kind
        cache.label = reference.label
        cache.planeHalfSize = nil
        return reference
    end

    local a, b, c = unique[1], unique[2], unique[3]
    scratch.ab = subtractInto(scratch.ab, b, a)
    scratch.ac = subtractInto(scratch.ac, c, a)
    local normal = crossInto(reference.normal or scratch.normal, scratch.ab, scratch.ac)
    reference.normal = normalizeInto(normal, normal, epsilonSqr)
    if reference.normal then
        reference.tangentA = reference.tangentA or VectorP(0, 0, 0)
        reference.tangentB = reference.tangentB or VectorP(0, 0, 0)
        if planeAxesInto(reference.normal, reference.tangentA, reference.tangentB, scratch) then
            reference.kind = M.MIRROR_PLANE
            reference.label = mirrorLabel(M.MIRROR_PLANE)
            reference.point = a

            cache.valid = true
            cache.kind = reference.kind
            cache.label = reference.label
            updatePlaneRenderData(cache, reference)
            return reference
        end
    end

    local axisA, axisB = farthestPair(unique, uniqueCount)
    local dir = axisA and axisB and subtractInto(reference.axis or scratch.axis, axisB, axisA) or nil
    reference.axis = dir and normalizeInto(dir, dir, epsilonSqr) or nil
    if not reference.axis then
        reference.kind = M.MIRROR_POINT
        reference.label = mirrorLabel(M.MIRROR_POINT)
        reference.point = unique[1]
    else
        reference.kind = M.MIRROR_AXIS
        reference.label = mirrorLabel(M.MIRROR_AXIS)
        reference.point = axisA
        reference.axisA = axisA
        reference.axisB = axisB
    end

    cache.valid = true
    cache.kind = reference.kind
    cache.label = reference.label
    cache.planeHalfSize = nil
    return reference
end

local function copyReference(reference)
    if not istable(reference) or not reference.kind then return end

    local out = {
        kind = reference.kind,
        label = reference.label
    }

    if isvector(reference.point) then out.point = copyVec(reference.point) end
    if isvector(reference.axisA) then out.axisA = copyVec(reference.axisA) end
    if isvector(reference.axisB) then out.axisB = copyVec(reference.axisB) end
    if isvector(reference.axis) then out.axis = copyVec(reference.axis) end
    if isvector(reference.normal) then out.normal = copyVec(reference.normal) end
    if isvector(reference.tangentA) then out.tangentA = copyVec(reference.tangentA) end
    if isvector(reference.tangentB) then out.tangentB = copyVec(reference.tangentB) end

    if istable(reference.points) then
        out.points = {}
        for i = 1, #reference.points do
            if isvector(reference.points[i]) then
                out.points[#out.points + 1] = copyVec(reference.points[i])
            end
        end
    end

    return out
end

function M.IsMirrorMode(stateOrSpace)
    if istable(stateOrSpace) then
        return stateOrSpace.activeSpace == M.MIRROR_SPACE
    end

    return stateOrSpace == M.MIRROR_SPACE
end

function M.GetMirrorStateCache(state, key)
    if not istable(state) then return end

    state.mirror = state.mirror or {}
    state.mirror.points = state.mirror.points or {}

    key = key or "_magicAlignMirrorCache"
    state.mirror[key] = state.mirror[key] or {}
    return state.mirror[key]
end

function M.ResolveMirrorState(mirror, cache, options)
    mirror = istable(mirror) and mirror or {}
    options = istable(options) and options or {}
    cache = istable(cache) and cache or {}

    local points = istable(options.points) and options.points or (istable(mirror.points) and mirror.points or {})
    local fallbackEnt = options.fallbackEnt
    local worldPoints = cache.worldPoints or {}
    cache.worldPoints = worldPoints

    local changed = false
    local active = M.IsMirrorMode(options.activeSpace)
    if cache.active ~= active then
        cache.active = active
        changed = true
    end

    local pointCount = 0
    for i = 1, math.min(#points, M.MAX_POINTS) do
        local point = points[i]
        local slot = worldPoints[pointCount + 1]
        local world, ref, refPos, refAng, refMirrorAxis = resolvePointWorldInto(point, fallbackEnt, slot, options)
        if isvector(world) then
            pointCount = pointCount + 1
            worldPoints[pointCount] = world
            if markPointSignature(cache, pointCount, point, ref, world, refPos, refAng, refMirrorAxis) then
                changed = true
            end
        end
    end

    clearVectorList(worldPoints, pointCount + 1)
    if cache.pointCount ~= pointCount then
        cache.pointCount = pointCount
        changed = true
    end
    if clearStaleSignatures(cache, pointCount + 1) then
        changed = true
    end

    if changed or cache.resolved ~= true then
        cache.resolved = true
        cache.revision = (tonumber(cache.revision) or 0) + 1
        updateMidpoint(cache)
        classifyCache(cache)
        mirror.classification = cache.label
    end

    return cache
end

function M.ResolveMirrorWorldPoints(points, fallbackEnt)
    local cache = M.ResolveMirrorState({ points = points }, publicResolveCache, {
        fallbackEnt = fallbackEnt
    })
    local out = {}

    local count = tonumber(cache.pointCount) or 0
    for i = 1, count do
        if isvector(cache.worldPoints[i]) then
            out[#out + 1] = copyVec(cache.worldPoints[i])
        end
    end

    return out
end

function M.ClassifyMirrorReferenceFromWorldPoints(worldPoints)
    local cache = M.ResolveMirrorState({ points = worldPoints }, publicClassifyCache, {
        worldPoints = true
    })

    return copyReference(cache.reference)
end

function M.ClassifyMirrorReference(points, fallbackEnt)
    local cache = M.ResolveMirrorState({ points = points }, publicClassifyCache, {
        fallbackEnt = fallbackEnt
    })

    return copyReference(cache.reference)
end

local function mirrorVectorAcrossPlane(vec, normal)
    return M.SubtractVectorsPrecise(vec, M.ScaleVectorPrecise(normal, 2 * M.DotVectorsPrecise(vec, normal)))
end

local function mirrorVectorAroundAxis(vec, axis)
    return M.SubtractVectorsPrecise(M.ScaleVectorPrecise(axis, 2 * M.DotVectorsPrecise(vec, axis)), vec)
end

local function repairedAngle(ang, forward, upHint)
    local repaired = M.AngleFromForwardUpPrecise(forward, upHint)
    return repaired or copyAng(ang)
end

local function entityMirrorAxis(ent)
    if not IsValid(ent) then return M.ENTITY_MIRROR_NONE or 0 end
    if M.EntityMirror and M.EntityMirror.AxisForEntity then
        return M.EntityMirror.AxisForEntity(ent)
    elseif M.EntityMirror and M.EntityMirror.GetAxis then
        return M.EntityMirror.GetAxis(ent)
    end

    return M.ENTITY_MIRROR_NONE or 0
end

local function referenceMirrorAxis(reference)
    if M.EntityMirror and M.EntityMirror.AxisForMirrorReference then
        return M.EntityMirror.AxisForMirrorReference(reference)
    end

    return M.ENTITY_MIRROR_NONE or 0
end

local function composeEntityMirrorAxis(currentAxis, deltaAxis)
    if M.EntityMirror and M.EntityMirror.ComposeAxis then
        return M.EntityMirror.ComposeAxis(currentAxis, deltaAxis)
    end

    currentAxis = math.Clamp(math.floor(tonumber(currentAxis) or (M.ENTITY_MIRROR_NONE or 0)), M.ENTITY_MIRROR_NONE or 0, M.ENTITY_MIRROR_Z or 3)
    deltaAxis = math.Clamp(math.floor(tonumber(deltaAxis) or (M.ENTITY_MIRROR_NONE or 0)), M.ENTITY_MIRROR_NONE or 0, M.ENTITY_MIRROR_Z or 3)
    if deltaAxis == (M.ENTITY_MIRROR_NONE or 0) then return currentAxis end
    if currentAxis == (M.ENTITY_MIRROR_NONE or 0) then return deltaAxis end
    if currentAxis == deltaAxis then return M.ENTITY_MIRROR_NONE or 0 end
    return M.ENTITY_MIRROR_NONE or 0
end

local function remainingMirrorAxis(a, b)
    local none = M.ENTITY_MIRROR_NONE or 0
    a = math.Clamp(math.floor(tonumber(a) or none), none, M.ENTITY_MIRROR_Z or 3)
    b = math.Clamp(math.floor(tonumber(b) or none), none, M.ENTITY_MIRROR_Z or 3)
    if a == none or b == none or a == b then return none end

    for axis = M.ENTITY_MIRROR_X or 1, M.ENTITY_MIRROR_Z or 3 do
        if axis ~= a and axis ~= b then
            return axis
        end
    end

    return none
end

local function angleLocalAxisWorld(ang, axis)
    if not isangle(ang) then return end

    if axis == M.ENTITY_MIRROR_X and M.AngleForwardPrecise then
        return M.AngleForwardPrecise(ang)
    elseif axis == M.ENTITY_MIRROR_Y and M.AngleRightPrecise then
        return M.AngleRightPrecise(ang)
    elseif axis == M.ENTITY_MIRROR_Z and M.AngleUpPrecise then
        return M.AngleUpPrecise(ang)
    end
end

local function bakeEntityMirrorComposition(ang, currentAxis, deltaAxis)
    local targetAxis = composeEntityMirrorAxis(currentAxis, deltaAxis)
    local rotationAxis = remainingMirrorAxis(currentAxis, deltaAxis)
    if rotationAxis == (M.ENTITY_MIRROR_NONE or 0) then
        return ang, targetAxis, rotationAxis, false
    end

    local worldAxis = angleLocalAxisWorld(ang, rotationAxis)
    if not isvector(worldAxis) or not M.RotateAngleAroundAxisPrecise then
        return ang, targetAxis, rotationAxis, false
    end

    local baked = M.RotateAngleAroundAxisPrecise(ang, worldAxis, 180)
    return isangle(baked) and baked or ang, targetAxis, rotationAxis, isangle(baked)
end

function M.MirrorPose(pos, ang, reference)
    if not isvector(pos) or not isangle(ang) or not istable(reference) then return end

    local kind = reference.kind
    local outPos
    local outAng

    if kind == M.MIRROR_POINT and isvector(reference.point) then
        outPos = M.SubtractVectorsPrecise(M.ScaleVectorPrecise(reference.point, 2), pos)
        -- Point and plane reflections are left-handed transforms. Props can only
        -- receive right-handed Angles, so Mirror reflects the facing/up hints and
        -- rebuilds a deterministic prop-compatible basis from them.
        outAng = repairedAngle(ang, -M.AngleForwardPrecise(ang), -M.AngleUpPrecise(ang))
    elseif kind == M.MIRROR_AXIS and isvector(reference.point) and isvector(reference.axis) then
        local delta = M.SubtractVectorsPrecise(pos, reference.point)
        outPos = M.AddVectorsPrecise(reference.point, mirrorVectorAroundAxis(delta, reference.axis))
        outAng = M.RotateAngleAroundAxisPrecise(ang, reference.axis, 180)
    elseif kind == M.MIRROR_PLANE and isvector(reference.point) and isvector(reference.normal) then
        local delta = M.SubtractVectorsPrecise(pos, reference.point)
        outPos = M.SubtractVectorsPrecise(pos, M.ScaleVectorPrecise(reference.normal, 2 * M.DotVectorsPrecise(delta, reference.normal)))
        outAng = repairedAngle(
            ang,
            mirrorVectorAcrossPlane(M.AngleForwardPrecise(ang), reference.normal),
            mirrorVectorAcrossPlane(M.AngleUpPrecise(ang), reference.normal)
        )
    end

    if not isvector(outPos) or not isangle(outAng) then return end

    return outPos, outAng
end

function M.MirrorEntityPose(ent, reference)
    if not IsValid(ent) or not istable(reference) then return end

    local pos, ang = M.MirrorPose(ent:GetPos(), ent:GetAngles(), reference)
    if not isvector(pos) or not isangle(ang) then return end

    local currentAxis = entityMirrorAxis(ent)
    local deltaAxis = referenceMirrorAxis(reference)
    local targetAng, targetAxis, rotationAxis, bakedRotation = bakeEntityMirrorComposition(ang, currentAxis, deltaAxis)

    return pos, targetAng, targetAxis, currentAxis, deltaAxis, rotationAxis, bakedRotation
end

function M.ApplyTransformModeToPropSet(mode, prop1, linked, data, out)
    if mode ~= M.TRANSFORM_MODE_MIRROR or not IsValid(prop1) then return end

    local reference = data and data.reference or data
    if not istable(reference) then return end

    out = istable(out) and out or {}
    local linkedOut = istable(out.linked) and out.linked or {}
    out.linked = linkedOut

    local pos, ang, targetAxis, currentAxis, deltaAxis, rotationAxis, bakedRotation = M.MirrorEntityPose(prop1, reference)
    if not isvector(pos) or not isangle(ang) then return end
    if M.EntityMirror and M.EntityMirror.DebugEntity then
        M.EntityMirror.DebugEntity("mirror-pose-prop1", prop1, {
            referenceKind = reference.kind,
            referencePoint = reference.point,
            referenceAxis = reference.axis,
            referenceNormal = reference.normal,
            targetPos = pos,
            targetAng = ang,
            currentAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(currentAxis) or tostring(currentAxis),
            deltaAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(deltaAxis) or tostring(deltaAxis),
            previewAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(targetAxis) or tostring(targetAxis),
            bakedRotationAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(rotationAxis) or tostring(rotationAxis),
            bakedRotation = bakedRotation == true
        })
    end

    out.pos = pos
    out.ang = ang
    out.mode = mode
    out.reference = reference

    local linkedCount = 0
    linked = istable(linked) and linked or {}
    for i = 1, #linked do
        local ent = linked[i]
        if IsValid(ent) and ent ~= prop1 and M.IsProp(ent) then
            local linkedPos, linkedAng, linkedTargetAxis, linkedCurrentAxis, linkedDeltaAxis, linkedRotationAxis, linkedBakedRotation = M.MirrorEntityPose(ent, reference)
            if isvector(linkedPos) and isangle(linkedAng) then
                if M.EntityMirror and M.EntityMirror.DebugEntity then
                    M.EntityMirror.DebugEntity("mirror-pose-linked", ent, {
                        referenceKind = reference.kind,
                        targetPos = linkedPos,
                        targetAng = linkedAng,
                        currentAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(linkedCurrentAxis) or tostring(linkedCurrentAxis),
                        deltaAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(linkedDeltaAxis) or tostring(linkedDeltaAxis),
                        previewAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(linkedTargetAxis) or tostring(linkedTargetAxis),
                        bakedRotationAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(linkedRotationAxis) or tostring(linkedRotationAxis),
                        bakedRotation = linkedBakedRotation == true
                    })
                end

                linkedCount = linkedCount + 1
                local entry = linkedOut[linkedCount]
                if not istable(entry) then
                    entry = {}
                    linkedOut[linkedCount] = entry
                end

                entry.ent = ent
                entry.pos = linkedPos
                entry.ang = linkedAng
                entry.absolute = true
            end
        end
    end

    for i = linkedCount + 1, #linkedOut do
        linkedOut[i] = nil
    end

    return out
end

return M
