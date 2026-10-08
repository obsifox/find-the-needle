class_name GlintParticles
extends RefCounted


const STAR_BURST:= 0.85


const STAR_TRAIL:= 0.15


const ENERGY_BURST:= 0.22


const ENERGY_TRAIL:= 0.12

const SHADER:= "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;\n\nuniform vec4 core_tint : source_color = vec4(1.0, 0.99, 0.96, 1.0);\nuniform float star_gain = 0.85;\nuniform float energy = 0.22;\n\nvoid vertex() {\n\t// Billboarding, written out rather than had for free from\n\t// BaseMaterial3D.BILLBOARD_ENABLED, because that property lives on\n\t// StandardMaterial3D and this is a ShaderMaterial. Both lines are what\n\t// Godot's own billboard mode generates: the first throws away the\n\t// instance's rotation and faces the camera, the second puts back the\n\t// per-particle SCALE the first one just flattened -- without it every\n\t// spark comes out the same size and scale_min/scale_max do nothing.\n\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(\n\t\tINV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);\n\tMODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(\n\t\tvec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),\n\t\tvec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),\n\t\tvec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),\n\t\tvec4(0.0, 0.0, 0.0, 1.0));\n}\n\nvoid fragment() {\n\tvec2 p = UV * 2.0 - 1.0;\n\tfloat r = length(p);\n\t// Lifted wholesale from GLINT_SHADER so the two effects are the same\n\t// silhouette: a tight core, a soft ball around it, and the four-point star\n\t// a bright highlight throws through a lens.\n\tfloat core = exp(-r * r * 45.0) * 6.0 + exp(-r * r * 12.0) * 1.6;\n\tfloat halo = exp(-r * r * 3.0) * 0.42;\n\tfloat star = (exp(-p.x * p.x * 170.0) + exp(-p.y * p.y * 170.0))\n\t\t* exp(-r * r * 4.0) * star_gain;\n\t// Faded to nothing before the quad's edge, or the star arms end in a\n\t// straight cut and the square is back.\n\tfloat v = (core + halo + star) * (1.0 - smoothstep(0.62, 1.0, r));\n\t// The particle's own colour at the edges, going white in the middle: a\n\t// spark hot enough to see is hot enough to be white where it is brightest,\n\t// whatever colour it burns at further out. COLOR.a is the ramp's fade.\n\t// The mix reads the RAW core, so the middle of a spark goes white however\n\t// far the energy is turned down -- anything bright enough to see at all is\n\t// white where it is brightest. Energy scales what comes out, not what the\n\t// shape is.\n\tALBEDO = mix(COLOR.rgb, core_tint.rgb, clamp(core, 0.0, 1.0)) * v * COLOR.a * energy;\n\tALPHA = 1.0;\n}\n"


static var _shader: Shader


static func draw_quad(size: float, star_gain: float = STAR_BURST,
		energy: float = ENERGY_BURST) -> QuadMesh:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat:= ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("star_gain", star_gain)
	mat.set_shader_parameter("energy", energy)
	var quad:= QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	return quad
