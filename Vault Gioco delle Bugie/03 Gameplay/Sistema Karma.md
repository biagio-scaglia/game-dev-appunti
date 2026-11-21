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

## Varianti da valutare
- Due contatori separati (`verita`, `bugie`) invece di uno solo: rende più facile riconoscere la route **neutral**
- Bugie "piccole" e bugie "grandi" con pesi diversi

Collegato: [[Route e finali]], [[Sistema a scelte (grafo)]]
