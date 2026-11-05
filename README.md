<h1 align="center">🧪 roblox-with-swe</h1>

<br>

<h3 align="center">A Roblox game built like a software project.<br>Code, tests, collaboration, and releases—explored on Linux</h3>

<p align="center">
  <a href="https://github.com/Petri-Hub/roblox-with-swe/actions/workflows/publish.yml"><img alt="Publish" src="https://github.com/Petri-Hub/roblox-with-swe/actions/workflows/publish.yml/badge.svg?branch=staging" /></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/Petri-Hub/roblox-with-swe" /></a>
  <img alt="Time spent" src="https://img.shields.io/endpoint?url=https%3A%2F%2Flab-wakapi.petri.zip%2Fapi%2Fcompat%2Fshields%2Fv1%2FPetri%2Fproject%3Aroblox-with-swe%2Finterval%3Aall_time&label=time%20spent&logo=wakatime&logoColor=white&color=blue&cacheSeconds=3600" />
</p>

<br>

## About

> **TL;DR:** a proof of concept for bringing software engineering to Roblox on Linux: source-controlled places, linting, automated regression tests, Git Flow, playtest previews, and eventually staging and production releases. Friends will build together through branches and reviewed pull requests, using Discord to discuss ideas and ask an agent to help implement them. That agent will be a new Hermes profile in my personal agent pepper, running in my homelab and contributing through the same tests and review process. This game is the first place to try that shared workflow.

## Play the game

This AI-assisted horror game is taking shape in a procedurally generated town: a 640-stud square of flat grass ringed by a wall of rock, with a three by three grid of streets, four one-room houses on every block, a lamp in each block, a paved plaza where every life starts and a belt of trees between the last street and the rock. The town is in daylight: the sun sits at 13:24, the fog is a light haze far away, and the sky is open, so the streets and the rock rim are visible all the way out. The current build is an early playtest of the map, first-person movement, and the weapons.

Every life starts in the air: the battle bus (`src/assets/BattleBus.rbxm`, Creator Store asset `1255341965`) crosses the sky over the spawn clearing at 235 studs, and you leave it right behind it, coming down under a slow chute instead of falling like a rock. Every life gets the bus, respawns included, and its horn (`8255757586`) plays as you leave. `BusDropService` clones the model from `ServerStorage`, flies it along a random lane and glides the player down until the feet touch. A bus still in the air and close to the clearing takes the next player instead of a second bus leaving beside it.

Every life starts with the flashlight and the `M9` pistol — kills are the shop currency, so you need a gun to earn the first ones — and the rest is bought with ghost kills at a shop the town keeps on the plaza. The guns are meshed Creator Store models — the AK-47 (`8413055627`) and the M9 (`8321118198`) — normalised by the client into first-person viewmodels. The AK-47 (30 rounds, 600 rounds per minute, iron sights while holding right mouse, `R` to reload) costs 4 kills, the `M9` pistol — semi automatic, 15 rounds — costs 2 kills, and the UV floodlight costs 6. Until you pay, that slot is empty — it keeps only its number, with no item name — and refuses to equip it. Both guns run on the same engine and differ only in their definition file. The flashlight lives in the hotbar: press `2` to take it out or put it away, and `F` to turn its beam on or off. Press the slot that is in hand again, or `0`, to walk with empty hands. Casting a spell puts the item away too, because the fireball and the telekinesis need the hand. Slot `3` is the ghost detector, which reads the distance to the nearest ghost in studs every three seconds. Slot `4` is the UV floodlight: hold left mouse to wash ghosts in violet light, which burns them slowly and pushes them back, until the 8 second battery runs dry; it refills on its own in 10 seconds. The handheld flashlight runs a wide 110-degree flood cone, so it lights a clearing instead of a pencil beam. Ghosts drift out of the fog at 4.4 studs per second groaning, and every one you put down adds a point to the `KILLS` counter in the corner. They come in two shipped looks (`src/assets/Ghost.rbxm` and `src/assets/GhostAlt2.rbxm`, Creator Store assets `16371325697` and `14659873441`) with a random tint and height, all scaled to about seven studs.
The three spells are behind devil fruits now: one fruit appears beside a tree in the belt every minute, and eating one is the only way to get a power.

### Performance

The town is built for machines that are not fast, so the cost is kept low on purpose:

- `StreamingEnabled` is on in the place, with a 96-stud minimum and a 512-stud target, so the client only holds the part of the 640-stud map around the player.
- The terrain is written in 40-cell chunks, and the generator clears it first, so generation never builds the whole world in one Lua table.
- Streets, houses and lamps are plain parts: each house is a floor, five walls, a lintel, two window panes and a roof, and the whole town is a few hundred parts.
- Scenery props cast no shadows and do not fire touch events; only the two landmarks in the plaza do.
- The scenery density was pulled back for the bigger map, so the bushes and debris sit at about two thirds of the count the old spacing would give.
- The camera mist is thin now: a handful of small particles instead of a full-screen blanket.
- The HUD only writes a value when it changes: the hit markers are collected once, the reload bar and the crosshair state are gated, and the stamina bar updates only when its value moves.
- The place uses ShadowMap lighting rather than Future, and the daylight is one atmosphere plus two cheap post effects.

### Code layout

The two largest files are split by responsibility:

- `GhostService` keeps the AI, the damage, the culling and the spawn timing; `GhostFactory` builds the model itself, either from a shipped template or as the procedural fallback.
- `WeaponController` keeps the shooting, the pose and the input; `WeaponHud` builds the crosshair, ammo, reload bar, hit marker and touch buttons and hands them back as a table.
- `SpellBadge` builds the spell widget once for both spells, and each controller only decides what its bar means (charge for the fireball, hold or cooldown for the telekinesis).

### The shop

`ShopService` plants one stall in the town, built from parts on the lot the layout keeps free in the plaza (`ForestLayout.SHOP_LOT`), turned to face the middle. It levels nothing and digs nothing: the town is flat on purpose. It hangs two warm lamps and a sign, and drops a `Sound` (`1839910323`, a 30 second music box) on a linear rolloff so the track is at full volume only at the counter and gone past 78 studs: you hear the shop before you see it, but not from across the map.

The game is first person, and first person locks the cursor to the centre, so `ShopClient` steps the camera back and frees the mouse while you stand at the counter; walk away and the first-person camera comes back.

Prices live in `src/shared/ShopCatalog.luau` and the money is the `KILLS` counter. The client only asks to buy; `ShopService` checks the distance to the counter, the price, whether you already own the item, then spends the kills, flips the ownership attribute and puts the purchase in your hands. Combat and the UV lamp check ownership on every use, so an unpaid client cannot shoot the rifle it did not buy.

### The fire magic

The fireball belongs to whoever ate the flame fruit: it is not a shop item and nobody starts with it. Press `Z` and the character points the right arm and hand at the cursor; a spinning rune circle, built from neon parts and fire particles, opens in front of the palm and a fireball leaves it. The ball flies at 110 studs per second up to 240 studs with a particle trail and its own light.

Hold `Z` to charge it: the circle in front of the palm grows with the hold, and so does the ball, up to a ceiling of 1.6 seconds and 2.2 times its size. Let go to throw. A tap still throws the small ball.

On impact it explodes: a flash, an expanding shockwave, fire, sparks, smoke, embers, a boom and a light tremor on the screens of players within 55 studs. A direct hit deals 120 damage — enough to kill a full-health ghost — and the blast splashes up to 100 damage within 16 studs. A fully charged ball is bigger and meaner: 240 direct damage, 190 splash at the centre, and a 26-stud radius, with the crater, the cracks and the blast particles scaled to match. The surface under the blast gets a scorched crater and eight to eleven radial cracks that follow the terrain and disappear after 30 seconds. Each cast is followed by `SOL CRUEL` above the character and in the chat, and the spell takes 6 seconds to recharge; the ability slot above the UV battery shows the countdown.

The tuning lives in `src/shared/FireMagic.luau`, the damage, projectile and scorch marks in `src/server/FireMagicService.luau`, the input and first-person arm in `src/client/FireMagicController.client.luau`, and the badge in `src/client/SpellBadge.luau`, and the circle, ball, blast and screen shake in `src/client/FireMagicEffects.client.luau`.

### The telekinesis

The second spell, which also comes from a fruit. Point the cursor at a prop or a ghost and press `X`: it leaves the ground and floats where you point. It chases the cursor at 60 studs per second, never further than 45 studs from you, with a white rune circle in the casting hand — the fireball's circle in white, but with an eight-pointed star of two squares instead of the double triangle — four rings of white wind blades around the floating thing, a swirl of wind particles and a looping gust. While it floats, the mouse wheel pushes it away or pulls it back in 3-stud steps between 7 and 45 studs, and `Q` and `E` turn it left and right on top of the slow drift. `X` again lowers it: a prop settles back on the ground, a ghost drifts down. Press right mouse while it floats to hurl it, and the throw starts with a short wind push at the hand before the object leaves the grip.

Only props of a sane size answer the spell: the largest side of the bounding box up to 14 studs and at most 80 parts. Barrels, crates and bushes fly. The wrecked car, the shop stall, the spawn pad and the terrain stay where they are. A ghost is grabbed whole: its chase AI is suspended and the server drives its pivot while the spell holds it. One object can only be under one spell at a time.

A throw flies at 120 studs per second for up to 120 studs and stops on the first surface or ghost it meets. The hit deals 70 damage and splashes up to 45 more within 9 studs; a thrown ghost takes the same hit, hangs dazed for 2 seconds afterwards, and a heavy prop that lands on a ghost counts as a direct hit. The impact raises dust, wind sparks, a white shockwave, a thud and a small screen tremor, and the throw itself plays the ascending gust. The spell recharges in 2.5 seconds after the object leaves your hand, and the ability slot counts it down.

### The transmutation

The third spell, which also comes from a fruit. Point the cursor at the ground and press `C`: the character kneels and puts both hands on the ground — two first-person arms drop and meet in front of the body — a red rune circle opens under the feet with a red light, six red lightning arcs crackle around it and a shock plays. When the windup ends the spikes come out of exactly what the cursor was pointing at, in that material: metal where the cursor is on metal, wood on wood, brick on brick, ice on ice. Eleven spikes in a loose spiral, the tall one in the middle, each one a faceted stone spike mesh squashed to its own height and width and turned so the facets never line up, tinted and textured by the surface they come from. The circle under the feet is five studs across, big enough for the character to stand inside it. The ability slot names what came out of the ground for a moment.

The cast reads the surface with a ray from the head, so a client cannot call spikes behind a wall, and the material comes from the surface the server actually hit. The cluster hits for 58 damage at the centre, fading to nothing at 7 studs, and stuns ghosts for 1.1 seconds. The spikes crumble back into the ground after 4.2 seconds, and the spell recharges in 8 seconds.

The tuning, the material table and the spike layout live in `src/shared/Transmutation.luau`; the ground read, the spikes and the damage in `src/server/TransmutationService.luau` (the spike mesh lives in `src/assets/transmutation/Spike.rbxm`, and the code falls back to stacked cylinders if the mesh is missing); the input, the two hands and the badge in `src/client/TransmutationController.client.luau`; the red circle, the arcs, the shock and the burst in `src/client/TransmutationEffects.client.luau`.

The three spells do not overlap. While something floats, the gun is put away, right mouse throws instead of aiming and `Z` waits. While the hands are on the ground, `Z` and `X` wait. Casting a spell also empties the hand: the item returns to the hotbar, and the player picks it again if wanted.

The tuning lives in `src/shared/Telekinesis.luau`, the grab, drag, throw and damage in `src/server/TelekinesisService.luau`, the input and first-person arm in `src/client/TelekinesisController.client.luau`, and the badge in `src/client/SpellBadge.luau`, the white circle in `src/client/MagicCircle.luau`, and the wind, impacts and shake in `src/client/TelekinesisEffects.client.luau`.

### The fruits

The three powers are not free any more: every one of them comes from a fruit, and the fruit is the only way in. `FruitService` drops one beside a tree in the belt around the town every minute — three on the map at most, and an untouched fruit sinks back into the world after five minutes so the belt cannot fill up. A fruit sits three to nine studs from a trunk in a random direction, so the trees are the landmark: you walk the belt looking at the trunks. When the trees have no free spot, the fruit falls back to open ground away from the streets and the houses.

A fruit is a ball, a spiral of ribs and a stem, built from parts and hovering a little above the ground with a glow, so it reads through the bushes before you can see the shape. Walking up to it offers a prompt; taking it does not grant the power yet. The fruit goes to your hands unopened, and from there `E` eats it and `G` puts it back on the ground in front of you.

Eating is what grants the power, and there is one power per player: a second fruit replaces the first, the same way a second devil fruit would. Every spell reads the `Power` attribute on the player, so replacing it moves the ability slot to the new spell and the old one stops answering. The badge in the bottom-right corner is that slot: it only exists while a power does, and it shows the cooldown or the hint of the spell you carry. Nobody starts with a spell — the first fruit is the first power.

The server owns the whole flow: the prompt checks the distance, the pickup is a server call, and eat and drop only work for the fruit the player is really holding. A player who dies or leaves while carrying one drops it where they stood, instead of losing it to a respawn.

The rules live in `src/shared/FruitSpec.luau` (the powers, the spawn ring, the lifetime, the draw and the reach), the definitions in `src/shared/fruits/` and `src/shared/FruitRegistry.luau`, the engine in `src/server/FruitService.luau`, and the held fruit, the spin and the two keys in `src/client/FruitController.client.luau`. The `Power` attribute itself is `src/shared/Powers.luau`.

### The extra abilities

Every fruit used to carry one spell on one key. Each one carries four now: the main spell stays where it was — `Z` fire, `X` telekinesis, `C` earth — and three more sit on `T`, `V` and `B`, the same three keys for every fruit, so the wheel is learned once and only the effects change. `AbilityService` owns the nine new ones: it checks the power, runs the cooldown, does the damage on the server and tells every client what to draw. The keys, the hints and every number live in `src/shared/Abilities.luau`; the look lives in `src/client/AbilityEffects.luau` and the row of key caps in `src/client/AbilityHud.luau`.

**Fire** — `T` Explosão Solar: a ring of fire around the caster, 22 studs out, damage falling from 120 in the middle to 55 at the rim, and everything thrown back. `V` Meteoro: a ball pulled out of the sky onto the point under the cursor, up to 170 studs away, one second of fall and a 16-stud blast for up to 240. `B` Muralha de Fogo: a 26-stud wall of flame 14 studs ahead that burns anything crossing it, 26 damage every half second for six seconds. The main fireball also leaves the ground burning for six seconds now, 16 damage a tick.

**Push** — `T` Onda de Choque: a cone 34 studs long and 84 wide, damage from 75 down with distance and a knockback that clears a street. `V` Impulso: throws the caster along the aim at 82 studs per second and 62 up, the way out of a crowd. `B` Vórtice: everything within 38 studs of a point 16 studs ahead is dragged in over half a second, held, then hit for 140. Props thrown by the main spell now daze the ghosts they land on, not only the one they hit.

**Earth** — `T` Terremoto: 26 studs of ground slam, 100 damage and a 1.2 second stumble. `V` Muralha de Pedra: a 22-stud wall of rock 12 studs ahead that stands for 12 seconds — a ghost only walks, so it has to go around. `B` Punho de Pedra: a fist of rock out of the ground on the aimed point, up to 70 studs away, 260 damage in 9 studs. The spike field of the main spell keeps cutting while it stands: 14 damage every 0.6 seconds.

### Adding a fruit

Fruit are data, the same way weapons are. To add one:

1. Copy `src/shared/fruits/Fogo.luau` to `src/shared/fruits/<Fruta>.luau` and change `id`, `name`, `power`, `weight`, `body`, `swirl`, `glow` and `flavor`.
2. Register it once in `src/shared/FruitRegistry.luau`.

`FruitSpec.derive` validates the definition and fails the build on an empty id or name, a power that is not in the powers table, a weight that is not positive, a colour that is not a `Color3` or an empty flavour line. A fruit only grants a power that already exists, so a new fruit either feeds one of the three powers — main spell plus the three in `src/shared/Abilities.luau` — or comes with a new spell service.

### The arena

`ArenaService` builds a coliseum at `Arena.ORIGIN` — 1600, 180, 0 — far above and away from the town, so the procedural map never collides with it. The sand is 52 studs across, ringed by a wall with four iron gates, four tiers of stone seats, an outer wall with merlons, eight columns, red banners, eight burning torches and a gold `ARENA` plaque over the entrance. It is built from parts at server start, the same way the shop stall is.

Two chat commands move a player between the places. `/arena` (or `/coliseu`) teleports to the spawn facing the sand; `/floresta` (or `/sair`) returns to `ForestSpawn`. They are `TextChatCommand`s created under `TextChatService`, so the command is intercepted and never broadcast; a `Player.Chatted` fallback covers the old chat path, and a debounce makes sure a client that reports both paths only teleports once. The move itself is a server-side `PivotTo` of the character.

The arena has no enemies of its own yet: the ghost spawner places ghosts around players inside the town and culls the ones too far from every player, so the town empties while everyone is away.

### Adding a weapon

Weapons are data. `WeaponSpec` owns the magazine, cadence, reload, spread, recoil and state sync for every gun, and `WeaponRegistry` hands out the validated definitions. To add one:

1. Copy `src/shared/weapons/M9.luau` to `src/shared/weapons/<Gun>.luau` and change the numbers: `id`, `name`, `fireMode` (`auto` or `semi`), `damage`, `roundsPerMinute`, `magazine`, `startingReserve`, `maxReserve`, `reloadTime`, `range`, the three spreads, the recoil pairs and `sounds`.
   - For a meshed gun, also set `viewmodel.model` (the name under `ReplicatedStorage.WeaponModels`), `modelLength`, `modelRotation`, `hold` and `aim`. Drop the model in `src/assets/weapons/` and map it in `default.project.json` and `test.project.json`.
   - For a part-built gun, list the parts in `viewmodel.parts` and name `muzzlePart`, `boltPart` and `magazinePart`.
2. Register it once in `src/shared/WeaponRegistry.luau`.
3. Add it to the hotbar in `src/shared/Inventory.luau` — the label and the hint come from the definition.

`WeaponSpec.derive` validates the table and fails the build on a missing name, a zero cadence, a part named twice, a muzzle that is not in the part list or a gun without a fire sound, so a typo cannot ship a weapon that does not shoot. Three tests in `tests/specs/WeaponSpec.spec.luau` run a synthetic third gun through the same engine to keep the abstraction honest.

- [Staging playtest](https://www.roblox.com/games/112768229129661) receives changes merged into `staging`.
- [Production game](https://www.roblox.com/games/138015860615681) receives changes merged into `production`.

## Contents

- [Play the game](#play-the-game)
- [How it works](#how-it-works)
- [Software engineering in Roblox](#software-engineering-in-roblox)
- [Collaboration](#collaboration)
- [Technologies](#technologies)
- [Work on the project](#work-on-the-project)
- [Roadmap](#roadmap)
- [Repository layout](#repository-layout)
- [Related projects](#related-projects)
- [References](#references)

## How it works

<p align="center">
  <img src="assets/how-it-works.svg" alt="Architecture: a GitHub repository connects to a Linux checkout. Rokit and Wally provide tools and packages; StyLua and Selene check source; Rojo builds or syncs it into Studio through Vinegar. Planned pull requests come from friends and a Hermes profile, while GitHub Actions publishes staging and production places through Roblox Open Cloud." />
</p>

The GitHub repository holds the Luau and world files. On Linux, a local checkout uses Rokit and Wally for tools and dependencies, StyLua and Selene for source checks, and Rojo to build a place or sync it to Studio through Vinegar. The planned path connects friends and the Hermes profile in pepper through pull requests; GitHub Actions runs checks and publishes staging and production places through Roblox Open Cloud.

## Software engineering in Roblox

| Practice | Tool | What it means here |
|---|---|---|
| Source of truth | Git, Luau, Rojo project files, and model JSON | Scripts and the parts of the world we can describe as data live in files that can be reviewed and changed together. |
| Reproducible toolchain | Rokit | The repository pins the versions of Rojo, Wally, StyLua, Selene, and jest-roblox-cli. |
| Dependency management | Wally | `wally.toml` declares packages; `wally.lock` records the resolved versions. Jest Roblox is already installed as a development dependency. |
| Formatting | StyLua and pre-commit | Luau gets a consistent style before it enters Git. |
| Static analysis | Selene | Linting catches suspicious Luau code without launching the game. |
| Regression testing | Jest Roblox and jest-roblox-cli | A separate test place runs the game's rules, locally through Studio on Linux or remotely through Roblox Open Cloud. |
| Continuous integration and delivery | GitHub Actions and Roblox Open Cloud | Pull requests run formatting, linting, builds, and engine tests; merges publish separate staging and production places. |

The tools have different jobs. Rojo moves files into Roblox's DataModel; it does not decide whether the code is correct. Selene checks code without running it; Jest checks behavior by running it. A successful build is therefore only one part of a trustworthy change.

The first feature of the project let a player harvest a tree in the world. The server checks the player's distance and the tree's regrowth timer, awards one wood, then hides the canopy for eight seconds. A client HUD shows the wood count. The harvest rules live in a shared module so they can be tested without waiting for a real timer.

## Collaboration

<p align="center">
  <img src="assets/collaboration.svg" alt="Proposed four-lane collaboration flow. Friends discuss an idea in Discord; friends or a Hermes agent create a branch and pull request; GitHub Actions checks StyLua, Selene, a Rojo build, and Jest tests; then staging is playtested before a production Roblox release." />
</p>

Friends start with an idea or bug in Discord. A contributor or Lemon, the Hermes agent in pepper, turns the agreed change into code on a branch and opens a pull request. GitHub Actions checks formatting with StyLua, lint with Selene, build with Rojo, and run Jest tests. Passing changes reach a staging place for playtesting before a production release.

Lemon's development skills live with his profile in [pepper](https://github.com/Petri-Hub/pepper/tree/main/profiles/lemon/skills), covering setup, previews, design, implementation, tests, documentation and delivery.

## Technologies

<table align="center">
  <tr>
    <td align="center" width="112"><a href="https://create.roblox.com/docs/studio"><img src="https://cdn.simpleicons.org/robloxstudio" width="42" height="42" alt="Roblox Studio" /><br>Roblox Studio</a></td>
    <td align="center" width="112"><a href="https://luau.org/"><img src="https://cdn.simpleicons.org/luau" width="42" height="42" alt="Luau" /><br>Luau</a></td>
    <td align="center" width="112"><a href="https://vinegarhq.org/Vinegar/Installation.html"><img src="https://raw.githubusercontent.com/vinegarhq/vinegar/master/data/icons/vinegar.svg" width="42" height="42" alt="Vinegar" /><br>Vinegar</a></td>
    <td align="center" width="112"><a href="https://rojo.space/docs/v7/"><img src="https://api.iconify.design/material-icon-theme/rojo.svg" width="42" height="42" alt="Rojo" /><br>Rojo</a></td>
    <td align="center" width="112"><a href="https://github.com/rojo-rbx/rokit"><img src="https://api.iconify.design/catppuccin/rokit.svg" width="42" height="42" alt="Rokit" /><br>Rokit</a></td>
    <td align="center" width="112"><a href="https://wally.run/"><img src="https://wally.run/favicon.ico" width="42" height="42" alt="Wally package manager" /><br>Wally</a></td>
  </tr>
  <tr>
    <td align="center" width="112"><a href="https://github.com/JohnnyMorganz/StyLua"><img src="https://api.iconify.design/catppuccin/stylua.svg" width="42" height="42" alt="StyLua" /><br>StyLua</a></td>
    <td align="center" width="112"><a href="https://kampfkarren.github.io/selene/"><img src="https://api.iconify.design/mdi/text-box-check-outline.svg?color=%239198A1" width="42" height="42" alt="Linting icon" /><br>Selene</a></td>
    <td align="center" width="112"><a href="https://pre-commit.com/"><img src="https://cdn.simpleicons.org/precommit" width="42" height="42" alt="pre-commit" /><br>pre-commit</a></td>
    <td align="center" width="112"><a href="https://roblox.github.io/jest-roblox/"><img src="https://cdn.simpleicons.org/jest" width="42" height="42" alt="Jest" /><br>Jest Roblox</a></td>
    <td align="center" width="112"><a href="https://git-scm.com/docs"><img src="https://cdn.simpleicons.org/git" width="42" height="42" alt="Git" /><br>Git</a></td>
    <td align="center" width="112"><a href="https://docs.github.com/"><img src="https://cdn.simpleicons.org/github/9198A1" width="42" height="42" alt="GitHub" /><br>GitHub</a></td>
  </tr>
</table>

## Work on the project

### Requirements

- [Git](https://git-scm.com/install/) to clone and contribute to the repository.
- [GNU Make](https://www.gnu.org/software/make/#download) to run the project commands.
- [Rokit](https://github.com/rojo-rbx/rokit#installation) to install the pinned development tools.
- [curl](https://curl.se/download.html) to install the Jest Studio plugin on Linux.
- [pre-commit](https://pre-commit.com/#installation) to enable the formatting hook.
- [Roblox Studio](https://create.roblox.com/docs/tutorials/curriculums/studio/install-studio), or [Vinegar](https://vinegarhq.org/Vinegar/Installation.html) to run Studio on Linux.
- [Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004) for live syncing with Studio.

### Installation

From the repository root:

```bash
# Install the tool versions pinned in rokit.toml.
rokit install

# Install the dependencies declared in wally.toml.
wally install

# Enable automatic Luau formatting when committing.
pre-commit install

# On Linux, install the matching Jest plugin in Vinegar's Studio.
bash scripts/install-jest-plugin.sh
```

### Coding

```bash
# Edit the files in src/ and save your changes.

# Format Luau source files.
make format-apply

# Check Luau source files with Selene.
make lint

# Sync changes to Studio through the Rojo plugin.
make serve
```

### Building

```bash
# Build the development place in dist/.
make build

# Build the staging place file in dist/.
make build-staging

# Build the production place file in dist/.
make build-production
```

To view the place in Roblox Studio, open a built `.rbxlx` file or run `make serve` and connect the Rojo Studio plugin to its server URL.

### Testing

```bash
# Run the Jest regression tests through Vinegar.
make test-on-system

# Run the same tests in Roblox Open Cloud, without Studio.
make test-on-ocale
```

`make test-on-system` builds the test place from the current working files, launches Studio through Vinegar, runs Jest, prints the result, and closes Studio. The test place includes Wally's development packages, so run `wally install` first. Studio opens a window during the run.

## Roadmap

What is working now:

- ✅ Pin the local toolchain with Rokit.
- ✅ Build a place from source files and sync it into Studio with Rojo.
- ✅ Run Roblox Studio through Vinegar on Linux.
- ✅ Describe a small piece of the world as a Rojo model JSON file.
- ✅ Format Luau with StyLua and run it from pre-commit.
- ✅ Lint Luau with Selene.
- ✅ Add Wally and lock Jest Roblox as a development dependency.
- ✅ Add a small tree harvesting behavior worth testing.
- ✅ Build a separate Rojo test place with Jest tests for the harvesting rules.
- ✅ Run Jest from a Linux terminal with jest-roblox-cli and Vinegar.
- ✅ Run Jest through Open Cloud with a dedicated test place.
- ✅ Run formatting, linting, builds, and engine tests in GitHub Actions.
- ✅ Publish separate staging and production places through the Roblox API.
- ✅ Build roblox-assets-mcp for Creator Store search and download URLs.

## Repository layout

```sh
.
├── .github/
│   └── workflows/
│       ├── quality.yml          # format, lint, build, and Jest checks
│       └── publish.yml          # build and publish staging and production places
│
├── assets/
│   ├── collaboration.excalidraw  # editable collaboration diagram
│   ├── collaboration.svg         # collaboration diagram shown above
│   ├── how-it-works.excalidraw  # editable workflow diagram
│   └── how-it-works.svg         # workflow diagram shown above
│
├── src/
│   ├── client/                  # client-side Luau
│   ├── server/                  # server-side Luau
│   ├── shared/                  # shared modules
│   └── world/                   # world objects for Rojo
│
├── tests/                       # Jest regression specs
├── scripts/                     # Vinegar launch and plugin setup scripts
│
├── default.project.json         # files mapped into the Roblox DataModel
├── test.project.json            # separate place for running Jest tests
├── jest.config.toml             # Jest CLI configuration
├── Makefile                     # local development commands
│
├── rokit.toml                   # pinned development tools
├── wally.toml                   # package declarations
├── wally.lock                   # resolved package versions
│
├── .stylua.toml                 # formatter configuration
├── selene.toml                  # linter configuration
└── .pre-commit-config.yaml      # formatting hook
```

## License

This repository is licensed under the [MIT License](LICENSE).

## Related projects

| 📦<br>[roblox-assets-mcp](https://github.com/Petri-Hub/roblox-assets-mcp) | 🐦<br>[pepper](https://github.com/Petri-Hub/pepper) | 🧰<br>[lab](https://github.com/Petri-Hub/lab) |
|---|---|---|
| Asset-only MCP server for Creator Store search, previews, and temporary download URLs. | My personal agent; the planned Hermes profile for this project will be documented there. | My homelab, where pepper and the new profile will run. |

## References

- [Roblox Creator Hub](https://create.roblox.com/docs): engine, Studio, and publishing documentation
- [Rojo](https://rojo.space/docs/): file-to-DataModel mapping, building, and live sync
- [Rokit](https://github.com/rojo-rbx/rokit): versioned development tools
- [Wally](https://github.com/UpliftGames/wally): packages, manifest, and lockfile
- [StyLua](https://github.com/JohnnyMorganz/StyLua): Luau formatting
- [pre-commit](https://pre-commit.com/): Git hook setup and configuration
- [Selene](https://kampfkarren.github.io/selene/): Luau linting
- [Jest Roblox](https://roblox.github.io/jest-roblox/): test runner and assertions
- [jest-roblox-cli](https://github.com/christopher-buss/jest-roblox-cli): terminal runner for Studio and Open Cloud
- [Luau LSP](https://github.com/JohnnyMorganz/luau-lsp): editor analysis and Rojo sourcemaps
- [Vinegar](https://vinegarhq.org/): Roblox Studio on Linux
- [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes): playtests and scripted tests
- [Studio command-line interface](https://create.roblox.com/docs/studio/command-line-interface): run a Luau test entrypoint from a terminal
- [Open Cloud API keys](https://create.roblox.com/docs/cloud/auth/api-keys): key creation, permissions, and expiration
- [Open Cloud scopes](https://create.roblox.com/docs/cloud/reference/scopes): the permission each endpoint requires
- [Open Cloud Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution): engine code execution for automation
- [Place publishing API](https://create.roblox.com/docs/cloud/guides/usage-place-publishing): automated place releases
- [Git](https://git-scm.com/doc): version control for the project
- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/): feature, release, and hotfix branches
- [GitHub Actions](https://docs.github.com/en/actions): CI and deployment workflows
- [Wakapi](https://wakapi.dev): time tracking for this project and the badge above
