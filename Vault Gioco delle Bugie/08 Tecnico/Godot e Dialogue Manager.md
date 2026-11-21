---
tags: [tecnico, godot]
stato: da verificare
---
# Godot e Dialogue Manager

## Motore
- **Godot**

## Il problema
- Il gioco è a scelte → serve un [[Sistema a scelte (grafo)]]
- Godot lo regge? Worst case: no → **evitare backend custom** (costi = $$)

## Soluzione proposta
- Usare l'addon **Dialogue Manager** per Godot (negli appunti "Dialog Manager 2" `[?]`)
  - Verificare la versione compatibile con la versione di Godot che useremo (per Godot 4 esiste la serie più recente dell'addon)
  - Permette dialoghi ramificati, condizioni e variabili → il `karma` del [[Sistema Karma]] può stare lì

## Aperto
- Come impostare i dialoghi **a livello grafico**? (box, ritratti, effetti)

## Già pronto
- L'intro dello studio, riusabile in ogni gioco: cartella `intro-studio/` del repo
