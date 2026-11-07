extends ColorRect

## Réplica de las tareas de fldeff_flash.c, con pasos de un frame GBA (60 Hz).
const SHADER := preload("res://scripts/transitions/cave_transition.gdshader")
const INDICES := preload("res://graficos/transiciones/cueva_indices.png")
const OSCUROS := [0.0, 16.0, 32.0, 49.0, 65.0, 82.0, 98.0, 115.0]
const CLAROS := [131.0, 148.0, 164.0, 180.0, 197.0, 213.0, 230.0, 255.0]
const FRAMES_ENTRADA := 28
const FRAMES_SALIDA := 38


static func estado_frame(entrando: bool, frame: int) -> Dictionary:
	var paleta := PackedFloat32Array()
	paleta.resize(16)
	paleta.fill(1.0)
	var mezcla := 1.0
	var fondo := 0.0
	if entrando:
		if frame >= 2:
			var count := mini((frame - 2) * 2, 14)
			for i in range(count + 1):
				var origen := 15 - count + i
				paleta[i] = (OSCUROS[origen] if origen < 8 else CLAROS[origen - 8]) / 255.0
		if frame >= 11:
			mezcla = float(maxi(27 - frame, 0)) / 16.0
	else:
		for i in range(8):
			paleta[i] = CLAROS[i] / 255.0
		mezcla = clampf(float(frame - 2) / 16.0, 0.0, 1.0)
		if frame >= 20:
			var count := mini(frame - 20, 7)
			paleta.fill(1.0)
			for i in range(8 - count):
				paleta[i] = CLAROS[i + count] / 255.0
		if frame >= 28:
			fondo = 1.0
	return {"paleta": paleta, "mezcla": mezcla, "fondo": fondo}


func reproducir(entrando: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("indices", INDICES)
	material = shader_material
	var frames := FRAMES_ENTRADA if entrando else FRAMES_SALIDA
	_aplicar_frame(0.0, entrando)
	var tween := create_tween()
	tween.tween_method(_aplicar_frame.bind(entrando), 0.0, float(frames), float(frames) / 60.0)
	await tween.finished


func _aplicar_frame(frame: float, entrando: bool) -> void:
	var estado := estado_frame(entrando, int(frame))
	for parametro in estado:
		(material as ShaderMaterial).set_shader_parameter(parametro, estado[parametro])
