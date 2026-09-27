extends Control

signal main_menu_requested

@onready var reason_label: Label = $Reason
@onready var stats_label: Label = $Stats


func _ready() -> void:
	$MenuButton.pressed.connect(_on_menu_button_pressed)


func set_document_content(reason_text: String, confirmed_claims: int, claim_threshold: int, money: int) -> void:
	reason_label.text = "ОСНОВАНИЕ ДЛЯ УВОЛЬНЕНИЯ\n%s" % reason_text
	stats_label.text = "Подтверждённых претензий: %d из %d\nСостояние казны: %d монет" % [confirmed_claims, claim_threshold, money]


func _on_menu_button_pressed() -> void:
	main_menu_requested.emit()
