-- Beta Mario (your beeie_mario_geo model, anims and voice clips).
-- Plain vanilla moveset on purpose: Mario stays "normal", the castle does the creeping.

_G.FBTB = _G.FBTB or {}
local F = _G.FBTB

E_MODEL_BEEIE_MARIO = smlua_model_util_get_id("beeie_mario_geo")
F.betaModel = E_MODEL_BEEIE_MARIO

------------------------------------------------------------------
-- voice clips (files live in /sound)
------------------------------------------------------------------
F.samples = {
    attacked = audio_sample_load("sound_beta_mario_attacked.ogg"),
    eeuh     = audio_sample_load("sound_beta_mario_eeuh.ogg"),
    hawh     = audio_sample_load("sound_beta_mario_hawh.ogg"),
    jump_hoo = audio_sample_load("sound_beta_mario_jump_hoo.ogg"),
    jump_wah = audio_sample_load("sound_beta_mario_jump_wah.ogg"),
    jump_yah = audio_sample_load("sound_beta_mario_jump_yah.ogg"),
    on_fire  = audio_sample_load("sound_beta_mario_on_fire.ogg"),
    uh       = audio_sample_load("sound_beta_mario_uh.ogg"),
    woah     = audio_sample_load("sound_beta_mario_woah.ogg"),
    yahaa    = audio_sample_load("sound_beta_mario_yahaa.ogg"),
    yeah     = audio_sample_load("sound_beta_mario_yeah.ogg"),
    none     = audio_sample_load("sound_beta_mario_none.ogg"),
    woosh    = audio_sample_load("sound_beta_mario_woosh.ogg"),
}
local S = F.samples

-- vanilla character sound -> beta clip(s). A table = pick one at random.
-- Swap these around if a clip lands on the wrong action.
local VOICE = {}
local function map(sound, ...)
    if sound == nil then return end          -- constant missing in this coopdx build
    local pool = {}
    for _, clip in ipairs({ ... }) do if clip then table.insert(pool, clip) end end
    if #pool > 0 then VOICE[sound] = pool end
end
map(CHAR_SOUND_ATTACKED,          S.attacked)
map(CHAR_SOUND_ON_FIRE,           S.on_fire)
map(CHAR_SOUND_UH,                S.uh)
map(CHAR_SOUND_EEUH,              S.eeuh)
map(CHAR_SOUND_WHOA,              S.woah)
map(CHAR_SOUND_YAHOO,             S.yeah)
map(CHAR_SOUND_YAHOO_WAHA_YIPPEE, S.yahaa)
map(CHAR_SOUND_YAH_WAH_HOO,       S.jump_yah, S.jump_wah, S.jump_hoo)
map(CHAR_SOUND_HOOHOO,            S.jump_hoo)
map(CHAR_SOUND_WAH2,              S.jump_wah)
map(CHAR_SOUND_GROUND_POUND_WAH,  S.hawh)
map(CHAR_SOUND_PUNCH_YAH,         S.woosh)
map(CHAR_SOUND_PUNCH_WAH,         S.none)
map(CHAR_SOUND_PUNCH_HOO,         S.none)

local function is_beta(m)
    if F.sonicActive and F.sonicModel and F.sonicModel ~= 0 then return false end
    return m.character.type == CT_MARIO and F.betaModel ~= nil and F.betaModel ~= 0
end

local function on_character_sound(m, characterSound)
    if not is_beta(m) then return end
    local pool = VOICE[characterSound]
    if not pool then return end
    local s = pool[math.random(#pool)]
    if not s then return end
    audio_sample_play(s, m.pos, 1.0)
    return NO_SOUND   -- cancel the vanilla voice
end
hook_event(HOOK_CHARACTER_SOUND, on_character_sound)

------------------------------------------------------------------
-- model, beta shading, beta crouch animations (anims.lua registers them)
------------------------------------------------------------------
local function on_mario_update(m)
    if not is_beta(m) then return end
    obj_set_model_extended(m.marioObj, F.betaModel)

    m.marioBodyState.shadeR = 63
    m.marioBodyState.shadeG = 63
    m.marioBodyState.shadeB = 63

    if m.action == ACT_WALKING or m.action == ACT_BUTT_SLIDE then
        m.marioBodyState.torsoAngle.x = 0
        m.marioBodyState.torsoAngle.z = 0
    end
    
    if m.action == ACT_TRIPLE_JUMP then
        set_mario_action(m, ACT_TWIRLING, 0)
    end
    
    local id = m.marioObj.header.gfx.animInfo.animID
    if id == MARIO_ANIM_STOP_CROUCHING then
        smlua_anim_util_set_animation(m.marioObj, "stop_crouching")
    elseif id == MARIO_ANIM_START_CROUCHING then
        smlua_anim_util_set_animation(m.marioObj, "start_crouching")
    elseif id == MARIO_ANIM_CROUCHING then
        smlua_anim_util_set_animation(m.marioObj, "crouching")
    end
end
hook_event(HOOK_MARIO_UPDATE, on_mario_update)
