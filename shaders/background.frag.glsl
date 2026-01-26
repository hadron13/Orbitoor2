#version 330

#define PI 3.14159


uniform vec2 resolution;
uniform float time;
uniform vec3 camera_pos;
uniform mat4 camera_transform;

float hash13(vec3 p3) {
    p3  = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f * f * (3.0 - 2.0 * f);  

    float n000 = hash13(p + vec3(0,0,0));
    float n100 = hash13(p + vec3(1,0,0));
    float n010 = hash13(p + vec3(0,1,0));
    float n110 = hash13(p + vec3(1,1,0));
    float n001 = hash13(p + vec3(0,0,1));
    float n101 = hash13(p + vec3(1,0,1));
    float n011 = hash13(p + vec3(0,1,1));
    float n111 = hash13(p + vec3(1,1,1));

    float c00 = mix(n000, n100, f.x);
    float c10 = mix(n010, n110, f.x);
    float c01 = mix(n001, n101, f.x);
    float c11 = mix(n011, n111, f.x);

    float c0 = mix(c00, c10, f.y);
    float c1 = mix(c01, c11, f.y);

    return mix(c0, c1, f.z) * 2.0 - 1.0;   // → centered [-1,1]
}

float ridged(vec3 p, float seed) {
    p *= 0.8;  // frequency
    
    float f = 0.0;
    float amp = 1.0;
    float weight = 1.0;
    
    for (int i = 0; i < 5; i++) {
        float n = abs(1.0 - abs(noise(p + seed)));   // ridge = 1 - |noise|
        n *= n;                                      // sharper ridges
        n *= weight;
        weight = clamp(n * 2.0, 0.0, 1.0);           // domain warp strength
        f += n * amp;
        amp *= 0.45;                                 // persistence < 0.5 → ridged look
        p *= mat3(1.1,0.4,-0.2, -0.3,1.2,0.1, 0.2,-0.1,1.3) * 2.3;  // rotate & scale
    }
    return f;
}

float planet_height(vec3 n) {
    float h  = ridged(n * 1.2, 17.3) * 0.07;
          h += ridged(n * 4.1, 41.1) * 0.025;
          h += ridged(n * 12.0, 133.7) * 0.008;
    return h;
}


float sphere(vec3 position, vec3 origin, float radius){
    return distance(position, origin) - radius;
}



float map(vec3 p, bool normal){

    vec3 planet_origin = vec3(0, 0, 1.0f);
    vec3 planet_normal = normalize(p - planet_origin);
    float planet_dist = distance(p, planet_origin);
    
    float height = 0;
    if(normal) height = planet_height(planet_normal);

    float surface_radius = 1.0 + height * 0.5;

    return sphere(p, planet_origin, surface_radius);
}

vec3 normal(vec3 position){
    float eps = 0.000001;
    return normalize(vec3( 
        map(position + vec3(eps, 0, 0), true) - map(position - vec3(eps, 0, 0), true),
        map(position + vec3(0, eps, 0), true) - map(position - vec3(0, eps, 0), true),
        map(position + vec3(0, 0, eps), true) - map(position - vec3(0, 0, eps), true)
    ));
}

float shadow(vec3 position, vec3 to_light_direction, float min_t, float max_t){
    float res = 1.0;
    float t = min_t;
    for(int i = 0; i < 32 && t < max_t; i++){
        float dist = map(position + to_light_direction * t, false);
        if(dist < 0.001){
            return 0.0;
        }
        t += max(0.001, dist);
        res = min( res, 16*dist/t );
    }
    return res;
}

//attenuation | diffuse | specular
vec3 light(vec3 position, vec3 direction, vec3 light_position){

    vec3 normal = normal(position);
    vec3 light_direction = normalize(light_position - position);
    vec3 halfway_direction = -normalize(-light_direction + direction);

    float light_distance = length(light_position - position);
    float attenuation = 0.3 / (0.3 + 0.2 * light_distance + 0.1 * light_distance * light_distance); 
    // float shadow = shadow(position, light_direction, 0.01, light_distance);
    float shadow = 1.0f;

    float shininess = pow(65535.0, 1.0 - 0.8);
    
    float spec_normalization = ((shininess + 2.0) * (shininess + 4.0)) / (8.0 * PI * (pow(2.0, -shininess * 0.5) + shininess));
    spec_normalization = max(spec_normalization - 0.3496155267919281, 0.0) * PI;

    float diffuse_factor = max(dot(normal, light_direction), 0)  * shadow;
    float specular_factor = pow(max(dot(normal, halfway_direction), 0.0), shininess) * diffuse_factor * spec_normalization;
    return vec3(attenuation, diffuse_factor, specular_factor);
}


vec3 render(vec3 position, vec3 dir){
    
    vec3 light_color = vec3(1.0);
    vec3 light_position = vec3(sin(time/30)*2.0, 0.5f, cos(time/30)*2.0f + 1.0);
    vec3 light_position1 = vec3(sin(time/30+PI/2)*2.0f, 0.5f, cos(time/30+PI/2)*2.0f + 1.0);

    vec3 light_calc = light(position, dir, light_position);
    vec3 light_calc1 = light(position, dir, light_position1);

    float attenuation = light_calc.x + light_calc1.x;
    float diffuse_factor = light_calc.y + light_calc1.y;
    float specular_factor = light_calc.z + light_calc1.z;

    vec3 albedo = vec3(0.718,0.667,0.635);

    vec3 ambient  = 0.005  * attenuation * albedo;
    vec3 diffuse  = 0.40  * attenuation * diffuse_factor * albedo;
    vec3 specular = 0.01  * attenuation * specular_factor * light_color;


    vec3 color = mix(ambient + diffuse + specular, specular_factor * albedo, 0.0);
    return color;
}


void main(){
    vec2 uv = gl_FragCoord.xy/resolution.y - vec2((resolution.x/resolution.y - 1.0)/2.0, 0);
    vec2 centered_uv = (uv - 0.5)*2;

    vec3 ray_origin = vec3(0, 0, -1.0) + camera_pos;  
    vec3 ray_direction = (vec4(normalize(vec3(centered_uv, 1.0)), 1.0) * camera_transform).xyz;
    float t = 0;

    vec3 color = vec3(0);

    for(int steps = 0; steps < 32 && t < 4; steps++){
        float dist = map(ray_origin + ray_direction * t, false);

        if(dist < 0.01){
            color = render(ray_origin + ray_direction * t, ray_direction);
            break;
        }
        t+=dist;
        // t += max(0.001, dist);
    }


    // gl_FragColor = vec4(color, 1.0);
    gl_FragColor = vec4(1.0, 0, 0, 1.0);
}
