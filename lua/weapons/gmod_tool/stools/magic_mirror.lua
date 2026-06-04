TOOL.Category = "Construction"
TOOL.Name = "#tool.magic_mirror.name"
TOOL.Command = nil
TOOL.ConfigName = ""

MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

include("magic_align/tool_config.lua")
include("magic_align/magic_mirror.lua")
include("magic_align/magic_mirror_tool_setup.lua")

if SERVER then
    AddCSLuaFile("magic_align/tool_config.lua")
    AddCSLuaFile("magic_align/magic_mirror.lua")
    AddCSLuaFile("magic_align/magic_mirror_tool_setup.lua")
    AddCSLuaFile("magic_align/toolgun_effects.lua")
    AddCSLuaFile("magic_align/client/geometry.lua")
    AddCSLuaFile("magic_align/client/tool_session.lua")
    AddCSLuaFile("magic_align/client/tool_offsets.lua")
    AddCSLuaFile("magic_align/client/commit_upload.lua")
    AddCSLuaFile("magic_align/client/math_parser.lua")
    AddCSLuaFile("magic_align/client/formula_manager.lua")
    AddCSLuaFile("magic_align/client/render_primitives.lua")
    AddCSLuaFile("magic_align/client/render_toolgun.lua")
    AddCSLuaFile("magic_align/client/magic_mirror.lua")
    AddCSLuaFile("magic_align/client/magic_mirror_render.lua")
    AddCSLuaFile("magic_align/client/magic_mirror_toolgun.lua")
    AddCSLuaFile("magic_align/client/menuentryhack.lua")

    include("magic_align/toolgun_effects.lua")
    return
end

include("magic_align/toolgun_effects.lua")
include("magic_align/client/geometry.lua")
include("magic_align/client/tool_session.lua")
include("magic_align/client/tool_offsets.lua")
include("magic_align/client/commit_upload.lua")
include("magic_align/client/render_primitives.lua")
include("magic_align/client/render_toolgun.lua")
include("magic_align/client/magic_mirror.lua")
include("magic_align/client/magic_mirror_render.lua")
include("magic_align/client/magic_mirror_toolgun.lua")
include("magic_align/client/menuentryhack.lua")
