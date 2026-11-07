## Mugshots del Alto Mando y del Campeón (Phase2Task_MugShotTransition,
## Phase2_Mugshot_Func1..10). La animación es común a los cinco: las bandas de
## color, los carriles por los que se deslizan los retratos, el destello blanco
## desde el centro y el oscurecido final. Cada escena heredada solo cambia los
## exports (Mugshots_CreateOpponentPlayerSprites):
##   - sMugshotsTrainerPicIDsTable → `frame_retrato` (atlas trainers64/8150.png).
##   - sMugshotsOpponentRotationScales → `escala_rival` (valor / 256).
##   - sMugshotsOpponentCoords → `desplazamiento_rival` (dx, dy).
##   - sOpponentMugshotsPals + sPlayerMugshotsPals → `fondo_chico` / `fondo_chica`.
## El SE_BT_START de Phase2_Mugshot_Func4 es una pista de audio de la animación.
class_name TransicionMugshot
extends TransicionBatalla

## Retrato frontal de 64x64: el mugshot usa la mitad superior (OAM 64x32).
const ATLAS_RETRATOS: Texture2D = preload("res://graficos/trainers64/8150.png")
const RETRATO_CHICO: Texture2D = preload("res://graficos/trainers64/001.png")
const RETRATO_CHICA: Texture2D = preload("res://graficos/trainers64/002.png")
const COLUMNAS_ATLAS: int = 10
const PASO_ATLAS: int = 65

## Frame del rival en el atlas de retratos (Sixto 78, Fátima 79, Nívea 80,
## Dracón 81, Máximo 29).
@export var frame_retrato: int = 78
## ConvertScaleParam: escala visual = parámetro de SetOamMatrixRotationScaling / 256.
@export var escala_rival: float = 2.0
## El centro del rival empieza en (dx - 32, dy + 42).
@export var desplazamiento_rival: Vector2i = Vector2i.ZERO
## BG0 con la banda del rival y la de BRUNO / AURA (gSaveBlock2.playerGender).
@export var fondo_chico: Texture2D
@export var fondo_chica: Texture2D

@onready var _fondo: ColorRect = $Fondo
@onready var _rival: Sprite2D = $CarrilRival/Rival
@onready var _jugador: Sprite2D = $CarrilJugador/Jugador


func _preparar() -> void:
	configurar(_jugador_es_chica())


## Aplica los exports y el sexo del jugador a los nodos de la escena.
func configurar(jugador_chica: bool) -> void:
	var rival := AtlasTexture.new()
	rival.atlas = ATLAS_RETRATOS
	rival.region = Rect2(
		1 + PASO_ATLAS * (frame_retrato % COLUMNAS_ATLAS),
		1 + PASO_ATLAS * floori(float(frame_retrato) / COLUMNAS_ATLAS),
		64, 32
	)
	_rival.texture = rival
	_rival.scale = Vector2(escala_rival, escala_rival)
	_rival.position = Vector2(desplazamiento_rival.x - 32, desplazamiento_rival.y + 42)
	var jugador := AtlasTexture.new()
	jugador.atlas = RETRATO_CHICA if jugador_chica else RETRATO_CHICO
	jugador.region = Rect2(0, 0, 64, 32)
	_jugador.texture = jugador
	var fondo := fondo_chica if jugador_chica else fondo_chico
	if fondo != null:
		(_fondo.material as ShaderMaterial).set_shader_parameter(&"fondo", fondo)


func _jugador_es_chica() -> bool:
	var guardado := get_node_or_null("/root/SistemaGuardado")
	if guardado == null:
		return false
	var datos: Variant = guardado.get("datos_vivos")
	if datos == null:
		return false
	var jugador: Variant = datos.get("jugador")
	if not (jugador is Dictionary):
		return false
	return str((jugador as Dictionary).get("sexo", "M")) == "F"
