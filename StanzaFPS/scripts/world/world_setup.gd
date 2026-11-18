extends RefCounted
## Ambiente (luce generale, tonalità) e mesh di navigazione dei nemici (partita offline, actors/nemico.gd).

const Config := preload("res://scripts/config.gd")


static func add_environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"   # il renderer Mobile non ha SSAO
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)


## Calcola dove possono camminare i nemici, partendo dalle collisioni dei figli di "nav".
## Pendenze oltre agent_max_slope e gradini oltre agent_max_climb (metri di gioco) non sono percorribili.
static func bake_navigation(nav: NavigationRegion3D) -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Config.LAYER_WORLD
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.75
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(false)
