-- Fix: B3313 Toad stars
-- Vanilla Toad star awards use SM64's save file. B3313 uses its own.
-- This watches for finished Toad dialogs and spawns the star so it can
-- be collected through B3313's star system.

local toadGave = {}
local readingToad = nil
local wasInDialog = false

local function toad_key(o)
    return string.format("%d_%d_%d_%d",
        (gNetworkPlayers[0] and gNetworkPlayers[0].currLevelNum) or 0,
        (gNetworkPlayers[0] and gNetworkPlayers[0].currAreaIndex) or 0,
        math.floor((o.oPosX or 0) / 40),
        math.floor((o.oPosZ or 0) / 40))
end

local function toad_star_index(o)
    local index = (o.oBehParams >> 24) & 0xFF
    if index == 0 or index == 0xFF then
        index = (o.oBehParams >> 16) & 0xFF
    end
    return index
end

local function is_toad_object(o)
    if o == nil then return false end
    -- Vanilla Toad
    if id_bhvToadMessage and obj_has_behavior_id and obj_has_behavior_id(o, id_bhvToadMessage) ~= 0 then
        return true
    end
    -- Heuristic: text interact + toad-sized hitbox (B3313 custom toads)
    if o.oInteractType == (INTERACT_TEXT or 0x800000)
        and o.hitboxRadius and o.hitboxRadius >= 60 and o.hitboxRadius <= 120
        and o.hitboxHeight and o.hitboxHeight >= 80 and o.hitboxHeight <= 150 then
        return true
    end
    return false
end

local function find_nearby_toad(m)
    if not m or not m.marioObj then return nil end
    local best, bestD = nil, 350

    -- Vanilla
    if id_bhvToadMessage then
        local o = obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvToadMessage)
        if o then
            local d = dist_between_objects(o, m.marioObj)
            if d < bestD then best, bestD = o, d end
        end
    end

    -- Scan objects near Mario for custom toads (limited range)
    -- Use bob-omb buddy as alternate if toads were mis-mapped to buddy
    if id_bhvBobombBuddy then
        local o = obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvBobombBuddy)
        if o and is_toad_object(o) then
            local d = dist_between_objects(o, m.marioObj)
            if d < bestD then best, bestD = o, d end
        end
    end

    return best
end

local function try_give_toad_star(o)
    if not o then return end
    local key = toad_key(o)
    if toadGave[key] then return end

    local index = toad_star_index(o)

    if index > 0 and b3313_star_is_collected and b3313_star_is_collected(index) then
        toadGave[key] = true
        return
    end

    local x, y, z = o.oPosX, o.oPosY + 220, o.oPosZ
    local star = nil
    if spawn_default_star then
        star = spawn_default_star(x, y, z)
    elseif spawn_non_sync_object and id_bhvSpawnedStar then
        star = spawn_non_sync_object(id_bhvSpawnedStar, E_MODEL_STAR, x, y, z, nil)
    end

    if star then
        if index > 0 then
            star.oBehParams = (index << 24) | (star.oBehParams & 0x00FFFFFF)
        end
        toadGave[key] = true
        djui_chat_message_create("\\#ffff00\\Toad star appeared!")
    end
end

-- Watch dialog end near a Toad
hook_event(HOOK_MARIO_UPDATE, function(m)
    if m.playerIndex ~= 0 then return end

    local inDialog = (m.action == ACT_READING_NPC_DIALOG
        or m.action == ACT_WAITING_FOR_DIALOG
        or m.action == ACT_READING_AUTOMATIC_DIALOG)

    if inDialog then
        wasInDialog = true
        local o = find_nearby_toad(m)
        if o then readingToad = o end
    elseif wasInDialog then
        wasInDialog = false
        local o = readingToad or find_nearby_toad(m)
        readingToad = nil
        if o then
            try_give_toad_star(o)
        end
    end
end)

-- Also hook vanilla ToadMessage: when interacted, queue star on dialog end
hook_behavior(id_bhvToadMessage, OBJ_LIST_GENACTOR, false, nil, function(o)
    bhv_toad_message_loop()
    if (o.oInteractStatus & INT_STATUS_INTERACTED) ~= 0 then
        o.oInteractStatus = 0
        readingToad = o
        wasInDialog = true
    end
end)

-- Clear per-area when level changes
hook_event(HOOK_ON_LEVEL_INIT, function()
    toadGave = {}
    readingToad = nil
    wasInDialog = false
end)

hook_chat_command("toadstar", "- force nearest Toad to give a star (host)", function()
    if not network_is_server() then
        djui_chat_message_create("Host only")
        return true
    end
    local m = gMarioStates[0]
    local o = find_nearby_toad(m)
    if o then
        toadGave[toad_key(o)] = nil
        try_give_toad_star(o)
        djui_chat_message_create("Forced Toad star")
    else
        if spawn_default_star then
            spawn_default_star(m.pos.x, m.pos.y + 200, m.pos.z)
            djui_chat_message_create("No Toad found — spawned test star")
        else
            djui_chat_message_create("No Toad nearby")
        end
    end
    return true
end)
