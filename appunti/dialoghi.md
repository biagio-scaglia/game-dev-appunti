# Dialoghi legati al mondo

**Il problema.** In un gioco dove ogni oggetto racconta qualcosa ci sono decine di cose con cui parlare.
Scrivere a mano, per ognuna, un'area di collisione, un collegamento a un testo e un controllo
"già visto?" non scala. E i dialoghi devono poter cambiare il gioco: aprire una porta, contare una bugia.

**La soluzione nel gioco.** [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) per
i testi (ramificazioni, condizioni, variabili) e un nodo piccolo,
[stanza/dialogue/talk.gd](../stanza/dialogue/talk.gd), che li lega al mondo.

## Un cue per oggetto, col nome del tile

Nel file dei dialoghi ([forest.dialogue](../stanza/dialogue/forest.dialogue)) ogni titolo (`~ nome`) ha
il nome del tile della cosa:

```
~ watering_can
if seen("watering_can") == 0
    A small watering can, half buried in the earth. Blue. Never used.
    ...
else
    The price sticker. She never peeled it off.
=> END
```

Le cose con cui si parla sono una lista di `{id, rect}`. Una cosa piazzata nella scena col tile
`watering_can` diventa parlabile da sola, se il suo nome è tra i `TALKS` della zona. Ogni frame `talk.gd`
guarda cosa c'è davanti ai piedi di Lethe, nella direzione in cui guarda
([room_things.gd](../stanza/world/room_things.gd)), e mostra il fumetto sopra la testa.

`seen("id")` conta le visite: la prima volta il racconto intero, poi una riga breve. È il modo più
economico per non ripetere un testo lungo.

## I dialoghi che cambiano il gioco

Dialogue Manager cerca le funzioni e le variabili negli "extra states" passati all'avvio. La zona ci
mette se stessa, lo stato della partita e i meccanismi:

```gdscript
talk.extra_states.append(self)
talk.extra_states.append(puzzles)    # i dialoghi aprono porte e scatole
```

e il testo le chiama:

```
- Use the key.
    Lethe: I locked it. Every night. Then every day.
    do open_door("bedroom")
```

La logica resta nel codice ([zone_puzzles.gd](../stanza/forest/zone_puzzles.gd), `open_door()` controlla
che ci sia la chiave); il dialogo decide *quando* chiederla. Le scelte tra verità e bugia fanno
`set truth += 1` / `set lies += 1` direttamente sullo stato.

## Le righe che mentono

Un tag su una riga intera, `[#wrong]`, la fa guastare e tremare (il riquadro sobbalza, il carillon
stona). Tag dentro la riga (`[glitch]`, `[shiver]`, `[flicker]`) sono effetti `RichTextEffect` in
[text_effects.gd](../stanza/dialogue/text_effects.gd). È la meccanica del gioco (le bugie) resa con il
testo, senza una riga di codice in più per ogni dialogo.

## Fermare il personaggio, e il tasto che chiude

Durante un dialogo Lethe è ferma (`frozen`). Alla fine `talk.gd` aspetta due frame di fisica prima di
liberarla: il tasto che ha chiuso il dialogo è lo stesso della spada, e senza quell'attesa partirebbe un
fendente. Un dettaglio piccolo che si scopre solo giocando. (Il test in
[test_dialogue.gd](../stanza/tests/test_dialogue.gd) controlla che Lethe torni libera; che il fendente
non parta non è ancora coperto.)

## Testarli

Un dialogo si apre da codice (`talk.talk("shoebox")`) e si guida con un piccolo pilota che va avanti e
sceglie una risposta: vedi [Testare un gioco Godot da riga di comando](test-headless.md).
