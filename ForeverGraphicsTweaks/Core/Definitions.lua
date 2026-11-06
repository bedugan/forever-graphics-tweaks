-- Every setting FGT manages, and every preset value, lives in this file.
-- Nothing else in the addon hard-codes CVar names or numbers.
--
-- Fields:
--   cvar        CVar name. Also the setting key.
--   label       Display name.
--   category    Key into ns.Categories.
--   kind        "slider" | "choice" | "toggle".
--   min/max/step  Allowed range. Choices and toggles use min/max too.
--   choices     For "choice": labels indexed by value (value = index - 1 + min).
--   format      Display offset, for 0-9 quality levels shown as 1-10.
--   reverse     Slider runs right-to-left so "right" always means more detail.
--   tier        1 = Blizzard quality parent, applied before tier 2 children.
--   presets     balanced/ultra values. Missing means "leave unchanged".
--               The Default preset reads C_CVar.GetCVarDefault at runtime.
--   lessThan    Another CVar this value must stay below (pending value if
--               FGT manages it, otherwise the live value).
--   atMost      Same as lessThan but allows equality.
--   impact      Estimated FPS cost: "low" | "medium" | "high". Not measured.
--   timing      "immediate" | "delayed" (needs camera movement or new terrain
--               to stream in).
--   previewable False would exclude the setting from timed tests.
--   visual      Schematic kind drawn by UI/Comparison.lua.
--   evidence    "source" (Blizzard UI source for 1.60.1.70790) or "wiki"
--               (warcraft.wiki.gg, Retail). Nothing is verified in game yet.
local _, ns = ...

ns.Categories = {
	{ key = "quality", label = "Quality levels" },
	{ key = "vegetation", label = "Ground vegetation" },
	{ key = "detail", label = "Object and terrain detail" },
	{ key = "image", label = "Image quality" },
	{ key = "effects", label = "Other enhancements" },
}

ns.Presets = {
	{ key = "default", label = "Default", tip = "The client's native defaults, read from the game. Not your saved original settings." },
	{ key = "balanced", label = "Balanced", tip = "More detail without the most expensive options." },
	{ key = "ultra", label = "Ultra", tip = "Favors detail and draw distance. Expect a larger frame rate cost." },
	{ key = "custom", label = "Custom", tip = "Your own adjustments." },
}

local QUALITY_LEVEL = "Blizzard quality level. Changing it also resets the detailed values it controls, so FGT applies it first."

ns.Settings = {
	-- Quality levels (tier 1). Range 0-9, Blizzard shows 1-10.
	{
		cvar = "graphicsViewDistance", label = "View distance level", category = "quality",
		kind = "slider", min = 0, max = 9, step = 1, format = 1, tier = 1,
		presets = { balanced = 7, ultra = 9 },
		impact = "high", timing = "immediate", visual = "distance", evidence = "source",
		summary = "How far the world is drawn. " .. QUALITY_LEVEL,
	},
	{
		cvar = "graphicsEnvironmentDetail", label = "Environment detail level", category = "quality",
		kind = "slider", min = 0, max = 9, step = 1, format = 1, tier = 1,
		presets = { balanced = 7, ultra = 9 },
		impact = "medium", timing = "immediate", visual = "lod", evidence = "source",
		summary = "Detail of buildings, trees, and props. " .. QUALITY_LEVEL,
	},
	{
		cvar = "graphicsGroundClutter", label = "Ground clutter level", category = "quality",
		kind = "slider", min = 0, max = 9, step = 1, format = 1, tier = 1,
		presets = { balanced = 7, ultra = 9 },
		impact = "medium", timing = "delayed", visual = "density", evidence = "source",
		summary = "Amount and reach of grass and small ground plants. " .. QUALITY_LEVEL,
	},

	-- Ground vegetation
	{
		cvar = "groundEffectDensity", label = "Grass density", category = "vegetation",
		kind = "slider", min = 16, max = 256, step = 8, tier = 2,
		presets = { balanced = 64, ultra = 128 },
		impact = "medium", timing = "delayed", visual = "density", evidence = "wiki",
		summary = "How many grass and plant sprites are placed on the ground. Higher looks fuller and costs more.",
	},
	{
		cvar = "groundEffectDist", label = "Grass draw distance", category = "vegetation",
		kind = "slider", min = 40, max = 500, step = 10, tier = 2,
		presets = { balanced = 320, ultra = 450 },
		impact = "medium", timing = "delayed", visual = "distance", evidence = "wiki",
		summary = "Distance in yards at which grass stops being drawn.",
	},
	{
		cvar = "groundEffectFade", label = "Grass fade start", category = "vegetation",
		kind = "slider", min = 40, max = 500, step = 10, tier = 2, atMost = "groundEffectDist",
		presets = { balanced = 280, ultra = 400 },
		impact = "low", timing = "delayed", visual = "distance", evidence = "wiki",
		summary = "Distance where grass starts fading out. Must not exceed grass draw distance.",
	},

	-- Object and terrain detail
	{
		cvar = "lodObjectFadeScale", label = "Object fade distance", category = "detail",
		kind = "slider", min = 50, max = 300, step = 10, tier = 2,
		presets = { balanced = 150, ultra = 200 },
		impact = "medium", timing = "immediate", visual = "lod", evidence = "wiki",
		summary = "Scales how far away trees, buildings, and props stay visible before fading. 100 is normal.",
	},
	{
		cvar = "lodObjectCullSize", label = "Small object culling", category = "detail",
		kind = "slider", min = 4, max = 30, step = 1, reverse = true, tier = 2,
		presets = { balanced = 12, ultra = 8 },
		impact = "medium", timing = "immediate", visual = "lod", evidence = "wiki",
		summary = "Objects smaller than this on screen get hidden. Lower values keep more small objects, so the slider runs right to left.",
	},
	{
		cvar = "terrainLodDist", label = "Terrain detail distance", category = "detail",
		kind = "slider", min = 200, max = 1500, step = 25, tier = 2,
		presets = { balanced = 650, ultra = 1000 },
		impact = "medium", timing = "delayed", visual = "terrain", evidence = "wiki",
		summary = "Distance at which terrain switches to its simpler shape. Higher keeps hills and cliffs detailed further out.",
	},
	{
		cvar = "horizonStart", label = "Horizon detail start", category = "detail",
		kind = "slider", min = 400, max = 6000, step = 100, tier = 2, lessThan = "horizonClip",
		presets = {},
		impact = "medium", timing = "delayed", visual = "terrain", evidence = "wiki",
		summary = "Where distant horizon terrain begins. Must stay below the horizon clip distance. No preset changes it.",
	},

	-- Image quality
	{
		cvar = "ResampleAlwaysSharpen", label = "Always sharpen", category = "image",
		kind = "toggle", min = 0, max = 1, step = 1, tier = 2,
		presets = { balanced = 1, ultra = 1 },
		impact = "low", timing = "immediate", visual = "clarity", evidence = "wiki",
		summary = "Applies the sharpening pass even at 100% render scale. Needed for Sharpness to have an effect without FSR.",
	},
	{
		cvar = "ResampleSharpness", label = "Sharpness", category = "image",
		kind = "slider", min = 0, max = 2, step = 0.1, reverse = true, tier = 2,
		presets = {},
		impact = "low", timing = "immediate", visual = "clarity", evidence = "source",
		summary = "Strength of the sharpening pass. 0 is strongest and 2 is weakest, so the slider runs right to left. Works with Always sharpen or FSR.",
	},
	{
		cvar = "textureFilteringMode", label = "Texture filtering", category = "image",
		kind = "choice", min = 0, max = 5, step = 1, tier = 2,
		choices = { "Bilinear", "Trilinear", "2x anisotropic", "4x anisotropic", "8x anisotropic", "16x anisotropic" },
		presets = { balanced = 4, ultra = 5 },
		impact = "low", timing = "immediate", visual = "filtering", evidence = "source",
		summary = "Keeps ground and wall textures crisp at steep viewing angles.",
	},
	{
		cvar = "reflectionMode", label = "Water reflections", category = "image",
		kind = "slider", min = 0, max = 3, step = 1, tier = 2,
		presets = { ultra = 3 },
		impact = "high", timing = "immediate", visual = "reflection", evidence = "wiki",
		summary = "How much of the world water reflects. Higher reflects more and costs the most of any setting here.",
	},

	-- Other enhancements
	{
		cvar = "shadowNumCascades", label = "Shadow cascades", category = "effects",
		kind = "slider", min = 1, max = 4, step = 1, tier = 2,
		presets = { ultra = 4 },
		impact = "medium", timing = "immediate", visual = "shadows", evidence = "wiki",
		summary = "Number of shadow detail bands. More bands keep distant shadows sharper. Blizzard's shadow quality setting can reset this.",
	},
	{
		cvar = "weatherDensity", label = "Weather density", category = "effects",
		kind = "slider", min = 0, max = 3, step = 1, tier = 2,
		presets = { ultra = 3 },
		impact = "low", timing = "immediate", visual = "weather", evidence = "wiki",
		summary = "Amount of rain and snow particles. Only visible in zones with active weather.",
	},
}

ns.SettingsByKey = {}
for index, setting in ipairs(ns.Settings) do
	setting.order = index
	if setting.previewable == nil then
		setting.previewable = true
	end
	ns.SettingsByKey[setting.cvar] = setting
end

-- Not managed. Read only by diagnostics.
ns.WatchedCVars = { "RAIDsettingsEnabled", "horizonClip", "ResampleQuality" }
