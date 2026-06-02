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

local CACHE_VERSION = 15

local WORLD_AXIS_KEYS = { "x", "y", "z" }
local WORLD_GRID = {
    defaultStep = 16,
    minStep = 0.125,
    maxStep = 512,
    familyEpsilonSqr = 1e-10,
    pairDetEpsilon = 1e-8,
    extraLineAlphaScale = 0.62,
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
    displacementHitTexture = "**displacement**",
    displacementBoundsTolerance = 4,
    displacementPlaneTolerance = 4,
    displacementSurfacePickTolerance = 4,
    displacementNormalDotMin = 0.94,
    displacementEdgeProjectionTolerance = 4,
    displacementRayPickTolerance = 5,
    edgePickTolerance = 0.35,
    edgeProjectionTolerance = 2.5,
    polygonPickTolerance = 0.02,
    polygonTolerance = 0.001,
    rayPickTolerance = 2.5,
    rayPlaneDotMin = 0.0001,
    rayPreferScore = 0.4,
    rayNormalWeight = 1.5,
    queryCellRadius = 1,
    vertexMergeToleranceSqr = 1e-8,
    vertexNeighborCellSize = 16,
    vertexNeighborTolerance = 0.05,
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
    progressSnapshotInterval = 1,
    defaultBudgetMs = 2.5,
    minBudgetMs = 0.1,
    maxBudgetMs = 8
}

local BSP = {
    headerLumps = 64,
    headerSize = 1036,
    ident = "VBSP",
    lumpFaces = 7,
    lumpVertexes = 3,
    lumpSurfEdges = 13,
    lumpEdges = 12,
    lumpTexInfo = 6,
    lumpTexData = 2,
    lumpTexDataStringData = 43,
    lumpTexDataStringTable = 44,
    lumpDispInfo = 26,
    lumpDispVerts = 33,
    faceSize = 56,
    vertexSize = 12,
    edgeSize = 4,
    surfEdgeSize = 4,
    texInfoSize = 72,
    texDataSize = 32,
    dispInfoSize = 176,
    dispVertSize = 20,
    maxDispPower = 4,
    startPositionToleranceSqr = 1,
    compressedLumpId = "LZMA"
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
    cache.faceDescriptors = {}
    cache.gridDescriptors = {}
    cache.edgeIndex = {}
    cache.vertexIndex = {}
    cache.largeSurfaces = {}
    cache.sources = {}
    cache.total = 0
    cache.brushTotal = 0
    cache.brushProcessed = 0
    cache.cached = 0
    cache.skipped = 0
    cache.displacements = 0
    cache.displacementTotal = 0
    cache.displacementProcessed = 0
    cache.displacementSurfaces = 0
    cache.displacementSkipped = 0
    cache.displacementError = nil
    cache.neighborTotal = 0
    cache.neighborProcessed = 0
    cache.stage = status == cache.STATUS.BUILDING and "starting" or nil
    cache.stageTotal = 0
    cache.stageProcessed = 0
    cache.stageStartedAt = nil
    cache.stageSampleAt = nil
    cache.stageSampleProcessed = nil
    cache.stageSampleTotal = nil
    cache.progressSampleAt = nil
    cache.progressSampleDone = nil
    cache.progressSampleTotal = nil
    cache.progressSnapshot = nil
    cache.progressSnapshotAt = nil
    cache.startedAt = nil
    cache.readyAt = nil
    cache.worker = nil
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

local function setVectorComponents(out, x, y, z)
    if isvector(out) then
        out.x, out.y, out.z = x, y, z
        return out
    end

    return VectorP(x, y, z)
end

local function worldFromUvInto(surfaceData, u, v, out)
    local origin = surfaceData.origin
    local uAxis = surfaceData.uAxis
    local vAxis = surfaceData.vAxis

    return setVectorComponents(
        out,
        origin.x + uAxis.x * u + vAxis.x * v,
        origin.y + uAxis.y * u + vAxis.y * v,
        origin.z + uAxis.z * u + vAxis.z * v
    )
end

local function worldFromUv(surfaceData, u, v)
    return worldFromUvInto(surfaceData, u, v)
end

local function worldAxisFromUv(surfaceData, u, v, axisKey)
    local origin = surfaceData.origin
    local uAxis = surfaceData.uAxis
    local vAxis = surfaceData.vAxis

    if axisKey == "x" then
        return origin.x + uAxis.x * u + vAxis.x * v
    elseif axisKey == "y" then
        return origin.y + uAxis.y * u + vAxis.y * v
    end

    return origin.z + uAxis.z * u + vAxis.z * v
end

local function boundsDistanceSqr(surfaceData, x, y, z, tolerance)
    local mins = surfaceData and surfaceData.worldMins
    local maxs = surfaceData and surfaceData.worldMaxs
    if not isvector(mins) or not isvector(maxs) then return math.huge end

    local eps = tonumber(tolerance) or 0
    local dx = x < mins.x - eps and (mins.x - eps) - x or x > maxs.x + eps and x - (maxs.x + eps) or 0
    local dy = y < mins.y - eps and (mins.y - eps) - y or y > maxs.y + eps and y - (maxs.y + eps) or 0
    local dz = z < mins.z - eps and (mins.z - eps) - z or z > maxs.z + eps and z - (maxs.z + eps) or 0

    return dx * dx + dy * dy + dz * dz
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

function worldBSP.usesGlobalGrid(settings)
    return usesGlobalGrid(settings)
end

function worldBSP.shouldBuildCache(settings)
    return settings
        and settings.worldTarget ~= false
        and settings.worldBspSnap == true
        and usesGlobalGrid(settings)
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

local function addGlobalProjectionPair(out, seen, familyU, familyV, lineMode, alphaScale)
    if not familyU or not familyV or not familiesAreIndependent(familyU, familyV) then return end

    local key = familyU.axis .. ":" .. familyV.axis .. ":" .. tostring(lineMode or "full")
    if seen[key] then return end
    seen[key] = true

    local overlay = {
        axisU = familyU.axis,
        axisV = familyV.axis,
        lineMode = lineMode or "full"
    }

    if alphaScale then
        overlay.alphaScale = alphaScale
    end

    out[#out + 1] = overlay
    return overlay
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
            addGlobalProjectionPair(
                out,
                seen,
                horizontal[i],
                zFamily,
                i == 1 and "full" or "line_u",
                i == 1 and nil or WORLD_GRID.extraLineAlphaScale
            )
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

    do
        local rendered = {}
        for i = 1, #out do
            local overlay = out[i]
            local lineMode = overlay and overlay.lineMode or "full"
            if lineMode == "full" then
                rendered[overlay.axisU] = true
                rendered[overlay.axisV] = true
            elseif lineMode == "u" or lineMode == "line_u" then
                rendered[overlay.axisU] = true
            elseif lineMode == "v" or lineMode == "line_v" then
                rendered[overlay.axisV] = true
            end
        end

        for i = 1, #WORLD_AXIS_KEYS do
            local family = families[WORLD_AXIS_KEYS[i]]
            if family and not rendered[family.axis] then
                local partner, partnerWeight
                for j = 1, #WORLD_AXIS_KEYS do
                    local candidate = families[WORLD_AXIS_KEYS[j]]
                    if candidate and candidate ~= family and familiesAreIndependent(family, candidate) then
                        local weight = candidate.weight or 0
                        if not partnerWeight or weight > partnerWeight then
                            partner, partnerWeight = candidate, weight
                        end
                    end
                end

                if addGlobalProjectionPair(out, seen, family, partner, "line_u", WORLD_GRID.extraLineAlphaScale) then
                    rendered[family.axis] = true
                end
            end
        end
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

local function addClippedRangeValue(minValue, maxValue, uniqueCount, value, eps)
    if not minValue then
        return value, value, 1
    end

    if math.abs(value - minValue) <= eps or math.abs(value - maxValue) <= eps then
        return minValue, maxValue, uniqueCount
    end

    if value < minValue then
        minValue = value
    elseif value > maxValue then
        maxValue = value
    end

    return minValue, maxValue, uniqueCount + 1
end

local function clippedLineRange(face, axisKey, value)
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 3 then return end

    local eps = CONFIG.polygonTolerance
    local minOther, maxOther, uniqueCount
    local previous = polygon[#polygon]

    if axisKey == "u" then
        for i = 1, #polygon do
            local current = polygon[i]
            local a = previous.u
            local b = current.u
            local oa = previous.v
            local ob = current.v

            if math.abs(a - value) <= eps and math.abs(b - value) <= eps then
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, oa, eps)
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, ob, eps)
            elseif math.abs(a - b) > eps and value >= (a < b and a or b) - eps and value <= (a > b and a or b) + eps then
                local t = (value - a) / (b - a)
                if t >= -eps and t <= 1 + eps then
                    minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, oa + (ob - oa) * math.Clamp(t, 0, 1), eps)
                end
            elseif math.abs(a - value) <= eps then
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, oa, eps)
            elseif math.abs(b - value) <= eps then
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, ob, eps)
            end

            previous = current
        end
    else
        for i = 1, #polygon do
            local current = polygon[i]
            local a = previous.v
            local b = current.v
            local oa = previous.u
            local ob = current.u

            if math.abs(a - value) <= eps and math.abs(b - value) <= eps then
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, oa, eps)
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, ob, eps)
            elseif math.abs(a - b) > eps and value >= (a < b and a or b) - eps and value <= (a > b and a or b) + eps then
                local t = (value - a) / (b - a)
                if t >= -eps and t <= 1 + eps then
                    minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, oa + (ob - oa) * math.Clamp(t, 0, 1), eps)
                end
            elseif math.abs(a - value) <= eps then
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, oa, eps)
            elseif math.abs(b - value) <= eps then
                minOther, maxOther, uniqueCount = addClippedRangeValue(minOther, maxOther, uniqueCount, ob, eps)
            end

            previous = current
        end
    end

    if (uniqueCount or 0) < 2 then return end

    return minOther, maxOther
end

function worldBSP.faceLineWorldPoints(face, _, axisKey, value, outA, outB)
    local surfaceData = face and face.surface
    if not surfaceData then return end

    local minOther, maxOther = clippedLineRange(face, axisKey, value)
    if not minOther or not maxOther then return end

    if axisKey == "u" then
        return worldFromUvInto(surfaceData, value, minOther, outA), worldFromUvInto(surfaceData, value, maxOther, outB)
    end

    return worldFromUvInto(surfaceData, minOther, value, outA), worldFromUvInto(surfaceData, maxOther, value, outB)
end

local function surfaceMaterialName(surfaceInfo)
    local getMaterial = surfaceInfo and surfaceInfo.GetMaterial
    if not isfunction(getMaterial) then return end

    local ok, material = pcall(getMaterial, surfaceInfo)
    if not ok or material == nil then return end

    local getName = material.GetName
    if isfunction(getName) then
        local nameOk, name = pcall(getName, material)
        if nameOk and name ~= nil then
            return tostring(name), material
        end
    end

    return tostring(material), material
end

local function buildSurfaceData(surfaceInfo, index, source, sourceSurfaceIndex)
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
        source = source,
        sourceEnt = source and source.ent or nil,
        sourceIdentity = source and source.identity or nil,
        sourceEntityIndex = source and source.entityIndex or nil,
        sourceClass = source and source.class or nil,
        sourceModel = source and source.model or nil,
        sourceIsWorld = source and source.isWorld == true,
        sourceSurfaceIndex = sourceSurfaceIndex,
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
    surfaceData.materialName, surfaceData.material = surfaceMaterialName(surfaceInfo)

    surfaceData.globalFamilies = buildGlobalFamilies(surfaceData)

    for i = 1, #(surfaceData.edges or {}) do
        surfaceData.edges[i].surface = surfaceData
    end

    return surfaceData
end

function worldBSP.markCachedSurface(surfaceData)
    if not surfaceData then return end

    surfaceData._magicAlignWorldBspCacheVersion = CACHE_VERSION
    surfaceData._magicAlignWorldBspCacheMap = cache.map
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

local function vertexCellCoord(value)
    return math.floor(value / CONFIG.vertexNeighborCellSize)
end

local function vertexCellKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function addVertexToCell(key, surfaceData, index, vertex, uid)
    local cell = cache.vertexIndex[key]
    if not cell then
        cell = {}
        cache.vertexIndex[key] = cell
    end

    cell[#cell + 1] = {
        surface = surfaceData,
        index = index,
        vertex = vertex,
        uid = uid
    }
end

local function indexSurfaceVertices(surfaceData, nextCandidateUid)
    nextCandidateUid = tonumber(nextCandidateUid) or 0
    local vertexNeighborUids = {}
    surfaceData.vertexNeighborUids = vertexNeighborUids

    for i = 1, #(surfaceData.vertices or {}) do
        local vertex = surfaceData.vertices[i]
        if isvector(vertex) then
            nextCandidateUid = nextCandidateUid + 1
            vertexNeighborUids[i] = nextCandidateUid
            addVertexToCell(
                vertexCellKey(vertexCellCoord(vertex.x), vertexCellCoord(vertex.y), vertexCellCoord(vertex.z)),
                surfaceData,
                i,
                vertex,
                nextCandidateUid
            )
        end
    end

    return nextCandidateUid
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

local function indexSurfaceEdges(surfaceData, nextCandidateUid)
    nextCandidateUid = tonumber(nextCandidateUid) or 0

    for i = 1, #(surfaceData.edges or {}) do
        local edge = surfaceData.edges[i]
        if edge then
            nextCandidateUid = nextCandidateUid + 1
            edge.uid = nextCandidateUid

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

    return nextCandidateUid
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

worldBSP.neighborBuild = worldBSP.neighborBuild or {}

function worldBSP.neighborBuild.surfacesAreNeighbors(surfaceA, surfaceB)
    local seenA = surfaceA and surfaceA.neighborSeen
    if seenA and seenA[surfaceB] then return true end

    local seenB = surfaceB and surfaceB.neighborSeen
    return seenB and seenB[surfaceA] == true
end

function worldBSP.setBuildStage(stage, total, processed)
    local stageNow = now()
    cache.stage = stage
    cache.stageTotal = math.max(tonumber(total) or 0, 0)
    cache.stageProcessed = math.Clamp(tonumber(processed) or 0, 0, cache.stageTotal)
    cache.stageStartedAt = stageNow
    cache.stageSampleAt = stageNow
    cache.stageSampleProcessed = cache.stageProcessed
    cache.stageSampleTotal = cache.stageTotal
end

function worldBSP.updateBuildStage(processed, total)
    if total ~= nil then
        cache.stageTotal = math.max(tonumber(total) or 0, 0)
    end

    local stageTotal = tonumber(cache.stageTotal) or 0
    cache.stageProcessed = stageTotal > 0
        and math.Clamp(tonumber(processed) or 0, 0, stageTotal)
        or math.max(tonumber(processed) or 0, 0)

    if cache.stageSampleTotal ~= nil and cache.stageSampleTotal ~= stageTotal then
        cache.stageSampleAt = now()
        cache.stageSampleProcessed = cache.stageProcessed
        cache.stageSampleTotal = stageTotal
    end
end

local function estimateRemainingFromFraction(elapsed, fraction)
    if not fraction or fraction <= 0 or fraction >= 1 then return nil end
    elapsed = tonumber(elapsed) or 0
    if elapsed <= 0 then return nil end

    return elapsed * (1 - fraction) / fraction
end

local function estimateRemainingFromSample(currentTime, done, total, sampleAt, sampleDone, sampleTotal)
    done = tonumber(done)
    total = tonumber(total)
    sampleAt = tonumber(sampleAt)
    sampleDone = tonumber(sampleDone)
    sampleTotal = tonumber(sampleTotal)

    if not done or not total or total <= 0 or done <= 0 or done >= total then return nil end
    if not sampleAt or not sampleDone or sampleTotal ~= total then return nil end

    local deltaDone = done - sampleDone
    local deltaTime = (tonumber(currentTime) or 0) - sampleAt
    if deltaDone <= 0 or deltaTime <= 0 then return nil end

    return ((total - done) / deltaDone) * deltaTime
end

local function maxProgressEta(...)
    local eta
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        value = tonumber(value)
        if value and value >= 0 and value ~= math.huge and value == value then
            eta = eta and math.max(eta, value) or value
        end
    end

    return eta
end

function worldBSP.cacheOverallProgress()
    if cache.status == cache.STATUS.READY then
        return 1, 1
    end

    local done = 0
    local total = 0

    local brushTotal = tonumber(cache.brushTotal) or tonumber(cache.total) or 0
    if brushTotal > 0 then
        total = total + brushTotal
        done = done + math.Clamp(tonumber(cache.brushProcessed) or 0, 0, brushTotal)
    end

    local displacementTotal = tonumber(cache.displacementTotal) or 0
    local displacementProcessed = tonumber(cache.displacementProcessed) or 0
    if displacementTotal > 0 or displacementProcessed > 0 then
        displacementTotal = math.max(displacementTotal, displacementProcessed)
        total = total + displacementTotal
        done = done + math.Clamp(displacementProcessed, 0, displacementTotal)
    end

    local neighborTotal = tonumber(cache.neighborTotal) or 0
    local neighborProcessed = tonumber(cache.neighborProcessed) or 0
    if neighborTotal > 0 or neighborProcessed > 0 then
        neighborTotal = math.max(neighborTotal, neighborProcessed)
        total = total + neighborTotal
        done = done + math.Clamp(neighborProcessed, 0, neighborTotal)
    end

    if total <= 0 then
        local stageTotal = tonumber(cache.stageTotal) or 0
        if stageTotal <= 0 then return nil, nil end
        return math.Clamp(tonumber(cache.stageProcessed) or 0, 0, stageTotal), stageTotal
    end

    return done, total
end

function worldBSP.cacheProgress()
    local currentStatus = cache.status or cache.STATUS.IDLE
    local currentTime = now()
    local startedAt = tonumber(cache.startedAt)
    local readyAt = tonumber(cache.readyAt)
    local elapsed = startedAt and math.max((readyAt or currentTime) - startedAt, 0) or 0
    local done, total = worldBSP.cacheOverallProgress()
    local fraction = done and total and total > 0 and math.Clamp(done / total, 0, 1) or nil
    local overallEta
    local recentEta

    if currentStatus == cache.STATUS.BUILDING and fraction and fraction > 0 and fraction < 1 then
        overallEta = estimateRemainingFromFraction(elapsed, fraction)
        recentEta = estimateRemainingFromSample(
            currentTime,
            done,
            total,
            cache.progressSampleAt,
            cache.progressSampleDone,
            cache.progressSampleTotal
        )
    elseif currentStatus == cache.STATUS.READY then
        fraction = 1
        overallEta = 0
    end

    local stageTotal = tonumber(cache.stageTotal) or 0
    local stageProcessed = tonumber(cache.stageProcessed) or 0
    local stageFraction = stageTotal > 0 and math.Clamp(stageProcessed / stageTotal, 0, 1) or nil
    local stageElapsed = cache.stageStartedAt and math.max(currentTime - cache.stageStartedAt, 0) or 0
    local stageEta
    local stageRecentEta
    if currentStatus == cache.STATUS.BUILDING and stageFraction and stageFraction > 0 and stageFraction < 1 then
        stageEta = estimateRemainingFromFraction(stageElapsed, stageFraction)
        stageRecentEta = estimateRemainingFromSample(
            currentTime,
            stageProcessed,
            stageTotal,
            cache.stageSampleAt,
            cache.stageSampleProcessed,
            cache.stageSampleTotal
        )
    end

    local eta = maxProgressEta(overallEta, recentEta, stageEta, stageRecentEta)
    if currentStatus == cache.STATUS.READY then
        eta = 0
    end

    if currentStatus == cache.STATUS.BUILDING then
        if done and total and total > 0 then
            local sampleDone = tonumber(cache.progressSampleDone)
            if cache.progressSampleTotal ~= total or not sampleDone or done > sampleDone then
                cache.progressSampleAt = currentTime
                cache.progressSampleDone = done
                cache.progressSampleTotal = total
            end
        end

        if stageTotal > 0 then
            local sampleProcessed = tonumber(cache.stageSampleProcessed)
            if cache.stageSampleTotal ~= stageTotal or not sampleProcessed or stageProcessed > sampleProcessed then
                cache.stageSampleAt = currentTime
                cache.stageSampleProcessed = stageProcessed
                cache.stageSampleTotal = stageTotal
            end
        end
    else
        cache.progressSampleAt = nil
        cache.progressSampleDone = nil
        cache.progressSampleTotal = nil
        cache.stageSampleAt = nil
        cache.stageSampleProcessed = nil
        cache.stageSampleTotal = nil
    end

    return {
        status = currentStatus,
        stage = cache.stage,
        percent = fraction and fraction * 100 or nil,
        fraction = fraction,
        eta = eta,
        overallEta = overallEta,
        recentEta = recentEta,
        elapsed = elapsed,
        done = done,
        total = total,
        stagePercent = stageFraction and stageFraction * 100 or nil,
        stageFraction = stageFraction,
        stageEta = stageEta,
        stageRecentEta = stageRecentEta,
        stageElapsed = stageElapsed,
        stageDone = stageProcessed,
        stageTotal = stageTotal
    }
end

function worldBSP.refreshCacheProgressSnapshot(force)
    local currentTime = now()
    local snapshotAt = tonumber(cache.progressSnapshotAt)
    if not force
        and cache.progressSnapshot
        and snapshotAt
        and currentTime - snapshotAt < CONFIG.progressSnapshotInterval then
        return cache.progressSnapshot
    end

    local progress = worldBSP.cacheProgress()
    progress.sampledAt = currentTime
    cache.progressSnapshot = progress
    cache.progressSnapshotAt = currentTime

    return progress
end

function worldBSP.cacheProgressSnapshot()
    return cache.progressSnapshot
end

function worldBSP.formatProgressPercent(value)
    if value == nil then return "n/a" end
    return ("%.1f%%"):format(math.Clamp(tonumber(value) or 0, 0, 100))
end

function worldBSP.formatProgressSeconds(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds < 0 or seconds == math.huge or seconds ~= seconds then
        return "n/a"
    end

    if seconds >= 60 then
        return ("%dm%02ds"):format(math.floor(seconds / 60), math.floor(seconds % 60))
    end

    return ("%.1fs"):format(seconds)
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

    local tolerance = tonumber(CONFIG.edgeCollinearTolerance) or 0
    if tolerance < 0 then return false end

    local offset = edgeB.a - edgeA.a
    local lineOffset = cross(offset, edgeA.dir)
    if M.VectorLengthSqrPrecise(lineOffset) > tolerance * tolerance then return false end

    return edgeIntervalsOverlap(edgeA, edgeB)
end

local function verticesAreAdjacent(surfaceData, vertex, other)
    if not surfaceData or not other or surfaceData == other.surface then return false end
    if not isvector(vertex) or not isvector(other.vertex) then return false end

    local tolerance = tonumber(CONFIG.vertexNeighborTolerance) or 0
    if tolerance < 0 then return false end

    local otherVertex = other.vertex
    local dx = otherVertex.x - vertex.x
    if math.abs(dx) > tolerance then return false end

    local dy = otherVertex.y - vertex.y
    if math.abs(dy) > tolerance then return false end

    local dz = otherVertex.z - vertex.z
    if math.abs(dz) > tolerance then return false end

    return dx * dx + dy * dy + dz * dz <= tolerance * tolerance
end

function worldBSP.neighborBuild.markCandidatePair(seenPairs, uidA, uidB)
    if not uidA or not uidB or uidA >= uidB then return false end

    local seenForA = seenPairs[uidA]
    if seenForA then
        if seenForA[uidB] then return false end
    else
        seenForA = {}
        seenPairs[uidA] = seenForA
    end

    seenForA[uidB] = true
    return true
end

function worldBSP.neighborBuild.walkSurfaceEdgePairs(surfaceData, seenPairs, onPair)
    local count = 0
    local markCandidatePair = worldBSP.neighborBuild.markCandidatePair

    for edgeIndex = 1, #(surfaceData.edges or {}) do
        local edge = surfaceData.edges[edgeIndex]
        local uid = edge and edge.uid
        if uid then
            local minX, minY, minZ, maxX, maxY, maxZ = edgeCellBounds(edge)
            for x = minX, maxX do
                for y = minY, maxY do
                    for z = minZ, maxZ do
                        local cell = cache.edgeIndex[edgeCellKey(x, y, z)]
                        if cell then
                            for j = 1, #cell do
                                local other = cell[j]
                                local otherSurface = other and other.surface
                                if otherSurface
                                    and otherSurface ~= surfaceData
                                    and markCandidatePair(seenPairs, uid, other.uid) then
                                    count = count + 1
                                    if onPair then
                                        onPair(surfaceData, edge, otherSurface, other)
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

    return count
end

function worldBSP.neighborBuild.walkSurfaceVertexPairs(surfaceData, seenPairs, onPair)
    local count = 0
    local vertexNeighborUids = surfaceData.vertexNeighborUids
    local markCandidatePair = worldBSP.neighborBuild.markCandidatePair

    for vertexIndex = 1, #(surfaceData.vertices or {}) do
        local vertex = surfaceData.vertices[vertexIndex]
        local uid = vertexNeighborUids and vertexNeighborUids[vertexIndex]
        if uid and isvector(vertex) then
            local cellX = vertexCellCoord(vertex.x)
            local cellY = vertexCellCoord(vertex.y)
            local cellZ = vertexCellCoord(vertex.z)
            for x = cellX - 1, cellX + 1 do
                for y = cellY - 1, cellY + 1 do
                    for z = cellZ - 1, cellZ + 1 do
                        local cell = cache.vertexIndex[vertexCellKey(x, y, z)]
                        if cell then
                            for j = 1, #cell do
                                local other = cell[j]
                                local otherSurface = other and other.surface
                                if otherSurface
                                    and otherSurface ~= surfaceData
                                    and markCandidatePair(seenPairs, uid, other.uid) then
                                    count = count + 1
                                    if onPair then
                                        onPair(surfaceData, vertex, otherSurface, other)
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

    return count
end

function worldBSP.neighborBuild.countCandidatePairs()
    local total = 0
    local edgePairs = {}
    local vertexPairs = {}
    local surfaces = cache.surfaces or {}
    local walkSurfaceEdgePairs = worldBSP.neighborBuild.walkSurfaceEdgePairs
    local walkSurfaceVertexPairs = worldBSP.neighborBuild.walkSurfaceVertexPairs

    worldBSP.setBuildStage("neighbor_count", #surfaces, 0)
    for i = 1, #surfaces do
        local surfaceData = surfaces[i]
        total = total + walkSurfaceEdgePairs(surfaceData, edgePairs)
        total = total + walkSurfaceVertexPairs(surfaceData, vertexPairs)
        worldBSP.updateBuildStage(i)
        maybeYield()
    end

    return total
end

function worldBSP.neighborBuild.updateLinkProgress(processed)
    cache.neighborProcessed = processed
    cache.stageProcessed = processed
end

function worldBSP.neighborBuild.linkCandidatePairs(total)
    local processed = 0
    local edgePairs = {}
    local vertexPairs = {}
    local surfaces = cache.surfaces or {}
    local helpers = worldBSP.neighborBuild
    local walkSurfaceEdgePairs = helpers.walkSurfaceEdgePairs
    local walkSurfaceVertexPairs = helpers.walkSurfaceVertexPairs

    local function advance()
        processed = processed + 1
        helpers.updateLinkProgress(processed)
    end

    local function linkEdgePair(surfaceData, edge, otherSurface, other)
        advance()
        if helpers.surfacesAreNeighbors(surfaceData, otherSurface) then return end

        if edgesAreAdjacent(edge, other) then
            addSurfaceNeighbor(surfaceData, otherSurface)
            addSurfaceNeighbor(otherSurface, surfaceData)
        end
    end

    local function linkVertexPair(surfaceData, vertex, otherSurface, other)
        advance()
        if helpers.surfacesAreNeighbors(surfaceData, otherSurface) then return end

        if verticesAreAdjacent(surfaceData, vertex, other) then
            addSurfaceNeighbor(surfaceData, otherSurface)
            addSurfaceNeighbor(otherSurface, surfaceData)
        end
    end

    for i = 1, #surfaces do
        local surfaceData = surfaces[i]
        walkSurfaceEdgePairs(surfaceData, edgePairs, linkEdgePair)
        walkSurfaceVertexPairs(surfaceData, vertexPairs, linkVertexPair)
        worldBSP.updateBuildStage(processed)
    end

    cache.neighborTotal = math.max(tonumber(total) or 0, processed)
    helpers.updateLinkProgress(processed)
    worldBSP.updateBuildStage(processed, cache.neighborTotal)
end

local function buildDirectNeighborCache()
    cache.edgeIndex = {}
    cache.vertexIndex = {}
    cache.neighborTotal = 0
    cache.neighborProcessed = 0
    worldBSP.setBuildStage("neighbor_index", #(cache.surfaces or {}), 0)

    local nextCandidateUid = 0
    for i = 1, #(cache.surfaces or {}) do
        local surfaceData = cache.surfaces[i]
        surfaceData.neighbors = {}
        surfaceData.neighborSeen = {}
        nextCandidateUid = indexSurfaceEdges(surfaceData, nextCandidateUid)
        nextCandidateUid = indexSurfaceVertices(surfaceData, nextCandidateUid)
        worldBSP.updateBuildStage(i)
        maybeYield()
    end

    local neighborHelpers = worldBSP.neighborBuild
    local neighborWorkTotal = neighborHelpers.countCandidatePairs()
    cache.neighborTotal = neighborWorkTotal
    cache.neighborProcessed = 0
    worldBSP.setBuildStage("neighbor_links", neighborWorkTotal, 0)
    neighborHelpers.linkCandidatePairs(neighborWorkTotal)

    for i = 1, #(cache.surfaces or {}) do
        cache.surfaces[i].neighborSeen = nil
    end
end

local function finishBuild()
    cache.status = cache.STATUS.READY
    cache.readyAt = now()
    cache.worker = nil
    cache.stage = "ready"
    cache.stageProcessed = cache.stageTotal

    local seconds = math.max(cache.readyAt - (cache.startedAt or cache.readyAt), 0)
    local displacementInfo = ""
    if (cache.displacementSurfaces or 0) > 0 or (cache.displacementSkipped or 0) > 0 then
        displacementInfo = (", %d displacement surfaces from %d displacements, %d displacement skips"):format(
            cache.displacementSurfaces or 0,
            cache.displacements or 0,
            cache.displacementSkipped or 0
        )
    elseif cache.displacementError then
        displacementInfo = ", displacement parser: " .. tostring(cache.displacementError)
    end

    print(("Magic Align: World BSP snapping ready in %.2fs (%d surfaces cached, %d skipped%s)."):format(
        seconds,
        cache.cached or 0,
        cache.skipped or 0,
        displacementInfo
    ))

    worldBSP.refreshCacheProgressSnapshot(true)
end

local function entityIndex(ent)
    local entIndex = ent and ent.EntIndex
    if not isfunction(entIndex) then return end

    local ok, index = pcall(entIndex, ent)
    if ok then return tonumber(index) end
end

local function entityClass(ent)
    local getClass = ent and ent.GetClass
    if not isfunction(getClass) then return end

    local ok, class = pcall(getClass, ent)
    if ok and class ~= nil then return tostring(class) end
end

local function entityModel(ent)
    local getModel = ent and ent.GetModel
    if not isfunction(getModel) then return end

    local ok, model = pcall(getModel, ent)
    if ok and model ~= nil then return tostring(model) end
end

local function isWorldBrushEntity(ent)
    if game and isfunction(game.GetWorld) and ent == game.GetWorld() then
        return true
    end

    return entityIndex(ent) == 0
end

local function entityIdentity(ent)
    if isWorldBrushEntity(ent) then
        return "world:0"
    end

    return ("%s:%s:%s"):format(
        tostring(entityIndex(ent) or "nil"),
        tostring(entityClass(ent) or ""),
        tostring(entityModel(ent) or "")
    )
end

local function readWorldBrushSurfaceSources()
    local candidates = {}
    local count = 0
    local seen = {}

    local function addCandidate(ent)
        if ent == nil then return end

        local key = entityIndex(ent) or tostring(ent)
        if seen[key] then
            return
        end
        seen[key] = true

        count = count + 1
        candidates[count] = ent
    end

    if game and isfunction(game.GetWorld) then
        addCandidate(game.GetWorld())
    end
    if isfunction(Entity) then
        addCandidate(Entity(0))
    end
    if ents and isfunction(ents.GetAll) then
        local all = ents.GetAll()
        if istable(all) then
            for i = 1, #all do
                addCandidate(all[i])
            end
        end
    end

    local sources = {}
    for i = 1, count do
        local ent = candidates[i]
        local getBrushSurfaces = ent and ent.GetBrushSurfaces or nil
        if isfunction(getBrushSurfaces) then
            local ok, surfaces = pcall(getBrushSurfaces, ent)
            if ok and istable(surfaces) and #surfaces > 0 then
                local sourceIndex = #sources + 1
                sources[sourceIndex] = {
                    ent = ent,
                    identity = entityIdentity(ent),
                    entityIndex = entityIndex(ent),
                    class = entityClass(ent),
                    model = entityModel(ent),
                    isWorld = isWorldBrushEntity(ent),
                    surfaces = surfaces,
                    surfaceCount = #surfaces
                }
            end
        end
    end

    if #sources == 0 then return end
    return sources
end

local function bspCanRead(data, offset, length)
    return isstring(data)
        and offset
        and length
        and offset >= 0
        and length >= 0
        and offset + length <= #data
end

local function bspByte(data, offset)
    return string.byte(data, offset + 1, offset + 1) or 0
end

local function bspReadUInt16(data, offset)
    if not bspCanRead(data, offset, 2) then return 0 end

    return bspByte(data, offset) + bspByte(data, offset + 1) * 256
end

local function bspReadInt16(data, offset)
    local value = bspReadUInt16(data, offset)
    if value >= 0x8000 then value = value - 0x10000 end
    return value
end

local function bspReadUInt32(data, offset)
    if not bspCanRead(data, offset, 4) then return 0 end

    return bspByte(data, offset)
        + bspByte(data, offset + 1) * 0x100
        + bspByte(data, offset + 2) * 0x10000
        + bspByte(data, offset + 3) * 0x1000000
end

local function bspReadInt32(data, offset)
    local value = bspReadUInt32(data, offset)
    if value >= 0x80000000 then value = value - 0x100000000 end
    return value
end

local function bspReadFloat(data, offset)
    local value = bspReadUInt32(data, offset)
    local sign = 1
    if value >= 0x80000000 then
        sign = -1
        value = value - 0x80000000
    end

    local exponent = math.floor(value / 0x800000)
    local mantissa = value - exponent * 0x800000
    if exponent == 255 then
        return sign * math.huge
    elseif exponent == 0 then
        return sign * (mantissa / 0x800000) * 2 ^ (-126)
    end

    return sign * (1 + mantissa / 0x800000) * 2 ^ (exponent - 127)
end

local function bspReadVector(data, offset)
    if not bspCanRead(data, offset, 12) then return end

    return VectorP(
        bspReadFloat(data, offset),
        bspReadFloat(data, offset + 4),
        bspReadFloat(data, offset + 8)
    )
end

local function bspReadCString(data, offset, maxLength)
    if not bspCanRead(data, offset, 1) then return end

    local limit = math.min(#data, offset + (tonumber(maxLength) or 256))
    local first = offset + 1
    for i = first, limit do
        if string.byte(data, i, i) == 0 then
            return string.sub(data, first, i - 1)
        end
    end

    return string.sub(data, first, limit)
end

local function readCurrentMapBspData()
    if not (file and isfunction(file.Read)) then
        return nil, "file.Read unavailable"
    end

    local map = currentMap()
    if map == "" then
        return nil, "map name unavailable"
    end

    local path = "maps/" .. map .. ".bsp"
    local data = file.Read(path, "GAME")
    if not isstring(data) or #data == 0 then
        return nil, "could not read " .. path
    end

    return data
end

local function readBspHeader(data)
    if not bspCanRead(data, 0, BSP.headerSize) then
        return nil, "BSP header is incomplete"
    end
    if string.sub(data, 1, 4) ~= BSP.ident then
        return nil, "BSP header magic is not VBSP"
    end

    local header = {
        version = bspReadInt32(data, 4),
        lumps = {},
        mapRevision = bspReadInt32(data, 8 + BSP.headerLumps * 16)
    }

    for i = 0, BSP.headerLumps - 1 do
        local offset = 8 + i * 16
        header.lumps[i] = {
            fileofs = bspReadInt32(data, offset),
            filelen = bspReadInt32(data, offset + 4),
            version = bspReadInt32(data, offset + 8),
            fourCC = bspReadUInt32(data, offset + 12)
        }
    end

    return header
end

local function bspLump(header, id)
    return header and header.lumps and header.lumps[id]
end

local function bspLumpCount(header, id, stride)
    local lump = bspLump(header, id)
    if not lump or (lump.filelen or 0) <= 0 or (stride or 0) <= 0 then return 0 end

    return math.floor(lump.filelen / stride)
end

local function bspLumpIsReadable(data, lump)
    return lump and lump.fileofs and lump.filelen and lump.filelen > 0
        and bspCanRead(data, lump.fileofs, lump.filelen)
end

local function bspLumpIsCompressed(data, lump)
    if not bspLumpIsReadable(data, lump) then return false end
    if (tonumber(lump.fourCC) or 0) ~= 0 then return true end

    return string.sub(data, lump.fileofs + 1, lump.fileofs + 4) == BSP.compressedLumpId
end

local function requiredBspDisplacementLumpsReadable(data, header)
    local required = {
        BSP.lumpFaces,
        BSP.lumpVertexes,
        BSP.lumpSurfEdges,
        BSP.lumpEdges,
        BSP.lumpDispInfo,
        BSP.lumpDispVerts
    }

    for i = 1, #required do
        local id = required[i]
        local lump = bspLump(header, id)
        if not bspLumpIsReadable(data, lump) then
            return false, "required lump " .. tostring(id) .. " is missing"
        end
        if bspLumpIsCompressed(data, lump) then
            return false, "required lump " .. tostring(id) .. " is LZMA-compressed"
        end
    end

    return true
end

local function readBspVertex(data, header, index)
    local lump = bspLump(header, BSP.lumpVertexes)
    local count = bspLumpCount(header, BSP.lumpVertexes, BSP.vertexSize)
    index = tonumber(index) or -1
    if index < 0 or index >= count then return end

    return bspReadVector(data, lump.fileofs + index * BSP.vertexSize)
end

local function readBspFace(data, header, index)
    local lump = bspLump(header, BSP.lumpFaces)
    local count = bspLumpCount(header, BSP.lumpFaces, BSP.faceSize)
    index = tonumber(index) or -1
    if index < 0 or index >= count then return end

    local offset = lump.fileofs + index * BSP.faceSize
    return {
        index = index,
        firstEdge = bspReadInt32(data, offset + 4),
        numEdges = bspReadInt16(data, offset + 8),
        texInfo = bspReadInt16(data, offset + 10),
        dispInfo = bspReadInt16(data, offset + 12)
    }
end

local function readBspFaceVertices(data, header, face)
    if not face or not face.firstEdge or not face.numEdges or face.numEdges < 3 then return end

    local surfEdgeLump = bspLump(header, BSP.lumpSurfEdges)
    local edgeLump = bspLump(header, BSP.lumpEdges)
    local surfEdgeCount = bspLumpCount(header, BSP.lumpSurfEdges, BSP.surfEdgeSize)
    local edgeCount = bspLumpCount(header, BSP.lumpEdges, BSP.edgeSize)
    if not surfEdgeLump or not edgeLump then return end

    local vertices = {}
    for i = 0, face.numEdges - 1 do
        local surfEdgeIndex = face.firstEdge + i
        if surfEdgeIndex < 0 or surfEdgeIndex >= surfEdgeCount then return end

        local surfEdge = bspReadInt32(data, surfEdgeLump.fileofs + surfEdgeIndex * BSP.surfEdgeSize)
        local edgeIndex = math.abs(surfEdge)
        if edgeIndex < 0 or edgeIndex >= edgeCount then return end

        local edgeOffset = edgeLump.fileofs + edgeIndex * BSP.edgeSize
        local vertexIndex = surfEdge >= 0
            and bspReadUInt16(data, edgeOffset)
            or bspReadUInt16(data, edgeOffset + 2)
        local vertex = readBspVertex(data, header, vertexIndex)
        if not vertex then return end

        vertices[#vertices + 1] = vertex
    end

    return vertices
end

local function readBspTextureName(data, header, texInfoIndex)
    texInfoIndex = tonumber(texInfoIndex) or -1
    if texInfoIndex < 0 then return end

    local texInfoLump = bspLump(header, BSP.lumpTexInfo)
    local texDataLump = bspLump(header, BSP.lumpTexData)
    local stringTableLump = bspLump(header, BSP.lumpTexDataStringTable)
    local stringDataLump = bspLump(header, BSP.lumpTexDataStringData)
    if not (bspLumpIsReadable(data, texInfoLump)
        and bspLumpIsReadable(data, texDataLump)
        and bspLumpIsReadable(data, stringTableLump)
        and bspLumpIsReadable(data, stringDataLump)) then
        return
    end
    if bspLumpIsCompressed(data, texInfoLump)
        or bspLumpIsCompressed(data, texDataLump)
        or bspLumpIsCompressed(data, stringTableLump)
        or bspLumpIsCompressed(data, stringDataLump) then
        return
    end

    local texInfoCount = bspLumpCount(header, BSP.lumpTexInfo, BSP.texInfoSize)
    if texInfoIndex >= texInfoCount then return end

    local texInfoOffset = texInfoLump.fileofs + texInfoIndex * BSP.texInfoSize
    local texDataIndex = bspReadInt32(data, texInfoOffset + 68)
    local texDataCount = bspLumpCount(header, BSP.lumpTexData, BSP.texDataSize)
    if texDataIndex < 0 or texDataIndex >= texDataCount then return end

    local texDataOffset = texDataLump.fileofs + texDataIndex * BSP.texDataSize
    local nameIndex = bspReadInt32(data, texDataOffset + 12)
    local nameCount = math.floor((stringTableLump.filelen or 0) / 4)
    if nameIndex < 0 or nameIndex >= nameCount then return end

    local stringOffset = bspReadInt32(data, stringTableLump.fileofs + nameIndex * 4)
    if stringOffset < 0 or stringOffset >= stringDataLump.filelen then return end

    return bspReadCString(data, stringDataLump.fileofs + stringOffset, 256)
end

local function readBspDispInfo(data, header, index)
    local lump = bspLump(header, BSP.lumpDispInfo)
    local count = bspLumpCount(header, BSP.lumpDispInfo, BSP.dispInfoSize)
    index = tonumber(index) or -1
    if index < 0 or index >= count then return end

    local offset = lump.fileofs + index * BSP.dispInfoSize
    return {
        index = index,
        startPosition = bspReadVector(data, offset),
        dispVertStart = bspReadInt32(data, offset + 12),
        power = bspReadInt32(data, offset + 20),
        mapFace = bspReadUInt16(data, offset + 36)
    }
end

local function nearestDisplacementStartCorner(vertices, startPosition)
    if not istable(vertices) or not isvector(startPosition) then return end

    local bestIndex, bestDist
    for i = 1, #vertices do
        local vertex = vertices[i]
        if isvector(vertex) then
            local dx = vertex.x - startPosition.x
            local dy = vertex.y - startPosition.y
            local dz = vertex.z - startPosition.z
            local dist = dx * dx + dy * dy + dz * dz
            if not bestDist or dist < bestDist then
                bestIndex = i
                bestDist = dist
            end
        end
    end

    return bestIndex, bestDist
end

local function orderedDisplacementCorners(faceVertices, startPosition)
    if not istable(faceVertices) or #faceVertices ~= 4 then
        return nil, "base face is not a quad"
    end

    local startIndex, startDist = nearestDisplacementStartCorner(faceVertices, startPosition)
    if not startIndex then
        return nil, "start corner unavailable"
    end
    if startDist and startDist > BSP.startPositionToleranceSqr then
        return nil, "start corner mismatch"
    end

    local count = #faceVertices
    return {
        c00 = faceVertices[startIndex],
        c01 = faceVertices[startIndex % count + 1],
        c11 = faceVertices[(startIndex + 1) % count + 1],
        c10 = faceVertices[(startIndex - 2) % count + 1]
    }
end

local function displacementBasePoint(corners, s, t)
    local c00 = corners.c00
    local c10 = corners.c10
    local c01 = corners.c01
    local c11 = corners.c11
    local a = (1 - s) * (1 - t)
    local b = s * (1 - t)
    local c = (1 - s) * t
    local d = s * t

    return VectorP(
        c00.x * a + c10.x * b + c01.x * c + c11.x * d,
        c00.y * a + c10.y * b + c01.y * c + c11.y * d,
        c00.z * a + c10.z * b + c01.z * c + c11.z * d
    )
end

local function displacementVertexPosition(data, header, info, corners, side, row, col)
    local dispVertsLump = bspLump(header, BSP.lumpDispVerts)
    local dispVertCount = bspLumpCount(header, BSP.lumpDispVerts, BSP.dispVertSize)
    local gridSize = side + 1
    local dispVertIndex = (info.dispVertStart or -1) + row * gridSize + col
    if dispVertIndex < 0 or dispVertIndex >= dispVertCount then return end

    local offset = dispVertsLump.fileofs + dispVertIndex * BSP.dispVertSize
    local dispVector = bspReadVector(data, offset)
    local dispDistance = bspReadFloat(data, offset + 12)
    if not dispVector or not dispDistance then return end

    local base = displacementBasePoint(corners, col / side, row / side)
    return VectorP(
        base.x + dispVector.x * dispDistance,
        base.y + dispVector.y * dispDistance,
        base.z + dispVector.z * dispDistance
    )
end

local function buildDisplacementVertexGrid(data, header, info, corners)
    local power = tonumber(info and info.power) or 0
    if power < 2 or power > BSP.maxDispPower then
        return nil, "unsupported power"
    end

    local side = 2 ^ power
    local gridSize = side + 1
    local grid = {}

    for row = 0, side do
        for col = 0, side do
            local vertex = displacementVertexPosition(data, header, info, corners, side, row, col)
            if not vertex then
                return nil, "disp vertex out of range"
            end

            grid[row * gridSize + col + 1] = vertex
        end
    end

    return grid, side, gridSize
end

local function displacementGridVertex(grid, gridSize, row, col)
    return grid[row * gridSize + col + 1]
end

local function makeDisplacementSurfaceInfo(vertices, materialName)
    return {
        GetVertices = function()
            return vertices
        end,
        GetMaterial = function()
            return materialName or "**displacement**"
        end
    }
end

local function addDisplacementTriangleSurface(source, group, materialName, vertices, surfaceId, sourceLabel, row, col, half, diagonal)
    local surfaceInfo = makeDisplacementSurfaceInfo(vertices, materialName)
    local surfaceData = buildSurfaceData(surfaceInfo, surfaceId, source, sourceLabel)
    if not surfaceData then return nil, "surface" end

    surfaceData.sourceIsDisplacement = true
    surfaceData.displacementIndex = group.index
    surfaceData.displacementMapFace = group.mapFace
    surfaceData.displacementGroup = group
    surfaceData.displacementRow = row
    surfaceData.displacementCol = col
    surfaceData.displacementHalf = half
    surfaceData.displacementDiagonal = diagonal
    surfaceData.materialName = materialName or surfaceData.materialName or "**displacement**"
    worldBSP.markCachedSurface(surfaceData)
    group.surfaces[#group.surfaces + 1] = surfaceData

    cache.cached = cache.cached + 1
    cache.displacementSurfaces = cache.displacementSurfaces + 1
    cache.surfaces[cache.cached] = surfaceData
    indexSurface(surfaceData)
    indexSurfacePlane(surfaceData)

    return surfaceData
end

local function addSourceDisplacementQuadTriangles(source, group, materialName, grid, gridSize, row, col, surfaceId)
    local p00 = displacementGridVertex(grid, gridSize, row, col)
    local p10 = displacementGridVertex(grid, gridSize, row, col + 1)
    local p01 = displacementGridVertex(grid, gridSize, row + 1, col)
    local p11 = displacementGridVertex(grid, gridSize, row + 1, col + 1)

    -- Source alternates displacement diagonals by the linear grid vertex index.
    -- The vertex order below preserves this file's normal winding convention.
    local odd = ((row * gridSize + col) % 2) == 1
    local diagonal = odd and "source_tlbr" or "source_bltr"
    local created = 0

    local first = odd and { p00, p10, p01 } or { p00, p10, p11 }
    local second = odd and { p10, p11, p01 } or { p00, p11, p01 }

    surfaceId = surfaceId + 1
    if addDisplacementTriangleSurface(
        source,
        group,
        materialName,
        first,
        surfaceId,
        ("disp:%d:%d:%d:a"):format(group.index, row, col),
        row,
        col,
        "a",
        diagonal
    ) then
        created = created + 1
    else
        cache.displacementSkipped = cache.displacementSkipped + 1
    end

    surfaceId = surfaceId + 1
    if addDisplacementTriangleSurface(
        source,
        group,
        materialName,
        second,
        surfaceId,
        ("disp:%d:%d:%d:b"):format(group.index, row, col),
        row,
        col,
        "b",
        diagonal
    ) then
        created = created + 1
    else
        cache.displacementSkipped = cache.displacementSkipped + 1
    end

    return surfaceId, created
end

local function appendDisplacementSurfacesForInfo(data, header, info, surfaceId)
    local face = readBspFace(data, header, info.mapFace)
    local faceVertices = readBspFaceVertices(data, header, face)
    local corners, cornerErr = orderedDisplacementCorners(faceVertices, info.startPosition)
    if not corners then
        return surfaceId, cornerErr
    end

    local grid, side, gridSize = buildDisplacementVertexGrid(data, header, info, corners)
    if not grid then
        return surfaceId, side
    end

    local materialName = readBspTextureName(data, header, face and face.texInfo) or "**displacement**"
    local source = {
        ent = game and isfunction(game.GetWorld) and game.GetWorld() or nil,
        identity = "world:0",
        entityIndex = 0,
        class = "worldspawn",
        model = nil,
        isWorld = true
    }
    local group = {
        index = info.index + 1,
        mapFace = info.mapFace,
        power = info.power,
        materialName = materialName,
        surfaces = {}
    }
    local created = 0

    for row = 0, side - 1 do
        for col = 0, side - 1 do
            local quadCreated
            surfaceId, quadCreated = addSourceDisplacementQuadTriangles(
                source,
                group,
                materialName,
                grid,
                gridSize,
                row,
                col,
                surfaceId
            )
            created = created + (quadCreated or 0)
        end

        maybeYield()
    end

    if created > 0 then
        cache.displacements = cache.displacements + 1
        return surfaceId
    end

    return surfaceId, "no displacement triangles"
end

local function appendBspDisplacementSurfaces(surfaceId)
    local data, readErr = readCurrentMapBspData()
    if not data then
        cache.displacementError = readErr
        print("Magic Align: BSP displacement parser skipped: " .. tostring(readErr))
        return surfaceId
    end

    local header, headerErr = readBspHeader(data)
    if not header then
        cache.displacementError = headerErr
        print("Magic Align: BSP displacement parser skipped: " .. tostring(headerErr))
        return surfaceId
    end

    local dispInfoLump = bspLump(header, BSP.lumpDispInfo)
    if not bspLumpIsReadable(data, dispInfoLump) then
        return surfaceId
    end

    local ok, lumpErr = requiredBspDisplacementLumpsReadable(data, header)
    if not ok then
        cache.displacementError = lumpErr
        print("Magic Align: BSP displacement parser skipped: " .. tostring(lumpErr))
        return surfaceId
    end

    local dispInfoCount = bspLumpCount(header, BSP.lumpDispInfo, BSP.dispInfoSize)
    if dispInfoCount <= 0 then return surfaceId end

    cache.displacementTotal = dispInfoCount
    cache.displacementProcessed = 0
    worldBSP.setBuildStage("displacements", dispInfoCount, 0)

    for i = 0, dispInfoCount - 1 do
        local info = readBspDispInfo(data, header, i)
        if info then
            local err
            surfaceId, err = appendDisplacementSurfacesForInfo(data, header, info, surfaceId)
            if err then
                cache.displacementSkipped = cache.displacementSkipped + 1
            end
        else
            cache.displacementSkipped = cache.displacementSkipped + 1
        end

        cache.displacementProcessed = i + 1
        worldBSP.updateBuildStage(i + 1)
        maybeYield()
    end

    return surfaceId
end

local function buildWorker()
    local sources = readWorldBrushSurfaceSources()

    if not istable(sources) then
        cache.status = cache.STATUS.UNAVAILABLE
        cache.worker = nil
        cache.error = "world brush surfaces unavailable"
        print("Magic Align: World BSP snapping unavailable; no world brush surfaces were returned.")
        return
    end

    cache.sources = sources
    cache.total = 0
    for i = 1, #sources do
        cache.total = cache.total + (tonumber(sources[i].surfaceCount) or 0)
    end
    cache.brushTotal = cache.total
    cache.brushProcessed = 0
    cache.neighborTotal = 0
    cache.neighborProcessed = 0
    if cache.total <= 0 then
        cache.status = cache.STATUS.UNAVAILABLE
        cache.worker = nil
        cache.error = "world brush surface list was empty"
        print("Magic Align: World BSP snapping unavailable; the world brush surface list was empty.")
        return
    end

    worldBSP.setBuildStage("brush_surfaces", cache.total, 0)

    local surfaceId = 0
    for sourceIndex = 1, #sources do
        local source = sources[sourceIndex]
        local surfaces = source.surfaces
        for i = 1, #(surfaces or {}) do
            surfaceId = surfaceId + 1
            local surfaceData = buildSurfaceData(surfaces[i], surfaceId, source, i)
            if surfaceData then
                worldBSP.markCachedSurface(surfaceData)
                cache.cached = cache.cached + 1
                cache.surfaces[cache.cached] = surfaceData
                indexSurface(surfaceData)
                indexSurfacePlane(surfaceData)
            else
                cache.skipped = cache.skipped + 1
            end

            cache.brushProcessed = cache.brushProcessed + 1
            worldBSP.updateBuildStage(cache.brushProcessed)
            maybeYield()
        end

        source.surfaces = nil
    end

    surfaceId = appendBspDisplacementSurfaces(surfaceId)
    buildDirectNeighborCache()
    finishBuild()
end

local function startBuild()
    resetCache(cache.STATUS.BUILDING)
    cache.startedAt = now()
    cache.worker = coroutine.create(buildWorker)
    worldBSP.setBuildStage("starting", 0, 0)
    worldBSP.refreshCacheProgressSnapshot(true)

    print("Magic Align: World BSP snapping cache is building...")
end

function worldBSP.update(settings)
    if not worldBSP.shouldBuildCache(settings) then
        if cache.status == cache.STATUS.BUILDING then
            print("Magic Align: World BSP snapping cache build cancelled; global units grid is not active.")
            resetCache(cache.STATUS.IDLE)
        elseif cache.status == cache.STATUS.READY then
            resetCache(cache.STATUS.IDLE)
        end
        return
    end

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
        worldBSP.refreshCacheProgressSnapshot(true)
        print("Magic Align: World BSP snapping failed: " .. cache.error)
        return
    end

    if coroutine.status(worker) == "dead" and cache.status == cache.STATUS.BUILDING then
        finishBuild()
    elseif cache.status == cache.STATUS.BUILDING then
        worldBSP.refreshCacheProgressSnapshot(false)
    end
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

local function traceHitsDisplacement(tr)
    return tostring(tr and tr.HitTexture or "") == CONFIG.displacementHitTexture
end

local function useDisplacementTraceTolerances(surfaceData, displacementTrace)
    return displacementTrace == true and surfaceData and surfaceData.sourceIsDisplacement == true
end

local function traceBoundsTolerance(surfaceData, displacementTrace)
    return useDisplacementTraceTolerances(surfaceData, displacementTrace)
        and CONFIG.displacementBoundsTolerance
        or CONFIG.boundsTolerance
end

local function tracePlaneTolerance(surfaceData, displacementTrace)
    return useDisplacementTraceTolerances(surfaceData, displacementTrace)
        and CONFIG.displacementPlaneTolerance
        or CONFIG.planeTolerance
end

local function traceSurfacePickTolerance(surfaceData, displacementTrace)
    return useDisplacementTraceTolerances(surfaceData, displacementTrace)
        and CONFIG.displacementSurfacePickTolerance
        or CONFIG.surfacePickTolerance
end

local function traceNormalDotMin(surfaceData, displacementTrace)
    return useDisplacementTraceTolerances(surfaceData, displacementTrace)
        and CONFIG.displacementNormalDotMin
        or CONFIG.normalDotMin
end

local function traceEdgeProjectionTolerance(surfaceData, displacementTrace)
    return useDisplacementTraceTolerances(surfaceData, displacementTrace)
        and CONFIG.displacementEdgeProjectionTolerance
        or CONFIG.edgeProjectionTolerance
end

local function traceRayPickTolerance(surfaceData, displacementTrace)
    return useDisplacementTraceTolerances(surfaceData, displacementTrace)
        and CONFIG.displacementRayPickTolerance
        or CONFIG.rayPickTolerance
end

local function traceMatchIsDisplacement(match)
    return match
        and match.surface
        and match.surface.sourceIsDisplacement == true
        and (match.match == "displacement"
            or match.match == "displacement_edge"
            or match.match == "same_displacement")
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

    local displacementTrace = traceHitsDisplacement(tr)
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
            local boundsTolerance = traceBoundsTolerance(surfaceData, displacementTrace)
            if pointInsideWorldBounds(surfaceData, hitPos, boundsTolerance) then
                local signedPlaneDist = signedPlaneDistance(surfaceData, hitPos.x, hitPos.y, hitPos.z)
                local planeDist = math.abs(signedPlaneDist)
                if planeDist <= tracePlaneTolerance(surfaceData, displacementTrace) then
                    local normalDot = dot(surfaceData.normal, hitNormal)
                    local absNormalDot = math.abs(normalDot)
                    if absNormalDot >= traceNormalDotMin(surfaceData, displacementTrace) then
                        local normal = surfaceData.normal
                        local u, v = surfaceUvFromComponents(
                            surfaceData,
                            hitPos.x - normal.x * signedPlaneDist,
                            hitPos.y - normal.y * signedPlaneDist,
                            hitPos.z - normal.z * signedPlaneDist
                        )
                        local uvInBounds = u >= surfaceData.uMin - boundsTolerance
                            and u <= surfaceData.uMax + boundsTolerance
                            and v >= surfaceData.vMin - boundsTolerance
                            and v <= surfaceData.vMax + boundsTolerance
                        local normalPenalty = (1 - absNormalDot) * 10
                        local pickTolerance = traceSurfacePickTolerance(surfaceData, displacementTrace)
                        local edgeProjectionTolerance = traceEdgeProjectionTolerance(surfaceData, displacementTrace)
                        local displacementMatch = useDisplacementTraceTolerances(surfaceData, displacementTrace)

                        if uvInBounds then
                            if planeDist <= pickTolerance
                                and pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonPickTolerance) then
                                local score = planeDist + normalPenalty
                                if not bestStrictScore or score < bestStrictScore then
                                    writeTraceMatch(
                                        bestStrict,
                                        surfaceData,
                                        normalDot < 0 and -1 or 1,
                                        u,
                                        v,
                                        displacementMatch and "displacement" or "strict"
                                    )
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
                        elseif planeDist <= pickTolerance then
                            local edgeDistance = polygonEdgeDistance(surfaceData.polygon, u, v)
                            if edgeDistance <= edgeProjectionTolerance then
                                local score = planeDist + normalPenalty + edgeDistance * 4 + 1
                                if not bestEdgeScore or score < bestEdgeScore then
                                    writeTraceMatch(
                                        bestEdge,
                                        surfaceData,
                                        normalDot < 0 and -1 or 1,
                                        u,
                                        v,
                                        displacementMatch and "displacement_edge" or "edge_project"
                                    )
                                    hasBestEdge = true
                                    bestEdgeScore = score
                                end
                            end
                        end
                    end
                end
            end

            if rayStart and rayDir and rayHitDistance then
                local rayPickTolerance = traceRayPickTolerance(surfaceData, displacementTrace)
                local boundsTolerance = traceBoundsTolerance(surfaceData, displacementTrace)
                local denom = dot(surfaceData.normal, rayDir)
                if math.abs(denom) >= CONFIG.rayPlaneDotMin then
                    local normal = surfaceData.normal
                    local origin = surfaceData.origin
                    local t = ((origin.x - rayStart.x) * normal.x
                        + (origin.y - rayStart.y) * normal.y
                        + (origin.z - rayStart.z) * normal.z) / denom
                    local traceDistance = math.abs(t - rayHitDistance)
                    if t >= 0 and traceDistance <= rayPickTolerance then
                        local rayX = rayStart.x + rayDir.x * t
                        local rayY = rayStart.y + rayDir.y * t
                        local rayZ = rayStart.z + rayDir.z * t
                        if pointInsideWorldBoundsComponents(surfaceData, rayX, rayY, rayZ, boundsTolerance + rayPickTolerance) then
                            local u, v = surfaceUvFromComponents(surfaceData, rayX, rayY, rayZ)
                            if u >= surfaceData.uMin - boundsTolerance
                                and u <= surfaceData.uMax + boundsTolerance
                                and v >= surfaceData.vMin - boundsTolerance
                                and v <= surfaceData.vMax + boundsTolerance
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

    if displacementTrace and hasBestStrict and traceMatchIsDisplacement(bestStrict) then
        return bestStrict
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
        if match and (match.match == "strict" or traceMatchIsDisplacement(match)) then
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
    local baseU = math.Round(worldAxisFromUv(surfaceData, rawU, rawV, pair.axisU) / step)
    local baseV = math.Round(worldAxisFromUv(surfaceData, rawU, rawV, pair.axisV) / step)
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

    local value = math.Round(worldAxisFromUv(surfaceData, rawU, rawV, family.axis) / step) * step
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
    face.worldBspFullGrid = not (settings and settings.worldBspFullGrid == false)
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
    return ("%.6f:%d"):format(
        worldGridStep(settings),
        settings and settings.worldBspFullGrid == false and 0 or 1
    )
end

local function buildRenderOverlayFace(surfaceData, settings)
    if not surfaceData then return end

    local step = worldGridStep(settings)
    local cache = surfaceData._magicAlignRenderOverlayFaces
    if not cache then
        cache = {}
        surfaceData._magicAlignRenderOverlayFaces = cache
    end

    local key = worldGridRenderCacheKey(settings)
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
        worldBspFullGrid = not (settings and settings.worldBspFullGrid == false),
        globalGridOverlays = globalProjectionPairs(surfaceData)
    }
    cache[key] = cached

    return cached
end

local function buildRenderNeighborFaces(surfaceData, settings)
    local neighbors = surfaceData and surfaceData.neighbors
    local groupSurfaces = surfaceData
        and surfaceData.displacementGroup
        and surfaceData.displacementGroup.surfaces
        or nil
    if (not istable(neighbors) or #neighbors == 0)
        and (not istable(groupSurfaces) or #groupSurfaces <= 1) then
        return
    end

    local cache = surfaceData._magicAlignRenderNeighborFaces
    if not cache then
        cache = {}
        surfaceData._magicAlignRenderNeighborFaces = cache
    end

    local key = worldGridRenderCacheKey(settings)
    local cached = cache[key]
    if cached then return cached end

    local out = {}
    local seen = {}
    local function addNeighbor(neighbor)
        if not neighbor or neighbor == surfaceData or seen[neighbor] then return end

        seen[neighbor] = true
        local face = buildRenderOverlayFace(neighbor, settings)
        if face then
            out[#out + 1] = face
        end
    end

    if istable(groupSurfaces) then
        for i = 1, #groupSurfaces do
            addNeighbor(groupSurfaces[i])
        end
    end

    if istable(neighbors) then
        for i = 1, #neighbors do
            addNeighbor(neighbors[i])
        end
    end

    cache[key] = out
    return out
end

-- Surface descriptor invalidation is intentionally tied to the owning cache:
-- the global BSP cache is rebuilt on map/CACHE_VERSION changes, while
-- per-surface trace entries are rebuilt when the map changes or the brush
-- entity identity/object is no longer current. Grid settings are part of the
-- grid descriptor key, so setting changes select a new descriptor without
-- mutating existing hover state.
worldBSP.HOVER_FACE_META = worldBSP.HOVER_FACE_META or {}
worldBSP.HOVER_FACE_META.__index = function(face, key)
    local gridDescriptor = rawget(face, "gridDescriptor")
    local gridValue = gridDescriptor and gridDescriptor[key]
    if gridValue ~= nil then return gridValue end

    local faceDescriptor = rawget(face, "faceDescriptor")
    return faceDescriptor and faceDescriptor[key] or nil
end

function worldBSP.surfaceSourceIdentity(surfaceData)
    if not surfaceData then return "unknown" end
    if surfaceData.sourceIsWorld == true then return "world:0" end

    local sourceEnt = surfaceData.sourceEnt
    if IsValid(sourceEnt) then
        return entityIdentity(sourceEnt)
    end

    return surfaceData.sourceIdentity or ("%s:%s:%s"):format(
        tostring(surfaceData.sourceEntityIndex or "nil"),
        tostring(surfaceData.sourceClass or ""),
        tostring(surfaceData.sourceModel or "")
    )
end

function worldBSP.surfaceDescriptorBaseKey(surfaceData)
    return ("%s:%s:%s"):format(
        tostring(currentMap()),
        worldBSP.surfaceSourceIdentity(surfaceData),
        tostring(surfaceData and surfaceData.id or "nil")
    )
end

function worldBSP.surfaceGridSettingsKey(settings)
    if usesGlobalGrid(settings) then
        return ("global:%.6f:%d"):format(
            worldGridStep(settings),
            settings and settings.worldBspFullGrid == false and 0 or 1
        )
    end

    if settings and settings.shift then
        return "surface:free"
    end

    return ("surface:%d:%d:%d:%d:%d:%d"):format(
        math.Round(tonumber(settings and settings.gridA) or 0),
        math.Round(tonumber(settings and settings.gridAMin) or 0),
        settings and settings.gridBEnabled and 1 or 0,
        math.Round(tonumber(settings and settings.gridB) or 0),
        math.Round(tonumber(settings and settings.gridBMin) or 0),
        math.Round(tonumber(settings and settings.minLength) or 0)
    )
end

function worldBSP.globalSurfaceDescriptorIsCurrent(surfaceData)
    return surfaceData
        and surfaceData._magicAlignWorldBspCacheVersion == CACHE_VERSION
        and surfaceData._magicAlignWorldBspCacheMap == cache.map
end

function worldBSP.surfaceDescriptorStores(surfaceData)
    local entry = surfaceData and surfaceData._magicAlignSurfaceTraceEntry
    if entry and worldBSP.surfaceTraceCachedSurfaceIsCurrent(surfaceData) then
        entry.faceDescriptors = entry.faceDescriptors or {}
        entry.gridDescriptors = entry.gridDescriptors or {}
        return entry.faceDescriptors, entry.gridDescriptors
    end

    if worldBSP.globalSurfaceDescriptorIsCurrent(surfaceData) then
        cache.faceDescriptors = cache.faceDescriptors or {}
        cache.gridDescriptors = cache.gridDescriptors or {}
        return cache.faceDescriptors, cache.gridDescriptors
    end

    surfaceData._magicAlignDescriptorFallback = surfaceData._magicAlignDescriptorFallback or {
        faceDescriptors = {},
        gridDescriptors = {}
    }

    return surfaceData._magicAlignDescriptorFallback.faceDescriptors,
        surfaceData._magicAlignDescriptorFallback.gridDescriptors
end

function worldBSP.buildSurfaceFaceDescriptor(surfaceData, key)
    return {
        kind = "SurfaceFaceDescriptor",
        key = key,
        map = currentMap(),
        entityIdentity = worldBSP.surfaceSourceIdentity(surfaceData),
        surfaceId = surfaceData and surfaceData.id or nil,
        sourceSurfaceIndex = surfaceData and surfaceData.sourceSurfaceIndex or nil,
        worldBSP = true,
        surface = surfaceData,
        lineWorldPoints = worldBSP.faceLineWorldPoints,
        polygon = surfaceData.polygon,
        worldCorners = surfaceData.vertices,
        worldMins = surfaceData.worldMins,
        worldMaxs = surfaceData.worldMaxs,
        surfaceNormal = surfaceData.normal,
        uAxis = surfaceData.uAxis,
        vAxis = surfaceData.vAxis,
        origin = surfaceData.center,
        center = surfaceData.center,
        uMin = surfaceData.uMin,
        uMax = surfaceData.uMax,
        vMin = surfaceData.vMin,
        vMax = surfaceData.vMax
    }
end

function worldBSP.surfaceFaceDescriptor(surfaceData)
    if not surfaceData then return end

    local faceStore = worldBSP.surfaceDescriptorStores(surfaceData)
    if not faceStore then return end

    local key = worldBSP.surfaceDescriptorBaseKey(surfaceData)
    local descriptor = faceStore[key]
    if descriptor then return descriptor end

    descriptor = worldBSP.buildSurfaceFaceDescriptor(surfaceData, key)
    faceStore[key] = descriptor
    return descriptor
end

function worldBSP.buildSurfaceGridDescriptor(surfaceData, faceDescriptor, settings, key, settingsKey)
    local descriptor = {
        kind = "SurfaceGridDescriptor",
        key = key,
        settingsKey = settingsKey,
        map = currentMap(),
        entityIdentity = worldBSP.surfaceSourceIdentity(surfaceData),
        surfaceId = surfaceData and surfaceData.id or nil,
        faceDescriptor = faceDescriptor
    }

    if usesGlobalGrid(settings) then
        local step = worldGridStep(settings)
        descriptor.globalGrid = true
        descriptor.globalGridStep = step
        descriptor.activeGridStep = step
        descriptor.worldBspFullGrid = not (settings and settings.worldBspFullGrid == false)
        descriptor.globalGridOverlays = globalProjectionPairs(surfaceData)
        descriptor.globalGridNeighbors = buildRenderNeighborFaces(surfaceData, settings)
        return descriptor
    end

    if settings and settings.shift then
        descriptor.freeFace = true
        return descriptor
    end

    local buildDescriptor = client.buildSnapFaceGridDescriptor
    if isfunction(buildDescriptor) then
        buildDescriptor(settings or {}, faceDescriptor, descriptor)
        descriptor.activeGridStep = activeStepFromSnapped({
            gridA = descriptor.gridA,
            gridB = descriptor.gridB
        })
    end

    return descriptor
end

function worldBSP.surfaceGridDescriptor(surfaceData, faceDescriptor, settings)
    if not surfaceData or not faceDescriptor then return end

    local _, gridStore = worldBSP.surfaceDescriptorStores(surfaceData)
    if not gridStore then return end

    local settingsKey = worldBSP.surfaceGridSettingsKey(settings)
    local key = ("%s:%s"):format(faceDescriptor.key, settingsKey)
    local descriptor = gridStore[key]
    if descriptor then return descriptor end

    descriptor = worldBSP.buildSurfaceGridDescriptor(surfaceData, faceDescriptor, settings, key, settingsKey)
    gridStore[key] = descriptor
    return descriptor
end

function worldBSP.newHoverCandidateState(faceDescriptor, gridDescriptor, normal, rawU, rawV)
    local face = setmetatable({}, worldBSP.HOVER_FACE_META)

    face.kind = "HoverCandidateState"
    face.faceDescriptor = faceDescriptor
    face.gridDescriptor = gridDescriptor
    face.descriptorKey = faceDescriptor and faceDescriptor.key or nil
    face.gridDescriptorKey = gridDescriptor and gridDescriptor.key or nil

    face.worldBSP = true
    face.surface = faceDescriptor.surface
    face.lineWorldPoints = faceDescriptor.lineWorldPoints
    face.polygon = faceDescriptor.polygon
    face.worldCorners = faceDescriptor.worldCorners
    face.origin = faceDescriptor.origin
    face.center = faceDescriptor.center
    face.uMin = faceDescriptor.uMin
    face.uMax = faceDescriptor.uMax
    face.vMin = faceDescriptor.vMin
    face.vMax = faceDescriptor.vMax

    face.rawU = rawU
    face.rawV = rawV
    face.normal = normal
    face.normalSign = dot(normal, face.surface.normal) < 0 and -1 or 1

    face.gridA = gridDescriptor and gridDescriptor.gridA or nil
    face.gridB = gridDescriptor and gridDescriptor.gridB or nil
    face.globalGrid = gridDescriptor and gridDescriptor.globalGrid or nil
    face.globalGridStep = gridDescriptor and gridDescriptor.globalGridStep or nil
    face.activeGridStep = gridDescriptor and gridDescriptor.activeGridStep or nil
    face.worldBspFullGrid = gridDescriptor and gridDescriptor.worldBspFullGrid or nil
    face.globalGridOverlays = gridDescriptor and gridDescriptor.globalGridOverlays or nil
    face.globalGridNeighbors = gridDescriptor and gridDescriptor.globalGridNeighbors or nil

    return face
end

function worldBSP.buildFace(surfaceData, normal, rawU, rawV, settings)
    local faceDescriptor = worldBSP.surfaceFaceDescriptor(surfaceData)
    if not faceDescriptor then return end

    local gridDescriptor = worldBSP.surfaceGridDescriptor(surfaceData, faceDescriptor, settings)
    local face = worldBSP.newHoverCandidateState(faceDescriptor, gridDescriptor, normal, rawU, rawV)
    local globalGrid = gridDescriptor and gridDescriptor.globalGrid == true

    local snapFaceCoordinates = client.snapFaceCoordinates
    snapScratch.buildFaceSnapped = snapScratch.buildFaceSnapped or {}
    local snapped = globalGrid
        and snapGlobalFaceCoordinates(settings or {}, face, surfaceData, rawU, rawV)
        or isfunction(snapFaceCoordinates)
        and snapFaceCoordinates(settings or {}, face, rawU, rawV, gridDescriptor, snapScratch.buildFaceSnapped)
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

    local worldPos = worldFromUv(surfaceData, u, v)
    face.worldPos = worldPos

    return face, worldPos
end

function worldBSP.traceSurfaceDataCanFastMatch(surfaceData)
    return surfaceData
        and isvector(surfaceData.origin)
        and isvector(surfaceData.normal)
        and isvector(surfaceData.worldMins)
        and isvector(surfaceData.worldMaxs)
        and istable(surfaceData.polygon)
        and #surfaceData.polygon >= 3
        and tonumber(surfaceData.uMin)
        and tonumber(surfaceData.uMax)
        and tonumber(surfaceData.vMin)
        and tonumber(surfaceData.vMax)
end

function worldBSP.traceTolerancesForSameSurface(surfaceData, displacementTrace)
    local boundsTolerance = tonumber(traceBoundsTolerance(surfaceData, displacementTrace))
    local pickTolerance = tonumber(traceSurfacePickTolerance(surfaceData, displacementTrace))
    local normalDotMin = tonumber(traceNormalDotMin(surfaceData, displacementTrace))
    local edgeTolerance = tonumber(CONFIG.sameSurfaceFastPathEdgeTolerance)

    if not boundsTolerance or not pickTolerance or not normalDotMin or not edgeTolerance then return end
    return boundsTolerance, pickTolerance, normalDotMin, edgeTolerance
end

function worldBSP.sameSurfaceFastMatchForSurface(tr, surfaceData)
    if not worldBSP.traceSurfaceDataCanFastMatch(surfaceData)
        or not tr
        or not isvector(tr.HitPos)
        or not isvector(tr.HitNormal) then
        return
    end

    local hitPos = tr.HitPos
    local displacementTrace = traceHitsDisplacement(tr)
    local boundsTolerance, pickTolerance, normalDotMin, edgeTolerance = worldBSP.traceTolerancesForSameSurface(surfaceData, displacementTrace)
    if not boundsTolerance then return end

    if not pointInsideWorldBounds(surfaceData, hitPos, boundsTolerance) then return end

    local hitNormal = normalizedVec(tr.HitNormal, M.PICKING_VECTOR_EPSILON_SQR)
    if not hitNormal then return end

    local signedPlaneDist = signedPlaneDistance(surfaceData, hitPos.x, hitPos.y, hitPos.z)
    if math.abs(signedPlaneDist) > pickTolerance then return end

    local normalDot = dot(surfaceData.normal, hitNormal)
    if math.abs(normalDot) < normalDotMin then return end

    local normal = surfaceData.normal
    local u, v = surfaceUvFromComponents(
        surfaceData,
        hitPos.x - normal.x * signedPlaneDist,
        hitPos.y - normal.y * signedPlaneDist,
        hitPos.z - normal.z * signedPlaneDist
    )

    if u < surfaceData.uMin - boundsTolerance
        or u > surfaceData.uMax + boundsTolerance
        or v < surfaceData.vMin - boundsTolerance
        or v > surfaceData.vMax + boundsTolerance then
        return
    end
    if not pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonTolerance) then return end
    if polygonEdgeDistance(surfaceData.polygon, u, v) <= edgeTolerance then return end

    traceScratch.sameSurfaceMatch = traceScratch.sameSurfaceMatch or {}
    return writeTraceMatch(
        traceScratch.sameSurfaceMatch,
        surfaceData,
        normalDot < 0 and -1 or 1,
        u,
        v,
        useDisplacementTraceTolerances(surfaceData, displacementTrace) and "same_displacement" or "same_surface"
    )
end

function worldBSP.globalCachedSurfaceIsCurrent(surfaceData)
    return surfaceData
        and surfaceData._magicAlignWorldBspCacheVersion == CACHE_VERSION
        and surfaceData._magicAlignWorldBspCacheMap == cache.map
end

local function sameSurfaceFastMatchFromTrace(tr)
    if cache.status ~= cache.STATUS.READY then return end

    local surfaceData = worldBSP.lastTraceSurface
    if not worldBSP.globalCachedSurfaceIsCurrent(surfaceData) then return end

    return worldBSP.sameSurfaceFastMatchForSurface(tr, surfaceData)
end

worldBSP.surfaceTraceCache = worldBSP.surfaceTraceCache or {}

function worldBSP.surfaceTraceCacheToken(surfaceTraceCache)
    return ("%s:%d:%d"):format(
        tostring(surfaceTraceCache and surfaceTraceCache.map or ""),
        tonumber(surfaceTraceCache and surfaceTraceCache.version) or 0,
        tonumber(surfaceTraceCache and surfaceTraceCache.revision) or 0
    )
end

function worldBSP.refreshSurfaceTraceCacheToken(surfaceTraceCache)
    if not istable(surfaceTraceCache) then return end

    surfaceTraceCache.statusToken = worldBSP.surfaceTraceCacheToken(surfaceTraceCache)
    return surfaceTraceCache.statusToken
end

function worldBSP.bumpSurfaceTraceCacheRevision(surfaceTraceCache)
    surfaceTraceCache = surfaceTraceCache or worldBSP.surfaceTraceCache
    if not istable(surfaceTraceCache) then return end

    surfaceTraceCache.revision = (tonumber(surfaceTraceCache.revision) or 0) + 1
    return worldBSP.refreshSurfaceTraceCacheToken(surfaceTraceCache)
end

function worldBSP.surfaceTraceEntryIsCurrent(entry, ent)
    if not istable(entry) or not ent then return false end

    local source = entry.source
    if source and source.isWorld == true then
        return isWorldBrushEntity(ent) and entry.identity == "world:0"
    end

    if entry.ent ~= ent or not IsValid(ent) then return false end
    return entry.identity == entityIdentity(ent)
end

function worldBSP.surfaceTraceCacheStatusToken()
    worldBSP.resetSurfaceTraceCacheIfNeeded()

    local surfaceTraceCache = worldBSP.surfaceTraceCache
    if not istable(surfaceTraceCache)
        or surfaceTraceCache.version ~= CACHE_VERSION
        or surfaceTraceCache.map ~= currentMap() then
        return
    end

    return surfaceTraceCache.statusToken or worldBSP.refreshSurfaceTraceCacheToken(surfaceTraceCache)
end

function worldBSP.candidateCacheStatusToken(settings)
    if not settings or settings.worldBspSnap ~= true then return end

    if usesGlobalGrid(settings) then
        if cache.status ~= cache.STATUS.READY then return end
        return cache.readyAt or true
    end

    return worldBSP.surfaceTraceCacheStatusToken()
end

function worldBSP.markSurfaceTraceCachedSurface(surfaceData, entry, surfaceTraceCache)
    if not surfaceData then return end

    surfaceTraceCache = surfaceTraceCache or worldBSP.surfaceTraceCache
    if not istable(surfaceTraceCache) then return end

    surfaceData._magicAlignSurfaceTraceCacheVersion = CACHE_VERSION
    surfaceData._magicAlignSurfaceTraceCacheMap = surfaceTraceCache.map
    surfaceData._magicAlignSurfaceTraceCacheRevision = entry and entry.revision or surfaceTraceCache.revision
    surfaceData._magicAlignSurfaceTraceEntry = entry
end

function worldBSP.surfaceTraceCachedSurfaceIsCurrent(surfaceData)
    local surfaceTraceCache = worldBSP.surfaceTraceCache
    local entry = surfaceData and surfaceData._magicAlignSurfaceTraceEntry
    local entries = surfaceTraceCache and surfaceTraceCache.entries

    return surfaceData
        and istable(surfaceTraceCache)
        and istable(entry)
        and istable(entries)
        and entries[entry.cacheKey] == entry
        and surfaceData._magicAlignSurfaceTraceCacheVersion == CACHE_VERSION
        and surfaceData._magicAlignSurfaceTraceCacheMap == surfaceTraceCache.map
        and surfaceData._magicAlignSurfaceTraceCacheRevision == entry.revision
        and entry.identity == worldBSP.surfaceSourceIdentity(surfaceData)
        and worldBSP.surfaceTraceEntryIsCurrent(entry, surfaceData.sourceEnt)
end

function worldBSP.traceMatchesSurfaceSource(tr, surfaceData)
    if not tr or not surfaceData then return false end

    if surfaceData.sourceIsWorld == true then
        return tr.HitWorld == true or isWorldBrushEntity(tr.Entity)
    end

    local sourceEnt = surfaceData.sourceEnt
    if not IsValid(sourceEnt) then return false end
    if tr.Entity == sourceEnt then return true end

    local sourceIndex = surfaceData.sourceEntityIndex
    return sourceIndex ~= nil and entityIndex(tr.Entity) == sourceIndex
end

function worldBSP.perSurfaceSameSurfaceFastMatchFromTrace(tr)
    worldBSP.resetSurfaceTraceCacheIfNeeded()

    local surfaceData = worldBSP.lastTraceSurface
    if not worldBSP.surfaceTraceCachedSurfaceIsCurrent(surfaceData)
        or not worldBSP.traceMatchesSurfaceSource(tr, surfaceData) then
        return
    end

    return worldBSP.sameSurfaceFastMatchForSurface(tr, surfaceData)
end

function worldBSP.indexSurfaceEntry(entry, surfaceData)
    if not entry or not surfaceData then return end

    local normal = surfaceData.normal
    local planeBuckets = entry.planeBuckets
    if isvector(normal) and istable(planeBuckets) then
        local key = planeBucketKey(
            planeNormalCoord(normal.x),
            planeNormalCoord(normal.y),
            planeNormalCoord(normal.z),
            planeDistanceCoord(surfaceData.planeDistance)
        )
        local bucket = planeBuckets[key]
        if not bucket then
            bucket = {}
            planeBuckets[key] = bucket
        end

        bucket[#bucket + 1] = surfaceData
    end

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
        entry.largeSurfaces[#entry.largeSurfaces + 1] = surfaceData
        return
    end

    local index = entry.index
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local key = cellKey(x, y, z)
                local cell = index[key]
                if not cell then
                    cell = {}
                    index[key] = cell
                end

                cell[#cell + 1] = surfaceData
            end
        end
    end
end

function worldBSP.querySurfaceEntry(entry, worldPos, out, seenOut, planeSet)
    if not entry or not isvector(worldPos) then return end

    local surfaces = out or {}
    local count = 0
    local seen = seenOut or {}
    local index = entry.index
    local x = cellCoord(worldPos.x)
    local y = cellCoord(worldPos.y)
    local z = cellCoord(worldPos.z)

    if istable(index) then
        for cx = x - CONFIG.queryCellRadius, x + CONFIG.queryCellRadius do
            for cy = y - CONFIG.queryCellRadius, y + CONFIG.queryCellRadius do
                for cz = z - CONFIG.queryCellRadius, z + CONFIG.queryCellRadius do
                    local cell = index[cellKey(cx, cy, cz)]
                    if cell then
                        for i = 1, #cell do
                            count = addQueriedSurface(surfaces, count, seen, planeSet, cell[i])
                        end
                    end
                end
            end
        end
    end

    local largeSurfaces = entry.largeSurfaces
    for i = 1, istable(largeSurfaces) and #largeSurfaces or 0 do
        count = addQueriedSurface(surfaces, count, seen, planeSet, largeSurfaces[i])
    end

    for i = count + 1, #surfaces do
        surfaces[i] = nil
    end
    for surfaceData in pairs(seen) do
        seen[surfaceData] = nil
    end

    return surfaces, count
end

function worldBSP.collectSurfaceEntryPlaneSet(entry, hitPos, hitNormal, out)
    if not entry or not isvector(hitPos) or not isvector(hitNormal) or not istable(entry.planeBuckets) then return end

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
                        local bucket = entry.planeBuckets[planeBucketKey(nx, ny, nz, distance)]
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

function worldBSP.perSurfaceCandidateFromMatch(match, settings)
    if not match then return end

    local surfaceData = match.surface
    local normal = match.normalSign < 0 and -surfaceData.normal or surfaceData.normal
    local face, worldPos = worldBSP.buildFace(surfaceData, normal, match.u, match.v, settings)
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
    lastDebug.surfaceDescriptorKey = face.descriptorKey
    lastDebug.gridDescriptorKey = face.gridDescriptorKey
    lastDebug.uncachedSurfaceGrid = false

    return {
        ent = M.WORLD_TARGET,
        localPos = worldPos,
        worldPos = worldPos,
        localNormal = normal,
        normal = normal,
        face = face,
        mode = settings and settings.shift and "world_surface_free_face" or "world_surface_grid"
    }
end

function worldBSP.resetSurfaceTraceCacheIfNeeded()
    local surfaceTraceCache = worldBSP.surfaceTraceCache
    local map = currentMap()
    if surfaceTraceCache.version == CACHE_VERSION
        and surfaceTraceCache.map == map
        and surfaceTraceCache.revision ~= nil then
        if surfaceTraceCache.statusToken == nil then
            worldBSP.refreshSurfaceTraceCacheToken(surfaceTraceCache)
        end
        return false
    end

    local revision = (tonumber(surfaceTraceCache.revision) or 0) + 1
    for key in pairs(surfaceTraceCache) do
        surfaceTraceCache[key] = nil
    end
    surfaceTraceCache.version = CACHE_VERSION
    surfaceTraceCache.map = map
    surfaceTraceCache.revision = revision
    surfaceTraceCache.entries = {}
    worldBSP.refreshSurfaceTraceCacheToken(surfaceTraceCache)
    worldBSP.lastTraceSurface = nil
    return true
end

function worldBSP.traceBrushEntity(tr)
    local ent = tr and tr.Entity
    if IsValid(ent) and isfunction(ent.GetBrushSurfaces) then
        return ent
    end

    if tr and tr.HitWorld == true then
        if game and isfunction(game.GetWorld) then
            ent = game.GetWorld()
            if ent and isfunction(ent.GetBrushSurfaces) then return ent end
        end
        if isfunction(Entity) then
            ent = Entity(0)
            if ent and isfunction(ent.GetBrushSurfaces) then return ent end
        end
    end
end

function worldBSP.traceBrushSurfaceEntry(tr)
    worldBSP.resetSurfaceTraceCacheIfNeeded()

    local ent = worldBSP.traceBrushEntity(tr)
    if not ent then return end

    local surfaceTraceCache = worldBSP.surfaceTraceCache
    local identity = entityIdentity(ent)
    local key = identity
    local entries = surfaceTraceCache.entries
    if not istable(entries) then
        entries = {}
        surfaceTraceCache.entries = entries
    end

    local entry = entries[key]
    if entry then
        if worldBSP.surfaceTraceEntryIsCurrent(entry, ent) then
            return entry
        end

        entries[key] = nil
        worldBSP.bumpSurfaceTraceCacheRevision(surfaceTraceCache)
    end

    local getBrushSurfaces = ent.GetBrushSurfaces
    if not isfunction(getBrushSurfaces) then return end

    local ok, surfaces = pcall(getBrushSurfaces, ent)
    if not ok or not istable(surfaces) or #surfaces <= 0 then return end

    worldBSP.bumpSurfaceTraceCacheRevision(surfaceTraceCache)

    local source = {
        ent = ent,
        identity = identity,
        entityIndex = entityIndex(ent),
        class = entityClass(ent),
        model = entityModel(ent),
        isWorld = isWorldBrushEntity(ent),
        surfaceCount = #surfaces
    }

    entry = {
        ent = ent,
        identity = identity,
        cacheKey = key,
        revision = surfaceTraceCache.revision,
        source = source,
        surfaces = {},
        index = {},
        largeSurfaces = {},
        planeBuckets = {},
        faceDescriptors = {},
        gridDescriptors = {},
        count = 0,
        skipped = 0,
        builtAt = now()
    }

    for i = 1, #surfaces do
        local surfaceData = buildSurfaceData(surfaces[i], i, source, i)
        if surfaceData then
            entry.count = entry.count + 1
            entry.surfaces[entry.count] = surfaceData
            worldBSP.markSurfaceTraceCachedSurface(surfaceData, entry, surfaceTraceCache)
            worldBSP.indexSurfaceEntry(entry, surfaceData)
        else
            entry.skipped = entry.skipped + 1
        end
    end

    entries[key] = entry
    return entry
end

function worldBSP.perSurfaceCandidateFromTrace(tr, settings)
    if not tr or not isvector(tr.HitPos) or not isvector(tr.HitNormal) then return end

    local fastMatch = worldBSP.perSurfaceSameSurfaceFastMatchFromTrace(tr)
    if fastMatch then
        local fastCandidate = worldBSP.perSurfaceCandidateFromMatch(fastMatch, settings)
        if fastCandidate then return fastCandidate end
    end

    local entry = worldBSP.traceBrushSurfaceEntry(tr)
    if not entry or (entry.count or 0) <= 0 then return end

    local hitNormal = normalizedVec(tr.HitNormal, M.PICKING_VECTOR_EPSILON_SQR)
    if not hitNormal then return end

    traceScratch.perSurfaceQuerySurfaces = traceScratch.perSurfaceQuerySurfaces or {}
    traceScratch.perSurfaceQuerySeen = traceScratch.perSurfaceQuerySeen or {}
    traceScratch.perSurfacePlaneSeen = traceScratch.perSurfacePlaneSeen or {}

    local planeSeen, planeCount = worldBSP.collectSurfaceEntryPlaneSet(entry, tr.HitPos, hitNormal, traceScratch.perSurfacePlaneSeen)
    if planeSeen and planeCount and planeCount > 0 then
        local surfaces, surfaceCount = worldBSP.querySurfaceEntry(
            entry,
            tr.HitPos,
            traceScratch.perSurfaceQuerySurfaces,
            traceScratch.perSurfaceQuerySeen,
            planeSeen
        )
        surfaceCount = surfaceCount or 0
        if surfaceCount > 0 then
            local match = selectSurfaceForTrace(tr, surfaces, surfaceCount, tr.HitPos, hitNormal, planeSeen)
            if match and (match.match == "strict" or traceMatchIsDisplacement(match)) then
                local candidate = worldBSP.perSurfaceCandidateFromMatch(match, settings)
                if candidate then return candidate end
            end
        end
    end

    local surfaces, surfaceCount = worldBSP.querySurfaceEntry(entry, tr.HitPos, traceScratch.perSurfaceQuerySurfaces, traceScratch.perSurfaceQuerySeen)
    surfaceCount = surfaceCount or 0
    if surfaceCount <= 0 then return end

    local match = selectSurfaceForTrace(tr, surfaces, surfaceCount, tr.HitPos, hitNormal)
    if not match then return end

    return worldBSP.perSurfaceCandidateFromMatch(match, settings)
end

function worldBSP.candidateFromTrace(tr, settings)
    if not settings or not settings.worldBspSnap then return end

    if not usesGlobalGrid(settings) then
        return worldBSP.perSurfaceCandidateFromTrace(tr, settings)
    end

    if cache.status ~= cache.STATUS.READY then return end

    local match = sameSurfaceFastMatchFromTrace(tr) or findSurfaceForTrace(tr)
    if not match then return end

    local surfaceData = match.surface
    local normal = match.normalSign < 0 and -surfaceData.normal or surfaceData.normal
    local face, worldPos = worldBSP.buildFace(surfaceData, normal, match.u, match.v, settings)
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
    lastDebug.surfaceDescriptorKey = face.descriptorKey
    lastDebug.gridDescriptorKey = face.gridDescriptorKey

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

function worldBSP.formatVec(value)
    if not isvector(value) then return "nil" end

    return ("%.2f %.2f %.2f"):format(value.x, value.y, value.z)
end

function worldBSP.boolLabel(value)
    return value and "yes" or "no"
end

function worldBSP.surfaceSourceLabel(surfaceData)
    if not surfaceData then return "unknown" end
    if surfaceData.sourceIsDisplacement then
        return ("world_displacement#%s"):format(tostring(surfaceData.displacementIndex or "?"))
    end
    if surfaceData.sourceIsWorld then
        return "world"
    end

    local class = surfaceData.sourceClass or "entity"
    local index = surfaceData.sourceEntityIndex
    if index then
        return ("%s#%d"):format(class, index)
    end

    return class
end

function worldBSP.surfaceDisplacementDiagonalLabel(surfaceData)
    if not surfaceData or not surfaceData.sourceIsDisplacement then return "-" end

    return tostring(surfaceData.displacementDiagonal or "?")
end

function worldBSP.traceRejectReason(info)
    if not info.inBounds then return "bounds" end
    if info.planeDist > (info.planeTolerance or CONFIG.planeTolerance) then return "plane" end
    if info.absNormalDot < (info.normalDotMin or CONFIG.normalDotMin) then return "normal" end
    if not info.uvInBounds then
        if info.planeDist <= (info.pickTolerance or CONFIG.surfacePickTolerance)
            and info.edgeDistance <= (info.edgeProjectionTolerance or CONFIG.edgeProjectionTolerance) then
            return "edge_project_ok"
        end

        return "uv_bounds"
    end
    if info.planeDist <= (info.pickTolerance or CONFIG.surfacePickTolerance) and info.inside then
        return info.displacement and "displacement_ok" or "strict_ok"
    end
    if info.edgeDistance <= CONFIG.edgePickTolerance then return "edge_ok" end

    return "polygon"
end

function worldBSP.traceDebugInfo(surfaceData, hitPos, hitNormal, displacementTrace)
    if not surfaceData or not isvector(hitPos) or not isvector(hitNormal) then return end

    local boundsTolerance = traceBoundsTolerance(surfaceData, displacementTrace)
    local signedPlaneDist = signedPlaneDistance(surfaceData, hitPos.x, hitPos.y, hitPos.z)
    local planeDist = math.abs(signedPlaneDist)
    local normalDot = dot(surfaceData.normal, hitNormal)
    local normal = surfaceData.normal
    local u, v = surfaceUvFromComponents(
        surfaceData,
        hitPos.x - normal.x * signedPlaneDist,
        hitPos.y - normal.y * signedPlaneDist,
        hitPos.z - normal.z * signedPlaneDist
    )
    local uvInBounds = u >= surfaceData.uMin - boundsTolerance
        and u <= surfaceData.uMax + boundsTolerance
        and v >= surfaceData.vMin - boundsTolerance
        and v <= surfaceData.vMax + boundsTolerance
    local inside = pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonPickTolerance)
    local edgeDistance = polygonEdgeDistance(surfaceData.polygon, u, v)
    local boundsDistSqr = boundsDistanceSqr(surfaceData, hitPos.x, hitPos.y, hitPos.z, boundsTolerance)
    local info = {
        surface = surfaceData,
        planeDist = planeDist,
        normalDot = normalDot,
        absNormalDot = math.abs(normalDot),
        u = u,
        v = v,
        inBounds = boundsDistSqr <= M.COMPUTE_EPSILON,
        boundsDist = math.sqrt(boundsDistSqr),
        uvInBounds = uvInBounds,
        inside = inside,
        edgeDistance = edgeDistance,
        displacement = useDisplacementTraceTolerances(surfaceData, displacementTrace),
        planeTolerance = tracePlaneTolerance(surfaceData, displacementTrace),
        pickTolerance = traceSurfacePickTolerance(surfaceData, displacementTrace),
        normalDotMin = traceNormalDotMin(surfaceData, displacementTrace),
        edgeProjectionTolerance = traceEdgeProjectionTolerance(surfaceData, displacementTrace)
    }

    info.reason = worldBSP.traceRejectReason(info)
    info.score = planeDist
        + info.boundsDist * 0.5
        + math.max(0, (info.normalDotMin or CONFIG.normalDotMin) - info.absNormalDot) * 20
        + (inside and 0 or math.min(edgeDistance, 64) * 0.1)
    return info
end

function worldBSP.insertTraceDebugCandidate(best, info, maxCount)
    if not info then return end

    local count = #best
    local insertAt = count + 1
    for i = 1, count do
        if info.score < best[i].score then
            insertAt = i
            break
        end
    end
    if insertAt > maxCount then return end

    table.insert(best, insertAt, info)
    if #best > maxCount then
        best[#best] = nil
    end
end

function worldBSP.printTraceDebugCandidates(surfaces, surfaceCount, hitPos, hitNormal, displacementTrace)
    surfaceCount = tonumber(surfaceCount) or 0
    if not surfaces or surfaceCount <= 0 then return end

    local best = {}
    local maxCount = 5
    for i = 1, surfaceCount do
        worldBSP.insertTraceDebugCandidate(best, worldBSP.traceDebugInfo(surfaces[i], hitPos, hitNormal, displacementTrace), maxCount)
    end

    for i = 1, #best do
        local info = best[i]
        local surfaceData = info.surface
        print(("Magic Align: World BSP debug candidate %d: surface=%d reason=%s plane=%.3f normalDot=%.3f bounds=%s boundsDist=%.3f uv=(%.3f, %.3f) uvBounds=%s inside=%s edge=%.3f source=%s sourceSurface=%s diag=%s material=%s."):format(
            i,
            tonumber(surfaceData and surfaceData.id) or -1,
            tostring(info.reason or "?"),
            tonumber(info.planeDist) or 0,
            tonumber(info.normalDot) or 0,
            worldBSP.boolLabel(info.inBounds),
            tonumber(info.boundsDist) or 0,
            tonumber(info.u) or 0,
            tonumber(info.v) or 0,
            worldBSP.boolLabel(info.uvInBounds),
            worldBSP.boolLabel(info.inside),
            tonumber(info.edgeDistance) or 0,
            worldBSP.surfaceSourceLabel(surfaceData),
            tostring(surfaceData and surfaceData.sourceSurfaceIndex or "?"),
            worldBSP.surfaceDisplacementDiagonalLabel(surfaceData),
            tostring(surfaceData and surfaceData.materialName or "?")
        ))
    end
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
            worldBSP.formatVec(tr.HitPos),
            worldBSP.formatVec(tr.HitNormal)
        ))
        worldBSP.printTraceDebugCandidates(
            surfaces,
            #surfaces,
            tr.HitPos,
            normalizedVec(tr.HitNormal, M.PICKING_VECTOR_EPSILON_SQR) or tr.HitNormal,
            traceHitsDisplacement(tr)
        )
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

    print(("Magic Align: World BSP debug: match=%s surface=%d candidates=%d raw=(%.3f, %.3f)%s hit=%s hitNormal=%s surfaceNormal=%s diag=%s."):format(
        tostring(match.match or "unknown"),
        tonumber(match.surface and match.surface.id) or -1,
        #surfaces,
        tonumber(match.u) or 0,
        tonumber(match.v) or 0,
        snapDetails,
        worldBSP.formatVec(tr.HitPos),
        worldBSP.formatVec(tr.HitNormal),
        worldBSP.formatVec(match.surface and match.surface.normal),
        worldBSP.surfaceDisplacementDiagonalLabel(match.surface)
    ))
end

function worldBSP.debugCache()
    local progress = worldBSP.cacheProgress()
    print(("Magic Align: World BSP cache: status=%s stage=%s progress=%s eta=%s stageProgress=%s stageEta=%s cached=%d skipped=%d displacements=%d displacementSurfaces=%d displacementSkipped=%d error=%s."):format(
        tostring(cache.status),
        tostring(progress.stage or "nil"),
        worldBSP.formatProgressPercent(progress.percent),
        worldBSP.formatProgressSeconds(progress.eta),
        worldBSP.formatProgressPercent(progress.stagePercent),
        worldBSP.formatProgressSeconds(progress.stageEta),
        tonumber(cache.cached) or 0,
        tonumber(cache.skipped) or 0,
        tonumber(cache.displacements) or 0,
        tonumber(cache.displacementSurfaces) or 0,
        tonumber(cache.displacementSkipped) or 0,
        tostring(cache.error or cache.displacementError or "nil")
    ))
end

if concommand and isfunction(concommand.Add) then
    if isfunction(concommand.Remove) then
        concommand.Remove("magic_align_world_bsp_debug_trace")
        concommand.Remove("magic_align_world_bsp_debug_cache")
    end

    concommand.Add("magic_align_world_bsp_debug_trace", function()
        worldBSP.debugTrace()
    end)
    concommand.Add("magic_align_world_bsp_debug_cache", function()
        worldBSP.debugCache()
    end)
end

return worldBSP
