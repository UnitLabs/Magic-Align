TOOL.Category = "Construction"
TOOL.Name = "#tool.magic_align.name"
TOOL.Command = nil
TOOL.ConfigName = ""

MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

include("magic_align/tool_config.lua")
include("magic_align/tool_setup.lua")

if SERVER then
    AddCSLuaFile("magic_align/tool_config.lua")
    AddCSLuaFile("magic_align/tool_setup.lua")
    AddCSLuaFile("magic_align/tool_actions.lua")
    AddCSLuaFile("magic_align/client/tool_session.lua")
    AddCSLuaFile("magic_align/client/tool_offsets.lua")
    AddCSLuaFile("magic_align/client/tool_gizmo.lua")
    AddCSLuaFile("magic_align/client/tool_preview.lua")
    AddCSLuaFile("magic_align/client/tool_commit.lua")
    AddCSLuaFile("magic_align/client/tool_interaction.lua")
    AddCSLuaFile("magic_align/client/math_parser.lua")
    AddCSLuaFile("magic_align/client/formula_manager.lua")
    AddCSLuaFile("magic_align/client/geometry.lua")
    AddCSLuaFile("magic_align/client/dmagic_align_numslider.lua")
    AddCSLuaFile("magic_align/client/world_bsp.lua")
    AddCSLuaFile("magic_align/client/gizmo_snap.lua")
    AddCSLuaFile("magic_align/client/menu.lua")
    AddCSLuaFile("magic_align/client/menuentryhack.lua")
    AddCSLuaFile("magic_align/client/render/world_grid_light.lua")
    AddCSLuaFile("magic_align/client/render/hover_grid.lua")
    AddCSLuaFile("magic_align/client/render/rotation_ticks.lua")
    AddCSLuaFile("magic_align/client/render.lua")
    AddCSLuaFile("magic_align/client/render_toolgun.lua")
    AddCSLuaFile("magic_align/client/world_points.lua")
    AddCSLuaFile("magic_align/toolgun_effects.lua")

    include("magic_align/toolgun_effects.lua")
    include("magic_align/tool_actions.lua")
    return
end

include("magic_align/toolgun_effects.lua")
include("magic_align/tool_actions.lua")
include("magic_align/client/tool_session.lua")
include("magic_align/client/tool_offsets.lua")
include("magic_align/client/gizmo_snap.lua")
include("magic_align/client/tool_gizmo.lua")
include("magic_align/client/tool_preview.lua")
include("magic_align/client/tool_commit.lua")
include("magic_align/client/tool_interaction.lua")

include("magic_align/client/geometry.lua")
include("magic_align/client/world_bsp.lua")
include("magic_align/client/world_points.lua")
include("magic_align/client/render/world_grid_light.lua")
include("magic_align/client/render/hover_grid.lua")
include("magic_align/client/render/rotation_ticks.lua")
include("magic_align/client/render.lua")
include("magic_align/client/menu.lua")
include("magic_align/client/menuentryhack.lua")
include("magic_align/client/render_toolgun.lua")
