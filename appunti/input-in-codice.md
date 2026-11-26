# Le azioni di input scritte nel codice

**Il problema.** La Input Map di Godot sta in `project.godot`: si modifica dall'editor, è difficile da
rivedere in un diff, e se copi uno script in un altro progetto le azioni non ci sono. In più un gioco
d'azione ha bisogno di più tasti per la stessa cosa (WASD e frecce, mouse, gamepad) e due azioni non
devono mai rispondere allo stesso tasto per sbaglio.

**La soluzione nel gioco.** [stanza/core/input_setup.gd](../stanza/core/input_setup.gd) crea le azioni
che mancano quando il gioco parte. Tutto lo schema sta in tre dizionari leggibili:

```gdscript
const ACTIONS := {
    &"move_left": [KEY_A, KEY_LEFT],
    &"cast": [KEY_Q, KEY_X, KEY_K],
    &"slash": ACTION_KEYS,
    &"interact": ACTION_KEYS,
    &"menu": [KEY_ESCAPE, KEY_C],
    # ...
}
const JOY_BUTTONS := {&"slash": [JOY_BUTTON_A], &"cast": [JOY_BUTTON_X], &"menu": [JOY_BUTTON_START], ...}
const JOY_AXES := {&"move_left": [JOY_AXIS_LEFT_X, -1.0], ...}
```

`ensure_actions()` si chiama da chi usa l'input (la protagonista, i dialoghi, il menu): è idempotente,
salta le azioni che esistono già. Così una azione definita a mano nella Input Map ha la precedenza.

## Le scelte, e perché

- **`physical_keycode`, non `keycode`.** Il tasto è quello nella *posizione* di W su una tastiera
  americana: su AZERTY WASD diventa ZQSD da solo, senza rimappare niente.
- **Un tasto unico per parlare e colpire.** `interact` e `slash` hanno gli stessi tasti. Chi parla
  (`talk.gd`) gestisce l'evento per primo in `_unhandled_input` e lo segna come gestito, così la spada
  non parte. Meno tasti da imparare, e il gioco li spiega solo quando servono.
- **Movimento con `Input.get_vector`.** Restituisce già un vettore normalizzato con la zona morta
  circolare: tastiera e levetta passano dalla stessa riga
  ([protagonista.gd](../stanza/characters/protagonista/protagonista.gd)).
- **La zona morta delle levette è più piccola (0.3) del default (0.5)**: si cammina piano anche
  inclinando poco. Per i tasti non cambia niente.
- **I menu usano le azioni `ui_*` di Godot** (che hanno già il gamepad): A conferma, B torna indietro.

## Il test che protegge lo schema

In [test_protagonista.gd](../stanza/tests/test_protagonista.gd) (`test_lo_schema_dei_tasti`), oltre a
controllare i tasti principali, un ciclo verifica che nessuna azione condivida un evento con `slash`,
`cast` o `menu` (tranne la coppia voluta `slash`/`interact`). Aggiungendo un tasto che ne ruba un altro,
il test fallisce prima che te ne accorga giocando.

## Cosa manca

La rimappatura da parte del giocatore. Quando servirà: salvare gli eventi scelti in
`user://settings.cfg` (c'è già [settings_store.gd](../stanza/core/settings_store.gd)), riapplicarli
dopo `ensure_actions()`, e riusare lo stesso controllo dei conflitti del test per rifiutare un tasto già
usato.
