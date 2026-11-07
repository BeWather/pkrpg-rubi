@tool
extends PanelContainer
class_name PokeSlotHorizontal

## Variante horizontal de PokeSlot: 280x70 px.
##
## La escena es deliberadamente independiente del controlador de equipos. El
## controlador externo decide qué hacer cuando recibe las señales de mover,
## agregar/editar o eliminar.

signal mover_arriba_solicitado
signal mover_abajo_solicitado
signal agregar_o_editar_solicitado
signal eliminar_confirmado
signal modificado

@onready var sprite_pokemon: TextureRect = $Contenido/MarcoSprite/SpritePokemon
@onready var etiqueta_nombre: Label = $Contenido/Informacion/Nombre
@onready var etiqueta_nivel: Label = $Contenido/Informacion/Nivel
@onready var etiqueta_ps: Label = $Contenido/Informacion/PS
@onready var etiqueta_estado: Label = $Contenido/Informacion/Estado
@onready var boton_arriba: Button = $Contenido/Acciones/Arriba
@onready var boton_abajo: Button = $Contenido/Acciones/Abajo
@onready var boton_agregar: Button = $Contenido/Acciones/Agregar
@onready var boton_quitar: Button = $Contenido/Acciones/Quitar
@onready var confirmacion_quitar: ConfirmationDialog = $ConfirmacionQuitar

var _entrada: Dictionary = {}
var _sincronizando := false
var _estilo_normal: StyleBoxFlat = null
var _estilo_foco: StyleBoxFlat = null


func _ready() -> void:
	boton_arriba.pressed.connect(func(): mover_arriba_solicitado.emit())
	boton_abajo.pressed.connect(func(): mover_abajo_solicitado.emit())
	boton_agregar.pressed.connect(func(): agregar_o_editar_solicitado.emit())
	boton_quitar.pressed.connect(_pedir_confirmacion_quitar)
	confirmacion_quitar.confirmed.connect(_confirmar_quitado)

	# Los textos de los botones del diálogo se personalizan aquí para no
	# depender de traducciones o de un Theme concreto.
	confirmacion_quitar.get_ok_button().text = "Quitar"
	confirmacion_quitar.get_cancel_button().text = "Cancelar"
	focus_entered.connect(_pintar_foco.bind(true))
	focus_exited.connect(_pintar_foco.bind(false))
	_actualizar_vista()


## Sincroniza el slot con un diccionario de datos.
##
## Claves admitidas:
## nombre_interno, nombre, mote, nivel, estad_ps_actual, estad_ps,
## ps_actual, ps_max, estado, estado_texto y shiny.
func establecer(entrada: Dictionary) -> void:
	_sincronizando = true
	_entrada = entrada.duplicate(true)
	_actualizar_vista()
	_sincronizando = false


## Atajo para alimentar el slot directamente desde un BasePokemon.
func establecer_pokemon(pokemon: BasePokemon) -> void:
	if pokemon == null:
		establecer({})
		return

	establecer({
		"nombre_interno": pokemon.nombre_interno,
		"nombre": pokemon.nombre,
		"mote": pokemon.mote,
		"nivel": pokemon.nivel,
		"estad_ps_actual": pokemon.estad_ps_actual,
		"estad_ps": pokemon.estad_ps,
		"estado": pokemon.estado,
		"shiny": pokemon.shiny,
	})


## Devuelve la entrada completa actualmente representada por el slot.
func entrada() -> Dictionary:
	return _entrada.duplicate(true)


func esta_vacio() -> bool:
	return _entrada.is_empty() or _nombre_interno().is_empty()


func _actualizar_vista() -> void:
	if not is_node_ready():
		return

	var vacio := esta_vacio()
	var nombre := _nombre_mostrable()

	etiqueta_nombre.text = "VACÍO" if vacio else nombre
	etiqueta_nivel.text = "Nv. —" if vacio else "Nv. %d" % int(_entrada.get("nivel", 1))
	etiqueta_ps.text = "PS —/—" if vacio else "PS %s/%s" % [_valor_ps_actual(), _valor_ps_maximo()]
	etiqueta_estado.text = "ESTADO —" if vacio else "ESTADO %s" % _texto_estado()

	boton_arriba.disabled = vacio
	boton_abajo.disabled = vacio
	boton_quitar.disabled = vacio
	boton_agregar.tooltip_text = "Agregar Pokémon en este slot" if vacio else "Editar Pokémon de este slot"

	if vacio:
		sprite_pokemon.texture = null
	else:
		_cargar_sprite()


func _nombre_interno() -> String:
	return str(_entrada.get("nombre_interno", "")).strip_edges().to_upper()


func _nombre_mostrable() -> String:
	var mote := str(_entrada.get("mote", "")).strip_edges()
	if not mote.is_empty():
		return mote.to_upper()
	var nombre := str(_entrada.get("nombre", "")).strip_edges()
	return nombre.to_upper() if not nombre.is_empty() else _nombre_interno()


func _valor_ps_actual() -> String:
	if _entrada.has("ps_actual"):
		return str(_entrada["ps_actual"])
	if _entrada.has("ps_actuales"):
		return str(_entrada["ps_actuales"])
	return str(_entrada.get("estad_ps_actual", "—"))


func _valor_ps_maximo() -> String:
	if _entrada.has("ps_max"):
		return str(_entrada["ps_max"])
	return str(_entrada.get("estad_ps", "—"))


func _texto_estado() -> String:
	if _entrada.has("estado_texto"):
		return str(_entrada["estado_texto"]).to_upper()

	# Dos escalas conviven: "estado" usa ProblemaEstado del singleton (-1
	# saludable, 0 debilitado); "estado_primario" usa la escala de la BBDD
	# (0 = sin estado, 1..6 identicos a ProblemaEstado) y el debilitado se
	# deduce de que los PS actuales sean 0.
	var estado: Variant
	if _entrada.has("estado"):
		estado = _entrada["estado"]
	elif _entrada.has("estado_primario"):
		var primario: int = int(_entrada["estado_primario"])
		if primario > 0:
			estado = primario
		else:
			estado = 0 if _valor_ps_actual() == "0" else -1
	else:
		estado = -1
	if estado is String:
		return estado.to_upper()

	var nombres := {
		-1: "SALUDABLE",
		0: "DEBILITADO",
		1: "ENVENENADO",
		2: "CONGELADO",
		3: "QUEMADO",
		4: "PARALIZADO",
		5: "DORMIDO",
		6: "POKERUS",
	}
	return str(nombres.get(int(estado), "NORMAL"))


func _cargar_sprite() -> void:
	var nombre := _nombre_interno()
	if nombre.is_empty():
		sprite_pokemon.texture = null
		return

	var es_shiny := bool(_entrada.get("shiny", int(_entrada.get("es_shiny", 0)) == 1))
	# Si la entrada trae personalidad, el frente de SPINDA lleva sus manchas.
	var personalidad := int(_entrada.get("personalidad", -1))
	sprite_pokemon.texture = PokemonSpriteManager.cargar_sprite_frente(nombre, es_shiny, personalidad)


func _pedir_confirmacion_quitar() -> void:
	if esta_vacio():
		return
	confirmacion_quitar.dialog_text = "¿Quitar a %s de este slot?" % _nombre_mostrable()
	confirmacion_quitar.popup_centered()


func _confirmar_quitado() -> void:
	_entrada = {}
	_actualizar_vista()
	eliminar_confirmado.emit()
	modificado.emit()


## Disponibilidad de acciones decidida por el controlador de la lista (sin
## huecos: mover solo dentro de la zona ocupada; '+' en ocupados para editar y
## en el primer vacio para agregar). Llamar SIEMPRE despues de establecer().
func configurar_acciones(puede_subir: bool, puede_bajar: bool, puede_agregar: bool) -> void:
	var vacio := esta_vacio()
	boton_arriba.disabled = vacio or not puede_subir
	boton_abajo.disabled = vacio or not puede_bajar
	boton_quitar.disabled = vacio
	boton_agregar.disabled = not puede_agregar


## Teclado con el slot enfocado: flechas mueven, Enter agrega/edita y Supr
## quita (mismas acciones que los 4 botones). Click izquierdo toma el foco.
func _gui_input(evento: InputEvent) -> void:
	var raton := evento as InputEventMouseButton
	if raton != null and raton.pressed and raton.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		return
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_UP:
			accept_event()
			if not boton_arriba.disabled:
				mover_arriba_solicitado.emit()
		KEY_DOWN:
			accept_event()
			if not boton_abajo.disabled:
				mover_abajo_solicitado.emit()
		KEY_ENTER, KEY_KP_ENTER:
			accept_event()
			if not boton_agregar.disabled:
				agregar_o_editar_solicitado.emit()
		KEY_DELETE:
			accept_event()
			if not boton_quitar.disabled:
				_pedir_confirmacion_quitar()


func _pintar_foco(activo: bool) -> void:
	if _estilo_normal == null:
		_estilo_normal = get_theme_stylebox("panel") as StyleBoxFlat
		if _estilo_normal == null:
			return
		_estilo_foco = _estilo_normal.duplicate() as StyleBoxFlat
		_estilo_foco.border_color = Color(0.55, 0.95, 0.7, 1)
	add_theme_stylebox_override("panel", _estilo_foco if activo else _estilo_normal)
