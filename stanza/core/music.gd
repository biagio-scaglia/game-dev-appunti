extends RefCounted
## Musica in loop: imposta il loop sul WAV (dall'inizio alla fine, il brano è già
## scritto per ripartire senza stacchi) e lo fa partire, sul canale della musica (così il
## volume della musica nelle impostazioni la regola da sola).

const Settings := preload("res://core/settings_store.gd")


static func play_loop(player: AudioStreamPlayer) -> void:
	var stream := player.stream as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	Settings.ensure_buses()
	player.bus = Settings.MUSIC_BUS
	player.play()
