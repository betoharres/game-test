extends Node3D

const DEFAULT_ADDRESS := "127.0.0.1"
const DEFAULT_PORT := 7000
const MAX_PLAYERS := 4
const MAX_REMOTE_CLIENTS := MAX_PLAYERS - 1
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const AMBIENT_BASE_VOLUME_DB := -25.0
const AMBIENT_VOLUME_VARIATION_DB := 1.0
const AMBIENT_PITCH_VARIATION := 0.01
const AMBIENT_VARIATION_DURATION := 6.0
const DISTANT_SOUND_STREAMS: Array[AudioStream] = [
	preload("res://sounds/random-distant-sounds/long-airplane-flying-over-1578.wav"),
	preload("res://sounds/random-distant-sounds/bathroom-sink-drain-1873.wav"),
	preload("res://sounds/random-distant-sounds/creaking-public-toilet-door-203.wav"),
	preload("res://sounds/random-distant-sounds/creature-sobbing-in-fear-464.wav"),
	preload("res://sounds/random-distant-sounds/lost-kid-sobbing-474.wav"),
	preload("res://sounds/random-distant-sounds/woman-sadmoan-33954.mp3"),
	preload("res://sounds/random-distant-sounds/hot-ooh-68892.mp3"),
]
const DISTANT_SOUND_VOLUMES_DB: Array[float] = [-11.0, 3.0, -13.0, -10.0, -10.0, -10.0, -8.0]
const DISTANT_SOUND_MIN_DELAY := 12.0
const DISTANT_SOUND_MAX_DELAY := 30.0
const DISTANT_SOUND_MIN_DISTANCE := 20.0
const DISTANT_SOUND_MAX_DISTANCE := 32.0
const DISTANT_SOUND_LOOK_UP_VOLUME_MULTIPLIER := 1.7
const STAMINA_FADE_DURATION := 0.5
const SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-3.0, 0.05, 6.0),
	Vector3(3.0, 0.05, 6.0),
	Vector3(-3.0, 0.05, 3.0),
	Vector3(3.0, 0.05, 3.0),
]

@export_group("Audio")
@export_range(-60.0, 0.0, 0.5) var recorder_noise_volume_db: float = -16.0

@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var ambient_sound: AudioStreamPlayer = $AmbientSound
@onready var recorder_noise: AudioStreamPlayer = $RecorderNoise
@onready var ambient_variation_timer: Timer = $AmbientVariationTimer
@onready var distant_sound: AudioStreamPlayer3D = $DistantSound
@onready var distant_sound_timer: Timer = $DistantSoundTimer
@onready var backrooms: MeshInstance3D = $Backrooms
@onready var level_collision_shape: CollisionShape3D = $Backrooms/WallCollision/CollisionShape3D
@onready var stamina_bar: ProgressBar = $HUD/StaminaDisplay/StaminaBar
@onready var sound_meter: SoundMeter = $HUD/SoundMeter
@onready var startup_black_screen: ColorRect = $StartupBlackout/BlackScreen

var _spawn_slots: Dictionary[int, int] = {}
var _ambient_rng := RandomNumberGenerator.new()
var _distant_sound_rng := RandomNumberGenerator.new()
var _last_distant_sound_index := -1
var _current_distant_sound_volume_db := 0.0
var _stamina_fade_tween: Tween


func _ready() -> void:
	_setup_level_collision()
	player_spawner.spawn_function = _create_player
	players.child_entered_tree.connect(_on_player_spawned)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_startup_blackout_finished() -> void:
	startup_black_screen.hide()
	_setup_ambient_sound()
	_setup_recorder_noise()
	_setup_distant_sounds()

	var options := _parse_startup_options()
	if not options["error"].is_empty():
		push_error("[Multiplayer] %s" % options["error"])
		return

	match options["mode"]:
		"host":
			_start_host(options["port"])
		"join":
			_start_client(options["address"], options["port"])
		_:
			_start_offline()


func _process(_delta: float) -> void:
	if not distant_sound.playing:
		return

	var local_player := _get_local_player()
	if local_player == null:
		return

	var camera := local_player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return

	var look_up_amount := clampf(-camera.global_basis.z.y, 0.0, 1.0)
	var volume_multiplier := lerpf(
		1.0,
		DISTANT_SOUND_LOOK_UP_VOLUME_MULTIPLIER,
		look_up_amount
	)
	distant_sound.volume_db = _current_distant_sound_volume_db + linear_to_db(volume_multiplier)


func _setup_level_collision() -> void:
	var collision_faces := PackedVector3Array()
	for surface_index in backrooms.mesh.get_surface_count():
		var surface_name: String = backrooms.mesh.surface_get_name(surface_index)
		if not surface_name.begins_with("Wall_") and not surface_name.begins_with("Ceiling_"):
			continue

		var arrays := backrooms.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for vertex_index in indices:
			collision_faces.append(vertices[vertex_index])

	if collision_faces.is_empty():
		push_error("Could not find wall or ceiling surfaces in the Backrooms mesh.")
		return

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision_faces)
	level_collision_shape.shape = shape


func _setup_ambient_sound() -> void:
	var ambient_stream := ambient_sound.stream as AudioStreamMP3
	ambient_stream.loop = true
	ambient_sound.volume_db = AMBIENT_BASE_VOLUME_DB
	if DisplayServer.get_name() == "headless":
		return

	ambient_sound.play()
	_ambient_rng.randomize()
	ambient_variation_timer.timeout.connect(_vary_ambient_sound)
	ambient_variation_timer.start()


func _setup_recorder_noise() -> void:
	var recorder_stream := recorder_noise.stream.duplicate() as AudioStreamOggVorbis
	recorder_stream.loop = true
	recorder_noise.stream = recorder_stream
	recorder_noise.volume_db = recorder_noise_volume_db
	if DisplayServer.get_name() == "headless":
		return

	recorder_noise.play()


func _vary_ambient_sound() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(
		ambient_sound,
		"volume_db",
		AMBIENT_BASE_VOLUME_DB + _ambient_rng.randf_range(
			-AMBIENT_VOLUME_VARIATION_DB,
			AMBIENT_VOLUME_VARIATION_DB
		),
		AMBIENT_VARIATION_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		ambient_sound,
		"pitch_scale",
		_ambient_rng.randf_range(1.0 - AMBIENT_PITCH_VARIATION, 1.0 + AMBIENT_PITCH_VARIATION),
		AMBIENT_VARIATION_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_distant_sounds() -> void:
	if DisplayServer.get_name() == "headless":
		return

	_distant_sound_rng.randomize()
	distant_sound.finished.connect(_schedule_distant_sound)
	distant_sound_timer.timeout.connect(_play_distant_sound)
	distant_sound_timer.start(_distant_sound_rng.randf_range(6.0, 16.0))


func _play_distant_sound() -> void:
	var local_player := _get_local_player()
	if local_player == null:
		distant_sound_timer.start(1.0)
		return

	var sound_index := _distant_sound_rng.randi_range(0, DISTANT_SOUND_STREAMS.size() - 1)
	if sound_index == _last_distant_sound_index:
		sound_index = (sound_index + _distant_sound_rng.randi_range(
			1,
			DISTANT_SOUND_STREAMS.size() - 1
		)) % DISTANT_SOUND_STREAMS.size()
	_last_distant_sound_index = sound_index

	var angle := _distant_sound_rng.randf_range(0.0, TAU)
	var distance := _distant_sound_rng.randf_range(
		DISTANT_SOUND_MIN_DISTANCE,
		DISTANT_SOUND_MAX_DISTANCE
	)
	distant_sound.global_position = local_player.global_position + Vector3(
		cos(angle) * distance,
		_distant_sound_rng.randf_range(2.0, 6.0),
		sin(angle) * distance
	)
	distant_sound.stream = DISTANT_SOUND_STREAMS[sound_index]
	_current_distant_sound_volume_db = DISTANT_SOUND_VOLUMES_DB[sound_index]
	distant_sound.volume_db = _current_distant_sound_volume_db
	distant_sound.pitch_scale = _distant_sound_rng.randf_range(0.97, 1.03)
	distant_sound.play()


func _schedule_distant_sound() -> void:
	distant_sound_timer.start(_distant_sound_rng.randf_range(
		DISTANT_SOUND_MIN_DELAY,
		DISTANT_SOUND_MAX_DELAY
	))


func _get_local_player() -> Node3D:
	for player in players.get_children():
		if player.is_multiplayer_authority():
			return player as Node3D
	return null


func _exit_tree() -> void:
	ambient_variation_timer.stop()
	ambient_sound.stop()
	ambient_sound.stream = null
	recorder_noise.stop()
	recorder_noise.stream = null
	distant_sound_timer.stop()
	distant_sound.stop()
	distant_sound.stream = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var peer := multiplayer.multiplayer_peer
	if peer != null and not peer is OfflineMultiplayerPeer:
		peer.close()


func _parse_startup_options() -> Dictionary:
	var host_requested := false
	var join_address := ""
	var port := DEFAULT_PORT
	var error_message := ""

	for argument in OS.get_cmdline_user_args():
		if argument == "--host":
			host_requested = true
		elif argument.begins_with("--join="):
			join_address = argument.substr("--join=".length()).strip_edges()
			if join_address.is_empty():
				error_message = "--join requires a non-empty address."
		elif argument == "--join":
			error_message = "--join requires an address, for example --join=127.0.0.1."
		elif argument.begins_with("--port="):
			var port_value := argument.substr("--port=".length())
			if not port_value.is_valid_int():
				error_message = "--port must be an integer between 1 and 65535."
			else:
				port = port_value.to_int()
				if port < 1 or port > 65535:
					error_message = "--port must be between 1 and 65535."
		elif argument == "--port":
			error_message = "--port requires a value, for example --port=7000."
		else:
			error_message = "Unknown startup argument: %s" % argument

	if host_requested and not join_address.is_empty():
		error_message = "--host and --join cannot be used together."

	var mode := "offline"
	if host_requested:
		mode = "host"
	elif not join_address.is_empty():
		mode = "join"

	return {
		"mode": mode,
		"address": join_address if not join_address.is_empty() else DEFAULT_ADDRESS,
		"port": port,
		"error": error_message,
	}


func _start_offline() -> void:
	var player := _create_player({"peer_id": 1, "spawn_index": 0})
	players.add_child(player)
	print("[Multiplayer] Offline mode")


func _start_host(port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_REMOTE_CLIENTS)
	if error != OK:
		push_error("[Multiplayer] Could not host on UDP port %d: %s" % [port, error_string(error)])
		return

	multiplayer.multiplayer_peer = peer
	_spawn_network_player(multiplayer.get_unique_id())
	print("[Multiplayer] Hosting on UDP port %d with peer ID %d" % [port, multiplayer.get_unique_id()])


func _start_client(address: String, port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		push_error("[Multiplayer] Could not connect to %s:%d: %s" % [address, port, error_string(error)])
		return

	multiplayer.multiplayer_peer = peer
	print("[Multiplayer] Connecting to %s:%d" % [address, port])


func _spawn_network_player(peer_id: int) -> void:
	if _spawn_slots.has(peer_id):
		return

	var spawn_index := _get_open_spawn_index()
	if spawn_index == -1:
		push_error("[Multiplayer] No spawn slot is available for peer %d." % peer_id)
		return

	var player := player_spawner.spawn({"peer_id": peer_id, "spawn_index": spawn_index})
	if player == null:
		push_error("[Multiplayer] Could not spawn a Player for peer %d." % peer_id)


func _create_player(data: Dictionary) -> Node:
	var peer_id: int = data["peer_id"]
	var spawn_index: int = data["spawn_index"]
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = str(peer_id)
	player.position = SPAWN_POSITIONS[spawn_index]
	player.set_multiplayer_authority(peer_id, true)
	_spawn_slots[peer_id] = spawn_index
	return player


func _get_open_spawn_index() -> int:
	for spawn_index in SPAWN_POSITIONS.size():
		if not _spawn_slots.values().has(spawn_index):
			return spawn_index
	return -1


func _on_peer_connected(peer_id: int) -> void:
	print("[Multiplayer] Peer %d connected" % peer_id)
	if multiplayer.is_server():
		_spawn_network_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_spawn_slots.erase(peer_id)
	print("[Multiplayer] Peer %d disconnected; active players: %d/%d" % [peer_id, _spawn_slots.size(), MAX_PLAYERS])
	if not multiplayer.is_server():
		return

	var player := players.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()


func _on_connected_to_server() -> void:
	print("[Multiplayer] Connected with peer ID %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	push_error("[Multiplayer] Connection failed.")
	_reset_client_session()


func _on_server_disconnected() -> void:
	push_warning("[Multiplayer] Server disconnected.")
	_reset_client_session()


func _reset_client_session() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_stop_stamina_fade()
	stamina_bar.visible = false
	sound_meter.set_sound_radius(0.0, 1.0)
	_spawn_slots.clear()
	for player in players.get_children():
		player.queue_free()


func _on_player_spawned(player: Node) -> void:
	print("[Multiplayer] Player %s spawned; active players: %d/%d" % [player.name, players.get_child_count(), MAX_PLAYERS])
	var controller := player as FirstPersonController
	if controller == null or not controller.is_multiplayer_authority():
		return

	controller.stamina_changed.connect(_on_stamina_changed)
	controller.sound_radius_changed.connect(_on_sound_radius_changed)
	if controller.is_node_ready():
		_on_stamina_changed(controller.stamina, controller.sprint_duration)
		_on_sound_radius_changed(
			controller.current_sound_radius,
			controller.get_max_sound_radius()
		)


func _on_stamina_changed(current_stamina: float, maximum_stamina: float) -> void:
	_stop_stamina_fade()
	stamina_bar.max_value = maximum_stamina
	stamina_bar.value = current_stamina
	stamina_bar.visible = true
	stamina_bar.modulate.a = 1.0

	if is_equal_approx(current_stamina, maximum_stamina):
		_stamina_fade_tween = create_tween()
		_stamina_fade_tween.tween_property(
			stamina_bar,
			"modulate:a",
			0.0,
			STAMINA_FADE_DURATION
		)
		_stamina_fade_tween.tween_callback(stamina_bar.hide)


func _stop_stamina_fade() -> void:
	if _stamina_fade_tween != null and _stamina_fade_tween.is_valid():
		_stamina_fade_tween.kill()
	_stamina_fade_tween = null


func _on_sound_radius_changed(current_radius: float, maximum_radius: float) -> void:
	sound_meter.set_sound_radius(current_radius, maximum_radius)
