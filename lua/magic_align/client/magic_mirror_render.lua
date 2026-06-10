MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local renderPrimitives = client.RenderPrimitives or include("magic_align/client/render_primitives.lua")
local MagicMirror = M.MagicMirror or include("magic_align/magic_mirror.lua")

local VectorP = M.VectorP
local isvector = M.IsVectorLike
local toVector = M.ToVector

local PURPLE_FILL = Color(176, 112, 235, 74)
local BOUNDS_COLOR = Color(176, 112, 235, 92)
local FACE_COLOR = Color(226, 198, 255, 190)
local ZONE_EDGE = Color(245, 232, 255, 230)
local ARROW_COLOR = Color(176, 112, 235, 255)

local boxCorners = {}
local edgePairs = {
    { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 },
    { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }
}

local function localFacePoint(axis, fixed, u, v)
    if axis == M.ENTITY_MIRROR_X then
        return VectorP(fixed, u, v)
    elseif axis == M.ENTITY_MIRROR_Y then
        return VectorP(u, fixed, v)
    end

    return VectorP(u, v, fixed)
end

local function worldPoint(ent, localPos)
    if not IsValid(ent) or not isvector(localPos) then return end

    local world = M.EntityMirror.LocalPointToWorld(ent, localPos)
    return world and toVector(world)
end

local function copyLocal(v)
    if not isvector(v) then return end

    return VectorP(v.x, v.y, v.z)
end

local function setAxisValue(v, axis, value)
    if axis == M.ENTITY_MIRROR_X then
        v.x = value
    elseif axis == M.ENTITY_MIRROR_Y then
        v.y = value
    elseif axis == M.ENTITY_MIRROR_Z then
        v.z = value
    end
end

local function axisRange(box, axis)
    local mins, maxs = box and box.mins, box and box.maxs
    if not (isvector(mins) and isvector(maxs)) then return end

    if axis == M.ENTITY_MIRROR_X then
        return mins.x, maxs.x
    elseif axis == M.ENTITY_MIRROR_Y then
        return mins.y, maxs.y
    elseif axis == M.ENTITY_MIRROR_Z then
        return mins.z, maxs.z
    end
end

local function centeredArrowSegmentLocal(box, axis)
    local mins, maxs = box and box.mins, box and box.maxs
    if not (isvector(mins) and isvector(maxs)) then return end

    local minValue, maxValue = axisRange(box, axis)
    if not (minValue and maxValue) then return end

    local axisLength = math.abs(maxValue - minValue)
    if axisLength <= (M.PICKING_EPSILON or 0.0001) then return end

    local center = (mins + maxs) * 0.5
    local margin = math.min(axisLength * 0.035, 2)
    if axisLength - margin * 2 <= axisLength * 0.5 then
        margin = 0
    end

    local startLocal = copyLocal(center)
    local endLocal = copyLocal(center)
    setAxisValue(startLocal, axis, minValue + margin)
    setAxisValue(endLocal, axis, maxValue - margin)

    return startLocal, endLocal
end

local function fillBoundsCorners(mins, maxs)
    boxCorners[1] = VectorP(mins.x, mins.y, mins.z)
    boxCorners[2] = VectorP(mins.x, maxs.y, mins.z)
    boxCorners[3] = VectorP(mins.x, mins.y, maxs.z)
    boxCorners[4] = VectorP(mins.x, maxs.y, maxs.z)
    boxCorners[5] = VectorP(maxs.x, mins.y, mins.z)
    boxCorners[6] = VectorP(maxs.x, maxs.y, mins.z)
    boxCorners[7] = VectorP(maxs.x, mins.y, maxs.z)
    boxCorners[8] = VectorP(maxs.x, maxs.y, maxs.z)
end

local function drawBounds(ent, box)
    if not (box and isvector(box.mins) and isvector(box.maxs)) then return end

    fillBoundsCorners(box.mins, box.maxs)
    for i = 1, #edgePairs do
        local edge = edgePairs[i]
        local a = worldPoint(ent, boxCorners[edge[1]])
        local b = worldPoint(ent, boxCorners[edge[2]])
        if a and b then
            render.DrawLine(a, b, BOUNDS_COLOR, true)
        end
    end
end

local function facePolygon(face, zone)
    local uMin, uMax = face.uMin, face.uMax
    local vMin, vMax = face.vMin, face.vMax
    local u25 = Lerp(0.25, uMin, uMax)
    local u75 = Lerp(0.75, uMin, uMax)
    local v25 = Lerp(0.25, vMin, vMax)
    local v75 = Lerp(0.75, vMin, vMax)
    local axis = face.axis
    local fixed = face.fixed

    if zone.kind == "center" then
        return {
            localFacePoint(axis, fixed, u25, v25),
            localFacePoint(axis, fixed, u75, v25),
            localFacePoint(axis, fixed, u75, v75),
            localFacePoint(axis, fixed, u25, v75)
        }
    elseif zone.kind == "u" and zone.side < 0 then
        return {
            localFacePoint(axis, fixed, uMin, vMin),
            localFacePoint(axis, fixed, u25, v25),
            localFacePoint(axis, fixed, u25, v75),
            localFacePoint(axis, fixed, uMin, vMax)
        }
    elseif zone.kind == "u" then
        return {
            localFacePoint(axis, fixed, u75, v25),
            localFacePoint(axis, fixed, uMax, vMin),
            localFacePoint(axis, fixed, uMax, vMax),
            localFacePoint(axis, fixed, u75, v75)
        }
    elseif zone.kind == "v" and zone.side < 0 then
        return {
            localFacePoint(axis, fixed, uMin, vMin),
            localFacePoint(axis, fixed, uMax, vMin),
            localFacePoint(axis, fixed, u75, v25),
            localFacePoint(axis, fixed, u25, v25)
        }
    elseif zone.kind == "v" then
        return {
            localFacePoint(axis, fixed, u25, v75),
            localFacePoint(axis, fixed, u75, v75),
            localFacePoint(axis, fixed, uMax, vMax),
            localFacePoint(axis, fixed, uMin, vMax)
        }
    end
end

local function drawFaceOutline(ent, face)
    local corners = face and face.corners
    if not istable(corners) then return end

    for i = 1, #corners do
        local a = worldPoint(ent, corners[i])
        local b = worldPoint(ent, corners[(i % #corners) + 1])
        if a and b then
            render.DrawLine(a, b, FACE_COLOR, true)
        end
    end
end

local function drawZone(ent, face, zone)
    local localPoints = face and zone and facePolygon(face, zone) or nil
    if not istable(localPoints) or #localPoints ~= 4 then return end

    local p1 = worldPoint(ent, localPoints[1])
    local p2 = worldPoint(ent, localPoints[2])
    local p3 = worldPoint(ent, localPoints[3])
    local p4 = worldPoint(ent, localPoints[4])
    if not (p1 and p2 and p3 and p4) then return end

    render.SetColorMaterial()
    render.DrawQuad(p1, p2, p3, p4, PURPLE_FILL)
    render.DrawQuad(p4, p3, p2, p1, PURPLE_FILL)

    render.DrawLine(p1, p2, ZONE_EDGE, true)
    render.DrawLine(p2, p3, ZONE_EDGE, true)
    render.DrawLine(p3, p4, ZONE_EDGE, true)
    render.DrawLine(p4, p1, ZONE_EDGE, true)
end

local function drawMirrorArrow(ent, box, _, zone)
    local axis = zone and zone.axis
    local startLocal, endLocal = centeredArrowSegmentLocal(box, axis)
    if not (startLocal and endLocal) then return end

    local startPos = worldPoint(ent, startLocal)
    local endPos = worldPoint(ent, endLocal)
    if not (startPos and endPos) then return end

    local ply = LocalPlayer()
    local viewerPos = IsValid(ply) and ply:GetShootPos() or EyePos()
    local colors = client.colors or {}
    if renderPrimitives and isfunction(renderPrimitives.DrawAxisArrow) then
        renderPrimitives.DrawAxisArrow(startPos, endPos, colors.mirror or ARROW_COLOR, viewerPos, {
            doubleHeaded = true
        })
    end
end

local function activeMirrorState()
    local mirrorClient = client.MagicMirror
    if mirrorClient and isfunction(mirrorClient.activeToolState) then
        local tool, state = mirrorClient.activeToolState()
        return tool, state
    end
end

hook.Remove("PostDrawTranslucentRenderables", "MagicMirrorDrawAABBZones")
hook.Add("PostDrawTranslucentRenderables", "MagicMirrorDrawAABBZones", function(bDrawingDepth, bDrawingSkybox)
    if bDrawingDepth or bDrawingSkybox then return end

    local _, state = activeMirrorState()
    local hover = state and state.hover
    if not hover or not IsValid(hover.ent) then return end

    cam.IgnoreZ(false)
    drawBounds(hover.ent, hover.box)
    drawFaceOutline(hover.ent, hover.face)
    drawZone(hover.ent, hover.face, hover.zone)
    cam.IgnoreZ(true)
    drawMirrorArrow(hover.ent, hover.box, hover.face, hover.zone)
    cam.IgnoreZ(false)
end)

MagicMirror.ClientRender = true

return MagicMirror
