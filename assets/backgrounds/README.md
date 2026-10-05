# Background photos

The app background (`ui/backdrop.gdshader`, `scripts/ui/backdrop.gd`) is a soft dark gradient.
A photo in this folder is shown **blurred, darkened and faded towards the bottom**, so the panels and
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
- Landscape, about 1920 px wide, a calm composition works best. Busy, bright detail is blurred away.
- Only add photos you are allowed to use. Note the source, author and licence below.
- Strength and blur are `photo_strength` and `blur_lod` in `ui/backdrop.gdshader`.
- Open the project in Godot once after adding a file so it gets imported.

## Photos used and credits

All from Wikimedia Commons, licence CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/).
Cropped to 16:9 and downscaled; the blur/darkening is applied in the game.

| File here | Original | Author | Date |
|---|---|---|---|
| `career_hub.jpg` | [Kalevan Kisat 2018 - Women's 800 m - Jemina Forss 1.jpg](https://commons.wikimedia.org/wiki/File:Kalevan_Kisat_2018_-_Women's_800_m_-_Jemina_Forss_1.jpg) | Tuomas Vitikainen | 22 Jul 2018, Harju Stadium, Jyväskylä |
| `race.jpg` | [Kalevan Kisat 2018 - Women's 800 m - Sara Kuivisto 4.jpg](https://commons.wikimedia.org/wiki/File:Kalevan_Kisat_2018_-_Women's_800_m_-_Sara_Kuivisto_4.jpg) | Tuomas Vitikainen | 22 Jul 2018, Harju Stadium, Jyväskylä |
| `default.jpg` | [Lahti Stadium 2021.jpg](https://commons.wikimedia.org/wiki/File:Lahti_Stadium_2021.jpg) | Kallerna | 27 Jul 2021, Lahti Stadium |

TODO: show these credits inside the game (a Credits screen) before any release.
