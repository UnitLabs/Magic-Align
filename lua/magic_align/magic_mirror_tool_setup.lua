MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local core = client.ToolCore or include("magic_align/tool_config.lua")
local MAGIC_MIRROR_DESCRIPTION = "Magic Mirror is an experimental companion tool included with Magic Align. It uses Magic Align's existing mirroring standard to mirror a single prop in place, ensuring consistency with Magic Align's mirrored props. Complex props may not always mirror correctly."
local DISABLE_MENU_ANIMATION_CVAR = "magic_mirror_disable_menu_animation"

TOOL.ClientConVar = TOOL.ClientConVar or {}
TOOL.ClientConVar.preserve_frozen_state = TOOL.ClientConVar.preserve_frozen_state or "0"
TOOL.ClientConVar.log_undo = TOOL.ClientConVar.log_undo or "0"
TOOL.ClientConVar.disable_menu_animation = TOOL.ClientConVar.disable_menu_animation or "0"
TOOL.Information = {
    { name = "left" }
}

local function writeClientActionTrace(trace)
    local ent = trace and trace.Entity or NULL
    local hitPos = trace and trace.HitPos or nil
    local hitNormal = trace and trace.HitNormal or nil
    local hitWorld = trace ~= nil and (trace.HitWorld == true or (IsValid(ent) and ent.IsWorld and ent:IsWorld())) or false
    local physBone = math.Clamp(math.floor(tonumber(trace and trace.PhysicsBone) or 0), 0, 65535)

    net.WriteEntity(IsValid(ent) and ent or NULL)
    net.WriteBool(trace ~= nil and trace.Hit == true or M.IsVectorLike(hitPos))
    net.WriteBool(M.IsVectorLike(hitPos))
    if M.IsVectorLike(hitPos) then
        net.WritePreciseVector(hitPos)
    end
    net.WriteBool(M.IsVectorLike(hitNormal))
    if M.IsVectorLike(hitNormal) then
        net.WritePreciseVector(hitNormal)
    end
    net.WriteBool(hitWorld)
    net.WriteUInt(physBone, 16)
end

local function sendMirrorClientAction(ply, trace)
    if CLIENT or not IsValid(ply) then return end

    net.Start(M.NET_CLIENT_ACTION)
        net.WriteUInt(M.CLIENT_ACTION_MAGIC_MIRROR_LEFTCLICK, 2)
        writeClientActionTrace(trace)
    net.Send(ply)
end

local function playFeedback(tool, kind, wouldAffect, trace, options)
    local effects = M.ToolgunEffects
    if not effects or not isfunction(effects.DispatchFeedback) then return end

    if isfunction(effects.ResolveFeedbackKind) then
        kind = effects.ResolveFeedbackKind(kind, wouldAffect)
    elseif wouldAffect == false then
        kind = "fail"
    end

    return effects.DispatchFeedback(kind, tool, trace, nil, options)
end

function TOOL:LeftClick(trace)
    if SERVER then
        if game.SinglePlayer() then
            sendMirrorClientAction(self:GetOwner(), trace)
        end

        return false
    end

    if game.SinglePlayer() then
        return false
    end

    local mirrorClient = client.MagicMirror
    if mirrorClient and isfunction(mirrorClient.queueClick) then
        mirrorClient.queueClick(self, trace)
        return false
    end

    playFeedback(self, "fail", false, trace)
    return false
end

function TOOL:RightClick(trace)
    if CLIENT and not game.SinglePlayer() then
        playFeedback(self, "fail", false, trace)
    end

    return false
end

TOOL.Reload = nil

if CLIENT then
    CreateClientConVar(
        "magic_align_toolgun_sound_volume",
        "0.25",
        true,
        false,
        "Magic Align family toolgun sound volume.",
        0,
        1
    )

    CreateClientConVar(
        DISABLE_MENU_ANIMATION_CVAR,
        TOOL.ClientConVar.disable_menu_animation,
        true,
        false,
        "Disable the Magic Mirror context menu entry animation.",
        0,
        1
    )

    language.Add("tool.magic_mirror.name", "Magic Mirror")
    language.Add("tool.magic_mirror.desc", "Mirror props in place.")
    language.Add("tool.magic_mirror.left", "Mirror hovered prop")

    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", {
            Text = "#tool.magic_mirror.name",
            Description = MAGIC_MIRROR_DESCRIPTION
        })
        panel:AddControl("CheckBox", {
            Label = "Preserve Frozen State",
            Command = "magic_mirror_preserve_frozen_state"
        })
        panel:AddControl("CheckBox", {
            Label = "Log Mirror Actions in Undo",
            Command = "magic_mirror_log_undo"
        })

        local misc = vgui.Create("DForm", panel)
        misc:SetName("Misc")
        misc:CheckBox("Disable Menu Animation", DISABLE_MENU_ANIMATION_CVAR)
        panel:AddItem(misc)
    end
end

core.sendMirrorClientAction = sendMirrorClientAction

return core
