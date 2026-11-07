## condicion_texto.gd
## Elige el texto de un msgbox de Gen 3 que depende del progreso
## (goto_if_set / call_if_eq antes del msgbox). `condiciones` es un Dictionary
## {condición: id_texto}: gana la primera que se cumple y, si ninguna,
## `por_defecto`. Una condición es el nombre de una bandera de SistemaGuardado
## o "MEDALLA_n" (FLAG_BADGE0n_GET, n = 1..8) o "INICIAL_EN_EQUIPO_n"
## (IsStarterInParty con VAR_STARTER_MON == n: 0 TREECKO, 1 TORCHIC, 2 MUDKIP) o
## "TIPO_EN_EQUIPO_<TIPO>" (IsGrassTypeInParty: algún Pokémon del equipo que no
## sea un huevo tiene ese tipo; p. ej. "TIPO_EN_EQUIPO_PLANTA").
## o "OBJETO_EN_MOCHILA_<nombre_interno>" (checkitem: el jugador lleva el objeto;
## p. ej. "OBJETO_EN_MOCHILA_PASECONCURSO").
##
## Orden: Godot guarda los Dictionary de las escenas con las claves ordenadas, así
## que el orden en que se escribieron no sobrevive a guardar la escena desde el
## editor. Cuando importa, cada clave lleva delante su prioridad: "1:bandera" se
## comprueba antes que "2:MEDALLA_5". Las claves sin prioridad van después, en el
## orden del Dictionary.
class_name CondicionTexto

const PREFIJO_MEDALLA: String = "MEDALLA_"
const PREFIJO_INICIAL_EN_EQUIPO: String = "INICIAL_EN_EQUIPO_"
const PREFIJO_TIPO_EN_EQUIPO: String = "TIPO_EN_EQUIPO_"
const PREFIJO_OBJETO_EN_MOCHILA: String = "OBJETO_EN_MOCHILA_"
const SIN_PRIORIDAD: int = 1 << 30


static func resolver(condiciones: Dictionary, por_defecto: String) -> String:
	for condicion: String in por_prioridad(condiciones):
		if cumple(condicion):
			return str(condiciones[condicion])
	return por_defecto


## Claves de `condiciones` en el orden en que se comprueban.
static func por_prioridad(condiciones: Dictionary) -> Array[String]:
	var entradas: Array = []
	var indice := 0
	for condicion: String in condiciones:
		entradas.append([prioridad(condicion), indice, condicion])
		indice += 1
	entradas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var claves: Array[String] = []
	for entrada in entradas:
		claves.append(entrada[2])
	return claves


## "n:condición" → n; sin prefijo, SIN_PRIORIDAD.
static func prioridad(condicion: String) -> int:
	var separador := condicion.find(":")
	if separador > 0 and condicion.left(separador).is_valid_int():
		return int(condicion.left(separador))
	return SIN_PRIORIDAD


static func sin_prioridad(condicion: String) -> String:
	return condicion.substr(condicion.find(":") + 1) if prioridad(condicion) != SIN_PRIORIDAD else condicion


static func cumple(condicion: String) -> bool:
	condicion = sin_prioridad(condicion)
	if condicion.begins_with(PREFIJO_MEDALLA):
		return SistemaGuardado.tiene_medalla(int(condicion.trim_prefix(PREFIJO_MEDALLA)) - 1)
	if condicion.begins_with(PREFIJO_INICIAL_EN_EQUIPO):
		return inicial_en_equipo(int(condicion.trim_prefix(PREFIJO_INICIAL_EN_EQUIPO)))
	if condicion.begins_with(PREFIJO_TIPO_EN_EQUIPO):
		return tipo_en_equipo(condicion.trim_prefix(PREFIJO_TIPO_EN_EQUIPO))
	if condicion.begins_with(PREFIJO_OBJETO_EN_MOCHILA):
		return objeto_en_mochila(condicion.trim_prefix(PREFIJO_OBJETO_EN_MOCHILA))
	return SistemaGuardado.get_flag(condicion)


## checkitem ITEM_X, 1: el jugador lleva al menos uno del objeto `nombre_interno`
## (clave de la tabla Objetos, p. ej. "PASECONCURSO") en su bolsillo.
static func objeto_en_mochila(nombre_interno: String) -> bool:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(nombre_interno)
	return SistemaGuardado.get_cantidad_objeto(nombre_interno, int(datos.get("bolsillo_id", 0))) > 0


## IsStarterInParty: el inicial elegido es `indice` y hay uno de su especie (sin
## evolucionar y que no sea HUEVO) en el equipo, sea o no el ejemplar original.
static func inicial_en_equipo(indice: int) -> bool:
	if SistemaGuardado.get_inicial() != indice:
		return false
	var especie: String = SistemaGuardado.INICIALES[indice]
	for pokemon in SistemaGuardado.get_equipo():
		if pokemon is BasePokemon and not pokemon.huevo and pokemon.nombre_interno == especie:
			return true
	return false


## IsGrassTypeInParty (special): hay en el equipo algún Pokémon con especie y que no
## sea un huevo cuyo tipo 1 o tipo 2 sea `nombre_tipo` ("PLANTA", "FUEGO"...).
static func tipo_en_equipo(nombre_tipo: String) -> bool:
	for pokemon in SistemaGuardado.get_equipo():
		if pokemon is BasePokemon and not pokemon.huevo and nombre_tipo in pokemon.obtener_nombres_tipos():
			return true
	return false
