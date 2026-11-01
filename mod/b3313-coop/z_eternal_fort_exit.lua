-- After collecting a star in Eternal Fort / Eternal Fort (beta),
-- teleport the player to Beginnings (level 16, area 0).

local ETERNAL_FORT_LEVEL = 34
local ETERNAL_FORT_AREAS = {
    [1] = true, -- Eternal Fort
    [5] = true, -- Eternal Fort (beta)
}

local BEGINNINGS_LEVEL = 16
local BEGINNINGS_AREA = 0

local pendingWarp = false
local warpDelay = 0
local wasStarDancing = false

local function is_in_eternal_fort()
    local np = gNetworkPlayers[0]
    if not np then return false end
    if np.currLevelNum ~= ETERNAL_FORT_LEVEL then return false end
    return ETERNAL_FORT_AREAS[np.currAreaIndex] == true
end

local function do_warp_to_beginnings()
    pendingWarp = false
    warpDelay = 0
    wasStarDancing = false
    if PS then
        PS.mode = 0
        PS.pending = nil
        PS.eject = false
    end
    if warp_to_level then
        warp_to_level(BEGINNINGS_LEVEL, BEGINNINGS_AREA, 0)
        djui_chat_message_create("\\#00ff00\\Warping to Beginnings...")
    end
end

local STAR_DANCE = {
    [ACT_STAR_DANCE_EXIT] = true,
    [ACT_STAR_DANCE_NO_EXIT] = true,
    [ACT_STAR_DANCE_WATER] = true,
    [ACT_FALL_AFTER_STAR_GRAB] = true,
}

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m.playerIndex ~= 0 then return end

    local dancing = STAR_DANCE[m.action] == true

    -- Just started star dance while in Eternal Fort → schedule warp
    if dancing and not wasStarDancing and is_in_eternal_fort() then
        pendingWarp = true
        warpDelay = 100 -- a bit over 3 seconds
    end
    wasStarDancing = dancing

    if pendingWarp then
        warpDelay = warpDelay - 1
        if warpDelay <= 0 then
            do_warp_to_beginnings()
        end
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    pendingWarp = false
    warpDelay = 0
    wasStarDancing = false
end)

print("[B3313] Eternal Fort star -> Beginnings loaded")
