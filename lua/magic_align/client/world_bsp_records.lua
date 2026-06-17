MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

return function(worldBSP, deps)
    if not istable(worldBSP) then return end

    deps = deps or {}

    local M = deps.M or MAGIC_ALIGN
    local VectorP = deps.VectorP or M.VectorP
    local isvector = deps.isvector or M.IsVectorLike
    local normalizedVec = deps.normalizedVec or M.NormalizeVectorPrecise
    local dot = deps.dot or M.DotVectorsPrecise
    local surfaceUv = deps.surfaceUv
    local expandBounds = deps.expandBounds
    local buildGlobalFamilies = deps.buildGlobalFamilies
    local BINARY_MAGIC = "MAWBCV07"
    local BINARY_PREHEADER_SIZE = 64
    local BINARY_MAIN_HEADER_SIZE = 4096
    local BINARY_SECTION_ENTRY_SIZE = 24
    local BINARY_GEOMETRY_FORMAT_FLOAT32_LE = 1
    local BINARY_GEOMETRY_FORMAT_VERSION = 1
    local BINARY_SURFACE_BASE_INTS = 30
    local BINARY_SURFACE_BASE_RECORD_SIZE = BINARY_SURFACE_BASE_INTS * 4
    local BINARY_VERTEX_RECORD_SIZE = 3 * 4
    local BINARY_GROUP_RECORD_SIZE = 4 * 4
    local BINARY_LINK_RECORD_SIZE = 2 * 4
    local UINT32_RANGE = 4294967296
    local INT32_MAX = 2147483647
    local INT32_MIN = -2147483648
    local INT32_SIGN = 2147483648

    local function finiteNumber(value)
        value = tonumber(value)
        if not value or value ~= value or value == math.huge or value == -math.huge then return end
        return value
    end

    local function recordVector(value)
        if not isvector(value) then return end
        return { value.x, value.y, value.z }
    end

    local function clampInt32(value)
        value = math.floor(tonumber(value) or 0)
        if value > INT32_MAX then return INT32_MAX end
        if value < INT32_MIN then return INT32_MIN end
        return value
    end

    local function packUInt32(value)
        value = math.floor(tonumber(value) or 0) % UINT32_RANGE

        local b1 = value % 256
        value = (value - b1) / 256
        local b2 = value % 256
        value = (value - b2) / 256
        local b3 = value % 256
        value = (value - b3) / 256
        local b4 = value % 256

        return string.char(
            math.floor(b1),
            math.floor(b2),
            math.floor(b3),
            math.floor(b4)
        )
    end

    local function packInt32(value)
        value = clampInt32(value)
        if value < 0 then
            value = UINT32_RANGE + value
        end

        return packUInt32(value)
    end

    local function readUInt32(data, offset)
        local b1, b2, b3, b4 = string.byte(data, offset, offset + 3)
        if not b4 then return end

        return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216, offset + 4
    end

    local function readInt32(data, offset)
        local value, nextOffset = readUInt32(data, offset)
        if value == nil then return end
        if value >= INT32_SIGN then
            value = value - UINT32_RANGE
        end

        return value, nextOffset
    end

    -- IEEE754 Float32 logic adapted from StarfallEx bit.lua:
    -- https://github.com/thegrb93/StarfallEx/blob/a888f0fe05c9dd29940018114b1fc163fd580ea8/lua/starfall/libs_sh/bit.lua
    -- StarfallEx credits the original float routine to rpfeltz.
    local function packFloat32(value)
        value = tonumber(value) or 0

        if value == 0 then
            return "\0\0\0\0"
        elseif value == math.huge then
            return string.char(0x00, 0x00, 0x80, 0x7F)
        elseif value == -math.huge then
            return string.char(0x00, 0x00, 0x80, 0xFF)
        elseif value ~= value then
            return string.char(0x00, 0x00, 0xC0, 0xFF)
        end

        local sign = 0x00
        if value < 0 then
            sign = 0x80
            value = -value
        end

        local mantissa, exponent = math.frexp(value)
        exponent = exponent + 0x7F
        if exponent <= 0 then
            mantissa = math.ldexp(mantissa, exponent - 1)
            exponent = 0
        elseif exponent >= 0xFF then
            return string.char(0x00, 0x00, 0x80, sign + 0x7F)
        elseif exponent == 1 then
            exponent = 0
        else
            mantissa = mantissa * 2 - 1
            exponent = exponent - 1
        end

        mantissa = math.floor(math.ldexp(mantissa, 23) + 0.5)
        if mantissa >= 0x800000 then
            mantissa = 0
            exponent = exponent + 1
            if exponent >= 0xFF then
                return string.char(0x00, 0x00, 0x80, sign + 0x7F)
            end
        end

        return string.char(
            mantissa % 0x100,
            math.floor(mantissa / 0x100) % 0x100,
            (exponent % 2) * 0x80 + math.floor(mantissa / 0x10000),
            sign + math.floor(exponent / 2)
        )
    end

    local function unpackFloat32(b1, b2, b3, b4)
        local exponent = (b4 % 0x80) * 0x02 + math.floor(b3 / 0x80)
        local mantissa = math.ldexp(((b3 % 0x80) * 0x100 + b2) * 0x100 + b1, -23)
        if exponent == 0xFF then
            if mantissa > 0 then
                return 0 / 0
            end
            if b4 >= 0x80 then
                return -math.huge
            end
            return math.huge
        elseif exponent > 0 then
            mantissa = mantissa + 1
        else
            exponent = exponent + 1
        end
        if b4 >= 0x80 then
            mantissa = -mantissa
        end
        return math.ldexp(mantissa, exponent - 0x7F)
    end

    local function appendInt32(parts, value)
        parts[#parts + 1] = packInt32(value)
    end

    local function appendUInt32(parts, value)
        parts[#parts + 1] = packUInt32(value)
    end

    local function appendFloat32(parts, value)
        value = finiteNumber(value)
        if value == nil then return false end

        parts[#parts + 1] = packFloat32(value)
        return true
    end

    local function appendRecordVector(parts, record)
        return appendFloat32(parts, record and record[1])
            and appendFloat32(parts, record and record[2])
            and appendFloat32(parts, record and record[3])
    end

    local function readFloat32(data, offset)
        if not offset then return end

        local b1, b2, b3, b4 = string.byte(data, offset, offset + 3)
        if not b4 then return end

        local value = unpackFloat32(b1, b2, b3, b4)
        if value ~= value or value == math.huge or value == -math.huge then return end

        return value, offset + 4
    end

    local function readVectorP(data, offset)
        local x, y, z
        x, offset = readFloat32(data, offset)
        y, offset = readFloat32(data, offset)
        z, offset = readFloat32(data, offset)
        if z == nil then return end

        return VectorP(x, y, z), offset
    end

    local function displacementHalfCode(value)
        value = tostring(value or "")
        if value == "a" then return 1 end
        if value == "b" then return 2 end
        return 0
    end

    local function displacementHalfFromCode(code)
        code = tonumber(code) or 0
        if code == 1 then return "a" end
        if code == 2 then return "b" end
    end

    local function displacementDiagonalCode(value)
        value = tostring(value or "")
        if value == "source_tlbr" then return 1 end
        if value == "source_bltr" then return 2 end
        if value == "tlbr" then return 3 end
        if value == "bltr" then return 4 end
        return 0
    end

    local function displacementDiagonalFromCode(code)
        code = tonumber(code) or 0
        if code == 1 then return "source_tlbr" end
        if code == 2 then return "source_bltr" end
        if code == 3 then return "tlbr" end
        if code == 4 then return "bltr" end
    end

    worldBSP.cacheBinary = {
        magic = BINARY_MAGIC,
        preHeaderSize = BINARY_PREHEADER_SIZE,
        mainHeaderSize = BINARY_MAIN_HEADER_SIZE,
        sectionEntrySize = BINARY_SECTION_ENTRY_SIZE,
        geometryFormat = BINARY_GEOMETRY_FORMAT_FLOAT32_LE,
        geometryFormatVersion = BINARY_GEOMETRY_FORMAT_VERSION,
        surfaceBaseRecordSize = BINARY_SURFACE_BASE_RECORD_SIZE,
        vertexRecordSize = BINARY_VERTEX_RECORD_SIZE,
        groupRecordSize = BINARY_GROUP_RECORD_SIZE,
        linkRecordSize = BINARY_LINK_RECORD_SIZE,
        sectionSurfaceBases = 1,
        sectionVertices = 2,
        sectionDisplacementGroups = 3,
        sectionDisplacementSurfaceLinks = 4,
        sectionNeighborLinks = 5,
        packUInt32 = packUInt32,
        packInt32 = packInt32,
        packFloat32 = packFloat32,
        readUInt32 = readUInt32,
        readInt32 = readInt32,
        readFloat32 = readFloat32
    }

    local function vectorFromRecord(record)
        if not istable(record) then return end

        local x = finiteNumber(record[1] or record.x)
        local y = finiteNumber(record[2] or record.y)
        local z = finiteNumber(record[3] or record.z)
        if x == nil or y == nil or z == nil then return end

        return VectorP(x, y, z)
    end

    local function recordPolygon(polygon)
        if not istable(polygon) then return end

        local out = {}
        for i = 1, #polygon do
            local point = polygon[i]
            local u = finiteNumber(point and point.u or point and point[1])
            local v = finiteNumber(point and point.v or point and point[2])
            if u ~= nil and v ~= nil then
                out[#out + 1] = { u, v }
            end
        end

        return #out >= 3 and out or nil
    end

    local function polygonFromRecord(record)
        if not istable(record) then return end

        local out = {}
        for i = 1, #record do
            local point = record[i]
            local u = finiteNumber(point and point[1] or point and point.u)
            local v = finiteNumber(point and point[2] or point and point.v)
            if u ~= nil and v ~= nil then
                out[#out + 1] = { u = u, v = v }
            end
        end

        return #out >= 3 and out or nil
    end

    local function sourceFromRecord(record)
        record = istable(record) and record or {}
        local source = istable(record.source) and record.source or nil
        local isWorld = not source or source.isWorld == true
        return {
            ent = isWorld and game.GetWorld() or nil,
            identity = source and tostring(source.identity or (isWorld and "world:0" or "world_bsp_cache")) or "world:0",
            entityIndex = source and tonumber(source.entityIndex) or (isWorld and 0 or nil),
            class = source and source.class and tostring(source.class) or nil,
            model = source and source.model and tostring(source.model) or nil,
            isWorld = isWorld,
            surfaceCount = source and tonumber(source.surfaceCount) or nil
        }
    end

    function worldBSP.surfaceCacheRecord(surfaceData)
        if not surfaceData then return end

        local vertices = {}

        for i = 1, #(surfaceData.vertices or {}) do
            local vertex = recordVector(surfaceData.vertices[i])
            if vertex then
                vertices[#vertices + 1] = vertex
            end
        end

        local id = tonumber(surfaceData.id)
        local origin = recordVector(surfaceData.origin)
        local normal = recordVector(surfaceData.normal)
        local uAxis = recordVector(surfaceData.uAxis)
        local vAxis = recordVector(surfaceData.vAxis)
        local uMin = finiteNumber(surfaceData.uMin)
        local uMax = finiteNumber(surfaceData.uMax)
        local vMin = finiteNumber(surfaceData.vMin)
        local vMax = finiteNumber(surfaceData.vMax)
        local mins = recordVector(surfaceData.worldMins)
        local maxs = recordVector(surfaceData.worldMaxs)
        if not id or id <= 0 or #vertices < 3 or not (origin and normal and uAxis and vAxis and mins and maxs)
            or uMin == nil or uMax == nil or vMin == nil or vMax == nil then
            return
        end

        local record = {
            id,
            vertices,
            origin,
            normal,
            uAxis,
            vAxis,
            { uMin, uMax, vMin, vMax },
            mins,
            maxs
        }

        if surfaceData.sourceIsDisplacement then
            record[10] = {
                surfaceData.displacementGroup and surfaceData.displacementGroup._magicAlignCacheGroupId
                    or surfaceData.displacementIndex,
                surfaceData.displacementIndex,
                surfaceData.displacementMapFace,
                surfaceData.displacementRow,
                surfaceData.displacementCol,
                surfaceData.displacementHalf,
                surfaceData.displacementDiagonal
            }
        end

        return record
    end

    function worldBSP.surfaceCacheBinaryRecord(surfaceData, vertexOffset)
        local record = worldBSP.surfaceCacheRecord(surfaceData)
        if not record then return end

        local vertices = record[2]
        local vertexCount = #(vertices or {})
        vertexOffset = math.floor(tonumber(vertexOffset) or -1)
        if vertexOffset < 0 then
            return nil, nil, nil, "invalid vertex offset"
        end
        if vertexCount < 3 then
            return nil, nil, nil, "surface has fewer than 3 vertices"
        end
        if vertexCount > INT32_MAX or vertexOffset > INT32_MAX - vertexCount then
            return nil, nil, nil, "surface vertex range exceeds binary record limit"
        end

        local displacement = record[10]
        local flags = istable(displacement) and 1 or 0
        local surfaceParts = {}
        local vertexParts = {}

        appendInt32(surfaceParts, record[1])
        appendUInt32(surfaceParts, vertexOffset)
        appendInt32(surfaceParts, vertexCount)
        appendInt32(surfaceParts, flags)
        appendInt32(surfaceParts, flags == 1 and displacement[4] or 0)
        appendInt32(surfaceParts, flags == 1 and displacement[5] or 0)
        appendInt32(surfaceParts, flags == 1 and displacementHalfCode(displacement[6]) or 0)
        appendInt32(surfaceParts, flags == 1 and displacementDiagonalCode(displacement[7]) or 0)

        if not (appendRecordVector(surfaceParts, record[3])
            and appendRecordVector(surfaceParts, record[4])
            and appendRecordVector(surfaceParts, record[5])
            and appendRecordVector(surfaceParts, record[6])
            and appendFloat32(surfaceParts, record[7][1])
            and appendFloat32(surfaceParts, record[7][2])
            and appendFloat32(surfaceParts, record[7][3])
            and appendFloat32(surfaceParts, record[7][4])
            and appendRecordVector(surfaceParts, record[8])
            and appendRecordVector(surfaceParts, record[9])) then
            return nil, nil, nil, "failed to encode required surface values"
        end

        for i = 1, vertexCount do
            if not appendRecordVector(vertexParts, vertices[i]) then
                return nil, nil, nil, "failed to encode surface vertex"
            end
        end

        local surfaceEncoded = table.concat(surfaceParts)
        if #surfaceEncoded ~= BINARY_SURFACE_BASE_RECORD_SIZE then
            return nil, nil, nil, "surface base record size mismatch"
        end

        local vertexEncoded = table.concat(vertexParts)
        if #vertexEncoded ~= vertexCount * BINARY_VERTEX_RECORD_SIZE then
            return nil, nil, nil, "surface vertex record size mismatch"
        end

        return surfaceEncoded, vertexEncoded, vertexCount
    end

    function worldBSP.surfaceFromCacheBinaryRecord(data, offset, vertexSection)
        offset = tonumber(offset) or 1
        if not isstring(data) or offset < 1 or offset + BINARY_SURFACE_BASE_RECORD_SIZE - 1 > #data then
            return nil, offset, "surface record out of range"
        end
        if not istable(vertexSection)
            or tonumber(vertexSection.offset) == nil
            or tonumber(vertexSection.recordCount) == nil
            or tonumber(vertexSection.recordStride) ~= BINARY_VERTEX_RECORD_SIZE then
            return nil, offset, "vertex section unavailable"
        end

        local id
        id, offset = readInt32(data, offset)
        local vertexOffset
        vertexOffset, offset = readUInt32(data, offset)
        local vertexCount
        vertexCount, offset = readInt32(data, offset)
        local flags
        flags, offset = readInt32(data, offset)
        local displacementRow
        displacementRow, offset = readInt32(data, offset)
        local displacementCol
        displacementCol, offset = readInt32(data, offset)
        local halfCode
        halfCode, offset = readInt32(data, offset)
        local diagonalCode
        diagonalCode, offset = readInt32(data, offset)

        if not id or id <= 0
            or vertexOffset == nil
            or not vertexCount
            or vertexCount < 3
            or vertexOffset + vertexCount > tonumber(vertexSection.recordCount) then
            return nil, offset, "invalid surface record header"
        end
        if flags ~= 0 and flags ~= 1 then
            return nil, offset, "invalid surface flags"
        end
        halfCode = tonumber(halfCode) or 0
        diagonalCode = tonumber(diagonalCode) or 0
        if flags == 1 and (halfCode < 1 or halfCode > 2 or diagonalCode < 1 or diagonalCode > 4) then
            return nil, offset, "invalid displacement surface flags"
        end

        local origin
        origin, offset = readVectorP(data, offset)
        local normalRecord
        normalRecord, offset = readVectorP(data, offset)
        local uAxisRecord
        uAxisRecord, offset = readVectorP(data, offset)
        local vAxisRecord
        vAxisRecord, offset = readVectorP(data, offset)
        if not (origin and normalRecord and uAxisRecord and vAxisRecord) then
            return nil, offset, "invalid surface basis"
        end

        local normal = normalizedVec(normalRecord, M.PICKING_VECTOR_EPSILON_SQR)
        local uAxis = normalizedVec(uAxisRecord, M.PICKING_VECTOR_EPSILON_SQR)
        local vAxis = normalizedVec(vAxisRecord, M.PICKING_VECTOR_EPSILON_SQR)
        if not normal or not uAxis or not vAxis then
            return nil, offset, "invalid normalized surface basis"
        end

        local uMin
        uMin, offset = readFloat32(data, offset)
        local uMax
        uMax, offset = readFloat32(data, offset)
        local vMin
        vMin, offset = readFloat32(data, offset)
        local vMax
        vMax, offset = readFloat32(data, offset)
        if uMin == nil or uMax == nil or vMin == nil or vMax == nil then
            return nil, offset, "invalid surface uv bounds"
        end

        local mins
        mins, offset = readVectorP(data, offset)
        local maxs
        maxs, offset = readVectorP(data, offset)
        if not (mins and maxs) then
            return nil, offset, "invalid surface bounds"
        end

        local vertices = {}
        local polygon = {}
        local sumX, sumY, sumZ = 0, 0, 0
        local originX, originY, originZ = origin.x, origin.y, origin.z
        local uAxisX, uAxisY, uAxisZ = uAxis.x, uAxis.y, uAxis.z
        local vAxisX, vAxisY, vAxisZ = vAxis.x, vAxis.y, vAxis.z
        local vertexReadOffset = tonumber(vertexSection.offset) + vertexOffset * BINARY_VERTEX_RECORD_SIZE
        for i = 1, vertexCount do
            local vertex
            vertex, vertexReadOffset = readVectorP(data, vertexReadOffset)
            if not vertex then
                return nil, offset, "invalid surface vertex"
            end

            vertices[i] = vertex
            local x, y, z = vertex.x, vertex.y, vertex.z
            sumX = sumX + x
            sumY = sumY + y
            sumZ = sumZ + z

            local dx, dy, dz = x - originX, y - originY, z - originZ
            local u = dx * uAxisX + dy * uAxisY + dz * uAxisZ
            local v = dx * vAxisX + dy * vAxisY + dz * vAxisZ
            polygon[i] = { u = u, v = v }
            if not uMin or u < uMin then uMin = u end
            if not uMax or u > uMax then uMax = u end
            if not vMin or v < vMin then vMin = v end
            if not vMax or v > vMax then vMax = v end
        end

        if not uMin or not uMax or not vMin or not vMax then return nil, offset, "invalid surface uv bounds" end

        local source = sourceFromRecord()
        local surfaceData = {
            id = id,
            source = source,
            sourceEnt = source.ent,
            sourceIdentity = source.identity,
            sourceEntityIndex = source.entityIndex,
            sourceClass = source.class,
            sourceModel = source.model,
            sourceIsWorld = source.isWorld == true,
            vertices = vertices,
            edges = {},
            polygon = polygon,
            origin = origin,
            normal = normal,
            planeDistance = dot(normal, origin),
            uAxis = uAxis,
            vAxis = vAxis,
            uMin = uMin,
            uMax = uMax,
            vMin = vMin,
            vMax = vMax,
            worldMins = mins,
            worldMaxs = maxs,
            center = VectorP(sumX / vertexCount, sumY / vertexCount, sumZ / vertexCount)
        }

        if flags ~= 0 then
            surfaceData.sourceIsDisplacement = true
            surfaceData.displacementRow = displacementRow
            surfaceData.displacementCol = displacementCol
            surfaceData.displacementHalf = displacementHalfFromCode(halfCode)
            surfaceData.displacementDiagonal = displacementDiagonalFromCode(diagonalCode)
        end

        return surfaceData, offset, nil, vertexOffset, vertexCount
    end

    function worldBSP.surfaceFromCacheRecord(record)
        if not istable(record) then return end

        local compact = record[2] ~= nil and record.vertices == nil
        local verticesRecord = compact and record[2] or record.vertices
        local originRecord = compact and record[3] or record.origin
        local normalSource = compact and record[4] or record.normal
        local uAxisSource = compact and record[5] or record.uAxis
        local vAxisSource = compact and record[6] or record.vAxis
        local uvRecord = compact and record[7] or record.uv
        local minsRecord = compact and record[8] or record.mins
        local maxsRecord = compact and record[9] or record.maxs
        local displacement = compact and record[10] or record.displacement

        local vertices = {}
        for i = 1, #(verticesRecord or {}) do
            local vertex = vectorFromRecord(verticesRecord[i])
            if vertex then
                vertices[#vertices + 1] = vertex
            end
        end
        if #vertices < 3 then return end

        local origin = vectorFromRecord(originRecord) or vertices[1]
        local normalRecord = vectorFromRecord(normalSource)
        local uAxisRecord = vectorFromRecord(uAxisSource)
        local vAxisRecord = vectorFromRecord(vAxisSource)
        if not normalRecord or not uAxisRecord or not vAxisRecord then return end

        local normal = normalizedVec(normalRecord, M.PICKING_VECTOR_EPSILON_SQR)
        local uAxis = normalizedVec(uAxisRecord, M.PICKING_VECTOR_EPSILON_SQR)
        local vAxis = normalizedVec(vAxisRecord, M.PICKING_VECTOR_EPSILON_SQR)
        if not normal or not uAxis or not vAxis then return end

        local polygon = polygonFromRecord(record.polygon)
        local uMin = uvRecord and finiteNumber(uvRecord[1])
        local uMax = uvRecord and finiteNumber(uvRecord[2])
        local vMin = uvRecord and finiteNumber(uvRecord[3])
        local vMax = uvRecord and finiteNumber(uvRecord[4])
        local worldMins = vectorFromRecord(minsRecord)
        local worldMaxs = vectorFromRecord(maxsRecord)
        local centerFromRecord = compact and nil or vectorFromRecord(record.center)
        local center = centerFromRecord or VectorP(0, 0, 0)

        if not polygon then
            polygon = {}
            for i = 1, #vertices do
                local u, v = surfaceUv({ origin = origin, uAxis = uAxis, vAxis = vAxis }, vertices[i])
                polygon[i] = { u = u, v = v }
                uMin = uMin and math.min(uMin, u) or u
                uMax = uMax and math.max(uMax, u) or u
                vMin = vMin and math.min(vMin, v) or v
                vMax = vMax and math.max(vMax, v) or v
            end
        else
            for i = 1, #polygon do
                local point = polygon[i]
                local u = point and point.u
                local v = point and point.v
                if u ~= nil and v ~= nil then
                    uMin = uMin and math.min(uMin, u) or u
                    uMax = uMax and math.max(uMax, u) or u
                    vMin = vMin and math.min(vMin, v) or v
                    vMax = vMax and math.max(vMax, v) or v
                end
            end
        end

        if not worldMins or not worldMaxs then
            for i = 1, #vertices do
                worldMins, worldMaxs = expandBounds(worldMins, worldMaxs, vertices[i])
            end
        end

        if not centerFromRecord then
            center = VectorP(0, 0, 0)
            for i = 1, #vertices do
                center = center + vertices[i]
            end
            center = center / #vertices
        end

        if not uMin or not uMax or not vMin or not vMax or not worldMins or not worldMaxs then return end

        local source = sourceFromRecord(record)
        local surfaceData = {
            id = tonumber(compact and record[1] or record.id),
            source = source,
            sourceEnt = source.ent,
            sourceIdentity = source.identity,
            sourceEntityIndex = source.entityIndex,
            sourceClass = source.class,
            sourceModel = source.model,
            sourceIsWorld = source.isWorld == true,
            sourceSurfaceIndex = record.source and tonumber(record.source.surfaceIndex) or nil,
            vertices = vertices,
            edges = {},
            polygon = polygon,
            origin = origin,
            normal = normal,
            planeDistance = dot(normal, origin),
            uAxis = uAxis,
            vAxis = vAxis,
            uMin = uMin,
            uMax = uMax,
            vMin = vMin,
            vMax = vMax,
            worldMins = worldMins,
            worldMaxs = worldMaxs,
            center = center
        }

        surfaceData.globalFamilies = buildGlobalFamilies(surfaceData)

        if istable(displacement) then
            surfaceData.sourceIsDisplacement = true
            surfaceData.displacementCacheGroupId = compact and displacement[1] or displacement.groupId
            surfaceData.displacementIndex = tonumber(compact and displacement[2] or displacement.index)
            surfaceData.displacementMapFace = tonumber(compact and displacement[3] or displacement.mapFace)
            surfaceData.displacementRow = tonumber(compact and displacement[4] or displacement.row)
            surfaceData.displacementCol = tonumber(compact and displacement[5] or displacement.col)
            surfaceData.displacementHalf = compact and displacement[6] and tostring(displacement[6])
                or displacement.half and tostring(displacement.half)
                or nil
            surfaceData.displacementDiagonal = compact and displacement[7] and tostring(displacement[7])
                or displacement.diagonal and tostring(displacement.diagonal)
                or nil
        end

        return surfaceData
    end

    return worldBSP
end
