extends RefCounted
class_name BattleHudController
## Etapa 2 (Sub-topic B1) del cambio SDD `2026-09-15-battle-flow-and-hud-controllers`:
## dueño de los nodos de HUD de batalla — los cuadros de PS
## (`cuadro_ps_jugador`/`cuadro_ps_rival`) y el timer cosmético de "wiggle"
## del cuadro de PS del jugador. Etapa 3 (Sub-topic B2, esta etapa) añade las
## utilidades genéricas de refresco de HUD (`_estadoE2S`,
## `_actualizar_estado_visual_pokemon`, `_obtener_slot_de_pokemon`,
## `_obtener_cuadro_ps_de_pokemon`) y el trigger del tween de daño
## (`animar_dano`). Etapa 4 añade la EXP/panel de subida de nivel. Ver
## design.md Decisiones D3/D4/D5.
##
## Etapa 4 (Sub-topic B3, cerrada): añadió `panel_subida_nivel` +
## `_crear_panel_subida_nivel()` y las funciones de render de EXP/subida de
## nivel (`iniciar_barra_experiencia`/`animar_barra_experiencia`/
## `reiniciar_porcentaje_barra_experiencia`, `actualizar_cuadro_ps_jugador_desde_snapshot`,
## `mostrar_panel_subida_nivel`/`panel_subida_nivel_esta_activo`/
## `avanzar_panel_subida_nivel`), per D2: `BattleResultController` sigue
## calculando el 100% de EXP/subida de nivel (mutación de `BasePokemon`
## incluida, cursores `exp_cursor`/`nivel_cursor` y el bucle en sí) y solo
## llama aquí con datos ya calculados. El shim de `_estadoE2S` en
## `batalla.gd` (nota de Etapa 3, ya retirada de este comentario) se eliminó
## en esta etapa: su único llamador (`_actualizar_cuadro_ps_jugador_desde_snapshot`,
## que sigue viviendo en `BattleResultController` como wrapper delgado hacia
## esta clase) ahora resuelve el estado vía `_estadoE2S` como método propio
## de esta misma clase.
##
## D3: no es una fachada nueva delante de `BattleSlot` — llama a la API que
## `BattleSlot` ya expone (`cuadro_ps`, `configurar_pokemon()`, etc.) para
## todo lo que es responsabilidad de un slot. Lo que sí posee es el estado
## que no tiene un hogar natural a nivel de slot: el timer de wiggle
## (cosmético de escena, no de un slot en particular) y, desde la Etapa 4,
## el panel de subida de nivel (una sola instancia para toda la batalla).
##
## D4 (Etapa 3): las utilidades genéricas de refresco por Pokémon
## (`_estadoE2S`, `_actualizar_estado_visual_pokemon`, `_obtener_slot_de_pokemon`,
## `_obtener_cuadro_ps_de_pokemon`) se mudan aquí junto con la propiedad de
## los nodos que operan, no se quedan repartidas.
##
## Resolución del riesgo de instancia suelta (`timer_cuadro_ps`; ver
## design.md Contexto/Riesgos y tasks.md Etapa 2.4): `BattleHudController`
## se instancia en `_ready()` (no inline como `fases`/`turno`), así que una
## instancia suelta de `batalla.gd` (`BatallaScript.new()`, nunca agregada
## al árbol de escena) nunca lo construye. Por eso `timer_cuadro_ps` (el
## objeto `Timer`) NO se mudó a esta clase — sigue siendo un campo
## inicializado inline en `batalla.gd`, exactamente igual que
## `timer_pkm_actual` (que este cambio no toca) — precisamente para no
## romper `test/batalla/batalla_bare_instance_test.gd` ni
## `test/batalla/handlers_estado_test.gd`, cuyo teardown llama a
## `b.timer_cuadro_ps.free()` sobre una instancia suelta sin `_ready()`.
## Lo que sí se mudó aquí es el *comportamiento* del wiggle:
## `_on_timer_cuadro_ps_timeout()` (que lee/escribe `cuadro_ps_jugador`,
## ahora propiedad de esta clase) y los wrappers
## `iniciar_timer_ps()`/`detener_timer_ps()`, que son el único punto desde
## el que el resto del código arranca/detiene el timer. `batalla.gd` sigue
## siendo dueño del objeto `Timer` en sí (lo construye inline, lo agrega al
## árbol y conecta su señal en `_configurar_timers()`/`_conectar_senales()`),
## pero ya no lo maneja directamente fuera de ese setup de bajo nivel.

var _b: BattleSceneController  # batalla.gd — composition root

var cuadro_ps_jugador: Node2D
var cuadro_ps_rival: Node2D
var panel_subida_nivel: CuadroSubirNivel

var _timer_cuadro_ps_cambio: bool = false


func _init(batalla: BattleSceneController) -> void:
	_b = batalla


## Llamado desde `batalla.gd::_ready()`, ya con `_b.slot_jugador`/`_b.slot_rival`
## listos (son `@onready`, asignados antes de que corra el cuerpo de `_ready()`).
func inicializar() -> void:
	cuadro_ps_jugador = _b.slot_jugador.cuadro_ps
	cuadro_ps_rival = _b.slot_rival.cuadro_ps


## --- Posicionamiento / visibilidad (antes en batalla.gd::_inicializar_escena()) ---

func posicionar_cuadros_ps_inicial() -> void:
	cuadro_ps_rival.position = _b.posiciones.get("cuadro_ps_rival_inicial")
	cuadro_ps_jugador.position = _b.posiciones.get("cuadro_ps_jugador_inicial")


func ocultar_cuadros_ps() -> void:
	cuadro_ps_rival.visible = false
	cuadro_ps_jugador.visible = false


## --- Posicionamiento / visibilidad (antes en batalla.gd::_configurar_batalla_sin_animaciones()) ---

func mostrar_cuadros_ps_sin_animaciones(batalla_sin_pokemon: bool) -> void:
	cuadro_ps_rival.visible = true
	cuadro_ps_jugador.visible = not batalla_sin_pokemon


func posicionar_cuadros_ps_final() -> void:
	cuadro_ps_rival.position = _b.posicion_final_cuadro_ps(_b.slot_rival)
	cuadro_ps_jugador.position = _b.posicion_final_cuadro_ps(_b.slot_jugador)


## --- Timer "wiggle" del cuadro de PS del jugador ---
## El objeto `Timer` sigue viviendo en `batalla.gd` (ver nota de cabecera);
## esta clase solo lo arranca/detiene y reacciona a su señal `timeout`.

func iniciar_timer_ps() -> void:
	_b.timer_cuadro_ps.start()


func detener_timer_ps() -> void:
	_b.timer_cuadro_ps.stop()


func _on_timer_cuadro_ps_timeout() -> void:
	_timer_cuadro_ps_cambio = !_timer_cuadro_ps_cambio
	if _timer_cuadro_ps_cambio:
		cuadro_ps_jugador.set_offset_y(1)
	else:
		cuadro_ps_jugador.set_offset_y(0)


## --- Utilidades genéricas de refresco por Pokémon (antes en batalla.gd, Etapa 3 / D4) ---

func _estadoE2S(estado: int) -> String:
	match estado:
		Singleton.ProblemaEstado.NORMAL: return "NORMAL"
		Singleton.ProblemaEstado.DEBILITADO: return "DEBILITADO"
		Singleton.ProblemaEstado.ENVENENADO: return "ENVENENADO"
		Singleton.ProblemaEstado.CONGELADO: return "CONGELADO"
		Singleton.ProblemaEstado.QUEMADO: return "QUEMADO"
		Singleton.ProblemaEstado.PARALIZADO: return "PARALIZADO"
		Singleton.ProblemaEstado.DORMIDO: return "DORMIDO"
		Singleton.ProblemaEstado.POKERUS: return "POKERUS"
	return "DESCONOCIDO"


func _obtener_slot_de_pokemon(pokemon: BasePokemon) -> BattleSlot:
	if pokemon == null:
		return null
	if pokemon == _b.poke_jugador:
		return _b.slot_jugador
	if pokemon == _b.poke_enemigo:
		return _b.slot_rival
	if _b.pokemones_activos_jugador.size() > 1 and pokemon == _b.pokemones_activos_jugador[1]:
		return _b.slot_jugador_secundario
	if _b.pokemones_activos_enemigo.size() > 1 and pokemon == _b.pokemones_activos_enemigo[1]:
		return _b.slot_rival_secundario
	return null


func _obtener_cuadro_ps_de_pokemon(pokemon: BasePokemon) -> Node:
	var slot := _obtener_slot_de_pokemon(pokemon)
	return slot.cuadro_ps if is_instance_valid(slot) else null


func _actualizar_estado_visual_pokemon(pokemon: BasePokemon) -> void:
	var slot := _obtener_slot_de_pokemon(pokemon)
	if is_instance_valid(slot):
		slot.actualizar_estado(_estadoE2S(pokemon.estado))


## --- Tween de daño de la barra de PS (antes inline en batalla.gd::_aplicar_danio_a_pokemon(), Etapa 3 / D5) ---
## Solo el trigger visual se mudó aquí; el cálculo de daño y el chequeo de
## `aguante` siguen en `batalla.gd::_aplicar_danio_a_pokemon()`, que llama a
## esta función una vez que ya calculó `{damage, endured}`. Sigue creando el
## tween "ad hoc" con `get_tree().create_tween()`, sin pasar por
## `BattleAnimationDirector` (D5 — no goal de esta etapa), sobre el mismo
## campo scratch compartido `_b.tween` que usaba el código original.
func animar_dano(cuadro_ps_objetivo: Node, ps_max: int, ps_actual: int) -> void:
	_b.tween = _b.get_tree().create_tween()
	cuadro_ps_objetivo.set_salud(ps_max, ps_actual, _b.tween)
	await _b.tween.finished


## --- Panel de subida de nivel (antes en batalla.gd, Etapa 4 / D3) ---
## Nodo de escena único (una instancia para toda la batalla, no por slot) —
## ver D3: no tiene hogar natural a nivel de `BattleSlot`.

func _crear_panel_subida_nivel() -> void:
	if is_instance_valid(panel_subida_nivel):
		return
	panel_subida_nivel = _b.CuadroSubirNivelScene.instantiate()
	panel_subida_nivel.name = "PanelSubidaNivel"
	panel_subida_nivel.visible = false
	panel_subida_nivel.z_index = 210
	_b.add_child(panel_subida_nivel)


## --- EXP / subida de nivel (antes en battle_result_controller.gd, Etapa 4 / D2) ---
## `BattleResultController` calcula el 100% de la ganancia de EXP y las
## subidas de nivel (`calcular_experiencia_ganada()`, snapshots de stats,
## mutación de `BasePokemon` incluida) y llama aquí solo con datos ya
## calculados; esta clase únicamente dispara el render sobre
## `cuadro_ps_jugador`/`panel_subida_nivel`. Las esperas de confirmación de
## texto (`_b.esperar_confirmacion_texto()`/`_b._mostrar_texto_y_esperar_confirmacion()`)
## siguen orquestadas por `BattleResultController`, territorio de
## `BattlePresentationController` sin cambios.

## Fija el estado inicial de la barra de EXP antes de animarla (el "desde"
## de un tramo de relleno).
func iniciar_barra_experiencia(exp_actual: int, exp_inicio_nivel: int, exp_siguiente_nivel: int) -> void:
	if is_instance_valid(cuadro_ps_jugador):
		cuadro_ps_jugador.set_experiencia(exp_actual, exp_inicio_nivel, exp_siguiente_nivel)


## Atenuación de SE_EXP respecto al resto de efectos: 70 % de amplitud
## (20·log10(0,7) ≈ -3,1 dB). Para otro porcentaje: linear_to_db(porcentaje / 100).
const VOLUMEN_SONIDO_EXPERIENCIA_DB: float = -3.1


## Anima la barra de EXP hasta `exp_destino` dentro de los límites de nivel dados.
## Suena SE_EXP mientras se llena y se corta al terminar el tramo
## (`PlaySE(SE_EXP)` / `m4aSongNumStop(SE_EXP)` en sub_802DA9C y sub_802DB6C).
func animar_barra_experiencia(exp_destino: int, exp_inicio_nivel: int, exp_siguiente_nivel: int) -> void:
	if is_instance_valid(cuadro_ps_jugador):
		var sonido: AudioStreamPlayer = _iniciar_sonido_experiencia()
		await cuadro_ps_jugador.animar_experiencia(exp_destino, exp_inicio_nivel, exp_siguiente_nivel, _b.DURACION_ANIMACION_EXP)
		if is_instance_valid(sonido):
			sonido.stop()
			sonido.queue_free()


## Reproductor propio (no el SFX compartido del mapa) para poder cortar el
## sonido en cuanto la barra termina. Cuelga de la batalla: si se libera a
## mitad del tramo, se lleva el sonido con ella.
func _iniciar_sonido_experiencia() -> AudioStreamPlayer:
	var anfitrion: Node = _anfitrion_sonido()
	if anfitrion == null or not anfitrion.is_inside_tree() or not Singleton.se.has("SE_EXP"):
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = Singleton.se["SE_EXP"]
	# El nivel de las opciones lo aplica el Singleton en el bus Master (el
	# reproductor usa ese bus); esto es solo la atenuación propia del sonido.
	reproductor.volume_db = VOLUMEN_SONIDO_EXPERIENCIA_DB
	anfitrion.add_child(reproductor)
	reproductor.play()
	return reproductor


## Nodo del que cuelga el reproductor (la batalla); separado para poder alojarlo
## en un nodo suelto en las pruebas, donde la escena real no entra al árbol.
func _anfitrion_sonido() -> Node:
	return _b


## Reinicia visualmente la barra de EXP a 0% (tras cada subida de nivel, para
## el siguiente tramo de relleno).
func reiniciar_porcentaje_barra_experiencia() -> void:
	if is_instance_valid(cuadro_ps_jugador):
		cuadro_ps_jugador.set_experiencia_porcentaje(0.0)


## Refresca `cuadro_ps_jugador` (nivel/estado/PS/EXP) desde un snapshot de
## stats ya calculado por `BattleResultController._snapshot_stats_pokemon()`.
## `_b.resultado._obtener_exp_inicio_nivel(...)` es una consulta de solo
## lectura a la tabla de crecimiento (no una mutación de `BasePokemon`) —
## sigue viviendo en `BattleResultController` por D2, esta clase solo la
## consulta para renderizar.
func actualizar_cuadro_ps_jugador_desde_snapshot(snapshot: Dictionary) -> void:
	if not is_instance_valid(cuadro_ps_jugador) or snapshot.is_empty():
		return
	cuadro_ps_jugador.set_nivel(int(snapshot.get("nivel", _b.poke_jugador.nivel)))
	cuadro_ps_jugador.set_estado(_estadoE2S(_b.poke_jugador.estado))
	cuadro_ps_jugador.set_salud_instantanea(int(snapshot.get("ps", _b.poke_jugador.estad_ps)), int(snapshot.get("ps_actual", _b.poke_jugador.estad_ps_actual)))
	cuadro_ps_jugador.set_experiencia(_b.poke_jugador.experiencia, _b.resultado._obtener_exp_inicio_nivel(_b.poke_jugador), _b.poke_jugador.exp_sig_nivel)


## Dispara `panel_subida_nivel.mostrar_subida()`. Devuelve `false` (sin
## disparar nada) si el panel no es válido — `BattleResultController` usa el
## valor de retorno para decidir si sigue con las esperas de confirmación,
## igual que el `is_instance_valid()` original.
func mostrar_panel_subida_nivel(stats_antes: Dictionary, stats_despues: Dictionary) -> bool:
	if not is_instance_valid(panel_subida_nivel):
		return false
	panel_subida_nivel.mostrar_subida(stats_antes, stats_despues)
	return true


func panel_subida_nivel_esta_activo() -> bool:
	return is_instance_valid(panel_subida_nivel) and panel_subida_nivel.esta_activo()


func avanzar_panel_subida_nivel() -> void:
	if is_instance_valid(panel_subida_nivel):
		panel_subida_nivel.avanzar_estado()
