if SERVER then return end

MAGIC_ALIGN = MAGIC_ALIGN or include("autorun/magic_align.lua")

local M = MAGIC_ALIGN

if M.ClientProfiler and M.ClientProfiler.active and isfunction(M.ClientProfiler.Stop) then
    M.ClientProfiler:Stop("module reload")
end

local Profiler = {}
M.ClientProfiler = Profiler

local DEFAULT_DURATION = 10
local MIN_DURATION = 1
local MAX_DURATION = 120
local DEFAULT_ROWS = 15
local MAX_ROWS = 60
local DISCOVERY_INTERVAL = 0.25
local FRAME_HOOK = "MagicAlignProfilerFrame"

local TOOL_METHODS = {
    "Think",
    "DrawHUD",
    "DrawToolScreen",
    "LeftClick",
    "RightClick",
    "Reload",
    "BuildCPanel",
    "Deploy",
    "Holster",
    "FreezeMovement"
}

local function now()
    return SysTime()
end

local function memoryKb()
    return collectgarbage("count") or 0
end

local function clampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function containsMagicAlign(value)
    value = string.lower(tostring(value or ""))
    return string.find(value, "magic_align", 1, true) ~= nil
        or string.find(value, "magicalign", 1, true) ~= nil
end

local function isProfilerLabel(value)
    value = string.lower(tostring(value or ""))
    return string.find(value, "profiler", 1, true) ~= nil
        or string.find(value, "profile", 1, true) ~= nil
end

local function functionSource(fn)
    if not debug or not isfunction(debug.getinfo) or not isfunction(fn) then return "" end

    local info = debug.getinfo(fn, "S")
    return info and (info.short_src or info.source or "") or ""
end

local function shortLabel(label, maxLength)
    label = tostring(label or "")
    maxLength = maxLength or 56

    if #label <= maxLength then
        return label
    end

    return "..." .. string.sub(label, #label - maxLength + 4)
end

local function safeName(value)
    local text = tostring(value or "")
    text = string.gsub(text, "%s+", "_")
    return text
end

local function currentHookFunction(eventName, identifier)
    local hooks = hook.GetTable()
    local bucket = hooks and hooks[eventName]
    return bucket and bucket[identifier] or nil
end

local function getControlTable(controlName)
    local control = vgui.GetControlTable(controlName)
    if control then return control end

    local controls = derma.GetControlList()
    local entry = controls and controls[controlName]

    if istable(entry) then
        return entry.Table or entry.Base
    end
end

local function finishMeasuredCall(profiler, stat, startTime, startMem, ok, ...)
    local elapsed = math.max(now() - startTime, 0)
    local deltaMem = memoryKb() - startMem

    profiler.callDepth = math.max((profiler.callDepth or 1) - 1, 0)
    profiler:Record(stat, elapsed, deltaMem)

    if not ok then
        stat.errors = stat.errors + 1
        local err = select(1, ...)
        error(err, 0)
    end

    return ...
end

function Profiler:Reset()
    self.active = false
    self.stats = {}
    self.statOrder = {}
    self.restoreStack = {}
    self.wrapperLookup = {}
    self.wrappedOwners = {}
    self.callDepth = 0
    self.suppressed = 0
    self.rows = DEFAULT_ROWS
    self.originalHookAdd = nil
    self.hookAddWrapper = nil
    self.originalNetReceive = nil
    self.netReceiveWrapper = nil
    self.startedAt = 0
    self.endsAt = 0
    self.lastDiscoveryAt = 0
    self.heapStart = 0
    self.heapLast = 0
    self.heapEnd = 0
    self.heapMin = 0
    self.heapMax = 0
    self.frameSamples = 0
    self.frameHeapRise = 0
    self.frameHeapDrop = 0
end

function Profiler:Suppress()
    self.suppressed = (self.suppressed or 0) + 1
end

function Profiler:Unsuppress()
    self.suppressed = math.max((self.suppressed or 1) - 1, 0)
end

function Profiler:GetStat(label, source)
    local stat = self.stats[label]

    if stat then
        return stat
    end

    stat = {
        label = label,
        source = source or "",
        calls = 0,
        total = 0,
        max = 0,
        memNet = 0,
        memRise = 0,
        memDrop = 0,
        maxMemRise = 0,
        maxMemDrop = 0,
        errors = 0
    }

    self.stats[label] = stat
    self.statOrder[#self.statOrder + 1] = stat

    return stat
end

function Profiler:Record(stat, elapsed, deltaMem)
    stat.calls = stat.calls + 1
    stat.total = stat.total + elapsed

    if elapsed > stat.max then
        stat.max = elapsed
    end

    stat.memNet = stat.memNet + deltaMem

    if deltaMem >= 0 then
        stat.memRise = stat.memRise + deltaMem

        if deltaMem > stat.maxMemRise then
            stat.maxMemRise = deltaMem
        end
    else
        local drop = -deltaMem
        stat.memDrop = stat.memDrop + drop

        if drop > stat.maxMemDrop then
            stat.maxMemDrop = drop
        end
    end
end

function Profiler:MeasuredFunction(label, fn, source)
    local stat = self:GetStat(label, source)
    local profiler = self

    local wrapper = function(...)
        if not profiler.active or (profiler.suppressed or 0) > 0 then
            return fn(...)
        end

        profiler.callDepth = (profiler.callDepth or 0) + 1

        local startTime = now()
        local startMem = memoryKb()

        return finishMeasuredCall(profiler, stat, startTime, startMem, pcall(fn, ...))
    end

    self.wrapperLookup[wrapper] = true

    return wrapper
end

function Profiler:OwnerKey(owner, key)
    return tostring(owner) .. "\n" .. tostring(key)
end

function Profiler:WrapOwnerFunction(owner, key, label, source)
    if not istable(owner) then return false end

    local fn = rawget(owner, key)

    if not isfunction(fn) or self.wrapperLookup[fn] then
        return false
    end

    local ownerKey = self:OwnerKey(owner, key)
    if self.wrappedOwners[ownerKey] then
        return false
    end

    local wrapper = self:MeasuredFunction(label, fn, source or functionSource(fn))
    self.wrappedOwners[ownerKey] = true
    owner[key] = wrapper

    self.restoreStack[#self.restoreStack + 1] = function()
        if owner[key] == wrapper then
            owner[key] = fn
        end
    end

    return true
end

function Profiler:WrapTableFunctions(owner, labelPrefix, skipKeys)
    if not istable(owner) then return end

    for key, value in pairs(owner) do
        if isfunction(value) and not (skipKeys and skipKeys[key]) then
            self:WrapOwnerFunction(owner, key, labelPrefix .. "." .. safeName(key))
        end
    end
end

function Profiler:ShouldWrapHook(eventName, identifier, fn)
    if not isfunction(fn) or self.wrapperLookup[fn] then return false end

    if identifier == FRAME_HOOK then return false end
    if isProfilerLabel(identifier) then return false end

    return containsMagicAlign(identifier)
        or containsMagicAlign(eventName)
        or containsMagicAlign(functionSource(fn))
end

function Profiler:WrapHookFunction(eventName, identifier, fn)
    if not self:ShouldWrapHook(eventName, identifier, fn) then
        return fn
    end

    local label = "hook." .. safeName(eventName) .. "." .. safeName(identifier)
    local wrapper = self:MeasuredFunction(label, fn, functionSource(fn))

    self.restoreStack[#self.restoreStack + 1] = function()
        if currentHookFunction(eventName, identifier) == wrapper then
            local add = self.originalHookAdd or hook.Add
            add(eventName, identifier, fn)
        end
    end

    return wrapper
end

function Profiler:WrapExistingHooks()
    local hooks = hook.GetTable()
    if not istable(hooks) then return end

    local add = self.originalHookAdd or hook.Add
    if not isfunction(add) then return end

    for eventName, bucket in pairs(hooks) do
        if istable(bucket) then
            for identifier, fn in pairs(bucket) do
                local wrapper = self:WrapHookFunction(eventName, identifier, fn)

                if wrapper ~= fn then
                    add(eventName, identifier, wrapper)
                end
            end
        end
    end
end

function Profiler:InstallHookAddWrapper()
    if self.hookAddWrapper then return end

    local original = hook.Add
    local profiler = self

    local wrapper = function(eventName, identifier, fn)
        if profiler.active and isfunction(fn) then
            fn = profiler:WrapHookFunction(eventName, identifier, fn)
        end

        return original(eventName, identifier, fn)
    end

    self.originalHookAdd = original
    self.hookAddWrapper = wrapper
    hook.Add = wrapper

    self.restoreStack[#self.restoreStack + 1] = function()
        if hook.Add == wrapper then
            hook.Add = original
        end
    end
end

function Profiler:ShouldWrapNetReceiver(name, fn)
    if not isfunction(fn) or self.wrapperLookup[fn] then return false end
    return containsMagicAlign(name) or containsMagicAlign(functionSource(fn))
end

function Profiler:WrapNetReceiver(name, fn)
    if not self:ShouldWrapNetReceiver(name, fn) then
        return fn
    end

    local label = "net." .. safeName(name)
    local wrapper = self:MeasuredFunction(label, fn, functionSource(fn))
    local key = string.lower(tostring(name or ""))

    self.restoreStack[#self.restoreStack + 1] = function()
        if istable(net.Receivers) and net.Receivers[key] == wrapper then
            net.Receivers[key] = fn
        end
    end

    return wrapper
end

function Profiler:WrapExistingNetReceivers()
    if not istable(net.Receivers) then return end

    for name, fn in pairs(net.Receivers) do
        local wrapper = self:WrapNetReceiver(name, fn)

        if wrapper ~= fn then
            net.Receivers[name] = wrapper
        end
    end
end

function Profiler:InstallNetReceiveWrapper()
    if self.netReceiveWrapper then return end

    local original = net.Receive
    local profiler = self

    local wrapper = function(name, fn)
        if profiler.active and isfunction(fn) then
            fn = profiler:WrapNetReceiver(name, fn)
        end

        return original(name, fn)
    end

    self.originalNetReceive = original
    self.netReceiveWrapper = wrapper
    net.Receive = wrapper

    self.restoreStack[#self.restoreStack + 1] = function()
        if net.Receive == wrapper then
            net.Receive = original
        end
    end
end

function Profiler:AddToolCandidate(candidates, seen, tool)
    if not istable(tool) then return end
    if seen[tool] then return end

    seen[tool] = true
    candidates[#candidates + 1] = tool
end

function Profiler:ToolCandidates()
    local candidates = {}
    local seen = {}

    local getter = M.GetActiveClassicMagicAlignTool or M.GetActiveMagicAlignTool
    if isfunction(getter) then
        local ply = LocalPlayer()
        local tool = IsValid(ply) and getter(ply) or nil
        self:AddToolCandidate(candidates, seen, tool)
    end

    local stored = weapons.GetStored("gmod_tool")
    local tools = istable(stored) and stored.Tool or nil

    if istable(tools) then
        self:AddToolCandidate(candidates, seen, tools.magic_align)
        self:AddToolCandidate(candidates, seen, tools["magic_align"])
    end

    return candidates
end

function Profiler:WrapToolMethods()
    for _, tool in ipairs(self:ToolCandidates()) do
        for _, methodName in ipairs(TOOL_METHODS) do
            self:WrapOwnerFunction(tool, methodName, "TOOL." .. methodName)
        end
    end
end

function Profiler:WrapModuleFunctions()
    local client = M.Client

    self:WrapTableFunctions(M, "MAGIC_ALIGN", {
        Client = true,
        ClientProfiler = true
    })

    self:WrapTableFunctions(client, "MAGIC_ALIGN.Client", {
        ClientState = true,
        ClientSheet = true,
        ClientTabs = true,
        colors = true,
        menuColors = true,
        Profiler = true
    })

    if istable(client) then
        self:WrapTableFunctions(client.geometry, "MAGIC_ALIGN.Client.geometry")
        self:WrapTableFunctions(client.WorldBSP, "MAGIC_ALIGN.Client.WorldBSP")
        self:WrapTableFunctions(client.WorldPoints, "MAGIC_ALIGN.Client.WorldPoints")
        self:WrapTableFunctions(client.gizmoShared, "MAGIC_ALIGN.Client.gizmoShared")
        self:WrapTableFunctions(client.worldGridRender, "MAGIC_ALIGN.Client.worldGridRender")
    end

    self:WrapTableFunctions(M.MathParser, "MAGIC_ALIGN.MathParser")
    self:WrapTableFunctions(M.FormulaManager, "MAGIC_ALIGN.FormulaManager")
    self:WrapTableFunctions(M.Compat, "MAGIC_ALIGN.Compat")
end

function Profiler:WrapVguiControl(controlName)
    local control = getControlTable(controlName)
    self:WrapTableFunctions(control, "vgui." .. controlName)
end

function Profiler:WrapVguiControls()
    self:WrapVguiControl("DMagicAlignNumSlider")
    self:WrapVguiControl("DMagicAlignNumSliders")
end

function Profiler:Discover()
    self:Suppress()
    self:InstallHookAddWrapper()
    self:InstallNetReceiveWrapper()
    self:WrapExistingHooks()
    self:WrapExistingNetReceivers()
    self:WrapToolMethods()
    self:WrapModuleFunctions()
    self:WrapVguiControls()
    self:Unsuppress()
end

function Profiler:SampleFrame()
    local heap = memoryKb()

    self.heapEnd = heap
    self.frameSamples = self.frameSamples + 1

    if heap < self.heapMin then self.heapMin = heap end
    if heap > self.heapMax then self.heapMax = heap end

    local delta = heap - self.heapLast

    if delta > self.frameHeapRise then
        self.frameHeapRise = delta
    elseif -delta > self.frameHeapDrop then
        self.frameHeapDrop = -delta
    end

    self.heapLast = heap
end

function Profiler:Think()
    if not self.active then return end

    self:SampleFrame()

    local t = now()

    if t - self.lastDiscoveryAt >= DISCOVERY_INTERVAL then
        self.lastDiscoveryAt = t
        self:Discover()
    end

    if t >= self.endsAt then
        self:Stop("complete")
    end
end

function Profiler:RowsSorted(compare)
    local rows = {}

    for _, stat in ipairs(self.statOrder or {}) do
        if stat.calls > 0 then
            rows[#rows + 1] = stat
        end
    end

    table.sort(rows, compare)

    return rows
end

function Profiler:PrintRows(title, rows)
    local limit = math.min(self.rows or DEFAULT_ROWS, #rows)
    print("[MagicAlign Profiler] " .. title)
    print("[MagicAlign Profiler] #  label                                                    calls  total_ms   avg_ms   max_ms   heap+KB  gcDropKB   netKB")

    for i = 1, limit do
        local stat = rows[i]
        local avg = stat.calls > 0 and stat.total / stat.calls or 0

        print(string.format(
            "[MagicAlign Profiler] %02d %-56s %6d %9.3f %8.4f %8.3f %9.1f %9.1f %8.1f",
            i,
            shortLabel(stat.label, 56),
            stat.calls,
            stat.total * 1000,
            avg * 1000,
            stat.max * 1000,
            stat.memRise,
            stat.memDrop,
            stat.memNet
        ))
    end

    if limit == 0 then
        print("[MagicAlign Profiler] no calls captured")
    end
end

function Profiler:PrintReport(reason)
    local duration = math.max((self.stoppedAt or now()) - (self.startedAt or now()), 0)

    print(string.format(
        "[MagicAlign Profiler] %s after %.2fs. heap start=%.1fKB end=%.1fKB peak=%.1fKB min=%.1fKB maxFrame+=%.1fKB maxFrameDrop=%.1fKB frames=%d",
        reason or "stopped",
        duration,
        self.heapStart or 0,
        self.heapEnd or 0,
        self.heapMax or 0,
        self.heapMin or 0,
        self.frameHeapRise or 0,
        self.frameHeapDrop or 0,
        self.frameSamples or 0
    ))

    self:PrintRows("Top CPU, inclusive", self:RowsSorted(function(a, b)
        return a.total > b.total
    end))

    self:PrintRows("Top heap growth", self:RowsSorted(function(a, b)
        if a.memRise == b.memRise then
            return a.total > b.total
        end

        return a.memRise > b.memRise
    end))

    self:PrintRows("Top GC drops observed inside calls", self:RowsSorted(function(a, b)
        if a.memDrop == b.memDrop then
            return a.total > b.total
        end

        return a.memDrop > b.memDrop
    end))
end

function Profiler:Restore()
    self:Suppress()

    for i = #(self.restoreStack or {}), 1, -1 do
        local restore = self.restoreStack[i]

        if isfunction(restore) then
            pcall(restore)
        end
    end

    hook.Remove("Think", FRAME_HOOK)

    self.restoreStack = {}
    self.wrapperLookup = {}
    self.wrappedOwners = {}
    self.hookAddWrapper = nil
    self.netReceiveWrapper = nil
    self.originalHookAdd = nil
    self.originalNetReceive = nil
    self:Unsuppress()
end

function Profiler:Start(duration, rows)
    if self.active then
        print("[MagicAlign Profiler] already running; use magic_align_profile_stop first")
        return
    end

    self:Reset()

    duration = clampNumber(duration, MIN_DURATION, MAX_DURATION, DEFAULT_DURATION)
    rows = clampNumber(rows, 1, MAX_ROWS, DEFAULT_ROWS)

    self.active = true
    self.rows = math.floor(rows)
    self.startedAt = now()
    self.endsAt = self.startedAt + duration
    self.lastDiscoveryAt = 0
    self.heapStart = memoryKb()
    self.heapLast = self.heapStart
    self.heapEnd = self.heapStart
    self.heapMin = self.heapStart
    self.heapMax = self.heapStart

    self:Discover()

    hook.Add("Think", FRAME_HOOK, function()
        Profiler:Think()
    end)

    print(string.format(
        "[MagicAlign Profiler] running for %.1fs; rows=%d; command: magic_align_profile_stop",
        duration,
        self.rows
    ))
end

function Profiler:Stop(reason)
    if not self.active then
        print("[MagicAlign Profiler] not running")
        return
    end

    self.stoppedAt = now()
    self.heapEnd = memoryKb()
    self.active = false

    self:Restore()
    self:PrintReport(reason or "stopped")
end

function Profiler:Status()
    if not self.active then
        print("[MagicAlign Profiler] not running")
        return
    end

    print(string.format(
        "[MagicAlign Profiler] running %.2fs / %.2fs; captured labels=%d; heap=%.1fKB",
        now() - self.startedAt,
        self.endsAt - self.startedAt,
        #(self.statOrder or {}),
        memoryKb()
    ))
end

Profiler:Reset()

concommand.Add("magic_align_profile", function(ply, cmd, args)
    args = args or {}

    local first = string.lower(tostring(args[1] or ""))

    if first == "stop" then
        Profiler:Stop("stopped")
        return
    elseif first == "status" then
        Profiler:Status()
        return
    end

    Profiler:Start(args[1], args[2])
end)

concommand.Add("magic_align_profile_stop", function()
    Profiler:Stop("stopped")
end)

concommand.Add("magic_align_profile_status", function()
    Profiler:Status()
end)

print("[MagicAlign Profiler] loaded. Use: magic_align_profile 10")

return Profiler
