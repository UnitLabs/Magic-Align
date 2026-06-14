MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local VectorP = M.VectorP
local isvector = M.IsVectorLike
local toVector = M.ToVector
local client = M.Client or {}
M.Client = client
local geometry = client.geometry or {}

local colors = client.colors or {}

local RENDER_CONFIG = {
    gridLabelPercentCvar = "magic_align_grid_label_percent",
    gridLabelReduceFractionCvar = "magic_align_grid_label_reduce_fraction",
    gridAlphaCvar = "magic_align_grid_alpha"
}

local GRID_CONFIG = {
    alphaPrimary = 64,
    alphaSecondary = 64,
    snapLineAlpha = 255,
    snapLabelAlpha = 235,
    snapLabelInset = 1.6,
    bspSurfacePush = 0.12
}

local function newRenderVector(x, y, z)
    return Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
end

local function setRenderVector(out, x, y, z)
    local worldGridRender = client.worldGridRender
    local setter = worldGridRender and worldGridRender.setRenderVector
    if isfunction(setter) then
        return setter(out, x, y, z)
    end

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
local cursorLineFallbackColors = {
    source = { r = 255, g = 190, b = 80 },
    target = { r = 80, g = 220, b = 255 },
    mirror = { r = 176, g = 112, b = 235 }
}
local cursorAccentFallbackColors = {
    source = { r = 255, g = 190, b = 80 },
    target = { r = 80, g = 220, b = 255 },
    mirror = { r = 176, g = 112, b = 235 }
}
local cursorAccentKeys = {
    source = "cursorSource",
    target = "cursorTarget",
    mirror = "mirror"
}

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

local function drawLine(startPos, endPos, color, writeZ)
    startPos = toVector(startPos)
    endPos = toVector(endPos)
    if not startPos or not endPos then return end

    render.DrawLine(startPos, endPos, color, writeZ)
end

local function paletteColor(key, alpha)
    local palette = client.colors or colors
    local fallback = cursorLineFallbackColors[key] or cursorLineFallbackColors.target
    local color = palette and palette[key] or colors[key] or fallback

    return cachedColor(
        color and color.r or fallback.r,
        color and color.g or fallback.g,
        color and color.b or fallback.b,
        alpha
    )
end

local function cursorAccentColorForSide(side, alpha)
    local palette = client.colors or colors
    local paletteKey = cursorAccentKeys[side] or cursorAccentKeys.source
    local fallback = cursorAccentFallbackColors[side] or cursorAccentFallbackColors.source
    local color = palette and palette[paletteKey] or colors[paletteKey] or fallback

    return cachedColor(
        color and color.r or fallback.r,
        color and color.g or fallback.g,
        color and color.b or fallback.b,
        alpha
    )
end

local function cursorSideForContext(state, side, ent)
    if side == "mirror" then
        return "mirror"
    elseif side == "target" then
        return "target"
    elseif side == "source" then
        return "source"
    end
end

local function cursorLineSide(state, candidate)
    local hover = state and state.hover
    local press = state and state.press

    local pressSide = cursorSideForContext(state, press and press.side, press and press.ent)
    if pressSide then
        return pressSide
    end

    if hover and hover.pickTarget then
        return "target"
    elseif hover and hover.pickSource then
        return "source"
    end

    if hover and (candidate == nil or hover.candidate == candidate or hover.overlay == candidate) then
        local hoverSide = cursorSideForContext(state, hover.side, hover.ent)
        if hoverSide then return hoverSide end
    end

    return "source"
end

local function cursorLineColor(state, candidate, alpha)
    return paletteColor(cursorLineSide(state, candidate), alpha)
end

local function cursorAccentColor(state, candidate, alpha)
    return cursorAccentColorForSide(cursorLineSide(state, candidate), alpha)
end

local function lightScaledAlpha(alpha)
    local scale = client.worldGridRender.currentLightBlend and client.worldGridRender.currentLightBlend() or 1
    return math.Clamp(math.floor((tonumber(alpha) or 255) * scale + 0.5), 0, 255)
end

local function readClampedConVarInt(name, fallback, minValue, maxValue)
    local cvar = name and GetConVar(name) or nil
    local value = cvar and cvar:GetFloat() or fallback

    return math.Clamp(math.floor((tonumber(value) or fallback or 0) + 0.5), minValue or 0, maxValue or 255)
end

local function isDrawingPickPress(state)
    local press = state and state.press
    if not press then return false end

    if press.drawActive ~= true then
        return false
    end

    return press.kind == "pick"
        or press.kind == "select_source_pick"
        or press.kind == "select_target_pick"
end

local function hasDrawableFace(candidate)
    if not candidate or not candidate.face then return false end
    if IsValid(candidate.ent) then return true end

    return M.IsWorldTarget(candidate.ent) and candidate.face.worldBSP == true
end

local function shouldRenderGrid(state, candidate)
    if not hasDrawableFace(candidate) then return false end

    local settings = state and state.hover and state.hover.settings
    if isDrawingPickPress(state) then return false end
    if settings and settings.shift then return false end

    return true
end

local function shouldRenderFace(state, candidate)
    if not hasDrawableFace(candidate) then return false end
    if isDrawingPickPress(state) then return false end

    return true
end

local function sideAccentColor(state, side, ent)
    local contextSide = cursorSideForContext(state, side, ent)
    if contextSide then return cursorAccentColorForSide(contextSide, 255) end

    return colors.pending
end

local function activePickAccentColor(state)
    local press = state and state.press
    if not press or not isDrawingPickPress(state) then
        return colors.pending
    end

    return sideAccentColor(state, press.side, press.ent)
end

local function formatPercentLabel(percent)
    if percent == nil or percent <= 0.05 or percent >= 99.95 then return end

    local rounded = math.Round(percent, math.abs(percent - math.Round(percent)) < 0.05 and 0 or 1)
    if math.abs(rounded - math.Round(rounded)) < 0.05 then
        return ("%d%%"):format(math.Round(rounded))
    end

    return ("%.1f%%"):format(rounded)
end

local function gcd(a, b)
    a = math.abs(math.floor(tonumber(a) or 0))
    b = math.abs(math.floor(tonumber(b) or 0))

    while b ~= 0 do
        a, b = b, a % b
    end

    return math.max(a, 1)
end

local function lcm(a, b)
    a = math.max(math.floor(tonumber(a) or 0), 1)
    b = math.max(math.floor(tonumber(b) or 0), 1)

    return math.floor((a / gcd(a, b)) * b)
end

local function gridAxisDivisions(grid, axisKey)
    if not grid then return 0 end

    return math.max(math.Round(axisKey == "u" and (grid.divU or 0) or (grid.divV or 0)), 0)
end

local function commonGridDivisions(face, axisKey)
    local common = 1
    local found = false
    local gridSets = {}
    local seen = {}

    local function addGrid(grid)
        if not grid or seen[grid] then return end
        seen[grid] = true
        gridSets[#gridSets + 1] = grid
    end

    addGrid(face and face.gridA)
    addGrid(face and face.gridB)
    addGrid(face and face.snapGridU)
    addGrid(face and face.snapGridV)

    for _, grid in ipairs(gridSets) do
        local divisions = gridAxisDivisions(grid, axisKey)
        if divisions > 0 then
            common = lcm(common, divisions)
            found = true
        end
    end

    return found and common or 0
end

local function formatFractionLabel(index, divisions, commonDivisions, reduce)
    index = math.Round(tonumber(index) or 0)
    divisions = math.max(math.Round(tonumber(divisions) or 0), 0)
    commonDivisions = math.max(math.Round(tonumber(commonDivisions) or divisions), divisions)

    if divisions <= 0 or index <= 0 or index >= divisions then return end

    local numerator = index
    local denominator = divisions

    if reduce ~= false then
        numerator = math.Round(index * commonDivisions / divisions)
        denominator = commonDivisions
        local divisor = gcd(numerator, denominator)

        numerator = math.floor(numerator / divisor)
        denominator = math.floor(denominator / divisor)
    end

    if denominator <= 1 then return tostring(numerator) end

    return ("%d/%d"):format(numerator, denominator)
end

local function shouldUsePercentGridLabels()
    local cvar = GetConVar(RENDER_CONFIG.gridLabelPercentCvar)

    return cvar and cvar:GetBool() or false
end

local function shouldReduceFractionGridLabels()
    local cvar = GetConVar(RENDER_CONFIG.gridLabelReduceFractionCvar)

    return cvar == nil or cvar:GetBool()
end

local function currentGridLineAlpha(isPrimary)
    local fallback = isPrimary and GRID_CONFIG.alphaPrimary or GRID_CONFIG.alphaSecondary
    return readClampedConVarInt(RENDER_CONFIG.gridAlphaCvar, fallback, 0, 255)
end

local function formatGridLineLabel(face, axisKey)
    if shouldUsePercentGridLabels() then
        return formatPercentLabel(axisKey == "u" and face.snapPercentU or face.snapPercentV)
    end

    local grid = axisKey == "u" and face.snapGridU or face.snapGridV
    local index = axisKey == "u" and face.snapIndexU or face.snapIndexV
    local divisions = gridAxisDivisions(grid, axisKey)

    return formatFractionLabel(index, divisions, commonGridDivisions(face, axisKey), shouldReduceFractionGridLabels())
end

local reusableInsetStart = newRenderVector(0, 0, 0)
local reusableInsetEnd = newRenderVector(0, 0, 0)

local function insetLineEnds(a, b, inset, outA, outB)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length <= 1e-6 then
        return setRenderVector(outA, a.x, a.y, a.z), setRenderVector(outB, b.x, b.y, b.z)
    end

    local padding = math.min(inset, length * 0.25)
    local scale = padding / length

    return setRenderVector(outA, a.x + dx * scale, a.y + dy * scale, a.z + dz * scale),
        setRenderVector(outB, b.x - dx * scale, b.y - dy * scale, b.z - dz * scale)
end

local function faceLineLocalPoints(face, grid, axisKey, value)
    if axisKey == "u" then
        if face.axis == 1 then
            return VectorP(face.fixed, value, grid.vMin), VectorP(face.fixed, value, grid.vMax)
        elseif face.axis == 2 then
            return VectorP(value, face.fixed, grid.vMin), VectorP(value, face.fixed, grid.vMax)
        end

        return VectorP(value, grid.vMin, face.fixed), VectorP(value, grid.vMax, face.fixed)
    end

    if face.axis == 1 then
        return VectorP(face.fixed, grid.uMin, value), VectorP(face.fixed, grid.uMax, value)
    elseif face.axis == 2 then
        return VectorP(grid.uMin, face.fixed, value), VectorP(grid.uMax, face.fixed, value)
    end

    return VectorP(grid.uMin, value, face.fixed), VectorP(grid.uMax, value, face.fixed)
end

local reusableFaceLineA = newRenderVector(0, 0, 0)
local reusableFaceLineB = newRenderVector(0, 0, 0)

local function faceLineWorldPoints(ent, face, grid, axisKey, value, outA, outB)
    if face and face.worldBSP and isfunction(face.lineWorldPoints) then
        local a, b = face.lineWorldPoints(face, grid, axisKey, value, outA, outB)
        local normal = face.normal
        if isvector(a) and isvector(b) and isvector(normal) then
            local push = GRID_CONFIG.bspSurfacePush
            return setRenderVector(a, a.x + normal.x * push, a.y + normal.y * push, a.z + normal.z * push),
                setRenderVector(b, b.x + normal.x * push, b.y + normal.y * push, b.z + normal.z * push)
        end

        return a, b
    end

    local a, b = faceLineLocalPoints(face, grid, axisKey, value)
    if not a or not b then return end
    if not IsValid(ent) then return end

    return geometry.worldPosFromLocalPoint(ent, a), geometry.worldPosFromLocalPoint(ent, b)
end

local function drawSnapLineLabels2D(a, b, label, color)
    if not label then return end

    local startPos, endPos = insetLineEnds(a, b, GRID_CONFIG.snapLabelInset, reusableInsetStart, reusableInsetEnd)
    startPos = toVector(startPos)
    endPos = toVector(endPos)
    if not startPos or not endPos then return end

    local startScreen = startPos:ToScreen()
    local endScreen = endPos:ToScreen()

    if startScreen.visible then
        draw.SimpleTextOutlined(label, "DermaDefaultBold", startScreen.x, startScreen.y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    end

    if endScreen.visible then
        draw.SimpleTextOutlined(label, "DermaDefaultBold", endScreen.x, endScreen.y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    end
end

local function drawWorldBspBlockerMarker(blocker)
    if not istable(blocker) then return end

    local color = cachedColor(255, 166, 64, 215)
    local ent = blocker.ent
    if IsValid(ent)
        and render.DrawWireframeBox
        and isfunction(ent.GetPos)
        and isfunction(ent.GetAngles)
        and isfunction(ent.OBBMins)
        and isfunction(ent.OBBMaxs) then
        render.DrawWireframeBox(ent:GetPos(), ent:GetAngles(), ent:OBBMins(), ent:OBBMaxs(), color, true)
    end

    local hitPos = blocker.hitPos
    if isvector(hitPos) then
        local size = 6
        drawLine(hitPos - VectorP(size, 0, 0), hitPos + VectorP(size, 0, 0), color, true)
        drawLine(hitPos - VectorP(0, size, 0), hitPos + VectorP(0, size, 0), color, true)
        drawLine(hitPos - VectorP(0, 0, size), hitPos + VectorP(0, 0, size), color, true)
    end
end

local hoverRender = client.HoverRender or {}
client.HoverRender = hoverRender

function hoverRender.isDrawingPickPress(state)
    return isDrawingPickPress(state)
end

function hoverRender.activePickAccentColor(state)
    return activePickAccentColor(state)
end

function hoverRender.cursorLineColor(state, candidate, alpha)
    return cursorLineColor(state, candidate, alpha)
end

function hoverRender.cursorAccentColor(state, candidate, alpha)
    return cursorAccentColor(state, candidate, alpha)
end

function hoverRender.drawWorldBspBlockers(tool, state)
    if not tool or not tool.GetClientNumber or tool:GetClientNumber("world_bsp_show_blockers", 0) ~= 1 then return end

    local blockers = state and state.hover and state.hover.worldBspBlockers
    if not istable(blockers) or #blockers == 0 then return end

    render.SetColorMaterial()
    for i = 1, #blockers do
        drawWorldBspBlockerMarker(blockers[i])
    end
end

function hoverRender.drawGridLabels(state, candidate)
    if not shouldRenderGrid(state, candidate) then return end
    if candidate.face and candidate.face.worldBSP and candidate.face.globalGrid then return end

    local face = candidate.face
    local labelColor = cachedColor(255, 255, 255, GRID_CONFIG.snapLabelAlpha)

    if face.snapGridU and face.uSnap then
        local a, b = faceLineWorldPoints(candidate.ent, face, face.snapGridU, "u", face.uSnap, reusableFaceLineA, reusableFaceLineB)
        if a and b then
            drawSnapLineLabels2D(a, b, formatGridLineLabel(face, "u"), labelColor)
        end
    end

    if face.snapGridV and face.vSnap then
        local a, b = faceLineWorldPoints(candidate.ent, face, face.snapGridV, "v", face.vSnap, reusableFaceLineA, reusableFaceLineB)
        if a and b then
            drawSnapLineLabels2D(a, b, formatGridLineLabel(face, "v"), labelColor)
        end
    end
end

function hoverRender.drawFaceOutline(state, candidate)
    if not shouldRenderFace(state, candidate) then return end

    local face = candidate.face
    if face.worldBSP and istable(face.worldCorners) then
        local worldGridRender = client.worldGridRender
        local lookupRenderData = worldGridRender and worldGridRender.lookupWorldBspRenderData
        local renderData = isfunction(lookupRenderData) and lookupRenderData(face.surface) or nil
        if not renderData and worldGridRender and isfunction(worldGridRender.ensureWorldBspRenderData) then
            renderData = worldGridRender.ensureWorldBspRenderData(face.surface)
        end
        local corners = renderData and renderData.vertices or face.worldCorners
        local count = renderData and renderData.vertexCount or #corners
        if count < 2 then return end

        local color = cachedColor(255, 255, 255, 70)
        for i = 1, count do
            local a = corners[i]
            local b = corners[i % count + 1]
            if isvector(a) and isvector(b) then
                drawLine(a, b, color, false)
            end
        end
        return
    end

    local ent = candidate.ent
    local corners = face.corners

    for i = 1, 4 do
        local a = geometry.worldPosFromLocalPoint(ent, corners[i])
        local b = geometry.worldPosFromLocalPoint(ent, corners[i % 4 + 1])
        if a and b then
            drawLine(a, b, cachedColor(255, 255, 255, 70), true)
        end
    end
end

function hoverRender.drawGrid(state, candidate, options)
    if not shouldRenderGrid(state, candidate) then return end

    local face = candidate.face
    local ent = candidate.ent
    if face.worldBSP and face.globalGrid then
        local previousCursorLineColor = client.worldGridRender.cursorLineColor
        client.worldGridRender.cursorLineColor = cursorLineColor(state, candidate, GRID_CONFIG.snapLineAlpha)
        if istable(options) and options.depthTested and isfunction(client.worldGridRender.drawWorldBspGlobalGridDepthTested) then
            client.worldGridRender.drawWorldBspGlobalGridDepthTested(face)
        else
            client.worldGridRender.drawWorldBspGlobalGrid(face)
        end
        client.worldGridRender.cursorLineColor = previousCursorLineColor
        return
    end

    local snapLineColor = cursorLineColor(state, candidate, GRID_CONFIG.snapLineAlpha)

    local gridSets = hoverRender.reusableGridSets or {}
    local seen = hoverRender.reusableGridSeen or {}
    hoverRender.reusableGridSets = gridSets
    hoverRender.reusableGridSeen = seen
    for i = 1, #gridSets do
        gridSets[i] = nil
    end
    for grid in pairs(seen) do
        seen[grid] = nil
    end

    local function addGrid(grid)
        if not grid or seen[grid] then return end
        seen[grid] = true
        gridSets[#gridSets + 1] = grid
    end

    addGrid(face.gridA)
    addGrid(face.gridB)
    addGrid(face.snapGridU)
    addGrid(face.snapGridV)

    for _, grid in ipairs(gridSets) do
        local lineAlpha = lightScaledAlpha(currentGridLineAlpha(grid == face.gridA))

        for uIndex = 0, math.max(grid.divU or 0, 0) do
            local u = uIndex == (grid.divU or 0) and grid.uMax or (grid.uMin + grid.stepU * uIndex)
            local a, b = faceLineWorldPoints(ent, face, grid, "u", u, reusableFaceLineA, reusableFaceLineB)
            if a and b then
                drawLine(a, b, cachedColor(255, 255, 255, lineAlpha), false)
            end
        end

        for vIndex = 0, math.max(grid.divV or 0, 0) do
            local v = vIndex == (grid.divV or 0) and grid.vMax or (grid.vMin + grid.stepV * vIndex)
            local a, b = faceLineWorldPoints(ent, face, grid, "v", v, reusableFaceLineA, reusableFaceLineB)
            if a and b then
                drawLine(a, b, cachedColor(255, 255, 255, lineAlpha), false)
            end
        end
    end

    if face.snapGridU and face.uSnap then
        local a, b = faceLineWorldPoints(ent, face, face.snapGridU, "u", face.uSnap, reusableFaceLineA, reusableFaceLineB)
        if a and b then
            drawLine(a, b, snapLineColor, false)
        end
    end

    if face.snapGridV and face.vSnap then
        local a, b = faceLineWorldPoints(ent, face, face.snapGridV, "v", face.vSnap, reusableFaceLineA, reusableFaceLineB)
        if a and b then
            drawLine(a, b, snapLineColor, false)
        end
    end
end
