## evento_barca_arenque.gd
## Viaje en la barca del SR. ARENQUE de la RUTA 104 a PUEBLO AZULIZA (pokeruby
## Route104_MapScript2_14EE97 → Route104_EventScript_14EFD5). Va en la RUTA 104.
##
## La casa del SR. ARENQUE (npc_arenque_casa.gd) activa `BANDERA_EMBARCA`
## (VAR_BOARD_BRINEY_BOAT_ROUTE104_STATE 1) y hace el warp a (13,51) de Rubí. Al
## activarse el mapa con esa bandera (ON_FRAME):
## 1. ARENQUE baja dos casillas y sube a la barca (removeobject); el jugador va a la
##    izquierda y baja dos (se oculta) y suena MUS_SAILING.
## 2. La barca recorre Route104_Movement_14F09F (194 pasos a 16/8/4 fotogramas por
##    casilla) cruzando las RUTAS 105 y 106 hasta (12,8) de PUEBLO AZULIZA.
## 3. El jugador aparece en PUEBLO AZULIZA (baja, va a la izquierda y mira a la
##    derecha); ARENQUE sale de la barca, baja y mira a la izquierda; mensaje según
##    FLAG_DELIVERED_STEVEN_LETTER.
##
## Los mapas del Overworld están colocados como las conexiones de Rubí, así que el
## camino de la barca se recorre en coordenadas globales: una barca temporal en el
## Overworld, con la cámara enfocándola, sustituye a los objetos de cada mapa. Al
## llegar, el jugador pasa al mapa de destino con AdministradorMapa.set_mapa_actual,
## como al cruzar un borde.
##
## Coordenadas de Godot: RUTA 104 = Rubí + (2,0); PUEBLO AZULIZA = Rubí + (6,0).
extends EventoGuionizado
class_name EventoBarcaArenque

const MOTIVO_PAUSA: StringName = &"barca_arenque"
const MUSICA_NAVEGAR: String = "CROSSING_THE_SEA"  # MUS_SAILING
const FRAMES_BARCA: SpriteFrames = preload("res://escenas/avatares/npc_barca_arenque.tres")
const OFFSET_BARCA := Vector2(-16, -30)
const Z_BARCA: int = 1

## VAR_BOARD_BRINEY_BOAT_ROUTE104_STATE 1: embarcar al entrar en la RUTA 104.
const BANDERA_EMBARCA: String = "arenque_embarca_ruta_104"
## Inversa de FLAG_HIDE_MR_BRINEY_ROUTE104.
const BANDERA_ARENQUE_RUTA_104: String = "arenque_en_ruta_104"
## FLAG_HIDE_MR_BRINEY_BOAT_ROUTE104.
const BANDERA_BARCA_RUTA_104_OCULTA: String = "arenque_barca_ruta_104_oculta"
## Inversa de FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN.
const BANDERA_ARENQUE_AZULIZA: String = "arenque_en_azuliza"
## Inversa de FLAG_HIDE_MR_BRINEY_BOAT_DEWFORD.
const BANDERA_BARCA_AZULIZA: String = "arenque_barca_azuliza"
## Inversa de FLAG_HIDE_MR_BRINEY_ROUTE104_HOUSE (y de PEEKO).
const BANDERA_ARENQUE_CASA: String = "arenque_en_casa"
## FLAG_DELIVERED_STEVEN_LETTER (npc_arenque_casa.gd).
const BANDERA_CARTA: String = "carta_maximo_entregada"
## FLAG_DELIVERED_DEVON_GOODS.
const BANDERA_PIEZAS: String = "piezas_devon_entregadas"
## Inversa de FLAG_HIDE_MR_BRINEY_ROUTE109.
const BANDERA_ARENQUE_RUTA_109: String = "arenque_en_ruta_109"
## Inversa de FLAG_HIDE_MR_BRINEY_BOAT_ROUTE109.
const BANDERA_BARCA_RUTA_109: String = "arenque_barca_ruta_109"

const MAPA_RUTA_104: String = "ruta_104"
const MAPA_AZULIZA: String = "pueblo_azuliza"
const MAPA_RUTA_109: String = "ruta_109"
const RUTA_ARENQUE_RUTA_109: String = "NPCs/Arenque"
const RUTA_BARCA_RUTA_109: String = "NPCs/BarcaArenque"
const RUTA_ARENQUE_AZULIZA: String = "NPCs/ArenqueAzuliza"
const RUTA_BARCA_AZULIZA: String = "NPCs/BarcaAzuliza"
const RUTA_BARCA_RUTA_104: String = "NPCs/BarcaArenque"

## Celdas de Godot.
const BARCA_RUTA_104 := Vector2i(14, 54)  # Rubí (12,54)
const BARCA_AZULIZA := Vector2i(18, 8)  # Rubí (12,8)
const BARCA_RUTA_109 := Vector2i(23, 26)  # Rubí (21,26)

const TEXTO_LLEGADA: String = "AZULIZA_ARENQUE_LLEGADA"
const TEXTO_LLEGADA_CARTA: String = "AZULIZA_ARENQUE_LLEGADA_CARTA"

const NOMBRES_DIRECCION := {
	Vector2.DOWN: "abajo", Vector2.UP: "arriba", Vector2.LEFT: "izquierda", Vector2.RIGHT: "derecha",
}

## Route104_Movement_14F09F (194 pasos): [dirección, fotogramas por casilla, casillas].
const TRAMOS_A_AZULIZA := [
	[Vector2.DOWN, 16, 4],
	[Vector2.DOWN, 8, 4],
	[Vector2.DOWN, 4, 12],
	[Vector2.DOWN, 8, 4],
	[Vector2.RIGHT, 8, 2],
	[Vector2.RIGHT, 4, 6],
	[Vector2.RIGHT, 8, 2],
	[Vector2.DOWN, 8, 4],
	[Vector2.DOWN, 4, 83],
	[Vector2.DOWN, 8, 4],
	[Vector2.RIGHT, 8, 4],
	[Vector2.RIGHT, 4, 40],
	[Vector2.RIGHT, 8, 4],
	[Vector2.RIGHT, 16, 2],
	[Vector2.DOWN, 16, 2],
	[Vector2.DOWN, 8, 15],
	[Vector2.DOWN, 16, 2],
]
## DewfordTown_Movement_SailToPetalburg (194 pasos).
const TRAMOS_A_PETALIA := [
	[Vector2.UP, 16, 2],
	[Vector2.UP, 8, 15],
	[Vector2.UP, 16, 2],
	[Vector2.LEFT, 16, 2],
	[Vector2.LEFT, 8, 4],
	[Vector2.LEFT, 4, 40],
	[Vector2.LEFT, 8, 4],
	[Vector2.UP, 8, 4],
	[Vector2.UP, 4, 83],
	[Vector2.UP, 8, 4],
	[Vector2.LEFT, 8, 2],
	[Vector2.LEFT, 4, 6],
	[Vector2.LEFT, 8, 2],
	[Vector2.UP, 8, 2],
	[Vector2.UP, 4, 14],
	[Vector2.UP, 8, 4],
	[Vector2.UP, 16, 4],
]

## DewfordTown_Movement_SailToSlateport (171 pasos, +149 −22).
const TRAMOS_A_PORTUAL := [
	[Vector2.RIGHT, 16, 1],
	[Vector2.RIGHT, 8, 2],
	[Vector2.RIGHT, 4, 144],
	[Vector2.RIGHT, 8, 2],
	[Vector2.UP, 8, 2],
	[Vector2.UP, 4, 10],
	[Vector2.UP, 8, 10],
]
## Route109_Movement_14F5BF (171 pasos, −149 +22; walk_in_place_fastest_down al
## principio y al final: 0 casillas, solo gira).
const TRAMOS_DESDE_PORTUAL := [
	[Vector2.DOWN, 0, 0],
	[Vector2.DOWN, 16, 2],
	[Vector2.DOWN, 8, 2],
	[Vector2.DOWN, 4, 16],
	[Vector2.DOWN, 8, 2],
	[Vector2.LEFT, 8, 2],
	[Vector2.LEFT, 4, 136],
	[Vector2.LEFT, 8, 9],
	[Vector2.LEFT, 16, 2],
	[Vector2.DOWN, 0, 0],
]

## ARENQUE en el muelle de la RUTA 104 (objeto 8) y la barca (objeto 7).
@export var arenque_muelle: NodePath
@export var barca: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## false recorre el camino sin esperar (tests).
var con_animacion: bool = true
## Barca temporal del viaje (null fuera de él).
var barca_viaje: AnimatedSprite2D = null
## Último mapa del Overworld anunciado bajo la barca durante el viaje.
var _mapa_bajo_barca: MapaConfiguracion = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## Mapa del Overworld por su clave (null si no está cargado).
func buscar_mapa(clave: String) -> MapaConfiguracion:
	var adm := _administrador()
	if adm == null or not adm.has_method("_buscar_mapa_en_overworld"):
		return null
	return adm._buscar_mapa_en_overworld(clave)


## Posición global de los pies de `npc`: la barca eleva el pivote de su nodo (ver
## NpcBase.elevacion_pivote) y la barca del viaje parte de sus pies.
static func pies_de(npc: Node2D) -> Vector2:
	return npc.posicion_pies_global() if npc.has_method(&"posicion_pies_global") else npc.global_position


## Posición global (pies, como un NPC) de una celda de `mapa`.
static func posicion_global(mapa: Node2D, celda: Vector2i) -> Vector2:
	return mapa.global_position + Vector2(celda.x * 16 + 8, celda.y * 16 + 14)


## ============================================================================
## EMBARQUE EN LA RUTA 104 (ON_FRAME)
## ============================================================================

func _on_mapa_activado(_por_warp: bool) -> void:
	if not SistemaGuardado.get_flag(BANDERA_EMBARCA) or _en_curso:
		return
	var adm := _administrador()
	await esperar_fin_warp(adm)
	await viajar_a_azuliza(adm)


## Route104_EventScript_14EFD5.
func viajar_a_azuliza(adm: Node) -> void:
	if not SistemaGuardado.get_flag(BANDERA_EMBARCA) or not comenzar(adm):
		return
	var npc_arenque := _npc(arenque_muelle)
	var npc_barca := _npc(barca)
	if npc_arenque != null:
		npc_arenque.visible = true
		await recorrer(npc_arenque, [Vector2.DOWN, Vector2.DOWN])  # Route104_Movement_14F16C
		npc_arenque.visible = false  # removeobject 8
	SistemaGuardado.set_flag(BANDERA_ARENQUE_RUTA_104, false)
	await recorrer_jugador([Vector2.LEFT, Vector2.DOWN, Vector2.DOWN])  # Route104_Movement_14F162
	admin.jugador.visible = false  # hideobjectat LOCALID_PLAYER
	reproducir_musica(MUSICA_NAVEGAR)  # Common_EventScript_PlayBrineysBoatMusic
	var mapa_104 := obtener_mapa()
	var origen := posicion_global(mapa_104, BARCA_RUTA_104)
	if npc_barca != null:
		origen = pies_de(npc_barca)
		npc_barca.visible = false
	SistemaGuardado.set_flag(BANDERA_BARCA_RUTA_104_OCULTA, true)
	await navegar(origen, TRAMOS_A_AZULIZA)
	SistemaGuardado.set_flag(BANDERA_EMBARCA, false)  # VAR_BOARD_BRINEY_BOAT_ROUTE104_STATE 0
	# walk_down del jugador oculto + showobjectat en PUEBLO AZULIZA + Route104_Movement_14F168.
	await llegar_a_azuliza(BARCA_AZULIZA, [Vector2.DOWN, Vector2.LEFT],
		TEXTO_LLEGADA if SistemaGuardado.get_flag(BANDERA_CARTA) else TEXTO_LLEGADA_CARTA)


## Llegada a PUEBLO AZULIZA (común a la RUTA 104 y la RUTA 109): el jugador aparece en
## `celda`, recorre `pasos` y mira a la derecha; ARENQUE sale de la barca (12,8), baja
## y mira a la izquierda; vuelve la barca de AZULIZA y ARENQUE dice `texto`.
func llegar_a_azuliza(celda: Vector2i, pasos: Array, texto: String) -> void:
	var azuliza := buscar_mapa(MAPA_AZULIZA)
	if azuliza == null:
		push_warning("[BARCA_ARENQUE] PUEBLO AZULIZA no está en el Overworld")
		_terminar_sin_destino()
		return
	pasar_jugador_a(azuliza, celda, Vector2.DOWN)
	restaurar_musica_mapa()  # Common_EventScript_StopBrineysBoatMusic (fadedefaultbgm)
	await recorrer_jugador(pasos)
	girar_jugador(Vector2.RIGHT)
	var arenque_az := azuliza.get_node_or_null(RUTA_ARENQUE_AZULIZA) as Node2D
	SistemaGuardado.set_flag(BANDERA_ARENQUE_AZULIZA, true)  # clearflag FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN
	if arenque_az != null:
		colocar(arenque_az, BARCA_AZULIZA)  # setobjectxyperm 2, 12, 8
		arenque_az.visible = true
		await caminar(arenque_az, Vector2.DOWN)  # Route104_Movement_14F16F
		mirar(arenque_az, Vector2.LEFT)
	SistemaGuardado.set_flag(BANDERA_BARCA_AZULIZA, true)  # clearflag FLAG_HIDE_MR_BRINEY_BOAT_DEWFORD
	mostrar_barca(azuliza.get_node_or_null(RUTA_BARCA_AZULIZA) as Node2D, BARCA_AZULIZA, Vector2.DOWN)
	liberar_barca_viaje()
	await mensaje(texto)
	terminar(false, [arenque_az] if arenque_az != null else [])


## Sin mapa de destino: el jugador reaparece donde estaba y el guion acaba.
func _terminar_sin_destino() -> void:
	liberar_barca_viaje()
	admin.jugador.visible = true
	Singleton.foco_camara = admin.jugador
	restaurar_musica_mapa()
	terminar()


## ============================================================================
## PIEZAS COMUNES
## ============================================================================

## multichoice: índice de la opción elegida (cancelar = la última). Con dos opciones
## el menú responde "Y" / "N"; con más, el índice. `indice_inicial`: opción donde
## empieza el cursor (0 = la primera); `desplazamiento`: px extra sobre la posición
## por defecto del menú.
func elegir_opcion(clave: String, opciones: PackedStringArray, indice_inicial: int = 0, desplazamiento: Vector2 = Vector2.ZERO) -> int:
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	if indice_inicial > 0 or desplazamiento != Vector2.ZERO:
		dialogo.preguntaSiNo(tr(clave), opciones, indice_inicial, desplazamiento)
	else:
		dialogo.preguntaSiNo(tr(clave), opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			var respuesta := str(parametros[0]) if not parametros.is_empty() else "N"
			if respuesta == "Y":
				return 0
			if respuesta.is_valid_int():
				return clampi(int(respuesta), 0, opciones.size() - 1)
			return opciones.size() - 1
	return opciones.size() - 1


## lock + faceplayer desde la interacción de ARENQUE.
func comenzar_con(npc: Node2D) -> bool:
	if _en_curso or not comenzar(npc.nodo_administrador):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	return true


## applymovement de la barca (y del jugador oculto): barca temporal en el Overworld
## que recorre `tramos` desde `origen` (posición global de sus pies) con la cámara.
func navegar(origen: Vector2, tramos: Array) -> void:
	liberar_barca_viaje()
	barca_viaje = AnimatedSprite2D.new()
	barca_viaje.name = "BarcaViaje"
	barca_viaje.sprite_frames = FRAMES_BARCA
	barca_viaje.centered = false
	barca_viaje.offset = OFFSET_BARCA
	barca_viaje.z_index = Z_BARCA
	var padre: Node = null
	if is_instance_valid(admin):
		padre = admin.get("nodo_overworld")
	if padre == null:
		padre = get_tree().current_scene if get_tree().current_scene != null else self
	padre.add_child(barca_viaje)
	barca_viaje.global_position = origen
	Singleton.foco_camara = barca_viaje
	_mapa_bajo_barca = null
	# El tiempo que sobra al acabar una casilla pasa a la siguiente: el avance es continuo.
	var resto: float = 0.0
	for tramo in tramos:
		var direccion: Vector2 = tramo[0]
		orientar(barca_viaje, direccion)
		var duracion: float = float(tramo[1]) / FOTOGRAMAS_POR_SEGUNDO
		for i in int(tramo[2]):
			var inicio: Vector2 = barca_viaje.global_position
			var destino: Vector2 = inicio + direccion * 16.0
			if con_animacion:
				resto = await _recorrer_casilla(inicio, destino, duracion, resto)
				if not is_instance_valid(barca_viaje):
					return
			else:
				barca_viaje.global_position = destino
			_anunciar_mapa_bajo_barca()
	if not con_animacion:
		await get_tree().process_frame


## Una casilla de `inicio` a `destino` en `duracion` segundos, avanzando en cada
## fotograma antes de _process. Un Tween se procesa después de todos los _process,
## cámara incluida, y el sprite iría un fotograma por detrás de ella (vibraba a 4
## px por fotograma). `resto` es el tiempo que ya llevaba la casilla; devuelve el
## que sobra al acabarla.
func _recorrer_casilla(inicio: Vector2, destino: Vector2, duracion: float, resto: float) -> float:
	var transcurrido: float = resto
	while transcurrido < duracion:
		await get_tree().process_frame
		if not is_instance_valid(barca_viaje):
			return 0.0
		transcurrido += get_process_delta_time()
		barca_viaje.global_position = inicio.lerp(destino, minf(transcurrido / duracion, 1.0))
	barca_viaje.global_position = destino
	return transcurrido - duracion


## En Gen 3 la barca cambia de mapa al cruzar los bordes (RUTAS 105 y 106) y cada uno
## muestra su cartel de lugar; aquí el jugador sigue en el mapa de salida, así que se
## anuncia el mapa del Overworld que hay bajo la barca al entrar en uno distinto.
func _anunciar_mapa_bajo_barca() -> void:
	var adm := _administrador()
	if adm == null or not adm.has_method("anunciar_lugar_de_mapa") or not is_instance_valid(barca_viaje):
		return
	var mapa := mapa_en_posicion(barca_viaje.global_position)
	if mapa == null or mapa == _mapa_bajo_barca:
		return
	_mapa_bajo_barca = mapa
	adm.anunciar_lugar_de_mapa(mapa)


## Mapa del Overworld que contiene la posición global `pos` (null si cae en el mar
## sin mapa o no hay Overworld).
func mapa_en_posicion(pos: Vector2) -> MapaConfiguracion:
	var adm := _administrador()
	var raiz: Node = adm.get("nodo_overworld") if adm != null else null
	if raiz == null:
		return null
	# La barca solo navega entre mapas sueltos del Overworld, no entra en regiones.
	for hijo in raiz.get_children():
		var mapa := hijo as MapaConfiguracion
		if mapa == null:
			continue
		var rect := mapa.obtener_rect_util()
		if rect != Rect2() and rect.has_point(mapa.to_local(pos)):
			return mapa
	return null


static func orientar(sprite: AnimatedSprite2D, direccion: Vector2) -> void:
	sprite.play("camina_%s_1" % NOMBRES_DIRECCION.get(direccion, "abajo"))
	sprite.stop()
	sprite.frame = 0


func liberar_barca_viaje() -> void:
	if is_instance_valid(barca_viaje):
		barca_viaje.queue_free()
	barca_viaje = null


## Pone la barca de un mapa en su celda y la muestra (addobject).
func mostrar_barca(npc_barca: Node2D, celda: Vector2i, direccion: Vector2) -> void:
	if npc_barca == null:
		return
	colocar(npc_barca, celda)
	npc_barca.visible = true
	npc_barca.update_direction(direccion)


## showobjectat LOCALID_PLAYER en otro mapa: el jugador pasa a `mapa` en `celda`
## (cambia el mapa actual como al cruzar un borde) y la cámara vuelve a él.
func pasar_jugador_a(mapa: MapaConfiguracion, celda: Vector2i, direccion: Vector2) -> void:
	var jugador: Node2D = admin.jugador
	if admin.has_method("set_mapa_actual"):
		admin.set_mapa_actual(mapa, celda)
	if jugador.has_method("colocar_en_celda"):
		jugador.colocar_en_celda(celda, direccion)
	jugador.visible = true
	Singleton.foco_camara = jugador
