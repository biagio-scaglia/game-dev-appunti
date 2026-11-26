# Cutscene come copione

**Il problema.** Una cutscene è una sequenza: bande nere, la camera va là, il personaggio cammina, una
nuvoletta "!", un dialogo, la camera torna. Con timer e segnali collegati a mano diventa un groviglio
di callback, difficile da leggere e da cambiare.

**La soluzione nel gioco.** [stanza/core/cutscene.gd](../stanza/core/cutscene.gd): ogni passo è una
funzione che si può aspettare con `await`. Una scena si scrive dall'alto in basso, come un copione:

```gdscript
await cut.begin()                        # bande nere, Lethe ferma, l'interfaccia via
cut.face(zone.hero, Vector2.DOWN)
await cut.wait(0.9)
cut.emote(zone.hero, "?")
await cut.pan_to(zone.hero.global_position + Vector2(0, -90), 1.4)
await cut.say(DIALOGUE, "roots_arrive")
await cut.pan_back(1.0)
await cut.end()                          # tutto come prima, si gioca
```

(da `enter_roots()` in [forest_story.gd](../stanza/forest/forest_story.gd)).

## Perché funziona

- **`await` su un tween o un segnale** sospende la funzione senza bloccare il gioco: le animazioni, le
  luci e la musica vanno avanti.
- **I passi che non serve aspettare non si aspettano** (`emote`, `face`): partono e il copione continua.
- **`begin()` ed `end()` sono simmetrici**: chi scrive la scena non deve ricordarsi di nascondere e
  rimostrare l'interfaccia o di liberare il personaggio.
- **`pace`** accorcia tutte le attese: i test fanno girare le cutscene vere, in fretta.
- **La camera resta quella del giocatore**: `pan_to` la sposta rispettando i suoi limiti
  (`clamp_to_limits`), così una cutscene non mostra mai fuori dalla mappa.

## Le dipendenze

Il regista conosce il personaggio solo per due proprietà (`frozen`, `scripted`) e un metodo
(`update_animation`), chiamati con `set()` e `call()`: un altro personaggio con gli stessi nomi va bene.
Per i dialoghi usa un nodo con `say(resource, cue)` e il segnale `talk_finished`.

## Attenzione

Una funzione con `await` può riprendere quando il nodo non c'è più (cambio di scena durante la
cutscene). Le cutscene qui partono e finiscono dentro la stessa zona; se una scena cambia livello, il
cambio va fatto come *ultimo* passo, dopo `end()`.
