extends SceneTree

const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")
const WardrobeSimulationScript := preload("res://scripts/wardrobe_simulation.gd")
const PortalMirrorSimulationScript := preload("res://scripts/portal_mirror_simulation.gd")
const GargoyleSimulationScript := preload("res://scripts/gargoyle_simulation.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	var lava: RefCounted = RepairSimulationScript.new()
	_check("опечатки" in lava.get_employee_reaction(&"liliya", &"heat"), "Лилия комментирует нагрев лавового крана до действия")
	_check("уберите лаву" in lava.get_employee_reaction(&"boris", &"repair"), "Борис предупреждает о текущей лаве")
	lava.apply_action(&"liliya", &"freeze")
	_check("уплотнения" in lava.get_employee_reaction(&"boris", &"repair"), "После остановки лавы Борис не повторяет устаревшее предупреждение")

	var wardrobe: RefCounted = WardrobeSimulationScript.new()
	var left_line: String = wardrobe.get_employee_reaction(&"grog", &"physical_move", &"move_left")
	var kitchen_line: String = wardrobe.get_employee_reaction(&"grog", &"physical_move", &"move_kitchen")
	_check("левой стене" in left_line, "Грог называет выбранную левую стену")
	_check("кухню" in kitchen_line and kitchen_line != left_line, "Для прохода на кухню у Грога отдельная реплика")

	var portal: RefCounted = PortalMirrorSimulationScript.new()
	_check("Семь лет" in portal.get_employee_reaction(&"grog", &"physical_move"), "Грог предупреждает о разбивании зеркала")

	var gargoyle: RefCounted = GargoyleSimulationScript.new()
	_check("разговаривать будете вы" in gargoyle.get_employee_reaction(&"liliya", &"heat"), "Лилия произносит согласованную реплику перед нагревом горгульи")
	_check(not EmployeeReactionResolverScript.no_effect_for(&"nika").is_empty(), "Для неудачного воздействия есть живая реплика сотрудника")

	if failures.is_empty():
		print("ACTION DIALOGUE SMOKE TEST: PASS")
		quit(0)
	else:
		print("ACTION DIALOGUE SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)
