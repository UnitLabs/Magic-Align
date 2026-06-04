MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local ENABLE_CVAR = "magic_align_highlight_context_menu"
local MIRROR_DISABLE_ANIMATION_CVAR = "magic_mirror_disable_menu_animation"
local SCAN_ID = "MagicAlignMenuEntryLetterOverlay"
local TOGGLE_CALLBACK_ID = SCAN_ID .. "Toggle"
local OVERLAY_VERSION = 11
local DEFAULT_CATEGORY = (TOOL and type(TOOL.Category) == "string" and TOOL.Category ~= "" and TOOL.Category)
    or "Construction"
local colors = client.colors or {}

local function solidColor(color, fallback, alpha)
    color = color or fallback or color_white
    return Color(color.r, color.g, color.b, alpha or color.a or 255)
end

local sourceAccent = solidColor(colors.source, Color(255, 190, 80))
local targetAccent = solidColor(colors.target, Color(80, 220, 255))
local mirrorAccent = solidColor(colors.mirror, Color(176, 112, 235))

local MIRROR_TRAILING_PIXEL_TRIM = 1
local TOOL_ENTRIES = {
    {
        id = "align",
        tool = "magic_align",
        key = "tool.magic_align.name",
        text = "Magic Align",
        command = "gmod_tool magic_align",
        category = DEFAULT_CATEGORY,
        letters = {
            { prefix = "", letter = "M", color = sourceAccent, disabled = solidColor(sourceAccent, nil, 120) },
            { prefix = "Magic ", letter = "A", color = targetAccent, disabled = solidColor(targetAccent, nil, 120) }
        }
    },
    {
        id = "mirror",
        tool = "magic_mirror",
        key = "tool.magic_mirror.name",
        text = "Magic Mirror",
        command = "gmod_tool magic_mirror",
        category = DEFAULT_CATEGORY,
        letters = {
            { prefix = "", letter = "M", color = mirrorAccent, disabled = solidColor(mirrorAccent, nil, 120) }
        },
        mirror = {
            prefix = "Magic ",
            word = "Mirror",
            accent = mirrorAccent
        }
    }
}

local TOOL_ENTRY_BY_ID = {}
for i = 1, #TOOL_ENTRIES do
    TOOL_ENTRY_BY_ID[TOOL_ENTRIES[i].id] = TOOL_ENTRIES[i]
end

local MIRROR_RT_PAD = 2
local MIRROR_SWEEP_MAX_PAUSE = 2.4
local MIRROR_SWEEP_MIN_TIME = 0.65
local MIRROR_SWEEP_MAX_TIME = 0.95
local MIRROR_SWEEP_EDGE_PAUSE_MIN = 0.18
local MIRROR_SWEEP_EDGE_PAUSE_MAX_FRACTION = 0.5
local MIRROR_SWEEP_PARTIAL_CHANCE = 0.7
local MIRROR_SWEEP_PARTIAL_MIN = 0.15
local MIRROR_SWEEP_PARTIAL_MAX = 0.85
local MIRROR_SWEEP_RT_STEP = 2
local MIRROR_SWEEP_BAR_WIDTH = 2
local mirrorRtSerial = 0
local mirrorRtCache = {}

local function resolvedText(value)
    local raw = tostring(value or "")
    if raw == "" then return "", raw end

    local key = string.sub(raw, 1, 1) == "#" and string.sub(raw, 2) or raw
    return key and language.GetPhrase(key) or raw, raw
end

local function panelText(panel)
    return resolvedText((IsValid(panel) and panel.GetText and panel:GetText()) or "")
end

local function overlayEnabled()
    local cvar = GetConVar(ENABLE_CVAR)
    return not cvar or cvar:GetBool()
end

local function mirrorAnimationDisabled()
    local cvar = GetConVar(MIRROR_DISABLE_ANIMATION_CVAR)
    return cvar and cvar:GetBool()
end

local function categoryLabel(category)
    local label = category.GetLabel and category:GetLabel()
    if type(label) == "string" and label ~= "" then return label end

    label = IsValid(category.Header) and category.Header.GetText and category.Header:GetText()
    return type(label) == "string" and label ~= "" and label or nil
end

local function specCategoryMatches(spec, label, raw)
    local categoryText, categoryRaw = resolvedText(spec.category or DEFAULT_CATEGORY)
    return raw == categoryRaw or label == categoryText
end

local function isTargetCategory(panel)
    if not IsValid(panel) then return false end

    local className = panel.GetClassName and panel:GetClassName()
    local isCategory = className == "DCollapsibleCategory"
        or (panel.SetExpanded and panel.GetExpanded and IsValid(panel.Header))
    if not isCategory then return false end

    local cookieName = panel.GetCookieName and panel:GetCookieName()
    if type(cookieName) == "string" then
        for i = 1, #TOOL_ENTRIES do
            local suffix = "." .. (TOOL_ENTRIES[i].category or DEFAULT_CATEGORY)
            if string.sub(cookieName, -#suffix) == suffix then return true end
        end
    end

    local label = categoryLabel(panel)
    if not label then return false end

    local labelText, labelRaw = resolvedText(label)
    for i = 1, #TOOL_ENTRIES do
        if specCategoryMatches(TOOL_ENTRIES[i], labelText, labelRaw) then return true end
    end

    return false
end

local function entryMatchesText(spec, text, raw)
    return raw == "#" .. spec.key or raw == spec.key or text == spec.text
end

local function matchingEntrySpec(panel)
    if not IsValid(panel) or panel.MagicAlignMenuEntryOverlayPart then return nil end

    local installed = panel.MagicAlignMenuEntrySpecId and TOOL_ENTRY_BY_ID[panel.MagicAlignMenuEntrySpecId]
    if installed then return installed end

    for i = 1, #TOOL_ENTRIES do
        local spec = TOOL_ENTRIES[i]
        if panel.Name == spec.tool or panel.Command == spec.command then return spec end
    end

    local text, raw = panelText(panel)
    for i = 1, #TOOL_ENTRIES do
        local spec = TOOL_ENTRIES[i]
        if entryMatchesText(spec, text, raw) then return spec end
    end

    return nil
end

local function textInset(panel)
    if not panel.GetTextInset then return 0, 0 end

    local x, y = panel:GetTextInset()
    return tonumber(x) or 0, tonumber(y) or 0
end

local function textStartX(panel, text, font, width)
    surface.SetFont(font)

    local textWidth = surface.GetTextSize(text)
    local inset = textInset(panel)
    local align = panel.GetContentAlignment and panel:GetContentAlignment() or 4

    if align == 2 or align == 5 or align == 8 then
        return math.floor((width - textWidth) * 0.5 + inset + 0.5)
    elseif align == 3 or align == 6 or align == 9 then
        return math.floor(width - textWidth - inset + 0.5)
    end

    return math.floor(inset + 0.5)
end

local function panelTreeVisible(panel)
    if not IsValid(panel) then return false end
    if not IsValid(g_SpawnMenu) or not g_SpawnMenu:IsVisible() then return false end

    local current = panel
    while IsValid(current) do
        if current.IsVisible and not current:IsVisible() then return false end
        current = current.GetParent and current:GetParent() or nil
    end

    return true
end

local function panelReadyForOverlay(panel, width, height)
    if not panelTreeVisible(panel) then return false end
    width = width or (panel.GetWide and panel:GetWide()) or 0
    height = height or (panel.GetTall and panel:GetTall()) or 0
    return width > 0 and height > 0
end

local function overlayTextForSpec(spec)
    return spec.mirror and spec.mirror.prefix or spec.text
end

local function restorePanelText(panel)
    if panel.MagicAlignMenuEntryOriginalText ~= nil and panel.SetText then
        panel:SetText(panel.MagicAlignMenuEntryOriginalText)
    end

    panel.MagicAlignMenuEntryOriginalText = nil
end

local function removeOverlay(panel)
    if not IsValid(panel) then return end

    if panel.MagicAlignMenuEntryOverlay or panel.MagicAlignMenuEntryOverlayVersion then
        panel.PaintOver = panel.MagicAlignMenuEntryOldPaintOver
        panel.PerformLayout = panel.MagicAlignMenuEntryOldPerformLayout
    end

    if panel.MagicAlignMenuEntryWrappedClick then
        panel.DoClick = panel.MagicAlignMenuEntryOldDoClick
        panel.OnCursorEntered = panel.MagicAlignMenuEntryOldOnCursorEntered
    end

    local clips = panel.MagicAlignMenuEntryClips
    for i = 1, clips and #clips or 0 do
        if IsValid(clips[i]) then clips[i]:Remove() end
    end

    restorePanelText(panel)

    panel.MagicAlignMenuEntryClips = nil
    panel.MagicAlignMenuEntryOldPaintOver = nil
    panel.MagicAlignMenuEntryOldPerformLayout = nil
    panel.MagicAlignMenuEntryOldDoClick = nil
    panel.MagicAlignMenuEntryOldOnCursorEntered = nil
    panel.MagicAlignMenuEntryWrappedClick = nil
    panel.MagicAlignMenuEntryOverlay = nil
    panel.MagicAlignMenuEntryOverlayVersion = nil
    panel.MagicAlignMenuEntrySpecId = nil
    panel.MagicAlignMenuMirrorAnim = nil
    panel.MagicAlignMenuMirrorAnimRequested = nil
end

local function colorKey(color)
    color = color or color_white
    return ("%d_%d_%d_%d"):format(color.r or 255, color.g or 255, color.b or 255, color.a or 255)
end

local function toolModeActive(spec)
    local cvar = GetConVar("gmod_toolmode")
    return cvar and cvar:GetString() == spec.tool
end

local function entryActive(panel, spec)
    if panel.GetSelected and panel:GetSelected() then return true end
    if panel.GetChecked and panel:GetChecked() then return true end
    if panel.Selected or panel.m_bSelected then return true end
    return toolModeActive(spec)
end

local function categoryLineTextColor(panel, spec, enabled)
    local skin = panel.GetSkin and panel:GetSkin()
    local category = skin and skin.Colours and skin.Colours.Category
    local line = category and (panel.AltLine and category.LineAlt or category.Line)
    if not line then return nil end

    if not enabled then return line.Text_Disabled end
    if panel.Depressed or panel.m_bSelected or toolModeActive(spec) then return line.Text_Selected end
    if panel.Hovered then return line.Text_Hover end
    return line.Text
end

local function panelTextColor(panel, spec, enabled)
    if panel.UpdateColours and panel.GetSkin then
        panel:UpdateColours(panel:GetSkin())
    end

    local color = categoryLineTextColor(panel, spec, enabled)
    if not (color and color.r and color.g and color.b) then
        color = panel.GetTextStyleColor and panel:GetTextStyleColor()
    end
    if not (color and color.r and color.g and color.b) then
        color = panel.GetColor and panel:GetColor()
    end
    if not (color and color.r and color.g and color.b) then
        color = panel.GetTextColor and panel:GetTextColor()
    end

    local fallback = entryActive(panel, spec) and color_white or Color(30, 30, 30)
    return solidColor(color, fallback, enabled and (color and color.a) or math.min(color and color.a or 255, 140))
end

local function textTopY(font, height, text)
    surface.SetFont(font)
    local _, textHeight = surface.GetTextSize(text)
    return math.floor((height - textHeight) * 0.5 + 0.5)
end

local function drawTextAt(text, font, x, y, color)
    if text == "" then return end

    surface.SetFont(font)
    surface.SetTextColor(color.r, color.g, color.b, color.a)
    surface.SetTextPos(math.floor(x + 0.5), y)
    surface.DrawText(text)
end

local function drawHighlightedText(text, font, x, height, textColor, letters, enabled)
    if text == "" then return end

    surface.SetFont(font)

    local y = textTopY(font, height, text)
    local cursor = 1

    for i = 1, letters and #letters or 0 do
        local spec = letters[i]
        local prefix = spec.prefix or ""
        local letter = spec.letter or ""
        local startIndex = #prefix + 1
        local endIndex = startIndex + #letter - 1

        if startIndex >= cursor
            and string.sub(text, 1, #prefix) == prefix
            and string.sub(text, startIndex, endIndex) == letter then
            local segment = string.sub(text, cursor, startIndex - 1)
            local segmentX = x + surface.GetTextSize(string.sub(text, 1, cursor - 1))
            drawTextAt(segment, font, segmentX, y, textColor)

            local letterX = x + surface.GetTextSize(prefix)
            drawTextAt(letter, font, letterX, y, enabled and spec.color or spec.disabled)
            cursor = endIndex + 1
        end
    end

    local rest = string.sub(text, cursor)
    local restX = x + surface.GetTextSize(string.sub(text, 1, cursor - 1))
    drawTextAt(rest, font, restX, y, textColor)
end

local function renderMirrorWord(word, font, width, height, accent, textColor)
    surface.SetFont(font)

    local head = string.sub(word, 1, 1)
    local tail = string.sub(word, 2)
    local headWidth = surface.GetTextSize(head)
    local y = textTopY(font, height, word)

    surface.SetTextColor(accent.r, accent.g, accent.b, accent.a)
    surface.SetTextPos(MIRROR_RT_PAD, y)
    surface.DrawText(head)

    surface.SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)
    surface.SetTextPos(MIRROR_RT_PAD + headWidth, y)
    surface.DrawText(tail)
end

local function drawIntoRenderTarget(rt, clearColor, callback)
    clearColor = clearColor or color_black

    render.PushRenderTarget(rt)
    if render.OverrideAlphaWriteEnable then render.OverrideAlphaWriteEnable(true, true) end
    render.Clear(clearColor.r or 0, clearColor.g or 0, clearColor.b or 0, 0, true, true)
    cam.Start2D()
    callback()
    cam.End2D()
    if render.OverrideAlphaWriteEnable then render.OverrideAlphaWriteEnable(false, false) end
    render.PopRenderTarget()
end

local function createRtMaterial(name, rt)
    return CreateMaterial(name, "UnlitGeneric", {
        ["$basetexture"] = rt:GetName(),
        ["$translucent"] = "1",
        ["$vertexalpha"] = "1",
        ["$vertexcolor"] = "1",
        ["$ignorez"] = "1",
        ["$nolod"] = "1",
        ["$nomip"] = "1"
    })
end

local function mirrorRtPair(word, font, wordWidth, height, accent, textColor)
    if not GetRenderTarget or not CreateMaterial or not render or not cam then return nil end

    local rtW = math.max(math.ceil(wordWidth + MIRROR_RT_PAD * 2), 16)
    local rtH = math.max(math.ceil(height), 16)
    local key = table.concat({ word, font, rtW, rtH, colorKey(accent), colorKey(textColor) }, "|")
    local cached = mirrorRtCache[key]
    if cached then return cached end

    mirrorRtSerial = mirrorRtSerial + 1
    local baseName = "MagicAlignMirrorMenuText" .. mirrorRtSerial
    local normalRt = GetRenderTarget(baseName .. "_normal", rtW, rtH)
    local normalMaterial = createRtMaterial(baseName .. "_normal_mat", normalRt)

    drawIntoRenderTarget(normalRt, textColor, function()
        renderMirrorWord(word, font, rtW, rtH, accent, textColor)
    end)

    cached = {
        normal = normalMaterial,
        width = rtW,
        height = rtH,
        textWidth = wordWidth
    }
    mirrorRtCache[key] = cached
    return cached
end

local function randomLegDuration()
    return math.Rand(MIRROR_SWEEP_MIN_TIME, MIRROR_SWEEP_MAX_TIME)
end

local function randomEdgePause()
    local maxPause = math.max(MIRROR_SWEEP_EDGE_PAUSE_MIN, MIRROR_SWEEP_MAX_PAUSE * MIRROR_SWEEP_EDGE_PAUSE_MAX_FRACTION)
    return math.Rand(MIRROR_SWEEP_EDGE_PAUSE_MIN, maxPause)
end

local function easedCosine(t)
    return 0.5 - 0.5 * math.cos(math.Clamp(t, 0, 1) * math.pi)
end

local function randomFractionTarget(wordWidth, side, minFraction, maxFraction)
    local minX = math.Clamp(math.floor(wordWidth * minFraction + 0.5), 0, wordWidth)
    local maxX = math.Clamp(math.floor(wordWidth * maxFraction + 0.5), minX, wordWidth)
    local distance = maxX > minX and math.random(minX, maxX) or minX

    return side == "right" and wordWidth - distance or distance
end

local function randomPartialTarget(wordWidth, side)
    return randomFractionTarget(wordWidth, side, MIRROR_SWEEP_PARTIAL_MIN, MIRROR_SWEEP_PARTIAL_MAX)
end

local function defaultMirrorSweepX()
    return 0
end

local function resetMirrorAnimation(anim, wordWidth)
    local defaultX = defaultMirrorSweepX()
    anim.wordWidth = wordWidth
    anim.x = defaultX
    anim.queue = nil
    anim.pauseUntil = nil
    anim.startTime = nil
    anim.duration = nil
    anim.idle = true
    anim.defaultMirrored = true
    return defaultX
end

local function startMirrorSweepBurst(anim, wordWidth)
    local side = (anim.x or wordWidth) <= 0 and "left" or "right"
    local home = side == "right" and wordWidth or 0
    local far = side == "right" and 0 or wordWidth
    local target = math.Rand(0, 1) < MIRROR_SWEEP_PARTIAL_CHANCE and randomPartialTarget(wordWidth, side)
        or far

    anim.queue = { target, home }
    anim.x = home
end

local function startNextMirrorSweepLeg(anim)
    local to = anim.queue and table.remove(anim.queue, 1)
    if to == nil then return false end

    anim.from = anim.x or anim.from or 0
    anim.to = to
    anim.startTime = CurTime()
    anim.duration = randomLegDuration()
    return true
end

local function mirrorAnimationIdle(anim)
    return not anim or (anim.idle and not anim.startTime and not anim.pauseUntil
        and not (anim.queue and #anim.queue > 0))
end

local function mirrorSweepX(panel, wordWidth)
    local now = CurTime()
    wordWidth = math.max(math.floor(wordWidth + 0.5), 0)

    local anim = panel.MagicAlignMenuMirrorAnim
    if not anim or anim.wordWidth ~= wordWidth or not anim.defaultMirrored then
        anim = {}
        resetMirrorAnimation(anim, wordWidth)
        panel.MagicAlignMenuMirrorAnim = anim
    end

    if mirrorAnimationDisabled() then
        panel.MagicAlignMenuMirrorAnimRequested = nil
        return resetMirrorAnimation(anim, wordWidth), false
    end

    if panel.MagicAlignMenuMirrorAnimRequested then
        panel.MagicAlignMenuMirrorAnimRequested = nil
        if mirrorAnimationIdle(anim) then
            resetMirrorAnimation(anim, wordWidth)
            anim.idle = false
            startMirrorSweepBurst(anim, wordWidth)

            if not startNextMirrorSweepLeg(anim) then
                anim.idle = true
                return anim.x or defaultMirrorSweepX(), false
            end
        end
    end

    if anim.pauseUntil then
        if now < anim.pauseUntil then return anim.x or wordWidth, false end

        anim.pauseUntil = nil
        if not startNextMirrorSweepLeg(anim) then
            anim.idle = true
            return anim.x or wordWidth, false
        end
    end

    if anim.idle or not anim.startTime then return anim.x or defaultMirrorSweepX(), false end

    local t = (now - anim.startTime) / math.max(anim.duration or 1, 0.01)
    if t >= 1 then
        anim.x = anim.to
        anim.startTime = nil
        anim.duration = nil
        local hasQueuedLeg = anim.queue and #anim.queue > 0
        anim.pauseUntil = hasQueuedLeg and now + randomEdgePause() or nil
        anim.idle = not hasQueuedLeg
        return math.Clamp(anim.x or 0, 0, wordWidth), false
    end

    local eased = easedCosine(t)
    local x = (anim.from or wordWidth) + ((anim.to or 0) - (anim.from or wordWidth)) * eased
    anim.x = math.Clamp(math.floor(x + 0.5), 0, wordWidth)
    return anim.x, true
end

local function mirrorCutX(barX, wordWidth)
    local step = MIRROR_SWEEP_RT_STEP
    local cut = math.floor((barX or wordWidth) / step + 0.5) * step
    return math.Clamp(cut, 0, wordWidth)
end

local function drawMirrorSegment(pair, material, x, y, height, from, to, flipped)
    if not pair or not material or to <= from then return end

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    height = math.floor(height + 0.5)
    from = math.floor(from + 0.5)
    to = math.floor(to + 0.5)
    if to <= from then return end

    local u1 = (MIRROR_RT_PAD + from) / pair.width
    local u2 = (MIRROR_RT_PAD + to) / pair.width
    if flipped then
        local textWidth = math.max((pair.textWidth or math.max(pair.width - MIRROR_RT_PAD * 2, 0)) - MIRROR_TRAILING_PIXEL_TRIM, 0)
        u1 = (MIRROR_RT_PAD + textWidth - from) / pair.width
        u2 = (MIRROR_RT_PAD + textWidth - to) / pair.width
    end

    surface.SetMaterial(material)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRectUV(
        x + from,
        y,
        to - from,
        height,
        u1,
        0,
        u2,
        1
    )
end

local function pushPointFilter()
    if not TEXFILTER or TEXFILTER.POINT == nil then return false, false end

    local pushedMin = render.PushFilterMin ~= nil
    local pushedMag = render.PushFilterMag ~= nil
    if pushedMin then render.PushFilterMin(TEXFILTER.POINT) end
    if pushedMag then render.PushFilterMag(TEXFILTER.POINT) end
    return pushedMin, pushedMag
end

local function popPointFilter(pushedMin, pushedMag)
    if pushedMag and render.PopFilterMag then render.PopFilterMag() end
    if pushedMin and render.PopFilterMin then render.PopFilterMin() end
end

local function drawMirrorTextureClipped(panel, pair, material, x, y, height, from, to, flipped)
    if not pair or not material or to <= from then return end

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    height = math.floor(height + 0.5)
    from = math.floor(from + 0.5)
    to = math.floor(to + 0.5)
    if to <= from then return end

    if not render.SetScissorRect or not panel.LocalToScreen then
        drawMirrorSegment(pair, material, x, y, height, from, to, flipped)
        return
    end

    local screenX, screenY = panel:LocalToScreen(0, 0)
    local pushedMin, pushedMag = pushPointFilter()

    render.SetScissorRect(screenX + x + from, screenY + y, screenX + x + to, screenY + y + height, true)
        surface.SetMaterial(material)
        surface.SetDrawColor(255, 255, 255, 255)
        if flipped then
            surface.DrawTexturedRectUV(x - MIRROR_RT_PAD - MIRROR_TRAILING_PIXEL_TRIM, y, pair.width, pair.height, 1, 0, 0, 1)
        else
            surface.DrawTexturedRect(x - MIRROR_RT_PAD, y, pair.width, pair.height)
        end
    render.SetScissorRect(0, 0, 0, 0, false)

    popPointFilter(pushedMin, pushedMag)
end

local function drawMirrorWordOverlay(panel, spec, width, height, font, textX, enabled)
    local mirror = spec.mirror
    if not mirror then return end

    surface.SetFont(font)
    local fullWidth = math.floor(surface.GetTextSize(spec.text) + 0.5)
    local wordWidth = math.floor(surface.GetTextSize(mirror.word) + 0.5)
    local visibleWordWidth = math.max(wordWidth - MIRROR_TRAILING_PIXEL_TRIM, 0)
    local prefixWidth = math.max(fullWidth - wordWidth, 0)
    if visibleWordWidth <= 0 then return end

    local textColor = panelTextColor(panel, spec, enabled)
    local accent = enabled and mirror.accent or solidColor(mirror.accent, nil, 120)
    local pair = mirrorRtPair(mirror.word, font, wordWidth, height, accent, textColor)
    if not pair then return end

    local x = math.floor(textX + prefixWidth + 0.5)
    local barX, showBar = mirrorSweepX(panel, visibleWordWidth)
    barX = math.Clamp(barX, 0, visibleWordWidth)

    local cutX = mirrorCutX(barX, visibleWordWidth)
    drawMirrorTextureClipped(panel, pair, pair.normal, x, 0, height, 0, cutX)
    drawMirrorTextureClipped(panel, pair, pair.normal, x, 0, height, cutX, visibleWordWidth, true)

    if showBar then
        surface.SetDrawColor(accent.r, accent.g, accent.b, accent.a)
        surface.DrawRect(
            x + math.Clamp(barX - math.floor(MIRROR_SWEEP_BAR_WIDTH * 0.5), 0, math.max(visibleWordWidth - MIRROR_SWEEP_BAR_WIDTH, 0)),
            2,
            math.min(MIRROR_SWEEP_BAR_WIDTH, visibleWordWidth),
            math.max(height - 4, 1)
        )
    end
end

local function syncOverlay(panel, spec, width, height)
    if not panelReadyForOverlay(panel, width, height) then return end

    width = width or panel:GetWide()
    height = height or panel:GetTall()

    local text = spec.text
    local font = panel.GetFont and panel:GetFont() or "DermaDefault"
    local textX = textStartX(panel, text, font, width)
    local enabled = not panel.IsEnabled or panel:IsEnabled()
    local textColor = panelTextColor(panel, spec, enabled)

    drawHighlightedText(overlayTextForSpec(spec), font, textX, height, textColor, spec.letters, enabled)
    drawMirrorWordOverlay(panel, spec, width, height, font, textX, enabled)
end

local function preparePanelText(panel, spec)
    if panel.MagicAlignMenuEntryOriginalText ~= nil or not panel.SetText then return end

    panel.MagicAlignMenuEntryOriginalText = (panel.GetText and panel:GetText()) or spec.text
    panel:SetText("")
end

local function requestMirrorAnimation(panel)
    if mirrorAnimationDisabled() then return end
    if panel.MagicAlignMenuMirrorAnimRequested then return end
    if not mirrorAnimationIdle(panel.MagicAlignMenuMirrorAnim) then return end

    panel.MagicAlignMenuMirrorAnimRequested = true
end

local function wrapMirrorActions(panel)
    if panel.MagicAlignMenuEntryWrappedClick then return end

    panel.MagicAlignMenuEntryOldDoClick = panel.DoClick
    panel.MagicAlignMenuEntryOldOnCursorEntered = panel.OnCursorEntered
    panel.MagicAlignMenuEntryWrappedClick = true
    panel.DoClick = function(self, ...)
        requestMirrorAnimation(self)

        if self.MagicAlignMenuEntryOldDoClick then
            return self.MagicAlignMenuEntryOldDoClick(self, ...)
        end
    end

    panel.OnCursorEntered = function(self, ...)
        requestMirrorAnimation(self)

        if self.MagicAlignMenuEntryOldOnCursorEntered then
            return self.MagicAlignMenuEntryOldOnCursorEntered(self, ...)
        end
    end
end

local function installOverlay(panel, spec)
    if not overlayEnabled() then
        removeOverlay(panel)
        return
    end

    if spec and spec.mirror and not panelReadyForOverlay(panel) then return end

    if not spec or panel.MagicAlignMenuEntryOverlayVersion == OVERLAY_VERSION
        and panel.MagicAlignMenuEntrySpecId == spec.id then return end

    removeOverlay(panel)
    preparePanelText(panel, spec)

    panel.MagicAlignMenuEntryOverlay = true
    panel.MagicAlignMenuEntryOverlayVersion = OVERLAY_VERSION
    panel.MagicAlignMenuEntrySpecId = spec.id
    panel.MagicAlignMenuEntryOldPaintOver = panel.PaintOver
    panel.MagicAlignMenuEntryOldPerformLayout = panel.PerformLayout

    if spec.mirror then wrapMirrorActions(panel) end

    panel.PaintOver = function(self, width, height)
        if self.MagicAlignMenuEntryOldPaintOver then
            self.MagicAlignMenuEntryOldPaintOver(self, width, height)
        end

        syncOverlay(self, spec, width, height)
    end

    panel.PerformLayout = function(self, width, height)
        if self.MagicAlignMenuEntryOldPerformLayout then
            self.MagicAlignMenuEntryOldPerformLayout(self, width, height)
        end

        syncOverlay(self, spec, width, height)
    end
end

local function clearPanel(panel)
    if not IsValid(panel) then return end

    removeOverlay(panel)

    local children = panel:GetChildren()
    for i = 1, #children do
        clearPanel(children[i])
    end
end

local function scanPanel(panel, inTargetCategory)
    if not IsValid(panel) then return end

    inTargetCategory = inTargetCategory or isTargetCategory(panel)
    if inTargetCategory then installOverlay(panel, matchingEntrySpec(panel)) end

    local children = panel:GetChildren()
    for i = 1, #children do
        scanPanel(children[i], inTargetCategory)
    end
end

local function scanKnownMenus()
    if not IsValid(g_SpawnMenu) or not g_SpawnMenu:IsVisible() then return end

    local root = g_SpawnMenu.GetToolMenu and g_SpawnMenu:GetToolMenu()
    if not IsValid(root) then return end

    if overlayEnabled() then
        scanPanel(root, false)
    else
        clearPanel(root)
    end
end

client.InstallMenuEntryLetterOverlay = scanKnownMenus

for _, hookName in ipairs({ "SpawnMenuCreated", "PostReloadToolsMenu", "OnSpawnMenuOpen" }) do
    hook.Add(hookName, SCAN_ID, function()
        timer.Simple(0, scanKnownMenus)
    end)
end

if cvars and cvars.AddChangeCallback then
    if cvars.RemoveChangeCallback then
        cvars.RemoveChangeCallback(ENABLE_CVAR, TOGGLE_CALLBACK_ID)
    end

    cvars.AddChangeCallback(ENABLE_CVAR, function()
        timer.Simple(0, scanKnownMenus)
    end, TOGGLE_CALLBACK_ID)
end

timer.Create(SCAN_ID, 1, 0, function()
    if IsValid(g_SpawnMenu) and g_SpawnMenu:IsVisible() then
        scanKnownMenus()
    end
end)
