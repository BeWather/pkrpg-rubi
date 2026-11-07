# Interiores de bases secretas — recursos generados

Las 24 escenas de esta carpeta se importaron inicialmente con
`herramientas/importar_interiores_bases_secretas.py` y **son editables en Godot**.
El importador conserva escenas existentes por defecto. `--regenerar-escenas`
las reemplaza explícitamente; guardar/cotejar tus ediciones antes de usarlo.
`--check` valida assets y presencia de escenas; `--check-escenas` compara también
el texto con la plantilla original, por lo que puede diferir tras personalizarlas.

- Celdas locales conservan x/y del diseño GBA, sin sumar su borde interno +7.
- `Fondo`, `Suelo` y `Superior` mantienen la composición de capas original.
- `NPCs` usa z=1/Y-sort; TPTileDataMap controla la colisión del proyecto.
- PC e InicioConfirmado son marcadores con coordenadas originales.
- Salida es un `SalidaBaseSecreta` (tipo SALIDAS), declarado y editable. No tiene
  destino fijo: devuelve al mapa/celda/capa/dirección del contexto de origen.
- El componente `MapaDecoracion` y su contenedor `NPCs/Decoraciones` son declarados.
  Sus referencias se pueden revisar en el inspector; no crea nuevas capas en `_ready`.

La raíz `InteriorBaseSecreta` declara ID y referencia a `MapaDecoracion`.
El administrador llama `preparar_entrada(contexto)` **antes** de añadirla al árbol:
valida origen/propiedad y reconstruye decoración antes de `_ready` y activación.
Sin contexto válido se rechaza la navegación sin destruir el mapa anterior.
Entradas confirmadas registran retorno/visita solo en la activación efectiva.

**La navegación interna está conectada, pero no hay aún una entrada jugable en ruta
ni editor/PC ni confirmación de vista previa.** No probar guardado/retorno arrancando
F6 o CONTINUAR dentro como si esa carga ya estuviera implementada (tarea 4.6).
La entrada declarativa reutilizable está en `escenas/bases_secretas/entrada_base_secreta.tscn`;
vinculación, gráficos y examen comienzan en 4.2.

Revisión visual estática: `documentacion/bases_secretas/interiores_importados.png`.
No es una captura de ejecución Godot.
