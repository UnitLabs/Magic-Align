MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

return function(deps)
    deps = deps or {}

    local M = MAGIC_ALIGN
    local BSP = deps.BSP or {}
    local VectorP = deps.VectorP or M.VectorP
    local currentMap = deps.currentMap or game.GetMap
    local reader = {}

    local function canRead(data, offset, length)
        return isstring(data)
            and offset
            and length
            and offset >= 0
            and length >= 0
            and offset + length <= #data
    end

    local function byte(data, offset)
        return string.byte(data, offset + 1, offset + 1) or 0
    end

    local function readUInt16(data, offset)
        if not canRead(data, offset, 2) then return 0 end

        return byte(data, offset) + byte(data, offset + 1) * 256
    end

    local function readInt16(data, offset)
        local value = readUInt16(data, offset)
        if value >= 0x8000 then value = value - 0x10000 end
        return value
    end

    local function readUInt32(data, offset)
        if not canRead(data, offset, 4) then return 0 end

        return byte(data, offset)
            + byte(data, offset + 1) * 0x100
            + byte(data, offset + 2) * 0x10000
            + byte(data, offset + 3) * 0x1000000
    end

    local function readInt32(data, offset)
        local value = readUInt32(data, offset)
        if value >= 0x80000000 then value = value - 0x100000000 end
        return value
    end

    function reader.readFloat(data, offset)
        local value = readUInt32(data, offset)
        local sign = 1
        if value >= 0x80000000 then
            sign = -1
            value = value - 0x80000000
        end

        local exponent = math.floor(value / 0x800000)
        local mantissa = value - exponent * 0x800000
        if exponent == 255 then
            return sign * math.huge
        elseif exponent == 0 then
            return sign * (mantissa / 0x800000) * 2 ^ (-126)
        end

        return sign * (1 + mantissa / 0x800000) * 2 ^ (exponent - 127)
    end

    function reader.readVector(data, offset)
        if not canRead(data, offset, 12) then return end

        return VectorP(
            reader.readFloat(data, offset),
            reader.readFloat(data, offset + 4),
            reader.readFloat(data, offset + 8)
        )
    end

    local function readCString(data, offset, maxLength)
        if not canRead(data, offset, 1) then return end

        local limit = math.min(#data, offset + (tonumber(maxLength) or 256))
        local first = offset + 1
        for i = first, limit do
            if string.byte(data, i, i) == 0 then
                return string.sub(data, first, i - 1)
            end
        end

        return string.sub(data, first, limit)
    end

    function reader.readCurrentMapData()
        local map = currentMap()
        if map == "" then
            return nil, "map name unavailable"
        end

        local path = "maps/" .. map .. ".bsp"
        local data = file.Read(path, "GAME")
        if not isstring(data) or #data == 0 then
            return nil, "could not read " .. path
        end

        return data
    end

    function reader.readHeader(data)
        if not canRead(data, 0, BSP.headerSize) then
            return nil, "BSP header is incomplete"
        end
        if string.sub(data, 1, 4) ~= BSP.ident then
            return nil, "BSP header magic is not VBSP"
        end

        local header = {
            version = readInt32(data, 4),
            lumps = {},
            mapRevision = readInt32(data, 8 + BSP.headerLumps * 16)
        }

        for i = 0, BSP.headerLumps - 1 do
            local offset = 8 + i * 16
            header.lumps[i] = {
                fileofs = readInt32(data, offset),
                filelen = readInt32(data, offset + 4),
                version = readInt32(data, offset + 8),
                fourCC = readUInt32(data, offset + 12)
            }
        end

        return header
    end

    function reader.lump(header, id)
        return header and header.lumps and header.lumps[id]
    end

    function reader.lumpCount(header, id, stride)
        local lump = reader.lump(header, id)
        if not lump or (lump.filelen or 0) <= 0 or (stride or 0) <= 0 then return 0 end

        return math.floor(lump.filelen / stride)
    end

    function reader.lumpIsReadable(data, lump)
        return lump and lump.fileofs and lump.filelen and lump.filelen > 0
            and canRead(data, lump.fileofs, lump.filelen)
    end

    function reader.lumpIsCompressed(data, lump)
        if not reader.lumpIsReadable(data, lump) then return false end
        if (tonumber(lump.fourCC) or 0) ~= 0 then return true end

        return string.sub(data, lump.fileofs + 1, lump.fileofs + 4) == BSP.compressedLumpId
    end

    function reader.requiredDisplacementLumpsReadable(data, header)
        local required = {
            BSP.lumpFaces,
            BSP.lumpVertexes,
            BSP.lumpSurfEdges,
            BSP.lumpEdges,
            BSP.lumpDispInfo,
            BSP.lumpDispVerts
        }

        for i = 1, #required do
            local id = required[i]
            local lump = reader.lump(header, id)
            if not reader.lumpIsReadable(data, lump) then
                return false, "required lump " .. tostring(id) .. " is missing"
            end
            if reader.lumpIsCompressed(data, lump) then
                return false, "required lump " .. tostring(id) .. " is LZMA-compressed"
            end
        end

        return true
    end

    function reader.readVertex(data, header, index)
        local lump = reader.lump(header, BSP.lumpVertexes)
        local count = reader.lumpCount(header, BSP.lumpVertexes, BSP.vertexSize)
        index = tonumber(index) or -1
        if index < 0 or index >= count then return end

        return reader.readVector(data, lump.fileofs + index * BSP.vertexSize)
    end

    function reader.readFace(data, header, index)
        local lump = reader.lump(header, BSP.lumpFaces)
        local count = reader.lumpCount(header, BSP.lumpFaces, BSP.faceSize)
        index = tonumber(index) or -1
        if index < 0 or index >= count then return end

        local offset = lump.fileofs + index * BSP.faceSize
        return {
            index = index,
            firstEdge = readInt32(data, offset + 4),
            numEdges = readInt16(data, offset + 8),
            texInfo = readInt16(data, offset + 10),
            dispInfo = readInt16(data, offset + 12)
        }
    end

    function reader.readFaceVertices(data, header, face)
        if not face or not face.firstEdge or not face.numEdges or face.numEdges < 3 then return end

        local surfEdgeLump = reader.lump(header, BSP.lumpSurfEdges)
        local edgeLump = reader.lump(header, BSP.lumpEdges)
        local surfEdgeCount = reader.lumpCount(header, BSP.lumpSurfEdges, BSP.surfEdgeSize)
        local edgeCount = reader.lumpCount(header, BSP.lumpEdges, BSP.edgeSize)
        if not surfEdgeLump or not edgeLump then return end

        local vertices = {}
        for i = 0, face.numEdges - 1 do
            local surfEdgeIndex = face.firstEdge + i
            if surfEdgeIndex < 0 or surfEdgeIndex >= surfEdgeCount then return end

            local surfEdge = readInt32(data, surfEdgeLump.fileofs + surfEdgeIndex * BSP.surfEdgeSize)
            local edgeIndex = math.abs(surfEdge)
            if edgeIndex < 0 or edgeIndex >= edgeCount then return end

            local edgeOffset = edgeLump.fileofs + edgeIndex * BSP.edgeSize
            local vertexIndex = surfEdge >= 0
                and readUInt16(data, edgeOffset)
                or readUInt16(data, edgeOffset + 2)
            local vertex = reader.readVertex(data, header, vertexIndex)
            if not vertex then return end

            vertices[#vertices + 1] = vertex
        end

        return vertices
    end

    function reader.readTextureName(data, header, texInfoIndex)
        texInfoIndex = tonumber(texInfoIndex) or -1
        if texInfoIndex < 0 then return end

        local texInfoLump = reader.lump(header, BSP.lumpTexInfo)
        local texDataLump = reader.lump(header, BSP.lumpTexData)
        local stringTableLump = reader.lump(header, BSP.lumpTexDataStringTable)
        local stringDataLump = reader.lump(header, BSP.lumpTexDataStringData)
        if not (reader.lumpIsReadable(data, texInfoLump)
            and reader.lumpIsReadable(data, texDataLump)
            and reader.lumpIsReadable(data, stringTableLump)
            and reader.lumpIsReadable(data, stringDataLump)) then
            return
        end
        if reader.lumpIsCompressed(data, texInfoLump)
            or reader.lumpIsCompressed(data, texDataLump)
            or reader.lumpIsCompressed(data, stringTableLump)
            or reader.lumpIsCompressed(data, stringDataLump) then
            return
        end

        local texInfoCount = reader.lumpCount(header, BSP.lumpTexInfo, BSP.texInfoSize)
        if texInfoIndex >= texInfoCount then return end

        local texInfoOffset = texInfoLump.fileofs + texInfoIndex * BSP.texInfoSize
        local texDataIndex = readInt32(data, texInfoOffset + 68)
        local texDataCount = reader.lumpCount(header, BSP.lumpTexData, BSP.texDataSize)
        if texDataIndex < 0 or texDataIndex >= texDataCount then return end

        local texDataOffset = texDataLump.fileofs + texDataIndex * BSP.texDataSize
        local nameIndex = readInt32(data, texDataOffset + 12)
        local nameCount = math.floor((stringTableLump.filelen or 0) / 4)
        if nameIndex < 0 or nameIndex >= nameCount then return end

        local stringOffset = readInt32(data, stringTableLump.fileofs + nameIndex * 4)
        if stringOffset < 0 or stringOffset >= stringDataLump.filelen then return end

        return readCString(data, stringDataLump.fileofs + stringOffset, 256)
    end

    function reader.readDispInfo(data, header, index)
        local lump = reader.lump(header, BSP.lumpDispInfo)
        local count = reader.lumpCount(header, BSP.lumpDispInfo, BSP.dispInfoSize)
        index = tonumber(index) or -1
        if index < 0 or index >= count then return end

        local offset = lump.fileofs + index * BSP.dispInfoSize
        return {
            index = index,
            startPosition = reader.readVector(data, offset),
            dispVertStart = readInt32(data, offset + 12),
            power = readInt32(data, offset + 20),
            mapFace = readUInt16(data, offset + 36)
        }
    end

    return reader
end
