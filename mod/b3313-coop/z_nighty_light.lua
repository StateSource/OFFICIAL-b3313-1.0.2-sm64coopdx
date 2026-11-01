-- name: B3313 Nighty Light
-- description: A synced day/night cycle designed for B3313's custom levels.
-- This is a standalone lighting cycle. Do not run it alongside Day Night Cycle DX,
-- since both mods would control the same lighting values.

local DAY_LENGTH_MINUTES = 24 -- 24 real minutes per full in-game day
local FRAMES_PER_SECOND = 30  -- SM64CoopDX game update is typically 30 FPS
local GAME_MINUTES_PER_FRAME = 1440 / (DAY_LENGTH_MINUTES * 60 * FRAMES_PER_SECOND)

if network_is_server() then
    if gGlobalSyncTable.nightyLightEnabled == nil then
        gGlobalSyncTable.nightyLightEnabled = true
    end
    if gGlobalSyncTable.nightyLightTime == nil then
        gGlobalSyncTable.nightyLightTime = 8 * 60
    end
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function smoothstep(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function mix_color(a, b, t)
    return {
        r = math.floor(lerp(a.r, b.r, t) + 0.5),
        g = math.floor(lerp(a.g, b.g, t) + 0.5),
        b = math.floor(lerp(a.b, b.b, t) + 0.5),
    }
end

local NIGHT = { r = 55, g = 65, b = 115 }
local SUNRISE = { r = 255, g = 165, b = 125 }
local DAY = { r = 255, g = 255, b = 255 }
local SUNSET = { r = 255, g = 135, b = 100 }
local AMBIENT_NIGHT = { r = 45, g = 50, b = 85 }
local AMBIENT_DAY = { r = 190, g = 190, b = 190 }

-- Returns a lighting color for the current in-game minute.
local function get_cycle_colors(minutes)
    local hour = minutes / 60
    if hour < 5 or hour >= 20 then
        return NIGHT, AMBIENT_NIGHT, 0.72
    elseif hour < 7 then
        local t = smoothstep((hour - 5) / 2)
        return mix_color(NIGHT, SUNRISE, t), mix_color(AMBIENT_NIGHT, AMBIENT_DAY, t), lerp(0.72, 1.0, t)
    elseif hour < 8 then
        local t = smoothstep(hour - 7)
        return mix_color(SUNRISE, DAY, t), mix_color(AMBIENT_DAY, AMBIENT_DAY, t), 1.0
    elseif hour < 17 then
        return DAY, AMBIENT_DAY, 1.0
    elseif hour < 19 then
        local t = smoothstep((hour - 17) / 2)
        return mix_color(DAY, SUNSET, t), mix_color(AMBIENT_DAY, AMBIENT_NIGHT, t), lerp(1.0, 0.78, t)
    else
        local t = smoothstep(hour - 19)
        return mix_color(SUNSET, NIGHT, t), mix_color(AMBIENT_NIGHT, AMBIENT_NIGHT, t), lerp(0.78, 0.72, t)
    end
end

local function apply_lighting()
    if not gGlobalSyncTable.nightyLightEnabled then return end
    local minutes = gGlobalSyncTable.nightyLightTime or 480
    minutes = minutes % 1440
    local light, ambient, fogIntensity = get_cycle_colors(minutes)
    local vertex = mix_color(light, ambient, 0.45)

    for i = 0, 2 do
        local channel = (i == 0 and "r") or (i == 1 and "g") or "b"
        set_lighting_color(i, light[channel])
        set_lighting_color_ambient(i, ambient[channel])
        set_vertex_color(i, vertex[channel])
        set_fog_color(i, light[channel])
    end
    set_lighting_dir(0, 0)
    set_lighting_dir(1, 0.5)
    set_lighting_dir(2, 0.5)
    set_fog_intensity(fogIntensity)
end

hook_event(HOOK_UPDATE, function()
    if network_is_server() and gGlobalSyncTable.nightyLightEnabled then
        gGlobalSyncTable.nightyLightTime = ((gGlobalSyncTable.nightyLightTime or 480) + GAME_MINUTES_PER_FRAME) % 1440
    end
    apply_lighting()
end)

hook_chat_command("nightylight", "Toggle B3313 Nighty Light day/night cycle", function(msg)
    if not network_is_server() then
        djui_chat_message_create("Only the host can toggle Nighty Light.")
        return true
    end
    gGlobalSyncTable.nightyLightEnabled = not gGlobalSyncTable.nightyLightEnabled
    if gGlobalSyncTable.nightyLightEnabled then
        djui_chat_message_create("B3313 Nighty Light: ON")
        apply_lighting()
    else
        djui_chat_message_create("B3313 Nighty Light: OFF (lighting will return to the game's defaults on the next level load)")
    end
    return true
end)

hook_chat_command("nightytime", "Set Nighty Light time: /nightytime 0-23", function(msg)
    if not network_is_server() then
        djui_chat_message_create("Only the host can set Nighty Light time.")
        return true
    end
    local hour = tonumber(msg)
    if hour == nil then
        djui_chat_message_create("Usage: /nightytime 0-23")
        return true
    end
    hour = clamp(math.floor(hour), 0, 23)
    gGlobalSyncTable.nightyLightTime = hour * 60
    djui_chat_message_create(string.format("B3313 Nighty Light time set to %02d:00", hour))
    apply_lighting()
    return true
end)

hook_mod_menu_text("B3313 Nighty Light - 24-minute day")
