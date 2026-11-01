-- ============================================
-- B3313 ALL BOSS FIXES
-- Overrides broken/mis-mapped boss behaviors so fights work.
-- Loads after c_behaviors.lua (z_ prefix).
-- ============================================

if not B3313 then B3313 = { init = {}, loop = {}, data = {} } end
B3313.init = B3313.init or {}
B3313.loop = B3313.loop or {}

local function spawn_boss_star(o, index)
    local x, y, z = o.oPosX, o.oPosY + 200, o.oPosZ
    local star = nil
    if spawn_default_star then
        star = spawn_default_star(x, y, z)
    elseif spawn_non_sync_object and id_bhvSpawnedStar and E_MODEL_STAR then
        star = spawn_non_sync_object(id_bhvSpawnedStar, E_MODEL_STAR, x, y, z, nil)
    end
    if star and index and index > 0 then
        star.oBehParams = (index << 24) | (star.oBehParams & 0x00FFFFFF)
    end
    return star
end

local function face_mario(o, m)
    if m and m.marioObj then
        obj_turn_toward_object(o, m.marioObj, 0x10, 0x800)
    end
end

local function dist_to_mario(o, m)
    if not m or not m.marioObj then return 99999 end
    return dist_between_objects(o, m.marioObj)
end

-- ------------------------------------------
-- KING BOB-OMB (0x13005804)
-- Was bobomb_buddy. Full grab-throw fight.
-- ------------------------------------------
B3313.init[0x13005804] = function(o)
    obj_set_field_s32(o, 0x01, obj_get_field_s32(o, 0x01) | 0x2049)
    if B3313.data[0x13005804] then
        b3313_load_anims(o, B3313.data[0x13005804], 0x0500FE30)
    end
    b3313_drop_to_floor(o)
    o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ
    o.hitboxRadius = 100
    o.hitboxHeight = 100
    o.oWallHitboxRadius = 100
    o.oGravity = 2.5
    o.oFriction = 0.9
    o.oBuoyancy = 1.5
    if INTERACT_GRABBABLE then
        o.oInteractType = INTERACT_GRABBABLE
    else
        o.oInteractType = 0x2
    end
    if INT_SUBTYPE_GRABS_MARIO then
        o.oInteractionSubtype = INT_SUBTYPE_GRABS_MARIO
    end
    o.oHealth = 3
    o.oAction = 0
    o.oForwardVel = 0
    if b3313_animate then b3313_animate(o, 0) end
end

B3313.loop[0x13005804] = function(o)
    local m = nearest_mario_state_to_object(o)
    cur_obj_update_floor_and_walls()

    -- Held / thrown by Mario
    if o.oHeldState == HELD_HELD then
        o.oAction = 10
        return
    end
    if o.oHeldState == HELD_THROWN or o.oHeldState == HELD_DROPPED then
        o.oHeldState = HELD_FREE
        o.oAction = 2
        o.oTimer = 0
        o.oForwardVel = 20
        o.oVelY = 20
    end

    if o.oAction == 0 then
        -- Chase
        face_mario(o, m)
        o.oForwardVel = 10
        cur_obj_move_standard(-78)
        if dist_to_mario(o, m) < 200 and m then
            o.oAction = 1
            o.oTimer = 0
        end
        -- Stay near home
        local dx = o.oPosX - o.oHomeX
        local dz = o.oPosZ - o.oHomeZ
        if dx * dx + dz * dz > 250000 then
            o.oAction = 3
            o.oTimer = 0
        end
    elseif o.oAction == 1 then
        -- Grab attempt
        o.oForwardVel = 0
        face_mario(o, m)
        cur_obj_move_standard(-78)
        if o.oTimer > 45 then o.oAction = 0 end
    elseif o.oAction == 2 then
        -- Stunned after throw
        cur_obj_move_standard(-78)
        if (o.oMoveFlags & OBJ_MOVE_LANDED) ~= 0 or o.oTimer > 90 then
            o.oHealth = o.oHealth - 1
            o.oForwardVel = 0
            if o.oHealth <= 0 then
                spawn_boss_star(o, (o.oBehParams >> 24) & 0xFF)
                obj_mark_for_deletion(o)
                return
            end
            o.oAction = 0
        end
    elseif o.oAction == 3 then
        -- Return home
        local angle = atan2s(o.oHomeZ - o.oPosZ, o.oHomeX - o.oPosX)
        o.oMoveAngleYaw = approach_s16_symmetric(o.oMoveAngleYaw, angle, 0x400)
        o.oForwardVel = 12
        cur_obj_move_standard(-78)
        local dx = o.oPosX - o.oHomeX
        local dz = o.oPosZ - o.oHomeZ
        if dx * dx + dz * dz < 2500 or o.oTimer > 120 then
            o.oAction = 0
        end
    elseif o.oAction == 10 then
        -- Being held — vanilla handles position
    end
end

-- ------------------------------------------
-- KING WHOMP (0x1300866C)
-- field 0x44 = 5 marks king. Ensure boss params + star on death.
-- ------------------------------------------
local whomp_prev = B3313.loop[0x1300866C]
B3313.init[0x1300866C] = function(o)
    obj_set_field_s32(o, 0x44, 5) -- king marker
    obj_set_field_s32(o, 0x01, obj_get_field_s32(o, 0x01) | 0x2049)
    if B3313.data[0x1300866C] then
        b3313_load_anims(o, B3313.data[0x1300866C], 0x06020A04)
        b3313_load_collision(o, B3313.data[0x1300866C], 0x06020A0C)
    end
    -- King Whomp is larger
    obj_scale(o, 2.0)
    if b3313_animate then b3313_animate(o, 0) end
    o.oWallHitboxRadius = 0
    o.oGravity = -4.0
    o.oBounciness = -0.5
    o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ
    o.oHealth = 3
    o.oBehParams2ndByte = 1 -- vanilla king flag
end

B3313.loop[0x1300866C] = function(o)
    if bhv_whomp_loop then
        bhv_whomp_loop()
    end
    -- If whomp is defeated (hidden / dead action), spawn star once
    if o.oAction == 9 or o.oHealth <= 0 then -- common death actions
        if o.oUnk94 ~= 99 then
            o.oUnk94 = 99
            spawn_boss_star(o, (o.oBehParams >> 24) & 0xFF)
        end
    end
end

-- ------------------------------------------
-- BIG BOO (0x1F00161C)
-- ------------------------------------------
local bigboo_loop = B3313.loop[0x1F00161C]
B3313.loop[0x1F00161C] = function(o)
    if bhv_big_boo_loop then
        bhv_big_boo_loop()
    elseif bigboo_loop then
        bigboo_loop(o)
    end
    -- Star on death
    if o.oHealth ~= nil and o.oHealth <= 0 and o.oUnk94 ~= 99 then
        o.oUnk94 = 99
        spawn_boss_star(o, (o.oBehParams >> 24) & 0xFF)
    end
end

-- ------------------------------------------
-- WIGGLER (0x1300809C, 0x130084F4)
-- ------------------------------------------
for _, addr in ipairs({ 0x1300809C, 0x130084F4 }) do
    local prev = B3313.loop[addr]
    B3313.loop[addr] = function(o)
        if bhv_wiggler_update then
            bhv_wiggler_update()
        elseif prev then
            prev(o)
        end
        if o.oHealth ~= nil and o.oHealth <= 0 and o.oUnk94 ~= 99 then
            o.oUnk94 = 99
            spawn_boss_star(o, (o.oBehParams >> 24) & 0xFF)
        end
    end
end

-- ------------------------------------------
-- GOOMBOSS-like large goomba (0x130074B8 has goomba + special interact)
-- Treat high-scale goombas as bosses: 3 hits
-- ------------------------------------------
local function make_goomba_boss(addr)
    local prevInit = B3313.init[addr]
    local prevLoop = B3313.loop[addr]
    B3313.init[addr] = function(o)
        if prevInit then prevInit(o) end
        o.oHealth = o.oHealth or 3
        if o.header and o.header.gfx and o.header.gfx.scale then
            -- if already huge, treat as boss
        end
    end
    B3313.loop[addr] = function(o)
        if bhv_goomba_update then
            bhv_goomba_update()
        elseif prevLoop then
            prevLoop(o)
        end
    end
end
make_goomba_boss(0x130074B8)
make_goomba_boss(0x130058E0)
make_goomba_boss(0x13005898)
make_goomba_boss(0x1300589C)

-- ------------------------------------------
-- CAPTAIN FLY GUY style (scaled fly guys)
-- 0x13007AD8, 0x13007B24
-- ------------------------------------------
for _, addr in ipairs({ 0x13007AD8, 0x13007B24 }) do
    local prevInit = B3313.init[addr]
    local prevLoop = B3313.loop[addr]
    B3313.init[addr] = function(o)
        if prevInit then prevInit(o) end
        o.oHealth = 5
        o.oDamageOrCoinValue = 2
    end
    B3313.loop[addr] = function(o)
        if bhv_fly_guy_update then
            bhv_fly_guy_update()
        elseif prevLoop then
            prevLoop(o)
        end
        -- Defeat: when dead
        if (o.oAction == 5 or (o.oHealth ~= nil and o.oHealth <= 0)) and o.oUnk94 ~= 99 then
            o.oUnk94 = 99
            spawn_boss_star(o, (o.oBehParams >> 24) & 0xFF)
            obj_mark_for_deletion(o)
        end
    end
end

-- ------------------------------------------
-- BULLY / CHIEF CHILLY style (0x13007BB4)
-- ------------------------------------------
do
    local prevInit = B3313.init[0x13007BB4]
    local prevLoop = B3313.loop[0x13007BB4]
    B3313.init[0x13007BB4] = function(o)
        if prevInit then prevInit(o) end
        -- Big bully if scaled up in init already
        o.oHealth = 1
    end
    B3313.loop[0x13007BB4] = function(o)
        if bhv_bully_loop then
            bhv_bully_loop()
        elseif prevLoop then
            prevLoop(o)
        end
    end
end

-- ------------------------------------------
-- Mis-mapped "buddy" objects that should fight
-- 0x130080E4 / 0x13008248 use wiggler anims but buddy AI — convert to hostile
-- ------------------------------------------
for _, addr in ipairs({ 0x130080E4, 0x13008248 }) do
    B3313.init[addr] = function(o)
        obj_set_field_s32(o, 0x01, obj_get_field_s32(o, 0x01) | 0x2049)
        if B3313.data[addr] then
            -- keep anims from data if present
            for k, _ in pairs(B3313.data[addr]) do
                if type(k) == "number" then
                    b3313_load_anims(o, B3313.data[addr], k)
                    break
                end
            end
        end
        b3313_drop_to_floor(o)
        o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ
        o.hitboxRadius = 100
        o.hitboxHeight = 80
        o.oGravity = 2.5
        o.oHealth = 3
        o.oAction = 0
        o.oInteractType = INTERACT_BOUNCE_TOP or 0x1
        if o.header and o.header.gfx then
            -- scale already set in original init path sometimes
        end
    end
    B3313.loop[addr] = function(o)
        local m = nearest_mario_state_to_object(o)
        cur_obj_update_floor_and_walls()
        face_mario(o, m)
        if o.oAction == 0 then
            o.oForwardVel = 8
            cur_obj_move_standard(-78)
            -- bounce-top hit detection via interact status
            if (o.oInteractStatus & INT_STATUS_INTERACTED) ~= 0 then
                o.oInteractStatus = 0
                o.oHealth = o.oHealth - 1
                o.oAction = 1
                o.oTimer = 0
                o.oVelY = 30
                o.oForwardVel = -15
                if o.oHealth <= 0 then
                    spawn_boss_star(o, (o.oBehParams >> 24) & 0xFF)
                    obj_mark_for_deletion(o)
                    return
                end
            end
        elseif o.oAction == 1 then
            cur_obj_move_standard(-78)
            if o.oTimer > 40 then o.oAction = 0 end
        end
    end
end

-- ------------------------------------------
-- Re-register hooks so overrides take effect
-- (hook_behavior again with same name replaces)
-- ------------------------------------------
local function rehook(addr, list, init, loop, name)
    if init or loop then
        hook_behavior(nil, list, true,
            init or B3313.init[addr],
            loop or B3313.loop[addr],
            name)
    end
end

rehook(0x13005804, OBJ_LIST_GENACTOR, B3313.init[0x13005804], B3313.loop[0x13005804], "bhvB3313_13005804")
rehook(0x1300866C, OBJ_LIST_SURFACE, B3313.init[0x1300866C], B3313.loop[0x1300866C], "bhvB3313_1300866C")
rehook(0x1F00161C, OBJ_LIST_GENACTOR, B3313.init[0x1F00161C], B3313.loop[0x1F00161C], "bhvB3313_1F00161C")
rehook(0x1300809C, OBJ_LIST_GENACTOR, B3313.init[0x1300809C], B3313.loop[0x1300809C], "bhvB3313_1300809C")
rehook(0x130084F4, OBJ_LIST_GENACTOR, B3313.init[0x130084F4], B3313.loop[0x130084F4], "bhvB3313_130084F4")
rehook(0x13007AD8, OBJ_LIST_GENACTOR, B3313.init[0x13007AD8], B3313.loop[0x13007AD8], "bhvB3313_13007AD8")
rehook(0x13007B24, OBJ_LIST_GENACTOR, B3313.init[0x13007B24], B3313.loop[0x13007B24], "bhvB3313_13007B24")
rehook(0x13007BB4, OBJ_LIST_GENACTOR, B3313.init[0x13007BB4], B3313.loop[0x13007BB4], "bhvB3313_13007BB4")
rehook(0x130080E4, OBJ_LIST_GENACTOR, B3313.init[0x130080E4], B3313.loop[0x130080E4], "bhvB3313_130080E4")
rehook(0x13008248, OBJ_LIST_GENACTOR, B3313.init[0x13008248], B3313.loop[0x13008248], "bhvB3313_13008248")

print("[B3313] Boss fixes loaded")
