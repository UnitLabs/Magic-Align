MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local geometry = client.geometry or {}
client.geometry = geometry
local core = client.ToolCore or include("magic_align/tool_config.lua")
local isvector = M.IsVectorLike
local copyVec = core.copyVec
local copyAng = core.copyAng
local pointWorldCache = core.pointWorldCache
local cachedOffsets = core.cachedOffsets
local cachedAnchorOptions = core.cachedAnchorOptions
local selectedAnchorState = core.selectedAnchorState
local commitMode = core.commitMode
local canCommitState = core.canCommitState
local cleanupLinkedProps = core.cleanupLinkedProps
local resetClientSession = core.resetClientSession
local solvePreview = core.solvePreview
local copyMirrorReference = core.copyMirrorReference
local function writeCommitPoints(points)
    points = istable(points) and points or {}

    net.WriteUInt(#points, 2)
    for i = 1, #points do
        net.WritePreciseVector(points[i])
    end
end

local function predictCommitMirrorVisual(payload, commitId)
    if not istable(payload) or payload.mode == M.COMMIT_COPY then return end
    if not (M.EntityMirror and M.EntityMirror.PredictVisual) then return end

    local deltaAxis = math.Clamp(
        math.floor(tonumber(payload.entityMirrorAxis) or M.ENTITY_MIRROR_NONE),
        M.ENTITY_MIRROR_NONE,
        M.ENTITY_MIRROR_Z
    )
    if deltaAxis == M.ENTITY_MIRROR_NONE then return end

    local function predict(ent)
        if not IsValid(ent) or not M.IsProp(ent) then return end

        local axis = client.Mirror.previewEntityMirrorAxis(ent, deltaAxis)
        M.EntityMirror.PredictVisual(ent, axis, nil, commitId)
    end

    predict(payload.prop1)
    for i = 1, #(payload.linked or {}) do
        predict(payload.linked[i])
    end
end

local function beginCommitUpload(tool, payload, keepSession)
    if istable(M.CommitUpload) and not M.CommitUpload.finishedAt then return false end

    local linked = istable(payload.linked) and payload.linked or {}
    local chunkSize = M.GetCommitLinkedPartSize()
    local totalParts = math.ceil(#linked / chunkSize)

    M._nextCommitUploadId = (tonumber(M._nextCommitUploadId) or 0) + 1
    M.CommitUpload = {
        id = M._nextCommitUploadId,
        tool = tool,
        payload = payload,
        linked = linked,
        keepSession = keepSession == true,
        chunkSize = chunkSize,
        totalParts = totalParts,
        partIndex = 0,
        phase = "begin",
        progress = 0,
        startedAt = RealTime()
    }

    predictCommitMirrorVisual(payload, M.CommitUpload.id)

    return true
end

local function setCommitUploadProgress(upload, step)
    local totalSteps = (upload.totalParts or 0) + 2
    upload.progress = math.Clamp((tonumber(step) or 0) / math.max(totalSteps, 1), 0, 1)
    upload.updatedAt = RealTime()
end

local function sendCommitUploadStep()
    local upload = M.CommitUpload
    if not istable(upload) then return end

    if upload.finishedAt then
        local clearDelay = upload.resultAccepted ~= nil and 0.45 or 8.5
        if RealTime() - upload.finishedAt > clearDelay then
            M.CommitUpload = nil
        end
        return
    end

    local payload = upload.payload
    if not istable(payload) then
        M.CommitUpload = nil
        return
    end

    if upload.phase == "begin" then
        net.Start(M.NET)
            net.WriteUInt(upload.id, 32)
            net.WriteEntity(payload.prop1)
            net.WriteEntity(IsValid(payload.prop2) and payload.prop2 or NULL)
            net.WriteEntity(payload.toolEnt)
            net.WritePreciseVector(payload.pos)
            net.WritePreciseAngle(payload.ang)
            writeCommitPoints(payload.source)
            writeCommitPoints(payload.target)
            net.WriteUInt(#upload.linked, 8)
            net.WriteBool(payload.weld)
            net.WriteBool(payload.nocollide)
            net.WriteBool(payload.parent)
            net.WriteUInt(payload.mode, 2)
            net.WriteBool(payload.absoluteLinked == true)
            net.WriteUInt(math.Clamp(
                math.floor(tonumber(payload.entityMirrorAxis) or M.ENTITY_MIRROR_NONE),
                M.ENTITY_MIRROR_NONE,
                M.ENTITY_MIRROR_Z
            ), 2)
            if M.WriteSessionSnapshot then
                M.WriteSessionSnapshot(payload.sessionSnapshot)
            else
                net.WriteBool(false)
            end
        net.SendToServer()

        upload.phase = upload.totalParts > 0 and "parts" or "finish"
        setCommitUploadProgress(upload, 1)
        return
    end

    if upload.phase == "parts" then
        upload.partIndex = upload.partIndex + 1

        local startIndex = (upload.partIndex - 1) * upload.chunkSize + 1
        local endIndex = math.min(startIndex + upload.chunkSize - 1, #upload.linked)
        local count = math.max(endIndex - startIndex + 1, 0)

        if payload.absoluteLinked == true then
            for i = startIndex, endIndex do
                local target = payload.linkedTargets and payload.linkedTargets[i]
                if not (target and M.IsFiniteVector(target.pos) and M.IsFiniteAngle(target.ang)) then
                    M.CommitUpload = nil
                    return
                end
            end
        end

        net.Start(M.NET_COMMIT_LINKED_PART)
            net.WriteUInt(upload.id, 32)
            net.WriteUInt(upload.partIndex, 8)
            net.WriteUInt(upload.totalParts, 8)
            net.WriteUInt(count, 8)
            for i = startIndex, endIndex do
                net.WriteEntity(upload.linked[i])
                if payload.absoluteLinked == true then
                    local target = payload.linkedTargets and payload.linkedTargets[i]
                    net.WritePreciseVector(target.pos)
                    net.WritePreciseAngle(target.ang)
                end
            end
        net.SendToServer()

        if upload.partIndex >= upload.totalParts then
            upload.phase = "finish"
        end

        setCommitUploadProgress(upload, upload.partIndex + 1)
        return
    end

    net.Start(M.NET_COMMIT_FINISH)
        net.WriteUInt(upload.id, 32)
    net.SendToServer()

    setCommitUploadProgress(upload, (upload.totalParts or 0) + 2)
    upload.finishedAt = RealTime()

    if not upload.keepSession then
        resetClientSession(upload.tool)
    end
end

hook.Remove("Think", "MagicAlignCommitUpload")
hook.Add("Think", "MagicAlignCommitUpload", sendCommitUploadStep)

local function commit(tool, state)
    if not canCommitState(state) then return false end

    if M.FormulaManager and isfunction(M.FormulaManager.RefreshAll) then
        local changed = M.FormulaManager:RefreshAll(true)
        if changed then
            state._magicAlignPreviewCache = nil
            solvePreview(tool, state)
            if not state.preview
                or not M.IsFiniteVector(state.preview.pos)
                or not M.IsFiniteAngle(state.preview.ang) then
                return false
            end
        end
    end

    cleanupLinkedProps(state)

    local linked = {}
    local linkedTargets = {}
    local absoluteLinked = state.preview.absoluteLinked == true
    local maxLinked = M.GetMaxLinkedProps()
    if absoluteLinked then
        for i = 1, math.min(#(state.preview.linked or {}), maxLinked) do
            local entry = state.preview.linked[i]
            local ent = entry and entry.ent
            if IsValid(ent) and ent ~= state.prop1 and M.IsProp(ent)
                and M.IsFiniteVector(entry.pos) and M.IsFiniteAngle(entry.ang) then
                linked[#linked + 1] = ent
                linkedTargets[#linkedTargets + 1] = {
                    pos = entry.pos,
                    ang = entry.ang
                }
            end
        end
    else
        for i = 1, math.min(#state.linked, maxLinked) do
            local ent = state.linked[i]
            if IsValid(ent) and ent ~= state.prop1 and ent ~= state.prop2 and M.IsProp(ent) then
                linked[#linked + 1] = ent
            end
        end
    end

    local mode, keepSession = commitMode()
    local weldOnCommit = tool:GetClientNumber("weld") == 1
    local nocollideOnCommit = weldOnCommit or tool:GetClientNumber("nocollide") == 1
    local activeSpace = client.activeSpaceForTool(tool)
    local isMirrorAction = state.preview.transformMode == M.TRANSFORM_MODE_MIRROR
        or client.Mirror.isActive(tool, state)
    local sourceAnchorOptions = select(1, cachedAnchorOptions(tool, state, "from"))
    local targetAnchorOptions = select(1, cachedAnchorOptions(tool, state, "to"))
    local sourceAnchorId, sourcePriority = selectedAnchorState(tool, state, "from")
    local targetAnchorId, targetPriority = selectedAnchorState(tool, state, "to")
    local mirrorEntityCvar = GetConVar("magic_align_mirror_entity_mirror")
    local linkedStarts = {}
    for i = 1, #linked do
        local ent = linked[i]
        linkedStarts[i] = {
            pos = copyVec(ent:GetPos()),
            ang = copyAng(ent:GetAngles())
        }
    end

    local payload = {
        prop1 = state.prop1,
        prop2 = absoluteLinked and nil or (geometry.isWorldTarget(state.prop2) and nil or state.prop2),
        toolEnt = LocalPlayer():GetActiveWeapon(),
        startPos = copyVec(state.prop1:GetPos()),
        startAng = copyAng(state.prop1:GetAngles()),
        pos = state.preview.pos,
        ang = state.preview.ang,
        source = M.CopyPoints(state.source),
        target = absoluteLinked and {} or (geometry.isWorldTarget(state.prop2) and {} or M.CopyPoints(state.target)),
        linked = linked,
        linkedStarts = linkedStarts,
        linkedTargets = absoluteLinked and linkedTargets or nil,
        absoluteLinked = absoluteLinked,
        mirrorReference = copyMirrorReference(state.preview.mirrorReference),
        sessionSnapshot = M.CreateSessionSnapshot and M.CreateSessionSnapshot(state, {
            activeSpace = activeSpace,
            lastNonMirrorTab = M.ClientLastNonMirrorSpace,
            actionType = isMirrorAction and "mirror" or "align",
            isMirrorAction = isMirrorAction,
            mode = mode,
            offsets = select(1, cachedOffsets(tool, state)),
            anchors = {
                from = {
                    selected = sourceAnchorId,
                    priority = sourcePriority,
                    options = sourceAnchorOptions
                },
                to = {
                    selected = targetAnchorId,
                    priority = targetPriority,
                    options = targetAnchorOptions
                }
            },
            entityMirrorEnabled = mirrorEntityCvar and mirrorEntityCvar:GetBool() or false
        }) or nil,
        weld = weldOnCommit,
        nocollide = nocollideOnCommit,
        parent = tool:GetClientNumber("parent") == 1,
        mode = mode,
        entityMirrorAxis = state.preview.entityMirrorAxis or M.ENTITY_MIRROR_NONE
    }

    if not beginCommitUpload(tool, payload, keepSession) then
        return false
    end

    if isfunction(core.playToolgunFeedback) then
        core.playToolgunFeedback(tool, isMirrorAction and "mirrorCommit" or "commit", true)
    end

    return true
end

core.commit = commit

return core
