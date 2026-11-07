## evento_guionizado.gd
## Base de los eventos de mapa con guion (scripts de pokeruby con lockall,
## msgbox, applymovement, trainerbattle_no_intro…). Cada acción es una corrutina
## para escribir el guion como en el decomp:
##
##   if not comenzar(admin): return
##   await mensaje("CLAVE")
##   await caminar(npc, Vector2.DOWN)
##   var resultado := await combatir(id)
##   terminar(resultado == &"derrota_transferida")
##
## Las subclases (EventoFamiliaEstratega, EventoRival…) solo escriben su guion.
## `admin` es el AdministradorMapa (cuadro de diálogo, jugador y gestor de batalla).
extends Node2D
class_name EventoGuionizado

const NpcBase := preload("res://scripts/npc/npc_base.gd")
## Atajo para las subclases: `VelocidadPaso.RAPIDO` en vez de `NpcBase.VelocidadPaso.RAPIDO`.
const VelocidadPaso := NpcBase.VelocidadPaso

## Pokeruby mueve a 60 fotogramas por segundo.
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0

## Motivo de la pausa global mientras dura el guion. Cada subclase pone el suyo.
var motivo_pausa: StringName = &"evento_guionizado"
## AdministradorMapa del guion en curso.
var admin: Node = null

signal _mensaje_terminado

## playfanfare MUS_OBTAIN_ITEM.
const FANFARRIA_OBJETO: String = "OBTENIDO_OBJETO"
## playmoncry: grito por número nacional.
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"

const CUADRO_DINERO := preload("res://UI/cuadro_dinero/cuadro_dinero.tscn")
const PAJARO_VUELO := preload("res://escenas/overworld/pajaro_vuelo_npc.tscn")
## playse SE_M_FLY de FldEff_NPCFlyOut.
const SONIDO_VUELO: String = "SE_M_FLY"
## delay 15 entre dofieldeffect FLDEFF_NPCFLY_OUT y removeobject.
const FOTOGRAMAS_ANTES_DE_DESAPARECER: int = 15

var _en_curso: bool = false
## Recuadro del dinero mientras esté a la vista (mostrar_cuadro_dinero).
var _cuadro_dinero: CuadroDinero = null
## false omite las fanfarrias en lugar de esperar al audio (tests).
var con_fanfarrias: bool = true
## false omite los gritos de playmoncry (tests).
var con_gritos: bool = true


## lockall: empieza el guion y bloquea al jugador. Devuelve false (sin hacer
## nada) si ya hay un guion en curso o no hay administrador con cuadro de diálogo.
func comenzar(nuevo_admin: Node) -> bool:
	if _en_curso or nuevo_admin == null or nuevo_admin.get("cuadro_dialogo") == null:
		return false
	admin = nuevo_admin
	_en_curso = true
	bloquear_jugador(true)
	return true


func en_curso() -> bool:
	return _en_curso


## releaseall. Con `control_transferido` (derrota) el coordinador de derrota ya
## tiene el control del jugador: se cierran el diálogo y la pausa del guion,
## conservando no_control hasta que el warp llegue al punto de curación.
func terminar(control_transferido: bool = false, npcs: Array = []) -> void:
	ocultar_cuadro_dinero()
	if is_instance_valid(admin) and admin.cuadro_dialogo:
		admin.cuadro_dialogo.cerrar()
	if control_transferido:
		var jugador: Node = admin.get("jugador") if is_instance_valid(admin) else null
		if is_instance_valid(jugador):
			jugador.end_dialog()
		Singleton.mantener_pausa(motivo_pausa, false)
	else:
		bloquear_jugador(false)
	for npc in npcs:
		if is_instance_valid(npc) and npc.estado_actual != NpcBase.EstadoNPC.IDLE:
			npc.cambiar_estado(NpcBase.EstadoNPC.IDLE)
	_en_curso = false


func bloquear_jugador(activo: bool) -> void:
	Singleton.mantener_pausa(motivo_pausa, activo)
	var jugador: Node = admin.get("jugador") if is_instance_valid(admin) else null
	if jugador == null:
		return
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()
	jugador.no_control = activo


## ============================================================================
## DIÁLOGOS
## ============================================================================

## msgbox MSGBOX_DEFAULT. `cerrar = false` deja el cuadro abierto. `reemplazos`
## sustituye marcadores del texto ({mon} → nombre…).
func mensaje(clave: String, cerrar: bool = true, reemplazos: Dictionary = {}) -> void:
	admin.cuadro_dialogo.mostrar(_texto(clave, reemplazos), true, cerrar, _mensaje_terminado.emit)
	await _mensaje_terminado


## message + playfanfare + waitfanfare + waitmessage: el texto se escribe a la par
## de la fanfarria (`tema`, clave de Singleton.TEMAS_REGISTRADOS) y el guion sigue
## cuando acaban los dos, sin esperar el botón. Deja el cuadro abierto.
func mensaje_con_fanfarria(clave: String, tema: String = FANFARRIA_OBJETO, reemplazos: Dictionary = {}) -> void:
	var pendiente := [true]
	var al_terminar := func() -> void: pendiente[0] = false
	var cuadro = admin.cuadro_dialogo
	cuadro.mostrar(_texto(clave, reemplazos), false, false, al_terminar, false, cuadro.esta_activo)
	await fanfarria(tema)
	while pendiente[0]:
		await get_tree().process_frame


## playfanfare + waitfanfare.
func fanfarria(tema: String, esperar_subida: bool = false) -> void:
	if con_fanfarrias:
		await Fanfarria.reproducir(self, tema, esperar_subida)


func _texto(clave: String, reemplazos: Dictionary) -> String:
	var texto := tr(clave)
	for marcador in reemplazos:
		texto = texto.replace(str(marcador), str(reemplazos[marcador]))
	return texto


## msgbox MSGBOX_YESNO; cancelar equivale a NO.
func preguntar_si_no(clave: String, reemplazos: Dictionary = {}) -> bool:
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	dialogo.preguntaSiNo(_texto(clave, reemplazos))
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false


## giveitem: entrega el objeto con "¡Obtuvo X!" y la fanfarria. Devuelve false
## si no se pudo entregar. Deja el cuadro abierto.
func dar_objeto(npc: Node2D, objeto: String, cantidad: int = 1) -> bool:
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, cantidad)
	if not bool(resultado.get("exito", false)):
		return false
	if npc.has_method("mostrar_objeto_recibido"):
		await npc.mostrar_objeto_recibido(objeto)
	return true


## ============================================================================
## MOVIMIENTO (applymovement)
## ============================================================================

## walk_slow_* / walk_* / walk_fast_* / walk_fastest_* según `velocidad`
## (32 / 16 / 8 / 4 fotogramas por casilla, absolutos: no dependen de la
## velocidad_paso del NPC; ver NpcBase.duracion_para_velocidad). Como en Gen 3, un
## paso de guion no choca con el jugador ni con otros NPC; un borde (saliente) en
## la celda destino hace el salto de dos casillas de npc_base. Al terminar el NPC
## recupera su duracion_paso anterior. Con `mirada` (lock_facing_direction +
## walk_*) camina hacia `direccion` sin dejar de mirar a `mirada` (p. ej. un paso
## hacia atrás, de espaldas al destino) y termina mirando a `mirada`.
func caminar(npc: Node2D, direccion: Vector2, velocidad: NpcBase.VelocidadPaso = NpcBase.VelocidadPaso.NORMAL, mirada: Vector2 = Vector2.ZERO) -> void:
	var duracion_previa: float = npc.duracion_paso
	npc.duracion_paso = NpcBase.duracion_para_velocidad(velocidad)
	npc.mover_npc(direccion, true, mirada)
	while is_instance_valid(npc) and npc.estado_actual == NpcBase.EstadoNPC.MOVING:
		await get_tree().process_frame
	if is_instance_valid(npc):
		npc.duracion_paso = duracion_previa


## Varios pasos seguidos en la misma dirección o en una lista de direcciones.
func recorrer(npc: Node2D, direcciones: Array, velocidad: NpcBase.VelocidadPaso = NpcBase.VelocidadPaso.NORMAL) -> void:
	for direccion in direcciones:
		await caminar(npc, direccion, velocidad)


## walk_in_place_fastest_* / face_*: gira sin moverse.
func mirar(npc: Node2D, direccion: Vector2) -> void:
	npc.update_direction(direccion)


## Common_Movement_ExclamationMark.
func exclamacion(npc: Node2D) -> void:
	await npc.mostrar_exclamacion()


## walk_in_place_fast_* / jog_in_place_*: el NPC mira a `direccion` y marca el
## paso `pasos` veces sin moverse (alternando pie, `fotogramas_por_paso` cada uno).
func trotar_en_sitio(npc: Node2D, direccion: Vector2, pasos: int, fotogramas_por_paso: int = 8) -> void:
	npc.update_direction(direccion)
	var base: String = "camina_" + npc.get_nombre_dir(direccion)
	var mitad: int = fotogramas_por_paso >> 1
	for i in pasos:
		if not is_instance_valid(npc):
			return
		npc.animated_sprite.play("%s_%d" % [base, 1 + i % 2])
		npc.animated_sprite.stop()
		npc.animated_sprite.frame = 1
		await esperar_fotogramas(mitad)
		npc.animated_sprite.frame = 0
		await esperar_fotogramas(fotogramas_por_paso - mitad)


## applymovement a varios objetos a la vez + waitmovement 0: arranca todas las
## `tareas` (cada una, una corrutina o función sin argumentos) y espera a que
## terminen las últimas.
func en_paralelo(tareas: Array[Callable]) -> void:
	var pendientes: Array[int] = [tareas.size()]
	for tarea in tareas:
		_ejecutar_y_contar(tarea, pendientes)
	while pendientes[0] > 0:
		await get_tree().process_frame


func _ejecutar_y_contar(tarea: Callable, pendientes: Array[int]) -> void:
	await tarea.call()
	pendientes[0] -= 1


## applymovement LOCALID_PLAYER: el jugador recorre `direcciones` sin colisiones.
func recorrer_jugador(direcciones: Array, velocidad: NpcBase.VelocidadPaso = NpcBase.VelocidadPaso.NORMAL) -> void:
	var jugador: Node = admin.get("jugador")
	for direccion in direcciones:
		await jugador.caminar_guion(direccion, velocidad)


## lock_facing_direction + walk_* + unlock_facing_direction del jugador: da un paso
## sin dejar de mirar adonde miraba (le empujan hacia atrás).
func retroceder_jugador(direccion: Vector2) -> void:
	var jugador: Node = admin.get("jugador")
	var mirada: Vector2 = jugador.facing_direction
	await jugador.caminar_guion(direccion)
	jugador.detener_movimientos(mirada)


## setobjectxy LOCALID_PLAYER.
func colocar_jugador(celda: Vector2i, direccion: Vector2) -> void:
	admin.jugador.colocar_en_celda(celda, direccion)


## walk_in_place_fastest_* del jugador: solo gira.
func girar_jugador(direccion: Vector2) -> void:
	admin.jugador.detener_movimientos(direccion)


## jump_in_place_*: mira a `direccion` y da un saltito sin moverse (16 fotogramas).
## `fotograma` 1 salta con la pose de dar un paso (jump_*); 0, con la de estar parado.
func saltar_en_sitio(npc: Node2D, direccion: Vector2, fotograma: int = 0) -> void:
	npc.update_direction(direccion)
	var sprite: Node2D = npc.animated_sprite
	if sprite == null:
		return
	npc.animated_sprite.frame = fotograma
	var base := sprite.position
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", base.y - 6.0, 8 / FOTOGRAMAS_POR_SEGUNDO) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", base.y, 8 / FOTOGRAMAS_POR_SEGUNDO) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


## opendoor + waitdooranim sobre la puerta (warp.gd) de un mapa, sin entrar por ella.
func abrir_puerta(puerta: Node) -> void:
	await _animar_puerta(puerta, "abrir_puerta")


## closedoor + waitdooranim.
func cerrar_puerta(puerta: Node) -> void:
	await _animar_puerta(puerta, "cerrar_puerta")
	var animacion: AnimatedSprite2D = puerta.get("animacion") if puerta != null else null
	if animacion != null:
		animacion.visible = false


func _animar_puerta(puerta: Node, nombre: String) -> void:
	var animacion: AnimatedSprite2D = puerta.get("animacion") if puerta != null else null
	if animacion == null or not animacion.sprite_frames.has_animation(nombre):
		return
	# Solo opendoor/closedoor: el cambio de mapa pertenece al coordinador de Warp,
	# no a un callback de animation_finished. Los guiones no inician una transición.
	animacion.visible = true
	animacion.play(nombre)
	await animacion.animation_finished


## Los guiones ON_FRAME de pokeruby corren con el mapa ya visible: espera a que el
## warp en curso coloque al jugador y aclare la pantalla.
func esperar_fin_warp(administrador: Node) -> void:
	await get_tree().process_frame
	while is_instance_valid(administrador) and int(administrador.get("coneccion")) != 0:
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout


## Termina la salida de la puerta `celda` por la que llegó el jugador: si el paso de salida
## del warp sigue en curso espera a que acabe (caminar_guion lo completaría y daría otro);
## si el bloqueo del guion lo cortó, lo da.
func completar_salida_puerta(celda: Vector2i, direccion: Vector2 = Vector2.DOWN) -> void:
	var jugador: Node = admin.jugador
	while is_instance_valid(jugador) and jugador.get("paso_en_curso") == true:
		await get_tree().process_frame
	if jugador.pos_celda_act == celda:
		await recorrer_jugador([direccion])


## fadescreen FADE_TO_BLACK / FADE_FROM_BLACK.
func oscurecer_pantalla() -> void:
	await Singleton.transicion("oscurecer")


func aclarar_pantalla() -> void:
	await Singleton.transicion("aclarar")


## showmoneybox 0, 0: recuadro con el dinero del jugador en la esquina superior
## izquierda. Se cuelga de la capa de menús del administrador y se oculta solo en
## terminar().
func mostrar_cuadro_dinero() -> void:
	if not is_instance_valid(admin):
		return
	if not is_instance_valid(_cuadro_dinero):
		_cuadro_dinero = CUADRO_DINERO.instantiate()
		var capa: Node = admin.get_node_or_null("Menu")
		(capa if capa != null else admin).add_child(_cuadro_dinero)
	_cuadro_dinero.establecer_dinero(SistemaGuardado.get_dinero_jugador())


## updatemoneybox: refresca la cifra tras cobrar o pagar.
func actualizar_cuadro_dinero() -> void:
	if is_instance_valid(_cuadro_dinero):
		_cuadro_dinero.establecer_dinero(SistemaGuardado.get_dinero_jugador())


## hidemoneybox.
func ocultar_cuadro_dinero() -> void:
	if is_instance_valid(_cuadro_dinero):
		_cuadro_dinero.queue_free()
	_cuadro_dinero = null


## delay N / Common_Movement_DelayN.
func esperar_fotogramas(fotogramas: int) -> void:
	await get_tree().create_timer(fotogramas / FOTOGRAMAS_POR_SEGUNDO).timeout


## dofieldeffect FLDEFF_NPCFLY_OUT, delay 15, removeobject, waitfieldeffect: el NPC se va volando.
func salir_volando(npc: Node2D) -> void:
	var pajaro := _soltar_pajaro_vuelo()
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_DESAPARECER)
	npc.visible = false
	if is_instance_valid(pajaro):
		await pajaro.terminado


## dofieldeffect FLDEFF_NPCFLY_OUT, waitfieldeffect: el pájaro cruza la pantalla sin retirar a nadie.
func cruzar_pajaro_vuelo() -> void:
	await _soltar_pajaro_vuelo().terminado


func _soltar_pajaro_vuelo() -> PajaroVueloNpc:
	Singleton.play_sound.emit(SONIDO_VUELO)
	var pajaro: PajaroVueloNpc = PAJARO_VUELO.instantiate()
	add_child(pajaro)
	return pajaro


## addobject / setobjectxyperm: coloca al NPC en `celda` como recién aparecido.
static func colocar(npc: Node2D, celda: Vector2i) -> void:
	npc.coord = celda
	npc.position = npc.posicion_de_celda(celda) if npc.has_method(&"posicion_de_celda") \
		else Vector2(celda.x * 16 + 8, celda.y * 16 + 14)
	npc.coord_celda = celda
	npc.celda_origen = celda
	npc.rango_ini = celda - npc.rango
	npc.rango_fin = celda + npc.rango
	if npc.animated_sprite:
		npc.direccion_inicial()


## ============================================================================
## MÚSICA Y COMBATE
## ============================================================================

## playbgm. Corta el fundido del tema del mapa si sigue en curso: un evento puede
## dispararse justo al entrar en el mapa y su tema no debe descartarse.
func reproducir_musica(tema: String) -> void:
	if Singleton.TEMAS_REGISTRADOS.has(tema):
		Singleton.reproducir_tema(tema, true)


## savebgm 0 + fadedefaultbgm: vuelve la música del mapa.
func restaurar_musica_mapa() -> void:
	if is_instance_valid(admin) and admin.has_method("restaurar_musica_mapa_actual"):
		admin.restaurar_musica_mapa_actual()


## playmoncry: devuelve el reproductor para esperar_grito (null si no hay grito).
func grito(numero_nacional: int) -> AudioStreamPlayer:
	var ruta := RUTA_GRITO % numero_nacional
	if not con_gritos or not ResourceLoader.exists(ruta):
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(ruta) as AudioStream
	reproductor.finished.connect(reproductor.queue_free)
	add_child(reproductor)
	reproductor.play()
	return reproductor


## waitmoncry. Sin tipo: si el grito ya terminó, el reproductor está liberado.
func esperar_grito(reproductor: Variant) -> void:
	if is_instance_valid(reproductor) and (reproductor as AudioStreamPlayer).playing:
		await (reproductor as AudioStreamPlayer).finished


## trainerbattle_no_intro. Devuelve &"victoria", &"derrota_transferida" (el
## coordinador de derrota ya lleva al jugador al punto de curación) o &"fallo".
func combatir(entrenador_id: int, musica: String = "") -> StringName:
	admin.cuadro_dialogo.cerrar()
	var manager := admin.get("battle_manager") as OverworldBattleManager
	if manager == null:
		push_warning("[%s] Sin OverworldBattleManager" % motivo_pausa)
		return &"fallo"
	var opciones := OpcionesBatallaOverworld.para_entrenador(musica)
	var ejecucion: ResultadoEjecucionBatalla = await manager.combatir_entrenador(entrenador_id, opciones)
	if ejecucion.fue_rechazada():
		push_warning("[%s] Combate %d rechazado: %s" % [motivo_pausa, entrenador_id, ejecucion.codigo_error])
		return &"fallo"
	match ejecucion.resultado:
		ResultadoBatalla.Valor.VICTORIA_JUGADOR:
			return &"victoria"
		ResultadoBatalla.Valor.VICTORIA_ENEMIGO:
			return &"derrota_transferida" if manager.recuperar_derrota_estandar() else &"fallo"
	return &"fallo"


## ============================================================================
## UTILIDADES
## ============================================================================

func obtener_mapa() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo as MapaConfiguracion
