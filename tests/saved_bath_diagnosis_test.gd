extends SceneTree

const Bath := preload("res://scripts/frozen_bath_simulation.gd")

func _initialize() -> void:
	var failed := false
	for path: String in OS.get_cmdline_user_args():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for job_id: String in data.get("job_repair_states", {}):
			var saved: Dictionary = data["job_repair_states"][job_id]
			if not saved.get("world_object", {}).has("bath_damaged"):
				continue
			var simulation := Bath.new()
			simulation.load_state(saved)
			var damaged: bool = simulation.world_object["bath_damaged"]
			var reaction := simulation.get_employee_reaction(&"boris", &"diagnose", &"bath")
			var result: Dictionary = simulation.apply_action(&"boris", &"diagnose", false, &"bath")
			print("Saved bath: damaged=", damaged, "; reaction=", reaction, "; result=", result["message"])
			failed = failed or (damaged and ("цела" in reaction or "цела" in str(result["message"])))
	quit(1 if failed else 0)
