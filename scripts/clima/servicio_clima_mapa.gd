class_name ServicioClimaMapa
extends RefCounted

## Clima del mapa activo del overworld: clima de entrada (SelectorClimaEntrada o
## `clima_inicial`), ancla del canal de mundo, climas persistentes (restaurar,
## reiniciar, evaluar la llegada tras un warp) y las peticiones de cambio y
## restauración con validación de mapa activo.
##
## No guarda qué mapa es el actual ni de dónde viene el jugador: AdministradorMapa
## pasa el mapa en cada llamada y decide si los persistentes se conservan (ese
## seguimiento lo comparte con el estado volátil del mapa, que no es clima).
## La celda de entrada se pasa explícita (`celda_entrada`) cuando el jugador aún
## no está en su sitio: destino de un warp, celda de llegada al cruzar un borde o
## celda guardada al cargar. `null` = la celda actual del jugador.
##
## Es RefCounted y no Node: no procesa frames ni recibe señales, no depende del
## árbol y se prueba sin montar escenas. AdministradorMapa lo crea a demanda y
## lo enlaza con `enlazar()` antes de cada uso.

## Controlador que pinta el clima. Sin controlador ninguna operación hace nada
## (ni siquiera sincronizar los persistentes) y las peticiones devuelven false.
var controlador: ControladorClimaOverworld = null
## Jugador cuya celda decide la zona de entrada cuando no se pasa una explícita.
var jugador: Node2D = null
## Desplazamiento del sprite del jugador respecto a la esquina de su celda.
var jugador_offset: Vector2 = Vector2.ZERO


## Actualiza las dependencias (cambian en tiempo de ejecución: el jugador se crea
## al iniciar la partida y los tests inyectan el controlador). Devuelve el propio
## servicio para encadenar.
func enlazar(
	controlador_nuevo: ControladorClimaOverworld,
	jugador_nuevo: Node2D,
	offset_nuevo: Vector2
) -> ServicioClimaMapa:
	controlador = controlador_nuevo
	jugador = jugador_nuevo
	jugador_offset = offset_nuevo
	return self


## Sin mapa activo: suelta el ancla de mundo y deja el clima en NINGUNO.
func limpiar() -> void:
	if controlador == null:
		return
	controlador.configurar_ancla_mundo(null)
	controlador.limpiar_inmediato()


## Aplica sin transición el clima con el que se entra en `mapa`: la sequía de
## ClimaLegendario si está activa en ese mapa; si no, el de la zona del selector
## que contiene `celda_entrada` (o la celda del jugador si es null) o, si no hay
## zona, `clima_inicial`. Después reaplica o reinicia los climas persistentes del
## mapa según `conservar_persistentes`.
func aplicar_clima_entrada(
	mapa: MapaConfiguracion,
	celda_entrada: Variant = null,
	conservar_persistentes: bool = true
) -> void:
	if controlador == null or mapa == null:
		return
	# El ancla primero: el clima nuevo (o el que se conserva) crea su canal de
	# mundo bajo el mapa actual y se liberan los nodos del mapa anterior.
	controlador.configurar_ancla_mundo(mapa.obtener_ancla_clima_mundo())
	var zona := resolver_zona_entrada(mapa, celda_entrada)
	if ClimaLegendario.aplica_a(mapa):
		controlador.aplicar_inmediato(ClimaLegendario.CLIMA)
	elif zona != null:
		controlador.aplicar_inmediato(zona.clima, zona.intensidad)
	else:
		controlador.aplicar_inmediato(mapa.clima_inicial, mapa.intensidad_clima)
	sincronizar_persistentes(mapa, conservar_persistentes)


## Zona del SelectorClimaEntrada de `mapa` que contiene `celda_entrada` (o la
## celda del jugador si no es un Vector2i), o null si no hay selector, celda o
## zona.
func resolver_zona_entrada(mapa: MapaConfiguracion, celda_entrada: Variant = null) -> ZonaClimaEntrada:
	if mapa == null:
		return null
	var celda: Variant = celda_entrada if celda_entrada is Vector2i else obtener_celda_jugador(mapa)
	if not (celda is Vector2i):
		return null
	return mapa.resolver_zona_clima_entrada(celda as Vector2i)


## Celda local de `mapa` que ocupa el jugador, o null si no hay jugador en el
## árbol.
func obtener_celda_jugador(mapa: MapaConfiguracion) -> Variant:
	if mapa == null or jugador == null or not is_instance_valid(jugador) or not jugador.is_inside_tree():
		return null
	return mapa.global_to_map_cell(jugador.global_position - jugador_offset)


## Eventos de clima con estado guardado en la partida (p. ej. la tormenta de
## arena del desierto): se reaplican encima del clima de entrada, sin transición,
## o se reinician a inactivos si el jugador llega desde otro mapa.
func sincronizar_persistentes(mapa: MapaConfiguracion, conservar: bool) -> void:
	for nodo: DisparadorClimaPersistente in nodos_persistentes(mapa):
		if conservar:
			nodo.restaurar_estado_guardado()
		else:
			nodo.reiniciar_estado()


## Tras el teletransporte de un warp: los climas persistentes reiniciados deciden
## si arrancan activos según la celda de llegada del jugador. Los cruces de borde
## no pasan por aquí.
func evaluar_llegada_persistentes(mapa: MapaConfiguracion) -> void:
	if jugador == null or mapa == null:
		return
	var celda := mapa.global_to_map_cell(jugador.global_position - jugador_offset)
	for nodo: DisparadorClimaPersistente in nodos_persistentes(mapa):
		nodo.evaluar_llegada(celda)


## Cambia el clima del overworld. Si la petición declara `mapa_origen`, solo se
## acepta mientras ese mapa sea `mapa_activo`. `duracion <= 0` aplica sin
## transición.
func cambiar_clima(
	mapa_activo: MapaConfiguracion,
	definicion: DefinicionClima,
	duracion: float = 1.0,
	mapa_origen: MapaConfiguracion = null,
	intensidad: float = -1.0
) -> bool:
	if controlador == null:
		return false
	if mapa_origen != null and mapa_origen != mapa_activo:
		return false
	if duracion <= 0.0:
		controlador.aplicar_inmediato(definicion, intensidad)
	else:
		controlador.transicionar_a(definicion, duracion, intensidad)
	return true


## Vuelve al clima declarado por `mapa_activo`: el de la zona del selector que
## contiene la celda actual del jugador o, si no hay, `clima_inicial`.
func restaurar_clima(mapa_activo: MapaConfiguracion, duracion: float = 1.0) -> bool:
	if controlador == null or mapa_activo == null:
		return false
	var zona := resolver_zona_entrada(mapa_activo)
	if zona != null:
		return cambiar_clima(mapa_activo, zona.clima, duracion, mapa_activo, zona.intensidad)
	return cambiar_clima(
		mapa_activo,
		mapa_activo.clima_inicial,
		duracion,
		mapa_activo,
		mapa_activo.intensidad_clima
	)


## Tema del primer clima persistente activo de `mapa` (p. ej. RUTA_111_DESIERTO
## con la tormenta de arena), o "" si ninguno impone música.
func obtener_tema_musica_activo(mapa: MapaConfiguracion) -> String:
	for nodo: DisparadorClimaPersistente in nodos_persistentes(mapa):
		var tema := nodo.obtener_tema_musica_activo()
		if not tema.is_empty():
			return tema
	return ""


## Temas que pueden sonar con los climas persistentes de `mapa`, en orden y sin
## filtrar (para precargarlos antes de pisar la zona de activación).
func obtener_temas_musica_persistentes(mapa: MapaConfiguracion) -> Array[String]:
	var temas: Array[String] = []
	for nodo: DisparadorClimaPersistente in nodos_persistentes(mapa):
		temas.append(nodo.tema_musica)
	return temas


## El estado guardado de los persistentes solo sigue valiendo si el jugador no ha
## salido de la zona: al cargar la partida (`clave_previa` vacía), al reaplicar el
## mismo mapa o al volver de un interior propio del mapa (`exterior_previo`).
## Llegar desde otro mapa (vuelo, derrota, caminando por un borde) lo reinicia,
## así no aparece la tormenta fuera del desierto.
static func conserva_persistentes_al_entrar(
	clave_previa: String,
	exterior_previo: String,
	clave_actual: String
) -> bool:
	if clave_previa.is_empty() or clave_previa == clave_actual:
		return true
	return exterior_previo == clave_actual


## Nodos del grupo de climas persistentes que pertenecen a `mapa` (los exteriores
## siguen todos instanciados en el Overworld).
static func nodos_persistentes(mapa: MapaConfiguracion) -> Array[DisparadorClimaPersistente]:
	var nodos: Array[DisparadorClimaPersistente] = []
	if mapa == null or not mapa.is_inside_tree():
		return nodos
	for nodo: Node in mapa.get_tree().get_nodes_in_group(DisparadorClimaPersistente.GRUPO_ESTADO_PERSISTENTE):
		if nodo is DisparadorClimaPersistente and mapa.is_ancestor_of(nodo):
			nodos.append(nodo)
	return nodos
