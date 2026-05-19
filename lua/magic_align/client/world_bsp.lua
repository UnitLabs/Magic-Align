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

local CACHE_VERSION = 2

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
    queryCellRadius = 1,
    vertexMergeToleranceSqr = 1e-8,
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

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 then return math.atan(y / x) - math.pi end
    if y > 0 then return math.pi * 0.5 end
    if y < 0 then return -math.pi * 0.5 end
    return 0
end

local function centerOfVertices(vertices)
    local center = VectorP(0, 0, 0)
    for i = 1, #vertices do
        center = center + vertices[i]
    end

    return center / #vertices
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

local function orderSurfaceVertices(vertices, normal)
    local uAxis = projectedAxisFromVertices(vertices, normal)
    if not uAxis then return end

    local vAxis = normalizedVec(cross(normal, uAxis), M.PICKING_VECTOR_EPSILON_SQR)
    if not vAxis then return end

    local center = centerOfVertices(vertices)
    local entries = {}
    for i = 1, #vertices do
        local delta = vertices[i] - center
        local u = dot(delta, uAxis)
        local v = dot(delta, vAxis)
        entries[i] = {
            vertex = vertices[i],
            angle = atan2(v, u),
            distSqr = u * u + v * v
        }
    end

    table.sort(entries, function(a, b)
        if math.abs(a.angle - b.angle) <= M.COMPUTE_EPSILON then
            return a.distSqr < b.distSqr
        end

        return a.angle < b.angle
    end)

    local ordered = {}
    for i = 1, #entries do
        ordered[i] = entries[i].vertex
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

local function pointSegmentDistanceSqr2D(px, py, a, b)
    local abx, aby = b.u - a.u, b.v - a.v
    local lenSqr = abx * abx + aby * aby
    if lenSqr <= M.COMPUTE_EPSILON then
        local dx, dy = px - a.u, py - a.v
        return dx * dx + dy * dy
    end

    local t = ((px - a.u) * abx + (py - a.v) * aby) / lenSqr
    t = math.Clamp(t, 0, 1)

    local cx = a.u + abx * t
    local cy = a.v + aby * t
    local dx, dy = px - cx, py - cy
    return dx * dx + dy * dy
end

local function polygonEdgeDistance(polygon, u, v)
    if not istable(polygon) or #polygon < 2 then return math.huge end

    local best
    local previous = polygon[#polygon]
    for i = 1, #polygon do
        local current = polygon[i]
        local distSqr = pointSegmentDistanceSqr2D(u, v, previous, current)
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

    normal = computeNormal(vertices) or normal

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
                            local score = traceDistance + (1 - math.min(math.abs(denom), 1)) * 0.25
                            if not bestRayScore or score < bestRayScore then
                                bestRay = {
                                    surface = surfaceData,
                                    normalSign = denom > 0 and -1 or 1,
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

local function nearestPolygonGridPoint(face, rawU, rawV)
    local best
    local bestDist
    local grids = {}
    local seen = {}

    local function addGrid(grid, id)
        if not grid or seen[grid] then return end
        seen[grid] = true
        grids[#grids + 1] = { grid = grid, id = id }
    end

    addGrid(face.gridA, "A")
    addGrid(face.gridB, "B")

    for _, entry in ipairs(grids) do
        local grid = entry.grid
        for uIndex = 0, math.max(grid.divU or 0, 0) do
            local u = gridPointValue(grid, "u", uIndex)
            for vIndex = 0, math.max(grid.divV or 0, 0) do
                local v = gridPointValue(grid, "v", vIndex)
                if pointInPolygon2D(face.polygon, u, v, CONFIG.polygonTolerance) then
                    local dist = (u - rawU) ^ 2 + (v - rawV) ^ 2
                    if not bestDist or dist < bestDist then
                        bestDist = dist
                        best = {
                            u = u,
                            v = v,
                            grid = grid,
                            gridId = entry.id,
                            indexU = uIndex,
                            indexV = vIndex,
                            percentU = (grid.divU or 0) > 0 and (uIndex / grid.divU) * 100 or 0,
                            percentV = (grid.divV or 0) > 0 and (vIndex / grid.divV) * 100 or 0
                        }
                    end
                end
            end
        end
    end

    return best
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

    if not (settings and settings.shift) and not pointInPolygon2D(face.polygon, u, v, CONFIG.polygonTolerance) then
        local nearest = nearestPolygonGridPoint(face, rawU, rawV)
        if nearest then
            u = nearest.u
            v = nearest.v
            snapped.gridU = nearest.grid
            snapped.gridV = nearest.grid
            snapped.gridUId = nearest.gridId
            snapped.gridVId = nearest.gridId
            snapped.indexU = nearest.indexU
            snapped.indexV = nearest.indexV
            snapped.percentU = nearest.percentU
            snapped.percentV = nearest.percentV
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
        end
    end

    face.uSnap, face.vSnap = u, v
    face.snapGridU = snapped.gridU
    face.snapGridV = snapped.gridV
    face.snapGridUId = snapped.gridUId
    face.snapGridVId = snapped.gridVId
    face.snapIndexU, face.snapIndexV = snapped.indexU, snapped.indexV
    face.snapPercentU, face.snapPercentV = snapped.percentU, snapped.percentV

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

    print(("Magic Align: World BSP debug: match=%s surface=%d candidates=%d u=%.3f v=%.3f hit=%s normal=%s."):format(
        tostring(match.match or "unknown"),
        tonumber(match.surface and match.surface.id) or -1,
        #surfaces,
        tonumber(match.u) or 0,
        tonumber(match.v) or 0,
        formatVec(tr.HitPos),
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
