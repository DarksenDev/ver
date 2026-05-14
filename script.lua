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
Status.Text = "INITIALIZING AGENT..."
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
local function walkPath(targetPos)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    local path = Pathfinding:CreatePath({AgentRadius = 2.5, AgentCanJump = true, WaypointSpacing = 4})
    local success, _ = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
    if success and path.Status == Enum.PathStatus.Success then
        local wps = path:GetWaypoints()
        for i = 1, math.min(#wps, 4) do
            if not _G.BotRunning or hum.Health <= 0 then break end
            hum:MoveTo(wps[i].Position)
            if wps[i].Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            local arrived = hum.MoveToFinished:Wait(0.2)
            if not arrived and root.AssemblyLinearVelocity.Magnitude < 2.5 then hum.Jump = true wanderTarget = nil break end
        end
    else
        hum:MoveTo(targetPos)
        if root.AssemblyLinearVelocity.Magnitude < 2.5 then hum.Jump = true wanderTarget = nil end
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

-- MAIN AI LOOP
task.spawn(function()
    while _G.BotRunning do
        task.wait(0.1)
        pcall(function()
            local char = player.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            local disaster = workspace:FindFirstChild("Disaster")

            if not root or not hum or hum.Health <= 0 then return end
            if player.Character ~= lastCharacter then lastCharacter = player.Character wanderTarget = nil end

            -- КАТАСТРОФЫ И СОБЫТИЯ
            local d1_17 = disaster and (disaster:FindFirstChild("Disaster1") or disaster:FindFirstChild("Disaster17") or disaster:FindFirstChild("Water", true) or disaster:FindFirstChild("Flood", true))
            local d2 = disaster and (disaster:FindFirstChild("Disaster2") or disaster:FindFirstChild("Hamster", true))
            local d4 = disaster and disaster:FindFirstChild("Disaster4")
            local d5 = disaster and (disaster:FindFirstChild("Disaster5") or workspace:FindFirstChild("Zombie") or workspace:FindFirstChild("Zombie", true))
            local d6 = disaster and disaster:FindFirstChild("Disaster6")
            local d7 = disaster and disaster:FindFirstChild("Disaster7")
            local d12 = disaster and disaster:FindFirstChild("Disaster12")
            local d14_15 = disaster and (disaster:FindFirstChild("Disaster14") or disaster:FindFirstChild("Disaster15"))
            local d19 = disaster and disaster:FindFirstChild("Disaster19")
            local d20 = disaster and (disaster:FindFirstChild("Disaster20") or workspace:FindFirstChild("Snowman") or workspace:FindFirstChild("Snowman", true))
            local d22 = disaster and disaster:FindFirstChild("Disaster22")
            local d24 = disaster and disaster:FindFirstChild("Disaster24")

            local win = disaster and disaster:FindFirstChild("Win", true)
            local CLICKButton = workspace:FindFirstChild("CLICKButton", true)
            local weapon = char:FindFirstChild("ClassicSword") or player.Backpack:FindFirstChild("ClassicSword") or char:FindFirstChild("RocketLauncher") or player.Backpack:FindFirstChild("RocketLauncher")

            -- ИЕРАРХИЯ ЛОГИКИ
            if d24 then
                Status.Text = "EVENT 24: COLOR BLOCK SAFE"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 100)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 0, 100)
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

            elseif d1_17 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 1/17: WATER TP ESCAPE"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                local bestSafePoint = root.Position
                local maxElevation = -math.huge
                for _, p in pairs(disaster:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide and p.Name ~= "Water" and p.Name ~= "Flood" and p.Size.X >= 4 and p.Size.Z >= 4 then
                        if p.Position.Y > maxElevation then maxElevation = p.Position.Y bestSafePoint = p.Position end
                    end
                end
                root.CFrame = CFrame.new(bestSafePoint + Vector3.new(0, 4, 0))

            elseif d5 or d20 then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "EVENT 5/20: FLEEING MONSTER"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 50)
                PulseDot.BackgroundColor3 = Color3.fromRGB(255, 0, 50)
                local monster = d5 or d20
                if monster and monster:FindFirstChild("HumanoidRootPart") then
                    if (root.Position - monster.HumanoidRootPart.Position).Magnitude < 25 then
                        walkDirect(root.Position + (root.Position - monster.HumanoidRootPart.Position).Unit * 30)
                    end
                end

            elseif d2 then
                Status.Text = "EVENT 2: SPAMMING HAMSTER"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
                local hamster = disaster:FindFirstChild("Hamster", true) or disaster:FindFirstChildOfClass("ClickDetector", true)
                if hamster then
                    local target = hamster:IsA("ClickDetector") and hamster.Parent or hamster
                    walkDirect(target.Position)
                    fireclickdetector(hamster:IsA("ClickDetector") and hamster or target:FindFirstChildOfClass("ClickDetector"))
                end

            elseif d4 then
                Status.Text = "EVENT 4: DODGING FALLING BALLS"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 230, 0)
                local dangerousBall = disaster:FindFirstChildOfClass("Part", true)
                if dangerousBall and (dangerousBall.Position - root.Position).Magnitude < 15 and dangerousBall.Position.Y > root.Position.Y then
                    root.CFrame = root.CFrame * CFrame.new(math.random(-10,10), 0, math.random(-10,10))
                end

            elseif d6 then
                Status.Text = "EVENT 6: NUKE SHELTERING"
                GlowLine.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
                local shelter = disaster:FindFirstChildWhichIsA("BasePart", true)
                if shelter and shelter.Anchored then walkPath(shelter.Position) end

            elseif d7 then
                Status.Text = "EVENT 7: EVADING MURDERER"
                GlowLine.BackgroundColor3 = Color3.fromRGB(100, 0, 100)
                for _, p in pairs(game.Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("Knife", true) then
                        if (root.Position - p.Character.HumanoidRootPart.Position).Magnitude < 40 then
                            walkDirect(root.Position + (root.Position - p.Character.HumanoidRootPart.Position).Unit * 35)
                        end
                    end
                end

            -- СБОР ПОДАРКОВ ЧЕРЕЗ PROXIMITY PROMPT ДЛЯ СУПЕР-ФАРМА С ЕЛКИ
            elseif d22 then
                Status.Text = "EVENT 22: PROXIMITY COLLECTING"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
                PulseDot.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
                local prompt = disaster:FindFirstChildOfClass("ProximityPrompt", true)
                if prompt then
                    local parentPart = prompt.Parent
                    walkDirect(parentPart.Position)
                    if (root.Position - parentPart.Position).Magnitude < prompt.MaxActivationDistance then
                        fireproximityprompt(prompt)
                    end
                end

            elseif d12 then
                Status.Text = "EVENT 12: UFO DODGING"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
                for _, obj in pairs(disaster:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Position.Y > root.Position.Y + 8 and obj.Size.X > 6 then
                        walkDirect(obj.Position - Vector3.new(0, 8, 0)) break
                    end
                end

            elseif d14_15 then
                Status.Text = "EVENT 14/15: STORM SHELTER"
                GlowLine.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
                for _, obj in pairs(disaster:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Position.Y > root.Position.Y + 8 and obj.Size.X > 6 then
                        walkDirect(obj.Position - Vector3.new(0, 8, 0)) break
                    end
                end

            elseif d19 then
                Status.Text = "EVENT 19: DODGING LASERS"
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
                local laser = disaster:FindFirstChild("Laser", true) or disaster:FindFirstChildWhichIsA("BasePart", true)
                if laser and (laser.Position - root.Position).Magnitude < 8 then hum.Jump = true end

            elseif weapon then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "HUNTING ENEMIES WITH " .. weapon.Name:upper()
                GlowLine.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
                if weapon.Parent == player.Backpack then hum:EquipTool(weapon) end
                local target = nil local dist = 1000
                for _, p in pairs(game.Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.Humanoid.Health > 0 then
                        local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                        if d < dist then dist = d target = p.Character.HumanoidRootPart end
                    end
                end
                if target then
                    if weapon.Name == "RocketLauncher" then
                        if dist > 10 then walkPath(target.Position) else hum:MoveTo(root.Position) end
                        workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, target.Position)
                    else walkDirect(target.Position) end
                    root.CFrame = CFrame.new(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
                    weapon:Activate()
                end

            elseif win then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "PATHFINDING TO WIN PART"
                GlowLine.BackgroundColor3 = Color3.fromRGB(180, 50, 255)
                walkPath(win.Position)

            elseif CLICKButton then
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "MOVING TO START BUTTON"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
                local pos = CLICKButton:IsA("BasePart") and CLICKButton.Position or CLICKButton.Parent.Position
                walkDirect(pos)
                if (root.Position - pos).Magnitude < 10 then fireclickdetector(CLICKButton:FindFirstChildOfClass("ClickDetector") or CLICKButton) end
            else
                if safePlatform then safePlatform:Destroy() safePlatform = nil end
                Status.Text = "LOCAL ROAMING (SAFE IDLE)"
                GlowLine.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
                if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then wanderTarget = getLocalWanderPos(root) end
                walkDirect(wanderTarget)
            end
        end)
    end
end)
