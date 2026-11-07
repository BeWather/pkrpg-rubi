extends Resource
class_name Opciones

@export var velocidad_texto: int = Singleton.VelocidadTexto.MEDIA
@export var animacion_combate: bool = true
@export var tipo_combate: int = Singleton.TipoCombate.CAMBIAR
@export var nivel_audio: int = Singleton.Sonido.BAJO
@export var controles: int = Singleton.Controles.NORMAL
@export_range(1, 20) var imagen_tipo: int = 1

func to_dict() -> Dictionary:
    return {
        "velocidad_texto": int(velocidad_texto),
        "animacion_combate": bool(animacion_combate),
        "tipo_combate": int(tipo_combate),
        "nivel_audio": int(nivel_audio),
        "controles": int(controles),
        "imagen_tipo": int(imagen_tipo)
    }

func from_dict(d: Dictionary) -> void:
    velocidad_texto = int(d.get("velocidad_texto", velocidad_texto))
    animacion_combate = bool(d.get("animacion_combate", animacion_combate))
    tipo_combate = int(d.get("tipo_combate", tipo_combate))
    nivel_audio = int(d.get("nivel_audio", nivel_audio))
    controles = int(d.get("controles", controles))
    imagen_tipo = int(d.get("imagen_tipo", imagen_tipo))
