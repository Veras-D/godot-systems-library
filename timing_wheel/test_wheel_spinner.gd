extends SceneTree

const WheelConfig = preload("WheelConfig.gd")
const WheelSpinner = preload("WheelSpinner.gd")
const WheelSpinnerScene = preload("WheelSpinner.tscn")

func _init() -> void:
	print("==> Running WheelSpinner Node Lifecycle & Signal Tests...")

	# 1. Instantiate Spinner
	var spinner: WheelSpinner = WheelSpinnerScene.instantiate() as WheelSpinner
	assert(spinner != null, "Should instantiate WheelSpinner node")
	root.add_child(spinner)

	# 2. Test Setup
	var cfg = WheelConfig.create_card_wars_attacker(0.80, 0.07)
	spinner.setup(cfg)
	assert(spinner.state == WheelSpinner.State.IDLE, "State should be IDLE initially")

	# 3. Test Quick Resolve
	var qr_result = spinner.quick_resolve()
	assert(qr_result.has("id"), "Result must contain 'id'")
	assert(qr_result.has("multiplier"), "Result must contain 'multiplier'")
	assert(qr_result.has("angle_deg"), "Result must contain 'angle_deg'")
	assert(spinner.state == WheelSpinner.State.RESOLVED, "State should be RESOLVED after quick_resolve")
	print("Quick Resolve test passed. Result: ", qr_result.name, " Multiplier: ", qr_result.multiplier)

	# 4. Test Live Spin Kinetics & Signal Handling
	spinner.setup(cfg)
	var event_box = { "received": false, "data": {} }

	spinner.spin_completed.connect(func(res: Dictionary):
		event_box["received"] = true
		event_box["data"] = res
	)

	spinner.start_spin()
	assert(spinner.state == WheelSpinner.State.SPINNING, "State should be SPINNING after start_spin")

	# Wait past minimum spin duration (0.25s)
	await create_timer(0.35).timeout

	assert(spinner.current_angle_deg > 0.0, "Needle angle should advance during spin")
	print("Needle rotating successfully. Current angle: %.1f°" % spinner.current_angle_deg)

	# Trigger stop
	spinner.stop_spin()
	assert(spinner.state == WheelSpinner.State.STOPPING, "State should be STOPPING")

	# Wait for completion signal (deceleration takes ~0.25s)
	var timer = create_timer(1.0)
	while not event_box["received"] and timer.time_left > 0.0:
		await process_frame

	assert(event_box["received"], "spin_completed signal should have been received")
	assert(spinner.state == WheelSpinner.State.RESOLVED, "State should be RESOLVED after stopping")
	var signal_data: Dictionary = event_box["data"]
	assert(signal_data.has("id"), "Signal result must have 'id'")
	assert(signal_data.has("multiplier"), "Signal result must have 'multiplier'")
	print("Spin completed signal verified. Landed on: ", signal_data.name, " (", signal_data.angle_deg, "°)")

	# Clean up
	spinner.queue_free()
	print("==> All WheelSpinner Node & Signal Tests PASSED!")
	quit(0)
