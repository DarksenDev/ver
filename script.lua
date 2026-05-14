-- CLEANUP PREVIOUS SESSIONS
for _, old in pairs(game.CoreGui:GetChildren()) do
    if old.Name == "PremiumSurvivorAI" or old.Name == "SurvivorHub" then old:Destroy() end
end
if workspace:FindFirstChild("Disaster24_SafePlatform") then workspace.Disaster24_SafePlatform:Destroy() end

_G.BotRunning = true
local player = game.Players.LocalPlayer
local Pathfinding = game:GetService("PathfindingService")
local wanderTarget = nil
local safePlatform = nil
local lastCharacter = nil

-- PREMIUM COMPACT GUI
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "PremiumSurvivorAI"

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Size = UDim2.new(0, 280, 0, 100)
Main.Position = UDim2.new(0.5, -140, 0.05, 0)
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local GlowLine = Instance.new("Frame", Main)
GlowLine.Size = UDim2.new(1, 0, 0, 3)
GlowLine.BorderSizePixel = 0
GlowLine.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
Instance.new("UICorner", GlowLine).CornerRadius = UDim.new(0, 3)

local InnerFrame = Instance.new("Frame", Main)
InnerFrame.Size = UDim2.new(1, -20, 1, -25)
InnerFrame.Position = UDim2.new(0, 10, 0, 15)
InnerFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Instance.new("UICorner", InnerFrame).CornerRadius = UDim.new(0, 8)

local PulseDot = Instance.new("Frame", InnerFrame)
PulseDot.Size = UDim2.new(0, 8, 0, 8)
PulseDot.Position = UDim2.new(0, 15, 0, 26)
PulseDot.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
Instance.new("UICorner", PulseDot).CornerRadius = UDim.new(1, 0)

local Status = Instance.new("TextLabel", InnerFrame)
Status.Size = UDim2.new(1, -40, 1, 0)
Status.Position = UDim2.new(0, 32, 0, 0)
Status.BackgroundTransparency = 1
Status.Text = "INITIALIZING MULTI-AI..."
Status.TextColor3 = Color3.fromRGB(245, 245, 245)
Status.TextSize = 12
Status.Font = Enum.Font.GothamBold
Status.TextXAlignment = Enum.TextXAlignment.Left

-- ANTI-AFK & REJOIN
player.Idled:Connect(function()
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new(0,0))
end)
game:GetService("GuiService").ErrorMessageChanged:Connect(function()
    task.wait(5) game:GetService("TeleportService"):Teleport(game.PlaceId, player)
end)

-- НАВИГАЦИЯ
local function walkSmooth(targetPos)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    hum:MoveTo(targetPos)
    if root.AssemblyLinearVelocity.Magnitude < 3 then
        hum.Jump = true
        local sideBypass = targetPos + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
        hum:MoveTo(sideBypass)
    end
end

local function walkDirect(targetPos)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    hum:MoveTo(targetPos)
    if root.AssemblyLinearVelocity.Magnitude < 2.5 then hum.Jump = true wanderTarget = nil end
end

local function getLocalWanderPos(root)
    local rx = math.random(-14, 14) local rz = math.random(-14, 14)
    if math.abs(rx) < 6 then rx = rx > 0 and 6 or -6 end
    if math.abs(rz) < 6 then rz = rz > 0 and 6 or -6 end
    return root.Position + Vector3.new(rx, 0, rz)
end

-- ПОИСК БЛИЖАЙШЕГО ЗОМБИ ИЛИ СНЕГОВИКА
local function getClosestMonster(root, disasterFolder)
    local closest = nil
    local minDist = 25
    local scanTargets = {}
    if disasterFolder then table.insert(scanTargets, disasterFolder) end
    table.insert(scanTargets, workspace)

    for _, container in ipairs(scanTargets) do
        for _, obj in ipairs(container:GetChildren()) do
            if (string.find(string.lower(obj.Name), "zombie") or string.find(string.lower(obj.Name), "snowman")) and obj:FindFirstChild("HumanoidRootPart") then
                local d = (root.Position - obj.HumanoidRootPart.Position).Magnitude
                if d < minDist then minDist = d closest = obj.HumanoidRootPart end
            end
        end
    end
    return closest
end

-- ПОИСК ОПАСНЫХ ЛАЗЕРОВ
local function getClosestLaser(root, disasterFolder)
    if not disasterFolder then return nil end
    for _, obj in ipairs(disasterFolder:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Kill" then
            local d = (root.Position - obj.Position).Magnitude
            if d < 12 then return obj end
        end
    end
    return nil
end

-- TYCOON SCANNER
local function getCheapestTycoonButton(disasterFolder)
    local cheapestBtn = nil
    local lowestPrice = math.huge
    for _, obj in ipairs(disasterFolder:GetDescendants()) do
        if obj.Name == "IButton" and obj:FindFirstChild("Detect") then
            pcall(function()
                local gui = obj:FindFirstChild("Gui")
                local info = gui and gui:FindFirstChild("Info")
                local priceLabel = info and info:FindFirstChild("Price")
                if priceLabel and (priceLabel:IsA("TextLabel") or priceLabel:IsA("TextBox")) then
                    local priceText = priceLabel.Text:gsub("%D", "")
                    local priceNum = tonumber(priceText)
                    if priceNum and priceNum < lowestPrice then lowestPrice = priceNum cheapestBtn = obj:FindFirstChild("Detect") end
                end
            end)
        end
    end
    return cheapestBtn, lowestPrice
end

-- VIRTUAL MOUSE INTERCEPT
local mouse = player:GetMouse()
local targetOverride = nil
local isHoldingRocket = false

local mt = getrawmetatable(game)
local oldIndex = mt.__index
setreadonly(mt, false)
mt.__index = newcclosure(function(self, key)
    if self == mouse and isHoldingRocket and targetOverride and targetOverride.Parent then
        if key == "Hit" then return targetOverride.CFrame
        elseif key == "Target" then return targetOverride end
    end
    return oldIndex(self, key)
end)
setreadonly(mt, true)

-- MAIN AI LOOP
task.spawn(function()
    while _G.BotRunning do
        task.wait(0.1)
        pcall(function()
            local char = player.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            local disaster = workspace:FindFirstChild("Disaster")

            if not root or not hum or hum.Health <= 0 then targetOverride = nil isHoldingRocket = false return end
            if player.Character ~= lastCharacter then lastCharacter = player.Character wanderTarget = nil end

            -- УЛУЧШЕННОЕ ГЛОБАЛЬНОЕ ОПРЕДЕЛЕНИЕ ЛЮБОЙ ВОДЫ/FLOOD/TSUNAMI
            local waterDetected = false
            if disaster then
                -- Ищем совпадения по именам Water, Flood, Liquid, Disaster1, Disaster17 в папке и подпапках
                for _, v in ipairs(disaster:GetDescendants()) do
                    if v:IsA("BasePart") and (string.find(string.lower(v.Name), "water") or string.find(string.lower(v.Name), "flood") or string.find(string.lower(v.Name), "liquid") or v.Name == "Disaster1" or v.Name == "Disaster17") then
                        waterDetected = true
                        break
                    end
                end
            end

            -- ОСТАЛЬНЫЕ КАТАСТРОФЫ
            local d2 = disaster and (disaster:FindFirstChild("Disaster2") or disaster:FindFirstChild("Hamster", true))
            local d4 = disaster and disaster:FindFirstChild("Disaster4")
            local d6 = disaster and disaster:FindFirstChild("Disaster6")
            local d7 = disaster and disaster:FindFirstChild("Disaster7")
            local d12 = disaster and disaster:FindFirstChild("Disaster12")
            local d14_15 = disaster and (disaster:FindFirstChild("Disaster14") or disaster:FindFirstChild("Disaster15"))
            local d22 = disaster and disaster:FindFirstChild("Disaster22")
            local d24 = disaster and disaster:FindFirstChild("Disaster24")

            local activeMonster = getClosestMonster(root, disaster)
            local dangerousLaser = getClosestLaser(root, disaster)

            local win = disaster and disaster:FindFirstChild("Win", true)
            local CLICKButton = workspace:FindFirstChild("CLICKButton", true)
            local weapon = char:FindFirstChild("ClassicSword") or player.Backpack:FindFirstChild("ClassicSword") or char:FindFirstChild("RocketLauncher") or player.Backpack:FindFirstChild("RocketLauncher")

            local tycoonBtn, tycoonPrice = nil, nil
            local winButton = disaster and disaster:FindFirstChild("WinBUTTON", true)
            if disaster then tycoonBtn, tycoonPrice = getCheapestTycoonButton(disaster) end

            -- ИЕРАРХИЯ ЛОГИКИ С ИСПРАВЛЕННЫМ FLOOD TP
            if d24 then
                Status.Text = "EVENT 24: COLOR BLOCK SAFE"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 100)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 0, 100)
                targetOverride = nil; isHoldingRocket = false
                local platformPos = Vector3.new(-135, 34.5, 78)
                if not safePlatform or not safePlatform.Parent then
                    safePlatform = Instance.new("Part", workspace)
                    safePlatform.Name = "Disaster24_SafePlatform"
                    safePlatform.Size = Vector3.new(12, 1, 12)
                    safePlatform.Position = platformPos - Vector3.new(0, 2, 0)
                    safePlatform.Anchored = true
                    safePlatform.Material = Enum.Material.Glass
                    safePlatform.Transparency = 0.5
                    safePlatform.Color = Color3.fromRGB(0, 255, 255)
                end
                if (root.Position - platformPos).Magnitude > 4 then root.CFrame = CFrame.new(platformPos) else hum:MoveTo(root.Position) end

            -- 100% ФИКС ТЕЛЕПОРТА ОТ НАВОДНЕНИЙ FLOOD И TSUNAMI
            elseif waterDetected then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "⚡ EMERGENCY TP: EVADING WATER/FLOOD"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                targetOverride = nil; isHoldingRocket = false

                local bestSafePoint = root.Position
                local maxElevation = -math.huge

                -- Ищем самую надежную деталь в Disaster для спасения
                for _, p in pairs(disaster:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide and p.Transparency < 0.9 then
                        local nameLower = string.lower(p.Name)
                        -- Жестко игнорируем саму воду, жижу, триггеры и зоны спавна
                        if not string.find(nameLower, "water") and not string.find(nameLower, "flood") and not string.find(nameLower, "liquid") and not string.find(nameLower, "zone") then
                            -- Фильтр устойчивости: деталь должна быть широкой (не столб и не тонкая балка)
                            if p.Size.X >= 4 and p.Size.Z >= 4 then
                                -- Выбираем абсолютный максимум высоты на устойчивой поверхности
                                if p.Position.Y > maxElevation then
                                    maxElevation = p.Position.Y
                                    bestSafePoint = p.Position
                                end
                            end
                        end
                    end
                end
                -- Смещаемся ровно на центр крыши/платформы и прибавляем +4 блока для безопасности
                root.CFrame = CFrame.new(bestSafePoint + Vector3.new(0, 4, 0))

            elseif activeMonster then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "⚠️ ESCAPING MONSTER!"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 50)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 0, 50)
                targetOverride = nil; isHoldingRocket = false
                local escapeDirection = (root.Position - activeMonster.Position).Unit * 25
                walkDirect(root.Position + escapeDirection)

            elseif dangerousLaser then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "⚡ DODGING 'KILL' LASER!"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
                targetOverride = nil; isHoldingRocket = false
                hum.Jump = true
                local dodgeVector = Vector3.new(dangerousLaser.CFrame.LookVector.Z, 0, -dangerousLaser.CFrame.LookVector.X) * 12
                walkDirect(root.Position + dodgeVector)

            elseif d2 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 2: SPAMMING HAMSTER"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
                targetOverride = nil; isHoldingRocket = false
                local hamster = disaster:FindFirstChild("Hamster", true) or disaster:FindFirstChildOfClass("ClickDetector", true)
                if hamster then
                    local target = hamster:IsA("ClickDetector") and hamster.Parent or hamster
                    walkDirect(target.Position)
                    fireclickdetector(hamster:IsA("ClickDetector") and hamster or target:FindFirstChildOfClass("ClickDetector"))
                end

            elseif d4 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 4: DODGING BALLS"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 230, 0)
                targetOverride = nil; isHoldingRocket = false
                local dangerousBall = disaster:FindFirstChildOfClass("Part", true)
                if dangerousBall and (dangerousBall.Position - root.Position).Magnitude < 15 and dangerousBall.Position.Y > root.Position.Y then
                    root.CFrame = root.CFrame * CFrame.new(math.random(-10,10), 0, math.random(-10,10))
                end

            elseif d6 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 6: NUKE SHELTERING"
                GlowLine.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
                targetOverride = nil; isHoldingRocket = false
                local shelter = disaster:FindFirstChildWhichIsA("BasePart", true)
                if shelter and shelter.Anchored then walkSmooth(shelter.Position) end

            elseif d7 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 7: EVADING MURDERER"
                GlowLine.BackgroundColor3 = Color3.fromRGB(100, 0, 100)
                targetOverride = nil; isHoldingRocket = false
                for _, p in pairs(game.Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("Knife", true) then
                        if (root.Position - p.Character.HumanoidRootPart.Position).Magnitude < 40 then
                            walkDirect(root.Position + (root.Position - p.Character.HumanoidRootPart.Position).Unit * 35)
                        end
                    end
                end

            elseif d22 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 22: CHRISTMAS PROMPTS"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
                PulseDot.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
                targetOverride = nil; isHoldingRocket = false
                local prompt = disaster:FindFirstChildOfClass("ProximityPrompt", true)
                if prompt then
                    local parentPart = prompt.Parent
                    walkDirect(parentPart.Position)
                    if (root.Position - parentPart.Position).Magnitude < prompt.MaxActivationDistance then
                        fireproximityprompt(prompt)
                    end
                end

            elseif d12 or d14_15 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 12/14/15: SHELTER"
                GlowLine.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
                targetOverride = nil; isHoldingRocket = false
                for _, obj in pairs(disaster:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Position.Y > root.Position.Y + 8 and obj.Size.X > 6 then
                        walkDirect(obj.Position - Vector3.new(0, 8, 0)) break
                    end
                end

            elseif weapon then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "HUNTING ENEMIES WITH " .. weapon.Name:upper()
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
                if weapon.Parent == player.Backpack then hum:EquipTool(weapon) end
                
                isHoldingRocket = (weapon.Name == "RocketLauncher")
                local target = nil local dist = 1000
                for _, p in pairs(game.Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.Humanoid.Health > 0 then
                        local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                        if d < dist then dist = d target = p.Character.HumanoidRootPart end
                    end
                end
                if target then
                    targetOverride = target
                    if isHoldingRocket then
                        if dist > 10 then walkSmooth(target.Position) else hum:MoveTo(root.Position) end
                        workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, target.Position)
                    else 
                        targetOverride = nil; isHoldingRocket = false
                        walkDirect(target.Position) 
                    end
                    root.CFrame = CFrame.new(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
                    weapon:Activate()
                else
                    targetOverride = nil; isHoldingRocket = false
                end

            elseif tycoonBtn then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                targetOverride = nil; isHoldingRocket = false
                Status.Text = "TYCOON: BUYING ($" .. tycoonPrice .. ")"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
                PulseDot.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
                
                local distanceToBtn = (root.Position - tycoonBtn.Position).Magnitude
                if distanceToBtn <= 4 then
                    hum.Jump = true
                    local drift = (tick() % 1 > 0.5) and 1 or -1
                    walkDirect(tycoonBtn.Position + Vector3.new(drift, 0, 0))
                else
                    walkSmooth(tycoonBtn.Position)
                end

            elseif winButton then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                targetOverride = nil; isHoldingRocket = false
                Status.Text = "TYCOON FINISHED: WINBUTTON ACTIVE"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 180)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 0, 180)
                
                local targetNode = winButton:FindFirstChild("Detect") or winButton:FindFirstChildWhichIsA("BasePart", true) or winButton
                local distanceToWinBtn = (root.Position - targetNode.Position).Magnitude
                
                if distanceToWinBtn <= 4 then
                    hum.Jump = true
                    local drift = (tick() % 1 > 0.5) and 1 or -1
                    walkDirect(targetNode.Position + Vector3.new(drift, 0, 0))
                else
                    walkSmooth(targetNode.Position)
                end

            elseif tableBtn then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                targetOverride = nil; isHoldingRocket = false
                Status.Text = "SPAMMING GAME TABLE"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                walkDirect(tableBtn.Parent.Position)
                if (root.Position - tableBtn.Parent.Position).Magnitude < 10 then fireclickdetector(tableBtn) end

            elseif win then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                targetOverride = nil; isHoldingRocket = false
                Status.Text = "GOING TO WIN PART..."
                GlowLine.BackgroundColor3 = Color3.fromRGB(180, 50, 255)
                PulseDot.BackgroundColor3 = Color3.fromRGB(180, 50, 255)
                walkSmooth(win.Position)

            elseif CLICKButton then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                targetOverride = nil; isHoldingRocket = false
                Status.Text = "MOVING TO START BUTTON"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
                local pos = CLICKButton:IsA("BasePart") and CLICKButton.Position or CLICKButton.Parent.Position
                walkDirect(pos)
                if (root.Position - pos).Magnitude < 10 then fireclickdetector(CLICKButton:FindFirstChildOfClass("ClickDetector") or CLICKButton) end
            else
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                targetOverride = nil; isHoldingRocket = false
                Status.Text = "LOCAL ROAMING (SAFE IDLE)"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
                if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then wanderTarget = getLocalWanderPos(root) end
                walkDirect(wanderTarget)
            end
        end)
    end
end)
