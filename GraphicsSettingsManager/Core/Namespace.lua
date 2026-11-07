-- Shared namespace, injected game API, and a tiny event bus.
-- Core modules only reach the game through ns.api so tests can swap it out.
local ADDON, ns = ...

ns.name = ADDON
ns.version = "0.1.0"
ns.interface = 16001

local function savedVariables()
	-- Read the global every time. Forever beta clients have delivered
	-- SavedVariables late or not at all, so never cache the table.
	local db = GraphicsSettingsManagerDB
	if type(db) ~= "table" then
		db = {}
		GraphicsSettingsManagerDB = db
	end
	db.profiles = db.profiles or {}
	db.ui = db.ui or {}
	return db
end

ns.api = ns.api or {
	cvar = C_CVar,
	gameRules = C_GameRules,
	enum = Enum,
	clock = GetTime,
	now = time,
	inCombat = InCombatLockdown,
	buildInfo = GetBuildInfo,
	db = savedVariables,
	print = function(msg)
		DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7GSM|r " .. msg)
	end,
	reportError = function(err)
		geterrorhandler()(err)
	end,
}

local listeners = {}

function ns.on(event, fn)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], fn)
end

function ns.emit(event, ...)
	for _, fn in ipairs(listeners[event] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then
			ns.api.reportError(err)
		end
	end
end

function ns.print(msg)
	ns.api.print(msg)
end
