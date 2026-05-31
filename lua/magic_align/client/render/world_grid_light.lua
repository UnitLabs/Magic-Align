MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local isvector = M.IsVectorLike
local client = M.Client or {}
M.Client = client

client.worldGridRender = client.worldGridRender or {}

local LIGHT_ADAPT_CVAR = "magic_align_world_bsp_light_adapt"

local CONFIG = {
    sampleInterval = 0.25,
    sampleNormalPush = 2.0,
    smoothHalfLife = 0.28,
    minBlend = 0.05,
    maxBlend = 1.00,
    minLuma = 0.00,
    maxLuma = 1.25,
    perceptualGamma = 0.45,
    lumaScale = 2.0
}

local function now()
    if isfunction(RealTime) then
        return RealTime()
    end
    if isfunction(CurTime) then
        return CurTime()
    end

    return 0
end

local function enabled()
    local cvar = GetConVar(LIGHT_ADAPT_CVAR)

    return cvar == nil or cvar:GetBool()
end

local function probeState()
    local state = client.worldGridRender.lightProbeState
    if not istable(state) then
        state = {
            currentBlend = CONFIG.maxBlend,
            targetBlend = CONFIG.maxBlend,
            currentLuma = CONFIG.maxLuma,
            targetLuma = CONFIG.maxLuma,
            lastLuma = nil,
            lastLightColor = nil,
            lastSamplePos = nil,
            lastSampleNormal = nil,
            lastSampleOk = false,
            lastSampleAt = -math.huge,
            lastUpdateAt = nil
        }
        client.worldGridRender.lightProbeState = state
    end

    return state
end

local function luma(lightColor)
    if not isvector(lightColor) then return end

    local r = tonumber(lightColor.x) or 0
    local g = tonumber(lightColor.y) or 0
    local b = tonumber(lightColor.z) or 0
    local value = r * 0.2126 + g * 0.7152 + b * 0.0722
    if value ~= value or value == math.huge or value == -math.huge then return end

    return math.max(value, 0)
end

local function blendFromLuma(value)
    value = tonumber(value)
    if not value then
        return CONFIG.maxBlend
    end

    local span = math.max(CONFIG.maxLuma - CONFIG.minLuma, 1e-6)
    local t = math.Clamp((value - CONFIG.minLuma) / span, 0, 1)
    t = t ^ CONFIG.perceptualGamma
    return CONFIG.minBlend + (CONFIG.maxBlend - CONFIG.minBlend) * t
end

local function samplePosition(state, candidate)
    local hover = state and state.hover
    local trace = hover and hover.trace
    local pos = trace and trace.Hit and isvector(trace.HitPos) and trace.HitPos
        or candidate and isvector(candidate.worldPos) and candidate.worldPos
        or nil
    if not pos then return end

    local normal = trace and isvector(trace.HitNormal) and trace.HitNormal
        or candidate and isvector(candidate.normal) and candidate.normal
        or nil
    if normal and normal:LengthSqr() > 1e-8 then
        return pos + normal:GetNormalized() * CONFIG.sampleNormalPush, normal
    end

    return pos
end

function client.worldGridRender.updateLightBlend(state, candidate)
    local probe = probeState()
    local currentTime = now()

    if enabled() then
        local lastSampleAt = tonumber(probe.lastSampleAt) or -math.huge
        if currentTime - lastSampleAt >= CONFIG.sampleInterval then
            probe.lastSampleAt = currentTime
            local pos, normal = samplePosition(state, candidate)
            local targetBlend = CONFIG.maxBlend
            local targetLuma = CONFIG.maxLuma
            probe.lastSamplePos = pos
            probe.lastSampleNormal = normal
            probe.lastSampleOk = false
            if pos and isfunction(render.GetLightColor) then
                local ok, lightColor = pcall(render.GetLightColor, pos)
                local measuredLuma = ok and luma(lightColor) or nil
                if measuredLuma then
                    measuredLuma = measuredLuma * CONFIG.lumaScale
                    probe.lastLuma = measuredLuma
                    probe.lastLightColor = lightColor
                    probe.lastSampleOk = true
                    targetLuma = measuredLuma
                    targetBlend = blendFromLuma(measuredLuma)
                end
            end
            probe.targetLuma = targetLuma
            probe.targetBlend = math.Clamp(targetBlend, CONFIG.minBlend, CONFIG.maxBlend)
        end
    else
        probe.targetLuma = CONFIG.maxLuma
        probe.targetBlend = CONFIG.maxBlend
        probe.lastSampleOk = false
        probe.lastSampleAt = currentTime
    end

    local currentLuma = tonumber(probe.currentLuma) or CONFIG.maxLuma
    local targetLuma = tonumber(probe.targetLuma) or CONFIG.maxLuma
    local currentBlend = tonumber(probe.currentBlend) or CONFIG.maxBlend
    local targetBlend = tonumber(probe.targetBlend) or CONFIG.maxBlend
    local lastUpdateAt = tonumber(probe.lastUpdateAt) or currentTime
    probe.lastUpdateAt = currentTime

    local dt = math.Clamp(currentTime - lastUpdateAt, 0, 1)
    if dt > 0 then
        local halfLife = math.max(tonumber(CONFIG.smoothHalfLife) or 0.28, 1e-4)
        local t = 1 - (0.5 ^ (dt / halfLife))
        currentLuma = currentLuma + (targetLuma - currentLuma) * math.Clamp(t, 0, 1)
        currentBlend = currentBlend + (targetBlend - currentBlend) * math.Clamp(t, 0, 1)
    end

    probe.currentLuma = math.max(currentLuma, 0)
    probe.currentBlend = math.Clamp(currentBlend, CONFIG.minBlend, CONFIG.maxBlend)
    return probe.currentBlend
end

function client.worldGridRender.updateLightProbe(state)
    local hover = state and state.hover
    local candidate = hover and (hover.candidate or hover.overlay) or nil

    return client.worldGridRender.updateLightBlend(state, candidate)
end

function client.worldGridRender.currentLightBlend()
    local probe = client.worldGridRender.lightProbeState

    return math.Clamp(tonumber(probe and probe.currentBlend) or CONFIG.maxBlend, CONFIG.minBlend, CONFIG.maxBlend)
end

function client.worldGridRender.lightDebugInfo()
    local probe = probeState()

    return {
        enabled = enabled(),
        ok = probe.lastSampleOk == true,
        sampleAge = now() - (tonumber(probe.lastSampleAt) or 0),
        luma = probe.lastLuma,
        currentLuma = probe.currentLuma,
        targetLuma = probe.targetLuma,
        color = probe.lastLightColor,
        targetBlend = probe.targetBlend,
        currentBlend = probe.currentBlend,
        samplePos = probe.lastSamplePos,
        sampleNormal = probe.lastSampleNormal,
        config = CONFIG
    }
end
