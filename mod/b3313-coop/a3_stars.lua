-- B3313's own star save.
--
-- B3313 replaced SM64's save code: a star whose index (top byte of behParams) is 16 or more
-- is saved as course ((index - 16) / 8), star ((index - 16) % 8), with room for 59 courses
-- of 8 stars plus the castle's secret stars, and the star total counts all of them. Over
-- half of B3313's stars use those extended indices, and sm64coopdx's save can only hold
-- 25 courses of 7 stars, so the port keeps B3313's star table itself:
--   * collecting any star goes through b3313_collect_star() (same effects as the game's
--     star interaction) and is recorded here, then shared with the other players;
--   * the host keeps the table per save file in mod storage and sends it to joiners;
--   * every player's star count, collected-star models and star-door checks use it.

B3313.stars = {}            -- [course] = 8-bit mask, course -1 = castle secret stars
B3313.starsFile = -1
local NUM_COURSES = 59

local function stars_key(file) return "b3313_stars_" .. file end

local function stars_serialize()
    local t = {}
    for c = -1, NUM_COURSES - 1 do t[#t + 1] = string.format("%02x", B3313.stars[c] or 0) end
    return table.concat(t)
end

local function stars_deserialize(s)
    B3313.stars = {}
    if type(s) ~= "string" then return end
    local i = 0
    for hex in s:gmatch("%x%x") do
        B3313.stars[i - 1] = tonumber(hex, 16)
        i = i + 1
        if i > NUM_COURSES then break end
    end
end

local function stars_check_file()
    local file = get_current_save_file_num()
    if file ~= B3313.starsFile then
        B3313.starsFile = file
        if network_is_server() then
            stars_deserialize(mod_storage_load(stars_key(file), ""))
        end
    end
end

local function stars_persist()
    if network_is_server() then
        mod_storage_save(stars_key(get_current_save_file_num()), stars_serialize())
    end
end

-- B3313's mapping from a star index to (course, bit); course is 0-based, -1 = castle
function b3313_star_slot(index)
    if index >= 16 then return (index - 16) >> 3, (index - 16) & 7 end
    return gNetworkPlayers[0].currCourseNum - 1, index
end

function b3313_star_flags(course)
    stars_check_file()
    return B3313.stars[course] or 0
end

function b3313_star_is_collected(index)
    local c, b = b3313_star_slot(index)
    return (b3313_star_flags(c) & ((1 << b) & 0xFF)) ~= 0
end

function b3313_total_stars()
    stars_check_file()
    local n = 0
    for c = -1, NUM_COURSES - 1 do
        local f = B3313.stars[c] or 0
        while f ~= 0 do n = n + (f & 1); f = f >> 1 end
    end
    return n
end

local function stars_set(course, bit)
    stars_check_file()
    if course < -1 or course >= NUM_COURSES then return end
    B3313.stars[course] = ((B3313.stars[course] or 0) | (1 << bit)) & 0xFF
    stars_persist()
end

-- behaviors whose objects are stars (not keys, not the grand star)
local function is_b3313_star(o)
    if o.oInteractType ~= INTERACT_STAR_OR_KEY then return false end
    local id = get_id_from_behavior(o.behavior)
    if id == id_bhvBowserKey or id == id_bhvGrandStar then return false end
    if (o.oInteractionSubtype & INT_SUBTYPE_GRAND_STAR) ~= 0 then return false end
    return true
end

-- interact_star_or_key, with B3313's save instead of sm64coopdx's
function b3313_collect_star(m, o)
    if m.health < 0x100 then return end
    local noExit = (o.oInteractionSubtype & INT_SUBTYPE_NO_EXIT) ~= 0
    local lvl = gNetworkPlayers[0].currLevelNum
    local bowserLevel = (lvl == LEVEL_BOWSER_1 or lvl == LEVEL_BOWSER_2 or lvl == LEVEL_BOWSER_3)
    if not bowserLevel and gServerSettings.stayInLevelAfterStar ~= 0 then noExit = true end

    if gServerSettings.stayInLevelAfterStar ~= STAR_NON_STOP then mario_stop_riding_and_holding(m) end
    queue_rumble_data_mario(m, 5, 80)
    if not noExit then
        m.hurtCounter = 0
        m.healCounter = 0
        if m.capTimer > 1 then m.capTimer = 1 end
    end
    if gLevelValues.starHeal ~= 0 then
        m.healCounter = 31
        m.hurtCounter = 0
    end
    local action = noExit and ACT_STAR_DANCE_NO_EXIT or ACT_STAR_DANCE_EXIT
    if (m.action & ACT_FLAG_SWIMMING) ~= 0 or (m.action & ACT_FLAG_METAL_WATER) ~= 0 then action = ACT_STAR_DANCE_WATER end
    if (m.action & ACT_FLAG_AIR) ~= 0 then action = ACT_FALL_AFTER_STAR_GRAB end

    spawn_non_sync_object(id_bhvStarKeyCollectionPuffSpawner, E_MODEL_NONE, m.pos.x, m.pos.y, m.pos.z, nil)
    o.oInteractStatus = INT_STATUS_INTERACTED
    o.oIntangibleTimer = -1
    m.interactObj = o
    m.usedObj = o

    local index = (o.oBehParams >> 24) & 0xFF
    local course, bit = b3313_star_slot(index)
    stars_set(course, bit)
    network_send(true, { b3313 = "star", c = course, b = bit, bp = o.oBehParams,
        lvl = lvl, area = gNetworkPlayers[0].currAreaIndex,
        x = math.floor(o.oPosX), y = math.floor(o.oPosY), z = math.floor(o.oPosZ) })

    if not noExit then
        if b3313_painting_star_exit ~= nil then b3313_painting_star_exit(o) end
        drop_queued_background_music()
        fadeout_level_music(126)
    end
    play_sound(SOUND_MENU_STAR_SOUND, m.marioObj.header.gfx.cameraToObject)
    update_mario_sound_and_camera(m)
    if noExit and gServerSettings.stayInLevelAfterStar == STAR_NON_STOP then return end
    set_mario_action(m, action, noExit and 1 or 0)
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if interactType == INTERACT_STAR_OR_KEY and is_b3313_star(o) then
        if m.playerIndex == 0 and (o.oInteractStatus & INT_STATUS_INTERACTED) == 0 then
            b3313_collect_star(m, o)
        end
        return false
    end
    -- star doors compare sm64coopdx's own (empty) star count: let B3313's count open them
    if interactType == INTERACT_DOOR or interactType == INTERACT_WARP_DOOR then
        local need = (o.oBehParams >> 24) & 0xFF
        if need > 0 and b3313_total_stars() >= need then
            o.oBehParams = o.oBehParams & 0x00FFFFFF
        end
    end
    return true
end)

-- another player collected a star, or the host sent the whole table
hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data.b3313 == "star" then
        stars_set(data.c, data.b)
        local np = gNetworkPlayers[0]
        if data.lvl == np.currLevelNum and data.area == np.currAreaIndex then
            for _, id in ipairs({ id_bhvStar, id_bhvStarSpawnCoordinates, id_bhvSpawnedStar, id_bhvSpawnedStarNoLevelExit }) do
                local s = obj_get_first_with_behavior_id(id)
                while s ~= nil do
                    if s.oBehParams == data.bp and math.abs(s.oPosX - data.x) < 300 and math.abs(s.oPosZ - data.z) < 300 then
                        s.oInteractStatus = INT_STATUS_INTERACTED
                    end
                    s = obj_get_next_with_same_behavior_id(s)
                end
            end
        end
    elseif data.b3313 == "stars" then
        stars_deserialize(data.data)
        B3313.starsFile = get_current_save_file_num()
    end
end)

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
    if network_is_server() then
        stars_check_file()
        network_send_to(m.playerIndex, true, { b3313 = "stars", data = stars_serialize() })
    end
end)

-- the star counter (HUD, B3313's star gates) is B3313's total
hook_event(HOOK_UPDATE, function()
    local n = b3313_total_stars()
    for i = 0, MAX_PLAYERS - 1 do gMarioStates[i].numStars = n end
end)

-- collected stars show as transparent stars
local function star_show_collected(o)
    if b3313_star_is_collected((o.oBehParams >> 24) & 0xFF) then
        obj_set_model_extended(o, E_MODEL_TRANSPARENT_STAR)
    end
end
for _, id in ipairs({ id_bhvStar, id_bhvStarSpawnCoordinates, id_bhvSpawnedStar, id_bhvSpawnedStarNoLevelExit }) do
    hook_behavior(id, OBJ_LIST_LEVEL, false, star_show_collected, nil)
end



-- ============================================
-- RED STAR VISUAL FIX (actual red color)
-- ============================================

-- Star texture names used by sm64coopdx / dynos (try all)
local STAR_TEXTURE_NAMES = {
    "texture_star",
    "star",
    "star.rgba16",
    "segment2.0x0580.rgba16",
    "segment2.0x0A8C.rgba16",
    "textures/segment2.0x0580.rgba16",
    "textures/segment2.0x0A8C.rgba16",
}

local TEX_RED = nil
local function get_red_tex()
    if TEX_RED then return TEX_RED end
    local ok, t = pcall(get_texture_info, "red_star")
    if ok and t then TEX_RED = t end
    return TEX_RED
end

-- Indices known / marked as red power stars (expand with /markred)
local RED_STAR_INDICES = {
    [7] = true, [8] = true,
}

-- Runtime set of red stars currently in the level
local redStarsPresent = false

local function is_red_star(o)
    if o == nil then return false end
    local index = (o.oBehParams >> 24) & 0xFF
    if RED_STAR_INDICES[index] then return true end
    -- B3313 often encodes special stars in the 2nd byte
    local b2 = (o.oBehParams >> 16) & 0xFF
    if b2 == 1 or b2 == 2 or b2 == 0x10 then return true end
    -- Explicit marker from /markred
    if o.oUnk94 == 1 then return true end
    return false
end

local function apply_red_override()
    local tex = get_red_tex()
    if not tex then return end
    for _, name in ipairs(STAR_TEXTURE_NAMES) do
        pcall(texture_override_set, name, tex)
    end
end

local function clear_red_override()
    for _, name in ipairs(STAR_TEXTURE_NAMES) do
        pcall(texture_override_reset, name)
    end
end

local function star_color_init(o)
    if is_red_star(o) then
        o.oUnk94 = 1
    end
end

local function star_color_loop(o)
    local index = (o.oBehParams >> 24) & 0xFF
    if b3313_star_is_collected(index) then
        obj_set_model_extended(o, E_MODEL_TRANSPARENT_STAR)
        return
    end

    if is_red_star(o) then
        o.oUnk94 = 1
        redStarsPresent = true
        -- Keep solid star model (not transparent)
        if obj_has_model_extended and E_MODEL_STAR then
            if obj_has_model_extended(o, E_MODEL_TRANSPARENT_STAR) ~= 0 then
                obj_set_model_extended(o, E_MODEL_STAR)
            end
        end
        -- Slightly larger so red stars read clearly
        obj_scale(o, 1.15)
        -- Spin a bit faster
        o.oFaceAngleYaw = (o.oFaceAngleYaw + 0x400) % 0x10000
    end
end

-- Apply/clear texture override once per frame based on whether red stars exist
hook_event(HOOK_UPDATE, function()
    -- scan flag is set by star loops; apply override
    if redStarsPresent then
        apply_red_override()
    else
        clear_red_override()
    end
    redStarsPresent = false -- star loops set it true again next frame
end)

for _, id in ipairs({ id_bhvStar, id_bhvStarSpawnCoordinates, id_bhvSpawnedStar, id_bhvSpawnedStarNoLevelExit }) do
    hook_behavior(id, OBJ_LIST_LEVEL, false, star_color_init, star_color_loop)
end

hook_chat_command("markred", "- mark nearest star as red (host)", function()
    if not network_is_server() then
        djui_chat_message_create("Host only")
        return true
    end
    local m = gMarioStates[0]
    local best, bestDist = nil, 1e9
    for _, id in ipairs({ id_bhvStar, id_bhvStarSpawnCoordinates, id_bhvSpawnedStar, id_bhvSpawnedStarNoLevelExit }) do
        local s = obj_get_first_with_behavior_id(id)
        while s ~= nil do
            local d = dist_between_objects(s, m.marioObj)
            if d < bestDist then bestDist, best = d, s end
            s = obj_get_next_with_same_behavior_id(s)
        end
    end
    if best and bestDist < 1000 then
        local index = (best.oBehParams >> 24) & 0xFF
        RED_STAR_INDICES[index] = true
        best.oBehParams = (best.oBehParams & 0xFF00FFFF) | (1 << 16)
        best.oUnk94 = 1
        djui_chat_message_create("Marked star index \\#ff0000\\" .. tostring(index) .. "\\#ffffff\\ as red")
    else
        djui_chat_message_create("No star nearby")
    end
    return true
end)

hook_chat_command("redall", "- temporarily tint ALL stars red (test)", function()
    local tex = get_red_tex()
    if not tex then
        djui_chat_message_create("red_star texture missing")
        return true
    end
    for _, name in ipairs(STAR_TEXTURE_NAMES) do
        pcall(texture_override_set, name, tex)
    end
    djui_chat_message_create("\\#ff0000\\All stars forced red (texture override)")
    return true
end)
