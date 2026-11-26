# Cosa si può riusare

I pezzi del gioco che servono anche in un altro progetto Godot 4.7, con quello che si porta dietro. Non
sono un framework: si copiano i file, si leggono (sono corti, e ognuno spiega in testa cosa fa) e si
adattano.

Una nota sul permesso: il repository non ha ancora una licenza (vedi il [README](../README.md#licenza)).
Finché non c'è, questi pezzi si riusano nei progetti dell'autore; per tutti gli altri qui si possono
leggere e studiare.

Regola usata per questa lista: un pezzo ci sta solo se funziona fuori dal gioco **senza toccare il suo
codice**, o con un cambio di una riga dichiarato qui sotto. Il resto (la zona, il menu di pausa, i
nemici) è codice di Lethe: si legge per imparare, non si copia.

## Pronti da copiare

| Pezzo | Cosa fa | Si porta dietro | Testato in |
| --- | --- | --- | --- |
| [intro-studio/studio_intro/](../intro-studio/studio_intro/) | l'intro dello studio (luna, occhio, nome, musica), saltabile | niente: la cartella è autonoma. Si imposta `next_scene` | [intro-studio/tests/](../intro-studio/tests/) (31 test, anche in CI) |
| [run_tests.gd](../stanza/tests/run_tests.gd) + [base_test.gd](../stanza/tests/base_test.gd) | runner di test headless senza addon | niente | è lui che fa girare gli altri; vedi [test-headless.md](test-headless.md) |
| [core/room_camera.gd](../stanza/core/room_camera.gd) | camera a stanze per i dungeon: limiti per stanza che scivolano alle porte | niente. Il personaggio deve avere `frozen` | [test_roots.gd](../stanza/tests/test_roots.gd) |
| [core/sfx.gd](../stanza/core/sfx.gd) | suono usa-e-getta che si libera da solo e suona anche in pausa | niente | indiretto |
| [core/glow.gd](../stanza/core/glow.gd) | `PointLight2D` morbida con texture a gradiente generata | niente | indiretto |
| [menu/save_store.gd](../stanza/menu/save_store.gd) | slot di salvataggio in JSON, scrittura atomica | niente | [test_menu_logic.gd](../stanza/tests/test_menu_logic.gd) |
| [core/input_setup.gd](../stanza/core/input_setup.gd) | azioni di input create da codice (tastiera, mouse, gamepad) | niente; i dizionari in cima sono lo schema del gioco: si riscrivono | [test_protagonista.gd](../stanza/tests/test_protagonista.gd) |

## Da copiare con un cambio

| Pezzo | Cosa fa | Il cambio |
| --- | --- | --- |
| [core/cutscene.gd](../stanza/core/cutscene.gd) | regista di cutscene con `await` ([cutscene.md](cutscene.md)) | usa [fx/emote.gd](../stanza/fx/emote.gd) (che usa il font di `ui/fonts/`): copiare anche quelli, o togliere `emote()`. Il personaggio deve avere `frozen`, `scripted`, `update_animation()` |
| [ui/heart_menu.gd](../stanza/ui/heart_menu.gd) | lista di `Button` veri (tastiera, gamepad, mouse) con un cursore animato | il cursore è `res://title/art/heart.png`: cambiare il `preload` |
| [ui/screen_text.gd](../stanza/ui/screen_text.gd) | scritta centrata, nero per le dissolvenze, toast, testo che sale | il font è `res://ui/fonts/kenpixel_high_square.ttf` (CC0): cambiare il `preload` |
| [menu/game_state.gd](../stanza/menu/game_state.gd) | il modello: stato come dati, flag della storia, caricamento che valida tutto ([salvataggi.md](salvataggi.md)) | è lo stato di *questo* gioco: si copia la forma (`to_save` / `load_save` / `_list` / `_dict`), non i campi |

## Perché `intro-studio` è un progetto a parte

È l'unico pezzo pensato fin dall'inizio per andare in ogni gioco, quindi vive in un progetto Godot suo,
con una scena demo e i suoi test. Il gioco ne ha una copia in `stanza/studio_intro/`, che differisce
solo nella scena (sottotitolo in inglese, `next_scene` sul titolo). Se si cambia l'intro, si cambia in
`intro-studio/` e si ricopia: per ora non c'è un controllo automatico che le due copie restino uguali.

## Cosa non è stato estratto, e perché

- **Il sistema di dialoghi** ([talk.gd](../stanza/dialogue/talk.gd), [dialogue_box.gd](../stanza/dialogue/dialogue_box.gd)):
  dipende dal personaggio, dall'icona, dallo stile del menu e da Dialogue Manager. Il *metodo* è
  riusabile ed è spiegato in [dialoghi.md](dialoghi.md); il codice no, non ancora.
- **Il combattimento** (nemici, cuore, esperienza): è fatto per Lethe (la spada di vetro, la magia
  della verità). Generalizzarlo adesso vorrebbe dire indovinare cosa serve al prossimo gioco.
- **La zona**: il *modello* (facciata + pezzi + dati) è in [zona-a-pezzi.md](zona-a-pezzi.md).

Un pezzo passa nella lista "pronti" quando serve davvero a un secondo progetto: è lì che si vede cosa
va reso configurabile.
