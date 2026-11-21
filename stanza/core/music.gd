extends RefCounted
## Musica in loop: imposta il loop sul WAV (dall'inizio alla fine, il brano è già
## scritto per ripartire senza stacchi) e lo fa partire.


static func play_loop(player: AudioStreamPlayer) -> void:
	var stream := player.stream as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.play()
