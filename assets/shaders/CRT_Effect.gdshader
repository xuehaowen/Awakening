shader_type canvas_item;

// CRT Monitor Effect Shader
// Features: Scanlines, chromatic aberration, vignette, curvature, noise

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_count : hint_range(100.0, 2000.0) = 800.0;
uniform float chromatic_aberration : hint_range(0.0, 5.0) = 1.2;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_size : hint_range(0.0, 2.0) = 1.2;
uniform float curvature : hint_range(0.0, 0.1) = 0.02;
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.03;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float brightness : hint_range(0.5, 1.5) = 1.1;
uniform float contrast : hint_range(0.5, 2.0) = 1.2;
uniform vec4 tint_color : source_color = vec4(0.9, 1.0, 0.95, 1.0);
uniform bool enabled = true;

// Random function for noise
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Screen curvature distortion
vec2 curved_uv(vec2 uv) {
    vec2 delta = uv - 0.5;
    float dist = dot(delta, delta);
    return uv + delta * dist * curvature;
}

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }
    
    vec2 uv = UV;
    
    // Apply screen curvature
    uv = curved_uv(uv);
    
    // Chromatic aberration (RGB shift)
    float aberration = chromatic_aberration / 1000.0;
    vec2 uv_r = uv + vec2(aberration, 0.0);
    vec2 uv_b = uv - vec2(aberration, 0.0);
    
    // Sample texture with chromatic shift
    float r = texture(TEXTURE, uv_r).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, uv_b).b;
    
    vec3 color = vec3(r, g, b);
    
    // Scanlines
    float scanline = sin(uv.y * scanline_count * PI * 2.0);
    scanline = (scanline * 0.5 + 0.5) * (1.0 - scanline_intensity) + scanline_intensity;
    color *= scanline;
    
    // Vignette
    vec2 vignette_uv = uv * (1.0 - uv.xy);
    float vignette = vignette_uv.x * vignette_uv.y * 15.0;
    vignette = pow(vignette, vignette_size);
    color *= vignette * (1.0 - vignette_intensity) + vignette_intensity;
    
    // Film noise
    float noise = random(uv + vec2(TIME * 0.1, TIME * 0.1));
    color += (noise - 0.5) * noise_intensity;
    
    // Screen flicker
    float flicker = 1.0 + sin(TIME * 10.0) * flicker_intensity * 0.5;
    color *= flicker;
    
    // Brightness and contrast
    color = (color - 0.5) * contrast + 0.5;
    color *= brightness;
    
    // Apply tint
    color *= tint_color.rgb;
    
    // Clamp values
    color = clamp(color, 0.0, 1.0);
    
    // Check if UV is out of bounds (for curved screen edges)
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        color = vec3(0.0);
    }
    
    COLOR = vec4(color, 1.0);
}
