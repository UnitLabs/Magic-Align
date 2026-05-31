MAGIC_ALIGN = MAGIC_ALIGN or {}

local M = MAGIC_ALIGN
local isvector = M.IsVectorLike

M.ANCHOR_CENTER_ID = "mid123"
M.ANCHOR_PERCENT_MIN = 0
M.ANCHOR_PERCENT_MAX = 100
M.ANCHOR_PERCENT_STEP = 5
M.ANCHOR_PERCENT_DEFAULT = 50
M.ANCHOR_PERCENT_KEYS = { "mid12", "mid23", "mid13" }
M.ANCHORS = {
    { id = "p1", label = "P1" },
    { id = "p2", label = "P2" },
    { id = "p3", label = "P3" },
    { id = "mid12", label = "Mid P1-P2" },
    { id = "mid23", label = "Mid P2-P3" },
    { id = "mid13", label = "Mid P1-P3" },
    { id = M.ANCHOR_CENTER_ID, label = "General Mid" }
}
M.DEFAULT_PRIORITY = { "p1", "mid12", "p2", "p3", "mid23", "mid13", M.ANCHOR_CENTER_ID }

local priorityCache = {}

function M.ParsePriority(text)
    if istable(text) then return text end

    local key = string.lower(tostring(text or ""))
    local cached = priorityCache[key]
    if cached then
        return cached
    end

    local out = {}

    for token in string.gmatch(key, "[^,%s]+") do
        out[#out + 1] = token
    end

    priorityCache[key] = out
    return out
end

function M.ClampAnchorPercent(value)
    return math.Clamp(
        tonumber(value) or M.ANCHOR_PERCENT_DEFAULT,
        M.ANCHOR_PERCENT_MIN,
        M.ANCHOR_PERCENT_MAX
    )
end

function M.SnapAnchorPercent(value)
    local clamped = M.ClampAnchorPercent(value)
    local step = math.max(tonumber(M.ANCHOR_PERCENT_STEP) or 1, 1)
    local snapped = M.ANCHOR_PERCENT_MIN + math.Round((clamped - M.ANCHOR_PERCENT_MIN) / step) * step

    return math.Clamp(snapped, M.ANCHOR_PERCENT_MIN, M.ANCHOR_PERCENT_MAX)
end

function M.NormalizeAnchorOptions(options)
    options = istable(options) and options or {}

    if options._magicAlignNormalizedAnchorOptions == true then
        return options
    end

    return {
        _magicAlignNormalizedAnchorOptions = true,
        mid12_pct = M.ClampAnchorPercent(options.mid12_pct or options.mid12),
        mid23_pct = M.ClampAnchorPercent(options.mid23_pct or options.mid23),
        mid13_pct = M.ClampAnchorPercent(options.mid13_pct or options.mid13)
    }
end

function M.NormalizeAnchorOptionsCached(cache, options)
    if not istable(cache) then
        return M.NormalizeAnchorOptions(options)
    end

    options = istable(options) and options or {}
    local mid12 = M.ClampAnchorPercent(options.mid12_pct or options.mid12)
    local mid23 = M.ClampAnchorPercent(options.mid23_pct or options.mid23)
    local mid13 = M.ClampAnchorPercent(options.mid13_pct or options.mid13)
    local out = cache.options
    if not istable(out) then
        out = { _magicAlignNormalizedAnchorOptions = true }
        cache.options = out
    end

    if out.mid12_pct ~= mid12 or out.mid23_pct ~= mid23 or out.mid13_pct ~= mid13 then
        out.mid12_pct = mid12
        out.mid23_pct = mid23
        out.mid13_pct = mid13
        cache.revision = (tonumber(cache.revision) or 0) + 1
    end

    return out, tonumber(cache.revision) or 0
end

function M.AnchorOptionsFromReader(readValue, prefix)
    if type(readValue) ~= "function" then
        return M.NormalizeAnchorOptions()
    end

    prefix = tostring(prefix or "")
    if prefix ~= "" and not string.EndsWith(prefix, "_") then
        prefix = prefix .. "_"
    end

    return M.NormalizeAnchorOptions({
        mid12_pct = readValue(prefix .. "mid12_pct"),
        mid23_pct = readValue(prefix .. "mid23_pct"),
        mid13_pct = readValue(prefix .. "mid13_pct")
    })
end

local function interpolation(options, key)
    return (options[key .. "_pct"] or M.ANCHOR_PERCENT_DEFAULT) * 0.01
end

local function lerpPoint(a, b, t)
    return M.AddVectorsPrecise(
        M.ScaleVectorPrecise(a, 1 - t),
        M.ScaleVectorPrecise(b, t)
    )
end

local function setPoint(out, point)
    if not isvector(point) then return end

    if not isvector(out) then
        return M.VectorP(point.x, point.y, point.z)
    end

    out.x, out.y, out.z = point.x, point.y, point.z
    return out
end

local function lerpPointInto(out, a, b, t)
    if not isvector(a) or not isvector(b) then return end

    if not isvector(out) then
        out = M.VectorP(0, 0, 0)
    end

    out.x = a.x + (b.x - a.x) * t
    out.y = a.y + (b.y - a.y) * t
    out.z = a.z + (b.z - a.z) * t
    return out
end

local function anchorPoint(points, id, options)
    points = istable(points) and points or {}

    local p1, p2, p3 = points[1], points[2], points[3]

    if id == "p1" then return p1 end
    if id == "p2" then return p2 end
    if id == "p3" then return p3 end
    if id == "mid12" and p1 and p2 then return lerpPoint(p1, p2, interpolation(options, "mid12")) end
    if id == "mid23" and p2 and p3 then return lerpPoint(p2, p3, interpolation(options, "mid23")) end
    if id == "mid13" and p1 and p3 then return lerpPoint(p1, p3, interpolation(options, "mid13")) end

    if id == M.ANCHOR_CENTER_ID and p1 and p2 and p3 then
        local m12 = anchorPoint(points, "mid12", options)
        local m23 = anchorPoint(points, "mid23", options)
        local m13 = anchorPoint(points, "mid13", options)

        if m12 and m23 and m13 then
            return M.ScaleVectorPrecise(M.AddVectorsPrecise(M.AddVectorsPrecise(m12, m23), m13), 1 / 3)
        end
    end
end

local function anchorPointInto(out, points, id, options, scratch)
    points = istable(points) and points or {}
    scratch = istable(scratch) and scratch or {}

    local p1, p2, p3 = points[1], points[2], points[3]

    if id == "p1" then return setPoint(out, p1) end
    if id == "p2" then return setPoint(out, p2) end
    if id == "p3" then return setPoint(out, p3) end
    if id == "mid12" and p1 and p2 then return lerpPointInto(out, p1, p2, interpolation(options, "mid12")) end
    if id == "mid23" and p2 and p3 then return lerpPointInto(out, p2, p3, interpolation(options, "mid23")) end
    if id == "mid13" and p1 and p3 then return lerpPointInto(out, p1, p3, interpolation(options, "mid13")) end

    if id == M.ANCHOR_CENTER_ID and p1 and p2 and p3 then
        local m12 = lerpPointInto(scratch.m12, p1, p2, interpolation(options, "mid12"))
        local m23 = lerpPointInto(scratch.m23, p2, p3, interpolation(options, "mid23"))
        local m13 = lerpPointInto(scratch.m13, p1, p3, interpolation(options, "mid13"))
        scratch.m12, scratch.m23, scratch.m13 = m12, m23, m13

        if m12 and m23 and m13 then
            if not isvector(out) then
                out = M.VectorP(0, 0, 0)
            end

            out.x = (m12.x + m23.x + m13.x) / 3
            out.y = (m12.y + m23.y + m13.y) / 3
            out.z = (m12.z + m23.z + m13.z) / 3
            return out
        end
    end
end

function M.AnchorPoint(points, id, options)
    return anchorPoint(points, string.lower(tostring(id or "")), M.NormalizeAnchorOptions(options))
end

function M.AnchorAvailable(id, count)
    id = string.lower(tostring(id or ""))

    if id == "p1" then return count >= 1 end
    if id == "p2" or id == "mid12" then return count >= 2 end
    if id == "p3" or id == "mid23" or id == "mid13" or id == M.ANCHOR_CENTER_ID then return count >= 3 end

    return false
end

function M.ResolveAnchor(points, selected, priority, options)
    local seen = {}
    local normalized = M.NormalizeAnchorOptions(options)
    local parsedPriority = M.ParsePriority(priority)

    local function try(id)
        id = string.lower(tostring(id or ""))
        if id == "" or seen[id] then return end
        seen[id] = true

        local pos = anchorPoint(points, id, normalized)
        if isvector(pos) then
            return id, pos
        end
    end

    local id, pos = try(selected)
    if pos then return id, pos end

    for _, name in ipairs(parsedPriority) do
        id, pos = try(name)
        if pos then return id, pos end
    end

    for _, name in ipairs(M.DEFAULT_PRIORITY) do
        id, pos = try(name)
        if pos then return id, pos end
    end
end

local function anchorPriorityKey(priority)
    if istable(priority) then
        return table.concat(priority, ",")
    end

    return string.lower(tostring(priority or ""))
end

local function anchorPointsSignature(entry, points)
    points = istable(points) and points or {}

    local changed = entry.count ~= #points
    entry.count = #points

    for i = 1, 3 do
        local point = points[i]
        local prefix = "p" .. i
        if isvector(point) then
            if entry[prefix .. "x"] ~= point.x or entry[prefix .. "y"] ~= point.y or entry[prefix .. "z"] ~= point.z then
                changed = true
            end
            entry[prefix .. "x"], entry[prefix .. "y"], entry[prefix .. "z"] = point.x, point.y, point.z
        elseif entry[prefix .. "x"] ~= nil then
            changed = true
            entry[prefix .. "x"], entry[prefix .. "y"], entry[prefix .. "z"] = nil, nil, nil
        end
    end

    return changed
end

local function resolveAnchorInto(entry, points, selected, parsedPriority, normalized)
    local seen = entry.seen
    if not istable(seen) then
        seen = {}
        entry.seen = seen
    end
    for key in pairs(seen) do
        seen[key] = nil
    end

    local scratch = entry.scratch or {}
    entry.scratch = scratch

    local function try(id)
        id = string.lower(tostring(id or ""))
        if id == "" or seen[id] then return end
        seen[id] = true

        local pos = anchorPointInto(entry.pos, points, id, normalized, scratch)
        if isvector(pos) then
            entry.pos = pos
            return id, pos
        end
    end

    local id, pos = try(selected)
    if pos then return id, pos end

    for _, name in ipairs(parsedPriority) do
        id, pos = try(name)
        if pos then return id, pos end
    end

    for _, name in ipairs(M.DEFAULT_PRIORITY) do
        id, pos = try(name)
        if pos then return id, pos end
    end
end

function M.ResolveAnchorCached(cache, points, selected, priority, options, cacheOptions)
    if not istable(cache) then
        return M.ResolveAnchor(points, selected, priority, options)
    end

    cacheOptions = istable(cacheOptions) and cacheOptions or {}
    local entries = cache.entries
    if not istable(entries) then
        entries = {}
        cache.entries = entries
    end

    local selectedKey = string.lower(tostring(selected or ""))
    local parsedPriority = M.ParsePriority(priority)
    local priorityKey = anchorPriorityKey(parsedPriority)
    local normalized = M.NormalizeAnchorOptions(options)
    local revision = cacheOptions.revision
    local count = tonumber(entries.count) or 0
    if count > 16 then
        entries.count = 0
        count = 0
    end
    local entry

    for i = 1, count do
        local candidate = entries[i]
        if candidate
            and candidate.points == points
            and candidate.selected == selectedKey
            and candidate.priorityKey == priorityKey then
            entry = candidate
            break
        end
    end

    if not entry then
        count = count + 1
        entries.count = count
        entry = entries[count]
        if not istable(entry) then
            entry = {}
            entries[count] = entry
        end
    end

    local changed = entry.points ~= points
        or entry.selected ~= selectedKey
        or entry.priorityKey ~= priorityKey
        or entry.revision ~= revision
        or entry.mid12_pct ~= normalized.mid12_pct
        or entry.mid23_pct ~= normalized.mid23_pct
        or entry.mid13_pct ~= normalized.mid13_pct

    entry.points = points
    entry.selected = selectedKey
    entry.priorityKey = priorityKey
    entry.revision = revision
    entry.mid12_pct = normalized.mid12_pct
    entry.mid23_pct = normalized.mid23_pct
    entry.mid13_pct = normalized.mid13_pct

    if anchorPointsSignature(entry, points) then
        changed = true
    end

    if changed or entry.valid == nil then
        local id, pos = resolveAnchorInto(entry, points, selectedKey, parsedPriority, normalized)
        entry.id = id
        entry.valid = isvector(pos)
    end

    if not entry.valid then return end
    if cacheOptions.copy then
        return entry.id, M.VectorP(entry.pos.x, entry.pos.y, entry.pos.z)
    end

    return entry.id, entry.pos
end

return M
