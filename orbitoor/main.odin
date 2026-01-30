package orbitoor


import "vendor:sdl3"
import gl "vendor:OpenGL"
import "core:fmt"
import "core:os"
import "core:time"
import "core:c"
import "core:math"
import "core:sort"
import glm "core:math/linalg/glsl"


vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

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
    luminosity : f32,
    primary_color : vec3, 
    secondary_color: vec3,
    
    has_atmosphere : bool,
    atmosphere_height : f32,
    atmospheric_density : f32,
    rayleigh_coefficient : vec3,
    mie_coefficient: vec3, 

    has_sea : bool,
    sea_threshold: f32,
    sea_color : vec3,

    has_ice_caps: bool,
    ice_cap_range : f32,
    ice_color : vec3,

}

planet_shader : u32
planet_shader_uniforms : map[string]gl.Uniform_Info
star_shader : u32
star_shader_uniforms : map[string]gl.Uniform_Info
background_shader : u32
background_shader_uniforms : map[string]gl.Uniform_Info

quad_vao : u32

blackbody_radiation :: proc(T: f32, bComputeRadiance: bool) -> vec4{

    ChromaRadiance := vec4{0.0, 0.0, 0.0, 0.0};
    
    // --- Effective radiance in W/(sr*m2) ---
    if(bComputeRadiance){
        ChromaRadiance.a = 230141698.067 / (math.exp(25724.2/T) - 1.0);
    }
    
    // luminance Lv = Km*ChromaRadiance.a in cd/m2, where Km = 683.002 lm/W
    
    // --- Chromaticity in linear sRGB ---
    // (i.e. color luminance Y = dot({r,g,b}, {0.2126, 0.7152, 0.0722}) = 1)
    // --- R ---
    u := 0.000536332*T
    ChromaRadiance.r = 0.638749 + (u + 1.57533) / (u*u + 0.28664);
    
    // --- G ---
    u = 0.0019639*T;
    ChromaRadiance.g = 0.971029 + (u - 10.8015) / (u*u + 6.59002);
    
    // --- B ---
    p := 0.00668406*T + 23.3962;
    u = 0.000941064*T;
    q := u*u + 0.00100641*T + 10.9068;
    ChromaRadiance.b = 2.25398 - p/q;
    
    return ChromaRadiance;
}

draw_celestial_body :: proc(body: ^celestial_body, camera: ^camera, time: f32, width, height : i32, suns: []^celestial_body){

    uniforms : ^map[string]gl.Uniform_Info

    #partial switch(body.type){
        case .ROCKY_PLANET:
            gl.UseProgram(planet_shader) 
            uniforms = &planet_shader_uniforms
        case .STAR:
            gl.UseProgram(star_shader) 
            uniforms = &star_shader_uniforms
    }
    
    gl.Uniform2f(uniforms["resolution"].location, f32(width), f32(height))
    gl.Uniform1f(uniforms["time"].location, time)
    gl.Uniform3fv(uniforms["camera_pos"].location, 1, &camera.position[0])
    gl.Uniform3fv(uniforms["camera_dir"].location, 1, &camera.front[0])
   
    //physical params
    gl.Uniform3fv(uniforms["body_origin"].location, 1, &body.physic_body.position[0])
    gl.Uniform1f(uniforms["body_radius"].location, body.radius)
    gl.Uniform3fv(uniforms["body_axis"].location, 1, &body.rotation_axis[0])
    gl.Uniform1f(uniforms["body_rotation_speed"].location, body.rotation_speed)
   
    //color params
    gl.Uniform3fv(uniforms["body_color1"].location, 1, &body.primary_color[0])
    gl.Uniform3fv(uniforms["body_color2"].location, 1, &body.secondary_color[0])
    
    // gl.Uniform3fv(uniforms["sun_position"].location, 1, &sun_position[0])
    


    if(body.type == .ROCKY_PLANET){
        light_positions : [8*3]f32
        light_colors : [8*4]f32
        for i := 0; i < 8; i+=1{
            light_positions[3*i]     = (i < len(suns))? suns[i].physic_body.position.x: 0
            light_positions[3*i + 1] = (i < len(suns))? suns[i].physic_body.position.y: 0
            light_positions[3*i + 2] = (i < len(suns))? suns[i].physic_body.position.z: 0

            light_colors[4*i]     = (i < len(suns))? suns[i].primary_color.x: 0
            light_colors[4*i + 1] = (i < len(suns))? suns[i].primary_color.y: 0
            light_colors[4*i + 2] = (i < len(suns))? suns[i].primary_color.z: 0
            light_colors[4*i + 3] = (i < len(suns))? 1.0: 0
        }
        gl.Uniform3fv(gl.GetUniformLocation(planet_shader, "light_positions"), 8, &light_positions[0])
        gl.Uniform4fv(gl.GetUniformLocation(planet_shader, "light_colors"), 8, &light_colors[0])

        //sea params
        gl.Uniform1i(uniforms["planet_has_sea"].location, i32(body.has_sea))
        if(body.has_sea){
            gl.Uniform3fv(uniforms["planet_sea_color"].location, 1, &body.sea_color[0])
        }
       
        //atmosphere params
        gl.Uniform1i(uniforms["planet_has_atmosphere"].location, i32(body.has_atmosphere))
        if(body.has_atmosphere){
            gl.Uniform3fv(uniforms["planet_atmosphere_color"].location, 1, &body.rayleigh_coefficient[0])
        }

        //ice caps params
        gl.Uniform1i(uniforms["planet_has_ice_caps"].location, i32(body.has_ice_caps))
        if(body.has_ice_caps){
            gl.Uniform3fv(uniforms["planet_ice_color"].location, 1, &body.ice_color[0])
        }
    }

    gl.BindVertexArray(quad_vao)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)

}
G :: 0.01
apply_gravity :: proc(body_a : ^body, body_b: ^body){
    distance := glm.distance(body_a.position, body_b.position)
    force := (G * body_a.mass * body_b.mass) / (distance * distance)
    direction := glm.normalize(body_b.position - body_a.position)
    body_a.velocity +=  direction * (force/body_a.mass)
    body_b.velocity += -direction * (force/body_b.mass)
}
apply_velocity :: proc(body: ^body, delta_t: f32){
    body.position += body.velocity * delta_t
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
    sdl3.MaximizeWindow(window)
    defer sdl3.DestroyWindow(window)

    gl_context := sdl3.GL_CreateContext(window)
    defer sdl3.GL_DestroyContext(gl_context)

    sdl3.GL_SetSwapInterval(-1)
   
    gl.load_up_to(3, 3, sdl3.gl_set_proc_address)

    fmt.printfln("loaded OpenGL version %s", gl.GetString(gl.VERSION))
    fmt.printfln("vendor: %s", gl.GetString(gl.VENDOR) )
    
    gl.Enable(gl.FRAMEBUFFER_SRGB)
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)


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


    vertex_shader_paths := []string{"shaders/quad.vert.glsl", "shaders/quad.vert.glsl", "shaders/quad.vert.glsl"}
    fragment_shader_paths := []string{"shaders/planet.frag.glsl", "shaders/star.frag.glsl", "shaders/background.frag.glsl"} 
    shader_uniforms := []^map[string]gl.Uniform_Info{&planet_shader_uniforms, &star_shader_uniforms, &background_shader_uniforms}
    shader_programs := []^u32{&planet_shader, &star_shader, &background_shader}

    ok: bool
    for i := 0; i < len(shader_programs); i+=1{
        shader_programs[i]^, ok = gl.load_shaders_file(vertex_shader_paths[i], fragment_shader_paths[i])
        shader_uniforms[i]^ = gl.get_uniforms_from_program(shader_programs[i]^)

        if !ok {
            a, b, c, d := gl.get_last_error_messages()
            fmt.printfln("Could not compile shaders\n %s\n %s", a, c)
            return
        }else{
            fmt.printfln("Shaders %s %s loaded", vertex_shader_paths[i], fragment_shader_paths[i])
        }
    }
    
    for key, uniform in planet_shader_uniforms{
        sdl3.Log("%s - %i", uniform.name, uniform.location)
    }



    width, height : c.int
    sdl3.GetWindowSize(window, &width, &height)

    main_camera = { position = {10.0, 0, 30.0}, yaw = 90, fov = 90 }

    earth := celestial_body{
        type = .ROCKY_PLANET,
        name = "Earth",
        physic_body = {
            position = {0, 0, 40},
            velocity = {4.0, 0, 0},
            mass = 2.0
        },
        radius = 1.0,
        rotation_axis = {0, 1.0, 0},
        rotation_speed = 1.0, 
        primary_color = {0.1, 0.6, 0.2},
        secondary_color = {0.776,0.69,0.239},
        has_sea = true,
        sea_color = {0, 0, 0.8},
        has_atmosphere = true,  
        rayleigh_coefficient = {0, 0, 0.8}, 
        has_ice_caps = true,
        ice_color = {0.9, 0.9, 0.9}
    }

    mars := celestial_body{
        type = .ROCKY_PLANET,
        name = "Mars",
        physic_body = {
            position = {0, 0, 55},
            velocity = {3.5, 0, 0},
            mass = 1.5
        },
        radius = 0.5,
        rotation_axis = {0, 1.0, 0},
        rotation_speed = 2.0, 
        primary_color = {0.8, 0.2, 0.2},
        secondary_color = {0.776,0.69,0.239},
        has_sea = false,
        sea_color = {0, 0, 0.8},
        has_atmosphere = true,  
        rayleigh_coefficient = {0.8, 0, 0}, 
        has_ice_caps = true,
        ice_color = {0.9, 0.9, 0.9}
    }

    mercury := celestial_body{
        type = .ROCKY_PLANET,
        name = "Mercury",
        physic_body = {
            position = {0, 0, 30},
            velocity = {6.0, 0, 0},
            mass = 1.0
        },
        radius = 0.5,
        rotation_axis = {0, 1.0, 0},
        rotation_speed = 0.05, 
        primary_color = {0.4, 0.4, 0.4},
        secondary_color = {0.776,0.69,0.239},
        has_sea = false,  
        has_atmosphere = false,  
    }

    sun := celestial_body{
        type = .STAR,
        name = "Sun",
        physic_body = {
            position = {5.0, 0, 0},
            velocity = {0, 0, -5.0},
            mass = 150.0
        },
        radius = 4.0,
        rotation_axis = {0, 1.0, 0},
        rotation_speed = 1.0, 
        primary_color = blackbody_radiation(5000, false).xyz,
        temperature = 5000.0
    }
    solus := celestial_body{
        type = .STAR,
        name = "Solus",
        physic_body = {
            position = {-5.0, 0, 0},
            velocity = {0, 0, 5.0},
            mass = 100.0
        },
        radius = 3.0,
        rotation_axis = {0, 1.0, 0},
        rotation_speed = 1.0, 
        primary_color = blackbody_radiation(30000, false).xyz,
        temperature = 30000.0
    }

    chongus := celestial_body{
        type = .STAR,
        name = "Chongus",
        physic_body = {
            position = {0, 0, 14959787070.0},
            velocity = {0, 0, 5.0},
            mass = 10000000000.0
        },
        radius = 695508000.0,
        rotation_axis = {0, 1.0, 0},
        rotation_speed = 1.0, 
        primary_color = blackbody_radiation(1800, false).xyz,
        luminosity = 100.0,
        temperature = 1800.0
    }

    moon := celestial_body{
        type = .ROCKY_PLANET,
        name = "Moon",
        physic_body = {
            position = {0, 0, 384400000.0},
            velocity = {6.0, 0, 0},
            mass = 1.0
        },
        radius = 1737500.0,
        rotation_axis = {0, 1.0, 0},
        rotation_speed = 0.05, 
        primary_color = {0.4, 0.4, 0.4},
        secondary_color = {0.776,0.69,0.239},
        has_sea = false,  
        has_atmosphere = false,  
    }

    suns := []^celestial_body{&sun, &solus, &chongus}

    VERTEX_SHADER_PATH :: "shaders/quad.vert.glsl"
    FRAGMENT_SHADER_PATH :: "shaders/star.frag.glsl"

    stat, err := os.stat(FRAGMENT_SHADER_PATH)
    last_modification := stat.modification_time
    
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
            star_shader, ok = gl.load_shaders_file(VERTEX_SHADER_PATH, FRAGMENT_SHADER_PATH)
            star_shader_uniforms = gl.get_uniforms_from_program(star_shader)

            if !ok {
                a, b, c, d := gl.get_last_error_messages()
                fmt.printfln("Could not compile shaders\n %s\n %s", a, c)
            }else{
                fmt.printfln("Shaders reloaded")
            }
            last_modification = stat.modification_time
        }
        
        model := glm.identity(glm.mat4)
        view := camera_update(&main_camera, 1.5)
        projection := glm.mat4PerspectiveInfinite(main_camera.fov * math.RAD_PER_DEG, f32(width)/f32(height), 0.01)

        gl.ClearColor(0.0, 0.0, 0.0, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
   
        gl.Disable(gl.DEPTH_TEST)

        gl.UseProgram(background_shader)
        gl.Uniform2f(background_shader_uniforms["resolution"].location, f32(width), f32(height))
        gl.Uniform3fv(background_shader_uniforms["camera_dir"].location, 1, &main_camera.front[0])
        gl.BindVertexArray(quad_vao)
        gl.DrawArrays(gl.TRIANGLES, 0, 6)
        
        // gl.Enable(gl.DEPTH_TEST)
        

        time := f32(sdl3.GetTicks())/1000.0;


        // main_camera.position = earth.physic_body.position + vec3{0, 0, 2.0}

        bodies :[]^celestial_body = {&earth, &mars, &mercury, &sun, &solus, &chongus}
        sort.quick_sort_proc(bodies, proc(a: ^celestial_body, b: ^celestial_body) -> int{
            return (glm.distance(a.physic_body.position, main_camera.position) > glm.distance(b.physic_body.position, main_camera.position))? -1 : 0;
        })


        for body in &bodies{
            // if(body != &sun){
            //     apply_gravity(&body.physic_body, &sun.physic_body)
            //     apply_velocity(&body.physic_body, 1.0/165.0)
            // }

            for other_body in &bodies{
                if(other_body != body){
                    apply_gravity(&body.physic_body, &other_body.physic_body)
                }
            }
            apply_velocity(&body.physic_body, 1.0/165.0)

            draw_celestial_body(body, &main_camera, time, width, height, suns)
        }


        // gl.UniformMatrix4fv(uniforms["proj"].location, 1, gl.FALSE, &projection[0,0])
        // gl.UniformMatrix4fv(uniforms["view"].location, 1, gl.FALSE, &view[0,0])
        // gl.UniformMatrix4fv(uniforms["model"].location, 1, gl.FALSE, &model[0,0])

        sdl3.GL_SwapWindow(window)
    }



}




