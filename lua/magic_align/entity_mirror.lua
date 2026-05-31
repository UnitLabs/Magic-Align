local M = MAGIC_ALIGN
if not M then return end

M.ENTITY_MIRROR_NONE = 0
M.ENTITY_MIRROR_X = 1
M.ENTITY_MIRROR_Y = 2
M.ENTITY_MIRROR_Z = 3

M.ENTITY_MIRROR_VISUAL = 1
M.ENTITY_MIRROR_PHYSICS = 2
M.ENTITY_MIRROR_PRIMITIVE_AWARE = 4
M.ENTITY_MIRROR_DEFAULT_FLAGS = bit.bor(
    M.ENTITY_MIRROR_VISUAL,
    M.ENTITY_MIRROR_PHYSICS,
    M.ENTITY_MIRROR_PRIMITIVE_AWARE
)

M.ENTITY_MIRROR_MODIFIER_ID = "magic_align_entity_mirror"

local EntityMirror = M.EntityMirror or {}
M.EntityMirror = EntityMirror

local NW_AXIS = "magic_align_mirror_axis"
local NW_FLAGS = "magic_align_mirror_flags"
local NW_REVISION = "magic_align_mirror_revision"
local DEBUG_CVAR = "magic_align_mirror_debug"
local DEBUG_CLIENT_CVAR = "magic_align_mirror_debug_client"
local MIRROR_COLOR = Color(176, 112, 235)
local EDITOR_FADED_COLOR = Color(120, 120, 120)
local EDITOR_HEADER_FALLBACK = Color(122, 189, 254)
local EDITOR_BACKGROUND_FALLBACK = Color(245, 245, 245)

if SERVER then
    CreateConVar(
        DEBUG_CVAR,
        "0",
        FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
        "Print Magic Align mirror pose, visual, and physics debug data."
    )
elseif CLIENT then
    CreateClientConVar(
        DEBUG_CLIENT_CVAR,
        "0",
        true,
        false,
        "Print clientside Magic Align mirror visual and physics debug data."
    )
end

local function validAxis(axis)
    axis = tonumber(axis) or M.ENTITY_MIRROR_NONE
    axis = math.floor(axis)
    if axis < M.ENTITY_MIRROR_NONE or axis > M.ENTITY_MIRROR_Z then
        return M.ENTITY_MIRROR_NONE
    end

    return axis
end

local function validFlags(flags)
    flags = tonumber(flags)
    if not flags then return M.ENTITY_MIRROR_DEFAULT_FLAGS end

    return math.max(0, math.floor(flags))
end

function EntityMirror.IsMirrored(ent)
    return EntityMirror.GetAxis(ent) ~= M.ENTITY_MIRROR_NONE
end

function EntityMirror.AxisLabel(axis)
    axis = validAxis(axis)
    if axis == M.ENTITY_MIRROR_X then return "X" end
    if axis == M.ENTITY_MIRROR_Y then return "Y" end
    if axis == M.ENTITY_MIRROR_Z then return "Z" end
    return "Off"
end

function EntityMirror.Sanitize(data)
    if not istable(data) then return end

    local axis = validAxis(data.axis)
    if axis == M.ENTITY_MIRROR_NONE then return end

    return {
        schema = 1,
        axis = axis,
        flags = validFlags(data.flags),
        revision = math.max(0, math.floor(tonumber(data.revision) or 0))
    }
end

function EntityMirror.AxisForMirrorReference(reference)
    if not istable(reference) then return M.ENTITY_MIRROR_NONE end

    -- MirrorPose repairs point and plane reflections by preserving reflected
    -- forward/up hints. The remaining handedness flip is local right/Y.
    if reference.kind == M.MIRROR_POINT or reference.kind == M.MIRROR_PLANE then
        return M.ENTITY_MIRROR_Y
    end

    return M.ENTITY_MIRROR_NONE
end

function EntityMirror.ComposeAxis(currentAxis, deltaAxis)
    currentAxis = validAxis(currentAxis)
    deltaAxis = validAxis(deltaAxis)

    if deltaAxis == M.ENTITY_MIRROR_NONE then return currentAxis end
    if currentAxis == M.ENTITY_MIRROR_NONE then return deltaAxis end
    if currentAxis == deltaAxis then return M.ENTITY_MIRROR_NONE end

    -- Different local flips compose to a right-handed rotation. The caller is
    -- responsible for the pose solve; we clear the stored flip rather than stack.
    return M.ENTITY_MIRROR_NONE
end

function EntityMirror.ComposeState(state, deltaAxis, flags)
    state = istable(state) and state or {}

    return {
        axis = EntityMirror.ComposeAxis(state.axis, deltaAxis),
        flags = flags ~= nil and validFlags(flags) or validFlags(state.flags)
    }
end

function EntityMirror.StateAxis(state)
    if not istable(state) then return M.ENTITY_MIRROR_NONE end
    return validAxis(state.axis)
end

local function axisSigns(axis)
    if axis == M.ENTITY_MIRROR_X then return -1, 1, 1 end
    if axis == M.ENTITY_MIRROR_Y then return 1, -1, 1 end
    if axis == M.ENTITY_MIRROR_Z then return 1, 1, -1 end
    return 1, 1, 1
end

function EntityMirror.ApplyAxisToVector(out, value, axis)
    if not isvector(value) then return end
    out = isvector(out) and out or Vector()

    local sx, sy, sz = axisSigns(validAxis(axis))
    out.x = value.x * sx
    out.y = value.y * sy
    out.z = value.z * sz

    return out
end

function EntityMirror.ApplyAxisToPoint(point, axis)
    if not isvector(point) then return false end

    EntityMirror.ApplyAxisToVector(point, point, axis)
    if isvector(point.normal) then
        EntityMirror.ApplyAxisToVector(point.normal, point.normal, axis)
    end

    return true
end

function EntityMirror.ScaleForAxis(axis, out)
    out = isvector(out) and out or Vector()
    out.x, out.y, out.z = axisSigns(validAxis(axis))
    return out
end

local function scaleIsIdentity(scale)
    if not isvector(scale) then return true end

    local epsilon = tonumber(M.UI_COMPARE_EPSILON) or 0.0001
    return math.abs(scale.x - 1) <= epsilon
        and math.abs(scale.y - 1) <= epsilon
        and math.abs(scale.z - 1) <= epsilon
end

local function physicsScaleFor(ent, axis, out)
    out = isvector(out) and out or Vector()

    local sx, sy, sz = axisSigns(validAxis(axis))
    local physical = M.GetAdvResizerScales and M.GetAdvResizerScales(ent) or nil
    if isvector(physical) then
        sx = sx * physical.x
        sy = sy * physical.y
        sz = sz * physical.z
    end

    out.x = sx
    out.y = sy
    out.z = sz
    return out
end

local function scaleKey(scale)
    if not isvector(scale) then return "" end
    return string.format("%.6f:%.6f:%.6f", scale.x, scale.y, scale.z)
end

local function captureCollisionBounds(ent)
    if not IsValid(ent) then return end

    if isfunction(ent.GetCollisionBounds) then
        local mins, maxs = ent:GetCollisionBounds()
        if isvector(mins) and isvector(maxs) then
            return mins, maxs
        end
    end

    if isfunction(ent.OBBMins) and isfunction(ent.OBBMaxs) then
        local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
        if isvector(mins) and isvector(maxs) then
            return mins, maxs
        end
    end
end

local function captureRenderBounds(ent)
    if not IsValid(ent) then return end

    if isfunction(ent.GetRenderBounds) then
        local mins, maxs = ent:GetRenderBounds()
        if isvector(mins) and isvector(maxs) then
            return mins, maxs
        end
    end

    return captureCollisionBounds(ent)
end

local function scaledBounds(mins, maxs, scale)
    if not isvector(mins) or not isvector(maxs) or not isvector(scale) then return end

    return Vector(
        math.min(mins.x * scale.x, maxs.x * scale.x),
        math.min(mins.y * scale.y, maxs.y * scale.y),
        math.min(mins.z * scale.z, maxs.z * scale.z)
    ), Vector(
        math.max(mins.x * scale.x, maxs.x * scale.x),
        math.max(mins.y * scale.y, maxs.y * scale.y),
        math.max(mins.z * scale.z, maxs.z * scale.z)
    )
end

local function convexBounds(convexes)
    if not istable(convexes) or not istable(convexes[1]) then return end

    local mins, maxs
    for i = 1, #convexes do
        local convex = convexes[i]
        for j = 1, #convex do
            local item = convex[j]
            local pos = istable(item) and item.pos or item
            if isvector(pos) then
                if not mins then
                    mins = Vector(pos.x, pos.y, pos.z)
                    maxs = Vector(pos.x, pos.y, pos.z)
                else
                    mins.x = math.min(mins.x, pos.x)
                    mins.y = math.min(mins.y, pos.y)
                    mins.z = math.min(mins.z, pos.z)
                    maxs.x = math.max(maxs.x, pos.x)
                    maxs.y = math.max(maxs.y, pos.y)
                    maxs.z = math.max(maxs.z, pos.z)
                end
            end
        end
    end

    return mins, maxs
end

local function setLocalBounds(ent, mins, maxs, collision, render)
    if not IsValid(ent) or not isvector(mins) or not isvector(maxs) then return end

    if collision ~= false and isfunction(ent.SetCollisionBounds) then
        ent:SetCollisionBounds(mins, maxs)
    end

    if render ~= false and isfunction(ent.SetRenderBounds) then
        ent:SetRenderBounds(mins, maxs)
    end

    if render ~= false and isfunction(ent.DestroyShadow) then
        ent:DestroyShadow()
    end
end

local function setCollisionBounds(ent, mins, maxs)
    setLocalBounds(ent, mins, maxs, true, false)
end

local function setRenderBounds(ent, mins, maxs)
    setLocalBounds(ent, mins, maxs, false, true)
end

local function setPhysicsRenderBounds(ent, mins, maxs)
    setLocalBounds(ent, mins, maxs, true, true)
end

local function physicsConvexes(phys)
    if not IsValid(phys) or not phys.GetMeshConvexes then return end

    local convexes = phys:GetMeshConvexes()
    if istable(convexes) and istable(convexes[1]) then
        return convexes
    end
end

local function scaledConvexes(convexes, scratch, scale)
    if not istable(convexes) or not istable(convexes[1]) or not istable(scratch) or not isvector(scale) then
        return
    end

    for i = 1, #convexes do
        local src = convexes[i]
        local dst = scratch[i]
        if not istable(dst) then
            dst = {}
            scratch[i] = dst
        end

        local count = 0
        for j = 1, #src do
            local item = src[j]
            local pos = istable(item) and item.pos or item
            if isvector(pos) then
                count = count + 1
                local out = dst[count]
                if not isvector(out) then
                    out = Vector()
                    dst[count] = out
                end

                out.x = pos.x * scale.x
                out.y = pos.y * scale.y
                out.z = pos.z * scale.z
            end
        end

        for j = count + 1, #dst do
            dst[j] = nil
        end
    end

    for i = #convexes + 1, #scratch do
        scratch[i] = nil
    end

    return scratch
end

local DEBUG_SIGNATURES = setmetatable({}, { __mode = "k" })

function EntityMirror.DebugEnabled()
    local cvar = GetConVar(DEBUG_CVAR)
    if cvar and cvar:GetBool() then return true end

    if CLIENT then
        local clientCvar = GetConVar(DEBUG_CLIENT_CVAR)
        return clientCvar and clientCvar:GetBool() or false
    end

    return false
end

local function debugVector(value)
    if not isvector(value) then return tostring(value) end

    return ("%.3f %.3f %.3f"):format(value.x, value.y, value.z)
end

local function debugAngle(value)
    if not isangle(value) then return tostring(value) end

    return ("%.3f %.3f %.3f"):format(value.p, value.y, value.r)
end

local function debugBounds(mins, maxs)
    if not isvector(mins) or not isvector(maxs) then return "nil" end

    return ("%s -> %s"):format(debugVector(mins), debugVector(maxs))
end

local function debugValue(value)
    if isvector(value) then return debugVector(value) end
    if isangle(value) then return debugAngle(value) end
    if istable(value) and (value.mins ~= nil or value.maxs ~= nil) then
        return debugBounds(value.mins, value.maxs)
    end

    return tostring(value)
end

local function primitiveDebugResult(ent)
    local primitive = IsValid(ent) and ent.primitive or nil
    local result = istable(primitive) and primitive.result or nil
    if istable(result) and istable(result.convexes) and istable(result.convexes[1]) then
        return result, "cached"
    end

    if not IsValid(ent) or not isfunction(ent.PrimitiveGetConstruct) then return nil, "none" end

    local ok, valid, constructed = pcall(ent.PrimitiveGetConstruct, ent)
    if ok and valid and istable(constructed) then
        return constructed, "constructed"
    end

    return nil, ok and "invalid" or "error"
end

local function debugPrimitiveBounds(ent)
    if not (M.IsPrimitive and M.IsPrimitive(ent)) then return "non-primitive" end

    local result, source = primitiveDebugResult(ent)
    if not result then return source or "none" end

    local mins, maxs = convexBounds(result.convexes)
    if not mins or not maxs then
        mins, maxs = result.mins, result.maxs
    end

    return ("%s %s"):format(source or "unknown", debugBounds(mins, maxs))
end

function EntityMirror.DebugEntity(label, ent, extra, force)
    if not force and not EntityMirror.DebugEnabled() then return end
    if not IsValid(ent) then return end

    local axis = EntityMirror.GetAxis and EntityMirror.GetAxis(ent) or M.ENTITY_MIRROR_NONE
    local flags = EntityMirror.GetFlags and EntityMirror.GetFlags(ent) or 0
    local clientAxis = CLIENT and ent._magicAlignEntityMirrorAxis or nil
    local previewAxis = CLIENT and ent._magicAlignEntityMirrorPreviewAxis or nil
    local phys = ent:GetPhysicsObject()
    local cmins, cmaxs = captureCollisionBounds(ent)
    local rmins, rmaxs = captureRenderBounds(ent)
    local parts = {
        ("[%s]"):format(CLIENT and "CL" or "SV"),
        tostring(label or "mirror"),
        ("ent=%s#%s"):format(ent:GetClass(), ent:EntIndex()),
        ("primitive=%s"):format(M.IsPrimitive and M.IsPrimitive(ent) and "true" or "false"),
        ("axis=%s"):format(EntityMirror.AxisLabel(axis)),
        ("clientAxis=%s"):format(clientAxis ~= nil and EntityMirror.AxisLabel(clientAxis) or "nil"),
        ("previewAxis=%s"):format(previewAxis ~= nil and EntityMirror.AxisLabel(previewAxis) or "nil"),
        ("flags=%s"):format(flags),
        ("pos=%s"):format(debugVector(ent:GetPos())),
        ("ang=%s"):format(debugAngle(ent:GetAngles())),
        ("physPos=%s"):format(IsValid(phys) and debugVector(phys:GetPos()) or "nil"),
        ("physAng=%s"):format(IsValid(phys) and debugAngle(phys:GetAngles()) or "nil"),
        ("collision=%s"):format(debugBounds(cmins, cmaxs)),
        ("render=%s"):format(debugBounds(rmins, rmaxs)),
        ("primitiveBounds=%s"):format(debugPrimitiveBounds(ent))
    }

    if istable(extra) then
        local keys = {}
        for key in pairs(extra) do
            keys[#keys + 1] = key
        end
        table.sort(keys)

        for i = 1, #keys do
            local key = keys[i]
            parts[#parts + 1] = ("%s=%s"):format(tostring(key), debugValue(extra[key]))
        end
    end

    local line = "[Magic Align mirror debug] " .. table.concat(parts, " | ")
    if not force then
        local signatures = DEBUG_SIGNATURES[ent]
        if not signatures then
            signatures = {}
            DEBUG_SIGNATURES[ent] = signatures
        end

        if signatures[label] == line then return end
        signatures[label] = line
    end

    print(line)
end

function EntityMirror.DebugConvexes(label, ent, axis, scale, source, transformed)
    if not EntityMirror.DebugEnabled() then return end

    local smins, smaxs = convexBounds(source)
    local tmins, tmaxs = convexBounds(transformed)
    EntityMirror.DebugEntity(label, ent, {
        requestedAxis = EntityMirror.AxisLabel(axis),
        scale = scale,
        sourceConvex = { mins = smins, maxs = smaxs },
        transformedConvex = { mins = tmins, maxs = tmaxs }
    })
end

if CLIENT then
    concommand.Remove("magic_align_mirror_debug_target")
    concommand.Add("magic_align_mirror_debug_target", function()
        local ply = LocalPlayer()
        local trace = IsValid(ply) and ply:GetEyeTrace() or nil
        local ent = trace and trace.Entity or nil
        if not IsValid(ent) then
            print("[Magic Align mirror debug] no valid entity under crosshair")
            return
        end

        EntityMirror.DebugEntity("client-target-dump", ent, nil, true)
    end)

    concommand.Remove("magic_align_mirror_debug_state")
    concommand.Add("magic_align_mirror_debug_state", function()
        local client = M.Client
        local state = M.ClientState
        if not istable(state) or not IsValid(state.prop1) then
            print("[Magic Align mirror debug] no active Magic Align prop1 state")
            return
        end

        local mirrorState = client
            and client.Mirror
            and client.Mirror.resolve
            and client.Mirror.resolve(state)
            or nil
        local reference = mirrorState and mirrorState.reference or nil
        if not istable(reference) then
            print("[Magic Align mirror debug] no active mirror reference")
            return
        end

        local transformed = M.ApplyTransformModeToPropSet
            and M.ApplyTransformModeToPropSet(M.TRANSFORM_MODE_MIRROR, state.prop1, state.linked, reference, {})
            or nil
        local preview = state.preview
        local deltaAxis = EntityMirror.AxisForMirrorReference(reference)
        local previewAxis = EntityMirror.ComposeAxis(EntityMirror.GetAxis(state.prop1), deltaAxis)

        EntityMirror.DebugEntity("client-state-prop1", state.prop1, {
            referenceKind = reference.kind,
            referencePoint = reference.point,
            referenceAxis = reference.axis,
            referenceNormal = reference.normal,
            deltaAxis = EntityMirror.AxisLabel(deltaAxis),
            previewAxis = EntityMirror.AxisLabel(previewAxis),
            transformedPos = transformed and transformed.pos or nil,
            transformedAng = transformed and transformed.ang or nil,
            previewPos = preview and preview.pos or nil,
            previewAng = preview and preview.ang or nil,
            previewTransformMode = preview and preview.transformMode or nil,
            solveAnchorId = preview and preview.solve and preview.solve.sourceAnchorId or nil,
            solveAnchorLocal = preview and preview.solve and preview.solve.sourceAnchorLocal or nil,
            solveAnchorWorld = preview and preview.solve and preview.solve.sourceAnchorWorld or nil,
            solveAnchorWorldFromLocal = preview
                and preview.solve
                and isvector(preview.solve.sourceAnchorLocal)
                and isvector(preview.pos)
                and isangle(preview.ang)
                and M.LocalToWorldPosPrecise(preview.solve.sourceAnchorLocal, preview.pos, preview.ang)
                or nil
        }, true)

        if preview and IsValid(state.ghost) then
            EntityMirror.DebugEntity("client-state-ghost", state.ghost, {
                previewPos = preview.pos,
                previewAng = preview.ang,
                previewAxis = EntityMirror.AxisLabel(preview.entityMirrorPreviewAxis or M.ENTITY_MIRROR_NONE)
            }, true)
        end
    end)
end

function EntityMirror.GetAxis(ent)
    if not IsValid(ent) then return M.ENTITY_MIRROR_NONE end

    if SERVER then
        local mods = istable(ent.EntityMods) and ent.EntityMods or nil
        local stored = mods and EntityMirror.Sanitize(mods[M.ENTITY_MIRROR_MODIFIER_ID]) or nil
        if stored then return stored.axis end
    end

    if ent.GetNWInt then
        return validAxis(ent:GetNWInt(NW_AXIS, M.ENTITY_MIRROR_NONE))
    end

    return M.ENTITY_MIRROR_NONE
end

function EntityMirror.GetFlags(ent)
    if not IsValid(ent) then return M.ENTITY_MIRROR_DEFAULT_FLAGS end

    if SERVER then
        local mods = istable(ent.EntityMods) and ent.EntityMods or nil
        local stored = mods and EntityMirror.Sanitize(mods[M.ENTITY_MIRROR_MODIFIER_ID]) or nil
        if stored then return stored.flags end
    end

    if ent.GetNWInt then
        return validFlags(ent:GetNWInt(NW_FLAGS, M.ENTITY_MIRROR_DEFAULT_FLAGS))
    end

    return M.ENTITY_MIRROR_DEFAULT_FLAGS
end

if SERVER then
    local PHYS_SCRATCH = setmetatable({}, { __mode = "k" })

    local function actualPhysicsAxis(ent)
        return validAxis(IsValid(ent) and ent._magicAlignEntityMirrorPhysicsAxis or M.ENTITY_MIRROR_NONE)
    end

    local function setActualPhysicsAxis(ent, axis)
        if IsValid(ent) then
            ent._magicAlignEntityMirrorPhysicsAxis = validAxis(axis)
        end
    end

    local function physicsState(ent)
        local phys = IsValid(ent) and ent:GetPhysicsObject() or nil
        if not IsValid(phys) then return end

        local state = {}
        if phys.GetMass then state.mass = phys:GetMass() end
        if phys.GetMaterial then state.material = phys:GetMaterial() end
        if phys.IsCollisionEnabled then state.collision = phys:IsCollisionEnabled() end
        if phys.IsDragEnabled then state.drag = phys:IsDragEnabled() end
        if phys.GetVelocity then state.velocity = phys:GetVelocity() end
        if phys.GetAngleVelocity then state.angleVelocity = phys:GetAngleVelocity() end
        if phys.IsGravityEnabled then state.gravity = phys:IsGravityEnabled() end
        if phys.IsMotionEnabled then state.motion = phys:IsMotionEnabled() end
        if phys.IsAsleep then state.asleep = phys:IsAsleep() end

        return state
    end

    local function applyPhysicsState(ent, state)
        if not istable(state) then return end

        local phys = IsValid(ent) and ent:GetPhysicsObject() or nil
        if not IsValid(phys) then return end

        if isnumber(state.mass) and phys.SetMass then phys:SetMass(state.mass) end
        if isstring(state.material) and phys.SetMaterial then phys:SetMaterial(state.material) end
        if isbool(state.collision) and phys.EnableCollisions then phys:EnableCollisions(state.collision) end
        if isbool(state.drag) and phys.EnableDrag then phys:EnableDrag(state.drag) end
        if isvector(state.velocity) and phys.SetVelocity then phys:SetVelocity(state.velocity) end
        if isvector(state.angleVelocity) and phys.AddAngleVelocity and phys.GetAngleVelocity then
            phys:AddAngleVelocity(state.angleVelocity - phys:GetAngleVelocity())
        end
        if isbool(state.gravity) and phys.EnableGravity then phys:EnableGravity(state.gravity) end
        if isbool(state.motion) and phys.EnableMotion then phys:EnableMotion(state.motion) end
        if state.asleep == true then
            if phys.Sleep then phys:Sleep() end
        elseif phys.Wake then
            phys:Wake()
        end
    end

    local function finishPhysics(ent, customCollisions, state, keepPhysicsTransform)
        if not IsValid(ent) then return end

        ent:EnableCustomCollisions(customCollisions == true)
        ent:SetMoveType(MOVETYPE_VPHYSICS)
        ent:SetSolid(SOLID_VPHYSICS)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) and keepPhysicsTransform ~= true then
            phys:SetPos(ent:GetPos())
            phys:SetAngles(ent:GetAngles())
        end

        applyPhysicsState(ent, state)
        if isfunction(ent.Activate) then
            ent:Activate()
        end
    end

    local function scratchFor(ent)
        local scratch = PHYS_SCRATCH[ent]
        if not scratch then
            scratch = {}
            PHYS_SCRATCH[ent] = scratch
        end

        return scratch
    end

    local function primitiveConstruct(ent)
        if not IsValid(ent) or not isfunction(ent.PrimitiveGetConstruct) then return end

        local valid, result = ent:PrimitiveGetConstruct()
        if not valid or not istable(result) then return end
        if not istable(result.convexes) or not istable(result.convexes[1]) then return end

        return result
    end

    local function rebuildPrimitiveBase(ent, result, options)
        if not IsValid(ent) or not istable(result) then return false end

        local previousSuppress = ent._magicAlignEntityMirrorSuppressPrimitiveHook
        ent._magicAlignEntityMirrorSuppressPrimitiveHook = true

        if isfunction(ent.PrimitiveRebuildPhysics) then
            ent:PrimitiveRebuildPhysics(result)
        elseif isfunction(ent.PrimitiveReconstruct) then
            ent:PrimitiveReconstruct()
        else
            ent._magicAlignEntityMirrorSuppressPrimitiveHook = previousSuppress
            return false
        end

        ent._magicAlignEntityMirrorSuppressPrimitiveHook = previousSuppress
        if istable(ent.primitive) and type(ent.primitive.thread) == "thread" then
            return false
        end

        return true
    end

    local function initStockModelPhysics(ent)
        if not IsValid(ent) or not isfunction(ent.PhysicsInit) then return false end

        ent:EnableCustomCollisions(false)
        local ok = ent:PhysicsInit(SOLID_VPHYSICS)
        if ok == false then return false end

        local collisionMins, collisionMaxs = captureCollisionBounds(ent)
        local renderMins, renderMaxs = captureRenderBounds(ent)
        return ent:GetPhysicsObject(), collisionMins, collisionMaxs, renderMins, renderMaxs
    end

    local function rebuildModelPhysics(ent, axis, state)
        local phys, stockMins, stockMaxs, renderMins, renderMaxs = initStockModelPhysics(ent)
        if phys == false then return false end

        local scale = physicsScaleFor(ent, axis)
        local needsCustom = axis ~= M.ENTITY_MIRROR_NONE or not scaleIsIdentity(scale)
        if needsCustom then
            local source = physicsConvexes(phys)
            local convexes = scaledConvexes(source, scratchFor(ent), scale)
            if not convexes or not ent:PhysicsInitMultiConvex(convexes) then
                initStockModelPhysics(ent)
                finishPhysics(ent, false, state)
                setActualPhysicsAxis(ent, M.ENTITY_MIRROR_NONE)
                return false
            end

            local mins, maxs = convexBounds(convexes)
            if not mins or not maxs then
                mins, maxs = scaledBounds(stockMins, stockMaxs, scale)
            end
            setPhysicsRenderBounds(ent, mins, maxs)
            finishPhysics(ent, true, state)
        else
            setCollisionBounds(ent, stockMins, stockMaxs)
            setRenderBounds(ent, renderMins or stockMins, renderMaxs or stockMaxs)
            finishPhysics(ent, false, state)
        end

        setActualPhysicsAxis(ent, axis)
        return true
    end

    local function rebuildPrimitivePhysics(ent, axis, state, options)
        if not isfunction(ent.PrimitiveReconstruct) then return false end

        local result = primitiveConstruct(ent)
        if not result then return false end

        if options.baseAlreadyFresh ~= true and not rebuildPrimitiveBase(ent, result, options) then
            return false
        end

        local source = result.convexes
        if axis == M.ENTITY_MIRROR_NONE then
            local mins, maxs = convexBounds(source)
            setPhysicsRenderBounds(ent, mins, maxs)
            finishPhysics(ent, true, state)
            setActualPhysicsAxis(ent, M.ENTITY_MIRROR_NONE)
            return true
        end

        local scale = physicsScaleFor(ent, axis)
        local convexes = scaledConvexes(source, scratchFor(ent), scale)
        EntityMirror.DebugConvexes("server-primitive-physics-build", ent, axis, scale, source, convexes)
        if not convexes or not ent:PhysicsInitMultiConvex(convexes) then
            rebuildPrimitiveBase(ent, result, options)
            finishPhysics(ent, true, state)
            setActualPhysicsAxis(ent, M.ENTITY_MIRROR_NONE)
            return false
        end

        local mins, maxs = convexBounds(convexes)
        setPhysicsRenderBounds(ent, mins, maxs)
        finishPhysics(ent, true, state)
        setActualPhysicsAxis(ent, axis)
        EntityMirror.DebugEntity("server-primitive-physics-final", ent, {
            requestedAxis = EntityMirror.AxisLabel(axis),
            scale = scale
        })
        return true
    end

    local function rebuildPhysics(ent, axis, options)
        if not IsValid(ent) then return false end

        axis = validAxis(axis)
        options = istable(options) and options or {}
        local state = physicsState(ent)

        if M.IsPrimitive and M.IsPrimitive(ent) then
            return rebuildPrimitivePhysics(ent, axis, state, options)
        end

        return rebuildModelPhysics(ent, axis, state)
    end

    function EntityMirror.ApplyPhysics(ent, axis, options)
        axis = validAxis(axis)
        if axis == M.ENTITY_MIRROR_NONE or not IsValid(ent) then return false end

        options = istable(options) and options or {}
        local actual = actualPhysicsAxis(ent)
        if actual == axis and options.force ~= true and options.baseAlreadyFresh ~= true then
            return true
        end

        return rebuildPhysics(ent, axis, options)
    end

    function EntityMirror.RestorePhysics(ent, options)
        if not IsValid(ent) then return end

        options = istable(options) and options or {}
        return rebuildPhysics(ent, M.ENTITY_MIRROR_NONE, options)
    end

    local function networkState(ent, axis, flags)
        if not IsValid(ent) then return end

        ent:SetNWInt(NW_AXIS, validAxis(axis))
        ent:SetNWInt(NW_FLAGS, validFlags(flags))
        ent:SetNWInt(NW_REVISION, (ent:GetNWInt(NW_REVISION, 0) + 1) % 65536)
    end

    local function storeState(ent, data)
        if not IsValid(ent) then return end

        ent.EntityMods = istable(ent.EntityMods) and ent.EntityMods or {}
        if data then
            if duplicator and isfunction(duplicator.StoreEntityModifier) then
                duplicator.StoreEntityModifier(ent, M.ENTITY_MIRROR_MODIFIER_ID, data)
            else
                ent.EntityMods[M.ENTITY_MIRROR_MODIFIER_ID] = data
            end
        elseif duplicator and isfunction(duplicator.ClearEntityModifier) then
            duplicator.ClearEntityModifier(ent, M.ENTITY_MIRROR_MODIFIER_ID)
        else
            ent.EntityMods[M.ENTITY_MIRROR_MODIFIER_ID] = nil
        end
    end

    function EntityMirror.SetState(ent, axis, flags, options)
        if not IsValid(ent) then return false end

        axis = validAxis(axis)
        flags = validFlags(flags)
        options = istable(options) and options or {}

        local current = EntityMirror.GetAxis(ent)
        local currentFlags = EntityMirror.GetFlags(ent)
        local actual = actualPhysicsAxis(ent)
        local changed = current ~= axis or currentFlags ~= flags
        local forced = options.force == true

        if axis == M.ENTITY_MIRROR_NONE then
            local restoreAfterNetwork = M.IsPrimitive and M.IsPrimitive(ent)
            if not restoreAfterNetwork
                and (forced or actual ~= M.ENTITY_MIRROR_NONE or current ~= M.ENTITY_MIRROR_NONE or changed) then
                EntityMirror.RestorePhysics(ent)
            end

            storeState(ent)
            networkState(ent, M.ENTITY_MIRROR_NONE, flags)

            if restoreAfterNetwork
                and (forced or actual ~= M.ENTITY_MIRROR_NONE or current ~= M.ENTITY_MIRROR_NONE or changed) then
                EntityMirror.RestorePhysics(ent)
            end
            return true
        end

        local data = {
            schema = 1,
            axis = axis,
            flags = flags,
            revision = (ent:GetNWInt(NW_REVISION, 0) + 1) % 65536
        }

        storeState(ent, data)
        networkState(ent, axis, flags)

        if changed or forced then
            local hadPhysics = bit.band(currentFlags, M.ENTITY_MIRROR_PHYSICS) ~= 0
            local wantsPhysics = bit.band(flags, M.ENTITY_MIRROR_PHYSICS) ~= 0
            local forcePhysicsRebuild = forced and actual ~= M.ENTITY_MIRROR_NONE and wantsPhysics
            local restored = true
            if actual ~= M.ENTITY_MIRROR_NONE
                and (actual ~= axis or (hadPhysics and not wantsPhysics) or forcePhysicsRebuild) then
                restored = EntityMirror.RestorePhysics(ent, { suppressPrimitiveHook = true }) ~= false
            end
            if restored and wantsPhysics and (actual ~= axis or forced) then
                EntityMirror.ApplyPhysics(ent, axis, { force = forced })
            end
        end

        return true
    end

    function EntityMirror.ApplyDelta(ent, deltaAxis, flags)
        if not IsValid(ent) then return false end

        local axis = EntityMirror.ComposeAxis(EntityMirror.GetAxis(ent), deltaAxis)
        return EntityMirror.SetState(ent, axis, flags)
    end

    function EntityMirror.Capture(ent)
        if not IsValid(ent) then return end

        return {
            axis = EntityMirror.GetAxis(ent),
            flags = EntityMirror.GetFlags(ent)
        }
    end

    function EntityMirror.Restore(ent, state)
        if not IsValid(ent) then return end
        state = istable(state) and state or {}

        return EntityMirror.SetState(
            ent,
            validAxis(state.axis),
            validFlags(state.flags),
            { force = true }
        )
    end

    function EntityMirror.ApplyFromBaseState(ent, baseState, deltaAxis, flags, options)
        if not IsValid(ent) then return false end

        options = istable(options) and options or {}
        deltaAxis = validAxis(deltaAxis)
        local baseAxis = EntityMirror.StateAxis(baseState)
        if deltaAxis == M.ENTITY_MIRROR_NONE
            and options.includeBaseState ~= true
            and baseAxis == M.ENTITY_MIRROR_NONE then
            return false
        end

        local targetFlags = deltaAxis ~= M.ENTITY_MIRROR_NONE
            and validFlags(flags)
            or validFlags(istable(baseState) and baseState.flags or nil)
        local targetState = EntityMirror.ComposeState(baseState, deltaAxis, targetFlags)

        if options.normalizeInherited == true then
            -- Cloned entities may have already received mirrored EntityMods from
            -- the duplicator. Normalize through the same unmirrored base before
            -- applying the final state so copy and move use identical mirror physics.
            EntityMirror.SetState(ent, M.ENTITY_MIRROR_NONE, targetFlags, { force = true })
        end

        if targetState.axis == M.ENTITY_MIRROR_NONE then
            return EntityMirror.SetState(ent, M.ENTITY_MIRROR_NONE, targetState.flags, { force = true })
        end

        return EntityMirror.SetState(ent, targetState.axis, targetState.flags, { force = true })
    end

    if duplicator and isfunction(duplicator.RegisterEntityModifier) then
        duplicator.RegisterEntityModifier(M.ENTITY_MIRROR_MODIFIER_ID, function(_, ent, data)
            local stored = EntityMirror.Sanitize(data)
            if stored then
                EntityMirror.SetState(ent, stored.axis, stored.flags, { force = true })
            else
                EntityMirror.SetState(ent, M.ENTITY_MIRROR_NONE, M.ENTITY_MIRROR_DEFAULT_FLAGS, { force = true })
            end
        end)
    end

    hook.Add("Primitive_PostRebuildPhysics", "MagicAlignEntityMirrorPrimitivePhysics", function(ent)
        if not IsValid(ent) then return end
        if ent._magicAlignEntityMirrorSuppressPrimitiveHook then return end
        local axis = EntityMirror.GetAxis(ent)
        if axis == M.ENTITY_MIRROR_NONE then return end
        local flags = EntityMirror.GetFlags(ent)
        if bit.band(flags, M.ENTITY_MIRROR_PHYSICS) == 0 then return end
        if bit.band(flags, M.ENTITY_MIRROR_PRIMITIVE_AWARE) == 0 then return end

        EntityMirror.ApplyPhysics(ent, axis, { baseAlreadyFresh = true })
    end)
end

if CLIENT then
    local ACTIVE_VISUALS = setmetatable({}, { __mode = "k" })
    local CLIENT_ENTITY_STATE = setmetatable({}, { __mode = "k" })
    local ACTIVE_CLIENT_PHYSICS = setmetatable({}, { __mode = "k" })
    local CLIENT_PHYS_SCRATCH = setmetatable({}, { __mode = "k" })
    local VISUAL_PREDICTIONS = setmetatable({}, { __mode = "k" })
    local VISUAL_PREDICTIONS_BY_COMMIT = {}
    local VISUAL_PREDICTION_TIMEOUT = 8
    local reconcileEntity
    local releaseOwnedClientPhysics

    local function stateFor(ent)
        local state = CLIENT_ENTITY_STATE[ent]
        if not state then
            state = {
                desiredVisualAxis = M.ENTITY_MIRROR_NONE,
                desiredPhysicsAxis = M.ENTITY_MIRROR_NONE,
                ownsPhysics = false,
                ownedPhysicsKind = nil,
                ownedPhysicsAxis = M.ENTITY_MIRROR_NONE,
                ownedPhysicsScaleKey = nil,
                primitiveResult = nil,
                pendingPhysicsAxis = nil,
                lastRevision = nil
            }
            CLIENT_ENTITY_STATE[ent] = state
        end

        return state
    end

    local function desiredAxes(ent)
        local axis = EntityMirror.GetAxis(ent)
        local flags = EntityMirror.GetFlags(ent)
        local desiredVisualAxis = bit.band(flags, M.ENTITY_MIRROR_VISUAL) ~= 0
            and axis
            or M.ENTITY_MIRROR_NONE
        local desiredPhysicsAxis = M.ENTITY_MIRROR_NONE

        if bit.band(flags, M.ENTITY_MIRROR_PHYSICS) ~= 0 then
            if M.IsPrimitive and M.IsPrimitive(ent) then
                if bit.band(flags, M.ENTITY_MIRROR_PRIMITIVE_AWARE) ~= 0 then
                    desiredPhysicsAxis = axis
                end
            else
                desiredPhysicsAxis = axis
            end
        end

        return validAxis(desiredVisualAxis), validAxis(desiredPhysicsAxis), axis, flags
    end

    local function truthy(value)
        if value == true then return true end
        if value == false or value == nil then return false end

        local numeric = tonumber(value)
        if numeric ~= nil then return numeric ~= 0 end

        if isstring(value) then
            local text = string.lower(value)
            return text == "true" or text == "yes" or text == "on"
        end

        return false
    end

    local function advResizerClientPhysicsDisabled(ent)
        local entityMods = IsValid(ent) and ent.EntityMods or nil
        local modifierData = istable(entityMods) and entityMods.advr or nil
        if not istable(modifierData) then return false end

        return truthy(modifierData[7])
    end

    local function clientStateExtra(ent, state, extra)
        local data = {}
        if istable(extra) then
            for key, value in pairs(extra) do
                data[key] = value
            end
        end

        state = state or CLIENT_ENTITY_STATE[ent]
        if istable(state) then
            data.desiredVisualAxis = EntityMirror.AxisLabel(state.desiredVisualAxis)
            data.desiredPhysicsAxis = EntityMirror.AxisLabel(state.desiredPhysicsAxis)
            data.ownsPhysics = state.ownsPhysics == true
            data.ownedPhysicsKind = state.ownedPhysicsKind
            data.ownedPhysicsAxis = EntityMirror.AxisLabel(state.ownedPhysicsAxis)
            data.ownedPhysicsScaleKey = state.ownedPhysicsScaleKey
            data.pendingPhysicsAxis = state.pendingPhysicsAxis ~= nil
                and EntityMirror.AxisLabel(state.pendingPhysicsAxis)
                or "nil"
            data.lastRevision = state.lastRevision
        else
            data.clientState = "none"
        end

        local phys = IsValid(ent) and ent:GetPhysicsObject() or nil
        data.physValid = IsValid(phys)
        data.solid = IsValid(ent) and isfunction(ent.GetSolid) and ent:GetSolid() or nil
        data.moveType = IsValid(ent) and isfunction(ent.GetMoveType) and ent:GetMoveType() or nil
        data.collisionGroup = IsValid(ent) and isfunction(ent.GetCollisionGroup) and ent:GetCollisionGroup() or nil
        data.advrDcp = advResizerClientPhysicsDisabled(ent)

        if M.GetAdvResizerScales then
            local physical, visual = M.GetAdvResizerScales(ent)
            data.advrPhysical = physical
            data.advrVisual = visual
        end

        local handler = M.FindSizeHandler and M.FindSizeHandler(ent) or nil
        data.sizeHandler = IsValid(handler)
        if IsValid(handler) then
            data.handlerActualPhysics = isfunction(handler.GetActualPhysicsScale)
                and tostring(handler:GetActualPhysicsScale())
                or "nil"
            data.handlerVisual = isfunction(handler.GetVisualScale)
                and tostring(handler:GetVisualScale())
                or "nil"
        end

        return data
    end

    local function debugClientEntity(label, ent, state, extra, force)
        if not force and not EntityMirror.DebugEnabled() then return end
        if not IsValid(ent) then return end

        EntityMirror.DebugEntity(label, ent, clientStateExtra(ent, state, extra), force)
    end

    local function clientPhysicsScratch(ent)
        local scratch = CLIENT_PHYS_SCRATCH[ent]
        if not scratch then
            scratch = {}
            CLIENT_PHYS_SCRATCH[ent] = scratch
        end

        return scratch
    end

    local function primitiveResult(ent)
        local primitive = IsValid(ent) and ent.primitive or nil
        return istable(primitive) and primitive.result or nil
    end

    local function primitiveConvexes(ent)
        local result = primitiveResult(ent)
        if istable(result) and istable(result.convexes) and istable(result.convexes[1]) then
            return result.convexes
        end

        return physicsConvexes(IsValid(ent) and ent:GetPhysicsObject() or nil)
    end

    local function mirroredClientConvexes(ent, axis, scale)
        local convexes = primitiveConvexes(ent)
        if not convexes then return end

        scale = isvector(scale) and scale or physicsScaleFor(ent, axis)
        return scaledConvexes(convexes, clientPhysicsScratch(ent), scale)
    end

    local function pinClientPhysicsTransform(ent, phys)
        if not IsValid(ent) then return false end

        phys = phys or ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetPos(ent:GetPos())
            phys:SetAngles(ent:GetAngles())
            phys:EnableMotion(false)
            if phys.Sleep then
                phys:Sleep()
            end
            return true
        end

        return false
    end

    local function refreshActiveClientPhysics(ent, state)
        if state and (state.ownsPhysics == true or state.pendingPhysicsAxis ~= nil) then
            ACTIVE_CLIENT_PHYSICS[ent] = true
        else
            ACTIVE_CLIENT_PHYSICS[ent] = nil
        end
    end

    local function markPhysicsPending(ent, state, axis)
        state.pendingPhysicsAxis = validAxis(axis)
        refreshActiveClientPhysics(ent, state)
    end

    local function clearPhysicsPending(ent, state)
        state.pendingPhysicsAxis = nil
        refreshActiveClientPhysics(ent, state)
    end

    local function claimOwnedClientPhysics(ent, state, kind, axis, scaleKeyValue, primitiveResultValue)
        state.ownsPhysics = true
        state.ownedPhysicsKind = kind
        state.ownedPhysicsAxis = validAxis(axis)
        state.ownedPhysicsScaleKey = scaleKeyValue
        state.primitiveResult = primitiveResultValue
        refreshActiveClientPhysics(ent, state)
    end

    local function markOwnedClientPhysics(ent, state, kind, axis, scaleKeyValue, primitiveResultValue)
        claimOwnedClientPhysics(ent, state, kind, axis, scaleKeyValue, primitiveResultValue)
        clearPhysicsPending(ent, state)
    end

    local function clearOwnedClientPhysics(ent, state)
        state.ownsPhysics = false
        state.ownedPhysicsKind = nil
        state.ownedPhysicsAxis = M.ENTITY_MIRROR_NONE
        state.ownedPhysicsScaleKey = nil
        state.primitiveResult = primitiveResult(ent)
        refreshActiveClientPhysics(ent, state)
    end

    local function finishClientPhysics(ent, customCollisions, keepPhysicsTransform)
        ent:EnableCustomCollisions(customCollisions == true)
        ent:SetMoveType(MOVETYPE_VPHYSICS)
        ent:SetSolid(SOLID_VPHYSICS)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            if keepPhysicsTransform ~= true then
                pinClientPhysicsTransform(ent, phys)
            else
                phys:EnableMotion(false)
                if phys.Sleep then
                    phys:Sleep()
                end
            end
        end
    end

    local function initClientStockPhysics(ent)
        if not IsValid(ent) or not isfunction(ent.PhysicsInit) then return false end

        ent:EnableCustomCollisions(false)
        local ok = ent:PhysicsInit(SOLID_VPHYSICS)
        if ok == false then return false end

        local collisionMins, collisionMaxs = captureCollisionBounds(ent)
        local renderMins, renderMaxs = captureRenderBounds(ent)
        return ent:GetPhysicsObject(), collisionMins, collisionMaxs, renderMins, renderMaxs
    end

    local function buildClientModelPhysics(ent, axis, scale, state)
        scale = isvector(scale) and scale or physicsScaleFor(ent, axis)

        local phys, stockMins, stockMaxs, renderMins, renderMaxs = initClientStockPhysics(ent)
        if phys == false then
            debugClientEntity("client-model-physics-stock-init-failed", ent, state, {
                requestedAxis = EntityMirror.AxisLabel(axis),
                desiredScale = scale
            })
            return false
        end
        if state then
            claimOwnedClientPhysics(ent, state, "model_mirror", M.ENTITY_MIRROR_NONE, nil, nil)
        end
        debugClientEntity("client-model-physics-stock-owned", ent, state, {
            requestedAxis = EntityMirror.AxisLabel(axis),
            desiredScale = scale,
            desiredScaleKey = scaleKey(scale)
        })

        local source = physicsConvexes(phys)
        if not istable(source) or not istable(source[1]) then
            debugClientEntity("client-model-physics-source-missing", ent, state, {
                requestedAxis = EntityMirror.AxisLabel(axis),
                desiredScale = scale
            })
            return false
        end

        local convexes = scaledConvexes(source, clientPhysicsScratch(ent), scale)
        if not convexes or not ent:PhysicsInitMultiConvex(convexes) then
            debugClientEntity("client-model-physics-multiconvex-failed", ent, state, {
                requestedAxis = EntityMirror.AxisLabel(axis),
                desiredScale = scale
            })
            return false
        end

        local mins, maxs = convexBounds(convexes)
        if not mins or not maxs then
            mins, maxs = scaledBounds(stockMins, stockMaxs, scale)
        end
        setPhysicsRenderBounds(ent, mins, maxs)
        finishClientPhysics(ent, true)

        return true
    end

    local function rebuildClientModelBaselinePhysics(ent, scale)
        scale = isvector(scale) and scale or physicsScaleFor(ent, M.ENTITY_MIRROR_NONE)

        local phys, stockMins, stockMaxs, renderMins, renderMaxs = initClientStockPhysics(ent)
        if phys == false then return false end

        if scaleIsIdentity(scale) then
            if isvector(stockMins) and isvector(stockMaxs) then
                setCollisionBounds(ent, stockMins, stockMaxs)
            end
            if isvector(renderMins) and isvector(renderMaxs) then
                setRenderBounds(ent, renderMins, renderMaxs)
            end
            finishClientPhysics(ent, false)
            return true
        end

        local source = physicsConvexes(phys)
        if not istable(source) or not istable(source[1]) then return false end

        local convexes = scaledConvexes(source, clientPhysicsScratch(ent), scale)
        if not convexes or not ent:PhysicsInitMultiConvex(convexes) then
            return false
        end

        local mins, maxs = convexBounds(convexes)
        if not mins or not maxs then
            mins, maxs = scaledBounds(stockMins, stockMaxs, scale)
        end
        setPhysicsRenderBounds(ent, mins, maxs)
        finishClientPhysics(ent, true)
        return true
    end

    local function shouldEnsureClientBaselinePhysics(ent)
        if not IsValid(ent) then return false end
        if not (M.IsProp and M.IsProp(ent)) then return false end
        if M.IsPrimitive and M.IsPrimitive(ent) then return false end
        if advResizerClientPhysicsDisabled(ent) then return false end
        if not isfunction(ent.PhysicsInit) then return false end
        if isfunction(ent.GetSolid) and ent:GetSolid() ~= SOLID_VPHYSICS then return false end

        return true
    end

    local function hasExplicitMirrorNetworkState(state)
        local revision = tonumber(state and state.currentRevision)
        if revision and revision >= 0 then return true end

        revision = tonumber(state and state.lastRevision)
        return revision ~= nil and revision >= 0
    end

    local function ensureClientBaselinePhysics(ent, state, reason)
        if not IsValid(ent) then return false end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            if state.ownsPhysics == true and state.ownedPhysicsKind == "model_baseline" then
                pinClientPhysicsTransform(ent, phys)
            end
            return true
        end

        if not shouldEnsureClientBaselinePhysics(ent) then
            debugClientEntity("client-baseline-skipped", ent, state, {
                baselineReason = reason
            })
            return true
        end

        markPhysicsPending(ent, state, M.ENTITY_MIRROR_NONE)

        local scale = physicsScaleFor(ent, M.ENTITY_MIRROR_NONE, state.desiredPhysicsScale)
        local rebuilt = rebuildClientModelBaselinePhysics(ent, scale)
        debugClientEntity(rebuilt and "client-baseline-restored" or "client-baseline-failed", ent, state, {
            baselineReason = reason,
            baselineScale = scale,
            baselineScaleKey = scaleKey(scale)
        })

        if rebuilt then
            markOwnedClientPhysics(ent, state, "model_baseline", M.ENTITY_MIRROR_NONE, scaleKey(scale), nil)
            return true
        end

        refreshActiveClientPhysics(ent, state)
        return false
    end

    local function restoreOwnedPrimitiveBaseline(ent)
        local result = primitiveResult(ent)
        if istable(result) and istable(result.convexes) and istable(result.convexes[1]) then
            if ent:PhysicsInitMultiConvex(result.convexes) then
                local mins, maxs = convexBounds(result.convexes)
                setPhysicsRenderBounds(ent, mins, maxs)
                finishClientPhysics(ent, true)
                return true
            end
        end

        if isfunction(ent.PrimitiveReconstruct) then
            ent:PrimitiveReconstruct()
            if istable(ent.primitive) and type(ent.primitive.thread) == "thread" then
                return false
            end

            local mins, maxs = convexBounds(primitiveConvexes(ent))
            setPhysicsRenderBounds(ent, mins, maxs)
            finishClientPhysics(ent, true)

            return true
        end

        return false
    end

    releaseOwnedClientPhysics = function(ent, state)
        if not IsValid(ent) then return false end

        if state.ownsPhysics ~= true then
            debugClientEntity("client-release-unowned", ent, state, {
                releaseAxis = EntityMirror.AxisLabel(M.ENTITY_MIRROR_NONE)
            })
            if hasExplicitMirrorNetworkState(state) then
                return ensureClientBaselinePhysics(ent, state, "unowned-off-networked")
            end

            clearOwnedClientPhysics(ent, state)
            clearPhysicsPending(ent, state)
            return true
        end

        if state.ownedPhysicsKind == "model_baseline" then
            return ensureClientBaselinePhysics(ent, state, "owned-baseline")
        end

        markPhysicsPending(ent, state, M.ENTITY_MIRROR_NONE)
        debugClientEntity("client-release-owned", ent, state, {
            releaseKind = state.ownedPhysicsKind,
            releaseAxis = EntityMirror.AxisLabel(state.ownedPhysicsAxis)
        })

        local restored = false
        if state.ownedPhysicsKind == "primitive_mirror" then
            restored = restoreOwnedPrimitiveBaseline(ent)
        else
            if isfunction(ent.PhysicsDestroy) then
                ent:EnableCustomCollisions(false)
                ent:PhysicsDestroy()
                restored = true
            end

            local scale = physicsScaleFor(ent, M.ENTITY_MIRROR_NONE, state.desiredPhysicsScale)
            if not advResizerClientPhysicsDisabled(ent) then
                restored = rebuildClientModelBaselinePhysics(ent, scale)
                if restored then
                    markOwnedClientPhysics(ent, state, "model_baseline", M.ENTITY_MIRROR_NONE, scaleKey(scale), nil)
                    return true
                else
                    debugClientEntity("client-release-baseline-failed", ent, state, {
                        baselineScale = scale,
                        baselineScaleKey = scaleKey(scale)
                    })
                end
            else
                debugClientEntity("client-release-baseline-skipped-dcp", ent, state, {
                    baselineScale = scale,
                    baselineScaleKey = scaleKey(scale)
                })
            end
        end

        if not restored then
            refreshActiveClientPhysics(ent, state)
            return false
        end

        clearOwnedClientPhysics(ent, state)
        clearPhysicsPending(ent, state)
        return true
    end

    local function applyOwnedModelPhysics(ent, axis, state)
        axis = validAxis(axis)
        if axis == M.ENTITY_MIRROR_NONE then return releaseOwnedClientPhysics(ent, state) end

        if state.ownsPhysics == true and state.ownedPhysicsKind ~= "model_mirror" then
            if not releaseOwnedClientPhysics(ent, state) then return false end
        end

        local scale = physicsScaleFor(ent, axis, state.desiredPhysicsScale)
        state.desiredPhysicsScale = scale
        local desiredScaleKey = scaleKey(scale)
        if state.ownsPhysics == true
            and state.ownedPhysicsKind == "model_mirror"
            and state.ownedPhysicsAxis == axis
            and state.ownedPhysicsScaleKey == desiredScaleKey then
            clearPhysicsPending(ent, state)
            return true
        end

        markPhysicsPending(ent, state, axis)
        if not buildClientModelPhysics(ent, axis, scale, state) then
            return false
        end

        markOwnedClientPhysics(ent, state, "model_mirror", axis, desiredScaleKey, nil)
        return true
    end

    local function applyOwnedPrimitivePhysics(ent, axis, state)
        axis = validAxis(axis)
        if axis == M.ENTITY_MIRROR_NONE then return releaseOwnedClientPhysics(ent, state) end

        if state.ownsPhysics == true and state.ownedPhysicsKind ~= "primitive_mirror" then
            if not releaseOwnedClientPhysics(ent, state) then return false end
        end

        local result = primitiveResult(ent)
        local resultChanged = state.primitiveResult ~= result
        local scale = physicsScaleFor(ent, axis, state.desiredPhysicsScale)
        state.desiredPhysicsScale = scale
        local desiredScaleKey = scaleKey(scale)

        if state.ownsPhysics == true
            and state.ownedPhysicsKind == "primitive_mirror"
            and state.ownedPhysicsAxis == axis
            and state.ownedPhysicsScaleKey == desiredScaleKey
            and not resultChanged then
            clearPhysicsPending(ent, state)
            return true
        end

        markPhysicsPending(ent, state, axis)
        if istable(ent.primitive) and type(ent.primitive.thread) == "thread" then
            return false
        end

        if state.ownsPhysics == true
            and state.ownedPhysicsKind == "primitive_mirror"
            and not restoreOwnedPrimitiveBaseline(ent) then
            return false
        end

        local convexes = mirroredClientConvexes(ent, axis, scale)
        EntityMirror.DebugConvexes("client-primitive-physics-build", ent, axis, scale, primitiveConvexes(ent), convexes)
        if not convexes or not ent:PhysicsInitMultiConvex(convexes) then
            return false
        end

        local mins, maxs = convexBounds(convexes)
        setPhysicsRenderBounds(ent, mins, maxs)
        finishClientPhysics(ent, true)
        markOwnedClientPhysics(ent, state, "primitive_mirror", axis, desiredScaleKey, primitiveResult(ent))
        EntityMirror.DebugEntity("client-primitive-physics-final", ent, {
            requestedAxis = EntityMirror.AxisLabel(axis),
            scale = scale
        })
        return true
    end

    local function applyOwnedClientPhysics(ent, desiredPhysicsAxis, state)
        desiredPhysicsAxis = validAxis(desiredPhysicsAxis)
        if desiredPhysicsAxis == M.ENTITY_MIRROR_NONE then
            return releaseOwnedClientPhysics(ent, state)
        end

        if M.IsPrimitive and M.IsPrimitive(ent) then
            return applyOwnedPrimitivePhysics(ent, desiredPhysicsAxis, state)
        end

        return applyOwnedModelPhysics(ent, desiredPhysicsAxis, state)
    end

    local function reconcileClientPhysics(ent, desiredPhysicsAxis, state)
        state.desiredPhysicsAxis = validAxis(desiredPhysicsAxis)

        if not IsValid(ent) then return false end
        if not (M.IsProp and M.IsProp(ent)) then
            if state.desiredPhysicsAxis == M.ENTITY_MIRROR_NONE then
                return releaseOwnedClientPhysics(ent, state)
            end

            clearPhysicsPending(ent, state)
            return false
        end

        return applyOwnedClientPhysics(ent, state.desiredPhysicsAxis, state)
    end

    local function setRenderMatrix(ent, axis)
        axis = validAxis(axis)
        if axis == M.ENTITY_MIRROR_NONE then
            if ent._magicAlignEntityMirrorMatrix then
                ent:DisableMatrix("RenderMultiply")
                ent._magicAlignEntityMirrorMatrix = nil
            end
            return
        end

        local matrix = ent._magicAlignEntityMirrorMatrix or Matrix()
        matrix:Identity()
        local scale = EntityMirror.ScaleForAxis(axis, ent._magicAlignEntityMirrorScale)
        ent._magicAlignEntityMirrorScale = scale
        matrix:Scale(scale)
        ent._magicAlignEntityMirrorMatrix = matrix
        ent:EnableMatrix("RenderMultiply", matrix)
        EntityMirror.DebugEntity("client-visual-matrix", ent, {
            requestedAxis = EntityMirror.AxisLabel(axis),
            visualScale = scale
        })
    end

    local function mirrorRenderOverride(ent, ...)
        render.CullMode(MATERIAL_CULLMODE_CW)

        local old = ent._magicAlignEntityMirrorOldRenderOverride
        if isfunction(old) then
            old(ent, ...)
        else
            ent:DrawModel(...)
        end

        render.CullMode(MATERIAL_CULLMODE_CCW)
    end

    local function enableRenderOverride(ent)
        if ent.RenderOverride == mirrorRenderOverride then return end

        ent._magicAlignEntityMirrorOldRenderOverride = ent.RenderOverride
        ent.RenderOverride = mirrorRenderOverride
    end

    local function disableRenderOverride(ent)
        if ent.RenderOverride ~= mirrorRenderOverride then return end

        ent.RenderOverride = ent._magicAlignEntityMirrorOldRenderOverride
        ent._magicAlignEntityMirrorOldRenderOverride = nil
    end

    local function visualNeedsSync(ent, axis)
        axis = validAxis(axis)
        if validAxis(ent._magicAlignEntityMirrorAxis) ~= axis then return true end

        if axis == M.ENTITY_MIRROR_NONE then
            return ent.RenderOverride == mirrorRenderOverride
                or ent._magicAlignEntityMirrorMatrix ~= nil
        end

        return ent.RenderOverride ~= mirrorRenderOverride
            or ent._magicAlignEntityMirrorMatrix == nil
    end

    local function restoreVisualRenderBounds(ent)
        local mins = ent._magicAlignEntityMirrorBaseRenderMins
        local maxs = ent._magicAlignEntityMirrorBaseRenderMaxs
        if isvector(mins) and isvector(maxs) then
            setRenderBounds(ent, mins, maxs)
        end

        ent._magicAlignEntityMirrorBaseRenderMins = nil
        ent._magicAlignEntityMirrorBaseRenderMaxs = nil
    end

    local function applyVisualRenderBounds(ent, axis)
        if not IsValid(ent) then return end

        local baseMins = ent._magicAlignEntityMirrorBaseRenderMins
        local baseMaxs = ent._magicAlignEntityMirrorBaseRenderMaxs
        if not isvector(baseMins) or not isvector(baseMaxs) then
            baseMins, baseMaxs = captureRenderBounds(ent)
            if not isvector(baseMins) or not isvector(baseMaxs) then return end

            ent._magicAlignEntityMirrorBaseRenderMins = Vector(baseMins.x, baseMins.y, baseMins.z)
            ent._magicAlignEntityMirrorBaseRenderMaxs = Vector(baseMaxs.x, baseMaxs.y, baseMaxs.z)
        end

        local scale = EntityMirror.ScaleForAxis(axis, ent._magicAlignEntityMirrorRenderBoundsScale)
        ent._magicAlignEntityMirrorRenderBoundsScale = scale
        local mins, maxs = scaledBounds(baseMins, baseMaxs, scale)
        setRenderBounds(ent, mins, maxs)
    end

    function EntityMirror.ApplyVisual(ent, axis)
        if not IsValid(ent) then return end

        axis = validAxis(axis)
        if axis == M.ENTITY_MIRROR_NONE then
            setRenderMatrix(ent, M.ENTITY_MIRROR_NONE)
            disableRenderOverride(ent)
            restoreVisualRenderBounds(ent)
            ACTIVE_VISUALS[ent] = nil
            ent._magicAlignEntityMirrorAxis = M.ENTITY_MIRROR_NONE
            ent._magicAlignEntityMirrorCullPreviewAxis = M.ENTITY_MIRROR_NONE
            return
        end

        setRenderMatrix(ent, axis)
        enableRenderOverride(ent)
        applyVisualRenderBounds(ent, axis)
        ACTIVE_VISUALS[ent] = true
        ent._magicAlignEntityMirrorAxis = axis
    end

    local function applyVisualState(ent, desiredVisualAxis, state)
        state.desiredVisualAxis = validAxis(desiredVisualAxis)
        if visualNeedsSync(ent, state.desiredVisualAxis) then
            EntityMirror.ApplyVisual(ent, state.desiredVisualAxis)
        end
    end

    local function normalizedCommitId(commitId)
        commitId = tonumber(commitId)
        if not commitId then return end

        commitId = math.floor(commitId)
        if commitId < 0 then return end

        return commitId
    end

    local function unlinkVisualPrediction(ent, prediction)
        prediction = prediction or VISUAL_PREDICTIONS[ent]
        local commitId = prediction and normalizedCommitId(prediction.commitId) or nil
        if not commitId then return end

        local byCommit = VISUAL_PREDICTIONS_BY_COMMIT[commitId]
        if not byCommit then return end

        byCommit[ent] = nil
        if next(byCommit) == nil then
            VISUAL_PREDICTIONS_BY_COMMIT[commitId] = nil
        end
    end

    local function clearVisualPrediction(ent)
        if not VISUAL_PREDICTIONS[ent] then return end

        unlinkVisualPrediction(ent)
        VISUAL_PREDICTIONS[ent] = nil
    end

    function EntityMirror.PredictVisual(ent, axis, timeout, commitId)
        if not IsValid(ent) then return false end

        axis = validAxis(axis)
        commitId = normalizedCommitId(commitId)
        clearVisualPrediction(ent)

        VISUAL_PREDICTIONS[ent] = {
            axis = axis,
            commitId = commitId,
            revision = ent.GetNWInt and ent:GetNWInt(NW_REVISION, -1) or -1,
            expiresAt = RealTime() + math.max(tonumber(timeout) or VISUAL_PREDICTION_TIMEOUT, 0.1)
        }

        if commitId then
            local byCommit = VISUAL_PREDICTIONS_BY_COMMIT[commitId]
            if not byCommit then
                byCommit = setmetatable({}, { __mode = "k" })
                VISUAL_PREDICTIONS_BY_COMMIT[commitId] = byCommit
            end
            byCommit[ent] = true
        end

        EntityMirror.ApplyVisual(ent, axis)

        return true
    end

    function EntityMirror.ResolveVisualPrediction(commitId, accepted)
        commitId = normalizedCommitId(commitId)
        if not commitId then return false end

        local byCommit = VISUAL_PREDICTIONS_BY_COMMIT[commitId]
        if not byCommit then return false end

        local touched = false
        local now = RealTime()
        for ent in pairs(byCommit) do
            local prediction = VISUAL_PREDICTIONS[ent]
            if istable(prediction) and normalizedCommitId(prediction.commitId) == commitId then
                touched = true
                if accepted then
                    prediction.acknowledged = true
                    prediction.expiresAt = math.max(tonumber(prediction.expiresAt) or 0, now + 1)
                else
                    clearVisualPrediction(ent)
                    if reconcileEntity then
                        reconcileEntity(ent, "prediction")
                    end
                end
            end
        end

        if not accepted then
            VISUAL_PREDICTIONS_BY_COMMIT[commitId] = nil
        end

        return touched
    end

    function EntityMirror.ApplyVisualPreview(ent, axis)
        if not IsValid(ent) then return end

        axis = validAxis(axis)
        if axis == M.ENTITY_MIRROR_NONE then
            if validAxis(ent._magicAlignEntityMirrorPreviewAxis) == M.ENTITY_MIRROR_NONE
                and ent.RenderOverride ~= mirrorRenderOverride
                and ent._magicAlignEntityMirrorMatrix == nil then
                return
            end

            setRenderMatrix(ent, M.ENTITY_MIRROR_NONE)
            disableRenderOverride(ent)
            restoreVisualRenderBounds(ent)
            ACTIVE_VISUALS[ent] = nil
            ent._magicAlignEntityMirrorPreviewAxis = M.ENTITY_MIRROR_NONE
            return
        end

        if validAxis(ent._magicAlignEntityMirrorPreviewAxis) == axis
            and ent.RenderOverride == mirrorRenderOverride
            and ent._magicAlignEntityMirrorMatrix ~= nil then
            return
        end

        setRenderMatrix(ent, axis)
        enableRenderOverride(ent)
        applyVisualRenderBounds(ent, axis)
        ACTIVE_VISUALS[ent] = nil
        ent._magicAlignEntityMirrorPreviewAxis = axis
    end

    function EntityMirror.ApplyVisualCullPreview(ent, axis)
        if not IsValid(ent) then return end

        axis = validAxis(axis)
        if axis == M.ENTITY_MIRROR_NONE then
            if validAxis(ent._magicAlignEntityMirrorCullPreviewAxis) == M.ENTITY_MIRROR_NONE
                and ent.RenderOverride ~= mirrorRenderOverride then
                return
            end

            disableRenderOverride(ent)
            ent._magicAlignEntityMirrorCullPreviewAxis = M.ENTITY_MIRROR_NONE
            return
        end

        if validAxis(ent._magicAlignEntityMirrorCullPreviewAxis) == axis
            and ent.RenderOverride == mirrorRenderOverride then
            return
        end

        enableRenderOverride(ent)
        ent._magicAlignEntityMirrorCullPreviewAxis = axis
    end

    reconcileEntity = function(ent, reason)
        if not IsValid(ent) then return end

        local desiredVisualAxis, desiredPhysicsAxis = desiredAxes(ent)
        local revision = ent.GetNWInt and ent:GetNWInt(NW_REVISION, -1) or -1
        local state = CLIENT_ENTITY_STATE[ent]
        if not state
            and revision < 0
            and desiredVisualAxis == M.ENTITY_MIRROR_NONE
            and desiredPhysicsAxis == M.ENTITY_MIRROR_NONE
            and not VISUAL_PREDICTIONS[ent] then
            return
        end

        state = state or stateFor(ent)
        state.currentRevision = revision
        local visualAxis = desiredVisualAxis
        local prediction = VISUAL_PREDICTIONS[ent]

        if istable(prediction) then
            local expired = RealTime() > (tonumber(prediction.expiresAt) or 0)
            local predictionRevision = tonumber(prediction.revision) or -1
            local serverAdvanced = revision >= 0
                and predictionRevision >= 0
                and revision ~= predictionRevision
            local predictedAxis = validAxis(prediction.axis)

            if expired then
                clearVisualPrediction(ent)
            elseif serverAdvanced and visualAxis == predictedAxis then
                clearVisualPrediction(ent)
            elseif serverAdvanced then
                prediction.expiresAt = math.min(tonumber(prediction.expiresAt) or 0, RealTime() + 0.25)
                visualAxis = predictedAxis
            else
                visualAxis = predictedAxis
            end
        end

        applyVisualState(ent, visualAxis, state)
        reconcileClientPhysics(ent, desiredPhysicsAxis, state)
        if revision >= 0 then
            state.lastRevision = revision
        end
        debugClientEntity("client-reconcile", ent, state, {
            reason = reason,
            visualAxis = EntityMirror.AxisLabel(visualAxis),
            desiredVisualAxisNow = EntityMirror.AxisLabel(desiredVisualAxis),
            desiredPhysicsAxisNow = EntityMirror.AxisLabel(desiredPhysicsAxis),
            revision = revision
        })
    end

    hook.Add("EntityNetworkedVarChanged", "MagicAlignEntityMirrorNetworked", function(ent, name)
        if name ~= NW_AXIS and name ~= NW_FLAGS and name ~= NW_REVISION then return end
        reconcileEntity(ent, "network_var")
    end)

    hook.Add("NetworkEntityCreated", "MagicAlignEntityMirrorCreated", function(ent)
        reconcileEntity(ent, "created")
    end)

    local nextScan = 0
    hook.Add("Think", "MagicAlignEntityMirrorVisuals", function()
        for ent in pairs(ACTIVE_CLIENT_PHYSICS) do
            local state = CLIENT_ENTITY_STATE[ent]
            if not IsValid(ent) or not state then
                ACTIVE_CLIENT_PHYSICS[ent] = nil
            else
                if state.ownsPhysics == true and not pinClientPhysicsTransform(ent) then
                    markPhysicsPending(ent, state, state.desiredPhysicsAxis)
                end

                if state.pendingPhysicsAxis ~= nil then
                    reconcileEntity(ent, "think")
                end
            end
        end

        local now = RealTime()
        if now < nextScan then return end
        nextScan = now + 0.5

        for _, ent in ipairs(ents.GetAll()) do
            local state = CLIENT_ENTITY_STATE[ent]
            if EntityMirror.GetAxis(ent) ~= M.ENTITY_MIRROR_NONE
                or ACTIVE_VISUALS[ent]
                or ACTIVE_CLIENT_PHYSICS[ent]
                or VISUAL_PREDICTIONS[ent]
                or (state and (
                    state.ownsPhysics == true
                    or state.pendingPhysicsAxis ~= nil
                    or validAxis(state.desiredVisualAxis) ~= M.ENTITY_MIRROR_NONE
                    or validAxis(state.desiredPhysicsAxis) ~= M.ENTITY_MIRROR_NONE
                )) then
                reconcileEntity(ent, "think")
            end
        end
    end)

    local function rayMetrics(startPos, direction, ent)
        if not IsValid(ent) then return end

        local center = isfunction(ent.WorldSpaceCenter) and ent:WorldSpaceCenter() or ent:GetPos()
        if not isvector(center) then return end

        local offset = center - startPos
        local along = offset:Dot(direction)
        local closest = startPos + direction * along
        return along, center:Distance(closest), center
    end

    local function traceCandidateRadius(ent, fallback)
        local mins, maxs = captureCollisionBounds(ent)
        if isvector(mins) and isvector(maxs) then
            return math.max((maxs - mins):Length() * 0.5, tonumber(fallback) or 0)
        end

        return tonumber(fallback) or 96
    end

    local function addTraceCandidate(list, seen, ent, startPos, direction, maxDistance, radius)
        if not IsValid(ent) or seen[ent] or not (M.IsProp and M.IsProp(ent)) then return end

        local along, perpendicular, center = rayMetrics(startPos, direction, ent)
        if not along or along < 0 or along > maxDistance then return end

        local acceptedRadius = traceCandidateRadius(ent, radius)
        if perpendicular > acceptedRadius then return end

        seen[ent] = true
        list[#list + 1] = {
            ent = ent,
            along = along,
            perpendicular = perpendicular,
            center = center,
            acceptedRadius = acceptedRadius
        }
    end

    local function collectTraceCandidates(startPos, endPos, direction, maxDistance, radius)
        local list = {}
        local seen = {}
        local mins = Vector(-radius, -radius, -radius)
        local maxs = Vector(radius, radius, radius)

        if ents.FindAlongRay then
            for _, ent in ipairs(ents.FindAlongRay(startPos, endPos, mins, maxs)) do
                addTraceCandidate(list, seen, ent, startPos, direction, maxDistance, radius)
            end
        end

        for _, ent in ipairs(ents.GetAll()) do
            addTraceCandidate(list, seen, ent, startPos, direction, maxDistance, radius)
        end

        table.sort(list, function(a, b)
            return a.along < b.along
        end)

        return list
    end

    local function debugTrace(args)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local startPos = ply:EyePos()
        local direction = ply:EyeAngles():Forward()
        local maxDistance = math.Clamp(tonumber(args and args[1]) or 32768, 256, 65536)
        local radius = math.Clamp(tonumber(args and args[2]) or 96, 1, 1024)
        local endPos = startPos + direction * maxDistance
        local trace = util.TraceLine({
            start = startPos,
            endpos = endPos,
            filter = ply
        })
        local traceEnt = trace and trace.Entity or nil

        print(("[Magic Align mirror debug] trace start=%s end=%s hit=%s hitWorld=%s hitPos=%s fraction=%s"):format(
            debugVector(startPos),
            debugVector(endPos),
            IsValid(traceEnt) and ("%s#%s"):format(traceEnt:GetClass(), traceEnt:EntIndex()) or tostring(traceEnt),
            tostring(trace and trace.HitWorld or false),
            debugVector(trace and trace.HitPos or nil),
            tostring(trace and trace.Fraction or nil)
        ))

        if IsValid(traceEnt) then
            debugClientEntity("client-trace-hit", traceEnt, CLIENT_ENTITY_STATE[traceEnt], nil, true)
        end

        local candidates = collectTraceCandidates(startPos, endPos, direction, maxDistance, radius)
        if #candidates < 1 then
            print("[Magic Align mirror debug] no prop bounds candidates along eye ray")
            return
        end

        local limit = math.min(#candidates, 16)
        print(("[Magic Align mirror debug] prop bounds candidates=%d showing=%d radius=%.1f"):format(#candidates, limit, radius))
        for i = 1, limit do
            local item = candidates[i]
            local ent = item.ent
            debugClientEntity("client-trace-candidate-" .. i, ent, CLIENT_ENTITY_STATE[ent], {
                traceHit = ent == traceEnt,
                rayAlong = item.along,
                rayPerpendicular = item.perpendicular,
                rayAcceptedRadius = item.acceptedRadius,
                rayCenter = item.center
            }, true)
        end
    end

    concommand.Remove("magic_align_mirror_debug_trace")
    concommand.Add("magic_align_mirror_debug_trace", function(_, _, args)
        debugTrace(args)
    end)

    concommand.Remove("magic_align_mirror_debug_ent")
    concommand.Add("magic_align_mirror_debug_ent", function(_, _, args)
        local entIndex = math.floor(tonumber(args and args[1]) or -1)
        local ent = entIndex >= 0 and Entity(entIndex) or nil
        if not IsValid(ent) then
            print("[Magic Align mirror debug] usage: magic_align_mirror_debug_ent <entindex>")
            return
        end

        debugClientEntity("client-ent-dump", ent, CLIENT_ENTITY_STATE[ent], nil, true)
    end)

    local function mirroredEditor(panel)
        return IsValid(panel)
            and IsValid(panel.m_Entity)
            and EntityMirror.GetAxis(panel.m_Entity) ~= M.ENTITY_MIRROR_NONE
    end

    local function updatePrimitiveEditorWindow(panel)
        if not IsValid(panel) then return end

        local window = panel:GetParent()
        if not IsValid(window) then return end

        local mirrored = mirroredEditor(panel)
        local ent = panel.m_Entity
        local title = IsValid(ent) and tostring(ent) or ""
        if mirrored then
            title = title .. " [mirrored]"
        end

        local currentTitle = isfunction(window.GetTitle) and window:GetTitle() or nil
        if currentTitle ~= title then
            window:SetTitle(title)
        end

        local footer = mirrored and 24 or 12
        if window._magicAlignMirrorFooter ~= footer then
            window:DockPadding(4, 24, 4, footer)
            window._magicAlignMirrorFooter = footer
        end
    end

    local function drawEditorBox(bevel, x, y, w, h, color, tl, tr, bl, br)
        draw.RoundedBoxEx(bevel, x, y, w, h, EDITOR_FADED_COLOR, tl, tr, bl, br)
        draw.RoundedBoxEx(bevel, x + 1, y + 1, w - 2, h - 2, color, tl, tr, bl, br)
    end

    local function patchPrimitiveEditor()
        if not vgui or not vgui.GetControlTable then return false end

        local panel = vgui.GetControlTable("DTreeEditorBase")
        if not istable(panel) or panel._magicAlignMirrorPatched then return false end

        panel._magicAlignMirrorPatched = true
        local oldSetupWindow = panel.SetupWindow
        local oldSetEntity = panel.SetEntity

        panel.SetupWindow = function(self, ...)
            if isfunction(oldSetupWindow) then
                oldSetupWindow(self, ...)
            end

            local window = self:GetParent()
            if not IsValid(window) then return end

            window.Paint = function(pnl, w, h)
                local sk = pnl.GetEditorSkin and pnl:GetEditorSkin() or {}
                local mirrored = mirroredEditor(self)
                local header = 24
                local footer = mirrored and 24 or 12
                local headerColor = mirrored and MIRROR_COLOR or (sk.colorHeader or EDITOR_HEADER_FALLBACK)
                local background = sk.colorBackground or EDITOR_BACKGROUND_FALLBACK

                drawEditorBox(4, 0, 0, w, header, headerColor, true, true, false, false)
                drawEditorBox(4, 0, h - footer, w, footer, headerColor, false, false, true, true)
                surface.SetDrawColor(background)
                surface.DrawRect(0, header - 1, w, h - footer - header + 2)

                if mirrored then
                    draw.SimpleText(
                        "Mirrored primitive: some shape controls may act reversed.",
                        "DTreeEditorBaseSmall",
                        8,
                        h - footer + 5,
                        color_white,
                        TEXT_ALIGN_LEFT,
                        TEXT_ALIGN_TOP
                    )
                end
            end

            local oldThink = window.Think
            window.Think = function(pnl, ...)
                if isfunction(oldThink) then oldThink(pnl, ...) end
                updatePrimitiveEditorWindow(self)
            end

            updatePrimitiveEditorWindow(self)
        end

        panel.SetEntity = function(self, ent, ...)
            if isfunction(oldSetEntity) then
                oldSetEntity(self, ent, ...)
            end
            updatePrimitiveEditorWindow(self)
        end

        return true
    end

    hook.Add("Think", "MagicAlignEntityMirrorPrimitiveEditorPatch", function()
        if patchPrimitiveEditor() then
            hook.Remove("Think", "MagicAlignEntityMirrorPrimitiveEditorPatch")
        end
    end)
end

return M
