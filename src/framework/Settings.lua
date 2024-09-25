export type Initializer = {
	Name: string,
	Async: boolean,
	Protected: boolean,
	WarnDelay: number,
} 

export type OrderSettings = {
	DebugMode: boolean,
	InitOrder: "Individual" | "Project",
	InitFunctionConfig: {Initializer},
	SilentMode: boolean,
}

return {
	-- Verbose loading in the output window
	DebugMode = false,

	-- "Individual" means that each task will run its initializers in order
	-- before moving on to the next task. "Project" means that all tasks will
	-- run their first initializers, then all tasks will run their second
	-- initializers, and so on.
	InitOrder = "Project",

	-- Initializers will be executed in the order in which they appear in this
	-- array. The options are as follows:
	--
	-- Name: The name of the initialization function.
	-- Async: When true, if this function yields during execution, the thread
	--     will continue to the next initializer while waiting.
	-- Protected: When true, the function will not halt the initialization
	--     process if it errors. Async initializers are always protected.
	-- WarnDelay: The number of seconds to wait before warning about a slow
	--     execution time. Has no effect on async initializers.
	--
	-- Modules can override this configuration by defining a table named
	-- InitConfigOverride that contains the same structure as this table.
	InitFunctionConfig = {
		[1] = {
			Name = "Prep",
			Async = false,
			Protected = true,
			WarnDelay = 1,
		},
		[2] = {
			Name = "Init",
			Async = true,
			Protected = true,
			WarnDelay = 5,
		}
	},

	-- [EXPERIMENTAL]
	-- When true, the framework will not assume that it is the main or only
	-- framework in the game. Use of `shared` will be unavailable. Intended for
	-- use with plugins, packages, or other small scope projects.
	PortableMode = false,

	-- Disables regular output (does not disable warnings)
	SilentMode = not game:GetService("RunService"):IsStudio(),
} :: OrderSettings
