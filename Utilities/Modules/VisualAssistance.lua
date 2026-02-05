--[[
    VisualAssistance v1.00 by computerintrusion 01/29/2026
    
    High performance visual utility module for rendering player
    and object visuals using your executor's Drawing API

    Utilizes Maid and Signal for safe cleanup and event management
]]

assert(Drawing, "Executor does not support Drawing!")

local Signal = loadstring(game:HttpGet("https://github.com/computerintrusion/Merc-X/raw/refs/heads/main/Utilities/Modules/Signal.lua"))()
local Maid   = loadstring(game:HttpGet("https://github.com/computerintrusion/Merc-X/raw/refs/heads/main/Utilities/Modules/Maid.lua"))()

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CurrentCamera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local VisualAssistance = {}
VisualAssistance.__index = VisualAssistance
VisualAssistance.ClassName = "VisualAssistance"
VisualAssistance.ClassLoaded = false 

VisualAssistance.ObjectArray = {} -- TODO: add custom object drawing
VisualAssistance.PlayerArray = {}
VisualAssistance.PlayerAdded = Signal.new()
VisualAssistance.PlayerRemoved = Signal.new()

VisualAssistance.Configuration = {
    Settings = {
        Enabled = false,
        FontSize = 12,
        
        Whitelist = {}, -- Name

        CullDistance = { 
            Enabled = true, 
            MaxStuds = 1500 
        },
    },

    Name = {
        Enabled = false,
        Color = Color3.fromRGB(240, 210, 190), 
        Outline = true,
        Mode = "DisplayName", -- "Name", "DisplayName"
        Distance = { 
            Enabled = false, 
            Outline = true 
        } 
    },
    Health = {
        Enabled = false,
        Color = Color3.fromRGB(0, 255, 127),
        Outline = true
    },
    HitBox = {
        Enabled = false, 
        Color = Color3.fromRGB(255, 0, 0), 
        Outline = true 
    },
    Tracer = { 
        Enabled = false, 
        Color = Color3.fromRGB(0, 255, 255),
        Outline = true, Position = "Bottom" 
    },
}

local function VisualAssistance_NewDrawing(class, properties)
    local object = Drawing.new(class)
    for index, value in pairs(properties or {}) do 
        object[index] = value
    end

    return object
end

function VisualAssistance:DeepCopy(table)
    local copy = {}

    for index, value in pairs(table) do
        copy[index] = type(value) == "table" and self:DeepCopy(value) or value
    end

    return copy
end

local function VisualAssistance_GetDistance(player)
    if not player or not player.Character then 
        return math.huge 
    end

    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then 
        return math.huge 
    end

    local cameraPos = workspace.CurrentCamera.CFrame.Position

    return (root.Position - cameraPos).Magnitude
end

local function VisualAssistance_GetHealth(player)
    if not player or not player.Character then 
        return 100, 100
    end

    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth
    end

    return 100, 100
end

local function VisualAssistance_RenderPlayer(player, config)
    return {
        Name = VisualAssistance_NewDrawing("Text", {
            Text = player.Name,
            Size = config.Settings.FontSize,
            Color = config.Name.Color,
            Outline = config.Name.Outline,
            Center = true,
            Visible = true,
            Font = 0
        }),
        Health = VisualAssistance_NewDrawing("Square", {
            Color = config.Health.Color,
            Visible = true,
            Thickness = 2
        }),
        HitBox = VisualAssistance_NewDrawing("Square", {
            Color = config.HitBox.Color,
            Visible = true,
            Thickness = 1
        }),
        Tracer = VisualAssistance_NewDrawing("Line", {
            Color = config.Tracer.Color,
            Visible = true,
            Thickness = 1
        })
    }
end

function VisualAssistance.new()
    local self = setmetatable({}, VisualAssistance)

    self.Maid = Maid.new()
    self.Objects = {}
    self.Configuration = self:DeepCopy(VisualAssistance.Configuration)
    
    return self
end

function VisualAssistance:Update()
    local playerArray = self.PlayerArray
    local config = self.Configuration
    if not playerArray or not config.Settings.Enabled then 
        return 
    end

    local screenSize = CurrentCamera.ViewportSize
    local cullEnabled = config.Settings.CullDistance.Enabled
    local maxCull = config.Settings.CullDistance.MaxStuds
    local nameConfig = config.Name
    local healthConfig = config.Health
    local hitBoxConfig = config.HitBox
    local tracerConfig = config.Tracer
    local localPlayer = LocalPlayer
    local cameraCFramePos = CurrentCamera.CFrame.Position
    local distanceFactor = 0.28

    for player, drawings in pairs(playerArray) do
        if player == localPlayer then continue end

        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if not rootPart then
            for _, drawing in pairs(drawings) do drawing.Visible = false end
            continue
        end

        local rootPos = rootPart.Position
        local screenPosition, onScreen = CurrentCamera:WorldToViewportPoint(rootPos)
        if not onScreen then
            for _, drawing in pairs(drawings) do drawing.Visible = false end
            continue
        end

        local dx = rootPos.X - cameraCFramePos.X
        local dy = rootPos.Y - cameraCFramePos.Y
        local dz = rootPos.Z - cameraCFramePos.Z
        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

        if cullEnabled and distance > maxCull then
            for _, drawing in pairs(drawings) do drawing.Visible = false end
            continue
        end

        local topY = CurrentCamera:WorldToViewportPoint(rootPos + Vector3.new(0, 2.6, 0)).Y
        local bottomY = CurrentCamera:WorldToViewportPoint(rootPos - Vector3.new(0, 3, 0)).Y
        local halfHeight = math.abs(bottomY - topY) / 2

        local charWidth = math.floor(halfHeight * 1.5)
        local charHeight = math.floor(halfHeight * 1.9)
        local charSize = Vector2.new(charWidth, charHeight)
        local topLeftX = math.floor(screenPosition.X - charWidth / 2)
        local topLeftY = math.floor(screenPosition.Y - halfHeight * 1.6 / 2)
        local charTopLeft = Vector2.new(topLeftX, topLeftY)

        if drawings.Name then
            local visible = nameConfig.Enabled
            drawings.Name.Visible = visible
            if visible then
                local text = nameConfig.Mode == "DisplayName" and player.DisplayName or player.Name
                if nameConfig.Distance.Enabled then
                    text = text .. " (" .. math.floor(distance * distanceFactor) .. "m)"
                end
                drawings.Name.Text = text
                drawings.Name.Position = Vector2.new(topLeftX + charWidth / 2, topLeftY - 16)
                drawings.Name.Color = nameConfig.Color
                drawings.Name.Outline = nameConfig.Outline
            end
        end

        if drawings.Health then
            local visible = healthConfig.Enabled
            drawings.Health.Visible = visible
            if visible then
                local health, maxHealth = VisualAssistance_GetHealth(player)
                local ratio = math.clamp(health / maxHealth, 0, 1)
                drawings.Health.Size = Vector2.new(2, math.floor(charHeight * ratio))
                drawings.Health.Position = Vector2.new(topLeftX - 4, topLeftY + (charHeight * (1 - ratio)))
                drawings.Health.Color = healthConfig.Color
                drawings.Health.Outline = healthConfig.Outline
            end
        end

        if drawings.HitBox then
            local visible = hitBoxConfig.Enabled
            drawings.HitBox.Visible = visible
            if visible then
                drawings.HitBox.Size = charSize
                drawings.HitBox.Position = charTopLeft
                drawings.HitBox.Color = hitBoxConfig.Color
                drawings.HitBox.Outline = hitBoxConfig.Outline
            end
        end

        if drawings.Tracer then
            drawings.Tracer.Visible = tracerConfig.Enabled
            if drawings.Tracer.Visible then
                local tracerFrom = (tracerConfig.Position == "Top" and Vector2.new(screenSize.X / 2, 0))
                                or (tracerConfig.Position == "Bottom" and Vector2.new(screenSize.X / 2, screenSize.Y))
                                or Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)

                local tracerToY
                if tracerConfig.Position == "Top" then
                    if drawings.Name and drawings.Name.Visible then
                        tracerToY = topLeftY - drawings.Name.Size - 2
                    else
                        tracerToY = topLeftY
                    end
                else
                    tracerToY = topLeftY + charHeight + 4
                end

                local tracerTo = Vector2.new(topLeftX + charWidth / 2, tracerToY)

                drawings.Tracer.From = tracerFrom
                drawings.Tracer.To = tracerTo
                drawings.Tracer.Color = tracerConfig.Color
                drawings.Tracer.Outline = tracerConfig.Outline
            end
        end
    end
end

-- Initialize
function VisualAssistance:Initialize()
    assert(not VisualAssistance.ClassLoaded, "VisualAssistance has already been initialized.")

    self.Maid = Maid.new()
    self.PlayerArray = {}

    self.Maid.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        if self.Configuration.Settings.Whitelist[player.Name] then 
            return 
        end

        self.PlayerArray[player] = VisualAssistance_RenderPlayer(player, self.Configuration)
        self.PlayerAdded:Fire(player)
    end)

    self.Maid.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        if self.PlayerArray[player] then
            for _, drawing in pairs(self.PlayerArray[player]) do 
                drawing:Remove() 
            end

            self.PlayerArray[player] = nil
        end

        self.PlayerRemoved:Fire(player)
    end)

    for _,player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not self.Configuration.Settings.Whitelist[player.Name] then
            self.PlayerArray[player] = VisualAssistance_RenderPlayer(player, self.Configuration)
            self.PlayerAdded:Fire(player)
        end
    end

    self.Signals = {}
    self.Signals.RenderStepped = RunService.RenderStepped:Connect(function()
        self:Update()
    end)

    VisualAssistance.ClassLoaded = true
end

function VisualAssistance:Destroy()
    assert(VisualAssistance.ClassLoaded, "VisualAssistance has not been initialized.")
    
    if self.Signals then 
        for _, connection in pairs(self.Signals) do 
            connection:Disconnect() 
        end
    end
    
    for _, drawings in pairs(self.PlayerArray) do 
        for _, drawing in pairs(drawings) do 
            drawing:Remove() 
        end 
    end

    self.PlayerArray = {}

    if self.Maid then 
        self.Maid:DoCleaning() 
        self.Maid = nil 
    end

    VisualAssistance.ClassLoaded = false
end

return VisualAssistance
