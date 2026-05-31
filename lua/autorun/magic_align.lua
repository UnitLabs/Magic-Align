if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("magic_align/precision.lua")
    AddCSLuaFile("magic_align/rounding.lua")
    AddCSLuaFile("magic_align/anchor.lua")
    AddCSLuaFile("magic_align/mirror.lua")
    AddCSLuaFile("magic_align/entity_mirror.lua")
    AddCSLuaFile("magic_align/compat/primitive_sh.lua")
    AddCSLuaFile("magic_align/compat/primitive_cl.lua")
    AddCSLuaFile("magic_align/client/profiler.lua")
end

MAGIC_ALIGN = MAGIC_ALIGN or {}

local M = MAGIC_ALIGN

include("magic_align/precision.lua")
include("magic_align/rounding.lua")
include("magic_align/anchor.lua")
include("magic_align/compat/primitive_sh.lua")

local VectorP = M.VectorP
local AngleP = M.AngleP
local isvector = M.IsVectorLike
local isangle = M.IsAngleLike

if SERVER then
    include("magic_align/compat/primitive_sv.lua")
else
    include("magic_align/compat/primitive_cl.lua")
end

M.NET = "magic_align_commit"
M.NET_COMMIT_LINKED_PART = "magic_align_commit_linked_part"
M.NET_COMMIT_FINISH = "magic_align_commit_finish"
M.NET_COMMIT_RESULT = "magic_align_commit_result"
M.NET_UNDO_RESTORE = "magic_align_undo_restore"
M.NET_BOUNDS_REQUEST = "magic_align_bounds_request"
M.NET_BOUNDS_REPLY = "magic_align_bounds_reply"
M.NET_CLIENT_ACTION = "magic_align_client_action"
M.NET_VIEW_ANGLES = "magic_align_view_angles"
M.AABB_REQUEST_COOLDOWN = 0.25
M.MAX_POINTS = 3
M.MAX_COMMIT_PROPS = 255
M.DEFAULT_MAX_LINKED_PROPS = 32
M.DEFAULT_COMMIT_LINKED_PART_SIZE = 62
M.COMMIT_LINKED_PART_SIZE = M.DEFAULT_COMMIT_LINKED_PART_SIZE
M.DEFAULT_COMMIT_BUDGET_MS = 0.2
M.LINE_PLANE_EPSILON = M.PICKING_EPSILON
M.ZERO = VectorP(0, 0, 0)
M.ZERO_ANGLE = AngleP(0, 0, 0)
M.COMMIT_MOVE = 0
M.COMMIT_COPY = 1
M.COMMIT_COPY_MOVE = 2
M.CLIENT_ACTION_RIGHTCLICK = 0
M.CLIENT_ACTION_RESET = 1
M.CLIENT_ACTION_LEFTCLICK = 2
M.COMMIT_RESULT_OK = 0
M.COMMIT_RESULT_BUSY = 1
M.COMMIT_RESULT_INVALID = 2
M.COMMIT_RESULT_TIMEOUT = 3
M.COMMIT_RESULT_FAILED = 4
M.SESSION_SNAPSHOT_SCHEMA = 2
M.SESSION_SNAPSHOT_ACTION_UNKNOWN = 0
M.SESSION_SNAPSHOT_ACTION_ALIGN = 1
M.SESSION_SNAPSHOT_ACTION_MIRROR = 2

local MAX_LINKED_PROPS_CVAR = "magic_align_max_linked_props"
local COMMIT_LINKED_PART_SIZE_CVAR = "magic_align_commit_linked_part_size"
local COMMIT_BUDGET_CVAR = "magic_align_commit_budget_ms"

if SERVER then
    CreateConVar(
        MAX_LINKED_PROPS_CVAR,
        tostring(M.DEFAULT_MAX_LINKED_PROPS),
        FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
        "Maximum number of linked props per Magic Align commit.",
        0,
        M.MAX_COMMIT_PROPS
    )
    CreateConVar(
        COMMIT_LINKED_PART_SIZE_CVAR,
        tostring(M.DEFAULT_COMMIT_LINKED_PART_SIZE),
        FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
        "Maximum number of linked props per Magic Align commit upload part.",
        1,
        M.MAX_COMMIT_PROPS
    )
    CreateConVar(
        COMMIT_BUDGET_CVAR,
        tostring(M.DEFAULT_COMMIT_BUDGET_MS),
        FCVAR_ARCHIVE + FCVAR_NOTIFY,
        "Maximum CPU time in milliseconds per Magic Align commit slice.",
        0.01
    )
end

local function readConVarNumber(name, fallback, integer)
    local cvar = GetConVar(name)
    if not cvar then return fallback end

    local value = integer and cvar:GetInt() or cvar:GetFloat()
    value = tonumber(value)

    return value or fallback
end

function M.GetMaxLinkedProps()
    local limit = readConVarNumber(MAX_LINKED_PROPS_CVAR, M.DEFAULT_MAX_LINKED_PROPS, true)
    return math.Clamp(math.floor(limit or 0), 0, M.MAX_COMMIT_PROPS)
end

function M.GetCommitLinkedPartSize()
    local size = readConVarNumber(COMMIT_LINKED_PART_SIZE_CVAR, M.DEFAULT_COMMIT_LINKED_PART_SIZE, true)
    return math.Clamp(math.floor(size or M.DEFAULT_COMMIT_LINKED_PART_SIZE), 1, M.MAX_COMMIT_PROPS)
end

function M.GetCommitBudgetMs()
    local budget = readConVarNumber(COMMIT_BUDGET_CVAR, M.DEFAULT_COMMIT_BUDGET_MS, false)
    return math.max(tonumber(budget) or M.DEFAULT_COMMIT_BUDGET_MS, 0.1)
end

function M.GetCommitBudgetSeconds()
    return M.GetCommitBudgetMs() * 0.001
end
-- "Referenz" meint hier genau die vier Tabs im Tool.
-- Jeder Tab beschreibt einen eigenen lokalen Referenzraum:
-- prop1 = lokaler Raum von Prop 1
-- prop2 = lokaler Raum von Prop 2
-- points = lokaler Raum der gewaehlten Point-Axis
-- world = Weltachsen ohne lokale Rotation
M.SPACES = { "prop1", "prop2", "points", "world" }
M.UI_SPACES = { "prop1", "prop2", "points", "world", "mirror" }
M.MIRROR_SPACE = "mirror"
M.TRANSFORM_MODE_MIRROR = "mirror"
M.MIRROR_POINT = "point"
M.MIRROR_AXIS = "axis"
M.MIRROR_PLANE = "plane"
M.MIRROR_EPSILON_SQR = M.COMPUTE_VECTOR_EPSILON_SQR
M.WORLD_TARGET = M.WORLD_TARGET or setmetatable({
    __magic_align_world = true
}, {
    __tostring = function()
        return "magic_align_world"
    end
})

function M.IsWorldTarget(ent)
    if ent == M.WORLD_TARGET then
        return true
    end

    if IsValid(ent) and ent.IsWorld then
        return ent:IsWorld()
    end

    local world = game and game.GetWorld and game.GetWorld() or nil
    return world ~= nil and ent == world
end

function M.HasTargetEntity(ent)
    return M.IsWorldTarget(ent) or IsValid(ent)
end

function M.NextSessionId()
    M._nextSessionId = (tonumber(M._nextSessionId) or 0) + 1
    return M._nextSessionId
end

function M.NewSession()
    return {
        sessionId = M.NextSessionId(),
        state = "source_prop",
        prop1 = nil,
        prop2 = nil,
        activeSpace = "prop1",
        selectedWorldPointIndex = nil,
        linked = {},
        anchorSelection = {},
        source = {},
        target = {},
        mirror = {
            enabled = false,
            points = {},
            classification = nil
        },
        bounds = {},
        preview = nil,
        pending = nil,
        compatGhosts = { linked = {} },
        hover = nil,
        press = nil,
        ghost = nil,
        linkedGhosts = {},
        attackDown = false,
        useDown = false
    }
end

function M.PointReferenceFromEntity(ent)
    if M.IsWorldTarget(ent) then
        return { kind = "world" }
    end

    if IsValid(ent) then
        return { kind = "entity", ent = ent, entIndex = ent:EntIndex() }
    end
end

function M.CopyPointReference(ref)
    if not istable(ref) then return end

    if ref.kind == "world" then
        return { kind = "world" }
    end

    if ref.kind == "entity" then
        local entIndex = tonumber(ref.entIndex)
        if IsValid(ref.ent) then
            entIndex = ref.ent:EntIndex()
        end

        return { kind = "entity", ent = ref.ent, entIndex = entIndex }
    end
end

function M.SetPointReference(point, ent)
    if not isvector(point) then return point end

    local ref = M.PointReferenceFromEntity(ent)
    point.reference = M.CopyPointReference(ref)
    point.world = ref and ref.kind == "world" or nil

    return point
end

function M.CopyPoints(points)
    points = istable(points) and points or {}

    local out = {}

    for i = 1, #points do
        local p = points[i]
        if isvector(p) then
            out[i] = VectorP(p.x, p.y, p.z)

            if isvector(p.normal) then
                out[i].normal = VectorP(p.normal.x, p.normal.y, p.normal.z)
            end

            if p.world == true then
                out[i].world = true
            end

            local ref = M.CopyPointReference(p.reference)
            if ref then
                out[i].reference = ref
            end
        end
    end

    return out
end

local function hasUsableModel(ent)
    if not IsValid(ent) or not isfunction(ent.GetModel) then return false end

    local model = ent:GetModel()
    return isstring(model) and model ~= ""
end

local function isStoredScriptedEntity(class)
    if not isstring(class) or class == "" then return false end
    if not scripted_ents or not isfunction(scripted_ents.GetStored) then return false end

    local stored = scripted_ents.GetStored(class)
    return istable(stored) and stored.t ~= nil
end

function M.IsProp(ent)
    if not IsValid(ent) then return false end
    if ent:IsWorld() or ent:IsPlayer() or ent:IsNPC() or ent:IsWeapon() then return false end
    if M.IsPrimitive and M.IsPrimitive(ent) then return true end

    local class = ent:GetClass()
    if string.StartWith(class, "prop_") then return true end

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then return true end

    return hasUsableModel(ent) and isStoredScriptedEntity(class)
end

function M.GetActiveMagicAlignTool(ply)
    if not IsValid(ply) then return end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" then return end

    local tool = ply:GetTool()
    if not tool or tool.Mode ~= "magic_align" then return end

    return tool, weapon
end

local function sanitizeBounds(mins, maxs)
    if not isvector(mins) or not isvector(maxs) then return end

    mins = VectorP(mins.x, mins.y, mins.z)
    maxs = VectorP(maxs.x, maxs.y, maxs.z)

    local size = M.SubtractVectorsPrecise(maxs, mins)
    if not isvector(size) then return end
    if size.x < -M.VALIDATION_EPSILON or size.y < -M.VALIDATION_EPSILON or size.z < -M.VALIDATION_EPSILON then return end

    return mins, maxs
end

local function expandBounds(mins, maxs, point)
    if not isvector(point) then
        return mins, maxs
    end

    if not isvector(mins) or not isvector(maxs) then
        return VectorP(point.x, point.y, point.z), VectorP(point.x, point.y, point.z)
    end

    mins.x = math.min(mins.x, point.x)
    mins.y = math.min(mins.y, point.y)
    mins.z = math.min(mins.z, point.z)
    maxs.x = math.max(maxs.x, point.x)
    maxs.y = math.max(maxs.y, point.y)
    maxs.z = math.max(maxs.z, point.z)

    return mins, maxs
end

local function physAABBToLocalBounds(ent, phys)
    if not IsValid(ent) or not IsValid(phys) then return end
    if not phys.GetAABB or not phys.GetPos or not phys.GetAngles then return end

    local mins, maxs = sanitizeBounds(phys:GetAABB())
    if not mins or not maxs then return end

    local localMins, localMaxs
    local physPos = phys:GetPos()
    local physAng = phys:GetAngles()
    local entPos = ent:GetPos()
    local entAng = ent:GetAngles()
    if not isvector(physPos) or not isangle(physAng) or not isvector(entPos) or not isangle(entAng) then return end

    local corners = {
        VectorP(mins.x, mins.y, mins.z),
        VectorP(mins.x, mins.y, maxs.z),
        VectorP(mins.x, maxs.y, mins.z),
        VectorP(mins.x, maxs.y, maxs.z),
        VectorP(maxs.x, mins.y, mins.z),
        VectorP(maxs.x, mins.y, maxs.z),
        VectorP(maxs.x, maxs.y, mins.z),
        VectorP(maxs.x, maxs.y, maxs.z)
    }

    for i = 1, #corners do
        local worldPos = LocalToWorldPrecise(corners[i], AngleP(0, 0, 0), physPos, physAng)
        local localPos = isvector(worldPos) and WorldToLocalPrecise(worldPos, AngleP(0, 0, 0), entPos, entAng) or nil
        localMins, localMaxs = expandBounds(localMins, localMaxs, localPos)
    end

    return sanitizeBounds(localMins, localMaxs)
end

local SCALE_IDENTITY = VectorP(1, 1, 1)
local SCALE_ZERO = VectorP(0, 0, 0)

local function vectorApprox(a, b, eps)
    if not isvector(a) or not isvector(b) then return false end

    eps = eps or M.UI_COMPARE_EPSILON

    return math.abs(a.x - b.x) <= eps
        and math.abs(a.y - b.y) <= eps
        and math.abs(a.z - b.z) <= eps
end

local function parseScaleVector(value)
    local vec = value

    if isstring(value) then
        if value == "" then return end
        vec = VectorP(value)
    end

    if not isvector(vec) then return end

    return VectorP(vec.x, vec.y, vec.z)
end

function M.VectorApprox(a, b, eps)
    return vectorApprox(a, b, eps)
end

function M.ParseScaleVector(value)
    return parseScaleVector(value)
end

local function modifierScale(data, firstIndex)
    if not istable(data) then return end

    local x = tonumber(data[firstIndex])
    local y = tonumber(data[firstIndex + 1])
    local z = tonumber(data[firstIndex + 2])
    if not x or not y or not z then return end

    return VectorP(x, y, z)
end

local function findSizeHandler(ent)
    if not IsValid(ent) or not isfunction(ent.GetChildren) then return end

    local children = ent:GetChildren()
    for i = 1, #children do
        local child = children[i]
        if IsValid(child) and child:GetClass() == "sizehandler" then
            return child
        end
    end
end

function M.FindSizeHandler(ent)
    return findSizeHandler(ent)
end

function M.GetEntityModelScale(ent)
    return math.max(tonumber(IsValid(ent) and ent:GetModelScale() or 1) or 1, M.MODEL_SCALE_EPSILON)
end

function M.GetAdvResizerScales(ent)
    if not IsValid(ent) then return end

    local modifierData = istable(ent.EntityMods) and ent.EntityMods.advr or nil
    local physical = modifierScale(modifierData, 1)
    local visual = modifierScale(modifierData, 4)
    local handler = (physical and visual) and nil or findSizeHandler(ent)

    if not isvector(physical) then
        physical = IsValid(handler) and isfunction(handler.GetActualPhysicsScale)
            and parseScaleVector(handler:GetActualPhysicsScale())
            or nil
    end

    if not isvector(visual) then
        visual = IsValid(handler) and isfunction(handler.GetVisualScale)
            and parseScaleVector(handler:GetVisualScale())
            or nil
    end

    if not isvector(physical) or vectorApprox(physical, SCALE_ZERO) then
        physical = VectorP(1, 1, 1)
    end

    if not isvector(visual) or vectorApprox(visual, SCALE_ZERO) then
        visual = VectorP(1, 1, 1)
    end

    return physical, visual
end

function M.GetAdvResizerVisualScale(ent)
    local _, visual = M.GetAdvResizerScales(ent)
    if not isvector(visual) or vectorApprox(visual, SCALE_IDENTITY) then return end

    return visual
end

local function advResizerBoundsScale(ent)
    local physical, visual = M.GetAdvResizerScales(ent)
    if not isvector(physical) or not isvector(visual) then return end

    local ratio = VectorP(
        visual.x / math.max(physical.x, M.MODEL_SCALE_EPSILON),
        visual.y / math.max(physical.y, M.MODEL_SCALE_EPSILON),
        visual.z / math.max(physical.z, M.MODEL_SCALE_EPSILON)
    )

    if vectorApprox(ratio, SCALE_IDENTITY) then return end

    return ratio
end

function M.GetAdvResizerBoundsScale(ent)
    return advResizerBoundsScale(ent)
end

local function scaleBounds(mins, maxs, scale)
    if not isvector(mins) or not isvector(maxs) or not isvector(scale) then
        return mins, maxs
    end

    return sanitizeBounds(
        VectorP(mins.x * scale.x, mins.y * scale.y, mins.z * scale.z),
        VectorP(maxs.x * scale.x, maxs.y * scale.y, maxs.z * scale.z)
    )
end

function M.GetLocalBounds(ent)
    if not M.IsProp(ent) then return end

    local visualScale = M.GetAdvResizerBoundsScale(ent)

    local phys = ent:GetPhysicsObject()
    local mins, maxs = physAABBToLocalBounds(ent, phys)
    if mins and maxs then
        return scaleBounds(mins, maxs, visualScale)
    end

    if ent.GetCollisionBounds then
        mins, maxs = sanitizeBounds(ent:GetCollisionBounds())
        if mins and maxs then
            return scaleBounds(mins, maxs, visualScale)
        end
    end

    mins, maxs = sanitizeBounds(ent:OBBMins(), ent:OBBMaxs())
    if mins and maxs then
        return scaleBounds(mins, maxs, visualScale)
    end

    if ent.GetRenderBounds then
        mins, maxs = sanitizeBounds(ent:GetRenderBounds())
        if mins and maxs then
            return scaleBounds(mins, maxs, visualScale)
        end
    end
end

function M.RefreshState(session)
    local mirrorActive = M.IsMirrorMode and M.IsMirrorMode(session)

    if not IsValid(session.prop1) then
        session.state = "source_prop"
    elseif mirrorActive and not (M.ResolveMirrorState and M.ResolveMirrorState(
        session.mirror,
        M.GetMirrorStateCache and M.GetMirrorStateCache(session) or nil,
        { activeSpace = session.activeSpace }
    ).valid) then
        session.state = "mirror_points"
    elseif mirrorActive then
        session.state = "ready"
    elseif #session.source == 0 then
        session.state = "source_points"
    elseif not M.HasTargetEntity(session.prop2) then
        session.state = "target_prop"
    elseif #session.target == 0 then
        session.state = "target_points"
    else
        session.state = "ready"
    end
end

function M.ModeName(sourceCount, targetCount, hasTarget)
    if not hasTarget then
        return "local"
    end

    return ("%dx%d"):format(sourceCount, targetCount)
end

local copyVec = M.CopyVectorPrecise
local copyAng = M.CopyAnglePrecise

local function localToWorldSafe(localPos, localAng, originPos, originAng)
    return LocalToWorldPrecise(
        copyVec(localPos),
        copyAng(localAng),
        copyVec(originPos),
        copyAng(originAng)
    )
end

local function worldToLocalSafe(worldPos, worldAng, originPos, originAng)
    return WorldToLocalPrecise(
        copyVec(worldPos),
        copyAng(worldAng),
        copyVec(originPos),
        copyAng(originAng)
    )
end

function M.ResolvePointReference(point, fallbackEnt)
    if isvector(point) and istable(point.reference) then
        local ref = point.reference
        if ref.kind == "world" then
            return M.WORLD_TARGET
        elseif ref.kind == "entity" and IsValid(ref.ent) then
            return ref.ent
        elseif ref.kind == "entity" then
            return nil
        end
    end

    if isvector(point) and point.world == true then
        return M.WORLD_TARGET
    end

    return fallbackEnt
end

local function pointCacheFrame()
    return isfunction(FrameNumber) and FrameNumber() or nil
end

local function pointCacheSetVec(out, value)
    if not isvector(value) then return end

    if not isvector(out) then
        return VectorP(value.x, value.y, value.z)
    end

    out.x, out.y, out.z = value.x, value.y, value.z
    return out
end

local function pointCacheSetVecComponents(out, x, y, z)
    if not isvector(out) then
        return VectorP(x, y, z)
    end

    out.x, out.y, out.z = x, y, z
    return out
end

local function pointCacheEntPose(entry, prefix, ent)
    if M.IsWorldTarget(ent) then
        local changed = entry[prefix .. "Ent"] ~= M.WORLD_TARGET
            or entry[prefix .. "Valid"] ~= true
            or entry[prefix .. "World"] ~= true

        entry[prefix .. "Ent"] = M.WORLD_TARGET
        entry[prefix .. "Valid"] = true
        entry[prefix .. "World"] = true
        entry[prefix .. "PX"], entry[prefix .. "PY"], entry[prefix .. "PZ"] = 0, 0, 0
        entry[prefix .. "AP"], entry[prefix .. "AY"], entry[prefix .. "AR"] = 0, 0, 0
        return changed
    end

    if not IsValid(ent) then
        local changed = entry[prefix .. "Ent"] ~= ent
            or entry[prefix .. "Valid"] ~= false
            or entry[prefix .. "World"] ~= nil

        entry[prefix .. "Ent"] = ent
        entry[prefix .. "Valid"] = false
        entry[prefix .. "World"] = nil
        entry[prefix .. "PX"], entry[prefix .. "PY"], entry[prefix .. "PZ"] = nil, nil, nil
        entry[prefix .. "AP"], entry[prefix .. "AY"], entry[prefix .. "AR"] = nil, nil, nil
        return changed
    end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local changed = entry[prefix .. "Ent"] ~= ent
        or entry[prefix .. "Valid"] ~= true
        or entry[prefix .. "World"] ~= nil
        or entry[prefix .. "PX"] ~= pos.x
        or entry[prefix .. "PY"] ~= pos.y
        or entry[prefix .. "PZ"] ~= pos.z
        or entry[prefix .. "AP"] ~= ang.p
        or entry[prefix .. "AY"] ~= ang.y
        or entry[prefix .. "AR"] ~= ang.r

    entry[prefix .. "Ent"] = ent
    entry[prefix .. "Valid"] = true
    entry[prefix .. "World"] = nil
    entry[prefix .. "PX"], entry[prefix .. "PY"], entry[prefix .. "PZ"] = pos.x, pos.y, pos.z
    entry[prefix .. "AP"], entry[prefix .. "AY"], entry[prefix .. "AR"] = ang.p, ang.y, ang.r
    return changed
end

local function pointReferenceSignature(entry, point, fallbackEnt)
    local ref = isvector(point) and point.reference or nil
    local refKind = istable(ref) and ref.kind or nil
    local refEnt = istable(ref) and ref.ent or nil
    local refEntIndex = istable(ref) and ref.entIndex or nil
    local world = isvector(point) and point.world == true or nil
    local ent = M.ResolvePointReference(point, fallbackEnt)
    local changed = entry.point ~= point
        or entry.fallbackEnt ~= fallbackEnt
        or entry.refKind ~= refKind
        or entry.refEnt ~= refEnt
        or entry.refEntIndex ~= refEntIndex
        or entry.pointWorld ~= world
        or entry.resolvedEnt ~= ent

    entry.point = point
    entry.fallbackEnt = fallbackEnt
    entry.refKind = refKind
    entry.refEnt = refEnt
    entry.refEntIndex = refEntIndex
    entry.pointWorld = world
    entry.resolvedEnt = ent

    if pointCacheEntPose(entry, "ref", ent) then
        changed = true
    end

    return ent, changed
end

local function pointValueSignature(entry, point, includeNormal)
    local changed = entry.pointX ~= point.x or entry.pointY ~= point.y or entry.pointZ ~= point.z
    entry.pointX, entry.pointY, entry.pointZ = point.x, point.y, point.z

    if includeNormal then
        local normal = point.normal
        if isvector(normal) then
            if entry.normalX ~= normal.x or entry.normalY ~= normal.y or entry.normalZ ~= normal.z then
                changed = true
            end
            entry.normalX, entry.normalY, entry.normalZ = normal.x, normal.y, normal.z
        elseif entry.normalX ~= nil then
            changed = true
            entry.normalX, entry.normalY, entry.normalZ = nil, nil, nil
        end
    end

    return changed
end

local function pointCacheEntries(cache, name)
    if not istable(cache) then return end

    local entries = cache[name]
    if not istable(entries) then
        entries = {}
        cache[name] = entries
    end

    return entries
end

local function pointCacheEntry(cache, name, point, fallbackEnt)
    local entries = pointCacheEntries(cache, name)
    if not entries then return end

    local count = tonumber(entries.count) or 0
    if count > 64 then
        entries.count = 0
        count = 0
    end

    for i = 1, count do
        local entry = entries[i]
        if entry and entry.point == point and entry.fallbackEnt == fallbackEnt then
            return entry
        end
    end

    count = count + 1
    entries.count = count
    local entry = entries[count]
    if not istable(entry) then
        entry = {}
        entries[count] = entry
    end

    return entry
end

function M.ClearPointWorldCache(cache)
    if not istable(cache) then return end

    for _, name in ipairs({ "positions", "normals" }) do
        local entries = cache[name]
        if istable(entries) then
            entries.count = 0
        end
    end
end

function M.ResolvePointWorldPositionInto(out, point, fallbackEnt)
    if not isvector(point) then return end

    local ent = M.ResolvePointReference(point, fallbackEnt)
    if M.IsWorldTarget(ent) then
        return pointCacheSetVec(out, point)
    end

    if IsValid(ent) then
        local pos = ent:GetPos()
        local ang = ent:GetAngles()
        local x, y, z = point.x, point.y, point.z
        local pitch, yaw, roll = ang.p, ang.y, ang.r
        local sp, sy, sr = math.sin(pitch * math.pi / 180), math.sin(yaw * math.pi / 180), math.sin(roll * math.pi / 180)
        local cp, cy, cr = math.cos(pitch * math.pi / 180), math.cos(yaw * math.pi / 180), math.cos(roll * math.pi / 180)

        return pointCacheSetVecComponents(
            out,
            pos.x + (cp * cy) * x + (sp * sr * cy - cr * sy) * y + (sp * cr * cy + sr * sy) * z,
            pos.y + (cp * sy) * x + (sp * sr * sy + cr * cy) * y + (sp * cr * sy - sr * cy) * z,
            pos.z + (-sp) * x + (sr * cp) * y + (cr * cp) * z
        )
    end
end

function M.ResolvePointWorldPositionCached(cache, point, fallbackEnt, options)
    if not isvector(point) then return end
    if not istable(cache) then
        local world = M.ResolvePointWorldPosition(point, fallbackEnt)
        return istable(options) and options.copy and isvector(world) and copyVec(world) or world
    end

    options = istable(options) and options or {}
    local entry = pointCacheEntry(cache, "positions", point, fallbackEnt)
    if not entry then
        local world = M.ResolvePointWorldPosition(point, fallbackEnt)
        return options.copy and isvector(world) and copyVec(world) or world
    end

    local frame = pointCacheFrame()
    local revision = options.revision
    local ent, changed = pointReferenceSignature(entry, point, fallbackEnt)
    if pointValueSignature(entry, point, false) then changed = true end
    if entry.revision ~= revision then entry.revision = revision; changed = true end
    if options.frameOnly and entry.frame ~= frame then changed = true end

    if changed or entry.valid == nil then
        local out = entry.world
        if M.IsWorldTarget(ent) then
            out = pointCacheSetVec(out, point)
        elseif IsValid(ent) then
            out = M.ResolvePointWorldPositionInto(out, point, ent)
        else
            out = nil
        end

        entry.world = out
        entry.valid = isvector(out)
        entry.frame = frame
    end

    local world = entry.valid and entry.world or nil
    if options.copy and isvector(world) then
        return copyVec(world)
    end

    return world
end

function M.IsPointReferenceValid(point, fallbackEnt, options)
    options = istable(options) and options or {}

    local ent = M.ResolvePointReference(point, fallbackEnt)
    if not ent then return false end

    local forbidden = options.forbiddenEnt
    if IsValid(forbidden) and ent == forbidden then
        return false
    end

    if M.IsWorldTarget(ent) then
        return options.allowWorld ~= false
    end

    if not IsValid(ent) then return false end
    if options.requireProp == true and M.IsProp and not M.IsProp(ent) then return false end

    return true
end

function M.ResolvePointWorldPosition(point, fallbackEnt)
    if not isvector(point) then return end

    local ent = M.ResolvePointReference(point, fallbackEnt)
    if M.IsWorldTarget(ent) then
        return copyVec(point)
    end

    if IsValid(ent) then
        return M.LocalToWorldPosPrecise(point, ent:GetPos(), ent:GetAngles())
    end
end

function M.ResolvePointWorldNormalCached(cache, point, fallbackEnt, worldPos, options)
    if not isvector(point) then return end
    if not istable(cache) then
        local normal = M.ResolvePointWorldNormal(point, fallbackEnt, worldPos)
        return istable(options) and options.copy and isvector(normal) and copyVec(normal) or normal
    end

    options = istable(options) and options or {}
    local entry = pointCacheEntry(cache, "normals", point, fallbackEnt)
    if not entry then
        local normal = M.ResolvePointWorldNormal(point, fallbackEnt, worldPos)
        return options.copy and isvector(normal) and copyVec(normal) or normal
    end

    local frame = pointCacheFrame()
    local revision = options.revision
    local _, changed = pointReferenceSignature(entry, point, fallbackEnt)
    if pointValueSignature(entry, point, true) then changed = true end
    if entry.revision ~= revision then entry.revision = revision; changed = true end
    if options.frameOnly and entry.frame ~= frame then changed = true end
    if isvector(worldPos) then
        if entry.worldX ~= worldPos.x or entry.worldY ~= worldPos.y or entry.worldZ ~= worldPos.z then
            changed = true
        end
        entry.worldX, entry.worldY, entry.worldZ = worldPos.x, worldPos.y, worldPos.z
    elseif entry.worldX ~= nil then
        changed = true
        entry.worldX, entry.worldY, entry.worldZ = nil, nil, nil
    end

    if changed or entry.valid == nil then
        local normal = M.ResolvePointWorldNormal(point, fallbackEnt, worldPos)
        entry.normal = isvector(normal) and pointCacheSetVec(entry.normal, normal) or nil
        entry.valid = isvector(entry.normal)
        entry.frame = frame
    end

    local normal = entry.valid and entry.normal or nil
    if options.copy and isvector(normal) then
        return copyVec(normal)
    end

    return normal
end

function M.ResolvePointWorldNormal(point, fallbackEnt, worldPos)
    if not isvector(point) then return end

    local normal = M.NormalizeVectorPrecise(point.normal, M.COMPUTE_VECTOR_EPSILON_SQR)
    if not normal then return end

    local ent = M.ResolvePointReference(point, fallbackEnt)
    if M.IsWorldTarget(ent) then
        return copyVec(normal)
    end

    if not IsValid(ent) then return end

    local basePos = ent:GetPos()
    local baseAng = ent:GetAngles()
    if not isvector(basePos) or not isangle(baseAng) then return end

    local origin = isvector(worldPos) and worldPos or M.LocalToWorldPosPrecise(point, basePos, baseAng)
    local tip = M.LocalToWorldPosPrecise(M.AddVectorsPrecise(point, normal), basePos, baseAng)
    if not isvector(origin) or not isvector(tip) then return end

    return M.NormalizeVectorPrecise(M.SubtractVectorsPrecise(tip, origin), M.COMPUTE_VECTOR_EPSILON_SQR)
end

function M.ResolvePointPositionInReference(point, fallbackEnt, referenceEnt)
    local worldPos = M.ResolvePointWorldPosition(point, fallbackEnt)
    if not isvector(worldPos) then return end

    if M.IsWorldTarget(referenceEnt) then
        return copyVec(worldPos)
    end

    if IsValid(referenceEnt) then
        return M.WorldToLocalPosPrecise(worldPos, referenceEnt:GetPos(), referenceEnt:GetAngles())
    end
end

function M.ResolvePointNormalInReference(point, fallbackEnt, referenceEnt, worldPos)
    worldPos = isvector(worldPos) and worldPos or M.ResolvePointWorldPosition(point, fallbackEnt)
    if not isvector(worldPos) then return end

    local worldNormal = M.ResolvePointWorldNormal(point, fallbackEnt, worldPos)
    if not isvector(worldNormal) then return end

    if M.IsWorldTarget(referenceEnt) then
        return copyVec(worldNormal)
    end

    if not IsValid(referenceEnt) then return end

    local basePos = referenceEnt:GetPos()
    local baseAng = referenceEnt:GetAngles()
    if not isvector(basePos) or not isangle(baseAng) then return end

    local localPos = M.WorldToLocalPosPrecise(worldPos, basePos, baseAng)
    local localTip = M.WorldToLocalPosPrecise(M.AddVectorsPrecise(worldPos, worldNormal), basePos, baseAng)
    if not isvector(localPos) or not isvector(localTip) then return end

    return M.NormalizeVectorPrecise(M.SubtractVectorsPrecise(localTip, localPos), M.COMPUTE_VECTOR_EPSILON_SQR)
end

function M.ResolvePointSetWorld(points, fallbackEnt, options)
    points = istable(points) and points or {}
    options = istable(options) and options or {}

    local out = {}
    local count = math.min(#points, tonumber(options.maxPoints) or #points)
    local pointCache = options.pointWorldCache or options.cache
    local cacheOptions = {
        copy = false,
        revision = options.revision,
        frameOnly = options.frameOnly
    }

    for i = 1, count do
        local point = points[i]
        if not M.IsPointReferenceValid(point, fallbackEnt, options) then
            return
        end

        local worldPos = pointCache
            and M.ResolvePointWorldPositionCached(pointCache, point, fallbackEnt, cacheOptions)
            or M.ResolvePointWorldPosition(point, fallbackEnt)
        if not isvector(worldPos) then return end

        local copy = VectorP(worldPos.x, worldPos.y, worldPos.z)
        local worldNormal = pointCache
            and M.ResolvePointWorldNormalCached(pointCache, point, fallbackEnt, worldPos, cacheOptions)
            or M.ResolvePointWorldNormal(point, fallbackEnt, worldPos)
        if isvector(worldNormal) then
            copy.normal = VectorP(worldNormal.x, worldNormal.y, worldNormal.z)
        end

        out[i] = copy
    end

    return out
end

include("magic_align/mirror.lua")
include("magic_align/entity_mirror.lua")

local function normalized(v)
    return M.NormalizeVectorPrecise(v, M.COMPUTE_VECTOR_EPSILON_SQR)
end

local function projected(v, axis)
    return M.ProjectVectorPrecise(v, axis, M.COMPUTE_VECTOR_EPSILON_SQR)
end

local function chooseUp(axis)
    return projected(VectorP(0, 0, 1), axis) or projected(VectorP(0, 1, 0), axis) or VectorP(0, 1, 0)
end

local function singlePointNormalContext(points)
    local point = istable(points) and points[1] or nil
    if not isvector(point) or not isvector(point.normal) then return end

    local normal = normalized(point.normal)
    if not normal then return end

    return {
        pos = point,
        primary = normal,
        secondary = nil,
        ang = M.AngleFromForwardUpPrecise(normal, chooseUp(normal))
    }
end

local function pointContext(points, anchorOptions)
    local count = #points
    if count < 1 then return end

    -- Die Point-Axis ist ein lokaler Referenzraum, der nur aus den markierten
    -- Punkten aufgebaut wird:
    -- origin    = Bezugspunkt des Punktsatzes
    -- primary   = Hauptachse P1 -> P2
    -- secondary = zweite Achse aus P3, orthogonal auf primary projiziert
    -- ang       = vollstaendige Winkelbasis dieses Referenzraums
    local originId, origin = M.ResolveAnchor(points, M.ANCHOR_CENTER_ID, { "mid12", "p1" }, anchorOptions)
    origin = origin or points[1]
    local primary = count >= 2 and normalized(M.SubtractVectorsPrecise(points[2], points[1])) or nil
    local secondary = count >= 3 and projected(M.SubtractVectorsPrecise(points[3], origin), primary) or nil
    local up = primary and (secondary or chooseUp(primary)) or nil

    return {
        anchorId = originId,
        pos = origin,
        primary = primary,
        secondary = secondary,
        ang = primary and M.AngleFromForwardUpPrecise(primary, up) or nil
    }
end

local function rotateToAxis(ang, localAxis, targetAxis)
    if not localAxis or not targetAxis then return ang end

    localAxis = normalized(localAxis)
    targetAxis = normalized(targetAxis)
    if not localAxis or not targetAxis then return ang end

    local current = normalized(localToWorldSafe(localAxis, nil, nil, ang))
    if not current then return ang end

    local dot = math.Clamp(M.DotVectorsPrecise(current, targetAxis), -1, 1)

    if dot > 1 - M.DIRECTION_DOT_EPSILON then
        return ang
    end

    ang = copyAng(ang)

    if dot < -1 + M.DIRECTION_DOT_EPSILON then
        local fallback = projected(M.AngleUpPrecise(ang), targetAxis) or projected(M.AngleRightPrecise(ang), targetAxis) or chooseUp(targetAxis)
        return M.RotateAngleAroundAxisPrecise(ang, fallback, 180)
    end

    local axis = normalized(M.CrossVectorsPrecise(current, targetAxis))
    if not axis then
        return ang
    end

    return M.RotateAngleAroundAxisPrecise(ang, axis, math.deg(math.acos(dot)))
end

local function signedAngle(axis, fromVec, toVec)
    fromVec = projected(fromVec, axis)
    toVec = projected(toVec, axis)
    if not fromVec or not toVec then return 0 end

    return math.deg(math.atan2(
        M.DotVectorsPrecise(axis, M.CrossVectorsPrecise(fromVec, toVec)),
        M.DotVectorsPrecise(fromVec, toVec)
    ))
end

function M.Solve(prop1, sourcePoints, prop2, targetPoints, sourceSelected, sourcePriority, targetSelected, targetPriority, sourceAnchorOptions, targetAnchorOptions, options)
    options = istable(options) and options or {}

    local sourceCount = #sourcePoints
    local targetIsWorld = M.IsWorldTarget(prop2)
    local hasTarget = (targetIsWorld or IsValid(prop2)) and #targetPoints > 0
    local resolvedTargetPoints = hasTarget and M.ResolvePointSetWorld(targetPoints, prop2, {
        allowWorld = true,
        requireProp = true,
        maxPoints = M.MAX_POINTS,
        pointWorldCache = options.pointWorldCache,
        revision = options.pointWorldRevision,
        frameOnly = options.pointWorldFrameOnly
    }) or nil

    if not IsValid(prop1) or sourceCount < 1 then return end
    if hasTarget and not resolvedTargetPoints then return end

    local anchorCache = options.anchorCache
    local sourceAnchorId, sourceAnchorLocal
    if anchorCache then
        sourceAnchorId, sourceAnchorLocal = M.ResolveAnchorCached(anchorCache, sourcePoints, sourceSelected, sourcePriority, sourceAnchorOptions, {
            revision = options.sourceAnchorRevision,
            copy = true
        })
    else
        sourceAnchorId, sourceAnchorLocal = M.ResolveAnchor(sourcePoints, sourceSelected, sourcePriority, sourceAnchorOptions)
    end
    if not isvector(sourceAnchorLocal) then return end

    local targetAnchorId, targetAnchorLocal
    if hasTarget then
        if anchorCache then
            targetAnchorId, targetAnchorLocal = M.ResolveAnchorCached(anchorCache, resolvedTargetPoints, targetSelected, targetPriority, targetAnchorOptions, {
                revision = options.targetAnchorRevision,
                copy = true
            })
        else
            targetAnchorId, targetAnchorLocal = M.ResolveAnchor(resolvedTargetPoints, targetSelected, targetPriority, targetAnchorOptions)
        end
        if not isvector(targetAnchorLocal) then return end
    end

    local sourceContext = pointContext(sourcePoints, sourceAnchorOptions) or { pos = sourceAnchorLocal, anchorId = sourceAnchorId }
    local targetContext = hasTarget and (pointContext(resolvedTargetPoints, targetAnchorOptions) or { pos = targetAnchorLocal, anchorId = targetAnchorId }) or nil
    local targetSinglePointContext = hasTarget and #resolvedTargetPoints == 1 and singlePointNormalContext(resolvedTargetPoints) or nil
    local targetBasePos = hasTarget and VectorP(0, 0, 0) or nil
    local targetBaseAng = hasTarget and AngleP(0, 0, 0) or nil

    if sourceCount >= 2 and not sourceContext.primary then return end
    if hasTarget and #resolvedTargetPoints >= 2 and (not targetContext or not targetContext.primary) then return end

    local solveSourceAnchorId, solveSourceAnchorLocal = sourceAnchorId, sourceAnchorLocal
    local solveTargetAnchorId, solveTargetAnchorLocal = targetAnchorId, targetAnchorLocal

    local ang = AngleP(prop1:GetAngles().p, prop1:GetAngles().y, prop1:GetAngles().r)
    local partial = false
    local pointsLocalAng
    local pointsWorldAng

    -- Solve baut zuerst die Grundpose von Prop 1 im Weltspace:
    -- 1. lokale Source-Infos aus Prop 1 lesen
    -- 2. falls vorhanden auf den Ziel-Referenzraum von Prop 2 ausrichten
    -- 3. den geloesten Anchor von Prop 1 auf den Ziel-Anchor im Weltspace setzen
    if not hasTarget then
        partial = sourceCount < 3
        pointsLocalAng = sourceContext.ang
    elseif sourceCount == 1 and #resolvedTargetPoints == 1 then
        partial = false
    elseif sourceCount >= 2 and #resolvedTargetPoints >= 2 then
        -- Hier passiert die eigentliche Rotation von Prop 1 auf den
        -- aufgeloesten Ziel-Welt-Raum:
        -- primary richtet die Hauptachse aus, secondary loest den verbleibenden Twist.
        local targetAxisWorld = localToWorldSafe(targetContext.primary, nil, nil, targetBaseAng)
        ang = rotateToAxis(ang, sourceContext.primary, targetAxisWorld)
        partial = true
        pointsLocalAng = sourceContext.ang

        local sourceHintWorld = sourceContext.secondary and localToWorldSafe(sourceContext.secondary, nil, nil, ang)
            or projected(M.AngleUpPrecise(ang), targetAxisWorld)
        local targetHintWorld = targetContext.secondary and localToWorldSafe(targetContext.secondary, nil, nil, targetBaseAng) or nil

        if sourceHintWorld and targetHintWorld then
            ang = M.RotateAngleAroundAxisPrecise(ang, targetAxisWorld, signedAngle(targetAxisWorld, sourceHintWorld, targetHintWorld))
            partial = sourceCount < 3 or #resolvedTargetPoints < 3
        end
    elseif sourceCount == 1 and #resolvedTargetPoints >= 2 then
        partial = true
        pointsWorldAng = targetContext.ang and select(2, localToWorldSafe(nil, targetContext.ang, nil, targetBaseAng)) or nil
    else
        partial = true
        pointsLocalAng = sourceContext.ang
    end

    if targetSinglePointContext and targetSinglePointContext.ang then
        pointsLocalAng = nil
        pointsWorldAng = copyAng(targetSinglePointContext.ang)
    end

    local targetAnchorWorld = hasTarget
        and localToWorldSafe(solveTargetAnchorLocal, nil, targetBasePos, targetBaseAng)
        or localToWorldSafe(solveSourceAnchorLocal, nil, prop1:GetPos(), prop1:GetAngles())
    local rotatedAnchor = localToWorldSafe(solveSourceAnchorLocal, nil, nil, ang)
    local pos = M.SubtractVectorsPrecise(targetAnchorWorld, rotatedAnchor)
    local axisAng = pointsWorldAng or ang
    if pointsLocalAng then
        local _, worldAng = localToWorldSafe(nil, pointsLocalAng, nil, ang)
        axisAng = worldAng or axisAng
    end

    return {
        mode = M.ModeName(sourceCount, hasTarget and #resolvedTargetPoints or #targetPoints, hasTarget),
        partial = partial,
        pos = pos,
        ang = ang,
        axisAng = axisAng,
        pointsLocalAng = pointsLocalAng,
        pointsWorldAng = pointsWorldAng,
        sourceAnchorId = solveSourceAnchorId,
        sourceAnchorLocal = solveSourceAnchorLocal,
        sourceContextLocal = sourceContext,
        targetAnchorId = solveTargetAnchorId,
        targetAnchorLocal = solveTargetAnchorLocal,
        targetAnchorWorld = targetAnchorWorld,
        targetContextWorld = targetContext,
        sourceCount = sourceCount,
        targetCount = hasTarget and #resolvedTargetPoints or #targetPoints,
        hasTarget = hasTarget
    }
end

local function lPI(viewVec, viewOri, norm, ori, ang)
    if not isvector(viewVec) or not isvector(viewOri) or not isvector(norm) or not isvector(ori) or not isangle(ang) then
        return nil, nil
    end

    -- Der DragContext ist eine virtuelle Ebene im Weltspace.
    -- `ori` + `ang` beschreiben ihren lokalen Raum, damit derselbe Schnittpunkt
    -- direkt auch als lokale Gizmo-/Referenz-Koordinate verfuegbar ist.
    local denominator = M.DotVectorsPrecise(norm, viewVec)
    if math.abs(denominator) <= M.LINE_PLANE_EPSILON then
        return nil, nil
    end

    local distance = (M.DotVectorsPrecise(norm, ori) - M.DotVectorsPrecise(norm, viewOri)) / denominator
    local worldPos = M.AddVectorsPrecise(viewOri, M.ScaleVectorPrecise(viewVec, distance))
    local localPos = worldToLocalSafe(worldPos, nil, ori, ang)

    return worldPos, localPos
end

local function worldToLocalPosInto(out, worldPos, originPos, originAng)
    if not isvector(worldPos) or not isvector(originPos) or not isangle(originAng) then return end

    local x = worldPos.x - originPos.x
    local y = worldPos.y - originPos.y
    local z = worldPos.z - originPos.z
    local pitch = originAng.p
    local yaw = originAng.y
    local roll = originAng.r
    local sp, sy, sr = math.sin(pitch * math.pi / 180), math.sin(yaw * math.pi / 180), math.sin(roll * math.pi / 180)
    local cp, cy, cr = math.cos(pitch * math.pi / 180), math.cos(yaw * math.pi / 180), math.cos(roll * math.pi / 180)

    local m11, m12, m13 = cp * cy, sp * sr * cy - cr * sy, sp * cr * cy + sr * sy
    local m21, m22, m23 = cp * sy, sp * sr * sy + cr * cy, sp * cr * sy - sr * cy
    local m31, m32, m33 = -sp, sr * cp, cr * cp

    return pointCacheSetVecComponents(
        out,
        m11 * x + m21 * y + m31 * z,
        m12 * x + m22 * y + m32 * z,
        m13 * x + m23 * y + m33 * z
    )
end

function M.LinePlaneIntersectionInto(outWorld, outLocal, viewVec, viewOri, norm, ori, ang)
    if not isvector(viewVec) or not isvector(viewOri) or not isvector(norm) or not isvector(ori) or not isangle(ang) then
        return nil, nil
    end

    local denominator = M.DotVectorsPrecise(norm, viewVec)
    if math.abs(denominator) <= M.LINE_PLANE_EPSILON then
        return nil, nil
    end

    local distance = (M.DotVectorsPrecise(norm, ori) - M.DotVectorsPrecise(norm, viewOri)) / denominator
    outWorld = pointCacheSetVecComponents(
        outWorld,
        viewOri.x + viewVec.x * distance,
        viewOri.y + viewVec.y * distance,
        viewOri.z + viewVec.z * distance
    )
    outLocal = worldToLocalPosInto(outLocal, outWorld, ori, ang)

    return outWorld, outLocal
end

function M.LinePlaneIntersection(viewVec, viewOri, norm, ori, ang)
    local worldPos, localPos = lPI(viewVec, viewOri, norm, ori, ang)

    if not isvector(worldPos) or not isvector(localPos) then
        return nil, nil
    end

    return worldPos, localPos
end

function M.LocalToLocal(localPos, localAng, fromOrigin, fromAng, toOrigin, toAng)
    -- Offizielle Zwiebelschicht-Umrechnung:
    -- erst aus dem lokalen "from"-Raum in den Weltspace,
    -- dann aus dem Weltspace wieder in den lokalen "to"-Raum.
    -- Wichtig: Beide Bezugssysteme muessen dabei im selben Parent-Raum
    -- beschrieben sein. In diesem Tool ist dieser Parent-Raum der Weltspace.
    local worldPos, worldAng = localToWorldSafe(localPos, localAng, fromOrigin, fromAng)
    return worldToLocalSafe(worldPos, worldAng, toOrigin, toAng)
end

local function rotateAngle(ang, basisAng, rot)
    -- Die lokale Tab-Rotation wird offiziell in den Referenzraum eingeklinkt:
    -- Welt -> Referenz (WorldToLocal), lokale Delta-Rotation davorlegen,
    -- dann wieder Referenz -> Welt (LocalToWorld).
    local _, localAng = worldToLocalSafe(nil, ang, nil, basisAng)
    local _, composedLocalAng = localToWorldSafe(nil, localAng, nil, rot)
    local _, worldAng = localToWorldSafe(nil, composedLocalAng, nil, basisAng)
    return worldAng
end

function M.RotateAroundAnchor(pos, ang, anchorLocal, basisAng, rot)
    local anchorWorld = localToWorldSafe(anchorLocal, nil, pos, ang)
    ang = rotateAngle(ang, basisAng, rot)

    pos = M.SubtractVectorsPrecise(anchorWorld, localToWorldSafe(anchorLocal, nil, nil, ang))

    return pos, ang
end

local function rotatedBasis(basisAng, rot)
    local _, worldAng = localToWorldSafe(nil, rot, nil, basisAng)
    return worldAng
end

function M.ComposePose(solve, offsets, prop2)
    local pos = copyVec(solve.pos)
    local ang = copyAng(solve.ang)
    local prop2Ang = M.IsWorldTarget(prop2) and AngleP(0, 0, 0) or (IsValid(prop2) and prop2:GetAngles() or nil)
    local spaceBasis = {}
    local referenceBasis = {}
    local function rotateStoredBases(rotationBasis, rotationDelta)
        for _, storedName in ipairs(M.SPACES) do
            if referenceBasis[storedName] then
                referenceBasis[storedName] = rotateAngle(referenceBasis[storedName], rotationBasis, rotationDelta)
            end

            if spaceBasis[storedName] then
                spaceBasis[storedName] = rotateAngle(spaceBasis[storedName], rotationBasis, rotationDelta)
            end
        end
    end

    for _, name in ipairs(M.SPACES) do
        local item = offsets and offsets[name]
        local basis = AngleP(0, 0, 0)

        if name == "prop1" then
            basis = copyAng(ang)
        elseif name == "prop2" then
            basis = copyAng(prop2Ang or ang)
        elseif name == "points" then
            if solve.pointsLocalAng then
                local _, worldAng = localToWorldSafe(nil, solve.pointsLocalAng, nil, ang)
                basis = worldAng or ang
            else
                basis = copyAng(solve.pointsWorldAng or ang)
            end
        end

        local moveBasis = copyAng(basis)

        if item then
            local anchorWorld = localToWorldSafe(solve.sourceAnchorLocal, nil, pos, ang)

            if item.pos then
                anchorWorld = localToWorldSafe(item.pos, nil, anchorWorld, basis)
            end

            if item.rot then
                -- Eine aeussere Zwiebelschicht dreht auch alle bereits
                -- existierenden inneren Referenzraeume/Gizmos im Weltspace mit.
                if item.rot.p ~= 0 or item.rot.y ~= 0 or item.rot.r ~= 0 then
                    rotateStoredBases(basis, item.rot)
                end

                moveBasis = rotatedBasis(basis, item.rot)
                ang = rotateAngle(ang, basis, item.rot)
            end

            pos = M.SubtractVectorsPrecise(anchorWorld, localToWorldSafe(solve.sourceAnchorLocal, nil, nil, ang))
        end

        -- Diese beiden Basen werden so gespeichert, wie sie nach allen bisher
        -- verarbeiteten aeusseren Schichten im Weltspace sichtbar waeren.
        -- "moveBasis" ist der eigentliche Gizmo-Raum dieses Tabs:
        -- Referenzraum plus die lokalen Rotations-Slider des Tabs.
        referenceBasis[name] = copyAng(basis)
        spaceBasis[name] = copyAng(moveBasis)
    end

    return pos, ang, spaceBasis, referenceBasis
end

local function snapshotEntityRef(ent)
    if M.IsWorldTarget(ent) then
        return { kind = "world" }
    end

    if IsValid(ent) then
        return {
            kind = "entity",
            ent = ent,
            entIndex = ent:EntIndex()
        }
    end
end

local function resolveSnapshotEntityRef(ref)
    if not istable(ref) then return end

    if ref.kind == "world" then
        return M.WORLD_TARGET
    end

    if ref.kind == "entity" and IsValid(ref.ent) then
        return ref.ent
    end
end

local function snapshotPoints(points)
    points = istable(points) and points or {}
    local out = {}

    for i = 1, #points do
        local point = points[i]
        if M.IsFiniteVector(point) then
            local copy = VectorP(point.x, point.y, point.z)
            if M.IsFiniteVector(point.normal) then
                copy.normal = VectorP(point.normal.x, point.normal.y, point.normal.z)
            end
            if point.world == true then
                copy.world = true
            end
            copy.reference = M.CopyPointReference(point.reference)
            out[#out + 1] = copy
        end
    end

    return out
end

local function restoreSnapshotPoint(point, fallbackEnt)
    if not M.IsFiniteVector(point) then return end

    local refEnt
    if istable(point.reference) then
        refEnt = resolveSnapshotEntityRef(point.reference)
        if not refEnt then return end
    elseif point.world == true then
        refEnt = M.WORLD_TARGET
    elseif fallbackEnt ~= nil then
        refEnt = resolveSnapshotEntityRef(snapshotEntityRef(fallbackEnt))
        if not refEnt then return end
    end

    local copy = VectorP(point.x, point.y, point.z)
    if M.IsFiniteVector(point.normal) then
        copy.normal = VectorP(point.normal.x, point.normal.y, point.normal.z)
    end

    if point.world == true or M.IsWorldTarget(refEnt) then
        copy.world = true
    end

    if istable(point.reference) and M.SetPointReference then
        M.SetPointReference(copy, refEnt)
    elseif point.world == true and M.SetPointReference then
        M.SetPointReference(copy, M.WORLD_TARGET)
    end

    return copy
end

local function restoreSnapshotPoints(points, fallbackEnt)
    points = istable(points) and points or {}
    local out = {}

    for i = 1, math.min(#points, M.MAX_POINTS) do
        local point = restoreSnapshotPoint(points[i], fallbackEnt)
        if point then
            out[#out + 1] = point
        end
    end

    return out
end

local function snapshotOffsets(offsets)
    if not istable(offsets) then return end

    local out = {}
    for i = 1, #(M.SPACES or {}) do
        local space = M.SPACES[i]
        local offset = offsets[space]
        if istable(offset) then
            out[space] = {
                pos = M.IsFiniteVector(offset.pos) and VectorP(offset.pos.x, offset.pos.y, offset.pos.z) or nil,
                rot = M.IsFiniteAngle(offset.rot) and AngleP(offset.rot.p, offset.rot.y, offset.rot.r) or nil
            }
        end
    end

    return out
end

local function copySnapshotOffsets(offsets)
    offsets = istable(offsets) and offsets or {}
    local out = {}

    for i = 1, #(M.SPACES or {}) do
        local space = M.SPACES[i]
        local offset = offsets[space]
        if istable(offset) then
            out[space] = {
                pos = M.IsFiniteVector(offset.pos) and VectorP(offset.pos.x, offset.pos.y, offset.pos.z) or nil,
                rot = M.IsFiniteAngle(offset.rot) and AngleP(offset.rot.p, offset.rot.y, offset.rot.r) or nil
            }
        end
    end

    return out
end

local function normalizeActionType(actionType, isMirror)
    actionType = string.lower(tostring(actionType or ""))
    if isMirror == true or actionType == "mirror" then
        return "mirror", true
    end
    if actionType == "align" or actionType == "commit" or actionType == "" then
        return "align", false
    end

    return actionType, false
end

local function snapshotAnchorOptions(options)
    return M.NormalizeAnchorOptions(options)
end

local function snapshotAnchorSide(side)
    side = istable(side) and side or {}
    return {
        selected = string.lower(tostring(side.selected or side.anchor or "")),
        priority = table.concat(M.ParsePriority(side.priority), ","),
        options = snapshotAnchorOptions(side.options)
    }
end

local function snapshotAnchors(anchors, selection)
    anchors = istable(anchors) and anchors or {}
    selection = istable(selection) and selection or {}

    return {
        from = snapshotAnchorSide(anchors.from or selection.from),
        to = snapshotAnchorSide(anchors.to or selection.to)
    }
end

local function validUiSpace(space)
    space = tostring(space or "")
    for i = 1, #(M.UI_SPACES or M.SPACES or {}) do
        if (M.UI_SPACES or M.SPACES)[i] == space then
            return space
        end
    end
end

local function validNonMirrorSpace(space)
    space = validUiSpace(space)
    if space and not (M.IsMirrorMode and M.IsMirrorMode(space)) and space ~= M.MIRROR_SPACE then
        return space
    end
end

function M.ResolveSnapshotRestoreSpace(snapshot, currentSpace)
    snapshot = istable(snapshot) and snapshot or {}
    local ui = istable(snapshot.ui) and snapshot.ui or {}

    if snapshot.isMirrorAction == true then
        return M.MIRROR_SPACE
    end

    local selected = validUiSpace(ui.selectedTab) or validUiSpace(snapshot.activeSpace)
    local lastNonMirror = validNonMirrorSpace(ui.lastNonMirrorTab)
        or validNonMirrorSpace(snapshot.lastNonMirrorTab)
        or validNonMirrorSpace(selected)

    if (M.IsMirrorMode and M.IsMirrorMode(currentSpace)) or selected == M.MIRROR_SPACE then
        return lastNonMirror or "points"
    end

    return selected or lastNonMirror or "points"
end

function M.CreateSessionSnapshot(session, options)
    if not istable(session) then return end

    options = istable(options) and options or {}
    local mirror = istable(session.mirror) and session.mirror or {}
    local mirrorPoints = snapshotPoints(mirror.points)
    local activeSpace = options.activeSpace or session.activeSpace
    local lastNonMirrorTab = validNonMirrorSpace(options.lastNonMirrorTab)
        or validNonMirrorSpace(session.lastNonMirrorSpace)
        or validNonMirrorSpace(session.lastNonMirrorTab)
        or validNonMirrorSpace(activeSpace)
    local actionType, isMirrorAction = normalizeActionType(
        options.actionType or options.lastActionType,
        options.isMirrorAction
    )
    local mirrorCache = M.ResolveMirrorState
        and M.ResolveMirrorState(mirror, M.GetMirrorStateCache and M.GetMirrorStateCache(session) or nil, {
            activeSpace = activeSpace
        })
        or nil

    local linked = {}
    for i = 1, #(session.linked or {}) do
        local ent = session.linked[i]
        if IsValid(ent) then
            linked[#linked + 1] = snapshotEntityRef(ent)
        end
    end

    return {
        schema = M.SESSION_SNAPSHOT_SCHEMA,
        lastActionType = actionType,
        isMirrorAction = isMirrorAction,
        lastAction = {
            type = actionType,
            isMirror = isMirrorAction,
            mode = options.mode
        },
        prop1 = snapshotEntityRef(session.prop1),
        prop2 = snapshotEntityRef(session.prop2),
        activeSpace = activeSpace,
        source = snapshotPoints(session.source),
        target = snapshotPoints(session.target),
        linked = linked,
        anchors = snapshotAnchors(options.anchors, session.anchorSelection),
        offsets = snapshotOffsets(options.offsets or session.offsets),
        selectedWorldPointIndex = tonumber(session.selectedWorldPointIndex),
        mirror = {
            enabled = mirror.enabled == true,
            activeTab = M.IsMirrorMode and M.IsMirrorMode(activeSpace) or activeSpace == M.MIRROR_SPACE,
            points = mirrorPoints,
            classification = mirrorCache and mirrorCache.label or nil,
            entityMirrorEnabled = options.entityMirrorEnabled == true
        },
        ui = {
            selectedTab = validUiSpace(activeSpace) or "prop1",
            lastNonMirrorTab = lastNonMirrorTab
        }
    }
end

local function actionId(actionType, isMirror)
    actionType = normalizeActionType(actionType, isMirror)
    if actionType == "mirror" then return M.SESSION_SNAPSHOT_ACTION_MIRROR end
    if actionType == "align" then return M.SESSION_SNAPSHOT_ACTION_ALIGN end
    return M.SESSION_SNAPSHOT_ACTION_UNKNOWN
end

local function actionName(id)
    id = tonumber(id) or M.SESSION_SNAPSHOT_ACTION_UNKNOWN
    if id == M.SESSION_SNAPSHOT_ACTION_MIRROR then return "mirror" end
    if id == M.SESSION_SNAPSHOT_ACTION_ALIGN then return "align" end
    return "unknown"
end

local function spaceId(space)
    space = validUiSpace(space)
    local spaces = M.UI_SPACES or M.SPACES or {}
    for i = 1, #spaces do
        if spaces[i] == space then
            return i
        end
    end

    return 0
end

local function spaceName(id)
    id = math.floor(tonumber(id) or 0)
    local spaces = M.UI_SPACES or M.SPACES or {}
    return spaces[id]
end

local function anchorId(anchor)
    anchor = string.lower(tostring(anchor or ""))
    for i = 1, #(M.ANCHORS or {}) do
        if M.ANCHORS[i].id == anchor then
            return i
        end
    end

    return 0
end

local function anchorName(id)
    id = math.floor(tonumber(id) or 0)
    return M.ANCHORS and M.ANCHORS[id] and M.ANCHORS[id].id or nil
end

local function writeEntityRef(ref)
    if istable(ref) and ref.kind == "world" then
        net.WriteUInt(2, 2)
    elseif istable(ref) and ref.kind == "entity" then
        net.WriteUInt(1, 2)
        net.WriteEntity(IsValid(ref.ent) and ref.ent or NULL)
    else
        net.WriteUInt(0, 2)
    end
end

local function readEntityRef()
    local kind = net.ReadUInt(2)

    if kind == 2 then
        return { kind = "world" }, false
    elseif kind == 1 then
        local ent = net.ReadEntity()
        if IsValid(ent) then
            return snapshotEntityRef(ent), false
        end

        return nil, true
    end

    return nil, false
end

local function writeSnapshotPoint(point)
    net.WritePreciseVector(M.IsFiniteVector(point) and point or M.ZERO)
    net.WriteBool(M.IsFiniteVector(point and point.normal))
    if M.IsFiniteVector(point and point.normal) then
        net.WritePreciseVector(point.normal)
    end
    net.WriteBool(point and point.world == true)
    writeEntityRef(point and point.reference)
end

local function readSnapshotPoint()
    local pos = net.ReadPreciseVector()
    local hasNormal = net.ReadBool()
    local normal = hasNormal and net.ReadPreciseVector() or nil
    local world = net.ReadBool()
    local ref, invalidRef = readEntityRef()

    if not M.IsFiniteVector(pos) or invalidRef then return end

    local point = VectorP(pos.x, pos.y, pos.z)
    if M.IsFiniteVector(normal) then
        point.normal = VectorP(normal.x, normal.y, normal.z)
    end
    if world == true then
        point.world = true
    end
    point.reference = ref

    return point
end

local function writeSnapshotPoints(points)
    points = istable(points) and points or {}
    local writable = {}

    for i = 1, #points do
        if M.IsFiniteVector(points[i]) then
            writable[#writable + 1] = points[i]
        end
        if #writable >= M.MAX_POINTS then break end
    end

    local count = #writable

    net.WriteUInt(count, 2)
    for i = 1, count do
        writeSnapshotPoint(writable[i])
    end
end

local function readSnapshotPoints()
    local count = net.ReadUInt(2)
    local points = {}

    for i = 1, count do
        local point = readSnapshotPoint()
        if point then
            points[#points + 1] = point
        end
    end

    return points
end

local function writeSnapshotOffsets(offsets)
    offsets = istable(offsets) and offsets or {}

    for i = 1, #(M.SPACES or {}) do
        local offset = offsets[M.SPACES[i]]
        local hasOffset = istable(offset)
            and M.IsFiniteVector(offset.pos)
            and M.IsFiniteAngle(offset.rot)
        net.WriteBool(hasOffset)
        if hasOffset then
            net.WritePreciseVector(offset.pos)
            net.WritePreciseAngle(offset.rot)
        end
    end
end

local function readSnapshotOffsets()
    local offsets = {}

    for i = 1, #(M.SPACES or {}) do
        local space = M.SPACES[i]
        if net.ReadBool() then
            local pos = net.ReadPreciseVector()
            local rot = net.ReadPreciseAngle()
            if M.IsFiniteVector(pos) and M.IsFiniteAngle(rot) then
                offsets[space] = {
                    pos = VectorP(pos.x, pos.y, pos.z),
                    rot = AngleP(rot.p, rot.y, rot.r)
                }
            end
        end
    end

    return offsets
end

local function writePriority(priority)
    local parsed = M.ParsePriority(priority)
    local written = {}

    for i = 1, #parsed do
        local id = anchorId(parsed[i])
        if id > 0 then
            written[#written + 1] = id
        end
        if #written >= #(M.ANCHORS or {}) then break end
    end

    net.WriteUInt(#written, 4)
    for i = 1, #written do
        net.WriteUInt(written[i], 4)
    end
end

local function readPriority()
    local count = math.min(net.ReadUInt(4), #(M.ANCHORS or {}))
    local out = {}

    for i = 1, count do
        local name = anchorName(net.ReadUInt(4))
        if name then
            out[#out + 1] = name
        end
    end

    return table.concat(out, ",")
end

local function writeAnchorSide(side)
    side = snapshotAnchorSide(side)
    local options = snapshotAnchorOptions(side.options)

    net.WriteUInt(anchorId(side.selected), 4)
    writePriority(side.priority)
    net.WriteFloat(options.mid12_pct)
    net.WriteFloat(options.mid23_pct)
    net.WriteFloat(options.mid13_pct)
end

local function readAnchorSide()
    return {
        selected = anchorName(net.ReadUInt(4)) or "p1",
        priority = readPriority(),
        options = M.NormalizeAnchorOptions({
            mid12_pct = net.ReadFloat(),
            mid23_pct = net.ReadFloat(),
            mid13_pct = net.ReadFloat()
        })
    }
end

function M.WriteSessionSnapshot(snapshot)
    local hasSnapshot = istable(snapshot)
    net.WriteBool(hasSnapshot)
    if not hasSnapshot then return end

    local actionType, isMirrorAction = normalizeActionType(snapshot.lastActionType, snapshot.isMirrorAction)
    local lastAction = istable(snapshot.lastAction) and snapshot.lastAction or {}
    local mirror = istable(snapshot.mirror) and snapshot.mirror or {}
    local ui = istable(snapshot.ui) and snapshot.ui or {}

    net.WriteUInt(math.Clamp(math.floor(tonumber(snapshot.schema) or M.SESSION_SNAPSHOT_SCHEMA), 1, 255), 8)
    net.WriteUInt(actionId(actionType, isMirrorAction), 3)
    net.WriteBool(isMirrorAction)
    net.WriteUInt(math.Clamp(math.floor(tonumber(lastAction.mode) or 0), 0, 3), 2)
    writeEntityRef(snapshot.prop1)
    writeEntityRef(snapshot.prop2)
    net.WriteUInt(spaceId(snapshot.activeSpace), 3)
    writeSnapshotPoints(snapshot.source)
    writeSnapshotPoints(snapshot.target)

    local linked = istable(snapshot.linked) and snapshot.linked or {}
    local linkedCount = math.min(#linked, M.GetMaxLinkedProps(), M.MAX_COMMIT_PROPS)
    net.WriteUInt(linkedCount, 8)
    for i = 1, linkedCount do
        writeEntityRef(linked[i])
    end

    local anchors = istable(snapshot.anchors) and snapshot.anchors or {}
    writeAnchorSide(anchors.from)
    writeAnchorSide(anchors.to)
    writeSnapshotOffsets(snapshot.offsets)

    net.WriteBool(mirror.enabled == true)
    net.WriteBool(mirror.activeTab == true)
    net.WriteBool(mirror.entityMirrorEnabled == true)
    writeSnapshotPoints(mirror.points)

    net.WriteUInt(spaceId(ui.selectedTab or snapshot.activeSpace), 3)
    net.WriteUInt(spaceId(ui.lastNonMirrorTab or snapshot.lastNonMirrorTab), 3)
    net.WriteBool(tonumber(snapshot.selectedWorldPointIndex) ~= nil)
    if tonumber(snapshot.selectedWorldPointIndex) ~= nil then
        net.WriteUInt(math.Clamp(math.floor(tonumber(snapshot.selectedWorldPointIndex) or 0), 0, M.MAX_POINTS), 2)
    end
end

function M.ReadSessionSnapshot()
    if not net.ReadBool() then return end

    local schema = net.ReadUInt(8)
    local action = actionName(net.ReadUInt(3))
    local isMirrorAction = net.ReadBool()
    local mode = net.ReadUInt(2)
    local prop1 = readEntityRef()
    local prop2 = readEntityRef()
    local activeSpace = spaceName(net.ReadUInt(3))
    local source = readSnapshotPoints()
    local target = readSnapshotPoints()
    local linkedCount = net.ReadUInt(8)
    local linked = {}

    for i = 1, linkedCount do
        local ref = readEntityRef()
        if ref and #linked < M.GetMaxLinkedProps() then
            linked[#linked + 1] = ref
        end
    end

    local anchors = {
        from = readAnchorSide(),
        to = readAnchorSide()
    }
    local offsets = readSnapshotOffsets()
    local mirrorEnabled = net.ReadBool()
    local mirrorActiveTab = net.ReadBool()
    local entityMirrorEnabled = net.ReadBool()
    local mirrorPoints = readSnapshotPoints()
    local selectedTab = spaceName(net.ReadUInt(3))
    local lastNonMirrorTab = spaceName(net.ReadUInt(3))
    local hasSelectedWorldPoint = net.ReadBool()
    local selectedWorldPointIndex = hasSelectedWorldPoint and net.ReadUInt(2) or nil

    if schema < 1 or schema > M.SESSION_SNAPSHOT_SCHEMA then return end

    return {
        schema = schema,
        lastActionType = action,
        isMirrorAction = isMirrorAction == true or action == "mirror",
        lastAction = {
            type = action,
            isMirror = isMirrorAction == true or action == "mirror",
            mode = mode
        },
        prop1 = prop1,
        prop2 = prop2,
        activeSpace = activeSpace,
        source = source,
        target = target,
        linked = linked,
        anchors = anchors,
        offsets = offsets,
        mirror = {
            enabled = mirrorEnabled,
            activeTab = mirrorActiveTab,
            entityMirrorEnabled = entityMirrorEnabled,
            points = mirrorPoints
        },
        ui = {
            selectedTab = selectedTab,
            lastNonMirrorTab = validNonMirrorSpace(lastNonMirrorTab)
        },
        selectedWorldPointIndex = selectedWorldPointIndex
    }
end

function M.RestoreSessionSnapshot(snapshot, options)
    if not istable(snapshot) then return end

    local schema = tonumber(snapshot.schema) or 1
    if schema < 1 or schema > M.SESSION_SNAPSHOT_SCHEMA then return end

    options = istable(options) and options or {}
    local restored = M.NewSession()
    local prop1 = resolveSnapshotEntityRef(snapshot.prop1)
    local prop2 = resolveSnapshotEntityRef(snapshot.prop2)

    if IsValid(prop1) and M.IsProp(prop1) then
        restored.prop1 = prop1
    end

    if M.IsWorldTarget(prop2) or (IsValid(prop2) and M.IsProp(prop2) and prop2 ~= restored.prop1) then
        restored.prop2 = prop2
    end

    restored.source = restoreSnapshotPoints(snapshot.source, restored.prop1)
    restored.target = restoreSnapshotPoints(snapshot.target, restored.prop2)
    for i = #restored.target, 1, -1 do
        if not M.IsPointReferenceValid(restored.target[i], restored.prop2, {
            allowWorld = true,
            requireProp = true
        }) then
            table.remove(restored.target, i)
        end
    end
    restored.linked = {}

    for i = 1, math.min(#(snapshot.linked or {}), M.GetMaxLinkedProps()) do
        local ent = resolveSnapshotEntityRef(snapshot.linked[i])
        if IsValid(ent) and M.IsProp(ent) and ent ~= restored.prop1 and ent ~= restored.prop2 then
            restored.linked[#restored.linked + 1] = ent
        end
    end

    restored.offsets = copySnapshotOffsets(snapshot.offsets)
    restored.anchors = snapshotAnchors(snapshot.anchors)
    restored.anchorSelection = {
        from = {
            anchor = restored.anchors.from.selected,
            convarAnchor = restored.anchors.from.selected,
            pointCount = #restored.source,
            priority = restored.anchors.from.priority
        },
        to = {
            anchor = restored.anchors.to.selected,
            convarAnchor = restored.anchors.to.selected,
            pointCount = #restored.target,
            priority = restored.anchors.to.priority
        }
    }

    local mirror = istable(snapshot.mirror) and snapshot.mirror or {}
    restored.mirror = {
        enabled = mirror.enabled == true,
        activeTab = mirror.activeTab == true,
        points = restoreSnapshotPoints(mirror.points, nil),
        classification = mirror.classification,
        entityMirrorEnabled = mirror.entityMirrorEnabled == true
    }

    local ui = istable(snapshot.ui) and snapshot.ui or {}
    restored.lastNonMirrorSpace = validNonMirrorSpace(ui.lastNonMirrorTab)
        or validNonMirrorSpace(snapshot.lastNonMirrorTab)
        or validNonMirrorSpace(snapshot.activeSpace)
    restored.activeSpace = M.ResolveSnapshotRestoreSpace(snapshot, options.currentSpace)
    restored.selectedWorldPointIndex = tonumber(snapshot.selectedWorldPointIndex)

    M.RefreshState(restored)

    return restored, {
        activeSpace = restored.activeSpace,
        offsets = restored.offsets,
        anchors = restored.anchors,
        entityMirrorEnabled = restored.mirror.entityMirrorEnabled
    }
end

function M.PointInsideAABB(localPos, mins, maxs)
    local eps = M.AABB_PICKING_PADDING

    return localPos.x >= mins.x - eps and localPos.x <= maxs.x + eps
        and localPos.y >= mins.y - eps and localPos.y <= maxs.y + eps
        and localPos.z >= mins.z - eps and localPos.z <= maxs.z + eps
end

return M
