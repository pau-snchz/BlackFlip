extends AudioStreamPlayer

func play_music():
	if not playing:
		play()

func stop_music():
	if playing:
		stop()
