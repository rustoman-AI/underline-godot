# Underline playtest

A 40-week station on the Coney Island line. You run the yard. The rivals move in the tunnels, but this build is the station half: dig, build, staff, pass laws, and get through the week.

## Windows

Unzip the folder and run `Underline.exe`.

## Web

Unzip the folder. The page will not load if you open `index.html` straight from the disk. From that folder, in PowerShell:

```
python -m http.server 8060
```

Then open `http://localhost:8060`. If Python is not installed, use the Windows build.

## How a week goes

Dawn opens with the stocks and any choice that is waiting. Pick one. On the cut-away, tap a dark cell to dig, an open floor to build, and a room to staff, upgrade, or pull it down. Drag a resident onto a room, or tap the room and filter the list. The best skill for that room is listed first, with the number beside the name.

End turn closes the week. If someone is still waiting, the dawn card stays up until you choose.

Pump is only there during a flood, and it spends materials and power. Quarantine is only there during the cough.

## What to look at

- A button that will not fire says what is missing, on the button. "Needs 4 power. You have 0 power."
- Tap a resource in the top bar. It says what the yard makes, what it uses, and where that resource will be by dawn. If power will not cover the rooms, those rooms get a red edge.
- Pulling down a room that makes something you are about to run out of asks you to confirm, and names what stops.
- Some week between 11 and 16, three bills arrive at once. Materials can cover two of them. The third one lands.

## What this build is not

No network map, no bunker scene, and no ending beyond the week-40 clock, a revolt, or the yard emptying. The rooms are flat colors, not painted art.
