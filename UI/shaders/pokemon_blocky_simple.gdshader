shader_type canvas_item;

// Parámetro que controla el progreso de la transición (0.0 = muy pixelado, 1.0 = resolución original)
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

// Resolución del sprite (por defecto 64x64, ajustable)
uniform float sprite_resolution : hint_range(8.0, 128.0) = 64.0;

// Offset para movimiento en espiral
uniform float base_offset_pixels : hint_range(0.0, 32.0) = 8.0;

void fragment() {
    // Normalizar coordenadas UV
    vec2 normalized_uv = UV;
    
    // Movimiento en espiral con centro fijo
    vec2 base_offset_uv = vec2(base_offset_pixels) / sprite_resolution;
    
    // El radio disminuye de máximo a 0 conforme progresa
    float spiral_radius = (1.0 - transition_progress) * length(base_offset_uv);
    
    // El ángulo inicial para empezar desde abajo-derecha
    float initial_angle = -3.14159 / 4.0; // -45 grados para abajo-derecha
    
    // El sprite da una vuelta completa (2π) durante la transición
    float spiral_angle = initial_angle + (transition_progress * 3.14159 * 2.0);
    
    // Calcular desplazamiento en espiral puro (centro fijo en 0,0)
    vec2 spiral_offset = vec2(
        cos(spiral_angle) * spiral_radius,
        sin(spiral_angle) * spiral_radius
    );
    
    // Aplicar el desplazamiento
    vec2 displaced_uv = normalized_uv + spiral_offset;
    
    // Verificar límites UV
    bool is_out_of_bounds = (displaced_uv.x < 0.0 || displaced_uv.x > 1.0 || displaced_uv.y < 0.0 || displaced_uv.y > 1.0);
    
    if (is_out_of_bounds) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparente si está fuera de límites
    } else {
        // Blocky dissolve progresivo SIMPLE - reducir tamaño de bloques gradualmente
        // SIN revelar pixel por pixel, SOLO reducción de tamaño de bloques
        
        // PROTECCIÓN: Validar transition_progress
        float safe_progress = clamp(transition_progress, 0.0, 1.0);
        
        // Calcular el tamaño de bloque basado en el progreso
        float max_block_size = 4.0;  // Tamaño máximo de bloque (MUY grande al inicio)
        float min_block_size = 64.0; // Tamaño mínimo (resolución completa al final)
        
        // NUEVO: Aplicar curva de easing para que los bloques grandes duren más tiempo
        // Usar una curva exponencial: los bloques grandes se mantienen más tiempo,
        // luego aceleran rápidamente hacia bloques pequeños
        float eased_progress = safe_progress * safe_progress * safe_progress; // Curva cúbica
        
        // Interpolación con curva: empezar con bloques grandes (más tiempo), terminar rápido con bloques pequeños
        // Al inicio (progress=0.0): eased_progress ≈ 0.0, block_size = 4.0 (MUY PIXELADO - dura más)
        // Al final (progress=1.0): eased_progress = 1.0, block_size = 64.0 (ALTA RESOLUCIÓN - llega rápido)
        float block_size = mix(max_block_size, min_block_size, eased_progress);
        
        // PROTECCIÓN: Validar block_size
        block_size = clamp(block_size, 1.0, 64.0);
        
        // PROTECCIÓN: Validar displaced_uv antes de usar
        vec2 safe_displaced_uv = clamp(displaced_uv, 0.0, 1.0);
        
        // Aplicar pixelación con el tamaño de bloque calculado
        if (block_size > 1.5) { // Usar umbral más seguro
            vec2 pixelated_uv = floor(safe_displaced_uv * block_size) / block_size;
            // PROTECCIÓN ADICIONAL: Verificar que pixelated_uv sea válido
            if (pixelated_uv.x >= 0.0 && pixelated_uv.x <= 1.0 && pixelated_uv.y >= 0.0 && pixelated_uv.y <= 1.0) {
                COLOR = texture(TEXTURE, pixelated_uv);
            } else {
                // Fallback: usar coordenadas seguras
                COLOR = texture(TEXTURE, safe_displaced_uv);
            }
        } else {
            // Resolución completa
            COLOR = texture(TEXTURE, safe_displaced_uv);
        }
    }
}
