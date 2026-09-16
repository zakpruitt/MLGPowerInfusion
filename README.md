# Power Infusion MLG

Makes your Power Infusion windows dank.

When you gain Power Infusion, a 15 second cut of SICKEST MLG 360 NOSCOPE 2016 plays (timed so the drop hits mid-window) and a banner pops up at the top of your screen with a random message.

## Commands

| Command | Description |
|---|---|
| `/pimlg test` | Play the sound and banner |
| `/pimlg toggle` | Turn the addon on/off |
| `/pimlg alert` | Turn the banner on/off (sound still plays) |
| `/pimlg master` / `sfx` / `music` / `ambience` / `dialog` | Pick which volume slider controls the sound (default: Master) |

You can also click the addon in the addon compartment (the button by the minimap) to test it.

## Custom messages

Edit `Messages.lua`. `{player}` is replaced with your character name, and `batchest = true` shows the batchest emote next to that message.

## How detection works

Blizzard hides Power Infusion from addons in combat, so the addon registers the sound with Blizzard's aura sound system (`C_UnitAuras.AddAuraSound`). The game plays it when you gain PI, even in combat, M+ and raids.

- **Sound:** works everywhere. It is registered out of combat (login, `/reload`, or leaving combat) because Blizzard blocks registering in combat.
- **Banner:** uses Blizzard's aura frame (`AuraContainer`), which the game shows by itself while PI is on you, so it also works in combat. Blizzard blocks addons from reacting when that frame appears, so the banner is drawn from the aura's own timer: the game swaps in the message and fades it (and the background) out 3.5 seconds after PI lands. A new random message is picked each time you leave combat.
