class_name DialogoAprendizaje
extends RefCounted

## Conversación de aprender movimientos por nivel, común a la escena de
## evolución (`Task_EvolutionScene` estados 14 y 19-21), al CARAMELORARO en el
## equipo (`Task_RareCandy3`, `TeachMonMoveInPartyMenu`, `sub_806F358`) y a la subida
## de nivel en combate (`BattleScript_LevelUp` / `BattleScript_TryLearnMoveLoop`).
##
## `interfaz` es quien muestra los textos (duck typing):
##   mostrar_texto_aprendizaje(texto: String) -> void       (espera A/B)
##   preguntar_aprendizaje(texto: String) -> bool          (SÍ/NO; B = NO)
##   elegir_movimiento_aprendizaje(aprendizaje, nombre_mov) -> int  (0-3 o 4 = ninguno)
##   anunciar_movimiento_aprendido(texto: String) -> void  (con la fanfarria)


## Recorre los movimientos que la especie aprende a su nivel actual (o a `nivel`).
static func ejecutar(pokemon: BasePokemon, interfaz: Object, datos: Object = null, nivel: int = -1) -> void:
	var aprendizaje := AprendizajeMovimientos.new(pokemon, datos, nivel)
	while true:
		var paso: Dictionary = aprendizaje.siguiente()
		var resultado := int(paso["resultado"])
		if resultado == AprendizajeMovimientos.Resultado.FIN:
			return
		var nombre_mov := aprendizaje.nombre_movimiento(str(paso["movimiento"]))
		if resultado == AprendizajeMovimientos.Resultado.APRENDIDO:
			await interfaz.anunciar_movimiento_aprendido(texto("EVOLUCION_MOV_APRENDIDO", pokemon, nombre_mov))
		else:
			await _intentar_sustituir(aprendizaje, nombre_mov, interfaz)


## Ya tiene cuatro movimientos: preguntar cuál olvidar o renunciar.
static func _intentar_sustituir(aprendizaje: AprendizajeMovimientos, nombre_mov: String, interfaz: Object) -> void:
	var pokemon := aprendizaje.pokemon
	while true:
		await interfaz.mostrar_texto_aprendizaje(texto("EVOLUCION_MOV_QUIERE", pokemon, nombre_mov))
		await interfaz.mostrar_texto_aprendizaje(texto("EVOLUCION_MOV_NO_PUEDE", pokemon, nombre_mov))
		if await interfaz.preguntar_aprendizaje(texto("EVOLUCION_MOV_PREGUNTA", pokemon, nombre_mov)):
			while true:
				var indice: int = await interfaz.elegir_movimiento_aprendizaje(aprendizaje, nombre_mov)
				if indice < 0 or indice >= AprendizajeMovimientos.MAX_MOVIMIENTOS:
					break
				if aprendizaje.es_mo(indice):
					await interfaz.mostrar_texto_aprendizaje(traducir("EVOLUCION_MOV_MO"))
					continue
				var olvidado := aprendizaje.sustituir(indice)
				await interfaz.mostrar_texto_aprendizaje(traducir("EVOLUCION_MOV_PUF"))
				await interfaz.mostrar_texto_aprendizaje(texto("EVOLUCION_MOV_OLVIDO", pokemon, olvidado))
				await interfaz.mostrar_texto_aprendizaje(traducir("EVOLUCION_MOV_Y"))
				await interfaz.anunciar_movimiento_aprendido(texto("EVOLUCION_MOV_APRENDIDO", pokemon, nombre_mov))
				return
		# ¿Dejar de aprenderlo? Con NO se vuelve a empezar.
		if await interfaz.preguntar_aprendizaje(texto("EVOLUCION_MOV_DEJAR", pokemon, nombre_mov)):
			await interfaz.mostrar_texto_aprendizaje(texto("EVOLUCION_MOV_NO_APRENDIO", pokemon, nombre_mov))
			return


static func texto(clave: String, pokemon: BasePokemon, nombre_mov: String) -> String:
	return traducir(clave).replace("{mon}", pokemon.get_nombre_mostrar()).replace("{mov}", nombre_mov)


static func traducir(clave: String) -> String:
	return str(TranslationServer.translate(clave))
