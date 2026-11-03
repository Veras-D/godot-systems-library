extends SceneTree

# Godot Systems Library - Master Test Runner
# Automatically discovers and executes all test_*.gd scripts in the library.
# Reports execution status, timings, logs failure output, and exits with code 0 (success) or 1 (failure).

const COLOR_RESET = "\u001b[0m"
const COLOR_RED = "\u001b[31;1m"
const COLOR_GREEN = "\u001b[32;1m"
const COLOR_YELLOW = "\u001b[33;1m"
const COLOR_CYAN = "\u001b[36;1m"
const COLOR_GRAY = "\u001b[90m"

func _init() -> void:
	print("\n" + COLOR_CYAN + "========================================================" + COLOR_RESET)
	print(COLOR_CYAN + "   GODOT MODULAR SYSTEMS LIBRARY - MASTER TEST RUNNER   " + COLOR_RESET)
	print(COLOR_CYAN + "========================================================" + COLOR_RESET + "\n")

	var test_files: Array[String] = []
	_scan_for_tests("res://", test_files)
	test_files.sort()

	if test_files.is_empty():
		print(COLOR_YELLOW + "No test files matching 'test_*.gd' were found." + COLOR_RESET)
		quit(0)
		return

	print("Discovered %d test suites to execute:\n" % test_files.size())

	var godot_bin = OS.get_executable_path()
	var passed = 0
	var failed = 0
	var failed_reports: Array[Dictionary] = []
	var start_all = Time.get_ticks_msec()

	for test_path in test_files:
		var test_name = test_path.get_file()
		var dir_name = test_path.get_base_dir().replace("res://", "")
		print("%s▶ Running [%s / %s]...%s" % [COLOR_GRAY, dir_name, test_name, COLOR_RESET])

		var output: Array = []
		var t_start = Time.get_ticks_msec()
		var exit_code = OS.execute(godot_bin, ["--headless", "--path", ".", "-s", test_path], output, true)
		var elapsed = (Time.get_ticks_msec() - t_start) / 1000.0

		var full_output_parts: Array[String] = []
		for item in output:
			full_output_parts.append(str(item))

		var out_str: String = ""
		if not full_output_parts.is_empty():
			if full_output_parts.size() > 1 and not full_output_parts[0].contains("\n"):
				out_str = "\n".join(full_output_parts)
			else:
				out_str = "".join(full_output_parts)

		if exit_code == 0:
			passed += 1
			print("%s  ✔ PASS%s %s(%.2fs)%s" % [COLOR_GREEN, COLOR_RESET, COLOR_GRAY, elapsed, COLOR_RESET])
		else:
			failed += 1
			print("%s  ✖ FAIL%s %s(exit code %d, %.2fs)%s" % [COLOR_RED, COLOR_RESET, COLOR_YELLOW, exit_code, elapsed, COLOR_RESET])
			failed_reports.append({
				"path": test_path,
				"code": exit_code,
				"output": out_str
			})

	var total_time = (Time.get_ticks_msec() - start_all) / 1000.0

	# Print failure diagnostics if any
	if not failed_reports.is_empty():
		print("\n" + COLOR_RED + "--------------------------------------------------------" + COLOR_RESET)
		print(COLOR_RED + "                 FAILURE DIAGNOSTICS                    " + COLOR_RESET)
		print(COLOR_RED + "--------------------------------------------------------" + COLOR_RESET)
		for f_rep in failed_reports:
			print("\n%sFAILED SUITE: %s (Exit Code: %d)%s" % [COLOR_RED, f_rep["path"], f_rep["code"], COLOR_RESET])
			print(COLOR_GRAY + f_rep["output"].strip_edges() + COLOR_RESET)

	# Print Summary Table
	print("\n" + COLOR_CYAN + "========================================================" + COLOR_RESET)
	print(COLOR_CYAN + "                      TEST SUMMARY                      " + COLOR_RESET)
	print(COLOR_CYAN + "========================================================" + COLOR_RESET)
	print("  Total Suites : %d" % test_files.size())
	print("  Passed       : %s%d%s" % [COLOR_GREEN if passed > 0 else COLOR_RESET, passed, COLOR_RESET])
	print("  Failed       : %s%d%s" % [COLOR_RED if failed > 0 else COLOR_RESET, failed, COLOR_RESET])
	print("  Total Time   : %.2fs" % total_time)
	print(COLOR_CYAN + "========================================================" + COLOR_RESET + "\n")

	if failed > 0:
		print(COLOR_RED + "TEST SUITE FAILED." + COLOR_RESET + "\n")
		quit(1)
	else:
		print(COLOR_GREEN + "ALL TEST SUITES PASSED SUCCESSFULLY." + COLOR_RESET + "\n")
		quit(0)

func _scan_for_tests(dir_path: String, out_tests: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		# Ignore hidden directories like .godot, .git
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			_scan_for_tests(full_path, out_tests)
		else:
			if file_name.begins_with("test_") and file_name.ends_with(".gd"):
				out_tests.append(full_path)

		file_name = dir.get_next()
	dir.list_dir_end()
