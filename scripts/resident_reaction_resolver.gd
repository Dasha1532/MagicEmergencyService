class_name ResidentReactionResolver
extends RefCounted


const FIRE_REACTIONS: PackedStringArray = [
	"Потушите это немедленно!",
	"У меня тут пожар! Немедленно тушите!",
	"Вы что творите? Быстро погасите огонь!",
]
const DAMAGE_REACTIONS: PackedStringArray = [
	"Осторожнее! Вы уже портите моё имущество!",
	"Я вижу новые повреждения. За это придётся отвечать!",
	"Я вызывал ремонтную бригаду, а не подрывников! Прекратите всё ломать!",
]
const RUINED_REACTIONS: PackedStringArray = [
	"Что вы наделали! Я буду жаловаться!",
	"Вы уничтожили мою вещь! Я потребую полную компенсацию!",
	"Это вы называете ремонтом? От моего имущества ничего не осталось!",
]


static func message_for(object_state: Dictionary, default_message: String, voice_variant: int = 0) -> String:
	if _is_ruined(object_state):
		return _pick(RUINED_REACTIONS, voice_variant)
	if bool(object_state.get("burning", false)):
		return _pick(FIRE_REACTIONS, voice_variant)
	if int(object_state.get("damage", 0)) > 0:
		return _pick(DAMAGE_REACTIONS, voice_variant)
	return default_message


static func title_for(object_state: Dictionary, default_title: String, object_name: String) -> String:
	var localized_object_name := TranslationServer.translate(object_name)
	if _is_ruined(object_state):
		return TranslationServer.translate("%s уничтожен") % localized_object_name
	if bool(object_state.get("burning", false)):
		return TranslationServer.translate("%s горит") % localized_object_name
	if int(object_state.get("damage", 0)) > 0:
		return TranslationServer.translate("%s повреждён") % localized_object_name
	return default_title


static func _is_ruined(object_state: Dictionary) -> bool:
	if bool(object_state.get("destroyed", false)):
		return true
	if object_state.has("condition") and int(object_state["condition"]) <= 0:
		return true
	if object_state.has("durability") and int(object_state.get("damage", 0)) >= int(object_state["durability"]):
		return true
	if StringName(str(object_state.get("visual_state", ""))) == &"melted":
		return true
	return false


static func _pick(options: PackedStringArray, voice_variant: int) -> String:
	return options[posmod(voice_variant, options.size())]
