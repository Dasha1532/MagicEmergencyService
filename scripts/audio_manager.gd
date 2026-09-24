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
