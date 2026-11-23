extends RefCounted
## Suoni usa-e-getta: un AudioStreamPlayer che suona una volta e poi si libera da solo.


static func play(parent: Node, stream: AudioStream, pitch := 1.0, db := 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = db
	player.process_mode = Node.PROCESS_MODE_ALWAYS   # suona anche a gioco in pausa
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
	return player
