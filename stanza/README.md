# stanza

Progetto Godot 4.7: la stanza di un hikikomori, di notte. La protagonista cammina in 8 direzioni,
corre e lancia magie che illuminano la stanza.

![La stanza](../docs/stanza.gif)

- **WASD / frecce**: cammina
- **Shift**: corri
- **Spazio / J**: magia (carica sulle mani, poi il proiettile parte verso dove guarda)

## Comandi

```sh
$GODOT --path .                                                   # gioca
$GODOT --headless --path . -s res://tests/run_tests.gd            # test
$GODOT --path . -s res://tools/capture_frames.gd -- <cartella>    # screenshot automatici
```

## Com'è fatto

```
main.tscn / main.gd              stanza al buio (CanvasModulate) + protagonista
world/
├── room_tiles.png / .json       atlante dei tile e i suoi dati (dal generatore)
├── room_tileset.gd              costruisce il TileSet dal JSON, con le collisioni
├── room_layout.gd               com'è arredata la stanza (solo dati)
└── room.gd                      dipinge i livelli (pavimento, muri, oggetti, mobili) e accende le luci
characters/protagonista/
├── facing.gd                    8 direzioni -> riga dello sheet + specchio (solo logica)
├── protagonista_frames.gd       animazioni dagli sheet (idle, walk, run, attack x 5 direzioni)
├── protagonista.gd / .tscn      CharacterBody2D: movimento, corsa, magia
└── sprites/                     gli sheet: SOLO IN LOCALE (vedi sotto)
magic/
├── magic_frames.gd              animazioni di carica, proiettile, impatto
├── projectile.gd / .tscn        vola, ha una luce viola, esplode su muri e mobili
└── one_shot_effect.gd           carica e impatto: si suonano una volta, la luce si spegne
core/
├── glow.gd                      luci morbide (PointLight2D a gradiente radiale)
└── input_setup.gd               crea le azioni di input se mancano
tests/                           un file per modulo + mini runner headless
```

- **Luci**: la stanza è scurita da un `CanvasModulate`; schermo del PC, lampada, telefono e luna
  tra le tende hanno una `PointLight2D`, e così il proiettile e l'impatto (viola).
- **Magia**: gli effetti usano il blend additivo (`CanvasItemMaterial` -> Add) per brillare.
- **Profondità**: il livello dei mobili è ordinato per Y insieme alla protagonista, che passa
  davanti o dietro a seconda di dove sta.

## Sprite della protagonista: solo in locale

Gli sheet in `characters/protagonista/sprites/` non sono nel repo: sono la protagonista disegnata
sopra il [Character Template di Eris Esra](https://erisesra.itch.io/character-templates-pack), che
si può usare nei giochi ma non ridistribuire. Senza quella cartella il progetto si apre lo stesso
(con un errore che lo spiega), ma la protagonista non si vede e i suoi test falliscono.

Il tileset e gli effetti magici invece sono disegnati da zero (generatori in locale) e sono nel repo.
