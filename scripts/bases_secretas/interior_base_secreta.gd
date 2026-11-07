@tool
extends MapaConfiguracion
class_name InteriorBaseSecreta

## La escena declara compositor/salida. El administrador prepara antes de add_child.
@export var interior_id: int = -1
@export var mapa_decoracion: MapaDecoracion

var sistema: SistemaBasesSecretas  # Inyección opcional para tests; servicio perezoso en juego.
var _contexto: Dictionary = {}
var _llegada_registrada: bool = false
var _preview_activa: bool = false
var _recogida_activa: bool = false
const MOTIVO_PAUSA: StringName = &"bases_secretas"


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		mapa_activado.connect(_al_activar)


func preparar_entrada(contexto: Dictionary) -> bool:
	if sistema == null:
		sistema = SistemaGuardado.get_bases_secretas()
	var validado: Dictionary = ContextoBaseSecreta.validar(contexto, interior_id, sistema)
	if validado.is_empty() or mapa_decoracion == null or mapa_decoracion.interior_id != interior_id:
		return false
	var colocaciones: Array[Dictionary] = []
	if not bool(validado["vista_previa"]):
		colocaciones = sistema.obtener_colocaciones()
	if mapa_decoracion.recomponer(colocaciones) != &"exito":
		return false
	_contexto = validado.duplicate(true)
	_llegada_registrada = false
	mapa_exterior_asociado = str(_contexto["retorno"]["mapa_actual"])
	return true


func obtener_contexto() -> Dictionary:
	return _contexto.duplicate(true)


func es_vista_previa() -> bool:
	return bool(_contexto.get("vista_previa", false))


func control_bloqueado() -> bool:
	return _contexto.is_empty() or es_vista_previa()


func bloquea_menu() -> bool:
	return control_bloqueado() or pc_activo()


func pc_activo() -> bool:
	var pc: PCBaseSecreta = get_node_or_null("PC") as PCBaseSecreta
	return pc != null and pc.activa


func permite_guardar() -> bool:
	return not _contexto.is_empty() and not es_vista_previa() and not _preview_activa \
		and not _recogida_activa and not pc_activo() and sistema != null and sistema.id_base() == int(_contexto.get("entrada_id", 0))


func obtener_nombre_lugar() -> String:
	if sistema == null or es_vista_previa():
		return super.obtener_nombre_lugar()
	var propietario: Dictionary = sistema.obtener_base().get("propietario", {})
	if str(propietario.get("nombre", "")).is_empty():
		return super.obtener_nombre_lugar()
	return DatosCicloBaseSecreta.texto("BASES_NOMBRE_PROPIETARIO").format(
		{"nombre": str(propietario.get("nombre", ""))})


func aceptar_vista_previa(propietario: Dictionary) -> bool:
	if not es_vista_previa() or sistema == null or sistema.tiene_base():
		return false
	if sistema.establecer_base(int(_contexto["entrada_id"]), propietario) != &"exito":
		return false
	_contexto["vista_previa"] = false
	sistema.registrar_retorno(_contexto["retorno"])
	return true


func presentar_vista_previa(administrador: Node) -> void:
	if not es_vista_previa() or _preview_activa or administrador.get("dialogo_bases") == null:
		return
	_preview_activa = true
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var jugador: Node2D = administrador.get("jugador") as Node2D
	jugador.set("no_control", true)
	# SecretBase_EventScript_FirstEntrance: dos pasos al norte antes de preguntar.
	if jugador.has_method("caminar_guion"):
		await jugador.call("caminar_guion", Vector2.UP)
		await jugador.call("caminar_guion", Vector2.UP)
	var dialogo: Node = administrador.get("dialogo_bases") as Node
	var aceptar: bool = await dialogo.call("preguntar", DatosCicloBaseSecreta.texto("BASES_ESTABLECER"))
	if aceptar:
		administrador.call("confirmar_base_secreta", self)
	else:
		solicitar_salida(administrador)
	_preview_activa = false
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if int(administrador.get("coneccion")) == 0:
		jugador.set("no_control", false)


func _exit_tree() -> void:
	if (_preview_activa or _recogida_activa) and not Engine.is_editor_hint():
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)


## Secuencia original de PCPackUp, compartida por el menú PC.
func solicitar_recogida(administrador: Node) -> bool:
	if _recogida_activa or _preview_activa or es_vista_previa() or _contexto.is_empty() \
		or administrador == null or administrador.get("mapa_actual") != self \
		or int(administrador.get("coneccion")) != 0 or administrador.get("dialogo_bases") == null \
		or sistema == null or not sistema.es_compatible() or sistema.id_base() != int(_contexto["entrada_id"]):
		return false
	_recogida_activa = true
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var jugador: Node2D = administrador.get("jugador") as Node2D
	jugador.set("no_control", true)
	var dialogo: Node = administrador.get("dialogo_bases") as Node
	var recogida: bool = false
	if await dialogo.call("preguntar", DatosCicloBaseSecreta.texto("BASES_RECOGER_CONFIRMAR")):
		recogida = bool(administrador.call("recoger_base_secreta", self))
	_recogida_activa = false
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if int(administrador.get("coneccion")) == 0:
		jugador.set("no_control", false)
	return recogida


## La salida sigue siendo posible después de recoger la base (retorno volátil propio).
func solicitar_salida(administrador: Node) -> bool:
	if pc_activo() and not _recogida_activa:
		return false
	if _contexto.is_empty() or administrador == null or not administrador.has_method("salir_base_secreta"):
		return false
	return bool(administrador.call("salir_base_secreta", self, _contexto["retorno"].duplicate(true)))


func _al_activar(por_warp: bool) -> void:
	if not por_warp or _llegada_registrada or _contexto.is_empty() or es_vista_previa():
		return
	# Contar solo llegada efectiva: preparar/precargar no cambia el guardado.
	if sistema.registrar_retorno(_contexto["retorno"]):
		sistema.registrar_visita()
		_llegada_registrada = true
