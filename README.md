# game-dev-appunti

Appunti e pezzi riusabili per i miei giochi in pixel art, fatti con Godot 4.7.

![Lethe nella stanza](docs/stanza.gif)

## Contenuto

| Cartella | Cos'è |
| --- | --- |
| [stanza](stanza/) | Il gioco, titolo provvisorio **Aletheia**: intro dello studio, schermata del titolo, poi la stanza di un hikikomori di notte. La protagonista, Lethe, cammina, corre, lancia magie che illuminano la stanza e fende con una spada di vetro. |
| [intro-studio](intro-studio/) | L'intro dello studio (la luna che guarda) da copiare all'inizio di ogni gioco, con i suoi test. |
| [Vault Gioco delle Bugie](Vault%20Gioco%20delle%20Bugie/) | Vault Obsidian con storia, lore e idee del gioco (un gioco a scelte sulle bugie). Si apre con *Obsidian → Apri cartella come vault* e si parte da `00 Home/🏠 Home.md`. |

## Provarlo

Serve [Godot 4.7](https://godotengine.org/download). `$GODOT` qui sotto è il percorso dell'eseguibile.

```sh
cd stanza
$GODOT --path .                                          # gioca
$GODOT --headless --path . -s res://tests/run_tests.gd   # test
```

| Tasto | Azione |
| --- | --- |
| WASD / frecce | cammina (8 direzioni) |
| Shift | corri |
| Spazio / J | magia: la carica sulle mani, poi il colpo parte verso dove guarda |
| K | spada di vetro dello specchio |
| Esc / X | menu di pausa (oggetti, incantesimi, equipaggiamento, stato, salvataggi) |

Gli sprite di Lethe **non sono nel repo** (sono disegnati sopra un template che non si può
ridistribuire): senza, il gioco si apre lo stesso ma lei non si vede. Dettagli nel
[README della stanza](stanza/README.md#sprite-della-protagonista-solo-in-locale).

## Lethe

Capelli bianchi lunghi, occhi viola, vestito nero e viola. La stanza è al buio, rischiarata solo
dal monitor, dalla lampada e da uno spiraglio di luna tra le tende: la sua magia viola la illumina
mentre vola. La spada è fatta del vetro dello specchio coperto, e cresce a ogni bugia.

## Crediti

- Base dei personaggi: [Character Templates Pack](https://erisesra.itch.io/character-templates-pack) di Eris Esra
- Font: Kenney Pixel ([kenney.nl](https://www.kenney.nl), CC0)
- Tileset, effetti, spada, musica e suoni: fatti da zero per il gioco
