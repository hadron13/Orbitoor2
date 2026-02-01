#version 330

in vec3 normal;
in vec3 position;

uniform vec3 camera_pos;
uniform samplerCube skybox;

void main(){
    vec3 I = normalize(position - camera_pos);
    vec3 R = reflect(I, normalize(normal));
    gl_FragColor = texture(skybox, R) * vec4(vec3(0.1), 1.0);
    // gl_FragColor = vec4(position, 1.0);
}
