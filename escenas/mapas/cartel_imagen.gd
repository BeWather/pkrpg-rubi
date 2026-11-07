@tool
extends Signpost
class_name CartelImagen

## Cartel sin texto: al accionarlo muestra `imagen` dentro del borde de menú de
## las opciones (VisorImagenCartel). Mientras está abierta el juego queda en
## pausa; se cierra con acción o cancelar.
##
## Las inscripciones en braille (`braillemessage` de pokeruby) son láminas del
## tamaño de su ventana: una de 240x160 ocupa la pantalla y una menor se coloca
## en `celda_ventana` (winLeft, winTop en celdas de 8 px). Con alguna condición de
## `textos_condicionales` cumplida (CondicionTexto) se muestra ese texto en vez de
## la lámina, como el `goto_if_set ..., msgbox` previo de los grabados de las
## cámaras de los REGI ("Hay un gran agujero en la pared.").

const MOTIVO_PAUSA := &"cartel_imagen"

## Emitida con el visor recién abierto (p. ej. la espera de la CUEVA INSULAR).
signal visor_abierto(visor: VisorImagenCartel)
## Emitida al cerrarse el visor.
signal visor_cerrado

@export var imagen: Texture2D
## Esquina superior izquierda de la ventana, en celdas de 8 px de la pantalla.
@export var celda_ventana: Vector2i = Vector2i.ZERO
## {condición: id_texto} que sustituye a la lámina (ver CondicionTexto).
@export var textos_condicionales: Dictionary[String, String] = {}

var _visor: VisorImagenCartel = null


func accionar_cartel() -> void:
	if _visor != null or imagen == null:
		return
	var texto := CondicionTexto.resolver(textos_condicionales, "")
	if not texto.is_empty():
		Singleton.mostrar_texto(tr(texto))
		return
	var nodo_ui := Singleton.obtener_nodo("Menu")
	if nodo_ui == null:
		return
	# Pausa propia: el administrador libera la del cartel en cuanto ve que no hay
	# cuadro de diálogo, y esta mantiene bloqueado al jugador mientras se mira.
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	_visor = VisorImagenCartel.new()
	_visor.configurar(imagen, Vector2(celda_ventana * 8))
	_visor.cerrado.connect(_on_visor_cerrado)
	nodo_ui.add_child(_visor)
	visor_abierto.emit(_visor)


func visor_actual() -> VisorImagenCartel:
	return _visor


func _on_visor_cerrado() -> void:
	_visor = null
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	visor_cerrado.emit()
	var admin = Singleton.obtener_nodo("Admin")
	if admin == null:
		return
	# La tecla con la que se cerró no debe volver a abrir el cartel.
	admin.debe_soltar_tecla_accion = true
	var jugador = admin.jugador
	if jugador != null and not admin.esta_pausado():
		jugador.no_control = false
