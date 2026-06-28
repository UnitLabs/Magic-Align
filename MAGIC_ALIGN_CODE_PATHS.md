# Magic Align Codepfade und Funktionsreferenz

Automatisch aus dem aktuellen Workspace erzeugt. Die Relevanz ist nach Risiko/Architekturwirkung sortiert, nicht nach Lade- oder Lesereihenfolge.

## Kurzstatistik

- Lua-Dateien: 48
- Funktionseintraege: 2384
- Davon benannt/API-Callbacks: 2316; zusaetzliche anonyme Inline-Funktionen: 68
- Erfasst werden: `local function`, `function name`, `name = function`, `hook.Add`, `net.Receive`, `concommand.Add` plus anonyme Inline-`function(...)`-Ausdruecke.
- Sehr kleine Loader-Dateien koennen keine eigenen Funktionen enthalten und stehen dann nur als Datei im Pfad.

## Pfaduebersicht nach Relevanz

1. [Server-Commit, echte Entity-Aenderung, Undo](#pfad-1) - 3 Dateien, 64 Funktionseintraege
2. [Shared Core: Praezision, Referenzen, Solver, Snapshots](#pfad-2) - 4 Dateien, 261 Funktionseintraege
3. [Client Runtime: State, Input, Hover, Preview](#pfad-3) - 11 Dateien, 358 Funktionseintraege
4. [Tool-Bootstrap und Ladegrenzen](#pfad-4) - 3 Dateien, 6 Funktionseintraege
5. [Mirror und Entity-Mirror](#pfad-5) - 6 Dateien, 290 Funktionseintraege
6. [World-Target, World-BSP, Grid-Snap, BSP-Cache](#pfad-6) - 7 Dateien, 386 Funktionseintraege
7. [Rendering, Ghosts, Toolgun-Feedback](#pfad-7) - 4 Dateien, 381 Funktionseintraege
8. [UI, Menues, Slider, Formeln](#pfad-8) - 5 Dateien, 497 Funktionseintraege
9. [Primitive-Kompatibilitaet](#pfad-9) - 3 Dateien, 23 Funktionseintraege
10. [Profiling und Diagnose](#pfad-10) - 2 Dateien, 50 Funktionseintraege

<a id="pfad-1"></a>
## Pfad 1: Server-Commit, echte Entity-Aenderung, Undo

Relevanz: Hoechste Relevanz: bewegt/kopiert reale Entities, prueft Rechte/Limits, erzeugt Constraints und Undo.

### Kernfluss

- [commit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_commit.lua:22) - baut finalen Commit-Payload aus Preview/Session
- [core.beginCommitUpload](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:47) - startet chunked Upload
- [sendCommitUploadStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:81) - sendet Begin/Parts/Finish im Think-Hook
- [net.Receive M.NET](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1143) - liest Basisdaten und Snapshot
- [net.Receive M.NET_COMMIT_LINKED_PART](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1255) - liest Linked-Prop-Teile
- [net.Receive M.NET_COMMIT_FINISH](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1322) - finalisiert Pending-Commit
- [queueCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:445) - legt Coroutine-Task an
- [runCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:799) - fuehrt Move/Copy/Copy&Move aus
- [restoreCommitStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:593) - Undo-Restore fuer Entities und Session
- [sendUndoRestore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:574) - sendet Session/Primitive-Restore an Client

### Dateien

- [lua/magic_align/client/tool_commit.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_commit.lua) - 142 Zeilen, 1 Funktionseintraege
- [lua/magic_align/client/commit_upload.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua) - 183 Zeilen, 7 Funktionseintraege
- [lua/autorun/server/magic_align_commit.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua) - 1371 Zeilen, 56 Funktionseintraege

### Funktionen

#### [lua/magic_align/client/tool_commit.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_commit.lua) (142 Zeilen, 1 Funktionen)
- [commit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_commit.lua:22) - local

#### [lua/magic_align/client/commit_upload.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua) (183 Zeilen, 7 Funktionen)
- [writeCommitPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:8) - local
- [previewEntityMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:17) - local
- [predictCommitMirrorVisual](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:25) - local
- [predict](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:35) - local
- [core.beginCommitUpload](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:47) - member/global
- [setCommitUploadProgress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:75) - local
- [sendCommitUploadStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/commit_upload.lua:81) - local

#### [lua/autorun/server/magic_align_commit.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua) (1371 Zeilen, 56 Funktionen)
- [sendCommitResult](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:27) - local
- [rejectCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:44) - local
- [rejectPendingCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:48) - local
- [finiteNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:58) - local
- [hasFiniteVectorFields](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:63) - local
- [hasFiniteAngleFields](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:67) - local
- [asGModVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:71) - local
- [asGModAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:80) - local
- [preciseVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:89) - local
- [preciseAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:93) - local
- [cloneVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:97) - local
- [cloneAng](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:103) - local
- [advResizerData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:111) - local
- [applyAdvResizerData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:138) - local
- [entityModel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:148) - local
- [applyEntityAppearance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:157) - local
- [copyPhysicsState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:224) - local
- [registerClonedEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:242) - local
- [countClonedProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:265) - local
- [applyDuplicatorData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:271) - local
- [cloneViaDuplicator](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:311) - local
- [cloneViaSpawnFallback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:340) - local
- [physicsMotionEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:377) - local
- [captureEntityState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:382) - local
- [canUse](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:399) - local
- [readPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:422) - local
- [finitePoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:433) - local
- [queueCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:445) - local
- [cloneEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:457) - local
- [settlePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:483) - local
- [restorePreservedMotion](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:496) - local
- [toolClientBool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:508) - local
- [applyEntityMirrorStateFromStart](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:513) - local
- [debugCommitEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:523) - local
- [removeEntities](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:537) - local
- [commitCheckpoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:545) - local
- [releaseCommitLock](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:550) - local
- [undoRestoreEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:556) - local
- [sendUndoRestore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:574) - local
- [restoreCommitStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:593) - local
- [expandWorldBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:649) - local
- [worldBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:666) - local
- [toolLocalBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:694) - local
- [aabbOverlap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:706) - local
- [pairKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:717) - local
- [addNoCollideConstraint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:730) - local
- [applyOverlapNoCollides](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:743) - local
- [applyCommitRelations](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:780) - local
- [runCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:799) - member/global
- [addUndoProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:870) - local
- [hook.Add Think / MagicAlignCommitQueue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1054) - hook callback
- [net.Receive M.NET_BOUNDS_REQUEST](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1092) - net callback
- [net.Receive M.NET_VIEW_ANGLES](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1125) - net callback
- [net.Receive M.NET](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1143) - net callback
- [net.Receive M.NET_COMMIT_LINKED_PART](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1255) - net callback
- [net.Receive M.NET_COMMIT_FINISH](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:1322) - net callback

<a id="pfad-2"></a>
## Pfad 2: Shared Core: Praezision, Referenzen, Solver, Snapshots

Relevanz: Zentrale Logik: alle Align-/Mirror-/Undo-Pfade haengen an diesen gemeinsamen Daten- und Geometrie-Helfern.

### Kernfluss

- [M.NewSession](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:177) - kanonisches Sessionmodell
- [M.PointReferenceFromEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:207) - Point-Referenzmodell
- [M.ResolvePointReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:631) - loest Point-Referenz
- [M.ResolvePointWorldPositionCached](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:872) - Point -> World mit Cache
- [M.ResolvePointSetWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1059) - Target-Point-Set fuer Solver
- [M.ResolveAnchorCached](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:321) - Source/Target Anchor-Auswahl
- [M.Solve](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1230) - berechnet Grundpose
- [M.ComposePose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1475) - wendet Offsets/Rotationen an
- [M.CreateSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1745) - serialisierbarer Undo-Snapshot
- [M.RestoreSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:2149) - best-effort Session-Restore

### Dateien

- [lua/magic_align/precision.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua) - 838 Zeilen, 103 Funktionseintraege
- [lua/magic_align/rounding.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua) - 167 Zeilen, 16 Funktionseintraege
- [lua/magic_align/anchor.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua) - 400 Zeilen, 21 Funktionseintraege
- [lua/autorun/magic_align.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua) - 2238 Zeilen, 121 Funktionseintraege

### Funktionen

#### [lua/magic_align/precision.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua) (838 Zeilen, 103 Funktionen)
- [finiteNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:33) - local
- [numberOrZero](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:38) - local
- [isVectorP](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:52) - local
- [isAngleP](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:56) - local
- [isVectorLike](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:60) - local
- [isAngleLike](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:64) - local
- [parseTripleString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:68) - local
- [VectorP](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:83) - local
- [AngleP](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:103) - local
- [angleAliasKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:123) - local
- [vectorOperand](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:129) - local
- [angleOperand](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:133) - local
- [safeDivisor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:137) - local
- [VectorPMeta.__tostring](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:148) - assigned
- [VectorPMeta.__unm](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:151) - assigned
- [VectorPMeta.__add](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:155) - assigned
- [VectorPMeta.__sub](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:160) - assigned
- [VectorPMeta.__mul](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:165) - assigned
- [VectorPMeta.__div](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:176) - assigned
- [VectorPMeta.__eq](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:190) - assigned
- [AnglePMeta.__index](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:197) - assigned
- [AnglePMeta.__newindex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:205) - assigned
- [AnglePMeta.__tostring](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:209) - assigned
- [AnglePMeta.__eq](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:212) - assigned
- [VectorPMethods:Clone](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:219) - member/global
- [VectorPMethods:Set](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:223) - member/global
- [VectorPMethods:Unpack](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:230) - member/global
- [VectorPMethods:LengthSqr](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:234) - member/global
- [VectorPMethods:Length](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:238) - member/global
- [VectorPMethods:Dot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:242) - member/global
- [VectorPMethods:Cross](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:246) - member/global
- [VectorPMethods:Distance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:250) - member/global
- [VectorPMethods:DistToSqr](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:254) - member/global
- [VectorPMethods:GetNormalized](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:262) - member/global
- [VectorPMethods:Normalize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:266) - member/global
- [VectorPMethods:Angle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:275) - member/global
- [VectorPMethods:ToScreen](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:287) - member/global
- [AnglePMethods:Clone](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:296) - member/global
- [AnglePMethods:Set](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:300) - member/global
- [AnglePMethods:Unpack](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:307) - member/global
- [AnglePMethods:Pitch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:311) - member/global
- [AnglePMethods:Yaw](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:315) - member/global
- [AnglePMethods:Roll](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:319) - member/global
- [AnglePMethods:Forward](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:323) - member/global
- [AnglePMethods:Right](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:327) - member/global
- [AnglePMethods:Up](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:331) - member/global
- [AnglePMethods:RotateAroundAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:335) - member/global
- [toGModVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:340) - member/global
- [toGModAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:348) - member/global
- [vecOrZero](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:370) - local
- [angOrZero](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:374) - local
- [copyVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:378) - local
- [copyAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:383) - local
- [vectorLengthSqr](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:388) - assigned
- [dotVectors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:398) - assigned
- [crossVectors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:406) - assigned
- [addVectors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:419) - local
- [subtractVectors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:430) - local
- [scaleVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:441) - assigned
- [normalizeVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:452) - assigned
- [projectVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:462) - local
- [angleMatrix](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:474) - assigned
- [multiplyMatrix](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:487) - local
- [transposeMultiplyMatrix](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:507) - local
- [transformVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:527) - local
- [localToWorldPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:538) - local
- [worldToLocalPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:554) - local
- [inverseTransformVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:576) - local
- [matrixFromBasis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:587) - local
- [axisAngleMatrix](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:595) - local
- [matrixAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:612) - assigned
- [M.IsFiniteNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:637) - member/global
- [M.IsFiniteVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:641) - member/global
- [M.IsFiniteAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:645) - member/global
- [M.CopyVectorPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:649) - member/global
- [M.CopyAnglePrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:653) - member/global
- [M.AddVectorsPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:657) - member/global
- [M.SubtractVectorsPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:661) - member/global
- [M.ScaleVectorPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:665) - member/global
- [M.DotVectorsPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:669) - member/global
- [M.CrossVectorsPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:673) - member/global
- [M.VectorLengthSqrPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:677) - member/global
- [M.NormalizeVectorPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:681) - member/global
- [M.ProjectVectorPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:685) - member/global
- [M.AngleMatrixPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:689) - member/global
- [M.MatrixAnglePrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:693) - member/global
- [M.AngleForwardPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:697) - member/global
- [M.AngleLeftPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:702) - member/global
- [M.AngleRightPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:707) - member/global
- [M.AngleUpPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:712) - member/global
- [M.AngleAxesPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:717) - member/global
- [M.AngleAxesPreciseInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:724) - member/global
- [M.AngleFromForwardUpPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:751) - member/global
- [M.RotateAngleAroundAxisPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:765) - member/global
- [M.LocalToWorldPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:779) - member/global
- [M.LocalToWorldPosPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:788) - member/global
- [M.WorldToLocalPosPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:792) - member/global
- [M.WorldToLocalPrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:796) - member/global
- [M.TransformPoseRelativePrecise](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:806) - member/global
- [net.WritePreciseVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:816) - member/global
- [net.ReadPreciseVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:823) - member/global
- [net.WritePreciseAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:827) - member/global
- [net.ReadPreciseAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/precision.lua:834) - member/global

#### [lua/magic_align/rounding.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua) (167 Zeilen, 16 Funktionen)
- [normalizeRoundingSetting](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:10) - local
- [negativeZeroText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:19) - local
- [M.NormalizeRoundingSetting](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:31) - member/global
- [M.IsRoundingDisabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:35) - member/global
- [M.RoundingSettingToDecimals](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:39) - member/global
- [M.GetConfiguredRounding](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:48) - member/global
- [M.GetDisplayRounding](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:61) - member/global
- [M.DescribeRoundingSetting](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:65) - member/global
- [M.TrimNumericString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:78) - member/global
- [M.FormatFixedNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:90) - member/global
- [M.FormatPreciseNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:105) - member/global
- [M.FormatConVarNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:119) - member/global
- [M.FormatDisplayNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:123) - member/global
- [M.FormatDisplayPreviewNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:134) - member/global
- [M.RoundNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:153) - member/global
- [M.RoundNumberForSetting](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/rounding.lua:163) - member/global

#### [lua/magic_align/anchor.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua) (400 Zeilen, 21 Funktionen)
- [M.ParsePriority](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:25) - member/global
- [M.ClampAnchorPercent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:44) - member/global
- [M.SnapAnchorPercent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:52) - member/global
- [M.NormalizeAnchorOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:60) - member/global
- [M.NormalizeAnchorOptionsCached](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:75) - member/global
- [M.AnchorOptionsFromReader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:100) - member/global
- [interpolation](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:117) - local
- [lerpPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:121) - local
- [setPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:128) - local
- [lerpPointInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:139) - local
- [anchorPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:152) - local
- [anchorPointInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:175) - local
- [M.AnchorPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:207) - member/global
- [M.AnchorAvailable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:211) - member/global
- [M.ResolveAnchor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:221) - member/global
- [try](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:226) - local
- [anchorPriorityKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:251) - local
- [anchorPointsSignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:259) - local
- [resolveAnchorInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:282) - local
- [try](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:295) - local
- [M.ResolveAnchorCached](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/anchor.lua:321) - member/global

#### [lua/autorun/magic_align.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua) (2238 Zeilen, 121 Funktionen)
- [readConVarNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:106) - local
- [M.GetMaxLinkedProps](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:116) - member/global
- [M.GetCommitLinkedPartSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:121) - member/global
- [M.GetCommitBudgetMs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:126) - member/global
- [M.GetCommitBudgetSeconds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:131) - member/global
- [__tostring](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:151) - assigned
- [M.IsWorldTarget](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:156) - member/global
- [M.HasTargetEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:168) - member/global
- [M.NextSessionId](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:172) - member/global
- [M.NewSession](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:177) - member/global
- [M.PointReferenceFromEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:207) - member/global
- [M.CopyPointReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:217) - member/global
- [M.SetPointReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:234) - member/global
- [M.CopyPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:244) - member/global
- [hasUsableModel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:272) - local
- [isStoredScriptedEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:279) - local
- [M.IsProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:286) - member/global
- [activeToolByPredicate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:300) - local
- [M.IsMagicAlignToolMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:312) - member/global
- [M.IsClassicMagicAlignToolMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:316) - member/global
- [M.GetActiveMagicAlignFamilyTool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:320) - member/global
- [M.GetActiveClassicMagicAlignTool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:326) - member/global
- [M.GetActiveMagicAlignTool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:332) - member/global
- [sanitizeBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:336) - local
- [expandBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:349) - local
- [physAABBToLocalBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:368) - local
- [vectorApprox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:405) - local
- [parseScaleVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:415) - local
- [M.VectorApprox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:428) - member/global
- [M.ParseScaleVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:432) - member/global
- [modifierScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:436) - local
- [findSizeHandler](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:447) - local
- [M.FindSizeHandler](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:471) - member/global
- [M.GetEntityModelScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:475) - member/global
- [M.GetAdvResizerScales](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:479) - member/global
- [M.GetAdvResizerVisualScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:510) - member/global
- [advResizerBoundsScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:517) - local
- [M.GetAdvResizerBoundsScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:532) - member/global
- [scaleBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:536) - local
- [M.GetLocalBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:547) - member/global
- [M.RefreshState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:578) - member/global
- [M.ModeName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:602) - member/global
- [localToWorldSafe](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:613) - local
- [worldToLocalSafe](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:622) - local
- [M.ResolvePointReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:631) - member/global
- [pointCacheFrame](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:650) - local
- [pointCacheSetVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:654) - local
- [pointCacheSetVecComponents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:665) - local
- [pointEntityMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:674) - local
- [mirrorAxisSigns](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:680) - local
- [pointCacheEntPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:684) - local
- [pointReferenceSignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:740) - local
- [pointValueSignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:770) - local
- [pointCacheEntries](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:790) - local
- [pointCacheEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:802) - local
- [M.ClearPointWorldCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:830) - member/global
- [M.ResolvePointWorldPositionInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:841) - member/global
- [M.ResolvePointWorldPositionCached](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:872) - member/global
- [M.IsPointReferenceValid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:916) - member/global
- [M.ResolvePointWorldPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:937) - member/global
- [M.ResolvePointWorldNormalCached](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:943) - member/global
- [M.ResolvePointWorldNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:988) - member/global
- [M.ResolvePointPositionInReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1017) - member/global
- [M.ResolvePointNormalInReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1030) - member/global
- [M.ResolvePointSetWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1059) - member/global
- [normalized](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1101) - local
- [projected](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1105) - local
- [chooseUp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1109) - local
- [singlePointNormalContext](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1113) - local
- [pointContext](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1128) - local
- [transformPointSetForEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1153) - local
- [rotateToAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1188) - local
- [signedAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1219) - local
- [M.Solve](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1230) - member/global
- [lPI](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1365) - local
- [worldToLocalPosInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1385) - local
- [M.LinePlaneIntersectionInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1409) - member/global
- [M.LinePlaneIntersection](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1431) - member/global
- [M.LocalToLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1441) - member/global
- [rotateAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1451) - local
- [M.RotateAroundAnchor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1461) - member/global
- [rotatedBasis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1470) - local
- [M.ComposePose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1475) - member/global
- [rotateStoredBases](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1481) - local
- [snapshotEntityRef](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1544) - local
- [resolveSnapshotEntityRef](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1558) - local
- [snapshotPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1570) - local
- [restoreSnapshotPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1592) - local
- [restoreSnapshotPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1624) - local
- [snapshotOffsets](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1638) - local
- [copySnapshotOffsets](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1656) - local
- [normalizeActionType](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1674) - local
- [snapshotAnchorOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1686) - local
- [snapshotAnchorSide](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1690) - local
- [snapshotAnchors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1699) - local
- [validUiSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1709) - local
- [validNonMirrorSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1718) - local
- [M.ResolveSnapshotRestoreSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1725) - member/global
- [M.CreateSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1745) - member/global
- [actionId](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1804) - local
- [actionName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1811) - local
- [spaceId](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1818) - local
- [spaceName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1830) - local
- [anchorId](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1836) - local
- [anchorName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1847) - local
- [writeEntityRef](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1852) - local
- [readEntityRef](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1863) - local
- [writeSnapshotPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1880) - local
- [readSnapshotPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1890) - local
- [writeSnapshotPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1911) - local
- [readSnapshotPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1930) - local
- [writeSnapshotOffsets](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1944) - local
- [readSnapshotOffsets](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1960) - local
- [writePriority](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1980) - local
- [readPriority](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:1998) - local
- [writeAnchorSide](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:2012) - local
- [readAnchorSide](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:2023) - local
- [M.WriteSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:2035) - member/global
- [M.ReadSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:2080) - member/global
- [M.RestoreSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:2149) - member/global
- [M.PointInsideAABB](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:2230) - member/global

<a id="pfad-3"></a>
## Pfad 3: Client Runtime: State, Input, Hover, Preview

Relevanz: Haupt-Arbeitsfluss im Tool: Klicks, Punktwahl, Dragging, Snapping, Preview und Ghosts.

### Kernfluss

- [TOOL:LeftClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:476) - queued Client-Klick
- [TOOL:RightClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:498) - Punkte entfernen / Linked Prop toggeln
- [TOOL:Reload](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:517) - Session resetten
- [TOOL:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:731) - pro Frame: State, Hover, Input, Preview
- [hoverState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1015) - liest EyeTrace und baut Hover-Kandidaten
- [pressState.beginMouse](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:655) - startet Pick/Drag/Gizmo
- [pressState.updateActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:637) - aktualisiert aktiven Press
- [solvePreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:771) - ruft Solver und baut Preview
- [pendingPreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1239) - zeigt Vorschau fuer naechsten Punkt
- [ensureGhost](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:922) - aktualisiert Ghosts

### Dateien

- [lua/magic_align/tool_config.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua) - 197 Zeilen, 3 Funktionseintraege
- [lua/magic_align/tool_setup.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_setup.lua) - 143 Zeilen, 0 Funktionseintraege
- [lua/magic_align/tool_actions.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua) - 567 Zeilen, 32 Funktionseintraege
- [lua/magic_align/client/tool_session.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua) - 1516 Zeilen, 85 Funktionseintraege
- [lua/magic_align/client/tool_offsets.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua) - 1245 Zeilen, 53 Funktionseintraege
- [lua/magic_align/client/tool_interaction.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua) - 814 Zeilen, 33 Funktionseintraege
- [lua/magic_align/client/tool_gizmo.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua) - 528 Zeilen, 17 Funktionseintraege
- [lua/magic_align/client/gizmo_snap.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua) - 458 Zeilen, 24 Funktionseintraege
- [lua/magic_align/client/tool_preview.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua) - 1431 Zeilen, 44 Funktionseintraege
- [lua/magic_align/client/world_points.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua) - 881 Zeilen, 52 Funktionseintraege
- [lua/magic_align/client/geometry.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua) - 197 Zeilen, 15 Funktionseintraege

### Funktionen

#### [lua/magic_align/tool_config.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua) (197 Zeilen, 3 Funktionen)
- [compatGhosts.clear](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:52) - member/global
- [compatGhosts.clearAll](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:58) - member/global
- [compatGhosts.set](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:64) - member/global

#### [lua/magic_align/tool_setup.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_setup.lua) (143 Zeilen, 0 Funktionen)
- Keine eigene Funktionsdefinition; Loader/Include-Datei.

#### [lua/magic_align/tool_actions.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua) (567 Zeilen, 32 Funktionen)
- [pointWorldCacheForAction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:17) - local
- [writeClientActionTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:22) - local
- [sendClientAction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:43) - local
- [client.activeSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:52) - member/global
- [isMirrorSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:63) - local
- [isUiSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:67) - local
- [rememberNonMirrorSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:77) - local
- [setClientActiveSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:86) - local
- [clearSessionVisuals](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:102) - local
- [editable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:118) - local
- [client.RightClick.toggleLinkedProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:158) - member/global
- [client.RightClick.removeEditablePointAtTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:193) - member/global
- [performClientRightClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:240) - local
- [pointRemovalAtTraceWouldAffect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:269) - local
- [leftClickWouldAffect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:293) - local
- [rightClickWouldAffect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:316) - local
- [reloadWouldAffect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:339) - local
- [toolgunFeedbackKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:356) - local
- [playToolgunFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:368) - local
- [markToolgunFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:390) - local
- [markReloadFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:394) - local
- [playNoEffectFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:398) - local
- [canCommitState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:402) - local
- [resetSessionConVars](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:410) - local
- [performClientReload](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:422) - local
- [resetClientSession](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:444) - local
- [validateClientState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:448) - local
- [client.setPlayerViewAngles](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:464) - member/global
- [TOOL:LeftClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:476) - member/global
- [TOOL:RightClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:498) - member/global
- [TOOL:Reload](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:517) - member/global
- [hook.Add AllowPlayerPickup / MagicAlignBlockUsePickup](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_actions.lua:537) - hook callback

#### [lua/magic_align/client/tool_session.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua) (1516 Zeilen, 85 Funktionen)
- [registerSessionState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:52) - local
- [ensureStateShape](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:62) - local
- [ensureRegisteredStateShape](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:85) - local
- [stateBySessionId](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:101) - local
- [state](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:121) - local
- [core.queueClientLeftClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:131) - member/global
- [comp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:138) - local
- [setVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:149) - local
- [setAng](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:160) - local
- [normalizedVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:171) - local
- [clientNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:175) - local
- [exactNormalKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:199) - local
- [buildTraceSample](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:210) - local
- [sampleWorldPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:245) - local
- [sampleLocalPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:255) - local
- [sampleLocalNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:260) - local
- [aggregateTraceProbes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:264) - local
- [buildTraceProbeCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:329) - local
- [ghostAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:352) - local
- [linkedGhostAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:356) - local
- [handlerVisualScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:364) - local
- [applyGhostScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:376) - local
- [angleApprox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:438) - local
- [revisionValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:447) - local
- [resizeRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:474) - local
- [primitiveRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:497) - local
- [mirrorBoundsRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:526) - local
- [boundsRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:530) - local
- [resetBoundsEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:548) - local
- [refreshBoundsEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:562) - local
- [maybeRefreshBoundsEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:581) - local
- [linkedPropIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:599) - local
- [isLinkedProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:609) - local
- [removeLinkedGhost](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:613) - local
- [resetLinkedProps](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:623) - local
- [removeLinkedProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:644) - local
- [cleanupLinkedProps](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:654) - local
- [cleanupTargetPointReferences](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:676) - local
- [commitMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:706) - local
- [targetDisplayLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:722) - local
- [updateToolHelp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:730) - local
- [ensureGhostModel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:770) - local
- [applyGhostAppearance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:800) - local
- [hideGhosts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:881) - local
- [hook.Add Think / MagicAlignHideGhostsWhenInactive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:898) - hook callback
- [restoreSmartSnap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:913) - local
- [shouldSuppressSmartSnap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:926) - local
- [updateSmartSnapSuppression](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:934) - local
- [ringCoords](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:959) - local
- [ringAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:969) - local
- [ringRotationDeltaSign](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:974) - local
- [clampRotationSnapIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:981) - local
- [clampTranslationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:985) - local
- [rotationSnapDivisions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:989) - local
- [rotationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:994) - local
- [translationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:999) - local
- [normalizeDegrees](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1003) - local
- [snapRotationAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1013) - local
- [isAngleMultiple](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1021) - local
- [isMajorRotationTick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1026) - local
- [readClientActionTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1030) - local
- [clientActionWouldAffect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1050) - local
- [playClientActionFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1062) - local
- [core.consumeClientActionFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1090) - member/global
- [net.Receive M.NET_CLIENT_ACTION](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1100) - net callback
- [net.Receive M.NET_BOUNDS_REPLY](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1123) - net callback
- [boundsEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1159) - local
- [requestBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1181) - local
- [boundsFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1203) - local
- [activeTool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1209) - local
- [uiBlocked](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1218) - local
- [cycleReferenceSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1222) - local
- [setReferenceSpaceSelectorHeld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1253) - local
- [referenceSpaceSelectorDown](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1264) - local
- [wheelReferenceSpaceStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1269) - local
- [referenceSpaceSelectorReleased](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1274) - local
- [withReferenceSpaceDirectionModifiers](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1278) - local
- [hook.Add PlayerBindPress / MagicAlignCycleReferenceSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1286) - hook callback
- [net.Receive M.NET_COMMIT_RESULT](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1323) - net callback
- [restoreSessionOnUndoEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1351) - local
- [applyRestoredOffsets](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1356) - local
- [applyRestoredAnchorSide](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1381) - local
- [applyRestoredAnchors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1399) - local
- [applyUndoSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1405) - local
- [net.Receive M.NET_UNDO_RESTORE](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:1430) - net callback

#### [lua/magic_align/client/tool_offsets.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua) (1245 Zeilen, 53 Funktionen)
- [cfg](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:23) - local
- [registerOffsetChangeCallbacks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:73) - local
- [currentFrameNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:105) - local
- [pointWorldCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:109) - local
- [anchorResultCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:121) - local
- [offsetFormulaRevisionsChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:133) - local
- [effectiveOffsetValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:169) - local
- [cachedOffsets](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:179) - local
- [cachedAnchorOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:237) - local
- [setValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:261) - local
- [completeAnchorOrder](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:265) - local
- [tryAdd](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:269) - local
- [priorityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:293) - local
- [highestAvailableAnchor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:305) - local
- [syncPreferredAnchor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:313) - local
- [refreshPreferredAnchors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:349) - local
- [selectedAnchorState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:354) - local
- [gridStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:366) - local
- [pickGridDivisions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:371) - local
- [snapToGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:383) - local
- [faceAxisLength](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:395) - local
- [traceOnlyEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:407) - local
- [rayBoxFaceHit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:424) - local
- [projectFacePointToProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:486) - local
- [localAimRay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:527) - local
- [fallbackFaceAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:541) - local
- [resolveFaceHit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:559) - local
- [buildFacePlane](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:576) - local
- [resetSnapFaceOutput](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:623) - local
- [writeSnapFaceGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:646) - local
- [buildSnapFaceGridDescriptor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:664) - local
- [snapFaceCoordinates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:689) - local
- [faceLocalPosAndOrigin](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:761) - local
- [faceCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:771) - local
- [client.worldBspTraceEntityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:855) - member/global
- [client.worldBspTraceEntityClass](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:861) - member/global
- [client.worldBspTraceEntityModel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:869) - member/global
- [client.worldBspCandidateCacheStatusToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:877) - member/global
- [client.worldBspCandidateCacheSameTraceVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:890) - member/global
- [client.storeWorldBspCandidateCacheTraceVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:902) - member/global
- [client.worldBspCandidateCacheMatches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:914) - member/global
- [client.storeWorldBspCandidateCacheEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:948) - member/global
- [client.lookupWorldBspCandidateCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:994) - member/global
- [client.clearWorldBspCandidateCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1008) - member/global
- [worldCandidateFromTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1014) - local
- [client.worldBspBlockerClass](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1060) - member/global
- [client.isWorldBspTraceBlocker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1065) - member/global
- [client.clearWorldBspTraceScratchList](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1081) - member/global
- [client.finishWorldBspTraceScratchList](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1087) - member/global
- [client.addWorldBspTraceBlocker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1097) - member/global
- [client.worldBspBlockerTraceStartAndDirection](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1127) - member/global
- [client.addWorldBspBaseBlockerTraceFilter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1147) - member/global
- [client.worldBspTraceThroughBlockers](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:1159) - member/global

#### [lua/magic_align/client/tool_interaction.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua) (814 Zeilen, 33 Funktionen)
- [useCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:66) - local
- [playQueuedClientActionFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:90) - local
- [client.Press.hoverPickCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:102) - member/global
- [client.Press.drawCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:109) - member/global
- [client.Press.pickCandidateForPress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:123) - member/global
- [client.Press.beginPick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:140) - member/global
- [client.Press.beginGizmoDrag](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:166) - member/global
- [client.Press.setReferencePositionFromGizmoCoords](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:225) - member/global
- [client.Press.updateGizmo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:243) - member/global
- [client.Formula.formatEnvironmentValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:302) - member/global
- [client.Formula.boundsSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:314) - member/global
- [client.Formula.addVariable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:332) - member/global
- [client.Formula.addConstants](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:351) - member/global
- [client.Formula.angleComponent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:358) - member/global
- [client.Formula.addEntityVariables](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:382) - member/global
- [client.Formula.anchorPointSet](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:403) - member/global
- [client.Formula.distance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:416) - member/global
- [client.Formula.triangleAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:424) - member/global
- [client.Formula.addAnchorDistanceVariables](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:444) - member/global
- [addDistance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:447) - local
- [client.Formula.addAnchorAngleVariables](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:464) - member/global
- [addAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:467) - local
- [client.Formula.addCrossAnchorDistanceVariables](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:481) - member/global
- [client.Formula.entitySignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:504) - member/global
- [client.getFormulaEnvironment](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:531) - assigned
- [pressState.updatePick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:598) - member/global
- [pressState.updateActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:637) - member/global
- [pressState.beginMouse](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:655) - member/global
- [pressState.finalCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:677) - member/global
- [pressState.applyCompletedPick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:685) - member/global
- [pressState.finishMouse](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:707) - member/global
- [hook.Add EntityRemoved / magic_align_reset_session_on_prop_remove](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:721) - hook callback
- [TOOL:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:731) - member/global

#### [lua/magic_align/client/tool_gizmo.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua) (528 Zeilen, 17 Funktionen)
- [hoverPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:30) - local
- [targetPointPressActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:61) - local
- [cornerCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:71) - local
- [referenceBasisFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:136) - local
- [gizmoBasisFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:157) - local
- [gizmoShared.sizeForProp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:180) - member/global
- [gizmoShared.setVecComponents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:188) - member/global
- [gizmoShared.setOffsetVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:197) - member/global
- [gizmoShared.setOffsetVec2](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:209) - member/global
- [gizmoShared.handle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:222) - member/global
- [gizmoShared.copyHandle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:240) - member/global
- [gizmoShared.metricsForSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:258) - member/global
- [gizmoShared.linearHandles](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:269) - member/global
- [gizmoShared.pickHoveredHandle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:325) - member/global
- [gizmoShared.linearDragNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:373) - member/global
- [gizmoShared.translationLocalPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:405) - member/global
- [gizmo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_gizmo.lua:439) - local

#### [lua/magic_align/client/gizmo_snap.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua) (458 Zeilen, 24 Funktionen)
- [comp](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:17) - local
- [setVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:21) - local
- [normalizedVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:32) - local
- [client.axisVectorForKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:36) - member/global
- [markSnapAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:46) - local
- [mergeSnapAxes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:52) - local
- [applyHandleSnap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:68) - local
- [handleUsesAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:108) - local
- [snapTranslationValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:120) - local
- [snapGizmoTranslation](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:130) - local
- [applyAxisSnap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:149) - local
- [worldToGizmoLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:166) - local
- [gizmoWorldOrigin](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:173) - local
- [gizmoTraceDirectionForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:183) - local
- [gizmoTraceFilter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:200) - local
- [traceSnapStartWorldPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:238) - local
- [traceSnapWorldPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:242) - local
- [traceSnapAxisResult](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:269) - local
- [traceSnapFromGizmo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:310) - local
- [snapAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:339) - local
- [candidateIsDirectGizmoSnapTarget](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:375) - local
- [client.snapGizmoPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:380) - member/global
- [snapToTranslation](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:387) - local
- [snapToWorldPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/gizmo_snap.lua:394) - local

#### [lua/magic_align/client/tool_preview.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua) (1431 Zeilen, 44 Funktionen)
- [clearHover](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:57) - local
- [markPointSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:77) - local
- [markPoseSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:129) - local
- [markLinkedSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:153) - local
- [client.markMirrorSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:175) - member/global
- [client.markTargetReferenceSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:217) - member/global
- [previewInputsChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:250) - local
- [markVecSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:272) - local
- [markPendingCandidateSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:287) - local
- [pendingPreviewInputsChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:321) - local
- [client.Mirror.pendingPreviewInputsChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:345) - member/global
- [markPreviewChangedFrame](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:377) - local
- [client.activeSpaceForTool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:382) - member/global
- [client.Mirror.state](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:388) - member/global
- [client.Mirror.isActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:395) - member/global
- [client.Mirror.syncEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:404) - member/global
- [client.Mirror.cache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:411) - member/global
- [client.Mirror.resolve](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:415) - member/global
- [client.Mirror.reference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:442) - member/global
- [client.Mirror.classificationLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:451) - member/global
- [client.Mirror.handleModifierToggle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:456) - member/global
- [client.Mirror.entityMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:470) - member/global
- [client.Mirror.previewEntityMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:477) - member/global
- [copyMirrorReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:483) - local
- [pointReferenceEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:497) - local
- [mirrorWorldPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:503) - local
- [client.Mirror.migrateCommittedPrimitivePoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:510) - member/global
- [rebasePrimitivePointByPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:526) - local
- [rebasePrimitivePointList](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:557) - local
- [client.Mirror.rebasePrimitivePointsForUndo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:573) - member/global
- [applyMirrorAxisToLocalPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:600) - local
- [client.Mirror.sourceAnchorLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:617) - member/global
- [client.Mirror.previewSolve](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:646) - member/global
- [client.Mirror.applyPreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:680) - member/global
- [client.Mirror.displayContext](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:721) - member/global
- [client.Mirror.previewInputsChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:740) - member/global
- [solvePreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:771) - local
- [ensureGhost](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:922) - local
- [hoverState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1015) - local
- [pointFromCandidateInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1159) - local
- [copyPointIntoPendingScratch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1191) - local
- [copyPendingPointList](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1213) - local
- [invalidatePendingPreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1229) - local
- [pendingPreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_preview.lua:1239) - local

#### [lua/magic_align/client/world_points.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua) (881 Zeilen, 52 Funktionen)
- [setVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:37) - local
- [normalizedVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:48) - local
- [targetPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:52) - local
- [mirrorActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:56) - local
- [mirrorState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:60) - local
- [mirrorPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:71) - local
- [activePointKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:76) - local
- [isPointKindActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:82) - local
- [sideForKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:92) - local
- [pointsForKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:96) - local
- [selectionStore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:106) - local
- [selectedFallbackEnt](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:116) - local
- [pointWorldCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:126) - local
- [pointWorldPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:138) - local
- [selectedIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:155) - local
- [setSelectedIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:173) - local
- [pressPointKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:211) - local
- [pressPointIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:225) - local
- [clearPointPress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:230) - local
- [adjustPressIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:240) - local
- [selectedPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:275) - local
- [referenceForPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:282) - local
- [pointFromWorldPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:290) - local
- [updatePoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:319) - local
- [updatePointFromCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:336) - local
- [gizmoSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:357) - local
- [worldBasis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:365) - local
- [pointGizmoBasis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:369) - local
- [modifierState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:387) - local
- [buildGizmo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:391) - local
- [beginPointPress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:470) - local
- [beginPointGizmoDrag](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:507) - local
- [traceSnapNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:576) - local
- [updatePointGizmoDrag](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:583) - local
- [altStateStore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:624) - local
- [hoverReferenceForToggle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:632) - local
- [hoverStableForToggle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:655) - local
- [worldPoints.clearSelection](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:669) - member/global
- [worldPoints.getSelectedIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:673) - member/global
- [worldPoints.isSelected](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:677) - member/global
- [worldPoints.toggleSelection](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:681) - member/global
- [worldPoints.hasToggleHint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:696) - member/global
- [worldPoints.handleModifierToggle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:701) - member/global
- [sanitizePointKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:735) - local
- [worldPoints.sanitizeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:761) - member/global
- [worldPoints.onPointRemoved](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:768) - member/global
- [worldPoints.onTargetPointRemoved](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:790) - member/global
- [worldPoints.getGizmo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:794) - member/global
- [worldPoints.shouldSuppressDefaultGizmo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:803) - member/global
- [worldPoints.beginMousePress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:813) - member/global
- [worldPoints.updateActivePress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:832) - member/global
- [worldPoints.handleMouseRelease](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_points.lua:875) - member/global

#### [lua/magic_align/client/geometry.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua) (197 Zeilen, 15 Funktionen)
- [normalizedVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:18) - local
- [worldIdentityPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:22) - local
- [worldIdentityAng](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:26) - local
- [entityBasePos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:30) - local
- [entityBaseAng](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:38) - local
- [geometry.isWorldTarget](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:46) - member/global
- [geometry.hasTargetEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:50) - member/global
- [geometry.traceHitsWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:54) - member/global
- [geometry.traceMatchesEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:62) - member/global
- [geometry.worldPosFromLocalPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:72) - member/global
- [geometry.localPointFromWorldPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:89) - member/global
- [geometry.localNormalFromWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:106) - member/global
- [geometry.worldNormalFromLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:129) - member/global
- [geometry.pointFromCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:153) - member/global
- [geometry.traceCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/geometry.lua:179) - member/global

<a id="pfad-4"></a>
## Pfad 4: Tool-Bootstrap und Ladegrenzen

Relevanz: Klein, aber wichtig: bestimmt, welche Module server/client geladen werden und welche ConVars existieren.

### Kernfluss

- [TOOL:LeftClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:61) - Magic-Mirror Klick-Bridge
- [TOOL.BuildCPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:119) - Magic-Mirror Control Panel

### Dateien

- [lua/weapons/gmod_tool/stools/magic_align.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/weapons/gmod_tool/stools/magic_align.lua) - 69 Zeilen, 0 Funktionseintraege
- [lua/weapons/gmod_tool/stools/magic_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/weapons/gmod_tool/stools/magic_mirror.lua) - 44 Zeilen, 0 Funktionseintraege
- [lua/magic_align/magic_mirror_tool_setup.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua) - 142 Zeilen, 6 Funktionseintraege

### Funktionen

#### [lua/weapons/gmod_tool/stools/magic_align.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/weapons/gmod_tool/stools/magic_align.lua) (69 Zeilen, 0 Funktionen)
- Keine eigene Funktionsdefinition; Loader/Include-Datei.

#### [lua/weapons/gmod_tool/stools/magic_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/weapons/gmod_tool/stools/magic_mirror.lua) (44 Zeilen, 0 Funktionen)
- Keine eigene Funktionsdefinition; Loader/Include-Datei.

#### [lua/magic_align/magic_mirror_tool_setup.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua) (142 Zeilen, 6 Funktionen)
- [writeClientActionTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:18) - local
- [sendMirrorClientAction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:39) - local
- [playFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:48) - local
- [TOOL:LeftClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:61) - member/global
- [TOOL:RightClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:84) - member/global
- [TOOL.BuildCPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror_tool_setup.lua:119) - member/global

<a id="pfad-5"></a>
## Pfad 5: Mirror und Entity-Mirror

Relevanz: Sehr fehleranfaellig: negative Achsen, Bounds, Primitive/Resize-Kompatibilitaet und visuelle Client-Synchronisierung.

### Kernfluss

- [M.ResolveMirrorState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:547) - klassifiziert Mirror-Punkte
- [M.MirrorPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:700) - spiegelt Pose an Punkt/Achse/Ebene
- [M.MirrorEntityPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:732) - kombiniert Pose mit EntityMirror-Achse
- [EntityMirror.ComposeAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:110) - komponiert gespeicherte Flip-Achsen
- [EntityMirror.PositionForInPlaceAxisChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:538) - korrigiert Pivot/Position
- [targetPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:149) - direktes Magic-Mirror-Ziel, exportiert als `MagicMirror.TargetPose`
- [updateHover](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:205) - waehlt Mirror-Zone
- [buildPayload](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:255) - nutzt denselben Commit-Pfad
- [TOOL:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:360) - Magic-Mirror Runtime

### Dateien

- [lua/magic_align/mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua) - 816 Zeilen, 43 Funktionseintraege
- [lua/magic_align/entity_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua) - 2944 Zeilen, 186 Funktionseintraege
- [lua/magic_align/magic_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua) - 210 Zeilen, 12 Funktionseintraege
- [lua/magic_align/client/magic_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua) - 390 Zeilen, 22 Funktionseintraege
- [lua/magic_align/client/magic_mirror_render.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua) - 248 Zeilen, 14 Funktionseintraege
- [lua/magic_align/client/magic_mirror_toolgun.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua) - 223 Zeilen, 13 Funktionseintraege

### Funktionen

#### [lua/magic_align/mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua) (816 Zeilen, 43 Funktionen)
- [numberOrZero](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:14) - local
- [mirrorLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:23) - local
- [setVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:33) - local
- [copyVecInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:42) - local
- [clearVectorList](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:47) - local
- [distSqr](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:53) - local
- [dot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:60) - local
- [subtractInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:66) - local
- [scaleInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:75) - local
- [addScaledInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:80) - local
- [crossInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:101) - local
- [normalizeInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:108) - local
- [projectOntoPlaneInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:117) - local
- [localToWorldPosInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:131) - local
- [resolvedReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:152) - local
- [resolvePointWorldInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:156) - local
- [markPointSignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:186) - local
- [clearStaleSignatures](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:225) - local
- [farthestPair](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:248) - local
- [planeAxesInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:263) - local
- [updateMidpoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:287) - local
- [updatePlaneRenderData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:307) - local
- [clearReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:366) - local
- [classifyCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:379) - local
- [copyReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:500) - local
- [M.IsMirrorMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:528) - member/global
- [M.GetMirrorStateCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:536) - member/global
- [M.ResolveMirrorState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:547) - member/global
- [M.ResolveMirrorWorldPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:598) - member/global
- [M.ClassifyMirrorReferenceFromWorldPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:614) - member/global
- [M.ClassifyMirrorReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:622) - member/global
- [mirrorVectorAcrossPlane](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:630) - local
- [mirrorVectorAroundAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:634) - local
- [repairedAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:638) - local
- [entityMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:643) - local
- [referenceMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:649) - local
- [composeEntityMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:653) - local
- [remainingMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:657) - local
- [angleLocalAxisWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:672) - local
- [bakeEntityMirrorComposition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:684) - local
- [M.MirrorPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:700) - member/global
- [M.MirrorEntityPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:732) - member/global
- [M.ApplyTransformModeToPropSet](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/mirror.lua:745) - member/global

#### [lua/magic_align/entity_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua) (2944 Zeilen, 186 Funktionen)
- [validAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:55) - local
- [validFlags](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:65) - local
- [EntityMirror.IsMirrored](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:72) - member/global
- [EntityMirror.AxisLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:76) - member/global
- [EntityMirror.Sanitize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:84) - member/global
- [EntityMirror.AxisForMirrorReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:98) - member/global
- [EntityMirror.ComposeAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:110) - member/global
- [EntityMirror.ComposeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:123) - member/global
- [EntityMirror.StateAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:132) - member/global
- [axisSigns](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:137) - local
- [setVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:144) - local
- [EntityMirror.AxisSigns](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:155) - member/global
- [EntityMirror.ApplyAxisToVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:159) - member/global
- [EntityMirror.ApplyAxisToPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:171) - member/global
- [EntityMirror.ScaleForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:182) - member/global
- [EntityMirror.AxisForEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:188) - member/global
- [EntityMirror.LocalPointToWorldForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:193) - member/global
- [EntityMirror.WorldPointToLocalForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:201) - member/global
- [EntityMirror.LocalVectorToWorldForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:211) - member/global
- [EntityMirror.WorldVectorToLocalForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:219) - member/global
- [EntityMirror.LocalPointToWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:229) - member/global
- [EntityMirror.WorldPointToLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:234) - member/global
- [EntityMirror.LocalVectorToWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:239) - member/global
- [EntityMirror.WorldVectorToLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:244) - member/global
- [scaleIsIdentity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:249) - local
- [scaleIsZero](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:258) - local
- [scaleApprox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:267) - local
- [copyScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:276) - local
- [stripAxisSign](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:292) - local
- [applyAxisSign](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:308) - local
- [liveSizeHandlerScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:318) - local
- [preferLiveResizeScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:329) - local
- [optionResizeScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:338) - local
- [captureResizeScales](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:345) - local
- [syncLiveSizeHandlerScales](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:364) - local
- [ensureStoredResizeScales](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:379) - local
- [physicsScaleFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:400) - local
- [liveSizeHandlerVisualScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:410) - local
- [resizeVisualScaleFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:414) - local
- [visualScaleFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:431) - local
- [scaleKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:436) - local
- [captureCollisionBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:441) - local
- [captureRenderBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:459) - local
- [boundsCenter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:472) - local
- [captureLocalBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:481) - local
- [localBoundsCenter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:492) - local
- [axisPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:497) - local
- [EntityMirror.LocalBoundsCenter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:508) - member/global
- [EntityMirror.BaseMirrorPivot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:512) - member/global
- [EntityMirror.LocalPivotForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:520) - member/global
- [EntityMirror.PositionForLocalPivot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:524) - member/global
- [EntityMirror.PositionForInPlaceAxisChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:538) - member/global
- [scaledBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:560) - local
- [EntityMirror.BoundsForAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:574) - member/global
- [EntityMirror.BoundsAxisForEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:581) - member/global
- [EntityMirror.BoundsInBaseSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:601) - member/global
- [EntityMirror.RevisionForEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:606) - member/global
- [EntityMirror.BoundsRevisionForEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:611) - member/global
- [convexBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:625) - local
- [setLocalBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:653) - local
- [setCollisionBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:669) - local
- [setRenderBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:673) - local
- [setPhysicsRenderBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:677) - local
- [physicsConvexes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:681) - local
- [scaledConvexes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:690) - local
- [EntityMirror.DebugEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:735) - member/global
- [debugVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:747) - local
- [debugAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:753) - local
- [debugBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:759) - local
- [debugValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:765) - local
- [primitiveDebugResult](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:775) - local
- [debugPrimitiveBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:792) - local
- [EntityMirror.DebugEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:806) - member/global
- [EntityMirror.DebugConvexes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:874) - member/global
- [concommand.Add magic_align_mirror_debug_target](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:889) - concommand callback
- [concommand.Add magic_align_mirror_debug_state](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:902) - concommand callback
- [EntityMirror.GetAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:962) - member/global
- [EntityMirror.GetFlags](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:978) - member/global
- [actualPhysicsAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:997) - local
- [EntityMirror.PhysicsAxisForEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1001) - member/global
- [setActualPhysicsAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1005) - local
- [physicsState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1011) - local
- [applyPhysicsState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1029) - local
- [finishPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1052) - local
- [scratchFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1071) - local
- [primitiveConstruct](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1081) - local
- [rebuildPrimitiveBase](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1091) - local
- [initStockModelPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1114) - local
- [rebuildModelPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1126) - local
- [rebuildPrimitivePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1170) - local
- [rebuildPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1214) - local
- [EntityMirror.ApplyPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1228) - member/global
- [EntityMirror.RestorePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1241) - member/global
- [networkState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1248) - local
- [storeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1264) - local
- [EntityMirror.SetState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1275) - member/global
- [physicsOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1290) - local
- [EntityMirror.ApplyDelta](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1351) - member/global
- [EntityMirror.Capture](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1358) - member/global
- [EntityMirror.Restore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1367) - member/global
- [EntityMirror.ApplyFromBaseState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1379) - member/global
- [scheduleModifierStateReapply](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1410) - local
- [hook.Add Primitive_PostRebuildPhysics / MagicAlignEntityMirrorPrimitivePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1432) - hook callback
- [stateFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1461) - local
- [desiredAxes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1481) - local
- [EntityMirror.PhysicsAxisForEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1502) - member/global
- [truthy](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1518) - local
- [advResizerClientPhysicsDisabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1533) - local
- [clientStateExtra](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1541) - local
- [debugClientEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1590) - local
- [hasBootstrapNetworkState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1597) - local
- [scheduleInitialReconcile](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1605) - local
- [clientPhysicsScratch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1637) - local
- [primitiveResult](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1647) - local
- [primitiveConvexes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1652) - local
- [mirroredClientConvexes](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1661) - local
- [pinClientPhysicsTransform](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1669) - local
- [refreshActiveClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1686) - local
- [markPhysicsPending](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1694) - local
- [clearPhysicsPending](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1699) - local
- [claimOwnedClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1704) - local
- [markOwnedClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1713) - local
- [clearOwnedClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1718) - local
- [finishClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1727) - local
- [initClientStockPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1745) - local
- [buildClientModelPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1757) - local
- [rebuildClientModelBaselinePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1805) - local
- [shouldEnsureClientBaselinePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1839) - local
- [hasExplicitMirrorNetworkState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1850) - local
- [ensureClientBaselinePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1858) - local
- [restoreOwnedPrimitiveBaseline](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1895) - local
- [releaseOwnedClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1922) - assigned
- [applyOwnedModelPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1988) - local
- [applyOwnedPrimitivePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2016) - local
- [applyOwnedClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2067) - local
- [reconcileClientPhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2080) - local
- [setRenderMatrix](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2096) - local
- [mirrorRenderOverride](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2136) - local
- [enableRenderOverride](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2149) - local
- [disableRenderOverride](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2160) - local
- [renderMatrixNeedsSync](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2168) - local
- [visualNeedsSync](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2184) - local
- [restoreVisualRenderBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2198) - local
- [applyVisualRenderBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2209) - local
- [EntityMirror.ApplyVisual](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2228) - member/global
- [applyVisualState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2250) - local
- [predictionVisualAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2264) - local
- [sizeHandlerParent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2272) - local
- [scheduleSizeHandlerVisualRefresh](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2280) - local
- [normalizedCommitId](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2330) - local
- [unlinkVisualPrediction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2340) - local
- [clearVisualPrediction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2354) - local
- [scheduleVisualPredictionExpiry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2361) - assigned
- [EntityMirror.PredictVisual](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2380) - member/global
- [EntityMirror.ResolveVisualPrediction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2410) - member/global
- [EntityMirror.ApplyVisualPreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2443) - member/global
- [EntityMirror.ApplyVisualCullPreview](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2476) - member/global
- [reconcileEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2500) - assigned
- [maintainActiveVisual](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2554) - local
- [queueEntityNetworkInit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2580) - local
- [bootstrapKnownEntities](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2595) - local
- [hook.Add EntityNetworkedVarChanged / MagicAlignEntityMirrorNetworked](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2601) - hook callback
- [hook.Add NetworkEntityCreated / MagicAlignEntityMirrorCreated](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2618) - hook callback
- [hook.Add NotifyShouldTransmit / MagicAlignEntityMirrorTransmit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2622) - hook callback
- [hook.Add InitPostEntity / MagicAlignEntityMirrorInitialState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2628) - hook callback
- [hook.Add EntityRemoved / MagicAlignEntityMirrorRemoved](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2636) - hook callback
- [hook.Add Primitive_PostRebuildPhysics / MagicAlignEntityMirrorClientPrimitivePhysics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2646) - hook callback
- [hook.Add Think / MagicAlignEntityMirrorActiveState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2661) - hook callback
- [rayMetrics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2688) - local
- [traceCandidateRadius](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2700) - local
- [addTraceCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2709) - local
- [collectTraceCandidates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2728) - local
- [debugTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2749) - local
- [concommand.Add magic_align_mirror_debug_trace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2800) - concommand callback
- [debugCommandEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2804) - local
- [concommand.Add magic_align_mirror_debug_ent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2818) - concommand callback
- [concommand.Add magic_align_mirror_debug_refresh_ent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2829) - concommand callback
- [mirroredEditor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2840) - local
- [updatePrimitiveEditorWindow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2846) - local
- [drawEditorBox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2871) - local
- [patchPrimitiveEditor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2876) - local
- [panel.SetupWindow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2884) - assigned
- [window.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2892) - assigned
- [window.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2919) - assigned
- [panel.SetEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2927) - assigned
- [hook.Add Think / MagicAlignEntityMirrorPrimitiveEditorPatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2937) - hook callback

#### [lua/magic_align/magic_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua) (210 Zeilen, 12 Funktionen)
- [sanitizeAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:19) - local
- [axisLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:28) - local
- [composeAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:36) - local
- [currentEntityAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:40) - local
- [remainingAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:44) - local
- [faceUAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:58) - local
- [faceVAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:64) - local
- [clamp01](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:70) - local
- [classifyFaceZone](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:74) - local
- [classifyCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:129) - local
- [localAxisWorld](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:136) - local
- [targetPose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/magic_mirror.lua:149) - local

#### [lua/magic_align/client/magic_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua) (390 Zeilen, 22 Funktionen)
- [playFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:16) - local
- [shapeMirrorState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:29) - local
- [newMirrorState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:51) - local
- [ensureState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:63) - local
- [mirrorClient.state](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:80) - member/global
- [removeMirrorGhosts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:84) - local
- [dropHoverTarget](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:106) - local
- [mirrorClient.reset](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:112) - member/global
- [activeToolState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:127) - local
- [mirrorSettings](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:140) - local
- [updateTargetPoseForZone](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:165) - local
- [updateHover](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:205) - local
- [buildSessionSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:244) - local
- [buildPayload](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:255) - local
- [commit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:303) - local
- [mirrorClient.queueClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:324) - member/global
- [mirrorClient.handleClientAction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:332) - member/global
- [consumeQueuedClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:342) - local
- [TOOL:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:360) - member/global
- [TOOL:Holster](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:368) - member/global
- [hook.Add Think / MagicMirrorCleanupGhostWhenInactive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:374) - hook callback
- [hook.Add EntityRemoved / MagicMirrorResetOnPropRemove](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror.lua:383) - hook callback

#### [lua/magic_align/client/magic_mirror_render.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua) (248 Zeilen, 14 Funktionen)
- [localFacePoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:26) - local
- [worldPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:36) - local
- [copyLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:43) - local
- [setAxisValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:49) - local
- [axisRange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:59) - local
- [centeredArrowSegmentLocal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:72) - local
- [fillBoundsCorners](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:96) - local
- [drawBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:107) - local
- [facePolygon](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:121) - local
- [drawFaceOutline](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:169) - local
- [drawZone](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:182) - local
- [drawMirrorArrow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:202) - local
- [activeMirrorState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:221) - local
- [hook.Add PostDrawTranslucentRenderables / MagicMirrorDrawAABBZones](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_render.lua:230) - hook callback

#### [lua/magic_align/client/magic_mirror_toolgun.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua) (223 Zeilen, 13 Funktionen)
- [solid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:24) - local
- [cachedColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:33) - local
- [colorAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:50) - local
- [ensureFonts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:55) - local
- [widestText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:95) - local
- [pickValueFont](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:107) - local
- [commitUploadProgress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:121) - local
- [drawBackdrop](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:128) - local
- [activeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:159) - local
- [activeHover](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:169) - local
- [axisLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:176) - local
- [drawAxisCard](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:183) - local
- [TOOL:DrawToolScreen](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/magic_mirror_toolgun.lua:211) - member/global

<a id="pfad-6"></a>
## Pfad 6: World-Target, World-BSP, Grid-Snap, BSP-Cache

Relevanz: Performance- und Map-abhaengig: BSP-Lesen, Oberflaechenindex, Grid-Kandidaten und persistenter Cache.

### Kernfluss

- [worldBSP.update](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2429) - startet/treibt Cache-Aufbau
- [startBuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2410) - erstellt Build-Coroutine
- [buildWorker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2342) - liest/indiziert Surfaces
- [worldBSP.candidateFromTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4667) - Trace -> Snap-Kandidat
- [worldBSP.buildFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4048) - bereitet Face/Grid vor
- [persistent.startLoad](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:992) - laedt persistenten Cache
- [persistent.saveCurrent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:579) - speichert persistenten Cache

### Dateien

- [lua/magic_align/client/world_bsp_reader.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua) - 297 Zeilen, 21 Funktionseintraege
- [lua/magic_align/client/world_bsp_records.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua) - 732 Zeilen, 27 Funktionseintraege
- [lua/magic_align/client/world_bsp_cache.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua) - 1032 Zeilen, 32 Funktionseintraege
- [lua/magic_align/client/world_bsp.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua) - 4948 Zeilen, 245 Funktionseintraege
- [lua/magic_align/client/render/world_grid_light.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua) - 184 Zeilen, 10 Funktionseintraege
- [lua/magic_align/client/render/hover_grid.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua) - 612 Zeilen, 43 Funktionseintraege
- [lua/magic_align/client/render/rotation_ticks.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua) - 115 Zeilen, 8 Funktionseintraege

### Funktionen

#### [lua/magic_align/client/world_bsp_reader.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua) (297 Zeilen, 21 Funktionen)
- [canRead](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:12) - local
- [byte](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:21) - local
- [readUInt16](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:25) - local
- [readInt16](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:31) - local
- [readUInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:37) - local
- [readInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:46) - local
- [reader.readFloat](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:52) - member/global
- [reader.readVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:71) - member/global
- [readCString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:81) - local
- [reader.readCurrentMapData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:95) - member/global
- [reader.readHeader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:110) - member/global
- [reader.lump](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:137) - member/global
- [reader.lumpCount](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:141) - member/global
- [reader.lumpIsReadable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:148) - member/global
- [reader.lumpIsCompressed](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:153) - member/global
- [reader.requiredDisplacementLumpsReadable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:160) - member/global
- [reader.readVertex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:184) - member/global
- [reader.readFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:193) - member/global
- [reader.readFaceVertices](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:209) - member/global
- [reader.readTextureName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:240) - member/global
- [reader.readDispInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:280) - member/global

#### [lua/magic_align/client/world_bsp_records.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua) (732 Zeilen, 27 Funktionen)
- [finiteNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:32) - local
- [recordVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:38) - local
- [clampInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:43) - local
- [packUInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:50) - local
- [packInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:69) - local
- [readUInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:78) - local
- [readInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:85) - local
- [packFloat32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:98) - local
- [unpackFloat32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:148) - local
- [appendInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:170) - local
- [appendUInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:174) - local
- [appendFloat32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:178) - local
- [appendRecordVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:186) - local
- [readFloat32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:192) - local
- [readVectorP](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:204) - local
- [displacementHalfCode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:214) - local
- [displacementHalfFromCode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:221) - local
- [displacementDiagonalCode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:227) - local
- [displacementDiagonalFromCode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:236) - local
- [vectorFromRecord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:268) - local
- [recordPolygon](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:279) - local
- [polygonFromRecord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:295) - local
- [sourceFromRecord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:311) - local
- [worldBSP.surfaceCacheRecord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:326) - member/global
- [worldBSP.surfaceCacheBinaryRecord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:382) - member/global
- [worldBSP.surfaceFromCacheBinaryRecord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:445) - member/global
- [worldBSP.surfaceFromCacheRecord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:599) - member/global

#### [lua/magic_align/client/world_bsp_cache.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua) (1032 Zeilen, 32 Funktionen)
- [now](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:35) - local
- [currentMap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:39) - local
- [cachePathForMap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:43) - local
- [openCacheFileForWrite](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:49) - local
- [cacheBinary](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:53) - local
- [maybeYield](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:78) - local
- [appendUInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:84) - local
- [appendInt32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:88) - local
- [appendString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:92) - local
- [crcString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:98) - local
- [readString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:103) - local
- [mapBspPath](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:118) - local
- [persistent.currentMapFingerprint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:122) - member/global
- [fingerprintMatches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:154) - local
- [headerMatches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:178) - local
- [buildMainHeader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:186) - local
- [buildPreHeader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:209) - local
- [readPreHeader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:237) - local
- [readMainHeader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:305) - local
- [buildSectionTable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:361) - local
- [readSectionTable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:377) - local
- [payloadChecksumMatches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:436) - local
- [requiredSection](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:448) - local
- [readCacheData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:458) - local
- [collectDisplacementGroups](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:515) - local
- [countNeighborLinks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:543) - local
- [countGroupSurfaceLinks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:563) - local
- [persistent.saveCurrent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:579) - member/global
- [applyGroupToSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:784) - local
- [loadWorker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:799) - local
- [persistent.startLoad](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:992) - member/global
- [persistent.cachePath](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:1028) - member/global

#### [lua/magic_align/client/world_bsp.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua) (4948 Zeilen, 245 Funktionen)
- [now](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:118) - local
- [currentMap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:122) - local
- [resetCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:126) - local
- [readBudgetMs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:190) - local
- [shouldYield](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:195) - local
- [maybeYield](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:202) - local
- [safeSurfaceBool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:208) - local
- [visibleSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:213) - local
- [copyVertices](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:219) - local
- [computeNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:247) - local
- [projectedAxisFromVertices](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:263) - local
- [hullCross2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:275) - local
- [hullEntryLess](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:279) - local
- [polygonArea2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:287) - local
- [orderSurfaceVertices](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:299) - local
- [pushHull](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:320) - local
- [longestEdgeAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:371) - local
- [expandBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:392) - local
- [surfaceUv](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:407) - local
- [surfaceUvFromComponents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:412) - local
- [setVectorComponents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:424) - local
- [worldFromUvInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:433) - local
- [worldFromUv](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:446) - local
- [worldAxisFromUv](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:450) - local
- [boundsDistanceSqr](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:464) - local
- [axisComponent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:477) - local
- [clampWorldGridStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:484) - local
- [worldGridStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:488) - local
- [usesGlobalGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:492) - local
- [worldBSP.usesGlobalGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:497) - member/global
- [worldBSP.shouldBuildCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:501) - member/global
- [cvarBool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:510) - local
- [cvarNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:516) - local
- [cvarString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:522) - local
- [worldBSP.currentClientSettings](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:528) - member/global
- [stopBackgroundUpdate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:548) - local
- [worldBSP.ensureBackgroundUpdate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:557) - member/global
- [buildGlobalFamilies](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:604) - local
- [familyPairDet](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:627) - local
- [familiesAreIndependent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:632) - local
- [addGlobalProjectionPair](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:636) - local
- [sortedHorizontalFamilies](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:657) - local
- [globalProjectionPairs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:669) - local
- [globalSnapPairs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:756) - local
- [pointOnSegment2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:797) - local
- [pointInPolygon2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:816) - local
- [closestPointOnSegment2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:842) - local
- [polygonEdgeDistance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:859) - local
- [buildSurfaceEdges](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:877) - local
- [addClippedRangeValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:910) - local
- [clippedLineRange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:928) - local
- [worldBSP.faceLineWorldPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:991) - member/global
- [surfaceMaterialName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1005) - local
- [buildSurfaceData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1023) - local
- [worldBSP.markCachedSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1137) - member/global
- [cellCoord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1144) - local
- [cellKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1148) - local
- [addToCell](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1152) - local
- [planeNormalCoord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1162) - local
- [planeDistanceCoord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1166) - local
- [planeBucketKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1170) - local
- [addToPlaneBucket](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1174) - local
- [indexSurfacePlane](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1188) - local
- [indexSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1200) - local
- [edgeCellCoord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1227) - local
- [edgeCellKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1231) - local
- [addEdgeToCell](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1235) - local
- [vertexCellCoord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1245) - local
- [vertexCellKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1249) - local
- [addVertexToCell](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1253) - local
- [indexSurfaceVertices](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1268) - local
- [edgeCellBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1291) - local
- [indexSurfaceEdges](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1301) - local
- [addSurfaceNeighbor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1324) - local
- [worldBSP.neighborBuild.surfacesAreNeighbors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1346) - member/global
- [worldBSP.setBuildStage](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1354) - member/global
- [worldBSP.updateBuildStage](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1365) - member/global
- [estimateRemainingFromFraction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1382) - local
- [estimateRemainingFromSample](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1390) - local
- [maxProgressEta](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1407) - local
- [worldBSP.cacheOverallProgress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1420) - member/global
- [worldBSP.cacheProgress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1467) - member/global
- [worldBSP.refreshCacheProgressSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1568) - member/global
- [worldBSP.cacheProgressSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1586) - member/global
- [worldBSP.formatProgressPercent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1590) - member/global
- [worldBSP.formatProgressSeconds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1595) - member/global
- [edgeIntervalsOverlap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1608) - local
- [edgesAreAdjacent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1619) - local
- [verticesAreAdjacent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1635) - local
- [worldBSP.neighborBuild.markCandidatePair](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1655) - member/global
- [worldBSP.neighborBuild.walkSurfaceEdgePairs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1670) - member/global
- [worldBSP.neighborBuild.walkSurfaceVertexPairs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1708) - member/global
- [worldBSP.neighborBuild.countCandidatePairs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1749) - member/global
- [worldBSP.neighborBuild.updateLinkProgress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1769) - member/global
- [worldBSP.neighborBuild.linkCandidatePairs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1774) - member/global
- [advance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1783) - local
- [linkEdgePair](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1788) - local
- [linkVertexPair](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1798) - local
- [buildDirectNeighborCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1820) - local
- [finishBuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1850) - local
- [worldBSP.entityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1881) - member/global
- [worldBSP.entityClass](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1889) - member/global
- [worldBSP.entityModel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1897) - member/global
- [worldBSP.isWorldBrushEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1905) - member/global
- [worldBSP.entityIdentity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1913) - member/global
- [readWorldBrushSurfaceSources](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1954) - local
- [addCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:1959) - local
- [nearestDisplacementStartCorner](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2014) - local
- [orderedDisplacementCorners](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2035) - local
- [displacementBasePoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2057) - local
- [displacementVertexPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2074) - local
- [buildDisplacementVertexGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2094) - local
- [displacementGridVertex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2118) - local
- [makeDisplacementSurfaceInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2122) - local
- [GetVertices](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2124) - assigned
- [GetMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2127) - assigned
- [addDisplacementTriangleSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2133) - local
- [addSourceDisplacementQuadTriangles](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2159) - local
- [appendDisplacementSurfacesForInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2213) - local
- [appendBspDisplacementSurfaces](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2271) - local
- [buildWorker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2342) - local
- [startBuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2410) - local
- [worldBSP.update](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2429) - member/global
- [worldBSP.isReady](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2478) - member/global
- [worldBSP.requestManualRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2482) - member/global
- [worldBSP.cacheStatusSummary](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2496) - member/global
- [addQueriedSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2533) - local
- [querySurfaces](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2544) - local
- [pointInsideWorldBoundsComponents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2581) - local
- [pointInsideWorldBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2591) - local
- [normalizedVectorFromComponents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2595) - local
- [traceRayInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2603) - local
- [signedPlaneDistance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2625) - local
- [writeTraceMatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2634) - local
- [traceHitsDisplacement](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2643) - local
- [useDisplacementTraceTolerances](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2647) - local
- [traceBoundsTolerance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2651) - local
- [tracePlaneTolerance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2657) - local
- [traceSurfacePickTolerance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2663) - local
- [traceNormalDotMin](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2669) - local
- [traceEdgeProjectionTolerance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2675) - local
- [traceRayPickTolerance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2681) - local
- [traceMatchIsDisplacement](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2687) - local
- [collectTracePlaneBucketSurfaces](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2696) - local
- [collectForNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2708) - local
- [selectSurfaceForTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2741) - local
- [findSurfaceForTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2889) - local
- [gridPointValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2922) - local
- [gridStepFromGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2932) - local
- [activeGridStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2946) - local
- [snapCandidateDistance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2967) - local
- [solveGlobalGridFamilies](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2973) - local
- [solveGlobalGridPair](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2987) - local
- [keepGlobalSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:2997) - local
- [globalPairSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3016) - local
- [globalLineSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3050) - local
- [configureGlobalFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3079) - local
- [snapGlobalFaceCoordinates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3088) - local
- [activeStepFromSnapped](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3121) - local
- [snapVisibilityEpsilon](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3138) - local
- [snapCandidateRank](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3147) - local
- [resetScratchArray](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3156) - local
- [nextScratchSlot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3168) - local
- [writeSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3181) - local
- [copySnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3201) - local
- [beginSnapSelector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3222) - local
- [emitSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3251) - local
- [addSurfaceAxisLine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3266) - local
- [collectSurfaceAxisLinesForGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3293) - local
- [collectSurfaceAxisLines](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3310) - local
- [emitSurfaceGridPointCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3318) - local
- [copySurfaceAxisMetadata](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3336) - local
- [emitSurfaceGridBoundaryCandidates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3353) - local
- [emitCornerSnapCandidates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3396) - local
- [globalFamilyValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3420) - local
- [addGlobalFamilyLine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3424) - local
- [collectGlobalFamilyLines](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3442) - local
- [emitGlobalGridPointCandidates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3464) - local
- [emitGlobalGridBoundaryCandidates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3497) - local
- [cross2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3539) - local
- [segmentCrossesPolygonEdge](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3543) - local
- [segmentCrossesSurfaceBoundary](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3565) - local
- [gridHasAxisBarrierBetween](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3583) - local
- [segmentCrossesSurfaceGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3601) - local
- [globalFamilyHasBarrierBetween](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3617) - local
- [segmentCrossesGlobalGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3632) - local
- [snapCandidateIsVisible](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3651) - assigned
- [localSurfaceSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3667) - local
- [localGlobalSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3690) - local
- [localVisibleSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3702) - local
- [snapModeForVisibleCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3710) - local
- [applyVisibleSnapCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3718) - local
- [worldGridRenderCacheKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3733) - local
- [buildRenderOverlayFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3740) - local
- [buildRenderNeighborFaces](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3773) - local
- [addNeighbor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3796) - local
- [worldBSP.HOVER_FACE_META.__index](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3829) - assigned
- [worldBSP.surfaceSourceIdentity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3838) - member/global
- [worldBSP.surfaceDescriptorBaseKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3854) - member/global
- [worldBSP.surfaceGridSettingsKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3862) - member/global
- [worldBSP.globalSurfaceDescriptorIsCurrent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3884) - member/global
- [worldBSP.surfaceDescriptorStores](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3890) - member/global
- [worldBSP.buildSurfaceFaceDescriptor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3913) - member/global
- [worldBSP.surfaceFaceDescriptor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3940) - member/global
- [worldBSP.buildSurfaceGridDescriptor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3955) - member/global
- [worldBSP.surfaceGridDescriptor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:3994) - member/global
- [worldBSP.newHoverCandidateState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4010) - member/global
- [worldBSP.buildFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4048) - member/global
- [worldBSP.traceSurfaceDataCanFastMatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4115) - member/global
- [worldBSP.traceTolerancesForSameSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4129) - member/global
- [worldBSP.sameSurfaceFastMatchForSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4139) - member/global
- [worldBSP.globalCachedSurfaceIsCurrent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4191) - member/global
- [sameSurfaceFastMatchFromTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4197) - local
- [worldBSP.surfaceTraceCacheToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4208) - member/global
- [worldBSP.refreshSurfaceTraceCacheToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4216) - member/global
- [worldBSP.bumpSurfaceTraceCacheRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4223) - member/global
- [worldBSP.surfaceTraceEntryIsCurrent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4231) - member/global
- [worldBSP.surfaceTraceCacheStatusToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4243) - member/global
- [worldBSP.candidateCacheStatusToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4256) - member/global
- [worldBSP.markSurfaceTraceCachedSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4267) - member/global
- [worldBSP.surfaceTraceCachedSurfaceIsCurrent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4279) - member/global
- [worldBSP.traceMatchesSurfaceSource](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4296) - member/global
- [worldBSP.perSurfaceSameSurfaceFastMatchFromTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4311) - member/global
- [worldBSP.indexSurfaceEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4323) - member/global
- [worldBSP.querySurfaceEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4378) - member/global
- [worldBSP.collectSurfaceEntryPlaneSet](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4419) - member/global
- [collectForNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4431) - local
- [worldBSP.perSurfaceCandidateFromMatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4464) - member/global
- [worldBSP.resetSurfaceTraceCacheIfNeeded](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4504) - member/global
- [worldBSP.traceBrushEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4529) - member/global
- [worldBSP.traceBrushSurfaceEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4543) - member/global
- [worldBSP.perSurfaceCandidateFromTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4619) - member/global
- [worldBSP.candidateFromTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4667) - member/global
- [worldBSP.formatVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4714) - member/global
- [worldBSP.boolLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4720) - member/global
- [worldBSP.surfaceSourceLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4724) - member/global
- [worldBSP.surfaceDisplacementDiagonalLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4742) - member/global
- [worldBSP.traceRejectReason](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4748) - member/global
- [worldBSP.traceDebugInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4768) - member/global
- [worldBSP.insertTraceDebugCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4816) - member/global
- [worldBSP.printTraceDebugCandidates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4835) - member/global
- [worldBSP.debugTrace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4869) - member/global
- [worldBSP.debugCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4920) - member/global
- [concommand.Add magic_align_world_bsp_debug_trace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4941) - concommand callback
- [concommand.Add magic_align_world_bsp_debug_cache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:4944) - concommand callback

#### [lua/magic_align/client/render/world_grid_light.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua) (184 Zeilen, 10 Funktionen)
- [now](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:24) - local
- [enabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:28) - local
- [probeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:34) - local
- [luma](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:56) - local
- [blendFromLuma](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:68) - local
- [samplePosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:80) - local
- [client.worldGridRender.updateLightBlend](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:98) - member/global
- [client.worldGridRender.updateLightProbe](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:154) - member/global
- [client.worldGridRender.currentLightBlend](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:161) - member/global
- [client.worldGridRender.lightDebugInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/world_grid_light.lua:167) - member/global

#### [lua/magic_align/client/render/hover_grid.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua) (612 Zeilen, 43 Funktionen)
- [newRenderVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:28) - local
- [setRenderVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:32) - local
- [cachedColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:68) - local
- [drawLine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:85) - local
- [paletteColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:93) - local
- [cursorAccentColorForSide](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:106) - local
- [cursorSideForContext](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:120) - local
- [cursorLineSide](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:130) - local
- [cursorLineColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:153) - local
- [cursorAccentColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:157) - local
- [lightScaledAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:161) - local
- [readClampedConVarInt](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:166) - local
- [isDrawingPickPress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:173) - local
- [hasDrawableFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:186) - local
- [shouldRenderGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:193) - local
- [shouldRenderFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:203) - local
- [sideAccentColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:210) - local
- [activePickAccentColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:217) - local
- [formatPercentLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:226) - local
- [gcd](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:237) - local
- [lcm](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:248) - local
- [gridAxisDivisions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:255) - local
- [commonGridDivisions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:261) - local
- [addGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:267) - local
- [formatFractionLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:289) - local
- [shouldUsePercentGridLabels](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:313) - local
- [shouldReduceFractionGridLabels](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:319) - local
- [currentGridLineAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:325) - local
- [formatGridLineLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:330) - local
- [insetLineEnds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:345) - local
- [faceLineLocalPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:361) - local
- [faceLineWorldPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:384) - local
- [drawSnapLineLabels2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:404) - local
- [drawWorldBspBlockerMarker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:424) - local
- [hoverRender.isDrawingPickPress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:450) - member/global
- [hoverRender.activePickAccentColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:454) - member/global
- [hoverRender.cursorLineColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:458) - member/global
- [hoverRender.cursorAccentColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:462) - member/global
- [hoverRender.drawWorldBspBlockers](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:466) - member/global
- [hoverRender.drawGridLabels](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:478) - member/global
- [hoverRender.drawFaceOutline](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:500) - member/global
- [hoverRender.drawGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:538) - member/global
- [addGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/hover_grid.lua:568) - local

#### [lua/magic_align/client/render/rotation_ticks.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua) (115 Zeilen, 8 Funktionen)
- [rotationRender.normalizeDegrees](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:10) - member/global
- [rotationRender.snapDisplayAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:20) - member/global
- [rotationRender.isAngleMultiple](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:29) - member/global
- [rotationRender.isMajorTick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:34) - member/global
- [rotationRender.isFortyFiveTick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:42) - member/global
- [tickDistanceLess](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:46) - local
- [tickAngleLess](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:54) - local
- [rotationRender.visibleTicks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render/rotation_ticks.lua:58) - member/global

<a id="pfad-7"></a>
## Pfad 7: Rendering, Ghosts, Toolgun-Feedback

Relevanz: Nutzerwahrnehmung: Preview-Ringe, Grid-Overlays, Toolgun-Screen, Sounds/Licht.

### Kernfluss

- [hook.Add PostDrawOpaqueRenderables / magic_align_draw](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4744) - Haupt-Render-Hook
- [hook.Add PostDrawTranslucentRenderables / magic_align_draw_overlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4814) - Overlay-Render-Hook
- [TOOL:DrawToolScreen](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1577) - Toolgun-Screen
- [toolgunEffects.DispatchFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:350) - zentraler Feedback-Ausloeser

### Dateien

- [lua/magic_align/client/render_primitives.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua) - 215 Zeilen, 14 Funktionseintraege
- [lua/magic_align/client/render.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua) - 4823 Zeilen, 240 Funktionseintraege
- [lua/magic_align/client/render_toolgun.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua) - 1610 Zeilen, 79 Funktionseintraege
- [lua/magic_align/toolgun_effects.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua) - 504 Zeilen, 48 Funktionseintraege

### Funktionen

#### [lua/magic_align/client/render_primitives.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua) (215 Zeilen, 14 Funktionen)
- [cachedColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:17) - local
- [cappedAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:34) - local
- [renderVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:40) - local
- [meshPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:45) - local
- [drawLine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:53) - local
- [pushTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:61) - local
- [drawFilledQuad](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:77) - local
- [drawFilledTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:87) - local
- [primitives.CachedColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:95) - member/global
- [primitives.CappedAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:99) - member/global
- [primitives.DrawLine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:103) - member/global
- [primitives.DrawFilledQuad](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:107) - member/global
- [primitives.DrawFilledTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:111) - member/global
- [primitives.DrawAxisArrow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_primitives.lua:115) - member/global

#### [lua/magic_align/client/render.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua) (4823 Zeilen, 240 Funktionen)
- [setStripePatternCopyBlend](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:150) - local
- [drawStripePatternRect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:160) - local
- [stripePatternStripeSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:166) - local
- [drawStripePatternDiagonal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:170) - local
- [drawLine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:188) - local
- [drawQuad](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:196) - local
- [meshPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:206) - local
- [anchorOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:215) - local
- [circlePointsForSegments](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:246) - local
- [numberOrZero](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:270) - local
- [newRenderVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:279) - local
- [setVecComponents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:287) - local
- [setVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:296) - local
- [localToWorldPosInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:307) - local
- [client.worldGridRender.setRenderVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:328) - member/global
- [cachedColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:343) - local
- [colorAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:360) - local
- [cappedAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:364) - local
- [scaledAlphaColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:369) - local
- [prop2BlueColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:374) - local
- [clampUnitInterval](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:386) - local
- [ringQualityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:390) - local
- [ringRenderSettingsForIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:395) - local
- [ringRenderSettingsForTool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:403) - local
- [activeRingRenderSettings](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:407) - local
- [ringRtSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:412) - local
- [scaleCircleResolutionValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:416) - local
- [circleSpriteRtSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:423) - local
- [ringRenderSegments](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:434) - local
- [circleSpriteSegments](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:439) - local
- [rotationRingTickLimit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:452) - local
- [quantizeShapeRatio](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:457) - local
- [compensatedInnerRatio](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:462) - local
- [resolvedRingInnerRadius](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:478) - local
- [shapeMetricsForRtSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:489) - local
- [reusableCirclePoly](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:514) - local
- [drawCircle2DAt](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:530) - local
- [drawRing2DByRadiiAt](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:557) - local
- [ensureShapeWhiteMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:592) - local
- [buildShapeCacheKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:614) - local
- [rebuildShapeCacheEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:624) - local
- [scheduleShapeCacheRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:656) - local
- [queueShapeCacheEntryRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:676) - local
- [ensureCachedShape](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:683) - local
- [drawCachedShapeRect2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:746) - local
- [ensureCachedCircleSprite](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:761) - local
- [drawCachedCircleSpriteRect2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:773) - local
- [pushTexturedWorldVertex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:781) - local
- [drawTexturedWorldQuad](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:788) - local
- [drawCachedShapePlane](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:815) - local
- [client.worldGridRender.isWorldGridLineMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:838) - member/global
- [client.worldGridRender.worldGridRtSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:842) - member/global
- [client.worldGridRender.worldGridRtDimensions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:885) - member/global
- [client.worldGridRender.pushWorldGridTextureFilter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:905) - member/global
- [client.worldGridRender.popWorldGridTextureFilter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:916) - member/global
- [client.worldGridRender.drawWorldGridRtLines](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:925) - member/global
- [drawHorizontal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:958) - local
- [drawVertical](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:967) - local
- [drawEdgeHorizontal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1007) - local
- [drawEdgeVertical](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1016) - local
- [drawCornerHorizontalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1026) - local
- [drawCornerHorizontalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1032) - local
- [drawCornerVerticalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1038) - local
- [drawCornerVerticalShadowForeground](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1044) - local
- [drawCornerVerticalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1050) - local
- [drawHorizontalHalfVerticalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1056) - local
- [drawHorizontalEdgeVerticalShadowForeground](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1063) - local
- [drawHorizontalHalfVerticalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1070) - local
- [drawHorizontalHalfHorizontalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1077) - local
- [drawHorizontalHalfHorizontalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1083) - local
- [drawVerticalHalfHorizontalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1089) - local
- [drawVerticalHalfHorizontalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1096) - local
- [drawVerticalHalfVerticalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1103) - local
- [drawVerticalHalfVerticalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1109) - local
- [drawCenterHorizontalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1115) - local
- [drawCenterHorizontalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1121) - local
- [drawCenterVerticalShadow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1127) - local
- [drawCenterVerticalLight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1133) - local
- [client.worldGridRender.rebuildWorldGridRtEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1169) - member/global
- [client.worldGridRender.scheduleWorldGridRtRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1192) - member/global
- [client.worldGridRender.queueWorldGridRtEntryRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1219) - member/global
- [client.worldGridRender.ensureWorldGridMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1226) - member/global
- [client.worldGridRender.axisComponent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1281) - member/global
- [client.worldGridRender.ensureWorldBspRenderData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1288) - member/global
- [client.worldGridRender.lookupWorldBspRenderData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1322) - member/global
- [client.worldGridRender.worldGridSurfaceComponent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1327) - member/global
- [client.worldGridRender.addUniqueWorldGridPoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1344) - member/global
- [client.worldGridRender.worldGridLineWorldPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1364) - member/global
- [client.worldGridRender.addWorldGridSnapAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1433) - member/global
- [client.worldGridRender.ensureWorldGridSnapCrossData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1441) - member/global
- [client.worldGridRender.drawWorldGridSnapCross](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1507) - member/global
- [client.worldGridRender.worldGridBatchKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1523) - member/global
- [client.worldGridRender.writeWorldGridBatchVertex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1533) - member/global
- [client.worldGridRender.createWorldGridMesh](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1547) - member/global
- [client.worldGridRender.buildWorldGridMesh](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1554) - member/global
- [client.worldGridRender.ensureWorldGridSurfaceBatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1583) - member/global
- [client.worldGridRender.prepareWorldGridSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1656) - member/global
- [worldGridQueueNow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1692) - local
- [worldGridFrameBudgetMs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1696) - local
- [worldGridQueueBudgetMs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1707) - local
- [worldGridRequestKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1714) - local
- [worldGridJobOwner](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1722) - local
- [worldGridJobStore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1727) - local
- [worldGridOverlayAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1739) - local
- [worldGridOverlayLineMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1748) - local
- [worldGridUnitKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1757) - local
- [worldGridUnitQueued](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1767) - local
- [registerWorldGridPrimaryUnit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1787) - local
- [registerWorldGridSurfaceUnit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1796) - local
- [activateWorldGridJob](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1803) - local
- [pushWorldGridPriorityUnit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1812) - local
- [appendWorldGridSurfaceUnits](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1821) - local
- [seedWorldGridJob](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1882) - local
- [worldGridVisibleNeighborSet](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1899) - local
- [worldGridJobHasPrimarySurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1926) - local
- [worldGridFaceNeedsUnit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1948) - local
- [worldGridJobHasSurfaceUnit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1962) - local
- [worldGridJobCoversFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1981) - local
- [publishWorldGridBatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2001) - local
- [nextWorldGridUnit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2029) - local
- [buildWorldGridUnit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2058) - local
- [processWorldGridJob](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2077) - local
- [compactWorldGridActiveJobs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2089) - local
- [client.worldGridRender.requestWorldBspGlobalGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2114) - member/global
- [client.worldGridRender.processQueue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2201) - member/global
- [client.worldGridRender.pushWorldGridBatchVertex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2237) - member/global
- [client.worldGridRender.drawWorldGridSurfaceBatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2248) - member/global
- [client.worldGridRender.drawWorldGridSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2267) - member/global
- [client.worldGridRender.prepareWorldBspGlobalGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2277) - member/global
- [client.prepareWorldBspRenderCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2284) - member/global
- [client.worldGridRender.drawWorldBspGlobalGridSurface](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2307) - member/global
- [client.worldGridRender.drawWorldBspGlobalGridDepthTested](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2335) - member/global
- [client.worldGridRender.drawWorldBspGlobalGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2342) - member/global
- [debugBool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2350) - local
- [debugSurfaceId](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2354) - local
- [debugHoverFace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2358) - local
- [debugOverlayList](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2365) - local
- [debugBatchDrawable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2382) - local
- [countPrimaryBatches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2387) - local
- [countSurfaceUnits](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2400) - local
- [countNeighborBatches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2427) - local
- [groupGapSummary](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2444) - local
- [client.worldGridRender.debugWorldBspGlobalGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2491) - member/global
- [concommand.Add magic_align_world_bsp_debug_grid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2568) - concommand callback
- [queueShapeCacheWarmup](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2573) - local
- [selectionColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2594) - local
- [shapeMetricCache.renderPerf.drawWireMarkerBatch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2605) - member/global
- [shapeMetricCache.renderPerf.addGhostRenderEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2634) - member/global
- [shapeMetricCache.renderPerf.drawGhostRenderEntries](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2653) - member/global
- [clampColorByte](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2670) - local
- [previewOccludedEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2674) - local
- [previewOccludedPickerColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2683) - local
- [cvarByte](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2693) - local
- [scaledOccludedPreviewColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2706) - local
- [stencilAvailable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2715) - local
- [stripeDistanceScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2719) - local
- [occludedStripeTileSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2728) - local
- [occludedStripeScreenCenter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2737) - local
- [occludedStripeParallaxCenter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2788) - local
- [drawScreenStripePattern](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2797) - local
- [pushScreenVertex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2814) - local
- [drawPreviewOccludedGhost](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2843) - local
- [drawPreviewOccludedCompatEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2878) - local
- [drawPreviewOccludedCompatGhosts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2885) - local
- [drawCircle2D](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2896) - local
- [drawRing2DByRadii](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2907) - local
- [beginBillboard](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2918) - local
- [drawCircleSprite](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2960) - local
- [drawRingSprite](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2984) - local
- [drawRotationRingTicks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3026) - local
- [drawPlaneSquare](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3043) - local
- [pushTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3075) - local
- [drawFilledQuad](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3089) - local
- [rotationRingBandRadii](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3099) - local
- [ringPlanePoint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3111) - local
- [drawRotationRingBandRealtime](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3117) - local
- [drawRotationSectorMask](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3150) - local
- [drawRotationDeltaSectorRealtime](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3165) - local
- [drawRotationRingBand](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3197) - local
- [drawRotationDeltaSector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3224) - local
- [componentForAxisKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3287) - local
- [handleUsesAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3291) - local
- [axisVectorsForKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3303) - local
- [translationDisplayDistance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3316) - local
- [activeTranslationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3321) - local
- [currentTranslationLocalPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3338) - local
- [translationSnapOverlayColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3350) - local
- [drawTranslationAxisTicks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3363) - local
- [drawTranslationPlaneGrid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3391) - local
- [drawTranslationSnapOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3442) - local
- [drawDoubleSidedPlaneSquare](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3462) - local
- [activeTraceMarkerDirection](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3488) - local
- [drawFilledTraceSnapSquare](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3501) - local
- [drawOutlineTraceSnapSquare](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3526) - local
- [drawTraceSnapHitCluster](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3530) - local
- [drawTraceSnapAxisMarker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3542) - local
- [drawFilledTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3569) - local
- [pushTexturedVertex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3577) - local
- [drawTexturedTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3584) - local
- [ensureStripePatternMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3606) - assigned
- [queueStripePatternRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3711) - local
- [drawStripedTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3735) - local
- [drawAxisArrow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3811) - local
- [drawFrame](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3817) - local
- [shouldDrawPointTriangle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3823) - local
- [anchorPercent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3827) - local
- [lerpPointFast](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3831) - local
- [anchorPointFast](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3839) - local
- [lerpPointInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3862) - local
- [anchorPointInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3873) - local
- [normalizedEntityMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3903) - local
- [mirrorLocalPointInto](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3912) - local
- [renderLocalPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3927) - local
- [drawPointSet](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3945) - local
- [anchorWorldPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3981) - local
- [pointWorldPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4020) - member/global
- [anchorWorldPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4033) - member/global
- [drawPoints](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4062) - local
- [client.MirrorRender.referenceExtent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4100) - member/global
- [client.MirrorRender.queuePlaneMaterialRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4106) - member/global
- [hook.Add PostRender / magic_align_mirror_plane_rebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4110) - hook callback
- [client.MirrorRender.ensurePlaneMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4147) - member/global
- [client.MirrorRender.drawPlaneSquare](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4202) - member/global
- [client.MirrorRender.drawAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4240) - member/global
- [client.MirrorRender.state](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4258) - member/global
- [client.MirrorRender.drawPointLabels](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4270) - member/global
- [client.MirrorRender.drawReference](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4285) - member/global
- [clearReusableEntries](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4314) - local
- [reusableEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4322) - local
- [shouldDrawGizmoHandle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4332) - local
- [reusableHoverGizmoForRender](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4338) - local
- [drawGizmoOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4355) - local
- [drawOverlayWireMarkers](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4519) - local
- [drawInteractionOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4564) - local
- [drawInteractionSurfaceOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4688) - local
- [TOOL:DrawHUD](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4700) - member/global
- [shouldDrawOpaqueGhostPass](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4727) - local
- [hook.Add PostDrawOpaqueRenderables / magic_align_draw](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4744) - hook callback
- [shouldDrawTranslucentOverlayPass](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4796) - local
- [hook.Add PostDrawTranslucentRenderables / magic_align_draw_overlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:4814) - hook callback

#### [lua/magic_align/client/render_toolgun.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua) (1610 Zeilen, 79 Funktionen)
- [solid](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:60) - local
- [cachedColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:193) - local
- [colorAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:210) - local
- [cachedStaticTextSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:214) - local
- [colorVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:236) - local
- [ensureToolgunLedMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:261) - local
- [ensureToolgunGlowMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:268) - local
- [toolgunLedSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:275) - local
- [toolgunGlowAccent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:288) - local
- [activeToolgunFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:293) - local
- [activeToolgunHoldColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:300) - local
- [toolgunLedVisual](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:335) - local
- [clearToolgunMaterialOverride](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:354) - local
- [clearToolgunLedOverride](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:374) - local
- [applyToolgunMaterialAccent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:379) - local
- [applyToolgunLedAccent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:402) - local
- [hook.Add Think / MagicAlignToolgunLedAccent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:447) - hook callback
- [normalizedAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:463) - local
- [frameDelta](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:467) - local
- [smoothedCompassAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:473) - local
- [compassSignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:502) - local
- [safeVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:511) - local
- [anchorOptionsFromTool](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:518) - local
- [activeAnchorSelection](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:535) - local
- [activeAnchorWorldPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:548) - local
- [commitUploadProgress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:579) - local
- [luminance](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:586) - local
- [accentTextColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:590) - local
- [clampDisplayValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:598) - local
- [formatUnits](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:607) - local
- [formatAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:611) - local
- [ensureFonts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:615) - local
- [widestText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:695) - local
- [pickValueFont](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:707) - local
- [cachedValueFont](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:721) - local
- [drawChip](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:764) - local
- [chipWidth](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:775) - local
- [footerRect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:780) - local
- [contentRect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:785) - local
- [drawBackdrop](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:790) - local
- [activeWorldGridCacheProgress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:822) - local
- [worldGridCacheAccent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:833) - local
- [worldGridCachePhaseIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:848) - local
- [worldGridCachePhaseCount](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:862) - local
- [stageProgressFraction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:870) - local
- [overallProgressFraction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:884) - local
- [formatEtaClock](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:892) - local
- [drawWorldGridCacheHeader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:902) - local
- [drawValueCards](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:942) - local
- [drawCompassRingLines](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:975) - local
- [rebuildCompassRingMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1008) - local
- [queueCompassRingRebuild](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1026) - local
- [ensureCompassRingMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1036) - local
- [drawCompassRing](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1086) - local
- [drawCompass](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1106) - local
- [compassAngle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1138) - local
- [currentSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1157) - local
- [displayLabelForSpace](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1166) - local
- [drawFooter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1174) - local
- [pointCountText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1212) - local
- [pointCountDisplayColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1227) - local
- [linkedCountText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1236) - local
- [blendColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1242) - local
- [linkedCountColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1253) - local
- [drawLinkedCountInline](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1272) - local
- [drawCompassPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1283) - local
- [drawIdleCompasses](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1311) - local
- [formulaSnapshotFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1380) - local
- [clearReusableMap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1395) - local
- [lockedFormulaKeysForPress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1405) - local
- [clearReusableArray](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1440) - local
- [writeSliderItem](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1446) - local
- [collectSliderItems](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1464) - local
- [buildTranslationItems](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1482) - local
- [buildRotationItems](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1509) - local
- [pressDisplaySignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1519) - local
- [buildDisplayData](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1536) - local
- [activeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1566) - local
- [TOOL:DrawToolScreen](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1577) - member/global

#### [lua/magic_align/toolgun_effects.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua) (504 Zeilen, 48 Funktionen)
- [now](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:59) - local
- [finiteVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:63) - local
- [effectVector](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:67) - local
- [safeNormal](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:75) - local
- [copyColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:85) - local
- [contextColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:91) - local
- [activeToolWeapon](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:108) - local
- [toolOwner](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:114) - local
- [weaponFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:126) - local
- [storedToolgun](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:139) - local
- [effectKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:146) - local
- [toolgunEffects.ResolveFeedbackKind](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:151) - member/global
- [markerColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:157) - local
- [markerFor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:167) - local
- [markActiveFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:184) - local
- [toolgunEffects.ActiveFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:196) - member/global
- [drawEffectsEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:211) - local
- [effectDataColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:215) - local
- [withEffectColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:223) - local
- [emitFeedbackSound](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:229) - local
- [playHitRings](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:243) - local
- [attachmentPosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:259) - local
- [nearShootPos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:265) - local
- [cachedMuzzlePosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:276) - local
- [liveMuzzlePosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:286) - local
- [muzzlePosition](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:298) - local
- [playMuzzleRing](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:305) - local
- [playFeedbackForWeapon](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:324) - local
- [traceParts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:343) - local
- [toolgunEffects.DispatchFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:350) - member/global
- [toolgunEffects.MarkFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:360) - member/global
- [toolgunEffects.PlayFeedback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:364) - member/global
- [toolgunEffects.DoShootEffect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:368) - member/global
- [toolgunEffects.PlayCommitAction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:372) - member/global
- [toolgunEffects.PlayCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:376) - member/global
- [toolgunEffects.PlayNoEffect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:380) - member/global
- [progress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:387) - local
- [ringSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:391) - local
- [airFrictionTravel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:395) - local
- [ringAlpha](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:406) - local
- [drawRing](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:410) - local
- [hook.Add PostDrawViewModel / MagicAlignToolgunMuzzleCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:416) - hook callback
- [hitRings:Init](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:433) - member/global
- [hitRings:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:444) - member/global
- [hitRings:Render](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:448) - member/global
- [muzzleRing:Init](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:462) - member/global
- [muzzleRing:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:478) - member/global
- [muzzleRing:Render](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:482) - member/global

<a id="pfad-8"></a>
## Pfad 8: UI, Menues, Slider, Formeln

Relevanz: Relevant fuer Bedienung und ConVar-Formeln; fachlich weniger riskant als Solver/Commit, aber gross.

### Kernfluss

- [TOOL.BuildCPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2313) - baut Hauptmenue
- [manager:RefreshAll](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:746) - aktualisiert Formeln
- [parser.evaluate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:399) - wertet Formel-Ausdruecke aus
- [scanKnownMenus](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:996) - Spawnmenu-Integration

### Dateien

- [lua/magic_align/client/menu.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua) - 2906 Zeilen, 190 Funktionseintraege
- [lua/magic_align/client/dmagic_align_numslider.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua) - 2564 Zeilen, 164 Funktionseintraege
- [lua/magic_align/client/formula_manager.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua) - 822 Zeilen, 41 Funktionseintraege
- [lua/magic_align/client/math_parser.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua) - 463 Zeilen, 29 Funktionseintraege
- [lua/magic_align/client/menuentryhack.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua) - 1031 Zeilen, 73 Funktionseintraege

### Funktionen

#### [lua/magic_align/client/menu.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua) (2906 Zeilen, 190 Funktionen)
- [M.GetFormulaEnvironment](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:13) - assigned
- [setValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:22) - local
- [getMenuCreditName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:65) - local
- [updateMenuCreditOnline](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:85) - local
- [clampRotationSnapIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:117) - local
- [clampTranslationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:121) - local
- [clampTraceSnapLength](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:125) - local
- [clampToolgunSoundVolume](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:129) - local
- [rotationSnapInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:134) - local
- [clampRingQualityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:143) - local
- [ringQualityInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:147) - local
- [ringQualityDisplayName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:152) - local
- [recommendedRingQualityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:163) - local
- [recommendedRingQualityDisplayName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:176) - local
- [ringQualityTooltipText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:180) - local
- [formatDisplayRoundedValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:228) - local
- [getBoolConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:236) - local
- [persistMenuConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:245) - local
- [applyPersistedMenuConVars](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:273) - local
- [currentRotationSnapIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:279) - local
- [setRotationSnapIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:283) - local
- [currentTranslationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:287) - local
- [referencePositionSliderSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:291) - local
- [setTranslationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:311) - local
- [currentTraceSnapLength](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:315) - local
- [setTraceSnapLength](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:319) - local
- [currentToolgunSoundVolume](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:323) - local
- [setToolgunSoundVolume](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:327) - local
- [clampWorldGridSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:331) - local
- [currentWorldGridSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:335) - local
- [setWorldGridSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:339) - local
- [currentWorldGridMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:343) - local
- [setWorldGridMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:352) - local
- [worldGridPresetFraction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:364) - local
- [worldGridPresetForFraction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:372) - local
- [nearestWorldGridPreset](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:379) - local
- [currentRingQualityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:397) - local
- [setRingQualityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:401) - local
- [isOffsetNeutral](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:405) - local
- [spaceHasOffsetChanges](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:409) - local
- [relayoutSessionTabs](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:420) - local
- [updateSessionTabTitle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:446) - local
- [updateSessionTabTitles](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:462) - local
- [registerSessionTabCallbacks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:474) - local
- [registerFormulaConVars](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:509) - local
- [solidColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:571) - local
- [expensiveQualityWarningHidden](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:600) - local
- [expensiveRingQualityEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:605) - local
- [addMagicAlignExpensiveQualityWarning](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:610) - local
- [resetExpensiveQualityWarningForSpawn](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:626) - local
- [hook.Add PlayerSpawn / MagicAlignExpensiveQualityWarningReset](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:631) - hook callback
- [hook.Add Think / MagicAlignExpensiveQualityWarning](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:638) - hook callback
- [wrapLabelText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:666) - local
- [textFits](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:677) - local
- [appendWrappedLine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:682) - local
- [getOutlinedLabelFont](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:725) - local
- [hideNativeLabelText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:733) - local
- [getOutlinedLabelTextSize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:752) - local
- [paintOutlinedLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:774) - local
- [styleOutlinedLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:810) - local
- [label.SetText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:823) - assigned
- [label.GetText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:835) - assigned
- [label.SetTextColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:839) - assigned
- [label.GetTextColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:852) - assigned
- [label.SizeToContentsY](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:859) - assigned
- [label.SizeToContents](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:864) - assigned
- [label.ApplySchemeSettings](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:872) - assigned
- [setStringConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:890) - assigned
- [getStringConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:894) - assigned
- [sliderDisplaySetting](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:903) - local
- [formatSliderDisplayValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:912) - local
- [syncStandardSliderDisplay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:920) - local
- [installSliderDisplayRounding](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:947) - local
- [slider.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:955) - assigned
- [currentRotationSnapStep](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:968) - local
- [resetInterpolationPercentages](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:973) - local
- [anchorLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:981) - local
- [completeAnchorOrder](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:993) - local
- [serializeAnchorOrder](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1014) - local
- [anchorAvailable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1018) - local
- [priorityIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1022) - local
- [highestAvailableAnchor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1032) - local
- [activeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1040) - local
- [pointCount](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1051) - local
- [styleTextEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1059) - local
- [entry.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1068) - assigned
- [stylePanelSlider](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1077) - local
- [slider.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1110) - assigned
- [installRingQualityRecommendationMarker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1123) - local
- [innerSlider.PaintOver](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1129) - assigned
- [innerSlider.Knob.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1182) - assigned
- [styleFlatButton](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1195) - local
- [button.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1199) - assigned
- [styleSubtleButton](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1214) - local
- [button.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1218) - assigned
- [stylePropertySheet](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1231) - local
- [sheet.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1235) - assigned
- [sheet.tabScroller.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1243) - assigned
- [stylePropertyTab](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1249) - local
- [tabButton.GetTabHeight](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1250) - assigned
- [tabButton.UpdateColours](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1254) - assigned
- [tabButton.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1258) - assigned
- [styleCheckBox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1279) - local
- [checkBox.Button.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1291) - assigned
- [addStyledSlider](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1328) - local
- [client.createToolgunSoundVolumeSlider](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1345) - assigned
- [slider.ShouldClampValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1357) - assigned
- [slider.FormatDisplayValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1360) - assigned
- [createStackPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1377) - local
- [stack:AddItem](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1387) - member/global
- [stack.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1399) - assigned
- [createHelpLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1430) - local
- [createMenuCreditRow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1447) - local
- [nameLabel.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1464) - assigned
- [row.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1476) - assigned
- [createMenuFooter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1489) - local
- [addStyledCheckBox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1503) - local
- [createStyledModeCombo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1514) - local
- [combo.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1529) - assigned
- [combo.OnSelect](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1536) - assigned
- [syncComboToValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1551) - local
- [installWorldGridPresetScale](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1568) - local
- [slider.GetSliderFractionForValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1573) - assigned
- [slider.NormalizeValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1577) - assigned
- [slider.TranslateSliderValues](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1585) - assigned
- [slider.Slider.TranslateValues](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1592) - assigned
- [createInlineCheckBoxRow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1604) - local
- [row.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1626) - assigned
- [readColorConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1650) - local
- [createPreviewOccludedColorPicker](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1657) - local
- [holder.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1683) - assigned
- [bindForcedVisualCheckBox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1694) - local
- [checkBox.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1697) - assigned
- [createPersistedCategory](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1719) - local
- [category.OnToggle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1732) - assigned
- [createAnchorPercentSlider](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1745) - local
- [slider.NormalizeValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1763) - assigned
- [slider.Slider.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1783) - assigned
- [slider.Slider.Knob.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1788) - assigned
- [createAnchorColumn](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1798) - local
- [column.body.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1823) - assigned
- [column:GetDisplayOrder](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1829) - member/global
- [column:ComputePlaceholderIndex](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1850) - member/global
- [column:LayoutRows](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1866) - member/global
- [column:Sync](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1897) - member/global
- [column:BeginInteraction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1923) - member/global
- [column:EndInteraction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1937) - member/global
- [column.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1965) - assigned
- [column.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1990) - assigned
- [row.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2008) - assigned
- [row.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2012) - assigned
- [row.OnMousePressed](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2057) - assigned
- [createInterpolationColumn](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2071) - local
- [column.resetButton.DoClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2091) - assigned
- [column.body.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2096) - assigned
- [column.body.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2112) - assigned
- [column.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2123) - assigned
- [createAnchorBoard](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2139) - local
- [board.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2164) - assigned
- [createInterpolationBoard](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2176) - local
- [board.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2193) - assigned
- [setSnapTitleText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2205) - local
- [createRingQualityControls](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2225) - local
- [updateRingQualityUi](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2250) - local
- [ringQualitySlider.OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2287) - assigned
- [TOOL.BuildCPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2313) - member/global
- [holder.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2346) - assigned
- [classification.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2373) - assigned
- [holder.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2381) - assigned
- [resetPos.DoClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2420) - assigned
- [resetRot.DoClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2428) - assigned
- [holder.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2434) - assigned
- [tab.Tab.DoClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2460) - assigned
- [updateRotationSnapUi](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2506) - local
- [rotationSnapSlider.OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2518) - assigned
- [updateTranslationSnapUi](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2564) - local
- [translationSnapSlider.OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2579) - assigned
- [updateTraceSnapUi](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2626) - local
- [traceSnapSlider.OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2641) - assigned
- [snapCategoryContent.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2651) - assigned
- [updateWorldGridStyleCheckBox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2688) - local
- [worldGridStyleCheckBox.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2702) - assigned
- [worldGridSizeSlider.ShouldClampValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2731) - assigned
- [worldGridCategoryContent.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2748) - assigned
- [worldCacheRebuildButton.DoClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2823) - assigned
- [performanceCategoryContent.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2834) - assigned
- [currentDisplayRoundingSetting](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2864) - local
- [updateDisplayRoundingUi](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2871) - local
- [displayRoundingSlider.OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2886) - assigned
- [miscCategoryContent.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2894) - assigned

#### [lua/magic_align/client/dmagic_align_numslider.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua) (2564 Zeilen, 164 Funktionen)
- [cloneColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:49) - local
- [accentShade](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:54) - local
- [sliderAccentColors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:64) - local
- [getEditorPalette](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:73) - local
- [ensureEditorFonts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:94) - local
- [isPanelDescendant](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:134) - local
- [resolveTextAreaFloatParent](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:146) - local
- [createEditorCard](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:172) - local
- [card.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:175) - assigned
- [paintEditorEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:189) - local
- [styleEditorCheckBox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:207) - local
- [checkBox.Button.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:220) - assigned
- [styleEditorScrollBar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:240) - local
- [vbar.btnGrip.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:259) - assigned
- [measureTextWidth](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:268) - local
- [registerFloatingTextOwner](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:273) - local
- [unregisterFloatingTextOwner](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:278) - local
- [collapseAllFloatingTextOwners](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:287) - local
- [nearlyEqual](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:307) - local
- [isFormulaText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:311) - local
- [isTransitionalExpressionText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:315) - local
- [sanitizeDecimals](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:333) - local
- [formatFormulaPreviewValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:339) - local
- [formatVariableValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:345) - local
- [copySettings](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:357) - local
- [buildEditorInfoSignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:374) - local
- [setTextEntryValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:394) - local
- [closeOtherExpressionEditors](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:417) - local
- [PANEL:Init](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:432) - member/global
- [self.Scratch.OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:477) - assigned
- [self.Scratch.OnMousePressed](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:482) - assigned
- [self.TextArea.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:507) - assigned
- [self.TextArea.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:510) - assigned
- [self.TextArea.OnEnter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:516) - assigned
- [self.TextArea.OnGetFocus](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:519) - assigned
- [self.TextArea.OnLoseFocus](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:536) - assigned
- [self.CenterSlot.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:548) - assigned
- [self.Slider.TranslateValues](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:569) - assigned
- [self.Slider.ResetToDefaultValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:577) - assigned
- [self.Slider.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:580) - assigned
- [self.Slider.Knob.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:587) - assigned
- [PANEL:EnsureRuntimeState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:617) - member/global
- [PANEL:GetConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:671) - member/global
- [PANEL:GetFormulaManager](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:675) - member/global
- [PANEL:SyncStoredStateFromManager](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:679) - member/global
- [PANEL:ApplyFormulaSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:699) - member/global
- [PANEL:HasFormulaPresentation](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:725) - member/global
- [PANEL:GetFormulaPreviewValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:730) - member/global
- [PANEL:UpdateFormulaResultLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:748) - member/global
- [PANEL:SetConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:774) - member/global
- [PANEL:GetInputDecimals](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:783) - member/global
- [PANEL:SetInputDecimals](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:797) - member/global
- [PANEL:GetInputSnap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:807) - member/global
- [PANEL:SetInputSnap](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:824) - member/global
- [PANEL:PrepareScratch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:831) - member/global
- [PANEL:IsFormulaLocked](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:835) - member/global
- [PANEL:UpdateFormulaLockState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:843) - member/global
- [PANEL:UpdateTextAreaTooltip](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:878) - member/global
- [PANEL:SyncEditorText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:891) - member/global
- [PANEL:SetDraftText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:906) - member/global
- [PANEL:GetExpressionOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:921) - member/global
- [PANEL:GetAvailableVariableRows](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:930) - member/global
- [PANEL:ResolveExpressionIdentifierValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:997) - member/global
- [PANEL:BuildFormulaWatchKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1025) - member/global
- [PANEL:GetAvailableVariableEntries](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1034) - member/global
- [PANEL:GetEditorVariableSearchText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1080) - member/global
- [PANEL:GetEditorShowNaEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1088) - member/global
- [PANEL:GetEditorShowWorldEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1096) - member/global
- [PANEL:GetEditorShowPointDistancesEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1104) - member/global
- [PANEL:GetEditorShowPointAnglesEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1112) - member/global
- [PANEL:IsWorldVariableEntryName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1120) - member/global
- [PANEL:IsPointDistanceEntryName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1126) - member/global
- [PANEL:IsPointAngleEntryName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1132) - member/global
- [PANEL:FilterEditorVariableEntries](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1137) - member/global
- [PANEL:SetEditorCellText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1178) - member/global
- [PANEL:CreateEditorReadOnlyCell](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1192) - member/global
- [cell.AllowInput](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1207) - assigned
- [cell.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1210) - assigned
- [cell.OnLoseFocus](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1226) - assigned
- [cell.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1237) - assigned
- [PANEL:EnsureEditorVariableRow](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1244) - member/global
- [row.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1261) - assigned
- [PANEL:RefreshEditorVariableTable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1274) - member/global
- [PANEL:RefreshEditorInfo](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1317) - member/global
- [PANEL:RestoreTextAreaFocusAfterEditorClose](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1350) - member/global
- [restore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1355) - local
- [focusExistingExpressionEditor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1382) - local
- [createExpressionEditorFrame](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1403) - local
- [frame.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1415) - assigned
- [frame.btnClose.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1440) - assigned
- [frame.OnRemove](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1455) - assigned
- [frame.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1485) - assigned
- [frame.Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1583) - assigned
- [frame.MagicAlignRefreshHeader](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1625) - assigned
- [buildExpressionEditorFilterPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1640) - local
- [filterPanel.PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1643) - assigned
- [searchEntry.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1688) - assigned
- [searchEntry.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1691) - assigned
- [showNaCheckBox.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1701) - assigned
- [showWorldCheckBox.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1713) - assigned
- [showPointDistancesCheckBox.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1725) - assigned
- [showPointAnglesCheckBox.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1737) - assigned
- [PANEL:OpenExpressionEditor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1747) - member/global
- [entry.Paint](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1782) - assigned
- [entry.OnChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1785) - assigned
- [entry.OnEnter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1792) - assigned
- [PANEL:PollTextAreaDoubleClick](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1869) - member/global
- [PANEL:PaintTextEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1895) - member/global
- [PANEL:PaintEditorTextEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1927) - member/global
- [PANEL:SetValidationState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1931) - member/global
- [PANEL:SetDisplayedText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1938) - member/global
- [PANEL:HandleDisplayRoundingChange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1951) - member/global
- [PANEL:FormatDisplayValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1969) - member/global
- [PANEL:FormatConVarValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1975) - member/global
- [PANEL:ShouldClampValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1992) - member/global
- [PANEL:GetSliderFractionForValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1996) - member/global
- [PANEL:NormalizeValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2001) - member/global
- [PANEL:UpdateBoundConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2021) - member/global
- [PANEL:ApplyValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2049) - member/global
- [PANEL:HandleTextChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2100) - member/global
- [PANEL:BuildTextCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2119) - member/global
- [PANEL:CommitText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2131) - member/global
- [PANEL:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2145) - member/global
- [PANEL:SyncFromConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2159) - member/global
- [PANEL:ReevaluateFormula](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2190) - member/global
- [PANEL:BackgroundFormulaThink](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2199) - member/global
- [PANEL:SetAccentColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2204) - member/global
- [PANEL:SetMinMax](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2212) - member/global
- [PANEL:ApplySchemeSettings](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2221) - member/global
- [PANEL:SetDark](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2236) - member/global
- [PANEL:SetLayoutMetrics](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2241) - member/global
- [PANEL:IsTextAreaFloating](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2253) - member/global
- [PANEL:GetCollapsedTextAreaWidth](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2257) - member/global
- [PANEL:GetTextAreaAnchorBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2261) - member/global
- [PANEL:GetExpandedTextAreaWidth](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2271) - member/global
- [PANEL:UpdateFloatingTextAreaBounds](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2285) - member/global
- [PANEL:ExpandTextArea](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2309) - member/global
- [PANEL:CollapseTextArea](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2347) - member/global
- [PANEL:GetMin](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2365) - member/global
- [PANEL:GetMax](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2369) - member/global
- [PANEL:GetRange](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2373) - member/global
- [PANEL:ResetToDefaultValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2377) - member/global
- [PANEL:SetMin](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2382) - member/global
- [PANEL:SetMax](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2392) - member/global
- [PANEL:SetValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2402) - member/global
- [PANEL:GetValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2409) - member/global
- [PANEL:SetDecimals](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2413) - member/global
- [PANEL:GetDecimals](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2423) - member/global
- [PANEL:IsEditing](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2427) - member/global
- [PANEL:IsHovered](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2434) - member/global
- [PANEL:PerformLayout](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2438) - member/global
- [PANEL:SetText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2460) - member/global
- [PANEL:GetText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2464) - member/global
- [PANEL:OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2468) - member/global
- [PANEL:TranslateSliderValues](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2471) - member/global
- [PANEL:GetTextArea](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2479) - member/global
- [PANEL:UpdateNotches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2483) - member/global
- [PANEL:OnRemove](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2494) - member/global
- [PANEL:SetEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2510) - member/global
- [PANEL:LoadCookies](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2518) - member/global
- [PANEL:GenerateExample](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2524) - member/global
- [PANEL:PostMessage](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2535) - member/global
- [PANEL:SetActionFunction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2551) - member/global
- [self.OnValueChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:2552) - assigned

#### [lua/magic_align/client/formula_manager.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua) (822 Zeilen, 41 Funktionen)
- [nearlyEqual](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:22) - local
- [formatSmart](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:26) - local
- [isFormulaText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:30) - local
- [hasEntryStateChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:34) - local
- [applyEntryState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:43) - local
- [snapshotDisplayText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:52) - local
- [Manager:EnsureHook](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:64) - member/global
- [hook.Add Think / MagicAlignFormulaManager](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:72) - hook callback
- [Manager:EnsureEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:77) - member/global
- [Manager:Touch](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:116) - member/global
- [Manager:GetRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:123) - member/global
- [Manager:GetEntryRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:127) - member/global
- [Manager:PollIntervalForEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:132) - member/global
- [Manager:ShouldPollEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:148) - member/global
- [Manager:ShouldPollConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:161) - member/global
- [Manager:MarkConVarChanged](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:170) - member/global
- [Manager:EnsureConVarCallback](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:178) - member/global
- [Manager:GetCookieKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:196) - member/global
- [Manager:PersistEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:205) - member/global
- [Manager:GetExpressionOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:214) - member/global
- [Manager:ResolveIdentifierValueRaw](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:249) - member/global
- [Manager:IsKnownIdentifier](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:277) - member/global
- [Manager:ResolveIdentifierValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:311) - member/global
- [Manager:GetEvaluationOptions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:324) - member/global
- [evalOptions.resolveIdentifier](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:331) - assigned
- [Manager:BuildFormulaWatchKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:362) - member/global
- [Manager:BuildTextCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:394) - member/global
- [Manager:ClearPendingState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:488) - member/global
- [Manager:ApplyStoredState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:497) - member/global
- [Manager:ClearStoredState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:507) - member/global
- [Manager:PushConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:518) - member/global
- [Manager:ApplyTextCommit](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:535) - member/global
- [Manager:ApplyDirectValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:567) - member/global
- [Manager:ReadConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:584) - member/global
- [Manager:PollConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:599) - member/global
- [Manager:RegisterConVar](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:684) - member/global
- [Manager:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:719) - member/global
- [Manager:RefreshAll](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:746) - member/global
- [Manager:ReevaluateFormula](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:766) - member/global
- [Manager:GetSnapshot](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:787) - member/global
- [Manager:GetNumericValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:807) - member/global

#### [lua/magic_align/client/math_parser.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua) (463 Zeilen, 29 Funktionen)
- [normalizeInput](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:13) - local
- [trimNumberString](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:26) - local
- [formatNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:37) - local
- [hasOnlyAllowedCharacters](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:41) - local
- [numericLiteral](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:47) - local
- [fail](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:56) - local
- [tokenize](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:63) - local
- [resolveIdentifier](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:151) - local
- [checkedValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:193) - local
- [sin](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:202) - assigned
- [cos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:205) - assigned
- [tan](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:208) - assigned
- [asin](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:211) - assigned
- [acos](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:214) - assigned
- [atan](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:217) - assigned
- [currentToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:223) - local
- [matchToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:227) - local
- [expectToken](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:235) - local
- [parsePrimary](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:247) - local
- [parsePower](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:286) - local
- [parseUnary](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:297) - member/global
- [parseMulDiv](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:309) - local
- [parseExpression](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:335) - member/global
- [Parser.HasOnlyAllowedCharacters](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:351) - member/global
- [Parser.IsNumericLiteral](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:355) - member/global
- [Parser.FormatNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:359) - member/global
- [Parser.GetSupportedFunctions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:363) - member/global
- [Parser.ExtractIdentifiers](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:372) - member/global
- [Parser.Evaluate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:399) - member/global

#### [lua/magic_align/client/menuentryhack.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua) (1031 Zeilen, 73 Funktionen)
- [solidColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:18) - local
- [panelMenuEntryManager](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:64) - local
- [activePanelDecorator](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:68) - local
- [activePanelSpec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:74) - local
- [resolvedText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:94) - local
- [panelText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:102) - local
- [overlayEnabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:106) - local
- [mirrorAnimationDisabled](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:111) - local
- [categoryLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:116) - local
- [specCategoryMatches](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:124) - local
- [isTargetCategory](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:129) - local
- [entryMatchesText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:156) - local
- [matchingEntrySpec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:160) - local
- [textInset](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:180) - local
- [textStartX](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:187) - local
- [panelTreeVisible](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:203) - local
- [panelReadyForOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:216) - local
- [overlayTextForSpec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:223) - local
- [clearLegacyOverlayState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:229) - local
- [colorKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:278) - local
- [toolModeActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:283) - local
- [entryActive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:288) - local
- [categoryLineTextColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:295) - local
- [panelTextColor](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:307) - local
- [textTopY](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:327) - local
- [drawTextAt](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:333) - local
- [drawHighlightedText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:342) - local
- [renderMirrorWord](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:375) - local
- [drawIntoRenderTarget](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:392) - local
- [createRtMaterial](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:405) - local
- [mirrorRtPair](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:417) - local
- [randomLegDuration](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:445) - local
- [randomEdgePause](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:449) - local
- [easedCosine](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:454) - local
- [randomFractionTarget](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:458) - local
- [randomPartialTarget](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:466) - local
- [defaultMirrorSweepX](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:470) - local
- [resetMirrorAnimation](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:474) - local
- [startMirrorSweepBurst](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:487) - local
- [startNextMirrorSweepLeg](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:498) - local
- [mirrorAnimationIdle](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:509) - local
- [mirrorSweepX](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:514) - local
- [mirrorCutX](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:576) - local
- [drawMirrorSegment](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:582) - local
- [pushPointFilter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:614) - local
- [popPointFilter](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:624) - local
- [drawMirrorTextureClipped](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:629) - local
- [drawMirrorWordOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:660) - local
- [syncOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:695) - local
- [requestMirrorAnimation](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:711) - local
- [ensurePanelManager](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:721) - local
- [managerHasDecorators](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:733) - local
- [addDecoratorOrder](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:737) - local
- [removeDecoratorOrder](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:746) - local
- [decoratorsWantTextHidden](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:756) - local
- [decoratorsWantMirrorActions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:765) - local
- [restoreManagedPanelText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:774) - local
- [updateManagedPanelText](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:783) - local
- [syncManagedOverlays](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:796) - local
- [ensurePaintHooks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:810) - local
- [manager.paintOverWrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:812) - assigned
- [manager.performLayoutWrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:829) - assigned
- [ensureMirrorActionHooks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:846) - local
- [manager.doClickWrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:848) - assigned
- [manager.onCursorEnteredWrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:867) - assigned
- [restoreManagedHook](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:886) - local
- [updateMirrorActionHooks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:894) - local
- [compactPanelManager](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:904) - local
- [removeOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:920) - assigned
- [installOverlay](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:935) - local
- [clearPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:973) - local
- [scanPanel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:984) - local
- [scanKnownMenus](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:996) - local

<a id="pfad-9"></a>
## Pfad 9: Primitive-Kompatibilitaet

Relevanz: Spezialpfad fuer Primitive-Entities und Duplicator; wichtig bei Copy/Mirror/Undo mit Primitives.

### Kernfluss

- [Compat.IsPrimitive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sh.lua:16) - Primitive-Erkennung, exportiert als `M.IsPrimitive`
- [clonePrimitiveEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sv.lua:12) - Server-Clone-Fallback, exportiert als `Compat.CloneEntity`
- [Compat.SetGhost](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:445) - clientside Primitive-Ghost

### Dateien

- [lua/magic_align/compat/primitive_sh.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sh.lua) - 23 Zeilen, 2 Funktionseintraege
- [lua/magic_align/compat/primitive_sv.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sv.lua) - 84 Zeilen, 1 Funktionseintraege
- [lua/magic_align/compat/primitive_cl.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua) - 484 Zeilen, 20 Funktionseintraege

### Funktionen

#### [lua/magic_align/compat/primitive_sh.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sh.lua) (23 Zeilen, 2 Funktionen)
- [isPrimitiveBaseClass](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sh.lua:8) - local
- [Compat.IsPrimitive](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sh.lua:16) - member/global

#### [lua/magic_align/compat/primitive_sv.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sv.lua) (84 Zeilen, 1 Funktionen)
- [clonePrimitiveEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_sv.lua:12) - local

#### [lua/magic_align/compat/primitive_cl.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua) (484 Zeilen, 20 Funktionen)
- [cloneVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:20) - local
- [cloneAng](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:25) - local
- [setVec](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:30) - local
- [setAng](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:43) - local
- [angleApprox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:56) - local
- [vectorApprox](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:65) - local
- [invalidateGhostSyncCache](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:69) - local
- [cloneValue](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:96) - local
- [valueSignature](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:112) - local
- [ghostState](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:129) - local
- [removeGhostEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:138) - local
- [primitiveRevision](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:151) - local
- [previewRenderMode](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:181) - local
- [ensureGhostEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:193) - local
- [syncGhostEntity](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:238) - local
- [refreshGhostEntry](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:390) - local
- [previewMirrorAxis](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:402) - local
- [Compat.ClearGhost](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:418) - member/global
- [Compat.ClearGhosts](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:432) - member/global
- [Compat.SetGhost](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/compat/primitive_cl.lua:445) - member/global

<a id="pfad-10"></a>
## Pfad 10: Profiling und Diagnose

Relevanz: Hilft beim Messen/Debuggen, aendert normalerweise keinen Tool-State.

### Kernfluss

- [Profiler:Start](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:635) - Profiler aktivieren
- [Profiler:Stop](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:670) - Profiler deaktivieren
- [Profiler:PrintReport](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:575) - Messdaten ausgeben

### Dateien

- [lua/autorun/client/magic_align_profiler.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/client/magic_align_profiler.lua) - 3 Zeilen, 0 Funktionseintraege
- [lua/magic_align/client/profiler.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua) - 727 Zeilen, 50 Funktionseintraege

### Funktionen

#### [lua/autorun/client/magic_align_profiler.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/client/magic_align_profiler.lua) (3 Zeilen, 0 Funktionen)
- Keine eigene Funktionsdefinition; Loader/Include-Datei.

#### [lua/magic_align/client/profiler.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua) (727 Zeilen, 50 Funktionen)
- [now](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:35) - local
- [memoryKb](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:39) - local
- [clampNumber](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:43) - local
- [containsMagicAlign](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:51) - local
- [isProfilerLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:57) - local
- [functionSource](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:63) - local
- [shortLabel](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:70) - local
- [safeName](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:81) - local
- [currentHookFunction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:87) - local
- [getControlTable](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:93) - local
- [finishMeasuredCall](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:105) - local
- [Profiler:Reset](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:121) - member/global
- [Profiler:Suppress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:148) - member/global
- [Profiler:Unsuppress](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:152) - member/global
- [Profiler:GetStat](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:156) - member/global
- [Profiler:Record](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:183) - member/global
- [Profiler:MeasuredFunction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:209) - member/global
- [wrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:213) - local assigned
- [Profiler:OwnerKey](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:231) - member/global
- [Profiler:WrapOwnerFunction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:235) - member/global
- [Profiler:WrapTableFunctions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:262) - member/global
- [Profiler:ShouldWrapHook](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:272) - member/global
- [Profiler:WrapHookFunction](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:283) - member/global
- [Profiler:WrapExistingHooks](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:301) - member/global
- [Profiler:InstallHookAddWrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:321) - member/global
- [wrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:327) - local assigned
- [Profiler:ShouldWrapNetReceiver](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:346) - member/global
- [Profiler:WrapNetReceiver](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:351) - member/global
- [Profiler:WrapExistingNetReceivers](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:369) - member/global
- [Profiler:InstallNetReceiveWrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:381) - member/global
- [wrapper](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:387) - local assigned
- [Profiler:AddToolCandidate](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:406) - member/global
- [Profiler:ToolCandidates](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:414) - member/global
- [Profiler:WrapToolMethods](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:436) - member/global
- [Profiler:WrapModuleFunctions](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:444) - member/global
- [Profiler:WrapVguiControl](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:474) - member/global
- [Profiler:WrapVguiControls](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:479) - member/global
- [Profiler:Discover](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:484) - member/global
- [Profiler:SampleFrame](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:496) - member/global
- [Profiler:Think](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:516) - member/global
- [Profiler:RowsSorted](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:533) - member/global
- [Profiler:PrintRows](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:547) - member/global
- [Profiler:PrintReport](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:575) - member/global
- [Profiler:Restore](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:612) - member/global
- [Profiler:Start](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:635) - member/global
- [Profiler:Stop](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:670) - member/global
- [Profiler:Status](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:684) - member/global
- [concommand.Add magic_align_profile](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:701) - concommand callback
- [concommand.Add magic_align_profile_stop](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:717) - concommand callback
- [concommand.Add magic_align_profile_status](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:721) - concommand callback

## Anonyme Inline-Funktionen

Diese Eintraege sind namenlose `function(...)`-Ausdruecke, die nicht als benannte Funktion, `hook.Add`, `net.Receive` oder `concommand.Add` starteten.

### [lua/autorun/magic_align.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua) (2)
- [anonymous@321](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:321) - `return activeToolByPredicate(ply, function(mode)`
- [anonymous@327](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/magic_align.lua:327) - `return activeToolByPredicate(ply, function(mode)`

### [lua/autorun/server/magic_align_commit.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua) (1)
- [anonymous@449](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/autorun/server/magic_align_commit.lua:449) - `task.co = coroutine.create(function()`

### [lua/magic_align/client/dmagic_align_numslider.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua) (3)
- [anonymous@524](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:524) - `timer.Simple(0, function()`
- [anonymous@1371](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1371) - `timer.Simple(0, function()`
- [anonymous@1377](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/dmagic_align_numslider.lua:1377) - `timer.Simple(0, function()`

### [lua/magic_align/client/formula_manager.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua) (1)
- [anonymous@191](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/formula_manager.lua:191) - `cvars.AddChangeCallback(cvarName, function()`

### [lua/magic_align/client/math_parser.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua) (2)
- [anonymous@417](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:417) - `local success, result = xpcall(function()`
- [anonymous@434](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/math_parser.lua:434) - `end, function(err)`

### [lua/magic_align/client/menu.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua) (5)
- [anonymous@268](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:268) - `cvars.AddChangeCallback(name, function(_, _, newValue)`
- [anonymous@490](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:490) - `cvars.AddChangeCallback(name, function()`
- [anonymous@1753](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:1753) - `slider:SetInputSnap("slider", function()`
- [anonymous@2307](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2307) - `return function()`
- [anonymous@2394](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menu.lua:2394) - `slider:SetInputSnap("slider", function()`

### [lua/magic_align/client/menuentryhack.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua) (4)
- [anonymous@431](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:431) - `drawIntoRenderTarget(normalRt, textColor, function()`
- [anonymous@1012](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:1012) - `hook.Add(hookName, SCAN_ID, function()`
- [anonymous@1022](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:1022) - `cvars.AddChangeCallback(ENABLE_CVAR, function()`
- [anonymous@1027](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/menuentryhack.lua:1027) - `timer.Create(SCAN_ID, 1, 0, function()`

### [lua/magic_align/client/profiler.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua) (9)
- [anonymous@253](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:253) - `self.restoreStack[#self.restoreStack + 1] = function()`
- [anonymous@291](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:291) - `self.restoreStack[#self.restoreStack + 1] = function()`
- [anonymous@339](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:339) - `self.restoreStack[#self.restoreStack + 1] = function()`
- [anonymous@360](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:360) - `self.restoreStack[#self.restoreStack + 1] = function()`
- [anonymous@399](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:399) - `self.restoreStack[#self.restoreStack + 1] = function()`
- [anonymous@591](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:591) - `self:PrintRows("Top CPU, inclusive", self:RowsSorted(function(a, b)`
- [anonymous@595](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:595) - `self:PrintRows("Top heap growth", self:RowsSorted(function(a, b)`
- [anonymous@603](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:603) - `self:PrintRows("Top GC drops observed inside calls", self:RowsSorted(function(a, b)`
- [anonymous@659](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/profiler.lua:659) - `hook.Add("Think", FRAME_HOOK, function()`

### [lua/magic_align/client/render.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua) (6)
- [anonymous@660](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:660) - `hook.Add("PostRender", SHAPE_CONFIG.rebuildHook, function()`
- [anonymous@1197](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1197) - `hook.Add("PostRender", rtConfig.rebuildHook, function()`
- [anonymous@1689](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:1689) - `(function()`
- [anonymous@2349](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:2349) - `(function()`
- [anonymous@3715](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3715) - `hook.Add("PostRender", STRIPE_CONFIG.rebuildHook, function()`
- [anonymous@3728](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render.lua:3728) - `cvars.AddChangeCallback(RENDER_CONFIG.ringQualityCvar, function(_, _, newValue)`

### [lua/magic_align/client/render_toolgun.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua) (1)
- [anonymous@1030](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/render_toolgun.lua:1030) - `hook.Add("PostRender", COMPASS_RING_REBUILD_HOOK, function()`

### [lua/magic_align/client/tool_interaction.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua) (2)
- [anonymous@536](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:536) - `local sourceAnchorOptions = M.AnchorOptionsFromReader(function(name)`
- [anonymous@539](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_interaction.lua:539) - `local targetAnchorOptions = M.AnchorOptionsFromReader(function(name)`

### [lua/magic_align/client/tool_offsets.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua) (1)
- [anonymous@95](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_offsets.lua:95) - `cvars.AddChangeCallback(cvarName, function()`

### [lua/magic_align/client/tool_session.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua) (2)
- [anonymous@318](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:318) - `table.sort(probes, function(a, b)`
- [anonymous@458](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/tool_session.lua:458) - `table.sort(keys, function(a, b)`

### [lua/magic_align/client/world_bsp.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua) (3)
- [anonymous@562](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:562) - `hook.Add("Think", BACKGROUND_CACHE_HOOK, function()`
- [anonymous@662](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:662) - `table.sort(out, function(a, b)`
- [anonymous@781](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp.lua:781) - `table.sort(pairs, function(a, b)`

### [lua/magic_align/client/world_bsp_cache.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua) (3)
- [anonymous@417](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:417) - `table.sort(sections, function(a, b)`
- [anonymous@536](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:536) - `table.sort(groups, function(a, b)`
- [anonymous@1017](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_cache.lua:1017) - `cache.worker = coroutine.create(function()`

### [lua/magic_align/client/world_bsp_reader.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua) (1)
- [anonymous@3](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_reader.lua:3) - `return function(deps)`

### [lua/magic_align/client/world_bsp_records.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua) (1)
- [anonymous@3](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/client/world_bsp_records.lua:3) - `return function(worldBSP, deps)`

### [lua/magic_align/entity_mirror.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua) (9)
- [anonymous@1414](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1414) - `timer.Simple(0, function()`
- [anonymous@1422](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1422) - `duplicator.RegisterEntityModifier(M.ENTITY_MIRROR_MODIFIER_ID, function(_, ent, data)`
- [anonymous@1615](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:1615) - `timer.Simple(INITIAL_RECONCILE_DELAYS[attempt] or 0, function()`
- [anonymous@2293](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2293) - `timer.Simple(INITIAL_RECONCILE_DELAYS[nextAttempt] or 0, function()`
- [anonymous@2322](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2322) - `timer.Simple(0, function()`
- [anonymous@2369](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2369) - `timer.Simple(delay, function()`
- [anonymous@2632](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2632) - `timer.Simple(0, function()`
- [anonymous@2647](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2647) - `timer.Simple(0, function()`
- [anonymous@2742](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/entity_mirror.lua:2742) - `table.sort(list, function(a, b)`

### [lua/magic_align/tool_config.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua) (10)
- [anonymous@12](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:12) - `geometry.isWorldTarget = geometry.isWorldTarget or function()`
- [anonymous@16](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:16) - `geometry.hasTargetEntity = geometry.hasTargetEntity or function(ent)`
- [anonymous@20](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:20) - `geometry.traceHitsWorld = geometry.traceHitsWorld or function()`
- [anonymous@24](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:24) - `geometry.traceMatchesEntity = geometry.traceMatchesEntity or function()`
- [anonymous@28](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:28) - `geometry.worldPosFromLocalPoint = geometry.worldPosFromLocalPoint or function()`
- [anonymous@32](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:32) - `geometry.localPointFromWorldPos = geometry.localPointFromWorldPos or function()`
- [anonymous@36](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:36) - `geometry.localNormalFromWorld = geometry.localNormalFromWorld or function()`
- [anonymous@40](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:40) - `geometry.worldNormalFromLocal = geometry.worldNormalFromLocal or function()`
- [anonymous@44](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:44) - `geometry.pointFromCandidate = geometry.pointFromCandidate or function()`
- [anonymous@48](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/tool_config.lua:48) - `geometry.traceCandidate = geometry.traceCandidate or function()`

### [lua/magic_align/toolgun_effects.lua](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua) (2)
- [anonymous@254](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:254) - `withEffectColor(marker.color, function()`
- [anonymous@319](N:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/addons/magic_align_test2/lua/magic_align/toolgun_effects.lua:319) - `withEffectColor(marker.color, function()`

## Pflegehinweise

- Aenderungen an Copy/Copy&Move/Mirror immer ueber die gemeinsame Commit-/Clone-Pipeline fuehren.
- Point-Referenzen zentral ueber `ResolvePoint*`/`SetPointReference` behandeln.
- Undo-Restore bleibt best-effort fuer Session-State, aber Entity-Undo muss immer laufen.
- World-BSP-Aenderungen immer auf Performance, Cache-Invalidierung und Map-Sonderfaelle pruefen.
