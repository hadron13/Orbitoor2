#version 330

uniform vec2 resolution;
uniform vec3 camera_dir;
uniform samplerCube skybox;

void main(){
    vec2 uv = gl_FragCoord.xy/resolution.y - vec2((resolution.x/resolution.y - 1.0)/2.0, 0);
    vec2 centered_uv = (uv - 0.5)*2;

    vec3 cam_right = normalize(cross(camera_dir, vec3(0, 1.0f, 0))); 
    vec3 cam_up = normalize(cross(cam_right, camera_dir));

    vec3 ray_direction = normalize(centered_uv.x * cam_right + centered_uv.y * cam_up + camera_dir );

    gl_FragColor = texture(skybox, ray_direction) * vec4(vec3(0.1), 1.0);
    // gl_FragColor = vec4(ray_direction, 1.0);
}
