extends SceneTree

const Mapper = preload("res://scripts/ai_pose_applier.gd")
var errors: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: errors.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var rig = app.get_node("Rig")
	var points: Array[Vector3] = []
	points.resize(33)
	points.fill(Vector3.ZERO)
	points[23] = Vector3(-.15,1,0); points[24] = Vector3(.15,1,0)
	points[11] = Vector3(-.2,1.5,.15); points[12] = Vector3(.2,1.5,-.15)
	points[7] = Vector3(-.1,1.8,0); points[8] = Vector3(.1,1.8,0)
	points[25] = Vector3(-.15,.5,0); points[26] = Vector3(.15,.5,0)
	points[27] = Vector3(-.15,.1,0); points[28] = Vector3(.15,.1,0)
	points[29] = Vector3(-.15,0,-.1); points[30] = Vector3(.15,0,-.1)
	points[31] = Vector3(-.15,0,.15); points[32] = Vector3(.15,0,.15)
	var landmarks: Array = []
	for point in points: landmarks.append({"x":-point.x,"y":-point.y,"z":point.z,"visibility":1.0})
	var data = Mapper.compute(landmarks,rig,1.0,Vector3.ZERO)
	for name in data.fk_rotations: app.rig_controller.find_node(name).quaternion = data.fk_rotations[name]
	var torso = app.rig_controller.find_node("torso_g")
	var expected := (points[12]-points[11]).normalized()
	check(torso.global_basis.orthonormalized().x.distance_to(expected)<.001,"Torso follows shoulders independently of hips")
	check(app.rig_controller.find_node("head_g").global_basis.orthonormalized().x.distance_to(Vector3.RIGHT)<.001,"Head uses updated torso orientation")
	var repeated = Mapper.compute(landmarks,rig,1.0,Vector3.ZERO)
	for name in repeated.fk_rotations: app.rig_controller.find_node(name).quaternion = repeated.fk_rotations[name]
	check(torso.global_basis.orthonormalized().x.distance_to(expected)<.001,"Repeated image application does not accumulate rotation")
	for basis in data.end_world_bases.values(): check(abs(basis.determinant()-1.0)<.001,"End basis is a proper rotation, not reflection")
	check(not data.end_world_bases.has("rhand_g"),"Degenerate hand landmarks are ignored")
	var collapsed: Array[Vector3] = []
	collapsed.resize(33); collapsed.fill(Vector3.ZERO)
	check(Mapper._foot_conv_basis(collapsed, landmarks.map(func(_v):return 1.0),30,32,26,28)==null,"Degenerate feet are ignored")
	var ratios := Mapper.estimate_scale(landmarks,rig)
	landmarks[11].x = 1000.0
	landmarks[11].visibility = 0.0
	check(is_finite(Mapper.estimate_scale(landmarks,rig)) and ratios>0,"Occluded shoulder does not explode scale")
	print("POSE_MAPPING failures=",errors.size())
	quit(0 if errors.is_empty() else 1)
