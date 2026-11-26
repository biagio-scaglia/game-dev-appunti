# Testare un gioco Godot da riga di comando

**Il problema.** Un gioco cambia ogni giorno, e provarlo a mano dopo ogni modifica non scala: dopo
un mese non si ricontrolla più il prologo per vedere se lo specchio chiama ancora. Serve qualcosa che
lo faccia da solo, in pochi minuti, anche su GitHub.

**La soluzione nel gioco.** Un runner di una sessantina di righe, senza addon:
[stanza/tests/run_tests.gd](../stanza/tests/run_tests.gd) e la base dei test
[base_test.gd](../stanza/tests/base_test.gd). Si lancia così:

```sh
godot --headless --audio-driver Dummy --path stanza -s res://tests/run_tests.gd
```

## Come funziona

- Il runner estende `SceneTree`: con `-s` Godot usa lui come albero principale, senza aprire scene.
- Cerca i file `res://tests/test_*.gd`, e in ognuno i metodi `test_*`. Per ogni test crea un'istanza
  nuova (niente stato che passa da un test all'altro), chiama `before()`, il test e `after()`, tutti
  con `await`: un test può aspettare frame, segnali, tween.
- Gli assert non fermano il test: si accumulano in `failures`, così un fallimento mostra tutto quello
  che non va.
- Esce con `quit(1)` se qualcosa fallisce: la CI diventa rossa.

## La trappola: il test che non compila

Se un file di test ha un errore di sintassi, `load()` dà uno script che non si può istanziare. La prima
versione del runner lo saltava in silenzio: il totale diceva "0 falliti" con un intero file mai
eseguito. Ora un file che non compila conta come fallito:

```gdscript
var script: GDScript = load(TESTS_DIR.path_join(file))
if script == null or not script.can_instantiate():
    failed += 1
    print("  FAIL  il file non compila (vedi SCRIPT ERROR sopra)")
    continue
```

Lezione generale: un runner deve fallire *rumorosamente*. "Verde" deve voler dire "tutto eseguito e
passato", non "niente è esploso".

## Gli aiuti che rendono testabile una scena

Il codice di gioco ha qualche gancio pensato per i test. Sono pochi e semplici:

| Gancio | A cosa serve | Esempio |
| --- | --- | --- |
| `sound = false` | i nodi non suonano: niente rumore, niente player audio da liberare | `add_scene(ZONE, func(n): n.sound = false)` |
| `Main.pending_save` | si parte da uno stato preciso (flag, zona, karma) senza giocare fino lì | [test_roots_puzzles.gd](../stanza/tests/test_roots_puzzles.gd), `_zone()` |
| `pace` / `Engine.time_scale` | le cutscene e le attese vanno più veloci | `Engine.time_scale = 6.0` |
| `SaveStore.dir` | i salvataggi dei test vanno in un'altra cartella | [test_menu_logic.gd](../stanza/tests/test_menu_logic.gd) |
| funzioni pubbliche come `talk("id")`, `press(id)` | si attiva una cosa senza simulare i tasti | `zone.talk.talk("bedroom_door")` |

Per i dialoghi c'è un piccolo "pilota" che va avanti da solo e sceglie una risposta:

```gdscript
func _drive(talk: Node, pick := 0) -> void:
    for i in 400:
        await tree.process_frame
        var box = talk.box
        if not is_instance_valid(box):
            break
        if box.choices_panel.visible:
            box.choose(pick)
        elif box.waiting or box.text_label.is_typing:
            box.advance()
```

## Cosa testare (e cosa no)

- **Sì:** le regole (il cuore che non va oltre il massimo, l'esperienza per livello), i percorsi di
  gioco (il passaggio si apre, la chiave si prende, *anche con una partita di sole bugie*), i bug già
  trovati (ogni bug corretto ha il suo test, così non torna).
- **Sì, ma con misura:** che una cosa sia visibile, faccia luce, sia sotto o sopra un'altra.
- **No:** l'aspetto. Per quello ci sono gli screenshot automatici
  ([tools/capture_frames.gd](../stanza/tools/capture_frames.gd)) e gli occhi.

Il numero dei test non è la misura: conta che ogni test controlli un comportamento che, se si rompe,
il giocatore se ne accorge.

## In CI

[.github/workflows/test.yml](../.github/workflows/test.yml): scarica Godot (in cache), importa il
progetto (un checkout nuovo non ha `.godot/`: senza `--import` le risorse non si caricano), lancia i
test del gioco e quelli di `intro-studio`, salva i log come artefatti.

## Quando non basta

Per un progetto grande, con molti sviluppatori, conviene un framework vero (gdUnit4, GUT): report,
mock, test parametrizzati. Questo runner basta finché i test sono di una persona e stanno in un
minuto o due.
