@tool
class_name SumersionTermal
extends RefCounted

## Agua termal (bandera TPTileDataMap.Flags.AGUA_TERMAL = MB_HOT_SPRINGS de pokeruby): el
## estanque de PUEBLO LAVACALDA tapa el cuerpo de quien se baña (jugador y NPC), que queda
## "sumergido" con solo la cabeza y los hombros fuera.
##
## En Rubí no hay recorte: GroundEffect_HotSprings crea un sprite de agua de 16x16
## (FldEff_HotSpringsWater / UpdateHotSpringsWaterFieldEffect, field_effect_helpers.c) pegado a
## los pies del objeto y por delante de él (subpriority - 1), con las 8 filas inferiores
## opacas (9 en las esquinas). Aquí se obtiene lo mismo recortando el sprite con el shader
## de hierba muy alta (hierba_muy_alta_clip.gdshader, uniforms `sumergir_agua_termal` y
## `agua_termal_*`), que deja ver el agua del mapa por debajo.
##
## Regla de Rubí (GetGroundEffectFlags_HotSprings, event_object_movement.c): el agua solo
## tapa al objeto cuando la celda actual Y la anterior (la de la que viene) son termales.
## La aplica al empezar el paso, de golpe y sin animación: el primer paso desde tierra al
## agua entra aún a cuerpo entero y el recorte aparece en el siguiente paso dentro del
## estanque; el paso que sale al suelo lo quita al empezar. Al aparecer o teletransportarse
## en una celda termal la anterior es ella misma, así que ya nace sumergido.
##
## Lo usan el jugador (character.gd) y los NPC (npc_base.gd) igual que EfectosArena y
## TierraPies: la entidad informa del inicio de cada paso y de cuando queda quieta; este
## objeto no consulta tiles por frame. El recorte solo afecta al sprite que lleva el
## material (`basico` del jugador, el AnimatedSprite2D del NPC): en bici o en surf se
## usan otros sprites sin este material y no se aplica.
##
## Es @tool porque npc_base.gd (también @tool) lo crea en el editor, donde la vista previa del
## NPC ya aparece sumergida si su celda es termal.

const PARAMETRO_SUMERGIR := &"sumergir_agua_termal"

## El agua tapa ahora al objeto.
var sumergido: bool = false

var _material: ShaderMaterial = null
## Celda y TPTileDataMap con los que se evaluó por última vez el estado.
var _celda_evaluada: Vector2i = Vector2i.ZERO
var _id_tp_evaluado: int = 0


func _init(material: ShaderMaterial = null) -> void:
	_material = material
	_aplicar()


## Regla de GetGroundEffectFlags_HotSprings: celda de origen y de destino del paso termales.
static func esta_sumergido(origen_termal: bool, destino_termal: bool) -> bool:
	return origen_termal and destino_termal


static func celda_es_termal(tp: TPTileDataMap, celda: Vector2i) -> bool:
	return tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.AGUA_TERMAL)


## Llamar al empezar un paso, con la entidad aún en la celda de origen.
func iniciar_paso(tp: TPTileDataMap, celda_origen: Vector2i, celda_destino: Vector2i) -> void:
	_registrar(tp, celda_destino)
	sumergido = esta_sumergido(celda_es_termal(tp, celda_origen), celda_es_termal(tp, celda_destino))
	_aplicar()


## Entidad quieta en `celda` (fin de paso, aterrizaje, teletransporte o aparición). Si ya se
## evaluó esa celda al empezar el paso que llevó hasta ella, se conserva ese resultado (cuenta
## la celda de la que venía); si no, la celda anterior es ella misma.
func actualizar_reposo(tp: TPTileDataMap, celda: Vector2i) -> void:
	var id_tp := tp.get_instance_id() if tp != null else 0
	if id_tp == _id_tp_evaluado and celda == _celda_evaluada:
		return
	_registrar(tp, celda)
	sumergido = celda_es_termal(tp, celda)
	_aplicar()


## Quita el recorte y olvida la celda evaluada (la entidad sale del árbol: el ShaderMaterial de
## una escena puede ser un recurso compartido que sobrevive a la instancia).
func reiniciar() -> void:
	sumergido = false
	_celda_evaluada = Vector2i.ZERO
	_id_tp_evaluado = 0
	_aplicar()


func _registrar(tp: TPTileDataMap, celda: Vector2i) -> void:
	_id_tp_evaluado = tp.get_instance_id() if tp != null else 0
	_celda_evaluada = celda


func _aplicar() -> void:
	if _material != null:
		_material.set_shader_parameter(PARAMETRO_SUMERGIR, sumergido)
