extends RefCounted
class_name MoveAnimationRegistry
## Compatibility facade: custom override -> native Ruby adaptation -> fallback.
## The old specific scripts remain available, but production now uses data.

## Animaciones nativas (documentacion/piloto_animaciones_nativas.md): los
## movimientos con escena en `AnimacionEscenaNativa.ESCENAS` usan
## AnimationPlayer/Tween en vez de la VM, en modo seguro: solo con contexto de
## batalla, solo si su estado de migración está en la lista blanca y nunca en
## los casos que el adaptador nativo aún no cubre (ver `motivo_vm`), que vuelven
## a la VM. Se activa con las opciones de proyecto de abajo o en runtime.
const AJUSTE_ANIMACIONES_NATIVAS := "rubi4/batalla/animaciones_nativas"
## Estados de `estado_migracion.json` que pueden usar la escena nativa.
const AJUSTE_ESTADOS_NATIVOS := "rubi4/batalla/animaciones_nativas_estados"
const ESTADOS_NATIVOS_POR_DEFECTO: PackedStringArray = ["nativo_validado"]
const RUTA_ESTADO_MIGRACION := "res://documentacion/piloto_animaciones_nativas/estado_migracion.json"
## §33: lo que el registro lee en runtime (clave → estado), generado desde estado_migracion.json por
## herramientas/piloto_animaciones_nativas/estado_runtime.py. `documentacion/` está en filesystem/exclude_dirs y
## no entra en un ejecutable exportado; este recurso sí. En el editor se sigue leyendo estado_migracion.json (mismo
## comportamiento que antes) y se avisa si el recurso no coincide.
const RUTA_ESTADO_RUNTIME := "res://recursos/animaciones/estado_animaciones_nativas.json"
## §34: ya no hay movimientos «con variantes» que vayan por la VM: el adaptador nativo recibe del presentador los mismos
## datos que la VM (MoveAnimationContext: source_damage, source_power, source_move_turn y source_counter_inputs con
## amistad, contadores de Corte Furia y Desenrollar/Bola Hielo, clima, terreno y el objetivo forzado de Remolino/Rugido)
## y RamasNativas elige la rama del script del original (comparadas con la ROM en §24, §30 y §34).

static var usar_animaciones_nativas: bool = ProjectSettings.get_setting(AJUSTE_ANIMACIONES_NATIVAS, false)
static var estados_nativos: PackedStringArray = ProjectSettings.get_setting(AJUSTE_ESTADOS_NATIVOS, ESTADOS_NATIVOS_POR_DEFECTO)
static var _estado_por_clave: Dictionary = {}
static var _estados_cargados: bool = false
## §34: claves cuya escena vale en combate doble, con varios objetivos o contra un aliado (clave -> true).
static var _validas_en_dobles: Dictionary = {}
## §34: de las anteriores, las comparadas también contra un aliado (objetivo en el lado del atacante).
static var _validas_contra_aliado: Dictionary = {}


## Sin `contexto` devuelve siempre la animación de la VM (herramientas y tests
## que inspeccionan su `definition`). Con contexto de batalla, la nativa si
## `motivo_vm` no pone pegas.
## La rama de la VM legada (BattleAnimationSequenceRegistry.animation_for_key()) está obsoleta: en producción solo se
## alcanza por configuración. Ver scripts/battle/animations/sequence/README.md.
static func obtener_animacion(movimiento: Movimiento, contexto: MoveAnimationContext = null) -> MoveAnimation:
	var key := BattleAnimationSequenceRegistry.key_for_move(movimiento)
	if contexto != null and motivo_vm(key, contexto).is_empty():
		var nativa := AnimacionEscenaNativa.para_clave(key)
		if nativa != null:
			return nativa
	var status := movimiento != null and movimiento.get_categoria_dano_id() == 3
	return BattleAnimationSequenceRegistry.animation_for_key(key, status)


## Por qué `key` debe ir por la VM en este contexto ("" = puede ir nativa).
static func motivo_vm(key: String, contexto: MoveAnimationContext) -> String:
	if not usar_animaciones_nativas:
		return "desactivadas"
	if not AnimacionEscenaNativa.ESCENAS.has(key):
		return "sin escena nativa"
	var estado: String = estado_migracion(key)
	if not estados_nativos.has(estado):
		return "estado %s fuera de la lista blanca" % (estado if not estado.is_empty() else "desconocido")
	if not is_instance_valid(contexto.slot_atacante) or not is_instance_valid(contexto.slot_defensor):
		# §36: un battler sin slot (debilitado sin relevo, objetivo que ya no está) no va a la VM: el original no anima
		# un movimiento sin objetivo (attackcanceler: «no hay objetivo») ni las animaciones de batalla de un battler
		# ausente (las condiciones de fin de turno miran sus PS). La escena nativa emite impacto y fin en el acto
		# (AnimacionEscenaNativa.reproducir() sin sprite), igual que la VM sin actores, pero sin crear la VM.
		return ""
	# §34: combate doble, varios objetivos y objetivo aliado solo con las escenas validadas para dobles
	# (estado_migracion.json → "dobles"; ver valida_en_dobles()). El original anima una sola vez con el primer objetivo
	# (attackanimation salta los demás), que es el slot_defensor que pone el presentador.
	# §35: con el objetivo de animación del original (los MOVE_TARGET_USER que la batalla dirige al compañero animan
	# contra el propio atacante, AnimacionEscenaNativa.slot_objetivo()).
	var objetivo: BattleSlot = AnimacionEscenaNativa.slot_objetivo(key, contexto)
	var aliado: bool = objetivo != contexto.slot_atacante and objetivo.es_jugador == contexto.slot_atacante.es_jugador
	if aliado and not es_valida_contra_aliado(key):
		return "objetivo aliado"
	if es_valida_en_dobles(key):
		# §36: el compañero ausente u oculto ya no va a la VM: las escenas eligen la variante «_d<A><O>_sin<P>» con la
		# geometría que usa el original sin él (EfectoMovimientoNativo._animacion_doble()).
		return ""
	if contexto.target_slots.size() > 1:
		return "varios objetivos"
	var batalla: Variant = contexto.batalla
	if not is_instance_valid(batalla):
		return ""
	var formato: Variant = (batalla as Object).get("formato_batalla")
	if formato is int and formato == Singleton.FormatoBatalla.DOBLE:
		return "batalla doble"
	# §33: sustituto y transformación ya no van por la VM: AparienciaNativa aplica las guardas de los llamadores
	# (BattleMoveActionPresenter, BattleSubstituteActionCoordinator, BattleTransformPresentation) y las auxiliares
	# de sustituto (special/5, special/6, general/2, general/3) tienen escena nativa.
	return ""


## §34: si la escena de `key` vale en combate doble (lista "dobles" del recurso de runtime / estado_migracion.json:
## comparada con la ROM en combate doble o por familia. §35 añade variantes por pareja, compañeros y cuatro battlers;
## las excepciones y los requisitos de compañero visible están en los mismos datos de migración).
static func es_valida_en_dobles(key: String) -> bool:
	estado_migracion(key)
	return _validas_en_dobles.has(key)


## §35: objetivo en el lado del atacante validado por ROM o por familia (lista "dobles_aliado").
static func es_valida_contra_aliado(key: String) -> bool:
	estado_migracion(key)
	return _validas_contra_aliado.has(key)


## §32: claves de las animaciones que no son de movimiento (las que lanza BattleAnimationDirector.play_key()).
const PREFIJOS_AUXILIARES: Array[String] = ["ruby:general/", "ruby:status/", "ruby:special/"]


static func es_auxiliar(key: String) -> bool:
	for prefijo: String in PREFIJOS_AUXILIARES:
		if key.begins_with(prefijo):
			return true
	return false


## §32: por qué la animación auxiliar `key` debe ir por la VM en este contexto ("" = puede ir nativa). Misma
## política que los movimientos (opción de proyecto, lista blanca por estado, dobles, varios objetivos) sobre el MoveAnimationContext que se deriva de la batalla real (contexto_auxiliar()); sin
## batalla real (laboratorio, comparador, tests con campos de prueba) siempre la VM.
static func motivo_vm_auxiliar(key: String, contexto: BattleAnimationContext) -> String:
	if not es_auxiliar(key):
		return "no es una animación auxiliar"
	if not usar_animaciones_nativas:
		return "desactivadas"
	var legacy: MoveAnimationContext = contexto_auxiliar(contexto)
	if legacy == null:
		return "sin batalla"
	return motivo_vm(key, legacy)


## §32: MoveAnimationContext de la batalla real para un BattleAnimationContext de play_key(): la composition root
## (el antecesor del campo con _pokemon_de_slot y _obtener_combatiente), los slots del atacante y de los objetivos
## (los mismos actores que la VM) y la potencia y el daño de presentación. null si no hay batalla real.
static func contexto_auxiliar(contexto: BattleAnimationContext) -> MoveAnimationContext:
	if contexto == null or not is_instance_valid(contexto.field):
		return null
	var batalla: Node = contexto.field
	while batalla != null and not (batalla.has_method(&"_pokemon_de_slot") and batalla.has_method(&"_obtener_combatiente")):
		batalla = batalla.get_parent()
	if batalla == null:
		return null
	var atacante: BattleAnimationActor = contexto.actors.get(contexto.attacker_id) as BattleAnimationActor
	var slot_atacante: BattleSlot = atacante.slot if atacante != null else _slot_ocupado(contexto.field, contexto.attacker_id)
	var objetivos: Array[BattleSlot] = []
	for id: int in contexto.target_ids:
		var actor: BattleAnimationActor = contexto.actors.get(id) as BattleAnimationActor
		# §34: from_legacy() no crea actor para un battler oculto (Vuelo, Excavar, Buceo, Bote) sin proyección de la batalla,
		# p. ej. la víctima de Drenadoras: en el original la animación sale igual, con el sprite invisible; la nativa usa
		# el slot ocupado de esa posición (su sprite sigue oculto y la escena no cambia su visibilidad).
		var slot: BattleSlot = actor.slot if actor != null and is_instance_valid(actor.slot) else _slot_ocupado(contexto.field, id)
		if slot != null and slot not in objetivos:
			objetivos.append(slot)
	var legacy: MoveAnimationContext = MoveAnimationContext.nueva(batalla, slot_atacante,
		objetivos[0] if not objetivos.is_empty() else null)
	legacy.target_slots = objetivos
	legacy.action_id = contexto.action_id
	legacy.phase = contexto.phase
	legacy.source_power = contexto.source_power
	legacy.source_damage = contexto.source_damage
	return legacy


## §34: el BattleSlot de la posición `id` (BattleSlot.Posicion) bajo `campo` si está en uso (visible: tiene ocupante);
## null si no existe o está vacío.
static func _slot_ocupado(campo: Node, id: int) -> BattleSlot:
	if not is_instance_valid(campo):
		return null
	for nodo: Node in campo.find_children("*", "", true, false):
		var slot: BattleSlot = nodo as BattleSlot
		if slot != null and int(slot.posicion_batalla) == id and slot.visible and is_instance_valid(slot.sprite_pokemon):
			return slot
	return null


static func estado_migracion(key: String) -> String:
	if not _estados_cargados:
		_estados_cargados = true
		var runtime: Dictionary = estados_runtime()
		# En el editor manda estado_migracion.json (como antes de §33); en un ejecutable exportado no existe.
		var origen: Dictionary = estados_de_migracion() if OS.has_feature("editor") else {}
		var dobles_runtime: Dictionary = dobles_de_runtime()
		var dobles_origen: Dictionary = dobles_de_migracion() if OS.has_feature("editor") else {}
		var aliado_runtime: Dictionary = dobles_de_runtime(true)
		var aliado_origen: Dictionary = dobles_de_migracion(true) if OS.has_feature("editor") else {}
		if not origen.is_empty():
			_estado_por_clave = origen
			_validas_en_dobles = dobles_origen
			_validas_contra_aliado = aliado_origen
			if runtime != origen or dobles_runtime != dobles_origen or aliado_runtime != aliado_origen:
				push_warning("MoveAnimationRegistry: %s no coincide con %s; vuelve a lanzar herramientas/piloto_animaciones_nativas/estado_runtime.py (el juego exportado usaría el recurso)." % [RUTA_ESTADO_RUNTIME, RUTA_ESTADO_MIGRACION])
		elif not runtime.is_empty():
			_estado_por_clave = runtime
			_validas_en_dobles = dobles_runtime
			_validas_contra_aliado = aliado_runtime
		else:
			push_warning("MoveAnimationRegistry: no se pudo leer %s; las animaciones nativas quedan desactivadas." % RUTA_ESTADO_RUNTIME)
	return str(_estado_por_clave.get(key, ""))


## §33: clave → estado del recurso de runtime ({} si no está).
static func estados_runtime() -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_ESTADO_RUNTIME)) if FileAccess.file_exists(RUTA_ESTADO_RUNTIME) else null
	var resultado: Dictionary = {}
	if datos is Dictionary and (datos as Dictionary).get("estados") is Dictionary:
		for clave: Variant in (datos as Dictionary).estados:
			resultado[str(clave)] = str((datos as Dictionary).estados[clave])
	return resultado


## §34: claves válidas en dobles del recurso de runtime (clave -> true; {} si no está); con `aliado`, la lista de las
## comparadas también contra un aliado.
static func dobles_de_runtime(aliado: bool = false) -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_ESTADO_RUNTIME)) if FileAccess.file_exists(RUTA_ESTADO_RUNTIME) else null
	var campo: String = "dobles_aliado" if aliado else "dobles"
	var resultado: Dictionary = {}
	if datos is Dictionary and (datos as Dictionary).get(campo) is Array:
		for clave: Variant in (datos as Dictionary)[campo]:
			resultado[str(clave)] = true
	return resultado


## §34: claves con "dobles": {"estado": "nativo"} en estado_migracion.json (clave -> true); con `aliado`, solo las que
## llevan además "aliado": true.
static func dobles_de_migracion(aliado: bool = false) -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_ESTADO_MIGRACION)) if FileAccess.file_exists(RUTA_ESTADO_MIGRACION) else null
	var resultado: Dictionary = {}
	if datos is Dictionary:
		for entrada: Variant in (datos as Dictionary).get("movimientos", []) + (datos as Dictionary).get("auxiliares", []):
			if entrada is Dictionary and (entrada as Dictionary).get("dobles") is Dictionary and str(entrada.dobles.get("estado", "")) == "nativo":
				if not aliado or bool(entrada.dobles.get("aliado", false)):
					resultado[str(entrada.clave)] = true
	return resultado


## clave → estado de estado_migracion.json ({} si no está: fuera del editor no se exporta).
static func estados_de_migracion() -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_ESTADO_MIGRACION)) if FileAccess.file_exists(RUTA_ESTADO_MIGRACION) else null
	var resultado: Dictionary = {}
	if datos is Dictionary:
		# §32: "auxiliares" lleva las animaciones generales, de estado y especiales (mismos estados).
		for entrada: Variant in (datos as Dictionary).get("movimientos", []) + (datos as Dictionary).get("auxiliares", []):
			if entrada is Dictionary and (entrada as Dictionary).has("clave"):
				resultado[str(entrada.clave)] = str(entrada.get("estado", ""))
	return resultado
