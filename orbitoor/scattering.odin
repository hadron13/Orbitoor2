package orbitoor

import gl "vendor:OpenGL"
import "core:fmt"

transmittance_lut_shader : u32
transmittance_lut_uniforms : map[string]gl.Uniform_Info
transmittance_lut_fbo : u32

multiscatter_lut_shader : u32
multiscatter_lut_uniforms : map[string]gl.Uniform_Info

TRANSMITTANCE_LUT_W :: 256
TRANSMITTANCE_LUT_H :: 64

MULTISCATTER_LUT_W :: 32
MULTISCATTER_LUT_H :: 32





scattering_precompute_init :: proc(){
	ok : bool
	transmittance_lut_shader, transmittance_lut_uniforms, ok = shader_compile("shaders/quad.vert.glsl", "shaders/scattering/transmittance_lut.glsl")
	multiscatter_lut_shader, multiscatter_lut_uniforms, ok = shader_compile("shaders/quad.vert.glsl", "shaders/scattering/multiscattering_lut.glsl")

	gl.GenFramebuffers(1, &transmittance_lut_fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, transmittance_lut_fbo)

	if(gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE){
		fmt.println("LUT framebuffer complete")
	}

	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

scattering_precompute_planet :: proc(body : ^celestial_body){

	fmt.printfln("Precomputing atmosphere for %s", body.name)
	gl.BindFramebuffer(gl.FRAMEBUFFER, transmittance_lut_fbo)
	gl.GenTextures(1, &body.transmittance_lut)
	gl.GenTextures(1, &body.multiscatter_lut)

	//Transmittance
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, body.transmittance_lut)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB32F, TRANSMITTANCE_LUT_W, TRANSMITTANCE_LUT_H, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, body.transmittance_lut, 0)

	//Draw LUT
	gl.BindVertexArray(quad_vao)
	gl.UseProgram(transmittance_lut_shader)
	gl.Viewport(0, 0, TRANSMITTANCE_LUT_W, TRANSMITTANCE_LUT_H)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	//Multiscattering

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, body.multiscatter_lut)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB32F, MULTISCATTER_LUT_W, MULTISCATTER_LUT_H, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, body.multiscatter_lut, 0)
	gl.DrawBuffer(gl.COLOR_ATTACHMENT1)

	//Draw LUT
	gl.UseProgram(multiscatter_lut_shader)
	gl.Uniform1i(multiscatter_lut_uniforms["transmittance_lut"].location, 0)
	gl.Viewport(0, 0, MULTISCATTER_LUT_W, MULTISCATTER_LUT_H)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)


	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

}
