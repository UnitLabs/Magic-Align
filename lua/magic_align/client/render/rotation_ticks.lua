MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local rotationRender = client.RotationRender or {}
client.RotationRender = rotationRender

function rotationRender.normalizeDegrees(angle)
    angle = tonumber(angle) or 0
    angle = angle % 360
    if angle < 0 then
        angle = angle + 360
    end

    return angle
end

function rotationRender.snapDisplayAngle(angle, step)
    step = tonumber(step) or 0
    if step <= 1e-8 then
        return rotationRender.normalizeDegrees(angle)
    end

    return rotationRender.normalizeDegrees(math.Round(rotationRender.normalizeDegrees(angle) / step) * step)
end

function rotationRender.isAngleMultiple(angle, interval)
    local remainder = rotationRender.normalizeDegrees(angle) % interval
    return remainder <= 1e-4 or math.abs(remainder - interval) <= 1e-4
end

function rotationRender.isMajorTick(angle)
    if client.isMajorRotationTick(angle) then
        return true
    end

    return rotationRender.isAngleMultiple(angle, 30) or rotationRender.isAngleMultiple(angle, 45)
end

function rotationRender.isFortyFiveTick(angle)
    return rotationRender.isAngleMultiple(angle, 45)
end

local function tickDistanceLess(a, b)
    if math.abs(a.dist - b.dist) <= 1e-4 then
        return a.angle < b.angle
    end

    return a.dist < b.dist
end

local function tickAngleLess(a, b)
    return a.angle < b.angle
end

function rotationRender.visibleTicks(divisions, step, cursorAngle, tickLimit)
    local cachedRotationTicks = rotationRender.rotationTicks
    if not cachedRotationTicks then
        cachedRotationTicks = {}
        rotationRender.rotationTicks = cachedRotationTicks
    end

    tickLimit = math.Clamp(math.Round(tonumber(tickLimit) or client.rotationSnapMaxVisibleTicks or 20), 1, math.max(divisions, 1))
    if cachedRotationTicks.ticks
        and cachedRotationTicks.divisions == divisions
        and math.abs((cachedRotationTicks.step or 0) - step) <= 1e-8
        and math.abs((cachedRotationTicks.cursorAngle or 0) - cursorAngle) <= 1e-8
        and cachedRotationTicks.tickLimit == tickLimit then
        return cachedRotationTicks.ticks
    end

    local ticks = cachedRotationTicks.allTicks or {}
    cachedRotationTicks.allTicks = ticks
    local tickCount = 0
    for index = 0, math.max(divisions - 1, 0) do
        tickCount = tickCount + 1
        local angle = index * step
        local tick = ticks[tickCount]
        if not tick then
            tick = {}
            ticks[tickCount] = tick
        end

        tick.angle = angle
        tick.dist = math.abs(math.AngleDifference(angle, cursorAngle))
        tick.major = rotationRender.isMajorTick(angle)
    end
    for i = tickCount + 1, #ticks do
        ticks[i] = nil
    end

    table.sort(ticks, tickDistanceLess)

    local selected = cachedRotationTicks.selectedTicks or {}
    cachedRotationTicks.selectedTicks = selected
    local selectedCount = math.min(tickLimit, #ticks)
    for i = 1, selectedCount do
        selected[i] = ticks[i]
    end
    for i = selectedCount + 1, #selected do
        selected[i] = nil
    end

    table.sort(selected, tickAngleLess)

    cachedRotationTicks.cursorAngle = cursorAngle
    cachedRotationTicks.divisions = divisions
    cachedRotationTicks.step = step
    cachedRotationTicks.tickLimit = tickLimit
    cachedRotationTicks.ticks = selected

    return selected
end
