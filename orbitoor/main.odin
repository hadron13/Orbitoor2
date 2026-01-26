package orbitoor


import "vendor:sdl3"
import gl "vendor:OpenGL"
import "core:fmt"
import "core:os"
import "core:time"
import "core:c"
import "core:math"
import glm "core:math/linalg/glsl"


vec2 :: [2]f32
vec3 :: [3]f32
color :: [4]f32

body :: struct{
    mass : f32,
    position : vec3,
    velocity : vec3
}

celestial_body_type :: enum{    
    STAR, PLANET
}


celestial_body :: struct{
    type : celestial_body_type,
    temperature : f32,
    primary_color : color,
    secondary_color: color, 
}



camera :: struct{
    position : [3]f32, 
    velocity : [3]f32,
    yaw,pitch: f32,
    fov      : f32,
}

main_camera : camera

camera_update :: proc"c"(camera : ^camera, delta_time : f32) -> (glm.mat4, vec3){

    front :[3]f32= glm.normalize(
    [3]f32{math.cos(glm.radians(camera.yaw)) * math.cos(glm.radians(camera.pitch)),
           math.sin(glm.radians(camera.pitch)),
           math.sin(glm.radians(camera.yaw)) * math.cos(glm.radians(camera.pitch))})
    
    front_straight := glm.normalize([3]f32{front.x, 0, front.z})

    up := [3]f32{0, 1, 0} 
    right := glm.normalize(glm.cross(up, front_straight))

    camera.position -= right          * main_camera.velocity.x * delta_time
    camera.position += up             * main_camera.velocity.y * delta_time
    camera.position -= front_straight * main_camera.velocity.z * delta_time 

    return glm.mat4LookAt(main_camera.position, main_camera.position + front, {0, 1, 0}), front

}

main :: proc(){
    if(!sdl3.Init({.VIDEO , .EVENTS})){
        return
    }
    defer sdl3.Quit()
    
    sdl3.GL_SetAttribute(sdl3.GLAttr.CONTEXT_MAJOR_VERSION, 3)
    sdl3.GL_SetAttribute(sdl3.GLAttr.CONTEXT_MINOR_VERSION, 3)
    sdl3.GL_SetAttribute(sdl3.GLAttr.CONTEXT_PROFILE_MASK, i32(sdl3.GLProfile.CORE))
    sdl3.GL_SetAttribute(sdl3.GLAttr.FRAMEBUFFER_SRGB_CAPABLE, 1)

    window := sdl3.CreateWindow("Orbitoor", 800, 1000, {.OPENGL, .RESIZABLE})
    defer sdl3.DestroyWindow(window)

    gl_context := sdl3.GL_CreateContext(window)
    defer sdl3.GL_DestroyContext(gl_context)

    sdl3.GL_SetSwapInterval(-1)
   
    gl.load_up_to(3, 3, sdl3.gl_set_proc_address)

    fmt.printfln("loaded OpenGL version %s", gl.GetString(gl.VERSION))
    fmt.printfln("vendor: %s", gl.GetString(gl.VENDOR) )
    
    gl.Enable(gl.FRAMEBUFFER_SRGB)

    quad : []f32 = {
       -1.0,-1.0, 0, 0, 0,
       -1.0, 1.0, 0, 0, 1,
        1.0,-1.0, 0, 1, 0,
        1.0,-1.0, 0, 1, 0,
       -1.0, 1.0, 0, 0, 1,
        1.0, 1.0, 0, 1, 1
    }
    
    quad_vbo, quad_vao: u32
    gl.GenVertexArrays(1, &quad_vao)
    gl.GenBuffers(1, &quad_vbo)
    
    gl.BindVertexArray(quad_vao)
    
    gl.BindBuffer(gl.ARRAY_BUFFER, quad_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(quad) * size_of(f32), raw_data(quad), gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)




    VERTEX_SHADER_PATH :: "shaders/billboard.vert.glsl"
    FRAGMENT_SHADER_PATH :: "shaders/planet.frag.glsl"

    shader, ok := gl.load_shaders_file(VERTEX_SHADER_PATH, FRAGMENT_SHADER_PATH)
    uniforms := gl.get_uniforms_from_program(shader)

    if !ok {
        a, b, c, d := gl.get_last_error_messages()
        fmt.printfln("Could not compile shaders\n %s\n %s", a, c)
        return
    }else{
        fmt.printfln("Shaders loaded")
    }
    stat, err := os.stat(FRAGMENT_SHADER_PATH)
    last_modification := stat.modification_time

    width, height : c.int
    sdl3.GetWindowSize(window, &width, &height)


    main_camera = {{0, 0, -2.0}, {0, 0, 0}, 0, 0, 90}

    loop:
    for{
        event : sdl3.Event
        for sdl3.PollEvent(&event){
            #partial switch(event.type){
                case .QUIT:
                    break loop
                case .KEY_UP:
                    if(event.key.key == sdl3.GetKeyFromName("r")){
                        shader, ok = gl.load_shaders_file(VERTEX_SHADER_PATH, FRAGMENT_SHADER_PATH)
                        uniforms = gl.get_uniforms_from_program(shader)

                        if !ok {
                            a, b, c, d := gl.get_last_error_messages()
                            fmt.printfln("Could not compile shaders\n %s\n %s", a, c)
                        }else{
                            fmt.printfln("Shaders loaded")
                        }
                    }
                    switch(event.key.key){
                    case sdl3.K_W: main_camera.velocity.z = 0
                    case sdl3.K_A: main_camera.velocity.x = 0
                    case sdl3.K_S: main_camera.velocity.z = 0
                    case sdl3.K_D: main_camera.velocity.x = 0
                    
                    case sdl3.K_SPACE: main_camera.velocity.y = 0
                    case sdl3.K_C: main_camera.velocity.y = 0
                    
                    case sdl3.K_Z: main_camera.fov = 90 

                    case sdl3.K_F6: gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
                    case sdl3.K_F7: gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
                        
                    case sdl3.K_ESCAPE:
                        _ = sdl3.SetWindowRelativeMouseMode(window, !sdl3.GetWindowRelativeMouseMode(window))
                    }
                case .KEY_DOWN:
                    switch(event.key.key){
                    case sdl3.K_W: main_camera.velocity.z = -0.1
                    case sdl3.K_A: main_camera.velocity.x = -0.1
                    case sdl3.K_S: main_camera.velocity.z = 0.1
                    case sdl3.K_D: main_camera.velocity.x = 0.1

                    case sdl3.K_SPACE: main_camera.velocity.y = 0.1
                    case sdl3.K_C: main_camera.velocity.y =    -0.1
                    
                    case sdl3.K_Z: main_camera.fov = 20
                    }
                case .MOUSE_MOTION:
                    if(sdl3.GetWindowRelativeMouseMode(window)){
                        main_camera.yaw   += cast(f32)event.motion.xrel * 0.2
                        main_camera.pitch -= cast(f32)event.motion.yrel * 0.2
                        main_camera.pitch = math.clamp(main_camera.pitch, -89.9, 89.9)
                    }

                case .WINDOW_RESIZED:
                    sdl3.GetWindowSize(window, &width, &height)
                    gl.Viewport(0, 0, width, height)
                
            }
        }
        
        if stat, err = os.stat(FRAGMENT_SHADER_PATH); time.diff(last_modification, stat.modification_time) != 0{
            shader, ok = gl.load_shaders_file(VERTEX_SHADER_PATH, FRAGMENT_SHADER_PATH)
            uniforms = gl.get_uniforms_from_program(shader)

            if !ok {
                a, b, c, d := gl.get_last_error_messages()
                fmt.printfln("Could not compile shaders\n %s\n %s", a, c)
            }else{
                fmt.printfln("Shaders loaded")
            }
            last_modification = stat.modification_time
        }
        
        model := glm.identity(glm.mat4)
        view, front := camera_update(&main_camera, 0.1)
        projection := glm.mat4PerspectiveInfinite(main_camera.fov * math.RAD_PER_DEG, f32(width)/f32(height), 0.01)

        gl.UseProgram(shader) 
        gl.ClearColor(0.0, 0.0, 0.0, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        
        gl.Uniform2f(uniforms["resolution"].location, f32(width), f32(height));
        gl.Uniform1f(uniforms["time"].location, f32(sdl3.GetTicks())/1000.0)
        gl.UniformMatrix4fv(uniforms["proj"].location, 1, gl.FALSE, &projection[0,0])
        gl.UniformMatrix4fv(uniforms["view"].location, 1, gl.FALSE, &view[0,0])
        gl.UniformMatrix4fv(uniforms["model"].location, 1, gl.FALSE, &model[0,0])
    
        gl.Uniform3fv(uniforms["camera_pos"].location, 1, &main_camera.position[0]);
        gl.Uniform3fv(uniforms["camera_dir"].location, 1, &front[0]);

        gl.BindVertexArray(quad_vao)

        gl.DrawArrays(gl.TRIANGLES, 0, 6)

        sdl3.GL_SwapWindow(window)
    }



}




