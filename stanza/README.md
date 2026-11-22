# stanza

Progetto Godot 4.7 del gioco (titolo provvisorio **Aletheia**, testi per ora in inglese): si apre
con l'intro dello studio, poi la schermata del titolo, poi la stanza di un hikikomori di notte.
La protagonista, Lethe, cammina in 8 direzioni, corre e lancia magie che illuminano la stanza.

![Il titolo](../docs/titolo.png)

![La stanza](../docs/stanza.gif)

- **WASD / frecce**: cammina
- **Shift**: corri
- **Spazio / J**: magia (carica sulle mani, poi il proiettile parte verso dove guarda)

## Comandi

```sh
$GODOT --path .                                                   # gioca
$GODOT --headless --path . -s res://tests/run_tests.gd            # test
$GODOT --path . -s res://tools/capture_frames.gd -- <cartella>    # screenshot automatici della stanza
$GODOT --path . -s res://tools/capture_frames.gd -- <cartella> - res://title/title_screen.tscn  # ...del titolo
```

## Com'è fatto

```
studio_intro/                    l'intro dello studio (copiata da ../intro-studio, sottotitolo "presents")
title/
├── title_screen.gd / .tscn      il titolo: appare dal nero, menu Start / Quit, poi la stanza
├── title_backdrop.gd            raggio di luna (con le nuvole che passano) e pulviscolo
├── title_figure.gd              Lethe di spalle nel raggio (solo se ci sono i suoi sprite)
├── title_name.gd                il titolo col nome nascosto: ogni tanto di A-LETHE-IA resta solo LETHE
├── title_menu.gd                il menu (Button veri: tastiera, gamepad, mouse): davanti alla voce
│                                scelta batte un cuore, e cambiare voce suona il carillon
└── art/                         finestra con tende e luna, pavimento, pannello del menu, cuore,
                                 ornamento (dal generatore in locale: griglia a 16 px, blocchi 2x2)
ui/fonts/                        Kenney Pixel (CC0)
main.tscn / main.gd              stanza al buio (CanvasModulate) + protagonista + OST
audio/stanza_theme.wav           l'OST della stanza: loop lo-fi di 25 s (dal generatore, senza stacchi)
audio/title_theme.wav            l'OST del titolo: il lamento di un giullare, valzer lento in Re minore
                                 su un carillon stonato, con sonagli e un bordone col tritono (44 s, loop)
audio/ui_move.wav, ui_confirm.wav  i suoni del menu (lamelle di carillon)
audio/magic_*.wav                i suoni della magia: il luccichio della carica, il soffio del lancio,
                                 il rintocco di vetro dell'impatto
world/
├── room_tiles.png / .json       atlante dei tile e i suoi dati (dal generatore)
├── room_tileset.gd              costruisce il TileSet dal JSON, con le collisioni
├── room_layout.gd               com'è arredata la stanza (solo dati)
├── room.gd                      dipinge i livelli (pavimento, muri, oggetti, mobili)
└── room_fx.gd                   luci, sfarfallio, schermo acceso, raggio di luna (dal JSON)
fx/
├── flicker.gd                   sfarfallio di una luce: tremolio + cali improvvisi
├── screen_glow.gd               lo schermo del PC che tremola, con la riga di scansione
├── moon_beam.gd                 il raggio di luna dalla tenda, con il pulviscolo
├── sparks.gd                    scintille di magia (scia e scoppio), quadratini da 2 pixel
├── screen_shake.gd              un piccolo tremolio dello schermo all'impatto
└── drop_shadow.gd               l'ombra sotto i piedi, a blocchi di 2 pixel come gli sprite
characters/protagonista/
├── facing.gd                    8 direzioni -> riga dello sheet + specchio (solo logica)
├── protagonista_frames.gd       animazioni dagli sheet (idle, walk, run, attack x 5 direzioni)
├── protagonista.gd / .tscn      CharacterBody2D: movimento, corsa, magia
└── sprites/                     gli sheet: SOLO IN LOCALE (vedi sotto)
magic/
├── magic_frames.gd              animazioni di carica (8), proiettile (4), impatto (9), ognuna col suo ritmo
├── projectile.gd / .tscn        vola con una scia di scintille e una luce viola, esplode su muri e mobili
└── one_shot_effect.gd           carica e impatto: luce (sale nella carica, si spegne nell'impatto),
                                 suono, scoppio di scintille e tremolio a scelta
core/
├── glow.gd                      luci morbide (PointLight2D a gradiente radiale)
├── music.gd                     musica in loop
└── input_setup.gd               crea le azioni di input se mancano
tests/                           un file per modulo + mini runner headless
```

- **Luci**: la stanza è scurita da un `CanvasModulate`; schermo del PC, lampada, telefono e luna
  tra le tende hanno una `PointLight2D` che sfarfalla (lo schermo ha anche cali improvvisi, la
  lampada ogni tanto), e così il proiettile e l'impatto (viola).
- **Atmosfera**: lo schermo acceso tremola con una riga di scansione; dalla tenda scende un raggio
  di luna con il pulviscolo; l'OST lo-fi (piano elettrico, basso, batteria leggera, vinile) va in loop.
- **Protagonista**: disegnata sulla griglia 32x32 della sagoma e ingrandita a blocchi 2x2,
  senza dettagli a mezzo pixel: ha la stessa grana del pavimento. Sotto i piedi ha un'ombra
  scura e semitrasparente.
- **Stile dei tile**: come Lethe, una sola griglia a 16 px ingrandita a blocchi 2x2 (niente Scale2x
  né dettagli a mezzo pixel): contorno colorato, tre toni per materiale, riflessi, retinatura a scacchi.
- **Magia**: tre tempi, come nei campioni di incantesimi: la carica raccoglie scintille a spirale
  sulle mani (la luce sale, un luccichio sempre più acuto), il colpo parte con un lampo e un soffio e
  lascia una scia; all'impatto un lampo bianco, un anello che si allarga e si spezza in archi, uno
  scoppio di scintille, un piccolo tremolio e un rintocco di vetro. Sprite sulla griglia di Lethe,
  blend additivo (`CanvasItemMaterial` -> Add) per brillare.
- **Una stanza che racconta**: niente doppioni, solo oggetti che sono uno strato della storia (vedi
  il vault, "La stanza di Lethe"): lo specchio coperto da un lenzuolo, il calendario barrato fino a un
  giorno cerchiato, il vassoio intatto davanti alla porta, la foto a faccia in giù sul comodino, le
  palline di carta accanto alla scrivania, la pianta secca sotto la finestra.
- **Profondità**: il livello dei mobili è ordinato per Y insieme alla protagonista, che passa
  davanti o dietro a seconda di dove sta.

## Sprite della protagonista: solo in locale

Gli sheet in `characters/protagonista/sprites/` non sono nel repo: sono la protagonista disegnata
sopra il [Character Template di Eris Esra](https://erisesra.itch.io/character-templates-pack), che
si può usare nei giochi ma non ridistribuire. Senza quella cartella il progetto si apre lo stesso
(con un errore che lo spiega), ma la protagonista non si vede e i suoi test falliscono.

Il tileset e gli effetti magici invece sono disegnati da zero (generatori in locale) e sono nel repo.
