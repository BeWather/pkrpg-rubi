extends RefCounted
class_name RegaloMT43

const RECIBIDO: String = "FLAG_RECEIVED_SECRET_POWER"
const OCULTAR: String = "FLAG_HIDE_SECRET_POWER_MAN"
const VENDEDOR: String = "FLAG_HIDE_TM_SALESMAN_SLATEPORT"
const DATOS: String = "res://BaseDatos/bases_secretas/regalo_mt43.json"
static var _datos: Dictionary = {}


static func datos() -> Dictionary:
	if _datos.is_empty():
		var valor: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
		if valor is Dictionary: _datos = valor
	return _datos.duplicate(true)


static func recibido() -> bool:
	return SistemaGuardado.get_flag(RECIBIDO) or SistemaGuardado.get_flag(OCULTAR)


## Ausencia en guardados antiguos equivale al setflag de new_game.inc, sin migrarlos.
static func vendedor_habilitado() -> bool:
	return not bool(SistemaGuardado.datos_vivos.datos_persistentes.banderas.get(VENDEDOR, true))


## false sólo con datos malformados: a diferencia de Ruby no se comprueba si la
## mochila está llena.
static func cabe() -> bool:
	if DatosMT43.maquina().is_empty(): return false
	var mochila: Dictionary = SistemaGuardado.datos_vivos.mochila
	var bolsillos: Variant = mochila.get("bolsillos")
	if not bolsillos is Dictionary: return false
	var bolsillo: Variant = bolsillos.get(str(DatosMT43.BOLSILLO))
	if not bolsillo is Dictionary: return false
	var items: Variant = bolsillo.get("items")
	if not items is Array: return false
	var nombres: Dictionary = {}
	for item: Variant in items:
		if not item is Dictionary: return false
		var nombre: String = str(item.get("nombre_interno", ""))
		var numero: Variant = item.get("cantidad", 0)
		if nombre.is_empty() or nombres.has(nombre) or not (numero is int or numero is float) \
			or float(numero) != floor(float(numero)) or numero < 1: return false
		nombres[nombre] = true
	return true


## Sin await: entrega única y banderas juntas. No modifica el servicio general.
static func entregar(partida: EstructuraGuardado) -> bool:
	if partida != SistemaGuardado.datos_vivos or recibido() or not cabe(): return false
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(DatosMT43.OBJETO, 1)
	if not bool(resultado.get("exito", false)): return false
	SistemaGuardado.set_flag(RECIBIDO, true)
	SistemaGuardado.set_flag(VENDEDOR, false)
	# Persistir retirada junto al regalo; el NPC permanece visible en su sesión actual.
	SistemaGuardado.set_flag(OCULTAR, true)
	return true


static func retirada(frente: Vector2) -> Array[Vector2i]:
	var etiqueta: String = "Route111_Movement_1A38EF" if frente == Vector2.UP else "Route111_Movement_1A38E3"
	if frente == Vector2.DOWN: return [] # VAR_FACING=1: removeobject sin movimiento.
	var resultado: Array[Vector2i] = []
	for paso: String in datos().get("retirada", {}).get(etiqueta, []):
		resultado.append(Vector2i.DOWN if paso == "down" else Vector2i.LEFT)
	return resultado


static func texto(clave: String) -> String:
	var texto: String = str(TranslationServer.translate(clave))
	if texto == clave:
		texto = ""
		for registro: Dictionary in datos().get("textos", []):
			if str(registro["clave"]) == clave: texto = str(registro["texto_es"])
	var ingles: bool = TranslationServer.get_locale().begins_with("en")
	return texto.replace("\\n", "\n").replace("{jugador}", str(SistemaGuardado.datos_vivos.jugador.get("nombre", ""))) \
		.replace("{objeto}", "TM43" if ingles else "MT43").replace("{bolsillo}", texto("MT43_REGALO_BOLSILLO") if clave != "MT43_REGALO_BOLSILLO" else "")
