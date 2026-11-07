extends RefCounted
class_name DialogoMaquina

## Conversación de enseñar una MT/MO en la pantalla de equipo: `Task_TeamMonTMMove`,
## `sub_806F358` (¿olvidar uno?), `TaughtMove` ("1, 2 y... ¡puf!") y
## `StopTryingToTeachMove_*` (¿dejar de aprender?), con los mismos contratos de
## aprendizaje/olvido que DialogoAprendizaje.
##
## `interfaz` (duck typing):
##   mostrar_texto_aprendizaje(texto: String) -> void
##   preguntar_aprendizaje(texto: String) -> bool              (SÍ/NO; B = NO)
##   elegir_movimiento_maquina(aprendizaje, nombre_mov) -> int  (0-3 o 4 = ninguno)
##   anunciar_movimiento_aprendido(texto: String) -> void      (con la fanfarria)
## `vigente` se consulta tras cada espera: si deja de valer, se abandona sin tocar nada.
## Devuelve true si el Pokémon aprendió el movimiento.
static func ejecutar(aprendizaje: EnsenanzaMaquina, interfaz: Object, vigente: Callable) -> bool:
	if not vigente.is_valid() or not vigente.call(): return false
	var pokemon: BasePokemon = aprendizaje.pokemon
	var mov: String = aprendizaje.nombre_mov
	var estado: EnsenanzaMaquina.Estado = aprendizaje.estado()
	if estado != EnsenanzaMaquina.Estado.VALIDA:
		if estado in [EnsenanzaMaquina.Estado.YA_CONOCE, EnsenanzaMaquina.Estado.INCOMPATIBLE]:
			var clave: String = "MAQUINA_YA_CONOCE" if estado == EnsenanzaMaquina.Estado.YA_CONOCE else "MAQUINA_INCOMPATIBLE"
			await interfaz.mostrar_texto_aprendizaje(DatosMaquinas.texto(clave, pokemon, mov))
		return false
	var paso: Dictionary = aprendizaje.siguiente()
	if int(paso["resultado"]) == AprendizajeMovimientos.Resultado.APRENDIDO:
		await interfaz.anunciar_movimiento_aprendido(DatosMaquinas.texto("MAQUINA_APRENDIDO", pokemon, mov))
		return true
	if int(paso["resultado"]) != AprendizajeMovimientos.Resultado.SIN_HUECO: return false
	while vigente.call():
		var olvidar: bool = await interfaz.preguntar_aprendizaje(DatosMaquinas.texto("MAQUINA_QUIERE", pokemon, mov))
		if not vigente.call(): return false
		if olvidar:
			while vigente.call():
				var indice: int = await interfaz.elegir_movimiento_maquina(aprendizaje, mov)
				if not vigente.call(): return false
				if indice < 0 or indice >= AprendizajeMovimientos.MAX_MOVIMIENTOS: break
				if aprendizaje.es_mo(indice):
					await interfaz.mostrar_texto_aprendizaje(DatosMaquinas.texto("MAQUINA_NO_OLVIDAR_MO"))
					continue
				var olvidado: String = aprendizaje.sustituir(indice)
				if olvidado.is_empty(): return false
				await interfaz.mostrar_texto_aprendizaje(DatosMaquinas.texto("MAQUINA_OLVIDO", pokemon, olvidado))
				await interfaz.anunciar_movimiento_aprendido(DatosMaquinas.texto("MAQUINA_APRENDIDO", pokemon, mov))
				return true
		var dejar: bool = await interfaz.preguntar_aprendizaje(DatosMaquinas.texto("MAQUINA_DEJAR", pokemon, mov))
		if not vigente.call(): return false
		if dejar:
			await interfaz.mostrar_texto_aprendizaje(DatosMaquinas.texto("MAQUINA_NO_APRENDIO", pokemon, mov))
			return false
	return false
