extends RefCounted
class_name AprendizajeBatalla

## Aprender movimientos al subir de nivel en combate: `BattleScript_LevelUp` →
## `handlelearnnewmove` / `BattleScript_TryLearnMoveLoop` (battle_scripts_1.s) y
## `atk59_handlelearnnewmove`, `atk5A_yesnoboxlearnmove`, `atk5B_yesnoboxstoplearningmove`
## (battle_script_commands.c). Implementa la interfaz de DialogoAprendizaje con la caja
## de texto y el SÍ/NO del combate; la ficha para olvidar se abre con fundido sobre la
## batalla (ShowSelectMovePokemonSummaryScreen → ReshowBattleScreenAfterMenu).
##
## El combate usa directamente `BasePokemon.movimientos` (no hay copia tipo gBattleMons),
## así que `GiveMoveToBattleMon` / `SetBattleMonMoveSlot` sobre el combatiente activo
## quedan hechos al cambiar el movimiento del Pokémon del equipo, con PP completos.

## MUS_LEVEL_UP: `fanfare` de BattleScript_LevelUp y de BattleScript_LearnedNewMove.
const TEMA_FANFARRIA: String = "LEVEL_UP"
const SCN_FICHA_OLVIDAR: PackedScene = preload("res://UI/poke-info/ficha_olvidar_movimiento.tscn")
## Por encima de la caja de texto, los menús y el SÍ/NO (z 6) del combate.
const Z_FICHA_OLVIDAR: int = 7

var _b: BattleSceneController
var _fanfarria_sonando: bool = false


func _init(batalla: BattleSceneController) -> void:
	_b = batalla


## Movimientos del learnset de `nivel` para `pokemon` (uno de los que ganan EXP, esté o
## no en el campo). Los ya conocidos se saltan (0xFFFE).
func aprender(pokemon: BasePokemon, nivel: int, datos: Object = null) -> void:
	await DialogoAprendizaje.ejecutar(pokemon, self, datos, nivel)


## `fanfare MUS_LEVEL_UP`: suena mientras se lee el mensaje. Si aún suena la anterior
## (subida de nivel y movimiento aprendido seguidos), se espera a que termine para que
## Fanfarria no tome la música ya silenciada como volumen a restaurar.
func tocar_fanfarria() -> void:
	await esperar_fanfarria()
	var anfitrion := _anfitrion()
	if anfitrion == null or not anfitrion.is_inside_tree():
		return
	_fanfarria_sonando = true
	_reproducir_fanfarria()


## Espera a que acabe la fanfarria en curso, incluida la subida de la música. Lo usan
## la siguiente fanfarria, el cambio a la música de victoria y el cierre de la batalla
## (un reproductor temporal que cuelga de la batalla no puede sobrevivirla).
func esperar_fanfarria() -> void:
	var anfitrion := _anfitrion()
	while _fanfarria_sonando and anfitrion != null and anfitrion.is_inside_tree():
		await anfitrion.get_tree().process_frame


## Nodo del que cuelga el reproductor de la fanfarria: la escena de batalla.
func _anfitrion() -> Node:
	return _b


func _reproducir_fanfarria() -> void:
	# esperar_subida: Fanfarria.reproducir devolvería nada más acabar el jingle, con la
	# música aún a -80 dB subiendo en segundo plano. La siguiente fanfarria tomaría ese
	# volumen a medias como el "previo" (jingle casi inaudible y música que ya no
	# recupera su nivel), así que el aviso de "sonando" dura hasta el volumen completo.
	await Fanfarria.reproducir(_anfitrion(), TEMA_FANFARRIA, true)
	_fanfarria_sonando = false


# --- Interfaz de DialogoAprendizaje ---

## `printstring` + espera de A/B.
func mostrar_texto_aprendizaje(texto: String) -> void:
	await _b._mostrar_texto_y_esperar_confirmacion(texto)


## `BATTLE_TEXT_DeleteMove` / `BATTLE_TEXT_StopLearning` con la ventana SÍ/NO del
## combate (sub_8023A80). B equivale a NO.
func preguntar_aprendizaje(texto: String) -> bool:
	await _b.mostrar_texto_batalla(texto)
	return await _b.presentacion.preguntar_si_no()


## `BattleScript_LearnedNewMove`: fanfarria y "¡X aprendió Y!".
func anunciar_movimiento_aprendido(texto: String) -> void:
	await tocar_fanfarria()
	await _b._mostrar_texto_y_esperar_confirmacion(texto)


## `atk5A_yesnoboxlearnmove` estados 1-3: con SÍ, fundido a negro, ficha y vuelta a la
## batalla con fundido (los hace la propia ficha). 0-3 = olvidar, 4 = ninguno (B).
func elegir_movimiento_aprendizaje(aprendizaje: AprendizajeMovimientos, _nombre_mov: String) -> int:
	var ficha: FichaOlvidarMovimiento = SCN_FICHA_OLVIDAR.instantiate()
	ficha.z_index = Z_FICHA_OLVIDAR
	_b.add_child(ficha)
	var indice: int = await ficha.elegir_aprendizaje(aprendizaje)
	ficha.queue_free()
	return indice
