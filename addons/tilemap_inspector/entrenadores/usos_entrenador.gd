@tool
extends RefCounted

## Qué NPC de las escenas usan cada `entrenador_id`: recorre los `.tscn` y asocia
## cada `entrenador_id = N` al último `[node name="…"]` visto.
## Resultado: {id: ["ruta_117 › Isaac", …]}.

static func escanear(raiz: String = "res://escenas") -> Dictionary:
	var usos := {}
	_escanear_dir(raiz, usos)
	return usos


static func _escanear_dir(ruta: String, usos: Dictionary) -> void:
	var dir := DirAccess.open(ruta)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_escanear_dir(ruta.path_join(sub), usos)
	for archivo in dir.get_files():
		if archivo.ends_with(".tscn"):
			_escanear_escena(ruta.path_join(archivo), usos)


static func _escanear_escena(ruta: String, usos: Dictionary) -> void:
	var texto := FileAccess.get_file_as_string(ruta)
	if not texto.contains("entrenador_id"):
		return
	var escena := ruta.get_file().get_basename()
	var nodo := ""
	var es_raiz := false
	for linea in texto.split("\n"):
		if linea.begins_with("[node name=\""):
			nodo = linea.get_slice("\"", 1)
			# El nodo raíz (sin parent=) es la plantilla (p. ej. npc_entrenador.tscn):
			# su valor por defecto no es un uso real.
			es_raiz = not linea.contains(" parent=\"")
		elif linea.begins_with("entrenador_id = ") and not es_raiz:
			var id := int(linea.get_slice("=", 1).strip_edges())
			if id > 0:
				if not usos.has(id):
					usos[id] = []
				usos[id].append("%s › %s" % [escena, nodo])
