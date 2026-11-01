-- Show B3313 area names in the CoopDX player list location column.
-- Uses network_player_set_override_location so every client sees where each player is.

local lastKey = ""

local function area_display_name(level, area)
    if not B3313_AREA_NAMES then return nil end
    local levels = B3313_AREA_NAMES[level]
    if not levels then return nil end
    local name = levels[area]
    if name and name ~= "" then return name end
    return nil
end

local function update_local_location()
    local np = gNetworkPlayers[0]
    if not np or not np.connected then return end
    if not network_player_set_override_location then return end

    local level = np.currLevelNum or 0
    local area = np.currAreaIndex or 0
    local key = tostring(level) .. ":" .. tostring(area)
    if key == lastKey then return end
    lastKey = key

    local name = area_display_name(level, area)
    if name then
        -- Player list location field has limited width; keep it readable
        if #name > 40 then
            name = name:sub(1, 37) .. "..."
        end
        network_player_set_override_location(np, name)
    else
        -- Fallback: LEVEL x AREA y
        network_player_set_override_location(np, string.format("Level %d Area %d", level, area))
    end
end

hook_event(HOOK_UPDATE, function()
    update_local_location()
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    lastKey = "" -- force refresh after warp
    update_local_location()
end)

hook_event(HOOK_ON_WARP, function()
    lastKey = ""
    update_local_location()
end)

print("[B3313] Player list area names loaded")
