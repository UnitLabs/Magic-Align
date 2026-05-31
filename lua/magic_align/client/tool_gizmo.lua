MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local geometry = client.geometry or {}
client.geometry = geometry
local core = client.ToolCore or include("magic_align/tool_config.lua")
local VectorP = M.VectorP
local isvector = M.IsVectorLike
local isangle = M.IsAngleLike
local colors = core.colors
local copyVec = core.copyVec
local copyAng = core.copyAng
local ZERO_VEC = core.ZERO_VEC
local ZERO_ANG = core.ZERO_ANG
local LocalToWorldPosPrecise = core.LocalToWorldPosPrecise
local setVec = core.setVec
local normalizedVec = core.normalizedVec
local clientNumber = core.clientNumber
local sampleWorldPos = core.sampleWorldPos
local sampleLocalPos = core.sampleLocalPos
local sampleLocalNormal = core.sampleLocalNormal
local aggregateTraceProbes = core.aggregateTraceProbes
local buildTraceProbeCandidate = core.buildTraceProbeCandidate
local boundsFor = core.boundsFor
local ringCoords = core.ringCoords
local ringAngle = core.ringAngle
local worldCandidateFromTrace = core.worldCandidateFromTrace
local function hoverPoint(ent, points, fallbackEnt, cache)
    local x, y = ScrW() * 0.5, ScrH() * 0.5
    local best, bestDist

    for i = 1, #points do
        local ref = M.ResolvePointReference and M.ResolvePointReference(points[i], fallbackEnt or ent) or (fallbackEnt or ent)
        local refMatches = geometry.isWorldTarget(ent)
            and geometry.isWorldTarget(ref)
            or (IsValid(ent) and ref == ent)
        if refMatches then
            local world = cache
                and M.ResolvePointWorldPositionCached(cache, points[i], fallbackEnt or ent)
                or M.ResolvePointWorldPosition(points[i], fallbackEnt or ent)
            if isvector(world) then
                local screen = world:ToScreen()
                if screen.visible then
                    local dist = (screen.x - x) ^ 2 + (screen.y - y) ^ 2
                    if not bestDist or dist < bestDist then
                        best = { index = i, worldPos = world, screen = screen }
                        bestDist = dist
                    end
                end
            end
        end
    end

    if bestDist and bestDist <= 196 then
        return best
    end
end

local function targetPointPressActive(state)
    local press = state and state.press
    if not istable(press) then return false end

    return press.side == "target"
        and (press.kind == "world_point_press"
            or press.kind == "drag_point"
            or (press.kind == "gizmo" and press.pointGizmo == true))
end

local function cornerCandidate(ent, samples, minLength, box, probes)
    if #samples < 2 then return end

    local travelled = 0
    local lastWorldPos = sampleWorldPos(ent, samples[1])
    for i = 2, #samples do
        local worldPos = sampleWorldPos(ent, samples[i])
        if isvector(lastWorldPos) and isvector(worldPos) then
            travelled = travelled + lastWorldPos:Distance(worldPos)
        end
        lastWorldPos = worldPos or lastWorldPos
    end
    if travelled < minLength then return end

    probes = istable(probes) and probes or aggregateTraceProbes(samples)
    if #probes < 2 then return end

    local selected = {}
    for i = 1, math.min(#probes, 3) do
        selected[i] = probes[i]
    end

    if #selected >= 3 then
        local a, b, c = selected[1], selected[2], selected[3]
        local cross23 = b.localNormal:Cross(c.localNormal)
        local denom = a.localNormal:Dot(cross23)

        if math.abs(denom) > M.COMPUTE_EPSILON then
            local localPos = (cross23 * a.planeDistance
                + c.localNormal:Cross(a.localNormal) * b.planeDistance
                + a.localNormal:Cross(b.localNormal) * c.planeDistance) / denom

            if not box or M.PointInsideAABB(localPos, box.mins, box.maxs) then
                local localNormal = normalizedVec(a.localNormal + b.localNormal + c.localNormal) or normalizedVec(a.localNormal)
                local candidate = buildTraceProbeCandidate(ent, localPos, localNormal, "corner", selected)
                if candidate then
                    return candidate
                end
            end
        end
    end

    local a, b = selected[1], selected[2]
    local rawAxis = a.localNormal:Cross(b.localNormal)
    local axisLengthSqr = rawAxis:LengthSqr()
    if axisLengthSqr < M.COMPUTE_VECTOR_EPSILON_SQR then return end

    local axisLocalDir = rawAxis / math.sqrt(axisLengthSqr)
    local axisBase = ((b.localNormal * a.planeDistance - a.localNormal * b.planeDistance):Cross(rawAxis)) / axisLengthSqr
    local totalCount = math.max(a.count + b.count, 1)
    local referencePos = (a.localPos * a.count + b.localPos * b.count) / totalCount
    local localPos = axisBase + axisLocalDir * axisLocalDir:Dot(referencePos - axisBase)

    if box and not M.PointInsideAABB(localPos, box.mins, box.maxs) then
        local midpoint = referencePos
        localPos = axisBase + axisLocalDir * axisLocalDir:Dot(midpoint - axisBase)
        if not M.PointInsideAABB(localPos, box.mins, box.maxs) then
            return
        end
    end

    local localNormal = normalizedVec(a.localNormal + b.localNormal) or normalizedVec(a.localNormal)
    return buildTraceProbeCandidate(ent, localPos, localNormal, "edge", selected, axisLocalDir)
end

local function referenceBasisFor(space, preview, solve, prop2)
    if preview.referenceBasis and preview.referenceBasis[space] then
        return preview.referenceBasis[space]
    elseif space == "world" then
        return ZERO_ANG
    elseif space == "prop2" and geometry.isWorldTarget(prop2) then
        return ZERO_ANG
    elseif space == "prop2" and IsValid(prop2) then
        return copyAng(prop2:GetAngles())
    elseif space == "points" and solve then
        if solve.pointsLocalAng then
            local _, worldAng = LocalToWorldPrecise(ZERO_VEC, solve.pointsLocalAng, ZERO_VEC, preview.ang)
            return worldAng or preview.ang
        end

        return solve.pointsWorldAng or preview.ang
    end

    return preview.ang
end

local function gizmoBasisFor(space, preview, solve, prop2)
    if preview.spaceBasis and preview.spaceBasis[space] then
        return preview.spaceBasis[space]
    end

    return referenceBasisFor(space, preview, solve, prop2)
end

local gizmoShared = client.gizmoShared or {}
client.gizmoShared = gizmoShared

local GIZMO_CONFIG = {
    defaultSize = 32,
    sizeScale = 0.42,
    minSize = 18,
    maxSize = 72,
    planeOffsetScale = 0.2,
    ringRadiusScale = 0.82,
    ringPadding = 0.5,
    pickRadiusMin = 324,
    pickRadiusScale = 0.18
}

function gizmoShared.sizeForProp(ent)
    return math.Clamp(
        IsValid(ent) and ent:BoundingRadius() * GIZMO_CONFIG.sizeScale or GIZMO_CONFIG.defaultSize,
        GIZMO_CONFIG.minSize,
        GIZMO_CONFIG.maxSize
    )
end

function gizmoShared.setVecComponents(out, x, y, z)
    if not isvector(out) then
        return VectorP(x, y, z)
    end

    out.x, out.y, out.z = x, y, z
    return out
end

function gizmoShared.setOffsetVec(out, origin, axis, distance)
    if not isvector(origin) or not isvector(axis) then return end

    distance = tonumber(distance) or 0
    return gizmoShared.setVecComponents(
        out,
        origin.x + axis.x * distance,
        origin.y + axis.y * distance,
        origin.z + axis.z * distance
    )
end

function gizmoShared.setOffsetVec2(out, origin, axisA, distanceA, axisB, distanceB)
    if not isvector(origin) or not isvector(axisA) or not isvector(axisB) then return end

    distanceA = tonumber(distanceA) or 0
    distanceB = tonumber(distanceB) or 0
    return gizmoShared.setVecComponents(
        out,
        origin.x + axisA.x * distanceA + axisB.x * distanceB,
        origin.y + axisA.y * distanceA + axisB.y * distanceB,
        origin.z + axisA.z * distanceA + axisB.z * distanceB
    )
end

function gizmoShared.handle(handles, index, kind, key, color)
    local item = handles[index]
    if not istable(item) then
        item = {}
        handles[index] = item
    end

    item.kind = kind
    item.key = key
    item.color = color
    item.a = nil
    item.b = nil
    item.center = nil
    item.axis = nil
    item.cursorAngle = nil
    return item
end

function gizmoShared.copyHandle(item, out)
    if not istable(item) then return end

    out = out or {}
    out.kind = item.kind
    out.key = item.key
    out.color = item.color
    out.a = isvector(item.a) and copyVec(item.a) or item.a
    out.b = isvector(item.b) and copyVec(item.b) or item.b
    out.center = isvector(item.center) and copyVec(item.center) or item.center
    out.axis = isvector(item.axis) and copyVec(item.axis) or item.axis
    out.axisA = isvector(item.axisA) and copyVec(item.axisA) or item.axisA
    out.axisB = isvector(item.axisB) and copyVec(item.axisB) or item.axisB
    out.cursorAngle = item.cursorAngle

    return out
end

function gizmoShared.metricsForSize(size, out)
    size = tonumber(size) or GIZMO_CONFIG.defaultSize

    out = istable(out) and out or {}
    out.planeOffset = size * GIZMO_CONFIG.planeOffsetScale
    out.ringRadius = size * GIZMO_CONFIG.ringRadiusScale
    out.ringPadding = GIZMO_CONFIG.ringPadding
    out.pickRadius = math.max(GIZMO_CONFIG.pickRadiusMin, size * size * GIZMO_CONFIG.pickRadiusScale)
    return out
end

function gizmoShared.linearHandles(origin, basis, size, reuse)
    reuse = istable(reuse) and reuse or nil
    local basisForward, basisRight, basisUp
    if reuse and M.AngleAxesPreciseInto then
        reuse.axes = reuse.axes or {}
        basisForward, basisRight, basisUp = M.AngleAxesPreciseInto(reuse.axes, basis)
    else
        basisForward, basisRight, basisUp = M.AngleAxesPrecise(basis)
    end
    local handles = istable(reuse) and reuse.handles or {}
    local metrics = gizmoShared.metricsForSize(size, istable(reuse) and reuse.metrics or nil)
    if istable(reuse) then
        reuse.handles = handles
        reuse.metrics = metrics
        reuse.basisForward = basisForward
        reuse.basisRight = basisRight
        reuse.basisUp = basisUp
    end

    local handle = gizmoShared.handle(handles, 1, "move", "x", colors.x)
    handle.a = origin
    handle.axis = basisForward
    handle.b = gizmoShared.setOffsetVec(handle.b, origin, basisForward, size)

    handle = gizmoShared.handle(handles, 2, "move", "y", colors.y)
    handle.a = origin
    handle.axis = basisRight
    handle.b = gizmoShared.setOffsetVec(handle.b, origin, basisRight, size)

    handle = gizmoShared.handle(handles, 3, "move", "z", colors.z)
    handle.a = origin
    handle.axis = basisUp
    handle.b = gizmoShared.setOffsetVec(handle.b, origin, basisUp, size)

    handle = gizmoShared.handle(handles, 4, "plane", "xy", colors.xy)
    handle.axisA = basisForward
    handle.axisB = basisRight
    handle.center = gizmoShared.setOffsetVec2(handle.center, origin, basisForward, metrics.planeOffset, basisRight, metrics.planeOffset)

    handle = gizmoShared.handle(handles, 5, "plane", "xz", colors.xz)
    handle.axisA = basisForward
    handle.axisB = basisUp
    handle.center = gizmoShared.setOffsetVec2(handle.center, origin, basisForward, metrics.planeOffset, basisUp, metrics.planeOffset)

    handle = gizmoShared.handle(handles, 6, "plane", "yz", colors.yz)
    handle.axisA = basisRight
    handle.axisB = basisUp
    handle.center = gizmoShared.setOffsetVec2(handle.center, origin, basisRight, metrics.planeOffset, basisUp, metrics.planeOffset)

    for i = 7, #handles do
        handles[i] = nil
    end

    return handles, basisForward, basisRight, basisUp, metrics
end

function gizmoShared.pickHoveredHandle(handles, pickRadius, ringRadius, ringPadding, origin, basis, eye, dir)
    local x, y = ScrW() * 0.5, ScrH() * 0.5
    local best, bestDist
    pickRadius = tonumber(pickRadius) or 0

    for i = 1, #handles do
        local item = handles[i]

        if item.kind == "move" and isvector(item.b) then
            local screen = item.b:ToScreen()
            if screen.visible then
                local dist = (x - screen.x) ^ 2 + (y - screen.y) ^ 2
                if dist < pickRadius and (not bestDist or dist < bestDist) then
                    best = item
                    bestDist = dist
                end
            end
        elseif item.kind == "plane" and isvector(item.center) then
            local screen = item.center:ToScreen()
            if screen.visible then
                local dist = (x - screen.x) ^ 2 + (y - screen.y) ^ 2
                if dist < pickRadius and (not bestDist or dist < bestDist) then
                    best = item
                    bestDist = dist
                end
            end
        elseif item.kind == "rot" and isvector(eye) and isvector(dir) then
            local scratch = gizmoShared._linePlaneScratch or {}
            gizmoShared._linePlaneScratch = scratch
            local worldPos, localPos
            if M.LinePlaneIntersectionInto then
                worldPos, localPos = M.LinePlaneIntersectionInto(scratch.world, scratch.localPos, dir, eye, item.axis, origin, basis)
                scratch.world, scratch.localPos = worldPos, localPos
            else
                worldPos, localPos = M.LinePlaneIntersection(dir, eye, item.axis, origin, basis)
            end
            if localPos then
                local u, v = ringCoords(item.key, localPos)
                item.cursorAngle = math.deg(ringAngle(item.key, localPos))
                local dist = math.abs(math.sqrt(u * u + v * v) - ringRadius)
                if dist <= ringPadding then
                    if dist < pickRadius and (not bestDist or dist < bestDist) then
                        best = item
                        bestDist = dist
                    end
                end
            end
        end
    end

    return best
end

function gizmoShared.linearDragNormal(origin, basis, item, eye)
    if not isvector(origin) or not isangle(basis) or not istable(item) or not isvector(eye) then return end

    if item.kind == "move" then
        local basisForward, basisRight, basisUp
        if not isvector(item.axis) then
            basisForward, basisRight, basisUp = M.AngleAxesPrecise(basis)
        end
        local axis = item.axis or (item.key == "x" and basisForward or item.key == "y" and basisRight or basisUp)
        local toEye = normalizedVec(M.SubtractVectorsPrecise(eye, origin))
        local normal = toEye and M.CrossVectorsPrecise(M.CrossVectorsPrecise(axis, toEye), axis) or nil
        if not normal or M.VectorLengthSqrPrecise(normal) < M.PICKING_VECTOR_EPSILON_SQR then
            normal = M.CrossVectorsPrecise(M.CrossVectorsPrecise(axis, VectorP(0, 0, 1)), axis)
        end

        return normalizedVec(normal)
    elseif item.kind == "plane" then
        local basisForward, basisRight, basisUp
        if not isvector(item.axisA) or not isvector(item.axisB) then
            basisForward, basisRight, basisUp = M.AngleAxesPrecise(basis)
        end
        local axisA = item.axisA or (item.key == "xy" and basisForward or item.key == "xz" and basisForward or basisRight)
        local axisB = item.axisB or (item.key == "xy" and basisRight or item.key == "xz" and basisUp or basisUp)
        local normal = M.CrossVectorsPrecise(axisA, axisB)
        if M.DotVectorsPrecise(normal, M.SubtractVectorsPrecise(eye, origin)) < 0 then
            normal = -normal
        end

        return normalizedVec(normal)
    end
end

function gizmoShared.translationLocalPos(item, dragStartLocal, localPos, out)
    if not istable(item) or not isvector(localPos) then return end

    dragStartLocal = dragStartLocal or ZERO_VEC
    local currentGizmoPos = setVec(out, dragStartLocal)

    if item.kind == "move" then
        if item.key == "x" then
            currentGizmoPos.x = localPos.x
        elseif item.key == "y" then
            currentGizmoPos.y = localPos.y
        else
            currentGizmoPos.z = localPos.z
        end
    elseif item.kind == "plane" then
        local first = item.key:sub(1, 1)
        local second = item.key:sub(2, 2)

        if first == "x" or second == "x" then
            currentGizmoPos.x = localPos.x
        end
        if first == "y" or second == "y" then
            currentGizmoPos.y = localPos.y
        end
        if first == "z" or second == "z" then
            currentGizmoPos.z = localPos.z
        end
    else
        return
    end

    return currentGizmoPos
end

local function gizmo(tool, state)
    local worldPoints = client.WorldPoints
    if worldPoints and isfunction(worldPoints.getGizmo) then
        local worldPointGizmo = worldPoints.getGizmo(tool, state)
        if worldPointGizmo then
            return worldPointGizmo
        end
    end
    if worldPoints and isfunction(worldPoints.shouldSuppressDefaultGizmo) and worldPoints.shouldSuppressDefaultGizmo(state) then
        return
    end

    local preview = state.preview
    if not preview or not preview.solve then return end

    local space = tool:GetClientInfo("space")
    if M.IsMirrorMode and M.IsMirrorMode(space) then return end
    local press = state.press
    local origin = LocalToWorldPosPrecise(preview.solve.sourceAnchorLocal, preview.pos, preview.ang)
    local basis = gizmoBasisFor(space, preview, preview.solve, state.prop2)
    local referenceBasis = referenceBasisFor(space, preview, preview.solve, state.prop2)
    local size = gizmoShared.sizeForProp(state.prop1)
    local eye = LocalPlayer():GetShootPos()
    local dir = LocalPlayer():GetAimVector()

    if press and press.kind == "gizmo" and press.space == space and press.gizmo and press.gizmo.kind == "rot" then
        origin = press.origin
        basis = press.basis
        referenceBasis = press.referenceBasis
    end

    local scratch = state._magicAlignGizmoScratch or {}
    state._magicAlignGizmoScratch = scratch
    local handles, basisForward, basisRight, basisUp, metrics = gizmoShared.linearHandles(origin, basis, size, scratch)
    local handle = gizmoShared.handle(handles, 7, "rot", "roll", colors.x)
    handle.axis = basisForward
    handle = gizmoShared.handle(handles, 8, "rot", "pitch", colors.y)
    handle.axis = basisRight
    handle = gizmoShared.handle(handles, 9, "rot", "yaw", colors.z)
    handle.axis = basisUp

    local best = gizmoShared.pickHoveredHandle(
        handles,
        metrics.pickRadius,
        metrics.ringRadius,
        metrics.ringPadding,
        origin,
        basis,
        eye,
        dir
    )

    local out = scratch.result
    if not istable(out) then
        out = {}
        scratch.result = out
    end

    out.origin = origin
    out.basis = basis
    out.referenceBasis = referenceBasis
    out.size = size
    out.planeOffset = metrics.planeOffset
    out.ringRadius = metrics.ringRadius
    out.ringPadding = metrics.ringPadding
    out.hover = press and press.kind == "gizmo" and press.space == space and press.gizmo or best
    out.space = space
    out.handles = handles
    out.basisForward = basisForward
    out.basisRight = basisRight
    out.basisUp = basisUp
    out.disableRotation = nil
    out.pointGizmo = nil
    out.pointGizmoKind = nil
    out.pointGizmoIndex = nil
    out.pointGizmoReference = nil
    out.worldPoint = nil
    out.worldPointIndex = nil

    return out
end

core.hoverPoint = hoverPoint
core.targetPointPressActive = targetPointPressActive
core.cornerCandidate = cornerCandidate
core.referenceBasisFor = referenceBasisFor
core.gizmoBasisFor = gizmoBasisFor
core.gizmo = gizmo

return core
