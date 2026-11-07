extends Node

## Arranque directo de debug: ejecutar una escena de mapa con F6 entra al
## juego completo (AdministradorMapa + Overworld + datos de partida) sin pasar
## por las pantallas de intro, apareciendo en un tile marcado desde el editor.
##
## Al lanzar con F6 una escena suelta, los autoloads del proyecto se cargan
## igualmente, así que este nodo existe y puede guardar el "arranque pendiente"
## que AdministradorMapa consume en su _ready().
##
## El tile marcado se lee del nodo SpawnDebug del mapa (herramienta de editor)
## y llega aquí como parámetro.
##
## Prioridad del spawn al arrancar un mapa:
##   1) tile del nodo SpawnDebug del mapa
##   2) última posición guardada, solo si el guardado está en ese mismo mapa
##   3) (0, 0)

const ESCENA_PRINCIPAL: String = "res://escenas/administrador_mapa.tscn"

## Guardados candidatos, en orden de preferencia. res:// solo es escribible en
## debug/editor; user:// es la ruta de las partidas reales.
const RUTAS_GUARDADO := [
	"res://partida/partida_guardada.json",
	"user://partida_guardada.json",
]

## Arranque pendiente que AdministradorMapa consumirá en su _ready().
var _pendiente: Dictionary = {}

## Cuando está activo, la pantalla de inicio no debe arrancar su secuencia: en
## arranque directo el juego entra al mapa, y la intro seguiría sonando y
## reiniciándose por detrás (sus nodos hijos procesan aunque el Control esté
## oculto). Lo marca AdministradorMapa en su _enter_tree, que corre antes del
## _ready de la intro.
var _omitir_intro: bool = false


# ============================================================
# API ESTÁTICA — la comparten el runtime y el plugin del editor
# ============================================================

## Normaliza una clave de mapa: minúsculas y sin separadores, para que
## "Ruta 101", "ruta_101" y "RUTA-101" comparen igual.
static func normalizar_clave_mapa(valor: String) -> String:
	return valor.to_lower().replace("_", "").replace("-", "").replace(" ", "")

## Posición guardada, pero solo si pertenece al mapa indicado: si el guardado
## está en otro mapa, sus cx/cy no sirven como spawn de este.
static func obtener_posicion_guardada_para(mapa_key: String) -> Dictionary:
	var clave := normalizar_clave_mapa(mapa_key)
	for ruta in RUTAS_GUARDADO:
		if not FileAccess.file_exists(ruta):
			continue
		var archivo := FileAccess.open(ruta, FileAccess.READ)
		if archivo == null:
			continue
		var datos: Variant = JSON.parse_string(archivo.get_as_text())
		archivo.close()
		if not (datos is Dictionary):
			continue
		var posicion: Variant = datos.get("posicion", {})
		if not (posicion is Dictionary):
			continue
		if normalizar_clave_mapa(str(posicion.get("mapa_actual", ""))) != clave:
			continue
		return {
			"cx": int(posicion.get("cx", 0)),
			"cy": int(posicion.get("cy", 0)),
			"capa_datos": int(posicion.get("capa_datos", 0)),
		}
	return {}


# ============================================================
# API DE RUNTIME — MapaConfiguracion y AdministradorMapa
# ============================================================

## Marca que la pantalla de inicio debe quedarse inerte (arranque directo).
func marcar_omitir_intro() -> void:
	_omitir_intro = true


## ¿La pantalla de inicio debe omitirse? Sí mientras haya un arranque pendiente
## o alguien lo haya marcado explícitamente.
func debe_omitir_intro() -> bool:
	return _omitir_intro or tiene_arranque_pendiente()


## Resuelve el tile de spawn de un mapa y lo deja pendiente para que
## AdministradorMapa arranque ahí. Sin marca (hay_marca = false) se usa la
## última posición guardada si es de este mismo mapa; si no, el origen (0, 0).
func solicitar_arranque_en_mapa(mapa_key: String, hay_marca: bool, cx: int = 0, cy: int = 0, capa_datos: int = 0) -> void:
	var origen := "marcador SpawnDebug del mapa"
	if not hay_marca:
		var guardada := obtener_posicion_guardada_para(mapa_key)
		if guardada.is_empty():
			cx = 0
			cy = 0
			origen = "origen (0, 0) — añade un nodo SpawnDebug al mapa"
		else:
			cx = int(guardada.get("cx", 0))
			cy = int(guardada.get("cy", 0))
			capa_datos = int(guardada.get("capa_datos", capa_datos))
			origen = "última posición guardada de este mapa"
	_pendiente = {
		"mapa_actual": mapa_key,
		"cx": cx,
		"cy": cy,
		"capa_datos": capa_datos,
	}
	print("🐞 [DEBUG-SPAWN] Arranque directo en '%s' (%d, %d) · origen: %s" % [
		mapa_key, cx, cy, origen,
	])

## Deja el arranque pendiente y cambia a la escena principal del juego.
func arrancar_juego_en_mapa(mapa_key: String, hay_marca: bool, cx: int = 0, cy: int = 0) -> void:
	solicitar_arranque_en_mapa(mapa_key, hay_marca, cx, cy)
	get_tree().change_scene_to_file(ESCENA_PRINCIPAL)

func tiene_arranque_pendiente() -> bool:
	return not _pendiente.is_empty()

## Devuelve el arranque pendiente y lo limpia (un solo uso).
func tomar_arranque_pendiente() -> Dictionary:
	var copia := _pendiente.duplicate(true)
	_pendiente = {}
	return copia
