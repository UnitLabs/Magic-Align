MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local core = client.ToolCore or include("magic_align/tool_config.lua")

local function writeCommitPoints(points)
    points = istable(points) and points or {}

    net.WriteUInt(#points, 2)
    for i = 1, #points do
        net.WritePreciseVector(points[i])
    end
end

local function previewEntityMirrorAxis(ent, deltaAxis)
    if client.Mirror and isfunction(client.Mirror.previewEntityMirrorAxis) then
        return client.Mirror.previewEntityMirrorAxis(ent, deltaAxis)
    end

    if M.EntityMirror and M.EntityMirror.ComposeAxis and M.EntityMirror.GetAxis then
        return M.EntityMirror.ComposeAxis(M.EntityMirror.GetAxis(ent), deltaAxis)
    end

    return M.ENTITY_MIRROR_NONE
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

        M.EntityMirror.PredictVisual(ent, previewEntityMirrorAxis(ent, deltaAxis), nil, commitId)
    end

    predict(payload.prop1)
    for i = 1, #(payload.linked or {}) do
        predict(payload.linked[i])
    end
end

function core.beginCommitUpload(tool, payload, keepSession)
    if istable(M.CommitUpload) and not M.CommitUpload.finishedAt then return false end
    if not istable(payload) then return false end

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
            net.WriteBool(payload.weld == true)
            net.WriteBool(payload.nocollide == true)
            net.WriteBool(payload.parent == true)
            net.WriteUInt(payload.mode or M.COMMIT_MOVE, 2)
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

    if not upload.keepSession and isfunction(core.resetClientSession) then
        core.resetClientSession(upload.tool)
    end
end

hook.Remove("Think", "MagicAlignCommitUpload")
hook.Add("Think", "MagicAlignCommitUpload", sendCommitUploadStep)

return core
