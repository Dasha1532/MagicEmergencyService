extends Node

signal language_changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_WINDOW_RESOLUTION := Vector2i(1600, 900)
const SUPPORTED_LOCALES: PackedStringArray = ["ru", "en"]
const SUPPORTED_WINDOW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var master_volume_percent: float = 100.0
var fullscreen_enabled: bool = false
var window_resolution: Vector2i = DEFAULT_WINDOW_RESOLUTION
var language: String = "ru"


func _ready() -> void:
	_load_settings()
	_apply_language()
	_apply_volume()
	_apply_fullscreen()


func set_master_volume(value: float) -> void:
	master_volume_percent = clampf(value, 0.0, 100.0)
	_apply_volume()
	_save_settings()


func get_master_volume() -> float:
	return master_volume_percent


func set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	_apply_fullscreen()
	_save_settings()


func is_fullscreen() -> bool:
	return fullscreen_enabled


func set_window_resolution(resolution: Vector2i) -> void:
	window_resolution = _validated_resolution(resolution)
	if not fullscreen_enabled:
		_apply_window_resolution()
	_save_settings()


func get_window_resolution() -> Vector2i:
	return window_resolution


func set_language(locale: String) -> void:
	language = locale if SUPPORTED_LOCALES.has(locale) else "ru"
	_apply_language()
	_save_settings()
	language_changed.emit(language)


func get_language() -> String:
	return language


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		master_volume_percent = _current_volume_percent()
		fullscreen_enabled = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		window_resolution = DEFAULT_WINDOW_RESOLUTION
		language = "ru" if OS.get_locale_language() == "ru" else "en"
		return
	master_volume_percent = clampf(float(config.get_value("audio", "master_volume_percent", 100.0)), 0.0, 100.0)
	fullscreen_enabled = bool(config.get_value("display", "fullscreen", false))
	window_resolution = _validated_resolution(Vector2i(
		int(config.get_value("display", "window_width", DEFAULT_WINDOW_RESOLUTION.x)),
		int(config.get_value("display", "window_height", DEFAULT_WINDOW_RESOLUTION.y))
	))
	language = str(config.get_value("localization", "language", "ru"))
	if not SUPPORTED_LOCALES.has(language):
		language = "ru"


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume_percent", master_volume_percent)
	config.set_value("display", "fullscreen", fullscreen_enabled)
	config.set_value("display", "window_width", window_resolution.x)
	config.set_value("display", "window_height", window_resolution.y)
	config.set_value("localization", "language", language)
	config.save(SETTINGS_PATH)


func _apply_language() -> void:
	TranslationServer.set_locale(language)


func _apply_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_index, master_volume_percent <= 0.0)
	if master_volume_percent > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume_percent / 100.0))


func _apply_fullscreen() -> void:
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_window_resolution()


func _apply_window_resolution() -> void:
	DisplayServer.window_set_size(window_resolution)
	var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var centered_position := Vector2i(
		int((screen_size.x - window_resolution.x) / 2.0),
		int((screen_size.y - window_resolution.y) / 2.0),
	)
	DisplayServer.window_set_position(centered_position)


func _validated_resolution(resolution: Vector2i) -> Vector2i:
	return resolution if SUPPORTED_WINDOW_RESOLUTIONS.has(resolution) else DEFAULT_WINDOW_RESOLUTION


func _current_volume_percent() -> float:
	var bus_index := AudioServer.get_bus_index("Master")
	if AudioServer.is_bus_mute(bus_index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
