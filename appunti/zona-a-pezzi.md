# Una zona a pezzi: facciata e figli

**Il problema.** Lo script di un livello cresce: nemici, morte e risveglio, luci, collisioni, cose con
cui parlare, meccanismi, cutscene. Lo script della zona della foresta era arrivato a circa 820
righe, e ogni modifica toccava tutto.

**La soluzione nel gioco.** [stanza/forest/forest_zone.gd](../stanza/forest/forest_zone.gd) è rimasta
il punto d'ingresso (circa 400 righe) ma *monta* dei figli, ognuno con un compito:

| Pezzo | Cosa fa | Tipo |
| --- | --- | --- |
| [zone_combat.gd](../stanza/forest/zone_combat.gd) | nemici, esperienza, cuore, morte e risveglio | `Node` figlio |
| [zone_puzzles.gd](../stanza/forest/zone_puzzles.gd) | piastre, cancelli, chiavi, porte, scatole | `Node` figlio |
| [forest_story.gd](../stanza/forest/forest_story.gd) | la regia: arrivi, Selene, obiettivi | `Node` figlio |
| [zone_dressing.gd](../stanza/forest/zone_dressing.gd) | luci, collisioni, raggi di luna, cose con cui parlare | solo funzioni statiche |
| [screen_text.gd](../stanza/ui/screen_text.gd) | scritte, neri, toast | solo funzioni statiche |

## Le regole che lo tengono in piedi

1. **La zona è la facciata.** I test, la regia e il menu parlano con la zona (`zone.die()`,
   `zone.enemies()`, `zone.died`), non con i pezzi. I segnali dei pezzi vengono ripetuti dalla zona:
   `combat.died.connect(died.emit)`. Così spostare codice da un pezzo all'altro non rompe chi lo usa.
2. **I pezzi ricevono la zona in `setup(zone)`** e da lì leggono quello che serve (`zone.hero`,
   `zone.state`, `zone.talk`). Niente autoload, niente ricerca nell'albero per nome.
3. **Se non tiene stato, è statico.** L'allestimento si fa una volta quando la zona parte: funzioni
   statiche, niente nodo.
4. **L'ordine di montaggio è esplicito** in `_ready()`: camera, combattimento, meccanismi, menu,
   dialoghi, interfaccia, regia. Chi viene dopo può usare chi viene prima.

## I dati del livello stanno fuori dal codice

Ogni zona ha un file di sole costanti ([zone_roots_layout.gd](../stanza/forest/zone_roots_layout.gd)):
terreno, stanze, cose, nemici, entrate, uscite, meccanismi. Lo stesso `forest_zone.gd` fa girare tutte
le zone: il dungeon è "una zona come le altre". Aggiungere una zona vuol dire scrivere dati, non codice.

Un generatore ([tools/make_forest_zone.gd](../stanza/tools/make_forest_zone.gd)) scrive la scena
`.tscn` dai dati; poi la scena si ritocca nell'editor. Attenzione: rigenerare una zona sovrascrive i
ritocchi. Si rigenera solo la zona che cambia.

## Un bug che insegna: due sistemi, la stessa cosa

Nel dungeon le radici che chiudono un passaggio usano lo stesso disegno (`root_gate`) del cancello
dell'arena. L'allestimento rendeva "parlabile" ogni cosa con quel disegno, i meccanismi rendevano
parlabile il cancello col suo testo. Risultato: due voci per la stessa radice, e dopo l'apertura il
passaggio libero diceva ancora "un muro di radici".

La correzione: le cose create dai meccanismi hanno un segno (`set_meta(&"puzzle", true)`) e
l'allestimento le lascia stare. La regola: **una cosa del mondo ha un solo proprietario** per ogni
comportamento. Se due sistemi la guardano, uno dei due deve sapere che non è sua. Il test
(`test_si_parla_con_porta_scatola_e_cancello`) controlla che il passaggio aperto non parli più.

## Quando non dividere

Non si divide per numero di righe, ma quando una parte si capisce da sola e cambia per motivi suoi. Un
pezzo che ha bisogno di metà dei campi della zona per funzionare non è un pezzo: è la zona tagliata a
metà.
