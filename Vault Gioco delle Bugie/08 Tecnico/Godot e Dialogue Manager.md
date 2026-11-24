---
tags: [tecnico, godot]
stato: in gioco
---
# Godot e Dialogue Manager

## Motore
- **Godot** 4.7

## Il problema
- Il gioco è a scelte → serve un [[Sistema a scelte (grafo)]]
- Godot lo regge? Worst case: no → **evitare backend custom** (costi = $$)

## Soluzione (in gioco)
- Addon **Dialogue Manager** 4.2.0 (Nathan Hoad, MIT), la serie per Godot 4.7: in `stanza/addons/dialogue_manager/`
  - Dialoghi ramificati, condizioni e variabili: le scelte cambiano già `truth` / `lies` (il [[Sistema Karma]])
  - I testi stanno in `stanza/dialogue/stanza.dialogue`: un "cue" per oggetto, col nome del suo tile.
    Un oggetto con un cue diventa interagibile da solo.

## A livello grafico (deciso)
- Riquadro in basso con la finestra e il font del menu di pausa, testo a macchina da scrivere
  con le lamelle del carillon
- Il viso di Lethe a sinistra quando pensa lei; il narratore senza ritratto
- Le scelte in una finestrella sopra, a destra, con il cuore che batte come cursore
- Quando Lethe ha davanti qualcosa con cui parlare, sopra la sua testa compare un'iconcina: un fumetto
  col cuore che batte come quello del menu (tum-tum, pausa). Compare con un piccolo salto, sparisce
  rimpicciolendo, e non la scurisce il buio della stanza. Tasto: E / Z / Invio

## Aperto
- Effetti sul testo (tremolio, glitch come nel menu) per le righe "che non vanno"
- Ritratti con più espressioni?

## Già pronto
- L'intro dello studio, riusabile in ogni gioco: cartella `intro-studio/` del repo
