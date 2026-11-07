extends RefCounted
class_name BattleIntroController
## Etapa 1 del cambio SDD `2026-09-14-battle-architecture-split`: mueve el
## código de la intro (R1, `documentacion/20260914-refactor-intro-batalla.md`)
## a su propia clase, sin cambiar su comportamiento.
##
## No es todavía la separación final de `design.md` (Decisión D5): esta clase
## mantiene una referencia a `batalla.gd` (`_b`) para los nodos y el estado
## que las etapas siguientes (4: BattlePresentationController, 5:
## BattlePhaseController) todavía no extrajeron — `fase_input()`,
## `derrota_inmediata_sin_equipo()`, `mostrar_texto_batalla()`,
## `emitir_particulas_pokeball()`, `aplicar_offset()`, `iconos_rival` /
## `iconos_jugador` (compartidos con la actualización de estado a mitad de
## batalla), `tween` / `tween2` (scratch compartido con el resto de
## `batalla.gd`). Es el primer paso seguro del strangler-fig, no el final.

# Aparición desde la pokébola: color de silueta y offset inicial de cada lado.
const COLOR_SILUETA_RIVAL := Color("#ffb5f7")
const COLOR_SILUETA_JUGADOR := Color("#aaffff")
const OFFSET_APARICION_RIVAL := Vector2(-6, -6)
const OFFSET_APARICION_JUGADOR := Vector2(26, 64)

# Fila de iconos de pokéball de la intro.
const ESPACIADO_ICONOS_PB := 10.0
const RETARDO_ICONOS_PB := 0.12

# Fallbacks para los mensajes cuando faltan los datos del entrenador.
const CLASE_ENTRENADOR_FALLBACK := "ENTRENADOR"
const NOMBRE_ENTRENADOR_FALLBACK := "MENDA LERENDA"

# Deslizamiento de las plataformas (suelos) en cada intro, en segundos: la tira
# de entrada se sincroniza con él (AnimacionEntradaBatalla). En la salvaje lo
# fijan las pistas de btlSueloArriba/btlSueloAbajo de "1. Intro salvaje".
const INICIO_SUELO_ENTRENADOR := 0.6
const DURACION_SUELO_ENTRENADOR := 2.0
const DURACION_SUELO_SALVAJE := 2.1

# Intro doble (pokeruby, pokeball.c): las dos balls de un lado salen a la vez,
# pero la del 2.º Pokémon tarda 25 frames más en abrirse
# (SendOutMonAnimation_Delay). Cuando ambos terminan de aparecer entran sus
# cuadros de PS (StartHealthboxSlideIn); el 2.º del jugador espera 20 frames.
const RETARDO_SEGUNDA_BALL := 25.0 / 60.0
const RETARDO_CUADRO_PS_JUGADOR2 := 20.0 / 60.0
const DURACION_ENTRADA_CUADRO_PS := 0.4
# Tiempo desde que empieza la salida hasta que se abre la 1.ª ball: la del
# rival espera en su sitio (abrir_pokeball) y la del jugador vuela 0.8 s.
const APERTURA_BALL_RIVAL := 0.3
const APERTURA_BALL_JUGADOR := 0.8

## Tipado estático desde el cambio SDD `2026-09-15-battle-controller-backref-typing`:
## `batalla.gd` ahora declara `class_name BattleSceneController`, así que `_b`
## se tipa directamente contra esa clase. Esto habilita chequeo estático de
## miembros (un acceso a un campo/método inexistente o renombrado en
## `batalla.gd` pasa a ser un error de compilación, no un fallo silencioso en
## tiempo de ejecución) e inferencia `:=` para los campos propios de
## `batalla.gd` y para las llamadas a sus funciones con `-> Type` declarado.
## Antes de ese cambio, `_b` era intencionalmente sin tipo porque `batalla.gd`
## no tenía `class_name` propio y tipar `_b` como `Node2D` (su única clase
## nominal disponible) rompía la inferencia `:=` en accesos a campos propios
## de `batalla.gd` (p. ej. `_b.mensaje_inicio_entrenador.replace(...)`) — ver
## `openspec/changes/2026-09-15-battle-controller-backref-typing/design.md`
## para la investigación empírica de esa causa y la solución.
var _b: BattleSceneController  # batalla.gd — composition root (ver nota de cabecera)

func _init(batalla: BattleSceneController) -> void:
	_b = batalla

## Ejecuta la intro de la batalla (desde pantalla negra) y, salvo derrota
## inmediata sin equipo (tipo 6, plan 20260912), termina en fase_input().
func ejecutar() -> void:
	_b.fases.cambiar_fase(_b.INICIO)
	_b.fases.reiniciar_subfase_inicio()
	if _b.tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		await _intro_entrenador()
	else:
		await _intro_salvaje()

## Cortinas, frente, suelo, entrenador y jugador entran a pantalla. Al
## terminar: reto, salida del rival y del jugador (o derrota inmediata).
func _intro_entrenador() -> void:
	_preparar_intro_doble()
	if _b.tween: _b.tween.kill()
	_b.tween = _b.get_tree().create_tween()
	_b.tween.set_parallel(true)
	_b.tween.tween_property(_b.cortina_arriba, "position", _b.posiciones.get("cortina_arriba_final"), 0.8)
	_b.tween.tween_property(_b.cortina_abajo, "position", _b.posiciones.get("cortina_abajo_final"), 0.8)
	_b.tween.tween_property(_b.suelo_arriba, "position", _b.posiciones.get("suelo_arriba_final"), DURACION_SUELO_ENTRENADOR).set_delay(INICIO_SUELO_ENTRENADOR)
	_b.tween.tween_property(_b.suelo_abajo, "position", _b.posiciones.get("suelo_abajo_final"), DURACION_SUELO_ENTRENADOR).set_delay(INICIO_SUELO_ENTRENADOR)
	_b.tween.tween_property(_b.sprite_prota, "position", _b.posiciones.get("sprite_prota_final"), DURACION_SUELO_ENTRENADOR).set_delay(INICIO_SUELO_ENTRENADOR)
	_b.tween.tween_property(_b.sprite_rival, "position", _b.posiciones.get("sprite_rival_final"), DURACION_SUELO_ENTRENADOR).set_delay(INICIO_SUELO_ENTRENADOR)
	_iniciar_animacion_entrada(INICIO_SUELO_ENTRENADOR, DURACION_SUELO_ENTRENADOR)
	await _b.tween.finished

	await _intro_entrenador_reto()
	await _intro_entrenador_rival_sale()

	if _b.batalla_sin_pokemon:
		# Plan 20260912 (tipo 6): sin equipo no hay Pokémon que enviar; tras la
		# presentación del rival el jugador cae derrotado sin llegar a INPUT.
		await _b.derrota_inmediata_sin_equipo()
		return

	await _intro_entrenador_jugador_sale()

## Ganchos e iconos de pokéball entran mientras se muestra el mensaje de
## reto; espera a que el jugador confirme para continuar.
func _intro_entrenador_reto() -> void:
	_b.cortina_arriba.visible = false
	_b.cortina_abajo.visible = false
	_b.animacion_entrada.detener()
	_b.btlDecoFrente.visible = false
	_b.fases.avanzar_subfase_inicio()  # -> INI_ICONOS_POKEBALL

	_b.soporte_balls_arriba.position = _b.posiciones.get("gancho_arriba_inicial")
	_b.soporte_balls_abajo.position = _b.posiciones.get("gancho_abajo_inicial")
	_b.soporte_balls_arriba.visible = true
	_b.soporte_balls_abajo.visible = true
	_b.nodo_iconos_pokeball.visible = true
	_crear_iconos_pokeball()

	var presentacion := _presentacion_entrenador()
	var mensaje: String = _b.mensaje_inicio_entrenador.replace("{CLASE_ENTRENADOR}", presentacion.clase).replace("{NOMBRE_ENTRENADOR}", presentacion.nombre)

	if _b.tween: _b.tween.kill()
	_b.tween = _b.get_tree().create_tween()
	_b.tween.set_parallel(true)
	_b.tween.tween_property(_b.soporte_balls_abajo, "position", _b.posiciones.get("gancho_abajo_final"), 0.4).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_b.tween.parallel().tween_property(_b.soporte_balls_arriba, "position", _b.posiciones.get("gancho_arriba_final"), 0.4).set_delay(0.05).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_animar_entrada_fila_iconos(_b.tween, _b.iconos_jugador, _b.posiciones.get("icono_pb_jugador_final"), 1, 0.25)
	_animar_entrada_fila_iconos(_b.tween, _b.iconos_rival, _b.posiciones.get("icono_pb_rival_final"), -1, 0.5)

	# El mensaje de reto y la entrada de ganchos+iconos corren en paralelo;
	# se espera a que ambos terminen antes de pedir que el jugador continúe.
	await _b.mostrar_texto_batalla(mensaje, false)
	await _esperar_tween(_b.tween)
	await _b.esperar_confirmacion_texto()

## Mensaje "X envía a Y", salida de gancho/iconos del rival, pokébola y
## aparición de su Pokémon.
func _intro_entrenador_rival_sale() -> void:
	var presentacion := _presentacion_entrenador()
	var doble := _rival_envia_dos()
	var mensaje: String
	if doble:
		mensaje = _b.mensaje_rival_envia_doble.replace("{NOMBRE_POKEMON_2}", _b.pokemones_activos_enemigo[1].nombre)
		mensaje = mensaje.replace("{NOMBRE_POKEMON}", _b.pokemones_activos_enemigo[0].nombre)
	else:
		var mje_poke: String = _b.equipo_enemigo_pokemones[0].nombre if _b.equipo_enemigo_pokemones.size() > 0 else "¿?"
		mensaje = _b.mensaje_rival_envia.replace("{NOMBRE_POKEMON}", mje_poke)
	mensaje = mensaje.replace("{CLASE_ENTRENADOR}", presentacion.clase)
	mensaje = mensaje.replace("{NOMBRE_ENTRENADOR}", presentacion.nombre)
	await _b.mostrar_texto_batalla(mensaje, false)

	_b.fases.avanzar_subfase_inicio()  # -> INI_RIVAL_SALE
	_b.iluminacion_campo.modulate.a = 0
	_b.iluminacion_campo.visible = true

	if _b.tween: _b.tween.kill()
	_b.tween = _b.get_tree().create_tween()
	_b.tween.set_parallel(true)
	_b.tween.tween_property(_b.sprite_rival, "position", _b.posiciones.get("sprite_rival_salida"), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_b.tween.tween_property(_b.soporte_balls_arriba, "position", _b.posiciones.get("gancho_arriba_salida"), 0.5).set_delay(0.03)
	_b.tween.tween_property(_b.soporte_balls_arriba, "modulate:a", 0, 0.5).set_delay(0.03).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animar_salida_fila_iconos(_b.tween, _b.iconos_rival, _b.posiciones.get("icono_pb_rival_salida"), 0.03, 0.1, 0.13, Tween.EASE_IN)

	if doble:
		var slots_rival: Array[BattleSlot] = [_b.slot_rival, _b.slot_rival_secundario]
		await _enviar_pareja(slots_rival, _b.pokemones_activos_enemigo, false)
		return

	await enviar_pokemon_rival(_b.poke_enemigo)

## Envío del Pokémon del slot rival en combate simple. La ball ya está en su
## sitio (el entrenador no la lanza): se abre, suelta partículas, el cuadro de PS
## entra desde donde esté y el Pokémon aparece con silueta y destello. Lo usan la
## intro y los cambios a mitad de combate (`BattleResultController`), que antes
## dejan el sprite oculto y el cuadro fuera de pantalla.
func enviar_pokemon_rival(pokemon: BasePokemon) -> void:
	var slot: BattleSlot = _b.slot_rival
	var offset := _b.obtener_offset_pokemon(pokemon.nombre_interno, false)
	slot.configurar_pokeball(bola_de(pokemon))
	await slot.abrir_pokeball()

	_b.emitir_particulas_pokeball({
		"posicion": _b.posicion_campo_slot(slot) + offset,
		"tiempo_emision": 0.3,
		"intervalo_emision": 0.02
	})
	slot.cerrar_pokeball()  # Corre en paralelo a la aparición; no gatea el siguiente paso.

	# Ingreso de la caja de PS del rival
	var tween_ps := _b.get_tree().create_tween()
	slot.cuadro_ps.visible = true
	tween_ps.tween_property(slot.cuadro_ps, "position", _b.posicion_final_cuadro_ps(slot), DURACION_ENTRADA_CUADRO_PS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await _animar_aparicion_pokemon(
		slot, slot.shader_pokemon,
		slot.pokeball.position + OFFSET_APARICION_RIVAL + offset,
		COLOR_SILUETA_RIVAL,
		offset
	)
	await _b.esperar_destellos_variocolor(slot, pokemon)

## Mensaje "¡Adelante, X!", salida del sprite del jugador y sus ganchos/
## iconos, y envío de su primer Pokémon.
func _intro_entrenador_jugador_sale() -> void:
	var doble := _jugador_envia_dos()
	if doble:
		var mensaje: String = _b.mensaje_jugador_envia_doble.replace("{NOMBRE_POKEMON_2}", _nombre_mostrado(_b.pokemones_activos_jugador[1]))
		await _b.mostrar_texto_batalla(mensaje.replace("{NOMBRE_POKEMON}", _nombre_mostrado(_b.pokemones_activos_jugador[0])), false)
	else:
		await _b.mostrar_texto_batalla("¡Adelante, %s!" % _nombre_mostrado(_b.poke_jugador), false)

	_b.fases.avanzar_subfase_inicio()  # -> INI_JUGADOR_SALE
	var tween_jugador: Tween = _b.get_tree().create_tween()
	tween_jugador.set_parallel(true)
	_b.sprite_prota.frame = 1
	tween_jugador.tween_property(_b.sprite_prota, "frame", 3, 0.6)
	tween_jugador.tween_property(_b.sprite_prota, "position", _b.posiciones.get("sprite_prota_salida"), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_jugador.tween_property(_b.soporte_balls_abajo, "position", _b.posiciones.get("gancho_abajo_salida"), 0.5)
	tween_jugador.tween_property(_b.soporte_balls_abajo, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animar_salida_fila_iconos(tween_jugador, _b.iconos_jugador, _b.posiciones.get("icono_pb_jugador_salida"), 0.0, 0.08, 0.12, Tween.EASE_IN_OUT)

	await _b.get_tree().create_timer(0.4).timeout
	if doble:
		var slots_jugador: Array[BattleSlot] = [_b.slot_jugador, _b.slot_jugador_secundario]
		await _enviar_pareja(slots_jugador, _b.pokemones_activos_jugador, true)
		if not await _b.habilidades.al_iniciar_batalla():return
		_b.fase_input()
		return
	await _enviar_pokemon_jugador()

## Suelo, jugador y Pokémon salvaje entran a pantalla. La propia animación
## dispara el anuncio ("¡Un X salvaje!") en t=2.1 vía Call Method Track
## (`_msje_intro_poke_salvaje()` en batalla.gd); aquí se espera a que la
## animación y el tipeo del mensaje terminen antes de pedir confirmación al
## jugador, y solo entonces se envía su propio Pokémon (o se pasa directo a
## INPUT si no tiene equipo).
func _intro_salvaje() -> void:
	# El Pokémon salvaje entra ya visible, deslizándose junto al suelo.
	_b.slot_rival.fijar_posicion_relativa_al_suelo(_b.posicion_slot_rel_suelo(_b.slot_rival))
	_b.aplicar_offset_a_slot(_b.slot_rival, _b.poke_enemigo, false)
	_b.spr_pokemon_rival.visible = true

	# La coreografía visual (incluido el anuncio, disparado por la propia
	# animación) vive en batalla.tscn; aquí solo se prepara el estado
	# dinámico y se espera a que termine para continuar la lógica.
	_b.animacion_intro.play(&"1. Intro salvaje")
	_iniciar_animacion_entrada(0.0, DURACION_SUELO_SALVAJE)
	await _esperar_animation_player(_b.animacion_intro)
	# Un variocolor retrasa el anuncio hasta acabar sus destellos.
	await _b.esperar_destellos_variocolor(_b.slot_rival)

	# El mensaje puede seguir tipeándose tras el fin de la animación (arrancó
	# en t=2.1, la animación termina en t=2.8); se espera a que el tipeo
	# termine antes de pedir que el jugador confirme.
	await _esperar_texto_batalla()
	await _b.esperar_confirmacion_texto()

	if _b.batalla_sin_pokemon:
		_b.poke_ball_jugador.visible = false
		await _b.get_tree().create_timer(2.0).timeout
		_b.fase_input()
		return

	var nombre_jugador: String = _b.poke_jugador.mote if _b.poke_jugador.mote != "" else _b.poke_jugador.nombre
	await _b.mostrar_texto_batalla("¡Adelante, %s!" % nombre_jugador, false)
	await _enviar_pokemon_jugador(true)

## Lanza la pokébola del jugador y hace aparecer su Pokémon; termina en
## fase_input(). Paso final común a la intro de entrenador y la salvaje.
## usar_animation_player: la rama salvaje continúa la coreografía que ya
## dejó corriendo `intro_salvaje` (el prota terminó en `Campo/btlJugador`
## posición (45, 48)) reproduciendo `jugador_envia_pokeball` — esa animación
## mueve al prota y, vía Call Method Track a t=0.62, dispara `pkb_anim`
## ("cae_pokeball_y_sale_pokemon"): caída de la Pokéball, aparición del
## Pokémon (iluminación + silueta) y cuadro de PS, todo dentro de esa
## animación secundaria (ver `_iniciar_caida_pokeball`/
## `_iniciar_aparicion_pokemon_jugador` en batalla.gd). La rama entrenador ya
## dejó al prota en su posición de salida con un tween propio
## (`_intro_entrenador_jugador_sale()`), así que sigue usando el lanzamiento
## y la aparición por Tween/código para no reproducir el tramo del prota de
## esa animación por encima.
func _enviar_pokemon_jugador(usar_animation_player: bool = false) -> void:
	if usar_animation_player:
		_b.animacion_intro.play(&"2. Jugador lanza pokeball")
		await _esperar_animation_player(_b.animacion_intro)
		# `pkb_anim` arrancó a t=0.62 de la animación anterior y dura más que
		# ella (llega hasta después de que la Pokéball aterriza y el Pokémon
		# termina de aparecer), así que sigue corriendo en este punto. El color
		# de la silueta ya lo fija `_iniciar_aparicion_pokemon_jugador` en
		# batalla.gd (vía `configurar_aparicion`), disparado por el Call Method
		# Track de esa animación a t=0.8 — no hace falta repetirlo acá.
		await _esperar_animation_player(_b.pkb_anim)
		await _b.esperar_destellos_variocolor(_b.slot_jugador)
		if not await _b.habilidades.al_iniciar_batalla():return
		_b.fase_input()
		return

	await _b.slot_jugador.animar_lanzamiento_parabolico()

	# Corre en paralelo; no se espera su fin para mostrar el cuadro de PS
	# (igual que el original: el fade-in de PS no dependía de la aparición).
	_animar_aparicion_pokemon(
		_b.slot_jugador, _b.shader_pokemon_jugador,
		_b.poke_ball_jugador.position + OFFSET_APARICION_JUGADOR + _b.obtener_offset_pokemon(_b.poke_jugador.nombre_interno, true),
		COLOR_SILUETA_JUGADOR,
		_b.obtener_offset_pokemon(_b.poke_jugador.nombre_interno, true)
	)

	await _b.get_tree().create_timer(0.2).timeout  # Hacer coincidir con el fade in de la iluminación.

	_b.hud.cuadro_ps_jugador.visible = true
	if _b.tween: _b.tween.kill()
	_b.tween = _b.get_tree().create_tween()
	_b.tween.tween_property(_b.hud.cuadro_ps_jugador, "position", _b.posicion_final_cuadro_ps(_b.slot_jugador), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _b.tween.finished
	await _b.esperar_destellos_variocolor(_b.slot_jugador)

	if not await _b.habilidades.al_iniciar_batalla():return
	_b.fase_input()

## Arranca la animación de la tira de entrada según el terreno del combate
## (StartBattleIntroAnim). Sin tira cargada (btlDecoFrente oculto) no hace nada.
func _iniciar_animacion_entrada(inicio_suelo: float, duracion_suelo: float) -> void:
	if not _b.btlDecoFrente.visible or _b.animacion_entrada == null:
		return
	_b.animacion_entrada.iniciar(_b.btlDecoFrente, _b.obtener_terreno_batalla(),
			_b.posiciones.get("frente_inicial"), inicio_suelo, duracion_suelo)

## --- Intro doble ---

func _rival_envia_dos() -> bool:
	return _b.formato_batalla == Singleton.FormatoBatalla.DOBLE and _b.pokemones_activos_enemigo.size() > 1

func _jugador_envia_dos() -> bool:
	return _b.formato_batalla == Singleton.FormatoBatalla.DOBLE and _b.pokemones_activos_jugador.size() > 1

func _nombre_mostrado(pokemon: BasePokemon) -> String:
	return pokemon.mote if pokemon.mote != "" else pokemon.nombre

## En doble, `_configurar_slot_secundario` deja visibles el 2.º Pokémon y su
## cuadro de PS; en la intro tienen que salir de su ball como el 1.º, así que
## se ocultan y los cuadros se dejan fuera de pantalla, listos para entrar.
func _preparar_intro_doble() -> void:
	if _b.formato_batalla != Singleton.FormatoBatalla.DOBLE:
		return
	for slot: BattleSlot in [_b.slot_rival_secundario, _b.slot_jugador_secundario]:
		slot.sprite_pokemon.visible = false
	for slot: BattleSlot in [_b.slot_rival, _b.slot_rival_secundario, _b.slot_jugador, _b.slot_jugador_secundario]:
		slot.cuadro_ps.visible = false
		slot.cuadro_ps.position = posicion_inicial_cuadro_ps(slot)

## Fuera de pantalla, a la izquierda (rival) o a la derecha (jugador) de su sitio.
func posicion_inicial_cuadro_ps(slot: BattleSlot) -> Vector2:
	var desplazamiento: Vector2 = _b.posiciones.get("cuadro_ps_desplazamiento_entrada")
	return _b.posicion_final_cuadro_ps(slot) + (desplazamiento if slot.es_jugador else -desplazamiento)

## Envío simultáneo de los dos Pokémon de un lado (Task_StartSendOutAnim /
## sub_8035C44): ambas balls a la vez, la 2.ª se abre RETARDO_SEGUNDA_BALL más
## tarde, un único destello para las dos apariciones y, al terminar ambas,
## entrada de los dos cuadros de PS.
func _enviar_pareja(slots: Array[BattleSlot], pokemones: Array[BasePokemon], es_jugador: bool) -> void:
	slots[1].configurar_pokeball(bola_de(pokemones[1]))
	_destello_pareja(APERTURA_BALL_JUGADOR if es_jugador else APERTURA_BALL_RIVAL)
	_salida_desde_ball(slots[0], pokemones[0], es_jugador, 0.0)  # Corre en paralelo.
	# Mismo recorrido que la 1.ª pero con el retardo extra: siempre termina después.
	await _salida_desde_ball(slots[1], pokemones[1], es_jugador, RETARDO_SEGUNDA_BALL)
	await _entrar_cuadros_ps(slots)
	for i in slots.size():
		await _b.esperar_destellos_variocolor(slots[i], pokemones[i])

## Envío de un único Pokémon en DOBLE (switchinanim): ball, aparición con su
## destello y entrada de su cuadro de PS. El slot ya viene preparado.
func enviar_pokemon_slot(slot: BattleSlot, pokemon: BasePokemon, es_jugador: bool) -> void:
	slot.configurar_pokeball(bola_de(pokemon))
	_destello_pareja(APERTURA_BALL_JUGADOR if es_jugador else APERTURA_BALL_RIVAL, 0.0)
	await _salida_desde_ball(slot, pokemon, es_jugador, 0.0)
	var slots: Array[BattleSlot] = [slot]
	await _entrar_cuadros_ps(slots)

## Ball (lanzada por el jugador o ya en el sitio del rival) que se abre tras
## `retardo_apertura` extra, y aparición del Pokémon sin destello propio.
func _salida_desde_ball(slot: BattleSlot, pokemon: BasePokemon, es_jugador: bool, retardo_apertura: float) -> void:
	var offset := _b.obtener_offset_pokemon(pokemon.nombre_interno, es_jugador)
	if es_jugador:
		# Todas las balls salen del mismo punto que en simple (pokeball.c, (24,68)),
		# aunque en doble ambos slots del jugador están desplazados.
		var origen: Vector2 = _b.posiciones.get("pokemon_jugador_rel_suelo")
		await slot.animar_lanzamiento_parabolico(Callable(), slot.position - origen, retardo_apertura)
	else:
		await slot.abrir_pokeball(APERTURA_BALL_RIVAL + retardo_apertura)
	# Ambos lados: AnimateBallOpenParticles al abrirse (sub_8046C78).
	_b.emitir_particulas_pokeball({
		"posicion": slot.get_parent().position + slot.position + offset,
		"tiempo_emision": 0.3,
		"intervalo_emision": 0.02
	})
	if not es_jugador:
		slot.cerrar_pokeball()  # Corre en paralelo a la aparición.
	await _animar_aparicion_pokemon(
		slot, slot.shader_pokemon,
		slot.pokeball.position + (OFFSET_APARICION_JUGADOR if es_jugador else OFFSET_APARICION_RIVAL) + offset,
		COLOR_SILUETA_JUGADOR if es_jugador else COLOR_SILUETA_RIVAL,
		offset, false
	)

## Destello del campo compartido por las dos apariciones: se enciende al abrirse
## la 1.ª ball y se apaga cuando la 2.ª recupera su color (mismos tiempos que
## `BattleSlot.animar_aparicion`: 0.2 s de crecimiento + 0.1 s + 0.4 s).
func _destello_pareja(espera_apertura: float, retardo_segunda: float = RETARDO_SEGUNDA_BALL) -> void:
	var iluminacion: ColorRect = _b.iluminacion_campo
	iluminacion.modulate.a = 0
	iluminacion.visible = true
	await _b.get_tree().create_timer(espera_apertura).timeout
	var tween_destello := _b.get_tree().create_tween()
	tween_destello.tween_property(iluminacion, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_destello.tween_interval(retardo_segunda + 0.1)
	tween_destello.tween_property(iluminacion, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_destello.finished
	iluminacion.visible = false

## Entrada de los cuadros de PS de una pareja (StartHealthboxSlideIn): los del
## rival a la vez, el 2.º del jugador RETARDO_CUADRO_PS_JUGADOR2 después.
func _entrar_cuadros_ps(slots: Array[BattleSlot]) -> void:
	var tween_cuadros := _b.get_tree().create_tween()
	tween_cuadros.set_parallel(true)
	for i in slots.size():
		var cuadro: Node2D = slots[i].cuadro_ps
		cuadro.position = posicion_inicial_cuadro_ps(slots[i])
		cuadro.visible = true
		var retardo := RETARDO_CUADRO_PS_JUGADOR2 if slots[i].es_jugador and i == 1 else 0.0
		tween_cuadros.tween_property(cuadro, "position", _b.posicion_final_cuadro_ps(slots[i]), DURACION_ENTRADA_CUADRO_PS).set_delay(retardo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_cuadros.finished

static func bola_de(pokemon: BasePokemon) -> String:
	return pokemon.encuentro_bola if not pokemon.encuentro_bola.is_empty() else "POKEBALL"

## Espera a que un tween termine, evitando el punto muerto de esperar una
## señal 'finished' que ya se emitió si el tween ya se detuvo.
func _esperar_tween(t: Tween) -> void:
	if is_instance_valid(t) and t.is_running():
		await t.finished

## Espera a que un AnimationPlayer termine, evitando el punto muerto de
## esperar una señal 'animation_finished' que ya se emitió si ya se detuvo.
func _esperar_animation_player(ap: AnimationPlayer) -> void:
	if is_instance_valid(ap) and ap.is_playing():
		await ap.animation_finished

## Espera a que la caja de texto termine de tipear el mensaje en curso,
## evitando el punto muerto de esperar 'texto_completado' si ya se emitió
## (p. ej. cuando un Call Method Track de la animación disparó el mensaje y
## ya terminó de tipearse antes de llegar a este punto).
func _esperar_texto_batalla() -> void:
	var caja: CajaTextoBatalla = _b.presentacion.caja_texto
	if is_instance_valid(caja) and caja.esta_mostrando():
		await caja.texto_completado

## Clase y nombre del entrenador rival para los mensajes de la intro. Con los
## soldados AQUA/MAGMA se intercambian, como los marcadores en la ROM española.
func _presentacion_entrenador() -> Dictionary:
	var entrenador: DatosEntrenador = _b.datos_batalla.get("entrenador", null)
	var clase: String = entrenador.clase_entrenador if entrenador else CLASE_ENTRENADOR_FALLBACK
	var nombre: String = entrenador.nombre if entrenador else NOMBRE_ENTRENADOR_FALLBACK
	if DatosEntrenador.nombre_delante(clase):
		return {"clase": nombre, "nombre": clase}
	return {"clase": clase, "nombre": nombre}

## Entrada en abanico de una fila de iconos de pokéball.
## direccion: +1 el abanico crece hacia la derecha (jugador), -1 hacia la izquierda (rival).
func _animar_entrada_fila_iconos(tween_obj: Tween, iconos: Array[AnimatedSprite2D], pos_final: Vector2, direccion: int, delay_inicial: float) -> void:
	for i in range(iconos.size()):
		var destino: Vector2 = pos_final + Vector2(ESPACIADO_ICONOS_PB * i * direccion, 0)
		tween_obj.parallel().tween_property(iconos[i], "position", destino, 0.1).set_delay(delay_inicial + RETARDO_ICONOS_PB * i).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

## Salida escalonada de una fila de iconos hacia un mismo destino.
func _animar_salida_fila_iconos(tween_obj: Tween, iconos: Array[AnimatedSprite2D], pos_salida: Vector2, delay_inicial: float, paso_delay: float, duracion: float, easing: Tween.EaseType) -> void:
	for i in range(iconos.size()):
		tween_obj.tween_property(iconos[i], "position", pos_salida, duracion).set_delay(delay_inicial + paso_delay * i).set_trans(Tween.TRANS_SINE).set_ease(easing)

## Prueba del shader de batalla y partículas (modo de prueba ModoPrueba.SHADER).
func probar_shader() -> void:
	print("🎨 [BATALLA-PRUEBA] Probando shader de batalla...")
	_b.slot_rival.configurar_pokeball("GREATBALL")
	await _b.slot_rival.abrir_pokeball()
	var parametros_particulas = {
		"posicion": _b.aplicar_offset(_b.posiciones.get("pokemon_rival_final"), false),
		"tiempo_emision": 0.5,  # Emitir partículas durante 0.5 segundos
		"intervalo_emision": 0.02  # Una partícula cada 0.02 segundos
	}
	_b.emitir_particulas_pokeball(parametros_particulas)
	_b.slot_rival.cerrar_pokeball()

	await _animar_aparicion_pokemon(
		_b.slot_rival, _b.shader_pokemon_rival,
		_b.poke_ball_rival.position + OFFSET_APARICION_RIVAL + _b.obtener_offset_pokemon(_b.poke_enemigo.nombre_interno, false),
		COLOR_SILUETA_RIVAL,
		_b.obtener_offset_pokemon(_b.poke_enemigo.nombre_interno, false)
	)

	print("✅ [BATALLA-PRUEBA] Prueba de shader completada.")

## Aparición de un Pokémon desde su pokébola: silueta que se agranda con
## iluminación de campo. Común a rival y jugador (cambian color y offset inicial).
## con_destello: false cuando el destello del campo lo controla quien llama
## (intro doble, `_destello_pareja`).
func _animar_aparicion_pokemon(slot: BattleSlot, shader: PokemonBattleShaderController, pos_inicial: Vector2, color_silueta: Color, pos_final: Vector2, con_destello: bool = true) -> void:
	if con_destello:
		_b.iluminacion_campo.modulate.a = 0
		_b.iluminacion_campo.visible = true
	slot.configurar_aparicion(pos_inicial, color_silueta)
	await slot.animar_aparicion(pos_final, _b.iluminacion_campo if con_destello else null)
	_b.loggear("Animación de iluminación terminada")
	_apagar_silueta(shader)

## Apaga el efecto de silueta dejando el sprite en su color normal.
func _apagar_silueta(shader: PokemonBattleShaderController) -> void:
	if shader:
		shader.set_parametro("efecto_silueta", false)
		shader.set_parametro("intensidad_silueta", 1.0)  # Restablecer para futuros usos
		shader.set_parametro("progreso_silueta", 1.0)
		shader.debug_estado("Estado final - Pokémon en color normal")

## Crear y posicionar los íconos de Pokéballs de ambos equipos
func _crear_iconos_pokeball() -> void:
	# Limpiar íconos anteriores
	for child in _b.nodo_iconos_pokeball.get_children():
		child.queue_free()
	_b.iconos_rival.clear()
	_b.iconos_jugador.clear()

	var sprite: SpriteFrames = load("res://escenas/batalla/pokeball_icono.tres")
	if not sprite:
		print("❌ Error al cargar la textura de ícono de Pokéball")
		return

	_crear_fila_iconos(sprite, "IconoPokeballRival", _b.posiciones.get("icono_pb_rival_inicial"), _b.equipo_enemigo_pokemones, _b.iconos_rival)
	_crear_fila_iconos(sprite, "IconoPokeballJugador", _b.posiciones.get("icono_pb_jugador_inicial"), _b.equipo_jugador_pokemones, _b.iconos_jugador)

## Crea los 6 iconos de pokéball de un lado, con el frame según el estado de cada Pokémon.
func _crear_fila_iconos(sprite: SpriteFrames, prefijo: String, pos_inicial: Vector2, equipo: Array[BasePokemon], destino: Array[AnimatedSprite2D]) -> void:
	for i in range(6):
		var icon: AnimatedSprite2D = AnimatedSprite2D.new()
		icon.sprite_frames = sprite
		icon.name = "%s%d" % [prefijo, i + 1]
		icon.centered = false
		icon.position = pos_inicial
		_b.nodo_iconos_pokeball.add_child(icon)
		destino.append(icon)
		icon.frame = _frame_icono_pokeball(equipo[i] if i < equipo.size() else null)

## Frame del icono de pokéball según el estado del Pokémon.
func _frame_icono_pokeball(pokemon: BasePokemon) -> int:
	if pokemon == null:
		return 0  # Ícono vacío si no hay Pokémon
	if pokemon.estado == Singleton.ProblemaEstado.DEBILITADO:
		return 3  # Ícono de Pokéball con Pokémon debilitado
	if pokemon.estado == Singleton.ProblemaEstado.NORMAL or pokemon.estado == Singleton.ProblemaEstado.POKERUS:
		return 1  # Ícono de Pokéball con Pokémon saludable
	return 2  # Ícono de Pokéball con Pokémon con problema de estado
