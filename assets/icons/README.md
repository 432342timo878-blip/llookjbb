# Icons

**Lucide** icons, version **0.460.0** (https://lucide.dev, files from https://unpkg.com/lucide-static@0.460.0/icons/), **ISC
licence** (the text is in `LICENSE` beside this file; keep it with the icons). Downloaded 2026-10-23 for session L1a (GDD 5 "The
look (V1)", "Icons").

One change to every file: `stroke="currentColor"` became `stroke="#ffffff"` (Godot's SVG importer has no "current colour"), so the
icons are white and the game tints them with `modulate` (`Icons.rect(name, size, colour)`, `scripts/ui/icons.gd`). Each `.import`
renders the SVG at 4× (96 px) with mipmaps, so it stays sharp when drawn at 13–20 px on a high-resolution screen.

What each one means in the game (GDD 5): easy run `footprints`, drills / strides `zap`, strength `dumbbell`, club group `users`,
tempo / intervals `timer`, long run `route`, mobility `person-standing`, rest `moon`, race `flag`, test `pencil-line`, study
`book-open`, family `house`, a friend `user-round`, an invitation `party-popper`, the coach's note `message-circle`, a warning
`triangle-alert`, confidence `smile`, race tactics `crosshair`, composure `shield`, aerobic `trending-up`, a day slot `sun`, an evening
slot `moon`, Play week `play`. The tab bar: This week `calendar-days`, Season `align-left`, Calendar `calendar`, People `users`,
Career `trophy`, Rankings `list-ordered`. The rest are there for the screens that follow (L2, L3, K1).

To add an icon: download `https://unpkg.com/lucide-static@0.460.0/icons/<name>.svg`, make the same `currentColor` change, copy one
of the `.import` files next to it with the new file name inside, and run `godot --headless --import` once. Athletics icons Lucide
does not have (a runner, spikes, the track oval) are drawn in the same 24 px / 2 px style and say so here.
