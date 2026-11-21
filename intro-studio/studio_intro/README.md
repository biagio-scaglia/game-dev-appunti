# Intro dello studio

L'intro che apre ogni gioco: una notte in pixel art, la luna che sale e cresce fino a piena,
apre l'occhio e ti guarda, poi il nome dello studio. Circa 7 secondi, con la sua musica.
Qualsiasi tasto la salta.

## Usarla in un gioco

1. Copia l'intera cartella `studio_intro/` nella radice del progetto (`res://studio_intro/`).
2. Imposta `studio_intro.tscn` come scena principale (o caricala tu all'avvio).
3. Nell'Inspector della scena imposta **Next Scene**: la scena da aprire dopo (es. il titolo).

In alternativa istanziala e ascolta il segnale `finished` (emesso a schermo già nero).

Pensata per un viewport di 640×360 con `texture_filter` *nearest*, come Erbalta.

## Opzioni (Inspector)

| Opzione | Default | Cosa fa |
|---|---|---|
| `studio_name` | `BIAGIO SCAGLIA` | Il nome dello studio |
| `subtitle` | `presenta` | La riga sotto il nome (vuota = niente) |
| `moon_watches` | `true` | La luna apre l'occhio |
| `play_music` | `true` | La musica dell'intro |
| `next_scene` | — | Scena da caricare a fine intro |
| `skippable` | `true` | I tasti saltano l'intro |

## Com'è fatta

`studio_intro.gd` è solo il regista: decide chi fa cosa e quando. Ogni pezzo è un modulo piccolo
con un solo compito, collegato con `preload` relativi (nessun `class_name`, così copiare la cartella
in un altro progetto non crea conflitti di nomi).

```
studio_intro/
├── studio_intro.gd / .tscn   il regista e la scena
├── logo/
│   ├── moon_logo.gd          la luna: rise(), wax(), shine(), watch()
│   └── moon_eye.gd           l'occhio: open(), close(), watch()
├── fx/
│   ├── starfield.gd          stelle che si accendono e tremolano, stella cadente
│   ├── moon_glade.gd         il riflesso della luna sul lago
│   └── intro_fx.gd           le scintille
├── title/
│   └── intro_title.gd        il nome lettera per lettera e il sottotitolo
├── core/
│   ├── skip_input.gd         quali input saltano l'intro
│   ├── sheet_frames.gd       taglia i fogli di sprite in animazioni
│   └── start_prompt.gd       "clicca per iniziare" (solo web: sblocca l'audio)
└── assets/                   generati da tools/make_assets.py + font Kenney (CC0)
```

Gli asset (sprite, suoni e musica) sono generati da zero con `tools/make_assets.py`:
per cambiare la palette, la luna o la melodia si modifica lo script e si rigenera.
