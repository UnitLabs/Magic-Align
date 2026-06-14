MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN
local client = M.Client or {}
M.Client = client

local worldBSP = client.WorldBSP
if not istable(worldBSP) then
    local ok, included = pcall(include, "magic_align/client/world_bsp.lua")
    if ok and istable(included) then
        worldBSP = included
        client.WorldBSP = worldBSP
    else
        client.WorldBSPCacheLoadError = ok and "world_bsp.lua did not return WorldBSP" or tostring(included)
        print("Magic Align: World BSP persistent cache disabled: " .. tostring(client.WorldBSPCacheLoadError))
        return
    end
end

local persistent = worldBSP.PersistentCache or {}
worldBSP.PersistentCache = persistent

local cache = worldBSP.cache or {}
local internals = worldBSP.cacheInternals or {}

local CACHE_FORMAT_VERSION = 6
local CACHE_DIR = "magic_align/world_bsp_cache"
local HEADER_BYTES = 1036
local REQUIRED_SECTION_COUNT = 5
local UINT32_MAX = 4294967295
local LOAD_SURFACE_YIELD_INTERVAL = 128
local LOAD_SMALL_SECTION_YIELD_INTERVAL = 128
local LOAD_LINK_YIELD_INTERVAL = 256

local function now()
    return isfunction(internals.now) and internals.now() or SysTime()
end

local function currentMap()
    return isfunction(internals.currentMap) and internals.currentMap() or game.GetMap()
end

local function cachePathForMap(mapName)
    mapName = tostring(mapName or currentMap() or "unknown")
    mapName = string.gsub(mapName, "[^%w_%-%.]", "_")
    return ("%s/%s.dat"):format(CACHE_DIR, mapName)
end

local function openCacheFileForWrite(path)
    return file.Open(path, "wb", "DATA"), "wb"
end

local function cacheBinary()
    local binary = worldBSP.cacheBinary
    if not istable(binary)
        or not isstring(binary.magic)
        or not tonumber(binary.preHeaderSize)
        or not tonumber(binary.mainHeaderSize)
        or not tonumber(binary.sectionEntrySize)
        or not tonumber(binary.surfaceBaseRecordSize)
        or not tonumber(binary.vertexRecordSize)
        or not tonumber(binary.groupRecordSize)
        or not tonumber(binary.linkRecordSize)
        or not isfunction(binary.packUInt32)
        or not isfunction(binary.packInt32)
        or not isfunction(binary.readUInt32)
        or not isfunction(binary.readInt32)
        or not isfunction(worldBSP.surfaceCacheBinaryRecord)
        or not isfunction(worldBSP.surfaceFromCacheBinaryRecord) then
        return
    end

    return binary
end

local function maybeYield()
    if isfunction(internals.maybeYield) then
        internals.maybeYield()
    end
end

local function appendUInt32(parts, binary, value)
    parts[#parts + 1] = binary.packUInt32(value)
end

local function appendInt32(parts, binary, value)
    parts[#parts + 1] = binary.packInt32(value)
end

local function appendString(parts, binary, value)
    value = tostring(value or "")
    appendUInt32(parts, binary, #value)
    parts[#parts + 1] = value
end

local function crcString(data)
    if not (util and isfunction(util.CRC) and isstring(data)) then return end
    return tostring(util.CRC(data))
end

local function readString(data, offset, limit, binary)
    if not offset or offset + 3 > limit then
        return nil, offset
    end

    local length
    length, offset = binary.readUInt32(data, offset)
    if length == nil or length < 0 or offset + length - 1 > limit then
        return nil, offset
    end

    local value = string.sub(data, offset, offset + length - 1)
    return value, offset + length
end

local function mapBspPath(mapName)
    return "maps/" .. tostring(mapName or currentMap() or "") .. ".bsp"
end

function persistent.currentMapFingerprint()
    local mapName = currentMap()
    local bspPath = mapBspPath(mapName)
    local bspSize = file.Size(bspPath, "GAME")
    local bspTime = file.Time(bspPath, "GAME")
    local header = ""

    local handle = file.Open(bspPath, "rb", "GAME")
    if handle then
        header = handle:Read(HEADER_BYTES) or ""
        handle:Close()
    end

    bspSize = tonumber(bspSize) or -1
    bspTime = tonumber(bspTime) or -1

    local headerCrc = util and isfunction(util.CRC) and util.CRC(header) or tostring(#header)
    local mapHash = util and isfunction(util.CRC)
        and util.CRC(("%s\t%d\t%d\t%s"):format(tostring(mapName), bspSize, bspTime, tostring(headerCrc)))
        or ("%s:%d:%d:%s"):format(tostring(mapName), bspSize, bspTime, tostring(headerCrc))

    return {
        map = mapName,
        bspPath = bspPath,
        bspSize = bspSize,
        bspTime = bspTime,
        bspHeaderCrc = headerCrc,
        mapHash = mapHash,
        available = bspSize >= 0 or bspTime >= 0 or #header > 0
    }
end

local function fingerprintMatches(header)
    if not istable(header) then return false, "missing header" end

    local expected = persistent.currentMapFingerprint()
    if not expected.available then
        return false, "map fingerprint unavailable"
    end

    local stored = istable(header.fingerprint) and header.fingerprint or {}
    if stored.available == false then
        return false, "stored map fingerprint unavailable"
    end

    if tostring(header.map or stored.map or "") ~= tostring(expected.map or "") then
        return false, "map changed"
    end

    if tostring(stored.mapHash or "") ~= tostring(expected.mapHash or "") then
        return false, "map hash changed"
    end

    return true
end

local function headerMatches(header)
    if not istable(header) then return false, "missing header" end
    if tonumber(header.formatVersion) ~= CACHE_FORMAT_VERSION then return false, "format changed" end
    if tonumber(header.cacheVersion) ~= tonumber(internals.cacheVersion) then return false, "cache version changed" end

    return fingerprintMatches(header)
end

local function buildMainHeader(binary, fingerprint, sectionCount, payloadCrc)
    local parts = {}

    appendUInt32(parts, binary, binary.surfaceBaseRecordSize)
    appendUInt32(parts, binary, binary.vertexRecordSize)
    appendUInt32(parts, binary, binary.groupRecordSize)
    appendUInt32(parts, binary, binary.linkRecordSize)
    appendUInt32(parts, binary, sectionCount)
    appendUInt32(parts, binary, fingerprint.available and 1 or 0)
    appendUInt32(parts, binary, os and os.time and os.time() or 0)
    appendString(parts, binary, fingerprint.map)
    appendString(parts, binary, fingerprint.mapHash)
    appendString(parts, binary, fingerprint.bspHeaderCrc)
    appendString(parts, binary, payloadCrc)

    local header = table.concat(parts)
    if #header > binary.mainHeaderSize then
        return nil, "binary header exceeds reserved size"
    end

    return header .. string.rep("\0", binary.mainHeaderSize - #header), #header
end

local function buildPreHeader(binary, mainHeaderUsed, sectionCount, fileSize, bodyOffset)
    local sectionTableOffset = binary.preHeaderSize + binary.mainHeaderSize + 1
    local bodySize = fileSize - bodyOffset + 1
    local parts = { binary.magic }

    appendUInt32(parts, binary, CACHE_FORMAT_VERSION)
    appendUInt32(parts, binary, binary.preHeaderSize)
    appendUInt32(parts, binary, binary.mainHeaderSize)
    appendUInt32(parts, binary, mainHeaderUsed)
    appendUInt32(parts, binary, sectionTableOffset)
    appendUInt32(parts, binary, sectionCount)
    appendUInt32(parts, binary, binary.sectionEntrySize)
    appendUInt32(parts, binary, fileSize)
    appendUInt32(parts, binary, 0)
    appendUInt32(parts, binary, bodyOffset)
    appendUInt32(parts, binary, bodySize)
    appendUInt32(parts, binary, binary.coordScale)
    appendUInt32(parts, binary, binary.axisScale)
    appendUInt32(parts, binary, internals.cacheVersion)

    local header = table.concat(parts)
    if #header ~= binary.preHeaderSize then
        return nil, "binary preheader size mismatch"
    end

    return header
end

local function readPreHeader(binary, data)
    local magic = binary.magic
    if string.sub(data, 1, #magic) ~= magic then
        return nil, "invalid cache magic"
    end

    local offset = #magic + 1
    local preHeader = {}
    preHeader.formatVersion, offset = binary.readUInt32(data, offset)
    preHeader.preHeaderSize, offset = binary.readUInt32(data, offset)
    preHeader.mainHeaderSize, offset = binary.readUInt32(data, offset)
    preHeader.mainHeaderUsed, offset = binary.readUInt32(data, offset)
    preHeader.sectionTableOffset, offset = binary.readUInt32(data, offset)
    preHeader.sectionCount, offset = binary.readUInt32(data, offset)
    preHeader.sectionEntrySize, offset = binary.readUInt32(data, offset)
    preHeader.fileSize, offset = binary.readUInt32(data, offset)
    preHeader.flags, offset = binary.readUInt32(data, offset)
    preHeader.bodyOffset, offset = binary.readUInt32(data, offset)
    preHeader.bodySize, offset = binary.readUInt32(data, offset)
    preHeader.coordScale, offset = binary.readUInt32(data, offset)
    preHeader.axisScale, offset = binary.readUInt32(data, offset)
    preHeader.cacheVersion, offset = binary.readUInt32(data, offset)

    if not (preHeader.formatVersion
        and preHeader.preHeaderSize
        and preHeader.mainHeaderSize
        and preHeader.mainHeaderUsed
        and preHeader.sectionTableOffset
        and preHeader.sectionCount
        and preHeader.sectionEntrySize
        and preHeader.fileSize
        and preHeader.flags
        and preHeader.bodyOffset
        and preHeader.bodySize
        and preHeader.coordScale
        and preHeader.axisScale
        and preHeader.cacheVersion) then
        return nil, "invalid cache preheader"
    end
    if offset ~= binary.preHeaderSize + 1 then
        return nil, "invalid cache preheader"
    end
    if preHeader.formatVersion ~= CACHE_FORMAT_VERSION then return nil, "format changed" end
    if preHeader.preHeaderSize ~= binary.preHeaderSize then return nil, "preheader size changed" end
    if preHeader.mainHeaderSize ~= binary.mainHeaderSize then return nil, "main header size changed" end
    if preHeader.sectionCount ~= REQUIRED_SECTION_COUNT then return nil, "section count changed" end
    if preHeader.sectionEntrySize ~= binary.sectionEntrySize then return nil, "section entry size changed" end
    if preHeader.flags ~= 0 then return nil, "unsupported cache flags" end
    if preHeader.fileSize ~= #data then return nil, "cache file size mismatch" end
    if preHeader.cacheVersion ~= tonumber(internals.cacheVersion) then return nil, "cache version changed" end
    if preHeader.coordScale ~= binary.coordScale or preHeader.axisScale ~= binary.axisScale then
        return nil, "surface quantization changed"
    end
    if preHeader.mainHeaderUsed > preHeader.mainHeaderSize then return nil, "invalid main header size" end
    if preHeader.sectionTableOffset ~= preHeader.preHeaderSize + preHeader.mainHeaderSize + 1 then
        return nil, "invalid section table offset"
    end
    if preHeader.bodyOffset ~= preHeader.sectionTableOffset + preHeader.sectionCount * preHeader.sectionEntrySize then
        return nil, "invalid body offset"
    end
    if preHeader.bodyOffset + preHeader.bodySize - 1 ~= preHeader.fileSize then
        return nil, "invalid body size"
    end

    return preHeader
end

local function readMainHeader(binary, data, preHeader)
    local offset = preHeader.preHeaderSize + 1
    local limit = offset + preHeader.mainHeaderUsed - 1
    if preHeader.mainHeaderUsed < 40 then
        return nil, "invalid main header"
    end

    local header = {
        formatVersion = preHeader.formatVersion,
        cacheVersion = preHeader.cacheVersion,
        coordScale = preHeader.coordScale,
        axisScale = preHeader.axisScale
    }

    header.surfaceBaseRecordSize, offset = binary.readUInt32(data, offset)
    header.vertexRecordSize, offset = binary.readUInt32(data, offset)
    header.groupRecordSize, offset = binary.readUInt32(data, offset)
    header.linkRecordSize, offset = binary.readUInt32(data, offset)
    header.sectionCount, offset = binary.readUInt32(data, offset)
    header.fingerprintAvailable, offset = binary.readUInt32(data, offset)
    header.createdAt, offset = binary.readUInt32(data, offset)
    header.map, offset = readString(data, offset, limit, binary)
    local mapHash
    mapHash, offset = readString(data, offset, limit, binary)
    local headerCrc
    headerCrc, offset = readString(data, offset, limit, binary)
    local payloadCrc
    payloadCrc, offset = readString(data, offset, limit, binary)

    if not (header.surfaceBaseRecordSize and header.vertexRecordSize and header.groupRecordSize and header.linkRecordSize)
        or not header.map
        or not mapHash
        or not headerCrc
        or not payloadCrc
        or offset ~= limit + 1 then
        return nil, "invalid main header"
    end
    if header.sectionCount ~= preHeader.sectionCount then return nil, "section count mismatch" end
    if header.sectionCount ~= REQUIRED_SECTION_COUNT then return nil, "section count changed" end
    if header.surfaceBaseRecordSize ~= binary.surfaceBaseRecordSize then return nil, "surface base record size changed" end
    if header.vertexRecordSize ~= binary.vertexRecordSize then return nil, "vertex record size changed" end
    if header.groupRecordSize ~= binary.groupRecordSize then return nil, "group record size changed" end
    if header.linkRecordSize ~= binary.linkRecordSize then return nil, "link record size changed" end
    if payloadCrc == "" then return nil, "missing cache payload checksum" end

    header.fingerprint = {
        map = header.map,
        mapHash = mapHash,
        bspHeaderCrc = headerCrc,
        available = header.fingerprintAvailable ~= 0
    }
    header.payloadCrc = payloadCrc

    return header
end

local function buildSectionTable(binary, sections)
    local parts = {}

    for i = 1, #sections do
        local section = sections[i]
        appendUInt32(parts, binary, section.type)
        appendUInt32(parts, binary, section.offset)
        appendUInt32(parts, binary, section.byteLength)
        appendUInt32(parts, binary, section.recordCount)
        appendUInt32(parts, binary, section.recordStride)
        appendUInt32(parts, binary, section.flags or 0)
    end

    return table.concat(parts)
end

local function readSectionTable(binary, data, preHeader)
    local sections = {}
    local byType = {}
    local offset = preHeader.sectionTableOffset
    if preHeader.sectionCount ~= REQUIRED_SECTION_COUNT then
        return nil, nil, "section count changed"
    end

    for i = 1, preHeader.sectionCount do
        local section = {}
        section.type, offset = binary.readUInt32(data, offset)
        section.offset, offset = binary.readUInt32(data, offset)
        section.byteLength, offset = binary.readUInt32(data, offset)
        section.recordCount, offset = binary.readUInt32(data, offset)
        section.recordStride, offset = binary.readUInt32(data, offset)
        section.flags, offset = binary.readUInt32(data, offset)
        if not (section.type and section.offset and section.byteLength and section.recordCount and section.recordStride and section.flags) then
            return nil, nil, "invalid section table"
        end
        if byType[section.type] then
            return nil, nil, "duplicate cache section"
        end
        if section.type < binary.sectionSurfaceBases or section.type > binary.sectionNeighborLinks then
            return nil, nil, "unknown cache section"
        end
        if section.flags ~= 0 then
            return nil, nil, "unsupported section flags"
        end
        if section.byteLength ~= section.recordCount * section.recordStride then
            return nil, nil, "section byte count mismatch"
        end

        sections[#sections + 1] = section
        byType[section.type] = section
    end

    if offset ~= preHeader.bodyOffset then
        return nil, nil, "section table size mismatch"
    end

    table.sort(sections, function(a, b)
        return (a.offset or 0) < (b.offset or 0)
    end)

    local expectedOffset = preHeader.bodyOffset
    for i = 1, #sections do
        local section = sections[i]
        if section.offset ~= expectedOffset then
            return nil, nil, "cache section offset mismatch"
        end
        expectedOffset = expectedOffset + section.byteLength
    end
    if expectedOffset ~= preHeader.fileSize + 1 then
        return nil, nil, "cache section length mismatch"
    end

    return sections, byType
end

local function payloadChecksumMatches(data, preHeader, header)
    local expected = tostring(header and header.payloadCrc or "")
    if expected == "" then return false, "missing cache payload checksum" end

    local payload = string.sub(data, preHeader.sectionTableOffset, preHeader.fileSize)
    local actual = crcString(payload)
    if not actual then return false, "cache payload checksum unavailable" end
    if actual ~= expected then return false, "cache payload checksum mismatch" end

    return true
end

local function requiredSection(sections, sectionType, recordStride, label)
    local section = sections[sectionType]
    if not section then return nil, "missing " .. label .. " section" end
    if tonumber(section.recordStride) ~= tonumber(recordStride) then
        return nil, label .. " section stride changed"
    end

    return section
end

local function readCacheData(path)
    local binary = cacheBinary()
    if not binary then return nil, nil, "binary cache codec unavailable" end

    local fileSize = tonumber(file.Size(path, "DATA"))
    if not fileSize or fileSize <= 0 then return nil, nil, "missing cache file" end
    if fileSize < binary.preHeaderSize then return nil, nil, "cache file truncated" end
    if fileSize > UINT32_MAX then return nil, nil, "cache file exceeds format size limit" end

    local data = file.Read(path, "DATA")
    if not isstring(data) or #data <= 0 then return nil, nil, "missing cache file" end
    if #data ~= fileSize then return nil, nil, "cache file read size mismatch" end
    if #data < binary.preHeaderSize then return nil, nil, "cache file truncated" end

    local preHeader, preErr = readPreHeader(binary, data)
    if not preHeader then return nil, nil, preErr end

    local header, headerErr = readMainHeader(binary, data, preHeader)
    if not header then return nil, nil, headerErr end

    local checksumOk, checksumErr = payloadChecksumMatches(data, preHeader, header)
    if not checksumOk then return nil, nil, checksumErr end

    local sectionList, sections, sectionErr = readSectionTable(binary, data, preHeader)
    if not sections then return nil, nil, sectionErr end

    local surfaceSection, surfaceErr = requiredSection(sections, binary.sectionSurfaceBases, binary.surfaceBaseRecordSize, "surface base")
    if not surfaceSection then return nil, nil, surfaceErr end
    local vertexSection, vertexErr = requiredSection(sections, binary.sectionVertices, binary.vertexRecordSize, "vertex")
    if not vertexSection then return nil, nil, vertexErr end
    local groupSection, groupErr = requiredSection(sections, binary.sectionDisplacementGroups, binary.groupRecordSize, "displacement group")
    if not groupSection then return nil, nil, groupErr end
    local groupLinkSection, groupLinkErr = requiredSection(sections, binary.sectionDisplacementSurfaceLinks, binary.linkRecordSize, "displacement surface link")
    if not groupLinkSection then return nil, nil, groupLinkErr end
    local neighborSection, neighborErr = requiredSection(sections, binary.sectionNeighborLinks, binary.linkRecordSize, "neighbor link")
    if not neighborSection then return nil, nil, neighborErr end

    header.sections = sections
    header.sectionList = sectionList
    header.surfaceSection = surfaceSection
    header.vertexSection = vertexSection
    header.groupSection = groupSection
    header.groupLinkSection = groupLinkSection
    header.neighborSection = neighborSection
    header.surfaces = surfaceSection.recordCount
    header.vertices = vertexSection.recordCount
    header.displacementGroups = groupSection.recordCount
    header.displacementSurfaceLinks = groupLinkSection.recordCount
    header.links = neighborSection.recordCount
    header.total = header.surfaces + header.displacementGroups + header.displacementSurfaceLinks + header.links

    local ok, reason = headerMatches(header)
    if not ok then return nil, nil, reason end

    return data, header
end

local function collectDisplacementGroups(surfaces)
    local groups = {}
    local seen = {}
    local usedIds = {}

    for i = 1, #(surfaces or {}) do
        local surfaceData = surfaces[i]
        local group = surfaceData and surfaceData.displacementGroup
        if group and not seen[group] then
            local id = tonumber(group.index) or (#groups + 1)
            while usedIds[id] do
                id = id + 1
            end

            group._magicAlignCacheGroupId = id
            seen[group] = true
            usedIds[id] = true
            groups[#groups + 1] = group
        end
    end

    table.sort(groups, function(a, b)
        return (tonumber(a._magicAlignCacheGroupId) or 0) < (tonumber(b._magicAlignCacheGroupId) or 0)
    end)

    return groups
end

local function countNeighborLinks(surfaces)
    local count = 0

    for i = 1, #(surfaces or {}) do
        local surfaceData = surfaces[i]
        local id = tonumber(surfaceData and surfaceData.id)
        local neighbors = surfaceData and surfaceData.neighbors
        if id and istable(neighbors) then
            for j = 1, #neighbors do
                local neighborId = tonumber(neighbors[j] and neighbors[j].id)
                if neighborId and id < neighborId then
                    count = count + 1
                end
            end
        end
    end

    return count
end

local function countGroupSurfaceLinks(groups)
    local count = 0

    for i = 1, #(groups or {}) do
        local group = groups[i]
        for j = 1, #(group.surfaces or {}) do
            local surfaceData = group.surfaces[j]
            if surfaceData and surfaceData.id then
                count = count + 1
            end
        end
    end

    return count
end

function persistent.saveCurrent()
    if not (istable(cache) and cache.status == cache.STATUS.BUILDING and istable(cache.surfaces)) then
        return false, "cache is not in a saveable build state"
    end
    local binary = cacheBinary()
    if not binary then
        return false, "binary cache codec unavailable"
    end

    file.CreateDir("magic_align")
    file.CreateDir(CACHE_DIR)

    local surfaces = cache.surfaces or {}
    local groups = collectDisplacementGroups(surfaces)
    local linkCount = countNeighborLinks(surfaces)
    local groupSurfaceLinkCount = countGroupSurfaceLinks(groups)
    local path = cachePathForMap()
    local fingerprint = persistent.currentMapFingerprint()
    if not fingerprint.available then
        return false, "map fingerprint unavailable"
    end

    local total = #surfaces + #groups + groupSurfaceLinkCount + linkCount
    local surfaceParts = {}
    local vertexParts = {}
    local groupParts = {}
    local groupLinkParts = {}
    local neighborParts = {}
    local vertexCount = 0
    local processed = 0

    cache.cacheFilePath = path
    cache.cacheFileStatus = "encoding"
    worldBSP.setBuildStage("save_cache", total, 0)

    for i = 1, #surfaces do
        local encodedSurface, encodedVertices, addedVertices, encodeErr = worldBSP.surfaceCacheBinaryRecord(surfaces[i], vertexCount)
        if not encodedSurface then
            return false, "failed to encode surface " .. tostring(i) .. ": " .. tostring(encodeErr)
        end

        surfaceParts[#surfaceParts + 1] = encodedSurface
        vertexParts[#vertexParts + 1] = encodedVertices
        vertexCount = vertexCount + (tonumber(addedVertices) or 0)
        processed = processed + 1
        worldBSP.updateBuildStage(processed, total)
        if i % 32 == 0 then
            maybeYield()
        end
    end

    for i = 1, #groups do
        local group = groups[i]
        appendInt32(groupParts, binary, group._magicAlignCacheGroupId)
        appendInt32(groupParts, binary, group.index)
        appendInt32(groupParts, binary, group.mapFace)
        appendInt32(groupParts, binary, group.power)

        processed = processed + 1
        worldBSP.updateBuildStage(processed, total)
        maybeYield()
    end

    for i = 1, #groups do
        local group = groups[i]
        local groupId = tonumber(group._magicAlignCacheGroupId) or 0
        for j = 1, #(group.surfaces or {}) do
            local surfaceData = group.surfaces[j]
            if surfaceData and surfaceData.id then
                appendInt32(groupLinkParts, binary, groupId)
                appendInt32(groupLinkParts, binary, surfaceData.id)

                processed = processed + 1
                worldBSP.updateBuildStage(processed, total)
                if processed % 64 == 0 then
                    maybeYield()
                end
            end
        end
    end

    for i = 1, #surfaces do
        local surfaceData = surfaces[i]
        local id = tonumber(surfaceData and surfaceData.id)
        local neighbors = surfaceData and surfaceData.neighbors
        if id and istable(neighbors) then
            for j = 1, #neighbors do
                local neighborId = tonumber(neighbors[j] and neighbors[j].id)
                if neighborId and id < neighborId then
                    appendInt32(neighborParts, binary, id)
                    appendInt32(neighborParts, binary, neighborId)
                    processed = processed + 1
                    worldBSP.updateBuildStage(processed, total)
                    if processed % 64 == 0 then
                        maybeYield()
                    end
                end
            end
        end
    end

    local sections = {
        {
            type = binary.sectionSurfaceBases,
            data = table.concat(surfaceParts),
            recordCount = #surfaces,
            recordStride = binary.surfaceBaseRecordSize,
            flags = 0
        },
        {
            type = binary.sectionVertices,
            data = table.concat(vertexParts),
            recordCount = vertexCount,
            recordStride = binary.vertexRecordSize,
            flags = 0
        },
        {
            type = binary.sectionDisplacementGroups,
            data = table.concat(groupParts),
            recordCount = #groups,
            recordStride = binary.groupRecordSize,
            flags = 0
        },
        {
            type = binary.sectionDisplacementSurfaceLinks,
            data = table.concat(groupLinkParts),
            recordCount = groupSurfaceLinkCount,
            recordStride = binary.linkRecordSize,
            flags = 0
        },
        {
            type = binary.sectionNeighborLinks,
            data = table.concat(neighborParts),
            recordCount = linkCount,
            recordStride = binary.linkRecordSize,
            flags = 0
        }
    }

    local sectionTableOffset = binary.preHeaderSize + binary.mainHeaderSize + 1
    local bodyOffset = sectionTableOffset + #sections * binary.sectionEntrySize
    local nextOffset = bodyOffset
    if #sections ~= REQUIRED_SECTION_COUNT then
        return false, "section count mismatch"
    end

    for i = 1, #sections do
        local section = sections[i]
        section.byteLength = #(section.data or "")
        if section.byteLength ~= section.recordCount * section.recordStride then
            return false, "section byte count mismatch"
        end

        section.offset = nextOffset
        nextOffset = nextOffset + section.byteLength
    end

    local fileSize = nextOffset - 1
    if fileSize > UINT32_MAX then
        return false, "cache file exceeds format size limit"
    end

    local sectionTable = buildSectionTable(binary, sections)
    if #sectionTable ~= #sections * binary.sectionEntrySize then
        return false, "section table size mismatch"
    end

    local payloadParts = { sectionTable }
    for i = 1, #sections do
        payloadParts[#payloadParts + 1] = sections[i].data
    end
    local payload = table.concat(payloadParts)
    local payloadCrc = crcString(payload)
    if not payloadCrc then
        return false, "cache payload checksum unavailable"
    end

    local mainHeader, mainHeaderUsed = buildMainHeader(binary, fingerprint, #sections, payloadCrc)
    if not mainHeader then return false, mainHeaderUsed end

    local preHeader, preHeaderErr = buildPreHeader(binary, mainHeaderUsed, #sections, fileSize, bodyOffset)
    if not preHeader then return false, preHeaderErr end

    local handle, writeMode = openCacheFileForWrite(path)
    if not handle then
        return false, "failed to open cache file for writing: "
            .. tostring(path)
            .. " (tried "
            .. tostring(writeMode)
            .. ")"
    end

    cache.cacheFileStatus = "saving"
    cache.cacheFileWriteMode = writeMode

    handle:Write(preHeader)
    handle:Write(mainHeader)
    handle:Write(payload)
    handle:Close()

    cache.cacheFileStatus = "saved"
    cache.cacheFilePath = path
    return true
end

local function applyGroupToSurface(group, surfaceData)
    if not (group and surfaceData) then return false end

    group.surfaces = group.surfaces or {}
    group.surfaces[#group.surfaces + 1] = surfaceData

    surfaceData.sourceIsDisplacement = true
    surfaceData.displacementGroup = group
    surfaceData.displacementCacheGroupId = group._magicAlignCacheGroupId or group.id
    surfaceData.displacementIndex = group.index
    surfaceData.displacementMapFace = group.mapFace

    return true
end

local function loadWorker(data, header, path)
    local binary = cacheBinary()
    if not binary then return false, "binary cache codec unavailable" end

    local surfacesById = {}
    local groupsById = {}
    local expectedSurfaces = math.max(tonumber(header.surfaces) or 0, 0)
    local expectedGroups = math.max(tonumber(header.displacementGroups) or 0, 0)
    local expectedGroupSurfaceLinks = math.max(tonumber(header.displacementSurfaceLinks) or 0, 0)
    local expectedLinks = math.max(tonumber(header.links) or 0, 0)
    local expectedVertices = math.max(tonumber(header.vertices) or 0, 0)
    local surfaceSection = header.surfaceSection
    local vertexSection = header.vertexSection
    local groupSection = header.groupSection
    local groupLinkSection = header.groupLinkSection
    local neighborSection = header.neighborSection
    local decodeSurface = worldBSP.surfaceFromCacheBinaryRecord
    local markCachedSurface = internals.markCachedSurface
    local indexSurface = internals.indexSurface
    local indexSurfacePlane = internals.indexSurfacePlane
    local addSurfaceNeighbor = internals.addSurfaceNeighbor
    local setBuildStage = worldBSP.setBuildStage
    local updateBuildStage = worldBSP.updateBuildStage
    local readInt32 = binary.readInt32
    local cacheSurfaces = cache.surfaces
    local cachedCount = cache.cached

    cache.total = expectedSurfaces
    cache.brushTotal = expectedSurfaces
    cache.brushProcessed = 0
    cache.displacementTotal = expectedGroups
    cache.displacementProcessed = 0
    cache.displacementLinkTotal = expectedGroupSurfaceLinks
    cache.displacementLinkProcessed = 0
    cache.neighborTotal = expectedLinks
    cache.neighborProcessed = 0

    setBuildStage("load_surfaces", expectedSurfaces, 0)
    local nextVertexOffset = 0
    for i = 1, expectedSurfaces do
        local offset = surfaceSection.offset + (i - 1) * surfaceSection.recordStride
        local surfaceData, _, loadErr, vertexOffset, vertexCount = decodeSurface(data, offset, vertexSection)
        if not surfaceData or not surfaceData.id then
            return false, loadErr or "invalid surface record"
        end
        if surfacesById[surfaceData.id] then
            return false, "duplicate surface id"
        end
        if vertexOffset ~= nextVertexOffset then
            return false, "non-contiguous surface vertex range"
        end
        vertexCount = tonumber(vertexCount) or 0
        nextVertexOffset = nextVertexOffset + vertexCount

        markCachedSurface(surfaceData)
        cachedCount = cachedCount + 1
        cache.cached = cachedCount
        cacheSurfaces[cachedCount] = surfaceData
        surfacesById[surfaceData.id] = surfaceData
        indexSurface(surfaceData)
        indexSurfacePlane(surfaceData)

        cache.brushProcessed = i
        if i % LOAD_SURFACE_YIELD_INTERVAL == 0 then
            updateBuildStage(i)
            maybeYield()
        end
    end
    if cache.brushProcessed ~= expectedSurfaces then
        return false, "surface count mismatch"
    end
    if nextVertexOffset ~= expectedVertices then
        return false, "vertex count mismatch"
    end
    updateBuildStage(expectedSurfaces)

    setBuildStage("load_displacement_groups", expectedGroups, 0)
    for i = 1, expectedGroups do
        local offset = groupSection.offset + (i - 1) * groupSection.recordStride
        local id
        id, offset = readInt32(data, offset)
        local index
        index, offset = readInt32(data, offset)
        local mapFace
        mapFace, offset = readInt32(data, offset)
        local power
        power, offset = readInt32(data, offset)
        if id == nil or index == nil or mapFace == nil or power == nil then
            return false, "invalid displacement group record"
        end

        local group = {
            id = id,
            _magicAlignCacheGroupId = id,
            index = index,
            mapFace = mapFace,
            power = power,
            surfaces = {}
        }
        if groupsById[id] then
            return false, "duplicate displacement group id"
        end
        groupsById[id] = group

        cache.displacementProcessed = i
        if i % LOAD_SMALL_SECTION_YIELD_INTERVAL == 0 then
            updateBuildStage(i)
            maybeYield()
        end
    end
    if cache.displacementProcessed ~= expectedGroups then
        return false, "displacement group count mismatch"
    end
    updateBuildStage(expectedGroups)

    setBuildStage("load_displacement_group_links", expectedGroupSurfaceLinks, 0)
    for i = 1, expectedGroupSurfaceLinks do
        local offset = groupLinkSection.offset + (i - 1) * groupLinkSection.recordStride
        local groupId
        groupId, offset = readInt32(data, offset)
        local surfaceId
        surfaceId, offset = readInt32(data, offset)
        local group = groupId and groupsById[groupId]
        local surfaceData = surfaceId and surfacesById[surfaceId]
        if not (group and surfaceData) then
            return false, "invalid displacement group surface"
        end

        if applyGroupToSurface(group, surfaceData) then
            cache.displacementSurfaces = cache.displacementSurfaces + 1
        end

        cache.displacementLinkProcessed = i
        if i % LOAD_LINK_YIELD_INTERVAL == 0 then
            updateBuildStage(i)
            maybeYield()
        end
    end
    if cache.displacementSurfaces ~= expectedGroupSurfaceLinks then
        return false, "displacement surface link count mismatch"
    end
    if cache.displacementLinkProcessed ~= expectedGroupSurfaceLinks then
        return false, "displacement link count mismatch"
    end
    updateBuildStage(expectedGroupSurfaceLinks)

    for _, group in pairs(groupsById) do
        if #(group.surfaces or {}) > 0 then
            cache.displacements = cache.displacements + 1
        end
    end

    setBuildStage("load_neighbor_links", expectedLinks, 0)
    for i = 1, expectedLinks do
        local offset = neighborSection.offset + (i - 1) * neighborSection.recordStride
        local firstId
        firstId, offset = readInt32(data, offset)
        local secondId
        secondId, offset = readInt32(data, offset)
        local first = firstId and surfacesById[firstId]
        local second = secondId and surfacesById[secondId]
        if not (first and second) then
            return false, "invalid neighbor link"
        end

        addSurfaceNeighbor(first, second)
        addSurfaceNeighbor(second, first)

        cache.neighborProcessed = i
        if i % LOAD_LINK_YIELD_INTERVAL == 0 then
            updateBuildStage(i)
            maybeYield()
        end
    end

    if cache.neighborProcessed ~= expectedLinks then
        return false, "neighbor link count mismatch"
    end
    updateBuildStage(expectedLinks)
    if cache.cached <= 0 then
        return false, "cache contained no surfaces"
    end

    for i = 1, #(cache.surfaces or {}) do
        cache.surfaces[i].neighborSeen = nil
    end

    cache.readySource = "loaded"
    cache.cacheFilePath = path
    cache.cacheFileStatus = "loaded"
    return true
end

function persistent.startLoad()
    if not (isfunction(internals.resetCache) and cacheBinary()) then
        return false
    end

    local path = cachePathForMap()
    local data, header, reason = readCacheData(path)
    if not data then
        cache.cacheFilePath = path
        cache.cacheFileStatus = reason
        return false
    end

    internals.resetCache(cache.STATUS.BUILDING)
    cache.activity = "loading"
    cache.workerKind = "load"
    cache.startedAt = now()
    cache.cacheFilePath = path
    cache.cacheFileStatus = "loading"
    cache.total = math.max(tonumber(header.surfaces) or 0, 0)
    cache.brushTotal = cache.total
    cache.displacementTotal = math.max(tonumber(header.displacementGroups) or 0, 0)
    cache.displacementLinkTotal = math.max(tonumber(header.displacementSurfaceLinks) or 0, 0)
    cache.displacementLinkProcessed = 0
    cache.neighborTotal = math.max(tonumber(header.links) or 0, 0)
    cache.worker = coroutine.create(function()
        return loadWorker(data, header, path)
    end)

    worldBSP.setBuildStage("load_surfaces", cache.brushTotal, 0)
    worldBSP.refreshCacheProgressSnapshot(true)

    print(("Magic Align: World BSP snapping cache is loading from %s..."):format(path))
    return true
end

function persistent.cachePath()
    return cachePathForMap()
end

return persistent
