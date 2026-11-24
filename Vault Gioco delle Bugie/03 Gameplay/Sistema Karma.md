---
tags: [gameplay, sistema]
stato: idea
---
# Sistema Karma

Gameplay basato su un **sistema di bugie "karmico"**.

## Implementazione semplice
- Un **contatore intero**: `karma = 0`
- Verità → `karma += 1` (+++)
- Bugia → `karma -= 1` (---)
- Facile da settare e da leggere dal sistema di dialoghi ([[Godot e Dialogue Manager]])

## Cosa dà il karma?
→ [[Verità = Magia, Bugia = Spada]]

## Il mondo si svuota (l'isolamento come meccanica)
Il karma non cambia solo le armi: cambia **quanta gente c'è** → [[Trama - bozza]].
- Ogni abitante ha una soglia: se le bugie superano le verità di troppo, al ritorno non c'è più.
  Al suo posto una **sagoma vuota**; la sua missione si chiude ([[Cose da fare]]).
- Con la verità tornano (non tutti: chi è stato dimenticato bevendo dal [[Il Lete|Lete]] no).
- Le case si chiudono, le strade restano vuote, la musica perde strumenti.
- Lethe non viene mai sgridata: il mondo **diventa come la sua stanza**, e basta.
- In gioco ci sono già due contatori (`truth`, `lies` in `GameState`) → [[Route e finali]].

## Varianti da valutare
- Due contatori separati (`verita`, `bugie`) invece di uno solo: rende più facile riconoscere la route **neutral**
- Bugie "piccole" e bugie "grandi" con pesi diversi

Collegato: [[Route e finali]], [[Sistema a scelte (grafo)]]
