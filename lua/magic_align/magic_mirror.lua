local M = MAGIC_ALIGN
if not M then return end

local MagicMirror = M.MagicMirror or {}
M.MagicMirror = MagicMirror

local VectorP = M.VectorP
local AngleP = M.AngleP
local isvector = M.IsVectorLike or isvector
local isangle = M.IsAngleLike or isangle
local copyVec = M.CopyVectorPrecise
local copyAng = M.CopyAnglePrecise

local AXIS_NONE = M.ENTITY_MIRROR_NONE or 0
local AXIS_X = M.ENTITY_MIRROR_X or 1
local AXIS_Y = M.ENTITY_MIRROR_Y or 2
local AXIS_Z = M.ENTITY_MIRROR_Z or 3

local function sanitizeAxis(axis)
    axis = math.floor(tonumber(axis) or AXIS_NONE)
    if axis < AXIS_NONE or axis > AXIS_Z then
        return AXIS_NONE
    end

    return axis
end

local function axisLabel(axis)
    axis = sanitizeAxis(axis)
    if axis == AXIS_X then return "X" end
    if axis == AXIS_Y then return "Y" end
    if axis == AXIS_Z then return "Z" end
    return "Off"
end

local function composeAxis(currentAxis, deltaAxis)
    if M.EntityMirror and M.EntityMirror.ComposeAxis then
        return M.EntityMirror.ComposeAxis(currentAxis, deltaAxis)
    end

    currentAxis = sanitizeAxis(currentAxis)
    deltaAxis = sanitizeAxis(deltaAxis)
    if deltaAxis == AXIS_NONE then return currentAxis end
    if currentAxis == AXIS_NONE then return deltaAxis end
    if currentAxis == deltaAxis then return AXIS_NONE end
    return AXIS_NONE
end

local function currentEntityAxis(ent)
    if M.EntityMirror and M.EntityMirror.GetAxis then
        return sanitizeAxis(M.EntityMirror.GetAxis(ent))
    end

    return AXIS_NONE
end

local function remainingAxis(a, b)
    a = sanitizeAxis(a)
    b = sanitizeAxis(b)
    if a == AXIS_NONE or b == AXIS_NONE or a == b then return AXIS_NONE end

    for axis = AXIS_X, AXIS_Z do
        if axis ~= a and axis ~= b then
            return axis
        end
    end

    return AXIS_NONE
end

local function faceUAxis(faceAxis)
    if faceAxis == AXIS_X then return AXIS_Y end
    if faceAxis == AXIS_Y then return AXIS_X end
    return AXIS_X
end

local function faceVAxis(faceAxis)
    if faceAxis == AXIS_X then return AXIS_Z end
    if faceAxis == AXIS_Y then return AXIS_Z end
    return AXIS_Y
end

local function clamp01(value)
    return math.Clamp(tonumber(value) or 0, 0, 1)
end

local function classifyFaceZone(face, u, v)
    if not istable(face) then return end

    local uMin = tonumber(face.uMin)
    local uMax = tonumber(face.uMax)
    local vMin = tonumber(face.vMin)
    local vMax = tonumber(face.vMax)
    if not uMin or not uMax or not vMin or not vMax then return end

    local uSize = uMax - uMin
    local vSize = vMax - vMin
    if math.abs(uSize) <= M.PICKING_EPSILON or math.abs(vSize) <= M.PICKING_EPSILON then
        return
    end

    local su = clamp01(((tonumber(u) or uMin) - uMin) / uSize)
    local sv = clamp01(((tonumber(v) or vMin) - vMin) / vSize)
    local faceAxis = sanitizeAxis(face.axis)
    local uAxis = faceUAxis(faceAxis)
    local vAxis = faceVAxis(faceAxis)
    local kind
    local axis
    local side = 0

    if su >= 0.25 and su <= 0.75 and sv >= 0.25 and sv <= 0.75 then
        kind = "center"
        axis = faceAxis
    else
        local a = math.abs(su - 0.5)
        local b = math.abs(sv - 0.5)
        if a > b then
            kind = "u"
            axis = uAxis
            side = su < 0.5 and -1 or 1
        else
            kind = "v"
            axis = vAxis
            side = sv < 0.5 and -1 or 1
        end
    end

    return {
        kind = kind,
        axis = axis,
        label = axisLabel(axis),
        side = side,
        su = su,
        sv = sv,
        u = tonumber(u) or uMin,
        v = tonumber(v) or vMin,
        uAxis = uAxis,
        vAxis = vAxis
    }
end

local function classifyCandidate(candidate)
    local face = istable(candidate) and candidate.face or nil
    if not face then return end

    return classifyFaceZone(face, face.u, face.v)
end

local function localAxisWorld(ang, axis)
    if not isangle(ang) then return end

    axis = sanitizeAxis(axis)
    if axis == AXIS_X and M.AngleForwardPrecise then
        return M.AngleForwardPrecise(ang)
    elseif axis == AXIS_Y and M.AngleRightPrecise then
        return M.AngleRightPrecise(ang)
    elseif axis == AXIS_Z and M.AngleUpPrecise then
        return M.AngleUpPrecise(ang)
    end
end

local function targetPose(ent, deltaAxis, out)
    if not IsValid(ent) then return end

    deltaAxis = sanitizeAxis(deltaAxis)
    if deltaAxis == AXIS_NONE then return end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    if not isvector(pos) or not isangle(ang) then return end

    local currentAxis = currentEntityAxis(ent)
    local targetAxis = composeAxis(currentAxis, deltaAxis)
    local rotationAxis = remainingAxis(currentAxis, deltaAxis)
    local targetAng = copyAng and copyAng(ang) or AngleP(ang.p, ang.y, ang.r)
    local bakedRotation = false

    if rotationAxis ~= AXIS_NONE and M.RotateAngleAroundAxisPrecise then
        local worldAxis = localAxisWorld(ang, rotationAxis)
        if isvector(worldAxis) then
            targetAng = M.RotateAngleAroundAxisPrecise(targetAng, worldAxis, 180)
            bakedRotation = true
        end
    end

    local targetPos = pos
    if M.EntityMirror and M.EntityMirror.PositionForInPlaceAxisChange then
        local adjusted = M.EntityMirror.PositionForInPlaceAxisChange(ent, targetAng, currentAxis, targetAxis)
        if isvector(adjusted) then
            targetPos = adjusted
        end
    end

    out = istable(out) and out or {}
    out.pos = copyVec and copyVec(targetPos) or VectorP(targetPos.x, targetPos.y, targetPos.z)
    out.ang = targetAng
    out.entityMirrorAxis = deltaAxis
    out.entityMirrorPreviewAxis = targetAxis
    out.currentMirrorAxis = currentAxis
    out.targetMirrorAxis = targetAxis
    out.rotationAxis = rotationAxis
    out.bakedRotation = bakedRotation
    out.transformMode = M.TRANSFORM_MODE_MIRROR
    out.absoluteLinked = true
    out.linked = out.linked or {}
    for i = 1, #out.linked do
        out.linked[i] = nil
    end

    return out
end

MagicMirror.SanitizeAxis = sanitizeAxis
MagicMirror.AxisLabel = axisLabel
MagicMirror.ComposeAxis = composeAxis
MagicMirror.CurrentEntityAxis = currentEntityAxis
MagicMirror.RemainingAxis = remainingAxis
MagicMirror.FaceUAxis = faceUAxis
MagicMirror.FaceVAxis = faceVAxis
MagicMirror.ClassifyFaceZone = classifyFaceZone
MagicMirror.ClassifyCandidate = classifyCandidate
MagicMirror.LocalAxisWorld = localAxisWorld
MagicMirror.TargetPose = targetPose

return MagicMirror
