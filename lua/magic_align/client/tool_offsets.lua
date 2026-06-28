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
local toVector = M.ToVector
local PICK_CONFIG = core.PICK_CONFIG
local copyVec = core.copyVec
local comp = core.comp
local ZERO_VEC = core.ZERO_VEC
local setVec = core.setVec
local normalizedVec = core.normalizedVec
local clientNumber = core.clientNumber
local translationSnapStep = core.translationSnapStep
local boundsFor = core.boundsFor
local buildTraceProbeCandidate = core.buildTraceProbeCandidate
local function cfg(tool, out)
    out = out or {}
    out.gridA = math.Clamp(math.Round(clientNumber(tool, "grid_a", 12)), 2, 24)
    out.gridAMin = math.Clamp(math.Round(clientNumber(tool, "grid_a_min", 3)), 2, 24)
    out.gridB = math.Clamp(math.Round(clientNumber(tool, "grid_b", 8)), 2, 24)
    out.gridBMin = math.Clamp(math.Round(clientNumber(tool, "grid_b_min", 2)), 2, 24)
    out.gridBEnabled = clientNumber(tool, "grid_b_enable", 0) == 1
    out.minLength = math.Clamp(math.Round(clientNumber(tool, "min_length", 4)), 0, 12)
    out.traceSnapLength = clientNumber(tool, "trace_snap_length", 5)
    out.translationSnap = translationSnapStep(tool)
    out.worldTarget = clientNumber(tool, "world_target", 1) == 1
    out.worldBspSnap = clientNumber(tool, "world_bsp_snap", 1) == 1
    out.worldBspGridMode = string.lower(tostring(tool and tool.GetClientInfo and tool:GetClientInfo("world_bsp_grid_mode") or "global"))
    if out.worldBspGridMode ~= "global" and out.worldBspGridMode ~= "global_units" then
        out.worldBspGridMode = "per_surface"
    else
        out.worldBspGridMode = "global"
    end
    out.worldBspGridSize = math.Clamp(clientNumber(tool, "world_bsp_grid_size", 16), 0.125, 512)
    out.worldBspBudgetMs = math.Clamp(clientNumber(tool, "world_bsp_budget_ms", 2.5), 0.1, 50)
    out.worldBspIgnoreBrushBlockers = true
    out.worldBspShowBlockers = clientNumber(tool, "world_bsp_show_blockers", 0) == 1
    out.worldBspFullGrid = clientNumber(tool, "world_bsp_full_grid", 1) == 1
    local activeSpace = tool and tool.GetClientInfo and tool:GetClientInfo("space") or nil
    out.alt = not M.IsMirrorMode(activeSpace) and (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT))
    out.shift = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

    return out
end

local OFFSET_KEYS = { "px", "py", "pz", "pitch", "yaw", "roll" }
local OFFSET_CLIENT_NAMES = {}
local OFFSET_CVAR_NAMES = {}
local offsetConVarRevision = 0
local offsetChangeCallbacksRegistered = false

for _, space in ipairs(M.SPACES or {}) do
    local clientNames = {}
    local cvarNames = {}
    OFFSET_CLIENT_NAMES[space] = clientNames
    OFFSET_CVAR_NAMES[space] = cvarNames

    for i = 1, #OFFSET_KEYS do
        local key = OFFSET_KEYS[i]
        local clientName = ("%s_%s"):format(space, key)
        clientNames[key] = clientName
        cvarNames[key] = "magic_align_" .. clientName
    end
end

local function registerOffsetChangeCallbacks()
    if offsetChangeCallbacksRegistered then
        return true
    end

    if not CLIENT or not cvars or not cvars.AddChangeCallback then
        return false
    end

    offsetChangeCallbacksRegistered = true

    for _, space in ipairs(M.SPACES or {}) do
        local cvarNames = OFFSET_CVAR_NAMES[space]
        for i = 1, #OFFSET_KEYS do
            local key = OFFSET_KEYS[i]
            local cvarName = cvarNames and cvarNames[key]
            if cvarName then
                local callbackId = ("magic_align_offset_cache_%s_%s"):format(space, key)
                if cvars.RemoveChangeCallback then
                    cvars.RemoveChangeCallback(cvarName, callbackId)
                end

                cvars.AddChangeCallback(cvarName, function()
                    offsetConVarRevision = offsetConVarRevision + 1
                end, callbackId)
            end
        end
    end

    return true
end

local function currentFrameNumber()
    return FrameNumber()
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

local function anchorResultCache(state)
    if not istable(state) then return end

    local cache = state._magicAlignAnchorResultCache
    if not istable(cache) then
        cache = {}
        state._magicAlignAnchorResultCache = cache
    end

    return cache
end

local function offsetFormulaRevisionsChanged(manager, cache)
    local managerRevision = manager and isfunction(manager.GetRevision) and manager:GetRevision() or nil
    if cache.managerRevision == managerRevision then
        return false
    end

    cache.managerRevision = managerRevision

    if not (manager and isfunction(manager.GetEntryRevision)) then
        return true
    end

    local revisions = cache.formulaRevisions
    if not revisions then
        revisions = {}
        cache.formulaRevisions = revisions
    end

    local changed = false
    for _, space in ipairs(M.SPACES or {}) do
        local cvarNames = OFFSET_CVAR_NAMES[space]
        for i = 1, #OFFSET_KEYS do
            local cvarName = cvarNames and cvarNames[OFFSET_KEYS[i]]
            if cvarName then
                local revision = manager:GetEntryRevision(cvarName)
                if revisions[cvarName] ~= revision then
                    revisions[cvarName] = revision
                    changed = true
                end
            end
        end
    end

    return changed
end

local function effectiveOffsetValue(tool, clientName, cvarName)
    local fallback = clientNumber(tool, clientName, 0)
    local manager = M.FormulaManager
    if manager and isfunction(manager.GetNumericValue) then
        return manager:GetNumericValue(cvarName, fallback)
    end

    return fallback
end

local function cachedOffsets(tool, state)
    state._magicAlignOffsetCache = state._magicAlignOffsetCache or { out = {}, values = {}, revision = 0 }
    local cache = state._magicAlignOffsetCache
    local frame = currentFrameNumber()
    if cache.initialized and frame ~= nil and cache.checkedFrame == frame then
        return cache.out, cache.revision
    end
    cache.checkedFrame = frame

    local callbacksReady = registerOffsetChangeCallbacks()
    local manager = M.FormulaManager
    local formulasChanged = offsetFormulaRevisionsChanged(manager, cache)
    local cvarsChanged = cache.offsetConVarRevision ~= offsetConVarRevision
    if cache.initialized and callbacksReady and not formulasChanged and not cvarsChanged then
        return cache.out, cache.revision
    end

    cache.initialized = true
    cache.offsetConVarRevision = offsetConVarRevision

    for _, space in ipairs(M.SPACES) do
        local values = cache.values[space]
        if not values then
            values = {}
            cache.values[space] = values
        end

        local changed = false
        local clientNames = OFFSET_CLIENT_NAMES[space]
        local cvarNames = OFFSET_CVAR_NAMES[space]
        for i = 1, #OFFSET_KEYS do
            local key = OFFSET_KEYS[i]
            local clientName = clientNames and clientNames[key] or (space .. "_" .. key)
            local cvarName = cvarNames and cvarNames[key] or ("magic_align_" .. clientName)
            local value = effectiveOffsetValue(tool, clientName, cvarName)
            if values[key] ~= value then
                values[key] = value
                changed = true
            end
        end

        local item = cache.out[space]
        if not item then
            item = { pos = VectorP(0, 0, 0), rot = AngleP(0, 0, 0) }
            cache.out[space] = item
            changed = true
        end

        if changed then
            item.pos.x, item.pos.y, item.pos.z = values.px, values.py, values.pz
            item.rot.p, item.rot.y, item.rot.r = values.pitch, values.yaw, values.roll
            cache.revision = cache.revision + 1
        end
    end

    return cache.out, cache.revision
end

local function cachedAnchorOptions(tool, state, side)
    state._magicAlignAnchorOptionCache = state._magicAlignAnchorOptionCache or {}
    local cache = state._magicAlignAnchorOptionCache[side]
    if not cache then
        cache = { optionsCache = {}, revision = 0 }
        state._magicAlignAnchorOptionCache[side] = cache
    end

    local prefix = side
    if prefix ~= "" and not string.EndsWith(prefix, "_") then
        prefix = prefix .. "_"
    end

    local options, revision = M.NormalizeAnchorOptionsCached(cache.optionsCache, {
        mid12_pct = tool:GetClientInfo(prefix .. "mid12_pct"),
        mid23_pct = tool:GetClientInfo(prefix .. "mid23_pct"),
        mid13_pct = tool:GetClientInfo(prefix .. "mid13_pct")
    })
    cache.options = options
    cache.revision = revision

    return cache.options, cache.revision
end

local function setValue(space, key, value)
    RunConsoleCommand("magic_align_" .. space .. "_" .. key, M.FormatConVarNumber(value))
end

local function completeAnchorOrder(priorityText)
    local order = {}
    local seen = {}

    local function tryAdd(id)
        id = string.lower(tostring(id or ""))
        if id == "" or seen[id] then return end

        for _, anchor in ipairs(M.ANCHORS or {}) do
            if anchor.id == id then
                order[#order + 1] = id
                seen[id] = true
                return
            end
        end
    end

    for _, id in ipairs(M.ParsePriority(priorityText)) do
        tryAdd(id)
    end

    for _, anchor in ipairs(M.ANCHORS or {}) do
        tryAdd(anchor.id)
    end

    return order
end

local function priorityIndex(order, id)
    id = string.lower(tostring(id or ""))

    for index, name in ipairs(order or {}) do
        if name == id then
            return index
        end
    end

    return math.huge
end

local function highestAvailableAnchor(order, count)
    for _, id in ipairs(order or {}) do
        if M.AnchorAvailable(id, count) then
            return id
        end
    end
end

local function syncPreferredAnchor(tool, state, side)
    local sidePoints = side == "from" and state.source or state.target
    local selectedKey = side == "from" and "from_anchor" or "to_anchor"
    local priorityKey = side == "from" and "from_priority" or "to_priority"
    local selectionState = state.anchorSelection[side] or {}
    local selected = string.lower(tool:GetClientInfo(selectedKey) or "")
    local priority = tool:GetClientInfo(priorityKey)
    local order = completeAnchorOrder(priority)
    local count = istable(sidePoints) and #sidePoints or 0
    local previousCount = tonumber(selectionState.pointCount) or 0
    local active = selected

    if selectionState.convarAnchor == selected and selectionState.anchor then
        active = selectionState.anchor
    end

    local bestAvailable = highestAvailableAnchor(order, count)
    local activeAvailable = M.AnchorAvailable(active, count)
    if bestAvailable and (not activeAvailable or (count > previousCount and priorityIndex(order, bestAvailable) < priorityIndex(order, active))) then
        active = bestAvailable
    end

    local resolvedSelected = selected
    if active ~= "" and active ~= selected then
        RunConsoleCommand("magic_align_" .. selectedKey, active)
        resolvedSelected = active
    end

    state.anchorSelection[side] = {
        anchor = active,
        convarAnchor = resolvedSelected,
        pointCount = count,
        priority = priority
    }
end

local function refreshPreferredAnchors(tool, state)
    syncPreferredAnchor(tool, state, "from")
    syncPreferredAnchor(tool, state, "to")
end

local function selectedAnchorState(tool, state, side)
    local selectedKey = side == "from" and "from_anchor" or "to_anchor"
    local priorityKey = side == "from" and "from_priority" or "to_priority"
    local selected = string.lower(tool:GetClientInfo(selectedKey) or "")
    local selection = state.anchorSelection and state.anchorSelection[side]
    if selection and selection.convarAnchor == selected then
        return selection.anchor, selection.priority
    end

    return selected, tool:GetClientInfo(priorityKey)
end

local function gridStep(size, div)
    if size <= M.PICKING_EPSILON then return 0 end
    return size / math.max(1, div)
end

local function pickGridDivisions(size, div, minDiv, minLength)
    local defaultDiv = math.max(1, math.floor(div))
    local fallbackDiv = math.Clamp(math.floor(minDiv), 1, defaultDiv)
    local defaultStep = gridStep(size, defaultDiv)

    if defaultStep > 0 and defaultStep < minLength and fallbackDiv < defaultDiv then
        return fallbackDiv, gridStep(size, fallbackDiv), true
    end

    return defaultDiv, defaultStep, false
end

local function snapToGrid(value, minValue, maxValue, step, divisions)
    if step <= M.COMPUTE_EPSILON or divisions <= 0 then
        return minValue, 0, 0
    end

    local index = math.Clamp(math.Round((value - minValue) / step), 0, divisions)
    local snapped = math.Clamp(minValue + index * step, minValue, maxValue)
    local percent = divisions > 0 and (index / divisions) * 100 or 0

    return snapped, index, percent
end

local function faceAxisLength(face)
    if not face or not isvector(face.mins) or not isvector(face.maxs) then return 0 end

    if face.axis == 1 then
        return math.max(face.maxs.x - face.mins.x, 0)
    elseif face.axis == 2 then
        return math.max(face.maxs.y - face.mins.y, 0)
    end

    return math.max(face.maxs.z - face.mins.z, 0)
end

local function traceOnlyEntity(ent, startPos, endPos)
    if not IsValid(ent) or not isvector(startPos) or not isvector(endPos) then return end

    local tr = util.TraceLine({
        start = toVector(startPos),
        endpos = toVector(endPos),
        filter = { ent },
        whitelist = true,
        ignoreworld = true,
        mask = MASK_ALL
    })

    if tr and tr.Hit and tr.Entity == ent and isvector(tr.HitPos) then
        return tr
    end
end

local function rayBoxFaceHit(startPos, dir, mins, maxs)
    if not isvector(startPos) or not isvector(dir) or not isvector(mins) or not isvector(maxs) then return end
    if M.VectorLengthSqrPrecise(dir) < M.PICKING_VECTOR_EPSILON_SQR then return end

    local tEnter, tExit = -1e9, 1e9
    local enterAxisKey, enterSign
    local exitAxisKey, exitSign
    local axisIndex = { x = 1, y = 2, z = 3 }

    for _, axis in ipairs({ "x", "y", "z" }) do
        local s, d = comp(startPos, axis), comp(dir, axis)
        local mn, mx = comp(mins, axis), comp(maxs, axis)

        if math.abs(d) < M.PICKING_EPSILON then
            if s < mn or s > mx then
                return
            end
        else
            local nearT, nearSign, farT, farSign
            if d > 0 then
                nearT, nearSign = (mn - s) / d, -1
                farT, farSign = (mx - s) / d, 1
            else
                nearT, nearSign = (mx - s) / d, 1
                farT, farSign = (mn - s) / d, -1
            end

            if nearT > tEnter then
                tEnter = nearT
                enterAxisKey = axis
                enterSign = nearSign
            end

            if farT < tExit then
                tExit = farT
                exitAxisKey = axis
                exitSign = farSign
            end

            if tEnter > tExit then
                return
            end
        end
    end

    if tEnter >= 0 and enterAxisKey then
        return {
            axis = axisIndex[enterAxisKey],
            sign = enterSign,
            point = startPos + dir * tEnter
        }
    end

    if tExit >= 0 and exitAxisKey then
        return {
            axis = axisIndex[exitAxisKey],
            sign = exitSign,
            point = startPos + dir * tExit
        }
    end
end

local function projectFacePointToProp(ent, face, localPos, worldNormal, fallbackLocalPos, fallbackWorldPos, fallbackNormal)
    if not IsValid(ent) or not face or not isvector(localPos) or not isvector(worldNormal) then
        return fallbackLocalPos, fallbackWorldPos, fallbackNormal
    end

    local outward = copyVec(worldNormal)
    if M.VectorLengthSqrPrecise(outward) < M.PICKING_VECTOR_EPSILON_SQR then
        return fallbackLocalPos, fallbackWorldPos, fallbackNormal
    end
    outward = normalizedVec(outward)
    if not outward then return fallbackLocalPos, fallbackWorldPos, fallbackNormal end

    local gridWorldPos = geometry.worldPosFromLocalPoint(ent, localPos)
    if not isvector(gridWorldPos) then
        return fallbackLocalPos, fallbackWorldPos, fallbackNormal
    end

    local gridNormal = outward
    local backDist = PICK_CONFIG.faceTraceOutsideOffset
    local traceStart = gridWorldPos + gridNormal * backDist
    local orthogonalTrace = traceOnlyEntity(
        ent,
        traceStart,
        gridWorldPos - gridNormal * (faceAxisLength(face) + backDist + PICK_CONFIG.faceTraceEndOvershoot)
    )

    local hitTrace = orthogonalTrace
    if not hitTrace and isvector(face.center) then
        local centerWorldPos = geometry.worldPosFromLocalPoint(ent, face.center)
        if isvector(centerWorldPos) then
            hitTrace = traceOnlyEntity(ent, traceStart, centerWorldPos)
        end
    end

    if hitTrace and isvector(hitTrace.HitPos) then
        return geometry.localPointFromWorldPos(ent, hitTrace.HitPos), copyVec(hitTrace.HitPos), copyVec(hitTrace.HitNormal)
    end

    return fallbackLocalPos, fallbackWorldPos, fallbackNormal
end

local function localAimRay(ent)
    local ply = LocalPlayer()
    local eye = IsValid(ply) and ply:GetShootPos() or nil
    local aim = IsValid(ply) and ply:GetAimVector() or nil
    local localEye = isvector(eye) and geometry.localPointFromWorldPos(ent, eye) or nil
    local localAim = isvector(eye) and isvector(aim) and geometry.localNormalFromWorld(ent, eye, aim) or nil

    if isvector(localAim) and M.VectorLengthSqrPrecise(localAim) > M.PICKING_VECTOR_EPSILON_SQR then
        return localEye, normalizedVec(localAim)
    end

    return localEye
end

local function fallbackFaceAxis(ent, tr, localHit)
    if not (isvector(localHit) and tr and isvector(tr.HitPos) and isvector(tr.HitNormal)) then return end

    local localNormal = geometry.localNormalFromWorld(ent, tr.HitPos, tr.HitNormal)
    localNormal = normalizedVec(localNormal)
    if not localNormal then return end

    local axis, sign = 1, localNormal.x >= 0 and 1 or -1
    local absX, absY, absZ = math.abs(localNormal.x), math.abs(localNormal.y), math.abs(localNormal.z)
    if absY > absX and absY > absZ then
        axis, sign = 2, localNormal.y >= 0 and 1 or -1
    elseif absZ > absX and absZ > absY then
        axis, sign = 3, localNormal.z >= 0 and 1 or -1
    end

    return axis, sign
end

local function resolveFaceHit(ent, tr, mins, maxs, localHit)
    local localEye, localAim = localAimRay(ent)
    local boxFaceHit = isvector(localEye) and isvector(localAim) and rayBoxFaceHit(localEye, localAim, mins, maxs) or nil
    local axis = boxFaceHit and boxFaceHit.axis or nil
    local sign = boxFaceHit and boxFaceHit.sign or nil
    local raw = boxFaceHit and boxFaceHit.point or VectorP(localHit.x, localHit.y, localHit.z)

    if axis and sign then
        return axis, sign, raw
    end

    axis, sign = fallbackFaceAxis(ent, tr, localHit)
    if not axis or not sign then return end

    return axis, sign, raw
end

local function buildFacePlane(axis, sign, mins, maxs, raw)
    local fixed, uMin, uMax, vMin, vMax, u, v, corners

    if axis == 1 then
        fixed = sign > 0 and maxs.x or mins.x
        uMin, uMax, vMin, vMax = mins.y, maxs.y, mins.z, maxs.z
        u, v = raw.y, raw.z
        corners = {
            VectorP(fixed, mins.y, mins.z),
            VectorP(fixed, maxs.y, mins.z),
            VectorP(fixed, maxs.y, maxs.z),
            VectorP(fixed, mins.y, maxs.z)
        }
    elseif axis == 2 then
        fixed = sign > 0 and maxs.y or mins.y
        uMin, uMax, vMin, vMax = mins.x, maxs.x, mins.z, maxs.z
        u, v = raw.x, raw.z
        corners = {
            VectorP(mins.x, fixed, mins.z),
            VectorP(maxs.x, fixed, mins.z),
            VectorP(maxs.x, fixed, maxs.z),
            VectorP(mins.x, fixed, maxs.z)
        }
    else
        fixed = sign > 0 and maxs.z or mins.z
        uMin, uMax, vMin, vMax = mins.x, maxs.x, mins.y, maxs.y
        u, v = raw.x, raw.y
        corners = {
            VectorP(mins.x, mins.y, fixed),
            VectorP(maxs.x, mins.y, fixed),
            VectorP(maxs.x, maxs.y, fixed),
            VectorP(mins.x, maxs.y, fixed)
        }
    end

    return {
        fixed = fixed,
        uMin = uMin,
        uMax = uMax,
        vMin = vMin,
        vMax = vMax,
        u = u,
        v = v,
        corners = corners
    }
end

local function resetSnapFaceOutput(out)
    out = out or {}
    out.u = nil
    out.v = nil
    out.gridU = nil
    out.gridV = nil
    out.gridUId = nil
    out.gridVId = nil
    out.indexU = nil
    out.indexV = nil
    out.percentU = nil
    out.percentV = nil
    out.boundaryKind = nil
    out.globalGrid = nil
    out.globalAxisU = nil
    out.globalAxisV = nil
    out.dist = nil
    out.valid = nil
    out.inside = nil

    return out
end

local function writeSnapFaceGrid(grid, face, sizeU, sizeV, div, minDiv, minLength)
    grid = grid or {}

    local divU, stepU = pickGridDivisions(sizeU, div, minDiv, minLength)
    local divV, stepV = pickGridDivisions(sizeV, div, minDiv, minLength)

    grid.stepU = stepU
    grid.stepV = stepV
    grid.divU = divU
    grid.divV = divV
    grid.uMin = face.uMin
    grid.uMax = face.uMax
    grid.vMin = face.vMin
    grid.vMax = face.vMax

    return grid
end

local function buildSnapFaceGridDescriptor(settings, face, out)
    if not face then return end

    settings = settings or {}
    out = out or {}
    local gridA = out.gridA
    local gridB = out.gridB
    out.gridA = nil
    out.gridB = nil

    if settings.shift then
        return out
    end

    local sizeU = face.uMax - face.uMin
    local sizeV = face.vMax - face.vMin

    out.gridA = writeSnapFaceGrid(gridA, face, sizeU, sizeV, settings.gridA, settings.gridAMin, settings.minLength)
    if settings.gridBEnabled then
        out.gridB = writeSnapFaceGrid(gridB, face, sizeU, sizeV, settings.gridB, settings.gridBMin, settings.minLength)
    end

    return out
end

local function snapFaceCoordinates(settings, face, u, v, gridDescriptor, out)
    settings = settings or {}

    local best = resetSnapFaceOutput(out)
    if settings.shift then
        best.u = math.Clamp(u, face.uMin, face.uMax)
        best.v = math.Clamp(v, face.vMin, face.vMax)
        return best
    end

    local sizeU = face.uMax - face.uMin
    local sizeV = face.vMax - face.vMin
    local gridA = gridDescriptor and gridDescriptor.gridA
    if not gridA then
        gridA = writeSnapFaceGrid(nil, face, sizeU, sizeV, settings.gridA, settings.gridAMin, settings.minLength)
    end

    local snapAU, indexAU, percentAU = snapToGrid(u, face.uMin, face.uMax, gridA.stepU, gridA.divU)
    local snapAV, indexAV, percentAV = snapToGrid(v, face.vMin, face.vMax, gridA.stepV, gridA.divV)

    best.u = snapAU
    best.v = snapAV
    best.gridU = gridA
    best.gridV = gridA
    best.gridUId = "A"
    best.gridVId = "A"
    best.indexU = indexAU
    best.indexV = indexAV
    best.percentU = percentAU
    best.percentV = percentAV

    local bestUDist = (u - snapAU) ^ 2
    local bestVDist = (v - snapAV) ^ 2

    face.gridA = gridA
    face.gridB = nil

    if settings.gridBEnabled then
        local gridB = gridDescriptor and gridDescriptor.gridB
        if not gridB then
            gridB = writeSnapFaceGrid(nil, face, sizeU, sizeV, settings.gridB, settings.gridBMin, settings.minLength)
        end

        local snapBU, indexBU, percentBU = snapToGrid(u, face.uMin, face.uMax, gridB.stepU, gridB.divU)
        local snapBV, indexBV, percentBV = snapToGrid(v, face.vMin, face.vMax, gridB.stepV, gridB.divV)
        local distBU = (u - snapBU) ^ 2
        local distBV = (v - snapBV) ^ 2

        face.gridB = gridB

        if distBU < bestUDist then
            best.u = snapBU
            bestUDist = distBU
            best.gridU = gridB
            best.gridUId = "B"
            best.indexU = indexBU
            best.percentU = percentBU
        end

        if distBV < bestVDist then
            best.v = snapBV
            bestVDist = distBV
            best.gridV = gridB
            best.gridVId = "B"
            best.indexV = indexBV
            best.percentV = percentBV
        end
    end

    return best
end

local function faceLocalPosAndOrigin(axis, fixed, u, v, center)
    if axis == 1 then
        return VectorP(fixed, u, v), VectorP(fixed, center.y, center.z)
    elseif axis == 2 then
        return VectorP(u, fixed, v), VectorP(center.x, fixed, center.z)
    end

    return VectorP(u, v, fixed), VectorP(center.x, center.y, fixed)
end

local function faceCandidate(ent, tr, settings, box)
    if tr.Entity ~= ent or not isvector(tr.HitPos) then return end

    local localHit = geometry.localPointFromWorldPos(ent, tr.HitPos)
    if not isvector(localHit) then return end
    if not box then return end

    local mins, maxs = box.mins, box.maxs
    local center = (mins + maxs) * 0.5
    local axis, sign, raw = resolveFaceHit(ent, tr, mins, maxs, localHit)
    if not axis or not sign then return end

    local face = {
        axis = axis,
        sign = sign,
        mins = mins,
        maxs = maxs
    }

    local plane = buildFacePlane(axis, sign, mins, maxs, raw)
    local snapped = snapFaceCoordinates(settings, plane, plane.u, plane.v)
    local localPos, faceOrigin = faceLocalPosAndOrigin(axis, plane.fixed, snapped.u, snapped.v, center)

    face.gridA = plane.gridA
    face.gridB = plane.gridB
    face.u, face.v = plane.u, plane.v
    face.uMin, face.uMax = plane.uMin, plane.uMax
    face.vMin, face.vMax = plane.vMin, plane.vMax
    face.uAxis = axis == 1 and 2 or 1
    face.vAxis = axis == 3 and 2 or 3
    face.uSnap, face.vSnap = snapped.u, snapped.v
    face.snapGridU = snapped.gridU
    face.snapGridV = snapped.gridV
    face.snapGridUId = snapped.gridUId
    face.snapGridVId = snapped.gridVId
    face.snapIndexU, face.snapIndexV = snapped.indexU, snapped.indexV
    face.snapPercentU, face.snapPercentV = snapped.percentU, snapped.percentV
    face.fixed = plane.fixed
    face.corners = plane.corners
    face.center = center
    face.origin = faceOrigin

    local localFaceNormal = axis == 1 and VectorP(sign, 0, 0) or axis == 2 and VectorP(0, sign, 0) or VectorP(0, 0, sign)
    local worldNormal = geometry.worldNormalFromLocal(ent, ZERO_VEC, localFaceNormal)
    local worldPos = geometry.worldPosFromLocalPoint(ent, localPos)
    if not isvector(worldNormal) or not isvector(worldPos) then return end

    local normal = worldNormal

    if settings.alt then
        local projectedLocalPos, projectedWorldPos, projectedNormal = projectFacePointToProp(
            ent,
            face,
            localPos,
            worldNormal,
            localHit,
            tr.HitPos,
            tr.HitNormal
        )

        if isvector(projectedLocalPos) then
            localPos = projectedLocalPos
        end
        if isvector(projectedWorldPos) then
            worldPos = projectedWorldPos
        end
        if isvector(projectedNormal) then
            normal = projectedNormal
        end
    end

    return {
        ent = ent,
        localPos = localPos,
        worldPos = worldPos,
        localNormal = geometry.localNormalFromWorld(ent, worldPos, normal),
        normal = normal,
        face = face,
        mode = settings.alt and (settings.shift and "projected_free_face" or "projected_grid")
            or settings.shift and "free_face"
            or "grid"
    }
end

function client.worldBspTraceEntityIndex(ent)
    if IsValid(ent) and isfunction(ent.EntIndex) then
        return ent:EntIndex()
    end
end

function client.worldBspTraceEntityClass(ent)
    local getClass = IsValid(ent) and ent.GetClass or nil
    if not isfunction(getClass) then return end

    local ok, class = pcall(getClass, ent)
    if ok and class ~= nil then return tostring(class) end
end

function client.worldBspTraceEntityModel(ent)
    local getModel = IsValid(ent) and ent.GetModel or nil
    if not isfunction(getModel) then return end

    local ok, model = pcall(getModel, ent)
    if ok and model ~= nil then return tostring(model) end
end

function client.worldBspCandidateCacheStatusToken(settings)
    local worldBSP = client.WorldBSP
    if worldBSP and isfunction(worldBSP.candidateCacheStatusToken) then
        return worldBSP.candidateCacheStatusToken(settings)
    end

    if not (worldBSP and isfunction(worldBSP.isReady) and worldBSP.isReady()) then return end

    local cache = worldBSP and worldBSP.cache

    return istable(cache) and cache.readyAt or true
end

function client.worldBspCandidateCacheSameTraceVec(entry, prefix, value)
    if isvector(value) then
        return entry[prefix .. "X"] == value.x
            and entry[prefix .. "Y"] == value.y
            and entry[prefix .. "Z"] == value.z
    end

    return entry[prefix .. "X"] == nil
        and entry[prefix .. "Y"] == nil
        and entry[prefix .. "Z"] == nil
end

function client.storeWorldBspCandidateCacheTraceVec(entry, prefix, value)
    if isvector(value) then
        entry[prefix .. "X"] = value.x
        entry[prefix .. "Y"] = value.y
        entry[prefix .. "Z"] = value.z
    else
        entry[prefix .. "X"] = nil
        entry[prefix .. "Y"] = nil
        entry[prefix .. "Z"] = nil
    end
end

function client.worldBspCandidateCacheMatches(entry, tr, settings)
    if not entry or not tr then return false end

    return entry.worldBspCacheStatusToken == client.worldBspCandidateCacheStatusToken(settings)
        and entry.worldBspSnap == (settings and settings.worldBspSnap)
        and entry.worldTarget == (settings and settings.worldTarget)
        and entry.worldBspGridMode == (settings and settings.worldBspGridMode)
        and entry.worldBspGridSize == (settings and settings.worldBspGridSize)
        and entry.worldBspIgnoreBrushBlockers == (settings and settings.worldBspIgnoreBrushBlockers)
        and entry.worldBspFullGrid == (settings and settings.worldBspFullGrid)
        and entry.gridA == (settings and settings.gridA)
        and entry.gridAMin == (settings and settings.gridAMin)
        and entry.gridB == (settings and settings.gridB)
        and entry.gridBMin == (settings and settings.gridBMin)
        and entry.gridBEnabled == (settings and settings.gridBEnabled)
        and entry.minLength == (settings and settings.minLength)
        and entry.shift == (settings and settings.shift)
        and entry.alt == (settings and settings.alt)
        and entry.entity == tr.Entity
        and entry.entityIndex == client.worldBspTraceEntityIndex(tr.Entity)
        and entry.entityClass == client.worldBspTraceEntityClass(tr.Entity)
        and entry.entityModel == client.worldBspTraceEntityModel(tr.Entity)
        and entry.hitWorld == tr.HitWorld
        and entry.hitSky == tr.HitSky
        and entry.hitBox == tr.HitBox
        and entry.surfaceProps == tr.SurfaceProps
        and entry.hitTexture == tr.HitTexture
        and entry.matType == tr.MatType
        and entry.contents == tr.Contents
        and client.worldBspCandidateCacheSameTraceVec(entry, "hitPos", tr.HitPos)
        and client.worldBspCandidateCacheSameTraceVec(entry, "hitNormal", tr.HitNormal)
        and client.worldBspCandidateCacheSameTraceVec(entry, "startPos", tr.StartPos)
        and client.worldBspCandidateCacheSameTraceVec(entry, "normal", tr.Normal)
end

function client.storeWorldBspCandidateCacheEntry(cache, tr, settings, candidate)
    if not istable(cache) or not tr then return end

    local index = (tonumber(cache.count) or 0) + 1
    cache.count = index

    local entry = cache[index]
    if not istable(entry) then
        entry = {}
        cache[index] = entry
    end

    entry.settings = settings
    entry.worldBspCacheStatusToken = client.worldBspCandidateCacheStatusToken(settings)
    entry.worldBspSnap = settings and settings.worldBspSnap
    entry.worldTarget = settings and settings.worldTarget
    entry.worldBspGridMode = settings and settings.worldBspGridMode
    entry.worldBspGridSize = settings and settings.worldBspGridSize
    entry.worldBspIgnoreBrushBlockers = settings and settings.worldBspIgnoreBrushBlockers
    entry.worldBspFullGrid = settings and settings.worldBspFullGrid
    entry.gridA = settings and settings.gridA
    entry.gridAMin = settings and settings.gridAMin
    entry.gridB = settings and settings.gridB
    entry.gridBMin = settings and settings.gridBMin
    entry.gridBEnabled = settings and settings.gridBEnabled
    entry.minLength = settings and settings.minLength
    entry.shift = settings and settings.shift
    entry.alt = settings and settings.alt
    entry.entity = tr.Entity
    entry.entityIndex = client.worldBspTraceEntityIndex(tr.Entity)
    entry.entityClass = client.worldBspTraceEntityClass(tr.Entity)
    entry.entityModel = client.worldBspTraceEntityModel(tr.Entity)
    entry.hitWorld = tr.HitWorld
    entry.hitSky = tr.HitSky
    entry.hitBox = tr.HitBox
    entry.surfaceProps = tr.SurfaceProps
    entry.hitTexture = tr.HitTexture
    entry.matType = tr.MatType
    entry.contents = tr.Contents
    client.storeWorldBspCandidateCacheTraceVec(entry, "hitPos", tr.HitPos)
    client.storeWorldBspCandidateCacheTraceVec(entry, "hitNormal", tr.HitNormal)
    client.storeWorldBspCandidateCacheTraceVec(entry, "startPos", tr.StartPos)
    client.storeWorldBspCandidateCacheTraceVec(entry, "normal", tr.Normal)
    entry.hasResult = true
    entry.result = candidate
end

function client.lookupWorldBspCandidateCache(cache, tr, settings)
    if not istable(cache) then return false end

    local count = tonumber(cache.count) or 0
    for i = 1, count do
        local entry = cache[i]
        if entry and entry.hasResult and client.worldBspCandidateCacheMatches(entry, tr, settings) then
            return true, entry.result
        end
    end

    return false
end

function client.clearWorldBspCandidateCache(cache)
    if istable(cache) then
        cache.count = 0
    end
end

local function worldBspTraceHitsStaticProp(tr)
    return tr
        and tr.HitWorld == true
        and tostring(tr.HitTexture or "") == "**studio**"
end

local function worldCandidateFromTrace(tr, settings, resultCache, stableCache)
    local worldBSP = client.WorldBSP
    local canUseWorldBsp = settings
        and settings.worldBspSnap
        and worldBSP
        and isfunction(worldBSP.candidateFromTrace)
    local stableCacheReady = canUseWorldBsp
        and client.worldBspCandidateCacheStatusToken(settings) ~= nil

    if stableCacheReady then
        local stableCached, stableCandidate = client.lookupWorldBspCandidateCache(stableCache, tr, settings)
        if stableCached then
            client.storeWorldBspCandidateCacheEntry(resultCache, tr, settings, stableCandidate)
            return stableCandidate
        end
    else
        client.clearWorldBspCandidateCache(stableCache)
    end

    local cached, cachedCandidate = client.lookupWorldBspCandidateCache(resultCache, tr, settings)
    if cached then
        return cachedCandidate
    end

    local candidate
    if canUseWorldBsp and not worldBspTraceHitsStaticProp(tr) then
        candidate = worldBSP.candidateFromTrace(tr, settings)
        if candidate then
            client.storeWorldBspCandidateCacheEntry(resultCache, tr, settings, candidate)
            if stableCacheReady then
                client.clearWorldBspCandidateCache(stableCache)
                client.storeWorldBspCandidateCacheEntry(stableCache, tr, settings, candidate)
            end
            return candidate
        end
    end

    candidate = geometry.traceCandidate(M.WORLD_TARGET, tr)
    client.storeWorldBspCandidateCacheEntry(resultCache, tr, settings, candidate)
    if stableCacheReady then
        client.clearWorldBspCandidateCache(stableCache)
        client.storeWorldBspCandidateCacheEntry(stableCache, tr, settings, candidate)
    else
        client.clearWorldBspCandidateCache(stableCache)
    end
    return candidate
end

client.worldBspBlockerTraceDistance = 32768
client.worldBspBlockerTraceLimit = 8

function client.worldBspBlockerClass(ent)
    if not IsValid(ent) or not isfunction(ent.GetClass) then return "" end
    return string.lower(tostring(ent:GetClass() or ""))
end

function client.isWorldBspTraceBlocker(ent)
    if not IsValid(ent) then return false end
    if M.IsWorldTarget(ent) then return false end
    if isfunction(ent.IsPlayer) and ent:IsPlayer() then return false end
    if isfunction(ent.IsNPC) and ent:IsNPC() then return false end
    if isfunction(ent.IsWeapon) and ent:IsWeapon() then return false end
    if M.IsProp(ent) then return false end

    local class = client.worldBspBlockerClass(ent)
    if class == "" then return false end

    return string.StartWith(class, "trigger_")
        or string.StartWith(class, "func_")
        or isfunction(ent.GetBrushSurfaces)
end

function client.clearWorldBspTraceScratchList(list)
    if not istable(list) then return end

    list._count = 0
end

function client.finishWorldBspTraceScratchList(list)
    if not istable(list) then return end

    local count = tonumber(list._count) or #list
    for i = count + 1, #list do
        list[i] = nil
    end
    list._count = nil
end

function client.addWorldBspTraceBlocker(blockers, tr, copyHit)
    if not istable(blockers) or not tr or not client.isWorldBspTraceBlocker(tr.Entity) then return end

    local ent = tr.Entity
    local count = tonumber(blockers._count) or #blockers
    for i = 1, count do
        if blockers[i].ent == ent then return end
    end

    count = count + 1
    blockers._count = count

    local blocker = blockers[count]
    if not istable(blocker) then
        blocker = {}
        blockers[count] = blocker
    end

    blocker.ent = ent
    blocker.class = client.worldBspBlockerClass(ent)
    blocker.index = isfunction(ent.EntIndex) and ent:EntIndex() or nil
    if copyHit then
        blocker.hitPos = isvector(tr.HitPos) and setVec(blocker.hitPos, tr.HitPos) or nil
        blocker.hitNormal = isvector(tr.HitNormal) and setVec(blocker.hitNormal, tr.HitNormal) or nil
    else
        blocker.hitPos = nil
        blocker.hitNormal = nil
    end
end

function client.worldBspBlockerTraceStartAndDirection(tr)
    local start = tr and isvector(tr.StartPos) and copyVec(tr.StartPos) or nil
    local ply = LocalPlayer()
    if not start and IsValid(ply) then
        start = copyVec(ply:GetShootPos())
    end
    if not isvector(start) then return end

    local dir = tr and isvector(tr.Normal) and normalizedVec(tr.Normal) or nil
    if not dir and tr and isvector(tr.HitPos) then
        dir = normalizedVec(tr.HitPos - start)
    end
    if not dir and IsValid(ply) then
        dir = normalizedVec(ply:GetAimVector())
    end
    if not dir then return end

    return start, dir
end

function client.addWorldBspBaseBlockerTraceFilter(filter)
    local ply = LocalPlayer()
    local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil

    if IsValid(ply) then
        filter[#filter + 1] = ply
    end
    if IsValid(weapon) then
        filter[#filter + 1] = weapon
    end
end

function client.worldBspTraceThroughBlockers(tr, settings, scratch)
    if not tr or tr.HitSky == true or not client.isWorldBspTraceBlocker(tr.Entity) then
        return tr, nil
    end
    if not (settings and (settings.worldBspIgnoreBrushBlockers or settings.worldBspShowBlockers)) then
        return tr, nil
    end

    scratch = istable(scratch) and scratch or nil
    local blockers = scratch and scratch.blockers or {}
    if scratch then
        scratch.blockers = blockers
        client.clearWorldBspTraceScratchList(blockers)
    end

    local copyHits = settings.worldBspShowBlockers == true
    client.addWorldBspTraceBlocker(blockers, tr, copyHits)

    if not settings.worldBspIgnoreBrushBlockers then
        client.finishWorldBspTraceScratchList(blockers)
        return tr, blockers
    end

    local start, dir = client.worldBspBlockerTraceStartAndDirection(tr)
    if not start or not dir then
        client.finishWorldBspTraceScratchList(blockers)
        return tr, blockers
    end

    local filter = scratch and scratch.filter or {}
    if scratch then
        scratch.filter = filter
        for i = 1, #filter do
            filter[i] = nil
        end
    end
    client.addWorldBspBaseBlockerTraceFilter(filter)
    if IsValid(tr.Entity) then
        filter[#filter + 1] = tr.Entity
    end

    for _ = 1, client.worldBspBlockerTraceLimit do
        local filtered = util.TraceLine({
            start = toVector(start),
            endpos = toVector(start + dir * client.worldBspBlockerTraceDistance),
            filter = filter
        })
        if not filtered or filtered.Hit == false or filtered.HitSky == true then
            client.finishWorldBspTraceScratchList(blockers)
            return tr, blockers
        end

        if geometry.traceHitsWorld(filtered) then
            client.finishWorldBspTraceScratchList(blockers)
            return filtered, blockers
        end

        if not client.isWorldBspTraceBlocker(filtered.Entity) then
            client.finishWorldBspTraceScratchList(blockers)
            return tr, blockers
        end

        client.addWorldBspTraceBlocker(blockers, filtered, copyHits)
        filter[#filter + 1] = filtered.Entity
    end

    client.finishWorldBspTraceScratchList(blockers)
    return tr, blockers
end


core.cfg = cfg
core.currentFrameNumber = currentFrameNumber
core.pointWorldCache = pointWorldCache
core.anchorResultCache = anchorResultCache
core.cachedOffsets = cachedOffsets
core.cachedAnchorOptions = cachedAnchorOptions
core.setValue = setValue
core.refreshPreferredAnchors = refreshPreferredAnchors
core.selectedAnchorState = selectedAnchorState
core.buildSnapFaceGridDescriptor = buildSnapFaceGridDescriptor
core.snapFaceCoordinates = snapFaceCoordinates
core.faceCandidate = faceCandidate
core.worldCandidateFromTrace = worldCandidateFromTrace
client.buildSnapFaceGridDescriptor = buildSnapFaceGridDescriptor

return core
