extends Node

const MAIN_MENU_CLICK := preload("res://assets/audio/703884__lilmati__diamond-click-luxury-ui-click.wav")
const BUTTON_CLICK := preload("res://assets/audio/677861__el_boss__ui-button-click.wav")
const CAT_PURR := preload("res://assets/audio/cat-purr.wav")
const SPELL_SHOOT := preload("res://assets/audio/500909__bertsz__spell-shoot-2.wav")
const BORIS_REPAIR := preload("res://assets/audio/724416__paulprit__cleat-knotting-on-boat.wav")
const TASK_COMPLETE := preload("res://assets/audio/task_complete.wav")
const MAIN_MENU_MUSIC := preload("res://assets/audio/The_Archivist_s_Ledger.mp3")
const OFFICE_MUSIC := preload("res://assets/audio/Clockwork_Correspondence.mp3")
const JOB_MUSIC := preload("res://assets/audio/The_Investigators_Ledger.mp3")
const COMPLAINT := preload("res://assets/audio/complaint.wav")
const BREAKING_WOOD := preload("res://assets/audio/breaking-pieces.wav")
const HEAVY_IMPACT := preload("res://assets/audio/udar.wav")
const WARDROBE_MOVE := preload("res://assets/audio/dvagaetskaf.wav")
const TRAP_INSTALL := preload("res://assets/audio/reitanna__drop-metal-thing.wav")
const GHOST_FLIGHT := preload("res://assets/audio/ghost.ogg")
const GHOST_TRAP := preload("res://assets/audio/lovuska.wav")
const GLASS_DEBRIS := preload("res://assets/audio/glass-debris.wav")
const MIRROR_SHATTER := preload("res://assets/audio/glass-shatter-5.wav")
const PORTAL_CLOSE := preload("res://assets/audio/magic-whoosh.wav")
const GHOST_SCREAM := preload("res://assets/audio/ghost-scream.mp3")
const STEPS := preload("res://assets/audio/steps.wav")
const RUNNING_WATER := preload("res://assets/audio/water.ogg")
const RAIN := preload("res://assets/audio/rain.ogg")
const GARGOYLE_WAKE := preload("res://assets/audio/rubble-trouble-wet-reverb.wav")
const LAVA_FLOW := preload("res://assets/audio/lava.ogg")

const CAT_SOUND_META := &"cat_purr_sound"
const MUSIC_FADE_SECONDS := 2.0
const MUSIC_SILENCE_DB := -40.0
const MUSIC_VOLUME_DB := -6.0206 # 50% линейной громкости.

var main_menu_player: AudioStreamPlayer
var button_player: AudioStreamPlayer
var cat_player: AudioStreamPlayer
var spell_player: AudioStreamPlayer
var boris_repair_player: AudioStreamPlayer
var task_complete_player: AudioStreamPlayer
var main_menu_music_player: AudioStreamPlayer
var office_music_player: AudioStreamPlayer
var job_music_player: AudioStreamPlayer
var complaint_player: AudioStreamPlayer
var breaking_wood_player: AudioStreamPlayer
var heavy_impact_player: AudioStreamPlayer
var wardrobe_move_player: AudioStreamPlayer
var trap_install_player: AudioStreamPlayer
var ghost_flight_player: AudioStreamPlayer
var ghost_trap_player: AudioStreamPlayer
var glass_debris_player: AudioStreamPlayer
var mirror_shatter_player: AudioStreamPlayer
var portal_close_player: AudioStreamPlayer
var ghost_scream_player: AudioStreamPlayer
var steps_player: AudioStreamPlayer
var running_water_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var gargoyle_wake_player: AudioStreamPlayer
var lava_flow_player: AudioStreamPlayer
var music_fades: Dictionary = {}


func _ready() -> void:
	# Фоновая музыка и интерфейсные звуки продолжают работать поверх меню паузы.
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_menu_player = _create_player(MAIN_MENU_CLICK)
	button_player = _create_player(BUTTON_CLICK)
	cat_player = _create_player(CAT_PURR, linear_to_db(0.3))
	spell_player = _create_player(SPELL_SHOOT)
	boris_repair_player = _create_player(BORIS_REPAIR)
	task_complete_player = _create_player(TASK_COMPLETE, linear_to_db(0.7))
	var looping_music := MAIN_MENU_MUSIC.duplicate() as AudioStreamMP3
	looping_music.loop = true
	main_menu_music_player = _create_player(looping_music)
	var looping_office_music := OFFICE_MUSIC.duplicate() as AudioStreamMP3
	looping_office_music.loop = true
	office_music_player = _create_player(looping_office_music)
	var looping_job_music := JOB_MUSIC.duplicate() as AudioStreamMP3
	looping_job_music.loop = true
	job_music_player = _create_player(looping_job_music)
	complaint_player = _create_player(COMPLAINT)
	breaking_wood_player = _create_player(BREAKING_WOOD)
	heavy_impact_player = _create_player(HEAVY_IMPACT)
	wardrobe_move_player = _create_player(WARDROBE_MOVE)
	trap_install_player = _create_player(TRAP_INSTALL)
	ghost_flight_player = _create_player(_looped_stream(GHOST_FLIGHT), linear_to_db(0.5))
	ghost_trap_player = _create_player(GHOST_TRAP)
	glass_debris_player = _create_player(GLASS_DEBRIS)
	mirror_shatter_player = _create_player(MIRROR_SHATTER)
	portal_close_player = _create_player(PORTAL_CLOSE)
	ghost_scream_player = _create_player(GHOST_SCREAM)
	steps_player = _create_player(STEPS)
	running_water_player = _create_player(_looped_stream(RUNNING_WATER), linear_to_db(0.5))
	rain_player = _create_player(_looped_stream(RAIN), linear_to_db(0.5))
	gargoyle_wake_player = _create_player(GARGOYLE_WAKE)
	lava_flow_player = _create_player(_looped_stream(LAVA_FLOW), linear_to_db(0.5))
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_in(get_tree().root)


func play_spell() -> void:
	spell_player.play()


func play_boris_repair() -> void:
	boris_repair_player.play()


func play_task_complete() -> void:
	task_complete_player.play()


func play_main_menu_music() -> void:
	_fade_music_in(main_menu_music_player)


func stop_main_menu_music() -> void:
	_fade_music_out(main_menu_music_player)


func play_office_music() -> void:
	_fade_music_in(office_music_player)


func stop_office_music() -> void:
	_fade_music_out(office_music_player)


func play_job_music() -> void:
	_fade_music_in(job_music_player)


func stop_job_music() -> void:
	_fade_music_out(job_music_player)


func play_complaint() -> void:
	complaint_player.play()


func play_breaking_wood() -> void:
	breaking_wood_player.play()


func play_heavy_impact() -> void:
	heavy_impact_player.play()


func play_wardrobe_move() -> void:
	wardrobe_move_player.play()


func play_trap_install() -> void:
	trap_install_player.play()


func play_ghost_trap() -> void:
	ghost_trap_player.play()


func play_glass_debris() -> void:
	glass_debris_player.play()


func play_mirror_shatter() -> void:
	mirror_shatter_player.play()


func play_portal_close() -> void:
	portal_close_player.play()


func play_ghost_scream() -> void:
	ghost_scream_player.play()


func play_steps() -> void:
	steps_player.play()


func play_gargoyle_wake() -> void:
	gargoyle_wake_player.play()


func set_ghost_flight_playing(enabled: bool) -> void:
	_set_loop_playing(ghost_flight_player, enabled)


func set_running_water_playing(enabled: bool) -> void:
	_set_loop_playing(running_water_player, enabled)


func set_rain_playing(enabled: bool) -> void:
	_set_loop_playing(rain_player, enabled)


func set_lava_flow_playing(enabled: bool) -> void:
	_set_loop_playing(lava_flow_player, enabled)


func _fade_music_in(player: AudioStreamPlayer) -> void:
	var fade := _start_music_fade(player)
	if not player.playing:
		player.volume_db = MUSIC_SILENCE_DB
		player.play()
	fade.tween_property(player, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.finished.connect(_clear_music_fade.bind(player, fade))


func _fade_music_out(player: AudioStreamPlayer) -> void:
	if not player.playing:
		return
	var fade := _start_music_fade(player)
	fade.tween_property(player, "volume_db", MUSIC_SILENCE_DB, MUSIC_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.finished.connect(_finish_music_fade_out.bind(player, fade))


func _start_music_fade(player: AudioStreamPlayer) -> Tween:
	var previous: Tween = music_fades.get(player) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	var fade := create_tween()
	music_fades[player] = fade
	return fade


func _clear_music_fade(player: AudioStreamPlayer, fade: Tween) -> void:
	if music_fades.get(player) == fade:
		music_fades.erase(player)


func _finish_music_fade_out(player: AudioStreamPlayer, fade: Tween) -> void:
	if music_fades.get(player) != fade:
		return
	player.stop()
	player.volume_db = MUSIC_SILENCE_DB
	music_fades.erase(player)


func _create_player(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_polyphony = 4
	add_child(player)
	return player


func _looped_stream(stream: AudioStream) -> AudioStream:
	var looped := stream.duplicate()
	if looped is AudioStreamWAV:
		(looped as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif looped is AudioStreamMP3:
		(looped as AudioStreamMP3).loop = true
	elif looped is AudioStreamOggVorbis:
		(looped as AudioStreamOggVorbis).loop = true
	return looped


func _set_loop_playing(player: AudioStreamPlayer, enabled: bool) -> void:
	if enabled:
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()


func _on_node_added(node: Node) -> void:
	if node is Button:
		_connect_button.call_deferred(node as Button)


func _connect_buttons_in(node: Node) -> void:
	if node is Button:
		_connect_button(node as Button)
	for child in node.get_children():
		_connect_buttons_in(child)


func _connect_button(button: Button) -> void:
	if not is_instance_valid(button) or button.has_meta(&"audio_click_connected"):
		return
	button.set_meta(&"audio_click_connected", true)
	var current_scene := get_tree().current_scene
	var is_main_menu := current_scene != null \
		and current_scene.scene_file_path == "res://scenes/TitleScreen.tscn" \
		and current_scene.is_ancestor_of(button)
	button.button_down.connect(_play_button_sound.bind(button, is_main_menu))


func _play_button_sound(button: Button, is_main_menu: bool) -> void:
	if button.has_meta(CAT_SOUND_META):
		cat_player.play()
		return
	if is_main_menu:
		main_menu_player.play()
	else:
		button_player.play()
