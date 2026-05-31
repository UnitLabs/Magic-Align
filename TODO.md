# Magic Align Todo

This file records the current design todo items for Magic Align. The intent is to solve these at the shared architecture level, not through isolated feature-specific branches in unrelated code paths.

## Not currently planned

- Snap preview dragging directly to World-BSP / world-grid candidates is not an active todo for now.

## 1. Done - Allow target points on any valid reference except Prop 1

Status: implemented on 2026-05-29. Target points now carry placement references and are resolved through shared reference-aware helpers for world position, target/reference-space conversion, normals, and validity. Prop 1 points remain local to Prop 1, while Target points can resolve against Prop 2, World/World-BSP/Grid, or other valid props/entities.

Target points should not be limited to Prop 2. They should be placeable on any valid reference except Prop 1, while Prop 2 remains the second main reference space for the Magic Align session.

Desired behavior:
- Prop 1 points stay strictly local to Prop 1.
- Target points can be placed on Prop 2, other props/entities, or the world.
- Dragging a target point from Prop 2 over the world to another prop should let the point change reference:
  `Prop 2 -> World -> Other Entity`.
- Prop 2 remains the second reference space for UI, offsets, session intent, and commit relationships.
- Prop 1 can be positioned from a combination of target references, such as a Prop-2 point, a world-grid point, and a point on another entity.

Design direction:
- Introduce a reference-aware target point model instead of assuming every target point is local to Prop 2.
- Use central point/reference resolver functions for conversions such as:
  - point to world position
  - point to target/reference space
  - point normal to world/local normal
  - point reference validity
- Do not scatter `world` / `entity` / `prop2` special cases across solve, preview, render, commit, and undo code.

Open implementation detail:
- Target points should carry their placement reference. They should not be silently frozen into Prop-2-local coordinates unless that behavior is explicitly chosen and documented.

## 2. Done - Store and optionally restore sessions from Magic Align undo

Status: implemented on 2026-05-29. Magic Align undo entries now carry a versioned session snapshot; the client-side `Restore Session on Undo` option controls snapshot restoration at undo time, while server entity undo always runs.

Every Magic Align undo entry should store a versioned snapshot of the executed session. Restoring that snapshot should be controlled by a Misc option:

`Restore Session on Undo`

Behavior:
- The session snapshot is always stored with the undo entry.
- The Misc option controls only whether the snapshot is restored when the undo is executed.
- This lets the user toggle the option later and still get predictable behavior.
- Entity undo must always run, regardless of whether session restore is enabled.
- Session restore is best-effort: if referenced entities no longer exist or no longer fit the current context, restore partially or skip safely.
- Session restore should also handle Mirror sessions and UI state.
- If the undone action was a Mirror action, restoring the session should reactivate the Mirror tab.
- If the undone action was not a Mirror action, and the UI is currently on the Mirror tab, restore an appropriate non-Mirror tab instead.

Snapshot should include:
- schema/version number
- last executed action type, including whether it was a Mirror action
- Prop 1
- Prop 2 or world target
- source points
- target points using the new reference-aware model
- mirror state needed to restore a Mirror session robustly
- linked props
- anchor selection, priority, and percentage options
- per-space offset/gizmo values
- relevant session/UI state, including the selected tab, that can be restored robustly

Server/client responsibility:
- The client remains the solver.
- The server does not need to recompute the align solve.
- The server should continue to receive final `pos` / `ang` and execute the commit safely.
- The server-side undo entry stores the session snapshot so the client can restore it when undo runs and the Misc option is enabled.

## 3. Done - Review Alt gizmo toggle behavior

Status: stabilized on 2026-05-29. The Alt gizmo toggle now uses a single logical Alt modifier edge, ignores drag/press and UI-blocked input, and requires a stable valid hovered point before toggling.

The Alt-based world/target point gizmo toggle can appear to switch by itself. Review and stabilize this input behavior.

Desired behavior:
- Toggle only on a real Alt-down edge.
- Treat left Alt and right Alt as one logical modifier state.
- Do not toggle while a drag/press is active.
- Do not toggle while UI input is blocking tool input.
- Require a valid and stable hovered target point before toggling.
- Avoid repeated toggles caused by a held key, frame-to-frame hover changes, or left/right Alt transitions.

## 4. Done - Keep server validation focused on execution safety

Status: implemented on 2026-05-29. Server commit validation focuses on safe final execution and bounded payloads instead of authoritative point geometry checks.

Point geometry does not need to be strictly validated as the authority for the final movement. The server only needs the final position and angle and should focus validation on safe execution.

Server should enforce:
- player/tool permission for moved/copied props
- spawn/copy/prop limits
- linked prop count limits
- entity validity
- finite vectors and angles
- bounded payload sizes
- safe handling of missing or invalid references

Do not add strict point-inside-reference validation unless a later feature actually needs points to be authoritative server-side geometry.
