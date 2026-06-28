MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local VectorP = M.VectorP
local AngleP = M.AngleP
local isvector = M.IsVectorLike
local isangle = M.IsAngleLike
local toVector = M.ToVector
local toAngle = M.ToAngle
local LocalToWorldPosPrecise = M.LocalToWorldPosPrecise
local client = M.Client or {}
M.Client = client
local geometry = client.geometry or {}
local renderPrimitives = client.RenderPrimitives or include("magic_align/client/render_primitives.lua")
local colors = client.colors or {}
local RENDER_CONFIG = {
    billboardScale = 0.035,
    billboardPush = 0.15,
    circleSegments = 40,
    ringQualityCvar = "magic_align_ring_quality",
    gridLabelPercentCvar = "magic_align_grid_label_percent",
    gridLabelReduceFractionCvar = "magic_align_grid_label_reduce_fraction",
    gridAlphaCvar = "magic_align_grid_alpha",
    previewOccludedCvar = "magic_align_preview_occluded",
    previewOccludedDefaultColor = Color(255, 179, 48, 222),
    wireframeMaterial = Material("models/wireframe")
}
local SHAPE_CONFIG = {
    cacheName = "magic_align_shape",
    rebuildHook = "magic_align_shape_rebuild",
    rebuildCallback = "magic_align_shape_quality",
    materialFlags = bit.bor(16, 32, 128, 2048, 2097152),
    rtPaddingRatio = 1 / 32,
    rtMinPadding = 8,
    ratioQuantization = 256,
    ringThicknessCompensationMax = 0.008,
    ringThicknessCompensationScale = 0.2
}
local STRIPE_CONFIG = {
    rtSize = 64,
    fillAlpha = 100,
    stripeAlpha = 200,
    stripeRatio = 0.5,
    worldTile = 5.5,
    triangleAlphaScale = 0.45,
    occludedReferenceDistance = 100,
    occludedMinScreenScale = 0.01,
    occludedMaxScreenScale = 100,
    occludedScreenParallax = 0.12,
    patternName = "magic_align_stripe_pattern",
    materialFlags = bit.bor(16, 32, 128, 2048, 2097152),
    rebuildHook = "magic_align_stripe_pattern_rebuild"
}
local STATIC_TRIANGLE_STRIPE_PERIOD = math.max(0.01, STRIPE_CONFIG.worldTile * math.sqrt(2))
local GRID_CONFIG = {
    alphaPrimary = 64,
    alphaSecondary = 64,
    snapLineAlpha = 255,
    snapLabelAlpha = 235,
    snapLabelInset = 1.6,
    bspSurfacePush = 0.12,
    bspGlobalAlpha = 255,
    bspGlobalNeighborAlpha = 120
}
client.worldGridRender = client.worldGridRender or {}
client.worldGridRender.queueConfig = client.worldGridRender.queueConfig or {
    defaultBudgetMs = 1.5,
    maxBudgetMs = 3,
    frameBudgetFraction = 0.10,
    fallbackFrameMs = 16.666,
    inactiveJobSeconds = 8,
    maxJobsPerFrame = 24
}
client.worldGridRender.queueConfig.frameBudgetFraction = client.worldGridRender.queueConfig.frameBudgetFraction or 0.10
client.worldGridRender.queueConfig.fallbackFrameMs = client.worldGridRender.queueConfig.fallbackFrameMs or 16.666
client.worldGridRender.rtConfig = client.worldGridRender.rtConfig or {
    cacheName = "magic_align_world_grid",
    baseRtSize = 256,
    referenceStep = 32,
    minRtSize = 16,
    lineWidthStepMin = 0.125,
    lineWidthStepMax = 8,
    lineWidthCapStep = 64,
    lineWidthMin = 0.015625,
    lineWidthMax = 0.25,
    lineRtScale = 2,
    alphaRtVersion = 15,
    maxRtSize = 4096,
    rebuildHook = "magic_align_world_grid_rebuild",
    maxRebuildsPerFrame = 1
}
client.worldGridRender.rtConfig.lineWidthStepMin = client.worldGridRender.rtConfig.lineWidthStepMin or 0.125
client.worldGridRender.rtConfig.lineWidthStepMax = client.worldGridRender.rtConfig.lineWidthStepMax or 8
client.worldGridRender.rtConfig.lineWidthCapStep = client.worldGridRender.rtConfig.lineWidthCapStep or 64
client.worldGridRender.rtConfig.lineWidthMin = client.worldGridRender.rtConfig.lineWidthMin or 0.015625
client.worldGridRender.rtConfig.lineWidthMax = client.worldGridRender.rtConfig.lineWidthMax or 0.25
client.worldGridRender.rtConfig.lineRtScale = client.worldGridRender.rtConfig.lineRtScale or 2
client.worldGridRender.rtConfig.alphaRtVersion = 15
local TRANSLATION_CONFIG = {
    axisTickCount = 21,
    gridHalfCells = 5
}
local ROTATION_CONFIG = {
    ringDefaultSegments = 32,
    ringMinSegments = 8,
    ringMaxSegments = 360,
    ringFillAlpha = 40,
    ringEdgeAlpha = 220,
    ringMinHalfWidth = 0.05,
    deltaSectorAlpha = 76,
    deltaSectorEdgeAlpha = 170
}
local circlePointCache = {}
local unitCircle
local stripePatternTexture
local stripeTrianglePatternTexture
local stripePatternMaterial
local stripeTrianglePatternMaterial
local stripePatternScreenMaterial
local stripePatternReady = false
local shapeCache = {}
local shapeCacheRebuildQueue = {}
local shapeCacheRebuildScheduled = false
client.worldGridRender.rtCache = client.worldGridRender.rtCache or {}
client.worldGridRender.rtRebuildQueue = client.worldGridRender.rtRebuildQueue or {}
client.worldGridRender.rtRebuildScheduled = client.worldGridRender.rtRebuildScheduled or false
client.worldGridRender.bspRenderCache = client.worldGridRender.bspRenderCache or setmetatable({}, { __mode = "k" })
client.worldGridRender.renderQueue = client.worldGridRender.renderQueue or {
    activeJobs = {},
    frame = 0
}
client.worldGridRender.renderQueue.activeJobs = client.worldGridRender.renderQueue.activeJobs or {}
client.worldGridRender.renderQueue.frame = client.worldGridRender.renderQueue.frame or 0
local shapeMetricCache = {}
local shapeWhiteMaterial
local reusableCirclePolyCache = {}
local reusableRingQuad = {
    { x = 0, y = 0, u = 0, v = 0 },
    { x = 0, y = 0, u = 0, v = 0 },
    { x = 0, y = 0, u = 0, v = 0 },
    { x = 0, y = 0, u = 0, v = 0 }
}
local reusableRotationRings = {
    { key = "roll" },
    { key = "pitch" },
    { key = "yaw" }
}
local ensureStripePatternMaterial

local function setStripePatternCopyBlend(enabled)
    render.OverrideAlphaWriteEnable(enabled, true)

    if enabled then
        render.OverrideBlend(true, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD)
    else
        render.OverrideBlend(false)
    end
end

local function drawStripePatternRect(intensity, x, y, width, height)
    intensity = math.Clamp(math.floor(tonumber(intensity) or 0), 0, 255)
    surface.SetDrawColor(intensity, intensity, intensity, intensity)
    surface.DrawRect(x, y, width, height)
end

local function stripePatternStripeSize()
    return math.Clamp(math.floor(STRIPE_CONFIG.rtSize * STRIPE_CONFIG.stripeRatio + 0.5), 1, STRIPE_CONFIG.rtSize)
end

local function drawStripePatternDiagonal(intensity)
    intensity = math.Clamp(math.floor(tonumber(intensity) or 0), 0, 255)
    surface.SetDrawColor(intensity, intensity, intensity, intensity)

    local size = STRIPE_CONFIG.rtSize
    local stripeSize = stripePatternStripeSize()
    for y = 0, size - 1 do
        local startX = (y - stripeSize + 1) % size
        local firstWidth = math.min(stripeSize, size - startX)
        surface.DrawRect(startX, y, firstWidth, 1)

        local wrappedWidth = stripeSize - firstWidth
        if wrappedWidth > 0 then
            surface.DrawRect(0, y, wrappedWidth, 1)
        end
    end
end

local function drawLine(startPos, endPos, color, writeZ)
    startPos = toVector(startPos)
    endPos = toVector(endPos)
    if not startPos or not endPos then return end

    render.DrawLine(startPos, endPos, color, writeZ)
end

local function drawQuad(a, b, c, d, color)
    a = toVector(a)
    b = toVector(b)
    c = toVector(c)
    d = toVector(d)
    if not a or not b or not c or not d then return end

    render.DrawQuad(a, b, c, d, color)
end

local function meshPosition(position)
    position = toVector(position)
    if not position then return end

    mesh.Position(position)
end

local renderAnchorOptionCache = {}

local function anchorOptions(tool, side)
    if not tool then return nil end

    local cache = renderAnchorOptionCache[side]
    if not cache then
        cache = { options = {} }
        renderAnchorOptionCache[side] = cache
    end

    local prefix = side
    if prefix ~= "" and not string.EndsWith(prefix, "_") then
        prefix = prefix .. "_"
    end

    local mid12 = M.ClampAnchorPercent(tool:GetClientInfo(prefix .. "mid12_pct"))
    local mid23 = M.ClampAnchorPercent(tool:GetClientInfo(prefix .. "mid23_pct"))
    local mid13 = M.ClampAnchorPercent(tool:GetClientInfo(prefix .. "mid13_pct"))

    if cache.tool ~= tool
        or cache.options.mid12_pct ~= mid12
        or cache.options.mid23_pct ~= mid23
        or cache.options.mid13_pct ~= mid13 then
        cache.tool = tool
        cache.options.mid12_pct = mid12
        cache.options.mid23_pct = mid23
        cache.options.mid13_pct = mid13
    end

    return cache.options
end

local function circlePointsForSegments(segments)
    segments = math.max(math.Round(tonumber(segments) or RENDER_CONFIG.circleSegments), 3)

    local points = circlePointCache[segments]
    if points then
        return points
    end

    points = {}
    for i = 0, segments do
        local rad = math.rad((i / segments) * 360)
        points[i + 1] = { x = math.cos(rad), y = math.sin(rad) }
    end

    circlePointCache[segments] = points
    return points
end

unitCircle = circlePointsForSegments(RENDER_CONFIG.circleSegments)

local ZERO_VEC = VectorP(0, 0, 0)
local ZERO_ANG = AngleP(0, 0, 0)
local DEG_TO_RAD = math.pi / 180

local function numberOrZero(value)
    value = tonumber(value)
    if value ~= nil and value == value and value ~= math.huge and value ~= -math.huge then
        return value
    end

    return 0
end

local function newRenderVector(x, y, z)
    x, y, z = numberOrZero(x), numberOrZero(y), numberOrZero(z)
    return Vector(x, y, z)
end

local reusableBillboardToViewer = newRenderVector(0, 0, 1)
local reusableBillboardPos = newRenderVector(0, 0, 0)

local function setVecComponents(out, x, y, z)
    if not isvector(out) then
        return newRenderVector(x, y, z)
    end

    out.x, out.y, out.z = x, y, z
    return out
end

local function setVec(out, value)
    if not isvector(value) then return end

    if not isvector(out) then
        return newRenderVector(value.x, value.y, value.z)
    end

    out.x, out.y, out.z = value.x, value.y, value.z
    return out
end

local function localToWorldPosInto(out, localPos, originPos, originAng)
    originPos = isvector(originPos) and originPos or ZERO_VEC
    originAng = isangle(originAng) and originAng or ZERO_ANG

    local x = isvector(localPos) and numberOrZero(localPos.x) or 0
    local y = isvector(localPos) and numberOrZero(localPos.y) or 0
    local z = isvector(localPos) and numberOrZero(localPos.z) or 0
    local pitch = numberOrZero(originAng.p)
    local yaw = numberOrZero(originAng.y)
    local roll = numberOrZero(originAng.r)
    local sp, sy, sr = math.sin(pitch * DEG_TO_RAD), math.sin(yaw * DEG_TO_RAD), math.sin(roll * DEG_TO_RAD)
    local cp, cy, cr = math.cos(pitch * DEG_TO_RAD), math.cos(yaw * DEG_TO_RAD), math.cos(roll * DEG_TO_RAD)

    return setVecComponents(
        out,
        numberOrZero(originPos.x) + (cp * cy) * x + (sp * sr * cy - cr * sy) * y + (sp * cr * cy + sr * sy) * z,
        numberOrZero(originPos.y) + (cp * sy) * x + (sp * sr * sy + cr * cy) * y + (sp * cr * sy - sr * cy) * z,
        numberOrZero(originPos.z) + (-sp) * x + (sr * cp) * y + (cr * cp) * z
    )
end

function client.worldGridRender.setRenderVector(out, x, y, z)
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    z = tonumber(z) or 0

    if not isvector(out) then
        return newRenderVector(x, y, z)
    end

    out.x, out.y, out.z = x, y, z
    return out
end

local cachedColors = {}

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

local function colorAlpha(color, alpha)
    return cachedColor(color.r, color.g, color.b, alpha == nil and color.a or alpha)
end

local function cappedAlpha(color, alpha)
    local baseAlpha = color.a == nil and 255 or color.a
    return cachedColor(color.r, color.g, color.b, math.min(baseAlpha, alpha))
end

local function scaledAlphaColor(color, scale)
    local baseAlpha = color.a == nil and 255 or color.a
    return cachedColor(color.r, color.g, color.b, math.Clamp(math.floor(baseAlpha * scale + 0.5), 0, 255))
end

local function prop2BlueColor(alpha)
    local palette = client.colors or colors
    local target = palette and palette.target or colors.target

    return cachedColor(
        target and target.r or 80,
        target and target.g or 220,
        target and target.b or 255,
        alpha
    )
end

local function clampUnitInterval(value)
    return math.Clamp(tonumber(value) or 0, 0, 1)
end

local function ringQualityIndex(tool)
    local raw = tool and tool.GetClientNumber and tool:GetClientNumber("ring_quality") or client.defaultRingQualityIndex
    return math.Clamp(math.Round(tonumber(raw) or client.defaultRingQualityIndex), 1, math.max(#client.ringQualityPresets, 1))
end

local function ringRenderSettingsForIndex(index)
    index = math.Clamp(math.Round(tonumber(index) or client.defaultRingQualityIndex), 1, math.max(#client.ringQualityPresets, 1))

    return client.ringQualityPresets[index]
        or client.ringQualityPresets[client.defaultRingQualityIndex]
        or client.ringQualityPresets[1]
end

local function ringRenderSettingsForTool(tool)
    return ringRenderSettingsForIndex(ringQualityIndex(tool))
end

local function activeRingRenderSettings()
    local tool = select(1, client.activeTool())
    return ringRenderSettingsForTool(tool)
end

local function ringRtSize(settings)
    return settings and (settings.ringRtSize or settings.rtSize) or nil
end

local function scaleCircleResolutionValue(value, minValue)
    value = tonumber(value)
    if value == nil then return end

    return math.max(math.floor(value * 0.25 + 0.5), minValue or 1)
end

local function circleSpriteRtSize(settings)
    if not settings then return end

    local raw = settings.circleRtSize
    if raw ~= nil then
        return math.max(math.Round(tonumber(raw) or 0), 1)
    end

    return scaleCircleResolutionValue(settings.ringRtSize or settings.rtSize, 1)
end

local function ringRenderSegments(settings)
    local raw = settings and (settings.ringSegments or settings.segments) or ROTATION_CONFIG.ringDefaultSegments
    return math.Clamp(math.Round(tonumber(raw) or ROTATION_CONFIG.ringDefaultSegments), ROTATION_CONFIG.ringMinSegments, ROTATION_CONFIG.ringMaxSegments)
end

local function circleSpriteSegments(settings)
    if settings and settings.circleSegments ~= nil then
        return math.max(math.Round(tonumber(settings.circleSegments) or RENDER_CONFIG.circleSegments), 3)
    end

    local derived = settings and scaleCircleResolutionValue(settings.ringSegments or settings.segments, 3) or nil
    if derived then
        return derived
    end

    return math.max(math.Round(RENDER_CONFIG.circleSegments), 3)
end

local function rotationRingTickLimit(settings, divisions)
    local raw = settings and settings.tickCount or client.rotationSnapMaxVisibleTicks
    return math.Clamp(math.Round(tonumber(raw) or client.rotationSnapMaxVisibleTicks), 1, math.max(math.Round(tonumber(divisions) or 0), 1))
end

local function quantizeShapeRatio(value)
    value = clampUnitInterval(value)
    return math.Clamp(math.Round(value * SHAPE_CONFIG.ratioQuantization) / SHAPE_CONFIG.ratioQuantization, 0, 1)
end

local function compensatedInnerRatio(innerRatio)
    innerRatio = clampUnitInterval(innerRatio)
    if innerRatio <= 0 then
        return 0
    end

    local thicknessRatio = math.Clamp(1 - innerRatio, 0, 1)
    thicknessRatio = math.Clamp(
        thicknessRatio + math.min(SHAPE_CONFIG.ringThicknessCompensationMax, thicknessRatio * SHAPE_CONFIG.ringThicknessCompensationScale),
        0,
        1
    )

    return math.Clamp(1 - thicknessRatio, 0, 1)
end

local function resolvedRingInnerRadius(innerRadius, outerRadius)
    outerRadius = math.max(tonumber(outerRadius) or 0, 0)
    if outerRadius <= 0 then
        return 0
    end

    innerRadius = math.Clamp(tonumber(innerRadius) or 0, 0, outerRadius)
    local innerRatio = quantizeShapeRatio(compensatedInnerRatio(innerRadius / outerRadius))
    return outerRadius * innerRatio
end

local function shapeMetricsForRtSize(rtSize)
    rtSize = math.max(math.Round(tonumber(rtSize) or 0), 1)

    local metrics = shapeMetricCache[rtSize]
    if metrics then
        return metrics
    end

    local halfSize = rtSize * 0.5
    local padding = math.max(math.floor(rtSize * SHAPE_CONFIG.rtPaddingRatio + 0.5), SHAPE_CONFIG.rtMinPadding)
    local outerRadius = math.max(halfSize - padding, 1)

    metrics = {
        rtSize = rtSize,
        halfSize = halfSize,
        padding = padding,
        outerRadius = outerRadius,
        worldScale = halfSize / outerRadius,
        segments = math.max(math.floor(rtSize / 32 + 0.5), RENDER_CONFIG.circleSegments)
    }

    shapeMetricCache[rtSize] = metrics
    return metrics
end

local function reusableCirclePoly(points)
    local key = #points
    local poly = reusableCirclePolyCache[key]
    if poly then
        return poly
    end

    poly = {}
    for i = 1, key + 1 do
        poly[i] = { x = 0, y = 0, u = 0, v = 0 }
    end

    reusableCirclePolyCache[key] = poly
    return poly
end

local function drawCircle2DAt(centerX, centerY, radius, color, points)
    radius = tonumber(radius) or 0
    if radius <= 0 then return end

    points = points or unitCircle
    centerX = tonumber(centerX) or 0
    centerY = tonumber(centerY) or 0

    local poly = reusableCirclePoly(points)
    poly[1].x = centerX
    poly[1].y = centerY
    poly[1].u = 0.5
    poly[1].v = 0.5

    for i = 1, #points do
        local point = points[i]
        local vertex = poly[i + 1]
        vertex.x = centerX + point.x * radius
        vertex.y = centerY + point.y * radius
        vertex.u = 0.5 + point.x * 0.5
        vertex.v = 0.5 + point.y * 0.5
    end

    surface.SetDrawColor(color)
    surface.DrawPoly(poly)
end

local function drawRing2DByRadiiAt(centerX, centerY, outerRadius, innerRadius, color, points)
    outerRadius = tonumber(outerRadius) or 0
    innerRadius = math.Clamp(tonumber(innerRadius) or 0, 0, outerRadius)
    if outerRadius <= 0 or innerRadius >= outerRadius then return end

    points = points or unitCircle
    centerX = tonumber(centerX) or 0
    centerY = tonumber(centerY) or 0

    surface.SetDrawColor(color)

    for i = 1, #points - 1 do
        local a = points[i]
        local b = points[i + 1]

        reusableRingQuad[1].x = centerX + a.x * outerRadius
        reusableRingQuad[1].y = centerY + a.y * outerRadius
        reusableRingQuad[1].u = 0.5 + a.x * 0.5
        reusableRingQuad[1].v = 0.5 + a.y * 0.5
        reusableRingQuad[2].x = centerX + b.x * outerRadius
        reusableRingQuad[2].y = centerY + b.y * outerRadius
        reusableRingQuad[2].u = 0.5 + b.x * 0.5
        reusableRingQuad[2].v = 0.5 + b.y * 0.5
        reusableRingQuad[3].x = centerX + b.x * innerRadius
        reusableRingQuad[3].y = centerY + b.y * innerRadius
        reusableRingQuad[3].u = 0.5 + b.x * 0.5
        reusableRingQuad[3].v = 0.5 + b.y * 0.5
        reusableRingQuad[4].x = centerX + a.x * innerRadius
        reusableRingQuad[4].y = centerY + a.y * innerRadius
        reusableRingQuad[4].u = 0.5 + a.x * 0.5
        reusableRingQuad[4].v = 0.5 + a.y * 0.5
        surface.DrawPoly(reusableRingQuad)
    end
end

local function ensureShapeWhiteMaterial()
    if not shapeWhiteMaterial then
        shapeWhiteMaterial = CreateMaterial(SHAPE_CONFIG.cacheName .. "_white_mat", "UnlitGeneric", {
            ["$basetexture"] = "vgui/white",
            ["$translucent"] = "1",
            ["$additive"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1",
            ["$nocull"] = "1",
            ["$model"] = "1"
        })
    end

    local materialFlags = shapeWhiteMaterial:GetInt("$flags") or 0
    local requiredFlags = bit.bor(materialFlags, SHAPE_CONFIG.materialFlags)
    if materialFlags ~= requiredFlags then
        shapeWhiteMaterial:SetInt("$flags", requiredFlags)
    end

    return shapeWhiteMaterial
end

local function buildShapeCacheKey(shapeKind, rtSize, innerRatio, segments)
    segments = math.max(math.Round(tonumber(segments) or 0), 0)

    if innerRatio == nil then
        return ("%s_%d_%d"):format(shapeKind, rtSize, segments)
    end

    return ("%s_%d_%d_%d"):format(shapeKind, rtSize, math.Round(innerRatio * SHAPE_CONFIG.ratioQuantization), segments)
end

local function rebuildShapeCacheEntry(entry)
    if not entry or not entry.texture or not entry.metrics then return end

    local metrics = entry.metrics
    local center = metrics.halfSize
    local outerRadius = metrics.outerRadius
    local points = circlePointsForSegments(entry.segments or metrics.segments)

    render.PushRenderTarget(entry.texture)
    render.Clear(0, 0, 0, 0, true, true)
    cam.Start2D()
        draw.NoTexture()

        if entry.shapeKind == "disc" then
            drawCircle2DAt(center, center, outerRadius, color_white, points)
        elseif entry.shapeKind == "ring" then
            drawRing2DByRadiiAt(center, center, outerRadius, outerRadius * (entry.innerRatio or 0), color_white, points)
        elseif entry.shapeKind == "ring_band" then
            local innerRadius = outerRadius * (entry.innerRatio or 0)
            local bandThickness = math.max(outerRadius - innerRadius, 1)
            local edgeThickness = math.min(math.max(math.floor(metrics.rtSize / 512 + 0.5), 1), bandThickness * 0.5)

            drawRing2DByRadiiAt(center, center, outerRadius, innerRadius, Color(255, 255, 255, ROTATION_CONFIG.ringFillAlpha), points)
            drawRing2DByRadiiAt(center, center, outerRadius, math.max(innerRadius, outerRadius - edgeThickness), Color(255, 255, 255, ROTATION_CONFIG.ringEdgeAlpha), points)
            drawRing2DByRadiiAt(center, center, math.min(outerRadius, innerRadius + edgeThickness), innerRadius, Color(255, 255, 255, ROTATION_CONFIG.ringEdgeAlpha), points)
        end
    cam.End2D()
    render.PopRenderTarget()

    entry.ready = true
end

local function scheduleShapeCacheRebuild()
    if shapeCacheRebuildScheduled then return end

    shapeCacheRebuildScheduled = true
    hook.Add("PostRender", SHAPE_CONFIG.rebuildHook, function()
        shapeCacheRebuildScheduled = false

        for entry in pairs(shapeCacheRebuildQueue) do
            shapeCacheRebuildQueue[entry] = nil
            rebuildShapeCacheEntry(entry)
        end

        if next(shapeCacheRebuildQueue) then
            scheduleShapeCacheRebuild()
        else
            hook.Remove("PostRender", SHAPE_CONFIG.rebuildHook)
        end
    end)
end

local function queueShapeCacheEntryRebuild(entry)
    if not entry or entry.ready then return end

    shapeCacheRebuildQueue[entry] = true
    scheduleShapeCacheRebuild()
end

local function ensureCachedShape(shapeKind, rtSize, innerRatio, segments)
    rtSize = math.max(math.Round(tonumber(rtSize) or 0), 1)
    if rtSize <= 0 then return end

    if innerRatio ~= nil then
        innerRatio = quantizeShapeRatio(innerRatio)
    end

    local metrics = shapeMetricsForRtSize(rtSize)
    segments = math.max(math.Round(tonumber(segments) or metrics.segments), 3)

    local cacheKey = buildShapeCacheKey(shapeKind, rtSize, innerRatio, segments)
    local entry = shapeCache[cacheKey]
    if not entry then
        local texture = GetRenderTargetEx(
            SHAPE_CONFIG.cacheName .. "_" .. cacheKey .. "_rt",
            rtSize,
            rtSize,
            RT_SIZE_NO_CHANGE,
            MATERIAL_RT_DEPTH_NONE,
            0,
            0,
            IMAGE_FORMAT_RGBA8888
        )
        local material = CreateMaterial(SHAPE_CONFIG.cacheName .. "_" .. cacheKey .. "_mat", "UnlitGeneric", {
            ["$basetexture"] = texture:GetName(),
            ["$translucent"] = "1",
            ["$additive"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1",
            ["$nocull"] = "1",
            ["$model"] = "1"
        })

        entry = {
            cacheKey = cacheKey,
            shapeKind = shapeKind,
            innerRatio = innerRatio,
            metrics = metrics,
            segments = segments,
            texture = texture,
            material = material,
            ready = false
        }

        shapeCache[cacheKey] = entry
    end

    entry.material:SetTexture("$basetexture", entry.texture)
    local materialFlags = entry.material:GetInt("$flags") or 0
    local requiredFlags = bit.bor(materialFlags, SHAPE_CONFIG.materialFlags)
    if materialFlags ~= requiredFlags then
        entry.material:SetInt("$flags", requiredFlags)
    end

    if not entry.ready then
        queueShapeCacheEntryRebuild(entry)
        return
    end

    return entry
end

local function drawCachedShapeRect2D(outerRadius, entry, color)
    if not entry or not entry.material or not entry.metrics then return false end

    outerRadius = tonumber(outerRadius) or 0
    if outerRadius <= 0 then return false end

    local rectHalfSize = outerRadius * entry.metrics.worldScale
    local rectSize = rectHalfSize * 2

    surface.SetMaterial(entry.material)
    surface.SetDrawColor(color)
    surface.DrawTexturedRect(-rectHalfSize, -rectHalfSize, rectSize, rectSize)
    return true
end

local function ensureCachedCircleSprite(settings, outerRadius, innerRadius, rtSizeOverride, segmentsOverride)
    local rtSize = rtSizeOverride or circleSpriteRtSize(settings)
    if not settings or settings.realtime or not rtSize then return end

    outerRadius = tonumber(outerRadius) or 0
    if outerRadius <= 0 then return end

    local segments = segmentsOverride or circleSpriteSegments(settings)
    return ensureCachedShape("disc", rtSize, nil, segments),
        ensureCachedShape("ring", rtSize, innerRadius / math.max(outerRadius, 1e-6), segments)
end

local function drawCachedCircleSpriteRect2D(outerRadius, fillEntry, outlineEntry, color)
    if not fillEntry or not outlineEntry then return false end

    drawCachedShapeRect2D(outerRadius, fillEntry, cappedAlpha(color, 220))
    drawCachedShapeRect2D(outerRadius, outlineEntry, cappedAlpha(color, 255))
    return true
end

local function pushTexturedWorldVertex(position, u, v, color)
    meshPosition(position)
    mesh.TexCoord(0, u, v)
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()
end

local function drawTexturedWorldQuad(a, b, c, d, color, material, doubleSided)
    if not material then return false end

    render.SetMaterial(material)
    mesh.Begin(MATERIAL_TRIANGLES, doubleSided and 4 or 2)
        pushTexturedWorldVertex(a, 0, 0, color)
        pushTexturedWorldVertex(b, 1, 0, color)
        pushTexturedWorldVertex(c, 1, 1, color)

        pushTexturedWorldVertex(a, 0, 0, color)
        pushTexturedWorldVertex(c, 1, 1, color)
        pushTexturedWorldVertex(d, 0, 1, color)

        if doubleSided then
            pushTexturedWorldVertex(c, 1, 1, color)
            pushTexturedWorldVertex(b, 1, 0, color)
            pushTexturedWorldVertex(a, 0, 0, color)

            pushTexturedWorldVertex(d, 0, 1, color)
            pushTexturedWorldVertex(c, 1, 1, color)
            pushTexturedWorldVertex(a, 0, 0, color)
        end
    mesh.End()

    return true
end

local function drawCachedShapePlane(origin, axisA, axisB, outerRadius, entry, color, doubleSided)
    if not isvector(origin) or not isvector(axisA) or not isvector(axisB) then return false end
    if axisA:LengthSqr() < 1e-8 or axisB:LengthSqr() < 1e-8 then return false end
    if not entry or not entry.metrics then return false end

    outerRadius = tonumber(outerRadius) or 0
    if outerRadius <= 0 then return false end

    local halfSize = outerRadius * entry.metrics.worldScale
    local axisX = axisA:GetNormalized() * halfSize
    local axisY = axisB:GetNormalized() * halfSize

    return drawTexturedWorldQuad(
        origin - axisX - axisY,
        origin + axisX - axisY,
        origin + axisX + axisY,
        origin - axisX + axisY,
        color,
        entry.material,
        doubleSided
    )
end

function client.worldGridRender.isWorldGridLineMode(lineMode)
    return lineMode == "line_u" or lineMode == "line_v"
end

function client.worldGridRender.worldGridRtSize(step)
    local rtConfig = client.worldGridRender.rtConfig
    step = math.max(tonumber(step) or rtConfig.referenceStep, 0.001)
    local referenceStep = rtConfig.referenceStep
    local scale = step / referenceStep
    local lineWidthStepMin = rtConfig.lineWidthStepMin or 0.125
    local lineWidthStepMax = rtConfig.lineWidthStepMax or 8
    local rtSize

    if step >= lineWidthStepMin and step < lineWidthStepMax then
        local range = math.max(lineWidthStepMax - lineWidthStepMin, 1e-6)
        local t = math.Clamp((step - lineWidthStepMin) / range, 0, 1)
        local minLineWidth = rtConfig.lineWidthMin or 0.015625
        local lineWidth = minLineWidth + ((rtConfig.lineWidthMax or 0.25) - minLineWidth) * t
        rtSize = math.Clamp(
            math.floor((step * 2) / math.max(lineWidth, 1e-6) + 0.5),
            1,
            rtConfig.baseRtSize
        )
    elseif step >= lineWidthStepMax then
        rtSize = math.floor((lineWidthStepMax * 2) / math.max(rtConfig.lineWidthMax or 0.25, 1e-6) + 0.5)
        local lineWidthCapStep = math.max(tonumber(rtConfig.lineWidthCapStep) or 64, lineWidthStepMax)
        if step >= lineWidthCapStep then
            local snappedStep = lineWidthCapStep
            while snappedStep < step and snappedStep < (rtConfig.maxRtSize or 4096) * lineWidthCapStep do
                snappedStep = snappedStep * 2
            end

            rtSize = math.floor(rtSize * (snappedStep / lineWidthCapStep) + 0.5)
        end

        rtSize = math.Clamp(rtSize, 1, rtConfig.maxRtSize or rtConfig.baseRtSize)
    else
        rtSize = math.Clamp(
            math.floor(rtConfig.baseRtSize * scale + 0.5),
            rtConfig.minRtSize,
            rtConfig.baseRtSize
        )
    end

    return rtSize
end

function client.worldGridRender.worldGridRtDimensions(step, lineMode)
    local rtConfig = client.worldGridRender.rtConfig
    local baseSize = client.worldGridRender.worldGridRtSize(step)
    if not client.worldGridRender.isWorldGridLineMode(lineMode) then
        return baseSize, baseSize
    end

    local lineSize = math.Clamp(
        math.floor(baseSize * math.max(tonumber(rtConfig.lineRtScale) or 2, 1) + 0.5),
        1,
        rtConfig.maxRtSize or baseSize
    )

    if lineMode == "line_u" then
        return lineSize, baseSize
    end

    return baseSize, lineSize
end

function client.worldGridRender.pushWorldGridTextureFilter()
    local pushedMin = false
    local pushedMag = false
    render.PushFilterMin(TEXFILTER.POINT)
    pushedMin = true
    render.PushFilterMag(TEXFILTER.POINT)
    pushedMag = true

    return pushedMin, pushedMag
end

function client.worldGridRender.popWorldGridTextureFilter(pushedMin, pushedMag)
    if pushedMag then
        render.PopFilterMag()
    end
    if pushedMin then
        render.PopFilterMin()
    end
end

function client.worldGridRender.drawWorldGridRtLines(width, height, lineMode, thin)
    width = math.max(math.floor(tonumber(width) or 0), 1)
    height = math.max(math.floor(tonumber(height) or width), 1)

    local maxX = width - 1
    local maxY = height - 1
    local xTwelfth = math.Clamp(math.floor(maxX / 12 + 0.5), 0, maxX)
    local yTwelfth = math.Clamp(math.floor(maxY / 12 + 0.5), 0, maxY)
    local xElevenTwelfths = math.Clamp(math.floor(maxX * 11 / 12 + 0.5), 0, maxX)
    local yElevenTwelfths = math.Clamp(math.floor(maxY * 11 / 12 + 0.5), 0, maxY)
    local xCenterStart = math.Clamp(math.floor(maxX * 11 / 24 + 0.5), 0, maxX)
    local xCenterEnd = math.Clamp(math.floor(maxX * 13 / 24 + 0.5), 0, maxX)
    local yCenterStart = math.Clamp(math.floor(maxY * 11 / 24 + 0.5), 0, maxY)
    local yCenterEnd = math.Clamp(math.floor(maxY * 13 / 24 + 0.5), 0, maxY)
    local centerXA = math.Clamp(math.floor(width * 0.5 - 0.5), 0, maxX)
    local centerXB = math.Clamp(centerXA + 1, 0, maxX)
    local centerYA = math.Clamp(math.floor(height * 0.5 - 0.5), 0, maxY)
    local centerYB = math.Clamp(centerYA + 1, 0, maxY)
    local centerXSpan = math.max(xCenterEnd - xCenterStart + 1, 1)
    local centerYSpan = math.max(yCenterEnd - yCenterStart + 1, 1)
    local hybridXNearLength = math.max(math.floor(centerXSpan * 0.5), 1)
    local hybridYNearLength = math.max(math.floor(centerYSpan * 0.5), 1)
    local hybridXFarLength = math.max(centerXSpan - hybridXNearLength, 1)
    local hybridYFarLength = math.max(centerYSpan - hybridYNearLength, 1)
    local hybridXEnd = math.Clamp(hybridXNearLength - 1, 0, maxX)
    local hybridYEnd = math.Clamp(hybridYNearLength - 1, 0, maxY)
    local hybridXStart = math.Clamp(maxX - hybridXFarLength + 1, 0, maxX)
    local hybridYStart = math.Clamp(maxY - hybridYFarLength + 1, 0, maxY)
    local edgeOffsetY = math.min(1, maxY)
    local drawU = lineMode ~= "v"
    local drawV = lineMode ~= "u"
    local crossOnly = lineMode == "cross"

    local function drawHorizontal(y, x0, x1)
        y = math.Clamp(math.floor(y + 0.5), 0, maxY)
        x0 = math.Clamp(math.floor(x0 + 0.5), 0, maxX)
        x1 = math.Clamp(math.floor(x1 + 0.5), 0, maxX)
        if x1 < x0 then x0, x1 = x1, x0 end

        surface.DrawRect(x0, y, x1 - x0 + 1, 1)
    end

    local function drawVertical(x, y0, y1)
        x = math.Clamp(math.floor(x + 0.5), 0, maxX)
        y0 = math.Clamp(math.floor(y0 + 0.5), 0, maxY)
        y1 = math.Clamp(math.floor(y1 + 0.5), 0, maxY)
        if y1 < y0 then y0, y1 = y1, y0 end

        surface.DrawRect(x, y0, 1, y1 - y0 + 1)
    end

    local lineOnlyU = lineMode == "line_u"
    local lineOnlyV = lineMode == "line_v"
    if lineOnlyU or lineOnlyV then
        surface.SetDrawColor(0, 0, 0, 255)
        if lineOnlyU then
            drawVertical(0, 0, maxY)
            drawVertical(centerXB, 0, maxY)
        end
        if lineOnlyV then
            drawHorizontal(maxY, 0, maxX)
            drawHorizontal(centerYA, 0, maxX)
        end

        surface.SetDrawColor(255, 255, 255, 255)
        if lineOnlyU then
            drawVertical(maxX, 0, maxY)
            drawVertical(centerXA, 0, maxY)
        end
        if lineOnlyV then
            drawHorizontal(0, 0, maxX)
            drawHorizontal(centerYB, 0, maxX)
        end

        surface.SetDrawColor(0, 0, 0, 255)
        if lineOnlyU then
            drawVertical(0, 0, maxY)
            drawVertical(centerXB, 0, maxY)
        end
        return
    end

    local function drawEdgeHorizontal(y)
        if crossOnly then
            drawHorizontal(y, 0, xTwelfth)
            drawHorizontal(y, xElevenTwelfths, maxX)
        else
            drawHorizontal(y, 0, maxX)
        end
    end

    local function drawEdgeVertical(x, includeCorner)
        local y0 = includeCorner and 0 or edgeOffsetY
        if crossOnly then
            drawVertical(x, y0, yTwelfth)
            drawVertical(x, yElevenTwelfths, maxY)
        else
            drawVertical(x, y0, maxY)
        end
    end

    local function drawCornerHorizontalShadow()
        if drawV then
            drawEdgeHorizontal(maxY)
        end
    end

    local function drawCornerHorizontalLight()
        if drawV then
            drawEdgeHorizontal(0)
        end
    end

    local function drawCornerVerticalShadow()
        if drawU then
            drawEdgeVertical(0, false)
        end
    end

    local function drawCornerVerticalShadowForeground()
        if drawU then
            drawEdgeVertical(0, true)
        end
    end

    local function drawCornerVerticalLight()
        if drawU then
            drawEdgeVertical(maxX, false)
        end
    end

    local function drawHorizontalHalfVerticalShadow()
        if drawU then
            drawVertical(centerXB, 0, hybridYEnd)
            drawVertical(centerXB, hybridYStart, maxY)
        end
    end

    local function drawHorizontalEdgeVerticalShadowForeground()
        if drawU then
            drawVertical(centerXB, 0, hybridYEnd)
            drawVertical(centerXB, hybridYStart, maxY)
        end
    end

    local function drawHorizontalHalfVerticalLight()
        if drawU then
            drawVertical(centerXA, 0, hybridYEnd)
            drawVertical(centerXA, hybridYStart, maxY)
        end
    end

    local function drawHorizontalHalfHorizontalShadow()
        if drawV then
            drawHorizontal(maxY, xCenterStart, xCenterEnd)
        end
    end

    local function drawHorizontalHalfHorizontalLight()
        if drawV then
            drawHorizontal(0, xCenterStart, xCenterEnd)
        end
    end

    local function drawVerticalHalfHorizontalShadow()
        if drawV then
            drawHorizontal(centerYA, 0, hybridXEnd)
            drawHorizontal(centerYA, hybridXStart, maxX)
        end
    end

    local function drawVerticalHalfHorizontalLight()
        if drawV then
            drawHorizontal(centerYB, 0, hybridXEnd)
            drawHorizontal(centerYB, hybridXStart, maxX)
        end
    end

    local function drawVerticalHalfVerticalShadow()
        if drawU then
            drawVertical(0, yCenterStart, yCenterEnd)
        end
    end

    local function drawVerticalHalfVerticalLight()
        if drawU then
            drawVertical(maxX, yCenterStart, yCenterEnd)
        end
    end

    local function drawCenterHorizontalShadow()
        if drawV then
            drawHorizontal(centerYA, xCenterStart, xCenterEnd)
        end
    end

    local function drawCenterHorizontalLight()
        if drawV then
            drawHorizontal(centerYB, xCenterStart, xCenterEnd)
        end
    end

    local function drawCenterVerticalShadow()
        if drawU then
            drawVertical(centerXB, yCenterStart, yCenterEnd)
        end
    end

    local function drawCenterVerticalLight()
        if drawU then
            drawVertical(centerXA, yCenterStart, yCenterEnd)
        end
    end

    surface.SetDrawColor(0, 0, 0, 255)
    drawCornerHorizontalShadow()
    drawHorizontalHalfHorizontalShadow()
    drawVerticalHalfHorizontalShadow()
    drawCenterHorizontalShadow()

    surface.SetDrawColor(255, 255, 255, 255)
    drawCornerHorizontalLight()
    drawHorizontalHalfHorizontalLight()
    drawVerticalHalfHorizontalLight()
    drawCenterHorizontalLight()

    surface.SetDrawColor(0, 0, 0, 255)
    drawCornerVerticalShadow()
    drawHorizontalHalfVerticalShadow()
    drawVerticalHalfVerticalShadow()

    surface.SetDrawColor(255, 255, 255, 255)
    drawCornerVerticalLight()
    drawHorizontalHalfVerticalLight()
    drawVerticalHalfVerticalLight()
    drawCenterVerticalLight()

    surface.SetDrawColor(0, 0, 0, 255)
    drawCornerVerticalShadowForeground()
    drawHorizontalEdgeVerticalShadowForeground()
    drawVerticalHalfVerticalShadow()
    drawCenterVerticalShadow()
end

function client.worldGridRender.rebuildWorldGridRtEntry(entry)
    if not entry or not entry.texture then return end

    render.SetWriteDepthToDestAlpha(false)

    render.PushRenderTarget(entry.texture)
    render.OverrideAlphaWriteEnable(true, true)
    render.ClearDepth()
    render.Clear(0, 0, 0, 0)
    cam.Start2D()
        draw.NoTexture()
        setStripePatternCopyBlend(true)
        client.worldGridRender.drawWorldGridRtLines(entry.rtWidth or entry.rtSize, entry.rtHeight or entry.rtSize, entry.lineMode, entry.thin)
        setStripePatternCopyBlend(false)
    cam.End2D()
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()

    render.SetWriteDepthToDestAlpha(true)

    entry.ready = true
end

function client.worldGridRender.scheduleWorldGridRtRebuild()
    local rtConfig = client.worldGridRender.rtConfig
    if client.worldGridRender.rtRebuildScheduled then return end

    client.worldGridRender.rtRebuildScheduled = true
    hook.Add("PostRender", rtConfig.rebuildHook, function()
        client.worldGridRender.rtRebuildScheduled = false

        local rebuilt = 0
        for entry in pairs(client.worldGridRender.rtRebuildQueue) do
            client.worldGridRender.rtRebuildQueue[entry] = nil
            client.worldGridRender.rebuildWorldGridRtEntry(entry)

            rebuilt = rebuilt + 1
            if rebuilt >= rtConfig.maxRebuildsPerFrame then
                break
            end
        end

        if next(client.worldGridRender.rtRebuildQueue) then
            client.worldGridRender.scheduleWorldGridRtRebuild()
        else
            hook.Remove("PostRender", rtConfig.rebuildHook)
        end
    end)
end

function client.worldGridRender.queueWorldGridRtEntryRebuild(entry)
    if not entry or entry.ready then return end

    client.worldGridRender.rtRebuildQueue[entry] = true
    client.worldGridRender.scheduleWorldGridRtRebuild()
end

function client.worldGridRender.ensureWorldGridMaterial(step, lineMode)
    local rtConfig = client.worldGridRender.rtConfig
    lineMode = lineMode or "full"
    local rtWidth, rtHeight = client.worldGridRender.worldGridRtDimensions(step, lineMode)
    local thin = (tonumber(step) or 0) < rtConfig.referenceStep
    local cacheKey = ("%dx%d_%s_%s_a%d"):format(rtWidth, rtHeight, lineMode, thin and "thin" or "normal", rtConfig.alphaRtVersion or 0)
    local entry = client.worldGridRender.rtCache[cacheKey]

    if not entry then
        local textureFlags = bit.bor(1, 256, 512, 8192)
        local texture = GetRenderTargetEx(
            rtConfig.cacheName .. "_" .. cacheKey .. "_rt",
            rtWidth,
            rtHeight,
            RT_SIZE_NO_CHANGE,
            MATERIAL_RT_DEPTH_NONE,
            textureFlags,
            0,
            IMAGE_FORMAT_BGRA8888 or 12
        )
        local material = CreateMaterial(rtConfig.cacheName .. "_" .. cacheKey .. "_mat", "UnlitGeneric", {
            ["$basetexture"] = texture:GetName(),
            ["$translucent"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1",
            ["$decal"] = "1",
            ["$nocull"] = "1",
            ["$model"] = "1"
        })

        entry = {
            texture = texture,
            material = material,
            rtSize = math.max(rtWidth, rtHeight),
            rtWidth = rtWidth,
            rtHeight = rtHeight,
            lineMode = lineMode,
            thin = thin,
            ready = false
        }

        client.worldGridRender.rtCache[cacheKey] = entry
    end

    entry.material:SetTexture("$basetexture", entry.texture)
    entry.material:SetInt("$decal", 1)
    entry.material:SetInt("$nocull", 1)

    if not entry.ready then
        client.worldGridRender.queueWorldGridRtEntryRebuild(entry)
    end

    return entry.material, entry
end

function client.worldGridRender.axisComponent(value, axisKey)
    if not isvector(value) then return 0 end
    if axisKey == "x" then return value.x end
    if axisKey == "y" then return value.y end
    return value.z
end

function client.worldGridRender.ensureWorldBspRenderData(surfaceData)
    local vertices = surfaceData and surfaceData.vertices
    if not istable(vertices) or #vertices == 0 then return end

    local entry = client.worldGridRender.bspRenderCache[surfaceData]
    local count = #vertices
    if entry and entry.sourceVertices == vertices and entry.vertexCount == count then
        return entry
    end

    entry = entry or { vertices = {} }
    local renderVertices = entry.vertices
    local validCount = 0
    for i = 1, count do
        local vertex = vertices[i]
        if isvector(vertex) then
            validCount = validCount + 1
            renderVertices[validCount] = client.worldGridRender.setRenderVector(renderVertices[validCount], vertex.x, vertex.y, vertex.z)
        end
    end

    for i = validCount + 1, #renderVertices do
        renderVertices[i] = nil
    end

    entry.sourceVertices = vertices
    entry.vertexCount = validCount
    entry.version = (entry.version or 0) + 1
    entry.worldGridBatches = nil
    client.worldGridRender.bspRenderCache[surfaceData] = entry

    return entry
end

function client.worldGridRender.lookupWorldBspRenderData(surfaceData)
    if not surfaceData then return end
    return client.worldGridRender.bspRenderCache[surfaceData]
end

function client.worldGridRender.worldGridSurfaceComponent(surfaceData, u, v, axisKey)
    if not surfaceData then return 0 end
    if axisKey == "x" then
        return (surfaceData.origin and surfaceData.origin.x or 0)
            + (surfaceData.uAxis and surfaceData.uAxis.x or 0) * u
            + (surfaceData.vAxis and surfaceData.vAxis.x or 0) * v
    elseif axisKey == "y" then
        return (surfaceData.origin and surfaceData.origin.y or 0)
            + (surfaceData.uAxis and surfaceData.uAxis.y or 0) * u
            + (surfaceData.vAxis and surfaceData.vAxis.y or 0) * v
    end

    return (surfaceData.origin and surfaceData.origin.z or 0)
        + (surfaceData.uAxis and surfaceData.uAxis.z or 0) * u
        + (surfaceData.vAxis and surfaceData.vAxis.z or 0) * v
end

function client.worldGridRender.addUniqueWorldGridPoint(points, count, surfaceData, u, v)
    local x = surfaceData.origin.x + surfaceData.uAxis.x * u + surfaceData.vAxis.x * v
    local y = surfaceData.origin.y + surfaceData.uAxis.y * u + surfaceData.vAxis.y * v
    local z = surfaceData.origin.z + surfaceData.uAxis.z * u + surfaceData.vAxis.z * v

    for i = 1, count do
        local other = points[i]
        local dx = x - other.x
        local dy = y - other.y
        local dz = z - other.z
        if dx * dx + dy * dy + dz * dz <= 1e-6 then
            return count
        end
    end

    count = count + 1
    points[count] = client.worldGridRender.setRenderVector(points[count], x, y, z)
    return count
end

function client.worldGridRender.worldGridLineWorldPoints(face, axisKey, value)
    local surfaceData = face and face.surface
    local polygon = face and face.polygon or surfaceData and surfaceData.polygon
    value = tonumber(value)
    if not surfaceData or not istable(polygon) or #polygon < 2 or not value then return end
    if not (isvector(surfaceData.origin) and isvector(surfaceData.uAxis) and isvector(surfaceData.vAxis)) then return end

    local epsilon = 1e-5
    local renderPerf = shapeMetricCache.renderPerf or {}
    shapeMetricCache.renderPerf = renderPerf
    local points = renderPerf.worldGridLinePoints or {}
    renderPerf.worldGridLinePoints = points
    local pointCount = 0
    local previous = polygon[#polygon]
    local previousValue = client.worldGridRender.worldGridSurfaceComponent(surfaceData, previous.u, previous.v, axisKey)

    for i = 1, #polygon do
        local current = polygon[i]
        local currentValue = client.worldGridRender.worldGridSurfaceComponent(surfaceData, current.u, current.v, axisKey)

        local previousOnLine = math.abs(previousValue - value) <= epsilon
        local currentOnLine = math.abs(currentValue - value) <= epsilon

        if previousOnLine then
            pointCount = client.worldGridRender.addUniqueWorldGridPoint(points, pointCount, surfaceData, previous.u, previous.v)
        end
        if currentOnLine then
            pointCount = client.worldGridRender.addUniqueWorldGridPoint(points, pointCount, surfaceData, current.u, current.v)
        end

        local delta = currentValue - previousValue
        if math.abs(delta) > epsilon then
            local t = (value - previousValue) / delta
            if t >= -epsilon and t <= 1 + epsilon then
                t = math.Clamp(t, 0, 1)
                pointCount = client.worldGridRender.addUniqueWorldGridPoint(
                    points,
                    pointCount,
                    surfaceData,
                    previous.u + (current.u - previous.u) * t,
                    previous.v + (current.v - previous.v) * t
                )
            end
        end

        previous = current
        previousValue = currentValue
    end

    if pointCount < 2 then return end

    local bestA, bestB, bestDist
    for i = 1, pointCount - 1 do
        local a = points[i]
        for j = i + 1, pointCount do
            local b = points[j]
            local dx = b.x - a.x
            local dy = b.y - a.y
            local dz = b.z - a.z
            local dist = dx * dx + dy * dy + dz * dz
            if not bestDist or dist > bestDist then
                bestA, bestB, bestDist = a, b, dist
            end
        end
    end

    return bestA, bestB
end

function client.worldGridRender.addWorldGridSnapAxis(axes, seen, axisKey)
    if axisKey ~= "x" and axisKey ~= "y" and axisKey ~= "z" then return end
    if seen[axisKey] then return end

    seen[axisKey] = true
    axes[#axes + 1] = axisKey
end

function client.worldGridRender.ensureWorldGridSnapCrossData(face)
    if not (face and face.globalGrid) then return end
    if face._magicAlignWorldGridSnapReady then
        return face._magicAlignWorldGridSnapLines, face._magicAlignWorldGridSnapLineCount or 0
    end

    local lines = face._magicAlignWorldGridSnapLines or {}
    face._magicAlignWorldGridSnapLines = lines
    face._magicAlignWorldGridSnapLineCount = 0
    face._magicAlignWorldGridSnapReady = true

    local surfaceData = face.surface
    if not surfaceData or not isvector(surfaceData.origin) or not isvector(surfaceData.uAxis) or not isvector(surfaceData.vAxis) then
        return lines, 0
    end

    local snapU = tonumber(face.uSnap)
    local snapV = tonumber(face.vSnap)
    if not snapU or not snapV then return lines, 0 end

    local renderPerf = shapeMetricCache.renderPerf or {}
    shapeMetricCache.renderPerf = renderPerf
    local axes = renderPerf.worldGridSnapAxes or {}
    local seen = renderPerf.worldGridSnapSeen or {}
    renderPerf.worldGridSnapAxes = axes
    renderPerf.worldGridSnapSeen = seen
    axes[1], axes[2], axes[3] = nil, nil, nil
    seen.x, seen.y, seen.z = nil, nil, nil

    client.worldGridRender.addWorldGridSnapAxis(axes, seen, face.snapGlobalAxisU)
    client.worldGridRender.addWorldGridSnapAxis(axes, seen, face.snapGlobalAxisV)

    local overlays = face.globalGridOverlays
    if istable(overlays) then
        for i = 1, #overlays do
            local overlay = overlays[i]
            if overlay then
                client.worldGridRender.addWorldGridSnapAxis(axes, seen, overlay.axisU)
                client.worldGridRender.addWorldGridSnapAxis(axes, seen, overlay.axisV)
                if #axes >= 2 then break end
            end
        end
    end

    local lineCount = 0
    for i = 1, math.min(#axes, 2) do
        local axisKey = axes[i]
        local value = client.worldGridRender.worldGridSurfaceComponent(surfaceData, snapU, snapV, axisKey)
        local a, b = client.worldGridRender.worldGridLineWorldPoints(face, axisKey, value)
        if a and b then
            lineCount = lineCount + 1
            local line = lines[lineCount] or {}
            lines[lineCount] = line
            line.a = client.worldGridRender.setRenderVector(line.a, a.x, a.y, a.z)
            line.b = client.worldGridRender.setRenderVector(line.b, b.x, b.y, b.z)
        end
    end

    for i = lineCount + 1, #lines do
        lines[i] = nil
    end
    face._magicAlignWorldGridSnapLineCount = lineCount

    return lines, lineCount
end

function client.worldGridRender.drawWorldGridSnapCross(face)
    if not (face and face._magicAlignWorldGridSnapReady) then return end

    local lines = face._magicAlignWorldGridSnapLines
    local lineCount = face._magicAlignWorldGridSnapLineCount or 0
    if not istable(lines) or (lineCount or 0) <= 0 then return end

    local color = client.worldGridRender.cursorLineColor or prop2BlueColor(GRID_CONFIG.snapLineAlpha)
    for i = 1, lineCount do
        local line = lines[i]
        if line and line.a and line.b then
            drawLine(line.a, line.b, color, false)
        end
    end
end

function client.worldGridRender.worldGridBatchKey(step, overlay, alpha, lineMode)
    return ("%.6f:%s:%s:%s:%d"):format(
        tonumber(step) or 0,
        tostring(overlay and overlay.axisU or ""),
        tostring(overlay and overlay.axisV or ""),
        tostring(lineMode or (overlay and overlay.lineMode) or "full"),
        math.Clamp(math.floor(tonumber(alpha) or 0), 0, 255)
    )
end

function client.worldGridRender.writeWorldGridBatchVertex(vertices, index, position, axisU, axisV, textureStep, color, normal)
    local vertex = vertices[index]
    if not vertex then
        vertex = {}
        vertices[index] = vertex
    end

    vertex.pos = position
    vertex.u = client.worldGridRender.axisComponent(position, axisU) / textureStep
    vertex.v = client.worldGridRender.axisComponent(position, axisV) / textureStep
    vertex.color = color
    vertex.normal = normal
end

function client.worldGridRender.createWorldGridMesh()
    local ok, meshObject = pcall(Mesh)
    if ok then
        return meshObject
    end
end

function client.worldGridRender.buildWorldGridMesh(batch)
    if not batch or batch.meshUnsupported then return end

    local meshObject = batch.mesh
    if not meshObject then
        meshObject = client.worldGridRender.createWorldGridMesh()
        if not meshObject then
            batch.meshUnsupported = true
            return
        end
        batch.mesh = meshObject
    end

    if not isfunction(meshObject.BuildFromTriangles) then
        batch.mesh = nil
        batch.meshUnsupported = true
        return
    end

    local ok = pcall(meshObject.BuildFromTriangles, meshObject, batch.vertices)
    if ok then
        batch.meshReady = true
    else
        batch.mesh = nil
        batch.meshReady = false
        batch.meshUnsupported = true
    end
end

function client.worldGridRender.ensureWorldGridSurfaceBatch(face, overlay, alpha)
    local renderData = client.worldGridRender.ensureWorldBspRenderData(face and face.surface)
    if not renderData then return end

    local vertices = renderData.vertices
    local vertexCount = renderData.vertexCount or 0
    local step = tonumber(face and face.globalGridStep) or 0
    if not istable(vertices) or vertexCount < 3 or not overlay or not overlay.axisU or not overlay.axisV or step <= 0 then return end

    local lineMode = overlay.lineMode or "full"
    if lineMode == "full" and face and face.worldBspFullGrid == false then
        lineMode = "cross"
    end

    local material, materialEntry = client.worldGridRender.ensureWorldGridMaterial(step, lineMode)
    if not material then return end

    local batches = renderData.worldGridBatches
    if not batches then
        batches = {}
        renderData.worldGridBatches = batches
    end

    local key = client.worldGridRender.worldGridBatchKey(step, overlay, alpha, lineMode)
    local batch = batches[key]
    if batch and batch.sourceVersion == renderData.version then
        batch.material = material
        batch.materialEntry = materialEntry
        batch.surfaceData = face and face.surface or batch.surfaceData
        batch.alpha = alpha
        batch.lineMode = lineMode
        return batch
    end

    batch = batch or { vertices = {} }
    batches[key] = batch

    local batchVertices = batch.vertices
    local color = cachedColor(255, 255, 255, alpha)
    -- Higher-res line RTs keep the same world tile size; only texel density changes.
    local textureStep = step * 2
    local axisU = overlay.axisU
    local axisV = overlay.axisV
    local normal = face and face.normal
    local writeIndex = 0

    for vertexIndex = 2, vertexCount - 1 do
        writeIndex = writeIndex + 1
        client.worldGridRender.writeWorldGridBatchVertex(batchVertices, writeIndex, vertices[1], axisU, axisV, textureStep, color, normal)
        writeIndex = writeIndex + 1
        client.worldGridRender.writeWorldGridBatchVertex(batchVertices, writeIndex, vertices[vertexIndex], axisU, axisV, textureStep, color, normal)
        writeIndex = writeIndex + 1
        client.worldGridRender.writeWorldGridBatchVertex(batchVertices, writeIndex, vertices[vertexIndex + 1], axisU, axisV, textureStep, color, normal)
    end

    for i = writeIndex + 1, #batchVertices do
        batchVertices[i] = nil
    end

    batch.material = material
    batch.materialEntry = materialEntry
    batch.surfaceData = face and face.surface or nil
    batch.alpha = alpha
    batch.lineMode = lineMode
    batch.sourceVersion = renderData.version
    batch.vertexCount = writeIndex
    batch.triangleCount = math.floor(writeIndex / 3)
    batch.meshReady = false
    client.worldGridRender.buildWorldGridMesh(batch)

    return batch
end

function client.worldGridRender.prepareWorldGridSurface(face, alpha)
    local overlays = face and face.globalGridOverlays
    if not istable(overlays) then return end

    local batches = face._magicAlignWorldGridBatches or {}
    face._magicAlignWorldGridBatches = batches

    local batchCount = 0
    for i = 1, #overlays do
        local overlay = overlays[i]
        local overlayAlpha = alpha
        if overlay and overlay.alphaScale then
            overlayAlpha = math.Clamp(math.floor((tonumber(alpha) or 0) * math.Clamp(tonumber(overlay.alphaScale) or 1, 0, 1) + 0.5), 0, 255)
        end

        local batch = client.worldGridRender.ensureWorldGridSurfaceBatch(face, overlay, overlayAlpha)
        if batch then
            batchCount = batchCount + 1
            batches[batchCount] = batch
        end
    end

    for i = batchCount + 1, #batches do
        batches[i] = nil
    end

    face._magicAlignWorldGridBatchCount = batchCount
    face._magicAlignWorldGridPreparedAlpha = alpha
    face._magicAlignWorldGridPreparedFullGrid = face.worldBspFullGrid ~= false
    face._magicAlignWorldGridPreparedRtVersion = client.worldGridRender.rtConfig and client.worldGridRender.rtConfig.alphaRtVersion or 0
    return batches, batchCount
end

(function()
local queueConfig = client.worldGridRender.queueConfig

local function worldGridQueueNow()
    return SysTime()
end

local function worldGridFrameBudgetMs()
    local frameSeconds = FrameTime()
    local frameMs = tonumber(frameSeconds) and frameSeconds * 1000 or queueConfig.fallbackFrameMs
    if frameMs <= 0 then
        frameMs = queueConfig.fallbackFrameMs
    end

    local fraction = math.Clamp(tonumber(queueConfig.frameBudgetFraction) or 0.10, 0.001, 1)
    return frameMs * fraction
end

local function worldGridQueueBudgetMs(settings)
    local configured = tonumber(settings and (settings.worldBspRenderBudgetMs or settings.worldBspBudgetMs))
        or queueConfig.defaultBudgetMs
    configured = math.Clamp(configured, 0, queueConfig.maxBudgetMs)
    return math.min(configured, worldGridFrameBudgetMs())
end

local function worldGridRequestKey(face)
    return ("%.6f:%d:%d"):format(
        tonumber(face and face.globalGridStep) or 0,
        face and face.worldBspFullGrid == false and 0 or 1,
        client.worldGridRender.rtConfig and client.worldGridRender.rtConfig.alphaRtVersion or 0
    )
end

local function worldGridJobOwner(surfaceData)
    if not surfaceData then return end
    return surfaceData.displacementGroup or surfaceData
end

local function worldGridJobStore(owner)
    if not owner then return end

    local jobs = owner._magicAlignWorldGridRenderJobs
    if not istable(jobs) then
        jobs = {}
        owner._magicAlignWorldGridRenderJobs = jobs
    end

    return jobs
end

local function worldGridOverlayAlpha(alpha, overlay)
    local overlayAlpha = tonumber(alpha) or 0
    if overlay and overlay.alphaScale then
        overlayAlpha = overlayAlpha * math.Clamp(tonumber(overlay.alphaScale) or 1, 0, 1)
    end

    return math.Clamp(math.floor(overlayAlpha + 0.5), 0, 255)
end

local function worldGridOverlayLineMode(face, overlay)
    local lineMode = overlay and overlay.lineMode or "full"
    if lineMode == "full" and face and face.worldBspFullGrid == false then
        return "cross"
    end

    return lineMode
end

local function worldGridUnitKey(face, overlay, alpha, lineMode)
    return ("%s:%s:%s:%s:%d"):format(
        tostring(face and face.surface or ""),
        tostring(overlay and overlay.axisU or ""),
        tostring(overlay and overlay.axisV or ""),
        tostring(lineMode or ""),
        math.Clamp(math.floor(tonumber(alpha) or 0), 0, 255)
    )
end

local function worldGridUnitQueued(job, unit)
    if not (job and unit) then return false end

    local units = job.units
    local index = tonumber(unit.index)
    if index and units and units[index] == unit then
        return true
    end

    local limit = job.unitCount or (units and #units or 0)
    for i = 1, limit do
        if units[i] == unit then
            unit.index = i
            return true
        end
    end

    return false
end

local function registerWorldGridPrimaryUnit(job, surfaceData)
    if not (job and surfaceData) then return end

    job.unitsBySurface = job.unitsBySurface or {}
    job.unitsBySurface[surfaceData] = true
    job.primaryUnitsBySurface = job.primaryUnitsBySurface or {}
    job.primaryUnitsBySurface[surfaceData] = true
end

local function registerWorldGridSurfaceUnit(job, surfaceData)
    if not (job and surfaceData) then return end

    job.unitsBySurface = job.unitsBySurface or {}
    job.unitsBySurface[surfaceData] = true
end

local function activateWorldGridJob(job)
    if not job or job._magicAlignQueueActive then return end

    local queue = client.worldGridRender.renderQueue
    local activeJobs = queue.activeJobs
    activeJobs[#activeJobs + 1] = job
    job._magicAlignQueueActive = true
end

local function pushWorldGridPriorityUnit(job, unit)
    if not job or not unit or unit.done or unit.failed or unit.priorityQueued then return end

    local priorityUnits = job.priorityUnits
    job.priorityUnitCount = (job.priorityUnitCount or 0) + 1
    priorityUnits[job.priorityUnitCount] = unit
    unit.priorityQueued = true
end

local function appendWorldGridSurfaceUnits(job, face, alpha, primary)
    local overlays = face and face.globalGridOverlays
    local surfaceData = face and face.surface
    if not (job and surfaceData and istable(overlays)) then return false end

    local registered = false
    for i = 1, #overlays do
        local overlay = overlays[i]
        if overlay and overlay.axisU and overlay.axisV then
            local overlayAlpha = worldGridOverlayAlpha(alpha, overlay)
            local lineMode = worldGridOverlayLineMode(face, overlay)
            local key = worldGridUnitKey(face, overlay, overlayAlpha, lineMode)
            local unit = job.unitsByKey[key]
            if unit and (unit.surfaceData ~= surfaceData or not worldGridUnitQueued(job, unit)) then
                job.unitsByKey[key] = nil
                unit = nil
            end

            if not unit then
                local index = (job.unitCount or 0) + 1
                unit = {
                    key = key,
                    face = face,
                    surfaceData = surfaceData,
                    overlay = overlay,
                    alpha = overlayAlpha,
                    primary = primary == true,
                    lineMode = lineMode,
                    index = index
                }

                job.unitCount = index
                job.units[index] = unit
                job.unitsByKey[key] = unit
                job.totalUnits = (job.totalUnits or 0) + 1
            elseif primary then
                unit.face = face
                unit.primary = true
            end

            registered = registered or unit.surfaceData == surfaceData
            if unit.surfaceData == surfaceData then
                registerWorldGridSurfaceUnit(job, surfaceData)
            end
            if primary then
                pushWorldGridPriorityUnit(job, unit)
                if unit.surfaceData == surfaceData then
                    registerWorldGridPrimaryUnit(job, surfaceData)
                end
            end
        end
    end

    if primary and registered then
        job.seededPrimaryBySurface = job.seededPrimaryBySurface or {}
        job.seededPrimaryBySurface[surfaceData] = true
    end

    return registered
end

local function seedWorldGridJob(job, face, includeNeighbors)
    appendWorldGridSurfaceUnits(job, face, GRID_CONFIG.bspGlobalAlpha, true)

    if includeNeighbors then
        local neighbors = face and face.globalGridNeighbors
        if istable(neighbors) then
            for i = 1, #neighbors do
                appendWorldGridSurfaceUnits(job, neighbors[i], GRID_CONFIG.bspGlobalNeighborAlpha, false)
            end
        end
    end

    if (job.doneUnits or 0) < (job.totalUnits or 0) then
        activateWorldGridJob(job)
    end
end

local function worldGridVisibleNeighborSet(job, face)
    local surfaceData = face and face.surface
    if not (job and surfaceData) then return end

    local sets = job.visibleNeighborSetBySurface
    if not istable(sets) then
        sets = {}
        job.visibleNeighborSetBySurface = sets
    end
    local cached = sets[surfaceData]
    if cached then return cached end

    cached = {}
    local neighbors = face.globalGridNeighbors
    if istable(neighbors) then
        for i = 1, #neighbors do
            local neighborSurface = neighbors[i] and neighbors[i].surface
            if neighborSurface then
                cached[neighborSurface] = true
            end
        end
    end

    sets[surfaceData] = cached
    return cached
end

local function worldGridJobHasPrimarySurface(job, surfaceData)
    if not (job and surfaceData) then return false end

    local primary = job.readyPrimaryBySurface and job.readyPrimaryBySurface[surfaceData]
    if primary and (primary.count or 0) > 0 then return true end

    local registered = job.primaryUnitsBySurface
    if registered and registered[surfaceData] then return true end

    local units = job.units
    local limit = job.unitCount or (units and #units or 0)
    for i = 1, limit do
        local unit = units and units[i]
        if unit and unit.surfaceData == surfaceData and unit.primary then
            registerWorldGridPrimaryUnit(job, surfaceData)
            return true
        end
    end

    return false
end

local function worldGridFaceNeedsUnit(face)
    local overlays = face and face.globalGridOverlays
    if not istable(overlays) then return false end

    for i = 1, #overlays do
        local overlay = overlays[i]
        if overlay and overlay.axisU and overlay.axisV then
            return true
        end
    end

    return false
end

local function worldGridJobHasSurfaceUnit(job, surfaceData)
    if not (job and surfaceData) then return false end

    local registered = job.unitsBySurface
    if registered and registered[surfaceData] then return true end

    local units = job.units
    local limit = job.unitCount or (units and #units or 0)
    for i = 1, limit do
        local unit = units and units[i]
        if unit and unit.surfaceData == surfaceData then
            registerWorldGridSurfaceUnit(job, surfaceData)
            return true
        end
    end

    return false
end

local function worldGridJobCoversFace(job, face)
    if not (job and face and face.surface) then return false end

    if worldGridFaceNeedsUnit(face) and not worldGridJobHasPrimarySurface(job, face.surface) then
        return false
    end

    local neighbors = face.globalGridNeighbors
    if istable(neighbors) then
        for i = 1, #neighbors do
            local neighbor = neighbors[i]
            if worldGridFaceNeedsUnit(neighbor) and not worldGridJobHasSurfaceUnit(job, neighbor.surface) then
                return false
            end
        end
    end

    return true
end

local function publishWorldGridBatch(job, unit, batch)
    if not job or not unit or not batch then return end

    if unit.primary then
        local bySurface = job.readyPrimaryBySurface
        local surfaceData = unit.surfaceData
        local surfaceBatches = bySurface[surfaceData]
        if not surfaceBatches then
            surfaceBatches = { count = 0, seen = {} }
            bySurface[surfaceData] = surfaceBatches
        end

        if not surfaceBatches.seen[batch] then
            surfaceBatches.seen[batch] = true
            surfaceBatches.count = surfaceBatches.count + 1
            surfaceBatches[surfaceBatches.count] = batch
        end

        return
    end

    if job.readyNeighborBatchSeen[batch] then return end

    job.readyNeighborBatchSeen[batch] = true
    job.readyNeighborBatchCount = (job.readyNeighborBatchCount or 0) + 1
    job.readyNeighborBatches[job.readyNeighborBatchCount] = batch
end

local function nextWorldGridUnit(job)
    local priorityUnits = job.priorityUnits
    while (job.priorityUnitCount or 0) > 0 do
        local index = job.priorityUnitCount
        local unit = priorityUnits[index]
        priorityUnits[index] = nil
        job.priorityUnitCount = index - 1

        if unit then
            unit.priorityQueued = false
            if not unit.done and not unit.failed then
                return unit
            end
        end
    end

    local units = job.units
    local cursor = tonumber(job.cursor) or 1
    while cursor <= (job.unitCount or #units) do
        local unit = units[cursor]
        cursor = cursor + 1
        job.cursor = cursor

        if unit and not unit.done and not unit.failed then
            return unit
        end
    end
end

local function buildWorldGridUnit(job, unit)
    if not job or not unit or unit.done or unit.failed then return end

    unit.building = true
    local ok, batch = pcall(client.worldGridRender.ensureWorldGridSurfaceBatch, unit.face, unit.overlay, unit.alpha)
    unit.building = false
    unit.done = true
    job.doneUnits = (job.doneUnits or 0) + 1

    if not ok then
        unit.failed = true
        job.failedUnits = (job.failedUnits or 0) + 1
        job.lastError = tostring(batch)
        return
    end

    publishWorldGridBatch(job, unit, batch)
end

local function processWorldGridJob(job, deadline)
    if not job or (job.doneUnits or 0) >= (job.totalUnits or 0) then return end

    while worldGridQueueNow() < deadline do
        local unit = nextWorldGridUnit(job)
        if not unit then return end

        buildWorldGridUnit(job, unit)
        if (job.doneUnits or 0) >= (job.totalUnits or 0) then return end
    end
end

local function compactWorldGridActiveJobs(nowTime)
    local queue = client.worldGridRender.renderQueue
    local activeJobs = queue.activeJobs
    local writeIndex = 0

    for i = 1, #activeJobs do
        local job = activeJobs[i]
        local active = job
            and (job.doneUnits or 0) < (job.totalUnits or 0)
            and nowTime - (tonumber(job.lastTouched) or nowTime) <= queueConfig.inactiveJobSeconds

        if active then
            writeIndex = writeIndex + 1
            activeJobs[writeIndex] = job
            job._magicAlignQueueActive = true
        elseif job then
            job._magicAlignQueueActive = false
        end
    end

    for i = writeIndex + 1, #activeJobs do
        activeJobs[i] = nil
    end
end

function client.worldGridRender.requestWorldBspGlobalGrid(face)
    if not (face and face.worldBSP and face.globalGrid and face.surface) then return end

    local key = worldGridRequestKey(face)
    local frame = FrameNumber()
    if frame ~= nil
        and face._magicAlignWorldGridRequestFrame == frame
        and face._magicAlignWorldGridRequestKey == key then
        local job = face._magicAlignWorldGridJob
        if job then
            return job
        end
    end

    local owner = worldGridJobOwner(face.surface)
    local jobs = worldGridJobStore(owner)
    if not jobs then return end

    local job = jobs[key]
    if not job then
        job = {
            key = key,
            owner = owner,
            units = {},
            unitsByKey = {},
            priorityUnits = {},
            readyNeighborBatches = {},
            readyNeighborBatchSeen = {},
            readyPrimaryBySurface = {},
            unitsBySurface = {},
            primaryUnitsBySurface = {},
            seededPrimaryBySurface = {},
            visibleNeighborSetBySurface = {},
            cursor = 1,
            totalUnits = 0,
            doneUnits = 0,
            failedUnits = 0,
            readyNeighborBatchCount = 0
        }
        jobs[key] = job
    else
        job.unitsBySurface = job.unitsBySurface or {}
        job.primaryUnitsBySurface = job.primaryUnitsBySurface or {}
        job.seededPrimaryBySurface = job.seededPrimaryBySurface or {}
        job.readyPrimaryBySurface = job.readyPrimaryBySurface or {}
    end

    local nowTime = worldGridQueueNow()
    local coversFace = worldGridJobCoversFace(job, face)
    if face._magicAlignWorldGridJob == job
        and face._magicAlignWorldGridRequestKey == key
        and job.seeded
        and job.lastRequestedSurface == face.surface
        and coversFace then
        job.lastTouched = nowTime
        job.currentSurface = face.surface
        job.currentFace = face
        face._magicAlignWorldGridVisibleNeighborSet = face._magicAlignWorldGridVisibleNeighborSet or worldGridVisibleNeighborSet(job, face)
        face._magicAlignWorldGridProgressDone = job.doneUnits or 0
        face._magicAlignWorldGridProgressTotal = job.totalUnits or 0
        face._magicAlignWorldGridRequestFrame = frame
        client.worldGridRender.renderQueue.focusJob = job
        client.worldGridRender.renderQueue.focusTouchedAt = nowTime
        return job
    end

    job.lastTouched = nowTime
    job.currentSurface = face.surface
    job.currentFace = face

    local includeNeighbors = not coversFace or not job.seeded or job.lastRequestedSurface ~= face.surface
    seedWorldGridJob(job, face, includeNeighbors)
    job.seeded = true
    job.lastRequestedSurface = face.surface

    face._magicAlignWorldGridJob = job
    face._magicAlignWorldGridRequestKey = key
    face._magicAlignWorldGridRequestFrame = frame
    face._magicAlignWorldGridVisibleNeighborSet = worldGridVisibleNeighborSet(job, face)
    face._magicAlignWorldGridProgressDone = job.doneUnits or 0
    face._magicAlignWorldGridProgressTotal = job.totalUnits or 0

    client.worldGridRender.renderQueue.focusJob = job
    client.worldGridRender.renderQueue.focusTouchedAt = nowTime
    return job
end

function client.worldGridRender.processQueue(settings)
    local queue = client.worldGridRender.renderQueue
    queue.frame = (queue.frame or 0) + 1

    local nowTime = worldGridQueueNow()
    local budgetMs = worldGridQueueBudgetMs(settings)
    local deadline = nowTime + budgetMs * 0.001
    local focusJob = queue.focusJob
    if focusJob and nowTime - (tonumber(queue.focusTouchedAt) or 0) > 0.2 then
        queue.focusJob = nil
        focusJob = nil
    end

    if focusJob then
        processWorldGridJob(focusJob, deadline)
    end

    local activeJobs = queue.activeJobs
    local processed = 0
    for i = 1, #activeJobs do
        if worldGridQueueNow() >= deadline then break end

        local job = activeJobs[i]
        if job and job ~= focusJob then
            processWorldGridJob(job, deadline)
            processed = processed + 1
            if processed >= queueConfig.maxJobsPerFrame then
                break
            end
        end
    end

    compactWorldGridActiveJobs(worldGridQueueNow())
end
end)()

function client.worldGridRender.pushWorldGridBatchVertex(vertex, alphaScale)
    if not vertex or not vertex.pos then return end

    local color = vertex.color or color_white
    alphaScale = math.Clamp(tonumber(alphaScale) or 1, 0, 1)
    meshPosition(vertex.pos)
    mesh.TexCoord(0, vertex.u or 0, vertex.v or 0)
    mesh.Color(color.r, color.g, color.b, math.Clamp(math.floor((color.a or 255) * alphaScale + 0.5), 0, 255))
    mesh.AdvanceVertex()
end

function client.worldGridRender.drawWorldGridSurfaceBatch(batch)
    if not batch or not batch.material or (batch.vertexCount or 0) <= 0 then return end
    if batch.materialEntry and batch.materialEntry.ready ~= true then return end

    local alphaScale = client.worldGridRender.currentLightBlend and client.worldGridRender.currentLightBlend() or 1
    local pushedMin, pushedMag = client.worldGridRender.pushWorldGridTextureFilter()
    render.SetMaterial(batch.material)
    if alphaScale >= 0.999 and batch.meshReady and batch.mesh and isfunction(batch.mesh.Draw) then
        batch.mesh:Draw()
    else
        mesh.Begin(MATERIAL_TRIANGLES, batch.triangleCount or math.floor((batch.vertexCount or 0) / 3))
            for i = 1, batch.vertexCount do
                client.worldGridRender.pushWorldGridBatchVertex(batch.vertices[i], alphaScale)
            end
        mesh.End()
    end
    client.worldGridRender.popWorldGridTextureFilter(pushedMin, pushedMag)
end

function client.worldGridRender.drawWorldGridSurface(face, alpha)
    local batches = face and face._magicAlignWorldGridBatches
    local batchCount = face and face._magicAlignWorldGridBatchCount or 0
    if not istable(batches) or (batchCount or 0) <= 0 then return end

    for i = 1, batchCount do
        client.worldGridRender.drawWorldGridSurfaceBatch(batches[i])
    end
end

function client.worldGridRender.prepareWorldBspGlobalGrid(face)
    if not face then return end

    client.worldGridRender.ensureWorldGridSnapCrossData(face)
    return client.worldGridRender.requestWorldBspGlobalGrid(face)
end

function client.prepareWorldBspRenderCandidate(candidate)
    local face = candidate and candidate.face
    if not (face and face.worldBSP) then return end

    local frame = FrameNumber()
    local token = face.surface
    if frame ~= nil
        and candidate._magicAlignPreparedFrame == frame
        and candidate._magicAlignPreparedFace == face
        and candidate._magicAlignPreparedToken == token then
        return
    end
    candidate._magicAlignPreparedFrame = frame
    candidate._magicAlignPreparedFace = face
    candidate._magicAlignPreparedToken = token

    client.worldGridRender.ensureWorldBspRenderData(face.surface)
    if face.globalGrid then
        client.worldGridRender.ensureWorldGridSnapCrossData(face)
        client.worldGridRender.requestWorldBspGlobalGrid(face)
    end
end

function client.worldGridRender.drawWorldBspGlobalGridSurface(face)
    local job = face and face._magicAlignWorldGridJob
    if not job then return false end

    local surfaceData = face.surface
    local visibleNeighbors = face._magicAlignWorldGridVisibleNeighborSet
    local primary = job.readyPrimaryBySurface and job.readyPrimaryBySurface[surfaceData]
    local primaryCount = primary and primary.count or 0
    local neighborBatches = job.readyNeighborBatches
    cam.IgnoreZ(false)
    for i = 1, (job.readyNeighborBatchCount or 0) do
        local batch = neighborBatches[i]
        if batch
            and (batch.surfaceData ~= surfaceData or primaryCount <= 0)
            and (batch.surfaceData == surfaceData or not visibleNeighbors or visibleNeighbors[batch.surfaceData]) then
            client.worldGridRender.drawWorldGridSurfaceBatch(batch)
        end
    end

    if primary then
        for i = 1, primaryCount do
            client.worldGridRender.drawWorldGridSurfaceBatch(primary[i])
        end
    end

    return true
end

function client.worldGridRender.drawWorldBspGlobalGridDepthTested(face)
    if not client.worldGridRender.drawWorldBspGlobalGridSurface(face) then return end

    client.worldGridRender.drawWorldGridSnapCross(face)
    cam.IgnoreZ(false)
end

function client.worldGridRender.drawWorldBspGlobalGrid(face)
    if not client.worldGridRender.drawWorldBspGlobalGridSurface(face) then return end

    cam.IgnoreZ(true)
    client.worldGridRender.drawWorldGridSnapCross(face)
end

(function()
local function debugBool(value)
    return value and "yes" or "no"
end

local function debugSurfaceId(surfaceData)
    return tostring(surfaceData and surfaceData.id or "nil")
end

local function debugHoverFace()
    local state = M.ClientState
    local hover = state and state.hover
    local candidate = hover and (hover.candidate or hover.overlay)
    return candidate and candidate.face or nil
end

local function debugOverlayList(face)
    local overlays = face and face.globalGridOverlays
    if not istable(overlays) then return "nil" end

    local out = {}
    for i = 1, #overlays do
        local overlay = overlays[i]
        out[#out + 1] = ("%s/%s/%s"):format(
            tostring(overlay and overlay.axisU or "?"),
            tostring(overlay and overlay.axisV or "?"),
            tostring(overlay and overlay.lineMode or "full")
        )
    end

    return table.concat(out, ",")
end

local function debugBatchDrawable(batch)
    if not batch or not batch.material or (batch.vertexCount or 0) <= 0 then return false end
    return not batch.materialEntry or batch.materialEntry.ready == true
end

local function countPrimaryBatches(job, surfaceData)
    local primary = job and job.readyPrimaryBySurface and job.readyPrimaryBySurface[surfaceData]
    local count = primary and (primary.count or 0) or 0
    local drawable = 0
    for i = 1, count do
        if debugBatchDrawable(primary[i]) then
            drawable = drawable + 1
        end
    end

    return count, drawable
end

local function countSurfaceUnits(job, surfaceData)
    local unitCount = 0
    local primaryCount = 0
    local doneCount = 0
    local failedCount = 0
    local buildingCount = 0
    local sameIdCount = 0
    local id = surfaceData and surfaceData.id

    local units = job and job.units
    local limit = job and (job.unitCount or (units and #units or 0)) or 0
    for i = 1, limit do
        local unit = units and units[i]
        if unit and unit.surfaceData == surfaceData then
            unitCount = unitCount + 1
            if unit.primary then primaryCount = primaryCount + 1 end
            if unit.done then doneCount = doneCount + 1 end
            if unit.failed then failedCount = failedCount + 1 end
            if unit.building then buildingCount = buildingCount + 1 end
        elseif unit and id ~= nil and unit.surfaceData and unit.surfaceData.id == id then
            sameIdCount = sameIdCount + 1
        end
    end

    return unitCount, primaryCount, doneCount, failedCount, buildingCount, sameIdCount
end

local function countNeighborBatches(job, surfaceData)
    local count = 0
    local drawable = 0
    local batches = job and job.readyNeighborBatches
    for i = 1, job and (job.readyNeighborBatchCount or 0) or 0 do
        local batch = batches and batches[i]
        if batch and batch.surfaceData == surfaceData then
            count = count + 1
            if debugBatchDrawable(batch) then
                drawable = drawable + 1
            end
        end
    end

    return count, drawable
end

local function groupGapSummary(job, face)
    local surfaceData = face and face.surface
    local group = surfaceData and surfaceData.displacementGroup
    local surfaces = group and group.surfaces
    if not istable(surfaces) then return end

    local visibleSet = face._magicAlignWorldGridVisibleNeighborSet
    local missing = {}
    local notVisible = {}
    local noUnits = {}
    local failed = {}
    local readyCount = 0
    local drawableCount = 0
    local registered = job and job.unitsBySurface

    for i = 1, #surfaces do
        local surface = surfaces[i]
        local primaryReady, primaryDrawable = countPrimaryBatches(job, surface)
        local neighborReady, neighborDrawable = countNeighborBatches(job, surface)
        local unitCount, _primaryCount, _doneCount, failedCount = countSurfaceUnits(job, surface)
        local visible = surface == surfaceData or not visibleSet or visibleSet[surface] == true
        local hasReady = primaryReady > 0 or neighborReady > 0
        local hasDrawable = primaryDrawable > 0 or neighborDrawable > 0
        local hasSurfaceUnit = registered and registered[surface] == true

        if hasReady then readyCount = readyCount + 1 end
        if hasDrawable then drawableCount = drawableCount + 1 end
        if not visible and #notVisible < 16 then notVisible[#notVisible + 1] = surface.id end
        if unitCount <= 0 and #noUnits < 16 then noUnits[#noUnits + 1] = surface.id end
        if failedCount > 0 and #failed < 16 then failed[#failed + 1] = surface.id end
        if visible and not hasDrawable and not hasSurfaceUnit and #missing < 16 then
            missing[#missing + 1] = surface.id
        end
    end

    print(("Magic Align: World BSP grid group: group=%s surfaces=%d readySurfaces=%d drawableSurfaces=%d missingVisibleNoDrawableOrUnit(first16)=%s noUnits(first16)=%s notVisible(first16)=%s failed(first16)=%s."):format(
        tostring(group.index or "?"),
        #surfaces,
        readyCount,
        drawableCount,
        table.concat(missing, ","),
        table.concat(noUnits, ","),
        table.concat(notVisible, ","),
        table.concat(failed, ",")
    ))
end

function client.worldGridRender.debugWorldBspGlobalGrid()
    local face = debugHoverFace()
    if not (face and face.worldBSP and face.surface) then
        print("Magic Align: World BSP grid debug: no hovered world BSP face.")
        return
    end

    local surfaceData = face.surface
    local group = surfaceData.displacementGroup
    local job = face._magicAlignWorldGridJob
    local primaryReady, primaryDrawable = countPrimaryBatches(job, surfaceData)
    local neighborReady, neighborDrawable = countNeighborBatches(job, surfaceData)
    local units, primaryUnits, doneUnits, failedUnits, buildingUnits, sameIdUnits = countSurfaceUnits(job, surfaceData)
    local surfaceRegistered = job and job.unitsBySurface and job.unitsBySurface[surfaceData] == true
    local primaryRegistered = job and job.primaryUnitsBySurface and job.primaryUnitsBySurface[surfaceData] == true
    local seededPrimary = job and job.seededPrimaryBySurface and job.seededPrimaryBySurface[surfaceData] == true
    local visibleSet = face._magicAlignWorldGridVisibleNeighborSet
    local visibleSelf = not visibleSet or visibleSet[surfaceData] == true

    print(("Magic Align: World BSP grid debug: surface=%s group=%s groupSurfaces=%d neighbors=%d globalGrid=%s overlays=%d[%s] step=%.6f fullGrid=%s."):format(
        debugSurfaceId(surfaceData),
        tostring(group and group.index or "nil"),
        group and istable(group.surfaces) and #group.surfaces or 0,
        face.globalGridNeighbors and #face.globalGridNeighbors or 0,
        debugBool(face.globalGrid),
        face.globalGridOverlays and #face.globalGridOverlays or 0,
        debugOverlayList(face),
        tonumber(face.globalGridStep) or 0,
        debugBool(face.worldBspFullGrid ~= false)
    ))

    if not job then
        print("Magic Align: World BSP grid job: nil.")
        return
    end

    print(("Magic Align: World BSP grid job: seeded=%s active=%s jobKey=%s faceKey=%s lastSurface=%s currentSurface=%s done=%d total=%d failed=%d cursor=%d priority=%d readyNeighbors=%d focus=%s error=%s."):format(
        debugBool(job.seeded),
        debugBool(job._magicAlignQueueActive),
        tostring(job.key or "nil"),
        tostring(face._magicAlignWorldGridRequestKey or "nil"),
        debugSurfaceId(job.lastRequestedSurface),
        debugSurfaceId(job.currentSurface),
        tonumber(job.doneUnits) or 0,
        tonumber(job.totalUnits) or 0,
        tonumber(job.failedUnits) or 0,
        tonumber(job.cursor) or 0,
        tonumber(job.priorityUnitCount) or 0,
        tonumber(job.readyNeighborBatchCount) or 0,
        debugBool(client.worldGridRender.renderQueue and client.worldGridRender.renderQueue.focusJob == job),
        tostring(job.lastError or "nil")
    ))

    print(("Magic Align: World BSP grid surface: surfaceRegistered=%s primaryRegistered=%s seededMarker=%s primaryReady=%d/%d neighborReady=%d/%d units=%d primaryUnits=%d done=%d failed=%d building=%d sameIdUnits=%d visibleSelf=%s snapReady=%s progress=%d/%d."):format(
        debugBool(surfaceRegistered),
        debugBool(primaryRegistered),
        debugBool(seededPrimary),
        primaryReady,
        primaryDrawable,
        neighborReady,
        neighborDrawable,
        units,
        primaryUnits,
        doneUnits,
        failedUnits,
        buildingUnits,
        sameIdUnits,
        debugBool(visibleSelf),
        debugBool(face._magicAlignWorldGridSnapReady),
        tonumber(face._magicAlignWorldGridProgressDone) or 0,
        tonumber(face._magicAlignWorldGridProgressTotal) or 0
    ))

    groupGapSummary(job, face)
end

concommand.Remove("magic_align_world_bsp_debug_grid")
concommand.Add("magic_align_world_bsp_debug_grid", function()
    client.worldGridRender.debugWorldBspGlobalGrid()
end)
end)()

local function queueShapeCacheWarmup(tool, qualityIndex)
    local settings = qualityIndex ~= nil and ringRenderSettingsForIndex(qualityIndex)
        or tool and ringRenderSettingsForTool(tool)
        or activeRingRenderSettings()
    if not settings or settings.realtime then
        return
    end

    local ringSize = ringRtSize(settings)
    local circleSize = circleSpriteRtSize(settings)
    local ringSegments = ringRenderSegments(settings)
    local circleSegments = circleSpriteSegments(settings)

    if ringSize then
        ensureCachedShape("disc", ringSize, nil, ringSegments)
    end
    if circleSize then
        ensureCachedShape("disc", circleSize, nil, circleSegments)
    end
end

local function selectionColor(state)
    if state and state.preview and state.preview.transformMode == M.TRANSFORM_MODE_MIRROR then
        local mirror = colors.mirror or Color(176, 112, 235)
        return cachedColor(mirror.r, mirror.g, mirror.b, 255)
    end

    return cachedColor(colors.source.r, colors.source.g, colors.source.b, 255)
end

shapeMetricCache.renderPerf = shapeMetricCache.renderPerf or {}

function shapeMetricCache.renderPerf.drawWireMarkerBatch(entries, ignoreZ)
    if not istable(entries) or #entries == 0 then return end

    render.MaterialOverride(RENDER_CONFIG.wireframeMaterial)
    render.SuppressEngineLighting(true)
    if ignoreZ then
        cam.IgnoreZ(true)
    end

    for i = 1, #entries do
        local entry = entries[i]
        local ent = entry and entry.ent
        local color = entry and entry.color
        if IsValid(ent) and color then
            render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
            render.SetBlend(math.Clamp((tonumber(entry.alpha) or 0) / 255, 0.02, 1))
            ent:DrawModel()
        end
    end

    if ignoreZ then
        cam.IgnoreZ(false)
    end
    render.SuppressEngineLighting(false)
    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
    render.MaterialOverride()
end

function shapeMetricCache.renderPerf.addGhostRenderEntry(entries, ghost, minBlend, maxBlend)
    if not istable(entries) or not IsValid(ghost) then return end
    if ghost.GetNoDraw and ghost:GetNoDraw() then return end

    local ghostColor = ghost:GetColor()
    local index = (tonumber(entries._magicAlignCount) or 0) + 1
    entries._magicAlignCount = index
    local entry = entries[index]
    if not istable(entry) then
        entry = {}
        entries[index] = entry
    end

    entry.ghost = ghost
    entry.alpha = ghostColor.a or 255
    entry.minBlend = minBlend
    entry.maxBlend = maxBlend
end

function shapeMetricCache.renderPerf.drawGhostRenderEntries(entries)
    if not istable(entries) or #entries == 0 then return end

    for i = 1, #entries do
        local entry = entries[i]
        if IsValid(entry.ghost) and not (entry.ghost.GetNoDraw and entry.ghost:GetNoDraw()) then
            local color = entry.ghost:GetColor()
            render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
            render.SetBlend(math.Clamp(entry.alpha / 255, entry.minBlend, entry.maxBlend))
            entry.ghost:DrawModel()
        end
    end

    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
end

local function clampColorByte(value, fallback)
    return math.Clamp(math.floor(tonumber(value) or fallback or 0), 0, 255)
end

local function previewOccludedEnabled(tool)
    if tool and tool.GetClientNumber then
        return (tonumber(tool:GetClientNumber("preview_occluded")) or 0) ~= 0
    end

    local cvar = GetConVar(RENDER_CONFIG.previewOccludedCvar)
    return cvar and cvar:GetBool() or false
end

local function previewOccludedPickerColor(tool)
    if tool and tool.GetClientNumber then
        return cachedColor(
            clampColorByte(tool:GetClientNumber("preview_occluded_r"), RENDER_CONFIG.previewOccludedDefaultColor.r),
            clampColorByte(tool:GetClientNumber("preview_occluded_g"), RENDER_CONFIG.previewOccludedDefaultColor.g),
            clampColorByte(tool:GetClientNumber("preview_occluded_b"), RENDER_CONFIG.previewOccludedDefaultColor.b),
            clampColorByte(tool:GetClientNumber("preview_occluded_a"), RENDER_CONFIG.previewOccludedDefaultColor.a)
        )
    end

    local function cvarByte(suffix, fallback)
        local cvar = GetConVar("magic_align_preview_occluded_" .. suffix)
        return clampColorByte(cvar and cvar:GetInt() or fallback, fallback)
    end

    return cachedColor(
        cvarByte("r", RENDER_CONFIG.previewOccludedDefaultColor.r),
        cvarByte("g", RENDER_CONFIG.previewOccludedDefaultColor.g),
        cvarByte("b", RENDER_CONFIG.previewOccludedDefaultColor.b),
        cvarByte("a", RENDER_CONFIG.previewOccludedDefaultColor.a)
    )
end

local function scaledOccludedPreviewColor(tool, holoAlpha, stripeColorOverride)
    local picker = previewOccludedPickerColor(tool)
    local alpha = math.Clamp(math.floor((picker.a / 255) * clampColorByte(holoAlpha, 0) + 0.5), 0, 255)
    if alpha <= 0 then return end

    local source = stripeColorOverride or picker
    return cachedColor(source.r, source.g, source.b, alpha)
end

local function stencilAvailable()
    return true
end

local function stripeDistanceScale(distance)
    distance = math.max(tonumber(distance) or 1, 1)
    return math.Clamp(
        STRIPE_CONFIG.occludedReferenceDistance / distance,
        STRIPE_CONFIG.occludedMinScreenScale,
        STRIPE_CONFIG.occludedMaxScreenScale
    )
end

local function occludedStripeTileSize(ghost)
    if not IsValid(ghost) then return STRIPE_CONFIG.rtSize end

    local center = ghost.WorldSpaceCenter and ghost:WorldSpaceCenter() or ghost:GetPos()
    if not isvector(center) then return STRIPE_CONFIG.rtSize end

    return math.max(1, STRIPE_CONFIG.rtSize * stripeDistanceScale(EyePos():Distance(center)))
end

local function occludedStripeScreenCenter(ghost)
    if not IsValid(ghost) then return ScrW() * 0.5, ScrH() * 0.5 end

    local mins, maxs
    if isfunction(ghost.GetRenderBounds) then
        mins, maxs = ghost:GetRenderBounds()
    end
    if (not isvector(mins) or not isvector(maxs)) and isfunction(ghost.OBBMins) and isfunction(ghost.OBBMaxs) then
        mins, maxs = ghost:OBBMins(), ghost:OBBMaxs()
    end

    if not isvector(mins) or not isvector(maxs) then
        local center = ghost.WorldSpaceCenter and ghost:WorldSpaceCenter() or ghost:GetPos()
        if isvector(center) then
            local screen = center:ToScreen()
            return screen.x, screen.y
        end

        return ScrW() * 0.5, ScrH() * 0.5
    end

    local pos = ghost:GetPos()
    local ang = ghost:GetAngles()
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for xIndex = 0, 1 do
        for yIndex = 0, 1 do
            for zIndex = 0, 1 do
                local localPos = VectorP(
                    xIndex == 0 and mins.x or maxs.x,
                    yIndex == 0 and mins.y or maxs.y,
                    zIndex == 0 and mins.z or maxs.z
                )
                local world = LocalToWorldPosPrecise(localPos, pos, ang)
                local screen = world:ToScreen()
                minX = math.min(minX, screen.x)
                minY = math.min(minY, screen.y)
                maxX = math.max(maxX, screen.x)
                maxY = math.max(maxY, screen.y)
            end
        end
    end

    if minX == math.huge or minY == math.huge then
        return ScrW() * 0.5, ScrH() * 0.5
    end

    return (minX + maxX) * 0.5, (minY + maxY) * 0.5
end

local function occludedStripeParallaxCenter(centerX, centerY)
    local amount = math.Clamp(tonumber(STRIPE_CONFIG.occludedScreenParallax) or 0, 0, 1)
    if amount <= 0 then return centerX, centerY end

    local screenCenterX = ScrW() * 0.5
    local screenCenterY = ScrH() * 0.5
    return centerX + (screenCenterX - centerX) * amount, centerY + (screenCenterY - centerY) * amount
end

local function drawScreenStripePattern(color, tileSize, centerX, centerY)
    if ensureStripePatternMaterial then
        ensureStripePatternMaterial()
    end

    local stripeMaterial = stripePatternScreenMaterial or stripePatternMaterial
    if not stripeMaterial then return false end

    tileSize = math.max(1, tonumber(tileSize) or STRIPE_CONFIG.rtSize)
    local screenWidth = ScrW()
    local screenHeight = ScrH()
    centerX = tonumber(centerX) or screenWidth * 0.5
    centerY = tonumber(centerY) or screenHeight * 0.5
    local angle = math.rad(45)
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)

    local function pushScreenVertex(x, y)
        local centeredX = x - centerX
        local centeredY = y - centerY
        meshPosition(VectorP(x, y, 0))
        mesh.TexCoord(
            0,
            0.5 + (centeredX * cosAngle + centeredY * sinAngle) / tileSize,
            0.5 + (-centeredX * sinAngle + centeredY * cosAngle) / tileSize
        )
        mesh.Color(color.r, color.g, color.b, color.a)
        mesh.AdvanceVertex()
    end

    cam.Start2D()
        render.SetMaterial(stripeMaterial)
        mesh.Begin(MATERIAL_TRIANGLES, 2)
            pushScreenVertex(0, 0)
            pushScreenVertex(screenWidth, 0)
            pushScreenVertex(screenWidth, screenHeight)

            pushScreenVertex(0, 0)
            pushScreenVertex(screenWidth, screenHeight)
            pushScreenVertex(0, screenHeight)
        mesh.End()
    cam.End2D()

    return true
end

local function drawPreviewOccludedGhost(tool, ghost, baseAlpha, stripeColorOverride)
    if not IsValid(ghost) or (ghost.GetNoDraw and ghost:GetNoDraw()) then return end
    if not stencilAvailable() then return end

    local ghostColor = ghost:GetColor()
    local overlayColor = scaledOccludedPreviewColor(tool, baseAlpha or ghostColor.a or 255, stripeColorOverride)
    if not overlayColor then return end

    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilPassOperation(STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(STENCILOPERATION_REPLACE)

    render.OverrideColorWriteEnable(true, false)
    render.SetBlend(0)
    ghost:DrawModel()
    render.SetBlend(1)
    render.OverrideColorWriteEnable(false, true)

    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilPassOperation(STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(STENCILOPERATION_KEEP)

    local centerX, centerY = occludedStripeParallaxCenter(occludedStripeScreenCenter(ghost))
    drawScreenStripePattern(overlayColor, occludedStripeTileSize(ghost), centerX, centerY)

    render.SetStencilEnable(false)
end

local function drawPreviewOccludedCompatEntry(tool, entry, stripeColorOverride)
    if not istable(entry) or not IsValid(entry.ghost) then return end

    local color = entry.color or entry.ghost:GetColor()
    drawPreviewOccludedGhost(tool, entry.ghost, color and color.a or nil, stripeColorOverride)
end

local function drawPreviewOccludedCompatGhosts(tool, state, stripeColorOverride)
    local ghosts = state and state.compatGhosts
    if not istable(ghosts) then return end

    drawPreviewOccludedCompatEntry(tool, ghosts.main, stripeColorOverride)

    for _, entry in pairs(ghosts.linked or {}) do
        drawPreviewOccludedCompatEntry(tool, entry, stripeColorOverride)
    end
end

local function drawCircle2D(radius, color, segments)
    local material = ensureShapeWhiteMaterial()
    if material then
        surface.SetMaterial(material)
    else
        draw.NoTexture()
    end

    drawCircle2DAt(0, 0, radius, color, circlePointsForSegments(segments or RENDER_CONFIG.circleSegments))
end

local function drawRing2DByRadii(outerRadius, innerRadius, color, segments)
    local material = ensureShapeWhiteMaterial()
    if material then
        surface.SetMaterial(material)
    else
        draw.NoTexture()
    end

    drawRing2DByRadiiAt(0, 0, outerRadius, innerRadius, color, circlePointsForSegments(segments or RENDER_CONFIG.circleSegments))
end

local function beginBillboard(worldPos, viewerPos)
    if not isvector(worldPos) then return end

    viewerPos = isvector(viewerPos)
        and viewerPos
        or (IsValid(LocalPlayer()) and LocalPlayer():GetShootPos() or EyePos())

    local wx, wy, wz = numberOrZero(worldPos.x), numberOrZero(worldPos.y), numberOrZero(worldPos.z)
    local dx = numberOrZero(viewerPos.x) - wx
    local dy = numberOrZero(viewerPos.y) - wy
    local dz = numberOrZero(viewerPos.z) - wz
    local distanceSqr = dx * dx + dy * dy + dz * dz
    local toViewer
    if distanceSqr < 1e-8 then
        toViewer = setVecComponents(reusableBillboardToViewer, 0, 0, 1)
    else
        local invDistance = 1 / math.sqrt(distanceSqr)
        toViewer = setVecComponents(reusableBillboardToViewer, dx * invDistance, dy * invDistance, dz * invDistance)
    end

    local ang = toViewer:Angle()
    if isangle(ang) and isfunction(ang.RotateAroundAxis) and isfunction(ang.Right) then
        ang:RotateAroundAxis(ang:Right(), -90)
    else
        ang = M.RotateAngleAroundAxisPrecise(ang, M.AngleRightPrecise(ang), -90)
    end
    local pos = setVecComponents(
        reusableBillboardPos,
        wx + toViewer.x * RENDER_CONFIG.billboardPush,
        wy + toViewer.y * RENDER_CONFIG.billboardPush,
        wz + toViewer.z * RENDER_CONFIG.billboardPush
    )

    local drawPos = toVector(pos)
    local drawAng = toAngle(ang)
    if not drawPos or not drawAng then return end

    -- Eine einzelne, zum Viewport gedrehte 3D2D-Flaeche reicht hier aus.
    cam.Start3D2D(drawPos, drawAng, RENDER_CONFIG.billboardScale)
    return true
end

local function drawCircleSprite(worldPos, radius, color, settings, viewerPos)
    settings = settings or activeRingRenderSettings()

    local pixelRadius = radius / RENDER_CONFIG.billboardScale
    local primaryInnerRadius = resolvedRingInnerRadius(math.max(pixelRadius - math.max(pixelRadius * 0.18, 4), 0), pixelRadius)
    local circleSegments = circleSpriteSegments(settings)
    local cachedCircleRtSize = circleSpriteRtSize(settings)

    if not beginBillboard(worldPos, viewerPos) then return end

    local drewCached = false
    if settings and not settings.realtime and cachedCircleRtSize then
        local fillEntry, outlineEntry = ensureCachedCircleSprite(settings, pixelRadius, primaryInnerRadius, cachedCircleRtSize, circleSegments)
        drewCached = drawCachedCircleSpriteRect2D(pixelRadius, fillEntry, outlineEntry, color) == true
    end

    if not drewCached then
        drawCircle2D(pixelRadius, cappedAlpha(color, 220), circleSegments)
        drawRing2DByRadii(pixelRadius, primaryInnerRadius, cappedAlpha(color, 255), circleSegments)
    end

    cam.End3D2D()
end

local function drawRingSprite(worldPos, radius, thickness, color, settings, viewerPos, matchCircleQuality)
    settings = settings or activeRingRenderSettings()

    local pixelRadius = radius / RENDER_CONFIG.billboardScale
    local pixelThickness = math.max(thickness / RENDER_CONFIG.billboardScale, 4)
    local mainInnerRadius = resolvedRingInnerRadius(math.max(pixelRadius - pixelThickness, 0), pixelRadius)
    local accentOuterRadius = math.max(pixelRadius - pixelThickness * 0.7, 0)
    local accentInnerRadius = resolvedRingInnerRadius(
        math.max(accentOuterRadius - math.max(pixelThickness * 0.22, 2), 0),
        accentOuterRadius
    )
    local ringSegments = matchCircleQuality and circleSpriteSegments(settings) or ringRenderSegments(settings)
    local cachedRingRtSize = matchCircleQuality and circleSpriteRtSize(settings) or ringRtSize(settings)

    if not beginBillboard(worldPos, viewerPos) then return end

    local drewCached = false
    if settings and not settings.realtime and cachedRingRtSize then
        local mainEntry = ensureCachedShape("ring", cachedRingRtSize, mainInnerRadius / math.max(pixelRadius, 1e-6), ringSegments)
        local accentEntry = accentOuterRadius > 0
            and ensureCachedShape("ring", cachedRingRtSize, accentInnerRadius / math.max(accentOuterRadius, 1e-6), ringSegments)
            or nil

        if mainEntry and (accentOuterRadius <= 0 or accentEntry) then
            drawCachedShapeRect2D(pixelRadius, mainEntry, cappedAlpha(color, 255))
            if accentEntry then
                drawCachedShapeRect2D(accentOuterRadius, accentEntry, cappedAlpha(color, 150))
            end
            drewCached = true
        end
    end

    if not drewCached then
        drawRing2DByRadii(pixelRadius, mainInnerRadius, cappedAlpha(color, 255), ringSegments)
        if accentOuterRadius > 0 then
            drawRing2DByRadii(accentOuterRadius, accentInnerRadius, cappedAlpha(color, 150), ringSegments)
        end
    end

    cam.End3D2D()
end

local function drawRotationRingTicks(origin, a, b, radius, size, ticks, color)
    if not istable(ticks) or #ticks == 0 then return end

    local minorInner = math.max(size * 0.022, 0.65)
    local majorInner = math.max(size * 0.048, 1.4)
    local major45Inner = math.max(size * 0.062, 1.9)

    for i = 1, #ticks do
        local tick = ticks[i]
        local angle = math.rad(tick.angle)
        local direction = a * math.cos(angle) + b * math.sin(angle)
        local inner = client.RotationRender.isFortyFiveTick(tick.angle) and major45Inner or tick.major and majorInner or minorInner

        drawLine(origin + direction * (radius - inner), origin + direction * radius, color, true)
    end
end

local function drawPlaneSquare(worldPos, axisA, axisB, halfSize, color, outline, flipNormal, flipFace)
    if not isvector(worldPos) or not isvector(axisA) or not isvector(axisB) then return end
    if axisA:LengthSqr() < 1e-8 or axisB:LengthSqr() < 1e-8 then return end

    local a = axisA:GetNormalized() * halfSize
    local b = axisB:GetNormalized() * halfSize
    local normal = a:Cross(b)
    if normal:LengthSqr() < 1e-8 then return end
    normal:Normalize()
    if flipNormal then
        normal = -normal
    end

    local push = normal * 0.12
    local p1 = worldPos - a - b + push
    local p2 = worldPos + a - b + push
    local p3 = worldPos + a + b + push
    local p4 = worldPos - a + b + push
    local edge = outline or colorAlpha(color, 255)

    if flipFace then
        p2, p4 = p4, p2
    end

    render.SetColorMaterial()
    drawQuad(p1, p2, p3, p4, colorAlpha(color, color.a or 160))
    drawLine(p1, p2, edge, true)
    drawLine(p2, p3, edge, true)
    drawLine(p3, p4, edge, true)
    drawLine(p4, p1, edge, true)
end

local function pushTriangle(a, b, c, color)
    meshPosition(a)
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()

    meshPosition(b)
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()

    meshPosition(c)
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()
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

local function rotationRingBandRadii(radius, padding)
    radius = tonumber(radius) or 0
    if radius <= 0 then return end

    local halfWidth = math.max((tonumber(padding) or 0) * 0.5, ROTATION_CONFIG.ringMinHalfWidth)
    local outerRadius = radius + halfWidth
    local innerRadius = resolvedRingInnerRadius(math.max(radius - halfWidth, 0.01), outerRadius)
    if innerRadius >= outerRadius then return end

    return innerRadius, outerRadius
end

local function ringPlanePoint(origin, axisA, axisB, angleDegrees, pointRadius)
    local angle = math.rad(angleDegrees)
    local dir = axisA * math.cos(angle) + axisB * math.sin(angle)
    return origin + dir * pointRadius
end

local function drawRotationRingBandRealtime(origin, axisA, axisB, innerRadius, outerRadius, fill, edge, segments)
    local material = ensureShapeWhiteMaterial()
    if material then
        render.SetMaterial(material)
        mesh.Begin(MATERIAL_TRIANGLES, segments * 2)
            for step = 0, segments - 1 do
                local angle1 = (step / segments) * 360
                local angle2 = ((step + 1) / segments) * 360
                local outer1 = ringPlanePoint(origin, axisA, axisB, angle1, outerRadius)
                local outer2 = ringPlanePoint(origin, axisA, axisB, angle2, outerRadius)
                local inner1 = ringPlanePoint(origin, axisA, axisB, angle1, innerRadius)
                local inner2 = ringPlanePoint(origin, axisA, axisB, angle2, innerRadius)

                pushTexturedWorldVertex(outer1, 0, 0, fill)
                pushTexturedWorldVertex(outer2, 0, 0, fill)
                pushTexturedWorldVertex(inner2, 0, 0, fill)

                pushTexturedWorldVertex(outer1, 0, 0, fill)
                pushTexturedWorldVertex(inner2, 0, 0, fill)
                pushTexturedWorldVertex(inner1, 0, 0, fill)
            end
        mesh.End()
    end

    for step = 0, segments - 1 do
        local angle1 = (step / segments) * 360
        local angle2 = ((step + 1) / segments) * 360

        drawLine(ringPlanePoint(origin, axisA, axisB, angle1, outerRadius), ringPlanePoint(origin, axisA, axisB, angle2, outerRadius), edge, true)
        drawLine(ringPlanePoint(origin, axisA, axisB, angle1, innerRadius), ringPlanePoint(origin, axisA, axisB, angle2, innerRadius), edge, true)
    end
end

local function drawRotationSectorMask(origin, axisA, axisB, radius, startAngle, delta, segments)
    render.SetColorMaterial()
    mesh.Begin(MATERIAL_TRIANGLES, segments * 2)
        for step = 0, segments - 1 do
            local angle1 = startAngle + delta * (step / segments)
            local angle2 = startAngle + delta * ((step + 1) / segments)
            local point1 = ringPlanePoint(origin, axisA, axisB, angle1, radius)
            local point2 = ringPlanePoint(origin, axisA, axisB, angle2, radius)

            pushTriangle(origin, point1, point2, color_white)
            pushTriangle(origin, point2, point1, color_white)
        end
    mesh.End()
end

local function drawRotationDeltaSectorRealtime(origin, axisA, axisB, radius, startAngle, delta, fill, edge, segments)
    local material = ensureShapeWhiteMaterial()
    if material then
        render.SetMaterial(material)
        mesh.Begin(MATERIAL_TRIANGLES, segments * 2)
            for step = 0, segments - 1 do
                local angle1 = startAngle + delta * (step / segments)
                local angle2 = startAngle + delta * ((step + 1) / segments)
                local point1 = ringPlanePoint(origin, axisA, axisB, angle1, radius)
                local point2 = ringPlanePoint(origin, axisA, axisB, angle2, radius)

                pushTexturedWorldVertex(origin, 0, 0, fill)
                pushTexturedWorldVertex(point1, 0, 0, fill)
                pushTexturedWorldVertex(point2, 0, 0, fill)

                pushTexturedWorldVertex(origin, 0, 0, fill)
                pushTexturedWorldVertex(point2, 0, 0, fill)
                pushTexturedWorldVertex(point1, 0, 0, fill)
            end
        mesh.End()
    end

    for step = 0, segments - 1 do
        local angle1 = startAngle + delta * (step / segments)
        local angle2 = startAngle + delta * ((step + 1) / segments)
        drawLine(ringPlanePoint(origin, axisA, axisB, angle1, radius), ringPlanePoint(origin, axisA, axisB, angle2, radius), edge, true)
    end

    drawLine(origin, ringPlanePoint(origin, axisA, axisB, startAngle, radius), edge, true)
    drawLine(origin, ringPlanePoint(origin, axisA, axisB, startAngle + delta, radius), edge, true)
end

local function drawRotationRingBand(origin, a, b, radius, padding, color, edgeColor, settings)
    if not isvector(origin) or not isvector(a) or not isvector(b) then return end
    if a:LengthSqr() < 1e-8 or b:LengthSqr() < 1e-8 then return end

    settings = settings or activeRingRenderSettings()

    local innerRadius, outerRadius = rotationRingBandRadii(radius, padding)
    if not innerRadius or not outerRadius then return end

    local axisA = a:GetNormalized()
    local axisB = b:GetNormalized()
    local baseColor = color or color_white
    local fill = cappedAlpha(baseColor, ROTATION_CONFIG.ringFillAlpha)
    local edge = edgeColor or cappedAlpha(baseColor, ROTATION_CONFIG.ringEdgeAlpha)
    local segments = ringRenderSegments(settings)
    local cachedRingRtSize = ringRtSize(settings)

    if not settings.realtime and cachedRingRtSize then
        local entry = ensureCachedShape("ring_band", cachedRingRtSize, innerRadius / outerRadius, segments)
        if drawCachedShapePlane(origin, axisA, axisB, outerRadius, entry, baseColor) then
            return
        end
    end

    drawRotationRingBandRealtime(origin, axisA, axisB, innerRadius, outerRadius, fill, edge, segments)
end

local function drawRotationDeltaSector(origin, a, b, radius, padding, startAngle, currentAngle, color, settings)
    if not isvector(origin) or not isvector(a) or not isvector(b) then return end
    if a:LengthSqr() < 1e-8 or b:LengthSqr() < 1e-8 then return end

    settings = settings or activeRingRenderSettings()

    radius = tonumber(radius) or 0
    startAngle = tonumber(startAngle)
    currentAngle = tonumber(currentAngle)
    if radius <= 0 or not startAngle or not currentAngle then return end

    local delta = math.AngleDifference(currentAngle, startAngle)
    if math.abs(delta) <= 0.05 then return end

    local ringPadding = tonumber(padding) or 0
    local bandHalfWidth = math.max(ringPadding * 0.5, ROTATION_CONFIG.ringMinHalfWidth)
    local gap = math.max(ringPadding * 0.16, 0.03)
    local discRadius = math.max(radius - bandHalfWidth - gap, 0.01)
    local axisA = a:GetNormalized()
    local axisB = b:GetNormalized()
    local fill = cappedAlpha(color or color_white, ROTATION_CONFIG.deltaSectorAlpha)
    local edge = cappedAlpha(color or color_white, ROTATION_CONFIG.deltaSectorEdgeAlpha)
    local segmentsPerCircle = ringRenderSegments(settings)
    local segments = math.Clamp(math.ceil(math.abs(delta) / 360 * segmentsPerCircle), 1, segmentsPerCircle)
    local cachedRingRtSize = ringRtSize(settings)

    if not settings.realtime and cachedRingRtSize and stencilAvailable() then
        local entry = ensureCachedShape("disc", cachedRingRtSize, nil, segmentsPerCircle)
        if entry then
            render.ClearStencil()
            render.SetStencilEnable(true)
            render.SetStencilWriteMask(255)
            render.SetStencilTestMask(255)
            render.SetStencilReferenceValue(1)
            render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
            render.SetStencilFailOperation(STENCILOPERATION_KEEP)
            render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
            render.SetStencilZFailOperation(STENCILOPERATION_REPLACE)

            render.OverrideColorWriteEnable(true, false)
            render.SetBlend(0)
            drawRotationSectorMask(origin, axisA, axisB, discRadius, startAngle, delta, segments)
            render.SetBlend(1)
            render.OverrideColorWriteEnable(false, true)

            render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
            render.SetStencilFailOperation(STENCILOPERATION_KEEP)
            render.SetStencilPassOperation(STENCILOPERATION_KEEP)
            render.SetStencilZFailOperation(STENCILOPERATION_KEEP)

            drawCachedShapePlane(origin, axisA, axisB, discRadius, entry, fill, true)

            render.SetStencilEnable(false)

            drawLine(origin, ringPlanePoint(origin, axisA, axisB, startAngle, discRadius), edge, true)
            drawLine(origin, ringPlanePoint(origin, axisA, axisB, startAngle + delta, discRadius), edge, true)
            return
        end
    end

    drawRotationDeltaSectorRealtime(origin, axisA, axisB, discRadius, startAngle, delta, fill, edge, segments)
end

local function componentForAxisKey(v, key)
    return key == "x" and v.x or key == "y" and v.y or v.z
end

local function handleUsesAxis(item, key)
    if not item or not key then return false end

    if item.kind == "move" then
        return item.key == key
    elseif item.kind == "plane" then
        return item.key:find(key, 1, true) ~= nil
    end

    return false
end

local function axisVectorsForKey(basis, key)
    if not isangle(basis) then return end

    local forward, right, up = M.AngleAxesPrecise(basis)
    if key == "x" then
        return forward, right, up
    elseif key == "y" then
        return right, forward, up
    end

    return up, forward, right
end

local function translationDisplayDistance(key, distance)
    local sign = key == "y" and -1 or 1
    return (tonumber(distance) or 0) * sign
end

local function activeTranslationSnapStep(tool, state)
    local fallback = tool and tool.GetClientInfo and tonumber(tool:GetClientInfo("translation_snap")) or nil
    local step = client.translationSnapStep(tool) or math.Clamp(tonumber(fallback) or 0, 0, 62)
    if step <= 0 then return 0 end

    local settings = state and state.hover and state.hover.settings
    if settings and settings.shift then
        return 0
    end

    if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
        return 0
    end

    return step
end

local function currentTranslationLocalPos(press)
    if press and isvector(press.currentGizmoPos) then
        return press.currentGizmoPos
    end

    if press and isvector(press.dragStartLocal) then
        return press.dragStartLocal
    end

    return ZERO_VEC
end

local function translationSnapOverlayColor(press)
    local gizmoColor = press and press.gizmo and press.gizmo.color or nil
    if istable(gizmoColor) and gizmoColor.r ~= nil and gizmoColor.g ~= nil and gizmoColor.b ~= nil then
        return gizmoColor
    end

    if press and press.gizmo and colors[press.gizmo.key] then
        return colors[press.gizmo.key]
    end

    return color_white
end

local function drawTranslationAxisTicks(press, size, step, spriteSettings, viewerPos)
    if not press or not press.gizmo or press.gizmo.kind ~= "move" then return end
    if not isvector(press.origin) or not isangle(press.basis) then return end

    local axisDir = select(1, axisVectorsForKey(press.basis, press.gizmo.key))
    if not isvector(axisDir) then return end

    local currentLocal = currentTranslationLocalPos(press)
    local currentIndex = math.Round(componentForAxisKey(currentLocal, press.gizmo.key) / step)
    local halfWindow = math.floor(TRANSLATION_CONFIG.axisTickCount * 0.5)
    local minIndex = currentIndex - halfWindow
    local maxIndex = currentIndex + halfWindow
    local baseColor = translationSnapOverlayColor(press)

    for index = minIndex, maxIndex do
        local worldPos = press.origin + axisDir * translationDisplayDistance(press.gizmo.key, index * step)
        local isCurrent = index == currentIndex
        local isMajor = index == 0 or math.abs(index) % 5 == 0

        local pointRadius = math.Min(step * 0.25, 2.5)
        local pointColor = isCurrent and colorAlpha(color_white, 228) or colorAlpha(baseColor, isMajor and 128 or 82)
        drawCircleSprite(worldPos, pointRadius, pointColor, spriteSettings, viewerPos)
    end

    local currentWorldPos = press.origin + axisDir * translationDisplayDistance(press.gizmo.key, currentIndex * step)
    drawRingSprite(currentWorldPos, math.Clamp(size * 0.042, 0.65, 1.4), math.Clamp(size * 0.012, 0.18, 0.42), color_white, spriteSettings, viewerPos)
end

local function drawTranslationPlaneGrid(press, size, step, spriteSettings, viewerPos)
    if not press or not press.gizmo or press.gizmo.kind ~= "plane" then return end
    if not isvector(press.origin) or not isangle(press.basis) then return end

    local first = press.gizmo.key:sub(1, 1)
    local second = press.gizmo.key:sub(2, 2)
    local axisA = select(1, axisVectorsForKey(press.basis, first))
    local axisB = select(1, axisVectorsForKey(press.basis, second))
    if not isvector(axisA) or not isvector(axisB) then return end

    local currentLocal = currentTranslationLocalPos(press)
    local currentIndexA = math.Round(componentForAxisKey(currentLocal, first) / step)
    local currentIndexB = math.Round(componentForAxisKey(currentLocal, second) / step)
    local minA = currentIndexA - TRANSLATION_CONFIG.gridHalfCells
    local maxA = currentIndexA + TRANSLATION_CONFIG.gridHalfCells
    local minB = currentIndexB - TRANSLATION_CONFIG.gridHalfCells
    local maxB = currentIndexB + TRANSLATION_CONFIG.gridHalfCells
    local baseColor = translationSnapOverlayColor(press)

    for index = minA, maxA do
        local lineStart = press.origin
            + axisA * translationDisplayDistance(first, index * step)
            + axisB * translationDisplayDistance(second, minB * step)
        local lineEnd = press.origin
            + axisA * translationDisplayDistance(first, index * step)
            + axisB * translationDisplayDistance(second, maxB * step)
        local isCurrent = index == currentIndexA
        --local isMajor = index == 0 or math.abs(index) % 5 == 0
        local lineColor = isCurrent and colorAlpha(color_white, 200) or colorAlpha(baseColor, 120)
        drawLine(lineStart, lineEnd, lineColor, false)
    end

    for index = minB, maxB do
        local lineStart = press.origin
            + axisA * translationDisplayDistance(first, minA * step)
            + axisB * translationDisplayDistance(second, index * step)
        local lineEnd = press.origin
            + axisA * translationDisplayDistance(first, maxA * step)
            + axisB * translationDisplayDistance(second, index * step)
        local isCurrent = index == currentIndexB
        --local isMajor = index == 0 or math.abs(index) % 5 == 0
        local lineColor = isCurrent and colorAlpha(color_white, 200) or colorAlpha(baseColor, 120)
        drawLine(lineStart, lineEnd, lineColor, false)
    end

    local currentWorldPos = press.origin
        + axisA * translationDisplayDistance(first, currentIndexA * step)
        + axisB * translationDisplayDistance(second, currentIndexB * step)
    drawRingSprite(currentWorldPos, math.Clamp(size * 0.045, 0.7, 1.5), math.Clamp(size * 0.012, 0.18, 0.42), color_white, spriteSettings, viewerPos)
end

local function drawTranslationSnapOverlay(tool, state, g, spriteSettings, viewerPos)
    local press = state and state.press
    if not press or press.kind ~= "gizmo" or not press.gizmo then return end

    local step = activeTranslationSnapStep(tool, state)
    if step <= 0 then return end

    local size = g and g.size or 32
    if press.gizmo.kind == "move" then
        drawTranslationAxisTicks(press, size, step, spriteSettings, viewerPos)
    elseif press.gizmo.kind == "plane" then
        drawTranslationPlaneGrid(press, size, step, spriteSettings, viewerPos)
    end
end

local reusablePointWorldPositions = {}
local reusablePointLocalPositions = {}
local reusablePointAnchorLocalPositions = {}
local reusablePointAnchorWorldPositions = {}

local function drawDoubleSidedPlaneSquare(worldPos, axisA, axisB, halfSize, outline, preferredNormal)
    if not isvector(worldPos) or not isvector(axisA) or not isvector(axisB) then return end
    if axisA:LengthSqr() < 1e-8 or axisB:LengthSqr() < 1e-8 then return end

    local a = axisA:GetNormalized() * halfSize
    local b = axisB:GetNormalized() * halfSize
    local normal = a:Cross(b)
    if normal:LengthSqr() < 1e-8 then return end
    normal:Normalize()
    if isvector(preferredNormal) and preferredNormal:LengthSqr() >= 1e-8 and normal:Dot(preferredNormal) < 0 then
        normal = -normal
    end

    local push = normal * 0.12
    local p1 = worldPos - a - b + push
    local p2 = worldPos + a - b + push
    local p3 = worldPos + a + b + push
    local p4 = worldPos - a + b + push
    local edge = outline or color_white

    drawLine(p1, p2, edge, true)
    drawLine(p2, p3, edge, true)
    drawLine(p3, p4, edge, true)
    drawLine(p4, p1, edge, true)
end

local function activeTraceMarkerDirection(state, g, key)
    local press = state.press
    if not press or press.kind ~= "gizmo" or not press.gizmo then return end
    if press.gizmo.kind ~= "move" and press.gizmo.kind ~= "plane" then return end
    if not handleUsesAxis(press.gizmo, key) then return end

    local entry = istable(press.traceSnapAxes) and press.traceSnapAxes[key] or nil
    local direction = entry and entry.direction or nil
    if not isvector(direction) or direction:LengthSqr() < 1e-8 then return end

    return direction:GetNormalized(), entry
end

local function drawFilledTraceSnapSquare(worldPos, axisA, axisB, halfSize, color)
    if not isvector(worldPos) or not isvector(axisA) or not isvector(axisB) then return end
    if axisA:LengthSqr() < 1e-8 or axisB:LengthSqr() < 1e-8 then return end

    local a = axisA:GetNormalized() * halfSize
    local b = axisB:GetNormalized() * halfSize
    local normal = a:Cross(b)
    if normal:LengthSqr() < 1e-8 then return end
    normal:Normalize()

    local push = normal * 0.12
    local p1 = worldPos - a - b + push
    local p2 = worldPos + a - b + push
    local p3 = worldPos + a + b + push
    local p4 = worldPos - a + b + push
    local outline = colorAlpha(color, 255)
    local fill = colorAlpha(color, 76)

    drawFilledQuad(p1, p2, p3, p4, fill)
    drawLine(p1, p2, outline, true)
    drawLine(p2, p3, outline, true)
    drawLine(p3, p4, outline, true)
    drawLine(p4, p1, outline, true)
end

local function drawOutlineTraceSnapSquare(worldPos, axisA, axisB, halfSize, color, preferredNormal)
    drawDoubleSidedPlaneSquare(worldPos, axisA, axisB, halfSize, colorAlpha(color, 244), preferredNormal)
end

local function drawTraceSnapHitCluster(center, outwardDir, axisA, axisB, halfSize, color, traceLength)
    if not isvector(center) or not isvector(outwardDir) or outwardDir:LengthSqr() < 1e-8 then return end

    local dir = outwardDir:GetNormalized()
    local mainHalfSize = halfSize * 2.36
    local copyOffset = math.max((tonumber(traceLength) or 0) * 0.191, 0.01)

    drawFilledTraceSnapSquare(center, axisA, axisB, mainHalfSize, color)
    drawOutlineTraceSnapSquare(center - dir * copyOffset, axisA, axisB, mainHalfSize, color, -dir)
    drawOutlineTraceSnapSquare(center - dir * (copyOffset * 2), axisA, axisB, mainHalfSize, color, -dir)
end

local function drawTraceSnapAxisMarker(origin, direction, axisA, axisB, distance, halfSize, color, traceEntry)
    if distance <= 0 or halfSize <= 0 then return end
    if not isvector(origin) or not isvector(direction) or direction:LengthSqr() < 1e-8 then return end

    local dir = direction:GetNormalized()
    local positiveCenter = origin + dir * distance
    local negativeCenter = origin - dir * distance

    if not istable(traceEntry) then
        drawOutlineTraceSnapSquare(positiveCenter, axisA, axisB, halfSize, color, dir)
        drawOutlineTraceSnapSquare(negativeCenter, axisA, axisB, halfSize, color, -dir)
        return
    end

    if traceEntry.positiveHit then
        drawTraceSnapHitCluster(positiveCenter, dir, axisA, axisB, halfSize, color, distance)
    else
        drawOutlineTraceSnapSquare(positiveCenter, axisA, axisB, halfSize, color, dir)
    end

    if traceEntry.negativeHit then
        drawTraceSnapHitCluster(negativeCenter, -dir, axisA, axisB, halfSize, color, distance)
    else
        drawOutlineTraceSnapSquare(negativeCenter, axisA, axisB, halfSize, color, -dir)
    end
end

local function drawFilledTriangle(a, b, c, color)
    render.SetColorMaterial()
    mesh.Begin(MATERIAL_TRIANGLES, 2)
        pushTriangle(a, b, c, color)
        pushTriangle(c, b, a, color)
    mesh.End()
end

local function pushTexturedVertex(position, u, v, color)
    meshPosition(position)
    mesh.TexCoord(0, u, v)
    mesh.Color(color.r, color.g, color.b, color.a)
    mesh.AdvanceVertex()
end

local function drawTexturedTriangle(a, b, c, uvA, uvB, uvC, color, material)
    if not material then return end

    render.SetMaterial(material)
    mesh.Begin(MATERIAL_TRIANGLES, 2)
        pushTexturedVertex(a, uvA.u, uvA.v, color)
        pushTexturedVertex(b, uvB.u, uvB.v, color)
        pushTexturedVertex(c, uvC.u, uvC.v, color)

        pushTexturedVertex(c, uvC.u, uvC.v, color)
        pushTexturedVertex(b, uvB.u, uvB.v, color)
        pushTexturedVertex(a, uvA.u, uvA.v, color)
    mesh.End()
end

local reusableTriangleUV = { {}, {}, {} }
local reusableTrianglePositions = {
    pa = newRenderVector(0, 0, 0),
    pb = newRenderVector(0, 0, 0),
    pc = newRenderVector(0, 0, 0)
}

ensureStripePatternMaterial = function()
    if not stripePatternTexture then
        stripePatternTexture = GetRenderTargetEx(
        STRIPE_CONFIG.patternName .. "_rt",
        STRIPE_CONFIG.rtSize,
        STRIPE_CONFIG.rtSize,
            RT_SIZE_NO_CHANGE,
            MATERIAL_RT_DEPTH_NONE,
            0,
            0,
            IMAGE_FORMAT_RGBA8888
        )
    end

    if not stripeTrianglePatternTexture then
        stripeTrianglePatternTexture = GetRenderTargetEx(
        STRIPE_CONFIG.patternName .. "_triangle_rt",
        STRIPE_CONFIG.rtSize,
        STRIPE_CONFIG.rtSize,
            RT_SIZE_NO_CHANGE,
            MATERIAL_RT_DEPTH_NONE,
            0,
            0,
            IMAGE_FORMAT_RGBA8888
        )
    end

    if not stripePatternMaterial then
    stripePatternMaterial = CreateMaterial(STRIPE_CONFIG.patternName .. "_mat", "UnlitGeneric", {
            ["$basetexture"] = stripePatternTexture:GetName(),
            ["$translucent"] = "1",
            ["$additive"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1",
            ["$model"] = "1"
        })
    end

    if not stripeTrianglePatternMaterial then
    stripeTrianglePatternMaterial = CreateMaterial(STRIPE_CONFIG.patternName .. "_triangle_mat", "UnlitGeneric", {
            ["$basetexture"] = stripeTrianglePatternTexture:GetName(),
            ["$translucent"] = "1",
            ["$additive"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1",
            ["$model"] = "1"
        })
    end

    if not stripePatternScreenMaterial then
    stripePatternScreenMaterial = CreateMaterial(STRIPE_CONFIG.patternName .. "_screen_mat", "UnlitGeneric", {
            ["$basetexture"] = stripePatternTexture:GetName(),
            ["$translucent"] = "1",
            ["$additive"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1"
        })
    end

    stripePatternMaterial:SetTexture("$basetexture", stripePatternTexture)
    stripeTrianglePatternMaterial:SetTexture("$basetexture", stripeTrianglePatternTexture)
    stripePatternScreenMaterial:SetTexture("$basetexture", stripePatternTexture)
    local materialFlags = stripePatternMaterial:GetInt("$flags") or 0
    local requiredFlags = bit.bor(materialFlags, STRIPE_CONFIG.materialFlags)
    if materialFlags ~= requiredFlags then
        stripePatternMaterial:SetInt("$flags", requiredFlags)
    end
    materialFlags = stripeTrianglePatternMaterial:GetInt("$flags") or 0
    requiredFlags = bit.bor(materialFlags, STRIPE_CONFIG.materialFlags)
    if materialFlags ~= requiredFlags then
        stripeTrianglePatternMaterial:SetInt("$flags", requiredFlags)
    end

    if not stripePatternReady then
        local stripeSize = stripePatternStripeSize()

        render.PushRenderTarget(stripePatternTexture)
        render.Clear(0, 0, 0, 0, true, true)
        cam.Start2D()
            -- Named render targets survive Lua refreshes; copy exact intensity values into the RT.
            setStripePatternCopyBlend(true)
        drawStripePatternRect(0, 0, 0, STRIPE_CONFIG.rtSize, STRIPE_CONFIG.rtSize)
        drawStripePatternRect(STRIPE_CONFIG.fillAlpha, 0, 0, STRIPE_CONFIG.rtSize, STRIPE_CONFIG.rtSize)
        drawStripePatternRect(STRIPE_CONFIG.stripeAlpha, 0, 0, STRIPE_CONFIG.rtSize, stripeSize)
            setStripePatternCopyBlend(false)
        cam.End2D()
        render.PopRenderTarget()

        render.PushRenderTarget(stripeTrianglePatternTexture)
        render.Clear(0, 0, 0, 0, true, true)
        cam.Start2D()
            setStripePatternCopyBlend(true)
        drawStripePatternRect(0, 0, 0, STRIPE_CONFIG.rtSize, STRIPE_CONFIG.rtSize)
        drawStripePatternRect(STRIPE_CONFIG.fillAlpha, 0, 0, STRIPE_CONFIG.rtSize, STRIPE_CONFIG.rtSize)
        drawStripePatternDiagonal(STRIPE_CONFIG.stripeAlpha)
            setStripePatternCopyBlend(false)
        cam.End2D()
        render.PopRenderTarget()

        stripePatternReady = true
    end

    return stripeTrianglePatternMaterial
end

local function queueStripePatternRebuild()
    stripePatternReady = false

    hook.Remove("PostRender", STRIPE_CONFIG.rebuildHook)
    hook.Add("PostRender", STRIPE_CONFIG.rebuildHook, function()
        ensureStripePatternMaterial()
        hook.Remove("PostRender", STRIPE_CONFIG.rebuildHook)
    end)
end

queueStripePatternRebuild()

if cvars and cvars.AddChangeCallback then
    if cvars.RemoveChangeCallback then
    cvars.RemoveChangeCallback(RENDER_CONFIG.ringQualityCvar, SHAPE_CONFIG.rebuildCallback)
    end

    cvars.AddChangeCallback(RENDER_CONFIG.ringQualityCvar, function(_, _, newValue)
        queueShapeCacheWarmup(nil, newValue)
    end, SHAPE_CONFIG.rebuildCallback)
end

queueShapeCacheWarmup()

local function drawStripedTriangle(a, b, c, frontColor, stripePhase, viewerPos)
    if not isvector(a) or not isvector(b) or not isvector(c) then return end

    local ax, ay, az = numberOrZero(a.x), numberOrZero(a.y), numberOrZero(a.z)
    local bx0, by0, bz0 = numberOrZero(b.x), numberOrZero(b.y), numberOrZero(b.z)
    local cx0, cy0, cz0 = numberOrZero(c.x), numberOrZero(c.y), numberOrZero(c.z)
    local abx, aby, abz = bx0 - ax, by0 - ay, bz0 - az
    local acx, acy, acz = cx0 - ax, cy0 - ay, cz0 - az
    local normalX = aby * acz - abz * acy
    local normalY = abz * acx - abx * acz
    local normalZ = abx * acy - aby * acx
    local normalLengthSqr = normalX * normalX + normalY * normalY + normalZ * normalZ
    if normalLengthSqr < 1e-8 then return end
    local invNormalLength = 1 / math.sqrt(normalLengthSqr)
    normalX, normalY, normalZ = normalX * invNormalLength, normalY * invNormalLength, normalZ * invNormalLength

    viewerPos = isvector(viewerPos)
        and viewerPos
        or setVec(shapeMetricCache.renderPerf.fallbackViewerPos, IsValid(LocalPlayer()) and LocalPlayer():GetShootPos() or EyePos())
    shapeMetricCache.renderPerf.fallbackViewerPos = viewerPos
    local centerX, centerY, centerZ = (ax + bx0 + cx0) / 3, (ay + by0 + cy0) / 3, (az + bz0 + cz0) / 3
    local viewerX, viewerY, viewerZ = numberOrZero(viewerPos.x), numberOrZero(viewerPos.y), numberOrZero(viewerPos.z)
    local frontFacing = normalX * (viewerX - centerX) + normalY * (viewerY - centerY) + normalZ * (viewerZ - centerZ) >= 0
    local visibleNormalScale = frontFacing and 0.08 or -0.08
    local pushX, pushY, pushZ = normalX * visibleNormalScale, normalY * visibleNormalScale, normalZ * visibleNormalScale
    local tintColor = frontFacing
        and cachedColor(frontColor.r, frontColor.g, frontColor.b, 220)
        or cachedColor(155, 155, 155, 255)
    local edgeColor = frontFacing and cappedAlpha(frontColor, 36) or cachedColor(165, 165, 165, 32)

    local pa = setVecComponents(reusableTrianglePositions.pa, ax + pushX, ay + pushY, az + pushZ)
    local pb = setVecComponents(reusableTrianglePositions.pb, bx0 + pushX, by0 + pushY, bz0 + pushZ)
    local pc = setVecComponents(reusableTrianglePositions.pc, cx0 + pushX, cy0 + pushY, cz0 + pushZ)

    local abLengthSqr = abx * abx + aby * aby + abz * abz
    if abLengthSqr < 1e-8 then return end
    local bx = math.sqrt(abLengthSqr)
    local invAbLength = 1 / bx
    local ux, uy, uz = abx * invAbLength, aby * invAbLength, abz * invAbLength
    local cx = acx * ux + acy * uy + acz * uz
    local vx, vy, vz = acx - ux * cx, acy - uy * cx, acz - uz * cx
    local vLenSqr = vx * vx + vy * vy + vz * vz
    if vLenSqr < 1e-8 then return end

    local cy = math.sqrt(vLenSqr)
    local stripePeriod = STATIC_TRIANGLE_STRIPE_PERIOD
    local phase = ((tonumber(stripePhase) or 0) % 1)
    local stripeMaterial = ensureStripePatternMaterial()

    if stripeMaterial then
        reusableTriangleUV[1].u = 0
        reusableTriangleUV[1].v = -phase
        reusableTriangleUV[2].u = bx / stripePeriod
        reusableTriangleUV[2].v = -phase
        reusableTriangleUV[3].u = cx / stripePeriod
        reusableTriangleUV[3].v = cy / stripePeriod - phase

        drawTexturedTriangle(
            pa,
            pb,
            pc,
            reusableTriangleUV[1],
            reusableTriangleUV[2],
            reusableTriangleUV[3],
            scaledAlphaColor(tintColor, STRIPE_CONFIG.triangleAlphaScale),
            stripeMaterial
        )
    else
        drawFilledTriangle(pa, pb, pc, frontFacing and cappedAlpha(frontColor, STRIPE_CONFIG.fillAlpha) or cachedColor(105, 105, 105, STRIPE_CONFIG.fillAlpha))
    end

    drawLine(pa, pb, edgeColor, false)
    drawLine(pb, pc, edgeColor, false)
    drawLine(pc, pa, edgeColor, false)
end

local function drawAxisArrow(startPos, endPos, color, viewerPos)
    if renderPrimitives and isfunction(renderPrimitives.DrawAxisArrow) then
        return renderPrimitives.DrawAxisArrow(startPos, endPos, color, viewerPos)
    end
end

local function drawFrame(pos, ang, size, alpha)
    render.DrawLine(toVector(pos), toVector(pos + ang:Forward() * size), cachedColor(colors.x.r, colors.x.g, colors.x.b, alpha), true)
    render.DrawLine(toVector(pos), toVector(pos + ang:Right() * size), cachedColor(colors.y.r, colors.y.g, colors.y.b, alpha), true)
    render.DrawLine(toVector(pos), toVector(pos + ang:Up() * size), cachedColor(colors.z.r, colors.z.g, colors.z.b, alpha), true)
end

local function shouldDrawPointTriangle(spriteSettings)
    return not (spriteSettings and spriteSettings.hidePointTriangles == true)
end

local function anchorPercent(options, key)
    return ((options and options[key .. "_pct"]) or M.ANCHOR_PERCENT_DEFAULT) * 0.01
end

local function lerpPointFast(a, b, t)
    return VectorP(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    )
end

local function anchorPointFast(points, id, options)
    local p1, p2, p3 = points[1], points[2], points[3]

    if id == "p1" then return p1 end
    if id == "p2" then return p2 end
    if id == "p3" then return p3 end
    if id == "mid12" and p1 and p2 then return lerpPointFast(p1, p2, anchorPercent(options, "mid12")) end
    if id == "mid23" and p2 and p3 then return lerpPointFast(p2, p3, anchorPercent(options, "mid23")) end
    if id == "mid13" and p1 and p3 then return lerpPointFast(p1, p3, anchorPercent(options, "mid13")) end

    if id == M.ANCHOR_CENTER_ID and p1 and p2 and p3 then
        local m12 = lerpPointFast(p1, p2, anchorPercent(options, "mid12"))
        local m23 = lerpPointFast(p2, p3, anchorPercent(options, "mid23"))
        local m13 = lerpPointFast(p1, p3, anchorPercent(options, "mid13"))

        return VectorP(
            (m12.x + m23.x + m13.x) / 3,
            (m12.y + m23.y + m13.y) / 3,
            (m12.z + m23.z + m13.z) / 3
        )
    end
end

local function lerpPointInto(out, a, b, t)
    if not isvector(a) or not isvector(b) then return end

    return setVecComponents(
        out,
        numberOrZero(a.x) + (numberOrZero(b.x) - numberOrZero(a.x)) * t,
        numberOrZero(a.y) + (numberOrZero(b.y) - numberOrZero(a.y)) * t,
        numberOrZero(a.z) + (numberOrZero(b.z) - numberOrZero(a.z)) * t
    )
end

local function anchorPointInto(out, points, id, options)
    local p1, p2, p3 = points[1], points[2], points[3]

    if id == "p1" then return p1 end
    if id == "p2" then return p2 end
    if id == "p3" then return p3 end
    if id == "mid12" then return lerpPointInto(out, p1, p2, anchorPercent(options, "mid12")) end
    if id == "mid23" then return lerpPointInto(out, p2, p3, anchorPercent(options, "mid23")) end
    if id == "mid13" then return lerpPointInto(out, p1, p3, anchorPercent(options, "mid13")) end

    if id == M.ANCHOR_CENTER_ID and p1 and p2 and p3 then
        local t12 = anchorPercent(options, "mid12")
        local t23 = anchorPercent(options, "mid23")
        local t13 = anchorPercent(options, "mid13")
        local p1x, p1y, p1z = numberOrZero(p1.x), numberOrZero(p1.y), numberOrZero(p1.z)
        local p2x, p2y, p2z = numberOrZero(p2.x), numberOrZero(p2.y), numberOrZero(p2.z)
        local p3x, p3y, p3z = numberOrZero(p3.x), numberOrZero(p3.y), numberOrZero(p3.z)
        local m12x, m12y, m12z = p1x + (p2x - p1x) * t12, p1y + (p2y - p1y) * t12, p1z + (p2z - p1z) * t12
        local m23x, m23y, m23z = p2x + (p3x - p2x) * t23, p2y + (p3y - p2y) * t23, p2z + (p3z - p2z) * t23
        local m13x, m13y, m13z = p1x + (p3x - p1x) * t13, p1y + (p3y - p1y) * t13, p1z + (p3z - p1z) * t13

        return setVecComponents(
            out,
            (m12x + m23x + m13x) / 3,
            (m12y + m23y + m13y) / 3,
            (m12z + m23z + m13z) / 3
        )
    end
end

local function normalizedEntityMirrorAxis(axis)
    axis = math.floor(tonumber(axis) or M.ENTITY_MIRROR_NONE)
    if axis <= M.ENTITY_MIRROR_NONE or axis > M.ENTITY_MIRROR_Z then
        return M.ENTITY_MIRROR_NONE
    end

    return axis
end

local function mirrorLocalPointInto(out, point, axis)
    if not isvector(point) then return end

    axis = normalizedEntityMirrorAxis(axis)
    if axis ~= M.ENTITY_MIRROR_NONE
        and M.EntityMirror
        and M.EntityMirror.ApplyAxisToVector then
        out = M.EntityMirror.ApplyAxisToVector(out, point, axis)
    else
        out = setVec(out, point)
    end

    return out
end

local function renderLocalPoints(points, axis)
    axis = normalizedEntityMirrorAxis(axis)
    if axis == M.ENTITY_MIRROR_NONE then return points end

    local out = reusablePointLocalPositions
    for i = 1, #points do
        out[i] = mirrorLocalPointInto(out[i], points[i], axis)
    end
    for i = #points + 1, #out do
        out[i] = nil
    end

    return out
end

local pointWorldPosition
local anchorWorldPosition

local function drawPointSet(ent, points, color, posOverride, angOverride, stripePhase, triangleColor, anchorConfig, spriteSettings, viewerPos, localMirrorAxis, pointCache)
    if #points < 1 then return end

    local basePos, baseAng
    if isvector(posOverride) and isangle(angOverride) then
        basePos, baseAng = posOverride, angOverride
    elseif M.IsWorldTarget(ent) then
        basePos, baseAng = ZERO_VEC, ZERO_ANG
    elseif IsValid(ent) then
        basePos, baseAng = ent:GetPos(), ent:GetAngles()
    else
        return
    end

    local localPoints = renderLocalPoints(points, localMirrorAxis)
    local worldPoints = reusablePointWorldPositions
    for i = 1, #localPoints do
        local resolved = pointCache
            and M.ResolvePointWorldPositionCached(pointCache, localPoints[i], ent)
            or M.ResolvePointWorldPosition(localPoints[i], ent)
        if isvector(resolved) then
            worldPoints[i] = setVec(worldPoints[i], resolved)
        else
            worldPoints[i] = localToWorldPosInto(worldPoints[i], localPoints[i], basePos, baseAng)
        end
    end
    for i = #localPoints + 1, #worldPoints do
        worldPoints[i] = nil
    end

    if shouldDrawPointTriangle(spriteSettings) and worldPoints[1] and worldPoints[2] and worldPoints[3] then
        drawStripedTriangle(worldPoints[1], worldPoints[2], worldPoints[3], triangleColor or color, stripePhase, viewerPos)
    end

    local mainRadius = 1.75
    local midRadius = mainRadius * 0.5
    local function anchorWorldPos(id)
        return anchorWorldPosition(localPoints, id, anchorConfig, ent, basePos, baseAng, pointCache, worldPoints)
    end

    local mid12World = anchorWorldPos("mid12")
    local mid23World = anchorWorldPos("mid23")
    local mid13World = anchorWorldPos("mid13")

    if worldPoints[2] and worldPoints[3] then
        drawLine(worldPoints[2], worldPoints[3], cappedAlpha(color, 170), true)
    end
    if worldPoints[1] and worldPoints[3] then
        drawLine(worldPoints[1], worldPoints[3], cappedAlpha(color, 170), true)
    end

    if mid12World then
        drawCircleSprite(mid12World, midRadius, cappedAlpha(color, 185), spriteSettings, viewerPos)
    end
    if mid23World then
        drawCircleSprite(mid23World, midRadius, cappedAlpha(color, 185), spriteSettings, viewerPos)
    end
    if mid13World then
        drawCircleSprite(mid13World, midRadius, cappedAlpha(color, 185), spriteSettings, viewerPos)
    end

    local centerWorld = anchorWorldPos(M.ANCHOR_CENTER_ID)
    if centerWorld then
        drawCircleSprite(centerWorld, midRadius * 0.9, cappedAlpha(color, 165), spriteSettings, viewerPos)
    end

    for i = 1, #worldPoints do
        drawCircleSprite(worldPoints[i], mainRadius, color, spriteSettings, viewerPos)
    end

    if worldPoints[1] and worldPoints[2] then
        drawAxisArrow(worldPoints[2], worldPoints[1], color, viewerPos)
    end
end

function pointWorldPosition(point, ent, basePos, baseAng, pointCache)
    if not isvector(point) then return end

    local world = pointCache
        and M.ResolvePointWorldPositionCached(pointCache, point, ent)
        or M.ResolvePointWorldPosition(point, ent)
    if not world and isvector(basePos) and isangle(baseAng) then
        world = LocalToWorldPosPrecise(point, basePos, baseAng)
    end

    return world
end

function anchorWorldPosition(points, id, options, ent, basePos, baseAng, pointCache, worldPoints)
    local p1 = worldPoints and worldPoints[1] or pointWorldPosition(points[1], ent, basePos, baseAng, pointCache)
    local p2 = worldPoints and worldPoints[2] or pointWorldPosition(points[2], ent, basePos, baseAng, pointCache)
    local p3 = worldPoints and worldPoints[3] or pointWorldPosition(points[3], ent, basePos, baseAng, pointCache)

    if id == "p1" then return p1 end
    if id == "p2" then return p2 end
    if id == "p3" then return p3 end
    if id == "mid12" and p1 and p2 then return lerpPointFast(p1, p2, anchorPercent(options, "mid12")) end
    if id == "mid23" and p2 and p3 then return lerpPointFast(p2, p3, anchorPercent(options, "mid23")) end
    if id == "mid13" and p1 and p3 then return lerpPointFast(p1, p3, anchorPercent(options, "mid13")) end

    if id == M.ANCHOR_CENTER_ID and p1 and p2 and p3 then
        local m12 = lerpPointFast(p1, p2, anchorPercent(options, "mid12"))
        local m23 = lerpPointFast(p2, p3, anchorPercent(options, "mid23"))
        local m13 = lerpPointFast(p1, p3, anchorPercent(options, "mid13"))

        return VectorP(
            (m12.x + m23.x + m13.x) / 3,
            (m12.y + m23.y + m13.y) / 3,
            (m12.z + m23.z + m13.z) / 3
        )
    end

    local anchor = anchorPointFast(points, id, options)
    if not anchor then return end
    return LocalToWorldPosPrecise(anchor, basePos, baseAng)
end

local function drawPoints(ent, points, color, anchorId, anchorConfig, labelPrefix, pointCache)
    local basePos, baseAng
    if M.IsWorldTarget(ent) then
        basePos, baseAng = ZERO_VEC, ZERO_ANG
    elseif IsValid(ent) then
        basePos, baseAng = ent:GetPos(), ent:GetAngles()
    else
        basePos, baseAng = ZERO_VEC, ZERO_ANG
    end

    for i = 1, #points do
        local world = pointCache
            and M.ResolvePointWorldPositionCached(pointCache, points[i], ent)
            or M.ResolvePointWorldPosition(points[i], ent)
        if not world and isvector(basePos) and isangle(baseAng) then
            world = LocalToWorldPosPrecise(points[i], basePos, baseAng)
        end
        local screen = world and world:ToScreen() or nil
        if screen and screen.visible then
            draw.SimpleTextOutlined((labelPrefix or "P") .. i, "DermaDefault", screen.x + 8, screen.y - 8, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
        end
    end

    if not anchorId then return end

    local world = anchorWorldPosition(points, anchorId, anchorConfig, ent, basePos, baseAng, pointCache)
    if not world then return end

    local screen = world:ToScreen()
    if screen.visible then
        draw.SimpleTextOutlined("A", "DermaDefault", screen.x, screen.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    end
end

client.MirrorRender = client.MirrorRender or {}
client.MirrorRender.planeGradientAlphaScale = 0.05
client.MirrorRender.planeOutlineScale = 0.35

function client.MirrorRender.referenceExtent(reference, viewerPos)
    local point = reference and reference.point
    local distance = isvector(point) and isvector(viewerPos) and point:Distance(viewerPos) or 256
    return math.Clamp(distance * 0.9, 128, 4096)
end

function client.MirrorRender.queuePlaneMaterialRebuild(cache)
    if not cache or cache.rebuildQueued then return end

    cache.rebuildQueued = true
    hook.Add("PostRender", "magic_align_mirror_plane_rebuild", function()
        local materialCache = client.MirrorRender.planeMaterialCache
        if not materialCache then
            hook.Remove("PostRender", "magic_align_mirror_plane_rebuild")
            return
        end

        materialCache.rebuildQueued = false
        if materialCache.ready then
            hook.Remove("PostRender", "magic_align_mirror_plane_rebuild")
            return
        end

        local size = materialCache.size or 512
        local center = size * 0.5
        local radius = (center - 1) * 0.6
        local steps = 28
        local points = circlePointsForSegments(64)
        local alphaScale = math.Clamp(tonumber(materialCache.gradientAlphaScale or client.MirrorRender.planeGradientAlphaScale) or 0.25, 0, 1)

        render.PushRenderTarget(materialCache.texture)
        render.Clear(0, 0, 0, 0, true, true)
        cam.Start2D()
            draw.NoTexture()
            for i = steps, 1, -1 do
                local t = i / steps
                local alpha = math.floor(255 * alphaScale * (1 - t) * (1 - t) + 0.5)
                drawCircle2DAt(center, center, radius * t, cachedColor(255, 255, 255, alpha), points)
            end
        cam.End2D()
        render.PopRenderTarget()

        materialCache.ready = true
        hook.Remove("PostRender", "magic_align_mirror_plane_rebuild")
    end)
end

function client.MirrorRender.ensurePlaneMaterial()
    local cache = client.MirrorRender.planeMaterialCache
    if not cache then
        local size = 512
        local texture = GetRenderTargetEx(
            "magic_align_mirror_plane_rt",
            size,
            size,
            RT_SIZE_NO_CHANGE,
            MATERIAL_RT_DEPTH_NONE,
            0,
            0,
            IMAGE_FORMAT_RGBA8888
        )
        local material = CreateMaterial("magic_align_mirror_plane_mat", "UnlitGeneric", {
            ["$basetexture"] = texture:GetName(),
            ["$translucent"] = "1",
            ["$additive"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1",
            ["$nocull"] = "1",
            ["$model"] = "1"
        })

        cache = {
            size = size,
            texture = texture,
            material = material,
            gradientAlphaScale = client.MirrorRender.planeGradientAlphaScale,
            ready = false
        }
        client.MirrorRender.planeMaterialCache = cache
    end

    local desiredAlphaScale = math.Clamp(tonumber(client.MirrorRender.planeGradientAlphaScale) or 0.25, 0, 1)
    if cache.gradientAlphaScale ~= desiredAlphaScale then
        cache.gradientAlphaScale = desiredAlphaScale
        cache.ready = false
    end

    cache.material:SetTexture("$basetexture", cache.texture)
    local materialFlags = cache.material:GetInt("$flags") or 0
    local requiredFlags = bit.bor(materialFlags, SHAPE_CONFIG.materialFlags)
    if materialFlags ~= requiredFlags then
        cache.material:SetInt("$flags", requiredFlags)
    end

    if not cache.ready then
        client.MirrorRender.queuePlaneMaterialRebuild(cache)
        return
    end

    return cache.material
end

function client.MirrorRender.drawPlaneSquare(mirrorState, fill, outline)
    local corners = mirrorState and mirrorState.planeCorners
    if not istable(corners) or not isvector(corners[1]) or not isvector(corners[2]) or not isvector(corners[3]) or not isvector(corners[4]) then return end

    local material = client.MirrorRender.ensurePlaneMaterial()
    if material then
        drawTexturedWorldQuad(corners[1], corners[2], corners[3], corners[4], fill, material, true)
    else
        drawFilledQuad(corners[1], corners[2], corners[3], corners[4], cappedAlpha(fill, 50))
    end

    local outlineScale = tonumber(client.MirrorRender.planeOutlineScale) or 1
    if outlineScale ~= 1 then
        local scratch = client.MirrorRender.planeOutlineScratch or {}
        client.MirrorRender.planeOutlineScratch = scratch

        local centerX = (corners[1].x + corners[3].x) * 0.5
        local centerY = (corners[1].y + corners[3].y) * 0.5
        local centerZ = (corners[1].z + corners[3].z) * 0.5
        for i = 1, 4 do
            local corner = corners[i]
            scratch[i] = setVecComponents(
                scratch[i],
                centerX + (corner.x - centerX) * outlineScale,
                centerY + (corner.y - centerY) * outlineScale,
                centerZ + (corner.z - centerZ) * outlineScale
            )
        end

        corners = scratch
    end

    drawLine(corners[1], corners[2], outline, true)
    drawLine(corners[2], corners[3], outline, true)
    drawLine(corners[3], corners[4], outline, true)
    drawLine(corners[4], corners[1], outline, true)
end

function client.MirrorRender.drawAxis(reference, viewerPos, color)
    if not (reference and isvector(reference.point) and isvector(reference.axis)) then return end

    local extent = client.MirrorRender.referenceExtent(reference, viewerPos)
    local scratch = client.MirrorRender.axisScratch or {}
    client.MirrorRender.axisScratch = scratch

    local px, py, pz = reference.point.x, reference.point.y, reference.point.z
    local ax, ay, az = reference.axis.x, reference.axis.y, reference.axis.z
    scratch.outerA = setVecComponents(scratch.outerA, px - ax * extent, py - ay * extent, pz - az * extent)
    scratch.outerB = setVecComponents(scratch.outerB, px + ax * extent, py + ay * extent, pz + az * extent)
    scratch.innerA = setVecComponents(scratch.innerA, px - ax * extent * 0.42, py - ay * extent * 0.42, pz - az * extent * 0.42)
    scratch.innerB = setVecComponents(scratch.innerB, px + ax * extent * 0.42, py + ay * extent * 0.42, pz + az * extent * 0.42)

    drawLine(scratch.outerA, scratch.outerB, colorAlpha(color, 120), true)
    drawLine(scratch.innerA, scratch.innerB, colorAlpha(color, 210), true)
end

function client.MirrorRender.state(state)
    if not (state and M.IsMirrorMode(state)) then return end

    if client.Mirror and client.Mirror.resolve then
        return client.Mirror.resolve(state)
    end

    return M.ResolveMirrorState(state.mirror, M.GetMirrorStateCache(state), {
        activeSpace = state.activeSpace
    })
end

function client.MirrorRender.drawPointLabels(state, color)
    local mirrorState = client.MirrorRender.state(state)
    if not mirrorState then return end

    local worldPoints = mirrorState.worldPoints or {}
    local count = tonumber(mirrorState.pointCount) or 0
    for i = 1, count do
        local world = worldPoints[i]
        local screen = isvector(world) and world:ToScreen() or nil
        if screen and screen.visible then
            draw.SimpleTextOutlined("M" .. i, "DermaDefault", screen.x + 8, screen.y - 8, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
        end
    end
end

function client.MirrorRender.drawReference(state, spriteSettings, viewerPos)
    local mirrorState = client.MirrorRender.state(state)
    if not mirrorState then return end

    local color = colors.mirror or Color(176, 112, 235)
    local worldPoints = mirrorState.worldPoints or {}
    local count = tonumber(mirrorState.pointCount) or 0
    for i = 1, count do
        local world = worldPoints[i]
        if isvector(world) then
            drawCircleSprite(world, 1.75, colorAlpha(color, 190), spriteSettings, viewerPos)
        end
    end

    local reference = mirrorState.reference
    if not reference then return end

    local point = reference.point
    if isvector(point) then
        drawCircleSprite(point, 1.75, colorAlpha(color, 235), spriteSettings, viewerPos)
    end

    if reference.kind == M.MIRROR_AXIS and isvector(reference.point) and isvector(reference.axis) then
        client.MirrorRender.drawAxis(reference, viewerPos, color)
    elseif reference.kind == M.MIRROR_PLANE and mirrorState.planeHalfSize then
        client.MirrorRender.drawPlaneSquare(mirrorState, colorAlpha(color, 145), colorAlpha(color, 155))
    end
end

local function clearReusableEntries(entries, lastUsed)
    if not istable(entries) then return end

    for i = (tonumber(lastUsed) or 0) + 1, #entries do
        entries[i] = nil
    end
end

local function reusableEntry(entries, index)
    local entry = entries[index]
    if not istable(entry) then
        entry = {}
        entries[index] = entry
    end

    return entry
end

local function shouldDrawGizmoHandle(activeHandle, kind, key)
    if not activeHandle then return true end

    return activeHandle.kind == kind and activeHandle.key == key
end

local function reusableHoverGizmoForRender(state)
    if not istable(state) then return end

    local hover = state.hover
    if not istable(hover) or not hover.gizmo then return end

    local press = state.press
    if press and press.kind == "gizmo" then return end

    if state._magicAlignPreviewChangedFrame ~= nil
        and state._magicAlignPreviewChangedFrame == FrameNumber() then
        return
    end

    return hover.gizmo
end

local function drawGizmoOverlay(tool, state, spriteSettings, viewerPos)
    if not (istable(state) and state.preview and state.preview.solve) then return end

    local g = reusableHoverGizmoForRender(state) or client.gizmo(tool, state)
    if not g then return end

    local showRotation = g.disableRotation ~= true
    local axisHandleRadius = g.size * 0.09
    local traceSnapLength = tool and tool.GetClientInfo and tonumber(tool:GetClientInfo("trace_snap_length")) or 0
    local traceMarkerHalfSize = math.Clamp(math.min(g.size * 0.028, traceSnapLength * 0.14), 0.24, 0.95)
    local press = state.press
    local activeHandle = press and press.kind == "gizmo" and press.space == g.space and press.gizmo or nil
    local basisForward, basisRight, basisUp = g.basisForward, g.basisRight, g.basisUp
    if not (isvector(basisForward) and isvector(basisRight) and isvector(basisUp)) then
        basisForward, basisRight, basisUp = M.AngleAxesPrecise(g.basis)
    end
    local xMove = g.handles and g.handles[1] or nil
    local yMove = g.handles and g.handles[2] or nil
    local zMove = g.handles and g.handles[3] or nil
    local xyPlane = g.handles and g.handles[4] or nil
    local xzPlane = g.handles and g.handles[5] or nil
    local yzPlane = g.handles and g.handles[6] or nil
    local xHandle = xMove and xMove.b or M.AddVectorsPrecise(g.origin, M.ScaleVectorPrecise(basisForward, g.size))
    local yHandle = yMove and yMove.b or M.AddVectorsPrecise(g.origin, M.ScaleVectorPrecise(basisRight, g.size))
    local zHandle = zMove and zMove.b or M.AddVectorsPrecise(g.origin, M.ScaleVectorPrecise(basisUp, g.size))

    if shouldDrawGizmoHandle(activeHandle, "move", "x") then
        drawLine(g.origin, M.SubtractVectorsPrecise(xHandle, M.ScaleVectorPrecise(basisForward, axisHandleRadius)), colors.x, true)
        drawCircleSprite(xHandle, axisHandleRadius, colors.x, spriteSettings, viewerPos)
    end
    if shouldDrawGizmoHandle(activeHandle, "move", "y") then
        drawLine(g.origin, M.SubtractVectorsPrecise(yHandle, M.ScaleVectorPrecise(basisRight, axisHandleRadius)), colors.y, true)
        drawCircleSprite(yHandle, axisHandleRadius, colors.y, spriteSettings, viewerPos)
    end
    if shouldDrawGizmoHandle(activeHandle, "move", "z") then
        drawLine(g.origin, M.SubtractVectorsPrecise(zHandle, M.ScaleVectorPrecise(basisUp, axisHandleRadius)), colors.z, true)
        drawCircleSprite(zHandle, axisHandleRadius, colors.z, spriteSettings, viewerPos)
    end

    if shouldDrawGizmoHandle(activeHandle, "plane", "xy") then
        drawPlaneSquare(xyPlane and xyPlane.center or M.AddVectorsPrecise(M.AddVectorsPrecise(g.origin, M.ScaleVectorPrecise(basisForward, g.planeOffset)), M.ScaleVectorPrecise(basisRight, g.planeOffset)), basisForward, basisRight, g.size * 0.11, colors.xy)
    end
    if shouldDrawGizmoHandle(activeHandle, "plane", "xz") then
        drawPlaneSquare(xzPlane and xzPlane.center or M.AddVectorsPrecise(M.AddVectorsPrecise(g.origin, M.ScaleVectorPrecise(basisForward, g.planeOffset)), M.ScaleVectorPrecise(basisUp, g.planeOffset)), basisForward, basisUp, g.size * 0.11, colors.xz, nil, true, true)
    end
    if shouldDrawGizmoHandle(activeHandle, "plane", "yz") then
        drawPlaneSquare(yzPlane and yzPlane.center or M.AddVectorsPrecise(M.AddVectorsPrecise(g.origin, M.ScaleVectorPrecise(basisRight, g.planeOffset)), M.ScaleVectorPrecise(basisUp, g.planeOffset)), basisRight, basisUp, g.size * 0.11, colors.yz)
    end

    if traceSnapLength > 0 then
        local xTraceDir, xTrace = activeTraceMarkerDirection(state, g, "x")
        local yTraceDir, yTrace = activeTraceMarkerDirection(state, g, "y")
        local zTraceDir, zTrace = activeTraceMarkerDirection(state, g, "z")

        if xTraceDir then
            drawTraceSnapAxisMarker(g.origin, xTraceDir, basisRight, basisUp, traceSnapLength, traceMarkerHalfSize, colors.x, xTrace)
        end
        if yTraceDir then
            drawTraceSnapAxisMarker(g.origin, yTraceDir, basisForward, basisUp, traceSnapLength, traceMarkerHalfSize, colors.y, yTrace)
        end
        if zTraceDir then
            drawTraceSnapAxisMarker(g.origin, zTraceDir, basisForward, basisRight, traceSnapLength, traceMarkerHalfSize, colors.z, zTrace)
        end
    end

    drawTranslationSnapOverlay(tool, state, g, spriteSettings, viewerPos)

    local ringRenderSettings = showRotation and spriteSettings or nil
    if showRotation then
        local rotationRings = reusableRotationRings
        local rollRing = rotationRings[1]
        rollRing.axis, rollRing.a, rollRing.b, rollRing.c = basisForward, basisRight, basisUp, colors.x
        local pitchRing = rotationRings[2]
        pitchRing.axis, pitchRing.a, pitchRing.b, pitchRing.c = basisRight, basisForward, basisUp, colors.y
        local yawRing = rotationRings[3]
        yawRing.axis, yawRing.a, yawRing.b, yawRing.c = basisUp, basisForward, basisRight, colors.z
        local rotationSnapEnabled = not (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT))
        local activeRotationKey = rotationSnapEnabled and g.hover and g.hover.kind == "rot" and g.hover.key or nil
        local rotationDivisions = client.rotationSnapDivisions(tool)
        local rotationStep = client.rotationSnapStep(tool) or (360 / math.max(rotationDivisions, 1))

        for i = 1, #rotationRings do
            local item = rotationRings[i]
            if shouldDrawGizmoHandle(activeHandle, "rot", item.key) then
                drawRotationRingBand(g.origin, item.a, item.b, g.ringRadius, g.ringPadding, item.c, nil, ringRenderSettings)

                if press and press.kind == "gizmo"
                    and press.gizmo and press.gizmo.kind == "rot"
                    and press.gizmo.key == item.key
                    and press.startRingAngle and press.currentRingAngle then
                    local sectorStartAngle = math.deg(press.startRingAngle)
                    local sectorCurrentAngle = press.currentRingAngle
                    if rotationSnapEnabled then
                        sectorStartAngle = client.RotationRender.snapDisplayAngle(sectorStartAngle, rotationStep)
                        sectorCurrentAngle = client.RotationRender.snapDisplayAngle(sectorCurrentAngle, rotationStep)
                    end

                    drawRotationDeltaSector(
                        g.origin,
                        item.a,
                        item.b,
                        g.ringRadius,
                        g.ringPadding,
                        sectorStartAngle,
                        sectorCurrentAngle,
                        item.c,
                        ringRenderSettings
                    )
                end

                if activeRotationKey == item.key and rotationDivisions > 0 then
                    local fallbackAngle = press and press.kind == "gizmo"
                        and press.gizmo and press.gizmo.kind == "rot"
                        and press.gizmo.key == item.key
                        and math.deg(press.startRingAngle)
                        or 0
                    local cursorAngle = press and press.kind == "gizmo"
                        and press.gizmo and press.gizmo.kind == "rot"
                        and press.gizmo.key == item.key
                        and press.currentRingAngle
                        or g.hover and g.hover.kind == "rot"
                        and g.hover.key == item.key
                        and g.hover.cursorAngle
                        or fallbackAngle
                    cursorAngle = client.RotationRender.normalizeDegrees(cursorAngle)
                    local ticks = client.RotationRender.visibleTicks(
                        rotationDivisions,
                        rotationStep,
                        cursorAngle,
                        rotationRingTickLimit(ringRenderSettings, rotationDivisions)
                    )
                    drawRotationRingTicks(g.origin, item.a, item.b, g.ringRadius - g.ringPadding * 0.5, g.size, ticks, colorAlpha(color_white, 220))
                end
            end

        end

    end

    if g.hover and shouldDrawGizmoHandle(activeHandle, g.hover.kind, g.hover.key) then
        if g.hover.kind == "move" then
            local axisDir = g.hover.key == "x" and basisForward
                or g.hover.key == "y" and basisRight
                or basisUp
            drawLine(g.hover.a, g.hover.b - axisDir * axisHandleRadius, color_white, true)
            drawRingSprite(g.hover.b, g.size * 0.09, g.size * 0.022, color_white, ringRenderSettings, viewerPos, true)
        elseif g.hover.kind == "plane" then
            if g.hover.key == "xy" then
                drawPlaneSquare(g.hover.center, basisForward, basisRight, g.size * 0.135, g.hover.color or colors.xy, color_white)
            elseif g.hover.key == "xz" then
                drawPlaneSquare(g.hover.center, basisForward, basisUp, g.size * 0.135, g.hover.color or colors.xz, color_white, true, true)
            else
                drawPlaneSquare(g.hover.center, basisRight, basisUp, g.size * 0.135, g.hover.color or colors.yz, color_white)
            end
        elseif g.hover.key == "roll" then
            drawRotationRingBand(g.origin, basisRight, basisUp, g.ringRadius, g.ringPadding, color_white, nil, ringRenderSettings)
        elseif g.hover.key == "pitch" then
            drawRotationRingBand(g.origin, basisForward, basisUp, g.ringRadius, g.ringPadding, color_white, nil, ringRenderSettings)
        else
            drawRotationRingBand(g.origin, basisForward, basisRight, g.ringRadius, g.ringPadding, color_white, nil, ringRenderSettings)
        end
    end
end

local function drawOverlayWireMarkers(state)
    local markerColor = selectionColor(state)
    local wireMarkers = shapeMetricCache.renderPerf.reusableWireMarkers or {}
    shapeMetricCache.renderPerf.reusableWireMarkers = wireMarkers

    local wireMarkerCount = 0
    wireMarkerCount = wireMarkerCount + 1
    local sourceMarker = reusableEntry(wireMarkers, wireMarkerCount)
    sourceMarker.ent = state.prop1
    sourceMarker.color = markerColor
    sourceMarker.alpha = 72

    wireMarkerCount = wireMarkerCount + 1
    local targetMarker = reusableEntry(wireMarkers, wireMarkerCount)
    targetMarker.ent = state.prop2
    targetMarker.color = colors.target
    targetMarker.alpha = 72

    local targetReferenceMarkers = {}
    for i = 1, #(state.target or {}) do
        local ref = M.ResolvePointReference(state.target[i], state.prop2)
        if IsValid(ref)
            and ref ~= state.prop1
            and ref ~= state.prop2
            and not targetReferenceMarkers[ref] then
            targetReferenceMarkers[ref] = true
            wireMarkerCount = wireMarkerCount + 1
            local refMarker = reusableEntry(wireMarkers, wireMarkerCount)
            refMarker.ent = ref
            refMarker.color = colors.target
            refMarker.alpha = 44
        end
    end

    for i = 1, #(state.linked or {}) do
        wireMarkerCount = wireMarkerCount + 1
        local linkedMarker = reusableEntry(wireMarkers, wireMarkerCount)
        linkedMarker.ent = state.linked[i]
        linkedMarker.color = markerColor
        linkedMarker.alpha = 34
    end
    clearReusableEntries(wireMarkers, wireMarkerCount)
    shapeMetricCache.renderPerf.drawWireMarkerBatch(wireMarkers, true)
end

local function drawInteractionOverlay(tool, state)
    if not istable(state) then return end

    drawOverlayWireMarkers(state)

    local hoverCandidate = state.hover and (state.hover.candidate or state.hover.overlay)
    local mirrorActive = M.IsMirrorMode(state)
    local sourceAnchorOptions = anchorOptions(tool, "from")
    local targetAnchorOptions = not mirrorActive and anchorOptions(tool, "to") or nil
    local spriteSettings = ringRenderSettingsForTool(tool)
    local viewerPos = setVec(shapeMetricCache.renderPerf.viewerPos, IsValid(LocalPlayer()) and LocalPlayer():GetShootPos() or EyePos())
    shapeMetricCache.renderPerf.viewerPos = viewerPos
    local pointCache = state._magicAlignPointWorldCache or {}
    state._magicAlignPointWorldCache = pointCache

    cam.IgnoreZ(true)
    drawPointSet(state.prop1, state.source, colors.source, nil, nil, 0, nil, sourceAnchorOptions, spriteSettings, viewerPos, nil, pointCache)
    if not mirrorActive then
        drawPointSet(state.prop2, state.target, colors.target, nil, nil, 0.5, nil, targetAnchorOptions, spriteSettings, viewerPos, nil, pointCache)
    end
    client.MirrorRender.drawReference(state, spriteSettings, viewerPos)

    if state.preview and state.preview.pos and state.preview.ang and #state.source > 0 then
        local previewPointAxis = state.preview.entityMirrorPreviewAxis
            or state.preview.entityMirrorAxis
            or M.ENTITY_MIRROR_NONE
        drawPointSet(
            nil,
            state.source,
            cachedColor(120, 255, 150, 5),
            state.preview.pos,
            state.preview.ang,
            0,
            cachedColor(120, 255, 150, 128),
            sourceAnchorOptions,
            spriteSettings,
            viewerPos,
            previewPointAxis,
            pointCache
        )
    end

    if state.press and client.HoverRender.isDrawingPickPress(state) and state.press.samples then
        local samples = state.press.samples
        local pathColor = client.HoverRender.activePickAccentColor(state)
        for i = 2, #samples do
            local a = client.sampleWorldPos(state.press.ent, samples[i - 1]) or samples[i - 1].pos
            local b = client.sampleWorldPos(state.press.ent, samples[i]) or samples[i].pos
            if isvector(a) and isvector(b) then
                drawLine(a, b, pathColor, true)
            end
        end

        if tool:GetClientNumber("show_trace_probes") == 1
            and IsValid(state.press.ent)
            and istable(state.press.aggregatedProbes) then
            for i = 1, #state.press.aggregatedProbes do
                local probe = state.press.aggregatedProbes[i]
                if isvector(probe.localPos) then
                    local worldPos = geometry.worldPosFromLocalPoint(state.press.ent, probe.localPos)
                    if isvector(worldPos) then
                        drawCircleSprite(worldPos, 0.22, colorAlpha(pathColor, 190), spriteSettings, viewerPos)
                    end
                end
            end
        end
    end

    if hoverCandidate and not client.HoverRender.isDrawingPickPress(state) then
        local hoverColor = client.HoverRender.cursorAccentColor(state, hoverCandidate, 210)
            or colorAlpha(colors.preview, 210)
        drawCircleSprite(hoverCandidate.worldPos, 1.2, hoverColor, spriteSettings, viewerPos)
    end

    if state.hover and state.hover.point then
        drawRingSprite(state.hover.point.worldPos, 1.7, 0.55, color_white, spriteSettings, viewerPos, true)
    end

    if state.corner and client.HoverRender.isDrawingPickPress(state) then
        local cornerColor = client.HoverRender.activePickAccentColor(state)
        drawCircleSprite(state.corner.worldPos, 1.05, colorAlpha(cornerColor, 215), spriteSettings, viewerPos)
        if isvector(state.corner.axisWorldDir) then
            local axisHalfLength = math.Clamp(IsValid(state.corner.ent) and state.corner.ent:BoundingRadius() * 0.18 or 12, 8, 28)
            drawLine(
                state.corner.worldPos - state.corner.axisWorldDir * axisHalfLength,
                state.corner.worldPos + state.corner.axisWorldDir * axisHalfLength,
                colorAlpha(cornerColor, 230),
                true
            )
        end
        drawLine(state.corner.worldPos, state.corner.worldPos + state.corner.normal * 10, cornerColor, true)
    end

    if state.pending then
        local pendingSolve = state.pending.solve
        local pendingAnchor = pendingSolve
            and (isvector(pendingSolve.sourceAnchorWorld)
                and pendingSolve.sourceAnchorWorld
                or LocalToWorldPosPrecise(pendingSolve.sourceAnchorLocal, state.pending.pos, state.pending.ang))
        if pendingAnchor then
            drawFrame(pendingAnchor, state.pending.ang, 10, 120)
        end
    end

    if state.preview and state.preview.solve then
        local solve = state.preview.solve
        local sourceAnchorWorld = isvector(solve.sourceAnchorWorld) and solve.sourceAnchorWorld or nil
        local sourceContextWorld = isvector(solve.sourceContextWorld) and solve.sourceContextWorld or nil
        local baseAnchor = sourceAnchorWorld or LocalToWorldPosPrecise(solve.sourceAnchorLocal, solve.pos, solve.ang)
        local liveAnchor = sourceAnchorWorld or LocalToWorldPosPrecise(solve.sourceAnchorLocal, state.preview.pos, state.preview.ang)
        local liveContext = sourceContextWorld or LocalToWorldPosPrecise(solve.sourceContextLocal and solve.sourceContextLocal.pos or solve.sourceAnchorLocal, state.preview.pos, state.preview.ang)

        drawFrame(baseAnchor, solve.ang, 12, 80)
        drawFrame(liveAnchor, state.preview.ang, 16, 220)
        drawFrame(liveContext, solve.axisAng, 8, 110)
    end

    drawGizmoOverlay(tool, state, spriteSettings, viewerPos)

    cam.IgnoreZ(false)
end

local depthTestedGridOptions = { depthTested = true }

local function drawInteractionSurfaceOverlay(tool, state)
    if not istable(state) then return end

    local hoverCandidate = state.hover and (state.hover.candidate or state.hover.overlay)

    cam.IgnoreZ(false)
    client.HoverRender.drawFaceOutline(state, hoverCandidate)
    client.HoverRender.drawWorldBspBlockers(tool, state)
    cam.IgnoreZ(false)
end

local function drawInteractionLateSurfaceGrid(tool, state)
    if not istable(state) then return end

    local hoverCandidate = state.hover and (state.hover.candidate or state.hover.overlay)

    cam.IgnoreZ(false)
    client.HoverRender.drawGrid(state, hoverCandidate, depthTestedGridOptions)
    cam.IgnoreZ(false)
end

function TOOL:DrawHUD()
    local tool, state = client.activeTool()
    if tool ~= self then return end
    if not client.validateState(self, state) then return end

    local hoverCandidate = state.hover and (state.hover.candidate or state.hover.overlay)
    local mirrorActive = M.IsMirrorMode(state)
    local sourceAnchorOptions = anchorOptions(tool, "from")
    local targetAnchorOptions = not mirrorActive and anchorOptions(tool, "to") or nil
    local pointCache = state._magicAlignPointWorldCache or {}
    state._magicAlignPointWorldCache = pointCache

    drawPoints(state.prop1, state.source, colors.source, state.preview and state.preview.solve and state.preview.solve.sourceAnchorId, sourceAnchorOptions, nil, pointCache)
    if not mirrorActive then
        drawPoints(state.prop2, state.target, colors.target, state.preview and state.preview.solve and state.preview.solve.targetAnchorId, targetAnchorOptions, nil, pointCache)
    end
    client.MirrorRender.drawPointLabels(state, colors.mirror)
    client.HoverRender.drawGridLabels(state, hoverCandidate)
end

hook.Remove("PreDrawViewModel", "magic_align_draw_before_viewmodel")
hook.Remove("PreDrawTranslucentRenderables", "magic_align_draw")
hook.Remove("PostDrawTranslucentRenderables", "magic_align_draw")
hook.Remove("PostDrawTranslucentRenderables", "magic_align_draw_gizmo")
hook.Remove("PostDrawTranslucentRenderables", "magic_align_draw_overlay")

local lastOpaqueGhostFrame
local function shouldDrawOpaqueGhostPass()
    if render.GetRenderTarget() ~= nil then
        return false
    end

    local frame = FrameNumber()
    if frame ~= nil then
        if lastOpaqueGhostFrame == frame then
            return false
        end

        lastOpaqueGhostFrame = frame
    end

    return true
end

hook.Add("PostDrawOpaqueRenderables", "magic_align_draw", function(bDrawingDepth, bDrawingSkybox)
    if bDrawingDepth or bDrawingSkybox then return end

    local tool, state = client.activeTool()
    if not tool then
        if shouldDrawOpaqueGhostPass() then
            if M.ClientState and IsValid(M.ClientState.ghost) then
                M.ClientState.ghost:SetNoDraw(true)
            end
            if M.ClientState and istable(M.ClientState.linkedGhosts) then
                for _, ghost in pairs(M.ClientState.linkedGhosts) do
                    if IsValid(ghost) then
                        ghost:SetNoDraw(true)
                    end
                end
            end
        end
        return
    end
    if not client.validateState(tool, state) then return end

    drawInteractionSurfaceOverlay(tool, state)

    if not shouldDrawOpaqueGhostPass() then return end

    local ghostEntries = shapeMetricCache.renderPerf.reusableGhostEntries or {}
    shapeMetricCache.renderPerf.reusableGhostEntries = ghostEntries
    ghostEntries._magicAlignCount = 0
    shapeMetricCache.renderPerf.addGhostRenderEntry(ghostEntries, state.ghost, 0.08, 0.65)
    if istable(state.linkedGhosts) then
        for _, ghost in pairs(state.linkedGhosts) do
            shapeMetricCache.renderPerf.addGhostRenderEntry(ghostEntries, ghost, 0.05, 0.38)
        end
    end
    clearReusableEntries(ghostEntries, ghostEntries._magicAlignCount)

    if previewOccludedEnabled(tool) then
        local stripeColorOverride = state.preview
            and state.preview.transformMode == M.TRANSFORM_MODE_MIRROR
            and (colors.mirror or Color(176, 112, 235))
            or nil
        for i = 1, #ghostEntries do
            local entry = ghostEntries[i]
            drawPreviewOccludedGhost(tool, entry.ghost, entry.alpha, stripeColorOverride)
        end
        drawPreviewOccludedCompatGhosts(tool, state, stripeColorOverride)
    end

    shapeMetricCache.renderPerf.drawGhostRenderEntries(ghostEntries)
end)

local lastTranslucentOverlayFrame
local function shouldDrawTranslucentOverlayPass()
    if render.GetRenderTarget() ~= nil then
        return false
    end

    local frame = FrameNumber()
    if frame ~= nil then
        if lastTranslucentOverlayFrame == frame then
            return false
        end

        lastTranslucentOverlayFrame = frame
    end

    return true
end

-- Preview ghosts are translucent clientsidemodels, so draw controls after that pass.
hook.Add("PostDrawTranslucentRenderables", "magic_align_draw_overlay", function(bDrawingDepth, bDrawingSkybox)
    if bDrawingDepth or bDrawingSkybox then return end
    if not shouldDrawTranslucentOverlayPass() then return end

    local tool, state = client.activeTool()
    if not tool then return end
    if not client.validateState(tool, state) then return end

    drawInteractionLateSurfaceGrid(tool, state)
    drawInteractionOverlay(tool, state)
end)
