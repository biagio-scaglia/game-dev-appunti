# Salvataggi in JSON che non si rompono

**Il problema.** Un salvataggio vive più a lungo del codice che lo ha scritto: cambi un campo, aggiungi
un oggetto, togli un incantesimo, e i file vecchi devono ancora caricarsi. E un file può arrivare rotto:
il gioco chiuso a metà scrittura, un giocatore che lo ritocca a mano.

**La soluzione nel gioco.** Due script piccoli, senza nodi:

- [stanza/menu/game_state.gd](../stanza/menu/game_state.gd): lo stato della partita come *dati puri*
  (un `RefCounted`), con `to_save()` e `load_save()`.
- [stanza/menu/save_store.gd](../stanza/menu/save_store.gd): solo file, uno per slot, JSON in
  `user://saves/`.

## 1. Lo stato è dati, non nodi

Tutto quello che si salva sta in `GameState`: karma (`truth`, `lies`), cuore, livello, incantesimi,
equipaggiamento, zona. I nodi (la protagonista, i nemici) *leggono* lo stato, non lo contengono. Così lo
stato si salva con un dizionario e si testa senza scene.

La storia sta in un dizionario di flag (`flags`): `"gate_thorns"`, `"key_old_key"`,
`"heart_seen"`... Aggiungere una cosa nuova che si ricorda non cambia il formato del file: è un flag in
più. I meccanismi del dungeon ([zone_puzzles.gd](../stanza/forest/zone_puzzles.gd)) leggono i flag
quando la zona parte e ricreano il mondo com'era (la porta resta aperta).

## 2. Al caricamento non ci si fida di niente

`load_save()` legge ogni campo con un valore di riserva e scarta quello che non torna:

- un incantesimo o un oggetto che non esiste più (rinominato, tolto) si salta;
- l'equipaggiamento si rimette solo se Lethe possiede l'oggetto *e* lo slot è giusto;
- i numeri si limitano (`heart_max` tra 1 e `HEART_CAP`, il cuore tra 1 e il massimo);
- un campo del tipo sbagliato (una stringa dove serve una lista) vale come vuoto, con `_list()` e
  `_dict()`, invece di mandare in crash l'assegnazione tipizzata.

```gdscript
static func _list(data: Dictionary, key: String) -> Array:
    var value = data.get(key, [])
    return value if value is Array else []
```

C'è un `"version"` nel file: per ora nessuna migrazione è servita, perché i campi nuovi hanno sempre un
default sensato. Quando servirà una trasformazione vera (un campo che cambia significato), si fa in
`load_save` guardando la versione.

## 3. Scrivere senza mai lasciare uno slot a metà

Scrivere direttamente sopra il file vecchio è pericoloso: se il gioco si chiude a metà, il file resta
troncato, il JSON non si legge e `read()` lo tratta come vuoto. Il salvataggio di prima è perso.

Si scrive prima in un file accanto, e solo se è andato tutto bene lo si mette al posto del vecchio:

```gdscript
var tmp := path(slot) + ".tmp"
var file := FileAccess.open(tmp, FileAccess.WRITE)
file.store_string(JSON.stringify(data, "\t"))
var ok := file.get_error() == OK
file.close()                                  # prima chiudere, poi rinominare
if not ok or DirAccess.rename_absolute(tmp, path(slot)) != OK:
    DirAccess.remove_absolute(tmp)
    return false
```

Il rinomina è l'operazione che il sistema operativo fa "tutta o niente": nel caso peggiore resta il file
vecchio intero.

## I test

[test_menu_logic.gd](../stanza/tests/test_menu_logic.gd): salvare e rileggere, un file che non è JSON
vale come vuoto, uno slot riscritto non lascia il `.tmp` in giro, un salvataggio coi campi del tipo
sbagliato si carica senza errori. E `test_all_inizio_lethe_non_ha_niente`: un salvataggio vecchio che
dice "ha la spada" senza averla trovata non regala niente.

## Perché JSON e non `ResourceSaver`

Un `.tres` salvato può contenere script, e caricarlo li esegue: un file di salvataggio scaricato da
internet diventa codice. JSON sono solo dati. In più si legge a occhio quando c'è un bug.
