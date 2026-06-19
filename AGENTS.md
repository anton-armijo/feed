# AGENTS.md

Briefing del proyecto para agentes de IA (opencode, codex, etc.). Léelo al
iniciar sesión para saber cómo construir, correr, lintar y testear sin que se
te explique cada vez.

## Resumen

Godot 4.6, GDScript only (sin C#), Jolt physics. Multiplayer maze 3DF
("Find the Teto"). Renderer: **gl_compatibility** (`project.godot:15,96-97`).

## Documentacion
Lee godot-docs/README.md para ver la documentacion de godot 4.6

## Cómo correr

```sh
godot --path .                      # editor
godot --path . --main-scene ...     # override (raramente necesario)
```

**Main scene = `scenes/menu.tscn`** (uid `ba8dpuhykc2ud`, en `project.godot:14`).
**NO** es `scenes/main.tscn` — ese es un sandbox/dev (casa + Miku + stairs).

## Cómo exportar

```sh
godot --headless --export-release "Linux"   export/teto.x86_64
godot --headless --export-release "Windows Desktop" export/teto.exe
cd export && ./to_appimage.sh               # empaqueta AppImage
```

Presets en `export_presets.cfg`.

## Lint

```sh
gdlint net/ player/ scripts/ tests/         # debe salir limpio (exit 0)
gdformat <file>...                          # formatea (normaliza ws, blank lines)
```

Requiere `godot-gdscript-toolkit` (`pip install --user gdtoolkit`).
Config en `.gdlintrc` (tabs, max-line 120, excluye `addons/`/`.godot/`).
`class-definitions-order` está deshabilitado (estilístico, requeriría
reformatear todo el codebase existente). El resto de reglas aplica.

**Antes de commit:** `gdlint` debe pasar en los archivos que toques.

## Tests

Framework: **gdUnit4** (addon en `addons/gdUnit4`).

```sh
bash addons/gdUnit4/runtest.sh --godot_binary "$(which godot)" -a tests/
```

Tests en `tests/` (espejan la estructura de `player/` etc.). Nombrado:
`test_<classname>.gd`, extiende `GdUnitTestSuite`. API de assertions:
`assert_float`, `assert_bool`, `assert_int`, `assert_str`, `assert_vector`
(unificado Vector2/Vector3), `assert_array`, `assert_dict`, etc.

**Antes de commit:** los tests deben pasar (CI lo verifica).

## CI

`.github/workflows/ci.yml` — dos jobs: `lint` (gdlint) y `test` (gdUnit4
headless sobre Godot 4.6). Ambos deben pasar en cada push/PR.

## Arquitectura

Patrón consistente en ambas capas: **composition root + blackboard +
componentes que reportan vía signals** ("references down, signals up").

### Capas

- **`net/`** — `NetSession` (autoload, composition root) → `NetState`
  (blackboard) + `NetTransport` (único writer del peer) +
  `SessionController` (lifecycle) + `SceneFlow` + `PlayerSpawnService`
  (MultiplayerSpawner server-authoritative). Dependencia **unidireccional
  `player → net`**: `net/` nunca importa `player/` (sólo referencia el
  `PackedScene` de forma genérica). El movimiento hoy es
  **peer-authoritative** (cada cliente simula su jugador).

- **`player/`** — `Player` (CharacterBody3D, composition root) →
  `PlayerBlackboard` (única read surface de estado/sync) + `PlayerApi`
  (fachada de verbos para sistemas externos: abilities, game layer,
  cutscenes, AI) + `PlayerAssembler` (feature flags) + componentes:
  `input/` → `motor/` → `fsm/` (7 estados) → presentación
  (`animation/`, `camera/`, `sounds/`) que lee del blackboard. Framework de
  `abilities/` listo pero sin abilities concretas. Config en `data/`
  (Resources puros).

### `CharacterPresenter` (character-agnostic)

El player es **character-agnostic**: no conoce la estructura interna del
modelo. Cada escena de modelo tiene un script en su root que extiende
`CharacterPresenter` (`player/scripts/animation/character_presenter.gd`) y
posee su propio `AnimationTree`/`AnimationPlayer`/`AnimationDriver`/shaders.
`Player` referencia el presenter por nodo tipado (`$Model/CharacterScene`)
y llama `setup_presenter(bb, resolved.locomotion)`. Swap de personaje =
swap de escena que extiende `CharacterPresenter`.

### `PlayerApi` vs `PlayerBlackboard`

Son **complementarios**, no la misma cosa:

- **`PlayerBlackboard`** — sustantivos (estado + signals). Es la superficie
  de sync para `MultiplayerSynchronizer` y la read surface para
  presentación. Se queda "dumb": sólo estado + signals de cambio.
- **`PlayerApi`** — verbos (acciones). Fachada que delega al subsystem
  correcto (motor, fsm, input, camera, animation, ability manager). Es el
  "camino bendito" para que sistemas externos influyan en el jugador. No
  replica, no tiene estado propio.

**Al añadir una función al player, considera dónde pertenece:**
- Si es una **acción** que sistemas externos deberían disparar → verbo en
  `PlayerApi`.
- Si es **estado** que otros deberían leer/watchear → campo/signal en
  `PlayerBlackboard`.
- Si es un **mecanismo interno** de un solo subsystem → se queda ahí.

`PlayerApi` vive como `Node` hijo de `Player` (descubrible en la escena,
`@onready var api: PlayerApi = $PlayerApi`). Se construye en `_ready()`
después de todos los `setup()` de componentes. 3 tiers:
1. **Core**: speed modifiers, gravity, velocity, FSM requests, input,
   abilities — cubre abilities y game layer.
2. **Feel**: intent injection, camera verbs, animation override — para
   cutscenes/AI.
3. **Extensión**: `register_verb`/`call_verb` — nodos auxiliares publican
   sus propios verbos sin que `PlayerApi` los conozca.

Ownership documentada por verbo (comentarios `##`), no enforced runtime.

### Reglas clave (single-writers por convención)

- Sólo `MovementMotor` llama `move_and_slide()` (`movement_motor.gd:89`).
- Sólo `NetTransport` escribe `multiplayer.multiplayer_peer`.
- Sólo `LocomotionFSM` escribe `bb.locomotion_state`.
- El blackboard es la **única** superficie de lectura para presentación/sync.
  Los components **escriben** en él; los observers **leen** + conectan signals.

### Config

`PlayerConfig` (aggregate `Resource`) → sub-resources `LocomotionConfig`,
`JumpConfig`, `CameraConfig`, `CameraEffectsConfig`, `StairConfig`,
`ProbeConfig`, `PlayerComponentsConfig`. Serializados como `.tres` en
`player/resources/`. `ensure_defaults()` garantiza sub-resources no-null.
`extras: Array[Resource]` lleva configs misceláneos (ej. `HeadTrackConfig`)
que los presenters/nodos auxiliares buscan por tipo.

**Patrón Resolved\*:** `Player` construye un `ResolvedPlayerConfig` inmutable
una vez en `setup()` vía `ResolvedPlayerConfig.resolve(config)`. Los
components leen **sólo** del resolved — nunca del `.tres` en runtime. El
resolver hace:
- **Passthrough** de knobs independientes (walk_speed, gravity, etc.).
- **Derivaciones cross-config** (weight → model_turn_speed,
  body_height → max_step_up).
- **Validación** centralizada (run_speed > walk_speed, weight > 0, etc.).

Las modificaciones runtime (abilities que cambian velocidad) van por el
modifier stack del motor, **no** mutando config. El resolver es inmutable.

## Convenciones

- **Indentación:** tabs.
- **`class_name`** en `net/scripts/` y `player/scripts/` (las capas
  reutilizables). **Omitido** en `net/scripts/net_session.gd` para no
  sombrear el autoload `NetSession`. Scripts de `scripts/game/` suelen
  omitirlo también.
- **Scripts co-locados** con su dominio (`net/scripts/`, `player/scripts/`).
  Scripts genéricos de juego en `scripts/game/`.
- **Doc-comments** `##` en cabeceras de archivo y clases (documentan
  ownership, single-writers, intención).
- **Autoloads:** sólo `NetSession` (`project.godot:20`).
- **Input actions** en `project.godot:26-87`: WASD, jump (Space),
  shift_lock (F3, toggle lock_on_character), run (F2), click, right_click
  (invierte lock_mouse), wheel_up/down.

### Locks: `lock_on_character` vs `lock_mouse`

- **`lock_on_character`** — el modelo se lockea a mirar hacia la cámara
  (backpedaling active). Toggle con F3 via `LockOnCharacterAbility`
  (opt-in via `PlayerComponentsConfig.enable_lock_on_character`).
  También seteable via `PlayerApi`.
- **`lock_mouse`** — el mouse se captura para orbitar la cámara.
  Default configurable (`always_on`/`always_off` en
  `PlayerComponentsConfig.default_lock_mouse_mode`). Right-click invierte
  el default temporalmente (hold).

## Gotchas

- **Arte/audio/materiales gitignored** (`materials/`, `sounds/`, `models/`,
  `player/character/model/`): un `git clone` solo no produce un juego
  runnable — faltan los assets locales.
- **Renderer mismatch** (ver Resumen).
- **`NetSession` es el único autoload** — no hay `AudioManager` ni player
  autoload (el jugador se instancia vía `MultiplayerSpawner`).
- **`maze_player.tscn`** hereda `base_player.tscn` y configura
  `force_first_person` + game layer; **NO** es el player base.
- **`scenes/main.tscn`** es sandbox, **no** el main scene.
