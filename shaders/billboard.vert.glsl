#version 330

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTex;

out vec2 texCoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

void main(){
    texCoord = aTex;
    mat4 model_view = view * model;
    

    // Column 0:
    model_view[0][0] = 1;
    model_view[0][1] = 0;
    model_view[0][2] = 0;

    // Column 1:
    model_view[1][0] = 0;
    model_view[1][1] = 1;
    model_view[1][2] = 0;

    // Column 2:
    model_view[2][0] = 0;
    model_view[2][1] = 0;
    model_view[2][2] = 1;

    gl_Position = proj * model_view * vec4(aPos*2, 1.0);
}
