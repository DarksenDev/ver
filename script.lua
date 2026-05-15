-- ============================================================
-- DON'T PRESS THE BUTTON X — BOT v2.0
-- Fixes: D3 noclip TP, D4 shield platform, D6 safeZone rush,
--        D9 pathfind+fallback TP, D10 smart platform survival
-- ============================================================

-- CLEANUP
for _, old in pairs(game.CoreGui:GetChildren()) do
    if old.Name == "PremiumSurvivorAI" then old:Destroy() end
end
for _, old in pairs(workspace:GetChildren()) do
    if old.Name == "_BotShield" or old.Name == "_BotStandPlatform" then old:Destroy() end
end

_G.BotRunning = true
_G.d6ReturnPos = nil
_G.d6TpCount = 0

local player       = game.Players.LocalPlayer
local Pathfinding  = game:GetService("PathfindingService")
local RunService   = game:GetService("RunService")

local wanderTarget     = nil
local lastCharacter    = nil
local shieldPart       = nil
local standPart        = nil
local d10Initialized   = false

-- ============================================================
-- НАСТРОЙКИ
-- ============================================================
local Settings = {
    AutoWin         = true,
    AutoClick       = true,
    AntiMonster     = true,
    AntiFlood       = true,
    AutoTycoon      = true,
    ShowShield      = true,
}

-- ============================================================
-- GUI
-- ============================================================
local TweenService = game:GetService("TweenService")

local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name        = "PremiumSurvivorAI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
Main.BorderSizePixel  = 0
Main.Size             = UDim2.new(0, 300, 0, 46)
Main.Position         = UDim2.new(0.5, -150, 0.04, 0)
Main.Active           = true
Main.Draggable        = true
Main.ClipsDescendants = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke", Main)
stroke.Color       = Color3.fromRGB(0, 170, 255)
stroke.Thickness   = 1.2
stroke.Transparency = 0.5

local Header = Instance.new("Frame", Main)
Header.Size             = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
Header.BorderSizePixel  = 0

local HeaderGrad = Instance.new("UIGradient", Header)
HeaderGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 16)),
})
HeaderGrad.Rotation = 90

local TopBar = Instance.new("Frame", Main)
TopBar.Size             = UDim2.new(1, 0, 0, 2)
TopBar.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
TopBar.BorderSizePixel  = 0
local TopBarGrad = Instance.new("UIGradient", TopBar)
TopBarGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 120, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 200)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(120, 0, 255)),
})

local PulseDot = Instance.new("Frame", Header)
PulseDot.Size             = UDim2.new(0, 9, 0, 9)
PulseDot.Position         = UDim2.new(0, 14, 0.5, -4)
PulseDot.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
PulseDot.BorderSizePixel  = 0
Instance.new("UICorner", PulseDot).CornerRadius = UDim.new(1, 0)

task.spawn(function()
    while true do
        TweenService:Create(PulseDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.7}):Play()
        task.wait(0.6)
        TweenService:Create(PulseDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()
        task.wait(0.6)
    end
end)

local TitleLabel = Instance.new("TextLabel", Header)
TitleLabel.Size               = UDim2.new(0, 120, 1, 0)
TitleLabel.Position           = UDim2.new(0, 30, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text               = "SURVIVOR AI"
TitleLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize           = 13
TitleLabel.Font               = Enum.Font.GothamBold
TitleLabel.TextXAlignment     = Enum.TextXAlignment.Left

local VerLabel = Instance.new("TextLabel", Header)
VerLabel.Size               = UDim2.new(0, 40, 1, 0)
VerLabel.Position           = UDim2.new(0, 148, 0, 0)
VerLabel.BackgroundTransparency = 1
VerLabel.Text               = "v2.0"
VerLabel.TextColor3         = Color3.fromRGB(0, 200, 255)
VerLabel.TextSize           = 10
VerLabel.Font               = Enum.Font.Gotham
VerLabel.TextXAlignment     = Enum.TextXAlignment.Left

local Status = Instance.new("TextLabel", Header)
Status.Size               = UDim2.new(1, -200, 1, 0)
Status.Position           = UDim2.new(0, 195, 0, 0)
Status.BackgroundTransparency = 1
Status.Text               = "INIT..."
Status.TextColor3         = Color3.fromRGB(0, 255, 140)
Status.TextSize           = 10
Status.Font               = Enum.Font.GothamBold
Status.TextXAlignment     = Enum.TextXAlignment.Right
Status.TextTruncate       = Enum.TextTruncate.AtEnd

local BtnSettings = Instance.new("TextButton", Header)
BtnSettings.Size               = UDim2.new(0, 24, 0, 24)
BtnSettings.Position           = UDim2.new(1, -52, 0.5, -12)
BtnSettings.BackgroundColor3   = Color3.fromRGB(25, 25, 38)
BtnSettings.BorderSizePixel    = 0
BtnSettings.Text               = "⚙"
BtnSettings.TextColor3         = Color3.fromRGB(180, 180, 220)
BtnSettings.TextSize           = 14
BtnSettings.Font               = Enum.Font.GothamBold
Instance.new("UICorner", BtnSettings).CornerRadius = UDim.new(0, 6)

local BtnMinimize = Instance.new("TextButton", Header)
BtnMinimize.Size               = UDim2.new(0, 24, 0, 24)
BtnMinimize.Position           = UDim2.new(1, -24, 0.5, -12)
BtnMinimize.BackgroundColor3   = Color3.fromRGB(25, 25, 38)
BtnMinimize.BorderSizePixel    = 0
BtnMinimize.Text               = "−"
BtnMinimize.TextColor3         = Color3.fromRGB(180, 180, 220)
BtnMinimize.TextSize           = 16
BtnMinimize.Font               = Enum.Font.GothamBold
Instance.new("UICorner", BtnMinimize).CornerRadius = UDim.new(0, 6)

local SettingsPanel = Instance.new("Frame", Main)
SettingsPanel.Size             = UDim2.new(1, 0, 0, 220)
SettingsPanel.Position         = UDim2.new(0, 0, 0, 46)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
SettingsPanel.BorderSizePixel  = 0
SettingsPanel.Visible          = false

local SepLine = Instance.new("Frame", SettingsPanel)
SepLine.Size             = UDim2.new(1, -20, 0, 1)
SepLine.Position         = UDim2.new(0, 10, 0, 0)
SepLine.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
SepLine.BorderSizePixel  = 0

local SettingsTitle = Instance.new("TextLabel", SettingsPanel)
SettingsTitle.Size               = UDim2.new(1, 0, 0, 28)
SettingsTitle.Position           = UDim2.new(0, 0, 0, 6)
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Text               = "⚙  НАСТРОЙКИ"
SettingsTitle.TextColor3         = Color3.fromRGB(0, 200, 255)
SettingsTitle.TextSize           = 11
SettingsTitle.Font               = Enum.Font.GothamBold

local function makeToggle(parent, yPos, label, settingKey)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1, -20, 0, 28)
    row.Position         = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size               = UDim2.new(1, -60, 1, 0)
    lbl.Position           = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = label
    lbl.TextColor3         = Color3.fromRGB(200, 200, 220)
    lbl.TextSize           = 11
    lbl.Font               = Enum.Font.Gotham
    lbl.TextXAlignment     = Enum.TextXAlignment.Left

    local toggleBg = Instance.new("Frame", row)
    toggleBg.Size             = UDim2.new(0, 38, 0, 18)
    toggleBg.Position         = UDim2.new(1, -46, 0.5, -9)
    toggleBg.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 80)
    toggleBg.BorderSizePixel  = 0
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", toggleBg)
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.Position         = Settings[settingKey] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel  = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton", row)
    btn.Size               = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text               = ""
    btn.ZIndex             = 5

    btn.MouseButton1Click:Connect(function()
        Settings[settingKey] = not Settings[settingKey]
        local on = Settings[settingKey]
        TweenService:Create(toggleBg, TweenInfo.new(0.2), {
            BackgroundColor3 = on and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 80)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }):Play()
    end)

    return row
end

makeToggle(SettingsPanel, 34,  "🏆  Auto Win",          "AutoWin")
makeToggle(SettingsPanel, 68,  "🖱️  Auto Click Button",  "AutoClick")
makeToggle(SettingsPanel, 102, "👾  Anti Monster",       "AntiMonster")
makeToggle(SettingsPanel, 136, "🌊  Anti Flood",         "AntiFlood")
makeToggle(SettingsPanel, 170, "💰  Auto Tycoon",        "AutoTycoon")

local settingsOpen = false
local minimized    = false

BtnSettings.MouseButton1Click:Connect(function()
    settingsOpen = not settingsOpen
    if minimized then return end
    SettingsPanel.Visible = settingsOpen
    local targetH = settingsOpen and (46 + 220) or 46
    TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
        Size = UDim2.new(0, 300, 0, targetH)
    }):Play()
    BtnSettings.TextColor3 = settingsOpen
        and Color3.fromRGB(0, 200, 255)
        or  Color3.fromRGB(180, 180, 220)
end)

BtnMinimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        SettingsPanel.Visible = false
        TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0, 300, 0, 46)
        }):Play()
        BtnMinimize.Text = "+"
    else
        BtnMinimize.Text = "−"
        if settingsOpen then
            SettingsPanel.Visible = true
            TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
                Size = UDim2.new(0, 300, 0, 46 + 220)
            }):Play()
        end
    end
end)

for _, btn in ipairs({BtnSettings, BtnMinimize}) do
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 55)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(25, 25, 38)}):Play()
    end)
end

local function setStatus(text, r, g, b)
    Status.Text      = text
    local col        = Color3.fromRGB(r, g, b)
    PulseDot.BackgroundColor3 = col
    stroke.Color     = col
    TopBarGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(r//2, g//2, b//2)),
        ColorSequenceKeypoint.new(0.5, col),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(r//3, g//3, b//3)),
    })
end

local GlowLine = TopBar

-- ============================================================
-- ANTI-AFK
-- ============================================================
player.Idled:Connect(function()
    pcall(function()
        game:GetService("VirtualUser"):CaptureController()
        game:GetService("VirtualUser"):ClickButton2(Vector2.new(0,0))
    end)
end)

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
local function getChar()
    local char = player.Character
    if not char then return nil, nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return nil, nil, nil end
    return char, root, hum
end

local function getLocalWanderPos(root)
    for attempt = 1, 5 do
        local rx = math.random(-14, 14)
        local rz = math.random(-14, 14)
        if math.abs(rx) < 6 then rx = rx > 0 and 7 or -7 end
        if math.abs(rz) < 6 then rz = rz > 0 and 7 or -7 end
        local targetPos = root.Position + Vector3.new(rx, 0, rz)
        
        -- Проверка на бездну
        local ray = Ray.new(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0))
        local hit = workspace:FindPartOnRay(ray, player.Character)
        if hit then
            return targetPos
        end
    end
    return root.Position
end

-- ============================================================
-- PATHFINDING
-- ============================================================
local function walkPath(targetPos, maxWaypoints)
    local char, root, hum = getChar()
    if not char then return false end
    maxWaypoints = maxWaypoints or 999

    local path = Pathfinding:CreatePath({
        AgentRadius   = 2.5,
        AgentHeight   = 5,
        AgentCanJump  = true,
        WaypointSpacing = 3,
    })

    local ok = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(targetPos)
        return false
    end

    local wps = path:GetWaypoints()
    local count = math.min(#wps, maxWaypoints)

    for i = 2, count do
        char, root, hum = getChar()
        if not char or not _G.BotRunning then return false end

        if wps[i].Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end
        hum:MoveTo(wps[i].Position)

        local stuckTimer  = 0
        local lastPos     = root.Position
        local arrived     = false

        local conn
        conn = hum.MoveToFinished:Connect(function(reached)
            arrived = reached
        end)

        while not arrived and stuckTimer < 2 and _G.BotRunning do
            task.wait(0.1)
            stuckTimer += 0.1
            if (root.Position - lastPos).Magnitude < 0.3 and stuckTimer > 0.6 then
                hum.Jump = true
                break
            end
            lastPos = root.Position
        end
        conn:Disconnect()

        if (root.Position - targetPos).Magnitude < 4 then return true end
    end
    return (root.Position - targetPos).Magnitude < 6
end

local function walkDirect(targetPos)
    local char, root, hum = getChar()
    if not char then return end
    hum:MoveTo(targetPos)
    if root.AssemblyLinearVelocity.Magnitude < 1.5 then
        hum.Jump = true
        wanderTarget = nil
    end
end

-- ============================================================
-- NOCLIP TP
-- ============================================================
local function noclipTP(targetPos)
    local char, root, hum = getChar()
    if not char then return end

    local saved = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            saved[p] = true
            p.CanCollide = false
        end
    end

    local start   = tick()
    local timeout = 6

    while _G.BotRunning and (root.Position - targetPos).Magnitude > 2 and tick() - start < timeout do
        local dir  = (targetPos - root.Position).Unit
        local step = math.min(3, (root.Position - targetPos).Magnitude)
        local newP = root.Position + dir * step

        local ray    = Ray.new(newP + Vector3.new(0, 8, 0), Vector3.new(0, -16, 0))
        local hit, hitPos = workspace:FindPartOnRay(ray, char)
        if hit then
            newP = Vector3.new(newP.X, hitPos.Y + 3, newP.Z)
        end

        root.CFrame = CFrame.new(newP)
        task.wait(0.05)
    end

    for p in pairs(saved) do
        pcall(function() p.CanCollide = true end)
    end
end

-- ============================================================
-- D4: ЩИТ
-- ============================================================
local function ensureShield(root)
    if not shieldPart or not shieldPart.Parent then
        shieldPart = Instance.new("Part", workspace)
        shieldPart.Name         = "_BotShield"
        shieldPart.Size         = Vector3.new(10, 1, 10)
        shieldPart.Anchored     = true
        shieldPart.CanCollide   = true
        shieldPart.Transparency = Settings.ShowShield and 0.4 or 1
        shieldPart.Color        = Color3.fromRGB(0, 200, 255)
        shieldPart.CastShadow   = false
    end
    shieldPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 7, 0))
end

local function destroyShield()
    if shieldPart and shieldPart.Parent then shieldPart:Destroy() end
    shieldPart = nil
end

-- ============================================================
-- D10: ПАДАЮЩИЕ ПЛАТФОРМЫ (ФИКС: СОЗДАЁМ ПЛАТФОРМУ, ЖДЁМ, ТП)
-- ============================================================
local function getCurrentPlatformUnder(root)
    local ray = Ray.new(root.Position, Vector3.new(0, -6, 0))
    local hit = workspace:FindPartOnRay(ray, player.Character)
    return hit
end

-- ============================================================
-- ПОБЕГ ОТ МОНСТРОВ
-- ============================================================
local function escapeMonster(root, monsterPos)
    local char, _, hum = getChar()
    if not char then return end

    local awayDir = (root.Position - monsterPos).Unit
    local angles  = {0, 45, -45, 90, -90, 120, -120, 180}
    local bestDir, bestClear = awayDir, 0

    for _, angle in ipairs(angles) do
        local rad = math.rad(angle)
        local dir = Vector3.new(
            awayDir.X * math.cos(rad) - awayDir.Z * math.sin(rad),
            0,
            awayDir.X * math.sin(rad) + awayDir.Z * math.cos(rad)
        ).Unit

        local ray = Ray.new(root.Position + Vector3.new(0, 2, 0), dir * 18)
        local hit = workspace:FindPartOnRay(ray, player.Character)
        local clearDist = hit and (hit.Position - root.Position).Magnitude or 18

        if clearDist > bestClear then
            bestClear = clearDist
            bestDir   = dir
        end
    end

    if bestClear < 4 then hum.Jump = true end
    walkDirect(root.Position + bestDir * 22)
end

-- ============================================================
-- DETECTION
-- ============================================================
local function getClosestMonster(root, disaster)
    local closest, minDist = nil, 28
    local containers = {workspace}
    if disaster then table.insert(containers, disaster) end

    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetChildren()) do
            local lname = string.lower(obj.Name)
            if (string.find(lname, "zombie") or string.find(lname, "snowman")) and obj:FindFirstChild("HumanoidRootPart") then
                local d = (root.Position - obj.HumanoidRootPart.Position).Magnitude
                if d < minDist then minDist = d closest = obj.HumanoidRootPart end
            end
        end
    end
    return closest
end

local function getClosestKillPart(root, disaster)
    if not disaster then return nil end
    for _, obj in ipairs(disaster:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Kill" then
            if (root.Position - obj.Position).Magnitude < 22 then return obj end
        end
    end
    return nil
end

-- Проверка: есть ли у игрока оружие
local function playerHasWeapon(plr)
    if not plr.Character then return false end
    for _, tool in ipairs(plr.Character:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name == "ClassicSword" or tool.Name == "RocketLauncher" or tool.Name == "Knife") then
            return true, tool
        end
    end
    return false, nil
end

-- ============================================================
-- FLOOD DETECTION
-- ============================================================
local function isFloodActive(disaster)
    if not disaster then return false end
    for _, v in ipairs(disaster:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = string.lower(v.Name)
            if string.find(n,"water") or string.find(n,"flood") or string.find(n,"liquid") then
                return true
            end
        end
    end
    if disaster:FindFirstChild("Disaster1") or disaster:FindFirstChild("Disaster17") then return true end
    return false
end

local function floodEscape(root)
    local best, maxY = root.Position, -math.huge
    local towerFolder    = workspace:FindFirstChild("Tower")
    local diedPlaceObj   = workspace:FindFirstChild("DiedPlace")

    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide and p.Transparency < 0.85
           and not p:IsDescendantOf(player.Character) then
            if towerFolder  and p:IsDescendantOf(towerFolder)  then continue end
            if diedPlaceObj and p:IsDescendantOf(diedPlaceObj) then continue end
            local n = string.lower(p:GetFullName())
            if not string.find(n,"water") and not string.find(n,"flood")
               and not string.find(n,"liquid")
               and p.Size.X >= 4 and p.Size.Z >= 4 then
                if p.Position.Y > maxY then
                    maxY = p.Position.Y
                    best = p.Position
                end
            end
        end
    end
    local char, root2 = getChar()
    if root2 then root2.CFrame = CFrame.new(best + Vector3.new(0, 5, 0)) end
end

-- ============================================================
-- TYCOON HELPERS
-- ============================================================
local function getCheapestTycoonButton(disasterFolder)
    local cheapestBtn = nil
    local lowestPrice = math.huge
    if not disasterFolder then return nil, math.huge end
    for _, obj in ipairs(disasterFolder:GetDescendants()) do
        if obj.Name == "IButton" and obj:FindFirstChild("Detect") then
            pcall(function()
                local gui = obj:FindFirstChild("Gui")
                local info = gui and gui:FindFirstChild("Info")
                local priceLabel = info and info:FindFirstChild("Price")
                if priceLabel and (priceLabel:IsA("TextLabel") or priceLabel:IsA("TextBox")) then
                    local priceText = priceLabel.Text:gsub("%D", "")
                    local priceNum = tonumber(priceText)
                    if priceNum and priceNum < lowestPrice then
                        lowestPrice = priceNum
                        cheapestBtn = obj:FindFirstChild("Detect")
                    end
                end
            end)
        end
    end
    return cheapestBtn, lowestPrice
end

-- ============================================================
-- VIRTUAL MOUSE (RocketLauncher)
-- ============================================================
local mouse           = player:GetMouse()
local targetOverride  = nil
local isHoldingRocket = false
local d9WinReached    = false
local winReached      = false
local winBtnReached   = false

local ok, mt = pcall(getrawmetatable, game)
if ok and mt then
    local oldIndex = mt.__index
    pcall(setreadonly, mt, false)
    mt.__index = newcclosure(function(self, key)
        if self == mouse and isHoldingRocket and targetOverride and targetOverride.Parent then
            if key == "Hit"    then return targetOverride.CFrame end
            if key == "Target" then return targetOverride end
        end
        return oldIndex(self, key)
    end)
    pcall(setreadonly, mt, true)
end

-- ============================================================
-- CLEANUP
-- ============================================================
local function cleanupExtras()
    destroyShield()
    if standPart and standPart.Parent then standPart:Destroy() end
    standPart       = nil
    d10Initialized  = false
    targetOverride  = nil
    isHoldingRocket = false
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ
-- ============================================================
task.spawn(function()
    while _G.BotRunning do
        task.wait(0.12)
        pcall(function()

            local char, root, hum = getChar()
            if not char then cleanupExtras() return end

            if char ~= lastCharacter then
                lastCharacter = char
                wanderTarget  = nil
                d9WinReached  = false
                winReached    = false
                winBtnReached = false
                _G.d6ReturnPos = nil
                _G.d6TpCount = 0
                cleanupExtras()
            end

            local disaster = workspace:FindFirstChild("Disaster")

            if not disaster or #disaster:GetChildren() == 0 then
                d9WinReached  = false
                winReached    = false
                winBtnReached = false
            end

            local d2  = disaster and (disaster:FindFirstChild("Disaster2") or disaster:FindFirstChild("Hamster", true))
            local d3  = disaster and disaster:FindFirstChild("Disaster3")
            local d4  = disaster and disaster:FindFirstChild("Disaster4")
            local d6  = disaster and disaster:FindFirstChild("Disaster6")
            local d7  = disaster and disaster:FindFirstChild("Disaster7")
            local d9  = disaster and disaster:FindFirstChild("Disaster9")
            local d10 = disaster and disaster:FindFirstChild("Disaster10")
            local d11 = disaster and disaster:FindFirstChild("Disaster11")
            local d12 = disaster and disaster:FindFirstChild("Disaster12")
            local d15 = disaster and disaster:FindFirstChild("Disaster15")
            local d18 = disaster and disaster:FindFirstChild("Disaster18")
            local d19 = disaster and disaster:FindFirstChild("Disaster19")
            local d22 = disaster and disaster:FindFirstChild("Disaster22")
            local d24 = disaster and disaster:FindFirstChild("Disaster24")

            local activeMonster   = Settings.AntiMonster and getClosestMonster(root, disaster) or nil
            local dangerousKill   = getClosestKillPart(root, disaster)
            local floodActive     = Settings.AntiFlood and isFloodActive(disaster) or false

            local winPart     = Settings.AutoWin and disaster and disaster:FindFirstChild("Win", true) or nil
            local CLICKButton = Settings.AutoClick and workspace:FindFirstChild("CLICKButton", true) or nil
            local weapon      = char:FindFirstChild("ClassicSword") or player.Backpack:FindFirstChild("ClassicSword")
                             or char:FindFirstChild("RocketLauncher") or player.Backpack:FindFirstChild("RocketLauncher")
            local tycoonBtn, tycoonPrice = nil, 0
            if Settings.AutoTycoon then tycoonBtn, tycoonPrice = getCheapestTycoonButton(disaster) end
            local winButton = Settings.AutoTycoon and disaster and disaster:FindFirstChild("WinBUTTON", true) or nil

            -- ПРОВЕРКА: ВРАГ С ОРУЖИЕМ
            local enemyWithWeapon = nil
            if not weapon then
                for _, p in ipairs(game.Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local hasWep, tool = playerHasWeapon(p)
                        if hasWep then
                            local dist = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                            if dist < 40 then
                                enemyWithWeapon = p.Character.HumanoidRootPart
                                break
                            end
                        end
                    end
                end
            end

            -- ====================================================
            -- ИЕРАРХИЯ ПРИОРИТЕТОВ
            -- ====================================================

            -- ── DISASTER 3: OBBY ──────────────────────────────
            if d3 then
                cleanupExtras()
                setStatus("D3 OBBY: NOCLIP → WIN", 255, 80, 0)
                if winPart then
                    noclipTP(winPart.Position + Vector3.new(0, 2, 0))
                else
                    hum:MoveTo(root.Position)
                end

            -- ── DISASTER 4: BALLS ─────────────────────────────
            elseif d4 then
                if standPart and standPart.Parent then standPart:Destroy() standPart = nil end
                d10Initialized = false
                setStatus("D4 BALLS: SHIELD + ROAMING", 255, 140, 0)
                ensureShield(root)
                if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then
                    wanderTarget = getLocalWanderPos(root)
                end
                walkDirect(wanderTarget)

            -- ── DISASTER 6: NUKE (TP SAFEZONE 3x → ROAMING) ──
            elseif d6 then
                cleanupExtras()
                
                if not _G.d6TpCount then _G.d6TpCount = 0 end
                
                if _G.d6TpCount >= 3 then
                    setStatus("D6 NUKE: ROAMING (3 TP DONE)", 0, 200, 100)
                    if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then
                        wanderTarget = getLocalWanderPos(root)
                    end
                    walkDirect(wanderTarget)
                else
                    setStatus("D6 NUKE: TP → SAFEZONE → BACK (" .. (_G.d6TpCount + 1) .. "/3)", 220, 30, 30)
                    
                    if not _G.d6ReturnPos then
                        _G.d6ReturnPos = root.Position
                    end
                    
                    local zones = {}
                    for _, p in ipairs(d6:GetDescendants()) do
                        if p:IsA("BasePart") and string.lower(p.Name) == "safezone" then
                            table.insert(zones, p)
                        end
                    end
                    
                    if #zones > 0 then
                        local closest, closestDist = nil, math.huge
                        for _, z in ipairs(zones) do
                            local d = (root.Position - z.Position).Magnitude
                            if d < closestDist then closestDist = d closest = z end
                        end
                        
                        if closest then
                            root.CFrame = CFrame.new(closest.Position + Vector3.new(0, 3, 0))
                            setStatus("D6 NUKE: TOUCHED SAFEZONE! (" .. (_G.d6TpCount + 1) .. "/3)", 0, 255, 100)
                            task.wait(0.3)
                            
                            _G.d6TpCount = _G.d6TpCount + 1
                            
                            if _G.d6TpCount < 3 and _G.d6ReturnPos then
                                local ray = Ray.new(_G.d6ReturnPos + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0))
                                local hit = workspace:FindPartOnRay(ray, player.Character)
                                if hit then
                                    root.CFrame = CFrame.new(_G.d6ReturnPos)
                                    setStatus("D6 NUKE: RETURNED (" .. _G.d6TpCount .. "/3)", 0, 255, 140)
                                else
                                    local safeFound = false
                                    for attempt = 1, 8 do
                                        local rx = math.random(-20, 20)
                                        local rz = math.random(-20, 20)
                                        local testPos = _G.d6ReturnPos + Vector3.new(rx, 0, rz)
                                        local testRay = Ray.new(testPos + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0))
                                        if workspace:FindPartOnRay(testRay, player.Character) then
                                            root.CFrame = CFrame.new(testPos)
                                            safeFound = true
                                            setStatus("D6 NUKE: RETURNED NEARBY (" .. _G.d6TpCount .. "/3)", 0, 255, 140)
                                            break
                                        end
                                    end
                                    if not safeFound then
                                        setStatus("D6 NUKE: STAYING IN SAFEZONE", 255, 150, 0)
                                    end
                                end
                            else
                                _G.d6ReturnPos = nil
                                setStatus("D6 NUKE: 3 TP DONE, ROAMING", 0, 200, 100)
                            end
                        end
                    else
                        setStatus("D6 NUKE: NO SAFEZONE FOUND", 255, 150, 0)
                        if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then
                            wanderTarget = getLocalWanderPos(root)
                        end
                        walkDirect(wanderTarget)
                    end
                end

            -- ── DISASTER 9: MAZE ──────────────────────────────
            elseif d9 then
                cleanupExtras()
                if d9WinReached then
                    setStatus("D9 MAZE: WIN REACHED!", 0, 255, 140)
                    hum:MoveTo(root.Position)
                elseif winPart then
                    local dist = (root.Position - winPart.Position).Magnitude
                    if dist <= 5 then
                        d9WinReached = true
                        setStatus("D9 MAZE: WIN REACHED!", 0, 255, 140)
                        hum:MoveTo(root.Position)
                    else
                        setStatus("D9 MAZE: PATHFINDING TO WIN", 80, 0, 200)
                        walkPath(winPart.Position + Vector3.new(0, 2, 0), 20)
                        task.wait(0.3)
                        local _, root2 = getChar()
                        if root2 then
                            local newDist = (root2.Position - winPart.Position).Magnitude
                            if newDist <= 5 then
                                d9WinReached = true
                            elseif newDist > 8 then
                                setStatus("D9 MAZE: NOCLIP FALLBACK!", 160, 0, 255)
                                noclipTP(winPart.Position + Vector3.new(0, 2, 0))
                                d9WinReached = true
                            end
                        end
                    end
                end

            -- ── DISASTER 10: FALLING PLATFORMS (ФИКС) ─────────
            elseif d10 then
                if shieldPart and shieldPart.Parent then destroyShield() end
                setStatus("D10 PLATFORMS: CREATING SAFE PLATFORM", 255, 200, 0)
                
                -- Создаём платформу под ботом
                if not standPart or not standPart.Parent then
                    standPart = Instance.new("Part", workspace)
                    standPart.Name        = "_BotStandPlatform"
                    standPart.Size        = Vector3.new(6, 1, 6)
                    standPart.Anchored    = true
                    standPart.CanCollide  = true
                    standPart.Transparency = 0.5
                    standPart.Color       = Color3.fromRGB(0, 255, 140)
                    standPart.Material    = Enum.Material.Neon
                end
                standPart.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0))
                
                setStatus("D10 PLATFORMS: WAITING 1s → TP", 255, 200, 0)
                task.wait(1)
                
                -- ТП на платформу
                if standPart and standPart.Parent then
                    root.CFrame = CFrame.new(standPart.Position + Vector3.new(0, 4, 0))
                    setStatus("D10 PLATFORMS: SAFE ON PLATFORM", 0, 255, 140)
                end

            -- ── DISASTER 11: BUTTON CLICKER ──────────────────
            elseif d11 then
                cleanupExtras()
                setStatus("D11 BUTTON: SPAM CLICKING!", 255, 255, 0)
                local btn = nil
                for _, obj in ipairs(d11:GetDescendants()) do
                    if obj:IsA("ClickDetector") and string.find(obj.Name, "TableNButtonClickDetector") then
                        btn = obj
                        break
                    end
                end
                if not btn then
                    btn = d11:FindFirstChildOfClass("ClickDetector", true)
                end
                if btn then
                    local btnPart = btn.Parent
                    if (root.Position - btnPart.Position).Magnitude > 8 then
                        walkPath(btnPart.Position)
                    else
                        fireclickdetector(btn)
                    end
                end

            -- ── FLOOD ────────────────────────────────────────
            elseif floodActive then
                cleanupExtras()
                setStatus("FLOOD: TP TO HIGH GROUND!", 255, 50, 50)
                floodEscape(root)

            -- ── ВРАГ С ОРУЖИЕМ (бота нет оружия) ────────────
            elseif enemyWithWeapon then
                cleanupExtras()
                setStatus("⚠️ ENEMY ARMED! ESCAPING", 255, 0, 80)
                escapeMonster(root, enemyWithWeapon.Position)

            -- ── MONSTER ESCAPE ───────────────────────────────
            elseif activeMonster then
                cleanupExtras()
                setStatus("MONSTER: SMART ESCAPE!", 255, 0, 50)
                escapeMonster(root, activeMonster.Position)

            -- ── KILL PART DODGE ──────────────────────────────
            elseif dangerousKill then
                cleanupExtras()
                setStatus("KILL LASER: DODGE!", 255, 0, 255)
                hum.Jump = true
                local dodge = Vector3.new(dangerousKill.CFrame.LookVector.Z, 0, -dangerousKill.CFrame.LookVector.X) * 14
                walkDirect(root.Position + dodge)

            -- ── DISASTER 2: HAMSTER ──────────────────────────
            elseif d2 then
                cleanupExtras()
                setStatus("D2 HAMSTER: CLICKING!", 255, 150, 0)
                local cd = d2:FindFirstChildOfClass("ClickDetector", true)
                if cd then
                    local target = cd.Parent
                    walkDirect(target.Position)
                    if (root.Position - target.Position).Magnitude < 16 then
                        fireclickdetector(cd)
                    end
                end

            -- ── DISASTER 7: MURDER ───────────────────────────
            elseif d7 then
                cleanupExtras()
                setStatus("D7 MURDER: EVADING KILLER", 100, 0, 100)
                for _, p in ipairs(game.Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("Knife", true) then
                        local knifeRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        if knifeRoot and (root.Position - knifeRoot.Position).Magnitude < 45 then
                            escapeMonster(root, knifeRoot.Position)
                        end
                    end
                end

            -- ── DISASTER 19: LASER ROOM ──────────────────────
            elseif d19 then
                cleanupExtras()
                setStatus("D19 LASER: DODGING ONLY", 255, 0, 180)
                local killPart = getClosestKillPart(root, disaster)
                if killPart then
                    hum.Jump = true
                    local dodge = Vector3.new(killPart.CFrame.LookVector.Z, 0, -killPart.CFrame.LookVector.X) * 14
                    walkDirect(root.Position + dodge)
                else
                    hum:MoveTo(root.Position)
                end

            -- ── DISASTER 22: CHRISTMAS ───────────────────────
            elseif d22 then
                cleanupExtras()
                setStatus("D22 XMAS: PROXIMITY PROMPT", 0, 255, 120)
                local prompt = d22:FindFirstChildOfClass("ProximityPrompt", true)
                if prompt then
                    local pp = prompt.Parent
                    walkDirect(pp.Position)
                    if (root.Position - pp.Position).Magnitude < prompt.MaxActivationDistance then
                        fireproximityprompt(prompt)
                    end
                end

            -- ── DISASTER 24: COLOR BLOCK ─────────────────────
            elseif d24 then
                cleanupExtras()
                setStatus("D24 COLOR BLOCK: SAFE ZONE", 255, 0, 100)
                local blocks = workspace:FindFirstChild("Blocks")
                local safePart = blocks and blocks:FindFirstChild("Part")
                if safePart then
                    if (root.Position - safePart.Position).Magnitude > 4 then
                        walkPath(safePart.Position + Vector3.new(0, 5, 0))
                    end
                end

            -- ── TYCOON: IButton ──────────────────────────────
            elseif tycoonBtn then
                cleanupExtras()
                winBtnReached = false
                setStatus("TYCOON: BUYING ($" .. tycoonPrice .. ")", 0, 230, 255)
                local distanceToBtn = (root.Position - tycoonBtn.Position).Magnitude
                if distanceToBtn <= 4 then
                    hum.Jump = true
                    local drift = (tick() % 1 > 0.5) and 1 or -1
                    walkDirect(tycoonBtn.Position + Vector3.new(drift, 0, 0))
                else
                    walkPath(tycoonBtn.Position)
                end

            -- ── TYCOON: WinBUTTON ────────────────────────────
            elseif winButton and not winBtnReached then
                cleanupExtras()
                setStatus("TYCOON FINISHED: WINBUTTON!", 255, 0, 180)
                local targetNode = winButton:FindFirstChild("Detect")
                    or winButton:FindFirstChildWhichIsA("BasePart", true)
                    or winButton
                local distanceToWinBtn = (root.Position - targetNode.Position).Magnitude
                if distanceToWinBtn <= 4 then
                    winBtnReached = true
                    hum.Jump = true
                    local drift = (tick() % 1 > 0.5) and 1 or -1
                    walkDirect(targetNode.Position + Vector3.new(drift, 0, 0))
                else
                    walkPath(targetNode.Position)
                end

            elseif winButton and winBtnReached then
                cleanupExtras()
                setStatus("TYCOON: WIN DONE, WAITING", 0, 255, 140)
                hum:MoveTo(root.Position)

            -- ── ОРУЖИЕ (Sword / RocketLauncher) ──────────────
            elseif weapon then
                cleanupExtras()
                
                if weapon.Parent == player.Backpack then
                    hum:EquipTool(weapon)
                    task.wait(0.15)
                end
                
                weapon = char:FindFirstChild("ClassicSword") or char:FindFirstChild("RocketLauncher")
                if not weapon then
                    targetOverride = nil
                    isHoldingRocket = false
                    setStatus("ROAMING (NO WEAPON EQUIPPED)", 0, 255, 140)
                    if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then
                        wanderTarget = getLocalWanderPos(root)
                    end
                    walkDirect(wanderTarget)
                else
                    isHoldingRocket = (weapon.Name == "RocketLauncher")
                    
                    local target, targetPlayer = nil, nil
                    local bestDist = 1000
                    for _, p in ipairs(game.Players:GetPlayers()) do
                        if p ~= player and p.Character
                        and p.Character:FindFirstChild("HumanoidRootPart")
                        and p.Character:FindFirstChildOfClass("Humanoid")
                        and p.Character.Humanoid.Health > 0 then
                            local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                            if d < bestDist then
                                bestDist = d
                                target = p.Character.HumanoidRootPart
                                targetPlayer = p
                            end
                        end
                    end
                    
                    if target and targetPlayer then
                        targetOverride = target
                        root.CFrame = CFrame.new(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
                        
                        if isHoldingRocket then
                            setStatus("ROCKET: FIRING AT " .. targetPlayer.Name, 255, 80, 0)
                            if bestDist > 25 then
                                hum:MoveTo(target.Position)
                            elseif bestDist < 12 then
                                local back = root.Position + (root.Position - target.Position).Unit * 15
                                hum:MoveTo(back)
                            else
                                hum:MoveTo(root.Position)
                            end
                            local cam = workspace.CurrentCamera
                            if cam then cam.CFrame = CFrame.new(cam.CFrame.Position, target.Position) end
                            pcall(function() weapon:Activate() end)
                        else
                            setStatus("SWORD: ATTACKING " .. targetPlayer.Name, 255, 60, 0)
                            hum:MoveTo(target.Position)
                            pcall(function() weapon:Activate() end)
                            task.wait(0.05)
                            pcall(function() weapon:Activate() end)
                        end
                    else
                        targetOverride = nil
                        isHoldingRocket = false
                        setStatus("ROAMING (NO TARGETS)", 0, 255, 140)
                        if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then
                            wanderTarget = getLocalWanderPos(root)
                        end
                        walkDirect(wanderTarget)
                    end
                end

            -- ── WIN PART ─────────────────────────────────────
            elseif winPart and not winReached then
                cleanupExtras()
                local distToWin = (root.Position - winPart.Position).Magnitude
                if distToWin <= 5 then
                    winReached = true
                    setStatus("WIN REACHED! STANDING BY", 0, 255, 140)
                    hum:MoveTo(root.Position)
                else
                    setStatus("PATHFINDING TO WIN PART!", 180, 50, 255)
                    walkPath(winPart.Position)
                end

            elseif winPart and winReached then
                cleanupExtras()
                setStatus("WIN REACHED! STANDING BY", 0, 255, 140)
                hum:MoveTo(root.Position)

            -- ── CLICK BUTTON ─────────────────────────────────
            elseif CLICKButton then
                cleanupExtras()
                setStatus("MOVING TO START BUTTON", 0, 150, 255)
                local pos = CLICKButton:IsA("BasePart") and CLICKButton.Position or CLICKButton.Parent.Position
                walkDirect(pos)
                if (root.Position - pos).Magnitude < 12 then
                    local cd = CLICKButton:FindFirstChildOfClass("ClickDetector") or CLICKButton
                    fireclickdetector(cd)
                end

            -- ── IDLE ROAMING ─────────────────────────────────
            else
                if not d4 then destroyShield() end
                if standPart and standPart.Parent then standPart:Destroy() standPart = nil end
                targetOverride = nil; isHoldingRocket = false
                setStatus("ROAMING (SAFE IDLE)", 0, 255, 140)
                if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then
                    wanderTarget = getLocalWanderPos(root)
                end
                walkDirect(wanderTarget)
            end

        end) -- pcall
    end -- while
end) -- task.spawn

print("[BOT v2.0] Loaded. Don't Press The Button X")
print("[BOT] Aggressive mode: ON | Anti-void roaming: ON | D10 platform fix: ON")
