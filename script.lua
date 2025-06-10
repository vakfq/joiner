-- autojoiner.lua
-- Roblox script for auto-joining based on Discord messages
-- Make sure to set getgenv().Token and getgenv().ChannelId before running!

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Anti AFK setup
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Validate Token and ChannelId from getgenv()
local Token = getgenv().Token
local ChannelId = getgenv().ChannelId

if not Token or Token == "" then
    error("[AutoJoiner] Missing Discord Token! Set getgenv().Token before running.")
end

if not ChannelId or ChannelId == "" then
    error("[AutoJoiner] Missing ChannelId! Set getgenv().ChannelId before running.")
end

-- Helper: request function (supports Synapse, KRNL, etc.)
local request = request or (syn and syn.request) or (http and http.request) or http_request
if not request then
    error("[AutoJoiner] HTTP request function not found in this executor!")
end

-- Track already joined messages to avoid repeats
local joinedFile = "joined_ids.txt"
local joinedIds = {}
if isfile(joinedFile) then
    local content = readfile(joinedFile)
    joinedIds = HttpService:JSONDecode(content)
else
    writefile(joinedFile, "[]")
end

local function saveJoinedId(messageId)
    table.insert(joinedIds, messageId)
    writefile(joinedFile, HttpService:JSONEncode(joinedIds))
end

-- Track victim leave status and timer
local victimUser = isfile("user_gag.txt") and readfile("user_gag.txt") or ""
local didVictimLeave = false
local timer = 0

Players.PlayerRemoving:Connect(function(player)
    if player.Name == victimUser then
        didVictimLeave = true
    end
end)

task.spawn(function()
    while wait(1) do
        timer = timer + 1
    end
end)

-- Main function: fetch Discord messages & teleport if new "Join to get GAG hit"
local function autoJoin()
    local success, response = pcall(function()
        return request({
            Url = "https://discord.com/api/v9/channels/"..ChannelId.."/messages?limit=10",
            Method = "GET",
            Headers = {
                ["Authorization"] = Token,
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Mozilla/5.0"
            }
        })
    end)

    if not success or not response then
        warn("[AutoJoiner] Failed HTTP request to Discord.")
        return
    end

    if response.StatusCode ~= 200 then
        warn("[AutoJoiner] Discord API returned status code:", response.StatusCode)
        return
    end

    local messages = HttpService:JSONDecode(response.Body)
    for _, message in ipairs(messages) do
        local embed = message.embeds and message.embeds[1]
        if message.content and embed and embed.title and embed.title:find("Join to get GAG hit") then
            local placeId, jobId = string.match(message.content, 'TeleportToPlaceInstance%((%d+),%s*["\']([%w%-]+)["\']%)')
            local victim = embed.fields and embed.fields[1] and embed.fields[1].value or ""

            if placeId and jobId and (didVictimLeave or timer > 10) then
                if not table.find(joinedIds, tostring(message.id)) then
                    writefile("user_gag.txt", victim)
                    saveJoinedId(tostring(message.id))
                    TeleportService:TeleportToPlaceInstance(tonumber(placeId), jobId, LocalPlayer)
                    return
                end
            end
        end
    end
end

-- Loop every 5 seconds
while wait(5) do
    pcall(autoJoin)
end
