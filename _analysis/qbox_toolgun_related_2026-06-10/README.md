# QBox Toolgun-Related Cache Files

Source scan:

- Fresh cache folder: `N:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\cache\lua_decompress_fresh`
- Search focus: `QBox`, `qbox`, `SToolDecal`, `stooldecal`, `qboxsounds`, `gmod_tool`, `gmod_toolmode`, `toolgun`, `TOOL.`, `physgun`
- Date collected: 2026-06-10

## Direct Toolgun Effect Chain

These are the important files for the broken toolgun effect behavior.

- `direct/01_qbox_gmod_tool_swep__d943cc13f972b09013f2c0f9c6b5b3bfea4b97c1.lua`
  - QBox-modified `gmod_tool` SWEP.
  - Defines `SWEP.ShootSound = "qboxsounds/toolgun.wav"`.
  - Defines network string `SToolDecal`.
  - Implements `SWEP:DoShootEffect(...)`.
  - Sends `SToolDecal` from inside `DoShootEffect`.
  - Suspicious line: `net.WriteAngle(ang)` uses `ang`, but `ang` is not local/defined in that function.

- `direct/02_qbox_stooldecal_client_hook__7c2dd1ca2300414f3512bd12e846a71ff3226805.lua`
  - Client-side `hook.Add("SToolDecal", "SToolDecal", ...)`.
  - Creates `cl_showtoolgun_decals` and `cl_showtoolgunuses`.
  - Runs `util.Effect("stooldecal", ...)`.

## Indirect QBox Tool Files

These are actual Sandbox tool files patched/commented by QBox. They do not own the global shoot effect chain, but they are selected and fired through the toolgun.

- `indirect_tools/01_qbox_modified_thruster_tool__1d542ebf01d5fcf81e620dd7bef617b9d26d1bd2.lua`
  - `TOOL.Name = "#tool.thruster.name"`.
  - Contains QBox-specific change/comment on `TOOL.ClientConVar["soundname"]`.

- `indirect_tools/02_qbox_modified_nocollide_tool__789ef02d0ec77b37299e1d30829a6bbf2121dc19.lua`
  - `TOOL.Name = "#tool.nocollide.name"`.
  - Contains QBox-specific change/comment in `TOOL:LeftClick`.

- `indirect_tools/03_qbox_modified_rope_tool__9c961fb664e59a6246460788c6e720d3bfd5a656.lua`
  - `TOOL.Name = "#tool.rope.name"`.
  - Contains `_G.QBOX_ALLOW_ROPE_WORLD` logic.

## Indirect QBox Gamemode / UI Context

These files are not the shoot effect bug itself, but they set up QBox, load the toolgun, or expose related settings.

- `indirect_gamemode/01_qbox_gamemode_init__530939f18145acee46302a565919febb9deb45e7.lua`
  - `GM.Name = "QBox"`, `GM.Author = "Meta Construct"`.
  - Includes `core/sh_physgun.lua`, `core/sh_effects.lua`, `core/sh_options_menu.lua`, and `player_class/player_qbox.lua`.

- `indirect_gamemode/02_player_qbox_loadout_gives_gmod_tool__4b09e48e5351648e707c1bb01a2f128b5ae52d25.lua`
  - Registers `player_qbox`.
  - `PLAYER:Loadout()` gives `gmod_tool`, `gmod_camera`, and `weapon_physgun`.

- `indirect_gamemode/03_qbox_physgun_helpers__623b9c7dcab0d731713e5429afb611045633157d.lua`
  - QBox physgun helper logic.
  - Adds/removes `Think` hook named `qbox_physgun`.

- `indirect_gamemode/04_qbox_spawnmenu_options_physgun__7ee741bf8e2816dba54438b071aaaecf9fc622be.lua`
  - Adds spawnmenu options for `qbox_hide_hands`, `qbox_physgun_helpers`, and `physgun_drawbeams`.

- `indirect_gamemode/05_qbox_cvar_list_toolgun_physgun__3ced4d32b0ac7e35ef80cd91fe3d4b58d18d8937.lua`
  - Contains cvar entries including `cl_toolgun_hue`, `cl_toolgun_sat`, `gmod_toolmode`, and `qbox_physgun_helpers`.

- `indirect_gamemode/06_qbox_gui_weapon_switch_and_undo_bind__099041562fbd745c8eb795d032b215bb255f809c.lua`
  - QBox GUI/weapon-selection sound file handling.
  - Hooks `GM:PlayerBindPress` for undo/gmod_undo shortcut behavior.

- `indirect_gamemode/07_qbox_client_hud_weapon_defaults__c7af2e14b97b47d513b5dd8fe347714258fc6194.lua`
  - QBox client HUD/default weapon cvars.
  - Defines `qbox_hide_hands`.

## Adjacent Effect File

- `adjacent_effects/01_qbox_none_effect_debug__d8a9349e9f43169d102b503303ada37b9e045ff9.lua`
  - QBox-only effect stub/debug file: `QBOX_DEBUG`.
  - Not directly part of the toolgun chain, but kept because the original issue concerns custom effects and this is a QBox effect file.

## Not QBox, But Related Meta Note

- `excluded_meta_notes/not_qbox_mta_loadout_physgun_camera__559de9cf669b0baab32804c2bf3089237fcbe413.lua`
  - `GM.Name = "MTA"`, `GM.Author = "Meta Construct"`.
  - Gives `weapon_physgun` and `gmod_camera`, but not `gmod_tool`.
  - Included only as a note because it is Meta Construct related, not QBox.

## Current Highest-Signal Bug Candidate

The strongest candidate remains:

`direct/01_qbox_gmod_tool_swep__d943cc13f972b09013f2c0f9c6b5b3bfea4b97c1.lua`

Inside `SWEP:DoShootEffect(...)`, the file sends `SToolDecal` and calls `net.WriteAngle(ang)`, but `ang` is not defined in the function arguments or as a local variable in that scope.
