# R6a research: viewpoints, track specs, Godot 3D (2026-11-08)

Done before building the three viewpoint prototypes (GDD 4.11 "Built (step R6a)"). Read dates: all web pages 2026-11-08. What is
confirmed, what is not, and what the prototypes took from it.

## 1. The track: World Athletics specs

| Fact | Value | Source / status |
|---|---|---|
| Outdoor 400 m standard track | two semicircles of radius **36.50 m** + two straights of **84.39 m**; lane width **1.22 m ± 0.01** | World Athletics (IAAF) Track and Field Facilities Manual 2008, section 2.2.1, **quoted second-hand** (Timo Denk's blog, [blog.timodenk.com/length-of-outer-running-track-lanes](https://blog.timodenk.com/length-of-outer-running-track-lanes/)) and in the Finnish federation's copy of the manual's Marking Plan S ([yleisurheilu.fi PDF](https://www.yleisurheilu.fi/wp-content/uploads/2026/02/Track-and-Field-Facilities-Manual-Marking-Plan-S.pdf), listed by the search; **the PDF itself was not opened**). Matches `Race` (`r_in` 36.5, `straight` 84.39, `LANE_W` 1.22) and the old top-down drawing exactly: the prototype uses the engine's numbers. |
| Race line | measured 0.30 m from the kerb (raised kerb) / 0.20 m (painted line) | one weak commercial page; the engine uses `r1` = 36.8 (0.30 m). **Verify** against the manual before the real stadium build. |
| Minimum inner radius 36.80 m | one page says so | conflicts with 36.50 m: probably the measuring line (36.5 + 0.3), not the kerb. Not used. |
| Indoor 200 m track | circumference 200 m, ~35 m straights (with 17.2-19 m radii), 4-8 lanes, lane width ~1.00 m | **weak**: one commercial page. The engine's indoor track is r 17.2, straights 45 m... and uses 1.22 m lanes (not 0.90-1.10 m) and a **flat** track; real hall tracks are **banked** in the bends. **To verify from the current manual's indoor section in R6b** (the lane width and the bank change how a hall looks and how bends are run). Prototype: engine numbers, flat. |
| Rules the engine already follows | 800 m: lanes for the first bend outdoors, two bends indoors (World Athletics since 1 Nov 2025) | GDD 4.3.1 decision 29. |

## 2. Athletics TV: what a broadcast shows and from where

The search did not find a document describing a standard 800 m graphic set (the European Athletics Broadcast Guidelines have a "shot by
shot guidelines for producing track events" section and a TV graphics section, but only the contents page was readable:
[Broadcast_Guidelines_web.pdf](https://publications.european-athletics.org/organisationalmanual/wp-content/uploads/sites/11/2021/08/Broadcast_Guidelines_web.pdf);
**the shot list was not read**). What the sources do say:

- **Timing data drives the graphics:** a live leaderboard, split times (distance races typically every 100 m) and the lap counter
  ([PT Timing atlas](https://www.pttiming.com/services/atlas)); distance-to-finish and the gap of the chase group to the leader are on-screen
  graphics ([Racemap](https://go.racemap.com/blog/live-graphic-coverage-location-data)).
- **Cameras:** a **side-on tracking camera** (on a rail or from the grandstand), a start-line camera, an **overhead** camera, plus head-on
  views of the finish straight ([Datavideo case study](https://datavideo.com/ru/article/95/2021-07-26-05-00-48)); newer AR graphics
  anchored to the track (Grand Slam Track, Birmingham 2026: floating data on the track) are the closest thing to our plan line and cues.
- **Not found:** how broadcasters draw a pace line / "ghost runner" for an 800 m. That one is Claude's design (a glowing bar across the track
  at where an even split would be now, like the World Athletics' pacing lights on the infield, which are real in distance meetings).

Taken into the prototypes: position board with gaps in seconds (leader's time at the finish, then +gaps), the race clock with metres to go,
split flashes at 200 / 400 / 600 m and the finish, a track map, name flags over the runners, a TV side camera on the infield side with a
head-on shot for the home straight, a top-down view.

## 3. Godot 3D / 2.5D on the Compatibility renderer (4.7)

From the [Godot renderer overview](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) (4.6 / 4.7 pages): the
Compatibility renderer is the lowest cost, built for low-end desktops and mobile, OpenGL based; **8 omni lights per mesh** (raisable),
**MSAA for 3D** yes, TAA no. The pages did not list MultiMesh, glow or shadow limits in the part that was readable. **What was tried
instead** (run in the real game's renderer, `--rendering-driver opengl3`, here through ANGLE on the user's PC):

- One directional light with shadows, `Environment` with colour background and ambient light, MSAA 2x, Filmic tone map: **works**.
- Crowd and advertising boards as **MultiMesh** (about 4 000 coloured boxes with per-instance colour): **works**, cheap.
- Additive transparent quads (effort glows, the plan line): **work**. A one-sided ceiling facing down (invisible from above): works.
- Label3D with billboard and no depth test (name flags, cues): **works**; sizes scaled with the camera distance in code.
- **Not tried:** a real phone. The scene is ~9 figures x 17 boxes + ~4 000 crowd boxes + ~600 stand quads: light, but the phone is the
  open risk the GDD already names (the viewpoint session of R6b measures it).

## 4. Runner models

The user chose **figures built in code** (2026-11-08): 17 shapes each (torso, head, shorts, 2 x thigh + shin + shoe, 2 x arm + forearm),
legs and arms swung by a phase that is a function of the distance run (no foot sliding, nothing to store), knees lifting with speed,
a lean forward, a lying pose after a fall. **No download was made.** A real CC0 model (with a run cycle that can be driven by speed) can be
looked for in R6b if the chosen view needs more realism; every download then needs the user's OK first.
