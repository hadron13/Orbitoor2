package orbitoor

import gl "vendor:OpenGL"
import "core:fmt"

shader_compile :: proc(vertex_shader_path, fragment_shader_path : string) -> (u32, map[string]gl.Uniform_Info, bool){
	shader_program : u32
	shader_uniforms: map[string]gl.Uniform_Info
	ok : bool

	shader_program, ok = gl.load_shaders_file(
		vertex_shader_path,
		fragment_shader_path,
	)

	if ok {
		fmt.printfln("Shaders %s %s loaded", vertex_shader_path, fragment_shader_path)
	}

	shader_uniforms = gl.get_uniforms_from_program(shader_program)

	return shader_program, shader_uniforms, ok
}
