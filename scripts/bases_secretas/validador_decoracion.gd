@tool
extends RefCounted
class_name ValidadorDecoracion

## Núcleo puro: geometría (5.1) y validación contra snapshot completo (5.2).
## No reserva inventario, escribe estado ni cambia escenas/tiles.
enum Permiso { SOLID_FLOOR, PASS_FLOOR, BEHIND_FLOOR, NA_WALL, SOLID_MAT }
enum Forma { TAM_1X1, TAM_2X1, TAM_3X1, TAM_4X2, TAM_2X2, TAM_1X2, TAM_1X3, TAM_2X4, TAM_3X3, TAM_3X2 }
enum ReglaSuperficie {
	INVALIDA = -1, SUELO, SUELO_O_BLOQUE_CAPA_CERO, SUELO_O_PARED_NORTE,
	PARED_NORTE, BORDE_O_CENTRO_ALFOMBRA, CENTRO_ALFOMBRA, SIN_COMPROBAR,
}
const DIMENSIONES: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 2), Vector2i(2, 2),
	Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 3), Vector2i(3, 2),
]
const NOMBRES_PERMISOS: Array[String] = ["SOLID_FLOOR", "PASS_FLOOR", "BEHIND_FLOOR", "NA_WALL", "SOLID_MAT"]
const DECOR_SOLID_BOARD: int = 33  # Única excepción de suelo sobre MB_HOLE.


static func tamano_forma(forma: int) -> Vector2i:
	return DIMENSIONES[forma] if forma >= 0 and forma < DIMENSIONES.size() else Vector2i.ZERO


static func forma_decoracion(decoracion_id: int) -> int:
	var datos: Dictionary = DatosBasesSecretas.decoracion(decoracion_id)
	if datos.is_empty():
		return -1
	return DIMENSIONES.find(Vector2i(int(datos["ancho"]), int(datos["alto"])))


static func permiso_decoracion(decoracion_id: int) -> int:
	return NOMBRES_PERMISOS.find(str(DatosBasesSecretas.decoracion(decoracion_id).get("permiso", "")))


## fila = 0 arriba, como el índice gráfico, NO distancia desde el ancla.
## sub_80FFC24 recorre SOLID_MAT solo en la fila de apoyo inferior.
static func regla_superficie(decoracion_id: int, fila: int) -> ReglaSuperficie:
	var forma: int = forma_decoracion(decoracion_id)
	var alto: int = tamano_forma(forma).y
	if forma < 0 or fila < 0 or fila >= alto:
		return ReglaSuperficie.INVALIDA
	match permiso_decoracion(decoracion_id):
		Permiso.SOLID_FLOOR, Permiso.PASS_FLOOR:
			return ReglaSuperficie.SUELO
		Permiso.BEHIND_FLOOR:
			return ReglaSuperficie.SUELO_O_PARED_NORTE if fila == 0 else ReglaSuperficie.SUELO_O_BLOQUE_CAPA_CERO
		Permiso.NA_WALL:
			return ReglaSuperficie.PARED_NORTE
		Permiso.SOLID_MAT:
			if fila != alto - 1:
				return ReglaSuperficie.SIN_COMPROBAR
			return ReglaSuperficie.CENTRO_ALFOMBRA if forma == Forma.TAM_1X2 else ReglaSuperficie.BORDE_O_CENTRO_ALFOMBRA
	return ReglaSuperficie.INVALIDA


## Predicado por celda, no valida una colocación. tipo_capa_gba_adorno es el
## nibble de atributos del metatile que se colocará, NO capa de datos Godot ni
## colisión/elevación del suelo actual. No inferirlo del permiso del adorno.
static func admite_superficie(decoracion_id: int, fila: int, comportamiento: int,
		tipo_capa_gba_adorno: int) -> bool:
	if comportamiento < 0 or comportamiento > 255 or tipo_capa_gba_adorno < 0 or tipo_capa_gba_adorno > 15:
		return false
	match regla_superficie(decoracion_id, fila):
		ReglaSuperficie.SUELO:
			return comportamiento == SuperficiesDecoracion.MB_NORMAL \
				or (decoracion_id == DECOR_SOLID_BOARD and comportamiento == SuperficiesDecoracion.MB_HOLE)
		ReglaSuperficie.SUELO_O_BLOQUE_CAPA_CERO:
			return comportamiento == SuperficiesDecoracion.MB_NORMAL \
				or (comportamiento == SuperficiesDecoracion.MB_BLOCK_DECORATION and tipo_capa_gba_adorno == 0)
		ReglaSuperficie.SUELO_O_PARED_NORTE:
			return comportamiento == SuperficiesDecoracion.MB_NORMAL or comportamiento == SuperficiesDecoracion.MB_NORTH_WALL
		ReglaSuperficie.PARED_NORTE:
			return comportamiento == SuperficiesDecoracion.MB_NORTH_WALL
		ReglaSuperficie.BORDE_O_CENTRO_ALFOMBRA:
			return comportamiento == SuperficiesDecoracion.MB_LARGE_MAT_EDGE or comportamiento == SuperficiesDecoracion.MB_LARGE_MAT_CENTER
		ReglaSuperficie.CENTRO_ALFOMBRA:
			return comportamiento == SuperficiesDecoracion.MB_LARGE_MAT_CENTER
		ReglaSuperficie.SIN_COMPROBAR:
			return true  # Cabeza gráfica del sprite; no es una celda de apoyo.
	return false


## Geometría en celdas locales Godot. Ancla inferior izquierda; orden gráfico
## de arriba a abajo/izquierda a derecha, igual a sub_80FF1EC (sin borde GBA +7).
## Huella nominal de la forma; no confundir con el tamaño/offset del PNG del sprite.
## "huella_preparada" NO es "exito" de colocación: aún falta validar el mapa.
static func preparar_huella(decoracion_id: int, ancla: Vector2i) -> Dictionary:
	var forma: int = forma_decoracion(decoracion_id)
	var permiso: int = permiso_decoracion(decoracion_id)
	if forma < 0 or permiso < 0:
		return {"resultado": &"decoracion_invalida"}
	var tamano: Vector2i = tamano_forma(forma)
	var graficas: Array[Vector2i] = []
	var comprobaciones: Array[Dictionary] = []
	for fila: int in tamano.y:
		for columna: int in tamano.x:
			var posicion: Vector2i = ancla + Vector2i(columna, fila - tamano.y + 1)
			graficas.append(posicion)
			var regla: ReglaSuperficie = regla_superficie(decoracion_id, fila)
			if regla != ReglaSuperficie.SIN_COMPROBAR:
				var indice: int = fila * tamano.x + columna
				comprobaciones.append({"posicion": posicion, "fila": fila, "columna": columna,
					"indice_huella": indice, "indice_grafico": 0 if permiso == Permiso.SOLID_MAT else indice,
					"regla_superficie": regla})
	return {"resultado": &"huella_preparada", "decoracion_id": decoracion_id, "ancla": ancla,
		"forma": forma, "permiso": permiso, "tamano": tamano,
		"huella_grafica": graficas, "celdas_a_validar": comprobaciones}


## Snapshot del terreno YA compuesto y de todos los objetos activos, no del layout
## original. jugador = celda real al abrir editor, NO cursor/preview. objetos excluye
## al jugador e incluye anclas de muñecos/cojines. No usa sus IDs/slots GBA como IDs Godot.
## Un éxito no reserva copias ni compone tiles. Revalidar al confirmar en el editor.
static func validar_terreno(decoracion_id: int, ancla: Vector2i, mapa: Dictionary) -> Dictionary:
	var plan: Dictionary = preparar_huella(decoracion_id, ancla)
	if plan["resultado"] != &"huella_preparada":
		return plan
	if not _snapshot_valido(mapa):
		return {"resultado": &"mapa_invalido"}
	var limites: Rect2i = mapa["limites"]
	var celdas: Dictionary = mapa["celdas"]
	var jugador: Vector2i = mapa["jugador"]
	var objetos: Array = mapa["objetos"]
	var permiso: int = int(plan["permiso"])
	var datos: Dictionary = DatosBasesSecretas.decoracion(decoracion_id)
	if ancla.x < 0 or ancla.y < 0 or ancla.x > 15 or ancla.y > 15:
		return _rechazo(&"posicion_invalida", ancla)
	# El cursor original limita el rectángulo nominal, incluso en sprites 1x2.
	for posicion: Vector2i in plan["huella_grafica"]:
		if not limites.has_point(posicion):
			return _rechazo(&"posicion_invalida", posicion)
	for comprobacion: Dictionary in plan["celdas_a_validar"]:
		var posicion: Vector2i = comprobacion["posicion"]
		var celda: Dictionary = celdas[posicion]
		var capa: int = 0
		if permiso != Permiso.SOLID_MAT:
			var indice: int = int(comprobacion["indice_grafico"])
			var meta: Dictionary = DatosInterioresBases.metatile(512 + int(datos["graficos_originales"][indice]))
			if meta.is_empty():
				return _rechazo(&"metatile_invalido", posicion)
			capa = int(meta["tipo_capa"])
		if not admite_superficie(decoracion_id, int(comprobacion["fila"]), int(celda["comportamiento"]), capa):
			return _rechazo(&"superficie_invalida", posicion)
		if permiso == Permiso.NA_WALL:
			var debajo: Vector2i = posicion + Vector2i.DOWN
			if not limites.has_point(debajo):
				return _rechazo(&"posicion_invalida", debajo)
			if int(celdas[debajo]["metatile_id"]) == 0x28C:
				return _rechazo(&"pared_obstruida", posicion)
			continue  # NA_WALL no consulta object events ni la celda del jugador.
		if objetos.has(posicion):
			return _rechazo(&"objeto_ocupando", posicion)
		if posicion == jugador:
			# sub_80FFB94: usa capa del metatile candidato, NO colisión actual.
			# Object event 0 (jugador) se permite en suelo/fila superior; no en apoyos.
			if permiso == Permiso.SOLID_MAT or (permiso == Permiso.BEHIND_FLOOR and int(comprobacion["fila"]) > 0) or capa != 0:
				return _rechazo(&"jugador_ocupando", posicion)
	plan["resultado"] = &"exito"
	return plan


## Preflight de copia/contexto/límites sobre un estado aislado; la única mutación
## es del candidato descartable. Mantiene las reglas en SistemaBasesSecretas sin
## presentar registrar_colocacion_validada() como validación de terreno.
static func validar_colocacion(sistema: SistemaBasesSecretas, copia_id: int, ancla: Vector2i,
		mapa: Dictionary, contexto: StringName = SistemaBasesSecretas.CONTEXTO_BASE) -> Dictionary:
	if sistema == null:
		return {"resultado": &"sistema_invalido"}
	if not sistema.es_compatible():
		return {"resultado": &"version_incompatible"}
	var candidato: SistemaBasesSecretas = SistemaBasesSecretas.new()
	candidato.from_dict(sistema.to_dict())
	var resultado: StringName = candidato.registrar_colocacion_validada(copia_id, ancla, contexto)
	if resultado != &"exito":
		return {"resultado": resultado}
	if mapa.get("contexto") != contexto:
		return {"resultado": &"contexto_invalido"}
	if contexto == SistemaBasesSecretas.CONTEXTO_BASE:
		var interior: int = int(DatosBasesSecretas.entrada(sistema.id_base())["interior_id"])
		if mapa.get("interior_id") != interior:
			return {"resultado": &"contexto_invalido"}
		var layout: Dictionary = DatosInterioresBases.interior(interior)
		if mapa.get("limites") != Rect2i(0, 0, int(layout["ancho"]), int(layout["alto"])):
			return {"resultado": &"mapa_invalido"}
	elif contexto == SistemaBasesSecretas.CONTEXTO_HABITACION:
		var casa: int = int(mapa.get("casa", 0))
		var habitacion: Dictionary = DatosHabitacionDecoracion.habitacion(casa)
		if habitacion.is_empty() or not mapa.get("casa_jugador") is int or casa != mapa["casa_jugador"]:
			return {"resultado": &"contexto_invalido"}
		if mapa.get("limites") != Rect2i(0, 0, int(habitacion["ancho"]), int(habitacion["alto"])):
			return {"resultado": &"mapa_invalido"}
	var id: int = int(sistema.obtener_copia(copia_id)["decoracion_id"])
	var plan: Dictionary = validar_terreno(id, ancla, mapa)
	if plan["resultado"] == &"exito":
		plan["copia_id"] = copia_id
		plan["contexto"] = contexto
	return plan


static func _rechazo(resultado: StringName, posicion: Vector2i) -> Dictionary:
	return {"resultado": resultado, "posicion": posicion}


static func _snapshot_valido(mapa: Dictionary) -> bool:
	if not mapa.get("limites") is Rect2i or not mapa.get("celdas") is Dictionary \
		or not mapa.get("jugador") is Vector2i or not mapa.get("objetos") is Array:
		return false
	var limites: Rect2i = mapa["limites"]
	if limites.position != Vector2i.ZERO or limites.size.x <= 0 or limites.size.y <= 0 \
		or not limites.has_point(mapa["jugador"]):
		return false
	for objeto: Variant in mapa["objetos"]:
		if not objeto is Vector2i or not limites.has_point(objeto):
			return false
	var celdas: Dictionary = mapa["celdas"]
	# Los layouts pueden medir 17 aunque el ANCLA persistida use nibbles de 4 bits.
	if celdas.size() != limites.size.x * limites.size.y:
		return false
	for y: int in limites.size.y:
		for x: int in limites.size.x:
			var celda: Variant = celdas.get(Vector2i(x, y))
			if not celda is Dictionary or not celda.get("comportamiento") is int or not celda.get("metatile_id") is int:
				return false
			if celda["comportamiento"] < 0 or celda["comportamiento"] > 255 or celda["metatile_id"] < 0 or celda["metatile_id"] > 1023:
				return false
	return true
