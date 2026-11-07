extends Node2D

# Señales
signal ficha_cerrada

# No usar @onready para nodo_raiz - lo inicializaremos manualmente
var nodo_raiz: Node2D = null
@onready var nd_ficha_frente = $"ficha-frente"
@onready var nd_ficha_reverso = $"ficha-reverso"
@onready var nd_fe_fondo = $"Fe-fondo"
@onready var nd_ma_fondo = $"Ma-fondo"
@onready var lb_id = $"ficha-frente/id"
@onready var lb_nombre = $"ficha-frente/nombre"
@onready var lb_dinero = $"ficha-frente/dinero"
@onready var lb_num_poke = $"ficha-frente/num-poke" # Ensure this path matches your scene tree exactly
@onready var lb_tiempo = $"ficha-frente/tiempo"
@onready var nd_medalla0 = $"ficha-frente/medalla0"
@onready var nd_medalla1 = $"ficha-frente/medalla1"
@onready var nd_medalla2 = $"ficha-frente/medalla2"
@onready var nd_medalla3 = $"ficha-frente/medalla3"
@onready var nd_medalla4 = $"ficha-frente/medalla4"
@onready var nd_medalla5 = $"ficha-frente/medalla5"
@onready var nd_medalla6 = $"ficha-frente/medalla6"
@onready var nd_medalla7 = $"ficha-frente/medalla7"
@onready var nd_avatar = $"ficha-frente/avatar"

@onready var tween: Tween

# Variables para controlar la ficha
var is_flipped = false
var is_animating = false
var original_position: Vector2
var sprite_width: float

# Duración de la animación (en segundos)
@export var flip_duration = 0.6
@export var ease_type = Tween.EASE_OUT
@export var transition_type = Tween.TRANS_BACK
@export var animacion_vertical: bool = false

var nombre: String
var seconds: int = 0

func _ready():
	print("🔍 [FICHA] Ready...")
	visible = false
	# Crear timer local de 1s para actualizar visualización de tiempo y reducir carga en _process
	var t = Timer.new()
	t.wait_time = 1.0
	t.one_shot = false
	add_child(t)
	t.connect("timeout", Callable(self, "_on_time_tick"))
	t.start()

func _process(_delta: float):
	# No hacemos trabajo pesado aquí; usamos timer local de 1s para actualizar el tiempo.
	pass


func _on_time_tick() -> void:
	# Cada segundo: leer tiempo desde SistemaGuardado.datos_vivos y alternar ':' / ' ' según paridad del segundo.
	if typeof(SistemaGuardado) == TYPE_NIL or not SistemaGuardado.datos_vivos:
		# No hay sistema de guardado disponible
		lb_tiempo.text = "--:--"
		return

	var tiempo_juego: int = int(SistemaGuardado.datos_vivos.tiempo_juego)
	seconds += 1
	if seconds >= 60:
		seconds = 0
	var hours = int(float(tiempo_juego) / 3600.0)
	var minutes = int(float(tiempo_juego % 3600) / 60.0)

	# Formato visual: hhh:mm si segundo par, hhh mm si impar
	var sep = ":"
	if (seconds % 2) != 0:
		sep = " "

	lb_tiempo.text = "%03s%s%02d" % [hours, sep, minutes]

func inicializar_con_datos():
	seconds = 0
	# Configurar la ficha con los datos desde SistemaGuardado (fuente de verdad)
	var sg_node = get_tree().root.get_node_or_null("SistemaGuardado")
	var datos_jugador: Dictionary = {}

	if sg_node and typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos:
		datos_jugador = SistemaGuardado.datos_vivos.jugador
	else:
		datos_jugador = {
			"nombre": "??",
			"sexo": "M",
			"dinero": 0,
			"medallas": [false,false,false,false,false,false,false,false]
		}

	var id_text = "-"
	if datos_jugador.has("id"):
		id_text = str(int(datos_jugador.id))

	lb_id.text = id_text
	lb_nombre.text = str(datos_jugador.get("nombre", "--"))
	lb_dinero.text = "$ " + str(int(datos_jugador.get("dinero", 0)))

	# num_poke / tiempo pueden estar en otro lugar del guardado; usar datos_vivos si existe
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos:
		lb_num_poke.text = str(PokedexPartida.contar_atrapados_resumen(
				SistemaGuardado.datos_vivos.pokedex.get("atrapados", []),
				SistemaGuardado.datos_vivos.datos_persistentes.banderas))
		# tiempo_juego está en segundos; formatear simple HH:MM si existe
		var t = SistemaGuardado.datos_vivos.tiempo_juego
		if typeof(t) == TYPE_INT:
			var mins = int(float(t) / 60.0)
			var horas = int(float(t) / 3600.0)
			lb_tiempo.text = "%s:%02d" % [horas, mins]
		else:
			if SistemaGuardado.datos_vivos.has("tiempo_juego"):
				lb_tiempo.text = str(SistemaGuardado.datos_vivos.tiempo_juego)
			else:
				lb_tiempo.text = "--"
	else:
		lb_num_poke.text = str(datos_jugador.get("num_poke", "--"))
		lb_tiempo.text = str(datos_jugador.get("tiempo", "--"))

	var medallas = datos_jugador.get("medallas", [])
	# Asegurar tamaño mínimo
	while medallas.size() < 8:
		medallas.append(false)

	nd_medalla0.visible = medallas[0]
	nd_medalla1.visible = medallas[1]
	nd_medalla2.visible = medallas[2]
	nd_medalla3.visible = medallas[3]
	nd_medalla4.visible = medallas[4]
	nd_medalla5.visible = medallas[5]
	nd_medalla6.visible = medallas[6]
	nd_medalla7.visible = medallas[7]

	var sexo = datos_jugador.get("sexo", "M")
	if sexo == "M":
		nd_avatar.texture = preload("res://graficos/trainers64/001.png")
		nd_fe_fondo.visible = false
		nd_ma_fondo.visible = true
	elif sexo == "F":
		nd_avatar.texture = preload("res://graficos/trainers64/002.png")
		nd_fe_fondo.visible = true
		nd_ma_fondo.visible = false
	else:
		print("⚠️ [FICHA] Sexo desconocido:", sexo)
		nd_ma_fondo.visible = true
		nd_fe_fondo.visible = true
	nd_ficha_frente.visible = true
	nd_ficha_reverso.visible = false
	visible = true

	# Esperar la transición desde Singleton si existe (compatibilidad)
	if typeof(Singleton) != TYPE_NIL and Singleton.has_method("transicion"):
		await Singleton.transicion("aclarar")
		
func _input(event):
	if is_animating:
		return  # Ignorar entradas si estamos animando

	# Detectar cuando se presiona el botón de acción (Enter o Espacio)
	if event.is_action_pressed("btn_accion"):
		flip_card()
	elif event.is_action_pressed("btn_cancelar"):
		# Cerrar ficha con transición
		cerrar_ficha_con_transicion()

func cerrar_ficha_con_transicion():
	"""Cierra la ficha del entrenador con transición de oscurecimiento."""
	print("🔍 [FICHA] Cerrando ficha con transición...")
	is_animating = true  # Prevenir otras interacciones
	
	Singleton.emit_signal("play_sound", "cursor_menu")
	
	await Singleton.transicion("oscurecer")
	emit_signal("ficha_cerrada")


func flip_card():
	"""Ejecuta la animación de voltear la ficha"""
	if is_animating:
		return
	
	is_animating = true
	
	# Crear el tween
	if tween:
		tween.kill()
	tween = create_tween()

	if animacion_vertical:
		# Primera parte: comprimir verticalmente hasta ser una línea
		tween.tween_method(_scale_vertically, 1.0, 0.0, flip_duration / 2.0)
		tween.tween_callback(_change_side)
		# Segunda parte: expandir verticalmente desde línea hasta tamaño normal
		tween.tween_method(_scale_vertically, 0.0, 1.0, flip_duration / 2.0)
	else:
		# Primera parte: comprimir horizontalmente hasta ser una línea
		tween.tween_method(_scale_horizontally, 1.0, 0.0, flip_duration / 2.0)
		tween.tween_callback(_change_side)
		# Segunda parte: expandir horizontalmente desde línea hasta tamaño normal
		tween.tween_method(_scale_horizontally, 0.0, 1.0, flip_duration / 2.0)

	tween.tween_callback(_on_flip_complete)
	
	# Aplicar easing para una animación más suave
	tween.set_ease(ease_type)
	tween.set_trans(transition_type)

func _scale_horizontally(scale_x: float):
	"""Aplica la escala horizontal al sprite"""
	if is_flipped:
		nd_ficha_reverso.scale.x = scale_x
	else:
		nd_ficha_frente.scale.x = scale_x

func _scale_vertically(scale_y: float):
	"""Aplica la escala vertical al sprite"""
	if is_flipped:
		nd_ficha_reverso.scale.y = scale_y
	else:
		nd_ficha_frente.scale.y = scale_y

func _change_side():
	"""Cambia el lado de la ficha"""
	is_flipped = !is_flipped

	if is_flipped:
		nd_ficha_frente.visible = false
		nd_ficha_reverso.visible = true
		print("Mostrando reverso de la ficha")
	elif not is_flipped:
		nd_ficha_frente.visible = true
		nd_ficha_reverso.visible = false
		print("Mostrando frente de la ficha")

func _on_flip_complete():
	"""Se ejecuta cuando la animación de flip termina"""
	is_animating = false
	print("Animación de flip completada")

func reset_to_front():
	"""Resetea la ficha al frente sin animación"""
	is_animating = false
	is_flipped = false
	if tween:
		tween.kill()
	nd_ficha_frente.scale.x = 1.0
	nd_ficha_frente.scale.y = 1.0
	nd_ficha_reverso.scale.x = 1.0
	nd_ficha_reverso.scale.y = 1.0
	nd_ficha_frente.visible = true
	nd_ficha_reverso.visible = false
	print("Mostrando frente de la ficha")

func flip_to_back_instantly():
	"""Voltea la ficha al reverso sin animación"""
	is_animating = false
	is_flipped = true
	if tween:
		tween.kill()
	nd_ficha_frente.scale.x = 1.0
	nd_ficha_frente.scale.y = 1.0
	nd_ficha_reverso.scale.x = 1.0
	nd_ficha_reverso.scale.y = 1.0
	nd_ficha_frente.visible = false
	nd_ficha_reverso.visible = true
	print("Mostrando reverso de la ficha")
