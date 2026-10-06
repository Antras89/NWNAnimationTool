extends SceneTree

var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func run() -> void:
	var app = load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var rig = app.get_node("Rig")
	var text := "newanim test model\nlength 1\nnode dummy rootdummy\nparent model\npositionkey 3\n0 0 0 1\n0.5 1 0 1\n1 2 0 1\norientationkey 2\n0 0 0 1 -0.4\n1 0 0 1 -0.8\nendnode\nnode dummy Lbicep_g\nparent torso_g\norientation 0 1 0 0.3\nendnode\ndoneanim test model"
	var parsed = MdlImporter.parse(text,rig)
	check(parsed != null,"Counted MDL keys")
	check(parsed.keyframes.size() == 3,"Position-only timestamps")
	check(parsed.keyframes[1].transforms.rootdummy.origin.distance_to(Vector3(1,1,0)) < .0001,"Position interpolation")
	check(parsed.keyframes[1].transforms.rootdummy.basis.get_rotation_quaternion().angle_to(Quaternion(Vector3.UP,-.6))<.002,"Signed rotation interpolation")
	var lower = MdlImporter.parse(text.to_lower(),rig)
	check(parsed.keyframes == lower.keyframes,"Case-insensitive bone names")
	check(MdlImporter.parse(text+"\n"+text,rig) == null,"Do not merge full model clips silently")
	app._keyframes = parsed.keyframes
	app._anim_length = 1
	app._on_duration_changed(2)
	check(app._keyframes[-1].time == 2,"Scale timeline")
	app._undo()
	check(app._keyframes[-1].time == 1,"Undo timeline")
	app._redo()
	check(app._keyframes[-1].time == 2,"Redo timeline")
	app.side_panel.set_anim_name("test")
	app._on_pose_memory_save(0)
	check(app._pose_memory_names[0] == "test","Named pose memory")
	for staff in [false,true]:
		app.side_panel._on_double_staff_toggled(staff)
		var blade = app.side_panel._weapon_meshes.rhand
		var hand = app.rig_controller.find_node("rhand_g")
		check(blade.to_global(Vector3(0,-.18,0) if staff else blade.get_node("LightsaberHilt").position).distance_to(hand.to_global(hand.mesh.get_aabb().get_center()))<.0001,"Centered hilt")
	app.qol._pin("right_leg",true)
	var foot = app.rig_controller.find_node("rfoot_g")
	var pinned: Vector3 = foot.global_position
	app.rig_controller.find_node("rootdummy").position.y -= .02
	app.qol.apply_constraints()
	check(foot.global_position.distance_to(pinned)<.002,"Foot pin")
	app.mdl_bank._apply_preview_rig("female")
	check(app._current_model_path.ends_with("a_fa.glb"),"Female MDL uses female preview")
	var neck = app.rig_controller.find_node("neck_g")
	check(abs(app._rest_transforms[neck].origin.y - .34636)<.001,"Female neck height matches MDL")
	app.mdl_bank._apply_preview_rig("male")
	check(app._current_model_path.ends_with("a_ba.glb"),"Male MDL uses male preview")
	app.rig_controller.select_component("right_upper_arm")
	check(app.rig_controller._node_to_component.rforearm_g == "right_forearm", "Separate forearm picking")
	app.rig_controller.select_component("left_calf", true)
	check(app.rig_controller.selected_components.size() == 2, "Shift adds selection")
	var arm = app.rig_controller.find_node("rbicep_g")
	var calf = app.rig_controller.find_node("lshin_g")
	check(app._attachment_translate_handle != null, "Multi-selection has translation arrows")
	var arm_pos = arm.global_position
	var calf_pos = calf.global_position
	var offset = Vector3(.03,.02,0)
	app._on_panel_position_changed(arm_pos + offset)
	check(arm.global_position.is_equal_approx(arm_pos + offset), "Position moves arm")
	check(calf.global_position.is_equal_approx(calf_pos + offset), "Position moves calf")
	var arm_before = arm.basis
	var calf_before = calf.basis
	var turn = Basis(Vector3.UP, .15)
	app._rotate_selection(arm_before * turn)
	check(arm.basis.is_equal_approx(arm_before * turn), "Group rotates arm")
	check(calf.basis.is_equal_approx(calf_before * turn), "Group rotates calf")
	await process_frame
	check(arm.basis.is_equal_approx(arm_before * turn), "IK does not overwrite FK arm")
	app.rig_controller.select_component("left_calf", true)
	check(app.rig_controller.selected_components.size() == 1, "Shift removes selection")
	app.rig_controller.select_component("right_forearm", true)
	check(app.rig_controller.selection_roots().size() == 1, "Parent-child selection avoids double rotation")
	app.rig_controller.deselect()
	check(app.rig_controller.selected_components.is_empty(), "Clear multi-selection")
	app._on_overlay_toggled(true)
	check(app._nwn_skeleton.visible and app._nwn_skeleton_mesh.get_surface_count() == 1, "Skel displays native hierarchy without source")
	app._on_overlay_toggled(false)
	check(not app._nwn_skeleton.visible, "Skel hides native hierarchy")
	print("WORKSHOP_SMOKE failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
