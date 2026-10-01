extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.jobs[&"memory_test"] = {"resident": "Господин Рагнар", "consequence": false}
	state.job_reports = []
	assert(state.get_resident_greeting(&"memory_test") == "Здравствуйте. Вот такая у меня неприятность.")
	state.job_reports.append({"job_id": "source", "resident": "Господин Рагнар", "rating": 5, "anomaly_id": "faucet_freeze"})
	assert("здорово помогли" in state.get_resident_greeting(&"memory_test"))
	state.jobs[&"memory_test"]["consequence"] = true
	state.jobs[&"memory_test"]["source_job_id"] = "source"
	state.jobs[&"memory_test"]["generated_instance"] = {"anomaly_id": "faucet_overheat"}
	assert(state.get_resident_greeting(&"memory_test") == "Спасибо, что в прошлый раз убрали лёд. Теперь этот же кран начал сам нагреваться.")
	state.job_reports.append({"job_id": "other", "resident": "Господин Рагнар", "rating": 1, "claim_amount": 350})
	assert("убрали лёд" in state.get_resident_greeting(&"memory_test"))
	state.jobs[&"memory_test"]["source_job_id"] = ""
	assert("без повреждений" in state.get_resident_greeting(&"memory_test"))
	print("RESIDENT MEMORY SMOKE TEST: PASS")
	quit()
