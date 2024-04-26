local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages.Promise)

local ProfileService = require(ServerStorage.Packages.ProfileService)

-- Module Wrapper for ProfileService
local DataStoreService = Knit.CreateService {
	Name = "DataStoreService",
	Client = {},
}

local Profiles = {} -- Player -> Profile
local ProfileStore

local PROFILE_STORE = "PlayerData"
local PROFILE_TEMPLATE = require(script.Template)

local PROFILE_TIMEOUT = 10 -- Seconds

-------------------------------------------------
-- Profile Methods
-------------------------------------------------

-- Get the player's profile data
function DataStoreService:Get(player: Player, key: string): string | number
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Player must be a Player")
	assert(typeof(key) == "string", "Key must be a string")

	local profile = self:_AwaitProfile(player)

	return profile.Data[key]
end

-- Set the player's profile data
function DataStoreService:Set(player: Player, key: string, value: string | number): nil
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Player must be a Player")
	assert(typeof(key) == "string", "Key must be a string")

	local profile = self:_AwaitProfile(player)

	profile.Data[key] = value
end

-------------------------------------------------
-- Internal Methods
-------------------------------------------------

-- Try await the player's profile. Times out after a set duration.
function DataStoreService:_AwaitProfile(player: Player)
	local _, profile = Promise.new(function(resolve)
		-- Check if the profile is already loaded. If so, resolve immediately
		local profile = Profiles[player]
		if profile then resolve(profile) end

		-- Else, wait for the profile to load
		repeat task.wait() until Profiles[player] ~= nil
		resolve(Profiles[player])

		-- If the profile doesn't load in time, reject
	end):timeout(PROFILE_TIMEOUT):await()

	-- If the profile doesn't load in time, throw error
	if not profile then error("Profile timed out") end

	return profile
end

-- PlayerAdded handler
function DataStoreService:_PlayerAdded(player: Player): nil
	local userId = player.UserId
	local profile = ProfileStore:LoadProfileAsync(tostring(userId))

	if profile ~= nil then
        profile:AddUserId(userId)
        profile:Reconcile()
        profile:ListenToRelease(function()
            Profiles[player] = nil
            -- The profile could've been loaded on another Roblox server:
            player:Kick("Error 1: Profile released")
        end)
        if player:IsDescendantOf(Players) == true then
			-- Success!
            Profiles[player] = profile
        else
            -- Player left before the profile loaded:
            profile:Release()
        end
    else
		-- Unknown Error
        player:Kick("Error 2: Unknown")
    end
end

-- PlayerRemoving handler
function DataStoreService:_PlayerRemoving(player: Player)
	local profile = Profiles[player]
    if not profile then return end

	profile:Release()
end

-------------------------------------------------
-- Knit Methods
-------------------------------------------------

function DataStoreService:KnitStart()
	print("DataStoreService started")
end

function DataStoreService:KnitInit()
	-- Get the ProfileStore
	ProfileStore = ProfileService.GetProfileStore(
		PROFILE_STORE,
		PROFILE_TEMPLATE
	)

	-- Listen for player events
	Players.PlayerAdded:Connect(function(player)
		self:_PlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_PlayerRemoving(player)
	end)

	-- Catchup players that have already joined
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(self._PlayerAdded, self, player)
	end
end


return DataStoreService