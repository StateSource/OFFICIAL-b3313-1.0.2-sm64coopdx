-- name: B3313 Softlock Fix
-- version: 1.1
-- target: SM64CoopDX 1.5.1

local stuckTimer = 0
local lastAction = nil
local recoveryCooldown = 0

-- Add only action constants that exist.
local EXIT_ACTIONS = {}
local STALL_ACTIONS = {}

local function add_action(action, timeout)
    if action ~= nil then
        EXIT_ACTIONS[action] = true
        if timeout ~= nil then
            STALL_ACTIONS[action] = timeout
        end
    end
end

add_action(ACT_STAR_DANCE_EXIT, 180)
add_action(ACT_STAR_DANCE_WATER, 180)
add_action(ACT_FALL_AFTER_STAR_GRAB, 150)
add_action(ACT_EXIT_AIRBORNE, 120)
add_action(ACT_EXIT_LAND_SAVE_DIALOG, 300)
add_action(ACT_DEATH_EXIT, 150)
add_action(ACT_UNUSED_DEATH_EXIT, 150)
add_action(ACT_FALLING_DEATH_EXIT, 150)
add_action(ACT_SPECIAL_EXIT_AIRBORNE, 150)
add_action(ACT_SPECIAL_DEATH_EXIT, 150)
add_action(ACT_DISAPPEARED, 90)
add_action(ACT_IN_CANNON, 600)

local function force_idle(m)
    if not m then return end

    m.vel.x = 0
    m.vel.y = 0
    m.vel.z = 0
    m.forwardVel = 0
    m.hurtCounter = 0

    if m.health < 0x100 then
        m.health = 0x880
    end

    set_mario_action(m, ACT_IDLE, 0)
end

local function recover(m, message)
    if not m then return end

    force_idle(m)
    stuckTimer = 0
    recoveryCooldown = 90

    if message then
        djui_chat_message_create(message)
    end
end

-- Detect potentially stuck actions.
hook_event(HOOK_MARIO_UPDATE, function(m)
    if m.playerIndex ~= 0 then return end

    if recoveryCooldown > 0 then
        recoveryCooldown = recoveryCooldown - 1
        return
    end

    if m.action == lastAction then
        stuckTimer = stuckTimer + 1
    else
        stuckTimer = 0
        lastAction = m.action
    end

    local timeout = STALL_ACTIONS[m.action]

    if timeout and stuckTimer > timeout then
        recover(m, "\\#ff8800\\Softlock recovery attempted.")
    end
end)

-- Reset tracking when a level loads.
hook_event(HOOK_ON_LEVEL_INIT, function()
    stuckTimer = 0
    lastAction = nil
    recoveryCooldown = 30
end)

-- Manual recovery command.
hook_chat_command("unstuck_a", "- attempt to recover from a softlock", function()
    local m = gMarioStates[0]

    if not m then
        djui_chat_message_create("Mario state unavailable.")
        return true
    end

    recover(m, "\\#00ff00\\Unstuck recovery attempted.")
    return true
end)

print("[B3313] Softlock fix loaded")