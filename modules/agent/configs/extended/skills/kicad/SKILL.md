---
name: kicad
description: Drive KiCad's PCB editor or 3D viewer on a run's desktop with the desktop tools. Read before the first desktop action in KiCad.
---

# KiCad on the desktop

Checked on KiCad 10.0.7, Xvfb 1280x800, Mesa llvmpipe.

- Start KiCad from the run's nixpkgs: `nix shell nixpkgs#kicad -c pcbnew <board>.kicad_pcb &`. KiCad from an older nixpkgs or a project flake cannot load the run's Mesa and shows "Could not use OpenGL" and a blank 3D viewer. The whereami skill says why.
- To zoom on a part in the 3D viewer, move the pointer over the part and press Space first. Space makes that point the pivot and the view centre. The 3D wheel zooms about the view centre, not about the pointer, so without Space the part leaves the screen.
- The 3D viewer paints the footprint under the pointer green. Before you read a colour in the 3D viewer, move the pointer off the board onto the background.
- In the 3D viewer the sideways wheel zooms: right zooms in, left zooms out. In the PCB editor the sideways wheel pans.
- F1 and F2 zoom the PCB editor and also move the pointer to the canvas centre. Read the pointer position again before a click. The wheel does not move the pointer.
- After a 3D view key such as Shift+Z (bottom), Z, X, Y or Home, wait 1.2 s. KiCad turns the board in an animation of about 1 s; a screenshot before that shows a half-turned board.
- A middle drag pans the PCB editor and the 3D viewer. Send it as a batch `drag` with `button: "middle"`. Ctrl+wheel also pans left and right, and Shift+wheel up and down.
- In a file dialog, an Enter sent straight after typing a path does nothing. Wait about 1 s after typing, press Enter, and check in the screenshot that the dialog closed.
- `zoom` enlarges the screen pixels and adds no detail. To read small text on the board, zoom with KiCad (wheel over the text, or F1) and take a new screenshot.
