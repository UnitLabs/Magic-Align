MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

util.AddNetworkString(MAGIC_ALIGN.NET)
util.AddNetworkString(MAGIC_ALIGN.NET_COMMIT_LINKED_PART)
util.AddNetworkString(MAGIC_ALIGN.NET_COMMIT_FINISH)
util.AddNetworkString(MAGIC_ALIGN.NET_COMMIT_RESULT)
util.AddNetworkString(MAGIC_ALIGN.NET_UNDO_RESTORE)
util.AddNetworkString(MAGIC_ALIGN.NET_BOUNDS_REQUEST)
util.AddNetworkString(MAGIC_ALIGN.NET_BOUNDS_REPLY)
util.AddNetworkString(MAGIC_ALIGN.NET_CLIENT_ACTION)
util.AddNetworkString(MAGIC_ALIGN.NET_VIEW_ANGLES)

local M = MAGIC_ALIGN
local VectorP = M.VectorP
local AngleP = M.AngleP
local toVector = M.ToVector
local toAngle = M.ToAngle
local REQUEST_STATE = setmetatable({}, { __mode = "k" })
local COMMIT_LOCK = setmetatable({}, { __mode = "k" })
local PENDING_COMMITS = setmetatable({}, { __mode = "k" })
local COMMIT_QUEUE = {}
local COMMIT_UPLOAD_TIMEOUT = 8
local COMMIT_ID_MAX = 4294967295
local runCommit
local modelScale = M.GetEntityModelScale

local function sendCommitResult(ply, commitId, ok, reason)
    if not IsValid(ply) then return end

    commitId = math.Clamp(math.floor(tonumber(commitId) or 0), 0, COMMIT_ID_MAX)
    reason = math.Clamp(
        math.floor(tonumber(reason) or (ok and M.COMMIT_RESULT_OK or M.COMMIT_RESULT_FAILED)),
        0,
        15
    )

    net.Start(M.NET_COMMIT_RESULT)
        net.WriteUInt(commitId, 32)
        net.WriteBool(ok == true)
        net.WriteUInt(reason, 4)
    net.Send(ply)
end

local function rejectCommit(ply, commitId, reason)
    sendCommitResult(ply, commitId, false, reason or M.COMMIT_RESULT_INVALID)
end

local function rejectPendingCommit(ply, pending, reason)
    if istable(pending) then
        rejectCommit(ply, pending.id, reason)
    end

    if IsValid(ply) then
        PENDING_COMMITS[ply] = nil
    end
end

local function finiteNumber(value)
    value = tonumber(value)
    return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
end

local function hasFiniteVectorFields(v)
    return v ~= nil and finiteNumber(v.x) and finiteNumber(v.y) and finiteNumber(v.z)
end

local function hasFiniteAngleFields(a)
    return a ~= nil and finiteNumber(a.p) and finiteNumber(a.y) and finiteNumber(a.r)
end

local function asGModVector(v)
    if not hasFiniteVectorFields(v) then return end

    local converted = isfunction(toVector) and toVector(v) or nil
    if converted ~= nil then return converted end
    if not isfunction(Vector) then return end

    return Vector(v.x, v.y, v.z)
end

local function asGModAngle(a)
    if not hasFiniteAngleFields(a) then return end

    local converted = isfunction(toAngle) and toAngle(a) or nil
    if converted ~= nil then return converted end
    if not isfunction(Angle) then return end

    return Angle(a.p, a.y, a.r)
end

local function preciseVector(x, y, z)
    local maker = M.VectorP or VectorP
    if isfunction(maker) then
        return maker(x, y, z)
    end
    if isfunction(Vector) then
        return Vector(x, y, z)
    end
end

local function preciseAngle(p, y, r)
    local maker = M.AngleP or AngleP
    if isfunction(maker) then
        return maker(p, y, r)
    end
    if isfunction(Angle) then
        return Angle(p, y, r)
    end
end

local function cloneVec(v)
    if not hasFiniteVectorFields(v) then return end

    return preciseVector(v.x, v.y, v.z) or asGModVector(v)
end

local function cloneAng(a)
    if not hasFiniteAngleFields(a) then return end

    return preciseAngle(a.p, a.y, a.r) or asGModAngle(a)
end

local SCALE_IDENTITY = preciseVector(1, 1, 1)

local function advResizerData(ent)
    local entityMods = IsValid(ent) and ent.EntityMods or nil
    local modifierData = istable(entityMods) and entityMods.advr or nil
    if istable(modifierData) then
        return table.Copy(modifierData)
    end

    local physical, visual = M.GetAdvResizerScales(ent)
    if not hasFiniteVectorFields(physical) or not hasFiniteVectorFields(visual) then
        return
    end

    if M.VectorApprox(physical, SCALE_IDENTITY) and M.VectorApprox(visual, SCALE_IDENTITY) then
        return
    end

    return {
        physical.x,
        physical.y,
        physical.z,
        visual.x,
        visual.y,
        visual.z,
        false
    }
end

local function applyAdvResizerData(ply, src, ent)
    if not IsValid(src) or not IsValid(ent) then return end
    if not duplicator or not isfunction(duplicator.StoreEntityModifier) or not isfunction(duplicator.ApplyEntityModifiers) then
        return
    end

    local data = advResizerData(src)
    if not istable(data) then return end

    duplicator.StoreEntityModifier(ent, "advr", data)
    duplicator.ApplyEntityModifiers(ply, ent)
end

local function entityModel(ent)
    if not IsValid(ent) or not isfunction(ent.GetModel) then return end

    local model = ent:GetModel()
    if not isstring(model) or model == "" then return end

    return model
end

local function applyEntityAppearance(src, ent, pos, ang)
    if not IsValid(src) or not IsValid(ent) then return end

    local model = entityModel(src)
    if model and isfunction(ent.SetModel) and ent:GetModel() ~= model then
        ent:SetModel(model)
    end

    local gPos = asGModVector(pos)
    if gPos and isfunction(ent.SetPos) then
        ent:SetPos(gPos)
    end

    local gAng = asGModAngle(ang)
    if gAng and isfunction(ent.SetAngles) then
        ent:SetAngles(gAng)
    end

    if isfunction(ent.SetSkin) then
        ent:SetSkin(src:GetSkin() or 0)
    end

    if isfunction(ent.SetMaterial) then
        ent:SetMaterial(src:GetMaterial() or "")
    end

    if isfunction(ent.SetColor) then
        ent:SetColor(src:GetColor())
    end

    if isfunction(ent.SetRenderMode) and isfunction(src.GetRenderMode) then
        ent:SetRenderMode(src:GetRenderMode())
    end

    if isfunction(ent.SetRenderFX) and isfunction(src.GetRenderFX) then
        ent:SetRenderFX(src:GetRenderFX())
    end

    if isfunction(ent.SetCollisionGroup) then
        ent:SetCollisionGroup(src:GetCollisionGroup())
    end

    if isfunction(ent.SetModelScale) then
        ent:SetModelScale(modelScale(src), 0)
    end

    local bodygroupCount = isfunction(src.GetNumBodyGroups) and src:GetNumBodyGroups() or 0
    if isfunction(ent.SetBodygroup) then
        for i = 0, bodygroupCount - 1 do
            ent:SetBodygroup(i, src:GetBodygroup(i))
        end
    end

    if isfunction(ent.SetSubMaterial) and isfunction(src.GetSubMaterial) then
        local srcMaterials = isfunction(src.GetMaterials) and src:GetMaterials() or nil
        local entMaterials = isfunction(ent.GetMaterials) and ent:GetMaterials() or nil
        local subCount = math.max(
            istable(srcMaterials) and #srcMaterials or 0,
            istable(entMaterials) and #entMaterials or 0
        )

        for i = 0, subCount - 1 do
            ent:SetSubMaterial(i, src:GetSubMaterial(i) or "")
        end
    end
end

local function copyPhysicsState(src, ent)
    local srcPhys = IsValid(src) and src:GetPhysicsObject() or nil
    local dstPhys = IsValid(ent) and ent:GetPhysicsObject() or nil
    if not IsValid(srcPhys) or not IsValid(dstPhys) then return end

    if isfunction(dstPhys.SetMass) and isfunction(srcPhys.GetMass) then
        dstPhys:SetMass(srcPhys:GetMass())
    end

    if isfunction(dstPhys.SetMaterial) and isfunction(srcPhys.GetMaterial) then
        dstPhys:SetMaterial(srcPhys:GetMaterial())
    end

    if isfunction(dstPhys.EnableGravity) and isfunction(srcPhys.IsGravityEnabled) then
        dstPhys:EnableGravity(srcPhys:IsGravityEnabled())
    end
end

local function registerClonedEntity(ply, ent, src)
    if not IsValid(ply) or not IsValid(ent) then return end

    if ent.SetCreator then
        ent:SetCreator(ply)
    end

    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end

    if ply.AddCleanup then
        ply:AddCleanup("props", ent)
    else
        cleanup.Add(ply, "props", ent)
    end

    local model = entityModel(ent) or entityModel(src)
    if model then
        hook.Run("PlayerSpawnedProp", ply, model, ent)
    end
end

local function countClonedProp(ply, ent)
    if not IsValid(ply) or not IsValid(ent) or not ply.AddCount then return end

    ply:AddCount("props", ent)
end

local function applyDuplicatorData(ply, src, ent, data)
    if not IsValid(ent) or not istable(data) then return end

    if isfunction(ent.RestoreNetworkVars) then
        ent:RestoreNetworkVars(data.DT)
    end

    if isfunction(ent.OnDuplicated) then
        ent:OnDuplicated(data)
    end

    if istable(data.EntityMods) then
        ent.EntityMods = table.Copy(data.EntityMods)
    end

    if istable(data.BoneMods) then
        ent.BoneMods = table.Copy(data.BoneMods)
    end

    if istable(data.PhysicsObjects) then
        ent.PhysicsObjects = table.Copy(data.PhysicsObjects)
    end

    if not (istable(data.EntityMods) and istable(data.EntityMods.advr))
        and duplicator
        and isfunction(duplicator.StoreEntityModifier) then
        local advrData = advResizerData(src)
        if istable(advrData) then
            duplicator.StoreEntityModifier(ent, "advr", advrData)
        end
    end

    if duplicator and isfunction(duplicator.ApplyEntityModifiers) then
        duplicator.ApplyEntityModifiers(ply, ent)
    end

    if duplicator and isfunction(duplicator.ApplyBoneModifiers) then
        duplicator.ApplyBoneModifiers(ply, ent)
    end

    if isfunction(ent.PostEntityPaste) then
        local created = IsValid(src) and { [src:EntIndex()] = ent } or { ent }
        ent:PostEntityPaste(ply or NULL, ent, created)
    end
end

local function cloneViaDuplicator(ply, src, pos, ang)
    if not duplicator
        or not isfunction(duplicator.CopyEntTable)
        or not isfunction(duplicator.CreateEntityFromTable) then
        return
    end

    local okCopy, data = pcall(duplicator.CopyEntTable, src)
    if not okCopy or not istable(data) then return end

    if istable(data.EntityMods) and M.ENTITY_MIRROR_MODIFIER_ID then
        data.EntityMods = table.Copy(data.EntityMods)
        data.EntityMods[M.ENTITY_MIRROR_MODIFIER_ID] = nil
    end

    if istable(data.BuildDupeInfo) then
        data.BuildDupeInfo = table.Copy(data.BuildDupeInfo)
        data.BuildDupeInfo.DupeParentID = nil
    end

    local okCreate, ent = pcall(duplicator.CreateEntityFromTable, ply, data)
    if not okCreate or not IsValid(ent) then return end

    applyEntityAppearance(src, ent, pos, ang)
    applyDuplicatorData(ply, src, ent, data)

    if isfunction(ent.Activate) then
        ent:Activate()
    end

    registerClonedEntity(ply, ent, src)

    return ent
end

local function cloneViaSpawnFallback(ply, src, pos, ang)
    local ent = ents.Create(src:GetClass())
    if not IsValid(ent) then return end

    local model = entityModel(src)
    if model and isfunction(ent.SetModel) then
        ent:SetModel(model)
    end

    local gPos = asGModVector(pos)
    if gPos and isfunction(ent.SetPos) then
        ent:SetPos(gPos)
    end

    local gAng = asGModAngle(ang)
    if gAng and isfunction(ent.SetAngles) then
        ent:SetAngles(gAng)
    end

    if isfunction(ent.Spawn) then
        ent:Spawn()
    end

    applyEntityAppearance(src, ent, pos, ang)

    if isfunction(ent.Activate) then
        ent:Activate()
    end

    applyAdvResizerData(ply, src, ent)
    copyPhysicsState(src, ent)

    registerClonedEntity(ply, ent, src)

    return ent
end

local function captureEntityState(ent)
    if not IsValid(ent) then return end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    if not hasFiniteVectorFields(pos) or not hasFiniteAngleFields(ang) then return end

    return {
        ent = ent,
        pos = cloneVec(pos),
        ang = cloneAng(ang),
        entityMirror = M.EntityMirror and M.EntityMirror.Capture and M.EntityMirror.Capture(ent) or nil,
        parent = IsValid(ent:GetParent()) and ent:GetParent() or nil
    }
end

local function canUse(ply, ent)
    if not M.IsProp(ent) then return false end

    if ent.CPPICanTool and ent:CPPICanTool(ply, "magic_align") == false then
        return false
    end

    local tr = {
        Entity = ent,
        HitPos = ent:WorldSpaceCenter(),
        HitNormal = asGModVector(preciseVector(0, 0, 1)),
        StartPos = ply:EyePos()
    }

    if hook.Run("CanTool", ply, tr, "magic_align") == false then
        return false
    end

    return true
end

local function readPoints()
    local count = net.ReadUInt(2)
    local points = {}

    for i = 1, count do
        points[i] = net.ReadPreciseVector()
    end

    return points
end

local function finitePoints(points)
    if not istable(points) then return false end

    for i = 1, #points do
        if not hasFiniteVectorFields(points[i]) then
            return false
        end
    end

    return true
end

local function queueCommit(task)
    if not istable(task) or not IsValid(task.ply) or COMMIT_LOCK[task.ply] then return false end

    COMMIT_LOCK[task.ply] = true
    task.co = coroutine.create(function()
        return runCommit(task)
    end)
    COMMIT_QUEUE[#COMMIT_QUEUE + 1] = task

    return true
end

local function cloneEntity(ply, src, pos, ang)
    if not IsValid(src) or not hasFiniteVectorFields(pos) or not hasFiniteAngleFields(ang) then return end
    if ply.CheckLimit and not ply:CheckLimit("props") then return end

    -- Prefer the stock duplicator path first so scripted entities can carry
    -- their own registered duplicate/restore logic without relying on AdvDupe.
    local ent = cloneViaDuplicator(ply, src, pos, ang)
    if IsValid(ent) then
        countClonedProp(ply, ent)
        return ent
    end

    if M.Compat and isfunction(M.Compat.CloneEntity) then
        local handled, compatEnt = M.Compat.CloneEntity(ply, src, pos, ang)
        if handled then
            countClonedProp(ply, compatEnt)
            return compatEnt
        end
    end

    ent = cloneViaSpawnFallback(ply, src, pos, ang)
    countClonedProp(ply, ent)

    return ent
end

local function settlePhysics(ent)
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end

    phys:SetPos(ent:GetPos())
    phys:SetAngles(ent:GetAngles())

    phys:EnableMotion(false)
    phys:Sleep()
end

local function applyEntityMirrorStateFromStart(ent, startState, deltaAxis, options)
    if not (M.EntityMirror and M.EntityMirror.ApplyFromBaseState) then return false end

    return M.EntityMirror.ApplyFromBaseState(
        ent,
        startState,
        deltaAxis,
        M.ENTITY_MIRROR_DEFAULT_FLAGS,
        options
    )
end

local function debugCommitEntity(label, ent, spec, entityMirrorAxis)
    if not (M.EntityMirror and M.EntityMirror.DebugEntity) then return end
    if not IsValid(ent) or not istable(spec) then return end

    local start = spec.start or {}
    M.EntityMirror.DebugEntity(label, ent, {
        requestedDeltaAxis = M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(entityMirrorAxis) or tostring(entityMirrorAxis),
        startPos = start.pos,
        startAng = start.ang,
        targetPos = spec.targetPos,
        targetAng = spec.targetAng,
        startMirrorAxis = istable(start.entityMirror) and (M.EntityMirror.AxisLabel and M.EntityMirror.AxisLabel(start.entityMirror.axis) or tostring(start.entityMirror.axis)) or "nil"
    })
end

local function removeEntities(entities)
    for i = 1, #entities do
        if IsValid(entities[i]) then
            entities[i]:Remove()
        end
    end
end

local function commitCheckpoint(task)
    if SysTime() < (task.deadline or 0) then return end
    coroutine.yield()
end

local function releaseCommitLock(task)
    if task and task.ply then
        COMMIT_LOCK[task.ply] = nil
    end
end

local function undoRestoreEntry(state)
    local ent = state and state.ent or nil
    if not IsValid(ent) or not (M.IsPrimitive and M.IsPrimitive(ent)) then return end
    if not hasFiniteVectorFields(state.pos) or not hasFiniteAngleFields(state.ang) then return end

    local fromPos = cloneVec(ent:GetPos())
    local fromAng = cloneAng(ent:GetAngles())
    if not hasFiniteVectorFields(fromPos) or not hasFiniteAngleFields(fromAng) then return end

    return {
        ent = ent,
        fromPos = fromPos,
        fromAng = fromAng,
        toPos = cloneVec(state.pos),
        toAng = cloneAng(state.ang)
    }
end

local function sendUndoRestore(ply, entries, sessionSnapshot)
    if not IsValid(ply) then return end
    if (not istable(entries) or #entries < 1) and not istable(sessionSnapshot) then return end

    local count = math.min(istable(entries) and #entries or 0, 255)
    net.Start(M.NET_UNDO_RESTORE)
        net.WriteUInt(count, 8)
        for i = 1, count do
            local entry = entries[i]
            net.WriteEntity(entry.ent)
            net.WritePreciseVector(entry.fromPos)
            net.WritePreciseAngle(entry.fromAng)
            net.WritePreciseVector(entry.toPos)
            net.WritePreciseAngle(entry.toAng)
        end
        if M.WriteSessionSnapshot then
            M.WriteSessionSnapshot(sessionSnapshot)
        else
            net.WriteBool(false)
        end
    net.Send(ply)
end

local function restoreCommitStep(_, props, created, undoPly, sessionSnapshot)
    -- A commit undo only needs the props' previous transforms plus the entities
    -- created by that step, such as constraints, copies or copy&move backups.
    local validProps = {}
    local undoRestoreEntries = {}

    for i = 1, #(created or {}) do
        local ent = created[i]
        if IsValid(ent) then
            ent:Remove()
        end
    end

    for i = 1, #(props or {}) do
        local state = props[i]
        local ent = state and state.ent or nil
        if IsValid(ent) and hasFiniteVectorFields(state.pos) and hasFiniteAngleFields(state.ang) then
            validProps[#validProps + 1] = state
            local entry = undoRestoreEntry(state)
            if entry then
                undoRestoreEntries[#undoRestoreEntries + 1] = entry
            end
        end
    end

    for i = 1, #validProps do
        validProps[i].ent:SetParent(nil)
    end

    for i = 1, #validProps do
        local state = validProps[i]
        local ent = state.ent
        if IsValid(ent) then
            local pos = asGModVector(state.pos)
            local ang = asGModAngle(state.ang)
            if pos and ang then
                ent:SetPos(pos)
                ent:SetAngles(ang)
            end
            if M.EntityMirror and M.EntityMirror.Restore then
                M.EntityMirror.Restore(ent, state.entityMirror)
            end
        end
    end

    for i = 1, #validProps do
        local state = validProps[i]
        local parent = IsValid(state.parent) and state.parent or nil
        state.ent:SetParent(parent)
    end

    for i = 1, #validProps do
        settlePhysics(validProps[i].ent)
    end

    sendUndoRestore(undoPly, undoRestoreEntries, sessionSnapshot)
end

local function expandWorldBounds(mins, maxs, point)
    if not hasFiniteVectorFields(point) then return mins, maxs end

    if not hasFiniteVectorFields(mins) or not hasFiniteVectorFields(maxs) then
        return cloneVec(point), cloneVec(point)
    end

    mins.x = math.min(mins.x, point.x)
    mins.y = math.min(mins.y, point.y)
    mins.z = math.min(mins.z, point.z)
    maxs.x = math.max(maxs.x, point.x)
    maxs.y = math.max(maxs.y, point.y)
    maxs.z = math.max(maxs.z, point.z)

    return mins, maxs
end

local function worldBounds(ent)
    local mins, maxs = M.GetLocalBounds(ent)
    if not hasFiniteVectorFields(mins) or not hasFiniteVectorFields(maxs) then return end

    local worldMins, worldMaxs
    local corners = {
        preciseVector(mins.x, mins.y, mins.z),
        preciseVector(mins.x, mins.y, maxs.z),
        preciseVector(mins.x, maxs.y, mins.z),
        preciseVector(mins.x, maxs.y, maxs.z),
        preciseVector(maxs.x, mins.y, mins.z),
        preciseVector(maxs.x, mins.y, maxs.z),
        preciseVector(maxs.x, maxs.y, mins.z),
        preciseVector(maxs.x, maxs.y, maxs.z)
    }

    local entPos = ent:GetPos()
    local entAng = ent:GetAngles()
    if not hasFiniteVectorFields(entPos) or not hasFiniteAngleFields(entAng) then return end

    for i = 1, #corners do
        local worldPos = M.LocalToWorldPrecise(corners[i], preciseAngle(0, 0, 0), entPos, entAng)
        worldMins, worldMaxs = expandWorldBounds(worldMins, worldMaxs, worldPos)
    end

    return worldMins, worldMaxs
end

local function aabbOverlap(minsA, maxsA, minsB, maxsB)
    if not hasFiniteVectorFields(minsA) or not hasFiniteVectorFields(maxsA)
        or not hasFiniteVectorFields(minsB) or not hasFiniteVectorFields(maxsB) then
        return false
    end

    return minsA.x <= maxsB.x and maxsA.x >= minsB.x
        and minsA.y <= maxsB.y and maxsA.y >= minsB.y
        and minsA.z <= maxsB.z and maxsA.z >= minsB.z
end

local function pairKey(a, b)
    if not IsValid(a) or not IsValid(b) then return end

    local first = a:EntIndex()
    local second = b:EntIndex()

    if first > second then
        first, second = second, first
    end

    return ("%d:%d"):format(first, second)
end

local function addNoCollideConstraint(a, b, made, nocollidePairs)
    if not IsValid(a) or not IsValid(b) or a == b then return end

    local key = pairKey(a, b)
    if not key or nocollidePairs[key] then return end

    local c = constraint.NoCollide(a, b, 0, 0)
    if IsValid(c) then
        nocollidePairs[key] = true
        made[#made + 1] = c
    end
end

local function applyOverlapNoCollides(entities, made, nocollidePairs, task)
    local bounds = {}
    local valid = {}

    for i = 1, #entities do
        local ent = entities[i]
        if IsValid(ent) then
            local mins, maxs = worldBounds(ent)
            if hasFiniteVectorFields(mins) and hasFiniteVectorFields(maxs) then
                bounds[ent] = {
                    mins = mins,
                    maxs = maxs
                }
                valid[#valid + 1] = ent
            end
        end

        commitCheckpoint(task)
    end

    for i = 1, #valid do
        local entA = valid[i]
        local dataA = bounds[entA]

        for j = i + 1, #valid do
            local entB = valid[j]
            local dataB = bounds[entB]

            if dataA and dataB and aabbOverlap(dataA.mins, dataA.maxs, dataB.mins, dataB.maxs) then
                addNoCollideConstraint(entA, entB, made, nocollidePairs)
            end

            commitCheckpoint(task)
        end
    end
end

local function applyCommitRelations(target, anchor, weld, nocollide, parent, made, nocollidePairs)
    if not IsValid(target) or not IsValid(anchor) or target == anchor then return end

    if weld then
        local c = constraint.Weld(target, anchor, 0, 0, 0, true, false)
        if IsValid(c) then
            made[#made + 1] = c
        end
    end

    if nocollide then
        addNoCollideConstraint(target, anchor, made, nocollidePairs)
    end

    if parent then
        target:SetParent(anchor)
    end
end

function runCommit(task)
    local ply = task.ply
    local prop1 = task.prop1
    local prop2 = task.prop2
    local pos, ang = task.pos, task.ang
    local sourcePoints = task.sourcePoints
    local targetPoints = task.targetPoints
    local linkedProps = task.linkedProps
    local weld = task.weld
    local nocollide = task.nocollide
    local parent = task.parent
    local mode = task.mode
    local entityMirrorAxis = tonumber(task.entityMirrorAxis) or M.ENTITY_MIRROR_NONE
    local linkedTargets = istable(task.linkedTargets) and task.linkedTargets or nil
    local usesAbsoluteTargets = linkedTargets ~= nil
    local effectiveNocollide = nocollide or weld

    if not IsValid(ply) then return end
    if not canUse(ply, prop1) then return end
    if IsValid(prop2) and not canUse(ply, prop2) then return end
    if prop1 == prop2 then return end
    if #linkedProps > M.GetMaxLinkedProps() then return end
    if linkedTargets and #linkedTargets ~= #linkedProps then return end

    if usesAbsoluteTargets then
        if #sourcePoints > M.MAX_POINTS then return end
    elseif #sourcePoints < 1 or #sourcePoints > M.MAX_POINTS then
        return
    end
    if #targetPoints > M.MAX_POINTS then return end
    if not finitePoints(sourcePoints) or not finitePoints(targetPoints) then return end
    if not hasFiniteVectorFields(pos) or not hasFiniteAngleFields(ang) then return end
    if mode ~= M.COMMIT_MOVE and mode ~= M.COMMIT_COPY and mode ~= M.COMMIT_COPY_MOVE then return end
    if entityMirrorAxis < M.ENTITY_MIRROR_NONE or entityMirrorAxis > M.ENTITY_MIRROR_Z then return end

    local sources = { prop1 }
    local seen = { [prop1] = true }
    if IsValid(prop2) then
        seen[prop2] = true
    end

    for i = 1, #linkedProps do
        local ent = linkedProps[i]
        if not IsValid(ent) or seen[ent] or not canUse(ply, ent) then return end

        local absolute = linkedTargets and linkedTargets[i] or nil
        if linkedTargets and (
            not istable(absolute)
            or not hasFiniteVectorFields(absolute.pos)
            or not hasFiniteAngleFields(absolute.ang)
        ) then
            return
        end

        seen[ent] = true
        sources[#sources + 1] = ent
        commitCheckpoint(task)
    end

    local sourcePos = cloneVec(prop1:GetPos())
    local sourceAng = cloneAng(prop1:GetAngles())
    local undoProps = {}
    local undoSeen = {}

    local function addUndoProp(ent)
        if not IsValid(ent) or undoSeen[ent] then return true end

        local start = captureEntityState(ent)
        if not start then return false end

        undoSeen[ent] = true
        undoProps[#undoProps + 1] = start
        return true
    end

    if not hasFiniteVectorFields(sourcePos) or not hasFiniteAngleFields(sourceAng) then return end
    if not addUndoProp(prop1) then return end
    if IsValid(prop2) and not addUndoProp(prop2) then return end

    local specs = {}
    for i = 1, #sources do
        local ent = sources[i]
        local start = captureEntityState(ent)
        if not start then return end
        local targetPos, targetAng, localPos, localAng

        if i == 1 then
            targetPos, targetAng = pos, ang
            localPos, localAng = M.WorldToLocalPrecise(start.pos, start.ang, sourcePos, sourceAng)
        elseif linkedTargets then
            local absolute = linkedTargets[i - 1]
            if not istable(absolute) then return end
            targetPos, targetAng = absolute.pos, absolute.ang
            localPos, localAng = M.WorldToLocalPrecise(start.pos, start.ang, sourcePos, sourceAng)
        else
            targetPos, targetAng, localPos, localAng = M.TransformPoseRelativePrecise(start.pos, start.ang, sourcePos, sourceAng, pos, ang)
        end

        if not hasFiniteVectorFields(localPos) or not hasFiniteAngleFields(localAng)
            or not hasFiniteVectorFields(targetPos) or not hasFiniteAngleFields(targetAng) then
            return
        end

        specs[i] = {
            source = ent,
            start = start,
            targetPos = cloneVec(targetPos),
            targetAng = cloneAng(targetAng)
        }

        if not addUndoProp(ent) then return end
        commitCheckpoint(task)
    end

    local created = {}
    local committed = {}

    if mode == M.COMMIT_COPY then
        for i = 1, #specs do
            if not IsValid(ply) then
                removeEntities(created)
                return
            end

            local spec = specs[i]
            if not IsValid(spec.source) then
                removeEntities(created)
                return
            end

            local target = cloneEntity(ply, spec.source, spec.targetPos, spec.targetAng)
            if not IsValid(target) then
                removeEntities(created)
                return
            end

            debugCommitEntity("commit-copy-after-clone", target, spec, entityMirrorAxis)
            applyEntityMirrorStateFromStart(target, spec.start.entityMirror, entityMirrorAxis, {
                includeBaseState = true,
                normalizeInherited = true
            })
            settlePhysics(target)
            debugCommitEntity("commit-copy-after-mirror", target, spec, entityMirrorAxis)
            committed[#committed + 1] = target
            created[#created + 1] = target
            commitCheckpoint(task)
        end
    else
        if mode == M.COMMIT_COPY_MOVE then
            for i = 1, #specs do
                if not IsValid(ply) then
                    removeEntities(created)
                    return
                end

                local spec = specs[i]
                if not IsValid(spec.source) then
                    removeEntities(created)
                    return
                end

                local backup = cloneEntity(ply, spec.source, spec.start.pos, spec.start.ang)
                if not IsValid(backup) then
                    removeEntities(created)
                    return
                end

                applyEntityMirrorStateFromStart(backup, spec.start.entityMirror, M.ENTITY_MIRROR_NONE, {
                    includeBaseState = true,
                    normalizeInherited = true
                })
                settlePhysics(backup)
                created[#created + 1] = backup
                commitCheckpoint(task)
            end
        end

        for i = 1, #specs do
            local spec = specs[i]
            local target = spec.source
            if not IsValid(target) then
                removeEntities(created)
                return
            end

            local targetPos = asGModVector(spec.targetPos)
            local targetAng = asGModAngle(spec.targetAng)
            if not targetPos or not targetAng then
                removeEntities(created)
                return
            end

                target:SetParent(nil)
                target:SetPos(targetPos)
                target:SetAngles(targetAng)
                settlePhysics(target)
                debugCommitEntity("commit-move-after-setpose", target, spec, entityMirrorAxis)
                if applyEntityMirrorStateFromStart(target, spec.start.entityMirror, entityMirrorAxis) then
                    settlePhysics(target)
                    debugCommitEntity("commit-move-after-mirror", target, spec, entityMirrorAxis)
                end
                committed[#committed + 1] = target
            commitCheckpoint(task)
        end
    end

    local nocollidePairs = {}
    local committedProp1 = committed[1]

    if IsValid(committedProp1) and IsValid(prop2) then
        applyCommitRelations(committedProp1, prop2, weld, effectiveNocollide, parent, created, nocollidePairs)
        commitCheckpoint(task)
    end

    for i = 2, #committed do
        applyCommitRelations(committed[i], committedProp1, weld, effectiveNocollide, parent, created, nocollidePairs)
        commitCheckpoint(task)
    end

    if effectiveNocollide then
        local overlapEntities = {}

        if IsValid(prop2) then
            overlapEntities[#overlapEntities + 1] = prop2
        end

        for i = 1, #committed do
            overlapEntities[#overlapEntities + 1] = committed[i]
        end

        applyOverlapNoCollides(overlapEntities, created, nocollidePairs, task)
    end

    if not IsValid(ply) then return end

    undo.Create("Magic Align")
        undo.SetPlayer(ply)
        undo.AddFunction(restoreCommitStep, undoProps, created, ply, task.sessionSnapshot)
    undo.Finish()

    return true
end

hook.Add("Think", "MagicAlignCommitQueue", function()
    local now = RealTime()
    for ply, pending in pairs(PENDING_COMMITS) do
        if not IsValid(ply) then
            PENDING_COMMITS[ply] = nil
        elseif now > (pending.expiresAt or 0) then
            rejectPendingCommit(ply, pending, M.COMMIT_RESULT_TIMEOUT)
        end
    end

    local task = table.remove(COMMIT_QUEUE, 1)
    if not task then return end

    task.deadline = SysTime() + M.GetCommitBudgetSeconds()

    local ok, result = coroutine.resume(task.co)
    if not ok then
        ErrorNoHalt(("[Magic Align] commit failed: %s\n"):format(tostring(result)))
        sendCommitResult(task.ply, task.id, false, M.COMMIT_RESULT_FAILED)
        releaseCommitLock(task)
        return
    end

    if coroutine.status(task.co) == "dead" then
        local accepted = result == true
        sendCommitResult(
            task.ply,
            task.id,
            accepted,
            accepted and M.COMMIT_RESULT_OK or M.COMMIT_RESULT_INVALID
        )
        releaseCommitLock(task)
        return
    end

    COMMIT_QUEUE[#COMMIT_QUEUE + 1] = task
end)

net.Receive(M.NET_BOUNDS_REQUEST, function(_, ply)
    if not IsValid(ply) then return end

    local ent = net.ReadEntity()
    local sessionId = net.ReadUInt(32)
    if not canUse(ply, ent) then return end

    local byPlayer = REQUEST_STATE[ply]
    if not byPlayer then
        byPlayer = {}
        REQUEST_STATE[ply] = byPlayer
    end

    local now = RealTime()
    local idx = ent:EntIndex()
    if now < (byPlayer[idx] or 0) then return end
    byPlayer[idx] = now + M.AABB_REQUEST_COOLDOWN

    local mins, maxs = M.GetLocalBounds(ent)

    net.Start(M.NET_BOUNDS_REPLY)
        net.WriteEntity(ent)
        net.WriteUInt(sessionId, 32)
        net.WriteBool(hasFiniteVectorFields(mins) and hasFiniteVectorFields(maxs))
        if hasFiniteVectorFields(mins) and hasFiniteVectorFields(maxs) then
            net.WritePreciseVector(mins)
            net.WritePreciseVector(maxs)
        end
    net.Send(ply)
end)

net.Receive(M.NET_VIEW_ANGLES, function(_, ply)
    if not game.SinglePlayer() or not IsValid(ply) then return end

    local ang = net.ReadPreciseAngle()
    if not hasFiniteAngleFields(ang) then return end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" then return end

    local tool = ply:GetTool()
    if not tool or tool.Mode ~= "magic_align" then return end

    local eyeAng = asGModAngle(ang)
    if eyeAng then
        ply:SetEyeAngles(eyeAng)
    end
end)

net.Receive(M.NET, function(_, ply)
    if not IsValid(ply) then return end

    local commitId = net.ReadUInt(32)
    if COMMIT_LOCK[ply] then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_BUSY)
        return
    end

    local prop1 = net.ReadEntity()
    local prop2 = net.ReadEntity()
    local toolEnt = net.ReadEntity()
    local pos = net.ReadPreciseVector()
    local ang = net.ReadPreciseAngle()
    local sourcePoints = readPoints()
    local targetPoints = readPoints()
    local linkedCount = net.ReadUInt(8)
    local weld = net.ReadBool()
    local nocollide = net.ReadBool()
    local parent = net.ReadBool()
    local mode = net.ReadUInt(2)
    local absoluteLinked = net.ReadBool()
    local entityMirrorAxis = net.ReadUInt(2)
    local sessionSnapshot = M.ReadSessionSnapshot and M.ReadSessionSnapshot() or nil

    local pending = PENDING_COMMITS[ply]
    if pending and RealTime() < (pending.expiresAt or 0) then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_BUSY)
        return
    end
    if pending then
        PENDING_COMMITS[ply] = nil
    end

    if linkedCount > M.GetMaxLinkedProps() then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_INVALID)
        return
    end
    if entityMirrorAxis < M.ENTITY_MIRROR_NONE or entityMirrorAxis > M.ENTITY_MIRROR_Z then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_INVALID)
        return
    end
    if not hasFiniteVectorFields(pos) or not hasFiniteAngleFields(ang) then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_INVALID)
        return
    end
    if not finitePoints(sourcePoints) or not finitePoints(targetPoints) then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_INVALID)
        return
    end
    if not IsValid(toolEnt) or toolEnt ~= ply:GetActiveWeapon() or toolEnt:GetClass() ~= "gmod_tool" then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_INVALID)
        return
    end

    PENDING_COMMITS[ply] = {
        id = commitId,
        expiresAt = RealTime() + COMMIT_UPLOAD_TIMEOUT,
        totalLinked = linkedCount,
        totalParts = math.ceil(linkedCount / M.GetCommitLinkedPartSize()),
        receivedParts = {},
        receivedCount = 0,
        linkedProps = {},
        linkedTargets = absoluteLinked and {} or nil,
        absoluteLinked = absoluteLinked == true,
        task = {
            id = commitId,
            ply = ply,
            prop1 = prop1,
            prop2 = prop2,
            pos = pos,
            ang = ang,
            sourcePoints = sourcePoints,
            targetPoints = targetPoints,
            linkedProps = {},
            linkedTargets = absoluteLinked and {} or nil,
            weld = weld,
            nocollide = nocollide,
            parent = parent,
            mode = mode,
            entityMirrorAxis = entityMirrorAxis,
            sessionSnapshot = sessionSnapshot or {
                schema = M.SESSION_SNAPSHOT_SCHEMA,
                lastActionType = "align",
                isMirrorAction = false,
                lastAction = {
                    type = "align",
                    isMirror = false,
                    mode = mode
                }
            }
        }
    }
end)

net.Receive(M.NET_COMMIT_LINKED_PART, function(_, ply)
    if not IsValid(ply) then return end

    local commitId = net.ReadUInt(32)
    local partIndex = net.ReadUInt(8)
    local totalParts = net.ReadUInt(8)
    local count = net.ReadUInt(8)
    local pending = PENDING_COMMITS[ply]
    if not pending or pending.id ~= commitId then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_INVALID)
        return
    end
    if RealTime() > (pending.expiresAt or 0) then
        rejectPendingCommit(ply, pending, M.COMMIT_RESULT_TIMEOUT)
        return
    end
    if pending.receivedParts[partIndex] or totalParts ~= pending.totalParts then
        rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
        return
    end
    if partIndex < 1 or partIndex > pending.totalParts then
        rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
        return
    end
    local partSize = M.GetCommitLinkedPartSize()
    if count < 1 or count > partSize then
        rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
        return
    end

    local firstIndex = (partIndex - 1) * partSize + 1
    if firstIndex + count - 1 > pending.totalLinked then
        rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
        return
    end

    local entities = {}
    local targets = pending.absoluteLinked and {} or nil
    for i = 1, count do
        entities[i] = net.ReadEntity()
        if pending.absoluteLinked then
            local pos = net.ReadPreciseVector()
            local ang = net.ReadPreciseAngle()
            if not hasFiniteVectorFields(pos) or not hasFiniteAngleFields(ang) then
                rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
                return
            end
            targets[i] = {
                pos = pos,
                ang = ang
            }
        end
    end

    for i = 1, #entities do
        local index = firstIndex + i - 1
        pending.linkedProps[index] = entities[i]
        if pending.absoluteLinked then
            pending.linkedTargets[index] = targets[i]
        end
    end

    pending.receivedParts[partIndex] = true
    pending.receivedCount = pending.receivedCount + count
    pending.expiresAt = RealTime() + COMMIT_UPLOAD_TIMEOUT
end)

net.Receive(M.NET_COMMIT_FINISH, function(_, ply)
    if not IsValid(ply) then return end

    local commitId = net.ReadUInt(32)
    if COMMIT_LOCK[ply] then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_BUSY)
        return
    end

    local pending = PENDING_COMMITS[ply]
    if not pending or pending.id ~= commitId then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_INVALID)
        return
    end
    if RealTime() > (pending.expiresAt or 0) then
        rejectPendingCommit(ply, pending, M.COMMIT_RESULT_TIMEOUT)
        return
    end
    if pending.receivedCount ~= pending.totalLinked then
        rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
        return
    end

    local linkedProps = {}
    local linkedTargets = pending.absoluteLinked and {} or nil
    for i = 1, pending.totalLinked do
        local ent = pending.linkedProps[i]
        if not IsValid(ent) then
            rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
            return
        end
        linkedProps[i] = ent

        if pending.absoluteLinked then
            local target = pending.linkedTargets and pending.linkedTargets[i] or nil
            if not istable(target) or not hasFiniteVectorFields(target.pos) or not hasFiniteAngleFields(target.ang) then
                rejectPendingCommit(ply, pending, M.COMMIT_RESULT_INVALID)
                return
            end
            linkedTargets[i] = target
        end
    end

    pending.task.linkedProps = linkedProps
    pending.task.linkedTargets = linkedTargets
    PENDING_COMMITS[ply] = nil
    if not queueCommit(pending.task) then
        rejectCommit(ply, commitId, M.COMMIT_RESULT_BUSY)
    end
end)
