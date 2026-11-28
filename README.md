# Cardgam

Cardgam is a Godot 4.7 prototype for a real-time arena deckbuilder. Import
`main/project.godot` in Godot and press F5, or run `godot --headless --path main --import` once, then `godot --path main`.

- Move with WASD or the arrow keys.
- Play with 1–4 or click a card. Its slot refills from the draw pile and the
  played card goes to the back of the cycle. Attacks with single targets aim
  at the nearest enemy.
- Survive the first fight, draft one card from a three-card booster, and choose
  whether to defend the ferryman’s beacon or face the road captain.
- Finished runs earn embers even on defeat. Spend three to unlock the Warden,
  who starts with a defensive special. Progress is saved locally by Godot.

The PNGs in `main/art` include two single-frame, right-facing sprites and a
four-tile isometric terrain atlas. The atlas stores 64 × 32 tiles left to right.
