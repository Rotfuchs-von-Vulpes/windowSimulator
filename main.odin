package windowSimulator

import "core:fmt"
import "core:mem"

import "base:runtime"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"

scene :: #load("assets/textures/scene3.jpg")
normalMap :: #load("assets/textures/normal_map4.png")

quadVertShader :: #load("assets/shaders/quad_vert.glsl", string)
quadFragShader :: #load("assets/shaders/quad_frag.glsl", string)

main :: proc () {
	context = runtime.default_context()

	tracking_allocator := new(mem.Tracking_Allocator)
	defer free(tracking_allocator)
	mem.tracking_allocator_init(tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(tracking_allocator)

	assert(sdl.Init(sdl.INIT_EVERYTHING) == 0)
	defer sdl.Quit()

	windowWidth, windowHeight, channels: i32
    pixels := stb.load_from_memory(raw_data(scene), i32(len(scene)), &windowWidth, &windowHeight, &channels, 4)

	// width, height, channels: i32
	// iconPixels := stb.load_from_memory(raw_data(icon_raw), cast(i32) len(icon_raw), &width, &height, &channels, 4)
	// iconSurface := sdl.CreateRGBSurfaceWithFormatFrom(iconPixels, width, height, 1, width * 4, cast(u32) sdl.PixelFormatEnum.RGBA8888)
    
	sdl.GL_SetAttribute(.CONTEXT_FLAGS, i32(sdl.GLcontextFlag.FORWARD_COMPATIBLE_FLAG))
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLprofile.CORE))
	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)

	window := sdl.CreateWindow(
		"Window simulator vizualizer",
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		windowWidth / 2, windowHeight / 2,
		{.OPENGL, .RESIZABLE, .ALLOW_HIGHDPI})
	assert(window != nil)
	defer sdl.DestroyWindow(window)

	gl_ctx := sdl.GL_CreateContext(window)
	defer sdl.GL_DeleteContext(gl_ctx)

	sdl.GL_MakeCurrent(window, gl_ctx)
    sdl.GL_SetSwapInterval(1)

	// sdl.SetWindowIcon(window, iconSurface) 
    
	gl.load_up_to(3, 3, proc(p: rawptr, name: cstring) {
		(cast(^rawptr)p)^ = sdl.GL_GetProcAddress(name)
	})
    
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)

    texture: u32
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB8, windowWidth, windowHeight, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
    gl.ActiveTexture(gl.TEXTURE1)
    stb.image_free(pixels)
    
	width, height, channels2: i32
    pixels = stb.load_from_memory(raw_data(normalMap), i32(len(normalMap)), &width, &height, &channels2, 4)

    normalTexture: u32
	gl.GenTextures(2, &normalTexture)
	gl.BindTexture(gl.TEXTURE_2D, normalTexture)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
    stb.image_free(pixels)

    quadVertices := [?]f32{
        // positions   // texCoords
        -1.0,  1.0,  0.0, 0.0,
        -1.0, -1.0,  0.0, 1.0,
        1.0, -1.0,  1.0, 1.0,

        -1.0,  1.0,  0.0, 0.0,
        1.0, -1.0,  1.0, 1.0,
        1.0,  1.0,  1.0, 0.0,
    }

    VAO, VBO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.BindVertexArray(VAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 0)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 2 * size_of(quadVertices[0]))
    
	program, shaderSuccess := gl.load_shaders_source(quadVertShader, quadFragShader)
    gl.UseProgram(program)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        fmt.println("could not compile blocks shaders\n %s\n %s", a, c)
    }

	uniforms := gl.get_uniforms_from_program(program)
    gl.Uniform1i(uniforms["screenTexture"].location, 0)
    gl.Uniform1i(uniforms["normalTexture"].location, 1)

	running := true
	e: sdl.Event
	for running {
		for sdl.PollEvent(&e) {
			#partial switch e.type {
				case .WINDOWEVENT:  #partial switch e.window.event {
					case .CLOSE: running = false
					//case .RESIZED: render.resize(e.window.data1, e.window.data2)
				}
			}
		}

		// nbFrames += 1
		// if time.duration_seconds(time.tick_since(lastTimeTicks)) >= 1.0 {
		// 	fps = nbFrames
		// 	nbFrames = 0
		// 	lastTimeTicks = time.tick_now()
		// }

	    gl.Clear(gl.COLOR_BUFFER_BIT)
        gl.BindVertexArray(VAO)
        gl.DrawArrays(gl.TRIANGLES, 0, 6)

		sdl.GL_SwapWindow(window)
	}

    for key, value in uniforms do delete(value.name)
    delete(uniforms)
    gl.DeleteBuffers(1, &VBO)
    gl.DeleteProgram(program)
	
	temp := runtime.default_temp_allocator_temp_begin()
	defer runtime.default_temp_allocator_temp_end(temp)
    fmt.printfln("printing leaks...")
    for _, leak in tracking_allocator.allocation_map {
        fmt.printfln(fmt.tprintf("%v leaked %m\n", leak.location, leak.size))
    }
    for bad_free in tracking_allocator.bad_free_array {
        fmt.printfln(fmt.tprintf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory))
    }
}