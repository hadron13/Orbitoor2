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
    return mod289(((x * 34.0) + 10.0) * x);
}

vec4 taylorInvSqrt(vec4 r)
{
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v)
{
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    //   x0 = x0 - 0.0 + 0.0 * C.xxx;
    //   x1 = x0 - i1  + 1.0 * C.xxx;
    //   x2 = x0 - i2  + 2.0 * C.xxx;
    //   x3 = x0 - 1.0 + 3.0 * C.xxx;
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
    vec3 x3 = x0 - D.yyy; // -1.0+3.0*C.x = -0.5 = -D.y

    // Permutations
    i = mod289(i);
    vec4 p = permute(permute(permute(
                    i.z + vec4(0.0, i1.z, i2.z, 1.0))
                    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
                + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float n_ = 0.142857142857; // 1.0/7.0
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z); //  mod(p,7*7)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_); // mod(j,N)

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
    //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    //Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.5 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 105.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1),
                dot(p2, x2), dot(p3, x3)));
}

float fbm(vec3 p, int octaves) {
    float value = 0;
    float frequency = 1.0f;
    float amplitude = 0.5f;
    for (int i = 0; i < octaves; i++) {
        float val = snoise((p + i) * frequency);

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
        oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s,
        oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s,
        oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c
    );
}

vec2 sphIntersect(in vec3 ro, in vec3 rd, in vec3 ce, float ra) {
    vec3 oc = ro - ce;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - ra * ra;
    float h = b * b - c;
    if (h < 0.0) return vec2(-1.0); // no intersection
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

vec3 ray_dir(float fov, vec2 size, vec2 pos) {
    vec2 xy = pos - size * 0.5;

    float cot_half_fov = tan(radians(90.0 - fov * 0.5));
    float z = size.y * -0.5 * cot_half_fov;

    return normalize(vec3(xy, -z));
}

uniform sampler2D colormap;
uniform sampler2D heightmap;

uniform float time;
uniform vec2 resolution;
uniform vec3 camera_pos;
uniform vec3 camera_dir;

uniform vec3 body_origin;
uniform float body_radius;
uniform vec3 body_axis;
uniform float body_rotation_speed;
uniform vec3 body_color1;
uniform vec3 body_color2;
uniform vec3 sun_position;

uniform vec3 light_positions[8];
uniform vec4 light_colors[8];

uniform bool planet_has_sea;
uniform vec3 planet_sea_color;

uniform bool planet_has_atmosphere;
uniform float planet_atmosphere_radius;
uniform vec3 planet_atmosphere_color;


uniform sampler2D transmittance_lut;
uniform sampler2D multiscatter_lut;

const float PI = 3.14159265358;

// Units are in megameters.
const float groundRadiusMM = 6.360;
const float atmosphereRadiusMM = 6.460;

// 200M above the ground.
const vec3 viewPos = vec3(0.0, groundRadiusMM + 0.0002, 0.0);

const vec2 tLUTRes = vec2(256.0, 64.0);
const vec2 msLUTRes = vec2(32.0, 32.0);


const vec3 groundAlbedo = vec3(0.3);

// These are per megameter.
const vec3 rayleighScatteringBase = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase = 0.0;

const float mieScatteringBase = 3.996;
const float mieAbsorptionBase = 4.4;

const vec3 ozoneAbsorptionBase = vec3(0.650, 1.881, .085);


float getMiePhase(float cosTheta) {
    const float g = 0.8;
    const float scale = 3.0/(8.0*PI);

    float num = (1.0-g*g)*(1.0+cosTheta*cosTheta);
    float denom = (2.0+g*g)*pow((1.0 + g*g - 2.0*g*cosTheta), 1.5);

    return scale*num/denom;
}

float getRayleighPhase(float cosTheta) {
    const float k = 3.0/(16.0*PI);
    return k*(1.0+cosTheta*cosTheta);
}

void getScatteringValues(vec3 pos,
                         out vec3 rayleighScattering,
                         out float mieScattering,
                         out vec3 extinction) {
    float altitudeKM = (length(pos)-groundRadiusMM)*1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM/8.0);
    float mieDensity = exp(-altitudeKM/1.2);

    rayleighScattering = rayleighScatteringBase*rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase*rayleighDensity;

    mieScattering = mieScatteringBase*mieDensity;
    float mieAbsorption = mieAbsorptionBase*mieDensity;

    vec3 ozoneAbsorption = ozoneAbsorptionBase*max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}

float safeacos(const float x) {
    return acos(clamp(x, -1.0, 1.0));
}

// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(vec3 ro, vec3 rd, float rad) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad*rad;
    if (c > 0.0f && b > 0.0) return -1.0;
    float discr = b*b - c;
    if (discr < 0.0) return -1.0;
    // Special case: inside sphere, use far discriminant
    if (discr > b*b) return (-b + sqrt(discr));
    return -b - sqrt(discr);
}

// From https://www.shadertoy.com/view/wlBXWK
vec2 rayIntersectSphere2D(
    vec3 start, // starting position of the ray
    vec3 dir, // the direction of the ray
    float radius // and the sphere radius
) {
    // ray-sphere intersection that assumes
    // the sphere is centered at the origin.
    // No intersection when result.x > result.y
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (radius * radius);
    float d = (b*b) - 4.0*a*c;
    if (d < 0.0) return vec2(1e5,-1e5);
    return vec2(
        (-b - sqrt(d))/(2.0*a),
        (-b + sqrt(d))/(2.0*a)
    );
}


/*
 * Same parameterization here.
 */
vec3 getValFromTLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
	float sunCosZenithAngle = dot(sunDir, up);
    vec2 uv = vec2(tLUTRes.x*clamp(0.5 + 0.5*sunCosZenithAngle, 0.0, 1.0),
                   tLUTRes.y*max(0.0, min(1.0, (height - groundRadiusMM)/(atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return texture(tex, uv).rgb;
}
vec3 getValFromMultiScattLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
	float sunCosZenithAngle = dot(sunDir, up);
    vec2 uv = vec2(msLUTRes.x*clamp(0.5 + 0.5*sunCosZenithAngle, 0.0, 1.0),
                   msLUTRes.y*max(0.0, min(1.0, (height - groundRadiusMM)/(atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return texture(tex, uv).rgb;
}



vec3 raymarchScattering(sampler2D TLUT, vec2 TLUT_size, sampler2D MSLUT, vec2 MSLUT_size,
                              vec3 viewPos,
                              vec3 rayDir,
                              vec3 sunDir,
                              float numSteps,
                              out vec3 transmittance) {


    vec2 atmos_intercept = rayIntersectSphere2D(viewPos, rayDir, atmosphereRadiusMM);
    float terra_intercept = rayIntersectSphere(viewPos, rayDir, groundRadiusMM);

    float mindist, maxdist;

    if (atmos_intercept.x < atmos_intercept.y){
        // there is an atmosphere intercept!
        // start at the closest atmosphere intercept
        // trace the distance between the closest and farthest intercept
        mindist = atmos_intercept.x > 0.0 ? atmos_intercept.x : 0.0;
		maxdist = atmos_intercept.y > 0.0 ? atmos_intercept.y : 0.0;
    } else {
        // no atmosphere intercept means no atmosphere!
        return vec3(0.0);
    }

    // if in the atmosphere start at the camera
    if (length(viewPos) < atmosphereRadiusMM) mindist=0.0;


    // if there's a terra intercept that's closer than the atmosphere one,
    // use that instead!
    if (terra_intercept > 0.0){ // confirm valid intercepts
        maxdist = terra_intercept;
    }

    // start marching at the min dist
    vec3 pos = viewPos + mindist * rayDir;

    float cosTheta = dot(rayDir, sunDir);

	float miePhaseValue = getMiePhase(cosTheta);
	float rayleighPhaseValue = getRayleighPhase(-cosTheta);

    vec3 lum = vec3(0.0);
    transmittance = vec3(1.0);
    float t = 0.0;
    for (float i = 0.0; i < numSteps; i += 1.0) {
        float newT = ((i + 0.3)/numSteps)*(maxdist-mindist);
        float dt = newT - t;
        t = newT;

        vec3 newPos = pos + t*rayDir;

        vec3 rayleighScattering, extinction;
        float mieScattering;

        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        vec3 sampleTransmittance = exp(-dt*extinction);

        vec3 sunTransmittance = getValFromTLUT(TLUT, TLUT_size, newPos, sunDir);
        vec3 psiMS = 0.0*getValFromMultiScattLUT(MSLUT, MSLUT_size, newPos, sunDir);

        vec3 rayleighInScattering = rayleighScattering*(rayleighPhaseValue*sunTransmittance + psiMS);
        vec3 mieInScattering = mieScattering*(miePhaseValue*sunTransmittance + psiMS);
        vec3 inScattering = (rayleighInScattering + mieInScattering);

        // Integrated scattering within path segment.
        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral*transmittance;

        transmittance *= sampleTransmittance;
    }
    return lum;
}


vec3 jodieReinhardTonemap(vec3 c){
    // From: https://www.shadertoy.com/view/tdSXzD
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);
    return mix(c / (l + 1.0), tc, tc);
}


void main() {
    vec2 uv = gl_FragCoord.xy / resolution.y - vec2((resolution.x / resolution.y - 1.0) / 2.0, 0);
    vec2 centered_uv = (uv - 0.5) * 2;

    vec3 cam_right = normalize(cross(camera_dir, vec3(0, 1.0f, 0)));
    vec3 cam_up = normalize(cross(cam_right, camera_dir));

    vec3 ray_origin = camera_pos;
    vec3 rd = ray_dir(90.0, vec2(1.0), uv);
    vec3 ray_direction = rd.x * cam_right + rd.y * cam_up + rd.z * camera_dir;
    // vec3 ray_direction = normalize(centered_uv.x * cam_right + centered_uv.y * cam_up + camera_dir );
    // vec3 ray_direction = normalize(camera_dir + ray_dir( 90.0, resolution.xy, gl_FragCoord.xy ));

    vec2 ground_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius);
    vec2 atm_intersection = vec2(0);
    vec2 closest_intersection = ground_intersection;

    if (planet_has_atmosphere) {
        atm_intersection = sphIntersect(ray_origin, ray_direction, body_origin, planet_atmosphere_radius);
        closest_intersection = atm_intersection;
        if (atm_intersection.y < 0.0) {
            discard;
        }
    } else {
        if (ground_intersection.y < 0.0) {
            discard;
        }
    }

    float z_far = 100000000.0;
    float z_near = 0.1;

    float A = (z_far + z_near) / (z_far - z_near);
    float B = (-2.0 * z_far * z_near) / (z_far - z_near);

    float depth = A + 1 / closest_intersection.x * B;
    gl_FragDepth = depth;

    int octaves = 7 - clamp(int(sqrt(closest_intersection.x / body_radius)), 0, 3);

    vec3 intersection_point = normalize(ray_origin + ray_direction * ground_intersection.x - body_origin);

    vec3 sphere_normal = normalize(intersection_point);

    vec2 map_uv = vec2(
            atan(sphere_normal.z, sphere_normal.x) / (PI * 2.0),
            acos(-sphere_normal.y) / PI
        );

    map_uv.x += time / 300.0;

    vec3 tangent_right = normalize(cross(vec3(0, 1.0, 0), sphere_normal));
    vec3 tangent_up = normalize(cross(tangent_right, sphere_normal));

    intersection_point *= rotation_mat(body_axis, time * body_rotation_speed);

    float eps = 0.001;

    float height = texture2D(heightmap, map_uv).r;
    float height_west = texture2D(heightmap, map_uv - vec2(-eps, 0.0)).r;
    float height_east = texture2D(heightmap, map_uv - vec2(eps, 0.0)).r;
    float height_north = texture2D(heightmap, map_uv - vec2(0.0, eps)).r;
    float height_south = texture2D(heightmap, map_uv - vec2(0.0, -eps)).r;

    vec3 noise_normal = normalize(vec3(height_west - height_east, height_south - height_north, 0.05));
    vec3 normal = normalize(noise_normal.x * tangent_right + noise_normal.y * tangent_up + noise_normal.z * sphere_normal);

    float sea_height = 0.55;
    vec3 surface_color = height > sea_height ? texture2D(colormap, map_uv).rgb : vec3(0.05, 0.05, 0.8);
    if (height < sea_height)
        normal = sphere_normal;

    float diffuse = 0;
    float specular = 0;
    for (int i = 0; i < 8; i++) {
        vec3 to_light = light_positions[i] - body_origin;
        float distance = length(to_light);
        float attenuation = 1.0 / (distance * distance);

        vec3 light_direction = normalize(to_light);
        vec3 halfway_direction = -normalize(-light_direction + ray_direction);

        diffuse += max(0.0, dot(sphere_normal, light_direction) * max(0.1, dot(normal, light_direction))) * light_colors[i].w * attenuation;
    }

    vec3 light_dir = normalize(light_positions[0] - body_origin);

    vec3 eye = ((ray_origin - body_origin) / body_radius) * 6.360;

    vec3 transmittance;
    vec3 scatter = raymarchScattering(transmittance_lut, tLUTRes, multiscatter_lut, msLUTRes, eye, ray_direction, light_dir, 64.0, transmittance);


    // vec3 sunTransmittance = getValFromTLUT(TLUT, TLUT_size, newPos, sunDir);
    // scatter = jodieReinhardTonemap(scatter);

    if (ground_intersection.y < 0.0) {
        // gl_FragColor = vec4( length(eye) - 2.0, 0, 0, 1.0);
        gl_FragColor = vec4(jodieReinhardTonemap(scatter * 20), step(0.0001, length(scatter)));
        // gl_FragColor = vec4(atm_intersection.y / body_radius, 0, 0, 0.5);
    } else {
        vec3 cloud_point = intersection_point * vec3(1.5, 2.5, 1.5) + 40.0;
        float cloud_thickness = fbm(cloud_point + fbm(cloud_point * 0.75 + time / 100.0 + fbm(cloud_point * 0.25 - time / 200.0, 2), 3), 4) + max(0.0, fbm(cloud_point * 2.0, 5));

        float cloud_factor = clamp(1.0 - exp(-3.0 * cloud_thickness), 0.0, 1.0);
        // cloud_factor = cloud_thickness;

        vec3 ground_color = diffuse * mix(surface_color, vec3(1.0), 0.0);

        vec3 combined_color = ground_color * transmittance + scatter * 20;

        gl_FragColor = vec4(jodieReinhardTonemap(combined_color), 1.0);
    }
    // gl_FragColor = vec4(vec3(texture2D(heightmap, map_uv).r), 1.0);
    // gl_FragColor = vec4(centered_uv, 0, 1.0);
}
