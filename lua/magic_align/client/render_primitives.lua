MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local primitives = client.RenderPrimitives or {}
client.RenderPrimitives = primitives

local VectorP = M.VectorP
local isvector = M.IsVectorLike
local toVector = M.ToVector

local cachedColors = primitives.cachedColors or {}
primitives.cachedColors = cachedColors

local function cachedColor(r, g, b, a)
    r = math.Clamp(math.floor(tonumber(r) or 0), 0, 255)
    g = math.Clamp(math.floor(tonumber(g) or 0), 0, 255)
    b = math.Clamp(math.floor(tonumber(b) or 0), 0, 255)
    a = math.Clamp(math.floor(tonumber(a) or 255), 0, 255)

    local key = (((r * 256) + g) * 256 + b) * 256 + a
    local cached = cachedColors[key]
    if cached then
        return cached
    end

    cached = Color(r, g, b, a)
    cachedColors[key] = cached
    return cached
end

local function cappedAlpha(color, alpha)
    color = color or color_white
    local baseAlpha = color.a == nil and 255 or color.a
    return cachedColor(color.r, color.g, color.b, math.min(baseAlpha, alpha))
end

local function renderVector(value)
    if not isvector(value) then return end
    return toVector(value)
end

local function meshPosition(position)
    position = renderVector(position)
    if not position then return false end

    mesh.Position(position)
    return true
end

local function drawLine(startPos, endPos, color, writeZ)
    startPos = renderVector(startPos)
    endPos = renderVector(endPos)
    if not startPos or not endPos then return end

    render.DrawLine(startPos, endPos, color, writeZ)
end

local function pushTriangle(a, b, c, color)
    if not meshPosition(a) then return false end
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()

    if not meshPosition(b) then return false end
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()

    if not meshPosition(c) then return false end
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()

    return true
end

local function drawFilledQuad(a, b, c, d, color)
    render.SetColorMaterial()
    mesh.Begin(MATERIAL_TRIANGLES, 4)
        pushTriangle(a, b, c, color)
        pushTriangle(a, c, d, color)
        pushTriangle(c, b, a, color)
        pushTriangle(d, c, a, color)
    mesh.End()
end

local function drawFilledTriangle(a, b, c, color)
    render.SetColorMaterial()
    mesh.Begin(MATERIAL_TRIANGLES, 2)
        pushTriangle(a, b, c, color)
        pushTriangle(c, b, a, color)
    mesh.End()
end

function primitives.CachedColor(r, g, b, a)
    return cachedColor(r, g, b, a)
end

function primitives.CappedAlpha(color, alpha)
    return cappedAlpha(color, alpha)
end

function primitives.DrawLine(startPos, endPos, color, writeZ)
    return drawLine(startPos, endPos, color, writeZ)
end

function primitives.DrawFilledQuad(a, b, c, d, color)
    return drawFilledQuad(a, b, c, d, color)
end

function primitives.DrawFilledTriangle(a, b, c, color)
    return drawFilledTriangle(a, b, c, color)
end

function primitives.DrawAxisArrow(startPos, endPos, color, viewerPos, options)
    startPos = renderVector(startPos)
    endPos = renderVector(endPos)
    if not startPos or not endPos then return end

    local axis = endPos - startPos
    local length = axis:Length()
    if length < 0.01 then return end

    axis:Normalize()

    local center = (startPos + endPos) * 0.5
    viewerPos = renderVector(viewerPos) or (IsValid(LocalPlayer()) and LocalPlayer():GetShootPos() or EyePos())
    if not isvector(viewerPos) then return end

    local toViewer = viewerPos - center
    local width = axis:Cross(toViewer)
    if width:LengthSqr() < 1e-8 then
        width = axis:Cross(math.abs(axis.z) < 0.99 and VectorP(0, 0, 1) or VectorP(0, 1, 0))
    end
    if width:LengthSqr() < 1e-8 then return end
    width:Normalize()

    local normal = width:Cross(axis)
    if normal:LengthSqr() > 1e-8 then
        normal:Normalize()
    else
        normal = VectorP(0, 0, 1)
    end

    color = color or color_white
    local doubleHeaded = istable(options) and options.doubleHeaded == true

    local push = normal * 0.08
    local shaftHalf = math.Clamp(length * 0.006, 0.06, 0.22)
    local headHalf = shaftHalf * 3.8
    local headLengthMax = length * (doubleHeaded and 0.24 or 0.28)
    local headLength = math.Clamp(length * (doubleHeaded and 0.14 or 0.16), math.min(shaftHalf * 4.2, headLengthMax), headLengthMax)
    local fill = cappedAlpha(color, 225)
    local outline = cachedColor(
        math.min(color.r + 55, 255),
        math.min(color.g + 55, 255),
        math.min(color.b + 55, 255),
        math.min((color.a or 255) + 26, 110)
    )

    if doubleHeaded then
        local startBase = startPos + axis * headLength
        local endBase = endPos - axis * headLength

        local startLeft = startBase - width * shaftHalf + push
        local startRight = startBase + width * shaftHalf + push
        local endLeft = endBase - width * shaftHalf + push
        local endRight = endBase + width * shaftHalf + push

        local startHeadLeft = startBase - width * headHalf + push
        local startHeadRight = startBase + width * headHalf + push
        local endHeadLeft = endBase - width * headHalf + push
        local endHeadRight = endBase + width * headHalf + push
        local startTip = startPos + push
        local endTip = endPos + push

        if startBase:DistToSqr(endBase) > 0.000001 then
            drawFilledQuad(startLeft, endLeft, endRight, startRight, fill)
            drawLine(startLeft, endLeft, outline, true)
            drawLine(startRight, endRight, outline, true)
        end

        drawFilledTriangle(startHeadLeft, startTip, startHeadRight, fill)
        drawFilledTriangle(endHeadLeft, endTip, endHeadRight, fill)

        drawLine(startHeadLeft, startTip, outline, true)
        drawLine(startTip, startHeadRight, outline, true)
        drawLine(startHeadLeft, startHeadRight, outline, true)
        drawLine(endHeadLeft, endTip, outline, true)
        drawLine(endTip, endHeadRight, outline, true)
        drawLine(endHeadLeft, endHeadRight, outline, true)
        return
    end

    local headBase = endPos - axis * headLength
    local tailLeft = startPos - width * shaftHalf + push
    local tailRight = startPos + width * shaftHalf + push
    local baseLeft = headBase - width * shaftHalf + push
    local baseRight = headBase + width * shaftHalf + push
    local headLeft = headBase - width * headHalf + push
    local headRight = headBase + width * headHalf + push
    local tip = endPos + push

    drawFilledQuad(tailLeft, baseLeft, baseRight, tailRight, fill)
    drawFilledTriangle(headLeft, tip, headRight, fill)

    drawLine(tailLeft, baseLeft, outline, true)
    drawLine(tailRight, baseRight, outline, true)
    drawLine(headLeft, tip, outline, true)
    drawLine(tip, headRight, outline, true)
    drawLine(tailLeft, tailRight, outline, true)
    drawLine(headLeft, headRight, outline, true)
end

return primitives
