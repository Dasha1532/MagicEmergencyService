extends RefCounted

static func build(section: String, crew: PackedStringArray, selected: String) -> Array[Dictionary]:
	var file := FileAccess.open("res://data/prison/dialogue.json", FileAccess.READ)
	var content: Dictionary = JSON.parse_string(file.get_as_text())
	var result: Array[Dictionary] = []
	for source: Dictionary in content.get(section, []):
		var speaker := str(source.get("speaker", ""))
		if speaker == "selected":
			speaker = selected
		if source.has("crew") and not crew.has(str(source["crew"])):
			continue
		if source.has("absent") and crew.has(str(source["absent"])):
			continue
		if source.has("not_selected") and selected == str(source["not_selected"]):
			continue
		if speaker in ["boris", "grog", "liliya", "nika", "felix"] and not crew.has(speaker):
			continue
		var line := source.duplicate(true)
		line["speaker"] = speaker
		if line.has("variants"):
			line["text"] = line["variants"].get(selected, line.get("text", ""))
		result.append(line)
	return result
