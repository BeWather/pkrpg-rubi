class_name DatosTiendaDecoracion
extends RefCounted

## Tiendas de decoración de Rubí (`pokemartdecoration`, pokeruby `src/shop.c`). Los datos viven en
## `BaseDatos/tiendas_decoracion.json` (qué vende cada dependiente); nombre, descripción,
## categoría y precio salen del catálogo de bases secretas (`DatosBasesSecretas`,
## `DatosTextosDecoracion`), que ya trae `gDecorations` entero. El guion es `TiendaDecoracionNpc`
## y la pantalla `CompraDecoracionUI`.

const RUTA_TABLA: String = "res://BaseDatos/tiendas_decoracion.json"
## Claves de `BaseDatos/dialogos.csv` (es + en).
const TEXTO_SALUDO: String = "DECORACION_TIENDA_SALUDO"
const TEXTO_DESPEDIDA: String = "DECORACION_TIENDA_DESPEDIDA"
const TEXTO_CONFIRMAR: String = "DECORACION_TIENDA_CONFIRMAR"
const TEXTO_GRACIAS: String = "DECORACION_TIENDA_GRACIAS"
const TEXTO_SIN_DINERO: String = "DECORACION_TIENDA_SIN_DINERO"
const TEXTO_SIN_SITIO: String = "DECORACION_TIENDA_SIN_SITIO"
const TEXTOS: PackedStringArray = [
	TEXTO_SALUDO, TEXTO_DESPEDIDA, TEXTO_CONFIRMAR, TEXTO_GRACIAS, TEXTO_SIN_DINERO, TEXTO_SIN_SITIO,
]

static var _tabla: Dictionary = {}
static var _cargada: bool = false


## Todas las tiendas: id -> datos.
static func todas() -> Dictionary:
	_cargar()
	return _tabla


## Datos de la tienda `id` ("ARBORADA_MESAS"...), o {} si no existe.
static func obtener(id: String) -> Dictionary:
	_cargar()
	return _tabla.get(id, {}) as Dictionary


## Ids de decoración que vende la tienda `id`, en el orden de Rubí ([] si no existe).
static func decoraciones(id: String) -> Array[int]:
	var resultado: Array[int] = []
	for decoracion_id: Variant in obtener(id).get("decoraciones", []):
		resultado.append(int(decoracion_id))
	return resultado


## Fuerza la relectura del JSON (pruebas).
static func recargar() -> void:
	_cargada = false
	_tabla = {}


## Lo que enseña la lista de la tienda de una decoración: id, nombre, descripción, categoría y
## precio (`gDecorations`). {} si el id no está en el catálogo.
static func detalle(decoracion_id: int) -> Dictionary:
	var datos: Dictionary = DatosBasesSecretas.decoracion(decoracion_id)
	if datos.is_empty():
		return {}
	return {
		"id": decoracion_id,
		"nombre": DatosBasesSecretas.nombre_decoracion(decoracion_id),
		"descripcion": DatosBasesSecretas.descripcion_decoracion(decoracion_id),
		"categoria": StringName(str(datos["categoria"])),
		"precio": int(datos["precio"]),
	}


## Precio con la moneda del proyecto: «3.000$» en español, «$3,000» en inglés.
static func formatear_precio(precio: int) -> String:
	var ingles: bool = TranslationServer.get_locale().begins_with("en")
	var separador: String = "," if ingles else "."
	var digitos: String = str(precio)
	var agrupado: String = ""
	for i: int in digitos.length():
		if i > 0 and (digitos.length() - i) % 3 == 0:
			agrupado += separador
		agrupado += digitos[i]
	return "$" + agrupado if ingles else agrupado + "$"


## Marcadores de los textos de la compra: {decoracion} (nombre) y {precio} (ya con la moneda).
static func reemplazos(decoracion_id: int) -> Dictionary:
	var datos: Dictionary = detalle(decoracion_id)
	return {
		"{decoracion}": str(datos.get("nombre", "")),
		"{precio}": formatear_precio(int(datos.get("precio", 0))),
	}


## `tr(clave)` con los marcadores sustituidos.
static func texto(clave: String, sustituciones: Dictionary = {}) -> String:
	var resultado: String = TranslationServer.translate(clave)
	for marcador: Variant in sustituciones:
		resultado = resultado.replace(str(marcador), str(sustituciones[marcador]))
	return resultado


static func _cargar() -> void:
	if _cargada:
		return
	_cargada = true
	var archivo: FileAccess = FileAccess.open(RUTA_TABLA, FileAccess.READ)
	if archivo == null:
		push_error("[DatosTiendaDecoracion] No se pudo abrir %s" % RUTA_TABLA)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if not datos is Dictionary or int(datos.get("version", -1)) != 1 or not datos.get("tiendas") is Dictionary:
		push_error("[DatosTiendaDecoracion] Tabla inválida: %s" % RUTA_TABLA)
		return
	_tabla = (datos["tiendas"] as Dictionary).duplicate(true)
