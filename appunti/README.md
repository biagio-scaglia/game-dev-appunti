# Appunti tecnici

Cose imparate facendo [Aletheia](../README.md) con Godot 4.7, scritte per chi fa un gioco 2D e vuole
vedere una soluzione che gira davvero, non la teoria. Ogni nota parte da un problema incontrato nel
gioco, mostra come è risolto nel codice (con il link al file) e dice quando *non* conviene farlo così.

Il vault Obsidian accanto ([Vault Gioco delle Bugie](../Vault%20Gioco%20delle%20Bugie/)) è il game
design di Lethe: trama, meccaniche, tono. Qui invece c'è il *come*. Le note sono Markdown semplice:
si leggono su GitHub e si aprono anche in Obsidian (*Apri cartella come vault*), senza plugin.

## Da dove partire

Se stai iniziando un progetto, in quest'ordine:

1. [Testare un gioco Godot da riga di comando](test-headless.md): prima i test, poi il resto. Un runner
   di 60 righe, senza addon, che fa da rete a tutto il resto (e gira in CI).
2. [Le azioni di input scritte nel codice](input-in-codice.md): tastiera, mouse e gamepad senza toccare
   la Input Map, e un test che impedisce a due azioni di pestarsi i piedi.
3. [Salvataggi in JSON che non si rompono](salvataggi.md): lo stato come dati puri, la validazione al
   caricamento, la scrittura atomica.
4. [Una zona a pezzi: facciata e figli](zona-a-pezzi.md): come tenere piccolo lo script di un livello
   quando cresce (combattimento, allestimento, meccanismi, regia), con i dati del livello in file a parte.
5. [Dialoghi legati al mondo](dialoghi.md): Dialogue Manager, un "cue" per oggetto, le funzioni del
   gioco chiamate dai dialoghi.
6. [Cutscene come copione](cutscene.md): una scena scritta come una lista di `await`.

Poi [Cosa si può riusare](riusare.md): i pezzi che escono dal gioco e si copiano in un altro progetto,
con le loro dipendenze.

## Le regole di queste note

- Ogni nota cita il file vero. Se il codice cambia, la nota si aggiorna con lui (nello stesso commit).
- Niente argomenti messi solo per completezza: una nota nasce quando un problema è stato risolto nel
  gioco e la soluzione serve anche fuori.
- Gli argomenti che mancano mancano perché il gioco non li ha ancora affrontati (vedi in fondo).

## Non ancora coperti

Arriveranno quando il gioco ci passa: export e distribuzione, profiling (finora non è servito: niente
cali di frame misurati), localizzazione dei testi, accessibilità oltre a quello che c'è già
(tremolio dello schermo disattivabile, velocità del testo, tasti multipli per ogni azione).
