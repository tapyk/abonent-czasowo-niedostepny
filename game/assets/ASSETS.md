# Asset manifest (technical)

Coordinates are in pixels. Sheet cells are written as (column, row), zero-based, from the top-left corner.
"Strip" means frames laid out horizontally, left to right in playback order, with no spacing.
All PNGs are RGBA with transparent backgrounds, except the opaque backgrounds noted below.
In Godot, import pixel art with **Filter = Nearest** (Project Settings > Rendering > Textures > Default Texture Filter = Nearest).

**Facing:** the player faces **RIGHT** and zombies face **LEFT**. Mirror with `flip_h`.

**Scale note:** the art comes from detailed 16-bit-style packs. The tiles are 16x16, as requested. The characters are taller than 32 px: the player body is about 46 px and zombies about 43 px. At 320x180 a character is roughly a quarter of the screen height, similar to Metal Slug. If you want smaller characters, scale the character nodes to 0.75 (nearest filtering), or zoom the camera out.

---

## sprites/characters/ (player: Warped City, by ansimuz)

Every frame is **71x67**. The character stands on the **bottom edge of the frame (y = 66)** and the body is centered at about x = 38. Use an `offset` of `(0, -33)` on an AnimatedSprite2D, or put the origin at the feet (35, 66). A suggested collision box (frame-local) is x 28..49, y 21..67, about 21x46 px.

| File | Size | Layout | Frames | Content / notes |
|---|---|---|---|---|
| `player_idle_strip.png` | 284x67 | strip, 71x67 | 4 | idle breathing, pistol held low. About 6-8 fps |
| `player_run_strip.png` | 568x67 | strip, 71x67 | 8 | run cycle. About 12 fps |
| `player_walk_strip.png` | 1136x67 | strip, 71x67 | 16 | slow walk cycle. About 16 fps |
| `player_jump_strip.png` | 284x67 | strip, 71x67 | 4 | f0 take-off tuck, f1-f2 somersault, f3 falling pose with pistol aimed right (use f3 as the "fall" frame) |
| `player_back_jump_strip.png` | 497x67 | strip, 71x67 | 7 | backflip (optional dodge) |
| `player_shoot.png` | 71x67 | single | 1 | standing shot, arm extended. **Muzzle point (54, 25)** |
| `player_run_shoot_strip.png` | 568x67 | strip, 71x67 | 8 | run while shooting. Muzzle at x 60-63, y 27-30 (about (62, 29)) |
| `player_crouch_shoot.png` | 71x67 | single | 1 | crouched shot. Muzzle (53, 43) |
| `player_hurt.png` | 71x67 | single | 1 | hit recoil |
| `player_climb_strip.png` | 426x67 | strip, 71x67 | 6 | ladder climb, back view |

## sprites/enemies/ (Soluna Software zombies)

Every frame is **45x45**. Feet are on the bottom edge (y = 44). Death frames end with the body lying down.

| File | Size | Layout | Frames | Content / notes |
|---|---|---|---|---|
| `zombie_walk_strip.png` | 270x45 | strip, 45x45 | 6 | shambling civilian zombie, faces left. Body bbox x 15..41, y 1..45. About 8 fps |
| `zombie_death_strip.png` | 270x45 | strip, 45x45 | 6 | f0-f1 hit and fall back with blood spray, f2-f3 falling, f4-f5 lying corpse. Play once and hold the last frame |
| `zombie_cop_walk_strip.png` | 270x45 | strip, 45x45 | 6 | zombie police officer, faces left. Body bbox x 16..32, y 0..44 |
| `zombie_cop_death_strip.png` | 225x45 | strip, 45x45 | 5 | falls back, ends lying down |

For the "burnt" variant, tint a zombie with `modulate = Color(1.0, 0.55, 0.25)` or use a shader.

## sprites/tiles/

### `tiles_warped_city.png`: 384x256, 16x16 grid, 24 cols x 16 rows, no spacing or margin (Warped City)
Dark teal cyberpunk building pieces. There is **no grass or dirt ground**. Use the wall blocks as solid ground and walls, and the platform for one-way ledges. Rows 0, 5 and 15 are empty.

- (1,1)-(1,3): narrow metal pillar, 1x3. (7,1)-(7,3): pillar variant
- (3,1)-(5,4): **doorway with lit window**, 3x4. The glowing window is (4,2)-(4,3). Also available as `props/prop_door_window.png`
- (9,1)-(10,4): **solid building wall block**, 2x4, with the top edge on row 1. Use it as ground/wall fill; it repeats vertically by reusing rows 2-3
- (18,1)-(19,4): solid wall block, 2x4 (mirrored variant of 9-10)
- (12,1)-(12,4): narrow wall strip with a machine at the base (12,4)
- (14,1)-(16,4): **closed roller-shutter door** (garage/shop), 3x4. Also `props/prop_door_shutter.png`
- (21,1): small single ledge/cap block
- (2,6)-(2,7): **ladder**, 1x2. Repeat (2,6)/(2,7) vertically. Also `props/prop_ladder.png`
- (4,6)-(4,8): vertical wall conduit with a lit electrical box at (4,8)
- (4,10)-(4,11): small post with a box/face at (4,11)
- (8,6)-(8,9) plus (7,9): **street-light / signal pole**. The lamp head is at (8,6) and the crossbar at (7,9)-(8,9). Also `props/prop_lamp_post.png`
- (10,6)-(12,7): pipe machinery, 3x2 (decoration)
- (11,9)-(12,10): AC unit / generator, 2x2. Also `props/prop_ac_unit.png`
- (14,6)-(16,9): half-open roller shutter with lit interior, 3x4
- (18,6)-(18,7): vent grille panel, 1x2
- (20,6)-(20,7): wall computer terminal / screen, 1x2
- (22,6)-(22,7): pipe panel, 1x2
- (7,11), (8,11), (9,11): **floating one-way platform**, left / middle / right, with a cyan lit top. Use the top 4 px for collision
- (14,11)-(16,14): glowing green portal/doorway, 3x4

### `tiles_warped_city_2.png`: 624x128, 16x16 grid, 39 cols x 8 rows, no spacing (Warped City 2)
Purple concrete slabs (good for rooftops and flyovers) with teal pipes. Row 0 is empty.

- (0,1)-(9,3): **long concrete slab / bridge deck**, horizontally seamless with no end caps. Row 1 is the slab top surface (the walkable top edge is y = 16 of the sheet), row 2 the front face with a railing pattern, row 3 the pipes underneath. The pattern repeats every 4 columns, so loop (1..4) or (5..8)
- (0,4)-(9,6): steel truss supports, to place under the slab
- (11,1)-(14,3): short slab segment, 4x3, same rows as above. Column 11 has a support plate
- (17,1)-(20,3): **cracked / damaged slab**, 4x3, for a ruined look
- (11,5)-(16,7): free-standing concrete block with ends, 6x3. The top surface is row 5
- (22,1)-(27,6): large concrete pillar/block with pipe clamps, 6x6 (rooftop structure)
- (29,1)-(37,6): large concrete block with teal bands and a circuit panel, 9x6 (container or rooftop machine room)

## sprites/props/

| File | Size | Content |
|---|---|---|
| `prop_antenna.png` | 22x96 | **Radio/LTE mast**: thin pole with a lit box and a beacon on top (Warped City). Origin at the bottom center (11, 95) |
| `prop_bush_large.png` | 42x27 | **Bush / fern**, dark green |
| `prop_bush_small.png` | 31x25 | low shrub / moss clump |
| `prop_crate.png` | 39x35 | wooden crate |
| `prop_crate_stack.png` | 73x68 | three stacked crates |
| `prop_barrel.png` | 24x30 | wooden barrel |
| `prop_door_shutter.png` | 48x64 | roller-shutter door (crop of tiles (14,1)-(16,4)) |
| `prop_door_window.png` | 48x64 | doorway with lit window (crop of tiles (3,1)-(5,4)) |
| `prop_lamp_post.png` | 48x64 | street-light pole (crop of tiles (7,6)-(9,9)). The pole is the middle 16 px column |
| `prop_ladder.png` | 16x32 | ladder, 2 tiles. Tile vertically |
| `prop_ac_unit.png` | 32x32 | AC unit / generator box |
| `prop_control_box_1.png` | 32x30 | electrical cabinet on legs |
| `prop_control_box_2.png` | 17x27 | small electrical box |
| `prop_control_box_3.png` | 62x30 | wide machinery box |
| `prop_car_police.png` | 163x60 | side-view police car (sci-fi hover car). Use it as a car wreck: darken it or rotate a few degrees |
| `prop_car_red.png` | 96x61 | side-view red compact hover car (wreck candidate) |
| `airplane_topdown.png` | 32x32 | grey long-wing airplane, **top-down**, nose pointing up. For the ending screen |
| `airplane_topdown_bomber.png` | 32x32 | grey heavy 4-engine plane, top-down, nose up |

## sprites/backgrounds/ (parallax, night)

Backgrounds are opaque except where noted. Repeat them horizontally with `ParallaxLayer.motion_mirroring = Vector2(width, 0)`.

| File | Size | Content / suggested use |
|---|---|---|
| `bg_sky_night.png` | 128x240, opaque | Furthest layer: dark-blue starry sky, orange-red cloud band and a tiny city silhouette on the horizon, which sits at about y 160-180. Taller than the screen; offset y by about -60 for a 180 px viewport. Scroll 0.0-0.1 |
| `bg_city_far.png` | 144x124, transparent above the skyline | Distant cyberpunk tower silhouettes in dark navy with pink lights. Scroll about 0.2 |
| `bg_blocks_mid.png` | 144x160, transparent sky | **Blocky apartment buildings** in maroon/purple with lit windows, the closest match to Polish *bloki*. Content starts at y 51; rows 94-159 are fully opaque. Scroll about 0.35 |
| `bg_city_glow_red.png` | 96x160, opaque | Alternative far layer: dense red city glow with a purple sky (Warped City 2 style) |
| `bg_city_near.png` | 493x209, transparent sky and gaps | Five separate near towers with neon signs, AC units and fire escapes, in teal/magenta. The gaps between towers are transparent and the edges do **not** loop seamlessly; mirror at width + some padding, or place towers individually. Scroll about 0.5 |

## sprites/items/

| File | Size | Content |
|---|---|---|
| `item_ammo_box_9mm.png` | 33x19 | green ammo box labelled "9mm" (**pistol ammo pickup**) |
| `item_ammo_box.png` | 38x19 | dark crate labelled "AMMO" with an ammo belt (larger ammo pickup) |
| `item_ammo_clip.png` | 8x13 | single pistol magazine (small ammo pickup) |
| `item_medkit.png` | 28x19 | white/grey medkit with a blue cross |
| `item_medkit_orange.png` | 28x19 | orange medkit with a blue cross |
| `item_battery.png` | 36x22 | car battery with cables (**mechanical/electrical part** quest item) |
| `item_gear.png` | 16x16 | grey cog / gear icon (1-bit style; tint with `modulate`) |
| `item_heart.png` | 16x16 | red heart (1-bit style) |

## sprites/fx/

| File | Size | Layout | Frames | Content |
|---|---|---|---|---|
| `fx_bullet_strip.png` | 80x5 | strip, 20x5 | 4 | **yellow tracer bullet** flying right. Loop it, or use f0 only |
| `fx_muzzle_flash_strip.png` | 32x16 | strip, 16x16 | 2 | yellow/orange star-burst muzzle flash (Kenney). Show for 1-2 frames at the muzzle point |
| `fx_bullet_hit_strip.png` | 45x11 | strip, 15x11 | 3 | blue impact ring expanding (bullet hit / spark) |
| `fx_energy_shot_strip.png` | 45x11 | strip, 15x11 | 3 | blue energy blob (optional enemy projectile) |
| `fx_explosion_strip.png` | 384x48 | strip, 48x48 | 8 | explosion: dark dot, flash, fireball, smoke, debris. Play once |

## sprites/ui/

| File | Size | Content |
|---|---|---|
| `ui_heart_full.png` / `ui_heart_empty.png` | 16x16 | HUD health heart, full / outline |
| `ui_pistol.png` | 16x16 | pistol icon (grey) |
| `ui_gear.png` | 16x16 | gear icon (same as `item_gear.png`) |
| `ui_warning.png` | 16x16 | yellow warning triangle |
| `ui_medkit_cross.png` | 16x16 | red medical cross |
| `ui_icons_1bit_sheet.png` | 784x352 | complete Kenney 1-Bit Pack (colored, transparent, packed): **16x16 grid, 49 cols x 22 rows, no spacing**. Useful cells: (39,10) full heart, (40,10) empty heart, (41,10) broken heart, (37,9) pistol, (38,9) raygun, (45,16) gear, (35,21) warning triangle, (36,21) skull sign, (43,11) red cross, (32,10) gold coin, (33,10)-(34,10) gems, digits 0-9 at (35,17)-(44,17), letters A-M (35,18)-(47,18), N-Z (35,19)-(47,19), arrows at (27,20)-(31,20), bushes/trees (0,1)-(7,2) |

## fonts/

Both fonts are by GGBotNet (CC0). Glyph coverage was checked with fontTools `getBestCmap()`. **All 18 Polish letters are present with outlines**: ą ć ę ł ń ó ś ź ż Ą Ć Ę Ł Ń Ó Ś Ź Ż.

| File | Native pixel size | Notes |
|---|---|---|
| `public_pixel.ttf` | **8 px** (8x8 monospace grid; unitsPerEm 1024, 1 px = 128 units) | 1324 glyphs, 98 languages. Use font_size 8 (or 16, 24…) for crisp text at 320x180. Mixed case. Main HUD/dialogue font |
| `pixelzone.ttf` | **16 px** (unitsPerEm 1024, 1 px = 64 units) | 1035 glyphs. Narrow proportional font with small lowercase. Use font_size 16 for titles and headings |

In Godot, set the font's `antialiasing = None`, `hinting = None` and `subpixel_positioning = Disabled` to keep it pixel-perfect.

## audio/

| File | Duration | Format | Description |
|---|---|---|---|
| `pistol_shot.ogg` | 0.43 s | OGG 96 kHz stereo | .22 pistol shot, real recording with a short room tail |
| `pistol_shot_alt.ogg` | 0.36 s | OGG 96 kHz stereo | second take of the same pistol, for variation |
| `gun_empty_click.ogg` | 0.45 s | OGG 48 kHz | dry metallic click (empty gun) |
| `gun_reload.ogg` | 0.26 s | OGG 48 kHz | metal latch snap (reload/cock) |
| `melee_swing.wav` | 0.19 s | WAV 16-bit 44.1 kHz | heavy whoosh (melee swing) |
| `melee_swing_light.wav` | 0.10 s | WAV 16-bit | light whoosh |
| `melee_punch.ogg` | 0.43 s | OGG 44.1 kHz | medium punch impact |
| `hit_flesh.ogg` | 0.65 s | OGG | heavy punch / flesh thud (bullet or melee hits a zombie) |
| `hit_flesh_2.ogg` | 0.54 s | OGG | heavy flesh-thud variant |
| `zombie_growl_1.wav` | 1.44 s | WAV 16-bit | long zombie groan (idle/aggro) |
| `zombie_growl_2.wav` | 0.85 s | WAV 16-bit | shorter zombie groan |
| `zombie_hurt.wav` | 0.33 s | WAV 16-bit | short zombie grunt (hurt) |
| `zombie_death.wav` | 1.58 s | WAV 16-bit | long zombie moan (death) |
| `pickup.ogg` | 0.47 s | OGG mono | rising synth blip (item pickup) |
| `jump.ogg` | 0.47 s | OGG | short "phase jump" synth sweep (arcade jump) |
| `player_hurt_1.ogg` | 0.70 s | OGG 48 kHz mono | female pain grunt |
| `player_hurt_2.ogg` | 0.53 s | OGG 48 kHz mono | female pain grunt, shorter |
| `player_death.ogg` | 1.33 s | OGG 48 kHz mono | longer female groan (death / heavy hit) |
| `ui_confirm.ogg` | 0.29 s | OGG mono | UI confirm chime |
| `ui_beep.ogg` | 0.12 s | OGG mono | short UI beep/bong (menu move, radio beep) |
| `ui_error.ogg` | 0.50 s | OGG mono | error buzz |
| `power_down.ogg` | 1.33 s | OGG mono | descending three-tone zap (**power-down / shutdown**) |
| `power_down_short.ogg` | 0.78 s | OGG mono | low descending tone (short power-down) |
| `footstep_concrete_1..3.ogg` | 0.11 s each | OGG | footsteps on concrete. Pick one at random per step |
| `explosion.ogg` | 0.78 s | OGG mono | crunchy explosion |

Note: the zombie clips were assigned to growl/hurt/death by length (the source pack is 24 unnamed zombie sounds), so swap in other takes if one doesn't fit. Radio static was not included; generate it procedurally, as planned.
