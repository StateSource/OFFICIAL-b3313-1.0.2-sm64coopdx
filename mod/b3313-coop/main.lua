-- name: \\#FFFFFF\\! 1.0.2 \\#00FFFF\\ULTRA 64\\#FFD700\\ MARIO BROS\\#FFFFFF\\ !
-- description: \n


-- B3313 starts the game in its Castle Grounds, which is area 1 of the Tiny-Huge Island slot
-- (level 13): its lvl_init_from_save_file (0x8024BD5C) replaces the level the menu passes (16)
-- with 13. The castle grounds slot (16) holds B3313's beta lobbies instead.
gLevelValues.entryLevel = LEVEL_THI

-- B3313 has no course or act names (the ROM's tables point at empty strings), see courses.lua

-- B3313 never shows the act/star select screen.
-- Soft disable so MarioHunt (and other gamemodes) can still override it when needed.
hook_event(HOOK_USE_ACT_SELECT, function()
    -- Let NO ONE DECIDE because its buggy
    return false
end)
