extends ColorRect

const SCN_CUADRO_DIALOGO: PackedScene = preload("res://UI/cuadro_dialogo.tscn")
const SCN_ENTRADA_NOMBRE: PackedScene = preload("res://escenas/entrada_nombre/entrada_nombre.tscn")
const SCN_EMISOR_PARTICULAS: PackedScene = preload("res://graficos/emisor.tscn")
const SCN_TRANSICION_NEGRA: PackedScene = preload("res://UI/transicion_negra.tscn")
const TEXTURA_MENU_BOX: Texture2D = preload("res://UI/menu_box_1.png")
const TAMANO_CUADRO_DIALOGO := Vector2(208, 48)

# Índice (0-based) de la página del saludo tras la que se reproduce la
# animación de salida de la pokébola, contando los separadores \p del mensaje:
# 0 «¡Hola!...» · 1 «¡Te doy la bienvenida...» · 2 «Me llamo ABEDUL.»
# 3 «Pero todo el mundo...» · 4 «Esto es lo que llamamos un “POKéMON”.»
const INDICE_PAGINA_SALIDA_POKEBALL := 4
const SEXO_CHICO := "M"
const SEXO_CHICA := "F"
const TEXTO_FINAL_SALUDO := "¿Eres un chico o una chica?"
const TEXTO_SELECCION_NOMBRE := "Muy bien.\\l¿Y cómo te llamas?"
const TEXTO_CONFIRMACION_NOMBRE := "Así que eres %s..."
const TEXTO_RECUERDO_PROFESOR := "¡Ah, sí, ya me acuerdo!\\p"
const NOMBRES_CHICO := ["OTRO NOMBRE", "BRUNO", "QUIMI", "RUFO", "ARTURO"]
const NOMBRES_CHICA := ["OTRO NOMBRE", "AURA", "TERESA", "RAQUEL", "SARA"]

## Bucle de la música: suena desde el principio y, al alcanzar BUCLE_FIN
## (1 min 14.04 s), retrocede a BUCLE_INICIO (0 min 27.60 s) para repetir.
## Mismo patrón que NuevoAudioStreamPlayer.reproducir(stream, ini, fin).
const BUCLE_INICIO_MUSICA: float = 27.60
const BUCLE_FIN_MUSICA: float = 74.04

@export_category("Desarrollo")
@export var no_reproducir_musica: bool = false
@export var saltar_animaciones_hasta_personaje: bool = false

@onready var animation_player: AnimationPlayer = $Presentacion1/AnimationPlayer
@onready var music_player: AudioStreamPlayer = $MusicaPlayer
@onready var menu_genero: Control = $MenuGenero
@onready var panel_genero: NinePatchRect = $MenuGenero/PanelGenero
@onready var panel_nombre: NinePatchRect = $MenuNombre/PanelNombre
@onready var panel_confirmacion_nombre: NinePatchRect = $MenuConfirmacionNombre/PanelConfirmacionNombre
@onready var selector_genero: PkSelectorSimple = $MenuGenero/PanelGenero/Selector
@onready var etiqueta_chico: Label = $MenuGenero/PanelGenero/EtiquetaChico
@onready var etiqueta_chica: Label = $MenuGenero/PanelGenero/EtiquetaChica
@onready var boton_chico: Button = $MenuGenero/PanelGenero/BotonChico
@onready var boton_chica: Button = $MenuGenero/PanelGenero/BotonChica
@onready var menu_nombre: Control = $MenuNombre
@onready var selector_nombre: PkSelectorSimple = $MenuNombre/PanelNombre/Selector
@onready var etiquetas_nombre: Array[Label] = [
	$MenuNombre/PanelNombre/EtiquetaNombre0,
	$MenuNombre/PanelNombre/EtiquetaNombre1,
	$MenuNombre/PanelNombre/EtiquetaNombre2,
	$MenuNombre/PanelNombre/EtiquetaNombre3,
	$MenuNombre/PanelNombre/EtiquetaNombre4,
]
@onready var botones_nombre: Array[Button] = [
	$MenuNombre/PanelNombre/BotonNombre0,
	$MenuNombre/PanelNombre/BotonNombre1,
	$MenuNombre/PanelNombre/BotonNombre2,
	$MenuNombre/PanelNombre/BotonNombre3,
	$MenuNombre/PanelNombre/BotonNombre4,
]
@onready var menu_confirmacion_nombre: Control = $MenuConfirmacionNombre
@onready var selector_confirmacion_nombre: PkSelectorSimple = $MenuConfirmacionNombre/PanelConfirmacionNombre/Selector
@onready var boton_confirmacion_si: Button = $MenuConfirmacionNombre/PanelConfirmacionNombre/BotonSi
@onready var boton_confirmacion_no: Button = $MenuConfirmacionNombre/PanelConfirmacionNombre/BotonNo
var cuadro_dialogo_local: NinePatchRect
var cuadro_dialogo_usado: NinePatchRect = null
var cuadro_dialogo_ocultado_entrada: NinePatchRect = null
var menu_genero_activo: bool = false
var genero_actual: int = 0
var cambio_genero_en_curso: bool = false
var menu_nombre_activo: bool = false
var nombre_actual: int = 0
var entrada_nombre_activa: Control = null
var transicion_entrada_nombre_en_curso: bool = false
var menu_confirmacion_nombre_activo: bool = false
var nombre_pendiente_confirmacion: String = ""
## Marca que el saludo inicial ya terminó: los párrafos finales posteriores
## (p. ej. TEXTO_FINAL_SALUDO) no deben re-disparar la secuencia de selección.
var _saludo_terminado: bool = false

func _get_imagen_tipo() -> int:
	if SistemaGuardado != null and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return 1


func _ready() -> void:
	animation_player.stop()
	animation_player.play("RESET")
	animation_player.advance(0.001)
	animation_player.stop()
	menu_genero.visible = false
	menu_confirmacion_nombre.visible = false
	var imagen_tipo := _get_imagen_tipo()
	MenuBoxManager.apply_texture_to_ninepatch(panel_genero, imagen_tipo)
	MenuBoxManager.apply_texture_to_ninepatch(panel_nombre, imagen_tipo)
	MenuBoxManager.apply_texture_to_ninepatch(panel_confirmacion_nombre, imagen_tipo)
	boton_chico.pressed.connect(_on_boton_chico_presionado)
	boton_chica.pressed.connect(_on_boton_chica_presionado)
	boton_confirmacion_si.pressed.connect(_on_boton_confirmacion_si_presionado)
	boton_confirmacion_no.pressed.connect(_on_boton_confirmacion_no_presionado)
	for indice in botones_nombre.size():
		botones_nombre[indice].pressed.connect(_on_boton_nombre_presionado.bind(indice))
	if _es_escena_ejecutada_sola():
		if saltar_animaciones_hasta_personaje:
			_iniciar_desde_final_personaje()
		else:
			play()

func _es_escena_ejecutada_sola() -> bool:
	return get_tree() != null and get_tree().current_scene == self

func play() -> void:
	_saludo_terminado = false
	animation_player.stop()
	animation_player.play("1.Presentación")
	music_player.stop()
	if not no_reproducir_musica:
		music_player.play()

## Salta la presentación completa hasta el estado final de la animación 3.
## Se usa para desarrollar y probar directamente la selección de personaje.
func _iniciar_desde_final_personaje() -> void:
	_saludo_terminado = true
	animation_player.stop()
	animation_player.play("3.Personaje por Defecto")
	var animacion_personaje: Animation = animation_player.get_animation("3.Personaje por Defecto")
	await get_tree().process_frame
	animation_player.seek(maxf(animacion_personaje.length - 0.001, 0.0), true)
	animation_player.pause()
	if not no_reproducir_musica:
		music_player.play()
	_mostrar_mensaje_final_desarrollo()
	_mostrar_menu_genero()

func _mostrar_mensaje_final_desarrollo() -> void:
	var cuadro_dialogo := _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	cuadro_dialogo_usado = cuadro_dialogo
	cuadro_dialogo.mostrar_inmediatamente(TEXTO_FINAL_SALUDO)

## Bucle manual de la música: al superar el límite retrocede al punto inicial.
func _process(_delta: float) -> void:
	if no_reproducir_musica:
		if music_player.playing:
			music_player.stop()
		return
	if music_player.playing and music_player.get_playback_position() >= BUCLE_FIN_MUSICA:
		print("🎵 [PARTIDA_NUEVA] Fin del tema (>= %.2f s): vuelta a %.2f s" % [BUCLE_FIN_MUSICA, BUCLE_INICIO_MUSICA])
		music_player.seek(BUCLE_INICIO_MUSICA)

func _obtener_cuadro_dialogo() -> NinePatchRect:
	if is_instance_valid(cuadro_dialogo_usado):
		return cuadro_dialogo_usado
	var cuadro_dialogo := Singleton.get_cuadro_dialogo()
	if cuadro_dialogo != null:
		return cuadro_dialogo
	if not _es_escena_ejecutada_sola():
		return null
	if not is_instance_valid(cuadro_dialogo_local):
		var capa_dialogo := CanvasLayer.new()
		capa_dialogo.name = "DialogoLocalLayer"
		capa_dialogo.layer = 100
		add_child(capa_dialogo)
		cuadro_dialogo_local = SCN_CUADRO_DIALOGO.instantiate() as NinePatchRect
		capa_dialogo.add_child(cuadro_dialogo_local)
		cuadro_dialogo_local.position = Vector2(16, 104)
		cuadro_dialogo_local.size = TAMANO_CUADRO_DIALOGO
		cuadro_dialogo_local.texture = TEXTURA_MENU_BOX
		cuadro_dialogo_local.patch_margin_left = 8
		cuadro_dialogo_local.patch_margin_right = 8
		var etiqueta_dialogo := cuadro_dialogo_local.get_node("RichTextLabel") as RichTextLabel
		etiqueta_dialogo.offset_left = 8
		etiqueta_dialogo.offset_right = 200
		cuadro_dialogo_local.get_node("Cursor").position.x = 198
	return cuadro_dialogo_local

func _mostrar_saludo() -> void:
	var cuadro_dialogo := _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	cuadro_dialogo_usado = cuadro_dialogo
	var mensaje: String = "¡Hola! Perdona que te haya\\lhecho esperar.\\p"
	mensaje += "¡Te doy la bienvenida al fabuloso\\lmundo de los POKéMON!\\p"
	mensaje += "Me llamo ABEDUL.\\p"
	mensaje += "Pero todo el mundo me llama\\lPROFESOR ABEDUL.\\p"
	mensaje += "Esto es lo que llamamos un\\l“POKéMON”.\\p"
	mensaje += "El mundo está habitado por\\lcriaturas llamadas POKéMON.\\p"
	# \w\l: al completar el 2.º renglón espera una pulsación (con cursor) y
	# solo entonces salta al tercero, en vez de desplazar el primero de golpe.
	mensaje += "Los humanos y los POKéMON vivimos\\ljuntos. A veces nos lo pasamos bien\\w\\ly nos ayudamos unos a otros.\\p"
	mensaje += "A veces nos unimos y combatimos\\lcontra equipos como el nuestro.\\p"
	mensaje += "Pero, a pesar de estos vínculos,\\lignoramos mucho sobre los POKéMON.\\p"
	mensaje += "De hecho, hay multitud de secretos\\lque rodean a los POKéMON.\\p"
	mensaje += "En mi afán por descubrirlos, he\\ldedicado mi vida a la investigación.\\w\\lEso es lo que hago."
	mensaje += "¿Y tú quién eres?"
	cuadro_dialogo.callback_pagina_completada = Callable(self, "_al_completar_pagina")
	# El saludo termina aquí; el hook de página final encadena la animación 3,
	# el mensaje progresivo de selección y el menú de género.
	cuadro_dialogo.mostrar(mensaje, false, false)

## Hook de página del cuadro de diálogo: bloquea el avance del texto mientras
## corre la animación de la pokéball (sin cursor, sin input) en la página indicada;
## al completar la página final encadena personaje, mensaje final y menú.
func _al_completar_pagina(indice_parrafo: int, _parrafo_final: bool, _contenido: String) -> void:
	if indice_parrafo == INDICE_PAGINA_SALIDA_POKEBALL:
		await _reproducir_salida_pokeball()
	elif _parrafo_final and not _saludo_terminado:
		# Solo la última página del saludo inicial encadena la selección; los
		# mensajes propios de esa secuencia también son párrafo final y sin
		# esta bandera volverían a lanzarla (bucle de animación 3 + mensaje).
		_saludo_terminado = true
		await _secuencia_seleccion_personaje()

## Reproduce la animación «salida_pokeball» y espera a que termine; al volver,
## el cuadro de diálogo muestra el cursor de espera para continuar el texto.
func _reproducir_salida_pokeball() -> void:
	print("🎬 [PARTIDA_NUEVA] Salida de la pokébola: inicio")
	animation_player.play("2.Salida Pokéball")
	await animation_player.animation_finished
	print("🎬 [PARTIDA_NUEVA] Salida de la pokébola: fin")

## Secuencia completa al terminar la última página del saludo: animación del
## personaje, mensaje final progresivo y, solo entonces, menú de género.
func _secuencia_seleccion_personaje() -> void:
	await _reproducir_personaje_por_defecto()
	await _mostrar_mensaje_final_progresivo()
	if cuadro_dialogo_usado != null and is_instance_valid(cuadro_dialogo_usado):
		cuadro_dialogo_usado.callback_pagina_completada = Callable()
	cuadro_dialogo_usado = null
	_mostrar_menu_genero()

## Reproduce la presentación del personaje y espera a que termine.
func _reproducir_personaje_por_defecto() -> void:
	print("🎬 [PARTIDA_NUEVA] Personaje por defecto: inicio")
	animation_player.play("3.Personaje por Defecto")
	await animation_player.animation_finished
	print("🎬 [PARTIDA_NUEVA] Personaje por defecto: fin")

## Escribe TEXTO_FINAL_SALUDO con typewriter y lo deja visible de forma
## permanente: sin cursor, no responde a botones ni puede saltarse. Solo un
## mensaje nuevo puede reemplazarlo.
func _mostrar_mensaje_final_progresivo(cuadro_dialogo_forzado: NinePatchRect = null) -> void:
	var cuadro_dialogo := cuadro_dialogo_forzado if is_instance_valid(cuadro_dialogo_forzado) else _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	cuadro_dialogo_usado = cuadro_dialogo
	cuadro_dialogo.mostrar(TEXTO_FINAL_SALUDO, false, false)
	await cuadro_dialogo.texto_completado

func _mostrar_menu_genero(reiniciar_genero: bool = true) -> void:
	menu_genero_activo = true
	if reiniciar_genero:
		genero_actual = 0
	menu_genero.visible = true
	_actualizar_selector_genero()
	print("🧑 [PARTIDA_NUEVA] Menú de género visible")

func _actualizar_selector_genero() -> void:
	selector_genero.position.y = 7.0 + genero_actual * 16.0
	# etiqueta_chico.modulate = Color(1, 0.35, 0.35) if genero_actual == 0 else Color.WHITE
	# etiqueta_chica.modulate = Color(1, 0.35, 0.35) if genero_actual == 1 else Color.WHITE

func _confirmar_genero() -> void:
	if not menu_genero_activo or cambio_genero_en_curso:
		return
	var sexo := SEXO_CHICO if genero_actual == 0 else SEXO_CHICA
	menu_genero_activo = false
	menu_genero.visible = false
	print("🧑 [PARTIDA_NUEVA] Personaje seleccionado: ", sexo)
	personaje_seleccionado.emit(sexo)
	await _mostrar_mensaje_seleccion_nombre()
	_mostrar_menu_nombre()

func _cambiar_genero_con_animacion(nuevo_genero: int) -> void:
	if cambio_genero_en_curso or nuevo_genero == genero_actual:
		return
	genero_actual = nuevo_genero
	_actualizar_selector_genero()
	Singleton.emit_signal("play_sound", "cursor_menu")
	cambio_genero_en_curso = true
	var nombre_animacion := "4.Cambio a Chica" if genero_actual == 1 else "5.Cambio a Chico"
	animation_player.play(nombre_animacion)
	await animation_player.animation_finished
	cambio_genero_en_curso = false

func _on_boton_chico_presionado() -> void:
	if cambio_genero_en_curso:
		return
	genero_actual = 0
	_actualizar_selector_genero()
	_confirmar_genero()

func _on_boton_chica_presionado() -> void:
	if cambio_genero_en_curso:
		return
	genero_actual = 1
	_actualizar_selector_genero()
	_confirmar_genero()

signal personaje_seleccionado(sexo: String)
signal nombre_seleccionado(nombre: String)
signal partida_completada

func _mostrar_mensaje_seleccion_nombre() -> void:
	var cuadro_dialogo := _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	cuadro_dialogo_usado = cuadro_dialogo
	cuadro_dialogo.mostrar(TEXTO_SELECCION_NOMBRE, false, false)
	await cuadro_dialogo.texto_completado

func _obtener_nombres_actuales() -> Array:
	return NOMBRES_CHICO if genero_actual == 0 else NOMBRES_CHICA

func _mostrar_menu_nombre() -> void:
	nombre_actual = 0
	menu_nombre_activo = true
	menu_nombre.visible = true
	_actualizar_menu_nombre()
	print("📝 [PARTIDA_NUEVA] Menú de nombres visible")

func _actualizar_menu_nombre() -> void:
	var nombres := _obtener_nombres_actuales()
	for indice in etiquetas_nombre.size():
		etiquetas_nombre[indice].text = nombres[indice]
	selector_nombre.position.y = 7.0 + nombre_actual * 16.0

func _confirmar_nombre() -> void:
	if not menu_nombre_activo or menu_confirmacion_nombre_activo:
		return
	var nombres := _obtener_nombres_actuales()
	if nombre_actual == 0:
		_mostrar_entrada_nombre()
		return
	var nombre := str(nombres[nombre_actual])
	menu_nombre_activo = false
	menu_nombre.visible = false
	await _mostrar_mensaje_confirmacion_nombre(nombre)
	_mostrar_menu_confirmacion_nombre()

func _mostrar_entrada_nombre() -> void:
	if transicion_entrada_nombre_en_curso or is_instance_valid(entrada_nombre_activa):
		return
	transicion_entrada_nombre_en_curso = true
	if is_instance_valid(cuadro_dialogo_usado):
		cuadro_dialogo_ocultado_entrada = cuadro_dialogo_usado
		cuadro_dialogo_ocultado_entrada.visible = false
	menu_nombre_activo = false
	menu_nombre.visible = false
	var tipo_objetivo := 0 if genero_actual == 0 else 1
	var transicion := _crear_transicion_entrada_nombre()
	await transicion.ejecutar(func() -> void:
		entrada_nombre_activa = SCN_ENTRADA_NOMBRE.instantiate() as Control
		entrada_nombre_activa.set("sexo_pokemon", 0)
		entrada_nombre_activa.connect("nombre_confirmado", _on_nombre_manual_confirmado, CONNECT_ONE_SHOT)
		entrada_nombre_activa.connect("cancelado", _on_nombre_manual_cancelado, CONNECT_ONE_SHOT)
		add_child(entrada_nombre_activa)
		entrada_nombre_activa.call("configurar", "¿CÓMO TE LLAMAS?", 7, false, tipo_objetivo)
	)
	transicion.queue_free()
	transicion_entrada_nombre_en_curso = false
	print("📝 [PARTIDA_NUEVA] Entrada manual de nombre visible")

func _on_nombre_manual_confirmado(nombre: String) -> void:
	if transicion_entrada_nombre_en_curso or not is_instance_valid(entrada_nombre_activa):
		return
	await _cerrar_entrada_nombre()
	await _mostrar_mensaje_confirmacion_nombre(nombre)
	_mostrar_menu_confirmacion_nombre()

func _on_nombre_manual_cancelado() -> void:
	if transicion_entrada_nombre_en_curso or not is_instance_valid(entrada_nombre_activa):
		return
	await _cerrar_entrada_nombre()
	await _mostrar_mensaje_seleccion_nombre()
	_mostrar_menu_nombre()

func _mostrar_mensaje_confirmacion_nombre(nombre: String) -> void:
	var cuadro_dialogo := _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	nombre_pendiente_confirmacion = nombre
	cuadro_dialogo_usado = cuadro_dialogo
	cuadro_dialogo.mostrar(TEXTO_CONFIRMACION_NOMBRE % nombre, false, false)
	await cuadro_dialogo.texto_completado

func _mostrar_menu_confirmacion_nombre() -> void:
	menu_confirmacion_nombre_activo = true
	menu_confirmacion_nombre.visible = true
	selector_confirmacion_nombre.position.y = 7.0
	print("📝 [PARTIDA_NUEVA] Menú de confirmación de nombre visible")

## Limpia el texto del cuadro de diálogo dejándolo visible y sin cursor.
## La invoca la animación «6.Regresa Profesor» (t=0.82) mientras el profesor
## vuelve a su puesto: el mensaje anterior desaparece sin cerrar el cuadro.
func _limpiar_texto_cuadro_dialogo() -> void:
	var cuadro_dialogo := _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	cuadro_dialogo.limpiar_texto()
	print("📝 [PARTIDA_NUEVA] Cuadro de diálogo limpio, sin cursor ni botones")

## Escribe TEXTO_RECUERDO_PROFESOR con typewriter al terminar la animación
## «6.Regresa Profesor» (t=1.13): queda visible, sin cursor ni botones.
func _mostrar_mensaje_recuerdo_profesor() -> void:
	var cuadro_dialogo: NinePatchRect = _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	cuadro_dialogo_usado = cuadro_dialogo
	var mensaje_profesor: String = "¡Ah, sí, ya me acuerdo!\\p"
	mensaje_profesor += "Tú te acabas de mudar a mi\\lpueblo natal, VILLA RAÍZ.\\w\\l¿A que sí?"
	cuadro_dialogo.mostrar(mensaje_profesor, false, false, Callable(), true)
	await cuadro_dialogo.texto_completado
	_reproducir_salida_profesor()

## Reproduce la animación «7.Salida Profesor» de salida del profesor y
## retorno del personaje elegido
func _reproducir_salida_profesor() -> void:
	print("🎬 [PARTIDA_NUEVA] Salida del profesor: inicio")
	animation_player.play("7.Salida Profesor")
	await animation_player.animation_finished
	print("🎬 [PARTIDA_NUEVA] Salida del profesor: fin")

	var cuadro_dialogo: NinePatchRect = _obtener_cuadro_dialogo()
	if cuadro_dialogo == null:
		return
	cuadro_dialogo_usado = cuadro_dialogo
	var mensaje_final: String = "Vale, escucha bien lo que te\\lvoy a decir...\\p"
	mensaje_final += "Tu propia aventura está a punto\\lde comenzar.\\p"
	mensaje_final += "Adelante, entra en el mundo de los\\lPOKéMON: un mundo de ensueño, lleno\\w\\lde aventuras y grandes amigos.\\p"
	mensaje_final += "Bueno, ven a verme luego. Te espero\\len mi LABORATORIO POKéMON."
	cuadro_dialogo.mostrar(mensaje_final, true, true)
	await cuadro_dialogo.texto_completado

	print("🎬 [PARTIDA_NUEVA] Animacion cerrando escena: inicio")
	animation_player.play("8.Cierre Escena")
	await animation_player.animation_finished
	print("🎬 [PARTIDA_NUEVA] Animacion cerrando escena: fin")
	partida_completada.emit()

## Cambia el sprite del profesor al protagonista elegido en el frame t=0.82
## de «7.Salida Profesor»: frame 0 = chico, 1 = chica.
func _mostrar_protagonista_elegido() -> void:
	var prof := get_node_or_null("Presentacion1/Prof")
	if prof == null:
		return
	prof.frame = 0 if genero_actual == 0 else 1
	print("🧑 [PARTIDA_NUEVA] Protagonista visible: frame ", prof.frame)

## Reproduce la animación «6.Regresa Profesor» tras confirmar el nombre: el
## profesor vuelve a su puesto mientras el cuadro se limpia (t=0.82) y, al
## final, muestra el mensaje de recuerdo (t=1.13).
func _reproducir_regresa_profesor() -> void:
	print("🎬 [PARTIDA_NUEVA] Regresa profesor: inicio")
	animation_player.play("6.Regresa Profesor")
	await animation_player.animation_finished
	print("🎬 [PARTIDA_NUEVA] Regresa profesor: fin")

func _resolver_confirmacion_nombre(aceptado: bool) -> void:
	if not menu_confirmacion_nombre_activo:
		return
	menu_confirmacion_nombre_activo = false
	menu_confirmacion_nombre.visible = false
	var nombre := nombre_pendiente_confirmacion
	nombre_pendiente_confirmacion = ""
	if aceptado:
		print("📝 [PARTIDA_NUEVA] Nombre confirmado: ", nombre)
		# El profesor debe recordar al jugador antes de emitir la selección:
		# la animación limpia el cuadro y escribe el mensaje de recuerdo.
		await _reproducir_regresa_profesor()
		nombre_seleccionado.emit(nombre)
		return
	await _mostrar_mensaje_seleccion_nombre()
	_mostrar_menu_nombre()

func _on_boton_confirmacion_si_presionado() -> void:
	_resolver_confirmacion_nombre(true)

func _on_boton_confirmacion_no_presionado() -> void:
	_resolver_confirmacion_nombre(false)

func _crear_transicion_entrada_nombre() -> CanvasLayer:
	var transicion := SCN_TRANSICION_NEGRA.instantiate() as CanvasLayer
	add_child(transicion)
	return transicion

func _cerrar_entrada_nombre() -> void:
	transicion_entrada_nombre_en_curso = true
	var transicion := _crear_transicion_entrada_nombre()
	await transicion.ejecutar(func() -> void:
		if is_instance_valid(entrada_nombre_activa):
			entrada_nombre_activa.queue_free()
		entrada_nombre_activa = null
		_restaurar_cuadro_dialogo_entrada()
	)
	transicion.queue_free()
	transicion_entrada_nombre_en_curso = false

func _restaurar_cuadro_dialogo_entrada() -> void:
	if is_instance_valid(cuadro_dialogo_ocultado_entrada):
		cuadro_dialogo_ocultado_entrada.visible = true
	cuadro_dialogo_ocultado_entrada = null

func _on_boton_nombre_presionado(indice: int) -> void:
	if not menu_nombre_activo:
		return
	nombre_actual = indice
	_actualizar_menu_nombre()
	Singleton.emit_signal("play_sound", "cursor_menu")
	_confirmar_nombre()

func _cancelar_seleccion_nombre() -> void:
	if not menu_nombre_activo:
		return
	menu_nombre_activo = false
	menu_nombre.visible = false
	menu_genero_activo = false
	menu_genero.visible = false
	await _mostrar_mensaje_final_progresivo(cuadro_dialogo_usado)
	_mostrar_menu_genero(false)
	print("🧑 [PARTIDA_NUEVA] Regreso al menú de selección de personaje")

func _input(event: InputEvent) -> void:
	if menu_confirmacion_nombre_activo:
		if event.is_action_pressed("btn_arriba"):
			selector_confirmacion_nombre.position.y = 7.0
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_abajo"):
			selector_confirmacion_nombre.position.y = 23.0
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_accion"):
			_resolver_confirmacion_nombre(selector_confirmacion_nombre.position.y < 16.0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_cancelar"):
			_resolver_confirmacion_nombre(false)
			get_viewport().set_input_as_handled()
		return
	if menu_nombre_activo:
		if event.is_action_pressed("btn_cancelar"):
			_cancelar_seleccion_nombre()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_arriba"):
			nombre_actual = (nombre_actual - 1 + NOMBRES_CHICO.size()) % NOMBRES_CHICO.size()
			_actualizar_menu_nombre()
			Singleton.emit_signal("play_sound", "cursor_menu")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_abajo"):
			nombre_actual = (nombre_actual + 1) % NOMBRES_CHICO.size()
			_actualizar_menu_nombre()
			Singleton.emit_signal("play_sound", "cursor_menu")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_accion"):
			_confirmar_nombre()
			get_viewport().set_input_as_handled()
		return
	if not menu_genero_activo or cambio_genero_en_curso:
		return
	if event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo"):
		_cambiar_genero_con_animacion(1 - genero_actual)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_accion"):
		_confirmar_genero()
		get_viewport().set_input_as_handled()

## Emisión de partículas al abrirse la pokébola (t=0.55 de «salida_pokeball»).
## Reutiliza el emisor del sistema de batalla con sus mismos parámetros y su
## política de auto-liberación: emisión + recorrido de partícula + margen.
func _emitir_particulas_salida() -> void:
	var bola := get_node_or_null("Presentacion1/PBall1") as Node2D
	var presentacion := get_node_or_null("Presentacion1") as Node2D
	if bola == null or presentacion == null:
		return
	var emisor: Node2D = SCN_EMISOR_PARTICULAS.instantiate()
	emisor.position = bola.position
	emisor.offset_posicion = Vector2.ZERO
	emisor.configurar({
		"tiempo_emision": 0.2,
		"intervalo_emision": 0.01,
	})
	presentacion.add_child(emisor)
	var tiempo_total: float = 0.3 + emisor.duracion_movimiento + 0.5
	get_tree().create_timer(tiempo_total).timeout.connect(func() -> void:
		if is_instance_valid(emisor):
			emisor.queue_free()
	)
