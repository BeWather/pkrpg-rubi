extends RefCounted
class_name ResultadoEjecucionBatalla

enum Estado {
	COMPLETADA,
	RECHAZADA,
}

var estado: Estado = Estado.RECHAZADA
var resultado: Variant = null
var codigo_error: StringName = &""
var mensaje_error: String = ""


static func completada(resultado_batalla: ResultadoBatalla.Valor) -> ResultadoEjecucionBatalla:
	var ejecucion := ResultadoEjecucionBatalla.new()
	ejecucion.estado = Estado.COMPLETADA
	ejecucion.resultado = resultado_batalla
	return ejecucion


static func rechazada(codigo: StringName, mensaje: String) -> ResultadoEjecucionBatalla:
	var ejecucion := ResultadoEjecucionBatalla.new()
	ejecucion.estado = Estado.RECHAZADA
	ejecucion.codigo_error = codigo
	ejecucion.mensaje_error = mensaje
	return ejecucion


func fue_completada() -> bool:
	return estado == Estado.COMPLETADA


func fue_rechazada() -> bool:
	return estado == Estado.RECHAZADA
