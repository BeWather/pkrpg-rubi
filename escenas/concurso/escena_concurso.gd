class_name EscenaConcurso
extends Node2D
## Pantalla de las apelaciones de un concurso (CB2_StartContest … Task_EndAppeals,
## src/contest.c). La lógica vive en MotorConcurso; esta escena pide la elección del
## jugador, ejecuta cada turno y reproduce sus EventoConcurso con los tiempos de
## pokeruby (anexo de núcleo §2.2-2.3 y §6.5).
##
## Uso: `await escena.ejecutar(motor)` con el motor ya iniciado. Al volver, el motor
## tiene las puntuaciones finales (estado.terminado).

signal concurso_terminado

## Posición de la caja `p` (gUnknown_083CA308: columna 19, filas p × 5).
const X_CAJAS: float = 144.0
const ALTO_CAJA: float = 40.0
## Pokémon de espalda: 64×64 centrado en x = 112 (CreateContestantSprite) con la base a
## la altura del Pokémon del jugador en combate. Mira a la izquierda: se refleja con
## gAffineAnims_BattleSpriteContest, salvo UNOWN (IsSpeciesNotUnown).
const POSICION_POKEMON: Vector2 = Vector2(80, 48)
const ENTRADA_POKEMON: float = 120.0
const ESPECIE_SIN_REFLEJO: String = "UNOWN"
const TELON_PIXELES_POR_FRAME: float = 7.0
const ALTO_PANTALLA: float = 160.0
## BlendAudienceBackground: dorado hasta aplausos × 3 / 16 o negro hasta 12 / 16.
const COLOR_PUBLICO_ANIMADO: Color = Color(30.0 / 31.0, 27.0 / 31.0, 8.0 / 31.0)
const COLOR_PUBLICO_ABURRIDO: Color = Color(0, 0, 0)
const PREFIJO_CADENA: String = "CONCURSO_CADENA_"
## Coordenadas 0/1 de los battlers (gUnknown_0837F578): el concursante tiene la posición 3
## y el objetivo invisible la 2 (gBattlerPositions de contest.c). Por eso el concursante
## anima como el lado rival.
const BASE_ATACANTE: Vector2 = Vector2(112, 80)
const CENTRO_OBJETIVO: Vector2 = Vector2(48, 40)
const LADO_SPRITE: int = 64
## SanitizeMove y gBattleAnims_Moves[0]: sin movimiento válido se anima Destructor.
const MOVIMIENTO_POR_DEFECTO: int = 1
const NUM_MOVIMIENTOS: int = 355
const MOV_RETROCESO: int = 216
const MOV_FRUSTRACION: int = 218
const MOV_MALDICION: int = 174
const MOV_REFUERZO: int = 270
## SetMoveSpecificAnimData: los de dos turnos muestran carga y ataque seguidos (Viento
## Cortante, Rayo Solar, Cabezazo, Ataque Aéreo).
const MOVIMIENTOS_DOS_PASADAS: Array[int] = [13, 76, 130, 143]
## Estado 9 de Task_DoAppeals (data[10]++ > 30): pausa entre las dos pasadas.
const PAUSA_ENTRE_PASADAS: float = 31.0
const TIPO_FANTASMA: int = 8
const MOV_TRANSFORMACION: int = 144
const MOV_SUSTITUTO: int = 164
const MOV_IMITACION: int = 272
## sub_8031FC4: la imagen de Transformación queda 6/16 hacia el blanco.
const BLANCO_TRANSFORMACION: float = 6.0 / 16.0

## Factor de todas las esperas; 0 = un frame por espera (tests).
@export var escala_tiempo: float = 1.0
## Los mensajes que piden A siguen solos (demostraciones y capturas).
@export var avance_automatico: bool = false
## Si es válido, decide el hueco del jugador sin menú: func(motor) -> int.
var elegir_movimiento: Callable = Callable()
## Textos mostrados en orden (para tests y depuración).
var registro_textos: PackedStringArray = []

var motor: MotorConcurso
var datos: DatosConcurso
var _material_pokemon: Material

@onready var _tinte_publico: ColorRect = $TintePublico
@onready var _juez: JuezConcurso = $Juez
@onready var _slot_atacante: BattleSlot = $SlotAtacante
@onready var _slot_objetivo: BattleSlot = $SlotObjetivo
@onready var _pokemon: Sprite2D = $SlotAtacante/Pokemon
@onready var _cajas: Array[CajaConcursante] = [$Cajas/Caja0, $Cajas/Caja1, $Cajas/Caja2, $Cajas/Caja3]
@onready var _medidor: MedidorAplausos = $MedidorAplausos
@onready var _telon: Sprite2D = $Telon
@onready var _menu: MenuMovimientosConcurso = $MenuMovimientos
@onready var _caja_texto: CajaTextoBatalla = $CajaTexto
@onready var _cursor_texto: AnimatedSprite2D = $CajaTexto/Cursor


func _ready() -> void:
	_caja_texto.set_cursor(_cursor_texto)
	_material_pokemon = _pokemon.material
	_pokemon.visible = false
	_preparar_objetivo_invisible()
	_tinte_publico.color.a = 0.0
	_aplicar_escala()


func _aplicar_escala() -> void:
	_juez.escala_tiempo = escala_tiempo
	_medidor.escala_tiempo = escala_tiempo
	for caja in _cajas:
		caja.escala_tiempo = escala_tiempo
	var rapido: bool = escala_tiempo <= 0.0
	_caja_texto.mostrar_todo_instantaneo = rapido
	_caja_texto.confirmacion_automatica = rapido or avance_automatico
	_caja_texto.pausa_automatica = 0.0 if rapido else CajaTextoBatalla.PAUSA_LECTURA


# === Flujo ===

## Las 5 apelaciones. Devuelve cuando el telón ha bajado tras «¡Se acabó el tiempo…!».
func ejecutar(motor_concurso: MotorConcurso) -> void:
	motor = motor_concurso
	datos = motor.datos
	_aplicar_escala()
	_redibujar_cajas()
	_telon.position.y = 0.0
	# Task_RaiseCurtainAtStart: 60 frames, telón arriba y entra el medidor.
	await esperar(60.0)
	await subir_telon()
	while not motor.terminado():
		await _jugar_apelacion()
	concurso_terminado.emit()


func _jugar_apelacion() -> void:
	var estado: EstadoConcurso = motor.estado
	var jugador: ConcursanteConcurso = motor.concursante(estado.indice_jugador)
	await _medidor.entrar()
	var numero: int = estado.numero_apelacion + 1
	var hueco: int = 0
	if jugador.turno_deshabilitado():
		# Task_DisplayAppealNumberText: «¡Pero no puede participar!» y sin menú.
		await mostrar_texto(_t("CONCURSO_EXHIBICION_N_NO_PARTICIPA", {"n": numero}))
		await esperar(60.0)
	else:
		await mostrar_texto(_t("CONCURSO_EXHIBICION_N", {"n": numero}), 0.0)
		await _caja_texto.esperar_input_continuar(Callable(), true)
		hueco = await _elegir_hueco(jugador)
	# Task_HideApplauseMeterForAppealStart + Task_AppealSetup (20 frames).
	_caja_texto.limpiar()
	await _medidor.salir()
	await esperar(20.0)
	motor.elegir_movimientos(hueco)
	for _turno in EstadoConcurso.NUM_CONCURSANTES:
		for evento in motor.ejecutar_turno():
			await reproducir(evento)
	for evento in motor.cerrar_apelacion():
		await reproducir(evento)


func _elegir_hueco(jugador: ConcursanteConcurso) -> int:
	if elegir_movimiento.is_valid():
		return int(elegir_movimiento.call(motor))
	_caja_texto.visible = false
	var hueco: int = await _menu.elegir(datos, jugador)
	_caja_texto.visible = true
	return hueco


# === Reproducción de eventos ===

func reproducir(evento: EventoConcurso) -> void:
	var i: int = evento.concursante
	var d: Dictionary = evento.datos
	match evento.tipo:
		EventoConcurso.Tipo.INICIO_APELACION:
			pass
		EventoConcurso.Tipo.OBSERVA:
			await mostrar_texto(_t("CONCURSO_OBSERVA", {"mon": _mote(i)}))
			await esperar(30.0)
		EventoConcurso.Tipo.ENTRA:
			await _entrar_pokemon(i)
		EventoConcurso.Tipo.NERVIOSO:
			await mostrar_texto(_t("CONCURSO_NERVIOSO_NO_ACTUA", {"mon": _mote(i)}))
			caja_de(i).fijar_atencion(false)
		EventoConcurso.Tipo.APELA:
			await mostrar_texto(_t("CONCURSO_SE_EXHIBIO", {"mon": _mote(i), "mov": _nombre_mov(int(d.get("movimiento", 0)))}))
		EventoConcurso.Tipo.ANIMACION:
			await _animar_movimiento(i, int(d.get("movimiento", 0)), int(d.get("objetivo", -1)))
		EventoConcurso.Tipo.INTERFERIDOS:
			var marcados: Array = d.get("concursantes", [])
			for k in marcados:
				caja_de(int(k)).fijar_icono(CajaConcursante.ICONO_SOBRESALTADO)
			if not marcados.is_empty():
				await esperar(20.0)
		EventoConcurso.Tipo.TEXTO_EFECTO:
			await mostrar_texto(_texto_cadena(int(d.get("cadena", EfectosConcurso.Cadena.NINGUNA)), i,
				int(d.get("actor", i))))
		EventoConcurso.Tipo.BOCADILLO:
			await _juez.mostrar_bocadillo(int(d.get("simbolo", 0)))
		EventoConcurso.Tipo.SIGUIENTE_TURNO:
			var ordenes: Array = d.get("orden_siguiente", [])
			var modos: Array = d.get("modo", [])
			for k in mini(ordenes.size(), modos.size()):
				caja_de(k).mostrar_siguiente_turno(int(modos[k]), int(ordenes[k]))
		EventoConcurso.Tipo.CORAZONES:
			await caja_de(i).animar_corazones(int(d.get("desde", 0)), int(d.get("delta", 0)))
		EventoConcurso.Tipo.ESTRELLAS:
			var antes: int = caja_de(i).estrellas
			caja_de(i).fijar_estrellas(int(d.get("condicion", 0)))
			if caja_de(i).estrellas != antes:
				TiempoConcurso.sonar(self, "SE_EXP_MAX")
				await esperar(20.0)
		EventoConcurso.Tipo.ICONO_ESTADO:
			caja_de(i).fijar_icono(int(d.get("icono", EventoConcurso.Icono.NINGUNO)))
		EventoConcurso.Tipo.ICONOS_ESTADO:
			var iconos: Array = d.get("iconos", [])
			for k in iconos.size():
				caja_de(k).fijar_icono(int(iconos[k]))
		EventoConcurso.Tipo.ATENCION_RETIRADA:
			caja_de(i).fijar_atencion(false)
		EventoConcurso.Tipo.NO_PODRA_APELAR:
			await mostrar_texto(_t("CONCURSO_NO_PODRA", {"mon": _mote(i)}))
		EventoConcurso.Tipo.COMBO:
			if bool(d.get("completado", false)):
				await mostrar_texto(_t("CONCURSO_COMBO_BIEN", {}))
			else:
				await mostrar_texto(_t("CONCURSO_JUEZ_EXPECTANTE", {"mon": _mote(i)}))
		EventoConcurso.Tipo.REPETICION:
			await mostrar_texto(_t("CONCURSO_REPETICION", {"mon": _mote(i)}))
		EventoConcurso.Tipo.PUBLICO_CONGELADO:
			await mostrar_texto(_t("CONCURSO_PUBLICO_SIGUE", {"otro": _mote(int(d.get("congelador", 0)))}))
			await mostrar_texto(_t("CONCURSO_IGNORADO", {"mon": _mote(i), "mov": _nombre_mov(int(d.get("movimiento", 0)))}))
		EventoConcurso.Tipo.PUBLICO:
			await _reaccion_publico(i, d)
		EventoConcurso.Tipo.MEDIDOR_REINICIADO:
			_medidor.fijar_nivel(0)
		EventoConcurso.Tipo.SALE:
			await _medidor.salir()
			await _salir_pokemon()
			_actualizar_atencion()
			await esperar(30.0)
		EventoConcurso.Tipo.FIN_APELACION:
			await _fin_apelacion(d)
		EventoConcurso.Tipo.FIN_CONCURSO:
			await mostrar_texto(_t("CONCURSO_FIN_EXHIBICIONES", {}))
			await bajar_telon()
			await esperar(50.0)


## Estado 41 de Task_DoAppeals: texto, medidor y tinte del público.
func _reaccion_publico(i: int, d: Dictionary) -> void:
	var cambio: int = int(d.get("cambio", 0))
	var valores: Dictionary = {"mon": _mote(i), "cat": _t("CONCURSO_CUALIDAD_%d" % int(d.get("categoria", 0)), {})}
	var clave: String = "CONCURSO_PUBLICO_MAL"
	if cambio > 0:
		clave = "CONCURSO_PUBLICO_ENTUSIASMA" if bool(d.get("lleno", false)) else "CONCURSO_PUBLICO_BIEN"
	await mostrar_texto(_t(clave, valores), 30.0)
	var aplausos: int = int(d.get("aplausos", 0))
	var tinte: Color = COLOR_PUBLICO_ANIMADO if cambio > 0 else COLOR_PUBLICO_ABURRIDO
	var intensidad: float = (aplausos * 3.0 if cambio > 0 else 12.0) / 16.0
	_tinte_publico.color = Color(tinte, 0.0)
	var tween := create_tween()
	tween.tween_property(_tinte_publico, "color:a", intensidad, maxf(0.3 * escala_tiempo, 0.01))
	await _medidor.mostrar_y_actualizar(aplausos)
	var vuelta := create_tween()
	vuelta.tween_property(_tinte_publico, "color:a", 0.0, maxf(0.3 * escala_tiempo, 0.01))
	await esperar(20.0)


## Task_FinishRoundOfAppeals … Task_UpdateRaiseCurtainAtRoundEnd.
func _fin_apelacion(d: Dictionary) -> void:
	var puntos: Array = d.get("puntos", [])
	for k in mini(puntos.size(), EstadoConcurso.NUM_CONCURSANTES):
		# El orden de las cajas aún es el de esta apelación: `orden` del evento.
		_caja_en_orden(k, d).mover_deslizador(int(puntos[k]))
	# SlidersDoneUpdating.
	while _cajas.any(func(caja: CajaConcursante) -> bool: return caja.deslizando):
		await get_tree().process_frame
	await esperar(30.0)
	var jugador: int = motor.estado.indice_jugador
	await mostrar_texto(_t("CONCURSO_ATENCION_%d" % clampi(int(d.get("nivel_atencion", 0)), 0, 5), {"mon": _mote(jugador)}))
	_caja_texto.limpiar()
	await bajar_telon()
	_redibujar_cajas()
	await esperar(20.0)
	await subir_telon()


func _caja_en_orden(i: int, d: Dictionary) -> CajaConcursante:
	var orden: Array = d.get("orden", motor.estado.orden)
	return _cajas[clampi(int(orden[i]), 0, 3)]


## Task_ResetForNextRound: cajas en el nuevo orden con estrellas, iconos y deslizador.
func _redibujar_cajas() -> void:
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var c: ConcursanteConcurso = motor.concursante(i)
		var caja: CajaConcursante = caja_de(i)
		caja.configurar(c)
		caja.corazones = 0
		caja.fijar_estrellas(c.condicion)
		caja.fijar_icono(motor.icono_estado(i))
		caja.mostrar_siguiente_turno(0, 0)
		caja.fijar_deslizador(c.puntos_totales)
		caja.fijar_atencion(c.atencion_juez)


func _actualizar_atencion() -> void:
	for i in EstadoConcurso.NUM_CONCURSANTES:
		caja_de(i).fijar_atencion(motor.concursante(i).atencion_juez)


## Caja del concursante `i` (la de su posición en la apelación en curso).
func caja_de(i: int) -> CajaConcursante:
	return _cajas[clampi(motor.estado.orden[i], 0, 3)]


# === Pokémon y animaciones ===

func _entrar_pokemon(i: int) -> void:
	var c: ConcursanteConcurso = motor.concursante(i)
	_pokemon.texture = PokemonSpriteManager.cargar_sprite_espalda(c.especie, c.shiny)
	_pokemon.material = _material_pokemon
	_pokemon.flip_h = c.especie != ESPECIE_SIN_REFLEJO
	_pokemon.position = POSICION_POKEMON + _desplazamiento_especie(c.especie) + Vector2(ENTRADA_POKEMON, 0)
	_pokemon.visible = true
	caja_de(i).parpadear()
	# Entra desde la derecha a 2 px por frame y espera 31 frames (contest.c:1594-1618).
	var destino: float = POSICION_POKEMON.x + _desplazamiento_especie(c.especie).x
	while _pokemon.position.x > destino:
		_pokemon.position.x = maxf(_pokemon.position.x - 2.0, destino)
		await esperar(1.0)
	await esperar(31.0)


func _salir_pokemon() -> void:
	if not _pokemon.visible:
		return
	# Sale hacia la izquierda a 6 px por frame.
	var limite: float = -64.0
	while _pokemon.position.x > limite:
		_pokemon.position.x -= 6.0
		await esperar(1.0)
	_pokemon.visible = false


func _desplazamiento_especie(especie: String) -> Vector2:
	var offset: Vector2 = Vector2.ZERO
	var posiciones: Dictionary = _posiciones_batalla()
	if posiciones.has(especie):
		var p: Variant = posiciones[especie].get("player_offset", {})
		if p is Dictionary:
			offset = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	return offset


static var _cache_posiciones: Dictionary = {}

static func _posiciones_batalla() -> Dictionary:
	if _cache_posiciones.is_empty():
		var archivo := FileAccess.open("res://escenas/batalla/battle_positions.json", FileAccess.READ)
		if archivo != null:
			var datos_json: Variant = JSON.parse_string(archivo.get_as_text())
			if datos_json is Dictionary:
				_cache_posiciones = datos_json
	return _cache_posiciones


## CreateInvisibleBattleTargetSprite: el objetivo existe para las coordenadas, pero sin
## imagen. La textura transparente evita que se vean las copias que hacen algunas escenas.
func _preparar_objetivo_invisible() -> void:
	var sprite: Sprite2D = _slot_objetivo.sprite_pokemon
	sprite.texture = ImageTexture.create_from_image(Image.create_empty(LADO_SPRITE, LADO_SPRITE, false, Image.FORMAT_RGBA8))
	sprite.position = CENTRO_OBJETIVO - Vector2(LADO_SPRITE, LADO_SPRITE) / 2.0
	sprite.visible = false


## Estados 7-9 de Task_DoAppeals: DoMoveAnim con la misma tabla que la batalla. Sin esperas
## (escala_tiempo = 0) no se reproduce: las escenas nativas van en tiempo real.
func _animar_movimiento(i: int, movimiento: int, objetivo: int = -1) -> void:
	if escala_tiempo <= 0.0:
		return
	var mov: int = movimiento if movimiento > 0 and movimiento < NUM_MOVIMIENTOS else MOVIMIENTO_POR_DEFECTO
	if mov in MOVIMIENTOS_DOS_PASADAS:
		await _reproducir_escena_nativa(mov, 0, objetivo)
		await esperar(PAUSA_ENTRE_PASADAS)
		await _reproducir_escena_nativa(mov, 1, objetivo)
	else:
		await _reproducir_escena_nativa(mov, _turno_animacion(i, mov), objetivo)
	_aplicar_imagen_final(mov, objetivo)


## La imagen de Transformación y el muñeco de Sustituto se quedan hasta que el Pokémon sale
## (la VRAM no se restaura; _entrar_pokemon carga la del siguiente).
func _aplicar_imagen_final(mov: int, objetivo: int) -> void:
	if mov == MOV_SUSTITUTO:
		_pokemon.texture = EfectoEspecialNativo.TEXTURA_SUSTITUTO_ESPALDA
		_pokemon.position = POSICION_POKEMON
	elif mov == MOV_TRANSFORMACION and objetivo >= 0:
		var c: ConcursanteConcurso = motor.concursante(objetivo)
		_pokemon.texture = PokemonSpriteManager.cargar_sprite_espalda(c.especie, c.shiny)
		_pokemon.flip_h = c.especie != ESPECIE_SIN_REFLEJO
		_pokemon.position = POSICION_POKEMON + _desplazamiento_especie(c.especie)
		var blanco: ShaderMaterial = ShaderMaterial.new()
		blanco.shader = EfectoMovimientoNativo.SHADER_TINTE
		blanco.set_shader_parameter(&"color_tinte", Color.WHITE)
		blanco.set_shader_parameter(&"cantidad", BLANCO_TRANSFORMACION)
		_pokemon.material = blanco


## SetMoveSpecificAnimData: Maldición anima como fantasma (turno 0) o no fantasma (turno 1).
func _turno_animacion(i: int, mov: int) -> int:
	if mov != MOV_MALDICION:
		return 0
	var especie: Dictionary = DatabaseManager.obtener_datos_pokemon(motor.concursante(i).especie)
	# tipo_2_id es NULL en las especies de un solo tipo.
	var fantasma: bool = especie.get("tipo_1_id") == TIPO_FANTASMA or especie.get("tipo_2_id") == TIPO_FANTASMA
	return 0 if fantasma else 1


func _reproducir_escena_nativa(mov: int, turno: int, objetivo: int = -1) -> void:
	var animacion: AnimacionEscenaNativa = AnimacionEscenaNativa.para_clave("ruby:move/%d" % mov)
	if animacion == null:
		return
	var terminada: Array[bool] = [false]
	animacion.finalizada.connect(func() -> void: terminada[0] = true, CONNECT_ONE_SHOT)
	animacion.reproducir(_contexto_animacion(mov, turno, objetivo), null)
	while not terminada[0]:
		await get_tree().process_frame


## SelectContestMoveBankTarget: los movimientos sobre el usuario animan contra el propio
## concursante; el resto, contra el objetivo invisible.
func _contexto_animacion(mov: int, turno: int, objetivo: int = -1) -> MoveAnimationContext:
	var a_si_mismo: bool = mov == MOV_REFUERZO or mov in AnimacionEscenaNativa.OBJETIVO_ATACANTE
	var contexto: MoveAnimationContext = MoveAnimationContext.nueva(self, _slot_atacante,
		_slot_atacante if a_si_mismo else _slot_objetivo)
	contexto.source_move_turn = turno
	# SetMoveSpecificAnimData: Retroceso con amistad máxima y Frustración con la mínima.
	if mov == MOV_RETROCESO:
		contexto.source_counter_inputs["source_friendship"] = 255
	elif mov == MOV_FRUSTRACION:
		contexto.source_counter_inputs["source_friendship"] = 0
	var centro: Vector2 = _pokemon.position + _pokemon.get_rect().get_center()
	contexto.geometria_concurso = {
		"centro_atacante": centro,
		"base_atacante": BASE_ATACANTE,
		"centro_defensor": centro if a_si_mismo else CENTRO_OBJETIVO,
		"base_defensor": BASE_ATACANTE if a_si_mismo else CENTRO_OBJETIVO,
	}
	# SetMoveSpecificAnimData: Transformación e Imitación usan la especie de contestantAnimTarget.
	if objetivo >= 0 and mov in [MOV_TRANSFORMACION, MOV_IMITACION]:
		contexto.geometria_concurso["datos"] = {"especie_defensor": motor.concursante(objetivo).especie}
	return contexto


# === Telón ===

func bajar_telon() -> void:
	TiempoConcurso.sonar(self, "SE_CONTEST_CURTAIN_FALL")
	while _telon.position.y < 0.0:
		_telon.position.y = minf(_telon.position.y + TELON_PIXELES_POR_FRAME, 0.0)
		await esperar(1.0)


func subir_telon() -> void:
	TiempoConcurso.sonar(self, "SE_CONTEST_CURTAIN_RISE")
	while _telon.position.y > -ALTO_PANTALLA:
		_telon.position.y = maxf(_telon.position.y - TELON_PIXELES_POR_FRAME, -ALTO_PANTALLA)
		await esperar(1.0)


# === Textos ===

## Escribe el mensaje y deja `pausa` frames de lectura ({PAUSE 60} de Rubí).
func mostrar_texto(texto: String, pausa: float = 60.0) -> void:
	registro_textos.append(texto)
	_caja_texto.descartar_lectura_pendiente()
	await _caja_texto.mostrar_texto(texto, escala_tiempo <= 0.0)
	_caja_texto.descartar_lectura_pendiente()
	if pausa > 0.0:
		await esperar(pausa)


func _texto_cadena(cadena: int, i: int, actor: int) -> String:
	var nombre: Variant = EfectosConcurso.Cadena.find_key(cadena)
	if nombre == null or cadena == EfectosConcurso.Cadena.NINGUNA:
		return ""
	return _t(PREFIJO_CADENA + str(nombre), {"mon": _mote(i), "otro": _mote(actor)})


func _t(clave: String, valores: Dictionary) -> String:
	var texto: String = tr(clave)
	for k in valores:
		texto = texto.replace("{%s}" % k, str(valores[k]))
	return texto


func _mote(i: int) -> String:
	return motor.concursante(i).mote if i >= 0 else ""


func _nombre_mov(movimiento: int) -> String:
	return datos.nombre_movimiento(movimiento)


func esperar(frames: float) -> void:
	await TiempoConcurso.esperar(self, frames, escala_tiempo)
