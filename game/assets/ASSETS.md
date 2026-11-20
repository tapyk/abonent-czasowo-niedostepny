# Asset manifest (technical): top-down 3/4 RPG set

The coordinates are tile cells written as **(column, row)**. They are zero-based and counted from the top-left corner of the sheet. A pixel position is `(col*16, row*16)`.
**Every tile sheet is a 16x16 grid with no spacing and no margin.** Two sheets were repacked from Kenney's 1-px-spaced originals, and their coordinates are unchanged.
All PNGs are RGBA. Transparent means alpha 0.
In Godot, import pixel art with **Filter = Nearest**. Set Project Settings > Rendering > Textures > Default Texture Filter = Nearest.
Most of the art is Kenney's 16 px "Roguelike / RPG Urban" family, which uses one shared purple-grey outline style, so the sheets mix cleanly.

**Visual consistency rule.** Use `city_tiles.png` as the base for terrain, roads, sidewalks and buildings. Use `urban_tiles.png` for the characters, hedges, fences, tree clusters, street props, doors and stairs.
`rpg_tiles.png` is brighter and more saturated. Use it only for interior floors and walls, water, bushes and the dead tree, and never mix its grass with the city grass.
`farm_crops.png` is by a different artist and has darker outlines. It is used only as the crop overlay in the field.

Every 9-slice and edge tile below exists in **one orientation only**. Kenney expects you to rotate or flip it for other sides. Godot 4 TileSet alternative tiles support `flip_h`, `flip_v` and `transpose`.

---

## sprites/tiles/

### `city_tiles.png` (Kenney Roguelike Modern City): 592x448, 37 cols x 28 rows. **Main tileset.**
Ground tiles are opaque. Props, windows, doors, trees and cars have transparent backgrounds, so they go on an upper TileMap layer.

**Ground fills (opaque, seamless):**
- grass: **(0,24)**, **(1,24)** (plain variants). The grass-island centre (1,26) is also plain grass
- dirt: **(4,24)**, **(5,24)**. The dirt-patch centre (11,26) is also plain dirt
- gravel / concrete ground: (2,24), (3,24)
- sand: (6,24), (7,24)
- cobble / rubble ground: (8,24). Mossy rubble (grass with stones): (25,4)
- **asphalt (plain): (11,19)**. A patched or pothole asphalt patch: (10,24). Manhole cover on asphalt: (9,24)

**Grass to dirt transitions (opaque):**
- **Grass island on dirt**, 9-slice (dirt outside): TL (0,25), T (1,25), TR (2,25), L (0,26), C (1,26), R (2,26), BL (0,27), B (1,27), BR (2,27). Inner corners (1-px dirt pixel at the named corner, otherwise grass): BR (3,25), BL (4,25), TR (3,26), TL (4,26). Single 1x1 grass patch: (3,27)
- **Dirt patch on grass**, 9-slice (grass outside): TL (10,25), T (11,25), TR (12,25), L (10,26), C (11,26), R (12,26), BL (10,27), B (11,27), BR (12,27). Inner corners: BR (13,25), BL (14,25), TR (13,26), TL (14,26). Single 1x1 dirt patch: (13,27)
- Speckled transition fills: dirt with grass flecks (9,27), grass with dirt flecks (19,27)
- (5..9, 25..27) and (15..18, 25..27) hold 1-wide strips and other combinations of the same two terrains

**Sidewalk / pavement (opaque, 3 materials, 3x5 each):** grey cols 0-2, beige cols 3-5, light blue-grey cols 6-8.
- plain paving: grey (0,19), (1,19), (2,19), (0,20), **(1,20)**, (2,20). Beige (3..5, 19..20). Light (6..8, 19..20)
- row 21: paving with a small post base / hatch (decorative variants)
- **row 22: curb edge.** A light curb line runs along the **bottom** edge, so the road is below. Grey (0,22), (1,22), (2,22). Rotate or flip it for other sides
- row 23: curb with a storm drain at the bottom edge
- the light blue-grey set (cols 6-8) is the one in Kenney's sample city and reads best as a sidewalk

**Road markings (opaque asphalt with paint):**
- dashed white centre line: horizontal (9,19), with an 8 px dash on the left half; repeat it along x. Vertical (9,20); repeat it along y
- zebra crossing: bars horizontal (9,22), (10,22), (11,22), for crossing a vertical road; bars vertical (12,22), (13,22), (14,22), for crossing a horizontal road
- double yellow line: horizontal (13,19), vertical (13,20). Single yellow edge lines: (14,19) bottom, (11,20) top, (12,20) right, (11,21) left, (12,21) bottom
- intersection plus (12,19). Stop-line T marks (11..14, 23)
- parking-bay outlines (15..18, 21..24). Arrows on asphalt: up (19,21), down (19,22), left (19,23), right (19,24). P sign (13,24), bicycle (14,24)

**Flat roofs (opaque), 4 materials, each an 8x4 block:** red origin col 0, **dark grey origin col 8**, light grey origin col 16, beige origin col 24 (rows 0-3).
The offsets inside a block are relative to its origin column `o`:
- 9-slice: TL (o+0,0), TR (o+1,0), BL (o+0,1), BR (o+1,1), top edge (o+2,0), bottom edge (o+2,1), left edge (o+3,0), right edge (o+3,1), **fill (o+6,0)**
- fill variants: (o+7,0) with rivets, (o+6,1) with a roof hatch/vent, (o+7,1) with a skylight panel
- 1-wide vertical strip: top (o+0,2), bottom (o+0,3). 1-tall horizontal strip: left (o+1,2), middle (o+2,2), right (o+3,2). Single (o+1,3)
- example, dark grey roof: TL (8,0), T (10,0), TR (9,0), L (11,0), fill (14,0), R (11,1), BL (8,1), B (10,1), BR (9,1)

**Building facades / walls (opaque), 4 materials, each a 4-col block, rows 4-12:** red brick cols 0-3, **grey brick cols 4-7 (best "blok" look)**, beige brick cols 8-11, glass curtain wall cols 12-15 (more glass at 16-18).
Inside a block with first column `w`: column w+0 is a 1-wide pillar. Then **w+1 = left end, w+2 = middle (repeat), w+3 = right end**.
- **top row (cornice line at the top): row 9**
- **middle rows: row 5** (plain brick). Row 6 is brick with a horizontal floor band, and row 7 is brick with a light window-sill ledge
- **bottom row (plinth): row 8**
- single-height wall (top and bottom in one tile): row 10
- row 4: grey drain pipes and cornice crosses (decoration). Rows 11-12: corner/pillar 2x2 variants
- grey brick example: top (5,9) (6,9) (7,9); middle (5,5) (6,5) (7,5); floor band (5,6) (6,6) (7,6); bottom (5,8) (6,8) (7,8)

**Window overlays (transparent around the frame), cols 25-30, rows 15-20.** Rows 15-17 have wooden frames and rows 18-20 grey metal frames.
- plain square grey window: (26,18), (27,18). Four-pane grey: (25,19), (26,19), (27,19), (25,20), (26,20). Tall grey: (28,19), (29,19), (29,20)
- wooden four-pane: (25,16), (26,16), (27,16). Arched: (28,15), (28,18). Window with graffiti/damage: (30,16), (30,19)
- **broken glass windows** (shop-window size): (20,21), (21,21), (22,21), (20,22), (21,22), (22,22). Intact shop windows (20..22, 23..25)

**Doors (overlays, 1 wide x 2 tall: top tile on row 26, bottom tile on row 27):**
- brown closed (20,26)+(20,27), brown closed mirrored (21,26)+(21,27), **brown open/dark** (22,26)+(22,27)
- green closed (23), (24); green open (25). Orange closed (26), (27); orange open (28). Dark doorway without a door (29), (30) (same two rows)
- glass shop doors (2x2): (23..24, 23..24), (25..26, 23..24). Dark open glass doors: (27..28, 21..25), (29..30, 23..25)
- outdoor steps (beige): (16,4)+(16,5), (17,4)+(17,5), (18,4)+(18,5). Grey steps (19,4), (20,4)

**Vegetation (transparent):** six tree kinds in cols 31-36. 31 light green, 32 orange (autumn), 33 dark green, 34 light green slim, 35 orange slim, 36 dark green cypress.
- **tree on ground (1x2): (c,10) top + (c,11) bottom with trunk**
- tree in a sidewalk planter (1x2): (c,10) top + (c,12) bottom with a grey planter
- small bush / sapling (1x1): (c,13)
- park lawn with a stone border (32..34, 0..2), 9-slice like the roofs. Statue on grass (35,2), (36,2)

**Fences and railings (transparent):**
- wooden plank fence, horizontal: (20,14), (21,14), (22,14), (23,14), (24,14). A lower variant: (20..23, 16). Vertical wooden fence pieces: (16,14), (16,15), (19,15), (16,16), (19,16)
- **chain-link fence panels** (mesh with transparent holes): (15..19, 17..20). Each is 1 tile with a grey frame; (17,19) and (17,20) are torn variants with holes
- metal pipe railing: (20..24, 17..18), (20..24, 19..20)
- low concrete parking stops: horizontal (35,18), (36,18), (35,22..23); vertical (35,19)+(36,19), (35,26..27)

**Street furniture and props (transparent, 1x1 unless noted):**
- rubble / rocks: large (12,13), medium (13,13), small (14,13). **Tyres**: single (12,14), stack (13,14), pile (14,14)
- trash: wheelie bin (15,13), bins (16,13), (17,13), (18,13), (33,3), (34,3). Orange oil barrel (32,3)
- boxes: open cardboard (13,15), (14,15), closed (13,16), (14,16), stacked (13,17), (14,17), wooden pallet crate (15,15)+(15,16). Traffic cone (14,18)
- fire hydrant (15,14). Teal mailbox (12,15)+(12,16). Shop shelves (9..13, 18), (12,17)
- **electrical / utility:** tall electrical cabinet (27,14), AC/fan unit (30,14), small boxes (25,14), (26,14), (29,14), gas meter (28,14), fan box (24,15), **keypad / control panel (24,16)**, vending/terminal machines (24,8), (25,8), (26,8), (27,8)
- road barricades (striped, 1x1 each): red/white (24,5), (25,5); orange (24,6), (25,6); yellow/black (24,7), (25,7)
- benches/planters (35,3), (36,3). Wooden bench (17,15)+(18,15). Wooden table (17,16)+(18,16)
- **poles:** street lamp curved left (1,16)+(1,17)+(1,18) (head, pole, base); curved right (2,16..18); lamp with green banner (0,16..18), (3,16..18); double T-lamp: head (4..6,16), pole (5,17)+(5,18). Park bollard light (4,17)+(4,18). Green park lamp (6,17)+(6,18)
- **wooden utility pole** with a lamp arm, 3 tall: (7,16)+(7,17)+(7,18) (arm left) and (8,16..18) (arm right). Good for overhead cables
- **sagging overhead cable / wire** between poles: (7,13), (8,13), (9,13). Wooden pole tops: (10,13), (11,13). Thin metal mast 4 tall: (11,14)+(11,15)+(11,16)+(11,17)
- traffic lights (1 wide): body (0..3, 14..15) with caps on row 13; coloured lights on (2,14)+(2,15)
- street-name / bus-stop signs (teal), 2 tall: (8..11, 14)+(8..11, 15)
- laundry line: (4,13), (5,13), (6,13)

**Cars (transparent; also exported as separate PNGs in props/):**
- green: side 3x2 facing left (31..33, 16..17), facing right (34..36, 16..17); vertical 2x2 facing up (31..32, 18..19), facing down (33..34, 18..19)
- grey: the same layout at rows 20-21 (side) and 22-23 (vertical)
- orange: the same layout at rows 24-25 (side) and 26-27 (vertical)

### `urban_tiles.png` (Kenney RPG Urban Pack): 432x288, 27 cols x 18 rows
Contains the **characters** (cols 23-26, also exported to characters/), plus lawns, pools, facades, trees, hedges, fences and props. Same outline style as city_tiles.

**8x3 terrain blocks (transparent outside the shape, to lay over ground).** Inside a block with origin `(o, r)`:
- 9-slice: TL (o,r), T (o+1,r), TR (o+2,r), L (o,r+1), **C (o+1,r+1)**, R (o+2,r+1), BL (o,r+2), B (o+1,r+2), BR (o+2,r+2)
- inner corners (the border shows only at the named corner): BR (o+5,r), BL (o+6,r), TR (o+5,r+1), TL (o+6,r+1)
- 1-tall horizontal strip: L (o+3,r+2), M (o+4,r+2), R (o+5,r+2). Single tile (o+6,r+2). 1-wide vertical strip: T (o+7,r), M (o+7,r+1), B (o+7,r+2)
- (o+3..o+4, r..r+1) is a 2x2 framed piece with an inner-corner centre
- blocks:
  - origin (0,0): **teal-green lawn with a beige curb**, a small courtyard lawn. Centre (1,1)
  - origin (8,0): light concrete slab with a pale border (plaza)
  - origin (0,3): beige paving with a blue-grey border
  - origin (8,3): grey slab with a beige border
  - origin (8,6): **water pool / pond with a stone rim**. Centre water (9,7)

**Facades:** red brick cols 16-22 rows 0-3, orange brick cols 16-22 rows 4-7.
- col 16: 1-wide pillar (row 0 top, rows 1-2 middle, row 3 bottom; +4 for orange)
- cols 17-19: wall with beige corner quoins. Left (17), middle (18), right (19). Row 0 top cornice, **row 1 middle with a floor band**, row 2 plain middle, row 3 bottom plinth
- cols 20-22: the same without quoins
- urban door/window tiles (below) have a grey surround meant for these facades

**Trees and thicket (transparent):**
- tall tree, teal: (16,8) top + (16,9) bottom. The same tree in a planter: (16,8) + (16,10). Smaller tree: (17,8)+(17,9), or in a planter (17,8)+(17,10)
- **THICKET, 3x3 dense tree cluster** (blocks a path): **(18,8)-(20,10)** teal. Column 18 is almost empty (only its right 6 px are used). Also exported as `props/thicket_green.png`
- tall column bush 1x2: (21,8)+(21,9). Small tree 1x1: (21,10). Round bush 1x1: (22,8). Small conifer 1x1: (22,9). Small round tree 1x1: (22,10)
- autumn (orange) versions: the same layout 3 rows lower (rows 11-13). Thicket (18,11)-(20,13), also `props/thicket_autumn.png`

**Hedges and fences (transparent):**
- **green hedge (low, 1 tile tall)**: left (4,12), middle (5,12), right (6,12). Short singles (7,12), (8,12). Use it as a garden hedge or a low thicket line
- **chain-link fence**: left (4,13), middle (5,13), right (6,13), end post (7,13)
- **wooden plank fence**: left (4,14), middle (5,14), right (6,14), end post (7,14)
- rope/chain barrier between posts: (0,8)-(4,8), and (0,9)-(4,9) with hanging items

**Stairs:** a wide outdoor/stairwell staircase going up, 2x3, at (0,12)-(1,14). A narrow staircase with a railing, 1x3, at (2,12)-(2,14). The whole 3x3 block (0..2, 12..14) is one connected sprite.

**Doors (1x1 overlays on a facade, grey surround):** glass doors (12,9), (13,9), (14,9), (15,9).
- closed: roll-up shutter (11,10), red (12,10), orange (13,10), orange double (14,10), glass double (15,10)
- damaged/open: broken door (11,11), **boarded-up door (12,11)**, orange door open (13,11), open dark doorway (14,11), dark doorway (15,11)
- grey double door 1x2: (15,12)+(15,13)
- windows: (11..14, 12..14) beige-framed, (11..14, 15..17) grey-framed. Shop window 3x2: (8..10, 13..14)

**Props (transparent, 1x1):** concrete jersey barriers (0,10), (1,10). Cracked block (0,11). Slab (1,11). Bollards (2,10), (2,11).
- boxes: closed (3,10), open (4,10), flattened (5,10). **Wooden crate (3,11)**. Crate with apples (4,11), crate with greens (5,11). Produce crates (6,10), (7,10)+(7,11). Shelf (6,11)
- red/white barricades (5,8), (6,8), and orange/black ones (5,9), (6,9). Wooden sign/bench (7,8), (7,9)
- red post box (8,9). Red hydrant (8,10). Trash cans (9,9), (10,9), (9,10), (10,10). **Black garbage bag (11,9)**. Blue mailboxes (8,11), (9,11). Fuel can (10,11)
- **wall electrical meter box (9,12)**, AC unit (10,12)
- chair (3,12)+(3,13), bench (3,14)
- street lamps, 1 wide x 2 tall (head on row 6, pole on row 7): curved lamp (2,6)+(2,7), double lamp (3,6)+(3,7), red no-entry sign (4,6)+(4,7), green street-name sign (5,6)+(5,7), blue bus-stop sign (6,6)+(6,7), green park lamp (7,6)+(7,7). Round mirror sign (1,7)
- vehicles (vertical, seen front/back): taxi 2x2 (15..16, 14..15), (18..19, 14..15); van 1x2 (17,14..15), (20,14..15); red cars 2x2 (15..16, 16..17), (18..19, 16..17); red van (17,16..17), (20,16..17); **green bus 2x4 (21..22, 14..17)**
- road tiles (darker asphalt than city_tiles): zebra (0,15..17), (2..4,16); parking outline (5..6, 16..17)

**Characters, cols 23-26:** 6 people x 3 rows. Col 23 = facing left, 24 = facing down, 25 = facing up, 26 = facing right. Within a person's 3 rows: stand, step A, step B. The six blocks start at rows 0 (young man), 3 (woman), 6 (old man), 9 (technician), 12 (Johnny), 15 (girl). Use the re-laid-out sheets in characters/ instead.

### `rpg_tiles.png` (Kenney Roguelike RPG Pack, repacked to remove spacing): 912x496, 57 cols x 31 rows
Brighter palette. Use it for interiors, water and a few plants.
- **interior floors (opaque):** dark wooden boards (5,2), grey stone squares (6,2), beige stone squares (7,2), wooden planks (8,2), (9,2); variants on row 3 (5..9,3); **damaged/cracked wooden floor** (5..9, 4..5)
- plain ground (bright style): grass (5,0), (5,1); dirt (6,0), (6,1); gravel (7,0); sand (8,0); cobble (9,0); grass with stones (9,1)
- water: plain (0,0), (0,1), (0,2). Pond with a grass bank 9-slice: TL (2,0), T (3,0), TR (4,0), L (2,1), C (3,1), R (4,1), BL (2,2), B (3,2), BR (4,2). Pool with a stone rim 9-slice: (2..4, 3..5)
- **grey stone interior / stairwell wall** (opaque): wall face left (24,15), middle (25,15), right (26,15). A version with a horizontal band on row 16 (24..26,16). Plain faces (20..23,15..16). Wall cap with battlements on row 14 (21..26,14), which looks castle-like, so prefer city wall tiles for the top row
- **cracked / damaged walls**: (23,19), (24,19), (25,19), (26,19), (23,20), (24,20), (25,20), (26,20). Broken-wall rubble tops: (20,18), (21,18)
- **interior stairs (steps going up)**: (22,18), (23,18). Beige versions (15,18), (16,18), brown versions (36,18), (37,18)
- arched doorway 3x1 (transparent opening): (24,17), (25,17), (26,17)
- the beige and brown wall sets repeat this layout at cols 13-19 and 34-40, with roofs (gables) on rows 21-24. The brown wooden set at cols 34-40 (walls rows 14-17, roof rows 21-24) can stand in for a **barn**
- plants (transparent): round trees 1x1 (13,9), (14,9), (15,9). Tall trees 1x2: (13..18, 10) top + (13..18, 11) bottom. Conifers 1x1 (16,9), (17,9), (18,9). Bushes (19,9) green, (20,9) orange, (21,9) teal
- low hedge strips: light left/middle/right (19,10), (20,10), (21,10); dark (19,11), (20,11), (21,11)
- **dead tree**: 1x2 (27,9)+(27,10). Small dead tree 1x1 (27,11). Both are exported in props/
- cactus (22,9..11). Berry bushes (23,9..11), (24,9..11). Flowers (28..30, 9)

### `indoor_tiles.png` (Kenney Roguelike Indoors, repacked): 432x288, 27 cols x 18 rows. Furniture only (transparent). Floors and walls come from rpg_tiles or city_tiles.
- tables: long 3x2 (0..2, 0..1), oval (3..4, 0..1), square (5,0..1), round (6,0..1). Chairs (0..3, 2..7). White chairs (0..3, 8)
- **beds** (front view, headboard at the top): single beds (8,6), (9,6), (10,6), (11,6), (8,7)-(11,7), (8,8), (9,8). Double beds 2 wide: (12..13,6), (12..13,7), (14..15,6), (14..15,7), (14..15,8). Side-view beds 2x1: (8..9,0..5), (12..15,0..5)
- **kitchen counters** (grey worktop): rows 12-17, cols 0-9. Drawers (0..3,y), dish rack (4,y), bottles (5,y), (6,y), plates (7,y), **sink (8,12), (8,13), (8,14)**. Counter corner/L pieces (10..11, 12..14)
- **stove/oven** (dark grey with burners): (14,14), (15,14), (14,15). Cot/bed tops with a green blanket: (14,12), (15,12). Grey appliance (fridge/washer): (11,15), (11,16). Dark armchairs (14..15, 16..17), dark tall cabinets (12,17), (13,17)
- wooden cabinets/wardrobe fronts (12..13, 13..16). Long counters/desks (8..10, 15..17)
- rugs: (16..18, 14..17). Small rugs/pictures (19..21, 12..17). Large carpets (23..26, 0..7)
- piano (23..24,8..9). Speakers (25,8..9), (26,8..9). Bookcase/wardrobe (23..26, 10..17). Ladder (21,9..11). Candelabras and lamps (19..22, 0..8). Plants (16,0), (17,0). Clock/shield (22,8..11)

### `farm_crops.png` (josehzz Farming Crops 16x16): 192x160, 12 cols x 10 rows (transparent overlays)
Each row holds 2 crops. Crop A uses cols 0-5 and crop B uses cols 6-11. **Col 0 / col 6 is the harvested item icon. Cols 1-5 / 7-11 are growth stages, ripest first:** col 1 = fully grown, col 5 = seeds.
Rows: 0 turnip | rose, 1 cucumber | tulip, 2 tomato | melon, 3 eggplant | lemon, 4 pineapple | rice, **5 wheat | grapes**, 6 strawberry | cassava, 7 potato | coffee, 8 orange | avocado, **9 corn | sunflower**.
- **field recipe:** fill with city dirt (4,24)/(5,24) and overlay **mature wheat (1,5)** or **corn (1,9)** on every tile. Mix in stages (2,5)/(3,5) for a neglected field. Ripe sunflower: (7,9)

---

## sprites/characters/ (Kenney RPG Urban Pack characters, re-laid out)

Every sheet is **48x64 = 3 cols x 4 rows of 16x16 frames**. Frames are transparent and the feet touch the bottom edge (y = 15).
**Rows: 0 = down (facing camera), 1 = left, 2 = right, 3 = up (back).** **Cols: 0 = stand, 1 = step A, 2 = step B.**
Walk cycle: frames `1, 0, 2, 0` at about 8 fps. Idle: frame 0. Collision: about 10x6 px at the feet (x 3..12, y 10..15).
There are no attack/shoot frames. Show the pistol with `fx_muzzle_flash_strip.png` at the hand in the facing direction, plus a 1-frame recoil offset.

| File | Who |
|---|---|
| `player_johnny.png` | **Hero Johnny**: bald man with a ginger beard, grey T-shirt, dark trousers |
| `npc_technician.png` | technician: orange hard hat, blue-grey overalls |
| `npc_technician_dead.png` | 16x16 single frame: the technician lying on his side (the down/stand frame rotated 90° CCW, head to the left). Flip or rotate as needed. For blood, add a dark-red puddle sprite or modulate |
| `npc_young_man.png` | young man, ginger hair, green T-shirt |
| `npc_old_man.png` | old man, grey hair and beard, green shirt |
| `npc_woman.png` | woman, long red hair, red top |
| `npc_girl.png` | girl, dark hair with an orange headband |

## sprites/enemies/ (derived from the Kenney characters by palette swap)

Same 48x64 layout as the characters (rows down/left/right/up, cols stand/stepA/stepB). Skin is swapped to sickly green, the eyes are red, and the clothes are dirty. A slower walk cycle at about 5 fps reads as a shamble.
| File | Look |
|---|---|
| `mutant_a.png` | green-skinned old man with grey hair, olive-brown rags (from npc_old_man) |
| `mutant_b.png` | green-skinned young man in a blood-red shirt (from npc_young_man) |
For the "burnt" variant, use `modulate = Color(1.0, 0.6, 0.35)`. For death, rotate a frame 90° the way npc_technician_dead does.

## sprites/props/

| File | Size | Content / origin |
|---|---|---|
| `car_{green,gray,orange}_side_left.png` | 48x32 | car seen from the side, 3/4 view, **facing left**. The body fills about 36x24 px, centred at the bottom. For a wreck, `modulate` it darker or brown |
| `car_{green,gray,orange}_side_right.png` | 48x32 | the same, facing right |
| `car_{green,gray,orange}_up.png` | 32x32 | car seen from behind/above, driving **up** (body 22x29) |
| `car_{green,gray,orange}_down.png` | 32x32 | car driving **down**, front visible |
| `thicket_green.png` / `thicket_autumn.png` | 48x48 | **dense 3x3 tree cluster** that blocks a path (urban_tiles (18,8)-(20,10) / (18,11)-(20,13)). Trunks at the bottom row. Collide with the bottom 2/3 |
| `tree_dead.png` | 16x32 | leafless dead tree (rpg (27,9)-(27,10)) |
| `tree_dead_small.png` | 16x16 | small dead tree / stump (rpg (27,11)) |
| `electric_cabinet.png` | 16x16 | tall grey street electrical cabinet (city (27,14)) |
| `control_panel_keypad.png` | 16x16 | grey wall panel with a keypad (city (24,16)). The antenna's control panel |
| `electric_meter_box.png` | 16x16 | wall-mounted meter box with a dial (urban (9,12)) |
| `rubble_large.png`, `rubble_small.png` | 16x16 | dark rubble / rock piles (city (12,13), (13,13)) |
| `tires_pile.png` | 16x16 | pile of tyres (city (14,14)) |
| `crate_cardboard.png` | 16x16 | closed cardboard box (city (13,16)) |
| `crate_wooden.png` | 16x16 | open wooden crate (urban (3,11)) |
| `barrel_orange.png` | 16x16 | orange oil barrel (city (32,3)) |
| `trash_bag.png` | 16x16 | black garbage bag (urban (11,9)) |
| `traffic_cone.png` | 16x16 | traffic cone (city (14,18)) |
| `road_barrier.png` | 16x16 | red/white road barricade (urban (5,8)) |
| `prop_antenna.png` | 22x96 | **radio/LTE mast**, front view (Warped City, darker cyberpunk palette). Thin pole with a lit box and a beacon. Origin at the bottom centre (11, 95). Front-on works in 3/4 view. Its palette is darker than Kenney's |
| `prop_control_box_1.png` | 32x30 | electrical cabinet on legs, front view (Warped City, dark teal) |
| `prop_control_box_2.png` | 17x27 | small electrical box, front view (Warped City) |
| `prop_control_box_3.png` | 62x30 | wide machinery box, front view (Warped City) |
| `airplane_topdown.png` | 32x32 | grey long-wing airplane, **top-down**, nose pointing up (Kenney Pixel Shmup). For the airfield and the ending |
| `airplane_topdown_bomber.png` | 32x32 | grey heavy 4-engine plane, top-down, nose up |

Other masts: the city wooden utility pole (7,16..18), the thin metal mast (11,14..17), and the cable span (7..9,13) can be combined into a cable line.

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
| `item_shears.png` | 32x32 | red-handled scissors / **garden shears ("sekator")** icon (Openclipart via AntumDeluge). In a 16 px world, draw it at scale 0.5 or keep it 32 px in the HUD/inventory |
| `item_wire_cutters.png` | 32x32 | blue-handled wire cutters / pliers (alternative "sekator" or cable tool) |
| `item_cable.png` | 32x32 | coiled thin brown cable/rope (**cable item**) (Fleurman) |
| `item_sickle.png` | 32x32 | sickle (alternative cutting tool / machete stand-in) |

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

Note: `player_hurt_1/2.ogg` and `player_death.ogg` are **female** voice recordings. The hero is now Johnny (male), so pitch them down (`pitch_scale` about 0.75) or replace them.
