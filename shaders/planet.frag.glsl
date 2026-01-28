#version 330

//
// Description : Array and textureless GLSL 2D/3D/4D simplex 
//               noise functions.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : stegu
//     Lastmod : 20201014 (stegu)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//               https://github.com/stegu/webgl-noise
// 

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
     return mod289(((x*34.0)+10.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
  return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v)
  { 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //   x0 = x0 - 0.0 + 0.0 * C.xxx;
  //   x1 = x0 - i1  + 1.0 * C.xxx;
  //   x2 = x0 - i2  + 2.0 * C.xxx;
  //   x3 = x0 - 1.0 + 3.0 * C.xxx;
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
  vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

// Permutations
  i = mod289(i); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients: 7x7 points over a square, mapped onto an octahedron.
// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
  float n_ = 0.142857142857; // 1.0/7.0
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
  //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.5 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 105.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
  }





vec2 sphIntersect( in vec3 ro, in vec3 rd, in vec3 ce, float ra ){
    vec3 oc = ro - ce;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - ra*ra;
    float h = b*b - c;
    if( h<0.0 ) return vec2(-1.0); // no intersection
    h = sqrt( h );
    return vec2( -b-h, -b+h );
}

float ridged(vec3 p, int octaves){
    float value = 0; 
    float frequency = 1.0f;
    float amplitude = 1.0f;
    for (int i = 0; i < octaves; i++){
        float val = snoise((p + i) * frequency); 
        val = 1-abs(val);
        val *= val;

        value += val * amplitude;
        amplitude /= 2;
        frequency *= 2;
    }
    return value;
}

mat3 rotation_mat(vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat3(
    oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  
    oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  
    oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c   
    );
}



vec3 ray_dir( float fov, vec2 size, vec2 pos ) {
	vec2 xy = pos - size * 0.5;

	float cot_half_fov = tan( radians( 90.0 - fov * 0.5 ) );	
	float z = size.y * -0.5 * cot_half_fov;
	
	return normalize( vec3( xy, -z ) );
}


uniform float time;
uniform vec2 resolution;
uniform vec3 camera_pos;
uniform vec3 camera_dir;

uniform vec3  body_origin;
uniform float body_radius;
uniform vec3  body_axis;
uniform float body_rotation_speed;
uniform vec3  body_color1;
uniform vec3  body_color2;
uniform vec3  sun_position;

uniform bool planet_has_sea;
uniform vec3 planet_sea_color;

uniform bool planet_has_atmosphere;
uniform vec3 planet_atmosphere_color;

uniform bool planet_has_ice_caps;
uniform vec3 planet_ice_color;


void main(){
    vec2 uv = gl_FragCoord.xy/resolution.y - vec2((resolution.x/resolution.y - 1.0)/2.0, 0);
    vec2 centered_uv = (uv - 0.5)*2;

    vec3 cam_right = normalize(cross(camera_dir, vec3(0, 1.0f, 0))); 
    vec3 cam_up = normalize(cross(cam_right, camera_dir));

    vec3 ray_origin = camera_pos;
    vec3 ray_direction = normalize(centered_uv.x * cam_right + centered_uv.y * cam_up + camera_dir );
    // vec3 ray_direction = normalize(camera_dir + ray_dir( 90.0, resolution.xy, gl_FragCoord.xy ));


    vec2 ground_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius);
    vec2 atm_intersection = vec2(0);
    vec2 closest_intersection = ground_intersection;

    if(planet_has_atmosphere){
        atm_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius * 1.1f);
        closest_intersection = atm_intersection; 
        if(atm_intersection.y < 0.0){
            discard;
        }
    }else{
        if(ground_intersection.y < 0.0){
            discard;
        }
    }
    

    float z_far = 1000.0;
    float z_near = 0.1;

    float A = (z_far + z_near) / (z_far - z_near);
    float B = (-2.0 * z_far * z_near) / (z_far - z_near);

    float depth = A + 1/closest_intersection.x * B;
    gl_FragDepth = depth;

    int octaves = 6 - clamp(int(sqrt(closest_intersection.x)), 0, 3);


    vec3 intersection_point = ray_origin + ray_direction * ground_intersection.x - body_origin; 

    vec3 sphere_normal = normalize(intersection_point); 
    vec3 tangent_right = normalize(cross(vec3(0, 1.0, 0), sphere_normal));
    vec3 tangent_up = normalize(cross(tangent_right, sphere_normal));
  
    intersection_point *= rotation_mat(body_axis, time * body_rotation_speed);
    float height = ridged(intersection_point, octaves);
    
    float eps = 0.0005;
    float height_north = ridged(intersection_point + eps * tangent_up, octaves);
    float height_south = ridged(intersection_point - eps * tangent_up, octaves);
    float height_east = ridged(intersection_point  + eps * tangent_right, octaves);
    float height_west = ridged(intersection_point  - eps * tangent_right, octaves);

    vec3 noise_normal = normalize(vec3(height_west - height_east, height_south - height_north, 0.05));
    vec3 normal = normalize(noise_normal.x * tangent_right + noise_normal.y * tangent_up + noise_normal.z * sphere_normal);

    vec3 ground_color = body_color1;

    if(planet_has_sea && height < 1.1){
        ground_color = planet_sea_color;
        normal = sphere_normal;
    }

    float polarness = abs(intersection_point.y) / (body_radius*0.8f);

    if(planet_has_ice_caps && polarness + height*0.1 > 1.0){
        ground_color = planet_ice_color;
    }

    vec3 sun_direction = normalize(sun_position - body_origin);
    
    float diffuse = max(0.0, dot(sphere_normal, sun_direction) * max(0.1, dot(normal, sun_direction ))  );
   
    float atm_thickness = atm_intersection.y - atm_intersection.x - (ground_intersection.y - ground_intersection.x); 


    float atm_factor = clamp(1.0 -exp(-atm_thickness * 0.4), 0, 1.0);

    if(ground_intersection.y < 0.0){ 
        gl_FragColor = vec4(mix(vec3(0), planet_atmosphere_color, atm_factor), 0.5);
    }else{
        gl_FragColor = vec4(mix(diffuse * ground_color, planet_atmosphere_color, planet_has_atmosphere? 0.2 : 0), 1.0);
    }
    // gl_FragColor = vec4(vec3(intersection_point), 1.0);
}
