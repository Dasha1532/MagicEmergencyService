extends Node

const SETTINGS_PATH := "user://settings.cfg"

var master_volume_percent: float = 100.0
var fullscreen_enabled: bool = false


func _ready() -> void:
	_load_settings()
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


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		master_volume_percent = _current_volume_percent()
		fullscreen_enabled = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		return
	master_volume_percent = clampf(float(config.get_value("audio", "master_volume_percent", 100.0)), 0.0, 100.0)
	fullscreen_enabled = bool(config.get_value("display", "fullscreen", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume_percent", master_volume_percent)
	config.set_value("display", "fullscreen", fullscreen_enabled)
	config.save(SETTINGS_PATH)


func _apply_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_index, master_volume_percent <= 0.0)
	if master_volume_percent > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume_percent / 100.0))


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _current_volume_percent() -> float:
	var bus_index := AudioServer.get_bus_index("Master")
	if AudioServer.is_bus_mute(bus_index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
