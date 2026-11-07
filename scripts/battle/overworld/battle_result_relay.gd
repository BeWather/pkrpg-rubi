extends RefCounted
class_name BattleResultRelay

signal resuelto(ejecucion: ResultadoEjecucionBatalla)

var _resuelto: bool = false
var _ejecucion: ResultadoEjecucionBatalla = null


func recibir_resultado(resultado: ResultadoBatalla.Valor) -> void:
	_resolver(ResultadoEjecucionBatalla.completada(resultado))


func escena_salida_inesperadamente() -> void:
	_resolver(ResultadoEjecucionBatalla.rechazada(
		&"escena_interrumpida",
		"La escena de batalla salió del árbol antes de informar un resultado."
	))


func rechazar(codigo: StringName, mensaje: String) -> void:
	_resolver(ResultadoEjecucionBatalla.rechazada(codigo, mensaje))


func esta_resuelto() -> bool:
	return _resuelto


func esperar() -> ResultadoEjecucionBatalla:
	if _resuelto:
		return _ejecucion
	return await resuelto


func _resolver(ejecucion: ResultadoEjecucionBatalla) -> void:
	if _resuelto:
		push_warning("[BATTLE_RELAY] Se ignoró una segunda finalización de la misma sesión")
		return
	_resuelto = true
	_ejecucion = ejecucion
	resuelto.emit(ejecucion)
