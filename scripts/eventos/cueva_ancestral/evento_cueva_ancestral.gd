## evento_cueva_ancestral.gd
## Guiones de la CUEVA ANCESTRAL (CAVE OF ORIGIN de pokeruby, data/scripts/cave_of_origin.inc y
## data/maps/CaveOfOrigin_*/scripts.inc). Cada planta lleva este nodo con sus disparadores de casilla
## (DisparadorEventoPorTiles hijos, `id_evento`):
##
## - `temblor_1` / `temblor_2` (CaveOfOrigin_EventScript_Shake1/2): la cámara tiembla (ShakeCamera
##   1,1 + SE_M_STRENGTH) la primera vez de cada visita (VAR_TEMP_1 / VAR_TEMP_2).
## - `grito` (CaveOfOrigin_EventScript_LegendaryCry, B4F): ruge GROUDON una vez por visita (VAR_TEMP_5).
## - `groudon` (CaveOfOrigin_B4F_EventScript_15DDD7, VAR_CAVE_OF_ORIGIN_B4F_STATE = 0): la ESFERA ROJA
##   brilla, se va la niebla, SE_M_DETECT con el destello en (9,13), SE_ORB con el círculo rojo centrado en el jugador
##   (DestelloEsfera), GROUDON baja dos pasos, ruge y empieza el combate con MUS_VS_KYOGRE_GROUDON y B_TRANSITION_SHARDS
##   (Nv. 45). Gane, huya o lo atrape, GROUDON desaparece (removeobject → FLAG_HIDE_LEGEND_MON_CAVE_OF_ORIGIN),
##   el estado pasa a 1 y se activa FLAG_LEGENDARY_BATTLE_COMPLETED; si lo debilita, «GROUDON parece
##   haber vuelto a quedarse dormido». Con una derrota manda el coordinador de derrota y no cambia nada.
## Con FLAG_LEGENDARY_BATTLE_COMPLETED los temblores y el grito ya no suenan
## (CaveOfOrigin_EventScript_DisableTriggers en OnTransition).
##
## Después del combate, las banderas de ARRECÍPOLIS y del MONTE PÍRICO (PLUBIO vuelve a su GIMNASIO, vecinos,
## fin de la sequía, MAGNO otra vez en la cima): HistoriaArrecipolis.al_completar_legendario.
##
## Al bajar, GROUDON se ladea a un lado y al otro (gObjectEventRotScalAnimTable_KyogreGroudon).
extends EventoGuionizado
class_name EventoCuevaAncestral

const MOTIVO_PAUSA: StringName = &"cueva_ancestral"

## FLAG_LEGENDARY_BATTLE_COMPLETED (compartida con el MONTE PÍRICO y ARRECÍPOLIS).
const BANDERA_LEGENDARIO_COMPLETADO: String = HistoriaMontePirico.BANDERA_LEGENDARIO_COMPLETADO
## FLAG_HIDE_LEGEND_MON_CAVE_OF_ORIGIN.
const BANDERA_GROUDON_OCULTO: String = "cueva_ancestral_groudon_oculto"
## VAR_CAVE_OF_ORIGIN_B4F_STATE.
const CONTADOR_ESTADO_B4: String = "cueva_ancestral_b4_estado"

const ESPECIE_GROUDON: String = "GROUDON"
const NUMERO_GROUDON: int = 383
const NIVEL_GROUDON: int = 45
const MUSICA_COMBATE: String = "BATALLA_KYOGRE_GROUDON"
const CLIMA_DESPEJADO := preload("res://recursos/clima/ninguno.tres")
const SONIDO_DETECTAR: String = "SE_M_DETECT"
const SONIDO_ESFERA: String = "SE_ORB"
## setfieldeffectargument del FLDEFF_SPARKLE: la casilla del coord_event, donde está el jugador.
const CELDA_DESTELLO := Vector2i(9, 13)
## applymovement 1, CaveOfOrigin_B4F_Movement_15DE7D: walk_down_start_affine, delay_16 ×2, walk_down_affine.
const FOTOGRAMAS_PASO_GROUDON: int = 16
const FOTOGRAMAS_PAUSA_GROUDON: int = 32
## AFFINEANIMCMD_FRAME: 1 unidad = 1/256 de vuelta, positiva en sentido antihorario. Primer paso (RotScalAnim_8370EA4):
## +1 cada 4 fotogramas; segundo paso (RotScalAnim_8370ED4): -1 cada 2, sin volver a cero (ChangeSpriteAffineAnim).
const UNIDAD_ROTACION: float = TAU / 256.0
const FOTOGRAMAS_ROTACION_PASO_1: int = 4
const FOTOGRAMAS_ROTACION_PASO_2: int = 2
const FOTOGRAMAS_TRAS_BAJAR: int = 60
const FOTOGRAMAS_TRAS_GRITO: int = 40

const TEXTO_ESFERA: String = "CUEVA_ANCESTRAL_ESFERA_BRILLA"
const TEXTO_DORMIDO: String = "CUEVA_ANCESTRAL_GROUDON_DORMIDO"

## Sprite de GROUDON (solo en el B4F).
@export var groudon: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Sustituye al combate real (tests): Callable() -> ResultadoBatalla.Valor.
var combate_simulado: Callable = Callable()
## false omite el destello y anima al instante el círculo rojo (tests).
var con_efectos: bool = true
## VAR_TEMP_*: disparadores ya usados en esta visita.
var _usados: Dictionary = {}


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var sprite := get_node_or_null(groudon) as CanvasItem
	if sprite != null and SistemaGuardado.get_flag(BANDERA_GROUDON_OCULTO):
		sprite.visible = false


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


static func legendario_completado() -> bool:
	return SistemaGuardado.get_flag(BANDERA_LEGENDARIO_COMPLETADO)


func _on_disparador(id_evento: StringName) -> void:
	if _en_curso:
		return
	match id_evento:
		&"temblor_1", &"temblor_2":
			if not legendario_completado() and not _usados.has(id_evento):
				await temblor(id_evento)
		&"grito":
			if not legendario_completado() and not _usados.has(id_evento):
				await grito_legendario()
		&"groudon":
			if SistemaGuardado.get_contador(CONTADOR_ESTADO_B4) == 0 and not SistemaGuardado.get_flag(BANDERA_GROUDON_OCULTO):
				await encuentro_groudon()


## CaveOfOrigin_EventScript_Shake (setvar VAR_0x8004 1, VAR_0x8005 1, special ShakeCamera).
func temblor(id_evento: StringName) -> void:
	if not comenzar(_administrador()):
		return
	_usados[id_evento] = true
	var camara: Node = admin.get("cam")
	if camara != null and camara.has_method("sacudir_camara"):
		camara.call("sacudir_camara", 1, 1)
		await get_tree().create_timer(camara.call("duracion_temblor")).timeout
	terminar()


## CaveOfOrigin_EventScript_LegendaryCry.
func grito_legendario() -> void:
	if not comenzar(_administrador()):
		return
	_usados[&"grito"] = true
	await esperar_grito(grito(NUMERO_GROUDON))
	terminar()


## CaveOfOrigin_B4F_EventScript_15DDD7.
func encuentro_groudon() -> void:
	if not comenzar(_administrador()):
		return
	girar_jugador(Vector2.UP)
	await mensaje(TEXTO_ESFERA)
	admin.cuadro_dialogo.cerrar()  # closemessage
	if admin.has_method("cambiar_clima_overworld"):
		admin.cambiar_clima_overworld(CLIMA_DESPEJADO)  # setweather WEATHER_NONE + doweather
	Singleton.play_sound.emit(SONIDO_DETECTAR)
	if con_efectos:
		var destello := EfectoDestello.lanzar(obtener_mapa(), CELDA_DESTELLO)
		if destello != null:
			await destello.terminado
	Singleton.play_sound.emit(SONIDO_ESFERA)
	# special sub_80818A4 con VAR_RESULT = 2 (Rubí): círculo rojo centrado en el jugador; sub_80818FC lo desvanece
	# en cuanto termina de expandirse.
	await DestelloEsfera.lanzar(admin, false, admin.get("cam") as Camera2D, con_efectos, _centro_jugador()).terminar()
	var sprite := get_node_or_null(groudon) as Node2D
	var posicion_inicial: Vector2 = sprite.position if sprite != null else Vector2.ZERO
	await _bajar_groudon()
	await esperar_fotogramas(FOTOGRAMAS_TRAS_BAJAR)
	var rugido := grito(NUMERO_GROUDON)
	await esperar_fotogramas(FOTOGRAMAS_TRAS_GRITO)
	await esperar_grito(rugido)
	var resultado: int = await _combatir_groudon()
	if resultado == -1 or ResultadoBatalla.es_derrota_jugador(resultado):
		# Al volver, el mapa recargado de la ROM lo tiene otra vez en su plantilla.
		if sprite != null:
			sprite.position = posicion_inicial
			sprite.rotation = 0.0
		terminar(resultado != -1)
		return
	# removeobject 1 (FLAG_HIDE_LEGEND_MON_CAVE_OF_ORIGIN) y el resto de CaveOfOrigin_B4F_EventScript_15DDD7.
	if sprite != null:
		sprite.visible = false
	SistemaGuardado.set_flag(BANDERA_GROUDON_OCULTO, true)
	if resultado == ResultadoBatalla.Valor.VICTORIA_JUGADOR:
		await mensaje(TEXTO_DORMIDO)  # B_OUTCOME_WON
	SistemaGuardado.set_contador(CONTADOR_ESTADO_B4, 1)
	HistoriaArrecipolis.al_completar_legendario()  # también FLAG_LEGENDARY_BATTLE_COMPLETED
	terminar()


func _bajar_groudon() -> void:
	var sprite := get_node_or_null(groudon) as Node2D
	if sprite == null:
		return
	var tween := create_tween()
	var duracion := FOTOGRAMAS_PASO_GROUDON / 60.0
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, 16), duracion)
	tween.parallel().tween_method(func(fotograma: int) -> void:
		sprite.rotation = -angulo_groudon(fotograma), 0, FOTOGRAMAS_PASO_GROUDON, duracion)
	tween.tween_interval(FOTOGRAMAS_PAUSA_GROUDON / 60.0)
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, 32), duracion)
	tween.parallel().tween_method(func(fotograma: int) -> void:
		sprite.rotation = -angulo_groudon(FOTOGRAMAS_PASO_GROUDON + fotograma), 0, FOTOGRAMAS_PASO_GROUDON, duracion)
	await tween.finished


## Ángulo antihorario de GROUDON tras `fotograma` fotogramas de movimiento (0..32; las pausas no cuentan).
static func angulo_groudon(fotograma: int) -> float:
	var primero: int = mini(fotograma, FOTOGRAMAS_PASO_GROUDON)
	var unidades: int = ceili(float(primero) / FOTOGRAMAS_ROTACION_PASO_1)
	unidades -= ceili(float(maxi(fotograma - FOTOGRAMAS_PASO_GROUDON, 0)) / FOTOGRAMAS_ROTACION_PASO_2)
	return unidades * UNIDAD_ROTACION


## Centro de la casilla del jugador en píxeles del viewport: en la ROM, (120,80) (VAR_RESULT = 2).
func _centro_jugador() -> Vector2:
	var jugador := admin.get("jugador") as Node2D
	if jugador == null or not jugador.is_inside_tree():
		return Vector2(120, 80) * DestelloEsfera.ESCALA
	return jugador.get_global_transform_with_canvas() * Vector2(0.0, 8.0 - NpcBase.OFFSET.y)


## ScrSpecial_StartGroudonKyogreBattle: B_TRANSITION_SHARDS y MUS_VS_KYOGRE_GROUDON.
static func opciones_combate() -> OpcionesBatallaOverworld:
	var opciones := OpcionesBatallaOverworld.para_salvaje()
	opciones.musica_especifica = MUSICA_COMBATE
	opciones.secuencia_transicion = PackedStringArray([CatalogoTransicionesBatalla.DESTELLOS, CatalogoTransicionesBatalla.FRAGMENTOS])
	return opciones


## setwildbattle SPECIES_GROUDON, 45 + ScrSpecial_StartGroudonKyogreBattle. Devuelve el
## ResultadoBatalla.Valor, o -1 si el combate no pudo empezar. Con una derrota el coordinador de
## derrota se queda con el control (ver terminar(true)).
func _combatir_groudon() -> int:
	admin.cuadro_dialogo.cerrar()
	if combate_simulado.is_valid():
		return int(combate_simulado.call())
	var manager := admin.get("battle_manager") as OverworldBattleManager
	if manager == null:
		push_warning("[CuevaAncestral] Sin OverworldBattleManager")
		return -1
	var opciones := opciones_combate()
	var lugar: String = str(admin.obtener_seccion_lugar_actual()) if admin.has_method("obtener_seccion_lugar_actual") else ""
	var ejecucion: ResultadoEjecucionBatalla = await manager.combatir_salvaje(ESPECIE_GROUDON, NIVEL_GROUDON, lugar, opciones)
	if ejecucion.fue_rechazada():
		push_warning("[CuevaAncestral] Combate rechazado: %s" % ejecucion.codigo_error)
		return -1
	if ResultadoBatalla.es_derrota_jugador(ejecucion.resultado) and not manager.recuperar_derrota_estandar():
		return -1
	return int(ejecucion.resultado)
