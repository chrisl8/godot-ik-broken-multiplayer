extends Node


func log_print(text: String, color: String = "white") -> void:
	if Globals.is_server or OS.is_debug_build():
		var unique_id: int = -1
		if multiplayer.has_multiplayer_peer():
			unique_id = multiplayer.get_unique_id()
		print_rich(
			"[color=",
			color,
			"]",
			Globals.local_debug_instance_number,
			" ",
			unique_id,
			" ",
			text,
			"[/color]"
		)


func quit_gracefully() -> void:
	# Quitting in Web just stops the game but leaves it stalled in the browser window, so it really should never happen.
	if !Globals.shutdown_in_progress and OS.get_name() != "Web":
		Globals.shutdown_in_progress = true
		if Globals.is_server:
			print_rich(
				"[color=orange]Disconnecting clients and saving data before shutting down server...[/color]"
			)
			Network.shutdown_server()
			while Network.peers.size() > 0:
				print_rich("[color=orange]...server still clearing clients...[/color]")
				await get_tree().create_timer(1).timeout
		get_tree().quit()
