extends Control

signal continuar_solicitado
signal nueva_partida_solicitada
signal partida_nueva_confirmada(sexo: String, nombre: String)
signal opciones_solicitadas
signal salir_solicitado

enum Estado { SPLASH, INTRO, MENU, BUSY, TITLE_INTRO, TITLE_HOLD }

const PERSONAJE_CHICA: String = "chica"
const PERSONAJE_CHICO: String = "chico"
const SCN_PARTIDA_NUEVA: PackedScene = preload("res://escenas/partida_nueva/partida_nueva.tscn")

## Cualquier accion, incluidas las direcciones, salta la intro del
## desarrollador y pasa directamente a la fase TitleIntro.
const ACCIONES_SALTAR_INTRO: Array[String] = [
	"btn_arriba",
	"btn_abajo",
	"btn_izquierda",
	"btn_derecha",
	"btn_accion",
	"btn_cancelar",
	"btn_menu",
	"btn_select",
]

## Durante TitleIntro estas acciones adelantan la animacion hasta su final;
## las direcciones se ignoran.
const ACCIONES_AVANZAR_TITLE_INTRO: Array[String] = [
	"btn_accion",
	"btn_cancelar",
	"btn_menu",
	"btn_select",
]

var estado: Estado = Estado.SPLASH
@export var saltar_inicio_bici: bool = true
@export var saltar_directo_title_intro: bool = false

## Generacion de la secuencia de intro: se incrementa al arrancar o al saltar
## la intro; las corrutinas antiguas se abortan comprobandola tras cada await.
var _generacion_intro: int = 0
## Tweens vivos de la intro, para poder cortarlos al saltar.
var _tweens_intro: Array[Tween] = []

## Personaje elegido para toda la intro (bici + intro de batalla).
## Se fija una sola vez en _ready() y el resto del script lo reutiliza.
var personaje_actual: String = PERSONAJE_CHICA
var escena_partida_nueva: Control = null
var _sexo_partida_nueva: String = ""
var _nombre_partida_nueva: String = ""

@onready var legal_splash: Control = $LegalSplash

@onready var developer_intro: Control = $DeveloperIntro
@onready var animation_parte1: AnimationPlayer = $DeveloperIntro/Estanque/AnimationPlayer
@onready var estanque: Node2D = $DeveloperIntro/Estanque
@onready var gota1: Node2D = $DeveloperIntro/Estanque/Gotas/Gota
@onready var gota2: Node2D = $DeveloperIntro/Estanque/Gotas/Gota2
@onready var gota3: Node2D = $DeveloperIntro/Estanque/Gotas/Gota3
@onready var onda_template: Sprite2D = $DeveloperIntro/Estanque/Ondas/Onda
@onready var logo_dev: Node2D = $DeveloperIntro/Estanque/LogoDev
@onready var seguimiento_sombra_latios: PathFollow2D = $DeveloperIntro/Estanque/RutaSombraLatios/SeguimientoLatios

@onready var bicicleteando: Node2D = $DeveloperIntro/Bicicleteando
@onready var animation_ciclista: AnimationPlayer = $DeveloperIntro/Bicicleteando/AnimationPlayer
@onready var as_chico: AnimatedSprite2D = $DeveloperIntro/Bicicleteando/Personaje/Bruno
@onready var as_chica: AnimatedSprite2D = $DeveloperIntro/Bicicleteando/Personaje/Aura

@onready var transicion_ball: Node2D = $DeveloperIntro/TransicionBall
@onready var anim_batalla: Node2D = $DeveloperIntro/AnimBatalla

@onready var title_intro: Control = $TitleIntro
@onready var title_intro_animacion: Node2D = $TitleIntro/TitleIntro
@onready var title_menu: Control = $TitleMenu
@onready var menu_inicio: Control = $TitleMenu/MenuInicio
@onready var transicion_color: ColorRect = $TransicionColor
@onready var intro_music_player: AudioStreamPlayer = $IntroMusicPlayer
@onready var musica_batalla_player: AudioStreamPlayer = $MusicaBatallaPlayer
@onready var title_music_player: AudioStreamPlayer = $TitleMusicPlayer
func _ready() -> void:
	# Arranque directo de debug (F6 sobre un mapa, o F5 con iniciar_debug): el
	# juego entra al overworld sin menú de inicio. Si la intro siguiera viva,
	# sus animaciones y su música sonarían por detrás y el ciclo del título se
	# reiniciaría cada vez que termina el tema.
	if _omitir_por_arranque_debug():
		_apagar_para_arranque_debug()
		return

	legal_splash.visible = true

	title_menu.visible = false
	menu_inicio.ocultar_menu()
	menu_inicio.continuar_solicitado.connect(_on_menu_continuar_solicitado)
	menu_inicio.nueva_partida_solicitada.connect(_on_menu_nueva_partida_solicitada)
	menu_inicio.opciones_solicitadas.connect(_on_menu_opciones_solicitadas)
	menu_inicio.salir_solicitado.connect(_on_menu_salir_solicitado)

	_preparar_intro()

	if saltar_directo_title_intro:
		_saltar_a_title_intro()
	elif saltar_inicio_bici:
		_saltar_a_bicicleteando()
	else:
		_iniciar_splash_legal()


## ¿Estamos en arranque directo de debug (F6 sobre un mapa, o F5 con
## iniciar_debug)? Lo decide DebugArranque, que AdministradorMapa marca en su
## _enter_tree, antes de este _ready.
func _omitir_por_arranque_debug() -> bool:
	if not OS.is_debug_build():
		return false
	var arranque := get_node_or_null("/root/DebugArranque")
	if arranque == null or not arranque.has_method("debe_omitir_intro"):
		return false
	return bool(arranque.call("debe_omitir_intro"))


## Deja la intro completamente inerte: oculta, sin procesar (ni ella ni sus
## hijos, que heredan el process_mode) y sin audio. No se libera porque
## AdministradorMapa la sigue referenciando (hide(), mostrar_error(),
## ocultar_menu()).
func _apagar_para_arranque_debug() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_detener_audio_intro(self)
	print("⏭️ [INTRO] Omitida: arranque directo de debug")


## Detiene cualquier reproductor de audio del subárbol. El audio no depende del
## process_mode, así que hay que pararlo explícitamente.
func _detener_audio_intro(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is AudioStreamPlayer:
			(hijo as AudioStreamPlayer).stop()
		elif hijo is AudioStreamPlayer2D:
			(hijo as AudioStreamPlayer2D).stop()
		elif hijo is AudioStreamPlayer3D:
			(hijo as AudioStreamPlayer3D).stop()
		_detener_audio_intro(hijo)


## Restaura los nodos de la intro a su estado inicial de escena para que cada
## ciclo (arranque o reinicio por fin del tema del titulo) empiece limpio.
## Re-elige el personaje al azar para la bici y la intro de batalla.
func _preparar_intro() -> void:
	_seleccionar_personaje_azar()
	_detener_intro()
	_reiniciar_estanque()


## Devuelve el estanque a su estado inicial de escena. La animacion RESET de
## la escena restaura lo que tiene claveado (posiciones de gotas y fondos,
## modulate y visibilidad del logo); lo que RESET no cubre se reinicia a
## mano: la visibilidad de Gota2/Gota3 y la sombra de Latios, que aGFLL deja
## al final de su ruta (quedaba flotando sobre el estanque en el ciclo
## siguiente) y debe volver al inicio, fuera de pantalla.
func _reiniciar_estanque() -> void:
	estanque.visible = false
	animation_parte1.stop()
	animation_parte1.play("RESET")
	animation_parte1.advance(0.001)
	animation_parte1.stop()
	gota1.visible = true
	gota2.visible = false
	gota3.visible = false
	_configurar_ruta_sombra_latios()


func _configurar_ruta_sombra_latios() -> void:
	seguimiento_sombra_latios.progress_ratio = 0.0

## Elige el personaje de toda la intro una sola vez y sincroniza la
## visibilidad de los sprites de la bici con esa decision.
func _seleccionar_personaje_azar() -> void:
	personaje_actual = [PERSONAJE_CHICA, PERSONAJE_CHICO].pick_random()
	_aplicar_personaje()

## La visibilidad de Bruno/Aura deja de ser fuente de verdad: se deriva de
## `personaje_actual` para que bici e intro de batalla usen el mismo valor.
func _aplicar_personaje() -> void:
	as_chico.visible = personaje_actual == PERSONAJE_CHICO
	as_chica.visible = personaje_actual == PERSONAJE_CHICA

func _iniciar_splash_legal() -> void:
	await get_tree().create_timer(2.0).timeout

	# Fade out del splash legal
	transicion_color.color = Color(0, 0, 0, 0)
	transicion_color.color.a = 0.0
	transicion_color.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(transicion_color, "color:a", 1.0, 0.5)
	await tween.finished
	legal_splash.visible = false
	estanque.visible = true
	_iniciar_intro_desarrollador()

func _iniciar_intro_desarrollador() -> void:
	_generacion_intro += 1
	var generacion: int = _generacion_intro
	estado = Estado.INTRO
	developer_intro.visible = true
	developer_intro.modulate.a = 1.0
	intro_music_player.play()
	var tween: Tween = _crear_tween_intro()
	tween.tween_property(transicion_color, "color:a", 0.0, 0.5)
	await tween.finished
	if _intro_invalidada(generacion):
		return
	transicion_color.visible = false

	# Animaciones de la intro del desarrollador
	animation_parte1.play("aGota")
	await animation_parte1.animation_finished
	if _intro_invalidada(generacion):
		return

	animation_parte1.play("aGotaB")
	await animation_parte1.animation_finished
	if _intro_invalidada(generacion):
		return
	gota1.visible = false

	# Crear 3 ondas expansivas con delays de 0.13s
	_animar_onda(Vector2(119, 128))
	await get_tree().create_timer(0.13).timeout
	if _intro_invalidada(generacion):
		return
	_animar_onda(Vector2(119, 128))
	await get_tree().create_timer(0.13).timeout
	if _intro_invalidada(generacion):
		return
	_animar_onda(Vector2(119, 128))

	await get_tree().create_timer(0.68).timeout
	if _intro_invalidada(generacion):
		return

	animation_parte1.play("aDosGotitias")
	await animation_parte1.animation_finished
	if _intro_invalidada(generacion):
		return

	animation_parte1.play("aGFLL")
	var duracion_fade_final: float = 0.5
	var animacion_final: Animation = animation_parte1.get_animation("aGFLL")
	var tiempo_hasta_fade: float = maxf(animacion_final.length - duracion_fade_final, 0.0)
	await get_tree().create_timer(tiempo_hasta_fade).timeout
	if _intro_invalidada(generacion):
		return

	# Fade blanco durante los últimos 0.5 segundos de aGFLL
	transicion_color.color = Color(1, 1, 1, 0)
	transicion_color.color.a = 0.0
	transicion_color.visible = true
	tween = _crear_tween_intro()
	tween.tween_property(transicion_color, "color:a", 1.0, duracion_fade_final)
	await tween.finished
	if _intro_invalidada(generacion):
		return
	estanque.visible = false

	# Aquí iniciamos la animación del jugador bicicleteando por el campo
	bicicleteando.visible = true
	transicion_color.visible = false
	await _reproducir_bicicleteando_y_fundir(generacion)
	if _intro_invalidada(generacion):
		return
	bicicleteando.visible = false

	# Timer de sincronización con el audio
	await get_tree().create_timer(1.0).timeout
	if _intro_invalidada(generacion):
		return

	# Transción Campo Pokéball: corta el tema de la intro y arranca el tema
	# de batalla, que acompana TransicionBall y la intro AnimBatalla.
	intro_music_player.stop()
	musica_batalla_player.play()
	await transicion_ball.reproducir_transicion_ball(transicion_color)
	if _intro_invalidada(generacion):
		return

	# Intro de batalla con personaje seleccionado al azar
	await _reproducir_anim_batalla()
	if _intro_invalidada(generacion):
		return

	# Ajustes para terminar esta fase
	developer_intro.visible = false
	musica_batalla_player.stop()
	_iniciar_title_intro()

	# Fundido del blanco final de la intro de batalla hacia el menú
	var tween_fin: Tween = _crear_tween_intro()
	tween_fin.tween_property(transicion_color, "color:a", 0.0, 0.5)
	await tween_fin.finished
	if _intro_invalidada(generacion):
		return
	transicion_color.visible = false


## Reproduce la intro de batalla (AnimBatalla) con `personaje_actual`, el
## mismo elegido para la escena de la bici. Al terminar, el destello blanco
## interno deja la pantalla cubierta; se transfiere esa cobertura al overlay
## global `transicion_color` para poder ocultar la intro sin cortes.
func _reproducir_anim_batalla() -> void:
	await anim_batalla.reproducir_animacion(null, personaje_actual)
	transicion_color.color = Color(1, 1, 1, 1)
	transicion_color.visible = true
	anim_batalla.visible = false


func _saltar_a_bicicleteando() -> void:
	_generacion_intro += 1
	var generacion: int = _generacion_intro
	estado = Estado.INTRO
	legal_splash.visible = false
	developer_intro.visible = true
	estanque.visible = false

	bicicleteando.visible = true
	transicion_color.visible = false

	await _reproducir_bicicleteando_y_fundir(generacion)
	if _intro_invalidada(generacion):
		return

	bicicleteando.visible = false
	transicion_color.visible = false
	developer_intro.visible = false
	_iniciar_title_intro()


func _reproducir_bicicleteando_y_fundir(generacion: int) -> void:
	# Ambos caminos reproducen la animación completa antes de pasar al menú.
	animation_ciclista.play("ciclista")
	if personaje_actual == PERSONAJE_CHICO:
		as_chico.play("pedaleando")
	else:
		as_chica.play("pedaleando")

	var animacion_final: Animation = animation_ciclista.get_animation("ciclista")
	await get_tree().create_timer(animacion_final.length).timeout
	if _intro_invalidada(generacion):
		return

	var duracion_fade_final: float = 0.5
	transicion_color.color = Color(1, 1, 1, 0)
	transicion_color.visible = true
	var tween: Tween = _crear_tween_intro()
	tween.tween_property(transicion_color, "color:a", 1.0, duracion_fade_final)
	await tween.finished

func _animar_onda(pos: Vector2 = Vector2(119, 128)) -> void:
	# Clonar el nodo Onda
	var onda_clon: Sprite2D = onda_template.duplicate()
	onda_clon.visible = true
	onda_clon.position = pos
	onda_clon.scale = Vector2(0.1, 0.1)
	$DeveloperIntro/Estanque/Ondas.add_child(onda_clon)

	# Animar escala de 0.1 a 1.28 y modulación de 1 a 0.3 en 0.5 segundos
	var tween: Tween = create_tween()
	tween.tween_property(onda_clon, "scale", Vector2(1.28, 1.28), 0.5)
	tween.parallel().tween_property(onda_clon, "modulate:a", 0.3, 0.5)
	tween.tween_callback(onda_clon.queue_free)

## Se llama desde la animación aGotaB
func _iniciar_ondas_gota_2() -> void:
	_animar_trio_ondas(Vector2(48, 112))

## Se llama desde la animación aDosGotitias
func _iniciar_ondas_gota_3() -> void:
	_animar_trio_ondas(Vector2(200, 128))


func _animar_trio_ondas(pos: Vector2) -> void:
	_animar_onda(pos)
	await get_tree().create_timer(0.13).timeout
	_animar_onda(pos)
	await get_tree().create_timer(0.13).timeout
	_animar_onda(pos)


## Arranca la fase TitleIntro: animacion de titulo y tema musical juntos.
## Al terminar la animacion (sola o adelantada con una accion) se pasa a
## TITLE_HOLD; si el tema termina antes de abrir el menu, la presentacion
## completa se reinicia en LegalSplash (modo atraccion).
func _iniciar_title_intro() -> void:
	if estado != Estado.INTRO:
		return
	estado = Estado.TITLE_INTRO
	transicion_color.visible = false
	title_intro.visible = true
	title_music_player.play()
	_esperar_fin_animacion_titulo()
	_esperar_fin_tema_titulo()


## Corrutina: al terminar la animacion de TitleIntro, el estado pasa a
## TITLE_HOLD, donde btn_menu/btn_accion abren el menu principal.
func _esperar_fin_animacion_titulo() -> void:
	await title_intro_animacion.reproducir_animacion()
	if estado == Estado.TITLE_INTRO:
		estado = Estado.TITLE_HOLD


## Corrutina: si el tema del titulo termina sin abrir el menu, el ciclo de
## presentacion completo se reinicia desde LegalSplash.
func _esperar_fin_tema_titulo() -> void:
	await title_music_player.finished
	if estado == Estado.TITLE_INTRO or estado == Estado.TITLE_HOLD:
		_reiniciar_presentacion()


## Salta toda la intro del desarrollador y pasa directamente a TitleIntro.
## Invalida las corrutinas en curso (generacion), detiene animaciones, musica
## y tweens, y cubre la pantalla en negro antes de mostrar el titulo.
func _saltar_a_title_intro() -> void:
	_generacion_intro += 1
	estado = Estado.INTRO
	_detener_intro()
	transicion_color.color = Color(0, 0, 0, 1)
	transicion_color.visible = true
	_iniciar_title_intro()


## Detiene y oculta todo lo que pertenece a la intro del desarrollador.
func _detener_intro() -> void:
	intro_music_player.stop()
	musica_batalla_player.stop()
	animation_parte1.stop()
	animation_ciclista.stop()
	as_chico.stop()
	as_chica.stop()
	for tween: Tween in _tweens_intro:
		tween.kill()
	_tweens_intro.clear()
	transicion_ball.detener()
	anim_batalla.detener()
	developer_intro.visible = false
	estanque.visible = false
	bicicleteando.visible = false


## Desde TITLE_HOLD (animacion de titulo terminada, tema sonando) abre el
## menu principal. El tema se corta para igualar el estado final natural.
func _abrir_menu_desde_titulo() -> void:
	if estado != Estado.TITLE_HOLD:
		return
	estado = Estado.MENU
	title_music_player.stop()
	title_intro_animacion.detener()
	_mostrar_menu_principal()


## Muestra el menu principal con cursor sobre la opcion actual.
func _mostrar_menu_principal() -> void:
	title_intro.visible = false
	title_menu.visible = true
	menu_inicio.mostrar_menu()


## Reinicia el ciclo completo de presentacion desde el splash legal.
func _reiniciar_presentacion() -> void:
	estado = Estado.SPLASH
	title_music_player.stop()
	title_intro_animacion.detener()
	title_intro.visible = false
	title_menu.visible = false
	menu_inicio.ocultar_menu()
	for tween: Tween in _tweens_intro:
		tween.kill()
	_tweens_intro.clear()
	_preparar_intro()

	# Fundido a negro y revelado del splash legal para un nuevo ciclo
	transicion_color.color = Color(0, 0, 0, 1)
	transicion_color.visible = true
	legal_splash.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(transicion_color, "color:a", 0.0, 0.5)
	await tween.finished
	if estado != Estado.SPLASH:
		return
	transicion_color.visible = false
	_iniciar_splash_legal()


## Salta directamente al menu principal sin pasar por TitleIntro.
## Referencia publica para pruebas y flujos que necesitan el menu montado.
func completar_presentacion() -> void:
	if estado != Estado.INTRO:
		return
	estado = Estado.MENU
	title_music_player.stop()
	_mostrar_menu_principal()


## True si la generacion ya no es la actual: la intro fue saltada o
## reemplazada y la corrutina que la comprueba debe abortar.
func _intro_invalidada(generacion: int) -> bool:
	return generacion != _generacion_intro


## Tween registrado para poder cortarlo si la intro se salta.
func _crear_tween_intro() -> Tween:
	var tween: Tween = create_tween()
	_tweens_intro.append(tween)
	return tween


func restaurar_menu() -> void:
	estado = Estado.MENU
	title_intro.visible = false
	title_menu.visible = true
	menu_inicio.restaurar_menu()


## Oculta solo el menu de opciones (intro/title permanecen); usado cuando
## administrador_mapa abre ventanas superpuestas (opciones, partida nueva).
func ocultar_menu() -> void:
	menu_inicio.ocultar_menu()


func mostrar_error(mensaje: String) -> void:
	estado = Estado.MENU
	title_intro.visible = false
	title_menu.visible = true
	menu_inicio.mostrar_error(mensaje)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	match estado:
		Estado.INTRO:
			_procesar_input_intro(event)
		Estado.TITLE_INTRO:
			_procesar_input_title_intro(event)
		Estado.TITLE_HOLD:
			_procesar_input_title_hold(event)
		_:
			pass  # SPLASH y BUSY no leen entrada


## DeveloperIntro: cualquier accion, incluidas las direcciones, salta la
## intro completa y pasa a la fase TitleIntro.
func _procesar_input_intro(event: InputEvent) -> void:
	for accion: String in ACCIONES_SALTAR_INTRO:
		if event.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			_saltar_a_title_intro()
			return


## TitleIntro: aceptar/cancelar/menu/select adelantan la animacion hasta su
## ultimo cuadro, dejandola como si hubiera terminado sola (las direcciones
## se ignoran y no se cancela nada).
func _procesar_input_title_intro(event: InputEvent) -> void:
	for accion: String in ACCIONES_AVANZAR_TITLE_INTRO:
		if event.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			title_intro_animacion.terminar_animacion()
			return


## TITLE_HOLD: animacion de titulo terminada y tema sonando; btn_menu o
## btn_accion abren el menu principal (el resto de acciones se ignora).
func _procesar_input_title_hold(event: InputEvent) -> void:
	if event.is_action_pressed("btn_menu") or event.is_action_pressed("btn_accion"):
		get_viewport().set_input_as_handled()
		_abrir_menu_desde_titulo()


func _on_menu_continuar_solicitado() -> void:
	_emitir_intencion_menu(continuar_solicitado)


func _on_menu_nueva_partida_solicitada() -> void:
	_abrir_partida_nueva()


func _abrir_partida_nueva() -> void:
	if estado != Estado.MENU or is_instance_valid(escena_partida_nueva):
		return
	estado = Estado.BUSY
	_sexo_partida_nueva = ""
	_nombre_partida_nueva = ""
	menu_inicio.ocultar_menu()
	title_menu.visible = false
	escena_partida_nueva = SCN_PARTIDA_NUEVA.instantiate() as Control
	add_child(escena_partida_nueva)
	escena_partida_nueva.personaje_seleccionado.connect(_on_partida_nueva_personaje_seleccionado)
	escena_partida_nueva.nombre_seleccionado.connect(_on_partida_nueva_nombre_seleccionado)
	escena_partida_nueva.partida_completada.connect(_on_partida_nueva_completada)
	escena_partida_nueva.call("play")


func _on_partida_nueva_personaje_seleccionado(sexo: String) -> void:
	_sexo_partida_nueva = sexo


func _on_partida_nueva_nombre_seleccionado(nombre: String) -> void:
	_nombre_partida_nueva = nombre


func _on_partida_nueva_completada() -> void:
	if not is_instance_valid(escena_partida_nueva):
		return
	var escena_finalizada := escena_partida_nueva
	escena_partida_nueva = null
	escena_finalizada.queue_free()
	partida_nueva_confirmada.emit(_sexo_partida_nueva, _nombre_partida_nueva)


func _on_menu_opciones_solicitadas() -> void:
	_emitir_intencion_menu(opciones_solicitadas)


func _on_menu_salir_solicitado() -> void:
	_emitir_intencion_menu(salir_solicitado)


func _emitir_intencion_menu(intencion: Signal) -> void:
	if estado != Estado.MENU:
		return
	estado = Estado.BUSY
	intencion.emit()
