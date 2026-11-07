@tool
extends "res://scripts/npc/npc_base.gd"

## Identificador del encuentro; puede compartirse entre dos NPC de una pareja.
@export var npc_id: String = ""
## ID del entrenador (0 si no es entrenador)
@export var entrenador_id: int = 0
## Activación opcional: los entrenadores existentes conservan su formato.
@export var combate_doble: bool = false
## Rango de visión (0 si no es entrenador)
## OJO: el rango de PASEO (`rango`) está anclado a `celda_origen` (npc_base). Los
## mapas quedan instanciados y sus NPC se reinicializan al ocultarse; no recalcular
## rango_ini/rango_fin desde coord_celda o el entrenador deriva fuera de su ruta.
@export var rango_vision: int = 0
## Ve en las cuatro direcciones, no solo hacia donde mira (trainerType BURIED (3)
## y SEE_ALL_DIRECTIONS (2) de pokeruby). Al detectar al jugador se gira hacia él.
## Los entrenadores OCULTO (enterrados en la ceniza de la Ruta 113) deben activarlo.
@export var ver_en_todas_direcciones: bool = false
## Activación independiente de la visibilidad: mientras la condición no se cumpla
## (bandera de SistemaGuardado o condición de CondicionTexto, como bandera_mostrar) el
## entrenador no avista al jugador aunque se vea. Vacío = siempre activo. Un entrenador
## OCULTO (visible = false, por bandera_ocultar/bandera_mostrar o por un guion) tampoco
## avista nunca: los objetos invisibles de Rubí no ven.
@export var bandera_activo: String = ""
## Texto a mostrar cuando ya se perdió el combate
@export var texto_post_combate: String = "..."
## Al perder dice texto_post_combate sin que le hablen: el `trainerbattle_*` de Rubí con
## guion de continuación que solo es `msgbox` + `release` (p. ej. soldados de la GUARIDA).
@export var hablar_al_perder: bool = false
## Combate doble (`trainerbattle_double`): texto si el jugador no tiene dos
## Pokémon que puedan combatir. Sin él, el combate empieza igualmente.
@export var texto_sin_dos_pokemon: String = ""
## Música de batalla específica. Selecciona desde Singleton.TEMAS_REGISTRADOS.
## Por defecto se usa la que esté definida en la Configuración del mapa.
@export var musica_batalla: String = "Por defecto"
## Jingle de presentación: el que suena en el mapa cuando el entrenador te ve.
## Selecciona desde Singleton.TEMAS_REGISTRADOS. "Por defecto" usa el jingle
## del registro del entrenador (`jingle_id`), como en la ROM.
@export var musica_presentacion: String = "Por defecto"
@export_group("Revancha")
## Presentación de la revancha (`trainerbattle_rematch` de Rubí). Solo se usa si
## el entrenador está en la tabla de revanchas (`TablaRevanchas`).
@export var texto_revancha: String = ""
## Texto al hablarle tras ganar alguna revancha, mientras no pida otra.
@export var texto_post_revancha: String = ""
## Revancha doble: texto si el jugador no tiene dos Pokémon que puedan combatir.
@export var texto_revancha_sin_dos_pokemon: String = ""
@export_group("")

## El jugador ha ganado el combate normal (no la revancha) iniciado por este NPC.
## Solo lo emite el miembro de la pareja que inició el combate.
signal combate_ganado(id_combate: int)
signal _post_combate_dicho

const PREFIJO_CONTEXTO_PRECARGA_MUSICA: String = "npc_entrenador_"
const TIPO_MIRAR_FIJO: Dictionary = {
	Vector2.UP: TipoMovimientoNPC.MIRAR_ARRIBA,
	Vector2.DOWN: TipoMovimientoNPC.MIRAR_ABAJO,
	Vector2.LEFT: TipoMovimientoNPC.MIRAR_IZQUIERDA,
	Vector2.RIGHT: TipoMovimientoNPC.MIRAR_DERECHA,
}

var ya_detectado_jugador: bool = false
var combate_pendiente: bool = false
var battle_manager: OverworldBattleManager = null
var _posee_secuencia_entrenador: bool = false
var _control_transferido_a_derrota: bool = false
## Tier que se está combatiendo en la revancha en curso (0 = ninguna).
var _id_revancha_en_curso: int = 0
## id_texto de la escena (presentación), para volver a él si se borra la bandera
## de combate (`cleartrainerflag`).
var _id_texto_presentacion: String = ""
## Guion tras ganar el combate normal (el script de victoria de trainerbattle).
## Recibe este NPC; se espera antes de devolver el control al jugador.
var continuacion_victoria: Callable = Callable()


func _ready() -> void:
	super._ready()
	_id_texto_presentacion = id_texto
	if not Engine.is_editor_hint():
		battle_manager = _obtener_battle_manager()
	_registrar_precarga_musica_si_corresponde()
	combate_pendiente = Engine.is_editor_hint() or not SistemaGuardado.get_flag(npc_id + "_combate")
	if not combate_pendiente:
		id_texto = texto_post_combate
		callback_dialogo = Callable()
	_loggear("npc entrenador listo con id_texto='%s'" % id_texto)


func _exit_tree() -> void:
	_cerrar_secuencia_entrenador()
	_liberar_precarga_musica_si_corresponde()


func _process(delta: float) -> void:
	_sincronizar_victoria_compartida()
	super._process(delta)
	if combate_pendiente and estado_actual == EstadoNPC.IDLE and _puede_detectar_jugador():
		_validar_vision_jugador()


## Dos NPC pueden representar a un único entrenador (p. ej. Tori y Tia).
## El que no inició el combate debe dejar de detectar al jugador al ganar el otro.
func _sincronizar_victoria_compartida() -> void:
	if not Engine.is_editor_hint() and combate_pendiente and not npc_id.is_empty() and SistemaGuardado.get_flag(npc_id + "_combate"):
		combate_pendiente = false
		ya_detectado_jugador = false
		id_texto = texto_post_combate
		callback_dialogo = Callable()


func _obtener_battle_manager() -> OverworldBattleManager:
	if not is_instance_valid(nodo_administrador):
		nodo_administrador = Singleton.obtener_nodo("Admin")
	if not is_instance_valid(nodo_administrador):
		return null
	return nodo_administrador.get("battle_manager") as OverworldBattleManager


## Solo detecta el entrenador del mapa activo: las celdas del jugador son locales
## a ese mapa y los demás mapas del overworld siguen instanciados (ver es_mapa_activo).
## Exige es_mapa_activo() SIEMPRE, incluso con procesar_fuera_del_mapa_activo: ese
## seteo permite actuar, no comparar celdas locales de mapas distintos.
func _puede_detectar_jugador() -> bool:
	if not esta_activo():
		return false
	if nodo_administrador != null and not nodo_administrador.puede_actuar_npc():
		return false
	if not _comparte_capa_con_jugador():
		return false
	return es_mapa_activo()


## Puede avistar al jugador: se ve en pantalla (no está oculto por bandera o guion) y,
## si tiene `bandera_activo`, esa condición se cumple.
func esta_activo() -> bool:
	if not visible:
		return false
	return bandera_activo.is_empty() or CondicionTexto.cumple(bandera_activo)


## Validar si el jugador está en rango de visión (si es entrenador).
## Como TrainerCanApproachPlayer de pokeruby, se compara con la celda DESTINO del
## jugador: si está a mitad de paso cuenta la celda a la que llega, no la que deja.
func _validar_vision_jugador() -> void:
	if entrenador_id <= 0 or rango_vision <= 0 or jugador == null or ya_detectado_jugador:
		return
	if _distancia_vision(jugador.obtener_celda_destino()) == 0:
		return
	if not _abrir_secuencia_entrenador():
		return
	ya_detectado_jugador = true
	_iniciar_secuencia_entrenador()


## Distancia (1..rango_vision) a la que el entrenador ve la celda; 0 si no la ve.
func _distancia_vision(celda: Vector2i) -> int:
	for direccion in _direcciones_vision():
		var distancia := _distancia_vision_hacia(celda, direccion)
		if distancia > 0:
			return distancia
	return 0


## TrainerCanApproachPlayer: solo hacia donde mira o, si ve en todas las
## direcciones, en el orden de sDirectionalApproachDistanceFuncs (S, N, O, E).
func _direcciones_vision() -> Array[Vector2]:
	if ver_en_todas_direcciones:
		return [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
	return [facing_direction]


func _distancia_vision_hacia(celda: Vector2i, direccion: Vector2) -> int:
	for i in range(1, rango_vision + 1):
		if coord_celda + Vector2i(direccion) * i == celda:
			return i
	return 0


## Al ver al jugador desde otra dirección, el entrenador se gira hacia él.
func _mirar_hacia_jugador() -> void:
	if not ver_en_todas_direcciones or not is_instance_valid(jugador):
		return
	var direccion := direccion_hacia(coord_celda, jugador.obtener_celda_destino())
	if direccion != facing_direction:
		update_direction(direccion)


## SetTrainerMovementType + OverrideMovementTypeForEventObject (trainer_see.c): al
## ver al jugador el entrenador abandona su patrón (giros, paseos) y queda fijo
## mirando hacia donde miraba. Al cambiar tipo_movimiento también cambia la
## dirección de reposo, por lo que persiste tras el combate, la derrota y las
## reinicializaciones del mapa.
func _fijar_direccion_al_detectar() -> void:
	var fijo: Variant = TIPO_MIRAR_FIJO.get(facing_direction)
	if fijo == null:
		return
	var direccion := facing_direction
	tipo_movimiento = fijo
	facing_direction = direccion
	direccion_base = direccion
	_iniciar_temporizador()


## Inicia la secuencia completa de animaciones cuando detecta al jugador
func _iniciar_secuencia_entrenador() -> void:
	cambiar_estado(EstadoNPC.INTERACTING)
	# Disfrazados y enterrados se giran al revelarse, no antes.
	if not es_tipo_revelable(tipo_movimiento):
		_mirar_hacia_jugador()
	# El paso en curso del jugador no se corta (dejaría su sprite entre dos celdas):
	# la pausa de la secuencia ya bloquea su entrada y se detiene al llegar.
	_detener_jugador_al_llegar()
	_reproducir_musica_presentacion()
	await _animar_exclamacion()
	# sub_80843DC: tras la exclamación, los DISFRAZ_* y OCULTO se revelan antes de
	# acercarse (sub_8084578 / sub_80845C8..sub_80846C8).
	if es_tipo_revelable(tipo_movimiento):
		await revelar()
		_mirar_hacia_jugador()
	# Después de revelar: cambia el tipo a MIRAR_* fijo (y con él se va el disfraz).
	_fijar_direccion_al_detectar()
	# sub_8084478: el entrenador no se acerca con el jugador aún en movimiento.
	await _detener_jugador_al_llegar()
	var pasos := 0
	while is_instance_valid(jugador) and coord_celda.distance_to(jugador.pos_celda_act) > 1.5 and pasos < 20:
		await _caminar_hacia_jugador()
		pasos += 1
	# OverrideTemplateCoordsForEventObject: donde se detiene es su nueva celda de origen.
	celda_origen = coord_celda
	rango_ini = celda_origen - rango
	rango_fin = celda_origen + rango
	await _hacer_jugador_mirar_npc()
	await get_tree().create_timer(0.05).timeout
	callback_dialogo = Callable(self, "_iniciar_combate_entrenador")
	super.evento_accion()


func evento_accion() -> void:
	_sincronizar_victoria_compartida()
	if combate_pendiente:
		if _falta_segundo_pokemon():
			_decir_sin_dos_pokemon()
			return
		if not _abrir_secuencia_entrenador():
			return
		# Hablarle sin pasar por su campo de visión: la música de presentación
		# suena desde el inicio del diálogo, como al ser avistado.
		_reproducir_musica_presentacion()
		callback_dialogo = Callable(self, "_iniciar_combate_entrenador")
		# EventScript_19F8E5 (reveal_trainer): se destapa antes de hablar.
		if es_tipo_revelable(tipo_movimiento) and estado_actual != EstadoNPC.MOVING:
			var era_oculto := tipo_movimiento == TipoMovimientoNPC.OCULTO
			cambiar_estado(EstadoNPC.INTERACTING)
			await revelar()
			# sub_80846E4: al salir de la ceniza queda fijo mirando al jugador.
			if era_oculto:
				_fijar_direccion_al_detectar()
	else:
		_preparar_interaccion_vencido()
	super.evento_accion()


## trainerbattle_double con menos de dos Pokémon aptos (HasEnoughMonsForDoubleBattle).
func _falta_segundo_pokemon() -> bool:
	return combate_doble and not texto_sin_dos_pokemon.is_empty() 		and not OverworldBattleManager.jugador_puede_combate_doble(SistemaGuardado.get_equipo())


## Muestra texto_sin_dos_pokemon sin combatir; id_texto se lee al abrir el cuadro.
func _decir_sin_dos_pokemon() -> void:
	if estado_actual == EstadoNPC.MOVING:
		super.evento_accion()
		return
	var presentacion := id_texto
	id_texto = texto_sin_dos_pokemon
	callback_dialogo = Callable()
	super.evento_accion()
	id_texto = presentacion


## Jingle de presentación: el del entrenador según su registro, como en la ROM
## (`special PlayTrainerEncounterMusic` → PlayTrainerEncounterMusic en el decomp,
## que traduce encounterMusic_gender a un jingle). `musica_presentacion` del
## inspector manda sobre el registro, para poder forzarlo sin tocar datos.
func _reproducir_musica_presentacion() -> void:
	var musica := musica_presentacion
	if musica.is_empty() or musica == "Por defecto" or not Singleton.TEMAS_REGISTRADOS.has(musica):
		musica = _jingle_del_entrenador()
	Singleton.reproducir_tema(musica)


## Clave del jingle de este entrenador: la del registro si existe, y el
## genérico como respaldo.
func _jingle_del_entrenador() -> String:
	var entrenador := _datos_entrenador()
	if entrenador != null:
		return MusicaRubi.jingle_encuentro(entrenador.jingle_id)
	return MusicaRubi.jingle_encuentro(MusicaRubi.indice_encuentro(0))


## Datos del entrenador de la tabla, o null si no hay.
func _datos_entrenador() -> DatosEntrenador:
	if entrenador_id <= 0 or DatabaseManager == null:
		return null
	return DatabaseManager.get_entrenador(entrenador_id)


## Texto y continuación al hablar con el entrenador ya vencido, como los scripts
## de mapa de Rubí: `trainerbattle_single` (vencido) → `ShouldTryRematchBattle`
## → `trainerbattle_rematch(_double)` / `EventScript_TryDoRematchBattle`.
## Un entrenador vencido nunca vuelve a detectar al jugador: hay que hablarle.
func _preparar_interaccion_vencido() -> void:
	id_texto = texto_post_combate
	callback_dialogo = Callable()
	_id_revancha_en_curso = 0
	var indice := indice_revancha_candidato()
	if indice < 0:
		return
	var revanchas := SistemaGuardado.get_revanchas()
	if not revanchas.debe_ofrecer_revancha(indice):
		return
	if not revanchas.esta_lista(indice):
		if not texto_post_revancha.is_empty():
			id_texto = texto_post_revancha
		return
	if texto_revancha.is_empty():
		push_warning("[NPC_ENTRENADOR] %s tiene revancha lista pero no texto_revancha" % npc_id)
		return
	# HasEnoughMonsForDoubleBattle: sin dos Pokémon aptos no hay combate y la
	# revancha sigue pendiente.
	if combate_doble and not OverworldBattleManager.jugador_puede_combate_doble(SistemaGuardado.get_equipo()):
		if not texto_revancha_sin_dos_pokemon.is_empty():
			id_texto = texto_revancha_sin_dos_pokemon
		return
	id_texto = texto_revancha
	if not _abrir_secuencia_entrenador():
		id_texto = texto_post_combate
		return
	_id_revancha_en_curso = revanchas.id_revancha(indice)
	_reproducir_musica_presentacion()
	callback_dialogo = Callable(self, "_iniciar_combate_revancha")


## Índice en la tabla de revanchas si este NPC es el tier 1 de una entrada y ya
## fue vencido (candidato al sorteo de `AdministradorMapa`); −1 si no.
func indice_revancha_candidato() -> int:
	if Engine.is_editor_hint() or entrenador_id <= 0 or npc_id.is_empty():
		return -1
	if not SistemaGuardado.get_flag(npc_id + "_combate"):
		return -1
	return SistemaGuardado.get_revanchas().indice_por_primer_id(entrenador_id)


func _iniciar_combate_entrenador() -> void:
	await _ejecutar_combate(entrenador_id, false)


func _iniciar_combate_revancha() -> void:
	await _ejecutar_combate(_id_revancha_en_curso, true)


func _ejecutar_combate(id_combate: int, es_revancha: bool) -> void:
	cambiar_estado(EstadoNPC.INTERACTING)
	battle_manager = _obtener_battle_manager()
	if battle_manager == null:
		_al_fallar_inicio(&"manager_ausente")
		return
	if is_instance_valid(jugador):
		jugador.detener_movimientos()
	var musica_override := "" if musica_batalla == "Por defecto" else musica_batalla
	var opciones := OpcionesBatallaOverworld.para_entrenador(musica_override)
	opciones.formato_doble = combate_doble
	var ejecucion: ResultadoEjecucionBatalla = await battle_manager.combatir_entrenador(id_combate, opciones)
	if ejecucion.fue_rechazada():
		_al_fallar_inicio(ejecucion.codigo_error)
		return
	match ejecucion.resultado:
		ResultadoBatalla.Valor.VICTORIA_JUGADOR:
			if es_revancha:
				_al_ganar_revancha(id_combate)
			else:
				await _al_ganar_al_entrenador()
		ResultadoBatalla.Valor.VICTORIA_ENEMIGO:
			await _al_perder_contra_entrenador()
		_:
			_al_fallar_inicio(&"resultado_no_valido_para_entrenador")
			return
	_cerrar_secuencia_entrenador()
	if is_inside_tree():
		cambiar_estado(EstadoNPC.IDLE)


func _al_ganar_al_entrenador() -> void:
	_consumir_combate()
	combate_ganado.emit(entrenador_id)
	# trainerbattle_* con guion de victoria (p. ej. la entrevista de GABI y TEO):
	# corre antes de devolver el control, con este NPC como argumento.
	if continuacion_victoria.is_valid():
		await continuacion_victoria.call(self)
	if hablar_al_perder and nodo_administrador != null:
		nodo_administrador.cuadro_dialogo.mostrar(tr(texto_post_combate), true, true, _post_combate_dicho.emit)
		await _post_combate_dicho


## `cleartrainerflag`: si alguien borró la bandera de combate de este npc_id, el
## entrenador vuelve a esperar combate con su texto de presentación.
func rearmar_combate_si_bandera_borrada() -> void:
	if Engine.is_editor_hint() or combate_pendiente or npc_id.is_empty():
		return
	if SistemaGuardado.get_flag(npc_id + "_combate"):
		return
	combate_pendiente = true
	ya_detectado_jugador = false
	id_texto = _id_texto_presentacion
	callback_dialogo = Callable()


## `CB2_EndTrainerEyeRematchBattle` + `SetTrainerFlagsAfterTrainerEyeRematch`: marca
## el tier y la entrada deja de estar lista. Sin texto posterior en el overworld.
func _al_ganar_revancha(id_combate: int) -> void:
	SistemaGuardado.get_revanchas().registrar_victoria(id_combate)
	_id_revancha_en_curso = 0
	id_texto = texto_post_combate
	callback_dialogo = Callable()
	_loggear("Revancha contra entrenador %d ganada" % id_combate)


func _al_perder_contra_entrenador() -> void:
	resetear_deteccion_jugador()
	if battle_manager != null:
		_control_transferido_a_derrota = battle_manager.recuperar_derrota_estandar()


func _consumir_combate() -> void:
	SistemaGuardado.set_flag(npc_id + "_combate", true)
	combate_pendiente = false
	id_texto = texto_post_combate
	callback_dialogo = Callable()
	_loggear("Combate contra entrenador %d consumido en memoria" % entrenador_id)


func _al_fallar_inicio(codigo: StringName) -> void:
	_loggear("No pudo iniciarse el combate (%s)" % codigo)
	resetear_deteccion_jugador()
	callback_dialogo = Callable()
	_cerrar_secuencia_entrenador()
	if is_instance_valid(jugador) and jugador.has_method("esperar_dialogo"):
		jugador.esperar_dialogo(false)
	if is_inside_tree():
		cambiar_estado(EstadoNPC.IDLE)
	if is_instance_valid(nodo_administrador) and nodo_administrador.has_method("restaurar_musica_mapa_actual"):
		nodo_administrador.restaurar_musica_mapa_actual()


func _abrir_secuencia_entrenador() -> bool:
	if _posee_secuencia_entrenador:
		return true
	if npc_id.strip_edges().is_empty() or entrenador_id <= 0 or id_texto.strip_edges().is_empty():
		push_warning("[NPC_ENTRENADOR] Configuración inválida: npc_id/entrenador_id/id_texto")
		return false
	if Singleton.motivos_pausa().has(&"secuencia_entrenador"):
		return false
	_posee_secuencia_entrenador = true
	Singleton.mantener_pausa(&"secuencia_entrenador", true)
	return true


func _cerrar_secuencia_entrenador() -> void:
	if not _posee_secuencia_entrenador:
		return
	_posee_secuencia_entrenador = false
	Singleton.mantener_pausa(&"secuencia_entrenador", false)
	if not _control_transferido_a_derrota and is_instance_valid(jugador) and jugador.has_method("esperar_dialogo"):
		jugador.esperar_dialogo(false)
	_control_transferido_a_derrota = false


func _animar_exclamacion() -> void:
	await mostrar_exclamacion()


## Espera a que el jugador termine su paso o salto en curso y lo inmoviliza.
func _detener_jugador_al_llegar() -> void:
	while is_instance_valid(jugador) and jugador.esta_en_movimiento():
		await get_tree().process_frame
	if is_instance_valid(jugador):
		jugador.detener_movimientos()


func _caminar_hacia_jugador() -> void:
	mover_npc(facing_direction)
	while estado_actual == EstadoNPC.MOVING:
		await get_tree().process_frame
	if estado_actual == EstadoNPC.IDLE:
		cambiar_estado(EstadoNPC.INTERACTING)


func _hacer_jugador_mirar_npc() -> void:
	if jugador == null:
		return
	if jugador.facing_direction != direcciones_opuestas[facing_direction]:
		jugador.can_move(direcciones_opuestas[facing_direction])
		jugador._actualizar_animacion_idle()
	await get_tree().process_frame


func resetear_deteccion_jugador() -> void:
	ya_detectado_jugador = false


func _obtener_contexto_precarga_musica() -> String:
	return "%s%d" % [PREFIJO_CONTEXTO_PRECARGA_MUSICA, get_instance_id()]


func _obtener_temas_precarga_musica() -> Array[String]:
	var temas: Array[String] = []
	var tema_presentacion := musica_presentacion
	if tema_presentacion == "Por defecto" or not Singleton.TEMAS_REGISTRADOS.has(tema_presentacion):
		tema_presentacion = _jingle_del_entrenador()
	var musica_registro := ""
	var entrenador := _datos_entrenador()
	if entrenador != null:
		musica_registro = entrenador.musica_id
	for tema in [
		tema_presentacion,
		"" if musica_batalla == "Por defecto" else musica_batalla,
		musica_registro,
	]:
		if not tema.is_empty() and Singleton.TEMAS_REGISTRADOS.has(tema) and not temas.has(tema):
			temas.append(tema)
	return temas


func _registrar_precarga_musica_si_corresponde() -> void:
	if Engine.is_editor_hint() or not is_instance_valid(nodo_administrador):
		return
	if nodo_administrador.has_method("actualizar_precarga_musica_contexto"):
		nodo_administrador.actualizar_precarga_musica_contexto(
			_obtener_contexto_precarga_musica(),
			_obtener_temas_precarga_musica()
		)


func _liberar_precarga_musica_si_corresponde() -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(nodo_administrador) and nodo_administrador.has_method("liberar_precarga_musica_contexto"):
		nodo_administrador.liberar_precarga_musica_contexto(_obtener_contexto_precarga_musica())
