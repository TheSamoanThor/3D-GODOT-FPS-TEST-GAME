shader_type canvas_item;

// Сюда мы закинем вашу картинку сот из Figma
uniform sampler2D hex_texture : repeat_enable, filter_linear;
uniform vec4 shield_color : source_color = vec4(0.0, 0.6, 1.0, 1.0); // Голубое или зеленое свечение
uniform vec2 texture_scale = vec2(5.0, 5.0); // Масштаб/количество сот на экране
uniform float pulse_speed = 1.5; // Скорость пульсации энергии щита

void fragment() {
	// 1. Масштабируем UV-координаты, чтобы соты красиво размножались
	vec2 scaled_uv = UV * texture_scale;
	
	// 2. Читаем текстуру сот из Figma
	vec4 hex_mask = texture(hex_texture, scaled_uv);
	
	// 3. Создаем эффект плавного размытия к краям (чтобы соты угасали у границ панели)
	// Математически вычисляем дистанцию от центра панели к ее краям
	vec2 center_dist = abs(UV - vec2(0.5));
	float edge_fade = smoothstep(0.5, 0.2, max(center_dist.x, center_dist.y));
	
	// 4. Добавляем мягкую пульсацию энергии во времени через sin()
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;
	
	// 5. Собираем финальный цвет: берем цвет щита, накладываем соты и применяем растворение краев
	vec4 final_color = shield_color;
	
	// Если на картинке из Figma соты черные, используем (1.0 - hex_mask.r)
	final_color.a = (1.0 - hex_mask.r) * shield_color.a * edge_fade * pulse;
	
	COLOR = final_color;
}
