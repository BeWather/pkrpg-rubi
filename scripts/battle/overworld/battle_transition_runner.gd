extends RefCounted
class_name BattleTransitionRunner

## Ejecuta una secuencia de estilos (CatalogoTransicionesBatalla) sobre el
## overworld: cada paso es una escena TransicionBatalla dentro de una CanvasLayer
## propia en root. La capa del paso anterior se quita después de añadir la nueva,
## así nunca asoma un frame del mapa entre fases. Si el último paso termina en
## negro, la capa se queda puesta hasta que el llamador llame a liberar() (con la
## escena de batalla ya encima).

const CAPA_TRANSICION: int = 99

var _host: Node
var _capa_actual: CanvasLayer = null
var _cancelado: bool = false


func _init(host: Node) -> void:
	_host = host


func ejecutar(secuencia: PackedStringArray) -> bool:
	_cancelado = false
	var termina_en_negro := false
	for estilo in secuencia:
		if _cancelado or not is_instance_valid(_host) or not _host.is_inside_tree():
			liberar()
			return false
		if CatalogoTransicionesBatalla.NINGUNA.has(estilo):
			continue
		var transicion := _crear_paso(estilo)
		if transicion == null:
			liberar()
			return false
		transicion.iniciar()
		await transicion.terminada
		if _cancelado:
			liberar()
			return false
		termina_en_negro = transicion.termina_en_negro
	if not termina_en_negro:
		liberar()
	return true


func cancelar() -> void:
	_cancelado = true
	liberar()


## Quita la capa de transición que siga puesta (la negra del último paso).
func liberar() -> void:
	_quitar_capa(_capa_actual)
	_capa_actual = null


func tiene_capa() -> bool:
	return is_instance_valid(_capa_actual)


func _crear_paso(estilo: String) -> TransicionBatalla:
	var ruta := CatalogoTransicionesBatalla.ruta(estilo)
	if ruta.is_empty():
		push_error("[BATTLE_TRANSITION] Estilo desconocido: %s" % estilo)
		return null
	var escena := load(ruta) as PackedScene
	var transicion := escena.instantiate() as TransicionBatalla if escena != null else null
	if transicion == null:
		push_error("[BATTLE_TRANSITION] No se pudo instanciar la transición: %s" % ruta)
		return null
	var anterior := _capa_actual
	_capa_actual = CanvasLayer.new()
	_capa_actual.name = "CapaTransicion" + String(CatalogoTransicionesBatalla.resolver(estilo)).to_pascal_case()
	_capa_actual.layer = CAPA_TRANSICION
	_capa_actual.add_child(transicion)
	_host.get_tree().root.add_child(_capa_actual)
	_quitar_capa(anterior)
	return transicion


## Se saca del árbol en el acto (no se ve ni un frame más) y se libera al final del
## frame: puede llamarse desde la propia señal `terminada` de la capa.
func _quitar_capa(capa: CanvasLayer) -> void:
	if not is_instance_valid(capa):
		return
	if capa.get_parent() != null:
		capa.get_parent().remove_child(capa)
	capa.queue_free()
