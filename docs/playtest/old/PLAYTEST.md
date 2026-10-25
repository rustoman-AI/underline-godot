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

Dawn opens on a card: the stocks, and a choice when one is waiting. Pick a choice, or press Not now to set it aside. On the station, tap a dark cell to dig, an open floor to build, and a room to staff, upgrade, or pull it down. Drag a resident from the People drawer onto a room, or tap the room and pick a name. The best skill for that room is listed first, with the number beside the name.

End turn closes the week. While a choice is still waiting, End turn stays dark. Hover it and it says someone is waiting. The button wakes up once you choose. If you pressed Not now, the button pulses until you do.

Pump is only there during a flood, and it spends materials and power. Quarantine is only there during the cough.

## What to look at

- A button that will not fire says what is missing, on the button. "Needs 4 power. You have 0 power."
- Tap a resource in the top bar. It says what the yard makes, what it uses, and where that resource will be by dawn. If power will not cover the rooms, those rooms get a red edge.
- Pulling down a room that makes something you are about to run out of asks you to confirm, and names what stops.
- Some week between 11 and 16, three bills arrive at once. Materials can cover two of them. The third one lands.

## What's new

- Network. The Network button opens the tunnel map. From a neighbor you can trade, and the Directorate moves squads, sends demands, and can take a station. The first station they take is one of the two neutral stops beside their squad, and it is not the same every game.
- Checks. Some dawn cards are a roll: two dice plus a resident's skill. A white check can be tried again once the card's requirement is met. A red check is a single roll. You pick who goes. When the skill is tied, a named Coney resident is offered first.
- The Coney cast. Five residents have names, skills, and a dossier: Old Man Coney, Salty Maggie, Bait, Barnum, and Sylvia the Mermaid. Open a person from the People panel.
- Menu and saves. The game opens on Continue, New game, Settings, and Credits. Settings cover the master, music, and effect volumes, fullscreen or a window, the interface scale, and reduced motion. During a game, Menu has Save and Load. Each week also saves on its own.

## What this build is not

No bunker scene, and no ending beyond the week-40 clock, a revolt, or the yard emptying. Pinch or scroll to look closer. The station is drawn for a wide landscape frame.
