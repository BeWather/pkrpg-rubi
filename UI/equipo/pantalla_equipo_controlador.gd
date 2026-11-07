extends Node2D

class_name PantallaEquipoControlador

# NOTA DE ARQUITECTURA:
# Esta escena y su script no son un Singleton ni se mantienen en memoria de forma persistente.
# Se considera una "escena reutilizable" que es instanciada bajo demanda por otros nodos
# (como el menú de pausa o la escena de batalla) cuando necesitan mostrar el equipo.
#
# Ciclo de vida típico:
# 1. Otro script (ej: `batalla.gd`) la instancia con `.instantiate()`.
# 2. Se añade al árbol de la escena activa con `add_child()`.
# 3. La función `_ready()` se ejecuta, realizando la inicialización básica.
# 4. El script llamador configura su estado inicial llamando a `mostrar_equipo_desde()`.
# 5. Cuando ya no se necesita, la escena es liberada de memoria (generalmente con `queue_free()`
#    o al liberar su nodo padre).
#
# Esto garantiza que la pantalla de equipo siempre se inicie en un estado limpio y predecible,
# sin conservar datos de usos anteriores.

# Controlador principal de la pantalla de equipo
# Maneja la lógica de navegación y estados de todas las cajas

@onready var caja1 = $"caja1"
@onready var caja2 = $"caja2"
@onready var caja3 = $"caja3"
@onready var caja4 = $"caja4"
@onready var caja5 = $"caja5"
@onready var caja6 = $"caja6"
@onready var boton_salir = $"boton-salir"
## Botón VALE de la TORRE BATALLA (sub_806BB9C): en reposo y con el cursor.
@onready var boton_vale: Sprite2D = $"boton-vale"
@onready var boton_vale_cursor: Sprite2D = $"boton-vale-cursor"
@onready var caja_texto: CajaTextoBatalla = $"NinePatchRect/CajaTexto"
@onready var cuadro_mensaje = $"NinePatchRect"  # Referencia al cuadro de mensaje
@onready var cursor: AnimatedSprite2D = $NinePatchRect/Cursor

var cajas: Array[CajaEquipo] = []
var cursor_actual: int = 0  # 0-5 = cajas, -1 = botón salir, -2 = botón VALE (TORRE_BATALLA)
const CURSOR_SALIR: int = -1
const CURSOR_VALE: int = -2

# Se añaden las nuevas variables para el controlador mejorado
var activo: bool = false
var equipo_actual: EquipoPokemon = null
# var indice_seleccionado: int = 0  # DEPRECATED: ahora usamos cursor_actual

# var estados_cajas: Array[bool] = []  # True si tiene Pokémon, False si está vacía

# Señales adicionales
signal pokemon_elegido(indice: int)
signal seleccion_cancelada
signal pantalla_cerrada
## Modo DAR_OBJETO: emitida al terminar el intento de dar el objeto (se haya
## equipado o no) tras cerrar el último mensaje.
signal dar_objeto_terminado
## Modos USAR_OBJETO y BATALLA_OBJETO: emitida tras usar objeto_a_usar sobre
## el Pokémon `indice` y cerrar el mensaje. `tuvo_efecto` = se gastó 1 unidad
## (en combate, además, se gasta el turno). Quien abrió la pantalla la cierra.
signal objeto_usado(indice: int, tuvo_efecto: bool)
## Menú de pausa: se eligió un movimiento de campo (`movimiento` = nombre
## interno, p. ej. "VUELO") para el Pokémon `indice`. El menú del Pokémon ya
## está cerrado; quien escucha decide cómo seguir (p. ej. el mapa de VUELO).
signal movimiento_campo_elegido(indice: int, movimiento: String)
## Modo TORRE_BATALLA: VALE con tres participantes válidos (índices en orden de entrada).
## Quien escucha cierra la pantalla.
signal equipo_torre_elegido(indices: Array[int])

## Modo TORRE_BATALLA: orden de los participantes (gSelectedOrderFromParty).
var torre: SeleccionEquipoTorre = null
const OPCION_ENTRAR: String = "ENTRAR"
const OPCION_NO_ENTRAR: String = "NO ENTRAR"
## Textos de la ROM española (OtherText_ThreePokeNeeded, _PokeCantBeSame,
## _NoIdenticalHoldItems y gOtherText_NoMoreThreePoke).
const TEXTOS_ERROR_TORRE: Dictionary = {
	SeleccionEquipoTorre.Fallo.FALTAN: "Necesitas tres POKéMON.",
	SeleccionEquipoTorre.Fallo.MISMA_ESPECIE: "POKéMON diferentes.",
	SeleccionEquipoTorre.Fallo.MISMO_OBJETO: "Ningún objeto idéntico.",
}
const TEXTO_NO_MAS_DE_TRES: String = "No pueden participar más\nde tres POKéMON."

## Enseñanza de una MT/MO en curso (USAR desde la mochila). Cada sesión tiene su número:
## si deja de ser vigente (`_ensenanza_vigente`) se cancela sin tocar nada.
var _ensenanza: EnsenanzaMaquina
var _sesion_ensenanza: int = 0
var _indice_ensenanza: int = -1
var _contexto_ensenanza: Dictionary = {}
var _selector_ensenanza: FichaOlvidarMovimiento
var _confirmacion_ensenanza: MenuConfirmacion
const PAUSA_ENSENANZA: StringName = &"ensenanza_maquina"
## Ficha para olvidar un movimiento (ShowSelectMovePokemonSummaryScreen). Por encima de
## la ficha del Pokémon (z 4) y de la caja de mensajes.
const SCN_FICHA_OLVIDAR: PackedScene = preload("res://UI/poke-info/ficha_olvidar_movimiento.tscn")
const Z_FICHA_OLVIDAR: int = 5

## Movimientos de campo con efecto implementado en el overworld (nombre interno).
const MOVIMIENTOS_CAMPO_IMPLEMENTADOS: Array[String] = ["VUELO", "SURF", "DESTELLO", "FUERZA", "GOLPEROCA", "CORTE", "DANOSECRETO", "TELETRANSP", "EXCAVAR", "BATIDO", "AMORTIGUADOR", "CASCADA", "BUCEO"]
## BATIDO y AMORTIGUADOR (fldeff_softboiled.c): pasan PS del usuario a otro
## Pokémon del equipo sin salir de la pantalla de equipo.
const MOVIMIENTOS_TRANSFERENCIA_PS: Array[String] = ["BATIDO", "AMORTIGUADOR"]
## OtherText_NotEnoughHP (cuadro pequeño). Provisional: original "Not enough
## HP...", no está en los textos extraídos de la ROM española.
const MENSAJE_PS_INSUFICIENTES := "No tiene suficientes PS."
## gOtherText_CantUseOnPoke (cuadro grande). Provisional: original "This can't
## be used on that POKéMON.", no está en los textos de la ROM española.
const MENSAJE_NO_SE_PUEDE_USAR_CON_POKEMON := "Esto no se puede usar con\nese POKéMON."
## SE_KAIFUKU de pokeruby (medicinas, BATIDO y AMORTIGUADOR).
const SONIDO_CURACION := "SE_USE_ITEM_KAIFUKU"
## IsBlueYellowRedFlute: suenan con SE_GLASS_FLUTE en vez de SE_USE_ITEM.
const SONIDO_FLAUTA := "SE_GLASS_FLUTE"
const FLAUTAS_MEDICINA: Array[String] = ["FLAUTAAZUL", "FLAMARILLA", "FLAUTAROJA"]
## PokemonMenu_FieldMove: los 8 primeros movimientos de campo (sFieldMoveFuncs
## 0-7) exigen FLAG_BADGE01_GET + índice. Se valida también para los que aún no
## están en MOVIMIENTOS_CAMPO_IMPLEMENTADOS, para cuando se implementen.
const MEDALLA_POR_MOVIMIENTO_CAMPO: Dictionary = {
	"CORTE": 0,		# Medalla Piedra
	"DESTELLO": 1,	# Medalla Puño
	"GOLPEROCA": 2,	# Medalla Dinamo
	"FUERZA": 3,	# Medalla Calor
	"SURF": 4,		# Medalla Equilibrio
	"VUELO": 5,		# Medalla Pluma
	"BUCEO": 6,		# Medalla Mente
	"CASCADA": 7,	# Medalla Lluvia
}
## OtherText_CantUseThatHere (cuadro pequeño).
const MENSAJE_NO_SE_PUEDE_USAR := "Aquí no puedes usar eso."
## gOtherText_CantBeUsedBadge (cuadro grande). Provisional: no está en los
## textos extraídos de la ROM española.
const MENSAJE_SIN_MEDALLA := "No podrás usarlo hasta que\nconsigas una nueva MEDALLA."
## Movimientos (nombre interno) que el menú del Pokémon lista en batalla. Vacía,
## como en pokeruby (ver puede_usar_en_batalla).
const MOVIMIENTOS_USABLES_EN_BATALLA: Array[String] = []
## Etiqueta del menú del Pokémon → nombre interno del movimiento de campo.
var _movimientos_campo_menu: Dictionary = {}

## Objeto de la mochila que se da en modo DAR_OBJETO (diccionario de la lista
## de la mochila: nombre_interno, nombre, ...) y su bolsillo (0-based).
var objeto_a_dar: Dictionary = {}
var bolsillo_objeto_a_dar: int = 0
## Medicina que se usa en los modos USAR_OBJETO y BATALLA_OBJETO (diccionario
## de la lista de la mochila) y su bolsillo (0-based), para gastarla.
var objeto_a_usar: Dictionary = {}
var bolsillo_objeto_a_usar: int = 0
## Solo en combate: BasePokemon -> PokemonEnCombate (o null si no está en el
## campo), para que la medicina quite estados volátiles como la confusión.
var obtener_combatiente: Callable = Callable()
## Posición del SÍ/NO del intercambio (DisplayYesNoMenu(23, 8) en party_menu.c).
const POSICION_SI_NO_DAR: Vector2 = Vector2(184, 64)
## Ventana de estadísticas del CARAMELORARO (la misma que en combate).
const SCN_CUADRO_SUBIR_NIVEL: PackedScene = preload("res://escenas/batalla/cuadro_subir_nivel.tscn")

# Nuevas variables específicas
# var contexto_origen: String = ""  # "menu_pausa", "batalla", etc.
# var modo_batalla: bool = false
var modo: Singleton.ModoPEquipo = Singleton.ModoPEquipo.NORMAL
var pokemon_actual_indice: int = -1

# Variables de memoria para navegación lateral
var ultimo_indice_derecha: int = 1

# Variables para el menú de selección de Pokémon
var menu_pokemon_activo: bool = false
var opciones_menu_pokemon: Array[String] = []
var indice_menu_pokemon: int = 0
var menu_pokemon_container: NinePatchRect
var labels_menu_pokemon: Array[Label] = []
var cursor_menu_pokemon: NinePatchRect
## true mientras se muestra el submenú OBJETO (DAR/QUITAR/SALIR) o CARTA
## (LEER/QUITAR/SALIR) en lugar del menú principal.
var submenu_objeto_activo: bool = false
## false = el cursor se detiene en los extremos (submenú OBJETO de Ruby).
var menu_cursor_circular: bool = true
## true mientras se elige el movimiento de un objeto de PP (_elegir_movimiento_objeto).
var _selector_movimiento_objeto_activo: bool = false
## Índice del movimiento elegido en ese selector, o -1 si se canceló con B.
signal _movimiento_objeto_elegido(indice: int)
## Alto de la ventana de CreateItemUseMoveMenu: siempre cuatro filas (10 tiles).
const ALTO_MENU_MOVIMIENTOS_OBJETO: int = 80

const TEXTO_MENU: LabelSettings = preload("res://UI/texto_normal_negro.tres")
const RUTA_MOCHILA: String = "res://UI/mochila/mochila.tscn"
const RUTA_PANTALLA_CARTA: String = "res://UI/cartas/pantalla_carta.tscn"
const RUTA_PALABRAS_FACILES: String = "res://UI/palabras_faciles/pantalla_palabras_faciles.tscn"
const OPCION_OBJETO: String = "OBJETO"
const OPCION_CARTA: String = "CARTA"
## Acción del modo GUARDERIA para depositar un Pokémon.
const OPCION_GUARDAR_GUARDERIA: String = "GUARDAR"
## battle_party_menu.c gOtherText_EGGCantBattle (no está en el decomp en español).
const TEXTO_HUEVO_NO_COMBATE: String = "¡Un HUEVO no puede combatir!"

# Variables para recordar estado antes de pantalla info
var menu_estaba_abierto_antes_info: bool = false

# Variables para el redimensionado del cuadro de mensaje
var cuadro_mensaje_tamano_original: Vector2
var cuadro_mensaje_posicion_original: Vector2

var cuadro_mensaje_tamaño_estándar: Vector2 = Vector2(240, 48)  # Tamaño estándar del cuadro de mensaje

# Variables para el modo de intercambio de posiciones
var modo_intercambio: bool = false
var pokemon_intercambio_origen: int = -1
## true si el modo intercambio está eligiendo a quién pasar PS con BATIDO o
## AMORTIGUADOR (pokemon_intercambio_origen es el usuario del movimiento).
var transferencia_ps_activa: bool = false
## Reproductor sin posición para los sonidos propios de la pantalla (el
## AudioStreamPlayer2D del administrador atenúa por distancia a su origen).
var _reproductor_sonidos: AudioStreamPlayer = null

# Constantes para las animaciones de intercambio
# pokeruby party_menu.c (sub_806D014..sub_806D15C, SpriteCB_sub_806D37C): cada frame las cajas
# se desplazan 1 tile (8 px) y el icono 8 px => 480 px/s a 60 fps. La primera caja sale 14
# tiles por la izquierda y las demás ~22 tiles por la derecha (de x=11 a >32 tiles).
const VELOCIDAD_INTERCAMBIO_PX_S: float = 8.0 * 60.0  # Píxeles por segundo (salida y entrada)
const DISTANCIA_SALIDA_IZQUIERDA: float = -104.0      # Píxeles hacia la izquierda para salir de pantalla
const DISTANCIA_SALIDA_DERECHA: float = 176.0         # Píxeles hacia la derecha para salir de pantalla

# Variables para la pantalla de información del Pokémon
var pantalla_info_pokemon: PantallaInfoPokemon = null

# Variables para transiciones de pantalla
var overlay_transicion: ColorRect = null
var tween_transicion: Tween = null

var mensaje_fijo: String = "Elegir un POKéMON."

func _ready() -> void:
	# Inicializar array de cajas para un fácil acceso
	cajas = [caja1, caja2, caja3, caja4, caja5, caja6]

	# Configurar la caja de texto
	caja_texto.set_cursor(cursor)

	# Guardar dimensiones originales del cuadro de mensaje
	cuadro_mensaje_tamano_original = cuadro_mensaje.size
	cuadro_mensaje_posicion_original = cuadro_mensaje.position

	# Inicializar overlay de transición
	inicializar_overlay_transicion()

	# Pre-cargar la pantalla de información (oculta)
	precargar_pantalla_info()

	# La pantalla empieza inactiva y oculta por defecto
	self.visible = false
	self.activo = false

	# Texturas de menús
	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		var tipo: int = SistemaGuardado.datos_vivos.opciones.imagen_tipo
		var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
		menu_box_manager.apply_texture_to_ninepatch(cuadro_mensaje, tipo)

func _input(event: InputEvent) -> void:
	if not activo:
		return

	# CajaTextoBatalla maneja su propio input para acelerar texto
	# Solo manejamos eventos específicos de la pantalla de equipo

	# Selector de movimiento de un objeto de PP (Task_HandleItemUseMoveMenuInput):
	# A sin sonido (lo pone el efecto), B con SE_SELECT.
	if _selector_movimiento_objeto_activo:
		if event.is_action_pressed("btn_abajo"):
			mover_cursor_menu_pokemon_abajo()
		elif event.is_action_pressed("btn_arriba"):
			mover_cursor_menu_pokemon_arriba()
		elif event.is_action_pressed("btn_accion"):
			_movimiento_objeto_elegido.emit(indice_menu_pokemon)
		elif event.is_action_pressed("btn_cancelar"):
			Singleton.emit_signal("play_sound", "cursor_menu")
			_movimiento_objeto_elegido.emit(-1)
		return

	# Si el menú de Pokémon está activo, manejar esos eventos primero
	if menu_pokemon_activo:
		if event.is_action_pressed("btn_abajo"):
			mover_cursor_menu_pokemon_abajo()
		elif event.is_action_pressed("btn_arriba"):
			mover_cursor_menu_pokemon_arriba()
		elif event.is_action_pressed("btn_accion"):
			ejecutar_accion_menu_pokemon()
		elif event.is_action_pressed("btn_cancelar"):
			# B en el submenú OBJETO vuelve al menú del Pokémon
			# (PokemonMenu_CancelSubmenu); en el de CARTA, a la lista (PokemonMenu_Cancel).
			Singleton.emit_signal("play_sound", "cursor_menu")
			if submenu_objeto_activo and not menu_cursor_circular:
				_volver_al_menu_pokemon(indice_menu_pokemon)
			else:
				cerrar_menu_pokemon()
		return

	# Navegación normal de la pantalla de equipo
	if event.is_action_pressed("btn_abajo"):
		_navegar_lista(mover_cursor_abajo)
	elif event.is_action_pressed("btn_arriba"):
		_navegar_lista(mover_cursor_arriba)
	elif event.is_action_pressed("btn_izquierda"):
		_navegar_lista(mover_cursor_izquierda)
	elif event.is_action_pressed("btn_derecha"):
		_navegar_lista(mover_cursor_derecha)
	elif event.is_action_pressed("btn_menu") and torre != null:
		# START lleva el cursor a VALE (SelectBattleTowerOKButton).
		_navegar_lista(establecer_cursor.bind(CURSOR_VALE))
	elif event.is_action_pressed("btn_accion"):
		ejecutar_accion()
	elif event.is_action_pressed("btn_cancelar"):
		# SE_SELECT también al salir de la pantalla o cancelar el CAMBIO.
		Singleton.emit_signal("play_sound", "cursor_menu")
		cancelar_seleccion()


## Mueve el cursor de la lista; suena SE_SELECT solo si ha cambiado de sitio
## (contra el borde no suena, como en la lista de la ROM).
func _navegar_lista(mover: Callable) -> void:
	var anterior: int = cursor_actual
	mover.call()
	if cursor_actual != anterior:
		Singleton.emit_signal("play_sound", "cursor_menu")

# --- API PÚBLICA ---

## Muestra la pantalla del equipo en un modo específico.
func mostrar_equipo_modo(modo_param: Singleton.ModoPEquipo, equipo_param: EquipoPokemon, mensaje_param: String = "Elegir un POKéMON.") -> void:
	modo = modo_param
	equipo_actual = equipo_param
	# En batalla el activo lo indica el propio equipo (crear_equipo_adaptado()
	# lo pone en la primera caja, como gBattlePartyCurrentOrder).
	pokemon_actual_indice = equipo_param.pokemon_actual_indice if equipo_param else 0
	# caja_texto.text = mensaje_param
	mensaje_fijo = mensaje_param
	# El cuadro puede venir agrandado del mensaje de un uso anterior (en
	# batalla la pantalla se reutiliza).
	cuadro_mensaje.size = cuadro_mensaje_tamano_original
	cuadro_mensaje.position = cuadro_mensaje_posicion_original
	caja_texto.mostrar_texto(mensaje_param, true)

	var tamaño_equipo: int = get_tamano_equipo()

	# Esta pantalla es una instancia persistente reutilizada en toda la
	# batalla/sesión (no se recrea cada apertura). Sin este reset, la caja que
	# quedó como CURSOR/SELECCIONADO en la sesión anterior (ej. el 3er poké)
	# se queda con ese estado visual "pegado" aunque el cursor real empiece
	# en la caja 0, porque el reset de establecer_cursor() solo limpia el
	# cursor_actual anterior, y aquí lo pisamos directamente a 0 sin pasar
	# por él.
	for caja in cajas:
		caja.establecer_estado(CajaEquipo.Estado.NORMAL)
		caja.quitar_foco_movil()
		caja.quitar_foco_fijo()

	# Rellenar las cajas con los datos de los Pokémon usando la nueva API
	for i in range(cajas.size()):
		if i < tamaño_equipo:
			var pokemon: BasePokemon = equipo_actual.pokemones[i]
			cajas[i].mostrar_datos_pokemon(pokemon)
		else:
			cajas[i].limpiar()
	_mostrar_descriptores_maquina()
	if modo != Singleton.ModoPEquipo.TORRE_BATALLA:
		torre = null
	boton_vale.visible = torre != null
	boton_vale_cursor.visible = false

	# Configurar estado inicial del cursor. La memoria puede venir de un equipo
	# más largo: se ajusta a la última caja.
	cursor_actual = 0
	if _modo_recuerda_cursor():
		cursor_actual = clampi(Singleton.equipo_ultimo_cursor, 0, maxi(tamaño_equipo - 1, 0))
	boton_salir.visible = false

	establecer_cursor(cursor_actual)

	# Activar la pantalla
	self.visible = true
	self.activo = true


## Inscripción en la TORRE BATALLA (sub_8121E34 + SetupBattleTowerPartyMenu): todas las
## cajas con PUEDE / NO PUEDE (`admitidos`, IsMonAllowedInBattleTower) y el botón VALE.
func mostrar_equipo_torre(equipo_param: EquipoPokemon, admitidos: Array[bool]) -> void:
	torre = SeleccionEquipoTorre.new(admitidos)
	mostrar_equipo_modo(Singleton.ModoPEquipo.TORRE_BATALLA, equipo_param)
	_dibujar_descriptores_torre()


func _dibujar_descriptores_torre() -> void:
	for i in range(mini(get_tamano_equipo(), cajas.size())):
		cajas[i].mostrar_descriptor(torre.descriptor(i))


## BattleTowerEntryMenuCallback_Enter: primer puesto libre; con el tercero el cursor
## pasa a VALE. Si ya hay tres, SE_FAILURE y aviso hasta A/B.
func _entrar_en_torre(indice: int) -> void:
	if torre.entrar(indice):
		cajas[indice].mostrar_descriptor(torre.descriptor(indice))
		cerrar_menu_pokemon()
		if torre.completa():
			establecer_cursor(CURSOR_VALE)
		return
	Singleton.play_sound.emit("SE_FAILURE")
	_destruir_menu_pokemon()
	menu_pokemon_activo = false
	activo = false
	await mostrar_mensaje_progresivo(TEXTO_NO_MAS_DE_TRES)
	Singleton.emit_signal("play_sound", "cursor_menu")
	_restaurar_cuadro_mensaje()
	activo = true


## sub_81224A8: VALE comprueba el equipo (sub_81220C8). Con un fallo el aviso queda en
## el cuadro pequeño hasta A/B; si no, emite equipo_torre_elegido.
func _confirmar_torre() -> void:
	var error := torre.validar(equipo_actual.pokemones)
	if error == SeleccionEquipoTorre.Fallo.NINGUNO:
		activo = false
		equipo_torre_elegido.emit(torre.orden.duplicate())
		return
	activo = false
	await _mostrar_aviso_cuadro_pequeno(str(TEXTOS_ERROR_TORRE[error]))
	# BattleTowerEntryMenuCallback_Exit.
	Singleton.emit_signal("play_sound", "cursor_menu")
	_restaurar_cuadro_mensaje()
	activo = true


## Modos de campo que comparten la memoria del cursor. En batalla no: el orden
## de las cajas es otro (el activo va primero).
func _modo_recuerda_cursor() -> bool:
	return modo == Singleton.ModoPEquipo.NORMAL \
		or modo == Singleton.ModoPEquipo.USAR_OBJETO \
		or modo == Singleton.ModoPEquipo.DAR_OBJETO


# --- LÓGICA DE NAVEGACIÓN ---

## Mueve el cursor a una nueva posición.
## Nueva_posicion: 0-5 = cajas, -1 = botón salir
func establecer_cursor(nueva_posicion: int) -> void:
	print("🎯 establecer_cursor() llamado - nueva_posicion: ", nueva_posicion, ", actual: ", cursor_actual)

	# Limpiar estado anterior
	if cursor_actual == CURSOR_VALE:
		boton_vale_cursor.visible = false
	elif cursor_actual == -1:
		# Estábamos en el botón de salir
		print("  🔽 Ocultando botón de salir")
		boton_salir.visible = false
	elif cursor_actual >= 0 and cursor_actual < get_tamano_equipo():
		# Estábamos en una caja
		var caja_anterior = cajas[cursor_actual]
		if caja_anterior.visible:
			var estado_anterior = obtener_estado_reposo(cursor_actual)
			print("  📦 Restaurando caja anterior ", cursor_actual, " a ", estado_anterior)
			caja_anterior.establecer_estado(estado_anterior)
			caja_anterior.quitar_foco_movil()

	# Establecer nuevo estado
	if nueva_posicion == CURSOR_VALE and torre != null:
		boton_vale_cursor.visible = true
		cursor_actual = CURSOR_VALE
	elif nueva_posicion == -1:
		# Ir al botón de salir
		print("  🔽 Mostrando botón de salir")
		boton_salir.visible = true
		cursor_actual = -1
	elif nueva_posicion >= 0 and nueva_posicion < get_tamano_equipo():
		# Ir a una caja
		cursor_actual = nueva_posicion
		var caja_actual = cajas[cursor_actual]
		print("  📦 Estableciendo caja ", cursor_actual, " a CURSOR")
		caja_actual.establecer_estado(CajaEquipo.Estado.CURSOR)
		caja_actual.poner_foco_movil()

		# Actualizar ultimo_indice_derecha si estamos en las cajas de la derecha (cajas 1-5)
		if nueva_posicion >= 1:
			ultimo_indice_derecha = nueva_posicion

## Navegación vertical hacia arriba.
## Si estamos en el botón de salir, saltamos al último Pokémon disponible.
func mover_cursor_arriba() -> void:
	# TORRE BATALLA (ChangeBattleTowerPartyMenuSelection): SALIR sube a VALE y VALE al último.
	if cursor_actual == -1 and torre != null:
		establecer_cursor(CURSOR_VALE)
	elif cursor_actual == -1 or cursor_actual == CURSOR_VALE:
		# Si estamos en el botón de salir, ir al último Pokémon disponible
		var ultimo_pokemon = get_ultimo_pokemon_disponible()
		if ultimo_pokemon >= 0:
			establecer_cursor(ultimo_pokemon)
	else:
		# Buscar el Pokémon anterior disponible
		var nueva_posicion = obtener_pokemon_anterior_disponible(cursor_actual)
		if nueva_posicion >= 0:
			establecer_cursor(nueva_posicion)
		else:
			# Si no hay Pokémon anteriores, ir al botón de salir
			establecer_cursor(-1)

## Navegación vertical hacia abajo.
## Si estamos en el botón de salir, saltamos al primer Pokémon disponible.
func mover_cursor_abajo() -> void:
	if cursor_actual == CURSOR_VALE:
		establecer_cursor(-1)
	elif cursor_actual == -1:
		# Si estamos en el botón de salir, ir al primer Pokémon disponible
		var primer_pokemon = obtener_primer_pokemon_disponible()
		if primer_pokemon >= 0:
			establecer_cursor(primer_pokemon)
	else:
		# Buscar el siguiente Pokémon disponible
		var nueva_posicion = obtener_pokemon_siguiente_disponible(cursor_actual)
		if nueva_posicion >= 0:
			establecer_cursor(nueva_posicion)
		else:
			# Si no hay más Pokémon, ir al botón de salir (en la TORRE BATALLA, a VALE)
			establecer_cursor(CURSOR_VALE if torre != null else -1)

## Navegación horizontal hacia la izquierda.
## Si estamos en las cajas de la derecha (1-5), saltamos a la caja principal (0).
## Si estamos en el botón de salir, no hacemos nada.
func mover_cursor_izquierda() -> void:
	if cursor_actual < 0:
		# Si estamos en el botón de salir, no hay navegación horizontal
		return

	# Si estamos en las cajas de la derecha (índices 1-5), ir a la caja principal (índice 0)
	if cursor_actual >= 1:
		# Solo saltar si la caja principal tiene un Pokémon
		if es_pokemon_disponible_para_navegacion(0):
			establecer_cursor(0)

## Navegación horizontal hacia la derecha.
## Si estamos en la caja principal (0), saltamos a la última caja tocada en la derecha.
## Si estamos en el botón de salir, no hacemos nada.
func mover_cursor_derecha() -> void:
	if cursor_actual < 0:
		# Si estamos en el botón de salir, no hay navegación horizontal
		return

	# Si estamos en la caja principal (índice 0), ir a la última caja tocada en la derecha
	if cursor_actual == 0:
		# Verificar que el último índice de la derecha sea válido y tenga un Pokémon
		if es_pokemon_disponible_para_navegacion(ultimo_indice_derecha):
			establecer_cursor(ultimo_indice_derecha)
		else:
			# Si el último índice no es válido, buscar el primer Pokémon disponible en la derecha
			var primer_pokemon_derecha = obtener_primer_pokemon_disponible_derecha()
			if primer_pokemon_derecha >= 0:
				establecer_cursor(primer_pokemon_derecha)

# --- LÓGICA DE ACCIONES ---

## Se ejecuta al presionar el botón de acción.
## Selecciona el Pokémon actualmente bajo el cursor o ejecuta la acción del botón de salir.
func ejecutar_accion() -> void:
	if cursor_actual == CURSOR_VALE:
		Singleton.emit_signal("play_sound", "cursor_menu")
		_confirmar_torre()
	elif cursor_actual == -1:
		Singleton.emit_signal("play_sound", "cursor_menu")
		if modo_intercambio:
			cancelar_modo_intercambio()
		else:
			cancelar_seleccion()
	elif modo_intercambio and transferencia_ps_activa:
		# transferir_ps_a suena por su cuenta.
		transferir_ps_a(cursor_actual)
	elif modo_intercambio:
		# En modo intercambio, ejecutar el intercambio con el Pokémon seleccionado
		Singleton.emit_signal("play_sound", "cursor_menu")
		ejecutar_intercambio(cursor_actual)
	else:
		# Modo normal, mostrar menú de Pokémon
		seleccionar_pokemon()

## Valida y muestra el menú de acciones para el Pokémon seleccionado.
func seleccionar_pokemon() -> void:
	if cursor_actual >= get_tamano_equipo() or cursor_actual < 0:
		return

	var pokemon_obj = equipo_actual.pokemones[cursor_actual]

	if _modo_recuerda_cursor():
		Singleton.equipo_ultimo_cursor = cursor_actual

	# NPC que pide elegir un POKéMON (ChoosePartyMon): elección directa, sin menú.
	if modo == Singleton.ModoPEquipo.ELEGIR:
		Singleton.emit_signal("play_sound", "cursor_menu")
		activo = false
		pokemon_elegido.emit(cursor_actual)
		return

	# TORRE BATALLA (HandleBattleTowerPartyMenu): A abre ENTRAR/NO ENTRAR/DATOS/SALIR.
	if modo == Singleton.ModoPEquipo.TORRE_BATALLA:
		Singleton.emit_signal("play_sound", "cursor_menu")
		mostrar_menu_pokemon(pokemon_obj)
		return

	if modo == Singleton.ModoPEquipo.DAR_OBJETO:
		if pokemon_obj.huevo:
			# TODO: sonido de error (SE_FAILURE) cuando exista en Singleton.se.
			return
		Singleton.emit_signal("play_sound", "cursor_menu")
		dar_objeto_a(cursor_actual)
		return

	# Medicina sobre un Pokémon (UseMedicine). Un huevo no se acepta (SE_HAZURE
	# en HandleBattlePartyMenu).
	if modo == Singleton.ModoPEquipo.USAR_OBJETO or modo == Singleton.ModoPEquipo.BATALLA_OBJETO:
		if pokemon_obj.huevo:
			# TODO: sonido de error (SE_FAILURE) cuando exista en Singleton.se.
			return
		Singleton.emit_signal("play_sound", "cursor_menu")
		usar_objeto_en(cursor_actual)
		return

	# Validaciones para el modo batalla
	if modo == Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO or modo == Singleton.ModoPEquipo.BATALLA_CAMBIO_OPCIONAL:
		if pokemon_obj.estad_ps_actual <= 0:
			caja_texto.text = "¡Ese POKéMON no tiene energía!"
			return
		if cursor_actual == pokemon_actual_indice or cursor_actual in get_meta("battle_blocked_visual_indices",[]):
			caja_texto.text = "¡Ese POKéMON ya está en combate!"
			return

	# Mostrar el menú de opciones para el pokémon seleccionado
	Singleton.emit_signal("play_sound", "cursor_menu")
	mostrar_menu_pokemon(pokemon_obj)

## Se ejecuta al presionar el botón de cancelar.
## Emite la señal correspondiente.
## Llamar a la función ocultar_pantalla_equipo() para ocultar la pantalla.
func cancelar_seleccion() -> void:
	print("🚫 cancelar_seleccion() llamada - modo:", modo)
	# Si estamos en modo intercambio, cancelarlo primero
	if modo_intercambio:
		cancelar_modo_intercambio()
		return

	# Comportamiento normal de cancelación
	match modo:
		Singleton.ModoPEquipo.NORMAL:
			print("🚫 Emitiendo pantalla_cerrada para modo NORMAL")
			emit_signal("pantalla_cerrada")
			# En modo normal (menú de pausa), NO ocultamos aquí porque el menú de pausa maneja la transición
		Singleton.ModoPEquipo.BATALLA_DATOS, Singleton.ModoPEquipo.BATALLA_CAMBIO_OPCIONAL, Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO:
			print("🚫 Emitiendo seleccion_cancelada para modo de batalla")
			emit_signal("seleccion_cancelada")
			# En modos de batalla, NO ocultamos aquí porque batalla.gd maneja la ocultación
		_:
			print("🚫 Emitiendo seleccion_cancelada para modo desconocido")
			emit_signal("seleccion_cancelada")

## Oculta la pantalla del equipo.
func ocultar_pantalla_equipo() -> void:
	activo = false
	visible = false

## Cierra la pantalla del equipo completamente, emitiendo las señales apropiadas y ocultándola.
func cerrar_pantalla() -> void:
	cancelar_seleccion()
	ocultar_pantalla_equipo()

# --- LÓGICA DEL MENÚ DE POKÉMON ---

## Muestra el menú de acciones para el Pokémon seleccionado.
func mostrar_menu_pokemon(pokemon_obj) -> void:
	# Cambiar el mensaje usando el nombre a mostrar del Pokémon
	caja_texto.text = pokemon_obj.get_nombre_mostrar() + " seleccionado."

	# Redimensionar el cuadro de mensaje para hacer espacio al menú
	# El cuadro termina donde empieza el menú (x = 152, ver ancho_menu en crear_menu_pokemon)
	var nuevo_ancho = 152
	cuadro_mensaje.size.x = nuevo_ancho

	# Construir las opciones del menú según el contexto
	opciones_menu_pokemon.clear()
	_movimientos_campo_menu.clear()

	# Agregar movimientos según el contexto (la guardería no lista movimientos)
	if modo != Singleton.ModoPEquipo.GUARDERIA and modo != Singleton.ModoPEquipo.TORRE_BATALLA \
			and pokemon_obj.movimientos != null and pokemon_obj.movimientos.size() > 0:
		for movimiento in pokemon_obj.movimientos:
			if movimiento is Movimiento and _nombre_interno_movimiento(movimiento) == "DANOSECRETO" \
				and (modo != Singleton.ModoPEquipo.NORMAL or pokemon_obj.huevo):
				continue
			if _es_modo_batalla():
				# En batalla (datos o cambio): los movimientos de campo (CORTE, SURF...) no se
				# ofrecen; solo los que cumplan puede_usar_en_batalla.
				if puede_usar_en_batalla(movimiento):
					opciones_menu_pokemon.append(movimiento.nombre.to_upper())
			else:
				# Fuera de batalla: verificar si puede usar en overworld
				if puede_usar_en_overworld(movimiento):
					var etiqueta: String = movimiento.nombre.to_upper()
					opciones_menu_pokemon.append(etiqueta)
					_movimientos_campo_menu[etiqueta] = _nombre_interno_movimiento(movimiento)

	# Agregar opciones fijas según el contexto (BATALLA_OBJETO y USAR_OBJETO
	# no llegan aquí: seleccionar_pokemon usa el objeto directamente).
	if modo == Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO or modo == Singleton.ModoPEquipo.BATALLA_CAMBIO_OPCIONAL or modo == Singleton.ModoPEquipo.BATALLA_DATOS:
		# Orden específico para batalla: CAMBIAR, DATOS, SALIR. Un huevo solo
		# tiene DATOS y SALIR (sBattlePartyPopupMenus[2] de battle_party_menu.c).
		if not pokemon_obj.huevo:
			opciones_menu_pokemon.append("CAMBIAR")
		opciones_menu_pokemon.append("DATOS")
		opciones_menu_pokemon.append("SALIR")
	elif modo == Singleton.ModoPEquipo.GUARDERIA:
		# GUARDAR, DATOS, SALIR; un huevo solo DATOS y SALIR (choose_party.c).
		if not pokemon_obj.huevo:
			opciones_menu_pokemon.append(OPCION_GUARDAR_GUARDERIA)
		opciones_menu_pokemon.append("DATOS")
		opciones_menu_pokemon.append("SALIR")
	elif modo == Singleton.ModoPEquipo.TORRE_BATALLA:
		# sBattleTowerEntryMenu (sub_81221F8): ENTRAR o NO ENTRAR si ya participa;
		# uno no admitido, solo DATOS y SALIR.
		if torre.admitido(cursor_actual):
			opciones_menu_pokemon.append(OPCION_NO_ENTRAR if torre.puesto(cursor_actual) >= 0 else OPCION_ENTRAR)
		opciones_menu_pokemon.append("DATOS")
		opciones_menu_pokemon.append("SALIR")
	else:
		# Orden para fuera de batalla: DATOS, [CAMBIO], OBJETO/CARTA, SALIR
		opciones_menu_pokemon.append("DATOS")

		# CAMBIO solo aparece si hay 2 o más Pokémon en el equipo
		if get_tamano_equipo() >= 2:
			opciones_menu_pokemon.append("CAMBIO")

		# Los huevos no tienen OBJETO; con una CARTA equipada la opción es CARTA
		# (POKEMENU_MAIL en pokemon_menu.c).
		if not pokemon_obj.huevo:
			opciones_menu_pokemon.append(OPCION_CARTA if ObjetosLlevados.es_carta(pokemon_obj.objeto) else OPCION_OBJETO)
		opciones_menu_pokemon.append("SALIR")

	# Crear el menú dinámicamente
	crear_menu_pokemon()

	# Activar el menú
	menu_pokemon_activo = true
	indice_menu_pokemon = 0
	actualizar_cursor_menu_pokemon()

## Crea dinámicamente el contenedor del menú de Pokémon.
func crear_menu_pokemon() -> void:
	# Cargar recursos
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	var img_type = 1
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		img_type = int(sg.datos_vivos.opciones.imagen_tipo)
	var cursor_texture = load("res://UI/cursor-menu.png") as Texture2D
	var label_settings: LabelSettings = TEXTO_MENU

	# Calcular dimensiones del menú
	var num_opciones = opciones_menu_pokemon.size()
	var ancho_menu = 88  # Crece hacia la izquierda: el borde derecho (x = 240) no se mueve
	var alto_menu = 16 + (num_opciones * 16)  # 8 top + 8 bottom + 16 por opción

	# Calcular posición para esquina inferior derecha
	# Usar dimensiones específicas de la pantalla de equipo (no del viewport completo)
	var pantalla_ancho = 248  # Dimensiones reales de la pantalla de equipo
	var pantalla_alto = 168   # Dimensiones reales de la pantalla de equipo

	var margen = 8  # Margen desde los bordes

	var pos_x = pantalla_ancho - ancho_menu - margen  # Esquina derecha
	var pos_y = pantalla_alto - alto_menu - margen    # Esquina inferior

	# Crear el contenedor principal
	menu_pokemon_container = NinePatchRect.new()
	# Aplicar textura dinámica según las opciones de guardado
	menu_box_manager.apply_texture_to_ninepatch(menu_pokemon_container, img_type)
	menu_pokemon_container.patch_margin_left = 8
	menu_pokemon_container.patch_margin_top = 8
	menu_pokemon_container.patch_margin_right = 8
	menu_pokemon_container.patch_margin_bottom = 8
	# Configurar Axis Stretch en Tile (horizontal y vertical)
	menu_pokemon_container.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	menu_pokemon_container.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	menu_pokemon_container.size = Vector2(ancho_menu, alto_menu)
	menu_pokemon_container.position = Vector2(pos_x, pos_y)  # Posición calculada dinámicamente

	# Asegurar que no esté centrado (aunque NinePatchRect no debería tener esta propiedad)
	print("🔧 Menú Pokémon creado en posición: (", pos_x, ", ", pos_y, ") tamaño: (", ancho_menu, ", ", alto_menu, ")")

	# Limpiar labels anteriores
	labels_menu_pokemon.clear()

	# Crear labels para cada opción
	for i in range(opciones_menu_pokemon.size()):
		var label = Label.new()
		label.text = opciones_menu_pokemon[i]
		label.label_settings = label_settings
		label.position = Vector2(8, 8 + (i * 16))
		label.size = Vector2(ancho_menu - 16, 16)
		label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		menu_pokemon_container.add_child(label)
		labels_menu_pokemon.append(label)

	# Crear cursor
	cursor_menu_pokemon = NinePatchRect.new()
	cursor_menu_pokemon.texture = cursor_texture
	cursor_menu_pokemon.patch_margin_left = 3
	cursor_menu_pokemon.patch_margin_top = 2
	cursor_menu_pokemon.patch_margin_right = 3
	cursor_menu_pokemon.patch_margin_bottom = 2
	cursor_menu_pokemon.position = Vector2(6, 6)
	cursor_menu_pokemon.size = Vector2(ancho_menu - 12, 18)  # Mismo margen a ambos lados del menú

	menu_pokemon_container.add_child(cursor_menu_pokemon)

	# Agregar el menú a la escena
	add_child(menu_pokemon_container)

## True si la pantalla se abrió desde un combate (datos, cambio opcional o forzado).
func _es_modo_batalla() -> bool:
	return modo == Singleton.ModoPEquipo.BATALLA_DATOS 		or modo == Singleton.ModoPEquipo.BATALLA_CAMBIO_OPCIONAL 		or modo == Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO


## Determina si un movimiento (`Movimiento`) se puede usar en el overworld: solo
## los movimientos de campo ya implementados (MOVIMIENTOS_CAMPO_IMPLEMENTADOS).
func puede_usar_en_overworld(movimiento) -> bool:
	if not (movimiento is Movimiento):
		return false
	return _nombre_interno_movimiento(movimiento) in MOVIMIENTOS_CAMPO_IMPLEMENTADOS


## Nombre interno del movimiento (p. ej. "VUELO"). Los movimientos de partida
## ya se cargan con su clave canónica (`Movimiento.desde_guardado`).
func _nombre_interno_movimiento(movimiento: Movimiento) -> String:
	return movimiento.get_nombre_interno()

## Determina si un movimiento (`Movimiento`) aparece en el menú del Pokémon
## durante la batalla (modo BATALLA_DATOS). En pokeruby ninguno lo hace: el menú
## de batalla (sBattlePartyMenuActions en battle_party_menu.c) solo tiene
## CAMBIAR, DATOS y SALIR; BATIDO/AMORTIGUADOR/TELETRANSP son movimientos de
## campo del menú de pausa. Se deja la lista para un futuro uso, hoy vacía.
func puede_usar_en_batalla(movimiento) -> bool:
	if not (movimiento is Movimiento):
		return false
	return _nombre_interno_movimiento(movimiento) in MOVIMIENTOS_USABLES_EN_BATALLA

## Actualiza la posición del cursor en el menú de Pokémon.
func actualizar_cursor_menu_pokemon() -> void:
	if cursor_menu_pokemon:
		cursor_menu_pokemon.position.y = 6 + (indice_menu_pokemon * 16)

## Mueve el cursor hacia arriba en el menú de Pokémon.
func mover_cursor_menu_pokemon_arriba() -> void:
	if not menu_cursor_circular and indice_menu_pokemon == 0:
		return
	Singleton.emit_signal("play_sound", "cursor_menu")
	indice_menu_pokemon = (indice_menu_pokemon - 1 + opciones_menu_pokemon.size()) % opciones_menu_pokemon.size()
	actualizar_cursor_menu_pokemon()

## Mueve el cursor hacia abajo en el menú de Pokémon.
func mover_cursor_menu_pokemon_abajo() -> void:
	if not menu_cursor_circular and indice_menu_pokemon == opciones_menu_pokemon.size() - 1:
		return
	Singleton.emit_signal("play_sound", "cursor_menu")
	indice_menu_pokemon = (indice_menu_pokemon + 1) % opciones_menu_pokemon.size()
	actualizar_cursor_menu_pokemon()

## Ejecuta la acción seleccionada en el menú de Pokémon.
func ejecutar_accion_menu_pokemon() -> void:
	Singleton.emit_signal("play_sound", "cursor_menu")
	var opcion_seleccionada = opciones_menu_pokemon[indice_menu_pokemon]

	if submenu_objeto_activo:
		_ejecutar_submenu_objeto(opcion_seleccionada)
		return

	match opcion_seleccionada:
		"DATOS":
			# Mostrar pantalla de información del Pokémon
			mostrar_pantalla_info_pokemon()
		"CAMBIO": # Esta opción solo aparece si hay 2 o más Pokémon y se ingresó por el menú de pausa
			# Activar modo de intercambio de posiciones
			activar_modo_intercambio()
		"CAMBIAR": # Esta opción solo aparece si se ingresó por el menú de batalla
			# Un huevo no puede salir a combatir (Task_BattlePartyMenuShift).
			if equipo_actual.pokemones[cursor_actual].huevo:
				cerrar_menu_pokemon()
				mostrar_mensaje_progresivo(TEXTO_HUEVO_NO_COMBATE, Callable(self, "cerrar_menu_pokemon"))
			# Task_BattlePartyMenuShift: con 0 PS no sale, sea cual sea su estado.
			elif equipo_actual.pokemones[cursor_actual].estad_ps_actual <= 0:
				cerrar_menu_pokemon()
				mostrar_mensaje_progresivo("¡%s no tiene\nenergía para luchar!" % equipo_actual.pokemones[cursor_actual].get_nombre_mostrar(), Callable(self, "cerrar_menu_pokemon"))
			# En BATALLA_DATOS no se puede elegir al Pokémon que ya está combatiendo
			elif modo == Singleton.ModoPEquipo.BATALLA_DATOS and cursor_actual == pokemon_actual_indice:
				# Cerrar el menú y mostrar mensaje de que ya está luchando
				cerrar_menu_pokemon()
				var nombre_pokemon = equipo_actual.pokemones[cursor_actual].get_nombre_mostrar()
				var callback_mensaje = Callable(self, "cerrar_menu_pokemon")
				mostrar_mensaje_progresivo("¡%s ya está\nluchando!" % nombre_pokemon.to_upper(), callback_mensaje)
			else:
				# Emitir señal para cambiar Pokémon en batalla
				cerrar_menu_pokemon()
				activo = false
				visible = false
				emit_signal("pokemon_elegido", cursor_actual)
		OPCION_OBJETO:
			_abrir_submenu_objeto(false)
		OPCION_CARTA:
			_abrir_submenu_objeto(true)
		OPCION_GUARDAR_GUARDERIA:
			# Quien escucha (la Abuela de la Guardería) cierra la pantalla.
			cerrar_menu_pokemon()
			activo = false
			pokemon_elegido.emit(cursor_actual)
		OPCION_ENTRAR:
			_entrar_en_torre(cursor_actual)
		OPCION_NO_ENTRAR:
			# BattleTowerEntryMenuCallback_NoEntry: los siguientes adelantan un puesto.
			torre.quitar(cursor_actual)
			_dibujar_descriptores_torre()
			cerrar_menu_pokemon()
		"SALIR" when modo == Singleton.ModoPEquipo.GUARDERIA or modo == Singleton.ModoPEquipo.TORRE_BATALLA:
			# Como el menú emergente de Ruby: vuelve a la lista.
			cerrar_menu_pokemon()
		"SALIR" when bool(get_meta("source_baton_chooser",false)) or bool(get_meta("relevo_doble_obligatorio",false)):
			cerrar_menu_pokemon();activo=true;visible=true
		"SALIR":
			print("🚪 Ejecutando SALIR desde menú Pokemon")
			cerrar_menu_pokemon()
			print("🚪 Menú cerrado, desactivando pantalla...")
			activo = false
			visible = false
			print("🚪 Emitiendo señal de cancelación...")
			cancelar_seleccion()
		_:
			# Es un movimiento (overworld o batalla)
			if modo == Singleton.ModoPEquipo.BATALLA_DATOS:
				# TODO: Ejecutar movimiento en batalla
				print("Usar movimiento en batalla: ", opcion_seleccionada)
			elif _movimientos_campo_menu.has(opcion_seleccionada):
				_usar_movimiento_campo(str(_movimientos_campo_menu[opcion_seleccionada]))
				return
			else:
				print("Usar movimiento en overworld: ", opcion_seleccionada)
			cerrar_menu_pokemon()


## Movimiento de campo elegido en el menú del Pokémon. VUELO y TELETRANSP no se
## pueden usar en interiores ni bajo el agua, SURF sin agua surfeable delante, CASCADA sin
## surfear mirando una cascada, BUCEO sin agua buceable o sin poder emerger, DESTELLO sin
## Medalla Puño, fuera de una cueva oscura o si ya se usó, ni EXCAVAR fuera de
## una cueva o sin entrada exterior, ni FUERZA si ya está activa ni GOLPEROCA sin una roca rompible delante ni CORTE sin
## un árbol cortable delante ni hierba cortable alrededor (mensaje y se sigue en la lista); BATIDO y AMORTIGUADOR piden 1/5 de los PS máximos y se resuelven
## en esta pantalla. Si procede, se cierra el menú y se avisa con
## movimiento_campo_elegido.
func _usar_movimiento_campo(movimiento: String) -> void:
	# PokemonMenu_FieldMove: sin la medalla, sub_806E834 (cuadro grande hasta A/B).
	if not tiene_medalla_para(movimiento):
		_destruir_menu_pokemon()
		menu_pokemon_activo = false
		activo = false
		await _mostrar_mensaje_dar(MENSAJE_SIN_MEDALLA)
		await _volver_a_lista()
		return
	# SetUpFieldMove_Strength / _Fly / FldEff_UseDig: el puzle en braille de la sala se
	# comprueba antes que las condiciones normales (VUELO en un interior, EXCAVAR sin salida).
	var resuelve_puzle := PuzleBraille.para_movimiento(movimiento) != null
	var no_se_puede := ((movimiento == "VUELO" or movimiento == "TELETRANSP") and _mapa_actual_es_interior()) \
		or (movimiento == "SURF" and not _jugador_puede_usar_surf()) \
		or (movimiento == "CASCADA" and not _jugador_puede_usar_cascada()) 		or (movimiento == "BUCEO" and not _jugador_puede_usar_buceo()) \
		or (movimiento == "DESTELLO" and not _puede_usar_destello()) 		or (movimiento == "FUERZA" and ControladorRocaFuerza.fuerza_activa()) 		or (movimiento == "GOLPEROCA" and ControladorRocaRomper.roca_frente_jugador() == null) \
		or (movimiento == "CORTE" and not _hay_algo_que_cortar()) \
		or (movimiento == "EXCAVAR" and not UsoObjetosCampo.puede_escapar_aqui()) \
		or (movimiento == "DANOSECRETO" and not AccesoDanoSecreto.puede_usar(equipo_actual.pokemones[cursor_actual]))
	no_se_puede = no_se_puede and not resuelve_puzle
	var sin_ps := movimiento in MOVIMIENTOS_TRANSFERENCIA_PS \
		and not puede_usar_transferencia_ps(equipo_actual.pokemones[cursor_actual])
	if no_se_puede or sin_ps:
		_destruir_menu_pokemon()
		menu_pokemon_activo = false
		activo = false
		await _mostrar_aviso_cuadro_pequeno(MENSAJE_PS_INSUFICIENTES if sin_ps else MENSAJE_NO_SE_PUEDE_USAR)
		await _volver_a_lista()
		return
	if movimiento in MOVIMIENTOS_TRANSFERENCIA_PS:
		activar_transferencia_ps()
		return
	cerrar_menu_pokemon()
	if movimiento_campo_elegido.get_connections().is_empty():
		print("Movimiento de campo sin receptor: ", movimiento)
		return
	# Quien escucha cierra esta pantalla; mientras tanto no se acepta más input.
	activo = false
	movimiento_campo_elegido.emit(cursor_actual, movimiento)


## SetUpFieldMove_Cut: un árbol cortable delante o, si no, hierba alta/muy alta o
## con ceniza en el cuadrado 3x3 centrado en el jugador.
func _hay_algo_que_cortar() -> bool:
	return ControladorArbolCortable.arbol_frente_jugador() != null \
		or HierbaCortableMapa.hierba_cortable_junto_al_jugador()


## SetUpFieldMove_Surf: el jugador no surfea ya y tiene delante agua surfeable.
func _jugador_puede_usar_surf() -> bool:
	var admin := get_tree().root.get_node_or_null("AdministradorMapa")
	var jugador: Node = admin.get("jugador") if admin != null else null
	return jugador != null and jugador.has_method("puede_usar_surf") and bool(jugador.call("puede_usar_surf"))


## SetUpFieldMove_Waterfall: el jugador surfea mirando al norte una cascada.
func _jugador_puede_usar_cascada() -> bool:
	var admin := get_tree().root.get_node_or_null("AdministradorMapa")
	var jugador: Node = admin.get("jugador") if admin != null else null
	return jugador != null and jugador.has_method("puede_usar_cascada") and bool(jugador.call("puede_usar_cascada"))


## SetUpFieldMove_Dive (TrySetDiveWarp): surfeando sobre agua buceable con un
## mapa submarino de destino, o bajo el agua donde se puede emerger.
func _jugador_puede_usar_buceo() -> bool:
	var admin := get_tree().root.get_node_or_null("AdministradorMapa")
	var jugador: Node = admin.get("jugador") if admin != null else null
	return jugador != null and jugador.has_method("puede_usar_buceo") and bool(jugador.call("puede_usar_buceo"))


## SetUpFieldMove_Flash: Medalla Puño, cueva oscura y Destello sin usar.
func _puede_usar_destello() -> bool:
	var admin := get_tree().root.get_node_or_null("AdministradorMapa")
	var mapa_actual = admin.get("mapa_actual") if admin != null else null
	if not (mapa_actual is MapaConfiguracion):
		return false
	return EfectoOscuridadCueva.puede_usar_destello(
		mapa_actual, _medallas_jugador(), EfectoOscuridadCueva.destello_activo()
	)


func _medallas_jugador() -> Variant:
	return SistemaGuardado.datos_vivos.jugador.get("medallas", [])


## ¿Tiene el jugador la medalla que exige `movimiento` (nombre interno)? Los
## movimientos sin medalla (TELETRANSP, BATIDO...) siempre devuelven true.
static func tiene_medalla_para(movimiento: String) -> bool:
	if not MEDALLA_POR_MOVIMIENTO_CAMPO.has(movimiento):
		return true
	return SistemaGuardado.tiene_medalla(int(MEDALLA_POR_MOVIMIENTO_CAMPO[movimiento]))


## PrintPartyMenuPromptText + sub_808ABF4: el aviso sale al instante en el cuadro
## pequeño del mensaje fijo y se espera A/B (sin flecha).
func _mostrar_aviso_cuadro_pequeno(mensaje: String) -> void:
	cuadro_mensaje.size = cuadro_mensaje_tamano_original
	cuadro_mensaje.position = cuadro_mensaje_posicion_original
	await caja_texto.mostrar_texto(FormateadorLigaduras.formatear(mensaje), true)
	await caja_texto.esperar_input_continuar(Callable(), false)


func _mapa_actual_es_interior() -> bool:
	var admin := get_tree().root.get_node_or_null("AdministradorMapa")
	if admin == null:
		return false
	return not mapa_permite_vuelo_y_teletransporte(admin.get("mapa_actual"))


## Overworld_MapTypeAllowsTeleportAndFly: rutas, pueblos, ciudades y rutas
## marinas (MapaConfiguracion.esInterior = false); no edificios ni cuevas.
static func mapa_permite_vuelo_y_teletransporte(mapa: Variant) -> bool:
	if not (mapa is MapaConfiguracion):
		return true
	var config := mapa as MapaConfiguracion
	# MAP_TYPE_UNDERWATER tampoco está en la lista de Overworld_MapTypeAllowsTeleportAndFly.
	return not config.esInterior and not config.mapa_submarino

## Cierra el menú de Pokémon y vuelve a la navegación normal.
func cerrar_menu_pokemon() -> void:
	print("🔄 Cerrando menú Pokemon - menu_pokemon_activo:", menu_pokemon_activo)
	menu_pokemon_activo = false
	_restaurar_cuadro_mensaje()
	_destruir_menu_pokemon()


## Vuelve a mostrar el mensaje fijo con el cuadro en su tamaño original.
func _restaurar_cuadro_mensaje() -> void:
	caja_texto.mostrar_texto(mensaje_fijo, true)
	cuadro_mensaje.size = cuadro_mensaje_tamano_original
	cuadro_mensaje.position = cuadro_mensaje_posicion_original


## Quita la ventana del menú (principal o submenú OBJETO) sin tocar el mensaje.
func _destruir_menu_pokemon() -> void:
	submenu_objeto_activo = false
	menu_cursor_circular = true
	if menu_pokemon_container:
		print("🔄 Eliminando menu_pokemon_container")
		remove_child(menu_pokemon_container)
		menu_pokemon_container.queue_free()
		menu_pokemon_container = null

	# Limpiar arrays
	labels_menu_pokemon.clear()
	opciones_menu_pokemon.clear()
	print("🔄 Menú Pokemon cerrado completamente")

## Muestra un mensaje personalizado de forma progresiva usando CajaTextoBatalla.
## El cuadro se asegura de estar en tamaño estándar.
func mostrar_mensaje_progresivo(mensaje: String, callback: Callable = Callable()) -> void:
	# PartyMenuEraseMsgBoxAndFrame: el cuadro se vacía antes de agrandarse. El
	# "Elegir un POKéMON." ya se leyó, así que no espera los 64 frames de lectura.
	caja_texto.limpiar()
	# Asegurar que el cuadro esté en su tamaño estándar
	cuadro_mensaje.size = cuadro_mensaje_tamaño_estándar
	cuadro_mensaje.position = cuadro_mensaje_posicion_original - Vector2(0, 16)

	# Usar CajaTextoBatalla para mostrar el texto
	await caja_texto.mostrar_texto(mensaje)

	# Si hay callback, esperar input para continuar
	if callback.is_valid():
		await caja_texto.esperar_input_continuar(callback)
	else:
		# Si no hay callback, aún necesitamos esperar input para continuar
		await caja_texto.esperar_input_continuar(Callable())

# --- SUBMENÚ OBJETO / CARTA (PokemonMenu_Item / PokemonMenu_Mail) ---

## Sustituye el menú principal por DAR/QUITAR/SALIR ("¿Qué hacer con el
## objeto?", cursor sin vuelta) o, si lleva una CARTA, LEER/QUITAR/SALIR.
func _abrir_submenu_objeto(es_carta: bool) -> void:
	_destruir_menu_pokemon()
	submenu_objeto_activo = true
	menu_cursor_circular = es_carta
	if es_carta:
		opciones_menu_pokemon.append_array(["LEER", "QUITAR", "SALIR"])
	else:
		opciones_menu_pokemon.append_array(["DAR", "QUITAR", "SALIR"])
		caja_texto.text = FormateadorLigaduras.formatear(tr("EQUIPO_QUE_HACER_OBJETO"))
	crear_menu_pokemon()
	indice_menu_pokemon = 0
	actualizar_cursor_menu_pokemon()


func _ejecutar_submenu_objeto(opcion: String) -> void:
	match opcion:
		"DAR":
			_dar_desde_mochila(cursor_actual)
		"QUITAR":
			_quitar_objeto(cursor_actual)
		"LEER":
			_leer_carta(cursor_actual)
		_:
			# SALIR (PokemonMenu_CancelSubmenu): vuelve al menú del Pokémon.
			_volver_al_menu_pokemon(indice_menu_pokemon)


## Vuelve a mostrar el menú del Pokémon seleccionado con el cursor en
## `cursor_menu`. Como sub_8089C7C(sPokeMenuCursorPos), al salir del submenú
## se reutiliza la posición del cursor del submenú.
func _volver_al_menu_pokemon(cursor_menu: int) -> void:
	_destruir_menu_pokemon()
	mostrar_menu_pokemon(equipo_actual.pokemones[cursor_actual])
	indice_menu_pokemon = clampi(cursor_menu, 0, opciones_menu_pokemon.size() - 1)
	actualizar_cursor_menu_pokemon()


## LEER (PokemonMenu_ReadMail): fundido, la carta que lleva el Pokémon `indice`
## (firmada por el jugador: aún no se escriben cartas) y, al cerrarla, vuelta a
## la lista con otro fundido (sub_808A8A8).
func _leer_carta(indice: int) -> void:
	cerrar_menu_pokemon()
	activo = false
	await Singleton.transicion("oscurecer")
	var pantalla: PantallaCarta = (load(RUTA_PANTALLA_CARTA) as PackedScene).instantiate() as PantallaCarta
	visible = false
	get_parent().add_child(pantalla)
	pantalla.abrir(DatosCarta.desde_pokemon(equipo_actual.pokemones[indice], SistemaGuardado.get_nombre_jugador()))
	await pantalla.carta_cerrada
	pantalla.get_parent().remove_child(pantalla)
	pantalla.queue_free()
	visible = true
	await Singleton.transicion("aclarar")
	await _volver_a_lista()


## DAR (PokemonMenu_GiveItem): abre la mochila; al elegir un objeto que se
## puede llevar vuelve al equipo y se lo da al Pokémon `indice`. Con B vuelve
## al menú del Pokémon (sub_808A3A4 → sub_8089E84, cursor en la primera opción).
func _dar_desde_mochila(indice: int) -> void:
	cerrar_menu_pokemon()
	activo = false
	await Singleton.transicion("oscurecer")
	var mochila: MochilaUI = (load(RUTA_MOCHILA) as PackedScene).instantiate() as MochilaUI
	var eleccion: Dictionary = {}
	mochila.objeto_seleccionado_selector.connect(
		func(objeto: Dictionary) -> void: eleccion.merge(objeto)
	)
	visible = false
	# Hermana de la pantalla de equipo (como la mochila con su DAR); se aclara sola.
	get_parent().add_child(mochila)
	mochila.activar_modo_dar_equipo()
	await mochila.mochila_cerrada
	mochila.get_parent().remove_child(mochila)
	mochila.queue_free()
	if eleccion.is_empty():
		_volver_al_menu_pokemon(0)
		visible = true
		await Singleton.transicion("aclarar")
		await get_tree().process_frame
		activo = true
		return
	visible = true
	await Singleton.transicion("aclarar")
	objeto_a_dar = eleccion
	bolsillo_objeto_a_dar = int(eleccion.get("bolsillo_id", 0))
	await _intentar_dar_objeto(indice)
	objeto_a_dar = {}
	await _volver_a_lista()


## QUITAR (PartyMenuTryGiveMonHeldItem_806ECE8): guarda en la mochila el
## objeto que lleva el Pokémon `indice`.
func _quitar_objeto(indice: int) -> void:
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	var nombre_mon: String = pokemon.get_nombre_mostrar()
	_destruir_menu_pokemon()
	menu_pokemon_activo = false
	activo = false
	if not ObjetosLlevados.lleva_objeto(pokemon):
		await _mostrar_mensaje_dar(tr("EQUIPO_NO_LLEVA_NADA").replace("{mon}", nombre_mon))
	else:
		var antiguo: String = pokemon.objeto
		if ObjetosLlevados.es_carta(antiguo):
			# TODO: DoTakeMail pregunta si enviar la CARTA al PC (buzón no implementado).
			print("📨 [EQUIPO] QUITAR CARTA: se guarda en la mochila (buzón del PC no implementado)")
		if ObjetosLlevados.quitar_objeto(pokemon):
			cajas[indice].actualizar_objeto_llevado(pokemon)
			await _mostrar_mensaje_dar(tr("EQUIPO_OBJETO_RECIBIDO")
				.replace("{key}", ObjetosLlevados.nombre_objeto(antiguo)).replace("{mon}", nombre_mon))
	await _volver_a_lista()


## Tras un mensaje del submenú: mensaje fijo y control de la lista. Se espera
## un frame para que la pulsación que cerró el mensaje no llegue a _input.
func _volver_a_lista() -> void:
	_restaurar_cuadro_mensaje()
	await get_tree().process_frame
	activo = true


# --- LÓGICA DE DAR OBJETO (modo DAR_OBJETO) ---

## Modo DAR_OBJETO (desde la mochila): da `objeto_a_dar` al Pokémon `indice`
## y al acabar emite dar_objeto_terminado.
func dar_objeto_a(indice: int) -> void:
	if indice < 0 or indice >= get_tamano_equipo():
		return
	activo = false
	await _intentar_dar_objeto(indice)
	dar_objeto_terminado.emit()


## Da `objeto_a_dar` al Pokémon `indice` (PartyMenuTryGiveMonHeldItem de
## pokeruby). La lógica de inventario vive en ObjetosLlevados; aquí sólo se
## muestran los mensajes y el SÍ/NO del intercambio.
func _intentar_dar_objeto(indice: int) -> void:
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	var nuevo: String = str(objeto_a_dar.get("nombre_interno", ""))
	var nombre_nuevo: String = str(objeto_a_dar.get("nombre", ObjetosLlevados.nombre_objeto(nuevo)))
	var nombre_mon: String = pokemon.get_nombre_mostrar()

	match ObjetosLlevados.dar_objeto(pokemon, nuevo, bolsillo_objeto_a_dar):
		ObjetosLlevados.ResultadoDar.EQUIPADO:
			cajas[indice].actualizar_objeto_llevado(pokemon)
			# PartyMenuTryGiveMonHeldItem: con una CARTA no hay mensaje hasta
			# escribirla (sub_808A228 → sub_808A5BC).
			if ObjetosLlevados.es_carta(nuevo) and not await _escribir_carta(indice, ""):
				return
			await _mostrar_mensaje_dar(tr("EQUIPO_DAR_OBJETO").replace("{mon}", nombre_mon).replace("{key}", nombre_nuevo))
		ObjetosLlevados.ResultadoDar.YA_LLEVA_CARTA:
			await _mostrar_mensaje_dar(tr("EQUIPO_QUITAR_CARTA_ANTES"))
		ObjetosLlevados.ResultadoDar.YA_LLEVA_OBJETO:
			var nombre_antiguo: String = ObjetosLlevados.nombre_objeto(pokemon.objeto)
			var pregunta: String = tr("EQUIPO_YA_LLEVA").replace("{mon}", nombre_mon).replace("{key2}", nombre_antiguo)
			# La última página queda en pantalla mientras se muestra el SÍ/NO.
			await _mostrar_mensaje_dar(pregunta, false)
			if await _preguntar_si_no(POSICION_SI_NO_DAR):
				var antiguo: String = pokemon.objeto
				if ObjetosLlevados.intercambiar_objeto(pokemon, nuevo, bolsillo_objeto_a_dar):
					cajas[indice].actualizar_objeto_llevado(pokemon)
					if ObjetosLlevados.es_carta(nuevo):
						# PartyMenuTryGiveMonHeldItem_806EACC: «Recibido X de Y.» y a escribir.
						await _mostrar_mensaje_dar(tr("EQUIPO_OBJETO_RECIBIDO").replace("{key}", nombre_antiguo).replace("{mon}", nombre_mon))
						if await _escribir_carta(indice, antiguo):
							await _mostrar_mensaje_dar(tr("EQUIPO_DAR_OBJETO").replace("{mon}", nombre_mon).replace("{key}", nombre_nuevo))
					else:
						await _mostrar_mensaje_dar(tr("EQUIPO_OBJETO_CAMBIADO").replace("{key2}", nombre_antiguo).replace("{key}", nombre_nuevo))
		_:
			push_warning("[EQUIPO] No se pudo dar %s a %s" % [nuevo, nombre_mon])


## Escribe la CARTA recién dada al Pokémon `indice` (sub_808A180 → sub_80E62A0
## con el modo 4 de PALABRAS FÁCILES). Si se cancela (sub_808A520 con
## gSpecialVar_Result = 0) la carta vuelve a la mochila y el Pokémon recupera
## `objeto_anterior` (que se saca otra vez de la mochila). Devuelve true si se
## escribió.
func _escribir_carta(indice: int, objeto_anterior: String) -> bool:
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	activo = false
	await Singleton.transicion("oscurecer")
	var pantalla: PantallaPalabrasFaciles = (load(RUTA_PALABRAS_FACILES) as PackedScene).instantiate() as PantallaPalabrasFaciles
	visible = false
	get_parent().add_child(pantalla)
	pantalla.abrir(PantallaPalabrasFaciles.Modo.CARTA, DatosCarta.ids_de(pokemon))
	var resultado: Array = await pantalla.terminada
	pantalla.get_parent().remove_child(pantalla)
	pantalla.queue_free()
	var aceptada: bool = bool(resultado[0])
	if aceptada:
		var ids: Array[int] = []
		ids.assign(resultado[1])
		DatosCarta.escribir(pokemon, ids, SistemaGuardado.get_nombre_jugador(), int(SistemaGuardado.datos_vivos.jugador.get("id", 0)))
	else:
		var carta: String = pokemon.objeto
		if not objeto_anterior.is_empty():
			SistemaGuardado.quitar_objeto_jugador(objeto_anterior, 1, ObjetosLlevados.bolsillo_de(objeto_anterior))
		SistemaGuardado.dar_objeto_jugador(carta, 1)
		pokemon.carta = {}
		pokemon.objeto = objeto_anterior
		cajas[indice].actualizar_objeto_llevado(pokemon)
	visible = true
	await Singleton.transicion("aclarar")
	return aceptada


## Muestra un mensaje (con páginas \p) en la caja de la pantalla de equipo.
## Si `esperar_ultima` es false la última página no espera A/B.
func _mostrar_mensaje_dar(mensaje: String, esperar_ultima: bool = true) -> void:
	var paginas: PackedStringArray = FormateadorLigaduras.formatear(mensaje).split("\\p")
	for i in range(paginas.size()):
		if i < paginas.size() - 1 or esperar_ultima:
			await mostrar_mensaje_progresivo(paginas[i])
		else:
			cuadro_mensaje.size = cuadro_mensaje_tamaño_estándar
			cuadro_mensaje.position = cuadro_mensaje_posicion_original - Vector2(0, 16)
			await caja_texto.mostrar_texto(paginas[i])


# --- LÓGICA DE USAR OBJETO (modos USAR_OBJETO y BATALLA_OBJETO) ---

## Usa `objeto_a_usar` sobre el Pokémon `indice` (UseMedicine de pokeruby):
## el efecto lo decide EfectosMedicina; aquí se anima la caja (estado al
## momento; barra y número de PS a la vez), se gasta 1 unidad si hubo efecto,
## se muestra el mensaje hasta pulsar A y se emite objeto_usado. Sin efecto
## suena SE_SELECT, sale "No tendrá ningún efecto." y no se gasta nada.
func usar_objeto_en(indice: int) -> void:
	if indice < 0 or indice >= get_tamano_equipo():
		return
	activo = false
	match str(objeto_a_usar.get("uso_campo", "")):
		DatosMaquinas.USO_CAMPO:
			if DatosMaquinas.es_maquina(objeto_a_usar):
				await _usar_maquina(indice)
				return
			await _mostrar_mensaje_dar(tr("MEDICINA_SIN_EFECTO"))
			objeto_usado.emit(indice, false)
			return
		UsoObjetosCampo.USO_PIEDRA_EVOLUTIVA:
			await _usar_piedra_evolutiva(indice)
			return
		UsoObjetosCampo.USO_CARAMELORARO:
			await _usar_caramelo_raro(indice)
			return
	if EfectosPP.es_soportado(str(objeto_a_usar.get("nombre_interno", ""))):
		await _usar_objeto_pp(indice)
		return
	if EfectosVitaminas.es_soportado(str(objeto_a_usar.get("nombre_interno", ""))):
		await _usar_vitamina(indice)
		return
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	var nombre_interno: String = str(objeto_a_usar.get("nombre_interno", "")).to_upper()
	var en_batalla: bool = modo == Singleton.ModoPEquipo.BATALLA_OBJETO
	var combatiente: PokemonEnCombate = null
	if en_batalla and obtener_combatiente.is_valid():
		combatiente = obtener_combatiente.call(pokemon) as PokemonEnCombate
	var resultado: EfectosMedicina.ResultadoMedicina = EfectosMedicina.aplicar(
		nombre_interno, pokemon, en_batalla, combatiente)
	if resultado.tuvo_efecto:
		await _animar_medicina(indice, pokemon, resultado)
		if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, bolsillo_objeto_a_usar):
			push_warning("[EQUIPO] No se pudo quitar 1 x %s del bolsillo %d" % [nombre_interno, bolsillo_objeto_a_usar])
	else:
		Singleton.emit_signal("play_sound", "cursor_menu")
	await _mostrar_mensaje_dar(resultado.mensaje)
	objeto_usado.emit(indice, resultado.tuvo_efecto)


## UseMedicine tras aplicar el efecto: SE_USE_ITEM (SE_GLASS_FLUTE con las
## flautas: IsBlueYellowRedFlute), el estado al momento y la barra y el número
## de PS a la vez.
func _animar_medicina(indice: int, pokemon: BasePokemon, resultado: EfectosMedicina.ResultadoMedicina) -> void:
	var es_flauta: bool = str(objeto_a_usar.get("nombre_interno", "")).to_upper() in FLAUTAS_MEDICINA
	_reproducir_sonido(SONIDO_FLAUTA if es_flauta else SONIDO_CURACION)
	var caja: CajaEquipo = cajas[indice]
	caja.actualizar_sprite_estado(pokemon)
	if resultado.ps_despues != resultado.ps_antes:
		await caja.animar_ps(resultado.ps_antes, resultado.ps_despues, pokemon.estad_ps)
	# El icono cambia de ritmo con los PS (SetMonIconAnim) y vuelve a
	# balancearse si el Pokémon ha revivido.
	caja.configurar_animacion_icono()
	if cursor_actual == indice:
		caja.aplicar_animacion_cursor()


## `DoSacredAshItemEffect` (ITEM_USE_ALL_MONS): aplica `objeto_a_usar` a cada
## Pokémon del equipo por orden, con su animación y mensaje ("{mon} ha
## recuperado la salud."). Si alguno revivió se gasta 1; si ninguno, "No tendrá
## ningún efecto.". Al final se emite objeto_usado (índice 0).
func usar_objeto_en_todos() -> void:
	activo = false
	var nombre_interno: String = str(objeto_a_usar.get("nombre_interno", "")).to_upper()
	var alguno: bool = false
	for indice in range(get_tamano_equipo()):
		var pokemon: BasePokemon = equipo_actual.pokemones[indice]
		var resultado: EfectosMedicina.ResultadoMedicina = EfectosMedicina.aplicar(nombre_interno, pokemon)
		if not resultado.tuvo_efecto:
			continue
		alguno = true
		await _animar_medicina(indice, pokemon, resultado)
		await _mostrar_mensaje_dar(resultado.mensaje)
	if alguno:
		if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, bolsillo_objeto_a_usar):
			push_warning("[EQUIPO] No se pudo quitar 1 x %s del bolsillo %d" % [nombre_interno, bolsillo_objeto_a_usar])
	else:
		await _mostrar_mensaje_dar(EfectosMedicina.texto(EfectosMedicina.CLAVE_SIN_EFECTO))
	objeto_usado.emit(0, alguno)


## `DoPPRecoveryItemEffect` / `DoPPUpItemEffect` + `DoRecoverPP`: ÉTER, BAYA
## ZANAMA, MÁS PP y MÁX. PP piden antes el movimiento (con B se vuelve a elegir
## Pokémon sin gastar nada); ELIXIR los restaura todos. Con efecto suena
## SE_USE_ITEM, se gasta 1 y sale "PP restaurados." o "PP de X subieron.".
func _usar_objeto_pp(indice: int) -> void:
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	var nombre_interno: String = str(objeto_a_usar.get("nombre_interno", "")).to_upper()
	var indice_movimiento: int = 0
	if EfectosPP.pide_movimiento(nombre_interno):
		indice_movimiento = await _elegir_movimiento_objeto(pokemon, EfectosPP.texto_pregunta(nombre_interno))
		if indice_movimiento < 0:
			# ItemUseMoveMenu_HandleCancel: vuelve a "¿Usar en qué POKéMON?".
			_restaurar_cuadro_mensaje()
			activo = true
			return
	var resultado: EfectosPP.ResultadoPP = EfectosPP.aplicar(nombre_interno, pokemon, indice_movimiento)
	if resultado.tuvo_efecto:
		_reproducir_sonido(SONIDO_CURACION)
		if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, bolsillo_objeto_a_usar):
			push_warning("[EQUIPO] No se pudo quitar 1 x %s del bolsillo %d" % [nombre_interno, bolsillo_objeto_a_usar])
	else:
		Singleton.emit_signal("play_sound", "cursor_menu")
	await _mostrar_mensaje_dar(resultado.mensaje)
	objeto_usado.emit(indice, resultado.tuvo_efecto)


## `UseMedicine` con una vitamina: con efecto suena SE_USE_ITEM, se gasta 1 y sale
## "{stat} de {mon} subió."; sin efecto, SE_SELECT y "No tendrá ningún efecto.".
func _usar_vitamina(indice: int) -> void:
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	var nombre_interno: String = str(objeto_a_usar.get("nombre_interno", "")).to_upper()
	var resultado: EfectosVitaminas.ResultadoVitamina = EfectosVitaminas.aplicar(nombre_interno, pokemon)
	if resultado.tuvo_efecto:
		_reproducir_sonido(SONIDO_CURACION)
		if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, bolsillo_objeto_a_usar):
			push_warning("[EQUIPO] No se pudo quitar 1 x %s del bolsillo %d" % [nombre_interno, bolsillo_objeto_a_usar])
		# MÁS PS cambia los PS máximos y actuales de la caja.
		cajas[indice].mostrar_datos_pokemon(pokemon)
	else:
		Singleton.emit_signal("play_sound", "cursor_menu")
	await _mostrar_mensaje_dar(resultado.mensaje)
	objeto_usado.emit(indice, resultado.tuvo_efecto)


## `CreateItemUseMoveMenu` + `Task_HandleItemUseMoveMenuInput`: ventana fija de
## cuatro filas (tiles 19,10-29,19) con los movimientos del Pokémon y la
## pregunta en el cuadro pequeño. Devuelve el índice elegido o -1 con B.
func _elegir_movimiento_objeto(pokemon: BasePokemon, pregunta: String) -> int:
	cuadro_mensaje.size.x = 152
	caja_texto.mostrar_texto(FormateadorLigaduras.formatear(pregunta), true)
	opciones_menu_pokemon.clear()
	for movimiento: Movimiento in pokemon.movimientos:
		if movimiento != null:
			opciones_menu_pokemon.append(movimiento.nombre.to_upper())
	crear_menu_pokemon()
	menu_pokemon_container.size.y = ALTO_MENU_MOVIMIENTOS_OBJETO
	menu_pokemon_container.position.y = 168 - ALTO_MENU_MOVIMIENTOS_OBJETO - 8
	indice_menu_pokemon = 0
	actualizar_cursor_menu_pokemon()
	_selector_movimiento_objeto_activo = true
	activo = true
	var elegido: int = await _movimiento_objeto_elegido
	_selector_movimiento_objeto_activo = false
	activo = false
	_destruir_menu_pokemon()
	return elegido


## `DoEvolutionStoneItemEffect`: si la piedra hace evolucionar al Pokémon se
## gasta y se lanza la escena (sin poder cancelarla); si no, "No tendrá ningún
## efecto." Después se vuelve a la mochila (gCB2_AfterEvolution = sub_80A53F8).
func _usar_piedra_evolutiva(indice: int) -> void:
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	var nombre_interno: String = str(objeto_a_usar.get("nombre_interno", ""))
	var destino := EvolucionPokemon.especie_destino(pokemon, EvolucionPokemon.Modo.OBJETO, nombre_interno)
	if destino.is_empty():
		Singleton.emit_signal("play_sound", "cursor_menu")
		await _mostrar_mensaje_dar(tr("MEDICINA_SIN_EFECTO"))
		objeto_usado.emit(indice, false)
		return
	if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, bolsillo_objeto_a_usar):
		push_warning("[EQUIPO] No se pudo quitar 1 x %s del bolsillo %d" % [nombre_interno, bolsillo_objeto_a_usar])
	await EscenaEvolucionAnim.ejecutar_en(get_tree(), pokemon, destino, false, SistemaGuardado.get_equipo(), false, true)
	objeto_usado.emit(indice, true)


## `DoRareCandyItemEffect` + `Task_RareCandy1..3`: sube un nivel (con la
## amistad del efecto del objeto), "¡{mon} subió al nivel N!" con la fanfarria,
## ventana de estadísticas, movimientos nuevos y, si procede, evolución
## (cancelable). Sin efecto a nivel 100.
func _usar_caramelo_raro(indice: int) -> void:
	var pokemon: BasePokemon = equipo_actual.pokemones[indice]
	var nombre_interno: String = str(objeto_a_usar.get("nombre_interno", ""))
	if pokemon.nivel >= 100:
		Singleton.emit_signal("play_sound", "cursor_menu")
		await _mostrar_mensaje_dar(tr("MEDICINA_SIN_EFECTO"))
		objeto_usado.emit(indice, false)
		return
	var antes := _estadisticas_caramelo(pokemon)
	CarameloRaro.aplicar(pokemon)
	var despues := _estadisticas_caramelo(pokemon)
	if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, bolsillo_objeto_a_usar):
		push_warning("[EQUIPO] No se pudo quitar 1 x %s del bolsillo %d" % [nombre_interno, bolsillo_objeto_a_usar])
	# RedrawPokemonInfoInMenu: nivel, PS e icono al momento, sin animar.
	cajas[indice].mostrar_datos_pokemon(pokemon)
	# La fanfarria suena mientras se lee el mensaje (Task_RareCandy1).
	Fanfarria.reproducir(self, CarameloRaro.TEMA_FANFARRIA)
	await _mostrar_mensaje_dar(tr("CARAMELO_SUBIO_NIVEL").replace("{mon}", pokemon.get_nombre_mostrar()).replace("{nivel}", str(pokemon.nivel)))
	await _mostrar_ventana_subida_nivel(antes, despues)
	await DialogoAprendizaje.ejecutar(pokemon, self)
	var destino := EvolucionPokemon.especie_destino(pokemon, EvolucionPokemon.Modo.NIVEL)
	if not destino.is_empty():
		await EscenaEvolucionAnim.ejecutar_en(get_tree(), pokemon, destino, true, SistemaGuardado.get_equipo(), false, true)
	objeto_usado.emit(indice, true)


func _estadisticas_caramelo(pokemon: BasePokemon) -> Dictionary:
	return {
		"ps": pokemon.estad_ps,
		"ataque": pokemon.estad_ataque,
		"defensa": pokemon.estad_defensa,
		"ataque_especial": pokemon.estad_ataque_especial,
		"defensa_especial": pokemon.estad_defensa_especial,
		"velocidad": pokemon.estad_velocidad,
	}


## PrintStatGrowthsInLevelUpWindow / PrintNewStatsInLevelUpWindow: subidas,
## A/B, totales, A/B y se cierra (misma ventana que en combate).
func _mostrar_ventana_subida_nivel(antes: Dictionary, despues: Dictionary) -> void:
	var ventana := SCN_CUADRO_SUBIR_NIVEL.instantiate() as CuadroSubirNivel
	ventana.z_index = 5
	add_child(ventana)
	ventana.mostrar_subida(antes, despues)
	while ventana.esta_activo():
		await get_tree().process_frame
		if Input.is_action_just_pressed("btn_accion") or Input.is_action_just_pressed("btn_cancelar"):
			Singleton.emit_signal("play_sound", "cursor_menu")
			ventana.avanzar_estado()
	ventana.queue_free()


## `TeachMonTMMove` (gPokemonItemUseCallback de `StartTeachMonTMHMMove`): enseña la
## MT/MO `objeto_a_usar` al Pokémon `indice`. Al terminar, con o sin éxito, se emite
## `objeto_usado` y la mochila cierra el equipo (sub_808B508 → sub_808B224).
func _usar_maquina(indice: int) -> void:
	if _ensenanza != null: return
	if modo != Singleton.ModoPEquipo.USAR_OBJETO:
		await _mostrar_mensaje_dar(tr("MEDICINA_SIN_EFECTO"))
		objeto_usado.emit(indice, false)
		return
	_sesion_ensenanza += 1
	var sesion: int = _sesion_ensenanza
	_indice_ensenanza = indice
	_ensenanza = EnsenanzaMaquina.new(equipo_actual.pokemones[indice], str(objeto_a_usar.get("nombre_interno", "")), bolsillo_objeto_a_usar)
	var admin: Node = get_node_or_null("/root/AdministradorMapa")
	_contexto_ensenanza = {"admin": admin, "mapa": admin.get("mapa_actual") if admin != null else null,
		"item": objeto_a_usar.duplicate(true), "bolsillo": bolsillo_objeto_a_usar}
	Singleton.mantener_pausa(PAUSA_ENSENANZA, true)
	var aprendida: bool = await DialogoMaquina.ejecutar(_ensenanza, self, _ensenanza_vigente.bind(sesion))
	if sesion == _sesion_ensenanza: _finalizar_ensenanza(aprendida)


func _ensenanza_vigente(sesion: int) -> bool:
	if sesion != _sesion_ensenanza or _ensenanza == null or not is_inside_tree() or is_queued_for_deletion() \
		or modo != Singleton.ModoPEquipo.USAR_OBJETO \
		or objeto_a_usar != _contexto_ensenanza.get("item") or bolsillo_objeto_a_usar != int(_contexto_ensenanza.get("bolsillo", -1)) \
		or _ensenanza._partida != SistemaGuardado.datos_vivos or not SistemaGuardado.get_equipo().has(_ensenanza.pokemon) \
		or not equipo_actual.pokemones.has(_ensenanza.pokemon): return false
	var admin: Node = _contexto_ensenanza.get("admin")
	if admin != null and (not is_instance_valid(admin) or admin.get("mapa_actual") != _contexto_ensenanza.get("mapa") or int(admin.get("coneccion")) != 0): return false
	return _ensenanza.aprendida or _ensenanza.vigente()


func _process(_delta: float) -> void:
	if _ensenanza != null and not _ensenanza_vigente(_sesion_ensenanza): cancelar_ensenanza()


func cancelar_ensenanza() -> void:
	if _ensenanza == null: return
	_finalizar_ensenanza(_ensenanza.aprendida)


func _finalizar_ensenanza(aprendida: bool, notificar: bool = true) -> void:
	_sesion_ensenanza += 1
	var indice: int = _indice_ensenanza
	_ensenanza = null
	_contexto_ensenanza.clear()
	Singleton.mantener_pausa(PAUSA_ENSENANZA, false)
	if is_instance_valid(_selector_ensenanza): _selector_ensenanza.call("cancelar")
	if is_instance_valid(_confirmacion_ensenanza): _confirmacion_ensenanza.call("cancelar")
	if notificar: objeto_usado.emit(indice, aprendida)


func _exit_tree() -> void:
	if _ensenanza != null: _finalizar_ensenanza(_ensenanza.aprendida, false)


## `sub_806F390` (SÍ) → "¿Qué movimiento debe olvidar?" → fundido a la ficha
## (ShowSelectMovePokemonSummaryScreen). Al volver, el equipo se redibuja sin los
## PUEDE/NO PUEDE (sub_808B518 no llama a sub_808AE8C).
func elegir_movimiento_maquina(aprendizaje: AprendizajeMovimientos, _nombre_mov: String) -> int:
	var sesion: int = _sesion_ensenanza
	await _mostrar_mensaje_dar(DatosMaquinas.texto("MAQUINA_ELEGIR_MOVIMIENTO"), false)
	if not _ensenanza_vigente(sesion): return FichaOlvidarMovimiento.INDICE_NUEVO
	# `_finalizar_ensenanza` la cierra con `cancelar()` (= B) si la sesión deja de ser válida.
	var ficha := _crear_ficha_olvidar()
	_selector_ensenanza = ficha
	var indice: int = await ficha.elegir_aprendizaje(aprendizaje)
	ficha.queue_free()
	_selector_ensenanza = null
	_quitar_descriptores_maquina()
	return indice


func _crear_ficha_olvidar() -> FichaOlvidarMovimiento:
	var ficha: FichaOlvidarMovimiento = SCN_FICHA_OLVIDAR.instantiate()
	ficha.z_index = Z_FICHA_OLVIDAR
	add_child(ficha)
	return ficha


## `sub_808AE8C`: en modo USAR_OBJETO con una MT/MO, cada caja muestra PUEDE, NO PUEDE
## o APRENDIDO en lugar de la barra y los números de PS.
func _mostrar_descriptores_maquina() -> void:
	if modo != Singleton.ModoPEquipo.USAR_OBJETO or not DatosMaquinas.es_maquina(objeto_a_usar):
		return
	var objeto: String = str(objeto_a_usar.get("nombre_interno", ""))
	var datos := DatosCrianza.new()
	for i in range(mini(get_tamano_equipo(), cajas.size())):
		cajas[i].mostrar_descriptor(DatosMaquinas.descriptor(equipo_actual.pokemones[i], objeto, datos))


## Pone un rótulo por caja en lugar de la barra y los números de PS (`sub_80F9C00`,
## equipo de un concurso).
func mostrar_descriptores(descriptores: Array[int]) -> void:
	for i in range(mini(descriptores.size(), cajas.size())):
		cajas[i].mostrar_descriptor(descriptores[i])


func _quitar_descriptores_maquina() -> void:
	for i in range(mini(get_tamano_equipo(), cajas.size())):
		cajas[i].quitar_descriptor()


# --- Interfaz de DialogoAprendizaje (CARAMELORARO) y DialogoMaquina (MT/MO) ---

func mostrar_texto_aprendizaje(texto: String) -> void:
	await _mostrar_mensaje_dar(texto)


func preguntar_aprendizaje(texto: String) -> bool:
	var sesion: int = _sesion_ensenanza
	var ensenando: bool = _ensenanza != null
	await _mostrar_mensaje_dar(texto, false)
	if ensenando:
		if not _ensenanza_vigente(sesion): return false
		var menu: MenuConfirmacion = preload("res://UI/maquinas/confirmacion_maquina.tscn").instantiate()
		_confirmacion_ensenanza = menu
		add_child(menu)
		menu.crear_menu(POSICION_SI_NO_DAR)
		var respuesta: String = await menu.opcion_seleccionada
		menu.queue_free()
		_confirmacion_ensenanza = null
		return respuesta == "Y"
	return await _preguntar_si_no(POSICION_SI_NO_DAR)


func anunciar_movimiento_aprendido(texto: String) -> void:
	Fanfarria.reproducir(self, CarameloRaro.TEMA_FANFARRIA)
	await _mostrar_mensaje_dar(texto)


func elegir_movimiento_aprendizaje(aprendizaje: AprendizajeMovimientos, _nombre_mov: String) -> int:
	await _mostrar_mensaje_dar(tr("EVOLUCION_MOV_CUAL"), false)
	var ficha := _crear_ficha_olvidar()
	var indice: int = await ficha.elegir_aprendizaje(aprendizaje)
	ficha.queue_free()
	return indice


## Ventana SÍ/NO (UI/MenuConfirmacion.gd). CANCELAR equivale a NO.
func _preguntar_si_no(posicion: Vector2) -> bool:
	var menu := MenuConfirmacion.new()
	menu.z_index = 5
	add_child(menu)
	menu.crear_menu(posicion)
	var respuesta: String = await menu.opcion_seleccionada
	menu.queue_free()
	return respuesta == "Y"

# --- LÓGICA DE INTERCAMBIO DE POSICIONES ---

## Activa el modo de intercambio de posiciones de Pokémon.
func activar_modo_intercambio() -> void:
	modo_intercambio = true
	pokemon_intercambio_origen = cursor_actual

	# Establecer estado SELECCIONADO en la caja de origen
	cajas[pokemon_intercambio_origen].establecer_estado(CajaEquipo.Estado.SELECCIONADO)
	cajas[pokemon_intercambio_origen].poner_foco_fijo()

	# Cerrar el menú de Pokémon
	cerrar_menu_pokemon()

	# Cambiar el mensaje fijo
	caja_texto.text = "¿Mover a qué posición?"

	print("🔄 Modo intercambio activado para posición: ", pokemon_intercambio_origen)

## Ejecuta el intercambio entre dos Pokémon del equipo con animación.
func ejecutar_intercambio(destino: int) -> void:
	if pokemon_intercambio_origen >= 0 and destino >= 0 and pokemon_intercambio_origen != destino:
		# Establecer estado SELECCIONADO en la caja de destino
		cajas[destino].establecer_estado(CajaEquipo.Estado.SELECCIONADO)

		# Iniciar la animación de intercambio
		iniciar_animacion_intercambio(pokemon_intercambio_origen, destino)
	else:
		# Si se selecciona la misma caja, cancelar
		cancelar_modo_intercambio()

## Inicia la animación de intercambio con salida y entrada de cajas.
func iniciar_animacion_intercambio(origen: int, destino: int) -> void:
	print("🎬 Iniciando animación de intercambio: ", origen, " ↔ ", destino)

	# Desactivar controles durante la animación
	activo = false

	# Calcular posiciones de salida (fuera de pantalla) usando las constantes
	var pos_salida_izquierda = Vector2(DISTANCIA_SALIDA_IZQUIERDA, 0)
	var pos_salida_derecha = Vector2(DISTANCIA_SALIDA_DERECHA, 0)

	# Guardar posiciones originales
	var pos_original_origen = cajas[origen].position
	var pos_original_destino = cajas[destino].position

	# Crear tween para la animación
	var tween = create_tween()
	tween.set_parallel(true)  # Permitir múltiples animaciones simultáneas

	# FASE 1: Sacar las cajas de la pantalla usando la constante de velocidad
	if origen == 0:
		# La primera caja sale por la izquierda
		tween.tween_property(cajas[origen], "position", pos_original_origen + pos_salida_izquierda, _duracion_intercambio(pos_salida_izquierda))
	else:
		# Las demás cajas salen por la derecha
		tween.tween_property(cajas[origen], "position", pos_original_origen + pos_salida_derecha, _duracion_intercambio(pos_salida_derecha))

	if destino == 0:
		# La primera caja sale por la izquierda
		tween.tween_property(cajas[destino], "position", pos_original_destino + pos_salida_izquierda, _duracion_intercambio(pos_salida_izquierda))
	else:
		# Las demás cajas salen por la derecha
		tween.tween_property(cajas[destino], "position", pos_original_destino + pos_salida_derecha, _duracion_intercambio(pos_salida_derecha))

	# FASE 2: Esperar que termine la salida, intercambiar datos, y hacer entrar las cajas
	await tween.finished

	# Intercambiar los datos de los Pokémon
	var temp = equipo_actual.pokemones[origen]
	equipo_actual.pokemones[origen] = equipo_actual.pokemones[destino]
	equipo_actual.pokemones[destino] = temp

	# Actualizar la visualización de las cajas (mientras están fuera de pantalla)
	cajas[origen].mostrar_datos_pokemon(equipo_actual.pokemones[origen])
	cajas[destino].mostrar_datos_pokemon(equipo_actual.pokemones[destino])

	# FASE 3: Hacer entrar las cajas desde sus posiciones de salida usando la constante de velocidad
	var tween2 = create_tween()
	tween2.set_parallel(true)

	tween2.tween_property(cajas[origen], "position", pos_original_origen, _duracion_intercambio(Vector2(DISTANCIA_SALIDA_IZQUIERDA if origen == 0 else DISTANCIA_SALIDA_DERECHA, 0)))
	tween2.tween_property(cajas[destino], "position", pos_original_destino, _duracion_intercambio(Vector2(DISTANCIA_SALIDA_IZQUIERDA if destino == 0 else DISTANCIA_SALIDA_DERECHA, 0)))

	await tween2.finished

	# FASE 4: Finalizar animación
	finalizar_animacion_intercambio(destino)

## Segundos que tarda una caja en recorrer `desplazamiento` a la velocidad del decomp.
func _duracion_intercambio(desplazamiento: Vector2) -> float:
	return absf(desplazamiento.x) / VELOCIDAD_INTERCAMBIO_PX_S

## Finaliza la animación de intercambio y restaura el estado normal.
func finalizar_animacion_intercambio(nueva_posicion_cursor: int) -> void:
	print("🎬 Animación de intercambio completada")

	# Restaurar estados normales de todas las cajas que estaban seleccionadas
	print("🔧 Limpiando estados de todas las cajas...")
	for i in range(cajas.size()):
		if i < get_tamano_equipo():
			print("  📦 Caja ", i, " - Limpiando foco móvil y fijo")
			cajas[i].quitar_foco_movil()
			cajas[i].quitar_foco_fijo()
			print("  📦 Caja ", i, " - Focos limpiados")

	# Limpiar variables del modo intercambio ANTES de establecer cursor
	modo_intercambio = false
	cajas[pokemon_intercambio_origen].establecer_estado(CajaEquipo.Estado.NORMAL)
	pokemon_intercambio_origen = -1
	caja_texto.text = "Elegir un POKéMON."
	print("🔄 Variables de intercambio limpiadas")

	# Reactivar controles
	activo = true

	# Mantener el cursor en la nueva posición del Pokémon intercambiado
	print("🎯 Estableciendo cursor en nueva posición: ", nueva_posicion_cursor)
	establecer_cursor(nueva_posicion_cursor)

	print("✅ Animación finalizada correctamente")

## Cancela el modo de intercambio y vuelve al estado normal.
func cancelar_modo_intercambio() -> void:
	print("🔄 cancelar_modo_intercambio() - origen: ", pokemon_intercambio_origen, ", actual: ", cursor_actual, ", cursor_en_boton: ", cursor_actual == -1)
	if transferencia_ps_activa:
		# El SE_SELECT de B o CANCELAR lo emite quien llama (_input / ejecutar_accion).
		transferencia_ps_activa = false

	# Restaurar estados normales de todas las cajas
	if pokemon_intercambio_origen >= 0:
		print("  📦 Restaurando caja origen ", pokemon_intercambio_origen, " a NORMAL")
		cajas[pokemon_intercambio_origen].establecer_estado(CajaEquipo.Estado.NORMAL)
		cajas[pokemon_intercambio_origen].quitar_foco_fijo()

	# Restaurar estado del cursor actual SOLO si NO estamos en el botón de salir
	if cursor_actual != -1 and cursor_actual >= 0 and cursor_actual < get_tamano_equipo():
		print("  📦 Estableciendo caja actual ", cursor_actual, " a CURSOR")
		cajas[cursor_actual].establecer_estado(CajaEquipo.Estado.CURSOR)
	elif cursor_actual == -1:
		print("  🔽 Manteniendo botón de salir visible")

	modo_intercambio = false
	pokemon_intercambio_origen = -1
	caja_texto.text = "Elegir un POKéMON."

	print("🔄 Modo intercambio cancelado")

# --- BATIDO / AMORTIGUADOR (fldeff_softboiled.c) ---

## SetUpFieldMove_SoftBoiled: hace falta tener al menos 1/5 de los PS máximos
## (división entera, como en Rubí: con justo 1/5 el usuario queda a 0 PS).
static func puede_usar_transferencia_ps(usuario: BasePokemon) -> bool:
	return usuario != null and not usuario.huevo \
		and usuario.estad_ps_actual >= cantidad_transferencia_ps(usuario)


## PS que pierde el usuario: 1/5 de sus PS máximos (división entera).
@warning_ignore("integer_division")
static func cantidad_transferencia_ps(usuario: BasePokemon) -> int:
	return usuario.estad_ps / 5 if usuario != null else 0


## sub_8133D50: no vale el propio usuario, un Pokémon debilitado ni uno con los
## PS llenos (ni un huevo, que no tiene PS que curar).
static func objetivo_valido_transferencia_ps(usuario: BasePokemon, objetivo: BasePokemon) -> bool:
	if usuario == null or objetivo == null or objetivo == usuario or objetivo.huevo:
		return false
	return objetivo.estad_ps_actual > 0 and objetivo.estad_ps_actual < objetivo.estad_ps


## Pasa los PS: el usuario pierde cantidad_transferencia_ps y el objetivo los
## recupera sin pasar de su máximo. Devuelve los PS recuperados por el objetivo.
static func aplicar_transferencia_ps(usuario: BasePokemon, objetivo: BasePokemon) -> int:
	var cantidad := cantidad_transferencia_ps(usuario)
	var curados := mini(cantidad, objetivo.estad_ps - objetivo.estad_ps_actual)
	usuario.estad_ps_actual = maxi(usuario.estad_ps_actual - cantidad, 0)
	# Con justo ps_max / 5 el usuario queda a 0 (también en Rubí): el combate
	# solo descarta a los que tienen el estado DEBILITADO.
	if usuario.estad_ps_actual == 0:
		usuario.estado = Singleton.ProblemaEstado.DEBILITADO
	objetivo.estad_ps_actual += curados
	return curados


## sub_8133D28: el cursor del modo CAMBIO elige a quién curar, con la caja del
## usuario marcada y "¿Usar en qué POKéMON?" en el cuadro pequeño.
func activar_transferencia_ps() -> void:
	activar_modo_intercambio()
	transferencia_ps_activa = true
	_mostrar_texto_transferencia_ps()


func _mostrar_texto_transferencia_ps() -> void:
	cuadro_mensaje.size = cuadro_mensaje_tamano_original
	cuadro_mensaje.position = cuadro_mensaje_posicion_original
	caja_texto.text = FormateadorLigaduras.formatear(tr("EQUIPO_USAR_EN_QUIEN"))


## A sobre el Pokémon `destino` mientras se elige a quién curar (sub_8133D50).
## Si no vale, "Esto no se puede usar con ese POKéMON." y se sigue eligiendo; si
## vale, SE_KAIFUKU, baja la barra del usuario, SE_KAIFUKU, sube la del
## objetivo, mensaje de PS recuperados y vuelta a la lista (sub_8133EF8).
func transferir_ps_a(destino: int) -> void:
	if pokemon_intercambio_origen < 0 or destino < 0 or destino >= get_tamano_equipo():
		return
	activo = false
	Singleton.emit_signal("play_sound", "cursor_menu")
	var origen: int = pokemon_intercambio_origen
	var usuario: BasePokemon = equipo_actual.pokemones[origen]
	var objetivo: BasePokemon = equipo_actual.pokemones[destino]
	if not objetivo_valido_transferencia_ps(usuario, objetivo):
		await _mostrar_mensaje_dar(MENSAJE_NO_SE_PUEDE_USAR_CON_POKEMON)
		_mostrar_texto_transferencia_ps()
		await get_tree().process_frame
		activo = true
		return
	var ps_usuario_antes: int = usuario.estad_ps_actual
	var ps_objetivo_antes: int = objetivo.estad_ps_actual
	var curados := aplicar_transferencia_ps(usuario, objetivo)
	# sub_806D5A4: el cuadro de la pregunta se borra mientras se animan las barras.
	cuadro_mensaje.visible = false
	_reproducir_sonido(SONIDO_CURACION)
	await cajas[origen].animar_ps(ps_usuario_antes, usuario.estad_ps_actual, usuario.estad_ps)
	cajas[origen].configurar_animacion_icono()
	_reproducir_sonido(SONIDO_CURACION)
	await cajas[destino].animar_ps(ps_objetivo_antes, objetivo.estad_ps_actual, objetivo.estad_ps)
	cajas[destino].configurar_animacion_icono()
	if cursor_actual == destino:
		cajas[destino].aplicar_animacion_cursor()
	cuadro_mensaje.visible = true
	await _mostrar_mensaje_dar(EfectosMedicina.texto(EfectosMedicina.CLAVE_PS_RECUPERADOS,
		{"{mon}": objetivo.get_nombre_mostrar(), "{n}": str(curados)}))
	_terminar_transferencia_ps()
	await _volver_a_lista()


## Quita la marca del usuario y deja el cursor donde estaba (sub_8133EF8).
func _terminar_transferencia_ps() -> void:
	var origen := pokemon_intercambio_origen
	modo_intercambio = false
	transferencia_ps_activa = false
	pokemon_intercambio_origen = -1
	if origen >= 0 and origen < get_tamano_equipo():
		cajas[origen].quitar_foco_fijo()
		cajas[origen].establecer_estado(CajaEquipo.Estado.NORMAL)
	if cursor_actual >= 0 and cursor_actual < get_tamano_equipo():
		cajas[cursor_actual].establecer_estado(CajaEquipo.Estado.CURSOR)


## Reproduce `sonido` (clave de Singleton.se) sin posición.
func _reproducir_sonido(sonido: String) -> void:
	if not Singleton.se.has(sonido):
		push_warning("[EQUIPO] Sonido no registrado: %s" % sonido)
		return
	if not is_instance_valid(_reproductor_sonidos):
		_reproductor_sonidos = AudioStreamPlayer.new()
		_reproductor_sonidos.name = "ReproductorSonidos"
		add_child(_reproductor_sonidos)
	_reproductor_sonidos.stream = Singleton.se[sonido]
	_reproductor_sonidos.play()

# --- FUNCIONES AUXILIARES ---

## Determina cuál debería ser el estado de reposo de una caja.
## Si está marcada para intercambio, mantiene SELECCIONADO, si no, NORMAL.
func obtener_estado_reposo(indice_caja: int) -> CajaEquipo.Estado:
	if modo_intercambio and indice_caja == pokemon_intercambio_origen:
		return CajaEquipo.Estado.SELECCIONADO
	else:
		return CajaEquipo.Estado.NORMAL

## Devuelve el número de Pokémon en el equipo actual.
func get_tamano_equipo() -> int:
	if equipo_actual:
		return equipo_actual.get_tamaño()
	return 0

## Devuelve el índice de la última caja que contiene un Pokémon.
func get_ultimo_pokemon_visible() -> int:
	return get_tamano_equipo() - 1

## Busca el primer Pokémon disponible para la batalla que no sea el actual.
func obtener_siguiente_pokemon_disponible() -> int:
	var tamano_equipo = get_tamano_equipo()
	for i in range(tamano_equipo):
		var pokemon = equipo_actual.pokemones[i]
		if i != pokemon_actual_indice and pokemon.puede_combatir():
			return i
	return 0 # Devuelve el primero si no hay otro disponible

# --- FUNCIONES AUXILIARES PARA NAVEGACIÓN ---

## Devuelve el índice del primer Pokémon disponible en el equipo.
func obtener_primer_pokemon_disponible() -> int:
	var tamaño_equipo = get_tamano_equipo()
	for i in range(tamaño_equipo):
		if es_pokemon_disponible_para_navegacion(i):
			return i
	return -1  # No hay Pokémon disponibles

## Devuelve el índice del último Pokémon disponible en el equipo.
func get_ultimo_pokemon_disponible() -> int:
	var tamaño_equipo = get_tamano_equipo()
	for i in range(tamaño_equipo - 1, -1, -1):
		if es_pokemon_disponible_para_navegacion(i):
			return i
	return -1  # No hay Pokémon disponibles

## Busca el Pokémon disponible anterior al índice actual.
func obtener_pokemon_anterior_disponible(indice_actual: int) -> int:
	for i in range(indice_actual - 1, -1, -1):
		if es_pokemon_disponible_para_navegacion(i):
			return i
	return -1  # No hay Pokémon anteriores disponibles

## Busca el siguiente Pokémon disponible después del índice actual.
func obtener_pokemon_siguiente_disponible(indice_actual: int) -> int:
	var tamaño_equipo = get_tamano_equipo()
	for i in range(indice_actual + 1, tamaño_equipo):
		if es_pokemon_disponible_para_navegacion(i):
			return i
	return -1  # No hay más Pokémon disponibles

## Determina si un Pokémon en el índice dado está disponible para la navegación.
## Un Pokémon está disponible si existe en el equipo.
func es_pokemon_disponible_para_navegacion(indice: int) -> bool:
	return indice >= 0 and indice < get_tamano_equipo()

## Devuelve el índice del primer Pokémon disponible en las cajas de la derecha (índices 1-5).
func obtener_primer_pokemon_disponible_derecha() -> int:
	var tamaño_equipo = get_tamano_equipo()
	for i in range(1, tamaño_equipo):
		if es_pokemon_disponible_para_navegacion(i):
			return i
	return -1  # No hay Pokémon disponibles en la derecha

# --- FUNCIONES PARA LA PANTALLA DE INFORMACIÓN DEL POKÉMON ---

## Crea el overlay negro para las transiciones de pantalla.
func inicializar_overlay_transicion() -> void:
	overlay_transicion = ColorRect.new()
	overlay_transicion.color = Color.BLACK
	overlay_transicion.size = Vector2(248, 168)  # Tamaño de la pantalla de equipo
	overlay_transicion.position = Vector2.ZERO
	overlay_transicion.z_index = 3  # Por encima de las cajas (z=1) pero debajo de la info (z=4)
	overlay_transicion.modulate.a = 0.0  # Inicialmente transparente
	overlay_transicion.visible = false
	add_child(overlay_transicion)

## Pre-carga la pantalla de información para evitar lag durante la transición.
func precargar_pantalla_info() -> void:
	if not pantalla_info_pokemon:
		var escena_info = load("res://UI/poke-info/pantalla-info.tscn")
		pantalla_info_pokemon = escena_info.instantiate()
		pantalla_info_pokemon.z_index = 4  # Por encima del overlay de transición
		pantalla_info_pokemon.visible = false  # Inicialmente oculta
		add_child(pantalla_info_pokemon)
		# Conectar la señal de cierre
		pantalla_info_pokemon.pantalla_cerrada.connect(_on_pantalla_info_cerrada)

## Muestra la pantalla de información del Pokémon actualmente seleccionado con transición.
func mostrar_pantalla_info_pokemon() -> void:
	if cursor_actual < 0 or cursor_actual >= get_tamano_equipo():
		return

	# Recordar si el menú estaba abierto antes de la transición
	menu_estaba_abierto_antes_info = menu_pokemon_activo
	print("💾 [EQUIPO] Recordando estado del menú: %s" % ("abierto" if menu_estaba_abierto_antes_info else "cerrado"))

	# Cerrar el menú de Pokémon antes de iniciar la transición
	cerrar_menu_pokemon()

	# Desactivar temporalmente esta pantalla
	activo = false

	# Iniciar la transición de oscurecimiento pasando el índice del Pokémon
	iniciar_transicion_entrada(cursor_actual)

## Se llama cuando la pantalla de información se cierra.
## Actualiza el cursor al Pokémon final y restaura el menú si estaba abierto.
func _on_pantalla_info_cerrada(indice_final: int) -> void:
	print("📥 [EQUIPO] Pantalla info cerrada - índice final: %d, menú anterior: %s" % [indice_final, "abierto" if menu_estaba_abierto_antes_info else "cerrado"])

	# Actualizar el cursor al índice final de la pantalla de información
	if indice_final >= 0 and indice_final < get_tamano_equipo():
		establecer_cursor(indice_final)

	# Reabrir el menú si estaba abierto antes
	if menu_estaba_abierto_antes_info:
		print("🔄 [EQUIPO] Reabriendo menú de opciones para Pokémon en posición %d" % cursor_actual)
		var pokemon_obj = equipo_actual.pokemones[cursor_actual]
		mostrar_menu_pokemon(pokemon_obj)

	# Iniciar la transición de salida
	iniciar_transicion_salida()

# --- FUNCIONES DE TRANSICIÓN ---

## Inicia la transición de oscurecimiento para mostrar la pantalla de información.
func iniciar_transicion_entrada(indice_pokemon: int) -> void:
	# Mostrar el overlay y animarlo a opaco
	overlay_transicion.visible = true
	overlay_transicion.modulate.a = 0.0

	# Crear tween para la transición
	if tween_transicion:
		tween_transicion.kill()
	tween_transicion = create_tween()

	# Fase 1: Oscurecer (0.3 segundos)
	tween_transicion.tween_property(overlay_transicion, "modulate:a", 1.0, 0.3)

	# Esperar a que termine la fase de oscurecimiento
	await tween_transicion.finished

	# Fase 2: Mostrar la pantalla de información mientras está oscuro
	# Pasar toda la lista del equipo y el índice del Pokémon seleccionado
	var lista_equipo = []
	for pokemon in equipo_actual.pokemones:
		if pokemon != null:
			lista_equipo.append(pokemon)

	pantalla_info_pokemon.mostrar_info_lista_pokemon(lista_equipo, indice_pokemon)

	# Fase 3: Aclarar (0.3 segundos)
	tween_transicion = create_tween()
	tween_transicion.tween_property(overlay_transicion, "modulate:a", 0.0, 0.3)

	# Esperar a que termine la fase de aclarado
	await tween_transicion.finished

	# Ocultar el overlay
	overlay_transicion.visible = false

## Inicia la transición de oscurecimiento para ocultar la pantalla de información.
func iniciar_transicion_salida() -> void:
	# Mostrar el overlay y animarlo a opaco
	overlay_transicion.visible = true
	overlay_transicion.modulate.a = 0.0

	# Crear tween para la transición
	if tween_transicion:
		tween_transicion.kill()
	tween_transicion = create_tween()

	# Fase 1: Oscurecer (0.3 segundos)
	tween_transicion.tween_property(overlay_transicion, "modulate:a", 1.0, 0.3)

	# Esperar a que termine la fase de oscurecimiento
	await tween_transicion.finished

	# Fase 2: Ocultar la pantalla de información mientras está oscuro
	if pantalla_info_pokemon:
		pantalla_info_pokemon.ocultar_pantalla()
		print("🌑 [EQUIPO] Pantalla info ocultada durante transición oscura")

	# Fase 3: Aclarar (0.3 segundos)
	tween_transicion = create_tween()
	tween_transicion.tween_property(overlay_transicion, "modulate:a", 0.0, 0.3)

	# Esperar a que termine la fase de aclarado
	await tween_transicion.finished

	# Ocultar el overlay y reactivar la pantalla de equipo
	overlay_transicion.visible = false
	activo = true
