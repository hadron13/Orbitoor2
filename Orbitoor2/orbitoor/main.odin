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

body :: struct{
    mass : f32,
    position : vec3,
    velocity : vec3
}

celestial_body_type :: enum{    
    STAR, ROCKY_PLANET, GAS_PLANET, ASTEROID, BLACK_HOLE
}


celestial_body :: struct{
    type : celestial_body_type,
    name : string,
    physic_body : body,
    radius : f32,
    rotation_axis : vec3,
    rotation_speed : f32,

    temperature : f32,
    primary_color : vec3, 
    secondary_color: vec3,
    
    has_atmosphere : bool,
    atmosphere_height : f32,
    atmospheric_density : f32,
    rayleigh_coefficient : vec3,
    mie_coefficient: vec3, 

    has_sea : bool,
    sea_color : vec3,

    has_ice_caps: bool,
    ice_cap_range : f32,
    ice_color : vec3,

}

planet_shader : u32
planet_shader_uniforms : map[string]gl.Uniform_Info
quad_vao : u32

draw_celestial_body :: proc(body: ^celestial_body, camera: ^camera, time: f32, width, height : i32){

    gl.UseProgram(planet_shader) 
    gl.Uniform2f(planet_shader_uniforms["resolution"].location, f32(width), f32(height))
    gl.Uniform1f(planet_shader_uniforms["time"].location, time)
    gl.Uniform3fv(planet_shader_uniforms["camera_pos"].location, 1, &camera.position[0])
    gl.Uniform3fv(planet_shader_uniforms["camera_dir"].location, 1, &camera.front[0])
    
    gl.Uniform3fv(planet_shader_uniforms["planet_origin"].location, 1, &body.physic_body.position[0])
    gl.Uniform1f(planet_shader_uniforms["planet_radius"].location, body.radius)
    gl.Uniform3fv(planet_shader_uniforms["planet_axis"].location, 1, &body.rotation_axis[0])
    gl.Uniform1f(planet_shader_uniforms["planet_rotation_speed"].location, body.rotation_speed)
    
    gl.Uniform3fv(planet_shader_uniforms["planet_color1"].location, 1, &body.primary_color[0])
    gl.Uniform3fv(planet_shader_uniforms["planet_color2"].location, 1, &body.secondary_color[0])
    gl.Uniform3fv(planet_shader_uniforms["planet_color_sea"].location, 1, &body.sea_color[0])
    

    gl.BindVertexArray(quad_vao)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)

}



camera :: struct{
    position : vec3, 
    velocity : vec3,
    yaw,pitch: f32,
    fov      : f32,
    front    : vec3
}

main_camera : camera

camera_update :: proc"c"(camera : ^camera, delta_time : f32) -> (glm.mat4){

    camera.front = glm.normalize(
    [3]f32{math.cos(glm.radians(camera.yaw)) * math.cos(glm.radians(camera.pitch)),
           math.sin(glm.radians(camera.pitch)),
           math.sin(glm.radians(camera.yaw)) * math.cos(glm.radians(camera.pitch))})
    
    front_straight := glm.normalize([3]f32{camera.front.x, 0, camera.front.z})

    up := [3]f32{0, 1, 0} 
    right := glm.normalize(glm.cross(up, front_straight))

    camera.position -= right          * main_camera.velocity.x * delta_time
    camera.position += up             * main_camera.velocity.y * delta_time
    camera.position -= front_straight * main_camera.velocity.z * delta_time 

    return glm.mat4LookAt(main_camera.position, main_camera.position + camera.front, {0, 1, 0})

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
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS);

    quad : []f32 = {
       -1.0,-1.0, 0, 0, 0,
       -1.0, 1.0, 0, 0, 1,
        1.0,-1.0, 0, 1, 0,
        1.0,-1.0, 0, 1, 0,
       -1.0, 1.0, 0, 0, 1,
        1.0, 1.0, 0, 1, 1
    }
    
    quad_vbo: u32
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
    planet_shader = shader;
    uniforms := gl.get_uniforms_from_program(shader)
    planet_shader_uniforms = uniforms

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

    main_camera = { position = {0, 0, -2.0}, fov = 90 }

    loop:
    for{
        event : sdl3.Event
        for sdl3.PollEvent(&event){
            #partial switch(event.type){
                case .QUIT:
                    break loop
                case .KEY_UP:
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
            planet_shader = shader;
            planet_shader_uniforms = uniforms
            last_modification = stat.modification_time
        }
        
        model := glm.identity(glm.mat4)
        view := camera_update(&main_camera, 0.1)
        projection := glm.mat4PerspectiveInfinite(main_camera.fov * math.RAD_PER_DEG, f32(width)/f32(height), 0.01)

        gl.UseProgram(shader) 
        gl.ClearColor(0.0, 0.0, 0.0, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        time := f32(sdl3.GetTicks())/1000.0;

        earth := celestial_body{
            type = .ROCKY_PLANET,
            name = "Earth",
            physic_body = {
                position = {0, 0, 0},
                velocity = {0, 0, 0},
                mass = 1.0
            },
            radius = 1.0,
            rotation_axis = {0, 1.0, 0},
            rotation_speed = 1.0, 
            primary_color = {0.1, 0.6, 0.2},
            secondary_color = {0.776,0.69,0.239},
            sea_color = {0, 0, 0.8},
            has_atmosphere = true,  
        }

        mars := celestial_body{
            type = .ROCKY_PLANET,
            name = "Mars",
            physic_body = {
                position = {5, 0, 0},
                velocity = {0, 0, 0},
                mass = 1.0
            },
            radius = 0.5,
            rotation_axis = {0, 1.0, 0},
            rotation_speed = 2.0, 
            primary_color = {0.8, 0.2, 0.2},
            secondary_color = {0.776,0.69,0.239},
            sea_color = {0, 0, 0.8},
            has_atmosphere = true,  
        }
        mars.physic_body.position = {math.sin(time) * 5, 0, math.cos(time) * 5}
        
        draw_celestial_body(&mars, &main_camera, time, width, height)
        draw_celestial_body(&earth, &main_camera, time, width, height)


        // gl.UniformMatrix4fv(uniforms["proj"].location, 1, gl.FALSE, &projection[0,0])
        // gl.UniformMatrix4fv(uniforms["view"].location, 1, gl.FALSE, &view[0,0])
        // gl.UniformMatrix4fv(uniforms["model"].location, 1, gl.FALSE, &model[0,0])

        sdl3.GL_SwapWindow(window)
    }



}




