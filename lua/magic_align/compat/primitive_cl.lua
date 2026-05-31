if SERVER then return end

MAGIC_ALIGN = MAGIC_ALIGN or {}

local M = MAGIC_ALIGN
local Compat = M.Compat or {}
local isvector = M.IsVectorLike
local isangle = M.IsAngleLike
local toVector = M.ToVector
local toAngle = M.ToAngle

local APPEARANCE_SYNC_INTERVAL = 0.15

M.Compat = Compat

hook.Remove("PostDrawTranslucentRenderables", "MagicAlignPrimitiveCompatGhosts")
hook.Remove("Think", "MagicAlignPrimitiveCompatGhosts")
hook.Remove("Think", "MagicAlignPrimitiveCompatGhostsThink")

local function cloneVec(v)
    if not isvector(v) then return end
    return M.CopyVectorPrecise(v)
end

local function cloneAng(a)
    if not isangle(a) then return end
    return M.CopyAnglePrecise(a)
end

local function setVec(dst, src)
    if not isvector(src) then return end
    if not isvector(dst) then
        return cloneVec(src)
    end

    dst.x = src.x
    dst.y = src.y
    dst.z = src.z

    return dst
end

local function setAng(dst, src)
    if not isangle(src) then return end
    if not isangle(dst) then
        return cloneAng(src)
    end

    dst.p = src.p
    dst.y = src.y
    dst.r = src.r

    return dst
end

local function angleApprox(a, b, eps)
    if not isangle(a) or not isangle(b) then return false end

    eps = tonumber(eps) or M.UI_COMPARE_EPSILON
    return math.abs(math.AngleDifference(a.p, b.p)) <= eps
        and math.abs(math.AngleDifference(a.y, b.y)) <= eps
        and math.abs(math.AngleDifference(a.r, b.r)) <= eps
end

local function vectorApprox(a, b, eps)
    if isfunction(M.VectorApprox) then
        return M.VectorApprox(a, b, eps)
    end

    if not isvector(a) or not isvector(b) then return false end

    eps = tonumber(eps) or M.UI_COMPARE_EPSILON or 0.0001
    return math.abs(a.x - b.x) <= eps
        and math.abs(a.y - b.y) <= eps
        and math.abs(a.z - b.z) <= eps
end

local function invalidateGhostSyncCache(ghost)
    if not IsValid(ghost) then return end

    ghost._magicAlignPos = nil
    ghost._magicAlignAng = nil
    ghost._magicAlignSkin = nil
    ghost._magicAlignMaterial = nil
    ghost._magicAlignCollisionGroup = nil
    ghost._magicAlignModelScale = nil
    ghost._magicAlignRenderFX = nil
    ghost._magicAlignBodygroups = nil
    ghost._magicAlignSubMaterials = nil
    ghost._magicAlignSubMaterialCount = nil
    ghost._magicAlignColorR = nil
    ghost._magicAlignColorG = nil
    ghost._magicAlignColorB = nil
    ghost._magicAlignColorA = nil
    ghost._magicAlignRenderMode = nil
    ghost._magicAlignEntityMirrorPreviewAxis = nil
    ghost._magicAlignEntityMirrorBaseRenderMins = nil
    ghost._magicAlignEntityMirrorBaseRenderMaxs = nil

    local materials = isfunction(ghost.GetMaterials) and ghost:GetMaterials() or nil
    ghost._magicAlignSubMaterialSlots = materials and #materials or 0
    ghost._magicAlignNeedsBoneSetup = true
end

local function cloneValue(value)
    if isvector(value) then
        return toVector(value)
    end

    if isangle(value) then
        return toAngle(value)
    end

    if istable(value) then
        return table.Copy(value)
    end

    return value
end

local function valueSignature(value)
    if isvector(value) then
        return ("v:%0.5f,%0.5f,%0.5f"):format(value.x, value.y, value.z)
    end

    if isangle(value) then
        return ("a:%0.5f,%0.5f,%0.5f"):format(value.p, value.y, value.r)
    end

    if istable(value) then
        local ok, json = pcall(util.TableToJSON, value)
        return ok and json or tostring(value)
    end

    return tostring(value)
end

local function ghostState(state)
    if not istable(state) then return end

    state.compatGhosts = state.compatGhosts or {}
    state.compatGhosts.linked = state.compatGhosts.linked or {}

    return state.compatGhosts
end

local function removeGhostEntity(entry)
    if not istable(entry) then return end

    if IsValid(entry.ghost) then
        entry.ghost:Remove()
    end

    entry.ghost = nil
    entry.revision = nil
    entry.nextAppearanceSync = nil
    entry.failed = nil
end

local function primitiveRevision(ent)
    if not IsValid(ent) then return "invalid" end

    local parts = {
        ent:GetClass(),
        tostring(math.max(tonumber(ent:GetModelScale() or 1) or 1, M.MODEL_SCALE_EPSILON)),
        tostring(ent:GetSkin() or 0),
        tostring(ent:GetMaterial() or "")
    }

    if isfunction(ent.PrimitiveGetKeys) then
        local keys = ent:PrimitiveGetKeys()
        if istable(keys) then
            local names = {}
            for name in pairs(keys) do
                names[#names + 1] = name
            end

            table.sort(names)

            for i = 1, #names do
                local name = names[i]
                parts[#parts + 1] = name .. "=" .. valueSignature(keys[name])
            end
        end
    end

    return table.concat(parts, "|")
end

local function previewRenderMode(src, alpha)
    local mode = isfunction(src.GetRenderMode) and src:GetRenderMode() or RENDERMODE_NORMAL

    if alpha < 255 then
        if mode == RENDERMODE_NORMAL or mode == RENDERMODE_NONE or mode == RENDERMODE_TRANSCOLOR then
            mode = RENDERMODE_TRANSALPHA
        end
    end

    return mode
end

local function ensureGhostEntity(entry)
    if not istable(entry) or not IsValid(entry.ent) then return end
    if entry.failed then return end

    local ghost = entry.ghost
    if IsValid(ghost) and ghost:GetClass() == entry.ent:GetClass() then
        return ghost
    end

    removeGhostEntity(entry)

    if not ents or not isfunction(ents.CreateClientside) then
        entry.failed = true
        return
    end

    ghost = ents.CreateClientside(entry.ent:GetClass(), RENDERGROUP_TRANSLUCENT)
    if not IsValid(ghost) then
        entry.failed = true
        return
    end

    local model = entry.ent:GetModel()
    if isstring(model) and model ~= "" and isfunction(ghost.SetModel) then
        ghost:SetModel(model)
    end

    ghost:SetNoDraw(true)
    ghost:SetRenderMode(RENDERMODE_TRANSALPHA)
    ghost:DrawShadow(false)

    if isfunction(ghost.Spawn) then
        ghost:Spawn()
    end

    if isfunction(ghost.Activate) then
        ghost:Activate()
    end

    local materials = ghost:GetMaterials()
    ghost._magicAlignSubMaterialSlots = materials and #materials or 0
    ghost._magicAlignNeedsBoneSetup = true
    entry.ghost = ghost
    entry.failed = nil
    entry.revision = nil
    entry.nextAppearanceSync = 0

    return ghost
end

local function syncGhostEntity(entry)
    local src = istable(entry) and entry.ent or nil
    local ghost = istable(entry) and entry.ghost or nil
    if not IsValid(src) or not IsValid(ghost) then return false end
    if not isvector(entry.pos) or not isangle(entry.ang) then return false end
    if istable(ghost.primitive) and type(ghost.primitive.thread) == "thread" then
        return false
    end

    local needsBoneSetup = ghost._magicAlignNeedsBoneSetup == true
    local now = RealTime()

    if entry.revision == nil or (entry.nextAppearanceSync or 0) <= now then
        local revision = primitiveRevision(src)
        if entry.revision ~= revision then
            if isfunction(src.PrimitiveGetKeys) then
                local keys = src:PrimitiveGetKeys()
                if istable(keys) then
                    for name, value in pairs(keys) do
                        local setter = ghost["Set" .. name]
                        if isfunction(setter) then
                            setter(ghost, cloneValue(value))
                        end
                    end
                end
            end

            entry.revision = revision
            if isfunction(ghost.PrimitiveReconstruct) then
                ghost:PrimitiveReconstruct()
                invalidateGhostSyncCache(ghost)
                if istable(ghost.primitive) and type(ghost.primitive.thread) == "thread" then
                    return false
                end
            end

            needsBoneSetup = true
        end

        local model = src:GetModel()
        if isstring(model) and model ~= "" and isfunction(ghost.SetModel) and ghost:GetModel() ~= model then
            ghost:SetModel(model)
            invalidateGhostSyncCache(ghost)
            needsBoneSetup = true
        end

        local skin = src:GetSkin() or 0
        if ghost._magicAlignSkin ~= skin then
            ghost:SetSkin(skin)
            ghost._magicAlignSkin = skin
            needsBoneSetup = true
        end

        local material = src:GetMaterial() or ""
        if ghost._magicAlignMaterial ~= material then
            ghost:SetMaterial(material)
            ghost._magicAlignMaterial = material
        end

        local collisionGroup = src:GetCollisionGroup()
        if ghost._magicAlignCollisionGroup ~= collisionGroup then
            ghost:SetCollisionGroup(collisionGroup)
            ghost._magicAlignCollisionGroup = collisionGroup
        end

        local modelScale = math.max(tonumber(src:GetModelScale() or 1) or 1, M.MODEL_SCALE_EPSILON)
        if ghost._magicAlignModelScale ~= modelScale then
            ghost:SetModelScale(modelScale, 0)
            ghost._magicAlignModelScale = modelScale
            needsBoneSetup = true
        end

        if isfunction(src.GetRenderFX) and isfunction(ghost.SetRenderFX) then
            local renderFX = src:GetRenderFX()
            if ghost._magicAlignRenderFX ~= renderFX then
                ghost:SetRenderFX(renderFX)
                ghost._magicAlignRenderFX = renderFX
            end
        end

        local bodygroups = ghost._magicAlignBodygroups or {}
        ghost._magicAlignBodygroups = bodygroups
        for i = 0, src:GetNumBodyGroups() - 1 do
            local bodygroup = src:GetBodygroup(i)
            if bodygroups[i] ~= bodygroup then
                ghost:SetBodygroup(i, bodygroup)
                bodygroups[i] = bodygroup
                needsBoneSetup = true
            end
        end

        local subMaterials = ghost._magicAlignSubMaterials or {}
        ghost._magicAlignSubMaterials = subMaterials
        local srcMaterials = src:GetMaterials()
        local subCount = math.max(
            srcMaterials and #srcMaterials or 0,
            ghost._magicAlignSubMaterialSlots or 0,
            ghost._magicAlignSubMaterialCount or 0
        )
        for i = 0, subCount - 1 do
            local subMaterial = src:GetSubMaterial(i) or ""
            if subMaterials[i] ~= subMaterial then
                ghost:SetSubMaterial(i, subMaterial)
                subMaterials[i] = subMaterial
                needsBoneSetup = true
            end
        end
        ghost._magicAlignSubMaterialCount = subCount

        entry.nextAppearanceSync = now + APPEARANCE_SYNC_INTERVAL
    end

    if not isvector(ghost._magicAlignPos) or not vectorApprox(ghost._magicAlignPos, entry.pos) then
        ghost:SetPos(toVector(entry.pos))
        ghost._magicAlignPos = setVec(ghost._magicAlignPos, entry.pos)
    end

    if not angleApprox(ghost._magicAlignAng, entry.ang) then
        ghost:SetAngles(toAngle(entry.ang))
        ghost._magicAlignAng = setAng(ghost._magicAlignAng, entry.ang)
    end

    local color = entry.color
    if color and (ghost._magicAlignColorR ~= color.r
        or ghost._magicAlignColorG ~= color.g
        or ghost._magicAlignColorB ~= color.b
        or ghost._magicAlignColorA ~= color.a) then
        ghost:SetColor(color)
        ghost._magicAlignColorR = color.r
        ghost._magicAlignColorG = color.g
        ghost._magicAlignColorB = color.b
        ghost._magicAlignColorA = color.a
    end

    local renderMode = previewRenderMode(src, color and color.a or 255)
    if ghost._magicAlignRenderMode ~= renderMode then
        ghost:SetRenderMode(renderMode)
        ghost._magicAlignRenderMode = renderMode
    end

    if needsBoneSetup and isfunction(ghost.SetupBones) then
        ghost:SetupBones()
        ghost._magicAlignNeedsBoneSetup = false
    end

    if M.EntityMirror and M.EntityMirror.ApplyVisualPreview then
        M.EntityMirror.ApplyVisualPreview(ghost, entry.entityMirrorAxis or M.ENTITY_MIRROR_NONE)
    end

    ghost:SetNoDraw(false)

    return true
end

local function refreshGhostEntry(entry)
    local ghost = ensureGhostEntity(entry)
    if not IsValid(ghost) then return false end

    if syncGhostEntity(entry) then
        return true
    end

    ghost:SetNoDraw(true)
    return false
end

local function previewMirrorAxis(state, ent, linked)
    local preview = istable(state) and state.preview or nil
    if not istable(preview) then return M.ENTITY_MIRROR_NONE end

    if linked and istable(preview.linked) then
        for i = 1, #preview.linked do
            local entry = preview.linked[i]
            if istable(entry) and entry.ent == ent then
                return entry.entityMirrorPreviewAxis or M.ENTITY_MIRROR_NONE
            end
        end
    end

    return preview.entityMirrorPreviewAxis or M.ENTITY_MIRROR_NONE
end

function Compat.ClearGhost(state, ent)
    local ghosts = ghostState(state)
    if not ghosts then return end

    if IsValid(ent) then
        removeGhostEntity(ghosts.linked[ent])
        ghosts.linked[ent] = nil
        return
    end

    removeGhostEntity(ghosts.main)
    ghosts.main = nil
end

function Compat.ClearGhosts(state)
    local ghosts = ghostState(state)
    if not ghosts then return end

    removeGhostEntity(ghosts.main)
    ghosts.main = nil

    for ent in pairs(ghosts.linked) do
        removeGhostEntity(ghosts.linked[ent])
        ghosts.linked[ent] = nil
    end
end

function Compat.SetGhost(state, ent, pos, ang, alphaFn, linked)
    if not Compat.IsPrimitive(ent) then return false end

    local ghosts = ghostState(state)
    if not ghosts then return true end

    local entry = linked and ghosts.linked[ent] or ghosts.main
    if not istable(entry) or entry.ent ~= ent then
        removeGhostEntity(entry)
        entry = { ent = ent }
    end

    local entColor = ent:GetColor()
    local alpha = isfunction(alphaFn) and alphaFn(entColor.a) or tonumber(alphaFn) or 120

    entry.ent = ent
    entry.pos = setVec(entry.pos, pos)
    entry.ang = setAng(entry.ang, ang)
    entry.color = entry.color or Color(255, 255, 255, 255)
    entry.color.r = entColor.r
    entry.color.g = entColor.g
    entry.color.b = entColor.b
    entry.color.a = math.Clamp(alpha, 0, 255)
    entry.entityMirrorAxis = previewMirrorAxis(state, ent, linked)
    entry.failed = nil

    if linked then
        ghosts.linked[ent] = entry
    else
        ghosts.main = entry
    end

    refreshGhostEntry(entry)

    return true
end

if istable(M.ClientState) then
    Compat.ClearGhosts(M.ClientState)
end
