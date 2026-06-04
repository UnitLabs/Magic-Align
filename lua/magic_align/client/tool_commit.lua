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
local solvePreview = core.solvePreview
local copyMirrorReference = core.copyMirrorReference

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

    if not (isfunction(core.beginCommitUpload) and core.beginCommitUpload(tool, payload, keepSession)) then
        return false
    end

    if isfunction(core.playToolgunFeedback) then
        core.playToolgunFeedback(tool, isMirrorAction and "mirrorCommit" or "commit", true)
    end

    return true
end

core.commit = commit

return core
