class_name CapaFondoCreditos
extends Sprite2D
## Una capa del fondo de la bici (BG1-BG3 u objetos de sub_8148F3C / sub_814910C): se desplaza a la
## derecha repitiendo su textura y, con `cuadros` = 2, alterna el ciclo de paleta de CycleSceneryPalette.

const FOTOGRAMAS_POR_CICLO: int = 4
const ALTO_CUADRO: float = 256.0

## Píxeles por fotograma a 60 fps.
@export var velocidad: float = 0.0
## El desnivel del terreno (gUnknown_0203935A) también la mueve.
@export var usa_bob: bool = false
@export var ancho: int = 256
@export var cuadros: int = 1

var _desplazamiento: float = 0.0


func actualizar(fotogramas: float, total: float, vertical: float, bob: float) -> void:
	_desplazamiento = fposmod(_desplazamiento - velocidad * fotogramas, float(ancho))
	var cuadro: int = int(total / FOTOGRAMAS_POR_CICLO) % cuadros
	region_rect.position = Vector2(_desplazamiento, cuadro * ALTO_CUADRO)
	position.y = -(vertical + (bob if usa_bob else 0.0))
