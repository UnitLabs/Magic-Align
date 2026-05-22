MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local worldBSP = client.WorldBSP or {}
client.WorldBSP = worldBSP

worldBSP.STATUS = worldBSP.STATUS or {}
worldBSP.STATUS.IDLE = worldBSP.STATUS.IDLE or "idle"
worldBSP.STATUS.BUILDING = worldBSP.STATUS.BUILDING or "building"
worldBSP.STATUS.READY = worldBSP.STATUS.READY or "ready"
worldBSP.STATUS.UNAVAILABLE = worldBSP.STATUS.UNAVAILABLE or "unavailable"
worldBSP.STATUS.ERROR = worldBSP.STATUS.ERROR or "error"

local VectorP = M.VectorP
local isvector = M.IsVectorLike
local copyVec = M.CopyVectorPrecise
local normalizedVec = M.NormalizeVectorPrecise
local dot = M.DotVectorsPrecise
local cross = M.CrossVectorsPrecise

local CACHE_VERSION = 7

local WORLD_AXIS_KEYS = { "x", "y", "z" }
local WORLD_GRID = {
    defaultStep = 16,
    minStep = 0.125,
    maxStep = 512,
    familyEpsilonSqr = 1e-10,
    pairDetEpsilon = 1e-8,
    verticalNormalZMax = 0.35,
    horizontalNormalZMin = 0.85
}

local CONFIG = {
    cellSize = 512,
    maxIndexedCellsPerSurface = 192,
    normalDotMin = 0.985,
    planeTolerance = 1.25,
    boundsTolerance = 2,
    surfacePickTolerance = 0.15,
    edgePickTolerance = 0.35,
    polygonPickTolerance = 0.02,
    polygonTolerance = 0.001,
    rayPickTolerance = 2.5,
    rayPlaneDotMin = 0.0001,
    rayPreferScore = 0.4,
    rayNormalWeight = 1.5,
    queryCellRadius = 1,
    vertexMergeToleranceSqr = 1e-8,
    hullTolerance = 0.001,
    edgeCellSize = 128,
    edgeParallelDotMin = 0.999,
    edgeCollinearTolerance = 0.15,
    edgeOverlapTolerance = 0.05,
    sameSurfaceFastPathEdgeTolerance = 1,
    planeBucketNormalStep = 0.1,
    planeBucketNormalRadius = 1,
    planeBucketDistanceStep = 4,
    planeBucketDistanceRadius = 1,
    planeBucketMinSurfaceCandidates = 10,
    hintAfterSeconds = 5,
    defaultBudgetMs = 2.5,
    minBudgetMs = 0.1,
    maxBudgetMs = 8
}

local cache = worldBSP.cache or {}
worldBSP.cache = cache
cache.STATUS = worldBSP.STATUS

local snapScratch = worldBSP.snapScratch or {}
worldBSP.snapScratch = snapScratch

local traceScratch = worldBSP.traceScratch or {}
worldBSP.traceScratch = traceScratch

local function now()
    return SysTime and SysTime() or RealTime()
end

local function currentMap()
    return game and game.GetMap and game.GetMap() or ""
end

local function resetCache(status)
    for key in pairs(snapScratch) do
        snapScratch[key] = nil
    end
    for key in pairs(traceScratch) do
        traceScratch[key] = nil
    end

    cache.version = CACHE_VERSION
    cache.map = currentMap()
    cache.status = status or cache.STATUS.IDLE
    cache.surfaces = {}
    cache.index = {}
    cache.planeBuckets = {}
    cache.edgeIndex = {}
    cache.largeSurfaces = {}
    cache.total = 0
    cache.cached = 0
    cache.skipped = 0
    cache.startedAt = nil
    cache.readyAt = nil
    cache.worker = nil
    cache.hintedSlow = false
    cache.error = nil
    worldBSP.lastTraceSurface = nil
end

if cache.status == nil or cache.version ~= CACHE_VERSION then
    resetCache(cache.STATUS.IDLE)
end

local function readBudgetMs(settings)
    local value = tonumber(settings and settings.worldBspBudgetMs) or CONFIG.defaultBudgetMs
    return math.Clamp(value, CONFIG.minBudgetMs, CONFIG.maxBudgetMs)
end

local function shouldYield()
    local started = tonumber(cache.frameStartedAt) or now()
    local budget = math.max((tonumber(cache.frameBudgetMs) or CONFIG.defaultBudgetMs) * 0.001, 0.0001)

    return now() - started >= budget
end

local function maybeYield()
    if shouldYield() then
        coroutine.yield()
    end
end

local function safeSurfaceBool(surfaceInfo, methodName)
    local method = surfaceInfo and surfaceInfo[methodName]
    return isfunction(method) and method(surfaceInfo) == true
end

local function visibleSurface(surfaceInfo)
    return not safeSurfaceBool(surfaceInfo, "IsNoDraw")
        and not safeSurfaceBool(surfaceInfo, "IsSky")
        and not safeSurfaceBool(surfaceInfo, "IsWater")
end

local function copyVertices(vertices)
    if not istable(vertices) then return end

    local out = {}
    local count = 0
    for i = 1, #vertices do
        local vertex = vertices[i]
        if isvector(vertex) then
            local copied = VectorP(vertex.x, vertex.y, vertex.z)
            local duplicate = false
            for j = 1, count do
                if M.VectorLengthSqrPrecise(copied - out[j]) <= CONFIG.vertexMergeToleranceSqr then
                    duplicate = true
                    break
                end
            end

            if not duplicate then
                count = count + 1
                out[count] = copied
            end
        end
    end

    if count < 3 then return end
    return out
end

local function computeNormal(vertices)
    local base = vertices[1]
    if not isvector(base) then return end

    for i = 2, #vertices - 1 do
        local a = vertices[i] - base
        for j = i + 1, #vertices do
            local b = vertices[j] - base
            local normal = normalizedVec(cross(a, b), M.PICKING_VECTOR_EPSILON_SQR)
            if normal then
                return normal
            end
        end
    end
end

local function projectedAxisFromVertices(vertices, normal)
    local base = vertices[1]
    for i = 2, #vertices do
        local axis = M.ProjectVectorPrecise(vertices[i] - base, normal, M.PICKING_VECTOR_EPSILON_SQR)
        if axis then return axis end
    end

    return M.ProjectVectorPrecise(VectorP(0, 0, 1), normal, M.PICKING_VECTOR_EPSILON_SQR)
        or M.ProjectVectorPrecise(VectorP(0, 1, 0), normal, M.PICKING_VECTOR_EPSILON_SQR)
        or M.ProjectVectorPrecise(VectorP(1, 0, 0), normal, M.PICKING_VECTOR_EPSILON_SQR)
end

local function hullCross2D(a, b, c)
    return (b.u - a.u) * (c.v - a.v) - (b.v - a.v) * (c.u - a.u)
end

local function hullEntryLess(a, b)
    if math.abs(a.u - b.u) <= CONFIG.polygonTolerance then
        return a.v < b.v
    end

    return a.u < b.u
end

local function polygonArea2D(entries)
    local area = 0
    local previous = entries[#entries]
    for i = 1, #entries do
        local current = entries[i]
        area = area + (previous.u * current.v - current.u * previous.v)
        previous = current
    end

    return area * 0.5
end

local function orderSurfaceVertices(vertices, normal)
    local uAxis = projectedAxisFromVertices(vertices, normal)
    if not uAxis then return end

    local vAxis = normalizedVec(cross(normal, uAxis), M.PICKING_VECTOR_EPSILON_SQR)
    if not vAxis then return end

    local entries = {}
    for i = 1, #vertices do
        local vertex = vertices[i]
        entries[i] = {
            vertex = vertex,
            u = dot(vertex, uAxis),
            v = dot(vertex, vAxis)
        }
    end

    table.sort(entries, hullEntryLess)

    local hull = {}
    local hullCount = 0
    local function pushHull(entry)
        while hullCount >= 2
            and hullCross2D(hull[hullCount - 1], hull[hullCount], entry) <= CONFIG.hullTolerance do
            hull[hullCount] = nil
            hullCount = hullCount - 1
        end

        hullCount = hullCount + 1
        hull[hullCount] = entry
    end

    for i = 1, #entries do
        pushHull(entries[i])
    end

    local lowerCount = hullCount
    for i = #entries - 1, 1, -1 do
        while hullCount > lowerCount
            and hullCross2D(hull[hullCount - 1], hull[hullCount], entries[i]) <= CONFIG.hullTolerance do
            hull[hullCount] = nil
            hullCount = hullCount - 1
        end

        hullCount = hullCount + 1
        hull[hullCount] = entries[i]
    end

    if hullCount > 1 then
        hull[hullCount] = nil
        hullCount = hullCount - 1
    end

    if hullCount < 3 then return end

    if polygonArea2D(hull) < 0 then
        local left, right = 1, hullCount
        while left < right do
            hull[left], hull[right] = hull[right], hull[left]
            left = left + 1
            right = right - 1
        end
    end

    local ordered = {}
    for i = 1, hullCount do
        ordered[i] = hull[i].vertex
    end

    return ordered
end

local function longestEdgeAxis(vertices, normal)
    local bestDir
    local bestLenSqr = 0

    for i = 1, #vertices do
        local a = vertices[i]
        local b = vertices[i % #vertices + 1]
        local edge = b - a
        local lenSqr = M.VectorLengthSqrPrecise(edge)
        if lenSqr > bestLenSqr then
            bestLenSqr = lenSqr
            bestDir = edge
        end
    end

    if not bestDir or bestLenSqr <= M.PICKING_VECTOR_EPSILON_SQR then return end

    local projected = bestDir - normal * dot(bestDir, normal)
    return normalizedVec(projected, M.PICKING_VECTOR_EPSILON_SQR)
end

local function expandBounds(mins, maxs, point)
    if not mins then
        return VectorP(point), VectorP(point)
    end

    mins.x = math.min(mins.x, point.x)
    mins.y = math.min(mins.y, point.y)
    mins.z = math.min(mins.z, point.z)
    maxs.x = math.max(maxs.x, point.x)
    maxs.y = math.max(maxs.y, point.y)
    maxs.z = math.max(maxs.z, point.z)

    return mins, maxs
end

local function surfaceUv(surfaceData, worldPos)
    local delta = worldPos - surfaceData.origin
    return dot(delta, surfaceData.uAxis), dot(delta, surfaceData.vAxis)
end

local function surfaceUvFromComponents(surfaceData, x, y, z)
    local origin = surfaceData.origin
    local uAxis = surfaceData.uAxis
    local vAxis = surfaceData.vAxis
    local dx = x - origin.x
    local dy = y - origin.y
    local dz = z - origin.z

    return dx * uAxis.x + dy * uAxis.y + dz * uAxis.z,
        dx * vAxis.x + dy * vAxis.y + dz * vAxis.z
end

local function worldFromUv(surfaceData, u, v)
    return surfaceData.origin + surfaceData.uAxis * u + surfaceData.vAxis * v
end

local function axisComponent(value, axisKey)
    if not isvector(value) then return 0 end
    if axisKey == "x" then return value.x end
    if axisKey == "y" then return value.y end
    return value.z
end

local function clampWorldGridStep(step)
    return math.Clamp(tonumber(step) or WORLD_GRID.defaultStep, WORLD_GRID.minStep, WORLD_GRID.maxStep)
end

local function worldGridStep(settings)
    return clampWorldGridStep(settings and settings.worldBspGridSize)
end

local function usesGlobalGrid(settings)
    local mode = string.lower(tostring(settings and settings.worldBspGridMode or "global"))
    return mode == "global" or mode == "global_units"
end

local function buildGlobalFamilies(surfaceData)
    local families = {}

    for i = 1, #WORLD_AXIS_KEYS do
        local axisKey = WORLD_AXIS_KEYS[i]
        local uCoeff = axisComponent(surfaceData.uAxis, axisKey)
        local vCoeff = axisComponent(surfaceData.vAxis, axisKey)
        local lenSqr = uCoeff * uCoeff + vCoeff * vCoeff

        if lenSqr > WORLD_GRID.familyEpsilonSqr then
            families[axisKey] = {
                axis = axisKey,
                uCoeff = uCoeff,
                vCoeff = vCoeff,
                origin = axisComponent(surfaceData.origin, axisKey),
                weight = math.sqrt(lenSqr)
            }
        end
    end

    return families
end

local function familyPairDet(a, b)
    if not a or not b then return 0 end
    return a.uCoeff * b.vCoeff - b.uCoeff * a.vCoeff
end

local function familiesAreIndependent(a, b)
    return math.abs(familyPairDet(a, b)) > WORLD_GRID.pairDetEpsilon
end

local function addGlobalProjectionPair(out, seen, familyU, familyV, lineMode)
    if not familyU or not familyV or not familiesAreIndependent(familyU, familyV) then return end

    local key = familyU.axis .. ":" .. familyV.axis .. ":" .. tostring(lineMode or "full")
    if seen[key] then return end
    seen[key] = true

    out[#out + 1] = {
        axisU = familyU.axis,
        axisV = familyV.axis,
        lineMode = lineMode or "full"
    }
end

local function sortedHorizontalFamilies(families)
    local out = {}
    if families.x then out[#out + 1] = families.x end
    if families.y then out[#out + 1] = families.y end

    table.sort(out, function(a, b)
        return (a.weight or 0) > (b.weight or 0)
    end)

    return out
end

local function globalProjectionPairs(surfaceData)
    if surfaceData.globalProjectionPairs then
        return surfaceData.globalProjectionPairs
    end

    local families = surfaceData.globalFamilies or buildGlobalFamilies(surfaceData)
    surfaceData.globalFamilies = families

    local out = {}
    local seen = {}
    local normalZ = math.abs(axisComponent(surfaceData.normal, "z"))
    local zFamily = families.z

    if normalZ <= WORLD_GRID.verticalNormalZMax and zFamily then
        local horizontal = sortedHorizontalFamilies(families)
        for i = 1, #horizontal do
            addGlobalProjectionPair(out, seen, horizontal[i], zFamily, i == 1 and "full" or "u")
        end
    elseif normalZ >= WORLD_GRID.horizontalNormalZMin and families.x and families.y then
        addGlobalProjectionPair(out, seen, families.x, families.y, "full")
    end

    if #out == 0 then
        local bestA, bestB, bestScore
        for i = 1, #WORLD_AXIS_KEYS - 1 do
            local a = families[WORLD_AXIS_KEYS[i]]
            for j = i + 1, #WORLD_AXIS_KEYS do
                local b = families[WORLD_AXIS_KEYS[j]]
                if familiesAreIndependent(a, b) then
                    local score = (a.weight or 0) + (b.weight or 0)
                    if not bestScore or score > bestScore then
                        bestA, bestB, bestScore = a, b, score
                    end
                end
            end
        end

        addGlobalProjectionPair(out, seen, bestA, bestB, "full")
    end

    surfaceData.globalProjectionPairs = out
    return out
end

local function globalSnapPairs(surfaceData)
    if surfaceData.globalSnapPairs then
        return surfaceData.globalSnapPairs
    end

    local families = surfaceData.globalFamilies or buildGlobalFamilies(surfaceData)
    surfaceData.globalFamilies = families

    local pairs = {}
    for i = 1, #WORLD_AXIS_KEYS - 1 do
        local a = families[WORLD_AXIS_KEYS[i]]
        for j = i + 1, #WORLD_AXIS_KEYS do
            local b = families[WORLD_AXIS_KEYS[j]]
            if familiesAreIndependent(a, b) then
                pairs[#pairs + 1] = {
                    familyU = a,
                    familyV = b,
                    axisU = a.axis,
                    axisV = b.axis,
                    det = familyPairDet(a, b)
                }
            end
        end
    end

    table.sort(pairs, function(a, b)
        local aVertical = (a.axisU == "z" or a.axisV == "z") and 1 or 0
        local bVertical = (b.axisU == "z" or b.axisV == "z") and 1 or 0
        if aVertical ~= bVertical then
            return aVertical > bVertical
        end

        local aWeight = (a.familyU.weight or 0) + (a.familyV.weight or 0)
        local bWeight = (b.familyU.weight or 0) + (b.familyV.weight or 0)
        return aWeight > bWeight
    end)

    surfaceData.globalSnapPairs = pairs
    return pairs
end

local function pointOnSegment2D(px, py, a, b, eps)
    local abx, aby = b.u - a.u, b.v - a.v
    local apx, apy = px - a.u, py - a.v
    local lenSqr = abx * abx + aby * aby
    if lenSqr <= M.COMPUTE_EPSILON then
        local dx, dy = px - a.u, py - a.v
        return dx * dx + dy * dy <= eps * eps
    end

    local crossValue = abx * apy - aby * apx
    if crossValue * crossValue > eps * eps * lenSqr then return false end

    local dotValue = apx * abx + apy * aby
    local len = math.sqrt(lenSqr)
    if dotValue < -eps * len then return false end

    return dotValue <= lenSqr + eps * len
end

local function pointInPolygon2D(polygon, u, v, eps)
    eps = eps or CONFIG.polygonTolerance
    if not istable(polygon) or #polygon < 3 then return false end

    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local a = polygon[i]
        local b = polygon[j]

        if pointOnSegment2D(u, v, a, b, eps) then
            return true
        end

        local intersects = ((a.v > v) ~= (b.v > v))
            and (u < (b.u - a.u) * (v - a.v) / ((b.v - a.v) ~= 0 and (b.v - a.v) or 1e-12) + a.u)
        if intersects then
            inside = not inside
        end

        j = i
    end

    return inside
end

local function closestPointOnSegment2D(px, py, a, b)
    local abx, aby = b.u - a.u, b.v - a.v
    local lenSqr = abx * abx + aby * aby
    if lenSqr <= M.COMPUTE_EPSILON then
        local dx, dy = px - a.u, py - a.v
        return a.u, a.v, 0, dx * dx + dy * dy
    end

    local t = ((px - a.u) * abx + (py - a.v) * aby) / lenSqr
    t = math.Clamp(t, 0, 1)

    local u = a.u + abx * t
    local v = a.v + aby * t
    local dx, dy = px - u, py - v
    return u, v, t, dx * dx + dy * dy
end

local function polygonEdgeDistance(polygon, u, v)
    if not istable(polygon) or #polygon < 2 then return math.huge end

    local best
    local previous = polygon[#polygon]
    for i = 1, #polygon do
        local current = polygon[i]
        local _, _, _, distSqr = closestPointOnSegment2D(u, v, previous, current)
        if not best or distSqr < best then
            best = distSqr
        end

        previous = current
    end

    return math.sqrt(best or math.huge)
end

local function buildSurfaceEdges(vertices)
    local edges = {}
    if not istable(vertices) or #vertices < 2 then return edges end

    for i = 1, #vertices do
        local a = vertices[i]
        local b = vertices[i % #vertices + 1]
        if isvector(a) and isvector(b) then
            local delta = b - a
            local lenSqr = M.VectorLengthSqrPrecise(delta)
            if lenSqr > M.PICKING_VECTOR_EPSILON_SQR then
                local len = math.sqrt(lenSqr)
                local dir = delta / len
                local mins, maxs = expandBounds(nil, nil, a)
                mins, maxs = expandBounds(mins, maxs, b)

                local edgeIndex = #edges + 1
                edges[edgeIndex] = {
                    index = edgeIndex,
                    a = a,
                    b = b,
                    dir = dir,
                    length = len,
                    mins = mins,
                    maxs = maxs
                }
            end
        end
    end

    return edges
end

local function addLineIntersection(values, value, eps)
    for i = 1, #values do
        if math.abs(values[i] - value) <= eps then
            return
        end
    end

    values[#values + 1] = value
end

local function clippedLineRange(face, axisKey, value)
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 3 then return end

    local values = {}
    local eps = CONFIG.polygonTolerance
    local key = axisKey == "u" and "u" or "v"
    local other = axisKey == "u" and "v" or "u"
    local previous = polygon[#polygon]

    for i = 1, #polygon do
        local current = polygon[i]
        local a = previous[key]
        local b = current[key]
        local oa = previous[other]
        local ob = current[other]

        if math.abs(a - value) <= eps and math.abs(b - value) <= eps then
            addLineIntersection(values, oa, eps)
            addLineIntersection(values, ob, eps)
        elseif math.abs(a - b) > eps and value >= math.min(a, b) - eps and value <= math.max(a, b) + eps then
            local t = (value - a) / (b - a)
            if t >= -eps and t <= 1 + eps then
                addLineIntersection(values, oa + (ob - oa) * math.Clamp(t, 0, 1), eps)
            end
        elseif math.abs(a - value) <= eps then
            addLineIntersection(values, oa, eps)
        elseif math.abs(b - value) <= eps then
            addLineIntersection(values, ob, eps)
        end

        previous = current
    end

    if #values < 2 then return end

    table.sort(values)
    return values[1], values[#values]
end

function worldBSP.faceLineWorldPoints(face, _, axisKey, value)
    local surfaceData = face and face.surface
    if not surfaceData then return end

    local minOther, maxOther = clippedLineRange(face, axisKey, value)
    if not minOther or not maxOther then return end

    if axisKey == "u" then
        return worldFromUv(surfaceData, value, minOther), worldFromUv(surfaceData, value, maxOther)
    end

    return worldFromUv(surfaceData, minOther, value), worldFromUv(surfaceData, maxOther, value)
end

local function buildSurfaceData(surfaceInfo, index)
    if not visibleSurface(surfaceInfo) then
        return nil, "hidden"
    end

    local getVertices = surfaceInfo and surfaceInfo.GetVertices
    if not isfunction(getVertices) then
        return nil, "vertices"
    end

    local vertices = copyVertices(getVertices(surfaceInfo))
    if not vertices then
        return nil, "vertices"
    end

    local normal = computeNormal(vertices)
    if not normal then
        return nil, "normal"
    end

    vertices = orderSurfaceVertices(vertices, normal)
    if not vertices then
        return nil, "order"
    end

    local orderedNormal = computeNormal(vertices)
    if orderedNormal then
        if dot(orderedNormal, normal) < 0 then
            local left, right = 1, #vertices
            while left < right do
                vertices[left], vertices[right] = vertices[right], vertices[left]
                left = left + 1
                right = right - 1
            end

            normal = -orderedNormal
        else
            normal = orderedNormal
        end
    end

    local uAxis = longestEdgeAxis(vertices, normal)
    if not uAxis then
        return nil, "edge"
    end

    local vAxis = normalizedVec(cross(normal, uAxis), M.PICKING_VECTOR_EPSILON_SQR)
    if not vAxis then
        return nil, "basis"
    end

    local origin = copyVec(vertices[1])
    local polygon = {}
    local uMin, uMax, vMin, vMax
    local worldMins, worldMaxs
    local center = VectorP(0, 0, 0)

    for i = 1, #vertices do
        local vertex = vertices[i]
        local u, v = surfaceUv({ origin = origin, uAxis = uAxis, vAxis = vAxis }, vertex)
        polygon[i] = { u = u, v = v }
        uMin = uMin and math.min(uMin, u) or u
        uMax = uMax and math.max(uMax, u) or u
        vMin = vMin and math.min(vMin, v) or v
        vMax = vMax and math.max(vMax, v) or v
        worldMins, worldMaxs = expandBounds(worldMins, worldMaxs, vertex)
        center = center + vertex
    end

    if not uMin or not uMax or not vMin or not vMax then
        return nil, "bounds"
    end

    if uMax - uMin <= M.PICKING_EPSILON or vMax - vMin <= M.PICKING_EPSILON then
        return nil, "thin"
    end

    local surfaceData = {
        id = index,
        vertices = vertices,
        edges = buildSurfaceEdges(vertices),
        polygon = polygon,
        origin = origin,
        normal = normal,
        planeDistance = dot(normal, origin),
        uAxis = uAxis,
        vAxis = vAxis,
        uMin = uMin,
        uMax = uMax,
        vMin = vMin,
        vMax = vMax,
        worldMins = worldMins,
        worldMaxs = worldMaxs,
        center = center / #vertices
    }

    surfaceData.globalFamilies = buildGlobalFamilies(surfaceData)

    for i = 1, #(surfaceData.edges or {}) do
        surfaceData.edges[i].surface = surfaceData
    end

    return surfaceData
end

local function cellCoord(value)
    return math.floor(value / CONFIG.cellSize)
end

local function cellKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function addToCell(index, key, surfaceData)
    local cell = index[key]
    if not cell then
        cell = {}
        index[key] = cell
    end

    cell[#cell + 1] = surfaceData
end

local function planeNormalCoord(value)
    return math.floor((tonumber(value) or 0) / CONFIG.planeBucketNormalStep + 0.5)
end

local function planeDistanceCoord(value)
    return math.floor((tonumber(value) or 0) / CONFIG.planeBucketDistanceStep + 0.5)
end

local function planeBucketKey(nx, ny, nz, distance)
    return tostring(nx) .. ":" .. tostring(ny) .. ":" .. tostring(nz) .. ":" .. tostring(distance)
end

local function addToPlaneBucket(key, surfaceData)
    if not istable(cache.planeBuckets) then
        cache.planeBuckets = {}
    end

    local bucket = cache.planeBuckets and cache.planeBuckets[key] or nil
    if not bucket then
        bucket = {}
        cache.planeBuckets[key] = bucket
    end

    bucket[#bucket + 1] = surfaceData
end

local function indexSurfacePlane(surfaceData)
    local normal = surfaceData and surfaceData.normal
    if not isvector(normal) then return end

    addToPlaneBucket(planeBucketKey(
        planeNormalCoord(normal.x),
        planeNormalCoord(normal.y),
        planeNormalCoord(normal.z),
        planeDistanceCoord(surfaceData.planeDistance)
    ), surfaceData)
end

local function indexSurface(surfaceData)
    local mins = surfaceData.worldMins
    local maxs = surfaceData.worldMaxs
    if not isvector(mins) or not isvector(maxs) then return end

    local minX = cellCoord(mins.x - CONFIG.boundsTolerance)
    local minY = cellCoord(mins.y - CONFIG.boundsTolerance)
    local minZ = cellCoord(mins.z - CONFIG.boundsTolerance)
    local maxX = cellCoord(maxs.x + CONFIG.boundsTolerance)
    local maxY = cellCoord(maxs.y + CONFIG.boundsTolerance)
    local maxZ = cellCoord(maxs.z + CONFIG.boundsTolerance)
    local cellCount = (maxX - minX + 1) * (maxY - minY + 1) * (maxZ - minZ + 1)

    if cellCount > CONFIG.maxIndexedCellsPerSurface then
        cache.largeSurfaces[#cache.largeSurfaces + 1] = surfaceData
        return
    end

    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                addToCell(cache.index, cellKey(x, y, z), surfaceData)
            end
        end
    end
end

local function edgeCellCoord(value)
    return math.floor(value / CONFIG.edgeCellSize)
end

local function edgeCellKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function addEdgeToCell(key, edge)
    local cell = cache.edgeIndex[key]
    if not cell then
        cell = {}
        cache.edgeIndex[key] = cell
    end

    cell[#cell + 1] = edge
end

local function edgeCellBounds(edge)
    local tol = CONFIG.edgeCollinearTolerance
    return edgeCellCoord(edge.mins.x - tol),
        edgeCellCoord(edge.mins.y - tol),
        edgeCellCoord(edge.mins.z - tol),
        edgeCellCoord(edge.maxs.x + tol),
        edgeCellCoord(edge.maxs.y + tol),
        edgeCellCoord(edge.maxs.z + tol)
end

local function indexSurfaceEdges(surfaceData)
    for i = 1, #(surfaceData.edges or {}) do
        local edge = surfaceData.edges[i]
        local minX, minY, minZ, maxX, maxY, maxZ = edgeCellBounds(edge)
        for x = minX, maxX do
            for y = minY, maxY do
                for z = minZ, maxZ do
                    addEdgeToCell(edgeCellKey(x, y, z), edge)
                end
            end
        end
    end
end

local function addSurfaceNeighbor(surfaceData, neighbor)
    if not surfaceData or not neighbor or surfaceData == neighbor then return end

    local seen = surfaceData.neighborSeen
    if not seen then
        seen = {}
        surfaceData.neighborSeen = seen
    end
    if seen[neighbor] then return end
    seen[neighbor] = true

    local neighbors = surfaceData.neighbors
    if not neighbors then
        neighbors = {}
        surfaceData.neighbors = neighbors
    end

    neighbors[#neighbors + 1] = neighbor
end

local function edgeIntervalsOverlap(edgeA, edgeB)
    local a0 = dot(edgeA.a, edgeA.dir)
    local a1 = dot(edgeA.b, edgeA.dir)
    local b0 = dot(edgeB.a, edgeA.dir)
    local b1 = dot(edgeB.b, edgeA.dir)
    local minA, maxA = math.min(a0, a1), math.max(a0, a1)
    local minB, maxB = math.min(b0, b1), math.max(b0, b1)

    return math.min(maxA, maxB) - math.max(minA, minB) >= CONFIG.edgeOverlapTolerance
end

local function edgesAreAdjacent(edgeA, edgeB)
    if not edgeA or not edgeB or edgeA.surface == edgeB.surface then return false end

    local parallel = math.abs(dot(edgeA.dir, edgeB.dir))
    if parallel < CONFIG.edgeParallelDotMin then return false end

    local offset = edgeB.a - edgeA.a
    local lineDistance = M.VectorLengthPrecise and M.VectorLengthPrecise(cross(offset, edgeA.dir))
        or math.sqrt(M.VectorLengthSqrPrecise(cross(offset, edgeA.dir)))
    if lineDistance > CONFIG.edgeCollinearTolerance then return false end

    return edgeIntervalsOverlap(edgeA, edgeB)
end

local function buildDirectNeighborCache()
    cache.edgeIndex = {}

    for i = 1, #(cache.surfaces or {}) do
        local surfaceData = cache.surfaces[i]
        surfaceData.neighbors = {}
        surfaceData.neighborSeen = {}
        indexSurfaceEdges(surfaceData)
        maybeYield()
    end

    local tested = {}
    for i = 1, #(cache.surfaces or {}) do
        local surfaceData = cache.surfaces[i]
        for edgeIndex = 1, #(surfaceData.edges or {}) do
            local edge = surfaceData.edges[edgeIndex]
            local minX, minY, minZ, maxX, maxY, maxZ = edgeCellBounds(edge)
            for x = minX, maxX do
                for y = minY, maxY do
                    for z = minZ, maxZ do
                        local cell = cache.edgeIndex[edgeCellKey(x, y, z)]
                        if cell then
                            for j = 1, #cell do
                                local other = cell[j]
                                local otherSurface = other and other.surface
                                if otherSurface and otherSurface ~= surfaceData then
                                    local aId = math.min(surfaceData.id or 0, otherSurface.id or 0)
                                    local bId = math.max(surfaceData.id or 0, otherSurface.id or 0)
                                    local key = aId .. ":" .. bId .. ":" .. edgeIndex .. ":" .. tostring(other.index or j)
                                    if not tested[key] then
                                        tested[key] = true
                                        if edgesAreAdjacent(edge, other) then
                                            addSurfaceNeighbor(surfaceData, otherSurface)
                                            addSurfaceNeighbor(otherSurface, surfaceData)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            maybeYield()
        end
    end

    for i = 1, #(cache.surfaces or {}) do
        cache.surfaces[i].neighborSeen = nil
    end
end

local function finishBuild()
    cache.status = cache.STATUS.READY
    cache.readyAt = now()
    cache.worker = nil

    local seconds = math.max(cache.readyAt - (cache.startedAt or cache.readyAt), 0)
    print(("Magic Align: World BSP snapping ready in %.2fs (%d surfaces cached, %d skipped)."):format(
        seconds,
        cache.cached or 0,
        cache.skipped or 0
    ))

    if notification and notification.AddLegacy then
        notification.AddLegacy("Magic Align world snapping is ready.", NOTIFY_HINT, 3)
    end
end

local function readWorldBrushSurfaces()
    local candidates = {}
    local count = 0

    local function addCandidate(ent)
        if ent == nil then return end

        for i = 1, count do
            if candidates[i] == ent then return end
        end

        count = count + 1
        candidates[count] = ent
    end

    if game and isfunction(game.GetWorld) then
        addCandidate(game.GetWorld())
    end
    if isfunction(Entity) then
        addCandidate(Entity(0))
    end

    for i = 1, count do
        local ent = candidates[i]
        local getBrushSurfaces = ent and ent.GetBrushSurfaces or nil
        if isfunction(getBrushSurfaces) then
            local surfaces = getBrushSurfaces(ent)
            if istable(surfaces) then
                return surfaces, ent
            end
        end
    end
end

local function buildWorker()
    local surfaces = readWorldBrushSurfaces()

    if not istable(surfaces) then
        cache.status = cache.STATUS.UNAVAILABLE
        cache.worker = nil
        cache.error = "world brush surfaces unavailable"
        print("Magic Align: World BSP snapping unavailable; no world brush surfaces were returned.")
        return
    end

    cache.total = #surfaces
    if cache.total <= 0 then
        cache.status = cache.STATUS.UNAVAILABLE
        cache.worker = nil
        cache.error = "world brush surface list was empty"
        print("Magic Align: World BSP snapping unavailable; the world brush surface list was empty.")
        return
    end

    for i = 1, cache.total do
        local surfaceData = buildSurfaceData(surfaces[i], i)
        if surfaceData then
            cache.cached = cache.cached + 1
            cache.surfaces[cache.cached] = surfaceData
            indexSurface(surfaceData)
            indexSurfacePlane(surfaceData)
        else
            cache.skipped = cache.skipped + 1
        end

        maybeYield()
    end

    buildDirectNeighborCache()
    finishBuild()
end

local function startBuild()
    resetCache(cache.STATUS.BUILDING)
    cache.startedAt = now()
    cache.worker = coroutine.create(buildWorker)
    cache.hintedSlow = true

    print("Magic Align: World BSP snapping cache is building...")
    if notification and notification.AddLegacy then
        notification.AddLegacy("Magic Align world snapping cache is building...", NOTIFY_HINT, 3)
    end
end

local function maybeSlowHint()
    if cache.hintedSlow or cache.status ~= cache.STATUS.BUILDING then return end
    if now() - (cache.startedAt or now()) < CONFIG.hintAfterSeconds then return end

    cache.hintedSlow = true
    print("Magic Align: World BSP snapping is still building...")
    if notification and notification.AddLegacy then
        notification.AddLegacy("Magic Align world snapping is still building...", NOTIFY_HINT, 4)
    end
end

function worldBSP.update(settings)
    if not settings or not settings.worldBspSnap then return end

    if cache.version ~= CACHE_VERSION or cache.map ~= currentMap() or cache.status == cache.STATUS.IDLE then
        startBuild()
    end

    if cache.status ~= cache.STATUS.BUILDING or not cache.worker then return end

    cache.frameStartedAt = now()
    cache.frameBudgetMs = readBudgetMs(settings)

    local worker = cache.worker
    local ok, err = coroutine.resume(worker)
    if not ok then
        cache.status = cache.STATUS.ERROR
        cache.error = tostring(err)
        cache.worker = nil
        print("Magic Align: World BSP snapping failed: " .. cache.error)
        return
    end

    if coroutine.status(worker) == "dead" and cache.status == cache.STATUS.BUILDING then
        finishBuild()
    end

    maybeSlowHint()
end

function worldBSP.isReady()
    return cache.status == cache.STATUS.READY
end

local function addQueriedSurface(surfaces, count, seen, planeSet, surfaceData)
    if not surfaceData then return count end
    if planeSet and not planeSet[surfaceData] then return count end
    if seen[surfaceData] then return count end

    seen[surfaceData] = true
    count = count + 1
    surfaces[count] = surfaceData
    return count
end

local function querySurfaces(worldPos, out, seenOut)
    if not isvector(worldPos) then return end

    local surfaces = out or {}
    local count = 0
    local seen = seenOut or {}
    local x = cellCoord(worldPos.x)
    local y = cellCoord(worldPos.y)
    local z = cellCoord(worldPos.z)

    for cx = x - CONFIG.queryCellRadius, x + CONFIG.queryCellRadius do
        for cy = y - CONFIG.queryCellRadius, y + CONFIG.queryCellRadius do
            for cz = z - CONFIG.queryCellRadius, z + CONFIG.queryCellRadius do
                local cell = cache.index and cache.index[cellKey(cx, cy, cz)] or nil
                if cell then
                    for i = 1, #cell do
                        count = addQueriedSurface(surfaces, count, seen, nil, cell[i])
                    end
                end
            end
        end
    end

    for i = 1, #(cache.largeSurfaces or {}) do
        count = addQueriedSurface(surfaces, count, seen, nil, cache.largeSurfaces[i])
    end

    for i = count + 1, #surfaces do
        surfaces[i] = nil
    end
    for surfaceData in pairs(seen) do
        seen[surfaceData] = nil
    end

    return surfaces, count
end

local function pointInsideWorldBoundsComponents(surfaceData, x, y, z, tolerance)
    local mins = surfaceData.worldMins
    local maxs = surfaceData.worldMaxs
    local eps = tolerance or CONFIG.boundsTolerance

    return x >= mins.x - eps and x <= maxs.x + eps
        and y >= mins.y - eps and y <= maxs.y + eps
        and z >= mins.z - eps and z <= maxs.z + eps
end

local function pointInsideWorldBounds(surfaceData, worldPos, tolerance)
    return pointInsideWorldBoundsComponents(surfaceData, worldPos.x, worldPos.y, worldPos.z, tolerance)
end

local function normalizedVectorFromComponents(x, y, z, epsilonSqr)
    local lengthSqr = x * x + y * y + z * z
    if lengthSqr <= (tonumber(epsilonSqr) or M.COMPUTE_VECTOR_EPSILON_SQR) then return end

    local invLength = 1 / math.sqrt(lengthSqr)
    return VectorP(x * invLength, y * invLength, z * invLength)
end

local function traceRayInfo(tr, hitPos)
    local start = isvector(tr.StartPos) and tr.StartPos or nil
    if not start and IsValid(LocalPlayer()) then
        start = LocalPlayer():GetShootPos()
    end
    if not isvector(start) then return end

    local dx = hitPos.x - start.x
    local dy = hitPos.y - start.y
    local dz = hitPos.z - start.z
    local dir = normalizedVectorFromComponents(dx, dy, dz, M.PICKING_VECTOR_EPSILON_SQR)
    if not dir then
        dir = isvector(tr.Normal)
            and normalizedVectorFromComponents(tr.Normal.x, tr.Normal.y, tr.Normal.z, M.PICKING_VECTOR_EPSILON_SQR)
            or nil
    end
    if not dir then return end

    local hitDistance = math.sqrt(dx * dx + dy * dy + dz * dz)
    return start, dir, hitDistance
end

local function signedPlaneDistance(surfaceData, x, y, z)
    local origin = surfaceData.origin
    local normal = surfaceData.normal

    return (x - origin.x) * normal.x
        + (y - origin.y) * normal.y
        + (z - origin.z) * normal.z
end

local function writeTraceMatch(out, surfaceData, normalSign, u, v, match)
    out.surface = surfaceData
    out.normalSign = normalSign
    out.u = u
    out.v = v
    out.match = match
    return out
end

local function collectTracePlaneBucketSurfaces(hitPos, hitNormal, out)
    if not isvector(hitPos) or not isvector(hitNormal) or not istable(cache.planeBuckets) then return end

    out = out or {}
    for surfaceData in pairs(out) do
        out[surfaceData] = nil
    end

    local count = 0
    local normalRadius = math.max(math.floor(CONFIG.planeBucketNormalRadius or 0), 0)
    local distanceRadius = math.max(math.floor(CONFIG.planeBucketDistanceRadius or 0), 0)

    local function collectForNormal(normal)
        local baseX = planeNormalCoord(normal.x)
        local baseY = planeNormalCoord(normal.y)
        local baseZ = planeNormalCoord(normal.z)
        local baseDistance = planeDistanceCoord(dot(normal, hitPos))

        for nx = baseX - normalRadius, baseX + normalRadius do
            for ny = baseY - normalRadius, baseY + normalRadius do
                for nz = baseZ - normalRadius, baseZ + normalRadius do
                    for distance = baseDistance - distanceRadius, baseDistance + distanceRadius do
                        local bucket = cache.planeBuckets[planeBucketKey(nx, ny, nz, distance)]
                        if bucket then
                            for i = 1, #bucket do
                                local surfaceData = bucket[i]
                                if not out[surfaceData] then
                                    out[surfaceData] = true
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    collectForNormal(hitNormal)
    collectForNormal(-hitNormal)

    if count <= 0 then return end
    return out, count
end

local function selectSurfaceForTrace(tr, surfaces, surfaceCount, hitPos, hitNormal, planeSet)
    if not surfaces or surfaceCount == 0 then return end

    local rayStart, rayDir, rayHitDistance = traceRayInfo(tr, hitPos)
    local bestStrict = traceScratch.bestStrict or {}
    local bestRay = traceScratch.bestRay or {}
    local bestEdge = traceScratch.bestEdge or {}
    traceScratch.bestStrict = bestStrict
    traceScratch.bestRay = bestRay
    traceScratch.bestEdge = bestEdge
    local hasBestStrict = false
    local bestStrictScore
    local hasBestRay = false
    local bestRayScore
    local hasBestEdge = false
    local bestEdgeScore
    for i = 1, surfaceCount do
        local surfaceData = surfaces[i]
        if planeSet and not planeSet[surfaceData] then
            surfaceData = nil
        end

        if surfaceData then
        if pointInsideWorldBounds(surfaceData, hitPos) then
            local signedPlaneDist = signedPlaneDistance(surfaceData, hitPos.x, hitPos.y, hitPos.z)
            local planeDist = math.abs(signedPlaneDist)
            if planeDist <= CONFIG.planeTolerance then
                local normalDot = dot(surfaceData.normal, hitNormal)
                local absNormalDot = math.abs(normalDot)
                if absNormalDot >= CONFIG.normalDotMin then
                    local normal = surfaceData.normal
                    local u, v = surfaceUvFromComponents(
                        surfaceData,
                        hitPos.x - normal.x * signedPlaneDist,
                        hitPos.y - normal.y * signedPlaneDist,
                        hitPos.z - normal.z * signedPlaneDist
                    )
                    if u >= surfaceData.uMin - CONFIG.boundsTolerance
                        and u <= surfaceData.uMax + CONFIG.boundsTolerance
                        and v >= surfaceData.vMin - CONFIG.boundsTolerance
                        and v <= surfaceData.vMax + CONFIG.boundsTolerance then
                        local normalPenalty = (1 - absNormalDot) * 10

                        if planeDist <= CONFIG.surfacePickTolerance
                            and pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonPickTolerance) then
                            local score = planeDist + normalPenalty
                            if not bestStrictScore or score < bestStrictScore then
                                writeTraceMatch(bestStrict, surfaceData, normalDot < 0 and -1 or 1, u, v, "strict")
                                hasBestStrict = true
                                bestStrictScore = score
                            end
                        else
                            local edgeDistance = polygonEdgeDistance(surfaceData.polygon, u, v)
                            if edgeDistance <= CONFIG.edgePickTolerance then
                                local score = planeDist + normalPenalty + edgeDistance * 4
                                if not bestEdgeScore or score < bestEdgeScore then
                                    writeTraceMatch(bestEdge, surfaceData, normalDot < 0 and -1 or 1, u, v, "edge")
                                    hasBestEdge = true
                                    bestEdgeScore = score
                                end
                            end
                        end
                    end
                end
            end
        end

        if rayStart and rayDir and rayHitDistance then
            local denom = dot(surfaceData.normal, rayDir)
            if math.abs(denom) >= CONFIG.rayPlaneDotMin then
                local normal = surfaceData.normal
                local origin = surfaceData.origin
                local t = ((origin.x - rayStart.x) * normal.x
                    + (origin.y - rayStart.y) * normal.y
                    + (origin.z - rayStart.z) * normal.z) / denom
                local traceDistance = math.abs(t - rayHitDistance)
                if t >= 0 and traceDistance <= CONFIG.rayPickTolerance then
                    local rayX = rayStart.x + rayDir.x * t
                    local rayY = rayStart.y + rayDir.y * t
                    local rayZ = rayStart.z + rayDir.z * t
                    if pointInsideWorldBoundsComponents(surfaceData, rayX, rayY, rayZ, CONFIG.boundsTolerance + CONFIG.rayPickTolerance) then
                        local u, v = surfaceUvFromComponents(surfaceData, rayX, rayY, rayZ)
                        if u >= surfaceData.uMin - CONFIG.boundsTolerance
                            and u <= surfaceData.uMax + CONFIG.boundsTolerance
                            and v >= surfaceData.vMin - CONFIG.boundsTolerance
                            and v <= surfaceData.vMax + CONFIG.boundsTolerance
                            and pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonPickTolerance) then
                            local normalDot = dot(surfaceData.normal, hitNormal)
                            local normalPenalty = (1 - math.min(math.abs(normalDot), 1)) * CONFIG.rayNormalWeight
                            local score = traceDistance + (1 - math.min(math.abs(denom), 1)) * 0.25 + normalPenalty
                            if not bestRayScore or score < bestRayScore then
                                writeTraceMatch(bestRay, surfaceData, normalDot < 0 and -1 or 1, u, v, "ray")
                                hasBestRay = true
                                bestRayScore = score
                            end
                        end
                    end
                end
            end
        end
        end
    end

    if hasBestRay and bestRayScore and bestRayScore <= CONFIG.rayPreferScore then
        return bestRay
    end

    if hasBestStrict then return bestStrict end
    if hasBestRay then return bestRay end
    if hasBestEdge then return bestEdge end
end

local function findSurfaceForTrace(tr)
    if cache.status ~= cache.STATUS.READY or not tr or not isvector(tr.HitPos) or not isvector(tr.HitNormal) then return end

    local hitPos = tr.HitPos
    local hitNormal = tr.HitNormal
    if not isvector(hitPos) or not isvector(hitNormal) then return end

    hitNormal = normalizedVec(hitNormal, M.PICKING_VECTOR_EPSILON_SQR)
    if not hitNormal then return end

    traceScratch.querySurfaces = traceScratch.querySurfaces or {}
    traceScratch.querySeen = traceScratch.querySeen or {}
    traceScratch.planeSeen = traceScratch.planeSeen or {}

    local surfaces, surfaceCount = querySurfaces(hitPos, traceScratch.querySurfaces, traceScratch.querySeen)
    surfaceCount = surfaceCount or 0
    if surfaceCount == 0 then return end

    if surfaceCount >= CONFIG.planeBucketMinSurfaceCandidates then
        local planeSeen, planeCount = collectTracePlaneBucketSurfaces(hitPos, hitNormal, traceScratch.planeSeen)
        local match = planeSeen
            and planeCount
            and planeCount > 0
            and selectSurfaceForTrace(tr, surfaces, surfaceCount, hitPos, hitNormal, planeSeen)
            or nil
        if match and match.match == "strict" then
            return match
        end
    end

    return selectSurfaceForTrace(tr, surfaces, surfaceCount, hitPos, hitNormal)
end

local function gridPointValue(grid, axisKey, index)
    local div = axisKey == "u" and grid.divU or grid.divV
    local minValue = axisKey == "u" and grid.uMin or grid.vMin
    local maxValue = axisKey == "u" and grid.uMax or grid.vMax
    local step = axisKey == "u" and grid.stepU or grid.stepV

    if index == div then return maxValue end
    return minValue + step * index
end

local function gridStepFromGrid(grid)
    if not grid then return end

    local step
    if tonumber(grid.stepU) and math.abs(grid.stepU) > M.COMPUTE_EPSILON then
        step = math.abs(grid.stepU)
    end
    if tonumber(grid.stepV) and math.abs(grid.stepV) > M.COMPUTE_EPSILON then
        step = step and math.min(step, math.abs(grid.stepV)) or math.abs(grid.stepV)
    end

    return step
end

local function activeGridStep(face)
    local step = tonumber(face and face.activeGridStep)
    if step and step > M.COMPUTE_EPSILON then
        return step
    end

    local gridStep = gridStepFromGrid(face and face.gridA)
    if gridStep then
        step = gridStep
    end

    if face and face.gridB and face.gridB ~= face.gridA then
        gridStep = gridStepFromGrid(face.gridB)
        if gridStep then
            step = step and math.min(step, gridStep) or gridStep
        end
    end

    return step
end

local function snapCandidateDistance(candidate, rawU, rawV)
    if not candidate or candidate.u == nil or candidate.v == nil then return math.huge end

    return (candidate.u - rawU) ^ 2 + (candidate.v - rawV) ^ 2
end

local function solveGlobalGridFamilies(a, b, det, valueU, valueV)
    if not a or not b then return end

    det = det or familyPairDet(a, b)
    if math.abs(det) <= WORLD_GRID.pairDetEpsilon then return end

    local rhsU = valueU - a.origin
    local rhsV = valueV - b.origin
    local u = (rhsU * b.vCoeff - a.vCoeff * rhsV) / det
    local v = (a.uCoeff * rhsV - rhsU * b.uCoeff) / det

    return u, v
end

local function solveGlobalGridPair(pair, valueU, valueV)
    return solveGlobalGridFamilies(
        pair and pair.familyU,
        pair and pair.familyV,
        pair and pair.det,
        valueU,
        valueV
    )
end

local function keepGlobalSnapCandidate(best, candidate, rawU, rawV)
    if not candidate then return best end

    candidate.dist = snapCandidateDistance(candidate, rawU, rawV)
    if not best then return candidate end

    local candidateInside = candidate.inside == true
    local bestInside = best.inside == true
    if candidateInside ~= bestInside then
        return candidateInside and candidate or best
    end

    if candidate.dist < best.dist then
        return candidate
    end

    return best
end

local function globalPairSnapCandidate(face, surfaceData, pair, rawU, rawV, step)
    local rawWorld = worldFromUv(surfaceData, rawU, rawV)
    local baseU = math.Round(axisComponent(rawWorld, pair.axisU) / step)
    local baseV = math.Round(axisComponent(rawWorld, pair.axisV) / step)
    local best

    for du = -1, 1 do
        for dv = -1, 1 do
            local valueU = (baseU + du) * step
            local valueV = (baseV + dv) * step
            local u, v = solveGlobalGridPair(pair, valueU, valueV)
            if u and v then
                best = keepGlobalSnapCandidate(best, {
                    u = u,
                    v = v,
                    gridU = nil,
                    gridV = nil,
                    gridUId = nil,
                    gridVId = nil,
                    indexU = nil,
                    indexV = nil,
                    percentU = nil,
                    percentV = nil,
                    globalGrid = true,
                    globalAxisU = pair.axisU,
                    globalAxisV = pair.axisV,
                    inside = pointInPolygon2D(face.polygon, u, v, CONFIG.polygonTolerance)
                }, rawU, rawV)
            end
        end
    end

    return best
end

local function globalLineSnapCandidate(face, surfaceData, family, rawU, rawV, step)
    if not family then return end

    local rawWorld = worldFromUv(surfaceData, rawU, rawV)
    local value = math.Round(axisComponent(rawWorld, family.axis) / step) * step
    local rhs = value - family.origin
    local denom = family.uCoeff * family.uCoeff + family.vCoeff * family.vCoeff
    if denom <= WORLD_GRID.familyEpsilonSqr then return end

    local offset = (family.uCoeff * rawU + family.vCoeff * rawV - rhs) / denom
    local u = rawU - family.uCoeff * offset
    local v = rawV - family.vCoeff * offset

    return {
        u = u,
        v = v,
        gridU = nil,
        gridV = nil,
        gridUId = nil,
        gridVId = nil,
        indexU = nil,
        indexV = nil,
        percentU = nil,
        percentV = nil,
        globalGrid = true,
        globalAxisU = family.axis,
        inside = pointInPolygon2D(face.polygon, u, v, CONFIG.polygonTolerance)
    }
end

local function configureGlobalFace(face, surfaceData, settings)
    local step = worldGridStep(settings)
    face.globalGrid = true
    face.globalGridStep = step
    face.activeGridStep = step
    face.globalGridOverlays = globalProjectionPairs(surfaceData)
end

local function snapGlobalFaceCoordinates(settings, face, surfaceData, rawU, rawV)
    if settings and settings.shift then
        return {
            u = math.Clamp(rawU, face.uMin, face.uMax),
            v = math.Clamp(rawV, face.vMin, face.vMax)
        }
    end

    configureGlobalFace(face, surfaceData, settings)

    local step = face.globalGridStep
    local best
    for _, pair in ipairs(globalSnapPairs(surfaceData)) do
        best = keepGlobalSnapCandidate(best, globalPairSnapCandidate(face, surfaceData, pair, rawU, rawV, step), rawU, rawV)
    end

    if not best then
        local families = surfaceData.globalFamilies or buildGlobalFamilies(surfaceData)
        for i = 1, #WORLD_AXIS_KEYS do
            best = keepGlobalSnapCandidate(best, globalLineSnapCandidate(face, surfaceData, families[WORLD_AXIS_KEYS[i]], rawU, rawV, step), rawU, rawV)
        end
    end

    if best then
        return best
    end

    return {
        u = math.Clamp(rawU, face.uMin, face.uMax),
        v = math.Clamp(rawV, face.vMin, face.vMax)
    }
end

local function activeStepFromSnapped(face, snapped)
    if face and face.globalGrid then
        return face.globalGridStep
    end

    local step
    if snapped then
        step = gridStepFromGrid(snapped.gridU)
        local stepV = gridStepFromGrid(snapped.gridV)
        if stepV then
            step = step and math.min(step, stepV) or stepV
        end
    end

    return step or activeGridStep(face)
end

local function snapVisibilityEpsilon(face)
    local step = activeGridStep(face)
    if step and step > M.COMPUTE_EPSILON then
        return math.max(CONFIG.polygonTolerance, step * 0.001)
    end

    return CONFIG.polygonTolerance
end

local function snapCandidateRank(candidate)
    local kind = candidate and candidate.boundaryKind
    if kind == "corner" then return 3 end
    if kind == "grid_boundary" then return 2 end
    return 1
end

local snapCandidateIsVisible

local function resetScratchArray(key)
    local array = snapScratch[key]
    if not array then
        array = { count = 0 }
        snapScratch[key] = array
    else
        array.count = 0
    end

    return array
end

local function nextScratchSlot(array)
    local index = (array.count or 0) + 1
    array.count = index

    local slot = array[index]
    if not slot then
        slot = {}
        array[index] = slot
    end

    return slot
end

local function writeSnapCandidate(candidate, u, v, gridU, gridV, gridUId, gridVId, indexU, indexV, percentU, percentV, boundaryKind, globalGrid, globalAxisU, globalAxisV)
    candidate.u = u
    candidate.v = v
    candidate.gridU = gridU
    candidate.gridV = gridV
    candidate.gridUId = gridUId
    candidate.gridVId = gridVId
    candidate.indexU = indexU
    candidate.indexV = indexV
    candidate.percentU = percentU
    candidate.percentV = percentV
    candidate.boundaryKind = boundaryKind
    candidate.globalGrid = globalGrid
    candidate.globalAxisU = globalAxisU
    candidate.globalAxisV = globalAxisV
    candidate.dist = nil

    return candidate
end

local function copySnapCandidate(target, source)
    target.u = source.u
    target.v = source.v
    target.gridU = source.gridU
    target.gridV = source.gridV
    target.gridUId = source.gridUId
    target.gridVId = source.gridVId
    target.indexU = source.indexU
    target.indexV = source.indexV
    target.percentU = source.percentU
    target.percentV = source.percentV
    target.boundaryKind = source.boundaryKind
    target.globalGrid = source.globalGrid
    target.globalAxisU = source.globalAxisU
    target.globalAxisV = source.globalAxisV
    target.dist = source.dist
    target.valid = true

    return target
end

local function beginSnapSelector(face, rawU, rawV)
    local selector = snapScratch.selector
    if not selector then
        selector = {}
        snapScratch.selector = selector
    end

    local current = snapScratch.currentCandidate
    if not current then
        current = {}
        snapScratch.currentCandidate = current
    end

    local best = snapScratch.bestCandidate
    if not best then
        best = {}
        snapScratch.bestCandidate = best
    end

    best.valid = false
    selector.face = face
    selector.rawU = rawU
    selector.rawV = rawV
    selector.current = current
    selector.best = best

    return selector
end

local function emitSnapCandidate(selector, candidate)
    if not candidate or candidate.u == nil or candidate.v == nil then return end

    candidate.dist = snapCandidateDistance(candidate, selector.rawU, selector.rawV)
    if not snapCandidateIsVisible(selector.face, selector.rawU, selector.rawV, candidate) then return end

    local best = selector.best
    if not best.valid
        or candidate.dist < best.dist - M.COMPUTE_EPSILON
        or (math.abs(candidate.dist - best.dist) <= M.COMPUTE_EPSILON
            and snapCandidateRank(candidate) > snapCandidateRank(best)) then
        copySnapCandidate(best, candidate)
    end
end

local function addSurfaceAxisLine(lines, face, axisKey, grid, gridId, index)
    if not grid then return end

    local div = math.max(math.Round(tonumber(axisKey == "u" and grid.divU or grid.divV) or 0), 0)
    index = math.Clamp(math.Round(tonumber(index) or 0), 0, div)

    local value = gridPointValue(grid, axisKey, index)
    if value == nil then return end

    local eps = snapVisibilityEpsilon(face)
    local count = lines.count or 0
    for i = 1, count do
        local line = lines[i]
        if line.axisKey == axisKey and math.abs(line.value - value) <= eps then
            return
        end
    end

    local line = nextScratchSlot(lines)
    line.axisKey = axisKey
    line.value = value
    line.grid = grid
    line.gridId = gridId
    line.index = index
    line.percent = div > 0 and (index / div) * 100 or 0
end

local function collectSurfaceAxisLinesForGrid(lines, face, axisKey, rawValue, grid, gridId)
    if not grid then return end

    local div = math.max(math.Round(tonumber(axisKey == "u" and grid.divU or grid.divV) or 0), 0)
    local step = axisKey == "u" and grid.stepU or grid.stepV
    local minValue = axisKey == "u" and grid.uMin or grid.vMin

    if step and math.abs(step) > M.COMPUTE_EPSILON then
        local base = math.floor(((tonumber(rawValue) or minValue) - minValue) / step)
        for offset = -1, 2 do
            addSurfaceAxisLine(lines, face, axisKey, grid, gridId, base + offset)
        end
    elseif div == 0 then
        addSurfaceAxisLine(lines, face, axisKey, grid, gridId, 0)
    end
end

local function collectSurfaceAxisLines(face, axisKey, rawValue, lines)
    collectSurfaceAxisLinesForGrid(lines, face, axisKey, rawValue, face and face.gridA, "A")
    if face and face.gridB and face.gridB ~= face.gridA then
        collectSurfaceAxisLinesForGrid(lines, face, axisKey, rawValue, face.gridB, "B")
    end
    return lines
end

local function emitSurfaceGridPointCandidate(selector, uLine, vLine)
    if not uLine or not vLine then return end

    emitSnapCandidate(selector, writeSnapCandidate(
        selector.current,
        uLine.value,
        vLine.value,
        uLine.grid,
        vLine.grid,
        uLine.gridId,
        vLine.gridId,
        uLine.index,
        vLine.index,
        uLine.percent,
        vLine.percent
    ))
end

local function copySurfaceAxisMetadata(candidate, line)
    if not candidate or not line then return end

    if line.axisKey == "u" then
        candidate.gridU = line.grid
        candidate.gridUId = line.gridId
        candidate.indexU = line.index
        candidate.percentU = line.percent
        return
    end

    candidate.gridV = line.grid
    candidate.gridVId = line.gridId
    candidate.indexV = line.index
    candidate.percentV = line.percent
end

local function emitSurfaceGridBoundaryCandidates(selector, axisLines)
    local polygon = selector.face and selector.face.polygon
    if not istable(polygon) or #polygon < 2 then return end

    local eps = snapVisibilityEpsilon(selector.face)
    local lineCount = axisLines.count or 0
    for lineIndex = 1, lineCount do
        local line = axisLines[lineIndex]
        local previous = polygon[#polygon]

        for i = 1, #polygon do
            local current = polygon[i]
            local a = line.axisKey == "u" and previous.u or previous.v
            local b = line.axisKey == "u" and current.u or current.v

            if math.abs(a - b) > eps
                and line.value >= math.min(a, b) - eps
                and line.value <= math.max(a, b) + eps then
                local t = math.Clamp((line.value - a) / (b - a), 0, 1)
                local candidate = writeSnapCandidate(
                    selector.current,
                    previous.u + (current.u - previous.u) * t,
                    previous.v + (current.v - previous.v) * t,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    "grid_boundary"
                )

                copySurfaceAxisMetadata(candidate, line)
                emitSnapCandidate(selector, candidate)
            end

            previous = current
        end
    end
end

local function emitCornerSnapCandidates(selector)
    local face = selector.face
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 2 then return end

    for i = 1, #polygon do
        local vertex = polygon[i]
        emitSnapCandidate(selector, writeSnapCandidate(
            selector.current,
            vertex.u,
            vertex.v,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            "corner"
        ))
    end
end

local function globalFamilyValue(family, u, v)
    return family.origin + family.uCoeff * u + family.vCoeff * v
end

local function addGlobalFamilyLine(lines, face, family, value)
    if not family or value == nil then return end

    local eps = snapVisibilityEpsilon(face)
    local count = lines.count or 0
    for i = 1, count do
        local line = lines[i]
        if line.family == family and math.abs(line.value - value) <= eps then
            return
        end
    end

    local line = nextScratchSlot(lines)
    line.family = family
    line.axis = family.axis
    line.value = value
end

local function collectGlobalFamilyLines(face, rawU, rawV, lines)
    local surfaceData = face and face.surface
    local step = activeGridStep(face)
    if not surfaceData or not step or step <= M.COMPUTE_EPSILON then return lines end

    local families = surfaceData.globalFamilies or buildGlobalFamilies(surfaceData)
    surfaceData.globalFamilies = families

    for i = 1, #WORLD_AXIS_KEYS do
        local family = families[WORLD_AXIS_KEYS[i]]
        if family then
            local rawValue = globalFamilyValue(family, rawU, rawV)
            local base = math.floor(rawValue / step)
            for offset = -1, 2 do
                addGlobalFamilyLine(lines, face, family, (base + offset) * step)
            end
        end
    end

    return lines
end

local function emitGlobalGridPointCandidates(selector, lines)
    local lineCount = lines.count or 0
    for i = 1, lineCount - 1 do
        local a = lines[i]
        for j = i + 1, lineCount do
            local b = lines[j]
            if a.family ~= b.family and familiesAreIndependent(a.family, b.family) then
                local u, v = solveGlobalGridFamilies(a.family, b.family, familyPairDet(a.family, b.family), a.value, b.value)

                if u and v then
                    emitSnapCandidate(selector, writeSnapCandidate(
                        selector.current,
                        u,
                        v,
                        nil,
                        nil,
                        nil,
                        nil,
                        nil,
                        nil,
                        nil,
                        nil,
                        nil,
                        true,
                        a.axis,
                        b.axis
                    ))
                end
            end
        end
    end
end

local function emitGlobalGridBoundaryCandidates(selector, lines)
    local face = selector.face
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 2 then return end

    local eps = snapVisibilityEpsilon(face)
    local lineCount = lines.count or 0
    for lineIndex = 1, lineCount do
        local line = lines[lineIndex]
        local previous = polygon[#polygon]

        for i = 1, #polygon do
            local current = polygon[i]
            local a = globalFamilyValue(line.family, previous.u, previous.v) - line.value
            local b = globalFamilyValue(line.family, current.u, current.v) - line.value

            if math.abs(a - b) > eps
                and ((a <= eps and b >= -eps) or (b <= eps and a >= -eps)) then
                local t = math.Clamp(a / (a - b), 0, 1)
                emitSnapCandidate(selector, writeSnapCandidate(
                    selector.current,
                    previous.u + (current.u - previous.u) * t,
                    previous.v + (current.v - previous.v) * t,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    "grid_boundary",
                    true,
                    line.axis
                ))
            end

            previous = current
        end
    end
end

local function cross2D(ax, ay, bx, by)
    return ax * by - ay * bx
end

local function segmentCrossesPolygonEdge(rawU, rawV, candidate, a, b, eps)
    local rx = candidate.u - rawU
    local ry = candidate.v - rawV
    local sx = b.u - a.u
    local sy = b.v - a.v
    local denom = cross2D(rx, ry, sx, sy)
    if math.abs(denom) <= M.COMPUTE_EPSILON then
        return false
    end

    local qx = a.u - rawU
    local qy = a.v - rawV
    local segmentT = cross2D(qx, qy, sx, sy) / denom
    local edgeT = cross2D(qx, qy, rx, ry) / denom
    local paramEps = 1e-5

    return segmentT > paramEps
        and segmentT < 1 - paramEps
        and edgeT >= -paramEps
        and edgeT <= 1 + paramEps
end

local function segmentCrossesSurfaceBoundary(face, rawU, rawV, candidate)
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 2 then return false end

    local eps = snapVisibilityEpsilon(face)
    local previous = polygon[#polygon]
    for i = 1, #polygon do
        local current = polygon[i]
        if segmentCrossesPolygonEdge(rawU, rawV, candidate, previous, current, eps) then
            return true
        end

        previous = current
    end

    return false
end

local function gridHasAxisBarrierBetween(grid, axisKey, fromValue, toValue, eps)
    if not grid or math.abs(toValue - fromValue) <= eps then return false end

    local div = math.max(math.Round(tonumber(axisKey == "u" and grid.divU or grid.divV) or 0), 0)
    local step = axisKey == "u" and grid.stepU or grid.stepV
    local minValue = axisKey == "u" and grid.uMin or grid.vMin
    if not step or math.abs(step) <= M.COMPUTE_EPSILON then return false end

    local low = math.min(fromValue, toValue) + eps
    local high = math.max(fromValue, toValue) - eps
    if low > high then return false end

    local first = math.ceil((low - minValue) / step - M.COMPUTE_EPSILON)
    local last = math.floor((high - minValue) / step + M.COMPUTE_EPSILON)

    return first <= last and last >= 0 and first <= div
end

local function segmentCrossesSurfaceGrid(face, rawU, rawV, candidate)
    local eps = snapVisibilityEpsilon(face)
    if gridHasAxisBarrierBetween(face and face.gridA, "u", rawU, candidate.u, eps)
        or gridHasAxisBarrierBetween(face and face.gridA, "v", rawV, candidate.v, eps) then
        return true
    end

    if face and face.gridB and face.gridB ~= face.gridA
        and (gridHasAxisBarrierBetween(face.gridB, "u", rawU, candidate.u, eps)
            or gridHasAxisBarrierBetween(face.gridB, "v", rawV, candidate.v, eps)) then
        return true
    end

    return false
end

local function globalFamilyHasBarrierBetween(family, step, rawU, rawV, candidate, eps)
    local fromValue = globalFamilyValue(family, rawU, rawV)
    local toValue = globalFamilyValue(family, candidate.u, candidate.v)
    if math.abs(toValue - fromValue) <= eps then return false end

    local low = math.min(fromValue, toValue) + eps
    local high = math.max(fromValue, toValue) - eps
    if low > high then return false end

    local first = math.ceil(low / step - M.COMPUTE_EPSILON)
    local last = math.floor(high / step + M.COMPUTE_EPSILON)

    return first <= last
end

local function segmentCrossesGlobalGrid(face, rawU, rawV, candidate)
    local surfaceData = face and face.surface
    local step = activeGridStep(face)
    if not surfaceData or not step or step <= M.COMPUTE_EPSILON then return false end

    local families = surfaceData.globalFamilies or buildGlobalFamilies(surfaceData)
    surfaceData.globalFamilies = families

    local eps = snapVisibilityEpsilon(face)
    for i = 1, #WORLD_AXIS_KEYS do
        local family = families[WORLD_AXIS_KEYS[i]]
        if family and globalFamilyHasBarrierBetween(family, step, rawU, rawV, candidate, eps) then
            return true
        end
    end

    return false
end

snapCandidateIsVisible = function(face, rawU, rawV, candidate)
    if not pointInPolygon2D(face.polygon, candidate.u, candidate.v, CONFIG.polygonTolerance) then
        return false
    end

    if segmentCrossesSurfaceBoundary(face, rawU, rawV, candidate) then
        return false
    end

    if face.globalGrid then
        return not segmentCrossesGlobalGrid(face, rawU, rawV, candidate)
    end

    return not segmentCrossesSurfaceGrid(face, rawU, rawV, candidate)
end

local function localSurfaceSnapCandidate(face, rawU, rawV)
    local selector = beginSnapSelector(face, rawU, rawV)
    local uLines = resetScratchArray("surfaceULines")
    local vLines = resetScratchArray("surfaceVLines")

    collectSurfaceAxisLines(face, "u", rawU, uLines)
    collectSurfaceAxisLines(face, "v", rawV, vLines)

    local uLineCount = uLines.count or 0
    local vLineCount = vLines.count or 0
    for i = 1, uLineCount do
        for j = 1, vLineCount do
            emitSurfaceGridPointCandidate(selector, uLines[i], vLines[j])
        end
    end

    emitSurfaceGridBoundaryCandidates(selector, uLines)
    emitSurfaceGridBoundaryCandidates(selector, vLines)
    emitCornerSnapCandidates(selector)

    return selector.best.valid and selector.best or nil
end

local function localGlobalSnapCandidate(face, rawU, rawV)
    local selector = beginSnapSelector(face, rawU, rawV)
    local lines = resetScratchArray("globalLines")

    collectGlobalFamilyLines(face, rawU, rawV, lines)
    emitGlobalGridPointCandidates(selector, lines)
    emitGlobalGridBoundaryCandidates(selector, lines)
    emitCornerSnapCandidates(selector)

    return selector.best.valid and selector.best or nil
end

local function localVisibleSnapCandidate(face, rawU, rawV)
    if face and face.globalGrid then
        return localGlobalSnapCandidate(face, rawU, rawV)
    end

    return localSurfaceSnapCandidate(face, rawU, rawV)
end

local function snapModeForVisibleCandidate(candidate)
    local kind = candidate and candidate.boundaryKind
    if kind == "grid_boundary" then return "grid_boundary" end
    if kind == "corner" then return "corner" end

    return "grid"
end

local function applyVisibleSnapCandidate(snapped, candidate)
    if not snapped or not candidate then return end

    snapped.gridU = candidate.gridU
    snapped.gridV = candidate.gridV
    snapped.gridUId = candidate.gridUId
    snapped.gridVId = candidate.gridVId
    snapped.indexU = candidate.indexU
    snapped.indexV = candidate.indexV
    snapped.percentU = candidate.percentU
    snapped.percentV = candidate.percentV
    snapped.globalAxisU = candidate.globalAxisU
    snapped.globalAxisV = candidate.globalAxisV
end

local function worldGridRenderCacheKey(settings)
    return ("%.6f"):format(worldGridStep(settings))
end

local function buildRenderOverlayFace(surfaceData, settings)
    if not surfaceData then return end

    local step = worldGridStep(settings)
    local cache = surfaceData._magicAlignRenderOverlayFaces
    if not cache then
        cache = {}
        surfaceData._magicAlignRenderOverlayFaces = cache
    end

    local key = ("%.6f"):format(step)
    local cached = cache[key]
    if cached then return cached end

    cached = {
        worldBSP = true,
        globalGrid = true,
        renderOnly = true,
        surface = surfaceData,
        polygon = surfaceData.polygon,
        worldCorners = surfaceData.vertices,
        normal = surfaceData.normal,
        origin = surfaceData.center,
        center = surfaceData.center,
        globalGridStep = step,
        globalGridOverlays = globalProjectionPairs(surfaceData)
    }
    cache[key] = cached

    return cached
end

local function buildRenderNeighborFaces(surfaceData, settings)
    local neighbors = surfaceData and surfaceData.neighbors
    if not istable(neighbors) or #neighbors == 0 then return end

    local cache = surfaceData._magicAlignRenderNeighborFaces
    if not cache then
        cache = {}
        surfaceData._magicAlignRenderNeighborFaces = cache
    end

    local key = worldGridRenderCacheKey(settings)
    local cached = cache[key]
    if cached then return cached end

    local out = {}
    for i = 1, #neighbors do
        local face = buildRenderOverlayFace(neighbors[i], settings)
        if face then
            out[#out + 1] = face
        end
    end

    cache[key] = out
    return out
end

local function buildFace(surfaceData, normal, rawU, rawV, settings)
    local face = {
        worldBSP = true,
        surface = surfaceData,
        lineWorldPoints = worldBSP.faceLineWorldPoints,
        polygon = surfaceData.polygon,
        worldCorners = surfaceData.vertices,
        normal = normal,
        origin = surfaceData.center,
        center = surfaceData.center,
        uMin = surfaceData.uMin,
        uMax = surfaceData.uMax,
        vMin = surfaceData.vMin,
        vMax = surfaceData.vMax
    }

    local globalGrid = usesGlobalGrid(settings)
    if globalGrid then
        configureGlobalFace(face, surfaceData, settings)
        face.globalGridNeighbors = buildRenderNeighborFaces(surfaceData, settings)
    end

    local snapFaceCoordinates = client.snapFaceCoordinates
    local snapped = globalGrid
        and snapGlobalFaceCoordinates(settings or {}, face, surfaceData, rawU, rawV)
        or isfunction(snapFaceCoordinates)
        and snapFaceCoordinates(settings or {}, face, rawU, rawV)
        or {
            u = math.Clamp(rawU, face.uMin, face.uMax),
            v = math.Clamp(rawV, face.vMin, face.vMax)
        }
    face.activeGridStep = activeStepFromSnapped(face, snapped)

    local u = snapped.u
    local v = snapped.v
    local snapMode = "grid"

    if not (settings and settings.shift) then
        local visibleCandidate = localVisibleSnapCandidate(face, rawU, rawV)
        if visibleCandidate then
            u = visibleCandidate.u
            v = visibleCandidate.v
            applyVisibleSnapCandidate(snapped, visibleCandidate)
            snapMode = snapModeForVisibleCandidate(visibleCandidate)
        elseif not pointInPolygon2D(face.polygon, u, v, CONFIG.polygonTolerance) then
            u = math.Clamp(rawU, face.uMin, face.uMax)
            v = math.Clamp(rawV, face.vMin, face.vMax)
            snapped.gridU = nil
            snapped.gridV = nil
            snapped.gridUId = nil
            snapped.gridVId = nil
            snapped.indexU = nil
            snapped.indexV = nil
            snapped.percentU = nil
            snapped.percentV = nil
            snapped.globalAxisU = nil
            snapped.globalAxisV = nil
            snapMode = "clamp"
        else
            snapMode = "grid"
        end
    end

    face.uSnap, face.vSnap = u, v
    face.snapGridU = snapped.gridU
    face.snapGridV = snapped.gridV
    face.snapGridUId = snapped.gridUId
    face.snapGridVId = snapped.gridVId
    face.snapIndexU, face.snapIndexV = snapped.indexU, snapped.indexV
    face.snapPercentU, face.snapPercentV = snapped.percentU, snapped.percentV
    face.snapGlobalAxisU = snapped.globalAxisU
    face.snapGlobalAxisV = snapped.globalAxisV
    face.snapMode = snapMode

    return face, worldFromUv(surfaceData, u, v)
end

local function sameSurfaceFastMatchFromTrace(tr)
    local surfaceData = worldBSP.lastTraceSurface
    if cache.status ~= cache.STATUS.READY
        or not surfaceData
        or not tr
        or not isvector(tr.HitPos)
        or not isvector(tr.HitNormal) then
        return
    end

    local hitPos = tr.HitPos
    if not pointInsideWorldBounds(surfaceData, hitPos) then return end

    local hitNormal = normalizedVec(tr.HitNormal, M.PICKING_VECTOR_EPSILON_SQR)
    if not hitNormal then return end

    local signedPlaneDist = signedPlaneDistance(surfaceData, hitPos.x, hitPos.y, hitPos.z)
    if math.abs(signedPlaneDist) > CONFIG.surfacePickTolerance then return end

    local normalDot = dot(surfaceData.normal, hitNormal)
    if math.abs(normalDot) < CONFIG.normalDotMin then return end

    local normal = surfaceData.normal
    local u, v = surfaceUvFromComponents(
        surfaceData,
        hitPos.x - normal.x * signedPlaneDist,
        hitPos.y - normal.y * signedPlaneDist,
        hitPos.z - normal.z * signedPlaneDist
    )

    if u < surfaceData.uMin - CONFIG.polygonTolerance
        or u > surfaceData.uMax + CONFIG.polygonTolerance
        or v < surfaceData.vMin - CONFIG.polygonTolerance
        or v > surfaceData.vMax + CONFIG.polygonTolerance then
        return
    end
    if not pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonTolerance) then return end
    if polygonEdgeDistance(surfaceData.polygon, u, v) <= CONFIG.sameSurfaceFastPathEdgeTolerance then return end

    traceScratch.sameSurfaceMatch = traceScratch.sameSurfaceMatch or {}
    return writeTraceMatch(traceScratch.sameSurfaceMatch, surfaceData, normalDot < 0 and -1 or 1, u, v, "same_surface")
end

function worldBSP.candidateFromTrace(tr, settings)
    if not settings or not settings.worldBspSnap or cache.status ~= cache.STATUS.READY then return end

    local match = sameSurfaceFastMatchFromTrace(tr) or findSurfaceForTrace(tr)
    if not match then return end

    local surfaceData = match.surface
    local normal = match.normalSign < 0 and -surfaceData.normal or surfaceData.normal
    local face, worldPos = buildFace(surfaceData, normal, match.u, match.v, settings)
    if not face or not isvector(worldPos) then return end
    worldBSP.lastTraceSurface = surfaceData

    local lastDebug = worldBSP.lastDebug or {}
    worldBSP.lastDebug = lastDebug
    lastDebug.match = match.match
    lastDebug.surfaceId = surfaceData.id
    lastDebug.rawU = match.u
    lastDebug.rawV = match.v
    lastDebug.snapU = face.uSnap
    lastDebug.snapV = face.vSnap
    lastDebug.snapGridUId = face.snapGridUId
    lastDebug.snapGridVId = face.snapGridVId
    lastDebug.snapIndexU = face.snapIndexU
    lastDebug.snapIndexV = face.snapIndexV
    lastDebug.snapMode = face.snapMode
    lastDebug.normal = surfaceData.normal
    lastDebug.worldPos = worldPos

    return {
        ent = M.WORLD_TARGET,
        localPos = worldPos,
        worldPos = worldPos,
        localNormal = normal,
        normal = normal,
        face = face,
        mode = settings.shift and "world_bsp_free_face" or "world_bsp_grid"
    }
end

local function formatVec(value)
    if not isvector(value) then return "nil" end

    return ("%.2f %.2f %.2f"):format(value.x, value.y, value.z)
end

function worldBSP.debugTrace(tr)
    tr = tr or (IsValid(LocalPlayer()) and LocalPlayer():GetEyeTrace() or nil)
    if not tr or not isvector(tr.HitPos) then
        print("Magic Align: World BSP debug: no valid eye trace.")
        return
    end

    local surfaces = querySurfaces(tr.HitPos) or {}
    local match = findSurfaceForTrace(tr)
    if not match then
        print(("Magic Align: World BSP debug: no match (status=%s, candidates=%d, hit=%s, normal=%s)."):format(
            tostring(cache.status),
            #surfaces,
            formatVec(tr.HitPos),
            formatVec(tr.HitNormal)
        ))
        return
    end

    local last = worldBSP.lastDebug
    local snapDetails = last and last.surfaceId == (match.surface and match.surface.id) and (" snap=(%.3f, %.3f %s %s%d/%s%d)"):format(
        tonumber(last.snapU) or 0,
        tonumber(last.snapV) or 0,
        tostring(last.snapMode or "?"),
        tostring(last.snapGridUId or "-"),
        tonumber(last.snapIndexU) or -1,
        tostring(last.snapGridVId or "-"),
        tonumber(last.snapIndexV) or -1
    ) or ""

    print(("Magic Align: World BSP debug: match=%s surface=%d candidates=%d raw=(%.3f, %.3f)%s hit=%s hitNormal=%s surfaceNormal=%s."):format(
        tostring(match.match or "unknown"),
        tonumber(match.surface and match.surface.id) or -1,
        #surfaces,
        tonumber(match.u) or 0,
        tonumber(match.v) or 0,
        snapDetails,
        formatVec(tr.HitPos),
        formatVec(tr.HitNormal),
        formatVec(match.surface and match.surface.normal)
    ))
end

if concommand and isfunction(concommand.Add) then
    if isfunction(concommand.Remove) then
        concommand.Remove("magic_align_world_bsp_debug_trace")
    end

    concommand.Add("magic_align_world_bsp_debug_trace", function()
        worldBSP.debugTrace()
    end)
end

return worldBSP
