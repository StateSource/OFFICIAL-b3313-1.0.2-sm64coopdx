-- Hand-ported B3313 custom routines (from the ROM's MIPS code). Each function replaces the
-- matching stub in b_natives.lua. `o` is the object running the behavior (gCurrentObject).

local function on_any_platform(o) return b3313_mario_on_platform(o) end

-- 807F19F8: crumbling platform. Shakes while stood on, then slowly sinks (gravity -0.1)
-- after 16 frames and breaks into
-- particles + coins when it lands, resets when Mario is far away. (bhvB3313_130062A0/130064E4/130071A4/13007824/...)
function b3313_fn_807F19F8(o)
    if o.oDistanceToMario > 6500.0 then
        cur_obj_set_pos_to_home()
        cur_obj_hide()
        o.oGravity = 0.0
        o.oTimer = 0
        return
    end
    if o.oTimer ~= 0 and (o.oMoveFlags & 3) ~= 0 then
        if (o.header.gfx.node.flags & GRAPH_RENDER_INVISIBLE) ~= 0 then return end
        spawn_mist_particles_variable(0, 0, 150.0)
        spawn_triangle_break_particles(30, 138, 3.0, 4)
        obj_spawn_loot_yellow_coins(o, o.oNumLootCoins, 20.0)
        cur_obj_hide()
        create_sound_spawner(0x302E2081)
        return
    end
    if o.oGravity == 0.0 then
        if on_any_platform(o) then
            cur_obj_shake_y(4.0)
            if o.oTimer >= 16 then o.oGravity = -0.1 end
        else
            cur_obj_set_pos_to_home()
            o.oTimer = 0
        end
    else
        cur_obj_update_floor_and_walls()
        cur_obj_move_standard(78)
    end
    cur_obj_unhide()
    load_object_collision_model()
    o.oCollisionDistance = 32767.0
end

-- 80406CB8: flip panel. Rotates 180 degrees (roll) every time the local Mario leaves the
-- ground, solid only while not flipping. (bhvB3313_13006A24)
function b3313_fn_80406CB8(o)
    local state = o.oBehParams
    if state == 1 then
        local roll = o.oFaceAngleRoll + 0xE39
        if o.oTimer == 0 then roll = roll - 1 end
        o.oFaceAngleRoll = roll
        if o.oTimer == 9 then
            o.oFaceAngleRoll = roll & 0x8000
            o.oBehParams = 2
        end
        return
    end
    local m = gMarioStates[0]
    if (m.action & ACT_GROUP_MASK) ~= ACT_GROUP_AIRBORNE then
        o.oBehParams = 0
    elseif (m.prevAction & ACT_GROUP_MASK) ~= ACT_GROUP_AIRBORNE and state ~= 2 then
        o.oTimer = 0
        o.oBehParams = 1
    end
    load_object_collision_model()
end

-- 807F1B94 / 807F1C10: runaway star piece. Hops around its home and runs from Mario. In
-- the ROM it is collected like a star, but B3313's star-dance code recognises it
-- (behavior 1F0014A0) and, instead of saving a star, plays the key fanfare and adds one
-- to every piece counter (bhvB3313_1F0014D0) in the area, showing the count; the 5th piece
-- makes the counter spawn the real star. Here the touch is handled directly (no dance) so
-- the piece never registers as a real star. (bhvB3313_1F0014A0)
function b3313_fn_807F1B94(o)
    o.oFaceAngleYaw = 0
    o.oAction = 1
    o.oInteractionSubtype = o.oInteractionSubtype | 0x8400
    o.oBuoyancy = 1200.0
    b3313_set_hitbox(o, 0, 0, 0, 0, 0, 80, 50, 0, 0)
    o.oWallHitboxRadius = 80.0
end

local function collect_star_piece(o)
    play_music(1, 0xF17, 0)
    play_sound(0x701EFF81, gMarioStates[0].marioObj.header.gfx.cameraToObject)
    local c = obj_get_first_with_behavior_id(bhvB3313_1F0014D0)
    while c ~= nil do
        local n = c.oHiddenStarTriggerCounter + 1
        c.oHiddenStarTriggerCounter = n
        if n ~= 5 then spawn_orange_number(n, 0, 0, 0) end
        c = obj_get_next_with_same_behavior_id(c)
    end
    obj_mark_for_deletion(o)
end

function b3313_fn_807F1C10(o)
    o.oFaceAngleYaw = o.oFaceAngleYaw + 0x800
    if (o.oFaceAngleYaw & 0x800) ~= 0 then
        o.oAnimState = o.oAnimState + 1
    end
    if o.oAction == 1 then
        o.oGravity = -1.0
        cur_obj_update_floor_and_walls()
        cur_obj_if_hit_wall_bounce_away()
        cur_obj_move_standard(78)
        if (o.oMoveFlags & 0x13) ~= 0 then
            cur_obj_play_sound_2(0x30160081)
            o.oVelY = 20.0
            o.oForwardVel = 20.0
            local dz = o.oPosZ - o.oHomeZ
            local dx = o.oPosX - o.oHomeX
            if dz * dz + dx * dx > 6250000.0 then
                o.oMoveAngleYaw = cur_obj_angle_to_home()
            elseif (random_u16() & 3) ~= 0 and o.oDistanceToMario < 1000.0 then
                o.oMoveAngleYaw = o.oAngleToMario + 0x8000
            else
                o.oMoveAngleYaw = random_u16()
            end
            if (random_u16() & 1) ~= 0 then
                o.oMoveAngleYaw = o.oMoveAngleYaw + (random_u16() & 0x1FFF)
            else
                o.oMoveAngleYaw = o.oMoveAngleYaw - (random_u16() & 0x1FFF)
            end
        end
    end
    local mo = gMarioStates[0].marioObj
    if mo ~= nil and o.activeFlags ~= ACTIVE_FLAG_DEACTIVATED and obj_check_hitbox_overlap(o, mo) then
        collect_star_piece(o)
    end
    o.oInteractStatus = 0
end

-- 807F1E00 / 807F1E3C: star piece counter. Shows a star outline; when 5 pieces have been
-- collected it spawns the star (red-coin style cutscene). (bhvB3313_1F0014D0)
function b3313_fn_807F1E00(o)
    spawn_non_sync_object(id_bhvRedCoinStarMarker, E_MODEL_TRANSPARENT_STAR, o.oPosX, o.oPosY, o.oPosZ, function(c)
        obj_copy_angle(c, o)
    end)
    o.oHiddenStarTriggerCounter = 0
end

function b3313_fn_807F1E3C(o)
    if o.oAction == 0 then
        if o.oHiddenStarTriggerCounter == 5 then o.oAction = 1 end
    elseif o.oAction == 1 then
        if o.oTimer >= 3 then
            spawn_red_coin_cutscene_star(o.oPosX, o.oPosY, o.oPosZ)
            o.activeFlags = ACTIVE_FLAG_DEACTIVATED
        end
    end
end

-- 804073D4: music change once the player has (top byte) stars: plays sequence (2nd
-- byte) and removes itself. Usually revealed by a proximity activator. (bhvB3313_1300720C)
function b3313_fn_804073D4(o)
    local need = (o.oBehParams >> 24) & 0xFF
    local have = save_file_get_total_star_count(get_current_save_file_num() - 1, 0, 0x18)
    if have >= need then
        play_music(0, o.oBehParams2ndByte | 0x400, 0)
        obj_mark_for_deletion(o)
    end
end

-- 807E045C: star-count gate. Removes itself, and removes the nearest object with the
-- behavior in its params (low 24 bits) depending on the player's star count vs the
-- required count (top byte). Field 0x1B selects the direction. (bhvB3313_1F001970 / 1F00195C)
function b3313_fn_807E045C(o)
    local required = (o.oBehParams >> 24) & 0xFF
    local stars = gMarioStates[0].numStars
    local below = stars < required
    local invert = obj_get_field_s32(o, 0x1B) ~= 0
    o.activeFlags = 0
    if (invert and below) or ((not invert) and not below) then
        local bid = b3313_bhv_id(0x13000000 | (o.oBehParams & 0xFFFFFF))
        if bid ~= nil then
            local other = cur_obj_nearest_object_with_behavior(get_behavior_from_id(bid))
            if other ~= nil then other.activeFlags = 0 end
        end
    end
end

-- 805634E8 (+ 8056348C, 80563040, action table @80563640): hopping critter (Mips-like).
-- Hops away from Mario when he is within 750 units, wanders back home, can be picked up
-- and thrown. (bhvB3313_1F003000)
local function holder_obj(o)
    local i = o.heldByPlayerIndex
    if i ~= nil and i >= 0 and i < MAX_PLAYERS and gMarioStates[i].marioObj ~= nil then
        return gMarioStates[i].marioObj
    end
    return gMarioStates[0].marioObj
end

local function critter_hop_if_frame(o)
    if o.oForwardVel > 0.0 then o.oForwardVel = 0.0 end
    if cur_obj_check_anim_frame(25) ~= 0 then
        cur_obj_play_sound_2(0x305E0081)
        o.oVelY = random_float() * 5.0 + 30.0
        o.oForwardVel = random_float() * 10.0 + 22.5
    end
end

local critter_actions = {
    [0] = function(o)
        o.oAngleToMario = obj_angle_to_object(o, gMarioStates[0].marioObj)
        b3313_animate(o, 0)
        local onGround = (o.oMoveFlags & 2) ~= 0
        if not onGround and o.oDistanceToMario <= 750.0 then
            cur_obj_rotate_yaw_toward(b3313_s16(o.oAngleToMario + 0x8000), 0x300)
            onGround = (o.oMoveFlags & 2) ~= 0
        end
        if not onGround then return end
        if o.oDistanceToMario > 750.0 then
            if cur_obj_check_if_near_animation_end() ~= 0 or o.header.gfx.animInfo.animFrame < 3 then
                o.oAction = 2
            end
        end
        critter_hop_if_frame(o)
    end,
    [1] = function(o)
        if (o.oMoveFlags & 0x279) ~= 0 then o.oAction = 0 end
    end,
    [2] = function(o)
        b3313_animate(o, 0)
        o.header.gfx.animInfo.animFrame = 0
        if o.oForwardVel > 0.0 then o.oForwardVel = 0.0 end
        if o.oTimer >= 151 then o.oAction = 3 end
        if o.oDistanceToMario <= 750.0 then o.oAction = 0 end
    end,
    [3] = function(o)
        o.oAngleToHome = cur_obj_angle_to_home()
        b3313_animate(o, 0)
        local onGround = (o.oMoveFlags & 2) ~= 0
        if not onGround then
            cur_obj_rotate_yaw_toward(b3313_s16(o.oAngleToHome), 0x400)
            onGround = (o.oMoveFlags & 2) ~= 0
        end
        if onGround then
            critter_hop_if_frame(o)
            local dx, dz = o.oHomeX - o.oPosX, o.oHomeZ - o.oPosZ
            if math.sqrt(dx * dx + dz * dz) < 500.0 then o.oAction = 2 end
        end
        if o.oDistanceToMario <= 500.0 then o.oAction = 0 end
    end,
}

function b3313_fn_805634E8(o)
    local held = o.oHeldState
    if held == HELD_FREE then
        cur_obj_enable_rendering_and_become_tangible(o)
        cur_obj_scale(0.4)
        b3313_set_hitbox(o, INTERACT_GRABBABLE, 20, 0, 1, 5, 300, 500, 300, 500)
        cur_obj_update_floor_and_walls()
        cur_obj_move_standard(30)
        local act = critter_actions[o.oAction]
        if act ~= nil then act(o) end
    elseif held == HELD_HELD then
        obj_copy_pos(o, holder_obj(o))
        cur_obj_become_intangible()
        cur_obj_disable_rendering()
        b3313_animate(o, 0)
        o.oAction = 0
    elseif held == HELD_THROWN then
        cur_obj_get_thrown_or_placed(40.0, 20.0, 0)
    elseif held == HELD_DROPPED then
        cur_obj_get_dropped()
        o.oAction = 0
    end
    if (o.oInteractStatus & INT_STATUS_STOP_RIDING) ~= 0 then
        cur_obj_get_thrown_or_placed(40.0, 20.0, 0)
        cur_obj_get_dropped()
        o.oFaceAngleYaw = gMarioStates[0].faceAngle.y
        o.oAction = 0
    end
    o.oInteractStatus = 0
end

-- 804108E4 (+ 804107AC, 80410648, actions 80410238..80410748, 804100B0): grabbing enemy
-- (Chuckya / King Bob-omb style) on model 119. Walks at Mario, grabs him, runs up to
-- 46 frames or to a ledge, then throws him. Mario can pick it up and throw it; it
-- dies in lava/quicksand and drops a blue coin. behParams 2nd byte 1 = boss version:
-- bigger, wakes up when Mario stands level with it (boss music), spits fire, gives a
-- star when it dies. (bhvB3313_00410000)
local function grabber_reached_end(o)
    return o.oTimer >= 46 or (o.oMoveFlags & OBJ_MOVE_HIT_EDGE) ~= 0
end

local grabber_actions = {
    [0] = function(o, boss)   -- idle until Mario comes close
        o.oForwardVel = 0.0
        o.oVelY = 0.0
        b3313_animate(o, 8)
        if boss then
            if o.oDistanceToMario >= 1500.0 then return end
            local awake = (o.oBehParams & 0xFF) ~= 0
            if gMarioStates[0].pos.y ~= o.oPosY and not awake then return end
            o.oAction = 1
            o.oTimer = 0
            if not awake then
                play_music(0, 0x416, 0)
                o.oBehParams = o.oBehParams | 1
            end
        elseif o.oDistanceToMario < 500.0 then
            o.oAction = 1
            o.oTimer = 0
        end
    end,
    [1] = function(o, boss)   -- walk towards Mario
        b3313_animate(o, 9)
        o.oForwardVel = boss and 3.0 or 5.0
        cur_obj_rotate_yaw_toward(b3313_s16(o.oAngleToMario), boss and 0x2BC or 0x1F4)
        if boss and o.oDistanceToMario > 400.0 and o.oTimer >= 41 and (random_u16() & 0xF) == 0 then
            o.oTimer = 0
            o.oAction = 8
        end
        if (o.oInteractStatus & INT_STATUS_GRABBED_MARIO) ~= 0 then
            o.oAction = 2
            o.oChuckyaUnk88 = 1
        end
    end,
    [2] = function(o)         -- grab animation
        b3313_animate(o, 3)
        if cur_obj_check_if_near_animation_end() ~= 0 then
            o.oAction = grabber_reached_end(o) and 3 or 4
        end
    end,
    [3] = function(o)         -- throw Mario
        o.oForwardVel = 0.0
        b3313_animate(o, 6)
        if cur_obj_check_anim_frame(14) ~= 0 then
            o.oChuckyaUnk88 = 2
            o.numCollidedObjs = 10
        end
        if cur_obj_check_if_near_animation_end() ~= 0 then
            o.oAction = 0
            o.oInteractStatus = o.oInteractStatus & ~INT_STATUS_GRABBED_MARIO
        end
    end,
    [4] = function(o)         -- run while carrying Mario
        o.oForwardVel = 15.0
        b3313_animate(o, 2)
        if grabber_reached_end(o) then o.oAction = 3 end
    end,
    [5] = function(o)         -- thrown by Mario, in the air
        b3313_animate(o, 9)
        if (o.oMoveFlags & OBJ_MOVE_LANDED) ~= 0 then
            o.oAction = 6
            cur_obj_play_sound_2(0x90570081)
        end
    end,
    [6] = function(o)         -- landed: dazed, then gets up
        o.oForwardVel = 0.0
        if o.oSubAction == 0 then
            b3313_animate(o, 5)
            cur_obj_extend_animation_if_at_end()
            if o.oTimer >= 36 then o.oSubAction = o.oSubAction + 1 end
        else
            b3313_animate(o, 4)
            if cur_obj_check_if_near_animation_end() ~= 0 then o.oAction = 0 end
        end
    end,
    [8] = function(o)         -- boss: spit fire (the anchor child spawns the flame)
        o.oForwardVel = 0.0
        b3313_animate(o, 6)
        if cur_obj_check_anim_frame(14) ~= 0 then o.oChuckyaUnk88 = 4 end
        if cur_obj_check_if_near_animation_end() ~= 0 then
            o.oAction = 0
            o.oTimer = 0
        end
    end,
}

local function grabber_free(o, boss)
    cur_obj_update_floor_and_walls()
    local act = grabber_actions[o.oAction]
    if act ~= nil then act(o, boss) end
    cur_obj_move_standard(-78)
    local h, floor = find_floor(o.oPosX, o.oPosY, o.oPosZ)
    if floor ~= nil and o.oPosY < h + 1.0 and (floor.type == SURFACE_BURNING or floor.type == SURFACE_INSTANT_QUICKSAND) then
        o.oAction = 7
    end
end

local function grabber_lava_death(o, boss)
    if obj_lava_death() == 0 then return end
    if boss then
        spawn_default_star(130.0, 1600.0, -4320.0)
        return
    end
    local yaw = o.oFaceAngleYaw + 0x8000
    local posY = o.oPosY + 310.0
    local coin = spawn_non_sync_object(bhvB3313_80410050, b3313_model(0x76), o.oPosX, o.oPosY, o.oPosZ, function(c)
        obj_copy_angle(c, o)
    end)
    cur_obj_play_sound_2(0x38300081)
    if coin ~= nil then
        coin.oForwardVel = 10.0
        coin.oVelY = 100.0
        coin.oPosY = posY
        coin.oMoveAngleYaw = math.floor(random_float() * 1024.0 + yaw)
    end
end

function b3313_fn_804108E4(o)
    local boss = o.oBehParams2ndByte == 1
    cur_obj_scale(boss and 3.0 or 2.0)
    o.oInteractionSubtype = o.oInteractionSubtype | INT_SUBTYPE_GRABS_MARIO
    local held = o.oHeldState
    if held == HELD_FREE then
        if o.oAction == 7 then grabber_lava_death(o, boss) else grabber_free(o, boss) end
    elseif held == HELD_HELD then
        cur_obj_become_intangible()
        cur_obj_disable_rendering()
        b3313_animate(o, 9)
        o.oAction = 0
    elseif held == HELD_THROWN or held == HELD_DROPPED then
        cur_obj_get_thrown_or_placed(15.0, 35.0, 5)
    end
    o.oInteractStatus = 0
    set_object_visibility(o, boss and 8000 or 3000)
end

-- 804100E0: the grabber's "anchor" child (sits in its hand via geo_update_held_mario_pos).
-- Vanilla anchor logic carries/throws Mario; B3313 adds: snap Mario's real position to
-- the hand while held, the boss's fire spit, and no fall damage right after a boss throw.
function b3313_fn_804100E0(o)
    local p = o.parentObj
    if p == nil then return end
    local boss = p.oBehParams2ndByte == 1
    o.oParentRelativePosY = -30.0
    o.oParentRelativePosX = -70.0
    common_anchor_mario_behavior(50.0, boss and -75.0 or 30.0, 0x40)
    local m = gMarioStates[0]
    local state = p.oChuckyaUnk88
    if state == 1 then
        if m.heldByObj == p then vec3f_copy(m.pos, m.marioObj.header.gfx.pos) end
        o.oTimer = 0
        return
    end
    if not boss then return end
    if state == 4 then
        cur_obj_play_sound_2(0x50558081)
        obj_spit_fire(0, 0, 0, 5.0, 203, 30.0, 25.0, 0x1000)
        p.oChuckyaUnk88 = 0
    end
    if o.oTimer < 10 and (m.heldByObj == p or m.usedObj == p) then
        m.peakHeight = m.pos.y + 3000.0
    end
end

-- 805627AC / 805627C8: Blargg (lava monster, vanilla Blargg animations). Turns toward
-- Mario when he's within 1750, opens up when within 1250 and after 45 frames breathes
-- a spray of flames (bhvB3313_0056265C). Killed by an explosion (thrown Bob-omb).
-- behParams top byte set = aims 250 units in front (+Z) of Mario. (bhvB3313_1F002600)
function b3313_fn_805627AC(o)
    obj_set_field_s32(o, 0x1B, o.oFaceAngleYaw)   -- home yaw
    o.header.gfx.animInfo.animFrame = 0x1D
end

local function blargg_hit_by_explosion(o)
    for i = 0, o.numCollidedObjs - 1 do
        local c = obj_get_collided_object(o, i)
        if c ~= nil and obj_has_behavior_id(c, id_bhvExplosion) ~= 0 then return true end
    end
    return false
end

function b3313_fn_805627C8(o)
    local act = o.oAction
    if act == 5 then      -- emerging
        if cur_obj_check_if_near_animation_end() ~= 0 then
            o.oAction = 0
            b3313_animate(o, 0)
        end
        return
    end
    if act == 4 then      -- dying
        if o.header.gfx.animInfo.animFrame >= 29 then o.activeFlags = ACTIVE_FLAG_DEACTIVATED end
        return
    end
    if blargg_hit_by_explosion(o) then
        o.oAction = 4
        cur_obj_play_sound_2(0x9204C081)
        b3313_animate(o, 1)
        o.header.gfx.animInfo.animFrame = 0
        o.oIntangibleTimer = -1
        return
    end
    if act == 0 then
        if o.oDistanceToMario <= 1750.0 then
            o.oAction = 1
        else
            o.oFaceAngleYaw = approach_s16_symmetric(o.oFaceAngleYaw, obj_get_field_s32(o, 0x1B), 0x200)
        end
        return
    end
    local target = o.oAngleToMario
    if ((o.oBehParams >> 24) & 0xFF) ~= 0 then
        local m = nearest_mario_state_to_object(o) or gMarioStates[0]
        target = atan2s((m.pos.z + 250.0) - o.oPosZ, m.pos.x - o.oPosX)
    end
    o.oFaceAngleYaw = approach_s16_symmetric(o.oFaceAngleYaw, target, 0x400)
    if act ~= 3 then
        if o.oDistanceToMario > 1750.0 then
            o.oAction = 0
        elseif o.oDistanceToMario > 1250.0 then
            o.oAction = 1
        else
            o.oAction = 2
            if act == 2 and o.oTimer >= 45 then
                o.oAction = 3
                b3313_animate(o, 1)
            end
        end
        return
    end
    -- act 3: breathing fire
    if cur_obj_check_if_near_animation_end() ~= 0 then
        o.oAction = 1
        b3313_animate(o, 0)
        return
    end
    local f = o.header.gfx.animInfo.animFrame
    if f >= 10 and f < 19 then
        cur_obj_play_sound_2(0x60000001)   -- SOUND_AIR_BOWSER_SPIT_FIRE
        if (f & 1) == 0 then
            local power = (f - 10) >> 1
            spawn_non_sync_object(bhvB3313_0056265C, b3313_model(0x90), o.oPosX, o.oPosY, o.oPosZ, function(c)
                obj_copy_angle(c, o)
                c.oBehParams = power << 24
            end)
        end
    end
end

-- 0056265C (+ 80562A00, 80562780, 80562A44, 80562A70): Blargg's flame. Flies out in an
-- arc (speed from behParams top byte), stops on the ground, then shrinks away. The ROM
-- script runs its movement step twice per frame (DELAY(1) inside a REPEAT), kept here.
local function blargg_flame_step(o)
    cur_obj_update_floor()
    cur_obj_move_standard(0)
    cur_obj_resolve_wall_collisions()
    if (o.oMoveFlags & 3) ~= 0 then
        o.oForwardVel = 0.0
        o.oVelX = 0.0
        o.oVelZ = 0.0
    end
    o.oMoveFlags = 0
    o.oInteractStatus = 0
end

local function blargg_flame_shrink(o)
    local s = o.header.gfx.scale.x - 0.35
    o.header.gfx.scale.x = s
    o.header.gfx.scale.y = s
    o.hitboxRadius = o.hitboxRadius - 1.25
    o.hitboxHeight = o.hitboxHeight - 2.5
    o.oInteractStatus = 0
end

local function blargg_flame_init(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.oDrawingDistance = 15000.0
    obj_set_billboard(o)
    obj_scale(o, 7.0)
    o.oInteractType = INTERACT_FLAME
    o.hitboxRadius = 25.0
    o.hitboxHeight = 50.0
    o.hitboxDownOffset = 25.0
    o.oIntangibleTimer = 0
    o.oWallHitboxRadius = 25.0
    o.oGravity = -2.0
    o.oBounciness = 0.0
    o.oDragStrength = 0.0
    o.oFriction = 0.0
    o.oBuoyancy = 0.0
    o.oPosY = o.oPosY + 175.0
    local spread = -1024 + (random_u16() >> 5)
    obj_set_field_s32(o, 0x1B, spread)
    o.oMoveAngleYaw = o.oFaceAngleYaw + spread
    local power = (o.oBehParams >> 24) & 0xFF
    o.oVelY = power * 2.5 + 30.0
    o.oForwardVel = power * 2.5 + 20.0
    cur_obj_compute_vel_xz()
    o.oMoveFlags = 0
    o.oB3313Delay = 0
end

local function blargg_flame_loop(o)
    local n = o.oB3313Delay
    o.oB3313Delay = n + 1
    if n == 0 then
        blargg_flame_step(o)
    elseif n < 100 then
        blargg_flame_step(o); blargg_flame_step(o)
        o.oAnimState = o.oAnimState + 1
    elseif n == 100 then
        blargg_flame_step(o)
        o.oAnimState = o.oAnimState + 1
        blargg_flame_shrink(o)
    elseif n < 110 then
        blargg_flame_shrink(o); blargg_flame_shrink(o)
        o.oAnimState = o.oAnimState + 1
    else
        blargg_flame_shrink(o)
        o.oAnimState = o.oAnimState + 1
        obj_mark_for_deletion(o)
    end
end

bhvB3313_0056265C = hook_behavior(nil, OBJ_LIST_LEVEL, true, blargg_flame_init, blargg_flame_loop, "bhvB3313_0056265C")

-- 80405248 / 80405250 (code at 80405E1C / 80405E64): proximity activator. Targets the
-- object placed N entries before it (behParams byte 3 = N; the ROM reaches it N slots
-- further on in the object pool). Byte 4 = 0: the target is frozen and hidden until
-- Mario comes within `radius` (behParams >> 16) of it, then restarts from the top of its
-- behavior. Byte 4 != 0: the target vanishes once Mario gets that close.
-- Here "frozen" = removed and spawned fresh later. (bhvB3313_004052F4)
B3313.activators = {}
local sActivatorNext = 0

local function placed_bhv_id(name)
    return _G["id_" .. name] or _G[name]
end

local function find_placed_object(bid, x, y, z)
    if bid == nil then return nil end
    local best, bestD = nil, 64.0
    local c = obj_get_first_with_behavior_id(bid)
    while c ~= nil do
        local dx, dz = c.oPosX - x, c.oPosZ - z
        local d = math.sqrt(dx * dx + dz * dz)
        if d <= bestD and math.abs(c.oPosY - y) < 2000.0 then best, bestD = c, d end
        c = obj_get_next_with_same_behavior_id(c)
    end
    return best
end

local function placed_angle(deg)
    return b3313_s16(math.floor(deg * 0x8000 / 180))
end

function b3313_fn_80405248(o)
    o.oB3313Ref = 0
    local list = B3313_ACTIVATORS[b3313_level()]
    if list == nil then return end
    local bp = o.oBehParams & 0xFFFFFFFF
    local pick = nil
    for _, e in ipairs(list) do
        if e[4] == bp and math.abs(e[1] - o.oPosX) < 1 and math.abs(e[2] - o.oPosY) < 1 and math.abs(e[3] - o.oPosZ) < 1 then
            local bid = placed_bhv_id(e[5])
            local t = find_placed_object(bid, e[6], e[7], e[8])
            if t ~= nil or pick == nil then pick = { spec = e, bid = bid, target = t } end
            if t ~= nil then break end
        end
    end
    if pick == nil or pick.bid == nil then return end
    local e = pick.spec
    pick.model = pick.target and obj_get_model_id_extended(pick.target) or b3313_model(e[10])
    if (e[4] & 0xFF) == 0 and pick.target ~= nil then
        obj_mark_for_deletion(pick.target)
        pick.target = nil
    end
    sActivatorNext = sActivatorNext + 1
    B3313.activators[sActivatorNext] = pick
    o.oB3313Ref = sActivatorNext
end

function b3313_fn_80405250(o)
    local st = B3313.activators[o.oB3313Ref]
    if st == nil then return end
    local e = st.spec
    local x, y, z = e[6], e[7], e[8]
    local t = st.target
    if t ~= nil and (t.activeFlags == ACTIVE_FLAG_DEACTIVATED or get_id_from_behavior(t.behavior) ~= st.bid) then
        st.target = nil; t = nil
    end
    if t ~= nil then x, y, z = t.oPosX, t.oPosY, t.oPosZ end
    local mo = gMarioStates[0].marioObj
    if mo == nil then return end
    local dx, dy, dz = mo.oPosX - x, mo.oPosY - y, mo.oPosZ - z
    if math.sqrt(dx * dx + dy * dy + dz * dz) > ((e[4] >> 16) & 0xFFFF) then return end
    if (e[4] & 0xFF) == 0 then
        spawn_non_sync_object(st.bid, st.model, e[6], e[7], e[8], function(c)
            c.oBehParams = e[9]
            c.oBehParams2ndByte = (e[9] >> 16) & 0xFF
            c.oFaceAnglePitch = placed_angle(e[11]); c.oMoveAnglePitch = c.oFaceAnglePitch
            c.oFaceAngleYaw = placed_angle(e[12]);   c.oMoveAngleYaw = c.oFaceAngleYaw
            c.oFaceAngleRoll = placed_angle(e[13]);  c.oMoveAngleRoll = c.oFaceAngleRoll
        end)
    elseif t ~= nil then
        obj_mark_for_deletion(t)
    end
    B3313.activators[o.oB3313Ref] = nil
    o.activeFlags = ACTIVE_FLAG_DEACTIVATED
end

-- 804066DC: same flip panel as 80406CB8, different model/collision. (bhvB3313_1300638C)
function b3313_fn_804066DC(o) b3313_fn_80406CB8(o) end

-- 804060E0: moving platform setup: speed = behParams 2nd byte, moves sideways (yaw+90).
-- (bhvB3313_13005D78, bhvB3313_13005E44)
function b3313_fn_804060E0(o)
    o.oForwardVel = o.oBehParams2ndByte
    o.oMoveAngleYaw = o.oFaceAngleYaw + 0x4000
end

-- 80406214 / 80406C84: yaw spin speed from behParams low 24 bits, negated if the top byte
-- is set. (bhvB3313_13005E44, bhvB3313_130069C8)
local function spin_from_params(o)
    local bp = o.oBehParams & 0xFFFFFFFF
    local v = bp & 0xFFFFFF
    if bp - v ~= 0 then v = -v end
    o.oAngleVelYaw = v
end
function b3313_fn_80406214(o) spin_from_params(o) end
function b3313_fn_80406C84(o) spin_from_params(o) end

-- 807F8200 (+ 807F7800): texture corruption. While Mario is within (2nd byte + 1) * 256
-- units, every 6th call (counter shared by all of these objects) the ROM rewrites every
-- texture pointer in the level's display lists to point 64KB further into raw RAM, so the
-- level's textures turn into scrolling memory garbage until the level is reloaded.
-- Here: the current area's textures are overridden with pages of an approximate N64 RAM
-- image (textures/b3313_garbage_XX.tex), stepping one page per tick. (bhvB3313_007F8130)
B3313.corrupt = nil
local sCorruptCounter = 0
local sGarbage = {}

local function garbage_tex(j)
    local t = sGarbage[j]
    if t == nil then
        t = get_texture_info(string.format("b3313_garbage_%02d", j))
        sGarbage[j] = t
    end
    return t
end

local function corrupt_apply(area)
    local c = B3313.corrupt
    local lvlTex = B3313_LEVEL_TEXTURES[c.level]
    local list = lvlTex and lvlTex[area]
    c.applied[area] = c.step
    if list == nil then return end
    for i, name in ipairs(list) do
        local g = garbage_tex((c.step + i * 5) % 64)
        if g ~= nil then
            texture_override_set(name, g)
            c.names[name] = true
        end
    end
end

local function corrupt_tick()
    local lvl = b3313_level()
    local c = B3313.corrupt
    if c == nil or c.level ~= lvl then
        c = { level = lvl, step = 0, applied = {}, names = {} }
        B3313.corrupt = c
    end
    c.step = c.step + 1
    corrupt_apply(gNetworkPlayers[0].currAreaIndex)
end

local function corrupt_reset()
    local c = B3313.corrupt
    if c == nil then return end
    for name, _ in pairs(c.names) do texture_override_reset(name) end
    B3313.corrupt = nil
end

-- level data is re-read from ROM on a level load, which undoes the corruption; moving to
-- another area of the same level keeps it (that area's display lists were corrupted too)
hook_event(HOOK_ON_LEVEL_INIT, corrupt_reset)
hook_event(HOOK_UPDATE, function()
    local c = B3313.corrupt
    if c == nil then return end
    if c.level ~= b3313_level() then corrupt_reset(); return end
    local area = gNetworkPlayers[0].currAreaIndex
    if c.applied[area] ~= c.step then corrupt_apply(area) end
end)

function b3313_fn_807F8200(o)
    if o.oAction ~= 0 then
        if o.oTimer == 0x100 then o.oTimer = 0 end
        sCorruptCounter = sCorruptCounter + 1
        if sCorruptCounter >= 6 then
            sCorruptCounter = 0
            -- the ROM branches on a register random_u16() happens to leave behind,
            -- which is nonzero about 255 times in 256
            if (random_u16() & 0xFF00) ~= 0 then corrupt_tick() end
        end
    end
    local r = (o.oBehParams2ndByte + 1) * 256
    o.oAction = (o.oDistanceToMario < r) and 1 or 0
end

-- 807F15E0: ambient sound emitter; behParams is the sound. Quiet while the camera is in
-- behind-Mario mode (mode 3). (bhvB3313_1F001400)
function b3313_fn_807F15E0(o)
    local area = gMarioStates[0].area
    local cam = area and area.camera
    if cam ~= nil and cam.mode == 3 then return end
    cur_obj_play_sound_1(o.oBehParams)
end

-- 807F1620: constant earthquake: screen shake strength 1/2/3 from behParams 2nd byte
-- 0/1/2. (If the low byte is set the ROM also glues it to the next object in the pool;
-- no placement in the ROM uses that.) (bhvB3313_1F001414)
function b3313_fn_807F1620(o)
    local b = o.oBehParams2ndByte
    if b == 0 then cur_obj_shake_screen(1)
    elseif b == 1 then cur_obj_shake_screen(2)
    elseif b == 2 then cur_obj_shake_screen(3) end
end

-- 807F1774: back-and-forth mover. Velocity (oUnkBC, oUnkC0, oForwardVel) as x/y/z, reversed
-- every (field 0x04 & 0xFFF) frames; bit 0x1000 adds a thud + screen shake on every other
-- reversal. (bhvB3313_13005EC4, bhvB3313_13005EF8, bhvB3313_13006658)
function b3313_fn_807F1774(o)
    local f = o.oB3313F04
    local period = f & 0xFFF
    if period ~= 0 and o.oTimer >= period then
        o.oTimer = 0
        o.oUnkBC = -o.oUnkBC
        o.oUnkC0 = -o.oUnkC0
        o.oForwardVel = -o.oForwardVel
        if (f & 0x1000) ~= 0 then
            o.oB3313F04 = f ~ 0x2000
            if (o.oB3313F04 & 0x2000) ~= 0 then
                cur_obj_shake_screen(1)
                cur_obj_play_sound_2(0x30468081)
            end
        end
    end
    o.oVelX = o.oUnkBC
    o.oVelY = o.oUnkC0
    o.oVelZ = o.oForwardVel
    o.oPosX = o.oPosX + o.oVelX
    o.oPosY = o.oPosY + o.oVelY
    o.oPosZ = o.oPosZ + o.oVelZ
end

-- 807F189C: text trigger. Shows dialog (behParams 2nd byte) when Mario is within
-- (top byte * 10) units. Byte 3 flags: 1 = skip if a collected (transparent) star exists
-- in the level, 2 = yes/no question that saves the game on "yes", 4 = show immediately
-- (automatic dialog) instead of an NPC-style talk. (bhvB3313_1F001444)
local function transparent_star_exists()
    for list = 0, NUM_OBJ_LISTS - 1 do
        local c = obj_get_first(list)
        while c ~= nil do
            if obj_has_model_extended(c, E_MODEL_TRANSPARENT_STAR) ~= 0 then return true end
            c = obj_get_next(c)
        end
    end
    return false
end

function b3313_fn_807F189C(o)
    local m = gMarioStates[0]
    local bp = o.oBehParams
    local dialog = o.oBehParams2ndByte
    local radius = ((bp >> 24) & 0xFF) * 10
    if radius >= 1280 then radius = radius - 2560 end   -- signed top byte
    local flags = (bp >> 8) & 0xFF
    if o.oAction == 1 then      -- yes/no question open
        if get_dialog_id() == -1 then
            if get_dialog_response() == 1 then
                save_file_do_save(get_current_save_file_num() - 1, 1)
            end
            if m.action == ACT_WAITING_FOR_DIALOG then set_mario_action(m, ACT_IDLE, 0) end
            disable_time_stop()
            o.activeFlags = o.activeFlags & ~ACTIVE_FLAG_ACTIVE
        end
        return
    end
    if (flags & 1) ~= 0 and transparent_star_exists() then
        o.activeFlags = o.activeFlags & ~ACTIVE_FLAG_ACTIVE
        return
    end
    if o.oDistanceToMario >= radius then return end
    if (flags & 4) ~= 0 then
        set_mario_action(m, ACT_READING_AUTOMATIC_DIALOG, dialog)
        o.activeFlags = o.activeFlags & ~ACTIVE_FLAG_ACTIVE
        return
    end
    if mario_ready_to_speak(m) == 0 then return end
    if (flags & 2) ~= 0 then
        set_mario_action(m, ACT_WAITING_FOR_DIALOG, 0)
        enable_time_stop()
        create_dialog_box_with_response(dialog)
        o.oAction = 1
    else
        set_mario_action(m, ACT_READING_AUTOMATIC_DIALOG, dialog)
        o.activeFlags = o.activeFlags & ~ACTIVE_FLAG_ACTIVE
    end
end

-- 80560514: camera controller. Always centres the radial camera on itself. Top byte 1:
-- default camera mode radial (focus z < 5120) or close-up otherwise. Top byte 2: inside
-- |x| < 1672 and z >= -480, switches a free-roam camera to a fixed camera at its position.
-- (bhvB3313_1F000500)
function b3313_fn_80560514(o)
    local area = gMarioStates[0].area
    local c = area and area.camera
    if c == nil then return end
    local kind = (o.oBehParams >> 24) & 0xFF
    c.areaCenX = o.oPosX
    c.areaCenZ = o.oPosZ
    if kind == 1 then
        gLakituState.defMode = (c.focus.z < 5120.0) and CAMERA_MODE_RADIAL or CAMERA_MODE_CLOSE
    elseif kind == 2 then
        local m = gMarioStates[0]
        if math.abs(m.pos.x) < 1672.0 and not (m.pos.z < -480.0) and gLakituState.mode == CAMERA_MODE_FREE_ROAM then
            set_camera_mode_fixed(c, math.floor(o.oPosX), math.floor(o.oPosY), math.floor(o.oPosZ))
        end
    end
end

-- 807F31F0: on-screen message (HUD font) while Mario is within (top byte * 10) units.
-- 2nd byte picks the text, flag 0x100 = lower on screen, 0x200 = flickering.
-- (bhvB3313_1F001660)
local B3313_SCREEN_TEXT = {
    [0] = "YOU ARE NOT WORTHY", "YOU ARE WORTHY", "GET ME OUT", "TURN IT OFF", "IT HURTS",
    "GET OUT", "FIND THE CORE", "DESTROY IT", "ENHANCER OFFLINE", "ENHANCER LIVE",
}
function b3313_fn_807F31F0(o)
    local bp = o.oBehParams
    if (bp & 0x200) ~= 0 and (random_u16() & 1) ~= 0 then return end
    local radius = ((bp >> 24) & 0xFF) * 10.0
    if radius < o.oDistanceToMario then return end
    local text = B3313_SCREEN_TEXT[(bp >> 16) & 0xFF]
    if text == nil then return end
    -- print_text_centered(160, y, text): queued here, drawn by the HUD hook below
    B3313.screenText[#B3313.screenText + 1] = { text = text, y = ((bp & 0x100) ~= 0) and 120 or 40 }
end

B3313.screenText = {}
hook_event(HOOK_ON_HUD_RENDER, function()
    local list = B3313.screenText
    if #list == 0 then return end
    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_HUD)
    djui_hud_set_color(255, 255, 255, 255)
    for _, t in ipairs(list) do
        local w = djui_hud_measure_text(t.text)
        -- N64 print_text y counts up from the bottom of the 240-line screen
        djui_hud_print_text(t.text, 160 - w * 0.5, 240 - t.y - 16, 1)
    end
    B3313.screenText = {}
end)

-- B3313's own save flags (the u16 at 0x807F1194, written by its custom save code): bits
-- 0-7 are the boo keys. Kept per save file in mod storage.
local function b3313_flags_key() return "flags_" .. get_current_save_file_num() end
function b3313_flags_get()
    local file = get_current_save_file_num()
    if B3313.flagsFile ~= file then
        B3313.flagsFile = file
        B3313.flags = tonumber(mod_storage_load(b3313_flags_key(), "0")) or 0
    end
    return B3313.flags
end
function b3313_flags_set_bit(n)
    local f = (b3313_flags_get() | (1 << n)) & 0xFFFF
    B3313.flags = f
    mod_storage_save(b3313_flags_key(), tostring(f))
end
local function b3313_key_count()
    local f, n = b3313_flags_get(), 0
    for i = 0, 7 do if (f & (1 << i)) ~= 0 then n = n + 1 end end
    return n
end

-- Vanilla boo helpers (static in boo.inc.c, so not reachable from Lua), as coopdx has them.
local sBooHitVel = { [0] = 6047, 5664, 5292, 4934, 4587, 4254, 3933, 3624, 3329, 3046, 2775,
    2517, 2271, 2039, 1818, 1611, 1416, 1233, 1063, 906, 761, 629, 509, 402, 308, 226, 157,
    100, 56, 25, 4, 0 }

local function boo_stop(o) o.oForwardVel = 0.0; o.oVelY = 0.0; o.oGravity = 0.0 end

local function boo_should_be_stopped(o)
    return (o.activeFlags & ACTIVE_FLAG_IN_DIFFERENT_ROOM) ~= 0
end

local function boo_should_be_active(o)
    local m = nearest_mario_state_to_object(o)
    local d = m and dist_between_objects(o, m.marioObj) or 10000
    local inRoom = false
    for i = 0, MAX_PLAYERS - 1 do
        local s = gMarioStates[i]
        if is_player_active(s) ~= 0 and (s.currentRoom == o.oRoom or s.currentRoom == 0) then inRoom = true end
    end
    if o.oRoom == -1 then return d < 1500.0 end
    if not boo_should_be_stopped(o) then return d < 1500.0 and inRoom end
    return false
end

local function boo_opacity_and_scale(o)
    if o.oBooTargetOpacity ~= o.oOpacity then
        if o.oBooTargetOpacity > o.oOpacity then
            o.oOpacity = o.oOpacity + 20
            if o.oBooTargetOpacity < o.oOpacity then o.oOpacity = o.oBooTargetOpacity end
        else
            o.oOpacity = o.oOpacity - 20
            if o.oBooTargetOpacity > o.oOpacity then o.oOpacity = o.oBooTargetOpacity end
        end
    end
    obj_scale(o, (o.oOpacity / 255.0 * 0.4 + 0.6) * o.oBooBaseScale)
end

local function boo_oscillate(o, ignoreOpacity)
    local t = o.oBooOscillationTimer
    o.oFaceAnglePitch = math.floor(sins(t) * 0x400)
    if o.oOpacity == 0xFF or ignoreOpacity then
        o.header.gfx.scale.x = sins(t) * 0.08 + o.oBooBaseScale
        o.header.gfx.scale.y = -sins(t) * 0.08 + o.oBooBaseScale
        o.header.gfx.scale.z = o.header.gfx.scale.x
        o.oGravity = sins(t) * o.oBooBaseScale
        o.oBooOscillationTimer = t + 0x400
    end
end

local function boo_vanish_or_appear(o)
    local p = nearest_player_to_object(o)
    if p == nil then return false end
    local relToMario = abs_angle_diff(obj_angle_to_object(o, p), o.oMoveAngleYaw)
    local relFace = abs_angle_diff(o.oMoveAngleYaw, p.oFaceAngleYaw)
    local done = false
    o.oVelY = 0.0
    if relToMario > 0x1568 or relFace < 0x6B58 then
        if o.oOpacity == 40 then
            o.oBooTargetOpacity = 255
            cur_obj_play_sound_2(SOUND_OBJ_BOO_LAUGH_LONG)
        end
        if o.oOpacity > 180 then done = true end
    elseif o.oOpacity == 255 then
        o.oBooTargetOpacity = 40
    end
    return done
end

local function boo_chase_mario(o, a0, a1, a2)
    local m = nearest_mario_state_to_object(o)
    if m == nil then return end
    local p = m.marioObj
    if boo_vanish_or_appear(o) then
        o.oInteractType = 0x8000
        local yaw
        if cur_obj_lateral_dist_from_obj_to_home(p) > 1500.0 then yaw = cur_obj_angle_to_home()
        else yaw = obj_angle_to_object(o, p) end
        cur_obj_rotate_yaw_toward(yaw, a1)
        o.oVelY = 0.0
        if mario_is_in_air_action(m) == 0 then
            local dy = o.oPosY - p.oPosY
            if a0 < dy and dy < 500.0 then
                o.oVelY = increment_velocity_toward_range(o.oPosY, p.oPosY + 50.0, 10.0, 2.0)
            end
        end
        cur_obj_set_vel_from_mario_vel(m, 10.0 - o.oBooNegatedAggressiveness, a2)
        if o.oForwardVel ~= 0.0 then boo_oscillate(o, false) end
    else
        o.oInteractType = 0
        o.oForwardVel = 0.0
        o.oVelY = 0.0
        o.oGravity = 0.0
    end
end

local function boo_get_attack_status(o)
    local st = 0
    local s = o.oInteractStatus
    if (s & INT_STATUS_INTERACTED) ~= 0 then
        if (s & INT_STATUS_WAS_ATTACKED) ~= 0 and (s & INT_STATUS_ATTACK_MASK) ~= ATTACK_FROM_ABOVE then
            cur_obj_become_intangible()
            o.oInteractStatus = 0
            cur_obj_play_sound_2(SOUND_OBJ_BOO_LAUGH_SHORT)
            st = 1     -- BOO_ATTACKED
        else
            cur_obj_play_sound_2(SOUND_OBJ_BOO_BOUNCE_TOP)
            o.oInteractStatus = 0
            st = -1    -- BOO_BOUNCED_ON
        end
    end
    return st
end

local function boo_update_after_bounced_on(o, a0)
    boo_stop(o)
    if o.oTimer == 0 then
        local p = nearest_player_to_object(o)
        local ang = p and obj_angle_to_object(o, p) or 0
        cur_obj_become_intangible()
        o.oFlags = o.oFlags & ~OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW
        o.oBooMoveYawBeforeHit = o.oMoveAngleYaw
        if coss(b3313_s16(o.oMoveAngleYaw) - b3313_s16(ang)) < 0.0 then
            o.oBooMoveYawDuringHit = o.oMoveAngleYaw
        else
            o.oBooMoveYawDuringHit = b3313_s16(o.oMoveAngleYaw + 0x8000)
        end
    end
    if o.oTimer < 32 then
        o.oForwardVel = sBooHitVel[o.oTimer] / 5000.0 * a0
        o.oVelY = coss(o.oTimer * 0x800 + 0x800)
        o.oMoveAngleYaw = o.oBooMoveYawDuringHit
        return false
    end
    cur_obj_become_tangible()
    o.oMoveAngleYaw = math.floor(o.oBooMoveYawBeforeHit)
    o.oFlags = o.oFlags | OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW
    o.oInteractStatus = 0
    o.oAction = 1
    return true
end

local function boo_update_during_death(o)
    if o.oTimer == 0 then
        local p = nearest_player_to_object(o)
        o.oForwardVel = 40.0
        if p ~= nil then o.oMoveAngleYaw = p.oMoveAngleYaw end
        o.oBooDeathStatus = BOO_DEATH_STATUS_DYING
        o.oFlags = o.oFlags & ~OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW
    else
        if o.oTimer == 5 then o.oBooTargetOpacity = 0 end
        if o.oTimer > 30 or (o.oMoveFlags & OBJ_MOVE_HIT_WALL) ~= 0 then
            spawn_mist_particles()
            o.oBooDeathStatus = BOO_DEATH_STATUS_DEAD
            local big = o.oBooParentBigBoo
            if big ~= nil then big.oBigBooNumMinionBoosKilled = big.oBigBooNumMinionBoosKilled + 1 end
            return true
        end
    end
    o.oVelY = 5.0
    o.oFaceAngleRoll = o.oFaceAngleRoll + 0x800
    o.oFaceAngleYaw = o.oFaceAngleYaw + 0x800
    return false
end

-- 807F303C / 807F3178 (actions 807F2E00..807F2FB8): key-carrying boo. Ghost-hunt style
-- boo that carries one of the 8 boo keys (behParams top byte = key number); the key is
-- shown already-collected (model 157) once you have it. 2nd byte 1 = counts towards the
-- nearby big boo (bhvB3313_1F00161C), then talks (dialog 107/108) when it dies.
-- (bhvB3313_1F0015C4)
local function spawn_boo_key(o)
    local n = (o.oBehParams >> 24) & 0xFF
    if n >= 0x80 then n = n - 0x100 end
    local raw = 0x55
    if n >= 0 and n < 16 and (b3313_flags_get() & (1 << n)) ~= 0 then raw = 0x9D end
    local bp = o.oBehParams
    return spawn_non_sync_object(bhvB3313_1F001590, b3313_model(raw), o.oPosX, o.oPosY, o.oPosZ, function(c)
        obj_copy_angle(c, o)
        c.parentObj = o
        c.oBehParams = bp
    end)
end

function b3313_fn_807F303C(o)
    local key = spawn_boo_key(o)
    if key ~= nil then obj_scale_xyz(key, 0.75, 0.75, 0.75) end
end

local key_boo_actions = {
    [0] = function(o)
        o.oBooParentBigBoo = nil
        if o.oBehParams2ndByte == 1 then
            o.oBooParentBigBoo = cur_obj_nearest_object_with_behavior(get_behavior_from_id(bhvB3313_1F00161C))
        end
        o.oBooTargetOpacity = 0xFF
        o.oBooBaseScale = 1.2
        o.oVelY = 0.0
        cur_obj_scale(1.2)
        cur_obj_become_tangible()
        if boo_should_be_active(o) then o.oAction = 1 end
    end,
    [1] = function(o)
        boo_chase_mario(o, 100.0, 0x200, 0.5)
        local st = boo_get_attack_status(o)
        if boo_should_be_stopped(o) then o.oAction = 0 end
        if st == -1 then o.oAction = 2 end
        if st == 1 then o.oAction = 3 end
    end,
    [2] = function(o)
        if boo_update_after_bounced_on(o, 20.0) then o.oAction = 1 end
    end,
    [3] = function(o)
        if boo_update_during_death(o) then
            if o.oBooParentBigBoo ~= nil then o.oAction = 4 else obj_mark_for_deletion(o) end
        end
    end,
    [4] = function(o)
        local m = gMarioStates[0]
        if o.oSubAction == 0 then
            local others = cur_obj_nearest_object_with_behavior(get_behavior_from_id(bhvB3313_1F0015C4))
            o.oB3313Ref = (others == nil) and 0x6C or 0x6B
            if mario_ready_to_speak(m) ~= 0 then
                set_mario_action(m, ACT_READING_AUTOMATIC_DIALOG, o.oB3313Ref)
                o.oSubAction = 1
            end
        elseif m.action ~= ACT_READING_AUTOMATIC_DIALOG then
            create_sound_spawner(SOUND_OBJ_DYING_ENEMY1)
            obj_mark_for_deletion(o)
            if o.oB3313Ref == 0x6C then play_puzzle_jingle() end
        end
    end,
}

function b3313_fn_807F3178(o)
    cur_obj_update_floor_and_walls()
    local act = key_boo_actions[o.oAction]
    if act ~= nil then act(o) end
    cur_obj_move_standard(78)
    boo_opacity_and_scale(o)
    o.oInteractStatus = 0
end

-- 807F30E8: the big boo (vanilla big boo loop) also carries a key. (bhvB3313_1F00161C)
function b3313_fn_807F30E8(o)
    spawn_boo_key(o)
    o.oBigBooNumMinionBoosKilled = 0
end

-- 807F2DC8 (actions 807F2A80, 807F2B4C, 807F2C2C): the boo key. Rides on its boo, pops
-- out when the boo dies, lands, and is collected on touch: sets its key bit; with 6 or
-- more keys each key also brings out a star (no level exit). (bhvB3313_1F001590)
local boo_key_actions = {
    [0] = function(o)
        local p = o.parentObj
        if p == nil then return end
        obj_copy_pos(o, p)
        o.oPosY = o.oPosY + 50.0 * p.oBooBaseScale
        if (p.header.gfx.node.flags & GRAPH_RENDER_INVISIBLE) ~= 0 then cur_obj_hide() else cur_obj_unhide() end
        if p.oBooDeathStatus ~= 0 then o.oAction = 1 end
        o.oFaceAngleRoll = o.oFaceAngleRoll + 0x200
        o.oFaceAngleYaw = o.oFaceAngleYaw + 0x200
    end,
    [1] = function(o)
        local p = o.parentObj
        if p ~= nil then obj_copy_pos(o, p) end
        if o.oTimer == 0 then
            if p ~= nil and p.parentObj ~= nil then o.parentObj = p.parentObj end
            o.oAction = 2
            local yaw = gMarioStates[0].marioObj.oMoveAngleYaw
            o.oVelX = sins(yaw) * 3.0
            o.oVelZ = coss(yaw) * 3.0
            o.oVelY = 40.0
        end
        o.oFaceAngleYaw = o.oFaceAngleYaw + 0x200
        o.oFaceAngleRoll = o.oFaceAngleRoll + 0x200
    end,
    [2] = function(o)
        cur_obj_update_floor_and_walls()
        cur_obj_move_standard(78)
        if o.oGraphYOffset < 26.0 then o.oGraphYOffset = o.oGraphYOffset + 2.0 end
        local roll = o.oFaceAngleRoll
        if (roll & 0xFFFF) ~= 0 then o.oFaceAngleRoll = (roll & 0xF800) + 0x800 end
        if (o.oMoveFlags & OBJ_MOVE_ON_GROUND) ~= 0 then o.oVelX = 0.0; o.oVelZ = 0.0 end
        o.oFaceAngleYaw = o.oFaceAngleYaw + 0x800
        if o.oTimer < 91 and (o.oMoveFlags & OBJ_MOVE_LANDED) == 0 then return end
        cur_obj_become_tangible()
        local mo = gMarioStates[0].marioObj
        if obj_check_if_collided_with_object(o, mo) == 0 then return end
        if o.parentObj ~= nil then o.parentObj.oInteractStatus = 1 end
        local n = (o.oBehParams >> 24) & 0xFF
        if n >= 0x80 then n = n - 0x100 end
        if n >= 0 and n < 16 then b3313_flags_set_bit(n) end
        obj_mark_for_deletion(o)
        spawn_non_sync_object(id_bhvGoldenCoinSparkles, E_MODEL_SPARKLES, o.oPosX, o.oPosY, o.oPosZ, nil)
        play_sound(0x30762081, mo.header.gfx.cameraToObject)
        if b3313_key_count() >= 6 and n < 8 then
            bhv_spawn_star_no_level_exit(o, 1, 1)
        end
    end,
}

function b3313_fn_807F2DC8(o)
    local act = boo_key_actions[o.oAction]
    if act ~= nil then act(o) end
end

bhvB3313_1F001590 = hook_behavior(nil, OBJ_LIST_LEVEL, true, function(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.hitboxRadius = 32.0
    o.hitboxHeight = 64.0
    o.oWallHitboxRadius = 30.0
    o.oGravity = -4.0
    o.oBounciness = -0.7
    o.oDragStrength = 10.0
    o.oFriction = 10.0
    o.oBuoyancy = 2.0
end, b3313_fn_807F2DC8, "bhvB3313_1F001590")

-- 80406000 / 80406040 / 80406D5C: setup for the vanilla sliding platform loop
-- (bhv_sliding_plat_2_loop): speed = 2nd byte, travel = low 16 bits, direction (vertical
-- if nonzero) = signed top byte. (bhvB3313_13005A14, bhvB3313_13005A4C, bhvB3313_13006A44)
local function sliding_plat_setup(o)
    local bp = o.oBehParams
    o.oBackAndForthPlatformVel = o.oBehParams2ndByte
    o.oBackAndForthPlatformPathLength = bp & 0xFFFF
    local d = (bp >> 24) & 0xFF
    if d >= 0x80 then d = d - 0x100 end
    o.oBackAndForthPlatformDirection = d
end
function b3313_fn_80406000(o) sliding_plat_setup(o) end
function b3313_fn_80406040(o) sliding_plat_setup(o) end
function b3313_fn_80406D5C(o) sliding_plat_setup(o) end

-- 807F2530 / 807F283C (+ 807F255C, 807F2620, 807F2774): water lurker. Hides deep under
-- the water surface, swims at Mario (8.3) when he's within 2500, lunges up at him when
-- he's above it, then sinks back. Stays between floor+50 and ceiling-250, grows back to
-- full size after a lunge. Hurts on touch (1 damage). (bhvB3313_1F001570)
function b3313_fn_807F2530(o)
    b3313_set_hitbox(o, INTERACT_DAMAGE, 0, 1, 0, 0, 90, 90, 70, 80)
end

local lurker_actions = {
    [0] = function(o)      -- lunge up
        local m = gMarioStates[0]
        o.oForwardVel = 14.0
        if o.oTimer == 2 then cur_obj_play_sound_2(0x300A0081) end
        local s = o.header.gfx.scale.x
        if 0.8 < s then s = s - 0.06 else s = 0.8 end
        o.header.gfx.scale.x = s; o.header.gfx.scale.z = s
        if o.oTimer >= 30 then o.oAction = 2; return end
        if not (o.oPosY < find_water_level(o.oPosX, o.oPosZ) - 250.0) then o.oAction = 2; return end
        o.oPosY = o.oPosY + (30 - o.oTimer)
        if m.pos.y < o.oPosY and o.oTimer < 30 then o.oTimer = 30 end
    end,
    [1] = function(o)      -- swim after Mario
        local m = gMarioStates[0]
        o.oForwardVel = 0.0
        if o.oDistanceToMario < 2500.0 then
            o.oForwardVel = 8.3
            if o.oPosY < m.pos.y - 90.0 then o.oAction = 0 end
            if m.pos.y + 60.0 < o.oPosY then o.oPosY = o.oPosY - 15.0 end
        end
    end,
    [2] = function(o)      -- sink back down
        local m = gMarioStates[0]
        o.oForwardVel = 0.0
        local falling = (m.pos.y - 250.0 < o.oPosY) and (o.oFloorHeight + 50.0 < o.oPosY)
        if not falling and o.oTimer >= 30 then o.oAction = 1; return end
        if o.oTimer < 10 then o.oPosY = o.oPosY - o.oTimer else o.oPosY = o.oPosY - 15.0 end
    end,
}

function b3313_fn_807F283C(o)
    if obj_update_standard_actions(1.0) == 0 then return end
    o.oMoveAngleYaw = approach_s16_asymptotic(b3313_s16(o.oMoveAngleYaw), b3313_s16(o.oAngleToMario), 0x400)
    local act = lurker_actions[o.oAction]
    if act ~= nil then act(o) end
    local yaw = o.oMoveAngleYaw
    o.oVelX = sins(yaw) * o.oForwardVel
    o.oVelZ = coss(yaw) * o.oForwardVel
    o.oPosX = o.oPosX + o.oVelX
    o.oPosZ = o.oPosZ + o.oVelZ
    if o.oAction ~= 0 then
        local s = o.header.gfx.scale.x
        if s < 1.0 then s = s + 0.025 else s = 1.0 end
        o.header.gfx.scale.x = s; o.header.gfx.scale.z = s
    end
    o.oFloorHeight = find_floor_height(o.oPosX, o.oPosY, o.oPosZ)
    if o.oPosY < o.oFloorHeight + 50.0 then o.oPosY = o.oFloorHeight + 50.0 end
    local ceil = find_ceil_height(o.oPosX, o.oPosY, o.oPosZ)
    if ceil - 250.0 < o.oPosY then o.oPosY = ceil - 250.0 end
    o.oInteractStatus = 0
end

-- 80562C18: "reflection" Mario. Draws a copy of Mario (same model, pose and animation
-- frame), optionally mirrored through this object's X / Y / Z plane (flags 1/2/4).
-- Visible within a radius (2nd byte * 20), or with flag 8 inside a box (bytes 2/3/4 * 20
-- per axis, 0 = unlimited); flag 0x10 inverts that, flag 0x20 keeps this object's own
-- model. (bhvB3313_1F002C00)
function b3313_fn_80562C18(o)
    local m = gMarioStates[0]
    local mo = m.marioObj
    if mo == nil then return end
    local bp = o.oBehParams & 0xFFFFFFFF
    local flags = (bp >> 24) & 0xFF
    local rx, ry, rz = ((bp >> 16) & 0xFF) * 20, ((bp >> 8) & 0xFF) * 20, (bp & 0xFF) * 20
    if (flags & 0x20) == 0 then
        local ext = obj_get_model_id_extended(mo)
        if ext ~= E_MODEL_NONE and obj_has_model_extended(o, ext) == 0 then obj_set_model_extended(o, ext) end
        o.globalPlayerIndex = gNetworkPlayers[0].globalIndex
    end
    local visible
    if (flags & 8) ~= 0 then
        visible = (rx == 0 or math.abs(mo.oPosX - o.oPosX) < rx)
              and (ry == 0 or math.abs(mo.oPosY - o.oPosY) < ry)
              and (rz == 0 or math.abs(mo.oPosZ - o.oPosZ) < rz)
    else
        visible = (rx == 0) or (o.oDistanceToMario < rx)
    end
    if (flags & 0x10) ~= 0 then visible = not visible end
    local g = o.header.gfx
    if not visible then
        g.scale.x, g.scale.y, g.scale.z = 0.0, 0.0, 0.0
        g.node.flags = g.node.flags & ~GRAPH_RENDER_ACTIVE
        return
    end
    local mg = mo.header.gfx
    g.angle.x, g.angle.y, g.angle.z = mg.angle.x, mg.angle.y, mg.angle.z
    g.pos.x, g.pos.y, g.pos.z = mg.pos.x, mg.pos.y, mg.pos.z
    g.scale.x, g.scale.y, g.scale.z = mg.scale.x, mg.scale.y, mg.scale.z
    g.node.flags = g.node.flags | GRAPH_RENDER_ACTIVE
    local a, ma = g.animInfo, mg.animInfo
    a.animID = ma.animID
    a.curAnim = ma.curAnim
    a.animFrame = ma.animFrame
    a.animTimer = ma.animTimer
    a.animFrameAccelAssist = ma.animFrameAccelAssist
    a.animAccel = ma.animAccel
    if (flags & 1) ~= 0 then
        g.pos.x = 2.0 * o.oPosX - g.pos.x
        g.angle.y = -g.angle.y
        g.scale.x = -g.scale.x
    end
    if (flags & 2) ~= 0 then
        g.pos.y = 2.0 * o.oPosY - g.pos.y
        g.scale.y = -g.scale.y
    end
    if (flags & 4) ~= 0 then
        g.pos.z = 2.0 * o.oPosZ - g.pos.z
        g.angle.y = -g.angle.y
        g.scale.z = -g.scale.z
    end
end

-- 80560624 (+ 805606B0, 80560678): fading apparition. Starts at opacity 170; when Mario
-- gets within 700 (horizontally) it fades out (type 0: after 32 frames; type 1: at once,
-- drifting upward faster and faster) and disappears. behParams low byte set: an invisible
-- sound source instead (the ROM reads an expansion-RAM word nothing ever writes, i.e. 0).
-- (bhvB3313_1F000600)
function b3313_fn_80560624(o)
    local bp = o.oBehParams
    if (bp & 0xFF) ~= 0 then
        o.oOpacity = 0
        cur_obj_play_sound_1(0x4004FF01)
        return
    end
    if o.oTimer == 0 then o.oOpacity = 0xAA end
    local mo = gMarioStates[0].marioObj
    if mo ~= nil and lateral_dist_between_objects(o, mo) <= 700.0 then
        local kind = (bp >> 24) & 0xFF
        if kind == 0 then
            if o.oTimer >= 32 then
                local a = o.oOpacity - 2
                if a < 0 then o.activeFlags = ACTIVE_FLAG_DEACTIVATED else o.oOpacity = a end
            end
        elseif kind == 1 then
            local a = o.oOpacity - 2
            if a < 0 then
                o.activeFlags = ACTIVE_FLAG_DEACTIVATED
            else
                o.oOpacity = a
                obj_set_field_f32(o, 0x1B, obj_get_field_f32(o, 0x1B) + 2.0)
            end
        end
    end
    o.oPosY = o.oPosY + obj_get_field_f32(o, 0x1B)
end

-- 80560C28: the giant eye. A big (3x) billboarded Mr. I that waits until Mario is within
-- (low 16 bits of behParams) on both X and Z, then flies forward at speed 16 for 512
-- frames and disappears. Touching it is instant death. Blinks at random. (bhvB3313_1F000C00)
function b3313_fn_80560C28(o)
    local mo = gMarioStates[0].marioObj
    o.header.gfx.node.flags = 0x25
    o.oIntangibleTimer = 0
    o.hitboxRadius = 400.0
    o.hitboxHeight = 400.0
    o.oInteractType = INTERACT_BOUNCE_TOP2
    o.header.gfx.scale.x, o.header.gfx.scale.y, o.header.gfx.scale.z = 3.0, 3.0, 3.0
    if o.oAction == 0 then
        local range = o.oBehParams & 0xFFFF
        if mo ~= nil and math.abs(o.oPosZ - mo.oPosZ) <= range and math.abs(o.oPosX - mo.oPosX) <= range then
            o.oAction = 1
        end
    elseif o.oTimer >= 0x200 then
        o.activeFlags = ACTIVE_FLAG_DEACTIVATED
    else
        o.oForwardVel = 16.0
        if o.oInteractStatus ~= 0 then gMarioStates[0].health = 0 end
    end
    if o.oMrIUnk110 == 0 and random_u16() % 127 == 0 then o.oMrIUnk110 = 1 end
end

-- Byte-for-byte copies of the small setup routines above, one per platform type.
-- yaw spin speed from behParams (same code as 80406214)
function b3313_fn_80406080(o) spin_from_params(o) end
function b3313_fn_804061AC(o) spin_from_params(o) end
function b3313_fn_804061E0(o) spin_from_params(o) end
function b3313_fn_804069C8(o) spin_from_params(o) end
function b3313_fn_80406D9C(o) spin_from_params(o) end
function b3313_fn_80407288(o) spin_from_params(o) end
function b3313_fn_80407360(o) spin_from_params(o) end
function b3313_fn_80407438(o) spin_from_params(o) end
-- sideways mover setup (same code as 804060E0)
function b3313_fn_804060B4(o) b3313_fn_804060E0(o) end
function b3313_fn_804063BC(o) b3313_fn_804060E0(o) end
function b3313_fn_804065A8(o) b3313_fn_804060E0(o) end
function b3313_fn_80406AC4(o) b3313_fn_804060E0(o) end
function b3313_fn_80406AF0(o) b3313_fn_804060E0(o) end
function b3313_fn_80406B1C(o) b3313_fn_804060E0(o) end
-- sliding platform setup (same code as 80406000)
function b3313_fn_80406528(o) sliding_plat_setup(o) end
function b3313_fn_80406568(o) sliding_plat_setup(o) end
function b3313_fn_804065D4(o) sliding_plat_setup(o) end
function b3313_fn_80406C10(o) sliding_plat_setup(o) end
function b3313_fn_80407394(o) sliding_plat_setup(o) end
function b3313_fn_8040746C(o) sliding_plat_setup(o) end
function b3313_fn_804074AC(o) sliding_plat_setup(o) end
function b3313_fn_804074EC(o) sliding_plat_setup(o) end
function b3313_fn_8040752C(o) sliding_plat_setup(o) end
function b3313_fn_8040756C(o) sliding_plat_setup(o) end
function b3313_fn_804075AC(o) sliding_plat_setup(o) end
function b3313_fn_80407B4C(o) sliding_plat_setup(o) end

-- 805679FC (+ 805676C8, 80567868, 805679D4) and 80567120: goomba tower. The spawner makes a
-- stack of goombas (top byte = height, default 5) when Mario is within 4000; the bottom
-- one walks/chases like a vanilla goomba (with B3313's tweaks) and carries the rest, which
-- wobble on top of it and drop down a slot when the one below is squished. Despawns when
-- Mario is 4500 away. B3313 varies goomba behaviour with its "enhancer" difficulty state;
-- that system isn't ported, so these use its neutral setting. (bhvB3313_1F007000)
local GT_MODE = 1     -- B3313's goomba variant byte (0x80373824), neutral
local sGoombaHitbox = { INTERACT_BOUNCE_TOP, 10, 1, 0, 0, 72, 50, 42, 40 }
local sGoombaAttackHandlers = { 2, 2, 3, 3, 2, 2 }   -- knockback, knockback, squish, squish, knockback, knockback

local function b3313_obj_handle_attacks(o, hb, attackedMarioAction, handlers)
    b3313_set_hitbox(o, hb[1], hb[2], hb[3], hb[4], hb[5], hb[6], hb[7], hb[8], hb[9])
    if obj_die_if_above_lava_and_health_non_positive() ~= 0 then return 1 end
    local s = o.oInteractStatus
    if (s & INT_STATUS_INTERACTED) ~= 0 then
        if (s & INT_STATUS_ATTACKED_MARIO) ~= 0 then
            if o.oAction ~= attackedMarioAction then
                o.oAction = attackedMarioAction
                o.oTimer = 0
            end
        else
            local attackType = s & INT_STATUS_ATTACK_MASK
            local h = handlers[attackType]
            if h == 2 then obj_set_knockback_action(attackType)
            elseif h == 3 then obj_set_squished_action()
            elseif h == 1 then obj_die_if_health_non_positive() end
            o.oInteractStatus = 0
            return attackType
        end
    end
    o.oInteractStatus = 0
    return 0
end

local function gt_spawn_member(p, i, relY)
    return spawn_non_sync_object(bhvB3313_80567034, b3313_model(0xC0), p.oPosX, p.oPosY + relY, p.oPosZ, function(c)
        obj_copy_angle(c, p)
        c.parentObj = p
        c.oBehParams = i << 16
        c.oBehParams2ndByte = i
        c.oHomeX, c.oHomeY, c.oHomeZ = p.oPosX, p.oPosY, p.oPosZ
        obj_scale(c, 1.5)
    end)
end

local goomba_tower_actions = {
    [0] = function(p)    -- 805676C8: build the stack
        if p.oDistanceToMario >= 4000.0 then return end
        local count = obj_get_field_s32(p, 0x1C)
        if count == 0 then
            count = (p.oBehParams >> 24) & 0xFF
            if count >= 0x80 then count = count - 0x100 end
        end
        if count == 0 then count = 5 end
        for i = count - 1, 0, -1 do
            if gt_spawn_member(p, i, math.floor(-i * 116.0 + 116.0 * (count - 1))) ~= nil then
                obj_set_field_s32(p, 0x1B, obj_get_field_s32(p, 0x1B) | (1 << i))
            end
        end
        obj_set_field_s32(p, 0x1C, count)
        obj_set_field_f32(p, 0x1D, 1.0)
        p.oAction = 1
    end,
    [1] = function(p)    -- 80567868: wait; despawn when far (the regrow path is unreachable)
        if obj_get_field_s32(p, 0x1C) == 0 then obj_mark_for_deletion(p); return end
        if p.oDistanceToMario > 4500.0 then
            p.oAction = 2
            p.oForwardVel = 0.0
        end
    end,
    [2] = function(p)    -- 805679D4: reset to home (members delete themselves)
        p.oAction = 0
        cur_obj_set_pos_to_home()
    end,
}

function b3313_fn_805679FC(o)
    o.oDeathSound = 0x5063C081
    local act = goomba_tower_actions[o.oAction]
    if act ~= nil then act(o) end
end

local function gt_begin_jump(o)
    cur_obj_play_sound_2(0x502F0081)
    o.oAction = 2
    o.oForwardVel = 0.0
    o.oVelY = 25.0
end

local function gt_walk(o, p)
    local aggressive = (GT_MODE == 2 or GT_MODE == 3)
    cur_obj_update_floor_and_walls()
    obj_forward_vel_approach(obj_get_field_f32(o, 0x21) * 1.5, 0.4)
    if aggressive or GT_MODE == 6 then o.oDamageOrCoinValue = 3 end
    if obj_get_field_f32(o, 0x21) > 2.0 then cur_obj_play_sound_at_anim_range(2, 17, 0x50200081) end
    if obj_get_field_s32(o, 0x20) ~= 0 then
        obj_set_field_s32(o, 0x20, obj_resolve_collisions_and_turn(b3313_s16(obj_get_field_s32(o, 0x1E)), 0x200))
        return
    end
    if o.oDistanceToMario >= 25000.0 then
        obj_set_field_s32(o, 0x1E, o.oAngleToMario)
        obj_set_field_s32(o, 0x1D, random_linear_offset(20, 30))
    end
    local hit, yaw = obj_bounce_off_walls_edges_objects()
    obj_set_field_s32(o, 0x20, hit)
    if hit ~= 0 then
        obj_set_field_s32(o, 0x1E, yaw)
    elseif o.oDistanceToMario < 1000.0 and GT_MODE ~= 4 then
        if obj_get_field_f32(o, 0x21) <= 2.0 then gt_begin_jump(o) end
        local target = o.oAngleToMario
        if GT_MODE == 5 then target = target + 0x8000 end
        obj_set_field_s32(o, 0x1E, target)
        obj_set_field_f32(o, 0x21, (aggressive or GT_MODE == 5) and 40.0 or 20.0)
    else
        obj_set_field_f32(o, 0x21, aggressive and 2.0 or (4.0 / 3.0))
        local t = obj_get_field_s32(o, 0x1D)
        if t ~= 0 then
            obj_set_field_s32(o, 0x1D, t - 1)
        elseif (random_u16() & 3) ~= 0 then
            obj_set_field_s32(o, 0x1E, obj_random_fixed_turn(0x2000))
            obj_set_field_s32(o, 0x1D, random_linear_offset(100, 100))
        else
            gt_begin_jump(o)
            obj_set_field_s32(o, 0x1E, obj_random_fixed_turn(0x6000))
        end
    end
    cur_obj_rotate_yaw_toward(b3313_s16(obj_get_field_s32(o, 0x1E)), aggressive and 0x600 or 0x200)
end

function b3313_fn_80567120(o)
    local p = o.parentObj
    if p == nil then return end
    if obj_update_standard_actions(1.5) == 0 then
        o.oAnimState = 1
    elseif p.oAction == 2 then
        obj_mark_for_deletion(o)
    else
        cur_obj_update_floor_and_walls()
        obj_set_field_s32(o, 0x22, obj_update_blinking(obj_get_field_s32(o, 0x22), 30, 50, 5))
        local idx = o.oBehParams2ndByte
        local alive = obj_get_field_s32(p, 0x1B)
        local moved = false
        if idx > 0 and (alive & (1 << (idx - 1))) == 0 then
            -- the goomba below is gone: drop down a slot
            alive = (alive | (1 << (idx - 1))) & ~(1 << idx)
            obj_set_field_s32(p, 0x1B, alive)
            o.oBehParams2ndByte = idx - 1
            moved = true
        end
        if not moved then
            local count = obj_get_field_s32(p, 0x1C)
            if idx + 1 == count then
                -- bottom goomba: walks and carries the tower
                local mo = gMarioStates[0].marioObj
                if mo ~= nil then o.oDistanceToMario = lateral_dist_between_objects(o, mo) end
                local sc = obj_get_field_f32(p, 0x1D)
                if sc < 1.0 then
                    local _, v = approach_f32_ptr(sc, 1.0, 0.1)
                    obj_set_field_f32(p, 0x1D, v)
                    cur_obj_scale(v * 1.5)
                end
                local accel = o.oForwardVel / 1.5 * 0.4
                if accel < 1.0 then accel = 1.0 end
                cur_obj_init_animation_with_accel_and_sound(0, accel)
                if o.oAction == 2 then
                    obj_resolve_object_collisions()
                    if (o.oMoveFlags & 3) ~= 0 then o.oAction = 0
                    else cur_obj_rotate_yaw_toward(b3313_s16(obj_get_field_s32(o, 0x1E)), 0x800) end
                else
                    gt_walk(o, p)
                end
                cur_obj_move_standard(-78)
                p.oPosX, p.oPosY, p.oPosZ = o.oPosX, o.oPosY, o.oPosZ
                p.oVelY = o.oVelY
                p.oFaceAngleYaw = o.oFaceAngleYaw
                p.oMoveAngleYaw = o.oMoveAngleYaw
            else
                -- riding on the stack, wobbling around its centre
                local ang = (idx * 0x4000 + get_global_timer() * 0x800) & 0xFFFF
                o.oPosX = coss(ang) * 6.0 + p.oPosX
                o.oPosZ = sins(ang) * 6.0 + p.oPosZ
                local ty = p.oPosY + 116.0 * (count - idx - 2) + obj_get_field_f32(p, 0x1D) * 116.0
                if o.oPosY < ty then
                    o.oPosY = ty
                    o.oVelY = 0.0
                end
            end
        end
        o.oNumLootCoins = (GT_MODE == 5) and -1 or 1
        if b3313_obj_handle_attacks(o, sGoombaHitbox, o.oAction, sGoombaAttackHandlers) ~= 0 then
            obj_set_field_s32(p, 0x1C, obj_get_field_s32(p, 0x1C) - 1)
            obj_set_field_s32(p, 0x1B, obj_get_field_s32(p, 0x1B) & ~(1 << o.oBehParams2ndByte))
        else
            obj_set_field_s32(o, 0x1C, o.oBehParams2ndByte * 4 + 20)
        end
        cur_obj_move_standard(-78)
    end
    o.oDeathSound = 0x5060B081
    o.oFaceAngleYaw = p.oMoveAngleYaw
end

bhvB3313_80567034 = hook_behavior(nil, OBJ_LIST_GENACTOR, true, function(o)
    o.oFlags = o.oFlags | 0x2001
    o.oB3313AnimTbl = 0
    o.oAnimations = gObjectAnimations.goomba_seg8_anims_0801DA4C   -- vanilla goomba animations
    b3313_animate(o, 0)
    o.oWallHitboxRadius = 60.0
    o.oGravity = -4.0
    o.oBounciness = 0.0
    o.oDragStrength = 10.0
    o.oFriction = 10.0
    o.oBuoyancy = 2.0
end, b3313_fn_80567120, "bhvB3313_80567034")

-- 80560860: only stays if B3313 save course 37, star bit 4 is set (an event flag in its
-- extended save table, see a3_stars.lua). (bhvB3313_13008720, bhvB3313_1300875C)
function b3313_fn_80560860(o)
    if (b3313_star_flags(0x25) & 0x10) == 0 then obj_mark_for_deletion(o) end
end

-- 80406DD0 / 804070B4: turntable. Spins up (to 0x300 per frame) while nobody stands on
-- it and winds down while Mario rides it; the speed lives in oBehParams like the ROM.
-- (bhvB3313_13006ADC, bhvB3313_13006C0C)
local function turntable(o)
    local v = o.oBehParams
    if not b3313_mario_on_platform(o) then
        v = v + 0x20
        if v >= 0x300 then v = 0x300 end
    else
        v = v - 0x30
        if v < 0 then v = 0 end
    end
    o.oBehParams = v
    o.oAngleVelYaw = b3313_s16(v)
    o.oFaceAngleYaw = o.oFaceAngleYaw + v
end
function b3313_fn_80406DD0(o) turntable(o) end
function b3313_fn_804070B4(o) turntable(o) end

-- 804072BC / 80407660: flip panels with other models (same code as 80406CB8).
-- (bhvB3313_13006FD0, bhvB3313_13007CF8)
function b3313_fn_804072BC(o) b3313_fn_80406CB8(o) end
function b3313_fn_80407660(o) b3313_fn_80406CB8(o) end

-- 80406FA4: launch orb. Bobs up and down; touching it (it's a coin-type interaction)
-- throws Mario into a triple jump with upward speed 40 + behParams, pops it with a puff
-- and a sound, and it comes back after 3 seconds. (bhvB3313_13006B44)
function b3313_fn_80406FA4(o)
    if o.oAction == 1 then
        if o.oTimer == 90 then
            o.header.gfx.node.flags = 0x25
            o.oIntangibleTimer = 0
            o.oAction = 0
            o.oInteractStatus = 0
            cur_obj_set_pos_to_home()
        end
        return
    end
    o.oPosY = o.oPosY + math.sin(o.oTimer / 30.0) * 2.0
    if o.oInteractStatus ~= 0 then
        local m = gMarioStates[0]
        m.vel.y = 40.0 + o.oBehParams
        m.action = ACT_TRIPLE_JUMP
        o.oAction = 1
        o.header.gfx.node.flags = 0x20
        spawn_mist_particles_variable(30, 0, 20.0)
        local v = random_u16() & 3
        if v > 2 then v = 2 end
        play_sound(0x2402FF81 + (v << 16), gGlobalSoundSource)
    end
end

-- 804079D4 / 80407A0C: talk spot. Invisible; within (top byte * 50) units Mario stops for
-- dialog (2nd byte), then by 3rd byte: 1 = warp through warp node (4th byte), 2 = a star
-- (index = 4th byte) appears, 3 = Mario drops dead. Re-arms when he walks away.
-- (bhvB3313_13007DD0)
function b3313_fn_804079D4(o)
    obj_set_field_f32(o, 0x1B, ((o.oBehParams >> 24) & 0xFF) * 50.0)
end

function b3313_fn_80407A0C(o)
    local m = gMarioStates[0]
    if o.oAction == 1 then          -- dialog open
        if m.action == ACT_READING_AUTOMATIC_DIALOG then return end
        o.oAction = 0
        obj_set_field_s32(o, 0x1C, 1)
        local kind = (o.oBehParams >> 8) & 0xFF
        local arg = o.oBehParams & 0xFF
        if kind == 1 then
            cur_obj_play_sound_1(0x70190081)
            o.oBehParams = (o.oBehParams & 0xFF00FFFF) | (arg << 16)
            m.usedObj = o
            level_trigger_warp(m, WARP_OP_WARP_OBJECT)
            o.activeFlags = ACTIVE_FLAG_DEACTIVATED
        elseif kind == 2 then
            local star = spawn_default_star(o.oPosX, o.oPosY, o.oPosZ)
            if star ~= nil then star.oBehParams = (star.oBehParams & 0x00FFFFFF) | (arg << 24) end
            o.activeFlags = ACTIVE_FLAG_DEACTIVATED
        elseif kind == 3 then
            m.health = 0
            m.action = ACT_DEATH_ON_BACK
        end
        return
    end
    if o.oDistanceToMario < obj_get_field_f32(o, 0x1B) then
        if obj_get_field_s32(o, 0x1C) == 0 and mario_ready_to_speak(m) ~= 0 then
            set_mario_action(m, ACT_READING_AUTOMATIC_DIALOG, (o.oBehParams >> 16) & 0xFF)
            o.oAction = 1
        end
    else
        obj_set_field_s32(o, 0x1C, 0)
    end
end

-- 807E00C8: star reward: once no object with the behavior in its params (low 24 bits)
-- is left, removes itself and a star appears (index = its top byte). (bhvB3313_1F001898)
function b3313_fn_807E00C8(o)
    local bid = b3313_bhv_id(0x13000000 | (o.oBehParams & 0xFFFFFF))
    if bid ~= nil and cur_obj_nearest_object_with_behavior(get_behavior_from_id(bid)) ~= nil then return end
    o.activeFlags = ACTIVE_FLAG_DEACTIVATED
    spawn_default_star(o.oPosX, o.oPosY, o.oPosZ)
end

-- 807E015C (B3313 code at 802B6640): star-count warp. Fewer stars than (top 16 bits of
-- behParams) -> warp node = 3rd byte, otherwise 4th byte; then a normal warp.
-- (bhvB3313_1F0018E0)
function b3313_fn_807E015C(o)
    local bp = o.oBehParams & 0xFFFFFFFF
    local need = (bp >> 16) & 0xFFFF
    local node = (gMarioStates[0].numStars < need) and ((bp >> 8) & 0xFF) or (bp & 0xFF)
    o.oBehParams = node << 16
    o.oBehParams2ndByte = node
end

-- B3313 timed challenges use the level timer (level_control_timer isn't available to
-- Lua, so the timer is run here).
B3313.timerRunning = false
function b3313_timer_start()
    gHudDisplay.timer = 0
    gHudDisplay.flags = gHudDisplay.flags | HUD_DISPLAY_FLAG_TIMER
    B3313.timerRunning = true
end
function b3313_timer_stop()
    B3313.timerRunning = false
end
hook_event(HOOK_UPDATE, function()
    if B3313.timerRunning and gHudDisplay.timer < 17999 then gHudDisplay.timer = gHudDisplay.timer + 1 end
end)
hook_event(HOOK_ON_LEVEL_INIT, function() B3313.timerRunning = false end)

-- 807E02C0 / 807E02F8: timed run to a goal. Starts the timer (pss_begin_slide); reaching
-- this spot (within 2nd byte * 50) stops it and, with 3rd byte set, a star (index = 4th
-- byte) appears. Taking longer than (top byte) seconds stops the timer and, unless bit 0
-- of the 3rd byte is set, kills Mario. (bhvB3313_1F001930)
function b3313_fn_807E02C0(o)
    obj_set_field_f32(o, 0x1B, ((o.oBehParams >> 16) & 0xFF) * 50.0)
end

function b3313_fn_807E02F8(o)
    local bp = o.oBehParams
    if o.oDistanceToMario < obj_get_field_f32(o, 0x1B) then
        gHudDisplay.flags = gHudDisplay.flags & ~HUD_DISPLAY_FLAG_TIMER
        b3313_timer_stop()
        if ((bp >> 8) & 0xFF) ~= 0 then
            local star = spawn_default_star(o.oPosX, o.oPosY, o.oPosZ)
            if star ~= nil then star.oBehParams = (star.oBehParams & 0x00FFFFFF) | ((bp & 0xFF) << 24) end
        end
        o.activeFlags = ACTIVE_FLAG_DEACTIVATED
        return
    end
    if o.oTimer < ((bp >> 24) & 0xFF) * 30 then return end
    b3313_timer_stop()
    gHudDisplay.flags = gHudDisplay.flags & ~HUD_DISPLAY_FLAG_TIMER
    if ((bp >> 8) & 1) == 0 then
        local m = gMarioStates[0]
        m.health = 0
        if (m.action & ACT_GROUP_MASK) == ACT_GROUP_CUTSCENE then m.action = ACT_DEATH_ON_BACK end
    end
    o.activeFlags = ACTIVE_FLAG_DEACTIVATED
end

-- 807E0550: door that warps (through warp node = 2nd byte) as soon as it starts to open.
-- (bhvB3313_1F0019DC)
function b3313_fn_807E0550(o)
    if (o.oAction == 1 or o.oAction == 2) and obj_get_field_s32(o, 0x1B) == 0 then
        obj_set_field_s32(o, 0x1B, 1)
        cur_obj_play_sound_1(0x70190081)
        local m = gMarioStates[0]
        m.usedObj = o
        level_trigger_warp(m, WARP_OP_WARP_OBJECT)
    end
end

-- 80405110 (code at 80403E30): hurting floor. Walking (not with the metal cap) on floor of
-- surface type (top byte of behParams) knocks Mario back and costs a wedge.
-- (bhvB3313_0040388C)
function b3313_fn_80405110(o)
    local m = gMarioStates[0]
    if (m.flags & MARIO_METAL_CAP) ~= 0 or m.floor == nil or m.health <= 0 then return end
    if m.floor.type ~= ((o.oBehParams >> 24) & 0xFF) then return end
    if (m.action & ACT_GROUP_MASK) ~= ACT_GROUP_MOVING or m.invincTimer ~= 0 then return end
    m.invincTimer = 60
    m.action = ACT_SOFT_BACKWARD_GROUND_KB
    m.health = m.health - 0x100
end

-- 80405118 (80403E9C): carry-it-out item. Can be picked up; the first time it is above
-- the water surface a star appears above it. (bhvB3313_004038A0)
function b3313_fn_80405118(o)
    o.oInteractType = INTERACT_GRABBABLE
    o.oFlags = 0x409
    cur_obj_enable_rendering_and_become_tangible(o)
    o.oVelY = -20.0
    if o.oHeldState == HELD_HELD then cur_obj_disable_rendering_and_become_intangible(o) end
    if obj_get_field_s32(o, 0x1D) == 0 and o.oPosY > find_water_level(o.oPosX, o.oPosZ) then
        obj_set_field_s32(o, 0x1D, 1)
        spawn_default_star(o.oPosX, o.oPosY + 300.0, o.oPosZ)
    end
    object_step()
end

-- 80405120 (80403F48): music fade zone: within (top 16 bits of behParams) units the level
-- music fades out over (3rd byte) frames. (bhvB3313_004038C8)
function b3313_fn_80405120(o)
    local bp = o.oBehParams & 0xFFFFFFFF
    if o.oDistanceToMario <= ((bp >> 16) & 0xFFFF) then fadeout_level_music((bp >> 8) & 0xFF) end
end

-- 80405128 (80403F7C): small breakable box that leaves a star when broken.
-- (bhvB3313_004038E0)
function b3313_fn_80405128(o)
    if o.activeFlags == ACTIVE_FLAG_DEACTIVATED and obj_get_field_s32(o, 0x1D) == 0 then
        obj_set_field_s32(o, 0x1D, 1)
        spawn_default_star(o.oHomeX, o.oHomeY + 300.0, o.oHomeZ)
    end
end

-- helpers from B3313's boss code (80405210 / 80405218)
local function b3313_hurtbox_overlap(a, b)
    local ay = a.oPosY - a.hitboxDownOffset
    local by = b.oPosY - b.hitboxDownOffset
    local dx, dz = a.oPosX - b.oPosX, a.oPosZ - b.oPosZ
    if a.hurtboxRadius + b.hurtboxRadius <= math.sqrt(dx * dx + dz * dz) then return false end
    if ay > b.hurtboxHeight + by then return false end
    if a.hitboxHeight + ay < by then return false end
    return true
end

-- which of the attack masks in bytes 0xF8..0xFB Mario's hit matches (1-4), -1 if he just
-- touched the hurtbox, 0 if no contact
local function boss_attack_check(o)
    local m = gMarioStates[0]
    local mo = m.marioObj
    if mo == nil or obj_check_if_collided_with_object(o, mo) == 0 then return 0 end
    local it = determine_interaction(m, o)
    local masks = obj_get_field_s32(o, 0x1C) & 0xFFFFFFFF
    for i = 1, 4 do
        local mask = (masks >> (32 - 8 * i)) & 0xFF
        if (it & mask) ~= 0 then return i end
    end
    if b3313_hurtbox_overlap(mo, o) then return -1 end
    return 0
end

local function boss_flicker(o)
    if o.oIntangibleTimer > 0 then
        o.header.gfx.node.flags = o.header.gfx.node.flags ~ GRAPH_RENDER_INVISIBLE
    else
        o.header.gfx.node.flags = o.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
    end
end

-- 80405100 (80403918): giant goomba boss. Circles the arena, dropping up to 3 small
-- goombas (bhvB3313_80403844) every 5 seconds. Kick a small goomba into it to hurt it;
-- each hit makes it grow and speed up; after the third it shakes, and a star appears.
-- (bhvB3313_00403800)
function b3313_fn_80405100(o)
    o.oFloor = cur_obj_update_floor_height_and_get_floor()
    local act = o.oAction
    if act == 1 then
        fadeout_level_music(0x20)
        if cur_obj_shake_y_until(0x20, 0x10) ~= 0 then
            spawn_default_star(o.oPosX, 700.0, o.oPosZ)
            spawn_mist_particles()
            cur_obj_play_sound_2(0x5061FF81)
            o.activeFlags = ACTIVE_FLAG_DEACTIVATED
            return
        end
    elseif act == 2 then
        o.oMoveAngleYaw = b3313_s32(o.oMoveAngleYaw + obj_get_field_s32(o, 0x48))
        obj_move_xyz_using_fvel_and_yaw(o)
        -- every 150 frames, while fewer than 3 are out, drop a small goomba
        local f = obj_get_field_s32(o, 0x1D) & 0xFFFFFFFF
        local count, t = (f >> 24) & 0xFF, ((f >> 16) & 0xFF) + 1
        if count < 3 then
            if t >= 150 then
                count = count + 1
                t = 0
                spawn_non_sync_object(bhvB3313_80403844, b3313_model(0xC0), -70.0, -100.0, -70.0, function(c)
                    c.parentObj = o
                    c.oGravity = -1.5
                    c.oVelY = 40.0
                    local yaw = random_u16()
                    c.oMoveAngleYaw = yaw
                    c.oFaceAngleYaw = yaw
                end)
            end
            obj_set_field_s32(o, 0x1D, (count << 24) | (t << 16) | (f & 0xFFFF))
        end
    elseif act == 3 then
        local done = cur_obj_shake_y_until(0x10, 0x10)
        local s = o.header.gfx.scale.y * 1.008
        o.header.gfx.scale.x, o.header.gfx.scale.y, o.header.gfx.scale.z = s, s, s
        if done ~= 0 then
            local turn = obj_get_field_s32(o, 0x48)
            obj_set_field_s32(o, 0x48, b3313_s32(turn + ((turn & 0xFFFFFFFF) >> 1)))
            o.oForwardVel = o.oForwardVel * 1.5
            o.hitboxRadius = o.hitboxRadius * 1.25
            o.hitboxHeight = o.hitboxHeight * 1.25
            o.hurtboxRadius = o.hurtboxRadius * 1.25
            o.hurtboxHeight = o.hurtboxHeight * 1.25
            o.oAction = (o.oHealth == 3) and 1 or 2
        end
    else
        o.header.gfx.animInfo.animAccel = 0x18000
        o.oHealth = 0
        o.oAction = 2
        o.oForwardVel = 20.0
        obj_set_field_s32(o, 0x48, -0xA0)
    end
    boss_flicker(o)
    if boss_attack_check(o) ~= 0 then take_damage_and_knock_back(gMarioStates[0], o) end
end

-- 80405108 (80403B5C): the boss's small goombas. Drop in, then walk; stomp or ground-pound
-- to squish, kick/punch to send it flying (into the boss to hurt it).
local function minion_die(o)
    local p = o.parentObj
    if p ~= nil then
        local f = obj_get_field_s32(p, 0x1D) & 0xFFFFFFFF
        local count = ((f >> 24) & 0xFF) - 1
        if count < 0 then count = 0 end
        obj_set_field_s32(p, 0x1D, (count << 24) | (f & 0xFFFFFF))
    end
    spawn_mist_particles()
    cur_obj_play_sound_2(0x5460FF81)
    o.activeFlags = ACTIVE_FLAG_DEACTIVATED
end

function b3313_fn_80405108(o)
    o.oFloor = cur_obj_update_floor_height_and_get_floor()
    local p = o.parentObj
    local state = obj_get_field_s32(o, 0x1D)
    if state == 1 then                  -- squished
        local sy = o.header.gfx.scale.y - 0.203
        o.header.gfx.scale.y = sy
        if not (sy < 0.203) then minion_die(o) end
        return
    elseif state == 2 then              -- kicked
        obj_move_xyz_using_fvel_and_yaw(o)
        o.header.gfx.animInfo.animAccel = 1
        cur_obj_move_using_vel_and_gravity()
        if p ~= nil and obj_check_hitbox_overlap(o, p) then
            p.oAction = 3
            p.oTimer = 0
            p.oHealth = p.oHealth + 1
            minion_die(o)
            return
        end
        if o.oPosY <= o.oFloorHeight then minion_die(o); return end
    elseif state == 3 then              -- walking
        cur_obj_move_using_fvel_and_gravity()
        if o.oPosY <= o.oFloorHeight then
            o.oPosY = o.oFloorHeight
            o.oVelY = 0.0
        end
        if p ~= nil and obj_check_hitbox_overlap(o, p) then obj_set_field_s32(o, 0x1D, 1) end
    else                                -- dropping in
        if o.oTimer <= 32 then
            cur_obj_move_using_vel_and_gravity()
        else
            o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosX, o.oPosZ
            o.oForwardVel = 7.0
            obj_set_field_s32(o, 0x1D, 3)
            obj_set_field_s32(o, 0x1C, 0x402E0100)   -- attack masks: stomp, kick/punch, pound
        end
    end
    boss_flicker(o)
    local hit = boss_attack_check(o)
    local m = gMarioStates[0]
    if hit == 1 then
        obj_set_field_s32(o, 0x1D, 1)
        m.vel.y = -m.vel.y
    elseif hit == 2 then
        o.oMoveAngleYaw = (o.oAngleToMario & 0xFFFF) ~ 0x8000
        local d = ((o.oMoveAngleYaw - m.faceAngle.y) & 0x7FFF)
        local s, c = math.abs(sins(d)), math.abs(coss(d))
        local v = m.forwardVel + 10.0
        m.forwardVel = v * s
        m.slideVelX = m.slideVelX * s
        m.slideVelZ = m.slideVelZ * s
        o.oForwardVel = v - v * s
        o.oVelY = o.oForwardVel / 2.0
        obj_set_field_s32(o, 0x1D, 2)
    elseif hit == 3 then
        obj_set_field_s32(o, 0x1D, 1)
    elseif hit ~= 0 then
        take_damage_and_knock_back(m, o)
    end
    if o.oPosY < -2000.0 then minion_die(o) end
end

bhvB3313_80403844 = hook_behavior(nil, OBJ_LIST_GENACTOR, true, function(o)
    o.oFlags = o.oFlags | 0x20C1
    o.oB3313AnimTbl = 0
    o.oAnimations = gObjectAnimations.goomba_seg8_anims_0801DA4C
    b3313_animate(o, 0)
    o.hitboxRadius, o.hitboxHeight = 72.0, 160.0
    o.hurtboxRadius, o.hurtboxHeight = 72.0, 160.0
    o.oDamageOrCoinValue = 1
    obj_scale(o, 1.5)
    o.oIntangibleTimer = 0
    b3313_drop_to_floor(o)
    o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ
end, b3313_fn_80405108, "bhvB3313_80403844")

-- spawn_object_relative() (not exposed to Lua)
function b3313_spawn_relative(parent, behParam, rx, ry, rz, modelExt, bhvId)
    return spawn_non_sync_object(bhvId, modelExt, parent.oPosX, parent.oPosY, parent.oPosZ, function(c)
        c.parentObj = parent
        obj_copy_angle(c, parent)
        obj_set_parent_relative_pos(c, rx, ry, rz)
        obj_build_relative_transform(c)
        c.oBehParams2ndByte = behParam
        c.oBehParams = (behParam & 0xFF) << 16
    end)
end

-- 80407120 / 80407704 / 8040786C: switch-opened gate (vanilla openable grill with its own
-- model and door behavior: model = top byte, door behavior 0x13xxxxxx = low 24 bits).
-- Opens when the nearby grill floor switch is pressed. (bhvB3313_13006E6C/13007D78/13007DB8)
local function switch_gate(o)
    if o.oAction == 0 then
        local bp = o.oBehParams & 0xFFFFFFFF
        local bid = b3313_bhv_id(0x13000000 + (bp & 0xFFFFFF))
        local model = b3313_model((bp >> 24) & 0xFF)
        if bid ~= nil then
            local a = b3313_spawn_relative(o, -1, 0x19A, 0, 0, model, bid)
            if a ~= nil then a.oMoveAngleYaw = a.oMoveAngleYaw + 0x8000 end
            b3313_spawn_relative(o, 1, -0x19A, 0, 0, model, bid)
        end
        o.oAction = 1
    elseif o.oAction == 1 then
        local sw = cur_obj_nearest_object_with_behavior(get_behavior_from_id(id_bhvFloorSwitchGrills))
        if sw ~= nil then
            o.oOpenableGrillUnkF4 = sw
            o.oAction = 2
        end
    elseif o.oAction == 2 then
        local sw = o.oOpenableGrillUnkF4
        if sw ~= nil and sw.oAction == 2 then
            o.oOpenableGrillUnk88 = 2
            cur_obj_play_sound_2(0x303FA081)
            o.oAction = 3
        end
    end
end
function b3313_fn_80407120(o) switch_gate(o) end
function b3313_fn_80407704(o) switch_gate(o) end
function b3313_fn_8040786C(o) switch_gate(o) end

-- 80406614 / 80406B48: purple-switch platform (vanilla hidden object logic, with its own
-- collision): invisible until the nearest floor switch is pressed, then solid for 360
-- frames and blinks out. (bhvB3313_1300636C, bhvB3313_13006940)
local function switch_platform(o)
    if o.oAction == 0 then
        local sw = o.oHiddenObjectUnkF4
        if sw == nil then
            sw = cur_obj_nearest_object_with_behavior(get_behavior_from_id(id_bhvFloorSwitchHiddenObjects))
            o.oHiddenObjectUnkF4 = sw
        end
        if sw ~= nil and sw.oAction == 2 then
            o.oAction = o.oAction + 1
            cur_obj_enable_rendering()
            cur_obj_unhide()
        else
            cur_obj_disable_rendering()
            cur_obj_become_intangible()
        end
    else
        cur_obj_become_tangible()
        load_object_collision_model()
        if cur_obj_wait_then_blink(360, 20) ~= 0 then o.oAction = 0 end
    end
end
function b3313_fn_80406614(o) switch_platform(o) end
function b3313_fn_80406B48(o) switch_platform(o) end

-- 8040610C: oscillating platform: moves along axis (2nd byte: 0=X 1=Y 2=Z) by
-- (top byte * 4) * sin(timer / (256 - 3rd byte)) around its home, carrying riders.
-- (bhvB3313_13005DB0)
function b3313_fn_8040610C(o)
    local bp = o.oBehParams & 0xFFFFFFFF
    local px, py, pz = o.oPosX, o.oPosY, o.oPosZ
    local d = ((bp >> 24) & 0xFF) * 4 * math.sin(o.oTimer / (256 - ((bp >> 8) & 0xFF)))
    local axis = (bp >> 16) & 0xFF
    if axis == 0 then o.oPosX = o.oHomeX + d
    elseif axis == 1 then o.oPosY = o.oHomeY + d
    elseif axis == 2 then o.oPosZ = o.oHomeZ + d end
    o.oVelX, o.oVelY, o.oVelZ = o.oPosX - px, o.oPosY - py, o.oPosZ - pz
end

-- bytes 0xFC..0xFF (field 0x1D), as B3313's boss code uses them
local function fbyte(o, i)
    return ((obj_get_field_s32(o, 0x1D) & 0xFFFFFFFF) >> (24 - 8 * i)) & 0xFF
end
local function fbyte_set(o, i, v)
    local sh = 24 - 8 * i
    local w = obj_get_field_s32(o, 0x1D) & 0xFFFFFFFF
    w = (w & ~(0xFF << sh)) | ((v & 0xFF) << sh)
    obj_set_field_s32(o, 0x1D, b3313_s32(w))
end

-- B3313 boss movement helpers (target position in fields 0x1E-0x20, target yaw in 0x21)
local function tgt_set(o, x, y, z)
    obj_set_field_f32(o, 0x1E, x); obj_set_field_f32(o, 0x1F, y); obj_set_field_f32(o, 0x20, z)
end
local function tgt_yaw(o)                     -- 80405220
    obj_set_field_s32(o, 0x21, atan2s(obj_get_field_f32(o, 0x20) - o.oPosZ, obj_get_field_f32(o, 0x1E) - o.oPosX))
end
local function tgt_vel(o, speed)              -- 80405200
    local dx = obj_get_field_f32(o, 0x1E) - o.oPosX
    local dy = obj_get_field_f32(o, 0x1F) - o.oPosY
    local dz = obj_get_field_f32(o, 0x20) - o.oPosZ
    local pitch = atan2s(math.sqrt(dx * dx + dz * dz), dy)
    local yaw = atan2s(dz, dx)
    local h = speed * coss(pitch)
    o.oVelY = speed * sins(pitch)
    o.oVelX = h * sins(yaw)
    o.oVelZ = h * coss(yaw)
    o.oForwardVel = speed
end
local function tgt_arrive(o)                  -- 80405208
    local tx, ty, tz = obj_get_field_f32(o, 0x1E), obj_get_field_f32(o, 0x1F), obj_get_field_f32(o, 0x20)
    local dx, dy, dz = tx - o.oPosX, ty - o.oPosY, tz - o.oPosZ
    if math.sqrt(dx * dx + dy * dy + dz * dz) <= o.oForwardVel then
        o.oVelX, o.oVelY, o.oVelZ, o.oForwardVel = 0, 0, 0, 0
        o.oPosX, o.oPosY, o.oPosZ = tx, ty, tz
        return true
    end
    return false
end
local function chance(pct) return random_float() < pct / 100.0 end   -- 80405228
local function on_default_floor(o) return o.oFloor ~= nil and o.oFloor.type == 0 end

-- 80405230 (804054F8): giant Fly Guy boss (Cool, Cool Mountain). Hovers around the arena,
-- chases Mario, swoops at him and charges in straight lines, dropping fireballs
-- (bhvB3313_80405298). Kick or punch it (or ground-pound it while it charges) to damage it;
-- after 17 damage it falls, and a star appears. (bhvB3313_00405260)
local function flyguy_boss_drop(o, H)
    local n = fbyte(o, 0)
    if n >= (H >> 1) then return end
    cur_obj_play_sound_2(0x5055FF81)
    fbyte_set(o, 0, n + 1)
    local bid = b3313_bhv_id(0x80405298)
    if bid == nil then return end
    local yaw = o.header.gfx.angle.y
    local d = 54.0 + o.oForwardVel
    spawn_non_sync_object(bid, b3313_model(0xCB),
        o.oPosX + d * sins(yaw), o.oPosY + 70.0, o.oPosZ + d * coss(yaw), function(c)
            c.parentObj = o
            obj_copy_angle(c, o)
            obj_set_field_s32(c, 0x1D, H >> 1)
        end)
end

local function flyguy_boss_bob(o)
    local p = fbyte(o, 3)
    fbyte_set(o, 3, p + 1)
    local d = -3.0 * coss((p & 0x7F) * 0x200)
    o.oB3313F47 = o.oB3313F47 + d
    o.oPosY = o.oPosY + d
end

function b3313_fn_80405230(o)
    o.oFloor = cur_obj_update_floor_height_and_get_floor()
    local m = gMarioStates[0]
    local H, S, T = o.oHealth, o.oSubAction, obj_get_field_s32(o, 0x30)
    local act = o.oAction
    local after = "check"         -- "check" (attack check only) or "bob" (bob, then check)
    local drop = false

    if act == 1 then
        -- chase Mario horizontally
        obj_set_field_s32(o, 0x1C, 0x04200000)
        tgt_set(o, m.pos.x, o.oPosY, m.pos.z)
        o.oForwardVel = H + 12
        tgt_yaw(o)
        cur_obj_rotate_yaw_toward(b3313_s16(obj_get_field_s32(o, 0x21)), H * 64 + 0x200)
        obj_move_xyz_using_fvel_and_yaw(o)
        if T == H * 16 + 0xF0 then o.oAction = 2 end
        if T % 48 == 0 and chance(H * 4 + 30) then drop = true end
        after = drop and "check" or "bob"
    elseif act == 2 then
        -- swoop down at Mario and back up
        obj_set_field_s32(o, 0x1C, 0x06200000)
        local swoop = S >= 2
        if S <= 0 then
            o.oSubAction = 1
            tgt_set(o, m.pos.x, m.pos.y, m.pos.z)
            tgt_yaw(o)
        end
        if S <= 1 then
            if cur_obj_rotate_yaw_toward(b3313_s16(obj_get_field_s32(o, 0x21)), 0x400 << fbyte(o, 2)) ~= 0 then
                o.oSubAction = 2
                obj_set_field_s32(o, 0x30, 0)
                swoop = true
            end
        end
        if swoop then
            cur_obj_play_sound_2(0x1417FF01)
            local t = obj_get_field_s32(o, 0x30)
            o.oVelY = -11.0 * coss(t * 0x200)
            o.oForwardVel = (((o.oHealth & 0xFFFFFFFF) >> 1) + 15) * sins(t * 0x200)
            cur_obj_move_using_vel()
            obj_move_xyz_using_fvel_and_yaw(o)
            if H >= 8 and t == 0x22 then
                drop = true
            elseif t == 0x40 then
                local limit = (H < 5) and 0 or ((H < 12) and 1 or 2)
                if fbyte(o, 2) == limit then
                    fbyte_set(o, 2, 0)
                    o.oAction = 5
                else
                    fbyte_set(o, 2, fbyte(o, 2) + 1)
                    o.oSubAction = 0
                end
            end
        end
    elseif act == 3 then
        -- fly away from Mario to the arena's edge, drop down, then charge back and forth
        local handled = false
        if S <= 0 then
            o.oSubAction = 1
            obj_set_field_s32(o, 0x21, o.oAngleToMario ~ 0x8000)
            o.oForwardVel = 50
        end
        if S <= 1 then
            cur_obj_rotate_yaw_toward(b3313_s16(obj_get_field_s32(o, 0x21)), o.oHealth * 64 + 0x600)
            obj_move_xyz_using_fvel_and_yaw(o)
            obj_set_field_s32(o, 0x1C, 0x04200000)
            if on_default_floor(o) then
                after = "bob"; handled = true
            else
                o.oSubAction = 2
            end
        end
        if not handled and S <= 2 then
            obj_set_field_s32(o, 0x21, o.oAngleToMario)
            tgt_set(o, o.oPosX, o.oHomeY - 400.0, o.oPosZ)
            cur_obj_rotate_yaw_toward(b3313_s16(o.oAngleToMario), 0x800)
            obj_face_pitch_approach(0x3800, 0x580)
            tgt_vel(o, 20.0)
            obj_set_field_s32(o, 0x1C, 0)
            cur_obj_move_using_vel()
            o.hitboxHeight = 112; o.hurtboxHeight = 112
            if tgt_arrive(o) then
                o.oSubAction = 3
                obj_set_field_s32(o, 0x30, 0)
                cur_obj_play_sound_2(0x0556FF81)
            else
                handled = true
            end
        end
        if not handled and S <= 3 then
            o.oDamageOrCoinValue = 2
            o.oForwardVel = 100 + fbyte(o, 2) * 16
            obj_move_xyz_using_fvel_and_yaw(o)
            obj_set_field_s32(o, 0x1C, 0x00000100)
            local t = obj_get_field_s32(o, 0x30)
            if t > 6 then
                if t == 8 then
                    fbyte_set(o, 3, fbyte(o, 3) + 1)
                    drop = true
                elseif not on_default_floor(o) then
                    fbyte_set(o, 2, fbyte(o, 2) + 1)
                    obj_set_field_s32(o, 0x21, o.oAngleToMario)
                    o.oSubAction = 4
                end
            end
            handled = true
        end
        if not handled then
            fbyte_set(o, 3, 0)
            local n = fbyte(o, 2)
            if n ~= 8 then
                obj_set_field_s32(o, 0x1C, 0)
                if cur_obj_rotate_yaw_toward(b3313_s16(obj_get_field_s32(o, 0x21)), n * 512 + 0x800) ~= 0 then
                    o.oSubAction = 3
                    cur_obj_play_sound_2(0x0556FF81)
                    obj_set_field_s32(o, 0x30, 0)
                end
            else
                -- done charging: rise back to hover height
                obj_set_field_s32(o, 0x1C, 0x04200000)
                o.hitboxHeight = 224; o.hurtboxHeight = 224
                tgt_set(o, o.oPosX, o.oHomeY, o.oPosZ)
                obj_face_pitch_approach(0, 0x580)
                tgt_vel(o, 20.0)
                cur_obj_move_using_vel()
                o.oDamageOrCoinValue = 1
                if tgt_arrive(o) then
                    fbyte_set(o, 2, 0)
                    o.oAction = 1
                end
            end
        end
    elseif act == 4 then
        -- defeated
        o.oIntangibleTimer = 256
        o.oVelX = o.oVelX / 1.0546875
        o.oVelY = o.oVelY / 1.0546875
        o.oVelZ = o.oVelZ / 1.0546875
        o.oForwardVel = o.oForwardVel / 1.0546875
        if T > 90 then
            spawn_default_star(m.pos.x, o.oHomeY, m.pos.z)
            spawn_mist_particles()
            cur_obj_play_sound_2(0x5060FF81)
            o.activeFlags = ACTIVE_FLAG_DEACTIVATED
        end
    elseif act == 5 then
        -- wander, then pick the next attack
        obj_set_field_s32(o, 0x1C, 0x04200000)
        if S <= 0 then
            o.oSubAction = 1
            o.oVelX, o.oVelY, o.oVelZ = 0, 0, 0
            o.oForwardVel = H + 8
            obj_set_field_s32(o, 0x21, random_u16())
            obj_set_field_s32(o, 0x30, 0)
        end
        cur_obj_rotate_yaw_toward(b3313_s16(obj_get_field_s32(o, 0x21)), H * 64 + 0x200)
        obj_move_xyz_using_fvel_and_yaw(o)
        local pick = true
        if on_default_floor(o) then
            pick = false
            if obj_get_field_s32(o, 0x30) == 45 then
                o.oSubAction = 0
                pick = chance(H * 4 + 20)
            end
        end
        if pick then
            if H >= 10 and chance(50) then o.oAction = 3 else o.oAction = 1 end
        end
        after = "bob"
    elseif act == 6 then
        -- hit: return to hover height
        tgt_set(o, o.oPosX, o.oHomeY + o.oB3313F47, o.oPosZ)
        tgt_vel(o, 20.0)
        cur_obj_move_using_vel()
        if tgt_arrive(o) then o.oAction = 5 end
    else
        o.hurtboxRadius = o.hitboxRadius
        o.hurtboxHeight = o.hitboxHeight
        o.oPosY = o.oFloorHeight + 500.0
        o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ
        o.oAction = 5
        o.oHealth = 0
        return
    end

    if drop then flyguy_boss_drop(o, H)
    elseif after == "bob" then flyguy_boss_bob(o) end

    boss_flicker(o)
    local r = boss_attack_check(o)
    if r < 0 then
        take_damage_and_knock_back(m, o)
    elseif r == 1 then
        cur_obj_play_sound_2(0x5463FF81)
        o.oHealth = o.oHealth + 2
        o.oIntangibleTimer = 60
        o.oAction = 6
        m.forwardVel = -m.forwardVel
    elseif r == 2 then
        cur_obj_play_sound_2(0x5462FF81)
        o.oHealth = o.oHealth + 1
        o.oIntangibleTimer = 100
    elseif r == 3 then
        cur_obj_play_sound_2(0x5463FF81)
        o.oHealth = o.oHealth + 2
        o.oIntangibleTimer = 20
    end
    if o.oAction ~= o.oPrevAction then obj_set_field_s32(o, 0x30, 0)
    else obj_set_field_s32(o, 0x30, obj_get_field_s32(o, 0x30) + 1) end
    if H >= 17 then
        o.oAction = 4
        fadeout_level_music(0x5A)
    end
end

-- 80405238 (80405CFC): the boss's fireball: homes in on Mario while falling; on the ground
-- it bursts into blue flames. (bhvB3313_80405298)
function b3313_fn_80405238(o)
    o.oFloor = cur_obj_update_floor_height_and_get_floor()
    local m = gMarioStates[0]
    local yaw = atan2s(m.pos.z - o.oPosZ, m.pos.x - o.oPosX)
    obj_set_field_s32(o, 0x21, yaw)
    o.oForwardVel = obj_get_field_s32(o, 0x1D) + 10
    cur_obj_rotate_yaw_toward(yaw, 0x300)
    obj_move_xyz_using_fvel_and_yaw(o)
    o.oVelY = -1.875
    cur_obj_move_using_vel()
    if o.oPosY < o.oFloorHeight + 25.0 then
        local p = o.parentObj
        if p ~= nil and p ~= o and p.activeFlags ~= ACTIVE_FLAG_DEACTIVATED
            and get_id_from_behavior(p.behavior) == bhvB3313_00405260 then
            fbyte_set(p, 0, fbyte(p, 0) - 1)
        end
        spawn_non_sync_object(id_bhvBlueFlamesGroup, b3313_model(0xCB), o.oPosX, o.oPosY, o.oPosZ, function(c)
            obj_copy_angle(c, o)
        end)
        o.activeFlags = ACTIVE_FLAG_DEACTIVATED
        cur_obj_play_sound_2(0x1410FF01)
    end
end

-- 807F20A0: the trap in the "Jumpscare Entity" area (Bowser 1 fight slot, area 10). B3313 holds Mario in place
-- with the screen shaking, then deliberately crashes the game after 79 frames. The port
-- can't (and shouldn't) crash sm64coopdx: it fakes the crash for the local player with a
-- silent black screen, then sends them back to the start, as resetting the console would.
-- (bhvB3313_1F0014F0)
B3313.fakeCrash = 0
function b3313_fn_807F20A0(o)
    cur_obj_shake_screen(SHAKE_POS_SMALL)
    local n = obj_get_field_s32(o, 0x02)
    if n >= 0x4F then
        if B3313.fakeCrash == 0 then B3313.fakeCrash = 1 end
        return
    end
    local m = gMarioStates[0]
    m.freeze = 2
    m.pos.x, m.pos.y, m.pos.z = -3488.0, 0.0, -21760.0
    local l = gLakituState
    l.curPos.x, l.curPos.y, l.curPos.z = -3488.0, 1024.0, -12480.0
    l.goalPos.x, l.goalPos.y, l.goalPos.z = -3488.0, 1024.0, -12480.0
    obj_set_field_s32(o, 0x02, n + 1)
    if o.oB3313F04 == 0 then
        o.oB3313F04 = 1
        cur_obj_play_sound_2(0x243A8081)
    end
end

hook_event(HOOK_UPDATE, function()
    local t = B3313.fakeCrash
    if t == 0 then return end
    B3313.fakeCrash = t + 1
    gMarioStates[0].freeze = 2
    if t == 1 then
        hud_hide()
        local seq = get_current_background_music()
        if seq ~= nil and seq ~= 0 then stop_background_music(seq) end
    elseif t == 150 then
        B3313.fakeCrash = 0
        hud_show()
        warp_to_start_level()
    end
end)

hook_event(HOOK_ON_HUD_RENDER, function()
    if B3313.fakeCrash == 0 then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_color(0, 0, 0, 255)
    djui_hud_render_rect(0, 0, djui_hud_get_screen_width() + 2, djui_hud_get_screen_height() + 2)
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    if B3313.fakeCrash ~= 0 then B3313.fakeCrash = 0; hud_show() end
end)

-- 807F21E0: Rainbow Ride button. Standing on it squashes it and moves a platform
-- (bhvB3313_130063D0) to (4812, -1290, 1755). (bhvB3313_1F001520)
local function any_mario_pressing(o)
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        if gNetworkPlayers[i].connected and m.marioObj ~= nil and m.marioObj.platform == o
            and (m.action & ACT_FLAG_SWIMMING) == 0
            and lateral_dist_between_objects(o, m.marioObj) < 127.5 then
            return true
        end
    end
    return false
end
function b3313_fn_807F21E0(o)
    local a = o.oAction
    if a == 0 then
        local model = b3313_model(0xCF)
        if obj_has_model_extended(o, model) == 0 then obj_set_model_extended(o, model) end
        cur_obj_scale(1.5)
        if any_mario_pressing(o) then o.oAction = 1 end
    elseif a == 1 then
        cur_obj_scale_over_time(2, 3, 1.5, 0.2)
        if o.oTimer == 3 then
            cur_obj_play_sound_2(0x803EC081)
            o.oAction = 2
            cur_obj_shake_screen(SHAKE_POS_SMALL)
        end
    elseif a == 2 then
        local bid = b3313_bhv_id(0x130063D0)
        local p = bid and obj_get_nearest_object_with_behavior_id(o, bid)
        if p ~= nil and (math.abs(p.oPosX - 4812) > 1 or math.abs(p.oPosY + 1290) > 1 or math.abs(p.oPosZ - 1755) > 1) then
            spawn_non_sync_object(bid, b3313_model(8), 4812.0, -1290.0, 1755.0, function(c)
                obj_copy_angle(c, o)
            end)
            obj_mark_for_deletion(p)
        end
    elseif a == 3 then
        cur_obj_scale_over_time(2, 3, 0.2, 1.5)
        if o.oTimer == 3 then o.oAction = 0 end
    elseif a == 4 then
        if cur_obj_is_mario_on_platform() == 0 then o.oAction = 3 end
    end
end

-- B3313's sentinel Mr. I (80560090) and its line-of-sight probe (80560404).
-- Field use (as in B3313): 0xF6 sweep target yaw, 0xF8 look-around toggle, 0xFA sweep speed,
-- 0xFC sweep direction, 0x100 probes that reached Mario, 0x102 probes that hit a wall,
-- 0x110 blink, 0x114 "Mario is in view".
local function h16_get(o, off)            -- s16 at byte offset off (0x88-based fields)
    local f = (off - 0x88) // 4
    local w = obj_get_field_s32(o, f) & 0xFFFFFFFF
    local v = ((off & 2) == 0) and (w >> 16) or (w & 0xFFFF)
    return b3313_s16(v)
end
local function h16_set(o, off, v)
    local f = (off - 0x88) // 4
    local w = obj_get_field_s32(o, f) & 0xFFFFFFFF
    if (off & 2) == 0 then w = (w & 0x0000FFFF) | ((v & 0xFFFF) << 16)
    else w = (w & 0xFFFF0000) | (v & 0xFFFF) end
    obj_set_field_s32(o, f, b3313_s32(w))
end

local function sentinel_mario()
    local mo = gMarioStates[0].marioObj
    return mo
end

local function sentinel_spawn_probe(o, yaw, fresh)
    local bid = b3313_bhv_id(0x80560068)
    if bid == nil then return end
    local c = spawn_non_sync_object(bid, E_MODEL_NONE, o.oPosX, o.oPosY, o.oPosZ, function(c)
        c.parentObj = o
        obj_copy_angle(c, o)
        c.oMoveAngleYaw = yaw
        if fresh then obj_set_field_s32(c, 0x1E, 1) end
    end)
    return c
end

-- 80560350: look for Mario; launch probes while he is in front of the eye
local function sentinel_look(o)
    local mo = sentinel_mario()
    if mo == nil then return end
    if dist_between_objects(o, mo) > 2496 or o.oInteractStatus ~= 0 or o.oAction == 2 then return end
    local toMario = obj_angle_to_object(o, mo)
    local d = math.abs((o.oMoveAngleYaw & 0xFFFF) - (toMario & 0xFFFF))
    obj_set_field_s32(o, 0x20, d)
    obj_set_field_s32(o, 0x23, 0)
    if d < 0x2800 then
        obj_set_field_s32(o, 0x23, 1)
        if (o.oTimer & 1) == 0 then sentinel_spawn_probe(o, toMario, true) end
    end
    if h16_get(o, 0x100) ~= 0 then
        o.oAction = 2
        obj_set_field_s32(o, 0x1E, 0)
    end
end

local function sentinel_turn(o, dir, speed)
    local yaw = o.oMoveAngleYaw & 0xFFFF
    if dir ~= 0 then yaw = yaw + speed else yaw = yaw - speed end
    o.oMoveAngleYaw = b3313_s16(yaw & 0xFFFF)
end

-- 80560090 (bhvB3313_1F000000): sweeps its gaze left and right. When Mario is in view it
-- fires invisible probes at him; once two get through without hitting a wall, it charges
-- straight at him, and its touch is instantly fatal.
function b3313_fn_80560090(o)
    local m = gMarioStates[0]
    local mo = m.marioObj
    sentinel_look(o)
    -- B3313 makes the eye a silent "coin": its touch while charging kills Mario
    if o.oB3313Ref ~= 0 and o.oInteractStatus == 0 and mo ~= nil and o.oIntangibleTimer == 0
        and obj_check_hitbox_overlap(o, mo) then
        o.oInteractStatus = INT_STATUS_INTERACTED
    end
    if o.oInteractStatus ~= 0 then
        m.health = 0
        o.oAction = 1
        o.oForwardVel = 0
        -- (B3313 leaves the eye in this state until the level reloads; in co-op the level
        -- doesn't reload for everyone, so the eye resets and keeps watching)
        o.oInteractStatus = 0
        o.oB3313Ref = 0
        obj_set_field_s32(o, 0x1E, 0)
    end

    local dist = (mo ~= nil) and dist_between_objects(o, mo) or 1e9
    local act = o.oAction
    if act == 0 then
        o.oForwardVel = 0
        local tgt = 0
        if dist <= 2496 then tgt = (h16_get(o, 0xFC) ~= 0) and -0x4000 or 0x4000 end
        h16_set(o, 0xF6, tgt)
        local d = math.abs((o.oMoveAngleYaw & 0xFFFF) - (tgt & 0xFFFF))
        h16_set(o, 0xFA, (d >> 3) + 0x40)
        if d < 0x400 then
            h16_set(o, 0xFC, h16_get(o, 0xFC) ~ 1)
            o.oAction = 1
            o.oIntangibleTimer = 4
        end
        sentinel_turn(o, h16_get(o, 0xFC), h16_get(o, 0xFA))
    elseif act == 1 then
        if h16_get(o, 0xF6) == 0 then
            o.oMoveAngleYaw = 0
            if dist <= 2496 then o.oAction = 0 end
        elseif o.oTimer >= 48 then
            o.oIntangibleTimer = 0
            h16_set(o, 0xF8, 0)
            o.oAction = 0
        elseif o.oSubAction == 0 then
            if o.oIntangibleTimer == 0 then
                o.oIntangibleTimer = 16
                o.oSubAction = 1
                h16_set(o, 0xF8, h16_get(o, 0xF8) ~ 1)
            end
            sentinel_turn(o, (h16_get(o, 0xF8) == 0) and 1 or 0, 0x800)
        elseif o.oIntangibleTimer == 0 then
            o.oIntangibleTimer = 4 << h16_get(o, 0xF8)
            o.oSubAction = 0
        end
    elseif act == 2 then
        obj_set_field_s32(o, 0x23, 1)
        if mo ~= nil then o.oMoveAngleYaw = obj_angle_to_object(o, mo) end
        if h16_get(o, 0x100) >= 2 then
            o.oForwardVel = 64
            o.hitboxRadius = 80
            o.hitboxHeight = 80
            o.oIntangibleTimer = 0
            o.oB3313Ref = 1
            cur_obj_play_sound_1(0x4004FF01)
        elseif h16_get(o, 0x102) >= 3 then
            obj_set_field_s32(o, 0x1E, 0)
            o.oAction = 1
        elseif o.oTimer % 15 == 0 then
            sentinel_spawn_probe(o, o.oMoveAngleYaw, false)
        end
    elseif act == 3 then
        sentinel_look(o)
    end

    -- random blink
    if o.oMrIUnk110 == 0 and random_u16() % 127 == 0 then o.oMrIUnk110 = 1 end
end

-- 80560404 (bhvB3313_80560068): the sentinel's invisible probe. Homes in on Mario at his
-- height; reaching him counts as a sighting, a wall in the way counts as a miss.
function b3313_fn_80560404(o)
    local p = o.parentObj
    local mo = sentinel_mario()
    if p == nil or p == o or mo == nil or obj_get_field_s32(p, 0x23) == 0
        or (p.oAction == 2 and obj_get_field_s32(o, 0x1E) ~= 0) then
        obj_mark_for_deletion(o)
        return
    end
    o.oInteractType = 0
    o.oForwardVel = 50
    o.oMoveAngleYaw = obj_angle_to_object(o, mo)
    o.oPosY = mo.oPosY
    o.oIntangibleTimer = 0
    o.hitboxHeight = 50
    o.hitboxRadius = 50
    local pos = { x = o.oPosX, y = o.oPosY, z = o.oPosZ }
    local wall = resolve_and_return_wall_collisions(pos, 0, 50)
    o.oPosX, o.oPosY, o.oPosZ = pos.x, pos.y, pos.z
    if wall ~= nil then
        h16_set(p, 0x102, h16_get(p, 0x102) + 1)
        h16_set(p, 0x100, 0)
        obj_mark_for_deletion(o)
    elseif obj_check_hitbox_overlap(o, mo) then
        h16_set(p, 0x100, h16_get(p, 0x100) + 1)
        h16_set(p, 0x102, 0)
        obj_mark_for_deletion(o)
    end
end

-- 80561224 (bhvB3313_1F001200): the giant Mr. I in Hazy Maze Cave. Rises out of the pit for
-- 200 frames, stares and blinks for 200 more, then lunges; half a second later the floor
-- under Mario becomes an instant warp, sending him to another area.
function b3313_fn_80561224(o)
    if (o.oBehParams >> 24) & 0xFF == 0 then
        o.oBehParams = (o.oBehParams & 0x00FFFFFF) | 0x01000000
        o.header.gfx.scale.x, o.header.gfx.scale.y, o.header.gfx.scale.z = 8.0, 8.0, 8.0
        o.header.gfx.node.flags = GRAPH_RENDER_ACTIVE | GRAPH_RENDER_BILLBOARD | GRAPH_RENDER_HAS_ANIMATION
    end
    local a = o.oAction
    if a == 1 then
        if o.oTimer >= 200 then o.oAction = 2
        elseif (o.oTimer & 0xF) == 0 then o.oMrIUnk110 = 1 end
    elseif a == 2 then
        if o.oTimer >= 32 then
            local floor = gMarioStates[0].floor
            if floor ~= nil then floor.type = SURFACE_INSTANT_WARP_1B end
            o.activeFlags = ACTIVE_FLAG_DEACTIVATED
        end
        o.oForwardVel = o.oForwardVel + 3.0
        cur_obj_play_sound_1(0x4004FF01)
    else
        if o.oTimer >= 200 then o.oAction = 1
        else o.oPosY = o.oPosY + 10.0 end
    end
end

-- 80561E28 (bhvB3313_1F001E00): a Mr. I that drifts past, bobbing, once Mario comes near;
-- it vanishes after (top 16 bits of behParams) frames.
function b3313_fn_80561E28(o)
    o.oDrawingDistance = 8000
    o.header.gfx.node.flags = o.header.gfx.node.flags | GRAPH_RENDER_BILLBOARD
    if o.oAction ~= 0 then
        if o.oTimer == 0 then
            obj_set_field_f32(o, 0x1B, 100.0)
            obj_set_field_f32(o, 0x1C, 800.0)
        end
        local ang = math.floor((o.oTimer & 0xFFFF) * obj_get_field_f32(o, 0x1C)) & 0xFFFF
        o.oPosY = sins(ang) * obj_get_field_f32(o, 0x1B) + o.oHomeY
        o.oForwardVel = 16
        if o.oTimer >= ((o.oBehParams >> 16) & 0xFFFF) then o.activeFlags = ACTIVE_FLAG_DEACTIVATED end
    end
    local mo = gMarioStates[0].marioObj
    if mo ~= nil and math.abs(mo.oPosZ - o.oPosZ) <= 2000 and math.abs(o.oPosY - mo.oPosY) <= 500 then
        o.oAction = 1
    end
end
