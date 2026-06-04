MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local VALUE_FONT_PREFIX = "MagicAlignToolgunValue"
local VALUE_FONT_SIZES = { 64, 58, 52, 46, 40, 34, 30, 26, 22, 18, 16 }
local fontsReady = false
local cachedColors = {}
local valueFontTexts = {}

local palette = {
    bg = Color(5, 6, 8),
    shell = Color(12, 14, 18),
    card = Color(23, 26, 32),
    cardSoft = Color(16, 18, 23),
    border = Color(72, 78, 90),
    text = Color(238, 242, 248),
    textMuted = Color(158, 168, 184),
    shadow = Color(0, 0, 0, 78)
}

local function solid(color, fallback)
    color = color or fallback
    return Color(color.r, color.g, color.b, 255)
end

local colors = client.colors or {}
local accent = solid(colors.mirror, Color(176, 112, 235))
local missingColor = Color(166, 174, 188)

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
    color = color or color_white
    return cachedColor(color.r, color.g, color.b, alpha)
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

    surface.CreateFont("MagicAlignToolgunCaption", {
        font = "Roboto",
        size = 18,
        weight = 600,
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

local function commitUploadProgress()
    local upload = M.CommitUpload
    if not istable(upload) or upload.finishedAt then return end

    return math.Clamp(tonumber(upload.progress) or 0, 0, 1)
end

local function drawBackdrop(width, height, cardAccent)
    cardAccent = cardAccent or accent

    surface.SetDrawColor(palette.bg)
    surface.DrawRect(0, 0, width, height)

    draw.RoundedBox(18, 8, 8, width - 16, height - 16, palette.shell)
    draw.RoundedBox(14, 16, 16, width - 32, height - 32, palette.cardSoft)

    local topBarX = 16
    local topBarY = 16
    local topBarW = width - 32
    local topBarH = 6

    surface.SetDrawColor(colorAlpha(cardAccent, 165))
    surface.DrawRect(topBarX, topBarY, topBarW, topBarH)

    local uploadProgress = commitUploadProgress()
    if uploadProgress then
        local covered = math.floor(topBarW * (1 - uploadProgress))
        if covered > 0 then
            surface.SetDrawColor(colorAlpha(Color(255, 190, 80), 178))
            surface.DrawRect(topBarX + topBarW - covered, topBarY, covered, topBarH)
        end
    end

    surface.SetDrawColor(palette.border)
    surface.DrawOutlinedRect(8, 8, width - 16, height - 16, 1)
    surface.DrawOutlinedRect(16, 16, width - 32, height - 32, 1)
end

local function activeState()
    local mirrorClient = client.MagicMirror
    if mirrorClient and isfunction(mirrorClient.activeToolState) then
        local _, state = mirrorClient.activeToolState()
        if state then return state end
    end

    return mirrorClient and mirrorClient.ClientState or M.MagicMirrorClientState
end

local function activeHover(state)
    local hover = state and state.hover
    if hover and IsValid(hover.ent) then
        return hover
    end
end

local function axisLabel(hover)
    local label = hover and hover.zone and hover.zone.label
    if label and label ~= "" then
        return label
    end
end

local function drawAxisCard(width, height, label)
    local margin = 24
    local top = 86
    local bottom = 30
    local cardX = margin
    local cardY = top
    local cardW = width - margin * 2
    local cardH = math.max(height - top - bottom, 56)
    local hasAxis = label ~= nil
    local value = hasAxis and label or "NO PROP"
    local valueColor = hasAxis and palette.text or missingColor

    draw.RoundedBox(12, cardX, cardY, cardW, cardH, palette.card)
    draw.RoundedBox(12, cardX, cardY, 8, cardH, colorAlpha(accent, 220))
    surface.SetDrawColor(colorAlpha(palette.shadow, 10))
    surface.DrawOutlinedRect(cardX, cardY, cardW, cardH, 1)

    draw.SimpleText("Local Axis", "MagicAlignToolgunCaption", cardX + 18, cardY + 14, palette.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    valueFontTexts[1] = value
    for i = 2, #valueFontTexts do
        valueFontTexts[i] = nil
    end

    local valueFont = pickValueFont(valueFontTexts, cardW - 30, math.max(cardH * 0.52, VALUE_FONT_SIZES[#VALUE_FONT_SIZES]))
    draw.SimpleText(value, valueFont, cardX + cardW * 0.5, cardY + cardH * 0.62, valueColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function TOOL:DrawToolScreen(width, height)
    ensureFonts()

    local hover = activeHover(activeState())
    local label = axisLabel(hover)

    drawBackdrop(width, height, accent)
    draw.SimpleText("MAGIC MIRROR", "MagicAlignToolgunBrand", 24, 30, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    drawAxisCard(width, height, label)
end

return true
