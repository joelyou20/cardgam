# Cardgam

Cardgam is a Godot 4.7 prototype for a real-time arena battler. Import
`main/project.godot` in Godot and press F5, or run
`godot --headless --path main --import` once, then `godot --path main`.

- Move with WASD or the arrow keys and aim with the mouse. The isometric terrain
  scrolls continuously.
- Left click attacks, right click uses the secondary attack, Space uses the
  movement ability, and R uses the special. Movement follows your movement
  keys, or the mouse if you aren't holding a direction.
- Player-side damage has a 10% chance to crit for double damage. The road
  captain's heavy hits count as critical hits. Sprites flash red on regular
  hits and white on crits, and enemy damage numbers float up from the target.
- Each character has four fixed abilities and its own pool of passive cards.
  Draft one augment from each booster to build your deck for the current run.
  Drafted augments take effect automatically.
- After the first fight, choose whether to defend the beacon or face the road
  captain. Finished runs earn embers even on defeat. Spend three to unlock
  the Warden. Progress is saved locally by Godot.

Choose **Play** from the main menu to open the roster, or **Unlocks** to see
requirements and progress. Vanguard is available from the start. Warden costs
three embers. Unlock Gier with 30 defeats across finished runs, Moonrose by
defending the beacon, Xola Kain by drafting four augments across runs, and the
Necroblade by defeating the road captain. Each character has a separate pool
of passive augments.

| Character | Left click | Right click | Space | R |
| --- | --- | --- | --- | --- |
| Gier | Delayed ground eruption | Line strike | Leap and slam | Three-second moving whirlwind |
| Moonrose | Piercing arrow | Knockback arrow fan | Teleport and vanish | Five-second barrage at the cursor |
| Xola Kain | Out-and-back boomerang | Two-orbit boomerang | Leap and leave a stun trap | Pull and stun with a net |
| The Necroblade | Siphon health in a cone | Raise slain enemies as skeletons | Teleport and leave a lure totem | Detonate surviving summons |

The PNGs in `main/art` include single-frame, right-facing sprites and a
four-tile isometric terrain atlas. The atlas stores 64 × 32 tiles left to right.
