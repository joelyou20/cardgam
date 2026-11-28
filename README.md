# Cardgam

Cardgam is a Godot 4.7 prototype for a real-time arena battler. Import
`main/project.godot` in Godot and press F5, or run
`godot --headless --path main --import` once, then `godot --path main`.

- Move with WASD or the arrow keys and aim with the mouse. The isometric terrain
  scrolls continuously.
- Left click attacks, right click uses the secondary attack, Space uses the
  movement ability, and R uses the special. Movement follows your movement
  keys, or the mouse if you aren't holding a direction.
- Each character has four fixed abilities and its own pool of passive cards.
  Draft one augment from each booster to build your deck for the current run.
  Drafted augments take effect automatically.
- After the first fight, choose whether to defend the beacon or face the road
  captain. Finished runs earn embers even on defeat. Spend three to unlock
  the Warden. Progress is saved locally by Godot.

The PNGs in `main/art` include two single-frame, right-facing sprites and a
four-tile isometric terrain atlas. The atlas stores 64 × 32 tiles left to right.
