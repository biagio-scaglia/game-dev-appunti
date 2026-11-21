---
tags: [gameplay, sistema]
stato: idea
---
# Sistema a scelte (grafo)

Il gioco è **sostanzialmente a scelte**.

## Dubbi originali
- Solo textbox? O anche altro?
- Serve un **sistema a grafi**: ogni scena è un nodo, ogni scelta un arco.
- Un algoritmo che "connette il tutto".
- Godot lo regge? Ipotesi worst case: no. Quindi **niente backend custom** (costa $$): usare un addon esistente → [[Godot e Dialogue Manager]].

## Struttura proposta
```
[Scena] --verità--> [Scena A]   (karma +1)
        \--bugia---> [Scena B]   (karma -1)
```
- Ogni scelta modifica il [[Sistema Karma]]
- Il karma accumulato apre o chiude rami → [[Route e finali]]

## Note
- Un grafo di dialoghi non è pesante per Godot: sono dati testuali. Il vero costo è **scrivere** tutti i rami.
- Per tenere i rami sotto controllo: struttura "branch & bottleneck" (i rami si separano e poi riconvergono sugli eventi chiave).
