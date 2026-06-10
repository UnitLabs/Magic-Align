MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local VectorP = M.VectorP
local isvector = M.IsVectorLike
local toVector = M.ToVector
local client = M.Client or {}
local FormulaManager = M.FormulaManager or include("magic_align/client/formula_manager.lua")
local colors = client.colors or {}
local activeTool = client.activeTool
local isWorldTarget = M.IsWorldTarget
local spaceLabels = client.spaceLabels or {}

local MICRO_UNIT = "\194\181"
local DEGREE_UNIT = "\194\176"
local VALUE_FONT_PREFIX = "MagicAlignToolgunValue"
local VALUE_FONT_SIZES = { 64, 58, 52, 46, 40, 34, 30, 26, 22, 18, 16 }
local VALUE_FONT_CACHE_VERSION = VALUE_FONT_PREFIX .. ":" .. table.concat(VALUE_FONT_SIZES, ",")
local COMPASS_RADIUS = 21
local COMPASS_RING_RT_SIZE = 48
local COMPASS_RING_RT_HALF = COMPASS_RING_RT_SIZE * 0.5
local COMPASS_RING_RT_NAME = "magic_align_toolgun_compass_ring_48_v1"
local COMPASS_RING_MATERIAL_NAME = "magic_align_toolgun_compass_ring_48_mat_v1"
local COMPASS_RING_REBUILD_HOOK = "MagicAlignToolgunCompassRingRebuild"
local WORLDGRID_CACHE_LABEL = "LOADING GRID"
local WORLDGRID_CACHE_PHASE_COUNT = 5
local WORLDGRID_CACHE_OVERALL_TRACK = Color(34, 40, 50)
local WORLDGRID_CACHE_OVERALL_FILL = Color(76, 96, 124)
local TAU = math.pi * 2
local fontsReady = false
local compassNeedles = {}
local compassRingRenderTarget
local compassRingMaterial
local compassRingReady = false
local compassRingRebuildQueued = false
local compassRingUnavailable = false

local COMPASS_NEEDLE = {
    stiffness = 76,
    damping = 7.5,
    maxFrameTime = 0.05,
    snapAngle = math.rad(0.08),
    snapVelocity = math.rad(0.8)
}

local palette = {
    bg = Color(5, 6, 8),
    shell = Color(12, 14, 18),
    card = Color(23, 26, 32),
    cardSoft = Color(16, 18, 23),
    border = Color(72, 78, 90),
    text = Color(238, 242, 248),
    textMuted = Color(158, 168, 184),
    accentTextDark = Color(10, 12, 16),
    idle = colors.preview or Color(80, 240, 255),
    shadow = Color(0, 0, 0, 78)
}

local function solid(color, fallback)
    color = color or fallback
    return Color(color.r, color.g, color.b, 255)
end

local handleAccent = {
    x = solid(colors.x, Color(255, 100, 100)),
    y = solid(colors.y, Color(120, 255, 120)),
    z = solid(colors.z, Color(120, 160, 255)),
    xy = solid(colors.xy, Color(255, 210, 80)),
    xz = solid(colors.xz, Color(255, 130, 210)),
    yz = solid(colors.yz, Color(110, 240, 255)),
    pitch = solid(colors.y, Color(120, 255, 120)),
    yaw = solid(colors.z, Color(120, 160, 255)),
    roll = solid(colors.x, Color(255, 100, 100))
}

local handleNames = {
    x = "X",
    y = "Y",
    z = "Z",
    xy = "XY",
    xz = "XZ",
    yz = "YZ",
    pitch = "Pitch",
    yaw = "Yaw",
    roll = "Roll"
}

local panelAccent = {
    prop1 = solid(colors.source, Color(255, 190, 80)),
    prop2 = solid(colors.target, Color(80, 220, 255))
}
local footerTabAccent = {
    prop1 = panelAccent.prop1,
    prop2 = panelAccent.prop2,
    points = solid(colors.axis, Color(92, 220, 148)),
    world = Color(210, 216, 226),
    mirror = solid(colors.mirror, Color(176, 112, 235))
}
local pointCountColor = Color(92, 220, 148)
local missingPropColor = Color(166, 174, 188)

local TOOLGUN_LED_SUBMATERIAL = 3
local TOOLGUN_LED_MATERIAL_PATH = "magic_align/toolgun/toolgun2_leds"
local TOOLGUN_GLOW_SUBMATERIAL = 2
local TOOLGUN_GLOW_MATERIAL_PATH = "magic_align/toolgun/toolgun3_glow"
local TOOLGUN_SELFILLUM_BOOST = 1.45
local TOOLGUN_SELFILLUM_SATURATION_THRESHOLD = 0.12
local TOOLGUN_LED_IDLE_BRIGHTNESS = 0.38
local TOOLGUN_LED_ACTION_BRIGHTNESS = 1
local TOOLGUN_GLOW_BRIGHTNESS = 1
local toolgunLedMaterial
local toolgunGlowMaterial
local toolgunLedState = {}
local toolgunGlowState = {}

local sliderColors = {
    px = handleAccent.x,
    py = handleAccent.y,
    pz = handleAccent.z,
    pitch = handleAccent.pitch,
    yaw = handleAccent.yaw,
    roll = handleAccent.roll
}

local sliderLabels = {
    px = "Pos X",
    py = "Pos Y",
    pz = "Pos Z",
    pitch = "Pitch",
    yaw = "Yaw",
    roll = "Roll"
}

local translationFallback = {
    x = { "px" },
    y = { "py" },
    z = { "pz" },
    xy = { "px", "py" },
    xz = { "px", "pz" },
    yz = { "py", "pz" }
}
local translationKeys = { "px", "py", "pz" }

local gizmoFormulaKeys = {
    move = {
        x = { "px" },
        y = { "py" },
        z = { "pz" }
    },
    plane = {
        xy = { "px", "py" },
        xz = { "px", "pz" },
        yz = { "py", "pz" }
    },
    rot = {
        roll = { "roll" },
        pitch = { "pitch" },
        yaw = { "yaw" }
    }
}

local cachedColors = {}
local staticTextSizeCache = {}
local compassRingSegments = {}
local compassPoly = {
    { x = 0, y = 0 },
    { x = 0, y = 0 },
    { x = 0, y = 0 }
}
local valueFontTexts = {}
local toolScreenCache = {
    data = {},
    items = {},
    lockedKeys = {},
    keyScratch = {},
    valueFont = { texts = {} },
    anchorResolveOptions = {},
    mirrorCompassContext = {}
}

for step = 0, 35 do
    local a0 = math.rad(step * 10)
    local a1 = math.rad((step + 1) * 10)
    local index = #compassRingSegments + 1

    compassRingSegments[index] = math.cos(a0) * COMPASS_RADIUS
    compassRingSegments[index + 1] = math.sin(a0) * COMPASS_RADIUS
    compassRingSegments[index + 2] = math.cos(a1) * COMPASS_RADIUS
    compassRingSegments[index + 3] = math.sin(a1) * COMPASS_RADIUS
end

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
    return cachedColor(color.r, color.g, color.b, alpha)
end

local function cachedStaticTextSize(font, text)
    text = tostring(text or "")

    local byFont = staticTextSizeCache[font]
    if not byFont then
        byFont = {}
        staticTextSizeCache[font] = byFont
    end

    local cached = byFont[text]
    if cached then
        return cached.width, cached.height
    end

    surface.SetFont(font)
    local width, height = surface.GetTextSize(text)
    cached = { width = width, height = height }
    byFont[text] = cached

    return width, height
end

local function colorVector(color, brightness)
    color = color or palette.idle
    brightness = math.Clamp(tonumber(brightness) or 1, 0, 1)

    local r = math.Clamp((tonumber(color.r) or 255) / 255, 0, 1)
    local g = math.Clamp((tonumber(color.g) or 255) / 255, 0, 1)
    local b = math.Clamp((tonumber(color.b) or 255) / 255, 0, 1)
    local minChannel = math.min(r, g, b)
    local maxChannel = math.max(r, g, b)
    local saturation = maxChannel > 0 and (maxChannel - minChannel) / maxChannel or 0

    if saturation >= TOOLGUN_SELFILLUM_SATURATION_THRESHOLD then
        local range = maxChannel - minChannel
        r = (r - minChannel) / range
        g = (g - minChannel) / range
        b = (b - minChannel) / range
    end

    return Vector(
        r * TOOLGUN_SELFILLUM_BOOST * brightness,
        g * TOOLGUN_SELFILLUM_BOOST * brightness,
        b * TOOLGUN_SELFILLUM_BOOST * brightness
    )
end

local function ensureToolgunLedMaterial()
    if toolgunLedMaterial then return toolgunLedMaterial end

    toolgunLedMaterial = Material(TOOLGUN_LED_MATERIAL_PATH)
    return toolgunLedMaterial
end

local function ensureToolgunGlowMaterial()
    if toolgunGlowMaterial then return toolgunGlowMaterial end

    toolgunGlowMaterial = Material(TOOLGUN_GLOW_MATERIAL_PATH)
    return toolgunGlowMaterial
end

local function toolgunLedSpace(tool)
    if tool and tool.Mode == M.TOOL_MODE_MAGIC_MIRROR then
        return M.MIRROR_SPACE
    end

    local space = tool and tool.GetClientInfo and tool:GetClientInfo("space") or nil
    if not space or space == "" then
        space = M.ClientState and M.ClientState.activeSpace or "prop1"
    end

    return space
end

local function toolgunGlowAccent(space)
    local mirror = M.IsMirrorMode(space) or space == M.MIRROR_SPACE
    return mirror and footerTabAccent.mirror or panelAccent.prop2 or palette.idle
end

local function activeToolgunFeedback(weapon)
    local effects = M.ToolgunEffects
    if not effects or not isfunction(effects.ActiveFeedback) then return end

    return effects.ActiveFeedback(weapon)
end

local function activeToolgunHoldColor()
    local state = M.ClientState
    local press = state and state.press
    if not press then return end
    if press._magicAlignToolgunLedHoldColor then
        return press._magicAlignToolgunLedHoldColor
    end

    local color
    if press.side == "source" then color = footerTabAccent.prop1 end
    if press.side == "target" then color = footerTabAccent.prop2 end
    if press.side == "mirror" then color = footerTabAccent.mirror end
    if not color and press.space then
        color = footerTabAccent[press.space] or toolgunGlowAccent(press.space)
    end

    if color then
        press._magicAlignToolgunLedHoldColor = Color(color.r or 255, color.g or 255, color.b or 255, 255)
        return press._magicAlignToolgunLedHoldColor
    end

    local hover = state.hover
    local candidate = press.currentCandidate
        or press.clickCandidate
        or hover and (hover.candidate or hover.overlay)
    local hoverRender = client.HoverRender
    if hoverRender and isfunction(hoverRender.cursorLineColor) then
        color = hoverRender.cursorLineColor(state, candidate, 255)
        if color then
            press._magicAlignToolgunLedHoldColor = Color(color.r or 255, color.g or 255, color.b or 255, 255)
            return press._magicAlignToolgunLedHoldColor
        end
    end
end

local function toolgunLedVisual(space, weapon)
    local ledAccent = footerTabAccent[space] or palette.idle
    local brightness = TOOLGUN_LED_IDLE_BRIGHTNESS

    local holdColor = activeToolgunHoldColor()
    if holdColor then
        ledAccent = holdColor
        brightness = TOOLGUN_LED_ACTION_BRIGHTNESS
    else
        local feedback = activeToolgunFeedback(weapon)
        if feedback and feedback.color then
            ledAccent = feedback.color
            brightness = TOOLGUN_LED_ACTION_BRIGHTNESS
        end
    end

    return ledAccent, brightness
end

local function clearToolgunMaterialOverride(state, subMaterial, materialPath)
    if IsValid(state.viewModel) then
        local original = state.originalSubMaterial
        state.viewModel:SetSubMaterial(subMaterial, original ~= "" and original or nil)
    end

    local ply = LocalPlayer()
    local currentViewModel = IsValid(ply) and ply:GetViewModel() or nil
    if IsValid(currentViewModel) and currentViewModel ~= state.viewModel then
        local current = currentViewModel.GetSubMaterial and currentViewModel:GetSubMaterial(subMaterial) or nil
        if current == materialPath then
            currentViewModel:SetSubMaterial(subMaterial, nil)
        end
    end

    state.viewModel = nil
    state.signature = nil
    state.originalSubMaterial = nil
end

local function clearToolgunLedOverride()
    clearToolgunMaterialOverride(toolgunLedState, TOOLGUN_LED_SUBMATERIAL, TOOLGUN_LED_MATERIAL_PATH)
    clearToolgunMaterialOverride(toolgunGlowState, TOOLGUN_GLOW_SUBMATERIAL, TOOLGUN_GLOW_MATERIAL_PATH)
end

local function applyToolgunMaterialAccent(viewModel, state, subMaterial, materialPath, material, accent, brightness, signaturePrefix)
    if state.viewModel ~= viewModel and IsValid(state.viewModel) then
        clearToolgunMaterialOverride(state, subMaterial, materialPath)
    end

    if state.viewModel ~= viewModel then
        local original = viewModel.GetSubMaterial and viewModel:GetSubMaterial(subMaterial) or nil
        state.originalSubMaterial = original ~= materialPath and original or nil
    end

    local brightnessKey = math.floor((tonumber(brightness) or 1) * 1000 + 0.5)
    local signature = ("%s:%d:%d:%d:%d"):format(signaturePrefix or tostring(subMaterial), accent.r or 255, accent.g or 255, accent.b or 255, brightnessKey)
    if state.viewModel == viewModel and state.signature == signature then
        return
    end

    material:SetVector("$selfillumtint", colorVector(accent, brightness))
    viewModel:SetSubMaterial(subMaterial, materialPath)

    state.viewModel = viewModel
    state.signature = signature
end

local function applyToolgunLedAccent(tool, weapon)
    local ply = LocalPlayer()
    if not IsValid(ply) then return clearToolgunLedOverride() end

    local viewModel = ply:GetViewModel()
    if not IsValid(viewModel) then return clearToolgunLedOverride() end

    local space = toolgunLedSpace(tool)
    if not IsValid(weapon) and isfunction(ply.GetActiveWeapon) then
        weapon = ply:GetActiveWeapon()
    end

    local ledAccent, ledBrightness = toolgunLedVisual(space, weapon)
    local glowAccent = toolgunGlowAccent(space)
    local ledMaterial = ensureToolgunLedMaterial()
    local glowMaterial = ensureToolgunGlowMaterial()

    if ledMaterial then
        applyToolgunMaterialAccent(
            viewModel,
            toolgunLedState,
            TOOLGUN_LED_SUBMATERIAL,
            TOOLGUN_LED_MATERIAL_PATH,
            ledMaterial,
            ledAccent,
            ledBrightness,
            "led:" .. tostring(space)
        )
    end

    if glowMaterial then
        applyToolgunMaterialAccent(
            viewModel,
            toolgunGlowState,
            TOOLGUN_GLOW_SUBMATERIAL,
            TOOLGUN_GLOW_MATERIAL_PATH,
            glowMaterial,
            glowAccent,
            TOOLGUN_GLOW_BRIGHTNESS,
            "glow:" .. tostring(space)
        )
    end
end

hook.Remove("Think", "MagicAlignToolgunLedAccent")
hook.Add("Think", "MagicAlignToolgunLedAccent", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        clearToolgunLedOverride()
        return
    end

    local tool, weapon = M.GetActiveMagicAlignFamilyTool(ply)
    if not tool then
        clearToolgunLedOverride()
        return
    end

    applyToolgunLedAccent(tool, weapon)
end)

local function normalizedAngle(angle)
    return (angle + math.pi) % TAU - math.pi
end

local function frameDelta()
    local dt = RealFrameTime()
    dt = tonumber(dt) or (1 / 60)
    return math.Clamp(dt, 0, COMPASS_NEEDLE.maxFrameTime)
end

local function smoothedCompassAngle(key, targetAngle, signature)
    targetAngle = normalizedAngle(targetAngle)

    local needle = compassNeedles[key]
    if not needle then
        needle = {
            angle = targetAngle,
            velocity = 0,
            signature = signature
        }
        compassNeedles[key] = needle
        return targetAngle
    end
    needle.signature = signature

    local dt = frameDelta()
    local delta = normalizedAngle(targetAngle - needle.angle)

    needle.velocity = (needle.velocity + delta * COMPASS_NEEDLE.stiffness * dt) * math.exp(-COMPASS_NEEDLE.damping * dt)
    needle.angle = normalizedAngle(needle.angle + needle.velocity * dt)

    if math.abs(delta) <= COMPASS_NEEDLE.snapAngle and math.abs(needle.velocity) <= COMPASS_NEEDLE.snapVelocity then
        needle.angle = targetAngle
        needle.velocity = 0
    end

    return needle.angle
end

local function compassSignature(ent, targetWorldPos)
    local base = isWorldTarget and isWorldTarget(ent) and "world" or (IsValid(ent) and tostring(ent:EntIndex()) or "none")
    if isvector(targetWorldPos) then
        return ("%s:%.1f:%.1f:%.1f"):format(base, targetWorldPos.x, targetWorldPos.y, targetWorldPos.z)
    end

    return base
end

local function safeVector(value)
    if not isvector(value) then return end
    return toVector(value)
end

local toolgunAnchorOptionCache = {}

local function anchorOptionsFromTool(tool, side)
    local prefix = side == "prop1" and "from" or "to"
    local cache = toolgunAnchorOptionCache[prefix]
    if not cache then
        cache = { optionsCache = {} }
        toolgunAnchorOptionCache[prefix] = cache
    end

    local options, revision = M.NormalizeAnchorOptionsCached(cache.optionsCache, {
        mid12_pct = tool and tool.GetClientInfo and tool:GetClientInfo(prefix .. "_mid12_pct"),
        mid23_pct = tool and tool.GetClientInfo and tool:GetClientInfo(prefix .. "_mid23_pct"),
        mid13_pct = tool and tool.GetClientInfo and tool:GetClientInfo(prefix .. "_mid13_pct")
    })

    return options, revision
end

local function activeAnchorSelection(tool, state, side)
    local prefix = side == "prop1" and "from" or "to"
    local selected = tool and tool.GetClientInfo and string.lower(tool:GetClientInfo(prefix .. "_anchor") or "") or nil
    local priority = tool and tool.GetClientInfo and tool:GetClientInfo(prefix .. "_priority") or nil
    local selection = state and state.anchorSelection and state.anchorSelection[prefix]

    if selection and selection.convarAnchor == selected then
        return selection.anchor, selection.priority
    end

    return selected, priority
end

local function activeAnchorWorldPos(tool, state, ent, points, side)
    if not ((isWorldTarget and isWorldTarget(ent)) or IsValid(ent)) or not istable(points) or #points == 0 then
        return nil
    end
    if not istable(state) then return nil end

    local selected, priority = activeAnchorSelection(tool, state, side)
    state._magicAlignToolgunAnchorCache = state._magicAlignToolgunAnchorCache or {}
    local options, optionRevision = anchorOptionsFromTool(tool, side)
    local cacheOptions = toolScreenCache.anchorResolveOptions
    cacheOptions.revision = optionRevision
    cacheOptions.copy = nil

    local _, localAnchor = M.ResolveAnchorCached(
        state._magicAlignToolgunAnchorCache,
        points,
        selected,
        priority,
        options,
        cacheOptions
    )
    local localPos = safeVector(localAnchor)
    if not localPos then return end

    if isWorldTarget and isWorldTarget(ent) then
        return localPos
    end

    return M.EntityMirror.LocalPointToWorld(ent, localPos)
end

local function commitUploadProgress()
    local upload = M.CommitUpload
    if not istable(upload) or upload.finishedAt then return end

    return math.Clamp(tonumber(upload.progress) or 0, 0, 1)
end

local function luminance(color)
    return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
end

local function accentTextColor(color)
    if luminance(color) >= 170 then
        return palette.accentTextDark
    end

    return cachedColor(252, 252, 252)
end

local function clampDisplayValue(value)
    value = tonumber(value) or 0
    if math.abs(value) < 0.005 then
        return 0
    end

    return value
end

local function formatUnits(value)
    return ("%+.2f %s"):format(clampDisplayValue(value), MICRO_UNIT)
end

local function formatAngle(value)
    return ("%+.2f%s"):format(clampDisplayValue(value), DEGREE_UNIT)
end

local function ensureFonts()
    if fontsReady then return end

    surface.CreateFont("MagicAlignToolgunBrand", {
        font = "Roboto",
        size = 25,
        weight = 900,
        antialias = true,
        extended = true
    })

    surface.CreateFont("MagicAlignToolgunTitle", {
        font = "Roboto",
        size = 21,
        weight = 700,
        antialias = true,
        extended = true
    })

    surface.CreateFont("MagicAlignToolgunTitleSoft", {
        font = "Roboto",
        size = 21,
        weight = 500,
        antialias = true,
        extended = true
    })

    surface.CreateFont("MagicAlignToolgunBody", {
        font = "Roboto",
        size = 18,
        weight = 550,
        antialias = true,
        extended = true
    })

    surface.CreateFont("MagicAlignToolgunChip", {
        font = "Roboto",
        size = 22,
        weight = 600,
        antialias = true,
        extended = true
    })

    surface.CreateFont("MagicAlignToolgunCaption", {
        font = "Roboto",
        size = 18,
        weight = 600,
        antialias = true,
        extended = true
    })

    surface.CreateFont("MagicAlignToolgunStatus", {
        font = "Roboto",
        size = 18,
        weight = 600,
        antialias = true,
        extended = true
    })

    surface.CreateFont("MagicAlignToolgunTab", {
        font = "Roboto",
        size = 14,
        weight = 700,
        antialias = true,
        extended = true
    })

    for _, size in ipairs(VALUE_FONT_SIZES) do
        surface.CreateFont(VALUE_FONT_PREFIX .. size, {
            font = "Roboto",
            size = size,
            weight = size >= 42 and 800 or 700,
            antialias = true,
            extended = true
        })
    end

    fontsReady = true
end

local function widestText(font, texts)
    surface.SetFont(font)

    local widest = 0
    for i = 1, #texts do
        local width = select(1, surface.GetTextSize(texts[i]))
        widest = math.max(widest, width)
    end

    return widest
end

local function pickValueFont(texts, maxWidth, maxHeight)
    ensureFonts()
    maxHeight = maxHeight or VALUE_FONT_SIZES[1]

    for _, size in ipairs(VALUE_FONT_SIZES) do
        local font = VALUE_FONT_PREFIX .. size
        if size <= maxHeight and widestText(font, texts) <= maxWidth then
            return font
        end
    end

    return VALUE_FONT_PREFIX .. VALUE_FONT_SIZES[#VALUE_FONT_SIZES]
end

local function cachedValueFont(texts, maxWidth, maxHeight, cache)
    cache = istable(cache) and cache or toolScreenCache.valueFont
    cache.texts = istable(cache.texts) and cache.texts or {}
    local count = #texts

    if cache.font
        and cache.fontVersion == VALUE_FONT_CACHE_VERSION
        and cache.maxWidth == maxWidth
        and cache.maxHeight == maxHeight
        and cache.count == count then
        local cacheTexts = cache.texts
        local matches = true

        for i = 1, count do
            if cacheTexts[i] ~= texts[i] then
                matches = false
                break
            end
        end

        if matches then
            return cache.font
        end
    end

    local font = pickValueFont(texts, maxWidth, maxHeight)
    local cacheTexts = cache.texts

    cache.font = font
    cache.fontVersion = VALUE_FONT_CACHE_VERSION
    cache.maxWidth = maxWidth
    cache.maxHeight = maxHeight
    cache.count = count
    for i = 1, count do
        cacheTexts[i] = texts[i]
    end
    for i = count + 1, #cacheTexts do
        cacheTexts[i] = nil
    end

    return font
end

local function drawChip(x, y, text, accent)
    local textWidth, textHeight = cachedStaticTextSize("MagicAlignToolgunChip", text)
    local width = textWidth + 20
    local height = textHeight + 10

    draw.RoundedBox(8, x, y, width, height, accent)
    draw.SimpleText(text, "MagicAlignToolgunChip", x + width * 0.5, y + height * 0.5, accentTextColor(accent), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    return width, height
end

local function chipWidth(text)
    local textWidth = select(1, cachedStaticTextSize("MagicAlignToolgunChip", text))
    return textWidth + 20
end

local function footerRect(width, height)
    local footerHeight = 20
    return 20, height - footerHeight - 14, width - 40, footerHeight
end

local function contentRect(width, height)
    local footerX, footerY, footerW = footerRect(width, height)
    return footerX, 80, footerW, math.max(footerY - 92, 40)
end

local function drawBackdrop(width, height, accent)
    accent = accent or palette.idle

    surface.SetDrawColor(palette.bg)
    surface.DrawRect(0, 0, width, height)

    draw.RoundedBox(18, 8, 8, width - 16, height - 16, palette.shell)
    draw.RoundedBox(14, 16, 16, width - 32, height - 32, palette.cardSoft)

    local topBarX = 16
    local topBarY = 16
    local topBarW = width - 32
    local topBarH = 6

    surface.SetDrawColor(colorAlpha(accent, 165))
    surface.DrawRect(topBarX, topBarY, topBarW, topBarH)

    local uploadProgress = commitUploadProgress()
    if uploadProgress then
        local covered = math.floor(topBarW * (1 - uploadProgress))
        if covered > 0 then
            surface.SetDrawColor(colorAlpha(panelAccent.prop1, 178))
            surface.DrawRect(topBarX + topBarW - covered, topBarY, covered, topBarH)
        end
    end

    surface.SetDrawColor(palette.border)
    surface.DrawOutlinedRect(8, 8, width - 16, height - 16, 1)
    surface.DrawOutlinedRect(16, 16, width - 32, height - 32, 1)

end

local function activeWorldGridCacheProgress()
    local worldBSP = client.WorldBSP
    if not worldBSP or not isfunction(worldBSP.cacheProgressSnapshot) then return end

    local progress = worldBSP.cacheProgressSnapshot()
    local buildingStatus = worldBSP.STATUS and worldBSP.STATUS.BUILDING or "building"
    if not progress or progress.status ~= buildingStatus then return end

    return progress
end

local function worldGridCacheAccent(progress)
    local stage = progress and progress.stage
    if stage == "displacements" then return panelAccent.prop2 or palette.idle end
    if stage == "neighbor_index" then return footerTabAccent.points or palette.idle end
    if stage == "neighbor_count" then return footerTabAccent.world or palette.idle end
    if stage == "neighbor_links" then return footerTabAccent.mirror or palette.idle end

    return panelAccent.prop1 or palette.idle
end

local function worldGridCachePhaseIndex(progress)
    local stage = progress and progress.stage
    if stage == "displacements" then return 2 end
    if stage == "neighbor_index" then return 3 end
    if stage == "neighbor_count" then return 4 end
    if stage == "neighbor_links" then return 5 end

    return 1
end

local function stageProgressFraction(progress)
    if not progress then return 0 end

    local fraction = tonumber(progress.stageFraction)
    if not fraction then
        local stagePercent = tonumber(progress.stagePercent)
        if stagePercent then
            fraction = stagePercent * 0.01
        end
    end

    return math.Clamp(fraction or 0, 0, 1)
end

local function overallProgressFraction(progress)
    local phaseIndex = worldGridCachePhaseIndex(progress)
    local phaseFraction = stageProgressFraction(progress)

    return math.Clamp((phaseIndex - 1 + phaseFraction) / WORLDGRID_CACHE_PHASE_COUNT, 0, 1)
end

local function formatEtaClock(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds < 0 or seconds == math.huge or seconds ~= seconds then
        return "--:--"
    end

    seconds = math.max(math.ceil(seconds), 0)
    return ("%02d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function drawWorldGridCacheHeader(width, progress, accent)
    local etaText = formatEtaClock(progress and (progress.eta or progress.stageEta))
    local font = "MagicAlignToolgunBrand"
    accent = accent or worldGridCacheAccent(progress)

    draw.SimpleText(WORLDGRID_CACHE_LABEL, font, 24, 30, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(etaText, font, width - 24, 30, palette.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    local x = 20
    local y = 66
    local w = width - 40
    local h = 12
    local overallX = x + 2
    local overallY = y + 2
    local overallW = math.max(w - 4, 0)
    local overallH = math.max(h - 4, 0)
    local overallFill = math.floor(overallW * overallProgressFraction(progress))
    local phaseX = x + 4
    local phaseY = y + 3
    local phaseW = math.max(w - 8, 0)
    local phaseH = math.max(h - 8, 0)
    local phaseFill = math.floor(phaseW * stageProgressFraction(progress))

    draw.RoundedBox(5, x, y, w, h, palette.card)
    surface.SetDrawColor(colorAlpha(palette.border, 115))
    surface.DrawOutlinedRect(x, y, w, h, 1)

    draw.RoundedBox(4, overallX, overallY, overallW, overallH, colorAlpha(WORLDGRID_CACHE_OVERALL_TRACK, 210))
    if overallFill > 0 then
        draw.RoundedBox(4, overallX, overallY, overallFill, overallH, colorAlpha(WORLDGRID_CACHE_OVERALL_FILL, 210))
    end

    if phaseFill > 0 then
        draw.RoundedBox(3, phaseX, phaseY, phaseFill, phaseH, colorAlpha(accent, 178))
    end
end

local function drawValueCards(width, height, items)
    local margin = 24
    local gap = 8
    local top = 86
    local _, footerY = footerRect(width, height)
    local availableHeight = math.max(footerY - top - 8, 56)
    local cardWidth = width - margin * 2
    local count = math.max(#items, 1)
    local cardHeight = math.floor((availableHeight - gap * (count - 1)) / count)
    for i = 1, #items do
        valueFontTexts[i] = items[i].value
    end
    for i = #items + 1, #valueFontTexts do
        valueFontTexts[i] = nil
    end

    local valueFont = cachedValueFont(valueFontTexts, cardWidth - 30, math.max(cardHeight * 0.52, VALUE_FONT_SIZES[#VALUE_FONT_SIZES]), toolScreenCache.valueFont)

    for index = 1, #items do
        local item = items[index]
        local y = top + (index - 1) * (cardHeight + gap)
        local itemValueFont = item.valueFont or valueFont

        draw.RoundedBox(12, margin, y, cardWidth, cardHeight, palette.card)
        draw.RoundedBox(12, margin, y, 8, cardHeight, item.accent or palette.idle)
        surface.SetDrawColor(colorAlpha(palette.shadow, 10))
        surface.DrawOutlinedRect(margin, y, cardWidth, cardHeight, 1)

        draw.SimpleText(item.label, "MagicAlignToolgunCaption", margin + 18, y + 14, palette.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(item.value, itemValueFont, margin + cardWidth * 0.5, y + cardHeight * 0.62, item.valueColor or palette.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function drawCompassRingLines(cx, cy, radius)
    radius = radius or COMPASS_RADIUS

    surface.SetDrawColor(colorAlpha(palette.border, 160))
    if radius == COMPASS_RADIUS then
        for i = 1, #compassRingSegments, 4 do
            surface.DrawLine(
                cx + compassRingSegments[i],
                cy + compassRingSegments[i + 1],
                cx + compassRingSegments[i + 2],
                cy + compassRingSegments[i + 3]
            )
        end
    else
        for step = 0, 35 do
            local a0 = math.rad(step * 10)
            local a1 = math.rad((step + 1) * 10)
            surface.DrawLine(
                cx + math.cos(a0) * radius,
                cy + math.sin(a0) * radius,
                cx + math.cos(a1) * radius,
                cy + math.sin(a1) * radius
            )
        end
    end

    surface.SetDrawColor(colorAlpha(palette.textMuted, 120))
    surface.DrawLine(cx, cy - radius, cx, cy - radius + 5)
    surface.DrawLine(cx, cy + radius - 5, cx, cy + radius)
    surface.DrawLine(cx - radius, cy, cx - radius + 5, cy)
    surface.DrawLine(cx + radius - 5, cy, cx + radius, cy)
end

local function rebuildCompassRingMaterial()
    compassRingRebuildQueued = false
    if compassRingUnavailable or not compassRingRenderTarget or not compassRingMaterial then return end

    render.PushRenderTarget(compassRingRenderTarget)
    render.OverrideAlphaWriteEnable(true, true)
    render.ClearDepth()
    render.Clear(0, 0, 0, 0)
    cam.Start2D()
        draw.NoTexture()
        drawCompassRingLines(COMPASS_RING_RT_HALF, COMPASS_RING_RT_HALF)
    cam.End2D()
    render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()

    compassRingReady = true
end

local function queueCompassRingRebuild()
    if compassRingReady or compassRingRebuildQueued then return end

    compassRingRebuildQueued = true
    hook.Add("PostRender", COMPASS_RING_REBUILD_HOOK, function()
        hook.Remove("PostRender", COMPASS_RING_REBUILD_HOOK)
        rebuildCompassRingMaterial()
    end)
end

local function ensureCompassRingMaterial()
    if compassRingReady then return compassRingMaterial end
    if compassRingUnavailable then return end

    if not compassRingRenderTarget then
        compassRingRenderTarget = GetRenderTargetEx(
            COMPASS_RING_RT_NAME,
            COMPASS_RING_RT_SIZE,
            COMPASS_RING_RT_SIZE,
            RT_SIZE_NO_CHANGE,
            MATERIAL_RT_DEPTH_NONE,
            0,
            0,
            IMAGE_FORMAT_RGBA8888
        )
        if not compassRingRenderTarget then
            compassRingUnavailable = true
            return
        end
    end

    local textureName = COMPASS_RING_RT_NAME
    if isfunction(compassRingRenderTarget.GetName) then
        textureName = compassRingRenderTarget:GetName()
    end

    if not compassRingMaterial then
        compassRingMaterial = CreateMaterial(COMPASS_RING_MATERIAL_NAME, "UnlitGeneric", {
            ["$basetexture"] = textureName,
            ["$translucent"] = "1",
            ["$vertexalpha"] = "1",
            ["$vertexcolor"] = "1",
            ["$ignorez"] = "1",
            ["$nolod"] = "1"
        })

        if not compassRingMaterial then
            compassRingUnavailable = true
            return
        end
    end

    if isfunction(compassRingMaterial.SetTexture) then
        compassRingMaterial:SetTexture("$basetexture", compassRingRenderTarget)
    end

    queueCompassRingRebuild()
    return compassRingReady and compassRingMaterial or nil
end

local function drawCompassRing(cx, cy, radius)
    if radius ~= COMPASS_RADIUS then
        draw.NoTexture()
        drawCompassRingLines(cx, cy, radius)
        return
    end

    local material = ensureCompassRingMaterial()
    if not material then
        draw.NoTexture()
        drawCompassRingLines(cx, cy, radius)
        return
    end

    surface.SetMaterial(material)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(cx - COMPASS_RING_RT_HALF, cy - COMPASS_RING_RT_HALF, COMPASS_RING_RT_SIZE, COMPASS_RING_RT_SIZE)
    draw.NoTexture()
end

local function drawCompass(cx, cy, radius, angle, accent)
    drawCompassRing(cx, cy, radius)

    local dirX = math.sin(angle)
    local dirY = -math.cos(angle)
    local length = radius - 1
    local halfWidth = math.max(radius * 0.28, 4)
    local tipX = cx + dirX * length
    local tipY = cy + dirY * length
    local tailX = cx - dirX * length
    local tailY = cy - dirY * length
    local rightX = cx - dirY * halfWidth
    local rightY = cy + dirX * halfWidth
    local leftX = cx + dirY * halfWidth
    local leftY = cy - dirX * halfWidth

    surface.SetDrawColor(accent)
    compassPoly[1].x, compassPoly[1].y = tipX, tipY
    compassPoly[2].x, compassPoly[2].y = rightX, rightY
    compassPoly[3].x, compassPoly[3].y = leftX, leftY
    surface.DrawPoly(compassPoly)

    draw.NoTexture()
    surface.SetDrawColor(colorAlpha(accent, 220))
    surface.DrawLine(leftX, leftY, tailX, tailY)
    surface.DrawLine(tailX, tailY, rightX, rightY)
    surface.DrawLine(rightX, rightY, leftX, leftY)

    surface.SetDrawColor(palette.card)
    surface.DrawRect(cx - 1, cy - 1, 2, 2)
end

local function compassAngle(ent, targetWorldPos)
    local player = LocalPlayer()
    if not IsValid(player) then return end

    local target = safeVector(targetWorldPos)
    if not target then
        if not IsValid(ent) then return end
        target = ent:GetPos()
    end

    local yaw = (player:GetPos() - target):Angle().y - player:EyeAngles().y

    if not isnumber(yaw) then
        return 0
    end

    return math.rad(-(yaw + 180))
end

local function currentSpace(tool, state, data)
    local space = data and data.space or tool:GetClientInfo("space")
    if not space or space == "" then
        space = state and state.press and state.press.space or "points"
    end

    return space
end

local function displayLabelForSpace(space, state)
    if space == "prop2" and isWorldTarget and isWorldTarget(state and state.prop2) then
        return spaceLabels.world or "World"
    end

    return spaceLabels[space] or tostring(space)
end

local function drawFooter(width, height, tool, state, data)
    local spaces = M.UI_SPACES or M.SPACES or { "prop1", "prop2", "points", "world", "mirror" }
    if not istable(spaces) or #spaces == 0 then return end

    local activeSpace = currentSpace(tool, state, data)
    local x, y, w, h = footerRect(width, height)
    local gap = 3
    local tabWidth = math.floor((w - gap * (#spaces - 1)) / #spaces)
    local remainder = w - tabWidth * #spaces - gap * (#spaces - 1)
    local tabX = x
    local stripColor = palette.shell
    local borderColor = palette.border

    draw.RoundedBoxEx(6, x, y, w, h, stripColor, true, true, false, false)
    surface.SetDrawColor(colorAlpha(borderColor, 180))
    surface.DrawOutlinedRect(x, y, w, h, 1)

    for i = 1, #spaces do
        local space = spaces[i]
        local tabW = tabWidth + (i == #spaces and remainder or 0)
        local active = space == activeSpace
        local bg = active and palette.card or palette.shell
        local textColor = active and palette.text or palette.textMuted

        draw.RoundedBoxEx(6, tabX, y, tabW, h, bg, true, true, false, false)
        surface.SetDrawColor(colorAlpha(borderColor, active and 170 or 130))
        surface.DrawOutlinedRect(tabX, y, tabW, h - 1, 1)

        if active then
            surface.SetDrawColor(footerTabAccent[space] or palette.text)
            surface.DrawRect(tabX + 1, y + h - 3, math.max(tabW - 2, 0), 3)
        end

        draw.SimpleText(displayLabelForSpace(space, state), "MagicAlignToolgunTab", tabX + tabW * 0.5, y + h * 0.48, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        tabX = tabX + tabW + gap
    end
end

local function pointCountText(count)
    count = math.max(math.floor(tonumber(count) or 0), 0)
    if count <= 0 then
        return "0 Points"
    end
    if count == 1 then
        return "1 Point"
    end
    if count == 2 then
        return "2-Point Axis"
    end

    return "3-Point Plane"
end

local function pointCountDisplayColor(count)
    count = math.max(math.floor(tonumber(count) or 0), 0)
    if count <= 0 then
        return missingPropColor
    end

    return pointCountColor
end

local function linkedCountText(count, maxCount)
    count = math.max(math.floor(tonumber(count) or 0), 0)
    maxCount = math.max(math.floor(tonumber(maxCount) or M.DEFAULT_MAX_LINKED_PROPS or 0), 0)
    return ("[%d/%d]"):format(count, maxCount)
end

local function blendColor(fromColor, toColor, t)
    t = math.Clamp(tonumber(t) or 0, 0, 1)

    return cachedColor(
        math.Round(Lerp(t, fromColor.r, toColor.r)),
        math.Round(Lerp(t, fromColor.g, toColor.g)),
        math.Round(Lerp(t, fromColor.b, toColor.b)),
        math.Round(Lerp(t, fromColor.a or 255, toColor.a or 255))
    )
end

local function linkedCountColor(count, maxCount)
    local ratio = 0
    maxCount = math.max(tonumber(maxCount) or 0, 0)
    if maxCount > 0 then
        ratio = math.Clamp((tonumber(count) or 0) / maxCount, 0, 1)
    end

    local alpha = math.Round(Lerp(ratio, 170, 230))
    local dark = cachedColor(182, 190, 204, alpha)
    local warn = cachedColor(240, 202, 105, alpha)
    local hot = cachedColor(255, 140, 126, alpha)

    if ratio <= 0.5 then
        return blendColor(dark, warn, ratio / 0.5)
    end

    return blendColor(warn, hot, (ratio - 0.5) / 0.5)
end

local function drawLinkedCountInline(x, y, h, label, count, maxCount)
    local text = linkedCountText(count, maxCount)
    local color = linkedCountColor(count, maxCount)

    local labelWidth = select(1, cachedStaticTextSize("MagicAlignToolgunTitleSoft", label))
    local textX = x + 18 + labelWidth + 8
    local lineY = y + h * 0.34

    draw.SimpleText(text, "MagicAlignToolgunTitleSoft", textX, lineY, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function drawCompassPanel(x, y, w, h, needleKey, label, ent, accent, pointCount, tool, state, points, context)
    draw.RoundedBox(12, x, y, w, h, palette.card)
    draw.RoundedBox(12, x, y, 8, h, colorAlpha(accent, 220))
    surface.SetDrawColor(colorAlpha(palette.border, 105))
    surface.DrawOutlinedRect(x, y, w, h, 1)

    local compassX = x + w - 28
    draw.SimpleText(label, "MagicAlignToolgunTitle", x + 18, y + h * 0.34, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if context and context.statusText then
        draw.SimpleText(context.statusText, "MagicAlignToolgunStatus", x + 18, y + h * 0.68, context.statusColor or pointCountDisplayColor(pointCount), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    elseif IsValid(ent) then
        draw.SimpleText(pointCountText(pointCount), "MagicAlignToolgunStatus", x + 18, y + h * 0.68, pointCountDisplayColor(pointCount), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    elseif isWorldTarget and isWorldTarget(ent) then
        draw.SimpleText(pointCountText(pointCount), "MagicAlignToolgunStatus", x + 18, y + h * 0.68, pointCountDisplayColor(pointCount), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText(context and context.missingText or "No Prop Selected", "MagicAlignToolgunCaption", x + 18, y + h * 0.68, missingPropColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local anchorWorldPos = context and context.targetWorldPos or activeAnchorWorldPos(tool, state, ent, points, needleKey)
    local angle = compassAngle(ent, anchorWorldPos)
    if angle then
        drawCompass(compassX, y + h * 0.5, COMPASS_RADIUS, smoothedCompassAngle(needleKey, angle, compassSignature(ent, anchorWorldPos)), accent)
    else
        compassNeedles[needleKey] = nil
    end
end

local function drawIdleCompasses(width, height, tool, state, mirrorContext)
    local x, y, w, h = contentRect(width, height)
    local gap = 10
    local panelHeight = 56
    local totalHeight = panelHeight * 2 + gap
    local startY = y + math.max((h - totalHeight) * 0.5, 0)

    drawCompassPanel(
        x,
        startY,
        w,
        panelHeight,
        "prop1",
        spaceLabels.prop1 or "Prop 1",
        state and state.prop1 or nil,
        panelAccent.prop1 or palette.idle,
        state and istable(state.source) and #state.source or 0,
        tool,
        state,
        state and state.source or nil
    )
    drawLinkedCountInline(
        x,
        startY,
        panelHeight,
        spaceLabels.prop1 or "Prop 1",
        state and istable(state.linked) and #state.linked or 0,
        M.GetMaxLinkedProps()
    )
    if mirrorContext then
        local context = toolScreenCache.mirrorCompassContext
        context.statusText = pointCountText(mirrorContext.pointCount or 0)
        context.statusColor = nil
        context.targetWorldPos = mirrorContext.targetWorldPos
        context.missingText = "No Mirror Points"

        drawCompassPanel(
            x,
            startY + panelHeight + gap,
            w,
            panelHeight,
            "prop2",
            mirrorContext.label or "Mirror",
            nil,
            mirrorContext.accent or footerTabAccent.mirror or palette.idle,
            mirrorContext.pointCount or 0,
            tool,
            state,
            nil,
            context
        )
    else
        drawCompassPanel(
            x,
            startY + panelHeight + gap,
            w,
            panelHeight,
            "prop2",
            displayLabelForSpace("prop2", state),
            state and state.prop2 or nil,
            panelAccent.prop2 or palette.idle,
            state and istable(state.target) and #state.target or 0,
            tool,
            state,
            state and state.target or nil
        )
    end
end

local function formulaSnapshotFor(cvarName)
    if not FormulaManager or not cvarName or cvarName == "" then
        return nil
    end

    FormulaManager:RegisterConVar(cvarName)

    local snapshot = FormulaManager:GetSnapshot(cvarName)
    if snapshot and snapshot.rawMode == "formula" then
        return snapshot
    end

    return nil
end

local function clearReusableMap(map)
    if not istable(map) then return {} end

    for key in pairs(map) do
        map[key] = nil
    end

    return map
end

local function lockedFormulaKeysForPress(press, out, keyScratch)
    if not press or press.kind ~= "gizmo" or not press.gizmo or not press.space then
        return nil
    end

    local byKind = gizmoFormulaKeys[press.gizmo.kind]
    local keys = byKind and byKind[press.gizmo.key]
    if press.gizmo.kind ~= "rot" and isvector(press.referenceDelta) then
        keys = keyScratch or {}
        for i = 1, #keys do
            keys[i] = nil
        end
        if math.abs(press.referenceDelta.x) > 1e-6 then keys[#keys + 1] = "px" end
        if math.abs(press.referenceDelta.y) > 1e-6 then keys[#keys + 1] = "py" end
        if math.abs(press.referenceDelta.z) > 1e-6 then keys[#keys + 1] = "pz" end
        if #keys == 0 then
            keys = byKind and byKind[press.gizmo.key]
        end
    end
    if not istable(keys) then
        return nil
    end

    local locked = clearReusableMap(out)
    for index = 1, #keys do
        local key = keys[index]
        local cvarName = ("magic_align_%s_%s"):format(press.space, key)
        if formulaSnapshotFor(cvarName) then
            locked[key] = true
        end
    end

    return next(locked) and locked or nil
end

local function clearReusableArray(items, count)
    for i = (tonumber(count) or 0) + 1, #items do
        items[i] = nil
    end
end

local function writeSliderItem(items, index, key, value, formatter, lockedKeys, fallbackLowercase)
    local locked = istable(lockedKeys) and lockedKeys[key] == true
    local item = items[index]
    if not istable(item) then
        item = {}
        items[index] = item
    end

    item.key = key
    item.label = sliderLabels[key] or string.upper(key)
    item.value = locked and (fallbackLowercase and "formula" or "FORMULA") or formatter(value)
    item.accent = sliderColors[key] or palette.idle
    item.valueColor = locked and palette.textMuted or palette.text
    item.valueFont = locked and "MagicAlignToolgunTab" or nil

    return item
end

local function collectSliderItems(keys, values, formatter, lockedKeys, items)
    items = istable(items) and items or {}
    local count = 0

    for i = 1, #keys do
        local key = keys[i]
        local value = clampDisplayValue(values[key])
        local locked = istable(lockedKeys) and lockedKeys[key] == true
        if locked or math.abs(value) >= 0.005 then
            count = count + 1
            writeSliderItem(items, count, key, value, formatter, lockedKeys)
        end
    end

    clearReusableArray(items, count)
    return items
end

local function buildTranslationItems(press, lockedKeys, items)
    local delta = press.referenceDelta or VectorP(0, 0, 0)
    local values = toolScreenCache.translationValues
    if not istable(values) then
        values = {}
        toolScreenCache.translationValues = values
    end
    values.px, values.py, values.pz = delta.x, delta.y, delta.z
    items = collectSliderItems(translationKeys, values, formatUnits, lockedKeys, items)

    if #items > 0 then
        return items
    end

    local fallback = translationFallback[press.gizmo.key] or { "px" }
    local count = 0

    for i = 1, #fallback do
        local key = fallback[i]
        count = count + 1
        writeSliderItem(items, count, key, 0, formatUnits, lockedKeys, true)
    end

    clearReusableArray(items, count)
    return items
end

local function buildRotationItems(_, press, lockedKeys, items)
    local key = press.gizmo and press.gizmo.key or "roll"
    local value = press.rotationDelta or 0

    items = istable(items) and items or {}
    writeSliderItem(items, 1, key, value, formatAngle, lockedKeys, true)
    clearReusableArray(items, 1)
    return items
end

local function pressDisplaySignature(press, formulaRevision, state)
    if not press or press.kind ~= "gizmo" or not press.gizmo then return "" end

    local delta = press.referenceDelta
    return tostring(press.kind)
        .. "|" .. tostring(press.space)
        .. "|" .. tostring(press.gizmo.kind)
        .. "|" .. tostring(press.gizmo.key)
        .. "|" .. tostring(isvector(delta) and delta.x or 0)
        .. "|" .. tostring(isvector(delta) and delta.y or 0)
        .. "|" .. tostring(isvector(delta) and delta.z or 0)
        .. "|" .. tostring(press.rotationDelta or 0)
        .. "|" .. tostring(formulaRevision or 0)
        .. "|" .. tostring(state and state._magicAlignPreviewRevision or 0)
        .. "|" .. tostring(state and state._magicAlignToolScreenRevision or 0)
end

local function buildDisplayData(tool, state, cache)
    local press = state and state.press
    if not press or press.kind ~= "gizmo" or not press.gizmo then
        return
    end

    cache = istable(cache) and cache or toolScreenCache
    local formulaRevision = FormulaManager and isfunction(FormulaManager.GetRevision) and FormulaManager:GetRevision() or 0
    local signature = pressDisplaySignature(press, formulaRevision, state)
    if cache.signature == signature and cache.data.items then
        return cache.data
    end
    cache.signature = signature

    local accent = handleAccent[press.gizmo.key] or palette.idle
    local lockedKeys = lockedFormulaKeysForPress(press, cache.lockedKeys, cache.keyScratch)
    local items = press.gizmo.kind == "rot"
        and buildRotationItems(tool, press, lockedKeys, cache.items)
        or buildTranslationItems(press, lockedKeys, cache.items)

    local data = cache.data
    data.accent = accent
    data.title = "Reference Delta"
    data.handle = handleNames[press.gizmo.key] or string.upper(tostring(press.gizmo.key or "Gizmo"))
    data.space = press.space
    data.items = items

    return data
end

local function activeState(tool)
    if activeTool then
        local active, state = activeTool()
        if active == tool and state then
            return state
        end
    end

    return M.ClientState
end

function TOOL:DrawToolScreen(width, height)
    ensureFonts()

    local state = activeState(self)
    local data = buildDisplayData(self, state, toolScreenCache)
    local mirrorContext = not data and client.Mirror and client.Mirror.displayContext and client.Mirror.displayContext(self, state) or nil
    local accent = data and data.accent or (mirrorContext and mirrorContext.accent) or palette.idle
    local cacheProgress = activeWorldGridCacheProgress()
    local cacheAccent = cacheProgress and worldGridCacheAccent(cacheProgress) or nil

    drawBackdrop(width, height, accent)

    if cacheProgress then
        drawWorldGridCacheHeader(width, cacheProgress, cacheAccent)
    else
        draw.SimpleText("MAGIC ALIGN", "MagicAlignToolgunBrand", 24, 30, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    if not data then
        drawIdleCompasses(width, height, self, state, mirrorContext)
        drawFooter(width, height, self, state, data)
        return
    end

    if not cacheProgress then
        draw.SimpleText(data.title, "MagicAlignToolgunTitle", 24, 58, palette.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local chipX = width - chipWidth(data.handle) - 24
        drawChip(chipX, 28, data.handle, data.accent)
    end

    drawValueCards(width, height, data.items)
    drawFooter(width, height, self, state, data)
end
