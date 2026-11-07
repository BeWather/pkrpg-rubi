extends NinePatchRect
class_name CuadroSubirNivel

signal vista_actualizada(estado: EstadoVista)
signal cuadro_cerrado

enum EstadoVista {
	OCULTO,
	INCREMENTOS,
	TOTALES
}

const POSICION_DEFAULT := Vector2(88, 0)

@onready var valor_ps: Label = $ps
@onready var valor_ataque: Label = $ataque
@onready var valor_defensa: Label = $defensa
@onready var valor_ataque_especial: Label = $at_esp
@onready var valor_defensa_especial: Label = $df_esp
@onready var valor_velocidad: Label = $veloc

var estado_actual: EstadoVista = EstadoVista.OCULTO
var stats_antes: Dictionary = {}
var stats_despues: Dictionary = {}

func _ready() -> void:
	visible = false
	position = POSICION_DEFAULT
	_aplicar_textura_marco()

## Marco elegido en Opciones (menu_box_N). Se mantiene el modo de relleno en mosaico
## de la escena (tile fit): el cuadro tiene tamaño fijo, nunca se estira.
func _aplicar_textura_marco() -> void:
	var tipo := 1
	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		tipo = int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	MenuBoxManager.apply_texture_to_ninepatch(self, tipo)

func mostrar_subida(stats_previos: Dictionary, stats_actuales: Dictionary) -> void:
	stats_antes = stats_previos.duplicate(true)
	stats_despues = stats_actuales.duplicate(true)
	visible = true
	position = POSICION_DEFAULT
	_mostrar_incrementos()

func avanzar_estado() -> void:
	match estado_actual:
		EstadoVista.INCREMENTOS:
			_mostrar_totales()
		EstadoVista.TOTALES:
			ocultar()
		_:
			pass

func ocultar() -> void:
	visible = false
	estado_actual = EstadoVista.OCULTO
	cuadro_cerrado.emit()

func esta_activo() -> bool:
	return visible and estado_actual != EstadoVista.OCULTO

func _mostrar_incrementos() -> void:
	_asignar_valor(valor_ps, _formatear_incremento(_obtener_incremento("ps")))
	_asignar_valor(valor_ataque, _formatear_incremento(_obtener_incremento("ataque")))
	_asignar_valor(valor_defensa, _formatear_incremento(_obtener_incremento("defensa")))
	_asignar_valor(valor_ataque_especial, _formatear_incremento(_obtener_incremento("ataque_especial")))
	_asignar_valor(valor_defensa_especial, _formatear_incremento(_obtener_incremento("defensa_especial")))
	_asignar_valor(valor_velocidad, _formatear_incremento(_obtener_incremento("velocidad")))
	estado_actual = EstadoVista.INCREMENTOS
	vista_actualizada.emit(estado_actual)

func _mostrar_totales() -> void:
	_asignar_valor(valor_ps, str(int(stats_despues.get("ps", 0))))
	_asignar_valor(valor_ataque, str(int(stats_despues.get("ataque", 0))))
	_asignar_valor(valor_defensa, str(int(stats_despues.get("defensa", 0))))
	_asignar_valor(valor_ataque_especial, str(int(stats_despues.get("ataque_especial", 0))))
	_asignar_valor(valor_defensa_especial, str(int(stats_despues.get("defensa_especial", 0))))
	_asignar_valor(valor_velocidad, str(int(stats_despues.get("velocidad", 0))))
	estado_actual = EstadoVista.TOTALES
	vista_actualizada.emit(estado_actual)

func _obtener_incremento(clave: String) -> int:
	return int(stats_despues.get(clave, 0)) - int(stats_antes.get(clave, 0))

func _formatear_incremento(incremento: int) -> String:
	var magnitud = abs(incremento)
	var signo = "+" if incremento >= 0 else "-"
	if magnitud < 10:
		return "%s %d" % [signo, magnitud]
	return "%s%d" % [signo, magnitud]

func _asignar_valor(label: Label, valor: String) -> void:
	if label != null:
		label.text = valor