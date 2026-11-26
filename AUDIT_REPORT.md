# Audit di game-dev-appunti

Data: 26 novembre 2026. Godot 4.7.2 (Windows, headless). Tutto quello che è segnato come verificato è
stato eseguito davvero; quello che non è stato possibile verificare è detto esplicitamente.

## In breve

| | Iniziale | Finale |
| --- | ---: | ---: |
| **Punteggio ponderato** | **6.0 / 10** | **7.6 / 10** |

Il gioco è scritto bene: tipizzato, commentato in testa a ogni file, con una suite di test che controlla
comportamenti veri e gira in CI. I punti deboli erano altrove: una knowledge base tecnica praticamente
assente, una documentazione rimasta indietro rispetto al codice, nessuna licenza, e qualche fragilità
nei salvataggi. Il 10 non è stato raggiunto, e non sarebbe onesto dirlo: i limiti che restano sono in
fondo, con il motivo.

## La mappa del repository

```
game-dev-appunti/
├── stanza/                 il gioco (Godot 4.7): 134 script, 23 file di test (257 test)
│   ├── title/ opening/ prologue/   titolo, cutscene iniziale, prologo nella stanza
│   ├── forest/             capitolo 1: tre zone, una facciata (forest_zone.gd) + pezzi
│   │                       (combat, dressing, puzzles, story) + dati per zona (*_layout.gd)
│   ├── characters/ enemies/ weapon/ magic/   Lethe, Selene, nemici, spada, magia
│   ├── dialogue/           Dialogue Manager + talk.gd (le cose con cui si parla)
│   ├── menu/               menu di pausa, GameState (lo stato salvato), SaveStore
│   ├── core/ ui/ fx/ world/   pezzi trasversali: input, camera, cutscene, luci, HUD, effetti, tile
│   ├── tests/              runner headless senza addon + un file per modulo
│   └── tools/              generatori di scene e tileset (GDScript); i generatori Python sono locali
├── intro-studio/           l'intro dello studio come progetto a sé (31 test), copiata in stanza/
├── appunti/                (nuovo) la knowledge base tecnica
├── Vault Gioco delle Bugie/   vault Obsidian: game design, trama, personaggi, tono (31 note)
├── docs/                   immagini del README
└── .github/workflows/      CI: import + test
```

Dipendenze esterne: solo Dialogue Manager 4.2.0 (MIT, con la sua LICENSE nell'addon). Un solo autoload
(quello dell'addon). Nessun file Python, nessun dato personale oltre al nome dell'autore.

## Punteggi

| Categoria | Peso | Iniziale | Finale |
| --- | ---: | ---: | ---: |
| Qualità tecnica | 20% | 7.5 | 8.5 |
| Architettura e manutenibilità | 15% | 8.0 | 8.0 |
| Qualità della knowledge base | 20% | 3.0 | 6.5 |
| Riutilizzabilità | 15% | 5.5 | 7.0 |
| Testing e affidabilità | 10% | 8.0 | 9.0 |
| Documentazione | 10% | 6.0 | 8.5 |
| Developer Experience | 5% | 7.0 | 8.0 |
| Open Source Readiness | 5% | 3.0 | 4.5 |
| **Totale ponderato** | | **6.0** | **7.6** |

### Qualità tecnica: 7.5 → 8.5

- **Evidenze iniziali.** Nessun errore né warning all'import; tutti i 134 script passano
  `--check-only`; nessun leak né `SCRIPT ERROR` nei log dei test. Tipizzazione statica diffusa.
- **Problemi trovati.**
  - Salvataggi scritti direttamente sopra il file: un'interruzione a metà lasciava uno slot troncato,
    che `read()` trattava come vuoto. Il salvataggio era perso senza avviso.
  - `GameState.load_save()` e `saved_position()` andavano in errore con un JSON valido ma coi campi del
    tipo sbagliato (es. `"equipped": []` assegnato a una variabile `Dictionary`, `"position": [12]`).
  - `heart_max` caricato non era limitato a `HEART_CAP`.
  - Nessun supporto al gamepad nel gioco (solo nei menu, tramite le azioni `ui_*` di Godot).
  - In `talk.gd` una condizione su due righe era stata incollata su una sola, con tabulazioni in mezzo.
  - (Dal playtest della stessa giornata, corretti prima dell'audit: la chiave del dungeon spariva dopo
    25 secondi come una mela; il passaggio di radici aperto rispondeva ancora "muro di radici".)
- **Interventi.** Scrittura atomica (`.tmp` + rinomina); caricamento che valida i tipi (`_list`,
  `_dict`) e limita il cuore; azioni del gamepad (levetta, croce, A, X, Start, grilletto) con zona morta
  0.3 per il movimento; riga di `talk.gd` ricomposta.
- **Perché non di più.** I personaggi sono raggiunti con `set(&"frozen")` / `call(&"is_attacking")`:
  è flessibile ma un nome sbagliato non dà errore. Nessuna misura di performance (non ce n'è stato
  bisogno, ma non è stata verificata).

### Architettura e manutenibilità: 8.0 → 8.0

- **Evidenze.** La zona è una facciata che monta pezzi con compiti chiari; i livelli sono dati
  (`*_layout.gd`) letti da un unico script; logica pura separata dai nodi (`GameState`, `Equipment`,
  `RoomThings`, `Facing`); niente autoload propri.
- **Problemi.** Due copie dell'intro (`intro-studio/studio_intro` e `stanza/studio_intro`) senza un
  controllo che restino allineate (oggi differiscono solo nella scena, come voluto). Accoppiamento per
  nomi di proprietà (vedi sopra). Il generatore delle zone sovrascrive i ritocchi fatti nell'editor.
- **Interventi.** Nessun refactoring: il codice non ne aveva bisogno, e riscrivere sistemi funzionanti
  era escluso. I rischi sono ora scritti (README della stanza, `appunti/zona-a-pezzi.md`,
  `appunti/riusare.md`).

### Qualità della knowledge base: 3.0 → 6.5

- **Situazione iniziale.** Il vault è di game design (ben fatto, ma non tecnico). La conoscenza tecnica
  stava solo nelle intestazioni degli script e nel README della stanza, file per file: utile per chi
  lavora sul gioco, inutile per chi vuole imparare *come* si fa una cosa.
- **Interventi.** Nuova cartella `appunti/` con 7 note, ognuna nata da un problema reale del gioco,
  con il codice che lo risolve, i compromessi e quando *non* farlo così:
  test headless, input da codice, salvataggi, zona a pezzi, dialoghi, cutscene, riuso.
  Ogni affermazione è stata controllata sul codice (due sono state corrette durante la verifica: la
  lunghezza storica di `forest_zone.gd`, e un test che non copre quello che la nota diceva).
- **Perché non di più.** Sette note sono poche. Mancano argomenti che il gioco non ha ancora affrontato
  (export, profiling, localizzazione, accessibilità, shader). Non sono stati scritti apposta: una nota
  senza un caso reale dietro sarebbe teoria generica, contro lo spirito del repository.

### Riutilizzabilità: 5.5 → 7.0

- **Evidenze.** `intro-studio` è un esempio pulito: cartella autonoma, opzioni nell'Inspector, segnale
  `finished`, test propri. Diversi pezzi del gioco non hanno dipendenze (`room_camera`, `sfx`, `glow`,
  `save_store`, `input_setup`, il runner dei test) ma nessuno lo diceva.
- **Interventi.** `appunti/riusare.md`: per ogni pezzo cosa fa, cosa si porta dietro (verificato con
  i `preload`), dove è testato; quelli che servono un cambio di una riga; cosa *non* è stato estratto
  e perché (dialoghi, combattimento, zona). Runner di `intro-studio` allineato a quello del gioco.
- **Perché non di più.** Niente è stato estratto in un pacchetto: sarebbe stato prematuro senza un
  secondo progetto che lo usa. Le due copie dell'intro restano manuali.

### Testing e affidabilità: 8.0 → 9.0

- **Evidenze.** 255 test iniziali, quasi tutti di comportamento (percorsi di gioco, regole, bug già
  visti, una partita "di sole bugie"). Runner che fallisce se un file non compila. CI su ogni push.
- **Problemi.** I test di `intro-studio` non giravano in CI; il suo runner saltava in silenzio un file
  che non compila (la correzione c'era solo nella copia del gioco).
- **Interventi.** CI estesa a `intro-studio` (import + test, log negli artefatti). Runner allineato.
  Nuovi test: salvataggio riscritto senza `.tmp` residuo, salvataggio coi campi sbagliati, schema del
  gamepad; più quelli del playtest (chiave che aspetta, passaggio aperto muto, obiettivi passo passo,
  piastra che pulsa).
- **Perché non di più.** Nessuna misura di copertura (Godot non la offre nativamente). Alcuni dettagli
  noti non hanno test (il tasto che chiude un dialogo non deve far partire la spada).

### Documentazione: 6.0 → 8.5

- **Problemi.** Il README della stanza non nominava 18 file (Selene, la regia della foresta, i pezzi
  della zona, le zone 2 e 3, le impostazioni del titolo, la camera a stanze...) e descriveva la
  foresta com'era alla prima zona ("l'uscita, per ora: titolo"). Il README principale diceva "la prima
  zona" e "più di 200 test". La nota tecnica del vault citava un solo file di dialoghi.
- **Interventi.** README della stanza: blocco della foresta riscritto, tutti i file presenti, gamepad,
  avviso sul generatore che sovrascrive. README principale: stato vero del capitolo 1, appunti, gamepad,
  cosa resta locale (generatori Python, allegati del vault), licenza. Vault: ingresso per chi arriva
  nella Home, nota tecnica aggiornata.
- **Verifiche.** Tutti i link relativi dei README e degli appunti puntano a file esistenti (0 rotti).

### Developer Experience: 7.0 → 8.0

- **Evidenze.** Comandi chiari per giocare, testare, catturare screenshot; CI con log scaricabili;
  azioni di input che non richiedono la Input Map.
- **Interventi.** Gamepad; percorso di lettura negli appunti; avviso esplicito sul generatore delle
  zone.
- **Limite.** Sprite, suoni e musiche si rigenerano solo con gli script Python dell'autore, che per
  scelta non sono nel repository: chi clona può usare gli asset, non rifarli.

### Open Source Readiness: 3.0 → 4.5

- **Problemi.** Nessuna licenza. Nessuna guida per contribuire.
- **Interventi.** Sezione *Licenza* nel README che dice com'è (nessuna licenza scelta: il codice si legge,
  non si riusa) e riassume le licenze di terze parti; la nota sul riuso è coerente con questo. Le
  attribuzioni (Eris Esra, Kenney, Nathan Hoad) erano già corrette e sono state verificate (la LICENSE
  MIT dell'addon è presente).
- **Perché resta bassa.** Scegliere una licenza è una decisione dell'autore, non di un audit. È il
  singolo intervento che sposterebbe di più questo voto.

## File modificati

Codice: `stanza/menu/save_store.gd`, `stanza/menu/game_state.gd`, `stanza/core/input_setup.gd`,
`stanza/dialogue/talk.gd`, `intro-studio/tests/run_tests.gd`, `.github/workflows/test.yml`.
Test: `stanza/tests/test_menu_logic.gd`, `stanza/tests/test_protagonista.gd`.
Documentazione: `README.md`, `stanza/README.md`, `Vault Gioco delle Bugie/00 Home/🏠 Home.md`,
`Vault Gioco delle Bugie/08 Tecnico/Godot e Dialogue Manager.md`.
Nuovi: `appunti/` (README, test-headless, input-in-codice, salvataggi, zona-a-pezzi, dialoghi,
cutscene, riusare), `AUDIT_REPORT.md`.

## Verifiche eseguite

| Controllo | Esito |
| --- | --- |
| Test del gioco (`stanza`, headless, Windows) | 257 passati, 0 falliti |
| Test di `intro-studio` | 31 passati, 0 falliti |
| Import headless del progetto (`--import`) | nessun errore né warning |
| `--check-only` su tutti i 134 script del gioco | nessun errore |
| Log dei test: `SCRIPT ERROR`, leak, orfani | nessuno |
| Link Obsidian del vault | nessun link a note mancanti; mancano solo le immagini di `99 Allegati/` (locali per scelta) |
| Link relativi in README e appunti | 0 rotti |
| File Python nel repository | 0 |
| CI su Linux con il nuovo passo di `intro-studio` | **non verificata qui**: si vedrà al primo push |

## Problemi ancora aperti

1. **Licenza** da scegliere (es. MIT per il codice, e una scelta separata per gli asset originali).
2. **Le due copie dell'intro** non hanno un controllo automatico di allineamento.
3. **Accoppiamento per nomi** (`set(&"frozen")`, `call(&"update_animation")`): un errore di battitura
   non dà errore. Un test che controlla che la protagonista abbia le proprietà usate da cutscene e
   camera lo renderebbe sicuro senza cambiare l'architettura.
4. **Rimappatura dei tasti** da parte del giocatore: assente (la strada è in `appunti/input-in-codice.md`).
5. **Il campo `stato` del vault** ha 14 valori liberi (`bozza`, `idea`, `idea forte`, `deciso, da fare`...):
   una scala corta (idea, bozza, deciso, in gioco) renderebbe le note filtrabili. Non toccato: sono note
   dell'autore.
6. **`intro-studio/studio_intro/README.md`** cita "come Erbalta": riferimento non chiaro a chi legge.
7. **Nessun test** per il tasto che chiude un dialogo (non deve far partire la spada).

## Suggerimenti per dopo

- Scegliere la licenza prima di condividere il repository.
- Aggiungere una nota negli appunti ogni volta che il gioco risolve un problema nuovo (il prossimo
  candidato naturale: il buio e le lanterne del dungeon, passo 4).
- Quando partirà un secondo gioco, spostare in un posto comune solo i pezzi che quel gioco usa davvero
  (la lista è in `appunti/riusare.md`).
