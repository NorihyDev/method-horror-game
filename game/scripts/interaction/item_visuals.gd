class_name ItemVisuals
extends RefCounted
## Procedural item models (placeholder art). Replace per docs/asset-replacement.md
## by mapping an ItemDefinition.shape to an imported scene.


static func build(item_id: String) -> Node3D:
	var def: ItemDefinition = Session.item(item_id)
	var shape := String(def.shape) if def else "box"
	var color := def.icon_color if def else Color(0.8, 0.8, 0.8)
	var root := Node3D.new()
	root.name = "Item_" + item_id
	match shape:
		"fuse":
			var ceramic := MaterialLib.flat(Color(0.85, 0.8, 0.68), 0.5)
			var cap := MaterialLib.flat(color, 0.3, 0.9)
			_cyl(root, 0.022, 0.07, ceramic, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3.ZERO))
			for sx in [-1, 1]:
				_cyl(root, 0.025, 0.018, cap, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(sx * 0.042, 0, 0)))
		"key":
			var brass := MaterialLib.flat(color, 0.3, 0.9)
			_tor(root, 0.022, 0.035, brass, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-0.05, 0, 0)))
			_box(root, Vector3(0.08, 0.008, 0.012), brass, Vector3(0.012, 0, 0))
			_box(root, Vector3(0.012, 0.008, 0.02), brass, Vector3(0.04, 0, 0.014))
			_box(root, Vector3(0.01, 0.008, 0.015), brass, Vector3(0.022, 0, 0.012))
		"belt":
			var rubber := MaterialLib.flat(color, 0.9)
			_tor(root, 0.07, 0.085, rubber, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		"gear":
			_gear(root, MaterialLib.flat(color, 0.35, 0.85))
		"assembly":
			_gear(root, MaterialLib.flat(Color(0.62, 0.63, 0.64), 0.35, 0.85))
			_tor(
				root,
				0.07,
				0.085,
				MaterialLib.flat(Color(0.12, 0.12, 0.13), 0.9),
				Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.03, 0))
			)
		"battery":
			_cyl(
				root,
				0.017,
				0.065,
				MaterialLib.flat(Color(0.12, 0.12, 0.13), 0.4, 0.3),
				Transform3D(Basis.IDENTITY, Vector3(0, 0.033, 0))
			)
			_cyl(
				root,
				0.0175,
				0.02,
				MaterialLib.flat(Color(0.6, 0.12, 0.1), 0.4),
				Transform3D(Basis.IDENTITY, Vector3(0, 0.055, 0))
			)
		"card":
			_box(root, Vector3(0.085, 0.003, 0.054), MaterialLib.flat(color, 0.4), Vector3(0, 0.002, 0))
			_box(
				root,
				Vector3(0.03, 0.004, 0.012),
				MaterialLib.flat(Color(0.55, 0.08, 0.08), 0.4),
				Vector3(-0.02, 0.003, -0.012)
			)
			var bars := def.marking if def else 0
			for i in bars:
				_box(
					root,
					Vector3(0.075, 0.004, 0.005),
					MaterialLib.flat(Color(0.95, 0.95, 0.92), 0.5),
					Vector3(0, 0.003, 0.008 + i * 0.009)
				)
		"relay":
			_box(root, Vector3(0.07, 0.05, 0.05), MaterialLib.flat(color, 0.5), Vector3(0, 0.035, 0))
			var pin := MaterialLib.flat(Color(0.75, 0.62, 0.3), 0.3, 0.9)
			for i in 4:
				_box(root, Vector3(0.006, 0.02, 0.006), pin, Vector3(-0.024 + i * 0.016, 0.0, 0))
		"cell":
			_box(root, Vector3(0.16, 0.12, 0.1), MaterialLib.flat(color, 0.5), Vector3(0, 0.06, 0))
			_box(root, Vector3(0.162, 0.03, 0.102), MaterialLib.flat(Color(0.85, 0.7, 0.15), 0.5), Vector3(0, 0.11, 0))
			_tor(
				root,
				0.02,
				0.03,
				MaterialLib.flat(Color(0.6, 0.6, 0.62), 0.3, 0.8),
				Transform3D(Basis.IDENTITY, Vector3(0, 0.13, 0))
			)
		"cutters":
			# Long red handles and short steel jaws, lying flat.
			var grip := MaterialLib.flat(color, 0.6)
			var steel := MaterialLib.flat(Color(0.6, 0.61, 0.63), 0.3, 0.9)
			for side in [-1, 1]:
				var handle := MeshInstance3D.new()
				var hm := BoxMesh.new()
				hm.size = Vector3(0.34, 0.02, 0.025)
				handle.mesh = hm
				handle.material_override = grip
				handle.rotation.y = side * 0.12
				handle.position = Vector3(-0.08, 0.012, side * 0.025)
				root.add_child(handle)
			_box(root, Vector3(0.14, 0.025, 0.05), steel, Vector3(0.15, 0.013, 0))
		_:
			_box(root, Vector3(0.08, 0.08, 0.08), MaterialLib.flat(color, 0.6), Vector3(0, 0.04, 0))
	return root


static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


static func _cyl(parent: Node3D, radius: float, height: float, mat: Material, xform: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.transform = xform
	parent.add_child(mi)


static func _tor(parent: Node3D, inner: float, outer: float, mat: Material, xform: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 6
	mi.mesh = m
	mi.material_override = mat
	mi.transform = xform
	parent.add_child(mi)


static func _gear(parent: Node3D, mat: Material) -> void:
	_cyl(parent, 0.06, 0.025, mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.0125, 0)))
	for i in 10:
		var a := TAU * i / 10.0
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.022, 0.025, 0.018)
		mi.mesh = m
		mi.material_override = mat
		mi.transform = Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.068, 0.0125, sin(a) * 0.068))
		parent.add_child(mi)
