B3313 Nighty Light - B3313 v1.0.2 SM64CoopDX port + day/night cycle
===========================================================

Install
  1. Delete the old "b3313-coop" folder from your mods folder if you have an older version.
  2. Put this "b3313-coop" folder into your sm64coopdx "mods" folder
     (Windows: %appdata%\sm64coopdx\mods).
  3. Start sm64coopdx, host a game and enable "B3313 Nighty Light".
     Don't enable other romhack mods at the same time.

What's in it
  - All 31 level slots of B3313 with every area (up to 15 per level, ~390 areas),
    extracted from the ROM and compiled for sm64coopdx (levels/*.lvl).
  - Level geometry, collision, warps, water boxes, scrolling textures,
    custom skyboxes, ~12,700 objects and B3313's custom object models.
  - 115 B3313 music tracks (sound/*.m64) mapped to the same sequence ids.
  - B3313's dialog text (spaced-out lowercase, as in the ROM). Course and act
    names are blank because B3313's own name tables are blank.
  - 224 B3313 custom object behaviors re-created in Lua (c_behaviors.lua).
  - B3313's own object code rewritten in Lua (b_natives_ported.lua): all 96 custom
    routines are now ported, so all 1,295 placed objects that use custom code run.

New in v0.4.3
  - The area display has a star counter after the area's name: a star, then the stars
    you've collected in this area / the stars this area has (gold when you have them all).
    The area's stars are worked out from its level script: placed stars, red coin and
    secret stars, stars in ! boxes, and the bosses and B3313 objects that drop a star.
    Areas with no stars show no counter. Stars that appear some other way (e.g. from boo
    keys) aren't counted.
  - Fast travel now goes Beta Lobby A, then B, then C/D, then E, and round again (skipping
    the lobby you're in).

New in v0.4.2
  - Extended area display under the lives counter: "AREA n" (B3313's levels have up to 15
    areas, numbered 0-14) with the area's name next to it, e.g. "AREA 3  BETA LOBBY B".
    B3313 doesn't name its areas itself, so the names are the community names from the
    B3313 wiki's List of Areas (388 of the port's 393 areas have one). Long names shrink to
    fit; it moves down a row while sm64coopdx's cap timer is showing. Type /b3313-area in
    chat to turn it off or on (remembered).
  - The game now starts where B3313 starts: the Castle Grounds, which is area 1 of the
    Tiny-Huge Island slot (level 13). B3313's file-select code swaps the level the menu
    asks for (16) for 13; earlier versions of the port started in level 16 instead.
  - No act/star select screen when entering a level, as in B3313 (it never shows one).

New in v0.4
  - Paintings. B3313 doesn't use SM64's painting warps: its paintings are objects whose
    model runs B3313 code that sm64coopdx can't run, so in v0.3 they were invisible and
    did nothing. All 141 of them are now rebuilt from the ROM (their own textures, size,
    position and angle) and drawn in the levels, and walking into one takes you through
    it, the way B3313 checks it (into the painting's frame, behind its surface).
      * Coming back: if you die or fall out, or collect a star that exits the course, after
        going in through a painting, you come back out of that painting (B3313's own
        return-to-painting system), and you can't fall straight back in while you're
        being thrown out.
      * The paintings don't ripple; they're drawn flat.
  - Fast travel. Pause and press Z ("PRESS Z TO FAST TRAVEL" shows on the pause screen) to
    fast travel to the beta lobbies, like B3313's pause-menu fast travel (order changed in
    v0.4.3, see above). The areas where
    B3313 turns fast travel off still have it off. (B3313 uses A; in sm64coopdx A resumes
    the game from the pause menu, so the port uses Z.)
  - Falls that are warps. Many B3313 areas send you elsewhere when you fall off (a floor
    warp). In multiplayer, sm64coopdx turned those falls into bubbles; they now warp.

New in v0.3
  - B3313's star save. B3313 rewrote SM64's save code to hold 59 courses of 8 stars,
    and over half of its stars use those extra slots, which sm64coopdx's save can't
    hold. The port now keeps B3313's star table itself (a3_stars.lua):
      * every star saves where B3313 saves it, and the star counter, star doors and
        star-count gates use B3313's total;
      * collected stars show as transparent stars;
      * stars are shared: when one player collects a star, everyone gets it;
      * the host keeps the stars per save file (mod storage) and sends them to players
        who join.
  - The remaining 32 custom routines (v0.2 had 64 of 96):
      * bosses: the giant goomba boss (kick its small goombas into it) and the giant
        Fly Guy boss in Cool, Cool Mountain (chases, swoops and charges, drops
        fireballs that burst into blue flames; kick or punch it, or ground-pound it
        while it charges);
      * the sentinel Mr. I eyes (sweep their gaze, fire line-of-sight probes at you and
        charge once they see you; their touch is fatal, as in B3313), the giant Mr. I in
        Hazy Maze Cave that rises from the pit and warps you away, and the drifting Mr. Is;
      * star events: star boxes, "defeat them all" star rewards, the item you carry
        above the water for a star, star-count warps;
      * timed runs to a goal (with the on-screen timer), talk spots (stop, read, then
        warp), doors that warp as they open, launch orbs, hurting floors, music fade
        zones;
      * turntables, flip-panel variants, switch-operated gates, purple-switch platforms,
        oscillating platforms, and the Rainbow Ride button that moves a platform;
      * the "Jumpscare Entity" area (area 10 of the Bowser 1 fight slot). B3313 deliberately
        crashes the game there. The port does not crash sm64coopdx: you get a few
        seconds of black, silent screen and are sent back to the start, as if the
        console had been reset.

Known gaps in this build
  - B3313's "enhancer" (its adaptive difficulty state that recolours goombas and
    changes their behaviour) isn't ported; goomba towers use its neutral setting.
  - Star pieces are counted on touch; the star-piece "dance" itself is skipped.
  - Ported objects are simulated on each player's game separately (not synced); only
    stars, boo keys and the save are shared.
  - Stars collected with an older version of the port (v0.1/v0.2, saved in
    sm64coopdx's own save) are not carried over to B3313's star table.
  - B3313's custom Mario/Luigi models are not used (sm64coopdx's characters are).
  - Custom HUD and other engine-level ASM patches from the ROM are not ported.

Files load in alphabetical order: a0_core -> a1_tables -> a2_models -> a3_stars ->
a4_paintings -> a5_areanames -> a6_areastars -> a_anims -> b_areadisplay -> b_natives -> b_natives_ported -> b_paintings ->
c_behaviors ->
d_* -> main.lua.


B3313 Nighty Light
------------------
- A synced day/night lighting cycle designed to run in B3313 custom levels.
- A full in-game day lasts about 24 real minutes.
- Host commands: /nightylight toggles the cycle; /nightytime 0-23 sets the hour.
- This is a standalone cycle. Do not enable Day Night Cycle DX at the same time, as both mods control global lighting.
- This package has been assembled but not tested in-game; lighting behavior can vary by custom level and renderer.
