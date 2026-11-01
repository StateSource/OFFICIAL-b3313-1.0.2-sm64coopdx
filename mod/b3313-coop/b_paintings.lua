-- B3313's paintings and fast travel.
--
-- Paintings. B3313 doesn't use SM64's painting warps (its level scripts have no painting
-- warp nodes). Each painting is an object (bhvB3313_1F00F800, model 186, top byte of
-- behParams = painting id, 2nd byte = warp node) whose model runs B3313 code (0x8056FBD0)
-- that draws the painting from a table of SM64 painting structs and does the warp check
-- itself (0x8056F820): when Mario is within the painting's width and height and just
-- behind its plane (B3313 leaves the wall behind a painting without collision), the object
-- grows a huge warp hitbox and the ordinary warp-object interaction takes him through the
-- painting's warp node. The port draws the paintings from models rebuilt out of the ROM
-- (one switch case per painting in the level's model 186, a4_paintings.lua) and does the
-- same check here.
--
-- Return to the painting. When Mario enters a painting, B3313 remembers it (0x807FFFD1/D2).
-- If he then dies, falls out, or collects a star that exits the course (0x807FFFD0), the
-- next warp goes back to the painting's level and area instead, and Mario is thrown out of
-- the painting (0x80249CE0 / 0x802DB230), as SM64's castle paintings do. Arriving in an
-- area with paintings forgets the painting again.
--
-- Fast travel. B3313's pause menu reads "PRESS [A] TO FAST TRAVEL": pressing it warps to
-- the beta lobbies in the castle grounds slot (play_mode_paused at 0x8024B644, 0x803711D8). Areas whose settings
-- object (bhvB3313_1F00706C) has flag 0x80 in its behParams disable it. In sm64coopdx A
-- already resumes the game from the pause menu, so the port uses Z.

local PAINTING_SIZE = 614.0

B3313.paint = {
    eject = false,      -- 0x8056FDF0: Mario arrived in this area; entering is blocked until
                        -- he leaves an intangible action (he may spawn inside a painting)
    ejectSound = false,
    retId = nil,        -- 0x807FFFD1: painting entered
    retLevel = nil,     -- 0x807FFFD2: its level and area
    retArea = nil,
    mode = 0,           -- 0x807FFFD0: 1 = died / fell out, 2 = collected a star
    modeTimer = 0,
    pending = nil,      -- painting to throw Mario out of after the return warp
    ftIndex = 0,        -- 0x807FFFEF: fast travel cycle
}
local PS = B3313.paint

local function painting_data(level, area, id)
    local l = B3313_PAINTINGS and B3313_PAINTINGS[level]
    local a = l and l[area]
    return a and a[id]
end

-- painting objects ---------------------------------------------------------------------

local function painting_init(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW
    o.oRoom = -1
    o.oInteractType = 0
    local np = gNetworkPlayers[0]
    local p = painting_data(np.currLevelNum, np.currAreaIndex, (o.oBehParams >> 24) & 0xFF)
    o.oAnimState = 0
    if p ~= nil then
        o.oPosX, o.oPosY, o.oPosZ = p[2], p[3], p[4]
        o.oHomeX, o.oHomeY, o.oHomeZ = p[2], p[3], p[4]
        local yaw = math.floor(p[5] * 65536 / 360 + 0.5)
        o.oFaceAngleYaw = yaw; o.oMoveAngleYaw = yaw
        o.oFaceAnglePitch = 0; o.oFaceAngleRoll = 0
        obj_scale(o, p[6] / PAINTING_SIZE)
        o.oAnimState = p[1]
    end
    -- first painting update in a new area (0x8056FC50)
    PS.eject = true
    PS.retId, PS.retLevel, PS.retArea = nil, nil, nil
    PS.mode = 0
end

local function painting_enter(o, m, id)
    local np = gNetworkPlayers[0]
    PS.retId, PS.retLevel, PS.retArea = id, np.currLevelNum, np.currAreaIndex
    -- the ordinary warp-object interaction (interact_warp), through node (2nd byte)
    m.interactObj = o
    m.usedObj = o
    play_sound(SOUND_MENU_ENTER_HOLE, m.marioObj.header.gfx.cameraToObject)
    queue_rumble_data_mario(m, 10, 80)
    mario_stop_riding_object(m)
    set_mario_action(m, ACT_DISAPPEARED, (WARP_OP_WARP_OBJECT << 16) + 2)
end

local function painting_loop(o)
    local m = gMarioStates[0]
    if m.marioObj == nil then return end
    local np = gNetworkPlayers[0]
    local id = (o.oBehParams >> 24) & 0xFF
    local p = painting_data(np.currLevelNum, np.currAreaIndex, id)
    if p == nil then return end
    if (m.action & ACT_FLAG_INTANGIBLE) == 0 then PS.eject = false end
    if m.action == ACT_DISAPPEARED then return end

    -- 0x8056F820: Mario's position in the painting's frame
    local th = math.rad(-p[5])
    local c, s = math.cos(th), math.sin(th)
    local dx, dy, dz = m.marioObj.oPosX - p[2], m.marioObj.oPosY - p[3], m.marioObj.oPosZ - p[4]
    local along = dz * s + dx * c          -- across the painting, 0..size
    local depth = dz * c - dx * s          -- in front (+) / behind (-) its plane
    local size = p[6]
    if along > 0 and along < size and depth > -150 and depth < 0 and dy > -100 and dy < size then
        if PS.eject then
            if not PS.ejectSound then
                play_sound(SOUND_GENERAL_PAINTING_EJECT, m.marioObj.header.gfx.cameraToObject)
                PS.ejectSound = true
            end
        else
            painting_enter(o, m, id)
        end
    elseif PS.ejectSound and depth >= 0 then
        PS.ejectSound = false
    end
end

bhvB3313_1F00F800 = hook_behavior(nil, OBJ_LIST_LEVEL, true, painting_init, painting_loop, "bhvB3313_1F00F800")

-- return to the painting ---------------------------------------------------------------

-- a star that exits the course (interact_star_or_key, 0x8024DCC0); called from a3_stars.lua
function b3313_painting_star_exit(o)
    if ((o.oBehParams >> 16) & 0xFF) ~= 0x0D then
        PS.mode = 2; PS.modeTimer = 0
    end
end

hook_event(HOOK_ON_DEATH, function(m)
    if m.playerIndex ~= 0 then return true end
    local ft = m.floor and m.floor.type
    local fall = (ft == SURFACE_DEATH_PLANE or ft == SURFACE_VERTICAL_WIND) and m.pos.y < m.floorHeight + 2048
    if fall and area_get_warp_node(0xF3) ~= nil then
        -- B3313 uses many falls as warps (warp node 0xF3). sm64coopdx would turn the fall
        -- into a bubble when other players are around; take the floor warp instead.
        if m.action ~= ACT_BUBBLED and level_trigger_warp(m, WARP_OP_WARP_FLOOR) == 20 then
            play_character_sound(m, CHAR_SOUND_WAAAOOOW)
        end
        return false
    end
    PS.mode = 1; PS.modeTimer = 0
    return true
end)

hook_event(HOOK_UPDATE, function()
    -- in co-op a death can end in a bubble instead of a warp; don't let it linger
    if PS.mode ~= 0 then
        PS.modeTimer = PS.modeTimer + 1
        if PS.modeTimer > 300 then PS.mode = 0 end
    end
end)

-- 0x8024B024: the delayed warp goes to the painting's level and area instead
hook_event(HOOK_BEFORE_WARP, function(destLevel, destArea, destWarpNode, arg)
    if PS.mode == 0 then return nil end
    local mode = PS.mode
    -- Softlock fix: if return painting data is invalid, abort override and allow normal warp
    if PS.retId == nil or PS.retLevel == nil or PS.retArea == nil then
        PS.mode = 0
        PS.pending = nil
        return nil
    end
    if painting_data(PS.retLevel, PS.retArea, PS.retId) == nil then
        PS.mode = 0
        PS.pending = nil
        return nil
    end
    PS.mode = 0
    PS.pending = { level = PS.retLevel, area = PS.retArea, id = PS.retId, mode = mode }
    -- destWarpNode 0 often softlocks when the area has no node 0; prefer 0x0A then 0x01
    local node = 0x0A
    return { destLevel = PS.retLevel, destArea = PS.retArea, destWarpNode = node }
end)

-- 0x80249CE0 + 0x802DB230: Mario comes out of the painting
hook_event(HOOK_ON_WARP, function()
    local pend = PS.pending
    PS.pending = nil
    if pend == nil then return end
    local np = gNetworkPlayers[0]
    if np.currLevelNum ~= pend.level or np.currAreaIndex ~= pend.area then return end
    local p = painting_data(pend.level, pend.area, pend.id)
    if p == nil then return end
    local m = gMarioStates[0]
    local th = math.rad(p[5])
    local c, s = math.cos(th), math.sin(th)
    local half = p[6] * 0.5
    local x = p[2] + c * half - s * 149.0
    local y = p[3] + half
    local z = p[4] - s * half - c * 149.0
    local yaw = (math.floor(p[5] * 182.04445) + 0x8000) & 0xFFFF
    if yaw >= 0x8000 then yaw = yaw - 0x10000 end
    m.pos.x, m.pos.y, m.pos.z = x, y, z
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    m.faceAngle.x, m.faceAngle.y, m.faceAngle.z = 0, yaw, 0
    local mo = m.marioObj
    if mo ~= nil then
        mo.oPosX, mo.oPosY, mo.oPosZ = x, y, z
        mo.header.gfx.pos.x, mo.header.gfx.pos.y, mo.header.gfx.pos.z = x, y, z
        mo.header.gfx.angle.y = yaw
    end
    set_mario_action(m, (pend.mode == 2) and ACT_EXIT_AIRBORNE or ACT_DEATH_EXIT, 0)
    if m.area ~= nil and m.area.camera ~= nil then reset_camera(m.area.camera) end
    PS.eject = true
end)

hook_event(HOOK_GET_STAR_COLLECTION_DIALOG, function()
    print("\\#ffff00\\Star collected!")
    return DIALOG_013
end)
-- fast travel ----------------------------------------------------------------------------

local function fast_travel_allowed()
    if bhvB3313_1F00706C == nil then return true end
    local o = obj_get_first_with_behavior_id(bhvB3313_1F00706C)
    while o ~= nil do
        if (o.oBehParams & 0x80) ~= 0 then return false end
        o = obj_get_next_with_same_behavior_id(o)
    end
    return true
end

-- Destinations, in order: Beta Lobby A (area 4), Beta Lobby B (3), Beta Lobby C/D (2) and
-- Beta Lobby E (8) of the castle grounds slot; the area you're in is skipped.
-- (B3313 itself cycles 2, 3, 4, picks 4 or 8 at random, and sends you to 4/8 only until
-- you have stars from its save courses 38-39; the port uses a fixed A, B, C/D, E order.)
local FAST_TRAVEL_ORDER = { 4, 3, 2, 8 }

function b3313_fast_travel()
    local np = gNetworkPlayers[0]
    local onGrounds = np.currLevelNum == LEVEL_CASTLE_GROUNDS
    local area
    for _ = 1, #FAST_TRAVEL_ORDER do
        PS.ftIndex = (PS.ftIndex % #FAST_TRAVEL_ORDER) + 1
        area = FAST_TRAVEL_ORDER[PS.ftIndex]
        if not (onGrounds and area == np.currAreaIndex) then break end
    end
    play_sound(SOUND_MENU_PAUSE_2, gGlobalSoundSource)
    if not warp_to_warpnode(LEVEL_CASTLE_GROUNDS, area, np.currActNum, 0x0A) then
        warp_to_level(LEVEL_CASTLE_GROUNDS, area, np.currActNum)
    end
end

hook_event(HOOK_UPDATE, function()
    if not is_game_paused() then return end
    local m = gMarioStates[0]
    if (m.controller.buttonPressed & B_BUTTON) ~= 0 and fast_travel_allowed() then
        b3313_fast_travel()
    end
end)

local currentFov = 130
local minFov = 30
local maxFov = 150
local fovStep = 5
hook_event(HOOK_UPDATE, function()
    local m = gMarioStates[0]
    if not m or not m.controller then return end
    local c = m.controller
    if (c.buttonPressed & L_JPAD) ~= 0 then
        currentFov = math.min(maxFov, currentFov + fovStep)
        set_override_fov(currentFov)
    elseif (c.buttonPressed & R_JPAD) ~= 0 then
        currentFov = math.max(minFov, currentFov - fovStep)
        set_override_fov(currentFov)
    end
end)

hook_event(HOOK_ON_HUD_RENDER, function()
if not is_game_paused() or not fast_travel_allowed() then return end
djui_hud_set_resolution(RESOLUTION_N64)
local t = (get_global_timer() * 8) % 504
local pulse = (t < 252) and t or (503 - t)
local scale = 0.5
local txt1 = " PRESS                  "
local txt2 = "         TO FAST TRAVEL "
local txtA = "     B                  "
local txt3 = "USE D-PAD TO CHANGE FOV "
local x = 30
local y = djui_hud_get_screen_height() - 60 - 16
djui_hud_set_font(FONT_NORMAL)
djui_hud_set_color(255, pulse, pulse, 255)
djui_hud_print_text(txt1, x, y, scale)
djui_hud_print_text(txt2, x + 8, y, scale)
djui_hud_print_text(txt3, x + 6, y + 16, scale)
djui_hud_set_font(FONT_SPECIAL)
djui_hud_set_color(255, pulse, pulse, 255)
djui_hud_print_text(txtA, x - 0.4, y, scale)
end)
-- for later: set_fov_function()