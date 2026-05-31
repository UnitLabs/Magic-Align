MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local toolgunEffects = M.ToolgunEffects or {}
M.ToolgunEffects = toolgunEffects

local HIT_EFFECT = "magic_align_toolgun_hit_rings"
local MUZZLE_EFFECT = "magic_align_toolgun_muzzle_ring"
local CLICK_SOUND = "buttons/lightswitch2.wav"
local COMMIT_SOUND = "buttons/button14.wav"
local RESET_SOUND = "ui/buttonclickrelease.wav"
local FAIL_SOUND = "ui/buttonrollover.wav"
local SOUND_VOLUME_CVAR = "magic_align_toolgun_sound_volume"
local MARK_LIFETIME = 0.5
local PATCH_VERSION = 1
local COLOR_DEFAULT = 0
local COLOR_FAIL = 1

local CONFIG = {
    life = 0.22,
    commitLife = 0.34,
    startSize = 8,
    maxSize = 10,
    stackStep = 3,
    maxAlpha = 235,
    soundLevel = 75,
    soundPitch = 200,
    soundVolume = 0.25,
    soundVolumeStep = 0.05,
    muzzleSizeScale = 0.4,
    muzzleTravelDistance = 4,
    muzzleAirFriction = 4,
    failMuzzleFadeSpeed = 4 / 3,
    muzzleMaxShootDist = 256
}

local PRESETS = {
    click = { sound = CLICK_SOUND, hit = true },
    commit = { sound = COMMIT_SOUND, hit = false, special = true, color = "commit" },
    reset = { sound = RESET_SOUND, hit = false, special = true, failColor = true },
    fail = { sound = FAIL_SOUND, hit = false, failColor = true, weaponAnim = false }
}

local ALIASES = {
    normal = "click",
    action = "click",
    leftClick = "click",
    rightClick = "click",
    reload = "reset",
    noEffect = "fail"
}

local pendingActions = toolgunEffects.pendingActions or setmetatable({}, { __mode = "k" })
toolgunEffects.pendingActions = pendingActions
local activeFeedback = toolgunEffects.activeFeedback or setmetatable({}, { __mode = "k" })
toolgunEffects.activeFeedback = activeFeedback
toolgunEffects.muzzleCache = toolgunEffects.muzzleCache or {}

local function now()
    return isfunction(RealTime) and RealTime() or CurTime()
end

local function finiteVector(value)
    if M.IsFiniteVector then return M.IsFiniteVector(value) end
    return isvector(value)
end

local function effectVector(value)
    if not finiteVector(value) then return end
    if M.ToVector then
        local converted = M.ToVector(value)
        if isvector(converted) then return converted end
    end

    return Vector(value.x, value.y, value.z)
end

local function safeNormal(value)
    local normal = effectVector(value)
    if not normal or normal:LengthSqr() <= 0.000001 then
        return Vector(0, 0, 1)
    end

    normal:Normalize()
    return normal
end

local function copyColor(color, alpha)
    color = color or color_white
    alpha = math.Clamp(math.floor(tonumber(alpha) or color.a or 255), 0, 255)
    return Color(color.r or 255, color.g or 255, color.b or 255, alpha)
end

local function contextColor(alpha)
    local palette = client.colors or {}
    if CLIENT then
        local state = M.ClientState
        local hover = state and state.hover
        local candidate = hover and (hover.candidate or hover.overlay)
        local hoverRender = client.HoverRender

        if hoverRender and isfunction(hoverRender.cursorLineColor) then
            local color = hoverRender.cursorLineColor(state, candidate, alpha or 255)
            if color then return copyColor(color, alpha or color.a or 255) end
        end
    end

    return copyColor(palette.target or Color(80, 220, 255), alpha or 255)
end

local function activeToolWeapon(owner)
    if not IsValid(owner) or not isfunction(owner.GetActiveWeapon) then return end
    local weapon = owner:GetActiveWeapon()
    if IsValid(weapon) and weapon:GetClass() == "gmod_tool" then return weapon end
end

local function toolOwner(tool)
    if tool and isfunction(tool.GetOwner) then
        local owner = tool:GetOwner()
        if IsValid(owner) then return owner end
    end

    if CLIENT and isfunction(LocalPlayer) then
        local ply = LocalPlayer()
        if IsValid(ply) then return ply end
    end
end

local function weaponFor(tool, fallbackWeapon)
    if IsValid(fallbackWeapon) and fallbackWeapon:GetClass() == "gmod_tool" then return fallbackWeapon end
    if IsValid(tool) and tool:GetClass() == "gmod_tool" then return tool end
    if not tool or tool.Mode ~= "magic_align" then return end

    if isfunction(tool.GetWeapon) then
        local weapon = tool:GetWeapon()
        if IsValid(weapon) then return weapon end
    end

    return activeToolWeapon(toolOwner(tool))
end

local function activeMagicAlignToolForWeapon(weapon)
    if not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" or not isfunction(weapon.GetOwner) then return end

    local owner = weapon:GetOwner()
    if not IsValid(owner) or not M.GetActiveMagicAlignTool then return end

    local tool, activeWeapon = M.GetActiveMagicAlignTool(owner)
    return activeWeapon == weapon and tool or nil
end

local function effectKind(kind)
    kind = ALIASES[kind] or kind
    return PRESETS[kind] and kind or "click"
end

function toolgunEffects.ResolveFeedbackKind(action, wouldAffect)
    if wouldAffect == false then return "fail" end
    if action == "mirrorCommit" then return "mirrorCommit" end
    return effectKind(action)
end

local function markerColor(preset, mirror)
    if preset.failColor then return Color(255, 55, 55) end

    local palette = client.colors or {}
    if mirror then return copyColor(palette.mirror or Color(176, 112, 235)) end
    if preset.color == "commit" then return copyColor(palette.target or Color(80, 220, 255)) end

    return CLIENT and contextColor(255) or nil
end

local function markerFor(kind)
    local mirror = kind == "mirrorCommit"
    kind = mirror and "commit" or effectKind(kind)

    local preset = PRESETS[kind]
    return {
        expires = now() + MARK_LIFETIME,
        kind = kind,
        sound = preset.sound,
        hit = preset.hit ~= false,
        muzzleSpecial = preset.special == true,
        weaponAnim = preset.weaponAnim ~= false,
        color = markerColor(preset, mirror),
        colorCode = preset.failColor and COLOR_FAIL or COLOR_DEFAULT
    }
end

local function markActiveFeedback(weapon, marker)
    if not CLIENT or not IsValid(weapon) or not marker then return end

    local startTime = now()
    activeFeedback[weapon] = {
        starts = startTime,
        expires = startTime + MARK_LIFETIME,
        kind = marker.kind,
        color = copyColor(marker.color or contextColor(255), 255)
    }
end

function toolgunEffects.ActiveFeedback(weapon)
    if not CLIENT or not IsValid(weapon) then return end

    local feedback = activeFeedback[weapon]
    if not feedback then return end

    local time = now()
    if (tonumber(feedback.expires) or 0) <= time then
        activeFeedback[weapon] = nil
        return
    end

    return feedback, time
end

local function consumeAction(weapon)
    local marker = pendingActions[weapon]
    pendingActions[weapon] = nil
    if not marker or (tonumber(marker.expires) and marker.expires < now()) then return end
    return marker
end

local function drawEffectsEnabled()
    return not GetConVarNumber or GetConVarNumber("gmod_drawtooleffects") ~= 0
end

local function effectDataColor(data, alpha)
    if data and isfunction(data.GetColor) and data:GetColor() == COLOR_FAIL then
        return Color(255, 55, 55, alpha or CONFIG.maxAlpha)
    end

    return copyColor(toolgunEffects.pendingEffectColor or contextColor(alpha), alpha or CONFIG.maxAlpha)
end

local function withEffectColor(color, callback)
    if CLIENT then toolgunEffects.pendingEffectColor = color or contextColor(255) end
    callback()
    if CLIENT then toolgunEffects.pendingEffectColor = nil end
end

local function emitFeedbackSound(weapon, soundPath)
    local volume = CONFIG.soundVolume
    local cvar = GetConVar and GetConVar(SOUND_VOLUME_CVAR) or nil
    if cvar and isfunction(cvar.GetFloat) then
        volume = cvar:GetFloat()
    end

    volume = math.Clamp(tonumber(volume) or CONFIG.soundVolume, 0, 1)
    volume = math.Round(volume / CONFIG.soundVolumeStep) * CONFIG.soundVolumeStep
    volume = math.Round(volume, 2)

    weapon:EmitSound(soundPath or CLICK_SOUND, CONFIG.soundLevel, CONFIG.soundPitch, volume)
end

local function playHitRings(hitPos, hitNormal, entity, physBone, marker)
    hitPos = effectVector(hitPos)
    if not hitPos then return end

    local data = EffectData()
    data:SetOrigin(hitPos+safeNormal(hitNormal))
    data:SetNormal(safeNormal(hitNormal))
    data:SetEntity(IsValid(entity) and entity or NULL)
    data:SetAttachment(math.max(math.floor(tonumber(physBone) or 0), 0))
    data:SetColor(marker.colorCode or COLOR_DEFAULT)

    withEffectColor(marker.color, function()
        util.Effect(HIT_EFFECT, data, true, true)
    end)
end

local function attachmentPosition(ent, attachment)
    if not IsValid(ent) or not isfunction(ent.GetAttachment) then return end
    local att = ent:GetAttachment(attachment or 1)
    return att and effectVector(att.Pos)
end

local function nearShootPos(pos, owner)
    if not finiteVector(pos) then return false end
    if not IsValid(owner) or not isfunction(owner.GetShootPos) then return true end

    local shootPos = effectVector(owner:GetShootPos())
    if not shootPos then return true end

    local maxDist = CONFIG.muzzleMaxShootDist
    return pos:DistToSqr(shootPos) <= maxDist * maxDist
end

local function cachedMuzzlePosition(weapon, owner)
    if not CLIENT then return end

    local cache = toolgunEffects.muzzleCache
    if cache.weapon ~= weapon or now() - (tonumber(cache.updatedAt) or 0) > 0.25 then return end

    local pos = effectVector(cache.pos)
    return nearShootPos(pos, owner) and pos or nil
end

local function liveMuzzlePosition(weapon, owner)
    if not CLIENT then return end

    if IsValid(owner) and isfunction(owner.ShouldDrawLocalPlayer) and not owner:ShouldDrawLocalPlayer() and isfunction(owner.GetViewModel) then
        local pos = attachmentPosition(owner:GetViewModel(), 1)
        if nearShootPos(pos, owner) then return pos end
    end

    local pos = attachmentPosition(weapon, 1)
    if nearShootPos(pos, owner) then return pos end
end

local function muzzlePosition(weapon, owner)
    return cachedMuzzlePosition(weapon, owner)
        or liveMuzzlePosition(weapon, owner)
        or (IsValid(owner) and isfunction(owner.GetShootPos) and effectVector(owner:GetShootPos()))
        or effectVector(weapon:GetPos())
end

local function playMuzzleRing(weapon, marker)
    local owner = weapon:GetOwner()
    local pos = muzzlePosition(weapon, owner)
    if not pos then return end

    local data = EffectData()
    data:SetOrigin(pos)
    data:SetStart(pos)
    data:SetNormal(IsValid(owner) and safeNormal(owner:GetAimVector()) * -1 or Vector(-1, 0, 0))
    data:SetEntity(weapon)
    data:SetAttachment(0)
    data:SetScale(marker.muzzleSpecial and 2 or 1)
    data:SetColor(marker.colorCode or COLOR_DEFAULT)

    withEffectColor(marker.color, function()
        util.Effect(MUZZLE_EFFECT, data, true, true)
    end)
end

local function playFeedbackForWeapon(weapon, marker, hitPos, hitNormal, entity, physBone, firstTimePredicted)
    if not IsValid(weapon) then return false end

    local owner = weapon:GetOwner()
    local predicted = firstTimePredicted ~= false
    if CLIENT and predicted then emitFeedbackSound(weapon, marker.sound) end
    markActiveFeedback(weapon, marker)

    if marker.weaponAnim ~= false then
        weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
        if IsValid(owner) then owner:SetAnimation(PLAYER_ATTACK1) end
    end

    if not predicted or not drawEffectsEnabled() or not CLIENT then return true end
    if marker.hit ~= false then playHitRings(hitPos, hitNormal, entity, physBone, marker) end
    playMuzzleRing(weapon, marker)
    return true
end

local function markFeedback(kind, weapon)
    if not IsValid(weapon) then return false end
    pendingActions[weapon] = markerFor(kind)
    return true
end

local function traceParts(trace)
    return trace and trace.HitPos,
        trace and trace.HitNormal,
        trace and trace.Entity,
        trace and trace.PhysicsBone or 0
end

function toolgunEffects.DispatchFeedback(kind, tool, trace, weaponOverride, options)
    local weapon = weaponFor(tool, weaponOverride)
    if not IsValid(weapon) then return false end

    if not CLIENT or (options and options.direct == false) then
        return markFeedback(kind, weapon)
    end

    local hitPos, hitNormal, entity, physBone = traceParts(trace)
    return playFeedbackForWeapon(weapon, markerFor(kind), hitPos, hitNormal, entity, physBone, true)
end

function toolgunEffects.MarkFeedback(kind, tool, weaponOverride)
    return toolgunEffects.DispatchFeedback(kind, tool, nil, weaponOverride, { direct = false })
end

function toolgunEffects.PlayFeedback(kind, tool, trace, weaponOverride)
    return toolgunEffects.DispatchFeedback(kind, tool, trace, weaponOverride)
end

function toolgunEffects.DoShootEffect(weapon, hitPos, hitNormal, entity, physBone, firstTimePredicted, marker)
    return playFeedbackForWeapon(weapon, marker or markerFor("click"), hitPos, hitNormal, entity, physBone, firstTimePredicted)
end

function toolgunEffects.PlayCommitAction(tool, mirror)
    return toolgunEffects.PlayFeedback(mirror and "mirrorCommit" or "commit", tool)
end

function toolgunEffects.PlayCommit(tool, mirror)
    return toolgunEffects.PlayCommitAction(tool, mirror)
end

function toolgunEffects.PlayNoEffect(tool)
    return toolgunEffects.PlayFeedback("fail", tool)
end

local function patchedDoShootEffect(self, hitPos, hitNormal, entity, physBone, firstTimePredicted)
    local marker = consumeAction(self)
    if marker then
        return toolgunEffects.DoShootEffect(self, hitPos, hitNormal, entity, physBone, firstTimePredicted, marker)
    end

    if activeMagicAlignToolForWeapon(self) then
        if SERVER and game.SinglePlayer() then return true end
        return toolgunEffects.DoShootEffect(self, hitPos, hitNormal, entity, physBone, firstTimePredicted, markerFor("click"))
    end

    local original = self._magicAlignToolgunEffectsOriginalDoShootEffect or toolgunEffects.originalDoShootEffect
    if isfunction(original) then return original(self, hitPos, hitNormal, entity, physBone, firstTimePredicted) end
end

function toolgunEffects.Install()
    if not weapons or not isfunction(weapons.GetStored) then return false end

    local toolgun = weapons.GetStored("gmod_tool")
    if not istable(toolgun) then return false end

    local original = toolgun._magicAlignToolgunEffectsOriginalDoShootEffect or toolgunEffects.originalDoShootEffect or toolgun.DoShootEffect
    if original == patchedDoShootEffect then return false end

    toolgunEffects.originalDoShootEffect = original
    toolgun._magicAlignToolgunEffectsOriginalDoShootEffect = original
    toolgun.DoShootEffect = patchedDoShootEffect
    toolgun._magicAlignToolgunEffectsInstalled = PATCH_VERSION

    if ents and isfunction(ents.FindByClass) then
        for _, weapon in ipairs(ents.FindByClass("gmod_tool")) do
            if IsValid(weapon) then
                weapon._magicAlignToolgunEffectsOriginalDoShootEffect = original
                weapon.DoShootEffect = patchedDoShootEffect
                weapon._magicAlignToolgunEffectsInstalled = PATCH_VERSION
            end
        end
    end

    return true
end

if CLIENT then
    local ringMaterial = Material("effects/select_ring")

    local function progress(startTime)
        return math.Clamp((CurTime() - startTime) / CONFIG.life, 0, 1)
    end

    local function ringSize(t)
        return Lerp(math.Clamp(t, 0, 1), CONFIG.startSize, CONFIG.maxSize)
    end

    local function airFrictionTravel(t)
        t = math.Clamp(tonumber(t) or 0, 0, 1)

        local friction = math.max(tonumber(CONFIG.muzzleAirFriction) or 0, 0)
        if friction <= 0.0001 then
            return t
        end

        return (1 - math.exp(-friction * t)) / (1 - math.exp(-friction))
    end

    local function ringAlpha(t)
        return math.Clamp(math.floor(CONFIG.maxAlpha * (1 - t) + 0.5), 0, 255)
    end

    local function drawRing(pos, normal, size, color)
        if size <= 0 or color.a <= 0 then return end
        render.SetMaterial(ringMaterial)
        render.DrawQuadEasy(pos, normal, size, size, color)
    end

    hook.Remove("EntityEmitSound", "MagicAlignToolgunSoundMuzzleFeedback")
    hook.Remove("PostDrawTranslucentRenderables", "MagicAlignToolgunLocalMuzzleRings")
    hook.Remove("PostDrawViewModel", "MagicAlignToolgunMuzzleCache")
    hook.Add("PostDrawViewModel", "MagicAlignToolgunMuzzleCache", function(viewModel, ply, weapon)
        if not IsValid(viewModel) or not IsValid(ply) or not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" then return end
        if not M.GetActiveMagicAlignTool then return end

        local _, activeWeapon = M.GetActiveMagicAlignTool(ply)
        if activeWeapon ~= weapon then return end

        local pos = attachmentPosition(viewModel, 1)
        if not nearShootPos(pos, ply) then return end

        local cache = toolgunEffects.muzzleCache
        cache.weapon = weapon
        cache.pos = pos
        cache.updatedAt = now()
    end)

    local hitRings = {}

    function hitRings:Init(data)
        self.BasePos = data:GetOrigin()
        self.Normal = safeNormal(data:GetNormal())
        self.Color = effectDataColor(data, CONFIG.maxAlpha)
        self.StartTime = CurTime()
        self.DieTime = self.StartTime + CONFIG.life

        local radius = CONFIG.maxSize + CONFIG.stackStep * 2
        self:SetRenderBoundsWS(self.BasePos - Vector(radius, radius, radius), self.BasePos + Vector(radius, radius, radius))
    end

    function hitRings:Think()
        return CurTime() < self.DieTime
    end

    function hitRings:Render()
        local t = progress(self.StartTime)
        local size = ringSize(t)
        local color = copyColor(self.Color, ringAlpha(t))

        drawRing(self.BasePos, self.Normal, size, color)
        drawRing(self.BasePos + self.Normal * (CONFIG.stackStep * t), self.Normal, size, color)
        drawRing(self.BasePos + self.Normal * (CONFIG.stackStep * 2 * t), self.Normal, size, color)
    end

    effects.Register(hitRings, HIT_EFFECT)

    local muzzleRing = {}

    function muzzleRing:Init(data)
        self.Special = (tonumber(data:GetScale()) or 1) > 1
        self.Fail = isfunction(data.GetColor) and data:GetColor() == COLOR_FAIL
        self.BasePos = data:GetOrigin() - safeNormal(data:GetNormal()) * 2
        self.Normal = safeNormal(data:GetNormal())
        self.Direction = self.Normal * -1
        self.Color = effectDataColor(data, CONFIG.maxAlpha)
        self.StartTime = CurTime()
        self.FadeSpeed = self.Fail and CONFIG.failMuzzleFadeSpeed or 1
        self.Life = (self.Special and CONFIG.commitLife or CONFIG.life) / self.FadeSpeed
        self.DieTime = self.StartTime + self.Life

        local radius = CONFIG.maxSize * CONFIG.muzzleSizeScale + CONFIG.muzzleTravelDistance + 1.6
        self:SetRenderBoundsWS(self.BasePos - Vector(radius, radius, radius), self.BasePos + Vector(radius, radius, radius))
    end

    function muzzleRing:Think()
        return CurTime() < self.DieTime
    end

    function muzzleRing:Render()
        local elapsed = CurTime() - self.StartTime
        local delays = self.Special and { 0, 0.055, 0.11 } or { 0 }

        for i = 1, #delays do
            local t = math.Clamp((elapsed - delays[i] / self.FadeSpeed) / (CONFIG.life / self.FadeSpeed), 0, 1)
            if t > 0 and t < 1 then
                drawRing(
                    self.BasePos
                        + self.Direction * ((self.Fail and 0 or CONFIG.muzzleTravelDistance) * airFrictionTravel(t))
                        + self.Normal * ((i - 1) * 0.8),
                    self.Normal,
                    ringSize(t) * CONFIG.muzzleSizeScale,
                    copyColor(self.Color, ringAlpha(t) * (1 - (i - 1) * 0.16))
                )
            end
        end
    end

    effects.Register(muzzleRing, MUZZLE_EFFECT)
end

if not toolgunEffects.Install() and hook then
    hook.Add("Initialize", "MagicAlignToolgunEffectsInstall", function()
        if toolgunEffects.Install() then hook.Remove("Initialize", "MagicAlignToolgunEffectsInstall") end
    end)
end

return toolgunEffects
