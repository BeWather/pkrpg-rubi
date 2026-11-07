class_name RegistroHabilidades
extends RefCounted

## Inventario de las 77 habilidades de la tabla Habilidades: dónde vive la
## lógica de cada una y hasta dónde llega el motor. Un test comprueba que
## coincide con la BD, de modo que añadir una habilidad sin registrarla falla.
##
## Estados:
## - ACTIVA: la lógica está en `HabilidadesCombate` y el motor de batalla la llama.
## - FUERA_DE_COMBATE: efecto en el mapa o al acabar la batalla (`EfectosHabilidad`).
## - LOGICA_LISTA: la función existe y está probada pero el motor aún no la
##   invoca (ahora no queda ninguna: críticos, efectos secundarios, confusión,
##   retroceso, drenaje, autodestrucción, K.O. de un golpe, robo de objeto,
##   cambios forzados y la forma de CASTFORM ya están en `EfectosGolpe`).
## - SIN_EFECTO_EN_ROM: la ROM tampoco le da efecto (CACOFONÍA).

enum Estado { ACTIVA, FUERA_DE_COMBATE, LOGICA_LISTA, SIN_EFECTO_EN_ROM }

const REGISTRO := {
	"HEDOR": [Estado.FUERA_DE_COMBATE, "EfectosHabilidad.ajustar_probabilidad_encuentro: mitad de encuentros salvajes"],
	"LLOVIZNA": [Estado.ACTIVA, "al_entrar: provoca lluvia"],
	"IMPULSO": [Estado.ACTIVA, "fin_de_turno: +1 VELOCIDAD desde la segunda ronda"],
	"ARMADURABATALLA": [Estado.ACTIVA, "EfectosGolpe.golpe_critico: evita los golpes críticos"],
	"ROBUSTEZ": [Estado.ACTIVA, "EfectosGolpe.resolver_ko_directo: inmune a Fisura y similares"],
	"HUMEDAD": [Estado.ACTIVA, "EfectosGolpe.mensaje_bloqueo_autodestruccion"],
	"FLEXIBILIDAD": [Estado.ACTIVA, "habilidad_que_impide_estado: parálisis"],
	"VELOARENA": [Estado.ACTIVA, "precision_modificada: ×0.8 en tormenta de arena"],
	"ELECESTATICA": [Estado.ACTIVA, "tras_golpe: 1/3 de parálisis al contacto"],
	"ABSORBEELEC": [Estado.ACTIVA, "bloquear_movimiento: absorbe ELÉCTRICO y cura 1/4"],
	"ABSORBEAGUA": [Estado.ACTIVA, "bloquear_movimiento: absorbe AGUA y cura 1/4"],
	"DESPISTE": [Estado.ACTIVA, "evita GRAN ENCANTO (_enamorar)"],
	"ACLIMATACION": [Estado.ACTIVA, "CampoCombate.clima_efectivo: anula el clima"],
	"OJOCOMPUESTO": [Estado.ACTIVA, "precision_modificada: ×1.3"],
	"INSOMNIO": [Estado.ACTIVA, "habilidad_que_impide_estado: sueño"],
	"CAMBIOCOLOR": [Estado.ACTIVA, "tras_golpe: cambia al tipo del golpe recibido"],
	"INMUNIDAD": [Estado.ACTIVA, "habilidad_que_impide_estado: veneno"],
	"ABSORBEFUEGO": [Estado.ACTIVA, "bloquear_movimiento + multiplicador_absorbe_fuego"],
	"POLVOESCUDO": [Estado.ACTIVA, "EfectosGolpe.tras_dano: ignora los efectos secundarios"],
	"RITMOPROPIO": [Estado.ACTIVA, "EfectosGolpe.confundir: impide la confusión"],
	"VENTOSAS": [Estado.ACTIVA, "BattleTurnController._resolver_arrastre: impide Remolino y Rugido"],
	"INTIMIDACION": [Estado.ACTIVA, "al_entrar: -1 ATAQUE a los rivales"],
	"SOMBRATRAMPA": [Estado.ACTIVA, "impide_huida: huir y cambiar"],
	"PIELTOSCA": [Estado.ACTIVA, "tras_golpe: 1/16 de PS al atacante de contacto"],
	"SUPERGUARDA": [Estado.ACTIVA, "bloquear_movimiento: solo pasa lo superefectivo"],
	"LEVITACION": [Estado.ACTIVA, "bloquear_movimiento: inmune a TIERRA"],
	"EFECTOESPORA": [Estado.ACTIVA, "tras_golpe: 1/10 de sueño, veneno o parálisis"],
	"SINCRONIA": [Estado.ACTIVA, "sincronizar: devuelve veneno, quemadura y parálisis"],
	"CUERPOPURO": [Estado.ACTIVA, "impide_bajar_estadistica"],
	"CURANATURAL": [Estado.ACTIVA, "al_salir: cura el estado al retirarse"],
	"PARARRAYOS": [Estado.ACTIVA, "redirigir_ataque_electrico (combates dobles)"],
	"DICHA": [Estado.ACTIVA, "EfectosGolpe.tras_dano: duplica la probabilidad de efectos secundarios"],
	"NADORAPIDO": [Estado.ACTIVA, "velocidad_modificada: ×2 con lluvia"],
	"CLOROFILA": [Estado.ACTIVA, "velocidad_modificada: ×2 con sol"],
	"ILUMINACION": [Estado.FUERA_DE_COMBATE, "EfectosHabilidad.ajustar_probabilidad_encuentro: doble de encuentros"],
	"RASTRO": [Estado.ACTIVA, "al_entrar: copia la habilidad de un rival"],
	"POTENCIA": [Estado.ACTIVA, "ataque_modificado: ×2 físico"],
	"PUNTOTOXICO": [Estado.ACTIVA, "tras_golpe: 1/3 de veneno al contacto"],
	"FOCOINTERNO": [Estado.ACTIVA, "EfectosGolpe.tras_dano: impide el retroceso"],
	"ESCUDOMAGMA": [Estado.ACTIVA, "habilidad_que_impide_estado: congelación"],
	"VELOAGUA": [Estado.ACTIVA, "habilidad_que_impide_estado: quemadura"],
	"IMAN": [Estado.ACTIVA, "impide_huida: atrapa a los de tipo ACERO"],
	"INSONORIZAR": [Estado.ACTIVA, "bloquear_movimiento: movimientos sonoros"],
	"CURALLUVIA": [Estado.ACTIVA, "fin_de_turno: 1/16 de PS con lluvia"],
	"CHORROARENA": [Estado.ACTIVA, "al_entrar: provoca tormenta de arena"],
	"PRESION": [Estado.ACTIVA, "pp_extra_por_presion"],
	"SEBO": [Estado.ACTIVA, "ataque_modificado: ataques de FUEGO y HIELO a la mitad"],
	"MADRUGAR": [Estado.ACTIVA, "reduccion_sueno: despierta el doble de rápido"],
	"CUERPOLLAMA": [Estado.ACTIVA, "tras_golpe: 1/3 de quemadura al contacto"],
	"FUGA": [Estado.ACTIVA, "impide_huida: huye siempre"],
	"VISTALINCE": [Estado.ACTIVA, "impide_bajar_estadistica: precisión"],
	"CORTEFUERTE": [Estado.ACTIVA, "impide_bajar_estadistica: ataque"],
	"RECOGIDA": [Estado.FUERA_DE_COMBATE, "EfectosHabilidad.aplicar_recogida: objeto tras ganar"],
	"AUSENTE": [Estado.ACTIVA, "holgazanea / fin_de_turno: un turno sí y otro no"],
	"ENTUSIASMO": [Estado.ACTIVA, "ataque_modificado ×1.5 y precision_modificada ×0.8"],
	"GRANENCANTO": [Estado.ACTIVA, "tras_golpe: 1/3 de enamorar al contacto"],
	"MAS": [Estado.ACTIVA, "ataque_modificado: ×1.5 especial junto a MENOS"],
	"MENOS": [Estado.ACTIVA, "ataque_modificado: ×1.5 especial junto a MÁS"],
	"PREDICCION": [Estado.ACTIVA, "actualizar_prediccion: tipo y forma de CASTFORM según el clima"],
	"VISCOSIDAD": [Estado.ACTIVA, "EfectosGolpe.tras_dano: impide el robo de Ladrón y Antojo"],
	"MUDAR": [Estado.ACTIVA, "fin_de_turno: 1/3 de curar el estado"],
	"AGALLAS": [Estado.ACTIVA, "ataque_modificado ×1.5 y sin penalización de quemadura"],
	"ESCAMAESPECIAL": [Estado.ACTIVA, "defensa_modificada: ×1.5 físico con estado"],
	"LODOLIQUIDO": [Estado.ACTIVA, "EfectosGolpe.tras_dano: el drenaje le hace daño al atacante"],
	"ESPESURA": [Estado.ACTIVA, "potencia_modificada: PLANTA con 1/3 de PS"],
	"MARLLAMAS": [Estado.ACTIVA, "potencia_modificada: FUEGO con 1/3 de PS"],
	"TORRENTE": [Estado.ACTIVA, "potencia_modificada: AGUA con 1/3 de PS"],
	"ENJAMBRE": [Estado.ACTIVA, "potencia_modificada: BICHO con 1/3 de PS"],
	"CABEZAROCA": [Estado.ACTIVA, "EfectosGolpe.tras_dano: sin daño de retroceso"],
	"SEQUIA": [Estado.ACTIVA, "al_entrar: provoca sol"],
	"TRAMPAARENA": [Estado.ACTIVA, "impide_huida: atrapa a los que no levitan ni vuelan"],
	"ESPIRITUVITAL": [Estado.ACTIVA, "habilidad_que_impide_estado: sueño"],
	"HUMOBLANCO": [Estado.ACTIVA, "impide_bajar_estadistica"],
	"ENERGIAPURA": [Estado.ACTIVA, "ataque_modificado: ×2 físico"],
	"CAPARAZON": [Estado.ACTIVA, "EfectosGolpe.golpe_critico: evita los golpes críticos"],
	"CACOFONIA": [Estado.SIN_EFECTO_EN_ROM, "la ROM no le da ningún efecto"],
	"BUCLEAIRE": [Estado.ACTIVA, "CampoCombate.clima_efectivo: anula el clima"],
}


static func claves() -> Array:
	return REGISTRO.keys()


static func estado_de(clave: String) -> int:
	return int((REGISTRO.get(clave, [-1, ""]) as Array)[0])


static func donde(clave: String) -> String:
	return str((REGISTRO.get(clave, [-1, ""]) as Array)[1])


## Cuántas habilidades hay en cada estado: {Estado: n}.
static func resumen() -> Dictionary:
	var cuenta := {}
	for clave in REGISTRO:
		var e: int = int((REGISTRO[clave] as Array)[0])
		cuenta[e] = int(cuenta.get(e, 0)) + 1
	return cuenta
