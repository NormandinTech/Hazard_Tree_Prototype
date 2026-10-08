# HAZARD TREE — Prototype (Shifts 1–5, full run)

Month 1 gray-box prototype: walking, flashlight, camcorder, tagging, and filing the work order on one burn-scar parcel.

## Run it

1. Install Godot 4.3 or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, and select `project.godot` in this folder.
3. Press **F5** (Run Project).

The first import takes a moment while Godot scans the scripts. If anything errors, copy the message from the Output or Debugger panel.

## Controls

| Key | Action |
| --- | --- |
| WASD | Walk |
| Shift | Sprint |
| Mouse | Look |
| Right mouse (hold) | Raise camcorder / record |
| F | Flashlight (battery drains) |
| Tab | Tablet: work order |
| Q (tablet open) | Switch between Work Order and Tapes |
| Up/Down, Space, Left/Right | Tapes: select, play/pause, scrub |
| 1 / 2 / 3 | Tag a recorded tree: Remove / Monitor / Retain |
| 4 | Flag a gas leak / mark remains for the coroner |
| 5 (hold) | Backpack pump: spray water on fires |
| F10 | Graphics quality: Medium / High / Low |
| E | File the work order at the truck · talk to / water / pick up an animal |
| Esc | Pause menu: resume, fullscreen, graphics, quit |
| F11 / Alt+Enter | Toggle fullscreen |

## How Shift 1 plays

1. Open the tablet to read the six trees on the work order.
2. Find each tree (orange flagging tape, painted ID).
3. Hold right mouse on it for 3 seconds to record it.
4. Walk up and tag it with 1, 2 or 3.
5. Return to the truck and press E to file.

Every camcorder session is saved as a tape (last 6 kept, up to 15 s each). Rewind them on the tablet.

Two things only exist through the camcorder (render layer 2): a dark figure that moves every time you lower the camera, and a tree that is not on the map. The image tears when they are in frame. A third thing only exists on the tapes: something standing behind two of the work-order trees while you record them. Live, it shows for a single frame.

## Files

- `scripts/main.gd` — builds the parcel, work order, truck, stump hole, anomalies; runs the shift
- `scripts/player.gd` — movement, flashlight, camcorder, assess and tag
- `scripts/hazard_tree.gd` — burned tree, flagging tape, painted ID, tag paint
- `scripts/hud.gd` — prompts, battery, camcorder overlay, tablet (work order + tapes), end card
- `scripts/recorder.gd` — captures camcorder tapes for replay
- `scripts/audio.gd` — loads optional sounds from `audio/` and plays them
- `scripts/town.gd` — the burned neighborhood: roads, chimneys, slabs, mobile-home frames, cars, poles. Town and street names are at the top.
- `scripts/truck.gd` — the hazard-tree crew truck
- `scripts/task_item.gd` — non-tree work-order items: gas leaks, the chimney to film
- `scripts/flashback.gd` — the lot as it was before the fire (shown only on tape frames)
- `scripts/director.gd` — the stalker, falling snags, random events
- `scripts/stalker_tree.gd` — the thing that hunts you: a burned snag with a hollow face
- `scripts/note.gd` — HT-6's clipboard notes (text lives in `NOTES` at the top of main.gd)
- `shaders/vhs.gdshader` — camcorder look

Everything is built in code, so there is one tiny scene file and no art assets yet.

## Next steps (Month 1 → 2)

- Swap gray-box trees for low-poly models

## Audio

Put sound files in `audio/` (ogg, wav or mp3) named: wind_loop, creak_1-3, step_1-4, camcorder_on, camcorder_loop, chainsaw_far, flashlight_click, spray, glitch. Missing files are skipped. On launch, the Output panel prints how many loaded and which are missing.

## Shifts

Filing the work order fades into the next shift. Shift 2 (afternoon) adds six deeper trees and two re-checks: trees from Shift 1 whose tags "went missing". Your old paint turns up on a tree you never touched. The figure moves closer, creaks come faster, and once per shift something stands in the open on tape while you film on the move.

Optional sound: `chainsaw_close` (ogg/wav/mp3) is used in Shift 2; without it the game falls back to `chainsaw_far`.

Testing shortcut (editor runs only): **F9** completes the current work order and skips to the next shift.

Shift 3 (dusk) adds gas leaks on burned slabs (hissing meter risers with vapor; flag with **4**) and an owner's request to film a standing chimney. Partway through filming, the tape cuts to the same lot before the fire: the house standing, green yard, pines, the family car, a kid's bike. Live, it only flickers for single frames.

Optional sound: `gas_hiss` (ogg/wav/mp3). Without it, the game generates its own hiss.

Shift 4 (night): the search team came through overnight. Their orange "X" marks are on the chimneys (only visible in your light), coroner's markers sit on two lots, and the radio sends you to a third place they missed (RPT-1): a tarp over a shape. Mark it with **4**. Nothing is ever shown under the tarp.

Two jump scares, each fires once: the figure at the lens when you raise the camcorder after finishing a few items, and the truck radio when you head back with most of the order done. Optional sound: `sting` (ogg/wav/mp3); without it the game uses `glitch`.

Standing near the truck recharges the flashlight.

Shift 5 (before dawn, final): one item, HT-500, the stump hole. On the walk the town flickers back to how it was before the fire (daylight, green yards, houses, and the great pine where the hole is now), longer and more often the closer you get. The past is silent. At the hole, **E** climbs down. The game ends on the tape.

## Horror pass

- **The stalker (Shifts 2–5).** Only the camcorder can see it, and it only moves while it is NOT in your camcorder's frame. Listen for footsteps. Film it for a few seconds and it backs off for a while. If it reaches you, you black out, wake at the truck with 35% light, and the paint on your last-tagged tree is gone. Your flashlight stutters when it's close.
- **Falling snags.** A dead tree near you groans; about a second and a half later it comes down toward you. Get out from under it or you're knocked out. Fallen snags stay down.
- **Random events.** Footsteps behind you, your light cutting out, a chainsaw starting right behind you, radio chatter, and a line on your tablet that shouldn't be there.
- **HT-6's notes.** Eight clipboard pages from the assessor before you, near trees across all five shifts. **E** picks one up; read them on the tablet's NOTES page (Q). The note text is a draft at the top of main.gd, meant to be rewritten.
- Shifts 2–4 have two more trees each, and recording a tree takes 5 seconds.

Tuning lives in each shift's config in main.gd: `stalk` (speed), `cool_min`/`cool_max` (seconds before it returns), `falls` and `events` (average seconds between them).

## Story and Sierra Northern Power pass

- **Opening.** Typed cards before Shift 1 set up the fire, Sierra Northern Power, and HT-6. Space or E advances; text is in `INTRO` at the top of main.gd.
- **The stalker is a tree.** A burned snag with roots splayed and a hollow knot of a face, embers in its sockets. Painting **REMOVE** on a tree brings it sooner.
- **Poles and transformers (PL-, XF-).** Sierra Northern Power wants condition reports. Film the pole or the transformer can (5 s), then rate it with 1/2/3 (pole: Replace / Repair / OK; transformer: Leaking / Damaged / OK). Look for oil weeping down the pole.
- **Tower 7/22 (Shift 4).** The origin tower by the hole, with an empty insulator string and a worn-through hook. The fallen line runs from it to the stump hole. Investigators want 8 s of footage; SNP doesn't.
- **A burned SNP bucket truck** on Old Mill Rd.
- **The ending.** Down in the hole, the tree rises over the rim beside the watcher and its roots grow across the opening.
- **Look (story pass).** Full-resolution rendering, ACES tone mapping, ambient occlusion, glow, volumetric haze (your flashlight casts a beam), a real sky, surface relief on every material, and thousands of pebbles, twigs and green shoots on the ground.

## Realism pass

- **Real textures (optional).** Make a `textures` folder next to `project.godot`. Put one folder per surface inside it, named exactly as below, with the files straight out of the download (2K JPG is plenty). The game finds the color, normal, roughness and AO maps by their file names, so don't rename the files, only the folder. A missing folder keeps the built-in look. The Output panel prints which sets loaded.

  | Folder | What to download (ambientCG / Poly Haven, CC0) |
  | --- | --- |
  | `ground_ash` | burnt ground, ash, dark forest floor |
  | `soil` | bare dirt, dry soil |
  | `gravel` | gravel |
  | `asphalt` | worn asphalt / road |
  | `concrete` | old concrete slab |
  | `brick` | old red brick |
  | `charred_wood` | burnt or charred wood |
  | `burnt_bark` | burnt bark (or any dark bark) |
  | `bark` | pine bark |
  | `rust` | rusted metal |
  | `metal` | weathered painted metal |
  | `rock` | rock / stone |
  | `grass` | green grass (the flashbacks) |
  | `roof` | roof shingles (the flashbacks) |

  Example: `textures/brick/Bricks076_2K-JPG_Color.jpg`, `..._NormalGL.jpg`, `..._Roughness.jpg`.
- **Flashlight** has a real beam pattern (hot center, reflector ring, dim spill) and soft shadows.
- **Ash** drifts down around you, **embers** lift off the ground at night, and some **stumps are still smoldering** (coal glow and a thread of smoke).
- **Ground mist** in patches that drift (Forward+ only).
- **Lens** on your own view: fine grain (heavier in the dark), edge fringing, dark corners. It fades out when the camcorder is up.
- **Vehicles** (`scripts/vehicles.gd`) are shaped bodies now, not stacked boxes: a real side profile with a sloped hood and windshield, a roof that narrows above the doors, wheel arches with dark wheel wells, glass, door seams, handles, mirrors, bumpers and lights, and tires with rims and lug nuts. Burned cars are ash-gray and rusted, have no glass, and sit on bare rims. Some are wagons. The crew truck and the burned SNP truck share the same pickup cab.

## Graphics pass

- **Graphics quality: F10** cycles Medium → High → Low (the game starts on Medium). High adds full global illumination (SDFGI) and 4x anti-aliasing; Low turns off haze, ambient occlusion and bounce light and renders a bit below full resolution for slower machines.
- **Bounce light** (Medium and up): your flashlight spills off walls, slabs and trunks onto what's around them.
- **Soft sun shadows** that sharpen where objects touch the ground, and a sharper shadow map for the flashlight.
- **Trees** are one continuous trunk each now: flared roots, vertical bark ridges the flashlight rakes across, a trunk that wanders as it climbs, splintered tops on snapped trees, and more branches with twigs. Tree IDs are spray paint you only see when light hits them.
- **Chimneys** have a real shape: hearth slab, firebox with an opening and steel lintel, sloped shoulders, a narrower stack with a corbel band, a broken top that's lost bricks, a terracotta flue liner, and fallen bricks around the base.
- **Corrugated roofing** is real ribbed sheet metal now, curled and twisted.
- Fire-stained concrete and scorched appliances.

## Fires and survivors

- **Backpack pump (hold 5).** A bladder bag of water with a wand. About 14 seconds of spray; it refills while you stand at the truck. The WATER gauge sits above LIGHT.
- **Spot fires.** The smoldering stumps around the parcel can be soaked out: aim at the glow and hold 5 for a couple of seconds. They throw steam and go dark.
- **The rekindle (Shift 2, FIRE-1).** A debris pile burning on a lot near the parcel: real flames, sparks, a smoke column, crackling. It's on the work order. Keep the water on it for several seconds; if you stop early it creeps back up. Don't stand in it.
- **Survivors** you can help or walk past:
  - **Shift 1: Biscuit, a dog** hiding by a burned car with a burned paw. Walk up (running makes it bolt), press E and stay close while you talk to it. It follows you to the truck and you tie it there.
  - **Shift 1: a rabbit** in the open. Offer it water (E).
  - **Shift 2: a cat** on a chimney hearth. Water it (E), pick it up (E), carry it to the truck. You can't spray while holding it.
  - **Shift 2: Maggie, an old gray dog** hiding under a manufactured home's chassis on the right side of the parcel. Same as Biscuit.
  - **Shift 3: a fawn** in the open, with its mother watching from the tree line. Water it and it walks back to her; they leave together.
  - **Shifts 3 and 4: skunks.** Offer water slowly. Run at one, crowd it, or hit it with the pump and it sprays you: your view goes yellow-green for about 25 seconds.
- **Wildlife.** Rabbits nibble at the ash and hop off when you get close. Squirrels dart up the nearest dead tree and wait for you to leave. At night their eyes catch your flashlight. Shift 5 has none: nothing moves out there anymore.
- **It matters.** A rescued dog (either one) growls from the truck whenever the thing comes back for you. Leave the dog, and in Shift 4 you'll hear a dog whimpering out in the dark, right where you left it. Go and look. The final evidence card lists who was found alive at the truck.
- Optional sounds (in `audio/`): `dog_growl`, `dog_whimper`. Fire crackle and the pump hiss are generated in code.

## Fullscreen and pause

The game starts fullscreen. F11 (or Alt+Enter) switches to a window and back. Esc pauses: Resume, Fullscreen, Graphics quality, Quit to desktop.

## Making a playtest build (Windows)

1. In Godot: **Editor > Manage Export Templates > Download and Install** (once; it matches your Godot version).
2. **Project > Export**. A "Windows Desktop" preset is already set up. Click **Export Project**, turn **off** "Export With Debug", and save. By default it writes `HazardTree.exe` into a `HazardTree-Playtest` folder next to your project folder.
3. Zip that folder and share it. Players unzip and double-click `HazardTree.exe`.
