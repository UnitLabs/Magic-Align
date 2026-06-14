MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client
local core = client.ToolCore or include("magic_align/tool_config.lua")
local TOOL_UI = core.TOOL_UI
local RENDER_QUALITY = core.RENDER_QUALITY
local SESSION_CONFIG = core.SESSION_CONFIG
local SMARTSNAP_CONFIG = core.SMARTSNAP_CONFIG
TOOL.ClientConVar = {
    grid_a = "12",
    grid_a_min = "3",
    grid_b_enable = "0",
    grid_b = "8",
    grid_b_min = "2",
    min_length = "4",
    trace_snap_length = "5",
    display_rounding = "5",
    show_trace_probes = "0",
    preview_occluded = "0",
    preview_occluded_r = "18",
    preview_occluded_g = "52",
    preview_occluded_b = "70",
    preview_occluded_a = "160",
    ring_quality = tostring(RENDER_QUALITY.defaultIndex),
    world_bsp_snap = "1",
    world_bsp_grid_mode = "global",
    world_bsp_grid_size = "16",
    world_bsp_budget_ms = "2.5",
    world_bsp_ignore_brush_blockers = "1",
    world_bsp_show_blockers = "0",
    world_bsp_full_grid = "1",
    world_bsp_light_adapt = "1",
    rotation_snap = "12",
    translation_snap = "0",
    world_target = "1",
    restore_session_on_undo = "1",
    toolgun_sound_volume = "0.25",
    weld = "0",
    nocollide = "0",
    parent = "0",
    mirror_entity_mirror = "0",
    from_anchor = "p1",
    from_priority = "mid12,p1,p2,p3,mid23,mid13,mid123",
    from_mid12_pct = "50",
    from_mid23_pct = "50",
    from_mid13_pct = "50",
    to_anchor = "p1",
    to_priority = "mid12,mid12,p2,p3,mid23,mid13,mid123",
    to_mid12_pct = "50",
    to_mid23_pct = "50",
    to_mid13_pct = "50",
    space = "prop1"
}

for _, space in ipairs(M.SPACES) do
    -- Positionswerte werden im Referenzraum des Tabs gespeichert.
    -- Die Winkelwerte beschreiben, wie der Gizmo innerhalb dieses
    -- Referenzraums gedreht ist.
    TOOL.ClientConVar[space .. "_px"] = "0"
    TOOL.ClientConVar[space .. "_py"] = "0"
    TOOL.ClientConVar[space .. "_pz"] = "0"
    TOOL.ClientConVar[space .. "_pitch"] = "0"
    TOOL.ClientConVar[space .. "_yaw"] = "0"
    TOOL.ClientConVar[space .. "_roll"] = "0"
end

TOOL.Information = TOOL_UI.information.idle

if CLIENT then
    CreateClientConVar(
        "magic_align_grid_label_percent",
        "1",
        true,
        false,
        "Show Magic Align gridline labels as percentages instead of reduced fractions.",
        0,
        1
    )

    CreateClientConVar(
        "magic_align_grid_label_reduce_fraction",
        "1",
        true,
        false,
        "Show Magic Align fraction labels in reduced form instead of the original grid fraction.",
        0,
        1
    )

    CreateClientConVar(
        "magic_align_grid_alpha",
        "64",
        true,
        false,
        "Set the alpha used for Magic Align Grid A and Grid B preview lines.",
        0,
        255
    )

    CreateClientConVar(
        SMARTSNAP_CONFIG.disableCvar,
        "1",
        true,
        false,
        "Disable SmartSnap while the Magic Align tool is active.",
        0,
        1
    )

    CreateClientConVar(
        "magic_align_highlight_context_menu",
        "1",
        true,
        false,
        "Highlight the Magic Align tool entry in the context menu.",
        0,
        1
    )

    CreateClientConVar(
        "magic_align_hide_expensive_quality_chat_warning",
        "0",
        true,
        false,
        "Hide the once-per-spawn Magic Align expensive gizmo quality chat warning.",
        0,
        1
    )

    language.Add("tool.magic_align.name", "Magic Align")
    language.Add("tool.magic_align.desc", TOOL_UI.defaultDescription)
    language.Add("tool.magic_align.left", "Place & Move Points | Manipulate Gizmo")
    language.Add("tool.magic_align.right", "Delete Points | Toggle Linked Props")
    language.Add("tool.magic_align.reload", "Reset Session")
    language.Add("tool.magic_align.use", "Commit | Shift: Keep Session | Ctrl: Copy | Ctrl+Shift: Copy&Move")
    language.Add("tool.magic_align.tab", "Cycle Space | Hold+Scroll: Choose")
    language.Add("tool.magic_align.point_gizmo", "Toggle Gizmo on hovered Point")
    language.Add("tool.magic_align.alt_pick", "Surface-Select")
    language.Add("tool.magic_align.supress_snap", "Suppress Snapping")
end

