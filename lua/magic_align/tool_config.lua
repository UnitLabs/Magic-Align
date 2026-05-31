MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local geometry = client.geometry or {}
client.geometry = geometry
local core = client.ToolCore or {}
client.ToolCore = core
local compatGhosts = {}

geometry.isWorldTarget = geometry.isWorldTarget or function()
    return false
end

geometry.hasTargetEntity = geometry.hasTargetEntity or function(ent)
    return geometry.isWorldTarget(ent) or IsValid(ent)
end

geometry.traceHitsWorld = geometry.traceHitsWorld or function()
    return false
end

geometry.traceMatchesEntity = geometry.traceMatchesEntity or function()
    return false
end

geometry.worldPosFromLocalPoint = geometry.worldPosFromLocalPoint or function()
    return nil
end

geometry.localPointFromWorldPos = geometry.localPointFromWorldPos or function()
    return nil
end

geometry.localNormalFromWorld = geometry.localNormalFromWorld or function()
    return nil
end

geometry.worldNormalFromLocal = geometry.worldNormalFromLocal or function()
    return nil
end

geometry.pointFromCandidate = geometry.pointFromCandidate or function()
    return nil
end

geometry.traceCandidate = geometry.traceCandidate or function()
    return nil
end

function compatGhosts.clear(state, ent)
    if M.Compat and isfunction(M.Compat.ClearGhost) then
        M.Compat.ClearGhost(state, ent)
    end
end

function compatGhosts.clearAll(state)
    if M.Compat and isfunction(M.Compat.ClearGhosts) then
        M.Compat.ClearGhosts(state)
    end
end

function compatGhosts.set(state, ent, pos, ang, alphaFn, linked)
    if M.Compat and isfunction(M.Compat.SetGhost) then
        return M.Compat.SetGhost(state, ent, pos, ang, alphaFn, linked)
    end

    return false
end

-- Die Tabs spiegeln die Referenzen aus dem Shared-Code wider.
-- Jeder Tab arbeitet mit seinem eigenen Referenzraum und zeigt denselben
-- Raum anschliessend als Gizmo im Weltspace an.
local TOOL_UI = {
    spaceLabels = {
        prop1 = "Prop 1",
        prop2 = "Prop 2",
        points = "Axis",
        world = "World",
        mirror = "Mirror"
    },
    defaultDescription = "Easily align props.",
    statusDescriptions = {
        source_prop = "Pick the source prop by placing a point on it.",
        source_points = "Place points on Prop 1.",
        target_prop = "Add Points, Link Props",
        target_points = "Place target points.",
        mirror_points = "Place Mirror points.",
        ready = "Refine positioning, then commit it."
    },
    information = {
        idle = {
            { name = "left" },
            { name = "right" },
            { name = "reload", icon = "magic_align/keys/R.png" },
            { name = "tab", icon = "magic_align/keys/TAB.png", },
            { name = "alt_pick", icon = "magic_align/keys/ALT.png" },
            { name = "supress_snap", icon = "magic_align/keys/SHFT.png", icon2 = "magic_align/keys/EMP.png" }
        },
        ready = {
            { name = "left" },
            { name = "right" },
            { name = "reload", icon = "magic_align/keys/R.png" },
            { name = "use", icon = "magic_align/keys/E.png" },
            { name = "tab", icon = "magic_align/keys/TAB.png" },
            { name = "alt_pick", icon = "magic_align/keys/ALT.png" },
            { name = "supress_snap", icon = "magic_align/keys/SHFT.png", icon2 = "magic_align/keys/EMP.png" }
        }
    }
}
TOOL_UI.information.worldPoint = { name = "point_gizmo", icon = "magic_align/keys/ALT.png" }
TOOL_UI.information.idleWorldPoint = {
    TOOL_UI.information.idle[1],
    TOOL_UI.information.idle[2],
    TOOL_UI.information.idle[3],
    TOOL_UI.information.idle[4],
    TOOL_UI.information.worldPoint,
    TOOL_UI.information.idle[6]
}
TOOL_UI.information.readyWorldPoint = {
    TOOL_UI.information.ready[1],
    TOOL_UI.information.ready[2],
    TOOL_UI.information.ready[3],
    TOOL_UI.information.ready[4],
    TOOL_UI.information.ready[5],
    TOOL_UI.information.worldPoint,
    TOOL_UI.information.ready[7]
}
TOOL_UI.information.idleMirror = {
    TOOL_UI.information.idle[1],
    TOOL_UI.information.idle[2],
    TOOL_UI.information.idle[3],
    TOOL_UI.information.idle[4],
    TOOL_UI.information.worldPoint,
    TOOL_UI.information.idle[6]
}
TOOL_UI.information.readyMirror = {
    TOOL_UI.information.ready[1],
    TOOL_UI.information.ready[2],
    TOOL_UI.information.ready[3],
    TOOL_UI.information.ready[4],
    TOOL_UI.information.ready[5],
    TOOL_UI.information.worldPoint,
    TOOL_UI.information.ready[7]
}

local RENDER_QUALITY = {
    presets = {
        { label = "Low", ringRtSize = 512, circleRtSize = 64, ringSegments = 64, circleSegments = 64, tickCount = 9, hidePointTriangles = true },
        { label = "Medium", ringRtSize = 1024, circleRtSize = 128, ringSegments = 128, circleSegments = 128, tickCount = 17 },
        { label = "High", ringRtSize = 2048, circleRtSize = 512, ringSegments = 256, circleSegments = 256, tickCount = 33 },
        { label = "Ultra", ringRtSize = 4096, circleRtSize = 1024, ringSegments = 360, circleSegments = 360, tickCount = 65 },
        { label = "Low", realtime = true, ringSegments = 12, circleSegments = 6, tickCount = 9, hidePointTriangles = true },
        { label = "Medium", realtime = true, ringSegments = 24, circleSegments = 12, tickCount = 17 },
        { label = "High", realtime = true, ringSegments = 36, circleSegments = 18, tickCount = 33 },
        { label = "Ultra", realtime = true, ringSegments = 64, circleSegments = 32, tickCount = 65 }
    },
    defaultIndex = 2
}

local PICK_CONFIG = {
    pointRemoveRadius = 12,
    cornerTraceMinLength = 6,
    drawSelectDeadzone = 1,
    faceTraceOutsideOffset = 1,
    faceTraceEndOvershoot = 1,
    traceProbeNormalDotMin = 0.999999
}

local ROTATION_CONFIG = {
    snapDivisors = { 3, 4, 5, 6, 8, 9, 10, 12, 15, 18, 20, 24, 30, 36, 40, 45, 60, 72, 90, 120, 180, 360 },
    defaultSnapIndex = 12,
    maxVisibleTicks = 20
}

local SESSION_CONFIG = {
    convarSuffixes = { "px", "py", "pz", "pitch", "yaw", "roll" }
}

local GHOST_REFRESH_INTERVAL = 0.10

local SMARTSNAP_CONFIG = {
    enabledCvar = "snap_enabled",
    disableCvar = "magic_align_disable_smartsnap_active"
}

core.compatGhosts = compatGhosts
core.TOOL_UI = TOOL_UI
core.RENDER_QUALITY = RENDER_QUALITY
core.PICK_CONFIG = PICK_CONFIG
core.ROTATION_CONFIG = ROTATION_CONFIG
core.SESSION_CONFIG = SESSION_CONFIG
core.GHOST_REFRESH_INTERVAL = GHOST_REFRESH_INTERVAL
core.SMARTSNAP_CONFIG = SMARTSNAP_CONFIG

return core
