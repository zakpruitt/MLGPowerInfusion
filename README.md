# MLG Power Infusion

Makes your Power Infusion windows dank.

When you gain Power Infusion, a 15 second cut of SICKEST MLG 360 NOSCOPE 2016 plays (timed so the drop hits mid-window) and a banner pops up at the top of your screen with a random message.

Works on retail and WoW: Forever.

## Commands

| Command | Description |
|---|---|
| `/mlgpi test` | Play the sound and banner |
| `/mlgpi status` | Show whether the sound and banner can fire in combat on your client |
| `/mlgpi debug` | Print how Power Infusion is being detected |
| `/mlgpi toggle` | Turn the addon on/off |
| `/mlgpi alert` | Turn the banner on/off (sound still plays) |
| `/mlgpi master` / `sfx` / `music` / `ambience` / `dialog` | Pick which volume slider controls the sound (default: Master) |

You can also click the addon in the addon compartment (the button by the minimap) to test it.

## Custom messages

Edit `Messages.lua`. `{player}` is replaced with your character name, and `batchest = true` shows the batchest emote next to that message.

## How detection works

Blizzard hides Power Infusion from addons in combat, so the addon registers the sound with Blizzard's aura sound system (`C_UnitAuras.AddAuraSound`). The game plays it when you gain PI, even in combat, M+ and raids.

- **Sound:** works everywhere. It is registered out of combat (login, `/reload`, or leaving combat) because Blizzard blocks registering in combat.
- **Full track:** Blizzard stops aura sounds after 5 seconds, so only the first 5 seconds are registered. The addon plays the rest itself, timed to pick up where the first part ends. Out of combat it sees PI land; in combat it goes off your own PI cast. If someone else gives you PI in combat, you only hear the first 5 seconds.
- **Banner:** uses Blizzard's aura frame (`AuraContainer`), which the game shows by itself while PI is on you, so it also works in combat. Blizzard blocks addons from reacting when that frame appears, so the banner is drawn from the aura's own timer: the game swaps in the message and fades it out (background, logo and batchest included) 3.5 seconds after PI lands. A new random message is picked each time you leave combat.
- **Fallback:** if a client can't register aura sounds, the addon watches for PI itself. That only works while the game lets addons read your buffs, so it may miss PI in combat. `/mlgpi status` shows which path your client uses.

<!-- portfolio
section: more
name: MLG Power Infusion
year: 2026
summary: A World of Warcraft addon that plays an MLG air horn when you get Power Infusion.
-->
