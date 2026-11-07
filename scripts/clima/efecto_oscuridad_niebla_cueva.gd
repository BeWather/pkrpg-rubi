class_name EfectoOscuridadNieblaCueva
extends EfectoOscuridadCueva

## Oscuridad y niebla a la vez (requires_flash + WEATHER_FOG_1 de pokeruby, CaveOfOrigin_B2F/B3F). La niebla es un hijo
## con show_behind_parent: como las ventanas del GBA, solo se ve dentro del círculo de luz.

@onready var _niebla: EfectoNieblaOverworld = $Niebla


func _ready() -> void:
	super._ready()
	_sincronizar_niebla()


func configurar(nueva_intensidad: float, nueva_area_visible: Rect2) -> void:
	super.configurar(nueva_intensidad, nueva_area_visible)
	_sincronizar_niebla()


func actualizar_area_visible(nueva_area_visible: Rect2) -> void:
	super.actualizar_area_visible(nueva_area_visible)
	_sincronizar_niebla()


func set_factor_mezcla(nuevo_factor: float) -> void:
	super.set_factor_mezcla(nuevo_factor)
	_sincronizar_niebla()


func detener() -> void:
	super.detener()
	if _niebla != null:
		_niebla.detener()


func _sincronizar_niebla() -> void:
	if _niebla == null:
		return
	_niebla.configurar(intensidad, Rect2(Vector2.ZERO, size))
	_niebla.set_factor_mezcla(factor_mezcla)
