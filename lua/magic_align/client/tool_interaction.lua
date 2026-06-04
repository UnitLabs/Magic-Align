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
local TOOL_UI = core.TOOL_UI
local RENDER_QUALITY = core.RENDER_QUALITY
local PICK_CONFIG = core.PICK_CONFIG
local ROTATION_CONFIG = core.ROTATION_CONFIG
local colors = core.colors
local copyVec = core.copyVec
local copyAng = core.copyAng
local ZERO_VEC = core.ZERO_VEC
local ZERO_ANG = core.ZERO_ANG
local WorldToLocalPosPrecise = core.WorldToLocalPosPrecise
local setVec = core.setVec
local normalizedVec = core.normalizedVec
local ensureStateShape = core.ensureStateShape
local clientNumber = core.clientNumber
local buildTraceSample = core.buildTraceSample
local sampleWorldPos = core.sampleWorldPos
local aggregateTraceProbes = core.aggregateTraceProbes
local boundsFor = core.boundsFor
local resetLinkedProps = core.resetLinkedProps
local removeLinkedProp = core.removeLinkedProp
local cleanupLinkedProps = core.cleanupLinkedProps
local cleanupTargetPointReferences = core.cleanupTargetPointReferences
local requestBounds = core.requestBounds
local updateToolHelp = core.updateToolHelp
local ringAngle = core.ringAngle
local ringRotationDeltaSign = core.ringRotationDeltaSign
local rotationSnapDivisions = core.rotationSnapDivisions
local rotationSnapStep = core.rotationSnapStep
local translationSnapStep = core.translationSnapStep
local snapRotationAngle = core.snapRotationAngle
local isMajorRotationTick = core.isMajorRotationTick
local activeTool = core.activeTool
local setClientActiveSpace = core.setClientActiveSpace
local uiBlocked = core.uiBlocked
local pointWorldCache = core.pointWorldCache
local cachedOffsets = core.cachedOffsets
local cachedAnchorOptions = core.cachedAnchorOptions
local setValue = core.setValue
local refreshPreferredAnchors = core.refreshPreferredAnchors
local selectedAnchorState = core.selectedAnchorState
local snapFaceCoordinates = core.snapFaceCoordinates
local worldCandidateFromTrace = core.worldCandidateFromTrace
local cornerCandidate = core.cornerCandidate
local gizmo = core.gizmo
local solvePreview = core.solvePreview
local ensureGhost = core.ensureGhost
local hoverState = core.hoverState
local pendingPreview = core.pendingPreview
local commit = core.commit
local playToolgunFeedback = core.playToolgunFeedback
local canCommitState = core.canCommitState
local validateClientState = core.validateClientState
local resetClientSession = core.resetClientSession
local gizmoShared = client.gizmoShared
local function useCandidate(state, side, candidate, index)
    if not candidate then return end

    local points
    if side == "source" then
        points = state.source
    elseif side == "mirror" then
        points = client.Mirror.state(state).points
    else
        points = state.target
    end

    local point = geometry.pointFromCandidate(candidate, side == "target" or side == "mirror")
    if not point then return end

    if index then
        points[index] = point
    elseif #points < M.MAX_POINTS then
        points[#points + 1] = point
    end

    M.RefreshState(state)
end

local function playQueuedClientActionFeedback(tool)
    local consume = core.consumeClientActionFeedback
    if not isfunction(consume) or not isfunction(playToolgunFeedback) then return end

    local feedback = consume()
    if not feedback then return end

    playToolgunFeedback(tool, feedback.action, feedback.wouldAffect, feedback.trace)
end

client.Press = client.Press or {}

function client.Press.hoverPickCandidate(hover)
    local candidate = hover and (hover.candidate or hover.overlay) or nil
    if not istable(candidate) then return end

    return candidate
end

function client.Press.drawCandidate(kind, ent, hover)
    if not geometry.hasTargetEntity(ent) or not hover or not hover.trace then return end
    if geometry.isWorldTarget(ent) then
        return worldCandidateFromTrace(
            hover.trace,
            hover.settings,
            hover.worldBspCandidateCache,
            hover.worldBspStableCandidateCache
        )
    end

    return geometry.traceCandidate(ent, hover.trace)
end

function client.Press.pickCandidateForPress(press, hover)
    if not press or not hover then return end

    if not press.drawActive then
        local candidate = client.Press.hoverPickCandidate(hover)
        if candidate and candidate.ent == press.ent then
            return candidate
        end
    end

    if press.kind == "pick" then
        return client.Press.drawCandidate("pick", press.ent, hover)
    elseif press.kind == "select_source_pick" or press.kind == "select_target_pick" then
        return client.Press.drawCandidate(press.kind, press.ent, hover)
    end
end

function client.Press.beginPick(kind, side, ent, hover)
    if not geometry.hasTargetEntity(ent) or not hover or not hover.trace then return end

    local clickCandidate = client.Press.hoverPickCandidate(hover)
    if clickCandidate and clickCandidate.ent ~= ent then
        clickCandidate = nil
    end

    local candidate = clickCandidate or client.Press.drawCandidate(kind, ent, hover)
    if not candidate then return end

    local firstSample = buildTraceSample(ent, hover.trace.HitPos, hover.trace.HitNormal, hover.trace)

    return {
        kind = kind,
        side = side,
        ent = ent,
        clickCandidate = clickCandidate,
        currentCandidate = candidate,
        drawDistance = 0,
        drawActive = false,
        samples = firstSample and { firstSample } or {},
        aggregatedProbes = firstSample and aggregateTraceProbes({ firstSample }) or {}
    }
end

function client.Press.beginGizmoDrag(tool, state, handle)
    if not handle or not handle.hover then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local eye = ply:GetShootPos()
    local dir = ply:GetAimVector()
    local origin = handle.origin
    local basis = handle.basis
    local item = gizmoShared.copyHandle(handle.hover)
    if not item then return end
    local normal = ((item.kind == "move" or item.kind == "plane")
        and gizmoShared.linearDragNormal(origin, basis, item, eye)
        or item.axis)
    normal = normalizedVec(normal)
    if not normal then return end

    if item.kind == "move" or item.kind == "plane" then
        local lookDir = M.SubtractVectorsPrecise(origin, eye)
        if M.VectorLengthSqrPrecise(lookDir) > M.PICKING_VECTOR_EPSILON_SQR then
            client.setPlayerViewAngles(ply, lookDir:Angle())
            dir = normalizedVec(lookDir) or dir
        end
    end

    local lineScratch = state._magicAlignGizmoLinePlaneScratch or {}
    state._magicAlignGizmoLinePlaneScratch = lineScratch
    local worldPos, localPos
    if M.LinePlaneIntersectionInto then
        worldPos, localPos = M.LinePlaneIntersectionInto(lineScratch.world, lineScratch.localPos, dir, eye, normal, origin, basis)
        lineScratch.world, lineScratch.localPos = worldPos, localPos
    else
        worldPos, localPos = M.LinePlaneIntersection(dir, eye, normal, origin, basis)
    end
    if not worldPos or not localPos then return end

    state.press = {
        kind = "gizmo",
        gizmo = item,
        origin = copyVec(origin),
        basis = copyAng(basis),
        referenceBasis = copyAng(handle.referenceBasis),
        normal = copyVec(normal),
        startWorld = copyVec(worldPos),
        startLocal = copyVec(localPos),
        dragStartLocal = (item.kind == "move" or item.kind == "plane") and VectorP(0, 0, 0) or copyVec(localPos),
        currentGizmoPos = (item.kind == "move" or item.kind == "plane") and VectorP(0, 0, 0) or nil,
        start = {
            x = clientNumber(tool, handle.space .. "_px", 0),
            y = clientNumber(tool, handle.space .. "_py", 0),
            z = clientNumber(tool, handle.space .. "_pz", 0),
            pitch = clientNumber(tool, handle.space .. "_pitch", 0),
            yaw = clientNumber(tool, handle.space .. "_yaw", 0),
            roll = clientNumber(tool, handle.space .. "_roll", 0)
        },
        startRingAngle = item.kind == "rot" and ringAngle(item.key, localPos) or nil,
        currentRingAngle = item.kind == "rot" and math.deg(ringAngle(item.key, localPos)) or nil,
        referenceDelta = VectorP(0, 0, 0),
        rotationDelta = 0,
        space = handle.space
    }
end

function client.Press.setReferencePositionFromGizmoCoords(press, startGizmoPos, currentGizmoPos)
    -- DragContext = virtuelle Ebene des aktiven Gizmos im Weltspace.
    -- `LocalToLocal` ist hier fuer Koordinaten gedacht, nicht fuer einen schon
    -- vorher gebildeten Delta-Vektor. Deshalb rechnen wir Start- und Zielpunkt
    -- erst getrennt vom Gizmo-Raum in den Referenzraum und bilden das Delta dort.
    local startRef = M.LocalToLocal(startGizmoPos, ZERO_ANG, ZERO_VEC, press.basis, ZERO_VEC, press.referenceBasis)
    local currentRef = M.LocalToLocal(currentGizmoPos, ZERO_ANG, ZERO_VEC, press.basis, ZERO_VEC, press.referenceBasis)
    if not isvector(startRef) or not isvector(currentRef) then return end

    local deltaRef = currentRef - startRef

    setValue(press.space, "px", press.start.x + deltaRef.x)
    setValue(press.space, "py", press.start.y + deltaRef.y)
    setValue(press.space, "pz", press.start.z + deltaRef.z)

    return setVec(press.referenceDelta, deltaRef)
end

function client.Press.updateGizmo(tool, state)
    local press = state.press
    if not press or press.kind ~= "gizmo" then return end

    local eye = LocalPlayer():GetShootPos()
    local dir = LocalPlayer():GetAimVector()
    local lineScratch = press.linePlaneScratch or {}
    press.linePlaneScratch = lineScratch
    local _, localPos
    if M.LinePlaneIntersectionInto then
        lineScratch.world, localPos = M.LinePlaneIntersectionInto(lineScratch.world, lineScratch.localPos, dir, eye, press.normal, press.origin, press.basis)
        lineScratch.localPos = localPos
    else
        _, localPos = M.LinePlaneIntersection(dir, eye, press.normal, press.origin, press.basis)
    end
    if not localPos then return end

    local dragStartLocal = press.dragStartLocal or press.startLocal

    if press.gizmo.kind == "move" then
        local currentGizmoPos = gizmoShared.translationLocalPos(press.gizmo, dragStartLocal, localPos, press.currentGizmoPos)
        currentGizmoPos = client.snapGizmoPosition(state, press, currentGizmoPos)
        press.currentGizmoPos = setVec(press.currentGizmoPos, currentGizmoPos)
        press.referenceDelta = client.Press.setReferencePositionFromGizmoCoords(press, dragStartLocal, currentGizmoPos) or press.referenceDelta
        press.rotationDelta = 0
    elseif press.gizmo.kind == "plane" then
        local currentGizmoPos = gizmoShared.translationLocalPos(press.gizmo, dragStartLocal, localPos, press.currentGizmoPos)
        currentGizmoPos = client.snapGizmoPosition(state, press, currentGizmoPos)
        press.currentGizmoPos = setVec(press.currentGizmoPos, currentGizmoPos)
        press.referenceDelta = client.Press.setReferencePositionFromGizmoCoords(press, dragStartLocal, currentGizmoPos) or press.referenceDelta
        press.rotationDelta = 0
    else
        local currentAngle = math.deg(ringAngle(press.gizmo.key, localPos))
        press.currentRingAngle = currentAngle
        local delta = math.AngleDifference(currentAngle, math.deg(press.startRingAngle))
        if not (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)) then
            local step = rotationSnapStep(tool)
            local snappedCurrent = snapRotationAngle(currentAngle, step)
            local snappedStart = snapRotationAngle(math.deg(press.startRingAngle), step)
            delta = math.AngleDifference(snappedCurrent, snappedStart)
        end
        delta = delta * ringRotationDeltaSign(press.gizmo.key)

        -- Das Ring-Drag liefert ein Delta um die bereits rotierte Gizmo-Achse.
        -- Deshalb bauen wir aus der Start-Basis direkt die neue Gizmo-Basis auf
        -- und rechnen diese erst danach zurueck in den Referenzraum des Tabs.
        local axis = client.axisVectorForKey(press.basis, press.gizmo.key == "roll" and "x" or press.gizmo.key == "pitch" and "y" or "z")
        local newBasis = M.RotateAngleAroundAxisPrecise(press.basis, axis, delta)

        local _, newLocalRot = WorldToLocalPrecise(ZERO_VEC, newBasis, ZERO_VEC, press.referenceBasis)
        if not isangle(newLocalRot) then return end

        setValue(press.space, "pitch", newLocalRot.p)
        setValue(press.space, "yaw", newLocalRot.y)
        setValue(press.space, "roll", newLocalRot.r)
        press.currentGizmoPos = nil
        press.referenceDelta = setVec(press.referenceDelta, ZERO_VEC)
        press.rotationDelta = delta
    end
end

client.Formula = client.Formula or {}

function client.Formula.formatEnvironmentValue(value)
    local number = tonumber(value)
    if number == nil then
        return tostring(value or "n/a")
    end

    return M.FormatDisplayNumber(number, M.GetDisplayRounding(), {
        fallback = M.DEFAULT_DISPLAY_ROUNDING,
        trim = true
    })
end

function client.Formula.boundsSize(currentState, ent)
    if not IsValid(ent) or not M.IsProp(ent) then return end

    if istable(currentState) then
        requestBounds(currentState, ent)

        local box = boundsFor(currentState, ent)
        if istable(box) and isvector(box.size) then
            return box.size
        end
    end

    local mins, maxs = M.GetLocalBounds(ent)
    if isvector(mins) and isvector(maxs) then
        return maxs - mins
    end
end

function client.Formula.addVariable(env, name, value, description)
    name = string.lower(tostring(name or ""))
    if name == "" then return end

    description = tostring(description or "")
    env.variableNames[#env.variableNames + 1] = name
    env.variableDescriptions[name] = description
    env.variableRows[#env.variableRows + 1] = {
        name = name,
        value = value == nil and "n/a" or client.Formula.formatEnvironmentValue(value),
        description = description
    }

    local numeric = tonumber(value)
    if numeric ~= nil then
        env.variables[name] = numeric
    end
end

function client.Formula.addConstants(env)
    client.Formula.addVariable(env, "pi", math.pi, "Pi constant")
    client.Formula.addVariable(env, "tau", math.pi * 2, "Tau constant (2 * pi)")
    client.Formula.addVariable(env, "deg2rad", math.pi / 180, "Multiply degrees by this to convert to radians")
    client.Formula.addVariable(env, "rad2deg", 180 / math.pi, "Multiply radians by this to convert to degrees")
end

function client.Formula.angleComponent(ang, ...)
    if not isangle(ang) then
        return nil
    end

    local keys = { ... }
    for index = 1, #keys do
        local key = keys[index]
        local value = ang[key]

        if isfunction(value) then
            local ok, result = pcall(value, ang)
            value = ok and result or nil
        end

        value = tonumber(value)
        if value ~= nil then
            return value
        end
    end

    return nil
end

function client.Formula.addEntityVariables(env, currentState, prefix, label, ent)
    local size = client.Formula.boundsSize(currentState, ent)
    local pos = IsValid(ent) and ent:GetPos() or nil
    local ang = IsValid(ent) and ent:GetAngles() or nil
    local pitch = client.Formula.angleComponent(ang, "Pitch", "pitch", "p")
    local yaw = client.Formula.angleComponent(ang, "Yaw", "yaw", "y")
    local roll = client.Formula.angleComponent(ang, "Roll", "roll", "r")

    client.Formula.addVariable(env, prefix .. "_box_x", isvector(size) and size.x or nil, label .. " AABB size X")
    client.Formula.addVariable(env, prefix .. "_box_y", isvector(size) and size.y or nil, label .. " AABB size Y")
    client.Formula.addVariable(env, prefix .. "_box_z", isvector(size) and size.z or nil, label .. " AABB size Z")

    client.Formula.addVariable(env, prefix .. "_world_x", isvector(pos) and pos.x or nil, label .. " world X")
    client.Formula.addVariable(env, prefix .. "_world_y", isvector(pos) and pos.y or nil, label .. " world Y")
    client.Formula.addVariable(env, prefix .. "_world_z", isvector(pos) and pos.z or nil, label .. " world Z")

    client.Formula.addVariable(env, prefix .. "_world_pitch", pitch, label .. " world pitch")
    client.Formula.addVariable(env, prefix .. "_world_yaw", yaw, label .. " world yaw")
    client.Formula.addVariable(env, prefix .. "_world_roll", roll, label .. " world roll")
end

function client.Formula.anchorPointSet(points, anchorOptions)
    points = istable(points) and points or {}

    return {
        p1 = M.AnchorPoint(points, "p1", anchorOptions),
        p2 = M.AnchorPoint(points, "p2", anchorOptions),
        p3 = M.AnchorPoint(points, "p3", anchorOptions),
        m12 = M.AnchorPoint(points, "mid12", anchorOptions),
        m23 = M.AnchorPoint(points, "mid23", anchorOptions),
        m13 = M.AnchorPoint(points, "mid13", anchorOptions)
    }
end

function client.Formula.distance(left, right)
    if not isvector(left) or not isvector(right) then
        return nil
    end

    return left:Distance(right)
end

function client.Formula.triangleAngle(vertex, left, right)
    if not isvector(vertex) or not isvector(left) or not isvector(right) then
        return nil
    end

    local toLeft = left - vertex
    local toRight = right - vertex
    local leftLength = toLeft:Length()
    local rightLength = toRight:Length()

    if leftLength <= M.COMPUTE_EPSILON or rightLength <= M.COMPUTE_EPSILON then
        return nil
    end

    local cosine = toLeft:Dot(toRight) / (leftLength * rightLength)
    cosine = math.Clamp(cosine, -1, 1)

    return math.deg(math.acos(cosine))
end

function client.Formula.addAnchorDistanceVariables(env, prefix, label, points, anchorOptions)
    local anchorPoints = client.Formula.anchorPointSet(points, anchorOptions)

    local function addDistance(nameSuffix, left, right, description)
        client.Formula.addVariable(
            env,
            ("%s_%s"):format(prefix, nameSuffix),
            client.Formula.distance(left, right),
            ("%s %s"):format(label, description)
        )
    end

    addDistance("dist_p1_p2", anchorPoints.p1, anchorPoints.p2, "distance P1 <-> P2")
    addDistance("dist_p2_p3", anchorPoints.p2, anchorPoints.p3, "distance P2 <-> P3")
    addDistance("dist_p1_p3", anchorPoints.p1, anchorPoints.p3, "distance P1 <-> P3")
    addDistance("dist_m12_p3", anchorPoints.m12, anchorPoints.p3, "distance M12 <-> P3")
    addDistance("dist_m23_p1", anchorPoints.m23, anchorPoints.p1, "distance M23 <-> P1")
    addDistance("dist_m13_p2", anchorPoints.m13, anchorPoints.p2, "distance M13 <-> P2")
end

function client.Formula.addAnchorAngleVariables(env, prefix, label, points, anchorOptions)
    local anchorPoints = client.Formula.anchorPointSet(points, anchorOptions)

    local function addAngle(nameSuffix, vertex, left, right, description)
        client.Formula.addVariable(
            env,
            ("%s_%s"):format(prefix, nameSuffix),
            client.Formula.triangleAngle(vertex, left, right),
            ("%s %s"):format(label, description)
        )
    end

    addAngle("p1_ang", anchorPoints.p1, anchorPoints.p2, anchorPoints.p3, "triangle angle at P1 (degrees)")
    addAngle("p2_ang", anchorPoints.p2, anchorPoints.p1, anchorPoints.p3, "triangle angle at P2 (degrees)")
    addAngle("p3_ang", anchorPoints.p3, anchorPoints.p1, anchorPoints.p2, "triangle angle at P3 (degrees)")
end

function client.Formula.addCrossAnchorDistanceVariables(env, leftLabel, rightLabel, leftPoints, leftAnchorOptions, rightPoints, rightAnchorOptions)
    local leftAnchorPoints = client.Formula.anchorPointSet(leftPoints, leftAnchorOptions)
    local rightAnchorPoints = client.Formula.anchorPointSet(rightPoints, rightAnchorOptions)
    local pointKeys = { "p1", "p2", "p3" }

    for leftIndex = 1, #pointKeys do
        local leftKey = pointKeys[leftIndex]
        local leftPoint = leftAnchorPoints[leftKey]

        for rightIndex = 1, #pointKeys do
            local rightKey = pointKeys[rightIndex]
            local rightPoint = rightAnchorPoints[rightKey]

            client.Formula.addVariable(
                env,
                ("dist_%s_%s"):format(leftKey, rightKey),
                client.Formula.distance(leftPoint, rightPoint),
                ("Distance %s %s <-> %s %s"):format(leftLabel, string.upper(leftKey), rightLabel, string.upper(rightKey))
            )
        end
    end
end

function client.Formula.entitySignature(ent)
    if geometry.isWorldTarget(ent) then
        return "world"
    end

    return IsValid(ent) and tostring(ent:EntIndex()) or "0"
end

client.spaceLabels = TOOL_UI.spaceLabels
client.colors = colors
client.ringQualityPresets = RENDER_QUALITY.presets
client.defaultRingQualityIndex = RENDER_QUALITY.defaultIndex
client.activeTool = activeTool
client.setActiveSpace = setClientActiveSpace
client.setValue = setValue
client.gizmo = gizmo
client.snapFaceCoordinates = snapFaceCoordinates
client.rotationSnapDivisors = ROTATION_CONFIG.snapDivisors
client.defaultRotationSnapIndex = ROTATION_CONFIG.defaultSnapIndex
client.rotationSnapDivisions = rotationSnapDivisions
client.rotationSnapStep = rotationSnapStep
client.translationSnapStep = translationSnapStep
client.rotationSnapMaxVisibleTicks = ROTATION_CONFIG.maxVisibleTicks
client.isMajorRotationTick = isMajorRotationTick
client.sampleWorldPos = sampleWorldPos
client.validateState = validateClientState
client.mirrorClassificationLabel = client.Mirror.classificationLabel
client.getFormulaEnvironment = function()
    local currentState = ensureStateShape(M.ClientState)
    cleanupLinkedProps(currentState)
    cleanupTargetPointReferences(currentState)
    local tool = select(1, activeTool())
    local sourceAnchorOptions = M.AnchorOptionsFromReader(function(name)
        return tool and tool:GetClientInfo(name)
    end, "from")
    local targetAnchorOptions = M.AnchorOptionsFromReader(function(name)
        return tool and tool:GetClientInfo(name)
    end, "to")
    local targetFormulaPoints = M.ResolvePointSetWorld
        and M.ResolvePointSetWorld(currentState.target, currentState.prop2, {
            allowWorld = true,
            requireProp = true,
            maxPoints = M.MAX_POINTS,
            pointWorldCache = pointWorldCache(currentState)
        })
        or currentState.target

    local env = {
        variables = {},
        variableNames = {},
        variableDescriptions = {},
        variableRows = {}
    }

    client.Formula.addConstants(env)
    client.Formula.addEntityVariables(env, currentState, "prop1", "Prop 1", currentState.prop1)
    client.Formula.addEntityVariables(env, currentState, "prop2", "Prop 2", currentState.prop2)
    client.Formula.addAnchorDistanceVariables(env, "prop1", "Prop 1", currentState.source, sourceAnchorOptions)
    client.Formula.addAnchorAngleVariables(env, "prop1", "Prop 1", currentState.source, sourceAnchorOptions)
    client.Formula.addAnchorDistanceVariables(env, "prop2", "Target", targetFormulaPoints, targetAnchorOptions)
    client.Formula.addAnchorAngleVariables(env, "prop2", "Target", targetFormulaPoints, targetAnchorOptions)
    client.Formula.addCrossAnchorDistanceVariables(
        env,
        "Prop 1",
        "Target",
        currentState.source,
        sourceAnchorOptions,
        targetFormulaPoints,
        targetAnchorOptions
    )

    local linkedSignatures = {}
    local linkedCount = 0
    for index = 1, #(currentState.linked or {}) do
        local ent = currentState.linked[index]
        if IsValid(ent) and ent ~= currentState.prop1 and ent ~= currentState.prop2 and M.IsProp(ent) then
            linkedCount = linkedCount + 1
            linkedSignatures[#linkedSignatures + 1] = client.Formula.entitySignature(ent)
            client.Formula.addEntityVariables(env, currentState, ("linked%d"):format(linkedCount), ("Linked %d"):format(linkedCount), ent)
        end
    end

    client.Formula.addVariable(env, "linked_count", linkedCount, "Number of currently linked props")
    env.watchKey = table.concat({
        "prop1=" .. client.Formula.entitySignature(currentState.prop1),
        "prop2=" .. client.Formula.entitySignature(currentState.prop2),
        "linked=" .. table.concat(linkedSignatures, ",")
    }, ";")

    return env
end

local pressState = {}

function pressState.updatePick(state)
    local tr = state.hover.trace
    local samples = state.press.samples
    local last = samples[#samples]
    local clickCandidate = client.Press.hoverPickCandidate(state.hover)
    if clickCandidate and clickCandidate.ent == state.press.ent then
        state.press.clickCandidate = clickCandidate
    end

    local lastWorldPos = sampleWorldPos(state.press.ent, last)
    if not isvector(lastWorldPos) or lastWorldPos:DistToSqr(tr.HitPos) > 1 then
        local sample = buildTraceSample(state.press.ent, tr.HitPos, tr.HitNormal, tr)
        if sample then
            samples[#samples + 1] = sample

            local sampleWorld = sampleWorldPos(state.press.ent, sample)
            if isvector(lastWorldPos) and isvector(sampleWorld) then
                state.press.drawDistance = (tonumber(state.press.drawDistance) or 0) + lastWorldPos:Distance(sampleWorld)
            end
        end
    end

    state.press.drawActive = (tonumber(state.press.drawDistance) or 0) >= PICK_CONFIG.drawSelectDeadzone

    local candidate = client.Press.pickCandidateForPress(state.press, state.hover)
    if candidate then
        state.press.currentCandidate = candidate
    end

    state.press.aggregatedProbes = aggregateTraceProbes(samples)
    state.corner = cornerCandidate(
        state.press.ent,
        samples,
        PICK_CONFIG.cornerTraceMinLength,
        boundsFor(state, state.press.ent),
        state.press.aggregatedProbes
    )
end

function pressState.updateActive(tool, state, worldPoints)
    if worldPoints and isfunction(worldPoints.updateActivePress) and worldPoints.updateActivePress(tool, state) then
        return
    end

    if state.press and state.press.kind == "drag_point" and state.hover.candidate and state.hover.side == state.press.side then
        useCandidate(state, state.press.side, state.hover.candidate, state.press.index)
    elseif state.press
        and (state.press.kind == "pick" or state.press.kind == "select_source_pick" or state.press.kind == "select_target_pick")
        and geometry.traceMatchesEntity(state.hover.trace, state.press.ent) then
        pressState.updatePick(state)
    elseif state.press and state.press.kind == "gizmo" then
        client.Press.updateGizmo(tool, state)
    else
        state.corner = nil
    end
end

function pressState.beginMouse(tool, state, worldPoints)
    if worldPoints and isfunction(worldPoints.beginMousePress) and worldPoints.beginMousePress(tool, state) then
        return
    end

    if state.hover.gizmo and state.hover.gizmo.hover then
        client.Press.beginGizmoDrag(tool, state, state.hover.gizmo)
    elseif state.hover.point and state.hover.side then
        state.press = {
            kind = "drag_point",
            side = state.hover.side,
            index = state.hover.point.index
        }
    elseif state.hover.side and state.hover.ent and state.hover.trace and geometry.traceMatchesEntity(state.hover.trace, state.hover.ent) then
        state.press = client.Press.beginPick("pick", state.hover.side, state.hover.ent, state.hover)
    elseif state.hover.pickSource then
        state.press = client.Press.beginPick("select_source_pick", "source", state.hover.pickSource, state.hover)
    elseif state.hover.pickTarget then
        state.press = client.Press.beginPick("select_target_pick", "target", state.hover.pickTarget, state.hover)
    end
end

function pressState.finalCandidate(state, press)
    if press.drawActive then
        return state.corner or press.currentCandidate or press.clickCandidate
    end

    return press.clickCandidate or press.currentCandidate
end

function pressState.applyCompletedPick(state, press, finalCandidate)
    if press.kind == "select_source_pick" and M.IsProp(press.ent) then
        state.prop1 = press.ent
        state.prop2 = nil
        resetLinkedProps(state)
        state.source = {}
        state.target = {}
        requestBounds(state, state.prop1)
        useCandidate(state, "source", finalCandidate)
    elseif press.kind == "select_target_pick" and (M.IsProp(press.ent) or geometry.isWorldTarget(press.ent)) and press.ent ~= state.prop1 then
        removeLinkedProp(state, press.ent)
        state.prop2 = press.ent
        state.target = {}
        if IsValid(state.prop2) then
            requestBounds(state, state.prop2)
        end
        useCandidate(state, "target", finalCandidate)
    elseif press.kind == "pick" then
        useCandidate(state, press.side, finalCandidate)
    end
end

function pressState.finishMouse(tool, state, worldPoints)
    local press = state.press
    local handledWorldPointRelease = worldPoints
        and isfunction(worldPoints.handleMouseRelease)
        and worldPoints.handleMouseRelease(tool, state, press)

    if press and not handledWorldPointRelease then
        pressState.applyCompletedPick(state, press, pressState.finalCandidate(state, press))
    end

    state.press = nil
    state.corner = nil
end

hook.Add("EntityRemoved", "magic_align_reset_session_on_prop_remove", function(ent)
    local state = M.ClientState
    if not state then return end
    if ent ~= state.prop1 and ent ~= state.prop2 then return end

    local getter = M.GetActiveClassicMagicAlignTool or M.GetActiveMagicAlignTool
    local tool = IsValid(LocalPlayer()) and getter(LocalPlayer()) or nil
    resetClientSession(tool)
end)

function TOOL:Think()
    local tool, state = activeTool()
    if tool ~= self then return end

    if not validateClientState(self, state) then
        return
    end

    cleanupLinkedProps(state)
    cleanupTargetPointReferences(state)
    state.activeSpace = client.activeSpaceForTool(self)
    client.Mirror.syncEnabled(self, state)
    M.RefreshState(state)
    local worldPoints = client.WorldPoints
    if worldPoints and isfunction(worldPoints.sanitizeState) then
        worldPoints.sanitizeState(state)
    end
    refreshPreferredAnchors(self, state)
    state.hover = hoverState(self, state)
    if client.worldGridRender and isfunction(client.worldGridRender.updateLightProbe) then
        client.worldGridRender.updateLightProbe(state)
    end
    if client.worldGridRender and isfunction(client.worldGridRender.processQueue) then
        client.worldGridRender.processQueue(state._magicAlignHoverSettings)
    end
    pressState.updateActive(self, state, worldPoints)

    solvePreview(self, state)
    pendingPreview(self, state)
    ensureGhost(state)
    updateToolHelp(self, state)

    local attack = input.IsMouseDown(MOUSE_LEFT)
    local use = input.IsKeyDown(KEY_E)
    local blocked = uiBlocked()
    local leftClickQueued = state.leftClickQueued == true
        and RealTime() - (tonumber(state.leftClickQueuedAt) or 0) <= 0.25
    state.leftClickQueued = false
    state.leftClickQueuedAt = nil

    client.Mirror.handleModifierToggle(self, state, blocked)
    if worldPoints
        and not client.Mirror.isActive(self, state)
        and isfunction(worldPoints.handleModifierToggle) then
        worldPoints.handleModifierToggle(state, blocked)
    end
    if blocked then
        if not attack then
            state.press = nil
        end
        state.attackDown = attack
        state.useDown = use
        return
    end

    if leftClickQueued and not state.press then
        pressState.beginMouse(self, state, worldPoints)
        if not attack and state.press then
            pressState.finishMouse(self, state, worldPoints)
        end
    elseif not attack and state.attackDown then
        pressState.finishMouse(self, state, worldPoints)
    end

    state.attackDown = attack
    playQueuedClientActionFeedback(self)

    if use and not state.useDown and not state.press then
        if canCommitState(state) then
            if commit(self, state) == false then
                playToolgunFeedback(self, "fail", false)
            end
        else
            playToolgunFeedback(self, "fail", false)
        end
    end
    state.useDown = use
end


core.useCandidate = useCandidate
core.pressState = pressState

return core
