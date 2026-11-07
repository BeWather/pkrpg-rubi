## Constantes del hardware GBA compartidas por los efectos de mundo (clima, agua,
## eventos por tiles). Sin dependencias de autoloads: se pueden usar en scripts
## @tool y en expresiones `const`.
class_name ConstantesGba
extends RefCounted

## Pantalla lógica del GBA en píxeles.
const RESOLUCION_LOGICA := Vector2(240, 160)
## Frames por segundo del GBA.
const FPS := 60
## Lado de un tile del mapa en píxeles.
const TAMANO_TILE := 16
