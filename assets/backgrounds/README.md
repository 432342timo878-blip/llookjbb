# Background photos (optional)

The app background (`ui/backdrop.gdshader`, `scripts/ui/backdrop.gd`) is a soft dark gradient.
Drop a photo in this folder and it is shown **blurred, darkened and faded towards the bottom**, so the panels and
text on top stay readable.

File names (`.jpg`, `.png` or `.webp`), the first one found wins:

| File | Used on |
|---|---|
| `main_menu.jpg` | main menu |
| `new_career.jpg` | character creation |
| `career_hub.jpg` | career hub (all tabs) |
| `race.jpg` | race screens |
| `load_game.jpg` | load screen |
| `default.jpg` | any screen without its own file |

Tips
- Landscape, at least 1920 px wide, a calm composition (a track, a stadium, a runner at the edge) works best.
  Busy, bright detail is blurred away, but a photo with a big dark area looks best.
- Only add photos you are allowed to use (your own, or e.g. Wikimedia Commons with a free licence). Note the
  source and licence in this README.
- Strength and blur are `photo_strength` and `blur_lod` in `ui/backdrop.gdshader`.
- Open the project in Godot once after adding a file so it gets imported.

Photos used: none yet.
