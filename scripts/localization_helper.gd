class_name LocalizationHelper
extends RefCounted


static func translate_saved_text(value: Variant) -> String:
	var source := client_terms(str(value))
	if source.is_empty() or not TranslationServer.get_locale().begins_with("en"):
		return source
	var exact := str(TranslationServer.translate(source))
	if exact != source:
		return exact
	# Старые сохранения могут хранить базовый текст и добавленное позже предложение.
	# Сначала переводим самый длинный известный префикс, чтобы не разбивать его на фразы.
	for index in range(source.length() - 1, -1, -1):
		if source.substr(index, 1) not in [".", "!", "?"]:
			continue
		var prefix := source.substr(0, index + 1)
		var translated_prefix := str(TranslationServer.translate(prefix))
		if translated_prefix != prefix:
			return translated_prefix + translate_saved_text(source.substr(index + 1))
	var result := ""
	var segment := ""
	for index in source.length():
		var character := source.substr(index, 1)
		segment += character
		if character in [".", "!", "?"]:
			result += _translate_segment(segment)
			segment = ""
	if not segment.is_empty():
		result += _translate_segment(segment)
	return result


static func client_terms(text: String) -> String:
	var replacements := {"ЖИЛЬЦАМИ": "КЛИЕНТАМИ", "ЖИЛЬЦОВ": "КЛИЕНТОВ", "ЖИЛЬЦА": "КЛИЕНТА", "ЖИЛЕЦ": "КЛИЕНТ", "Жильцы": "Клиенты", "Жилец": "Клиент", "жильцами": "клиентами", "жильцов": "клиентов", "жильца": "клиента", "жильцу": "клиенту", "жильцом": "клиентом", "жильцы": "клиенты", "жилец": "клиент"}
	for old_term: String in replacements:
		text = text.replace(old_term, str(replacements[old_term]))
	return text


static func _translate_segment(segment: String) -> String:
	var leading_length := segment.length() - segment.trim_prefix(" ").length()
	var trailing_length := segment.length() - segment.trim_suffix(" ").length()
	var exact := str(TranslationServer.translate(segment))
	if exact != segment:
		return " ".repeat(leading_length) + exact.strip_edges() + " ".repeat(trailing_length)
	var stripped := segment.strip_edges()
	if stripped.is_empty():
		return segment
	var translated := str(TranslationServer.translate(stripped))
	if translated == stripped and stripped.begins_with("Заявка выполнена после истечения срока: из оплаты удержано "):
		var amount_text := stripped.trim_prefix("Заявка выполнена после истечения срока: из оплаты удержано ").trim_suffix(" монет.")
		if amount_text.is_valid_int():
			translated = (str(TranslationServer.translate(" Заявка выполнена после истечения срока: из оплаты удержано %d монет.")) % int(amount_text)).strip_edges()
	if translated == stripped:
		return segment
	return " ".repeat(leading_length) + translated + " ".repeat(trailing_length)
