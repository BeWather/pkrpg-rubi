extends RefCounted
class_name TallerVidrio

## Precios de Route113_GlassWorkshop/scripts.inc (pokeruby).
const OBJETO_SACO := "SACOHOLLIN"
const BOLSILLO_CLAVE := 4
const CONTADOR_CENIZA := "ceniza_saco_hollin"
const BANDERA_SACO := "ruta_113_saco_entregado"
## VAR_GLASS_WORKSHOP_STATE 1 → 2: se activa al volver a entrar al taller con el saco ya entregado.
const BANDERA_REINGRESO := "ruta_113_taller_reingreso"
const RECETAS: Array[Dictionary] = [
	{"nombre": "FLAUTA AZUL", "objeto": "FLAUTAAZUL", "costo": 250},
	{"nombre": "FLAUTA AMARILLA", "objeto": "FLAMARILLA", "costo": 500},
	{"nombre": "FLAUTA ROJA", "objeto": "FLAUTAROJA", "costo": 500},
	{"nombre": "FLAUTA BLANCA", "objeto": "FLBLANCA", "costo": 1000},
	{"nombre": "FLAUTA NEGRA", "objeto": "FLAUTANEGRA", "costo": 1000},
	{"nombre": "SILLA BONITA", "objeto": "SILLA_BONITA", "costo": 6000, "decoracion": true, "decoracion_id": 13},
	{"nombre": "MESA BONITA", "objeto": "MESA_BONITA", "costo": 8000, "decoracion": true, "decoracion_id": 6},
]

var almacen: Object
var catalogo: Object
var decoraciones: SistemaBasesSecretas


func _init(p_almacen: Object, p_catalogo: Object, p_decoraciones: SistemaBasesSecretas = null) -> void:
	almacen = p_almacen
	catalogo = p_catalogo
	decoraciones = p_decoraciones


func tiene_saco() -> bool:
	return almacen.tiene_objeto(OBJETO_SACO, 1, BOLSILLO_CLAVE)


func saco_entregado() -> bool:
	return almacen.get_flag(BANDERA_SACO)

## Valida y setea la bandera de entrega del saco
func entregar_saco() -> bool:
	if tiene_saco():
		almacen.set_flag(BANDERA_SACO, true)
		return true
	if saco_entregado():
		return false
	if catalogo.obtener_datos_objeto(OBJETO_SACO).is_empty():
		return false
	var resultado: Dictionary = almacen.dar_objeto_jugador(OBJETO_SACO)
	if not bool(resultado.get("exito", false)):
		return false
	almacen.set_flag(BANDERA_SACO, true)
	return true


## Recién entregado el saco, el artesano repite las instrucciones hasta que el
## jugador sale del taller y vuelve a entrar.
func debe_repetir_instrucciones() -> bool:
	return saco_entregado() and not almacen.get_flag(BANDERA_REINGRESO)


## OnTransition del taller: llamar al entrar por un warp (no al cargar partida).
func registrar_entrada_taller() -> void:
	if debe_repetir_instrucciones():
		almacen.set_flag(BANDERA_REINGRESO, true)


func ceniza() -> int:
	return almacen.get_contador(CONTADOR_CENIZA)


func disponible(indice: int) -> bool:
	if indice < 0 or indice >= RECETAS.size():
		return false
	var receta: Dictionary = RECETAS[indice]
	if receta.get("decoracion", false):
		return _inventario_decoraciones() != null and not DatosBasesSecretas.decoracion(int(receta.decoracion_id)).is_empty()
	return not receta.get("decoracion", false) and not catalogo.obtener_datos_objeto(receta.objeto).is_empty()


func _inventario_decoraciones() -> SistemaBasesSecretas:
	# Resolver el servicio actual; nunca conservar el de una partida reemplazada.
	if almacen.has_method("get_bases_secretas"):
		return almacen.get_bases_secretas() as SistemaBasesSecretas
	return decoraciones


## No cobra si el premio no existe, el Saco no está o la entrega falla.
func canjear(indice: int) -> StringName:
	if not disponible(indice):
		return &"no_disponible"
	if not tiene_saco():
		return &"sin_saco"
	var receta: Dictionary = RECETAS[indice]
	if ceniza() < int(receta.costo):
		return &"ceniza_insuficiente"
	if receta.get("decoracion", false):
		var inventario: SistemaBasesSecretas = _inventario_decoraciones()
		if not inventario.es_compatible(): return &"version_incompatible"
		# Revalidación fresca y commit sin await: no cobrar hasta tener la copia.
		if inventario.agregar_decoracion(int(receta.decoracion_id)) < 0: return &"sin_espacio"
		almacen.set_contador(CONTADOR_CENIZA, ceniza() - int(receta.costo))
		return &"entregado"
	var resultado: Dictionary = almacen.dar_objeto_jugador(receta.objeto)
	if not bool(resultado.get("exito", false)):
		return &"sin_espacio"
	almacen.set_contador(CONTADOR_CENIZA, ceniza() - int(receta.costo))
	return &"entregado"
