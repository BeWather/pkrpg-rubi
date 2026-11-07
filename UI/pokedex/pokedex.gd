extends Control
## Lista regional independiente. En F6 usa una fixture; cargar_datos permite
## pasar registros {numero, nacional, nombre, visto, atrapado, tipos, color,
## peso, altura, sprite (ruta opcional)}; ver ordenador_pokedex.gd.
## Basado en SortPokedex/sub_808E48C/sub_808EE28 de pokeruby/src/pokedex.c.
## SELECT abre el buscador; sus resultados se muestran como lista aparte
## (isSearchResults) y B vuelve a la lista principal.

signal pokedex_cerrada

const DATOS_PRUEBA = preload("res://UI/pokedex/datos_prueba.gd")
const ORDENADOR = preload("res://UI/pokedex/ordenador_pokedex.gd")
const BUSCADOR: PackedScene = preload("res://UI/pokedex/buscador-pokedex.tscn")
const PAGINA: PackedScene = preload("res://UI/pokedex/pagina-pokedex.tscn")
## Centro del frente seleccionado en la lista (sub_808EE28) y en la ficha
## (CreateMonSpriteFromNationalDexNumber en 0x30, 0x38).
const CENTRO_FRENTE_LISTA: Vector2 = Vector2(96, 80)
const CENTRO_FRENTE_FICHA: Vector2 = Vector2(48, 56)
## SpriteCB_MoveMonForInfoScreen: 1 px por cuadro, 24 en diagonal y 24 en
## horizontal.
const DURACION_TRAMO_FRENTE: float = 0.4
const TEXTO_NORMAL: LabelSettings = preload("res://UI/texto_normal_negro.tres")
const ICONO_NUMERO: Texture2D = preload("res://UI/pokedex/graficos/num-no-visto.png")
const ICONO_ATRAPADO: Texture2D = preload("res://UI/pokedex/graficos/num-atrapado.png")
const ESPECIE_NO_VISTA: Texture2D = preload("res://UI/pokedex/graficos/especie-no-vista.png")
const BALL_CHICO: Texture2D = preload("res://UI/pokedex/graficos/main-ball-1.png")
const BALL_CHICA: Texture2D = preload("res://UI/pokedex/graficos/main-ball-2.png")
const ALTO_FILA: float = 16.0
const FILAS_PAGINA: int = 7
const GRADOS_POR_FILA: float = 22.5
const DURACION_FILA: float = 0.14
const DURACION_MENU: float = 0.3
const REPETICION_INICIAL: float = 0.32
const REPETICION: float = 0.14
const TAMANO_BASE: Vector2 = Vector2(240, 160)
const DURACION_FUNDIDO: float = 0.25

@export var usar_datos_prueba: bool = true
## Sin Dex Nacional el buscador oculta la fila MODO y la lista es la de Hoenn.
@export var dex_nacional_disponible: bool = false
@export var es_chica: bool = false:
	set(valor):
		es_chica = valor
		if is_node_ready():
			_aplicar_sexo()

@onready var _lista: Control = $"clip-lista/Lista"
@onready var _sprites: Node2D = $"clip-sprites/Sprites"
@onready var _ball: Sprite2D = $MainBall1
@onready var _cursor: Sprite2D = $"cursor-desplazamiento"
@onready var _arriba: AnimatedSprite2D = $"flecha-arriba"
@onready var _abajo: AnimatedSprite2D = $"flecha-abajo"
## Menu1: menú START de la lista (4 opciones). Menu2: el de los resultados
## de búsqueda (5 opciones, pokedex_listing_menu.bin), que sube hasta menuY 96.
@onready var _menus: Array[Sprite2D] = [$Menu1, $Menu2]
@onready var _flechas_menu: Array[AnimatedSprite2D] = [$"Menu1/flecha-derecha", $"Menu2/flecha-derecha2"]

var entradas: Array[Dictionary] = []
var indice_actual: int = 0
var _datos_cargados: bool = false
var _indice_visual: float = 0.0
var _tween: Tween
var _sprites_visibles: Dictionary = {}
var _texturas: Dictionary = {}
var _direccion_mantenida: int = 0
var _espera_repeticion: float = 0.0
var menu_abierto: bool = false
var indice_menu: int = 0
## Menú abierto o el último usado (Menu1 o Menu2) y su flecha.
var _menu: Sprite2D
var _flecha_menu: AnimatedSprite2D
var _posiciones_flecha_menu: Array[Vector2] = []
var _posiciones_menu_abierto: Array[Vector2] = []
var _tween_menu: Tween
var _menu_en_transicion: bool = false
var _cerrando_pokedex: bool = false
var _reproductor_f6: AudioStreamPlayer
## Modo y orden de la lista principal (gSaveBlock2.pokedex.mode/order).
var modo_dex: int = ORDENADOR.Modo.HOENN
var orden_dex: int = ORDENADOR.Orden.NUMERICO
## La lista muestra resultados de búsqueda en vez de la Pokédex completa.
var en_resultados: bool = false
var _datos: Array[Dictionary] = []
var _indice_principal: int = 0
var _buscador: Control
var _pagina: Control
## La raíz puede estar desplazada (offset_top = -1); las pantallas que abre
## la Pokédex (buscador, ficha) se compensan para quedar en (0, 0).
var _origen_pantalla: Vector2 = Vector2.ZERO
var _cambiando_pantalla: bool = false
var _fundido: ColorRect
## En el juego el menú de pausa cambia de pantalla con el telón: la Pokédex
## funde a negro al cerrar y no se oculta, para que no asome el mapa.
var fundir_al_cerrar: bool = false


func _ready() -> void:
	_origen_pantalla = -position
	_aplicar_sexo()
	_arriba.play()
	_abajo.play()
	# La posición de cada menú en la escena es la de abierto; espera debajo.
	for i in _menus.size():
		_flechas_menu[i].play()
		_posiciones_flecha_menu.append(_flechas_menu[i].position)
		_posiciones_menu_abierto.append(_menus[i].position)
		_menus[i].position = _posicion_cerrada(_menus[i])
		_menus[i].visible = false
	_menu = _menus[0]
	_flecha_menu = _flechas_menu[0]
	if not _datos_cargados:
		cargar_datos(DATOS_PRUEBA.crear() if usar_datos_prueba else [])
	_construir_lista()
	# current_scene puede asignarse después de _ready al ejecutar con F6.
	call_deferred("_ajustar_vista_previa")
	call_deferred("_preparar_audio_f6")
	get_viewport().size_changed.connect(_ajustar_vista_previa)


func _aplicar_sexo() -> void:
	$"Fe-fondo".visible = es_chica
	$"Ma-fondo".visible = not es_chica
	_ball.texture = BALL_CHICA if es_chica else BALL_CHICO


func _ajustar_vista_previa() -> void:
	if get_tree().current_scene != self:
		return
	var tamano := get_viewport_rect().size
	var factor := minf(tamano.x / TAMANO_BASE.x, tamano.y / TAMANO_BASE.y)
	scale = Vector2.ONE * factor
	position = (tamano - TAMANO_BASE * factor) / 2.0


func _preparar_audio_f6() -> void:
	if get_tree().current_scene != self or is_instance_valid(_reproductor_f6):
		return
	_reproductor_f6 = AudioStreamPlayer.new()
	_reproductor_f6.name = "ReproductorSEF6"
	# El volumen/mute configurado por Singleton ya se aplica en Master.
	# No copiar los dB al player: atenuaría dos veces el mismo sonido.
	_reproductor_f6.bus = &"Master"
	add_child(_reproductor_f6)


func _reproducir_efecto(clave: String) -> void:
	if get_tree().current_scene == self:
		_preparar_audio_f6()
		_reproductor_f6.stream = Singleton.se[clave]
		_reproductor_f6.play()
	else:
		# AdministradorMapa recibe la señal y usa su reproductor central.
		Singleton.play_sound.emit(clave)


## Ordena según modo_dex/orden_dex; en numérico rellena huecos y recorta
## después del último visto, como Ruby. Capturado implica visto.
## No se modifica el array recibido ni la partida.
func cargar_datos(datos: Array[Dictionary]) -> void:
	_datos_cargados = true
	_texturas.clear()
	_datos = ORDENADOR.normalizar(datos)
	en_resultados = false
	_mostrar_lista(ORDENADOR.ordenar(_datos, modo_dex, orden_dex))


func _mostrar_lista(lista: Array[Dictionary], indice: int = 0) -> void:
	_detener_animacion()
	_direccion_mantenida = 0
	entradas = lista
	indice_actual = clampi(indice, 0, maxi(0, entradas.size() - 1))
	_indice_visual = float(indice_actual)
	if is_node_ready():
		_construir_lista()


func _construir_lista() -> void:
	for hijo in _lista.get_children():
		hijo.free()
	for sprite in _sprites_visibles.values():
		sprite.free()
	_sprites_visibles.clear()
	for i in entradas.size():
		var entrada: Dictionary = entradas[i]
		var numero := int(entrada.get("numero_mostrado", entrada.get("numero", 0)))
		var fila := Control.new()
		fila.name = "Pokemon%03d" % numero
		fila.position = Vector2(0, i * ALTO_FILA)
		fila.size = Vector2(96, ALTO_FILA)
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lista.add_child(fila)
		var icono := Sprite2D.new()
		icono.name = "PrefijoNumero"
		icono.texture = ICONO_ATRAPADO if entrada["atrapado"] else ICONO_NUMERO
		icono.centered = false
		icono.position = Vector2(0, 2)
		fila.add_child(icono)
		_agregar_texto(fila, "Numero", "%03d" % numero, 16, 20)
		_agregar_texto(fila, "Nombre", str(entrada.get("nombre", "")).to_upper() if entrada["visto"] else "----------", 36, 60)
	# Los contadores son de toda la Pokédex del modo, no de la lista ordenada.
	var clave := "nacional" if modo_dex == ORDENADOR.Modo.NACIONAL else "numero"
	var vistos: int = 0
	var atrapados: int = 0
	for entrada in _datos:
		if int(entrada.get(clave, 0)) > 0:
			vistos += int(entrada["visto"])
			atrapados += int(entrada["atrapado"])
	$"num-avistados".text = str(vistos)
	$"num-atrapados".text = str(atrapados)
	# Los resultados de búsqueda no muestran contadores (CreateInterfaceSprites).
	$"num-avistados".visible = not en_resultados
	$"num-atrapados".visible = not en_resultados
	_dibujar_posicion(_indice_visual)
	_actualizar_flechas()


func _agregar_texto(fila: Control, nombre: String, texto: String, x: float, ancho: float) -> void:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.position = Vector2(x, 0)
	etiqueta.size = Vector2(ancho, ALTO_FILA)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.label_settings = TEXTO_NORMAL
	etiqueta.text = texto
	fila.add_child(etiqueta)


func abrir_menu() -> void:
	if menu_abierto or _cerrando_pokedex:
		return
	_detener_animacion()
	_dibujar_posicion(float(indice_actual))
	_direccion_mantenida = 0
	menu_abierto = true
	indice_menu = 0
	var cual := 1 if en_resultados else 0
	_menu = _menus[cual]
	_flecha_menu = _flechas_menu[cual]
	_flecha_menu.position = _posiciones_flecha_menu[cual]
	_menu.visible = true
	_animar_menu(_posiciones_menu_abierto[cual])
	_reproducir_efecto("SE_SELECT")


func _posicion_cerrada(menu: Sprite2D) -> Vector2:
	return Vector2(menu.position.x, TAMANO_BASE.y)


## Opciones del menú abierto: 4 en la lista, 5 en los resultados.
func _opciones_menu() -> int:
	return 5 if _menu == _menus[1] else 4


func cerrar_menu(reproducir_sonido: bool = true) -> void:
	if not menu_abierto:
		return
	_direccion_mantenida = 0
	menu_abierto = false
	_animar_menu(_posicion_cerrada(_menu))
	if reproducir_sonido:
		_reproducir_efecto("SE_SELECT")


func _animar_menu(destino: Vector2) -> void:
	if _tween_menu != null:
		_tween_menu.kill()
	_menu_en_transicion = true
	_actualizar_flechas()
	_tween_menu = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_menu.tween_property(_menu, "position", destino, DURACION_MENU)
	_tween_menu.finished.connect(_terminar_transicion_menu)


func _terminar_transicion_menu() -> void:
	_menu_en_transicion = false
	_tween_menu = null
	_menu.visible = menu_abierto
	_actualizar_flechas()


func _mover_cursor_menu(desplazamiento: int) -> void:
	var destino := clampi(indice_menu + desplazamiento, 0, _opciones_menu() - 1)
	if destino == indice_menu:
		return
	indice_menu = destino
	_flecha_menu.position = _posiciones_flecha_menu[_menus.find(_menu)] + Vector2(0, indice_menu * ALTO_FILA)
	_reproducir_efecto("SE_SELECT")


func _confirmar_menu() -> void:
	match indice_menu:
		0:
			cerrar_menu()
		1:
			cerrar_menu()
			mover_seleccion(-entradas.size(), false, false)
		2:
			cerrar_menu()
			mover_seleccion(entradas.size(), false, false)
		3:
			if en_resultados:
				volver_de_resultados("SE_TRUCK_DOOR")
			else:
				cerrar_pokedex()
		4:
			cerrar_pokedex()


## Oculta el menú sin animación, para cambios de pantalla bajo el fundido.
func _ocultar_menu_al_instante() -> void:
	if _tween_menu != null:
		_tween_menu.kill()
		_tween_menu = null
	_menu_en_transicion = false
	menu_abierto = false
	_menu.position = _posicion_cerrada(_menu)
	_menu.visible = false
	_actualizar_flechas()


func cerrar_pokedex() -> void:
	if _cerrando_pokedex:
		return
	_cerrando_pokedex = true
	var arbol := get_tree()
	var ejecutada_sola := arbol.current_scene == self
	_reproducir_efecto("SE_PC_OFF")
	# Cerrar toda la Pokédex usa PC_OFF, sin sobrescribirlo con SELECT.
	cerrar_menu(false)
	if _menu_en_transicion:
		await _tween_menu.finished
	# En F6 el player pertenece a esta escena: no salir cortando el efecto.
	# En el juego lo reproduce el nodo central, que sobrevive al cierre.
	if ejecutada_sola and _reproductor_f6.playing:
		await _reproductor_f6.finished
	if fundir_al_cerrar:
		await _fundir(1.0)
	_detener_animacion()
	if not fundir_al_cerrar:
		hide()
	set_process(false)
	set_process_unhandled_input(false)
	pokedex_cerrada.emit()
	# En F6 no hay pantalla anterior: salir solo de la ejecución de prueba.
	if ejecutada_sola and arbol.current_scene == self:
		arbol.quit()


## SELECT en la lista: SE_SELECT (solo desde la principal) y SE_PC_LOGIN,
## fundido a negro y pantalla de búsqueda con el modo y orden actuales.
func abrir_buscador() -> void:
	if _cambiando_pantalla or menu_abierto or _cerrando_pokedex:
		return
	_cambiando_pantalla = true
	_direccion_mantenida = 0
	_detener_animacion()
	_dibujar_posicion(float(indice_actual))
	if not en_resultados:
		_reproducir_efecto("SE_SELECT")
	_reproducir_efecto("SE_PC_LOGIN")
	await _fundir(1.0)
	_buscador = BUSCADOR.instantiate()
	_buscador.configurar(_datos, modo_dex, orden_dex, dex_nacional_disponible, _reproducir_efecto)
	_buscador.busqueda_terminada.connect(_al_terminar_busqueda)
	_buscador.position = _origen_pantalla
	add_child(_buscador)


## CAMBIO guarda modo y orden y vuelve al principio de la lista; una búsqueda
## con resultados los muestra; SALIR regresa a la lista principal.
func _al_terminar_busqueda(resultado: Dictionary) -> void:
	_buscador.queue_free()
	_buscador = null
	match str(resultado.get("accion", "salir")):
		"cambio":
			modo_dex = int(resultado["modo"])
			orden_dex = int(resultado["orden"])
			en_resultados = false
			_mostrar_lista(ORDENADOR.ordenar(_datos, modo_dex, orden_dex))
		"busqueda":
			if not en_resultados:
				_indice_principal = indice_actual
			en_resultados = true
			var lista: Array[Dictionary] = []
			lista.assign(resultado["lista"])
			_mostrar_lista(lista)
		_:
			if en_resultados:
				_restaurar_lista_principal()
	await _fundir(0.0)
	_cambiando_pantalla = false


## B en los resultados (SE_PC_OFF) o VER LA POKéDEX en su menú
## (SE_TRUCK_DOOR): vuelta a la lista principal en la especie que estaba
## seleccionada antes de buscar. El menú se funde sin bajar, como en Ruby.
func volver_de_resultados(sonido: String = "SE_PC_OFF") -> void:
	if not en_resultados or _cambiando_pantalla:
		return
	_cambiando_pantalla = true
	_direccion_mantenida = 0
	_reproducir_efecto(sonido)
	await _fundir(1.0)
	_ocultar_menu_al_instante()
	_restaurar_lista_principal()
	await _fundir(0.0)
	_cambiando_pantalla = false


func _restaurar_lista_principal() -> void:
	en_resultados = false
	_mostrar_lista(ORDENADOR.ordenar(_datos, modo_dex, orden_dex), _indice_principal)


## A sobre una especie vista: SE_PIN, la lista se funde mientras su frente
## se desliza a la posición de la ficha y entonces se abre la ficha.
## Sobre una no vista no pasa nada, como en Ruby.
func abrir_pagina() -> void:
	if _cambiando_pantalla or menu_abierto or _cerrando_pokedex or entradas.is_empty():
		return
	var entrada: Dictionary = entradas[indice_actual]
	if not entrada["visto"]:
		return
	_cambiando_pantalla = true
	_direccion_mantenida = 0
	_detener_animacion()
	_dibujar_posicion(float(indice_actual))
	_actualizar_flechas()
	_reproducir_efecto("SE_PIN")
	# _fundir crea el fundido antes de esperar: el frente queda por encima.
	_fundir(1.0)
	var frente := Sprite2D.new()
	frente.name = "FrenteDeslizandose"
	frente.texture = _obtener_frente(entrada)
	frente.position = CENTRO_FRENTE_LISTA
	add_child(frente)
	var destino := _origen_pantalla + CENTRO_FRENTE_FICHA
	var tween := create_tween()
	tween.tween_property(frente, "position", Vector2(CENTRO_FRENTE_LISTA.x - absf(destino.y - CENTRO_FRENTE_LISTA.y), destino.y), DURACION_TRAMO_FRENTE)
	tween.tween_property(frente, "position", destino, DURACION_TRAMO_FRENTE)
	await tween.finished
	_pagina = PAGINA.instantiate()
	_pagina.position = _origen_pantalla
	_pagina.configurar(entradas, indice_actual, es_chica, _reproducir_efecto, true)
	_pagina.pagina_cerrada.connect(_al_cerrar_pagina)
	add_child(_pagina)
	frente.queue_free()


## La ficha ya fundió a negro: la lista vuelve en la especie que se veía.
func _al_cerrar_pagina(indice: int) -> void:
	_pagina.queue_free()
	_pagina = null
	_fundido.modulate.a = 1.0
	indice_actual = clampi(indice, 0, maxi(0, entradas.size() - 1))
	_dibujar_posicion(float(indice_actual))
	_actualizar_flechas()
	await _fundir(0.0)
	_cambiando_pantalla = false


func _fundir(alfa: float) -> void:
	if not is_instance_valid(_fundido):
		_fundido = ColorRect.new()
		_fundido.name = "Fundido"
		_fundido.color = Color.BLACK
		# La raíz de la escena puede estar desplazada (offset_top = -1).
		_fundido.position = Vector2(0, -1)
		_fundido.size = TAMANO_BASE + Vector2(0, 2)
		_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fundido.modulate.a = 0.0
		add_child(_fundido)
	var tween := create_tween()
	tween.tween_property(_fundido, "modulate:a", alfa, DURACION_FUNDIDO)
	await tween.finished


func _unhandled_input(event: InputEvent) -> void:
	# El buscador y la ficha reciben sus propios controles.
	if is_instance_valid(_buscador) or is_instance_valid(_pagina):
		return
	if _menu_en_transicion or _cerrando_pokedex or _cambiando_pantalla:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"btn_select"):
		if not menu_abierto:
			abrir_buscador()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"btn_menu"):
		if menu_abierto:
			cerrar_menu()
		else:
			abrir_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"btn_cancelar"):
		if menu_abierto:
			cerrar_menu()
		elif en_resultados:
			volver_de_resultados()
		else:
			cerrar_pokedex()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"btn_accion"):
		if menu_abierto:
			_confirmar_menu()
		else:
			abrir_pagina()
		get_viewport().set_input_as_handled()
		return
	for accion in [&"btn_arriba", &"btn_abajo", &"btn_izquierda", &"btn_derecha"]:
		if event.is_action_released(accion):
			if (accion == &"btn_arriba" and _direccion_mantenida == -1) or (accion == &"btn_abajo" and _direccion_mantenida == 1):
				_direccion_mantenida = 0
			get_viewport().set_input_as_handled()
			return
		if not event.is_action_pressed(accion, false):
			continue
		if accion == &"btn_arriba" or accion == &"btn_abajo":
			_direccion_mantenida = -1 if accion == &"btn_arriba" else 1
			_espera_repeticion = REPETICION_INICIAL
			if menu_abierto:
				_mover_cursor_menu(_direccion_mantenida)
			else:
				mover_seleccion(_direccion_mantenida)
		else:
			_direccion_mantenida = 0
			if not menu_abierto:
				mover_seleccion(-FILAS_PAGINA if accion == &"btn_izquierda" else FILAS_PAGINA, false)
		get_viewport().set_input_as_handled()
		return


func _process(delta: float) -> void:
	if _direccion_mantenida == 0 or _menu_en_transicion or _cerrando_pokedex or _cambiando_pantalla:
		return
	_espera_repeticion -= delta
	if _espera_repeticion <= 0.0 and not esta_animando():
		if menu_abierto:
			_mover_cursor_menu(_direccion_mantenida)
		else:
			mover_seleccion(_direccion_mantenida)
		_espera_repeticion = REPETICION


func esta_animando() -> bool:
	return _tween != null and _tween.is_running()


func mover_seleccion(desplazamiento: int, suave: bool = true, reproducir_sonido: bool = true) -> void:
	if entradas.is_empty():
		return
	var destino := clampi(indice_actual + desplazamiento, 0, entradas.size() - 1)
	if destino == indice_actual:
		return
	_detener_animacion()
	indice_actual = destino
	_actualizar_flechas()
	if suave:
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_method(_dibujar_posicion, _indice_visual, float(destino), DURACION_FILA)
	else:
		# Saltos laterales instantáneos de siete, como en el decomp.
		_dibujar_posicion(float(destino))
	if reproducir_sonido:
		_reproducir_efecto("SE_DEX_SCROLL" if suave else "SE_DEX_PAGE")


func _detener_animacion() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _actualizar_flechas() -> void:
	var lista_activa := not menu_abierto and not _menu_en_transicion
	_arriba.visible = lista_activa and not entradas.is_empty() and indice_actual > 0
	_abajo.visible = lista_activa and not entradas.is_empty() and indice_actual < entradas.size() - 1
	_cursor.visible = not entradas.is_empty()


func _dibujar_posicion(indice: float) -> void:
	_indice_visual = indice
	_lista.position.y = 56.0 - indice * ALTO_FILA
	_ball.rotation_degrees = indice * GRADOS_POR_FILA
	_cursor.position.y = 20.0 + (indice * 120.0 / (entradas.size() - 1) if entradas.size() > 1 else 0.0)
	# Carrusel de frentes: centro (96,80), seno de amplitud 76 y escala Y
	# coseno, como sub_808EE28. Los huecos usan el gráfico de especie no vista.
	var necesarios: Array[int] = []
	for i in range(maxi(0, floori(indice) - 1), mini(entradas.size(), floori(indice) + 3)):
		if absf(i - indice) >= 2.0:
			continue
		necesarios.append(i)
		if not _sprites_visibles.has(i):
			var textura := _obtener_frente(entradas[i])
			if textura == null:
				continue
			var sprite := Sprite2D.new()
			sprite.name = "Frente%03d" % entradas[i]["numero"]
			sprite.texture = textura
			_sprites.add_child(sprite)
			_sprites_visibles[i] = sprite
		var frente: Sprite2D = _sprites_visibles[i]
		var angulo := (i - indice) * PI / 4.0
		frente.position = Vector2(0, sin(angulo) * 76.0)
		frente.scale = Vector2(1, maxf(0.001, cos(angulo)))
	for i in _sprites_visibles.keys():
		if i not in necesarios:
			_sprites_visibles[i].queue_free()
			_sprites_visibles.erase(i)


func _obtener_frente(entrada: Dictionary) -> Texture2D:
	if not entrada["visto"]:
		return ESPECIE_NO_VISTA
	var ruta := str(entrada.get("sprite", "res://graficos/pokemon/front/%s.png" % str(entrada.get("nombre", "")).to_upper()))
	if not _texturas.has(ruta):
		_texturas[ruta] = load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null
		if _texturas[ruta] == null:
			push_warning("Pokédex: no se encontró el sprite de frente: " + ruta)
	return _texturas[ruta] as Texture2D
