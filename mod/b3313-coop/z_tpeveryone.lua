-- /tpeveryone for B3313
-- Proper multiplayer version: uses sync tables so EVERY client warps itself.

gGlobalSyncTable.tpEveryoneLevel = 0
gGlobalSyncTable.tpEveryoneArea  = 0
gGlobalSyncTable.tpEveryoneAct   = 0
gGlobalSyncTable.tpEveryoneSeq   = 0
gGlobalSyncTable.tpEveryonePos   = 0
gGlobalSyncTable.tpHostX = 0
gGlobalSyncTable.tpHostY = 0
gGlobalSyncTable.tpHostZ = 0

local lastTpSeq = 0

local function find_b3313_area(query)
    if not query or query == "" then return nil end
    if not B3313_AREA_NAMES then return nil end
    query = string.lower(query)
    for level, areas in pairs(B3313_AREA_NAMES) do
        for area, name in pairs(areas) do
            if string.lower(name) == query then
                return level, area, name
            end
        end
    end
    return nil
end

local function do_local_warp_level(level, area, act)
    if warp_to_level then
        warp_to_level(level, area, act or 0)
    end
end

local function do_local_warp_pos(x, y, z)
    local m = gMarioStates[0]
    if not m then return end
    m.pos.x = x
    m.pos.y = y
    m.pos.z = z
    m.vel.x = 0
    m.vel.y = 0
    m.vel.z = 0
    m.forwardVel = 0
    if m.marioObj then
        m.marioObj.oPosX = x
        m.marioObj.oPosY = y
        m.marioObj.oPosZ = z
    end
end

-- Every client checks for a new TP request and warps THEMSELVES
hook_event(HOOK_UPDATE, function()
    local seq = gGlobalSyncTable.tpEveryoneSeq or 0
    if seq == 0 or seq == lastTpSeq then return end
    lastTpSeq = seq

    if gGlobalSyncTable.tpEveryonePos == 1 then
        do_local_warp_pos(
            gGlobalSyncTable.tpHostX or 0,
            gGlobalSyncTable.tpHostY or 0,
            gGlobalSyncTable.tpHostZ or 0
        )
    else
        local level = gGlobalSyncTable.tpEveryoneLevel or 0
        local area  = gGlobalSyncTable.tpEveryoneArea or 1
        local act   = gGlobalSyncTable.tpEveryoneAct or 0
        if level ~= 0 then
            do_local_warp_level(level, area, act)
        end
    end
end)

hook_chat_command("tpeveryone", "[area name] - warp everyone to a B3313 area, or to you", function(msg)
    if not network_is_server() then
        djui_chat_message_create("Only the host can use /tpeveryone")
        return true
    end

    local arg = nil
    if msg and msg ~= "" then
        arg = msg:match("^%s*(.-)%s*$")
    end

    local nextSeq = (gGlobalSyncTable.tpEveryoneSeq or 0) + 1

    if arg and arg ~= "" then
        if B3313_AREA_NAMES then
            local level, area, name = find_b3313_area(arg)
            if level then
                gGlobalSyncTable.tpEveryonePos = 0
                gGlobalSyncTable.tpEveryoneLevel = level
                gGlobalSyncTable.tpEveryoneArea = area or 1
                gGlobalSyncTable.tpEveryoneAct = 0
                gGlobalSyncTable.tpEveryoneSeq = nextSeq
                djui_chat_message_create("Warping everyone to \\#00ff00\\" .. name)
                djui_chat_message_create("(level " .. tostring(level) .. " area " .. tostring(area or 1) .. ")")
                return true
            end
        end

        local l, a = arg:match("^(%d+)%s+(%d+)$")
        if l then
            gGlobalSyncTable.tpEveryonePos = 0
            gGlobalSyncTable.tpEveryoneLevel = tonumber(l)
            gGlobalSyncTable.tpEveryoneArea = tonumber(a)
            gGlobalSyncTable.tpEveryoneAct = 0
            gGlobalSyncTable.tpEveryoneSeq = nextSeq
            djui_chat_message_create("Warping everyone to level \\#00ff00\\" .. l .. "\\#ffffff\\ area \\#00ff00\\" .. a)
            return true
        end

        local onlyLevel = tonumber(arg)
        if onlyLevel then
            gGlobalSyncTable.tpEveryonePos = 0
            gGlobalSyncTable.tpEveryoneLevel = onlyLevel
            gGlobalSyncTable.tpEveryoneArea = 1
            gGlobalSyncTable.tpEveryoneAct = 0
            gGlobalSyncTable.tpEveryoneSeq = nextSeq
            djui_chat_message_create("Warping everyone to level \\#00ff00\\" .. onlyLevel)
            return true
        end

        djui_chat_message_create("Unknown B3313 area: \\#ff0000\\" .. arg)
        djui_chat_message_create("Type the exact display name, e.g. Fabricated Lobby")
        return true
    end

    -- No arg: teleport everyone to host position
    local host = gMarioStates[0]
    gGlobalSyncTable.tpEveryonePos = 1
    gGlobalSyncTable.tpHostX = host.pos.x
    gGlobalSyncTable.tpHostY = host.pos.y
    gGlobalSyncTable.tpHostZ = host.pos.z
    gGlobalSyncTable.tpEveryoneLevel = 0
    gGlobalSyncTable.tpEveryoneSeq = nextSeq

    local count = 0
    for i = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[i] and gNetworkPlayers[i].connected then
            count = count + 1
        end
    end
    djui_chat_message_create("Teleporting \\#00ff00\\" .. count .. "\\#ffffff\\ player(s) to host")
    return true
end)
