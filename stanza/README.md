# stanza

Progetto Godot 4.7 del gioco (titolo provvisorio **Aletheia**, testi per ora in inglese): si apre
con l'intro dello studio, poi la schermata del titolo, con New Game una breve cutscene, poi la
stanza di un hikikomori di notte.
La protagonista, Lethe, cammina in 8 direzioni, corre, lancia magie che illuminano la stanza e
fende con la spada di vetro dello specchio.

![Il titolo](../docs/titolo.png)

![La stanza](../docs/stanza.gif)

I tasti non sono scritti a schermo: il gioco li spiegherà man mano, quando servono (vedi il vault,
"Trama - bozza").

| Tasto | Azione |
| --- | --- |
| WASD / frecce | cammina; tenendo la direzione per un attimo corre da sola (Shift: corre subito) |
| Spazio / Z / J / E / Invio / clic sinistro | il tasto unico: parla con la cosa davanti (sopra la testa di Lethe compare un fumetto col cuore) e va avanti nei dialoghi; se davanti non c'è niente, spada di vetro (solo quando Lethe ha la spada in mano) |
| Q / X / K / clic destro | magia (carica sulle mani, poi il proiettile parte verso dove guarda); solo quando Lethe sa un incantesimo |
| F2 | solo in debug: cambia lo stadio della spada |
| Esc / C | menu di pausa (Esc, C o tasto destro: indietro) |

Col gamepad: levetta sinistra o croce per camminare, A il tasto unico, X la magia, Start il menu
(B indietro), grilletto destro per correre subito (`core/input_setup.gd`).

## Comandi

`$GODOT` è il percorso dell'eseguibile di Godot 4.7; i comandi si lanciano da questa cartella.

```sh
$GODOT --path .                                                   # gioca
$GODOT --headless --path . -s res://tests/run_tests.gd            # test
$GODOT --path . -s res://tools/capture_frames.gd -- <cartella>    # screenshot automatici della stanza
$GODOT --path . -s res://tools/capture_frames.gd -- <cartella> - res://title/title_screen.tscn  # ...del titolo
```

## Com'è fatto

```
studio_intro/                    l'intro dello studio (copiata da ../intro-studio, sottotitolo "presents")
title/
├── title_screen.gd / .tscn      il titolo: Lethe davanti alla porta chiusa, la luna da una parte e la
│                                luce calda sotto la porta dall'altra. Appare dal nero, poi il menu
│                                Continue (se c'è un salvataggio) / New Game / Talk to Someone / Quit
│                                (Quit: lo schermo si rompe come in un incubo, poi si chiude)
├── title_door.gd                la porta: luce sotto, vassoio davanti; ogni tanto bussano e sotto
│                                compaiono i piedi
├── care_note.gd                 le pagine calme: l'avviso sui contenuti (la prima volta) e
│                                "Talk to Someone" coi numeri d'aiuto
├── title_backdrop.gd            raggio di luna (con le nuvole che passano) e pulviscolo
├── title_figure.gd              Lethe di spalle nel raggio (solo se ci sono i suoi sprite)
├── settings_page.gd             le impostazioni: volume, musica, schermo intero, tremolio, velocità
│                                del testo, cancellare i file
├── file_eraser.gd               cancellare un file, che non va come dovrebbe (il File 3 non si
│                                cancella, un file vero resiste prima di sparire)
├── title_name.gd                il titolo col nome nascosto: ogni tanto di A-LETHE-IA resta solo LETHE
└── art/                         finestra con tende e luna, pavimento, pannello del menu, cuore,
                                 ornamento (dal generatore in locale: griglia a 16 px, blocchi 2x2)
opening/
├── opening.gd / .tscn           la cutscene di New Game (~20 s, senza dialoghi): nero e bussano, il
│                                calendario si barra fino al giorno cerchiato, sotto "tomorrow I'll
│                                go out." e le sue eco sempre più sbiadite, nero e bussano, la stanza.
│                                Un tasto chiede conferma, il secondo salta. Continue non ci passa
└── calendar_page.gd             il foglio del calendario, disegnato in codice a blocchi di 2 pixel
forest/
├── zone_roots.tscn              il dungeon delle radici, sotto l'albero secco: 7 stanze più l'arena
│                                (3x3 schermi), scavate nella terra; la camera resta sulla stanza e
│                                scivola passando una porta (core/room_camera.gd); il nome della
│                                stanza la prima volta; la cornice d'argento dove ci si riposa;
│                                i meccanismi (zone_puzzles.gd): la piastra con l'impronta, il cancello
│                                di radici, la chiave e la porta della camera di Lethe, la scatola da
│                                scarpe col filo rosso; il passo 4 (zone_lanterns.gd): le lanterne di
│                                radice, la tenda di radici, il gesto Aprire dalla pietra antica, gli
│                                occhi nelle radici; le lanterne accese aprono l'arena
├── zone_wake.tscn               la prima zona della foresta (40x24 celle, 2x2 schermi), dove Lethe
│                                cade dallo specchio: bosco fitto intorno, il sentiero, il primo
│                                ruscello del Lete col ponte, i rovi sul ramo a nord, lo specchio.
│                                Scritta da tools/make_forest_zone.gd, poi si ritocca nell'editor
│                                (pennello del terreno; le cose sono Sprite2D da spostare)
├── zone_tree.tscn               la seconda zona: la radura dell'albero secco (la pianta del davanzale
│                                di Lethe, enorme), col buco tra le radici che scende al dungeon
├── zone_wake_layout.gd,         i dati delle zone, solo costanti: il terreno per vertici, le cose,
│   zone_tree_layout.gd,         le piante, i nemici, le entrate e le uscite; nel dungeon anche
│   zone_roots_layout.gd         stanze, piastre, cancelli, chiavi, porte e scatole
├── zone_layout.gd               le funzioni comuni per leggere i dati di una zona
├── zones.gd                     nome della zona -> scena (il salvataggio ricorda il nome)
├── forest_zone.gd               la zona quando parte: monta i pezzi qui sotto e li tiene insieme
│                                (notte, camera, OST, menu, dialoghi, obiettivo, uscite tra le zone).
│                                È la facciata: i pezzi e i test parlano con lei
├── zone_combat.gd               i nemici della zona, l'esperienza, il cuore, la morte e il
│                                risveglio, il segreto della decima morte
├── zone_dressing.gd             l'allestimento: luci e collisioni delle cose (dal JSON), raggi di
│                                luna, lucciole, le cose con cui si parla
├── zone_puzzles.gd              i meccanismi (piastre, cancelli, chiavi, porte, scatole, i rovi che
│                                il gesto Aprire scosta), ricordati nei flag della partita
├── zone_lanterns.gd             le lanterne di radice (si accendono con la luce della magia, o le
│                                accende Selene stancandosi) e le tende di radici (il gesto, poi la luna)
├── root_eye.gd                  un occhio nelle radici: al buio si apre e segue Lethe, la luce lo chiude;
│                                sta nella parete, sotto Lethe; si apre con un suono umido, sbatte
├── zone_light.gd                la luce di Lethe (gli MP): la magia la spende, torna piano da sola, in
│                                fretta vicino a una luce (lanterne, pozze di luna), tutta riposando,
│                                un po' a ogni verità
├── zone_ambience.gd             l'aria sottoterra: la polvere, le gocce che cadono (anello e plip con
│                                l'eco), le radici che scricchiolano e la terra che cade
└── forest_story.gd              la regia del capitolo: l'arrivo, Selene, il primo nemico, le battute,
                                 gli obiettivi passo passo, la discesa nel dungeon
characters/selene/selene.gd      Selene, la compagna: uno spicchio di luna che segue Lethe, fa luce
                                 e dice battute brevi sopra la testa (bark); si stanca quando fa luce
                                 al posto di Lethe (meno luce, colori più spenti, si salva)
enemies/
├── enemy.gd                     la base dei nemici: vita, debolezze (spada/magia), il lampo bianco e
│                                la spinta quando li colpisci, la morte che si scioglie in ombra, il
│                                danno a Lethe quando la toccano
├── shadow_moth.gd               la falena d'ombra: gira intorno a Lethe, si ferma (si sente) e si
│                                butta; va alla luce della magia. Debole alla magia
├── whispering_bramble.gd        il rovo che sussurra: fermo, sussurra una bugia di Lethe (si legge
│                                sopra), trema e frusta lontano. Debole alla spada, blocca il passo
├── false_firefly.gd             la lucciola falsa: sembra una lucciola, da vicino si apre (denti,
│                                luce rossa) e insegue; poi torna a fare la lucciola
├── sprites/                     i fogli (dal generatore in locale). Anteprima: ../docs/nemici.png
│                                (tutti: numeri del danno, barretta della vita sopra, un attimo
│                                scomposti dopo un colpo, luce che vola a Lethe come esperienza)
items/pickup.gd                  un oggetto per terra (la mela che lascia un nemico): galleggia, luccica,
                                 si prende passandoci sopra e dopo un po' sparisce; la chiave invece
                                 si raccoglie parlandoci e aspetta
fx/damage_number.gd              il numero del danno: rosa sul punto debole, grigio se l'arma fa poco
fx/emote.gd                      la nuvoletta sopra la testa: "!", "?", "...", un cuoricino
fx/fireflies.gd                  le lucciole del bosco (blend additivo, blocchi di 2 pixel)
fx/fire.gd                       un fuoco piccolo e vivo (le lanterne): la fiamma a blocchi in 4
                                 fotogrammi mai nello stesso ordine, le braci, il crepitio vicino; la
                                 vampata quando prende
fx/world_grey.gd                 il mondo che si svuota: con più bugie che verità i colori vanno al
                                 grigio, restano solo i rossi
prologue/
├── prologue.gd                  il regista del prologo nella stanza: il risveglio dopo la cutscene
│                                (gli occhi che si aprono, un respiro, "Night."), lo specchio che
│                                chiama quando chi bussava se n'è andato e Lethe ha guardato 5 cose
│                                (la musica della stanza si spegne, parte quella dello specchio),
│                                "Not yet." che lo fa brillare di più, e la caduta. In alto
│                                l'obiettivo: "Look around the room (n/5)", poi la porta, poi lo
│                                specchio (guardato tutto, bussano subito). Tutto nei flag
│                                della partita, così si salva
├── mirror_glow.gd               l'angolo scoperto dello specchio acceso: vetro che pulsa, luce
│                                fredda, scintille che salgono, ronzio di vetro, le crepe
└── mirror_fall.gd               la caduta: il lenzuolo, lo specchio che cede, Lethe tirata nel
                                 vetro, le schegge che volano su, la scheggia nel buio (la spada
                                 arriva qui), il cartello CHAPTER 1 / THE FOREST, poi la foresta
ui/
├── item_icons.gd                le icone degli oggetti (items/, 32x32) e i loro dati: cibo che cura,
│                                luce per la magia, l'acqua del Lete, potenziamenti, cose da
│                                raccogliere, chiavi, accessori. Anteprima: ../docs/oggetti.png
├── heart_hud.gd                 il riquadro in basso a sinistra: il cuore che una mano stringe a ogni
│                                colpo (heart_hud.png, 5 stadi), i cuoricini, il livello e la barra
│                                dell'esperienza; il battito più veloce con poco cuore, con l'ultimo
│                                pezzo i bordi scuri. Si nasconde durante i dialoghi. Sopra i cuori
│                                la luce (gli MP, light_row.gd)
├── light_row.gd                 la luce di Lethe: una fila di lune che si spengono con la magia e
│                                tornano con un lampo; trema se la luce non basta
├── objective_banner.gd          l'obiettivo in alto a sinistra (cosa fare adesso, in una riga), col
│                                cuore che batte; cambia scivolando, il numero si accende
├── heart_menu.gd                una lista di voci (Button veri: tastiera, gamepad, mouse): davanti
│                                alla voce scelta batte un cuore. La usano il titolo e il menu di pausa
├── screen_text.gd               le scritte e i neri dello schermo in un posto solo: scritta centrata,
│                                nero per le sfumature, toast in alto, "+3 EXP" che sale
└── fonts/                       Kenney Pixel (CC0)
main.tscn / main.gd              stanza al buio (CanvasModulate) + protagonista + OST
audio/stanza_theme.wav           l'OST della stanza: loop lo-fi di 25 s (dal generatore, senza stacchi)
audio/mirror_theme.wav           l'OST dello specchio: la melodia del titolo, lenta, su un'armonica di
                                 vetro, con un tappeto che luccica (loop di 53 s)
audio/heart_*.wav, enemy_*.wav, moth_*.wav, bramble_*.wav, firefly_bite.wav
                                 i suoni del combattimento: il cuore stretto, il battito, il cuore
                                 che si spezza, i nemici colpiti e che si sciolgono, le ali, il
                                 sussurro e la frusta del rovo, il morso della lucciola
audio/door_creak.wav, roots_retract.wav, stone_click.wav
                                 i meccanismi: la porta che si apre dopo tanto, le radici che si
                                 ritirano, la pietra che affonda
audio/roots_theme.wav            l'OST del dungeon: bordone sotto terra, il battito del cuore delle
                                 radici, gocce nel buio, il lamento del titolo su un vetro lontano
audio/forest_theme.wav           l'OST della foresta: Re dorico, arpa pizzicata, il motivo del titolo
                                 al flauto, grilli, vento e un gufo lontano (loop di 48 s)
audio/mirror_hum.wav, sheet_rustle.wav, mirror_break.wav, fall_whoosh.wav, shard_glint.wav,
wake_up.wav                      i suoni del prologo: il ronzio dello specchio, il lenzuolo, il vetro
                                 che cede (con il respiro all'indietro), la caduta, la scheggia, il
                                 risveglio
audio/title_theme.wav            l'OST del titolo: il lamento di un giullare, valzer lento in Re minore
                                 su un carillon stonato, con sonagli e un bordone col tritono (44 s, loop)
audio/ui_move.wav, ui_confirm.wav  i suoni del menu (lamelle di carillon)
audio/sword_slash.wav            il fendente: sibilo, vetro che stride, schegge
audio/menu_*.wav                 i suoni del menu di pausa: oggetti che fanno rumore da soli (la porta, il
                                 telefono, lo specchio, il carillon, l'orologio) e il "no" basso e scordato
                                 (dal generatore in locale)
audio/magic_*.wav                i suoni della magia: il luccichio della carica, il soffio del lancio,
                                 il rintocco di vetro dell'impatto
world/
├── room_tiles.png / .json       atlante dei tile e i suoi dati (dal generatore)
├── room_tileset.gd              costruisce il TileSet dal JSON, con le collisioni (anche per altri
│                                atlanti: "solid_cells" = solo quelle celle bloccano)
├── room_layout.gd               com'è arredata la stanza (solo dati)
├── room.gd                      dipinge i livelli (pavimento, muri, oggetti, mobili)
├── room_fx.gd                   luci, sfarfallio, schermo acceso, raggio di luna (dal JSON)
├── room_things.gd               le cose con cui si parla e quale c'è davanti a Lethe (solo logica)
├── forest/                      i tile della foresta del capitolo 1 (dal generatore in locale), 80:
│                                erba, bosco fitto, sentiero e Lete con l'autotile "a angoli" (bordi,
│                                angoli interni, diagonali: si dipingono col terreno nell'editor,
│                                forest_tileset.tres), ponti sul Lete, rovi che si aprono col gesto,
│                                alberi e abeti (bloccano solo al tronco), l'albero secco, rocce,
│                                funghi e fiori che fanno luce, lo specchio dove si salva, e il
│                                dungeon tra le radici. Anteprime: ../docs/foresta.png, foresta_radici.png
└── door_knock.gd                dopo un po' bussano alla porta: il colpo, la luce e due piedi sotto la
                                 porta. Se Lethe va ad aprire una voce le chiede se è sveglia;
                                 se no, dopo qualche colpo se ne vanno
dialogue/
├── stanza.dialogue              cosa dicono le cose della stanza (Dialogue Manager): un cue per
│                                oggetto, col nome del suo tile. Le scelte cambiano truth / lies
├── prologue.dialogue            il narratore del prologo: il risveglio, lo specchio che chiama
├── forest.dialogue              la foresta e il dungeon: le cose, Selene, i meccanismi (porte e
│                                scatole si aprono da qui, con le funzioni di zone_puzzles.gd)
├── dialogue_box.gd              il riquadro: testo a macchina da scrivere, il viso di Lethe quando
│                                pensa lei, le scelte col cuore, i suoni del carillon. Una riga
│                                col tag [#wrong] non va: si guasta tutta, il riquadro sobbalza,
│                                il carillon suona scordato
├── text_effects.gd, text_fx.gd  gli effetti sul testo per le righe che non vanno: [glitch] (le
│                                lettere diventano i segni del menu guasto), [shiver] (tremano a
│                                scatti di un pixel), [flicker] (si spengono). I conti in text_fx.gd
├── talk.gd                      l'iconcina sopra la testa di Lethe quando ha qualcosa davanti, apre il
│                                dialogo e ferma Lethe; conta le visite (seen("id") nei dialoghi).
│                                La prima volta accanto al fumetto c'è il tasto (E)
└── talk_icon.png                l'iconcina: un fumetto col cuore che batte (2 fotogrammi, blocchi 2x2)
addons/dialogue_manager/         Dialogue Manager 4.2.0 di Nathan Hoad (MIT), senza i file C#
fx/
├── flicker.gd                   sfarfallio di una luce: tremolio + cali improvvisi
├── screen_glow.gd               lo schermo del PC che tremola, con la riga di scansione
├── moon_beam.gd                 il raggio di luna dalla tenda, con il pulviscolo
├── sparks.gd                    scintille di magia (scia e scoppio), quadratini da 2 pixel
├── screen_shake.gd              un piccolo tremolio dello schermo all'impatto
├── drop_shadow.gd               l'ombra sotto i piedi, a blocchi di 2 pixel come gli sprite
├── screen_shatter.gd            lo schermo che si rompe (Quit, Game End): crepe a ragnatela,
│                                frammenti che cadono nel buio, la musica che muore come un nastro
└── mirror_shatter.gd            lo specchio che si rompe (la caduta): schegge lunghe quasi verticali
                                 che si girano a onda e volano su, strisce di luce che salgono
characters/protagonista/
├── facing.gd                    8 direzioni -> riga dello sheet + specchio (solo logica)
├── protagonista_frames.gd       animazioni dagli sheet (idle, walk, run, attack, slash x 5 direzioni)
├── protagonista.gd / .tscn      CharacterBody2D: movimento, corsa, magia e spada
└── sprites/                     gli sheet (idle, walk, run, attack, slash), vedi sotto
magic/
├── magic_frames.gd              animazioni di carica (8), proiettile (4), impatto (9), ognuna col suo ritmo
├── projectile.gd / .tscn        vola con una scia di scintille e una luce viola, esplode su muri e mobili
├── vigil.gd, vigil_flame.gd     la veglia, il secondo incantesimo: quattro fiammelle girano attorno a
│                                Lethe, poi partono una dopo l'altra verso i nemici vicini (o a ventaglio)
├── light_catch.gd               le luci della magia accendono le cose che prendono luce (le lanterne)
├── charge.tscn, impact.tscn     le scene della carica e dell'impatto (con one_shot_effect.gd)
└── one_shot_effect.gd           carica e impatto: luce (sale nella carica, si spegne nell'impatto),
                                 suono, scoppio di scintille e tremolio a scelta
weapon/
├── glass_sword.gd / .tscn       un fendente: lama che compare e luccica, scia di vetro, schegge, suono;
│                                colpisce il livello "nemici" mentre la lama passa
├── sword_frames.gd              il fendente in tre stadi (scheggia, pugnale, lama) x 6 fotogrammi
└── sprites/                     lo sheet della spada (dal generatore in locale)
menu/
├── pause_menu.gd / .tscn        il menu di pausa stile RPG Maker: tiene insieme i pezzi, sceglie la pagina
├── menu_page.gd                 la base delle pagine a lista (titolo, lista col cuore, aiuto, "no")
├── party_view.gd, hero_card.gd  la pagina del gruppo (solo Lethe) e la sua riga (ritratto, barre)
├── items_view.gd                gli oggetti della stanza (riguardati, cambiano descrizione)
├── spells_view.gd               gli incantesimi: quale va su Q
├── equip_view.gd                arma, corpo, accessorio, con l'anteprima dei parametri
├── status_view.gd               parametri, equipaggiamento, incantesimo, verità e bugie
├── lie_eyes.gd                  le bugie nello Stato: un filo spinato con gli occhi, uno aperto per bugia
├── save_view.gd, save_store.gd  i 3 file di salvataggio (JSON in user://saves; si scrive in un .tmp
│                                accanto e poi lo si sostituisce, così uno slot non resta mai a metà)
├── end_view.gd                  Game End: lo schermo si rompe e si torna al titolo
├── game_state.gd, equipment.gd  lo stato che si salva e i conti dei parametri (solo logica)
├── menu_data.gd                 tutti i testi e i numeri del menu (solo dati)
├── menu_style.gd, gauge.gd      tema, finestre, ritratti ritagliati dagli sheet, barre HP/MP
├── menu_glitcher.gd, glitch.gd  le scritte che si guastano per un attimo
├── menu_ambience.gd             gli oggetti della stanza che fanno rumore da soli, a menu aperto
├── menu_reactions.gd            il "no" sulle cose che non si possono, gli eventi dopo un salvataggio
└── menu_backdrop.gdshader       il gioco fermo dietro il menu: grigio, vignetta, righe, tremolio
core/
├── glow.gd                      luci morbide (PointLight2D a gradiente radiale)
├── music.gd                     musica in loop
├── sfx.gd                       suoni usa-e-getta (si liberano da soli, suonano anche in pausa)
├── cutscene.gd                  il regista delle cutscene: passi in fila con await (bande nere,
│                                camera, dialoghi, emote), così una scena si scrive come un copione
├── room_camera.gd               la camera per stanze dei dungeon: i limiti scivolano passando una porta
├── settings_store.gd            le cose da ricordare che non sono un salvataggio (l'avviso già letto)
└── input_setup.gd               crea le azioni di input se mancano (tastiera, mouse, gamepad)
tests/                           un file per modulo + mini runner headless (vedi ../appunti/)
tools/make_forest_tileset.gd     riscrive world/forest/forest_tileset.tres dal JSON (con l'autotile)
tools/make_forest_zone.gd        riscrive forest/zone_<nome>.tscn da zone_<nome>_layout.gd. Attenzione:
                                 sovrascrive i ritocchi fatti nell'editor, si lancia solo sulla zona
                                 che cambia

```

- **Luci**: la stanza è scurita da un `CanvasModulate`; schermo del PC, lampada, telefono e luna
  tra le tende hanno una `PointLight2D` che sfarfalla (lo schermo ha anche cali improvvisi, la
  lampada ogni tanto), e così il proiettile e l'impatto (viola).
- **Atmosfera**: lo schermo acceso tremola con una riga di scansione; dalla tenda scende un raggio
  di luna con il pulviscolo; l'OST lo-fi (piano elettrico, basso, batteria leggera, vinile) va in loop.
- **Protagonista**: disegnata sulla griglia 32x32 della sagoma e ingrandita a blocchi 2x2,
  senza dettagli a mezzo pixel: ha la stessa grana del pavimento. Sotto i piedi ha un'ombra
  scura e semitrasparente.
- **Stile dei tile**: come Lethe, una sola griglia a 16 px ingrandita a blocchi 2x2 (niente Scale2x
  né dettagli a mezzo pixel): contorno colorato, tre toni per materiale, riflessi, retinatura a scacchi.
- **Magia**: tre tempi, come nei campioni di incantesimi: la carica raccoglie scintille a spirale
  sulle mani (la luce sale, un luccichio sempre più acuto), il colpo parte con un lampo e un soffio e
  lascia una scia; all'impatto un lampo bianco, un anello che si allarga e si spezza in archi, uno
  scoppio di scintille, un piccolo tremolio e un rintocco di vetro. Sprite sulla griglia di Lethe,
  blend additivo (`CanvasItemMaterial` -> Add) per brillare.
- **Una stanza che racconta**: niente doppioni, solo oggetti che sono uno strato della storia (vedi
  il vault, "La stanza di Lethe"): lo specchio coperto da un lenzuolo, il calendario barrato fino a un
  giorno cerchiato, il vassoio intatto davanti alla porta, la foto a faccia in giù sul comodino, le
  palline di carta accanto alla scrivania, la pianta secca sotto la finestra.
- **Spada di vetro**: fatta del vetro dello specchio coperto (vedi il vault, "La spada di vetro"):
  ogni bugia ne stacca una scheggia, e la lama cresce in tre stadi. Lethe usa la posa d'attacco con
  la scia del braccio in vetro azzurro (la magia viola è la verità, la spada no).
- **All'inizio a mani vuote**: Lethe non sa incantesimi e non ha la spada (arrivano nella
  foresta, vedi il vault, "Trama - bozza"): nella stanza magia e spada non fanno niente, e nel
  menu incantesimi ed equipaggiamento non ancora trovati sono "???". Addosso ha solo il vestito.
  Lo stato della partita sa cosa ha imparato e trovato (`learn`, `give`) e lo salva.
- **Menu di pausa**: come in RPG Maker, con il cuore del titolo come cursore. Oggetti, incantesimi
  (quale parte con Q), equipaggiamento con l'anteprima dei parametri, stato, salvataggi.
  In fondo una barra d'aiuto dice cosa fa quello che si guarda e quali tasti usare. Per ora
  parametri, armi diverse dalla spada e incantesimi scelti si vedono solo nel menu: il
  combattimento non li usa ancora. E qualcosa non va: il gioco dietro si fa grigio e trema, la
  musica rallenta e stona, le scritte si guastano per un attimo (mai l'aiuto), lo stato a volte
  legge "Dead", Lethe a volte è di spalle, gli oggetti riguardati cambiano descrizione, e il
  File 3 non è suo. Ogni tanto gli oggetti della stanza fanno rumore da soli:
  bussano alla porta, il telefono vibra, lo specchio si incrina, il carillon suona, l'orologio si ferma. Scegliere una cosa
  che non si può (un incantesimo non imparato, usare un oggetto, uno slot vuoto) dà un "no" basso:
  la voce si fa rossa, la finestra sobbalza, a volte compare "STOP.". Dopo un salvataggio, a volte,
  succede qualcosa: bussano, il file per un attimo è di qualcun altro, "She saw you save.".
  Game End rompe lo schermo come il Quit del titolo.
- **Profondità**: il livello dei mobili è ordinato per Y insieme alla protagonista, che passa
  davanti o dietro a seconda di dove sta.

## Sprite della protagonista

Gli sheet in `characters/protagonista/sprites/` sono Lethe ridisegnata sopra il
[Character Templates Pack di Eris Esra](https://erisesra.itch.io/character-templates-pack). La
licenza permette di usare i template nei giochi, commerciali e non; nei progetti gratuiti chiede
di citare l'autrice con il link al template (fatto qui e nei crediti). Non permette di rivenderli,
nemmeno modificati, né di usarli per asset pack o commissioni: questi sprite sono parte del gioco,
non un pacchetto a sé.

Il tileset, gli effetti magici e la spada invece sono disegnati da zero (generatori in locale).
