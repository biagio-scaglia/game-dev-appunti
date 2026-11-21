# intro-studio

Progetto Godot 4.7 che contiene l'intro dello studio di Biagio Scaglia, pronta da copiare nei giochi.
Tutti i dettagli sull'intro sono in [studio_intro/README.md](studio_intro/README.md).

## Comandi

Con `GODOT` = percorso dell'eseguibile di Godot 4.7:

```sh
# Avviare l'intro (poi una scena segnaposto: Invio la rilancia)
$GODOT --path .

# Test (headless, esce con 1 se un test fallisce)
$GODOT --headless --path . -s res://tests/run_tests.gd

# Rigenerare sprite, suoni e musica (Python 3 + Pillow; gli script sono solo in locale)
python tools/make_assets.py

# Salvare fotogrammi dell'intro per controllarla a occhio
$GODOT --path . -s res://tools/capture_frames.gd -- <cartella>
```

## Cartelle

- `studio_intro/`: l'intro (è la cartella da copiare nei giochi)
- `demo/`: la scena segnaposto che parte dopo l'intro
- `tests/`: i test, un file per modulo, più un mini runner senza addon
- `tools/`: la cattura dei fotogrammi; i generatori degli asset in Python stanno qui solo in locale
