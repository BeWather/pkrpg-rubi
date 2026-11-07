@tool
## Acceso de lectura/escritura a BaseDatos/dialogos.csv (fuente de los textos de
## diálogo del juego, columnas id,es,en). No es autoload: en contexto @tool los
## editores lo usan vía preload, igual que otras herramientas de este addon.
class_name DialogosCSV
extends RefCounted

const RUTA_CSV := "res://BaseDatos/dialogos.csv"

## Devuelve {"orden": Array[String] (ids en orden del archivo), "filas": Dictionary (id -> {"es": String, "en": String})}.
static func cargar() -> Dictionary:
	var orden: Array[String] = []
	var filas: Dictionary = {}
	var archivo := FileAccess.open(RUTA_CSV, FileAccess.READ)
	if archivo == null:
		return {"orden": orden, "filas": filas}

	archivo.get_csv_line(",")  # descarta la fila de encabezado "id,es,en"
	# get_csv_line respeta comillas y comas embebidas; un split manual rompería
	# filas como CARTEL_VILLA_RAIZ_NOTAS (comillas escapadas, \p \l \n literales).
	while not archivo.eof_reached():
		var linea := archivo.get_csv_line(",")
		if linea.is_empty() or linea[0] == "":
			continue
		var id: String = linea[0]
		orden.append(id)
		filas[id] = {
			"es": linea[1] if linea.size() > 1 else "",
			"en": linea[2] if linea.size() > 2 else "",
		}
	archivo.close()
	return {"orden": orden, "filas": filas}

static func existe_clave(id: String) -> bool:
	if id.is_empty():
		return false
	return cargar()["filas"].has(id)

static func obtener_fila(id: String) -> Dictionary:
	return cargar()["filas"].get(id, {})

## Actualiza la fila de [param id] (o la agrega al final si es nueva) y reescribe el CSV completo.
static func guardar_fila(id: String, es: String, en: String) -> void:
	var tabla := cargar()
	var orden: Array = tabla["orden"]
	var filas: Dictionary = tabla["filas"]
	if not filas.has(id):
		orden.append(id)
	filas[id] = {"es": es, "en": en}

	var archivo := FileAccess.open(RUTA_CSV, FileAccess.WRITE)
	archivo.store_line("id,es,en")
	for clave in orden:
		var fila: Dictionary = filas[clave]
		archivo.store_line("%s,%s,%s" % [
			_csv_campo(clave),
			_csv_campo(String(fila.get("es", ""))),
			_csv_campo(String(fila.get("en", ""))),
		])
	archivo.close()

	# El importador csv_translation no detecta el cambio por sí solo desde
	# @tool; hay que forzar el reimport para que dialogos.es/en.translation
	# reflejen el nuevo contenido sin reabrir el proyecto.
	EditorInterface.get_resource_filesystem().reimport_files([RUTA_CSV])

static func _csv_campo(valor: String) -> String:
	if valor.find(",") != -1 or valor.find("\"") != -1 or valor.find("\n") != -1:
		return "\"%s\"" % valor.replace("\"", "\"\"")
	return valor

## Ids cuyo id, es o en contengan [param texto] (sin distinguir mayúsculas). Texto vacío devuelve todos.
static func buscar(texto: String) -> Array:
	var filtro := texto.to_lower()
	var tabla := cargar()
	var orden: Array = tabla["orden"]
	var filas: Dictionary = tabla["filas"]
	if filtro.is_empty():
		return orden.duplicate()
	var resultado: Array = []
	for id in orden:
		var fila: Dictionary = filas[id]
		if id.to_lower().find(filtro) != -1 \
				or String(fila.get("es", "")).to_lower().find(filtro) != -1 \
				or String(fila.get("en", "")).to_lower().find(filtro) != -1:
			resultado.append(id)
	return resultado
