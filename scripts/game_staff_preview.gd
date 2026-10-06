extends RefCounted

# Local game data only; no game geometry is bundled with the application.
static func build() -> MeshInstance3D:
	var path := "user://saberstaff/saberstaff.json"
	if not FileAccess.file_exists(path): return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.has("nodes"): return null
	var transforms := {}
	var mesh := ArrayMesh.new()
	for entry in data.nodes:
		var props: Dictionary = entry[2]
		var transform := Transform3D.IDENTITY
		if props.has("position"): transform.origin = _vector(props.position)
		if props.has("orientation"):
			var axis := _vector(props.orientation)
			if axis.length() > .00001: transform.basis = Basis(axis.normalized(),float(props.orientation[3]))
		if props.has("scale"): transform.basis = transform.basis.scaled(Vector3.ONE * float(props.scale[0]))
		var parent: String = str(props.get("parent",["null"])[0]).to_lower()
		transform = transforms.get(parent,Transform3D.IDENTITY) * transform
		transforms[str(entry[1]).to_lower()] = transform
		if not props.has("verts") or not props.has("faces"): continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in props.faces:
			for i in [0,2,1]:
				if props.has("tverts") and face.size() >= 7:
					var uv = props.tverts[int(face[4+i])]
					st.set_uv(Vector2(float(uv[0]),1.0-float(uv[1])))
				st.add_vertex(transform * _vector(props.verts[int(face[i])]))
		st.generate_normals()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var texture_path := path.get_base_dir().path_join(str(props.get("bitmap",[""])[0]).to_lower()+".png")
		if FileAccess.file_exists(texture_path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
			if img != null: material.albedo_texture = ImageTexture.create_from_image(img)
		st.set_material(material)
		st.commit(mesh)
	if mesh.get_surface_count() == 0: return null
	var result := MeshInstance3D.new()
	result.name = "GameSaberstaff"
	result.mesh = mesh
	result.set_meta("game_resource",data.get("resource",""))
	# Identity transform keeps the MDL's real attachment origin and scale.
	# Blades are guides; the hilt geometry above is copied from the game.
	var bounds := mesh.get_aabb()
	for side in [-1,1]:
		var guide := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.height = .6
		cylinder.top_radius = .015
		cylinder.bottom_radius = .015
		guide.mesh = cylinder
		guide.rotation_degrees.x = 90
		guide.position.z = bounds.position.z - .3 if side < 0 else bounds.end.z + .3
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(.2,.9,1)
		guide.material_override = material
		result.add_child(guide)
	return result

static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[2]),-float(values[1]))
