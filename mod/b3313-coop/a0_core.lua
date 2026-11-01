-- B3313 port core helpers (loaded first: files load in alphabetical order)

B3313 = { init = {}, loop = {}, data = {} }
B3313_CUSTOM_ANIMS = {}
B3313_ANIM_START = {}         -- custom anim name -> {startFrame, flags}
B3313_ANIM_TABLE_NAMES = {}   -- index -> custom anim table name (stored per object as an index)

define_custom_obj_fields({
    oB3313Delay = 'u32',
    oB3313AnimTbl = 'u32',
    oB3313Ref = 'u32',
    oB3313F04 = 's32',     -- B3313's object field 0x04 (coopdx uses that slot for oSyncID)
    oB3313F47 = 'f32',     -- B3313's object field 0x47 (coopdx uses that slot for oSyncDeath)
})

function b3313_level()
    return gNetworkPlayers[0].currLevelNum
end

local function anim_table_index(name)
    for i, n in ipairs(B3313_ANIM_TABLE_NAMES) do
        if n == name then return i end
    end
    B3313_ANIM_TABLE_NAMES[#B3313_ANIM_TABLE_NAMES + 1] = name
    return #B3313_ANIM_TABLE_NAMES
end

function b3313_load_collision(o, data, addr)
    local t = data and data[addr]
    local name = t and t[b3313_level()]
    if name ~= nil then
        o.collisionData = smlua_collision_util_get(name)
    end
end

function b3313_load_anims(o, data, addr)
    local t = data and data[addr]
    local e = t and t[b3313_level()]
    o.oB3313AnimTbl = 0
    if e == nil then return end
    if e[1] == "vanilla" then
        local a = gObjectAnimations[e[2]]
        if a ~= nil then o.oAnimations = a end
    else
        o.oB3313AnimTbl = anim_table_index(e[2])
    end
end

-- Start an object animation by index, from either a vanilla table (oAnimations) or a
-- B3313 custom table. Like geo_obj_init_animation, the frame only resets when the
-- animation actually changes, so this is safe to call every frame.
function b3313_animate(o, index)
    o.oSoundStateID = index
    if o.oB3313AnimTbl ~= 0 then
        local tbl = B3313_CUSTOM_ANIMS[B3313_ANIM_TABLE_NAMES[o.oB3313AnimTbl]]
        local name = tbl and tbl[index + 1]
        if name ~= nil and smlua_anim_util_get_current_animation_name(o) ~= name then
            smlua_anim_util_set_animation(o, name)
            local st = B3313_ANIM_START[name]
            local ai = o.header.gfx.animInfo
            if st ~= nil then
                ai.animFrame = st[1] + (((st[2] & ANIM_FLAG_FORWARD) ~= 0) and 1 or -1)
            else
                ai.animFrame = 0
            end
            ai.animAccel = 0
            ai.animYTrans = 0
        end
        return
    end
    if o.oAnimations ~= nil then
        obj_init_animation_with_sound(o, o.oAnimations, index)
    end
end

function b3313_drop_to_floor(o)
    local y = find_floor_height(o.oPosX, o.oPosY + 200.0, o.oPosZ)
    o.oPosY = y
    o.oMoveFlags = o.oMoveFlags | OBJ_MOVE_ON_GROUND
end

function b3313_spawn_child(o, model, bhvId, param)
    local c = spawn_non_sync_object(bhvId, model, o.oPosX, o.oPosY, o.oPosZ, function(c)
        c.parentObj = o
        c.oBehParams2ndByte = param
        obj_copy_angle(c, o)
    end)
    return c
end

function b3313_pss_begin_slide(o)
    -- vanilla pss_begin_slide: show + start the level timer (run by b_natives_ported.lua,
    -- since level_control_timer isn't available to Lua)
    if (gHudDisplay.flags & HUD_DISPLAY_FLAG_TIMER) == 0 then b3313_timer_start() end
end

-- Raw model id (as used by B3313's code and behavior scripts) -> extended model id for
-- the current level. Levels load their own models into slots, see a2_models.lua.
local sModelCache = {}
local sModelFallback = { [102] = "E_MODEL_MR_I_IRIS", [103] = "E_MODEL_MR_I" }
function b3313_model(raw)
    if raw == nil or raw == 0 then return E_MODEL_NONE end
    local t = B3313_MODELS and B3313_MODELS[b3313_level()]
    local name = (t and t[raw]) or (B3313_MAIN_MODELS and B3313_MAIN_MODELS[raw]) or sModelFallback[raw]
    if name == nil then return E_MODEL_NONE end
    local id = sModelCache[name]
    if id == nil then
        if string.sub(name, 1, 8) == "E_MODEL_" then
            id = _G[name]
        else
            id = smlua_model_util_get_id(name)
        end
        if id == nil or id == E_MODEL_ERROR_MODEL then id = E_MODEL_NONE end
        sModelCache[name] = id
    end
    return id
end

-- B3313 custom global variables (addresses in the hack's RAM), shared by ported routines
B3313.g = {}

-- behavior segment address (0x13xxxxxx / 0x1Fxxxxxx / RAM) -> behavior id
function b3313_bhv_id(addr)
    local v = B3313_VANILLA_BHV and B3313_VANILLA_BHV[addr]
    if v ~= nil then return v end
    return _G[string.format("bhvB3313_%08X", addr)]
end

-- true when any connected player's Mario is standing on object o
function b3313_mario_on_platform(o)
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        if m ~= nil and m.marioObj ~= nil and gNetworkPlayers[i].connected and m.marioObj.platform == o then
            return true
        end
    end
    return false
end

-- obj_set_hitbox with an inline ObjectHitbox definition
function b3313_set_hitbox(o, interactType, downOffset, damageOrCoinValue, health, numLootCoins, radius, height, hurtboxRadius, hurtboxHeight)
    local h = get_temp_object_hitbox()
    h.interactType = interactType
    h.downOffset = downOffset
    h.damageOrCoinValue = damageOrCoinValue
    h.health = health
    h.numLootCoins = numLootCoins
    h.radius = radius
    h.height = height
    h.hurtboxRadius = hurtboxRadius
    h.hurtboxHeight = hurtboxHeight
    obj_set_hitbox(o, h)
end

-- s32 wrap helper (N64 integer overflow)
function b3313_s32(x)
    x = x & 0xFFFFFFFF
    if x >= 0x80000000 then x = x - 0x100000000 end
    return x
end

-- s16 wrap helper for angle math done in 32-bit on N64
function b3313_s16(x)
    x = x & 0xFFFF
    if x >= 0x8000 then x = x - 0x10000 end
    return x
end
