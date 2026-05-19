MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local worldBSP = client.WorldBSP or {}
client.WorldBSP = worldBSP

local VectorP = M.VectorP
local isvector = M.IsVectorLike
local copyVec = M.CopyVectorPrecise
local normalizedVec = M.NormalizeVectorPrecise
local dot = M.DotVectorsPrecise
local cross = M.CrossVectorsPrecise

local CACHE_VERSION = 5

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
    boundaryGridTolerance = 0.05,
    boundarySnapPromoteTolerance = 0.45,
    boundaryRepairTolerance = 1.25,
    gridBoundaryTolerance = 1.25,
    cornerSnapTolerance = 2,
    hintAfterSeconds = 5,
    defaultBudgetMs = 1,
    minBudgetMs = 0.1,
    maxBudgetMs = 8
}

local cache = worldBSP.cache or {}
worldBSP.cache = cache

local function now()
    return SysTime and SysTime() or RealTime()
end

local function currentMap()
    return game and game.GetMap and game.GetMap() or ""
end

local function resetCache(status)
    cache.version = CACHE_VERSION
    cache.map = currentMap()
    cache.status = status or "idle"
    cache.surfaces = {}
    cache.index = {}
    cache.largeSurfaces = {}
    cache.total = 0
    cache.cached = 0
    cache.skipped = 0
    cache.startedAt = nil
    cache.readyAt = nil
    cache.worker = nil
    cache.hintedSlow = false
    cache.error = nil
end

if cache.status == nil or cache.version ~= CACHE_VERSION then
    resetCache("idle")
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

local function worldFromUv(surfaceData, u, v)
    return surfaceData.origin + surfaceData.uAxis * u + surfaceData.vAxis * v
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

    return {
        id = index,
        vertices = vertices,
        polygon = polygon,
        origin = origin,
        normal = normal,
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

local function finishBuild()
    cache.status = "ready"
    cache.readyAt = now()
    cache.worker = nil

    local seconds = math.max(cache.readyAt - (cache.startedAt or cache.readyAt), 0)
    print(("Magic Align: World BSP snapping ready in %.2fs (%d surfaces cached, %d skipped)."):format(
        seconds,
        cache.cached or 0,
        cache.skipped or 0
    ))

    if seconds >= CONFIG.hintAfterSeconds and notification and notification.AddLegacy then
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
        cache.status = "unavailable"
        cache.worker = nil
        cache.error = "world brush surfaces unavailable"
        print("Magic Align: World BSP snapping unavailable; no world brush surfaces were returned.")
        return
    end

    cache.total = #surfaces
    if cache.total <= 0 then
        cache.status = "unavailable"
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
        else
            cache.skipped = cache.skipped + 1
        end

        maybeYield()
    end

    finishBuild()
end

local function startBuild()
    resetCache("building")
    cache.startedAt = now()
    cache.worker = coroutine.create(buildWorker)
end

local function maybeSlowHint()
    if cache.hintedSlow or cache.status ~= "building" then return end
    if now() - (cache.startedAt or now()) < CONFIG.hintAfterSeconds then return end

    cache.hintedSlow = true
    print("Magic Align: World BSP snapping is still building...")
    if notification and notification.AddLegacy then
        notification.AddLegacy("Magic Align world snapping is still building...", NOTIFY_HINT, 4)
    end
end

function worldBSP.update(settings)
    if not settings or not settings.worldBspSnap then return end

    if cache.version ~= CACHE_VERSION or cache.map ~= currentMap() or cache.status == "idle" then
        startBuild()
    end

    if cache.status ~= "building" or not cache.worker then return end

    cache.frameStartedAt = now()
    cache.frameBudgetMs = readBudgetMs(settings)

    local worker = cache.worker
    local ok, err = coroutine.resume(worker)
    if not ok then
        cache.status = "error"
        cache.error = tostring(err)
        cache.worker = nil
        print("Magic Align: World BSP snapping failed: " .. cache.error)
        return
    end

    if coroutine.status(worker) == "dead" and cache.status == "building" then
        finishBuild()
    end

    maybeSlowHint()
end

function worldBSP.isReady()
    return cache.status == "ready"
end

local function querySurfaces(worldPos)
    if not isvector(worldPos) then return end

    local surfaces = {}
    local count = 0
    local seen = {}
    local x = cellCoord(worldPos.x)
    local y = cellCoord(worldPos.y)
    local z = cellCoord(worldPos.z)

    for cx = x - CONFIG.queryCellRadius, x + CONFIG.queryCellRadius do
        for cy = y - CONFIG.queryCellRadius, y + CONFIG.queryCellRadius do
            for cz = z - CONFIG.queryCellRadius, z + CONFIG.queryCellRadius do
                local cell = cache.index and cache.index[cellKey(cx, cy, cz)] or nil
                if cell then
                    for i = 1, #cell do
                        local surfaceData = cell[i]
                        if not seen[surfaceData] then
                            seen[surfaceData] = true
                            count = count + 1
                            surfaces[count] = surfaceData
                        end
                    end
                end
            end
        end
    end

    for i = 1, #(cache.largeSurfaces or {}) do
        local surfaceData = cache.largeSurfaces[i]
        if not seen[surfaceData] then
            seen[surfaceData] = true
            count = count + 1
            surfaces[count] = surfaceData
        end
    end

    return surfaces
end

local function pointInsideWorldBounds(surfaceData, worldPos, tolerance)
    local mins = surfaceData.worldMins
    local maxs = surfaceData.worldMaxs
    local eps = tolerance or CONFIG.boundsTolerance

    return worldPos.x >= mins.x - eps and worldPos.x <= maxs.x + eps
        and worldPos.y >= mins.y - eps and worldPos.y <= maxs.y + eps
        and worldPos.z >= mins.z - eps and worldPos.z <= maxs.z + eps
end

local function traceRayInfo(tr, hitPos)
    local start = isvector(tr.StartPos) and copyVec(tr.StartPos) or nil
    if not start and IsValid(LocalPlayer()) then
        start = copyVec(LocalPlayer():GetShootPos())
    end
    if not isvector(start) then return end

    local dir = normalizedVec(hitPos - start, M.PICKING_VECTOR_EPSILON_SQR)
    if not dir then
        dir = isvector(tr.Normal) and normalizedVec(copyVec(tr.Normal), M.PICKING_VECTOR_EPSILON_SQR) or nil
    end
    if not dir then return end

    local hitDistance = math.sqrt(M.VectorLengthSqrPrecise(hitPos - start))
    return start, dir, hitDistance
end

local function findSurfaceForTrace(tr)
    if cache.status ~= "ready" or not tr or not isvector(tr.HitPos) or not isvector(tr.HitNormal) then return end

    local hitPos = copyVec(tr.HitPos)
    local hitNormal = copyVec(tr.HitNormal)
    if not isvector(hitPos) or not isvector(hitNormal) then return end

    hitNormal = normalizedVec(hitNormal, M.PICKING_VECTOR_EPSILON_SQR)
    if not hitNormal then return end

    local surfaces = querySurfaces(hitPos)
    if not surfaces or #surfaces == 0 then return end

    local rayStart, rayDir, rayHitDistance = traceRayInfo(tr, hitPos)
    local bestStrict
    local bestStrictScore
    local bestRay
    local bestRayScore
    local bestEdge
    local bestEdgeScore
    for i = 1, #surfaces do
        local surfaceData = surfaces[i]
        if pointInsideWorldBounds(surfaceData, hitPos) then
            local signedPlaneDist = dot(hitPos - surfaceData.origin, surfaceData.normal)
            local planeDist = math.abs(signedPlaneDist)
            if planeDist <= CONFIG.planeTolerance then
                local normalDot = dot(surfaceData.normal, hitNormal)
                local absNormalDot = math.abs(normalDot)
                if absNormalDot >= CONFIG.normalDotMin then
                    local projectedHit = hitPos - surfaceData.normal * signedPlaneDist
                    local u, v = surfaceUv(surfaceData, projectedHit)
                    if u >= surfaceData.uMin - CONFIG.boundsTolerance
                        and u <= surfaceData.uMax + CONFIG.boundsTolerance
                        and v >= surfaceData.vMin - CONFIG.boundsTolerance
                        and v <= surfaceData.vMax + CONFIG.boundsTolerance then
                        local normalPenalty = (1 - absNormalDot) * 10

                        if planeDist <= CONFIG.surfacePickTolerance
                            and pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonPickTolerance) then
                            local score = planeDist + normalPenalty
                            if not bestStrictScore or score < bestStrictScore then
                                bestStrict = {
                                    surface = surfaceData,
                                    normalSign = normalDot < 0 and -1 or 1,
                                    u = u,
                                    v = v,
                                    projectedHit = projectedHit,
                                    match = "strict"
                                }
                                bestStrictScore = score
                            end
                        else
                            local edgeDistance = polygonEdgeDistance(surfaceData.polygon, u, v)
                            if edgeDistance <= CONFIG.edgePickTolerance then
                                local score = planeDist + normalPenalty + edgeDistance * 4
                                if not bestEdgeScore or score < bestEdgeScore then
                                    bestEdge = {
                                        surface = surfaceData,
                                        normalSign = normalDot < 0 and -1 or 1,
                                        u = u,
                                        v = v,
                                        projectedHit = projectedHit,
                                        match = "edge"
                                    }
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
                local t = dot(surfaceData.origin - rayStart, surfaceData.normal) / denom
                local traceDistance = math.abs(t - rayHitDistance)
                if t >= 0 and traceDistance <= CONFIG.rayPickTolerance then
                    local rayHit = rayStart + rayDir * t
                    if pointInsideWorldBounds(surfaceData, rayHit, CONFIG.boundsTolerance + CONFIG.rayPickTolerance) then
                        local u, v = surfaceUv(surfaceData, rayHit)
                        if u >= surfaceData.uMin - CONFIG.boundsTolerance
                            and u <= surfaceData.uMax + CONFIG.boundsTolerance
                            and v >= surfaceData.vMin - CONFIG.boundsTolerance
                            and v <= surfaceData.vMax + CONFIG.boundsTolerance
                            and pointInPolygon2D(surfaceData.polygon, u, v, CONFIG.polygonPickTolerance) then
                            local normalDot = dot(surfaceData.normal, hitNormal)
                            local normalPenalty = (1 - math.min(math.abs(normalDot), 1)) * CONFIG.rayNormalWeight
                            local score = traceDistance + (1 - math.min(math.abs(denom), 1)) * 0.25 + normalPenalty
                            if not bestRayScore or score < bestRayScore then
                                bestRay = {
                                    surface = surfaceData,
                                    normalSign = normalDot < 0 and -1 or 1,
                                    u = u,
                                    v = v,
                                    projectedHit = rayHit,
                                    match = "ray"
                                }
                                bestRayScore = score
                            end
                        end
                    end
                end
            end
        end
    end

    if bestRay and bestRayScore and bestRayScore <= CONFIG.rayPreferScore then
        return bestRay
    end

    return bestStrict or bestRay or bestEdge
end

local function gridPointValue(grid, axisKey, index)
    local div = axisKey == "u" and grid.divU or grid.divV
    local minValue = axisKey == "u" and grid.uMin or grid.vMin
    local maxValue = axisKey == "u" and grid.uMax or grid.vMax
    local step = axisKey == "u" and grid.stepU or grid.stepV

    if index == div then return maxValue end
    return minValue + step * index
end

local function gridEntriesForFace(face)
    local grids = {}
    local seen = {}

    local function addGrid(grid, id)
        if not grid or seen[grid] then return end
        seen[grid] = true
        grids[#grids + 1] = { grid = grid, id = id }
    end

    addGrid(face.gridA, "A")
    addGrid(face.gridB, "B")

    return grids
end

local function gridLineInfo(grid, axisKey, value)
    if not grid then return end

    local div = axisKey == "u" and grid.divU or grid.divV
    div = math.max(math.Round(tonumber(div) or 0), 0)
    if div <= 0 then return end

    local minValue = axisKey == "u" and grid.uMin or grid.vMin
    local maxValue = axisKey == "u" and grid.uMax or grid.vMax
    local step = axisKey == "u" and grid.stepU or grid.stepV
    if step == nil or math.abs(step) <= M.COMPUTE_EPSILON then return end

    local index = math.Clamp(math.Round((value - minValue) / step), 0, div)
    local lineValue = gridPointValue(grid, axisKey, index)
    if math.abs(lineValue - value) > CONFIG.boundaryGridTolerance then return end

    return index, div > 0 and (index / div) * 100 or 0, lineValue
end

local function nearestGridLineInfo(face, axisKey, value)
    local grids = gridEntriesForFace(face)
    local best

    for _, entry in ipairs(grids) do
        local index, percent, lineValue = gridLineInfo(entry.grid, axisKey, value)
        if index then
            local dist = math.abs(lineValue - value)
            if not best or dist < best.dist then
                best = {
                    grid = entry.grid,
                    gridId = entry.id,
                    index = index,
                    percent = percent,
                    value = lineValue,
                    dist = dist
                }
            end
        end
    end

    return best
end

local function snapCandidateDistance(candidate, rawU, rawV)
    if not candidate or candidate.u == nil or candidate.v == nil then return math.huge end

    return (candidate.u - rawU) ^ 2 + (candidate.v - rawV) ^ 2
end

local function keepNearestSnapCandidate(best, candidate, rawU, rawV)
    if not candidate then return best end

    candidate.dist = snapCandidateDistance(candidate, rawU, rawV)
    if not best or candidate.dist < best.dist then
        return candidate
    end

    return best
end

local function applyAxisInfo(candidate, axisKey, info, snapCoordinate)
    if not info then return end

    if axisKey == "u" then
        if snapCoordinate and info.value ~= nil then
            candidate.u = info.value
        end
        candidate.gridU = info.grid
        candidate.gridUId = info.gridId
        candidate.indexU = info.index
        candidate.percentU = info.percent
        return
    end

    if snapCoordinate and info.value ~= nil then
        candidate.v = info.value
    end
    candidate.gridV = info.grid
    candidate.gridVId = info.gridId
    candidate.indexV = info.index
    candidate.percentV = info.percent
end

local function fallbackBoundaryGrid(face)
    if face.gridA then return face.gridA end
    if face.gridB then return face.gridB end

    if not face.boundaryGrid then
        face.boundaryGrid = {
            uMin = face.uMin,
            uMax = face.uMax,
            vMin = face.vMin,
            vMax = face.vMax,
            divU = 1,
            divV = 1,
            stepU = face.uMax - face.uMin,
            stepV = face.vMax - face.vMin
        }
    end

    return face.boundaryGrid
end

local function applyEdgeAxisInfo(candidate, axisKey, face)
    local grid = fallbackBoundaryGrid(face)
    if not grid then return end

    if axisKey == "u" then
        candidate.gridU = grid
        candidate.gridUId = "E"
        candidate.indexU = nil
        candidate.percentU = nil
        return
    end

    candidate.gridV = grid
    candidate.gridVId = "E"
    candidate.indexV = nil
    candidate.percentV = nil
end

local function applyBoundaryAxisInfo(candidate, axisKey, face, value, allowEdgeLine, snapCoordinate)
    local minValue = axisKey == "u" and face.uMin or face.vMin
    local maxValue = axisKey == "u" and face.uMax or face.vMax

    if math.abs(value - minValue) <= CONFIG.boundarySnapPromoteTolerance then
        local info = nearestGridLineInfo(face, axisKey, minValue)
        if info then
            applyAxisInfo(candidate, axisKey, info, snapCoordinate)
        elseif allowEdgeLine then
            applyEdgeAxisInfo(candidate, axisKey, face)
        end
        return
    end

    if math.abs(value - maxValue) <= CONFIG.boundarySnapPromoteTolerance then
        local info = nearestGridLineInfo(face, axisKey, maxValue)
        if info then
            applyAxisInfo(candidate, axisKey, info, snapCoordinate)
        elseif allowEdgeLine then
            applyEdgeAxisInfo(candidate, axisKey, face)
        end
        return
    end

    local info = nearestGridLineInfo(face, axisKey, value)
    if info then
        applyAxisInfo(candidate, axisKey, info, snapCoordinate)
    elseif allowEdgeLine then
        applyEdgeAxisInfo(candidate, axisKey, face)
    end
end

local function gridLineCandidate(face, axisKey, snapped, rawU, rawV)
    if axisKey == "u" then
        if not snapped.gridU or snapped.u == nil then return end

        local minV, maxV = clippedLineRange(face, "u", snapped.u)
        if not minV or not maxV then return end

        return {
            u = snapped.u,
            v = math.Clamp(rawV, minV, maxV),
            gridU = snapped.gridU,
            gridV = nil,
            gridUId = snapped.gridUId,
            gridVId = nil,
            indexU = snapped.indexU,
            indexV = nil,
            percentU = snapped.percentU,
            percentV = nil
        }
    end

    if not snapped.gridV or snapped.v == nil then return end

    local minU, maxU = clippedLineRange(face, "v", snapped.v)
    if not minU or not maxU then return end

    return {
        u = math.Clamp(rawU, minU, maxU),
        v = snapped.v,
        gridU = nil,
        gridV = snapped.gridV,
        gridUId = nil,
        gridVId = snapped.gridVId,
        indexU = nil,
        indexV = snapped.indexV,
        percentU = nil,
        percentV = snapped.percentV
    }
end

local function keepBestBoundaryIntersection(best, candidate)
    if not candidate then return best end
    if not best or candidate.boundaryDist < best.boundaryDist then
        return candidate
    end
    if math.abs(candidate.boundaryDist - best.boundaryDist) <= M.COMPUTE_EPSILON and candidate.dist < best.dist then
        return candidate
    end

    return best
end

local function gridBoundaryIntersectionCandidate(face, axisKey, rawU, rawV, snapped, testU, testV)
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 2 or not snapped then return end

    local grid = axisKey == "u" and snapped.gridU or snapped.gridV
    local value = axisKey == "u" and snapped.u or snapped.v
    if not grid or value == nil then return end

    testU = tonumber(testU) or rawU
    testV = tonumber(testV) or rawV

    local best
    local previous = polygon[#polygon]
    for i = 1, #polygon do
        local current = polygon[i]
        local a = axisKey == "u" and previous.u or previous.v
        local b = axisKey == "u" and current.u or current.v
        local oa = axisKey == "u" and previous.v or previous.u
        local ob = axisKey == "u" and current.v or current.u
        local otherGrid = axisKey == "u" and snapped.gridV or snapped.gridU
        local otherValue = axisKey == "u" and snapped.v or snapped.u
        local useOtherGrid = false
        local other

        if math.abs(a - value) <= CONFIG.boundaryGridTolerance
            and math.abs(b - value) <= CONFIG.boundaryGridTolerance then
            local target = axisKey == "u" and testV or testU
            if otherGrid and otherValue ~= nil then
                target = otherValue
            end
            other = math.Clamp(target, math.min(oa, ob), math.max(oa, ob))
            useOtherGrid = otherGrid and otherValue ~= nil
                and math.abs(other - otherValue) <= CONFIG.boundaryGridTolerance
        elseif math.abs(a - b) > M.COMPUTE_EPSILON
            and value >= math.min(a, b) - CONFIG.boundaryGridTolerance
            and value <= math.max(a, b) + CONFIG.boundaryGridTolerance then
            local t = math.Clamp((value - a) / (b - a), 0, 1)
            other = oa + (ob - oa) * t
        end

        if other ~= nil then
            local candidate = {
                u = axisKey == "u" and value or other,
                v = axisKey == "u" and other or value,
                gridU = nil,
                gridV = nil,
                gridUId = nil,
                gridVId = nil,
                indexU = nil,
                indexV = nil,
                percentU = nil,
                percentV = nil
            }

            if axisKey == "u" then
                candidate.gridU = snapped.gridU
                candidate.gridUId = snapped.gridUId
                candidate.indexU = snapped.indexU
                candidate.percentU = snapped.percentU
                if useOtherGrid then
                    candidate.gridV = snapped.gridV
                    candidate.gridVId = snapped.gridVId
                    candidate.indexV = snapped.indexV
                    candidate.percentV = snapped.percentV
                end
            else
                candidate.gridV = snapped.gridV
                candidate.gridVId = snapped.gridVId
                candidate.indexV = snapped.indexV
                candidate.percentV = snapped.percentV
                if useOtherGrid then
                    candidate.gridU = snapped.gridU
                    candidate.gridUId = snapped.gridUId
                    candidate.indexU = snapped.indexU
                    candidate.percentU = snapped.percentU
                end
            end

            candidate.boundaryKind = "grid_boundary"
            candidate.boundaryDist = snapCandidateDistance(candidate, testU, testV)
            candidate.dist = snapCandidateDistance(candidate, rawU, rawV)
            best = keepBestBoundaryIntersection(best, candidate)
        end

        previous = current
    end

    return best
end

local function nearestGridBoundaryCandidate(face, rawU, rawV, snapped, testU, testV)
    local best
    best = keepBestBoundaryIntersection(
        best,
        gridBoundaryIntersectionCandidate(face, "u", rawU, rawV, snapped, testU, testV)
    )
    best = keepBestBoundaryIntersection(
        best,
        gridBoundaryIntersectionCandidate(face, "v", rawU, rawV, snapped, testU, testV)
    )

    return best
end

local function cornerSnapCandidate(face, rawU, rawV, testU, testV)
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 2 then return end

    testU = tonumber(testU) or rawU
    testV = tonumber(testV) or rawV

    local best
    for i = 1, #polygon do
        local vertex = polygon[i]
        local du = testU - vertex.u
        local dv = testV - vertex.v
        local distSqr = du * du + dv * dv
        if not best or distSqr < best.dist then
            best = {
                u = vertex.u,
                v = vertex.v,
                dist = distSqr
            }
        end
    end

    if not best then return end

    return {
        u = best.u,
        v = best.v,
        gridU = nil,
        gridV = nil,
        gridUId = nil,
        gridVId = nil,
        indexU = nil,
        indexV = nil,
        percentU = nil,
        percentV = nil,
        boundaryKind = "corner",
        boundaryDist = best.dist,
        dist = snapCandidateDistance(best, rawU, rawV)
    }
end

local function boundarySnapCandidate(face, rawU, rawV, snapped, testU, testV)
    local polygon = face and face.polygon
    if not istable(polygon) or #polygon < 2 then return end

    testU = tonumber(testU) or rawU
    testV = tonumber(testV) or rawV

    local best
    local previous = polygon[#polygon]
    for i = 1, #polygon do
        local current = polygon[i]
        local u, v, _, distSqr = closestPointOnSegment2D(testU, testV, previous, current)
        if not best or distSqr < best.dist then
            best = {
                u = u,
                v = v,
                dist = distSqr,
                a = previous,
                b = current
            }
        end

        previous = current
    end

    if not best then return end

    local corner = cornerSnapCandidate(face, rawU, rawV, testU, testV)
    if corner and corner.boundaryDist <= CONFIG.cornerSnapTolerance * CONFIG.cornerSnapTolerance then
        return corner
    end

    local du = math.abs(best.b.u - best.a.u)
    local dv = math.abs(best.b.v - best.a.v)
    local candidate = {
        u = best.u,
        v = best.v,
        gridU = nil,
        gridV = nil,
        gridUId = nil,
        gridVId = nil,
        indexU = nil,
        indexV = nil,
        percentU = nil,
        percentV = nil
    }

    if du <= CONFIG.boundaryGridTolerance then
        candidate.u = (best.a.u + best.b.u) * 0.5
        if snapped and snapped.v ~= nil then
            local clampedV = math.Clamp(snapped.v, math.min(best.a.v, best.b.v), math.max(best.a.v, best.b.v))
            candidate.v = clampedV
            if math.abs(clampedV - snapped.v) <= CONFIG.boundaryGridTolerance then
                candidate.gridV = snapped.gridV
                candidate.gridVId = snapped.gridVId
                candidate.indexV = snapped.indexV
                candidate.percentV = snapped.percentV
            else
                applyBoundaryAxisInfo(candidate, "v", face, candidate.v, false, true)
            end
        else
            candidate.v = best.v
            applyBoundaryAxisInfo(candidate, "v", face, candidate.v, false, true)
        end

        applyBoundaryAxisInfo(candidate, "u", face, candidate.u, true, true)
    elseif dv <= CONFIG.boundaryGridTolerance then
        if snapped and snapped.u ~= nil then
            local clampedU = math.Clamp(snapped.u, math.min(best.a.u, best.b.u), math.max(best.a.u, best.b.u))
            candidate.u = clampedU
            if math.abs(clampedU - snapped.u) <= CONFIG.boundaryGridTolerance then
                candidate.gridU = snapped.gridU
                candidate.gridUId = snapped.gridUId
                candidate.indexU = snapped.indexU
                candidate.percentU = snapped.percentU
            else
                applyBoundaryAxisInfo(candidate, "u", face, candidate.u, false, true)
            end
        else
            candidate.u = best.u
            applyBoundaryAxisInfo(candidate, "u", face, candidate.u, false, true)
        end

        candidate.v = (best.a.v + best.b.v) * 0.5
        applyBoundaryAxisInfo(candidate, "v", face, candidate.v, true, true)
    end

    candidate.boundaryKind = "boundary"
    candidate.boundaryDist = best.dist
    candidate.dist = snapCandidateDistance(candidate, rawU, rawV)
    return candidate
end

local function idealBoundarySnapCandidate(face, rawU, rawV, snapped)
    if not snapped or snapped.u == nil or snapped.v == nil then return end

    return boundarySnapCandidate(face, rawU, rawV, snapped, snapped.u, snapped.v)
end

local function nearestPolygonSnapPoint(face, rawU, rawV, snapped)
    local best

    best = keepNearestSnapCandidate(best, cornerSnapCandidate(face, rawU, rawV), rawU, rawV)
    best = keepNearestSnapCandidate(best, nearestGridBoundaryCandidate(face, rawU, rawV, snapped, snapped and snapped.u, snapped and snapped.v), rawU, rawV)
    best = keepNearestSnapCandidate(best, idealBoundarySnapCandidate(face, rawU, rawV, snapped), rawU, rawV)
    best = keepNearestSnapCandidate(best, boundarySnapCandidate(face, rawU, rawV, snapped), rawU, rawV)
    best = keepNearestSnapCandidate(best, gridLineCandidate(face, "u", snapped, rawU, rawV), rawU, rawV)
    best = keepNearestSnapCandidate(best, gridLineCandidate(face, "v", snapped, rawU, rawV), rawU, rawV)

    local grids = gridEntriesForFace(face)

    for _, uEntry in ipairs(grids) do
        local uGrid = uEntry.grid
        for _, vEntry in ipairs(grids) do
            local vGrid = vEntry.grid
            for uIndex = 0, math.max(uGrid.divU or 0, 0) do
                local u = gridPointValue(uGrid, "u", uIndex)
                for vIndex = 0, math.max(vGrid.divV or 0, 0) do
                    local v = gridPointValue(vGrid, "v", vIndex)
                    if pointInPolygon2D(face.polygon, u, v, CONFIG.polygonTolerance) then
                        best = keepNearestSnapCandidate(best, {
                            u = u,
                            v = v,
                            gridU = uGrid,
                            gridV = vGrid,
                            gridUId = uEntry.id,
                            gridVId = vEntry.id,
                            indexU = uIndex,
                            indexV = vIndex,
                            percentU = (uGrid.divU or 0) > 0 and (uIndex / uGrid.divU) * 100 or 0,
                            percentV = (vGrid.divV or 0) > 0 and (vIndex / vGrid.divV) * 100 or 0
                        }, rawU, rawV)
                    end
                end
            end
        end
    end

    return best
end

local function snapModeForBoundary(candidate, repair)
    local kind = candidate and candidate.boundaryKind
    if kind == "grid_boundary" then
        return repair and "grid_boundary_repair" or "grid_boundary"
    end
    if kind == "corner" then
        return repair and "corner_repair" or "corner"
    end

    return repair and "boundary_repair" or "boundary"
end

local function promoteToleranceForBoundary(candidate)
    local kind = candidate and candidate.boundaryKind
    if kind == "grid_boundary" then return CONFIG.gridBoundaryTolerance end
    if kind == "corner" then return CONFIG.cornerSnapTolerance end

    return CONFIG.boundarySnapPromoteTolerance
end

local function repairToleranceForBoundary(candidate)
    local kind = candidate and candidate.boundaryKind
    if kind == "grid_boundary" then return CONFIG.gridBoundaryTolerance end
    if kind == "corner" then return CONFIG.cornerSnapTolerance end

    return CONFIG.boundaryRepairTolerance
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

    local snapFaceCoordinates = client.snapFaceCoordinates
    local snapped = isfunction(snapFaceCoordinates)
        and snapFaceCoordinates(settings or {}, face, rawU, rawV)
        or {
            u = math.Clamp(rawU, face.uMin, face.uMax),
            v = math.Clamp(rawV, face.vMin, face.vMax)
        }

    local u = snapped.u
    local v = snapped.v
    local snapMode = "grid"
    local boundary

    if not (settings and settings.shift) then
        boundary = boundarySnapCandidate(face, rawU, rawV, snapped)
        local gridBoundary = nearestGridBoundaryCandidate(face, rawU, rawV, snapped, rawU, rawV)
        local currentDist = snapCandidateDistance({ u = u, v = v }, rawU, rawV)
        local promoteBoundary = keepBestBoundaryIntersection(nil, gridBoundary)
        promoteBoundary = keepBestBoundaryIntersection(promoteBoundary, boundary)
        if boundary and boundary.boundaryKind == "corner" then
            promoteBoundary = boundary
        end
        local promoteBoundaryDist = promoteBoundary and (promoteBoundary.boundaryDist or promoteBoundary.dist) or math.huge
        local promoteTolerance = promoteToleranceForBoundary(promoteBoundary)
        if promoteBoundary
            and promoteBoundaryDist <= promoteTolerance * promoteTolerance
            and (promoteBoundary.boundaryKind ~= "boundary" or promoteBoundary.dist <= currentDist) then
            u = promoteBoundary.u
            v = promoteBoundary.v
            snapped.gridU = promoteBoundary.gridU
            snapped.gridV = promoteBoundary.gridV
            snapped.gridUId = promoteBoundary.gridUId
            snapped.gridVId = promoteBoundary.gridVId
            snapped.indexU = promoteBoundary.indexU
            snapped.indexV = promoteBoundary.indexV
            snapped.percentU = promoteBoundary.percentU
            snapped.percentV = promoteBoundary.percentV
            snapMode = snapModeForBoundary(promoteBoundary, false)
        end
    end

    if not (settings and settings.shift) and not pointInPolygon2D(face.polygon, u, v, CONFIG.polygonTolerance) then
        local repairBoundary = boundary and boundary.boundaryKind == "corner" and boundary
            or nearestGridBoundaryCandidate(face, rawU, rawV, snapped, snapped and snapped.u, snapped and snapped.v)
            or idealBoundarySnapCandidate(face, rawU, rawV, snapped)
            or boundary
            or boundarySnapCandidate(face, rawU, rawV, snapped)
        local repairBoundaryDist = repairBoundary and (repairBoundary.boundaryDist or repairBoundary.dist) or math.huge
        local repairTolerance = repairToleranceForBoundary(repairBoundary)
        local nearest = repairBoundary
            and repairBoundaryDist <= repairTolerance * repairTolerance
            and repairBoundary
            or nearestPolygonSnapPoint(face, rawU, rawV, snapped)
        if nearest then
            u = nearest.u
            v = nearest.v
            snapped.gridU = nearest.gridU
            snapped.gridV = nearest.gridV
            snapped.gridUId = nearest.gridUId
            snapped.gridVId = nearest.gridVId
            snapped.indexU = nearest.indexU
            snapped.indexV = nearest.indexV
            snapped.percentU = nearest.percentU
            snapped.percentV = nearest.percentV
            snapMode = nearest == repairBoundary
                and snapModeForBoundary(repairBoundary, true)
                or (nearest.boundaryKind == "corner" and "corner_repair" or "repair")
        else
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
            snapMode = "clamp"
        end
    end

    face.uSnap, face.vSnap = u, v
    face.snapGridU = snapped.gridU
    face.snapGridV = snapped.gridV
    face.snapGridUId = snapped.gridUId
    face.snapGridVId = snapped.gridVId
    face.snapIndexU, face.snapIndexV = snapped.indexU, snapped.indexV
    face.snapPercentU, face.snapPercentV = snapped.percentU, snapped.percentV
    face.snapMode = snapMode

    return face, worldFromUv(surfaceData, u, v)
end

function worldBSP.candidateFromTrace(tr, settings)
    if not settings or not settings.worldBspSnap or cache.status ~= "ready" then return end

    local match = findSurfaceForTrace(tr)
    if not match then return end

    local surfaceData = match.surface
    local normal = match.normalSign < 0 and -surfaceData.normal or surfaceData.normal
    local face, worldPos = buildFace(surfaceData, normal, match.u, match.v, settings)
    if not face or not isvector(worldPos) then return end

    worldBSP.lastDebug = {
        match = match.match,
        surfaceId = surfaceData.id,
        rawU = match.u,
        rawV = match.v,
        snapU = face.uSnap,
        snapV = face.vSnap,
        snapGridUId = face.snapGridUId,
        snapGridVId = face.snapGridVId,
        snapIndexU = face.snapIndexU,
        snapIndexV = face.snapIndexV,
        snapMode = face.snapMode,
        normal = surfaceData.normal,
        worldPos = worldPos
    }

    return {
        ent = M.WORLD_TARGET,
        localPos = copyVec(worldPos),
        worldPos = copyVec(worldPos),
        localNormal = copyVec(normal),
        normal = copyVec(normal),
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
