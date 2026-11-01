-- Extended area display: under the lives counter, the number of the area you're in (B3313
-- levels have up to 15 areas, numbered 0-14), the area's name next to it, then a star
-- counter: stars collected in this area / stars this area has.
-- B3313 doesn't name its areas itself; the names are the community names from the B3313
-- wiki (a5_areanames.lua). The area's stars come from its level script (a6_areastars.lua):
-- placed stars, red coin and secret stars, stars in ! boxes, and the bosses and B3313
-- objects that drop one. Toggle with the chat command /b3313-area (remembered).

local showAreaDisplay = mod_storage_load("area_display") ~= "0"

hook_chat_command("b3313-area", "- turn the area display under the lives counter on or off", function()
    showAreaDisplay = not showAreaDisplay
    mod_storage_save("area_display", showAreaDisplay and "1" or "0")
    djui_chat_message_create("Area display " .. (showAreaDisplay and "on" or "off"))
    return true
end)

-- the HUD font has letters, digits and a few symbols but no brackets
local function hud_text(s)
    s = s:gsub(" %(", " - "):gsub("%(", ""):gsub("%)", "")
    return s:upper()
end

local nameCache = {}
local function area_name(level, area)
    local key = level * 16 + area
    local cached = nameCache[key]
    if cached == nil then
        local l = B3313_AREA_NAMES and B3313_AREA_NAMES[level]
        local n = l and l[area]
        cached = n and hud_text(n) or false
        nameCache[key] = cached
    end
    return cached or nil
end

-- stars collected here / stars here, by B3313 save slot (indices 8-15 can't be saved by
-- B3313's save, so they don't count)
local function area_stars(level, area)
    local l = B3313_AREA_STARS and B3313_AREA_STARS[level]
    local list = l and l[area]
    if list == nil then return nil end
    local seen, total, got = {}, 0, 0
    for _, idx in ipairs(list) do
        if idx < 8 or idx >= 16 then
            local c, b = b3313_star_slot(idx)
            local key = c * 8 + b
            if not seen[key] then
                seen[key] = true
                total = total + 1
                if (b3313_star_flags(c) & (1 << b)) ~= 0 then got = got + 1 end
            end
        end
    end
    if total == 0 then return nil end
    return got, total
end

-- B3313-style text title
local function print_b3313(text, x, y, scale, r, g, b)
    djui_hud_set_color(r, g, b, 180) -- rgba thingy
    djui_hud_set_font(FONT_MENU)
    djui_hud_print_text(text, x, y, scale * 0.5)
end

local rainbowTime = 0
local pr = 255
local pg = 0
local pb = 0

hook_event(HOOK_UPDATE, function()
    rainbowTime = rainbowTime + 0.02
    pr = (math.sin(rainbowTime) + 1) * 127.5
    pg = (math.sin(rainbowTime + 2.094) + 1) * 127.5
    pb = (math.sin(rainbowTime + 4.189) + 1) * 127.5
end)

hook_event(HOOK_ON_HUD_RENDER, function()
    if not showAreaDisplay then return end
    if (gHudDisplay.flags & HUD_DISPLAY_FLAG_LIVES) == 0 then return end
    local np = gNetworkPlayers[0]
    local level, area = np.currLevelNum, np.currAreaIndex
    if level == nil or level <= 0 then return end

    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_HUD)

    -- the lives counter sits at x 22, y 15-31; sm64coopdx's cap timer takes the next row
    local m = gMarioStates[0]
    local x, y = 0, (djui_hud_get_screen_height() - 11)
    djui_hud_set_color(0, 0, 0, 190)
    djui_hud_render_rect(0, (djui_hud_get_screen_height() - 10), 220, 10)

    if gLevelValues.hudCapTimer ~= 0 and (m.flags & MARIO_SPECIAL_CAPS) ~= 0 and m.capTimer > 0 then
        y = y + 0
    end

    local num = "AREA " .. tostring(area)
    local name = area_name(level, area)
    local got, total = area_stars(level, area)
    local count = got and (tostring(got) .. "/" .. tostring(total)) or nil

    -- widths at scale 1: the star icon is 16 wide, text is measured in the HUD font
    local gap = djui_hud_measure_text("   ")
    local numW = djui_hud_measure_text(num)
    local nameW = 0
    if name then
        if b3313_font_measure then
            nameW = b3313_font_measure(name)
        else
            nameW = djui_hud_measure_text(name)
        end
    end
    local countW = count and djui_hud_measure_text(count) or 0
    local width = numW
    if name then width = width + gap + nameW end
    if count then width = width + gap + 16 + 2 + countW end
    -- shrink long lines to fit the screen
    local scale = 0.4
    local avail = djui_hud_get_screen_width() - x - 8
    if width * scale > avail then scale = math.max(0.35, avail / width) end

    local cx = x
    print_b3313(num, cx, y, scale, pr, pg, pb)
    cx = cx + numW * scale
    if name then
        cx = cx + gap * scale
        if b3313_font_print then
            -- PNG glyph font (scale maps 16px glyphs)
            b3313_font_print(name, cx, y, scale) 
        else
            print_b3313(name, cx, y, scale, 255, 255, 255)
        end
    end
    if count then
        scale = 0.4
        djui_hud_set_color(0, 0, 0, 190)
        djui_hud_render_rect(0, (djui_hud_get_screen_height() - 20), 29, 10)
        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_render_texture(gTextures.star, 0.05, (djui_hud_get_screen_height() - 19.5), scale, scale)
        if got >= total then
            print_b3313(count, 6 + scale, (djui_hud_get_screen_height() - 20), scale, 255, 220, 90)
        else
            print_b3313(count, 6 + scale, (djui_hud_get_screen_height() - 20), scale, 255, 255, 255)
        end
    end
end)
-- goat: TMMThemastermario :D