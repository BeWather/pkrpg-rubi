extends RefCounted
class_name StatusEffectResolver
## Cambio SDD `2026-09-14-move-effect-resolver`: lógica de aplicación de
## movimientos de estado, extraída de `batalla.gd` (los seis handlers
## nombrados, la base común de protección/aguante, el chequeo de inmunidad
## por tipo) y de `move_resolver.gd` (el registro de handlers con nombre y su
## búsqueda por clave), sin cambiar su comportamiento (ver design.md).
##
## Todas las funciones son estáticas y nunca llaman de vuelta a `batalla.gd`,
## `BattleTurnController` ni código de presentación (`BattleSlot`,
## `_actualizar_estado_visual_pokemon`) — Decisión D4. Los `PokemonEnCombate`
## ya resueltos y el hecho de turno `es_ultimo_en_actuar` llegan como
## parámetros explícitos, resueltos por el llamador (Decisión D3). Cuando un
## handler cambia un estado persistente que necesita refrescar el ícono de
## estado en pantalla, deja el `BasePokemon` correspondiente en
## `ResultadoEstado.pokemon_a_refrescar_visual` en vez de llamar a
## `_actualizar_estado_visual_pokemon()` directamente (Decisión D2) — si un
## futuro handler nuevo cambia `.estado` y olvida fijar este campo, el ícono
## de estado en pantalla queda desactualizado (riesgo de bajo impacto, ver
## design.md Risks).
##
## `resolver()` es el único punto de entrada: primero prueba un handler con
## nombre vía `STATUS_EFFECT_HANDLERS`, y si no hay uno registrado, cae a la
## tabla Gen 3 de cambios de característica (`CambioEstadisticaGen3`).
##
## Etapa 2 (cutover): `battle_turn_controller.gd` llama a `resolver()` y a
## `obtener_definicion_handler_movimiento()` en el único punto de uso en
## vivo; las copias originales en `batalla.gd`/`move_resolver.gd` ya fueron
## eliminadas.

const STATUS_EFFECT_HANDLERS := {
	"PROTECT": {
		"handler": Callable(StatusEffectResolver, "_handler_movimiento_proteger"),
		"summary": "Activa protección del usuario durante el turno",
		"target_self": true
	},
	"DETECT": {
		"handler": Callable(StatusEffectResolver, "_handler_movimiento_detectar"),
		"summary": "Activa protección del usuario durante el turno",
		"target_self": true
	},
	"ENDURE": {
		"handler": Callable(StatusEffectResolver, "_handler_movimiento_aguante"),
		"summary": "Impide que el usuario baje de 1 PS durante el turno",
		"target_self": true
	},
	"YAWN": {
		"handler": Callable(StatusEffectResolver, "_handler_movimiento_bostezo"),
		"summary": "Hace que el objetivo se duerma al final del siguiente turno",
		"target_self": false
	},
	"THUNDER-WAVE": {
		"handler": Callable(StatusEffectResolver, "_handler_movimiento_onda_trueno"),
		"summary": "Paraliza al objetivo",
		"target_self": false
	},
	"THUNDERWAVE": {
		"handler": Callable(StatusEffectResolver, "_handler_movimiento_onda_trueno"),
		"summary": "Paraliza al objetivo",
		"target_self": false
	},
	"TOXIC": {
		"handler": Callable(StatusEffectResolver, "_handler_movimiento_toxico"),
		"summary": "Envenena gravemente al objetivo",
		"target_self": false
	}
}

## Punto de entrada único: busca un handler con nombre para el movimiento y,
## si existe, lo invoca; si no, lo resuelve como cambio de característica de
## la tabla Gen 3.
static func resolver(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate, es_ultimo_en_actuar: bool) -> ResultadoEstado:
	if BattleSubstituteRules.blocks_status(movimiento,atacante,defensor,combatiente_defensor):
		var blocked:=ResultadoEstado.new();blocked.mensaje="¡Pero falló!";return blocked
	var definicion := obtener_definicion_handler_movimiento(movimiento.get_nombre_interno())
	if not definicion.is_empty():
		var handler: Callable = definicion.get("handler")
		if handler.is_valid():
			return handler.call(movimiento, atacante, defensor, combatiente_atacante, combatiente_defensor, es_ultimo_en_actuar)

	var resultado := CambioEstadisticaGen3.resolver(movimiento, atacante, defensor, combatiente_atacante, combatiente_defensor)
	if resultado.mensaje.is_empty():
		# Movimientos de estado por su efecto del decomp (dormir, envenenar,
		# paralizar, quemar, confundir...): los nombres de la BD están en español.
		resultado = _resolver_por_efecto(movimiento, atacante, defensor, combatiente_atacante, combatiente_defensor)
	if resultado.mensaje.is_empty():
		resultado.mensaje = "El efecto de %s aún no está implementado." % movimiento.nombre
	return resultado


## Estado que deja cada movimiento de estado puro (`Movimientos.efecto`).
const ESTADO_POR_EFECTO := {
	"EFFECT_SLEEP": 5,
	"EFFECT_POISON": 1,
	"EFFECT_TOXIC": 1,
	"EFFECT_PARALYZE": 4,
	"EFFECT_WILL_O_WISP": 3,
}
const EFECTOS_CONFUSION := ["EFFECT_TEETER_DANCE", "EFFECT_CONFUSE", "EFFECT_SWAGGER", "EFFECT_FLATTER"]


## Resuelve un movimiento de estado según su efecto. Devuelve un
## `ResultadoEstado` vacío si el efecto no está soportado.
static func _resolver_por_efecto(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	var efecto := EfectosGolpe.efecto_de(movimiento)
	if efecto=="EFFECT_FOCUS_ENERGY":return preload("res://scripts/battle/focus_energy_rules.gd").produce(combatiente_atacante)
	if efecto=="EFFECT_YAWN":return _handler_movimiento_bostezo(movimiento,atacante,defensor,combatiente_atacante,combatiente_defensor,false)
	if efecto == "EFFECT_MEAN_LOOK" and movimiento.get_nombre_interno() in ["TELARANA","SPIDER_WEB","MALDEOJO","MEAN_LOOK","BLOQUEO","BLOCK"]:
		var id: int=169 if movimiento.get_nombre_interno() in ["TELARANA","SPIDER_WEB"] else 212 if movimiento.get_nombre_interno() in ["MALDEOJO","MEAN_LOOK"] else 335
		resultado.aplicado=preload("res://scripts/battle/escape_prevention_rules.gd").apply(combatiente_atacante,combatiente_defensor,id)
		resultado.mensaje="¡%s no puede escapar!"%defensor.get_nombre_combate() if resultado.aplicado else "¡Pero falló!"
		return resultado
	if efecto=="EFFECT_ATTRACT":
		if combatiente_defensor!=null and combatiente_defensor.semi_invulnerable.is_empty() and atacante.estad_ps_actual>0 and defensor.estad_ps_actual>0:
			resultado.aplicado=HabilidadesCombate.apply_infatuation(defensor,atacante,combatiente_defensor)
		resultado.mensaje="¡%s se enamoró de %s!"%[defensor.get_nombre_combate(),atacante.get_nombre_combate()] if resultado.aplicado else "¡Pero falló!"
		return resultado
	if efecto == "EFFECT_SPLASH":
		resultado.presentation_requested = true
		resultado.mensaje = "¡Pero no tuvo ningún efecto!"
		return resultado
	if ESTADO_POR_EFECTO.has(efecto):
		return _aplicar_estado_de_movimiento(movimiento, atacante, defensor, combatiente_defensor, int(ESTADO_POR_EFECTO[efecto]), efecto == "EFFECT_TOXIC")
	if EFECTOS_CONFUSION.has(efecto):
		return _aplicar_confusion_de_movimiento(efecto, atacante, defensor, combatiente_defensor)
	return resultado


static func _aplicar_estado_de_movimiento(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, combatiente_defensor: PokemonEnCombate, estado: int, grave: bool) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	if combatiente_defensor == null or defensor.estad_ps_actual <= 0 or defensor.estado != Singleton.ProblemaEstado.NORMAL:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	# Solo ONDA TRUENO (eléctrico) consulta la tabla de tipos; el resto de
	# movimientos de estado la ignoran en Gen 3 (HIPNOSIS afecta a SINIESTRO).
	var inmune_electrico := estado == HabilidadesCombate.ESTADO_PARALIZADO and movimiento.get_tipo() == "ELECTRICO" \
			and MoveResolver.calc_efectividad(movimiento, defensor) == 0.0
	if inmune_electrico or HabilidadesCombate.inmune_por_tipo(defensor, estado):
		resultado.mensaje = "No afecta a\n%s..." % defensor.get_nombre_combate()
		return resultado
	var bloqueo := HabilidadesCombate.mensaje_impide_estado(defensor, estado)
	if not bloqueo.is_empty():
		resultado.mensaje = bloqueo
		return resultado
	defensor.estado = estado
	var nombre := defensor.get_nombre_combate()
	match estado:
		HabilidadesCombate.ESTADO_DORMIDO:
			combatiente_defensor.iniciar_sueno()
			resultado.mensaje = "¡%s se quedó dormido!" % nombre
		HabilidadesCombate.ESTADO_ENVENENADO:
			if grave:
				combatiente_defensor.envenenamiento_grave = true
				combatiente_defensor.contador_veneno_grave = 1
				resultado.mensaje = "¡%s fue gravemente envenenado!" % nombre
			else:
				resultado.mensaje = "¡%s\nfue envenenado!" % nombre
		HabilidadesCombate.ESTADO_PARALIZADO:
			resultado.mensaje = "¡%s quedó paralizado!" % nombre
		HabilidadesCombate.ESTADO_QUEMADO:
			resultado.mensaje = "¡%s se ha quemado!" % nombre
	resultado.pokemon_a_refrescar_visual = defensor
	resultado.aplicado = true
	_agregar_sincronia(resultado, defensor, atacante, estado)
	return resultado


## Supersónico, Rayo Confuso, Beso Dulce, Contoneo (confunde y sube 2 el ATAQUE
## del objetivo) y Camelo (confunde y sube 1 el AT. ESP).
static func _aplicar_confusion_de_movimiento(efecto: String, atacante: BasePokemon, defensor: BasePokemon, combatiente_defensor: PokemonEnCombate) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	if combatiente_defensor == null or defensor.estad_ps_actual <= 0:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	var mensajes := PackedStringArray()
	if efecto == "EFFECT_SWAGGER" or efecto == "EFFECT_FLATTER":
		var stat := "ataque" if efecto == "EFFECT_SWAGGER" else "ataque_especial"
		var niveles := 2 if efecto == "EFFECT_SWAGGER" else 1
		for accion in EfectosGolpe.cambiar_estadistica(defensor, combatiente_defensor, stat, niveles, false):
			mensajes.append(accion.texto)
			resultado.pokemon_cambio_estadistica = defensor
			resultado.cambio_estadistica_sube = true
			resultado.source_stat_animation=accion.source_stat_animation
			resultado.aplicado = true
	if combatiente_defensor.esta_confuso:
		mensajes.append("¡%s ya\nestá confuso!" % defensor.get_nombre_combate())
	else:
		var acciones := EfectosGolpe.confundir(defensor, combatiente_defensor, Callable(), false)
		for accion in acciones:
			if not accion.source_status_key.is_empty():
				resultado.estado_animado_clave = accion.source_status_key
				resultado.estado_animado_pokemon = accion.objetivo
				resultado.estado_animado_indice = mensajes.size()
			mensajes.append(accion.texto)
		if combatiente_defensor.esta_confuso:
			resultado.aplicado = true
	if mensajes.is_empty():
		resultado.mensaje = "¡Pero falló!"
		return resultado
	resultado.mensaje = mensajes[0]
	resultado.mensajes_adicionales = mensajes.slice(1)
	return resultado

## Busca en STATUS_EFFECT_HANDLERS probando la clave tal cual, con guiones y
## sin separadores (los nombres internos de movimiento varían en formato).
static func obtener_definicion_handler_movimiento(nombre_interno: String) -> Dictionary:
	var clave = nombre_interno.to_upper()
	if STATUS_EFFECT_HANDLERS.has(clave):
		return STATUS_EFFECT_HANDLERS[clave]
	var clave_con_guion = clave.replace("_", "-")
	if STATUS_EFFECT_HANDLERS.has(clave_con_guion):
		return STATUS_EFFECT_HANDLERS[clave_con_guion]
	var clave_sin_separadores = clave.replace("_", "").replace("-", "")
	if STATUS_EFFECT_HANDLERS.has(clave_sin_separadores):
		return STATUS_EFFECT_HANDLERS[clave_sin_separadores]
	return {}

static func _resolver_movimiento_proteccion_base(usuario: BasePokemon, combatiente: PokemonEnCombate, endurecer: bool, es_ultimo_en_actuar: bool) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	if combatiente == null:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	if es_ultimo_en_actuar:
		combatiente.reiniciar_cadena_proteccion()
		resultado.mensaje = "¡Pero falló!"
		return resultado
	if not combatiente.supera_chequeo_proteccion():
		combatiente.reiniciar_cadena_proteccion()
		resultado.mensaje = "¡Pero falló!"
		return resultado

	if endurecer:
		combatiente.aguante_este_turno = true
	else:
		combatiente.protegido_este_turno = true
	combatiente.registrar_proteccion_exitosa()

	resultado.aplicado = true
	if endurecer:
		resultado.mensaje = "¡%s se preparó para aguantar el golpe!" % usuario.get_nombre_combate()
	else:
		resultado.mensaje = "¡%s se protegió!" % usuario.get_nombre_combate()
	return resultado

static func _handler_movimiento_proteger(_movimiento: Movimiento, atacante: BasePokemon, _defensor: BasePokemon, combatiente_atacante: PokemonEnCombate, _combatiente_defensor: PokemonEnCombate, es_ultimo_en_actuar: bool) -> ResultadoEstado:
	return _resolver_movimiento_proteccion_base(atacante, combatiente_atacante, false, es_ultimo_en_actuar)

static func _handler_movimiento_detectar(_movimiento: Movimiento, atacante: BasePokemon, _defensor: BasePokemon, combatiente_atacante: PokemonEnCombate, _combatiente_defensor: PokemonEnCombate, es_ultimo_en_actuar: bool) -> ResultadoEstado:
	return _resolver_movimiento_proteccion_base(atacante, combatiente_atacante, false, es_ultimo_en_actuar)

static func _handler_movimiento_aguante(_movimiento: Movimiento, atacante: BasePokemon, _defensor: BasePokemon, combatiente_atacante: PokemonEnCombate, _combatiente_defensor: PokemonEnCombate, es_ultimo_en_actuar: bool) -> ResultadoEstado:
	return _resolver_movimiento_proteccion_base(atacante, combatiente_atacante, true, es_ultimo_en_actuar)

static func _handler_movimiento_bostezo(_movimiento: Movimiento, _atacante: BasePokemon, defensor: BasePokemon, _combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate, _es_ultimo_en_actuar: bool) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	if combatiente_defensor == null or defensor.estad_ps_actual <= 0:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	if defensor.estado != Singleton.ProblemaEstado.NORMAL or combatiente_defensor.turnos_bostezo > 0:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	# INSOMNIO / ESPÍRITU VITAL: no puede dormirse.
	var bloqueo_sueno := HabilidadesCombate.mensaje_impide_estado(defensor, HabilidadesCombate.ESTADO_DORMIDO)
	if not bloqueo_sueno.is_empty():
		resultado.mensaje = bloqueo_sueno
		return resultado
	combatiente_defensor.turnos_bostezo = 2
	resultado.aplicado = true
	resultado.mensaje = "¡%s empezó a bostezar!" % defensor.get_nombre_combate()
	return resultado

static func _handler_movimiento_onda_trueno(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, _combatiente_atacante: PokemonEnCombate, _combatiente_defensor: PokemonEnCombate, _es_ultimo_en_actuar: bool) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	if defensor.estad_ps_actual <= 0:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	if defensor.estado != Singleton.ProblemaEstado.NORMAL:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	if _movimiento_no_afecta_por_tipo(movimiento, defensor):
		resultado.mensaje = "No afecta a\n%s..." % defensor.get_nombre_combate()
		return resultado
	# FLEXIBILIDAD impide la parálisis.
	var bloqueo := HabilidadesCombate.mensaje_impide_estado(defensor, HabilidadesCombate.ESTADO_PARALIZADO)
	if not bloqueo.is_empty():
		resultado.mensaje = bloqueo
		return resultado
	defensor.estado = Singleton.ProblemaEstado.PARALIZADO
	resultado.pokemon_a_refrescar_visual = defensor
	resultado.aplicado = true
	resultado.mensaje = "¡%s quedó paralizado!" % defensor.get_nombre_combate()
	_agregar_sincronia(resultado, defensor, atacante, HabilidadesCombate.ESTADO_PARALIZADO)
	return resultado

static func _handler_movimiento_toxico(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, _combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate, _es_ultimo_en_actuar: bool) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	if combatiente_defensor == null or defensor.estad_ps_actual <= 0:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	if defensor.estado != Singleton.ProblemaEstado.NORMAL:
		resultado.mensaje = "¡Pero falló!"
		return resultado
	if _movimiento_no_afecta_por_tipo(movimiento, defensor):
		resultado.mensaje = "No afecta a\n%s..." % defensor.get_nombre_combate()
		return resultado
	if HabilidadesCombate.inmune_por_tipo(defensor, HabilidadesCombate.ESTADO_ENVENENADO):
		resultado.mensaje = "No afecta a\n%s..." % defensor.get_nombre_combate()
		return resultado
	# INMUNIDAD impide el envenenamiento.
	var bloqueo := HabilidadesCombate.mensaje_impide_estado(defensor, HabilidadesCombate.ESTADO_ENVENENADO)
	if not bloqueo.is_empty():
		resultado.mensaje = bloqueo
		return resultado
	defensor.estado = Singleton.ProblemaEstado.ENVENENADO
	combatiente_defensor.envenenamiento_grave = true
	combatiente_defensor.contador_veneno_grave = 1
	resultado.pokemon_a_refrescar_visual = defensor
	resultado.aplicado = true
	resultado.mensaje = "¡%s fue gravemente envenenado!" % defensor.get_nombre_combate()
	_agregar_sincronia(resultado, defensor, atacante, HabilidadesCombate.ESTADO_ENVENENADO)
	return resultado

## SINCRONÍA: el estado recibido pasa también al atacante.
static func _agregar_sincronia(resultado: ResultadoEstado, receptor: BasePokemon, causante: BasePokemon, estado: int) -> void:
	for accion in HabilidadesCombate.sincronizar(receptor, causante, estado):
		resultado.mensajes_adicionales.append(accion.texto)
		if accion.objetivo != null:
			resultado.pokemones_a_refrescar_extra.append(accion.objetivo)

static func _movimiento_no_afecta_por_tipo(movimiento: Movimiento, defensor: BasePokemon) -> bool:
	return MoveResolver.calc_efectividad(movimiento, defensor) == 0.0
