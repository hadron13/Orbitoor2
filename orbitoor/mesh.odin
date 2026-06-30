package orbitoor

import "core:c"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:os"
import "core:sort"
import "core:strings"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:cgltf"
import "vendor:sdl3"
import stbi "vendor:stb/image"


mesh_load :: proc(filename: cstring) -> (output: mesh, success: b32) {
	options := cgltf.options{}
	data, result := cgltf.parse_file(options, filename)

	if (result != .success) {
		sdl3.Log("error loading %s", filename)
		return {}, false
	}
	result = cgltf.load_buffers(options, data, filename)
	if (result != .success) {
		sdl3.Log("error loading buffers of %s", filename)
		return {}, false
	}

	first_mesh := data.meshes[0]
	primitive := &first_mesh.primitives[0]

	index_accessor := primitive.indices

	position_accessor, normal_accessor: ^cgltf.accessor

	for attribute in primitive.attributes {

		if (attribute.type == .position) {
			position_accessor = attribute.data
		}
		if (attribute.type == .normal) {
			normal_accessor = attribute.data
		}
	}

	mesh_vao, vbo, ebo: u32
	gl.GenVertexArrays(1, &mesh_vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

	if (position_accessor.buffer_view == normal_accessor.buffer_view) {
		sdl3.Log("interleaved unsupported")
		return {}, false
	}


	gl.BindVertexArray(mesh_vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		int(position_accessor.buffer_view.size + normal_accessor.buffer_view.size),
		nil,
		gl.STATIC_DRAW,
	)
	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		int(position_accessor.buffer_view.size),
		rawptr(
			uintptr(position_accessor.buffer_view.buffer.data) +
			uintptr(position_accessor.offset + position_accessor.buffer_view.offset),
		),
	)

	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		int(normal_accessor.buffer_view.offset),
		int(normal_accessor.buffer_view.size),
		rawptr(
			uintptr(normal_accessor.buffer_view.buffer.data) +
			uintptr(normal_accessor.offset + normal_accessor.buffer_view.offset),
		),
	)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, i32(position_accessor.stride), 0)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		i32(position_accessor.stride),
		uintptr(normal_accessor.offset),
	)
	gl.EnableVertexAttribArray(1)

	if (primitive.indices == nil) {
		sdl3.Log("no indices found in %s", filename)
		return {}, false
	}
	sdl3.Log(
		"loaded file %s with %i vertices, %i indices",
		filename,
		position_accessor.count,
		primitive.indices.count,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		int(index_accessor.count * index_accessor.stride),
		rawptr(
			uintptr(index_accessor.buffer_view.buffer.data) +
			uintptr(index_accessor.offset + index_accessor.buffer_view.offset),
		),
		gl.STATIC_DRAW,
	)

	gl.BindVertexArray(0)

	return {
			vao = mesh_vao,
			shader = mesh_shader,
			indice_type = index_accessor.stride == 2 ? gl.UNSIGNED_SHORT : gl.UNSIGNED_INT,
			indice_count = u32(index_accessor.count),
		},
		true
}

mesh_draw :: proc(target_mesh: ^mesh, model, view, projection: ^glm.mat4) {
	gl.UseProgram(target_mesh.shader)

	gl.UniformMatrix4fv(mesh_shader_uniforms["proj"].location, 1, gl.FALSE, &projection[0, 0])
	gl.UniformMatrix4fv(mesh_shader_uniforms["view"].location, 1, gl.FALSE, &view[0, 0])
	gl.UniformMatrix4fv(mesh_shader_uniforms["model"].location, 1, gl.FALSE, &model[0, 0])
	gl.Uniform1i(mesh_shader_uniforms["skybox"].location, 0)
	gl.Uniform3fv(mesh_shader_uniforms["camera_pos"].location, 1, &main_camera.position[0])
	gl.BindVertexArray(target_mesh.vao)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, skybox_tex_id)

	gl.DrawElements(gl.TRIANGLES, i32(target_mesh.indice_count), target_mesh.indice_type, nil)

}
