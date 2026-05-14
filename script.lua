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

local player       = game.Players.LocalPlayer
local Pathfinding  = game:GetService("PathfindingService")
local RunService   = game:GetService("RunService")

local wanderTarget     = nil
local lastCharacter    = nil
local shieldPart       = nil   -- D4: щит над ботом
local standPart        = nil   -- D10: платформа под ботом
local d10Initialized   = false -- D10: флаг первого запуска умной логики

-- ============================================================
-- GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "PremiumSurvivorAI"
ScreenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel  = 0
Main.Size             = UDim2.new(0, 290, 0, 105)
Main.Position         = UDim2.new(0.5, -145, 0.05, 0)
Main.Active           = true
Main.Draggable        = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local GlowLine = Instance.new("Frame", Main)
GlowLine.Size            = UDim2.new(1, 0, 0, 3)
GlowLine.BorderSizePixel = 0
GlowLine.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
Instance.new("UICorner", GlowLine).CornerRadius = UDim.new(0, 3)

local InnerFrame = Instance.new("Frame", Main)
InnerFrame.Size              = UDim2.new(1, -20, 1, -25)
InnerFrame.Position          = UDim2.new(0, 10, 0, 15)
InnerFrame.BackgroundColor3  = Color3.fromRGB(22, 22, 28)
Instance.new("UICorner", InnerFrame).CornerRadius = UDim.new(0, 8)

local PulseDot = Instance.new("Frame", InnerFrame)
PulseDot.Size             = UDim2.new(0, 8, 0, 8)
PulseDot.Position         = UDim2.new(0, 12, 0.5, -4)
PulseDot.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
Instance.new("UICorner", PulseDot).CornerRadius = UDim.new(1, 0)

local Status = Instance.new("TextLabel", InnerFrame)
Status.Size               = UDim2.new(1, -40, 1, 0)
Status.Position           = UDim2.new(0, 28, 0, 0)
Status.BackgroundTransparency = 1
Status.Text               = "INITIALIZING..."
Status.TextColor3         = Color3.fromRGB(245, 245, 245)
Status.TextSize           = 12
Status.Font               = Enum.Font.GothamBold
Status.TextXAlignment     = Enum.TextXAlignment.Left
Status.TextWrapped        = true

local function setStatus(text, r, g, b)
    Status.Text = text
    local col = Color3.fromRGB(r, g, b)
    GlowLine.BackgroundColor3 = col
    PulseDot.BackgroundColor3 = col
end

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
    local rx = math.random(-14, 14)
    local rz = math.random(-14, 14)
    if math.abs(rx) < 6 then rx = rx > 0 and 7 or -7 end
    if math.abs(rz) < 6 then rz = rz > 0 and 7 or -7 end
    return root.Position + Vector3.new(rx, 0, rz)
end

-- ============================================================
-- PATHFINDING (полный маршрут, умный стак-детект)
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
        -- fallback: прямой MoveTo
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

        -- ждём прихода или детектируем застревание
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

        -- если мы уже у цели — выходим раньше
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
-- NOCLIP TP (проходит сквозь защиту к целевой позиции)
-- ============================================================
local function noclipTP(targetPos)
    local char, root, hum = getChar()
    if not char then return end

    -- отключаем коллизии
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

        -- прижимаемся к полу через рейкаст
        local ray    = Ray.new(newP + Vector3.new(0, 8, 0), Vector3.new(0, -16, 0))
        local hit, hitPos = workspace:FindPartOnRay(ray, char)
        if hit then
            newP = Vector3.new(newP.X, hitPos.Y + 3, newP.Z)
        end

        root.CFrame = CFrame.new(newP)
        task.wait(0.05)
    end

    -- восстанавливаем коллизии
    for p in pairs(saved) do
        pcall(function() p.CanCollide = true end)
    end
end

-- ============================================================
-- D4: ЩИТОВАЯ ПЛАТФОРМА (следует над ботом, отбивает камни)
-- ============================================================
local function ensureShield(root)
    if not shieldPart or not shieldPart.Parent then
        shieldPart = Instance.new("Part", workspace)
        shieldPart.Name         = "_BotShield"
        shieldPart.Size         = Vector3.new(10, 1, 10)
        shieldPart.Anchored     = true
        shieldPart.CanCollide   = true
        shieldPart.Material     = Enum.Material.SmoothPlastic
        shieldPart.Transparency = 0.4
        shieldPart.Color        = Color3.fromRGB(0, 200, 255)
        shieldPart.CastShadow   = false
        Instance.new("UICorner") -- просто маркер

        -- делаем щит не убивающим игрока (он сверху)
        local weld = Instance.new("BodyPosition", shieldPart) -- для красоты не используем, просто Anchored
    end
    -- позиционируем над головой
    shieldPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 7, 0))
end

local function destroyShield()
    if shieldPart and shieldPart.Parent then shieldPart:Destroy() end
    shieldPart = nil
end

-- ============================================================
-- D10: УМНЫЕ ПАДАЮЩИЕ ПЛАТФОРМЫ
-- Бот отслеживает платформу под ногами по Transparency
-- и заранее переходит на соседнюю безопасную
-- ============================================================
local d10SafeParts = {}    -- список живых платформ
local d10StandingOn = nil  -- на какой стоим сейчас

local function refreshD10Parts(disaster)
    d10SafeParts = {}
    if not disaster then return end
    local d10 = disaster:FindFirstChild("Disaster10")
    if not d10 then return end
    for _, p in ipairs(d10:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide and p.Transparency < 0.5 then
            table.insert(d10SafeParts, p)
        end
    end
end

local function getBestD10Platform(root, disaster)
    refreshD10Parts(disaster)
    local best, bestDist = nil, math.huge
    for _, p in ipairs(d10SafeParts) do
        if p and p.Parent and p.CanCollide and p.Transparency < 0.3 then
            local d = (root.Position - p.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = p
            end
        end
    end
    return best
end

local function getCurrentPlatformUnder(root, disaster)
    -- рейкастим вниз
    local ray = Ray.new(root.Position, Vector3.new(0, -6, 0))
    local hit = workspace:FindPartOnRay(ray, player.Character)
    return hit
end

-- ============================================================
-- D6: RUSH К SAFEZONE
-- ============================================================
local function rushToSafeZone(root, disaster)
    local d6 = disaster and disaster:FindFirstChild("Disaster6")
    if not d6 then return false end

    -- собираем все safeZone парты
    local zones = {}
    for _, p in ipairs(d6:GetDescendants()) do
        if p:IsA("BasePart") and string.lower(p.Name) == "safezone" then
            table.insert(zones, p)
        end
    end
    if #zones == 0 then return false end

    -- ближайшая safeZone
    local closest, closestDist = nil, math.huge
    for _, z in ipairs(zones) do
        local d = (root.Position - z.Position).Magnitude
        if d < closestDist then closestDist = d closest = z end
    end
    if not closest then return false end

    -- пробуем pathfinding с таймаутом 8 сек (путь сложный)
    local arrived = false
    local thread  = task.spawn(function()
        arrived = walkPath(closest.Position + Vector3.new(0, 3, 0))
    end)

    -- если за 8 сек не дошли — noclip
    task.delay(8, function()
        if not arrived then
            task.cancel(thread)
            noclipTP(closest.Position + Vector3.new(0, 3, 0))
        end
    end)

    return true
end

-- ============================================================
-- ПОБЕГ ОТ МОНСТРОВ (8 направлений)
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
-- MONSTER / LASER DETECTION
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
            if (root.Position - obj.Position).Magnitude < 16 then return obj end
        end
    end
    return nil
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
    -- Disaster1 / Disaster17
    if disaster:FindFirstChild("Disaster1") or disaster:FindFirstChild("Disaster17") then return true end
    return false
end

local function floodEscape(root)
    local best, maxY = root.Position, -math.huge
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide and p.Transparency < 0.85 and not p:IsDescendantOf(player.Character) then
            local n = string.lower(p:GetFullName())
            if not string.find(n,"water") and not string.find(n,"flood")
               and not string.find(n,"liquid") and not string.find(n,"diedplace")
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
local function getCheapestTycoonButton(disaster)
    local cheapestBtn, lowestPrice = nil, math.huge
    if not disaster then return nil, math.huge end
    for _, obj in ipairs(disaster:GetDescendants()) do
        if obj.Name == "IButton" and obj:FindFirstChild("Detect") then
            pcall(function()
                local gui    = obj:FindFirstChildWhichIsA("SurfaceGui", true) or obj:FindFirstChild("Gui")
                local info   = gui and gui:FindFirstChild("Info")
                local pLabel = info and info:FindFirstChild("Price")
                if pLabel then
                    local num = tonumber(pLabel.Text:gsub("%D",""))
                    if num and num < lowestPrice then
                        lowestPrice   = num
                        cheapestBtn   = obj:FindFirstChild("Detect")
                    end
                end
            end)
        end
    end
    return cheapestBtn, lowestPrice
end

-- ============================================================
-- VIRTUAL MOUSE (для RocketLauncher)
-- ============================================================
local mouse          = player:GetMouse()
local targetOverride = nil
local isHoldingRocket = false

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
-- CLEANUP HELPERS
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
                cleanupExtras()
            end

            local disaster = workspace:FindFirstChild("Disaster")

            -- Детектируем конкретные катастрофы
            local d3  = disaster and disaster:FindFirstChild("Disaster3")
            local d4  = disaster and disaster:FindFirstChild("Disaster4")
            local d6  = disaster and disaster:FindFirstChild("Disaster6")
            local d7  = disaster and disaster:FindFirstChild("Disaster7")
            local d9  = disaster and disaster:FindFirstChild("Disaster9")
            local d10 = disaster and disaster:FindFirstChild("Disaster10")
            local d11 = disaster and disaster:FindFirstChild("Disaster11")
            local d2  = disaster and (disaster:FindFirstChild("Disaster2") or disaster:FindFirstChild("Hamster", true))
            local d12 = disaster and disaster:FindFirstChild("Disaster12")
            local d15 = disaster and disaster:FindFirstChild("Disaster15")
            local d18 = disaster and disaster:FindFirstChild("Disaster18")
            local d19 = disaster and disaster:FindFirstChild("Disaster19")
            local d22 = disaster and disaster:FindFirstChild("Disaster22")
            local d24 = disaster and disaster:FindFirstChild("Disaster24")

            local activeMonster   = getClosestMonster(root, disaster)
            local dangerousKill   = getClosestKillPart(root, disaster)
            local floodActive     = isFloodActive(disaster)

            local winPart    = disaster and disaster:FindFirstChild("Win", true)
            local CLICKButton= workspace:FindFirstChild("CLICKButton", true)
            local weapon     = char:FindFirstChild("ClassicSword") or player.Backpack:FindFirstChild("ClassicSword")
                            or char:FindFirstChild("RocketLauncher") or player.Backpack:FindFirstChild("RocketLauncher")
            local tycoonBtn, tycoonPrice = getCheapestTycoonButton(disaster)
            local winButton  = disaster and disaster:FindFirstChild("WinBUTTON", true)

            -- ====================================================
            -- ИЕРАРХИЯ ПРИОРИТЕТОВ
            -- ====================================================

            -- ── DISASTER 3: OBBY ─ noclip TP к Win ──────────────
            if d3 then
                cleanupExtras()
                setStatus("D3 OBBY: NOCLIP → WIN", 255, 80, 0)
                if winPart then
                    noclipTP(winPart.Position + Vector3.new(0, 2, 0))
                else
                    hum:MoveTo(root.Position) -- стоим
                end

            -- ── DISASTER 4: ПАДАЮЩИЕ ШАРЫ ─ щит + ходьба ────────
            elseif d4 then
                if standPart and standPart.Parent then standPart:Destroy() standPart = nil end
                d10Initialized = false
                setStatus("D4 BALLS: SHIELD ACTIVE + ROAMING", 255, 140, 0)
                ensureShield(root)
                -- бот продолжает бродить как обычно
                if not wanderTarget or (root.Position - wanderTarget).Magnitude < 4 then
                    wanderTarget = getLocalWanderPos(root)
                end
                walkDirect(wanderTarget)

            -- ── DISASTER 6: NUKE ─ rush к safeZone ──────────────
            elseif d6 then
                cleanupExtras()
                setStatus("D6 NUKE: RUSHING SAFEZONE!", 220, 30, 30)
                -- Ищем safeZone каждый тик пока не дошли
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
                        if closestDist > 3 then
                            local reached = walkPath(closest.Position + Vector3.new(0, 3, 0), 30)
                            if not reached and closestDist > 8 then
                                -- fallback noclip если pathfinding не справился
                                noclipTP(closest.Position + Vector3.new(0, 3, 0))
                            end
                        else
                            hum:MoveTo(root.Position) -- стоим внутри
                        end
                    end
                end

            -- ── DISASTER 9: MAZE ─ pathfind + noclip fallback ───
            elseif d9 then
                cleanupExtras()
                setStatus("D9 MAZE: PATHFINDING TO WIN", 80, 0, 200)
                if winPart then
                    local dist = (root.Position - winPart.Position).Magnitude
                    if dist > 4 then
                        -- Пробуем pathfinding с умным стак-детектом
                        local pfResult = walkPath(winPart.Position + Vector3.new(0, 2, 0), 20)
                        -- Если после попытки всё ещё далеко — noclip
                        task.wait(0.5)
                        local _, root2 = getChar()
                        if root2 and (root2.Position - winPart.Position).Magnitude > 8 then
                            setStatus("D9 MAZE: NOCLIP FALLBACK!", 160, 0, 255)
                            noclipTP(winPart.Position + Vector3.new(0, 2, 0))
                        end
                    else
                        hum:MoveTo(root.Position) -- на месте победы
                    end
                end

            -- ── DISASTER 10: FALLING PLATFORMS ─ умная логика ───
            elseif d10 then
                if shieldPart and shieldPart.Parent then destroyShield() end
                setStatus("D10 PLATFORMS: SMART SURVIVAL", 255, 200, 0)

                -- Находим платформу под нами
                local underPart = getCurrentPlatformUnder(root, disaster)
                local needMove   = false

                if underPart then
                    -- Если платформа начала исчезать (Transparency > 0.05) — уходим
                    if underPart.Transparency > 0.05 or not underPart.CanCollide then
                        needMove = true
                    end
                else
                    needMove = true -- мы в воздухе — ищем платформу
                end

                if needMove then
                    local bestPart = getBestD10Platform(root, disaster)
                    if bestPart then
                        -- Прыгаем на ближайшую живую платформу
                        hum.Jump = true
                        walkDirect(bestPart.Position + Vector3.new(0, 4, 0))
                    else
                        -- Все платформы пропали — создаём спасательную под ногами
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
                    end
                else
                    -- Стоим безопасно — небольшое перемещение чтобы выглядеть как игрок
                    if not wanderTarget or (root.Position - wanderTarget).Magnitude < 2 then
                        -- блуждаем только в радиусе текущей платформы
                        if underPart then
                            local s  = underPart.Size
                            local rX = math.random(-math.floor(s.X/2)+1, math.floor(s.X/2)-1)
                            local rZ = math.random(-math.floor(s.Z/2)+1, math.floor(s.Z/2)-1)
                            wanderTarget = underPart.Position + Vector3.new(rX, 3, rZ)
                        end
                    end
                    if wanderTarget then walkDirect(wanderTarget) end
                    -- Удаляем аварийную платформу если больше не нужна
                    if standPart and standPart.Parent then standPart:Destroy() standPart = nil end
                end

            -- ── DISASTER 11: BUTTON CLICKER ──────────────────────
            elseif d11 then
                cleanupExtras()
                setStatus("D11 BUTTON: SPAM CLICKING!", 255, 255, 0)
                local btn = d11:FindFirstChildOfClass("ClickDetector", true)
                if btn then
                    local btnPart = btn.Parent
                    if (root.Position - btnPart.Position).Magnitude > 8 then
                        walkPath(btnPart.Position)
                    else
                        fireclickdetector(btn)
                    end
                end

            -- ── FLOOD / TSUNAMI ───────────────────────────────────
            elseif floodActive then
                cleanupExtras()
                setStatus("FLOOD: TP TO HIGH GROUND!", 255, 50, 50)
                floodEscape(root)

            -- ── MONSTER ESCAPE ────────────────────────────────────
            elseif activeMonster then
                cleanupExtras()
                setStatus("MONSTER: SMART ESCAPE!", 255, 0, 50)
                escapeMonster(root, activeMonster.Position)

            -- ── KILL PART DODGE ───────────────────────────────────
            elseif dangerousKill then
                cleanupExtras()
                setStatus("KILL LASER: DODGE!", 255, 0, 255)
                hum.Jump = true
                local dodge = Vector3.new(dangerousKill.CFrame.LookVector.Z, 0, -dangerousKill.CFrame.LookVector.X) * 14
                walkDirect(root.Position + dodge)

            -- ── DISASTER 2: HAMSTER ───────────────────────────────
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

            -- ── DISASTER 7: MURDER ───────────────────────────────
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

            -- ── DISASTER 19: LASER ROOM ───────────────────────────
            elseif d19 then
                cleanupExtras()
                setStatus("D19 LASER: PATHFIND TO END", 255, 0, 180)
                local endPart = d19:FindFirstChild("End")
                if endPart then
                    if (root.Position - endPart.Position).Magnitude > 4 then
                        local ok2 = walkPath(endPart.Position + Vector3.new(0, 3, 0))
                        if not ok2 then noclipTP(endPart.Position + Vector3.new(0, 3, 0)) end
                    end
                end

            -- ── DISASTER 22: CHRISTMAS PROMPTS ────────────────────
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

            -- ── DISASTER 24: COLOR BLOCK ──────────────────────────
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

            -- ── DISASTER 18: TYCOON ───────────────────────────────
            elseif d18 then
                cleanupExtras()
                if tycoonBtn then
                    setStatus("D18 TYCOON: BUYING ($" .. tycoonPrice .. ")", 0, 220, 255)
                    if (root.Position - tycoonBtn.Position).Magnitude <= 4 then
                        hum.Jump = true
                        walkDirect(tycoonBtn.Position + Vector3.new(math.random(-1,1), 0, 0))
                    else
                        walkPath(tycoonBtn.Position)
                    end
                elseif winButton then
                    setStatus("D18 TYCOON: WIN BUTTON!", 255, 0, 180)
                    local wbTarget = winButton:FindFirstChild("Detect") or winButton:FindFirstChildWhichIsA("BasePart", true) or winButton
                    if (root.Position - wbTarget.Position).Magnitude <= 4 then
                        hum.Jump = true
                    else
                        walkPath(wbTarget.Position)
                    end
                end

            -- ── ОРУЖИЕ ────────────────────────────────────────────
            elseif weapon then
                cleanupExtras()
                setStatus("HUNTING: " .. weapon.Name:upper(), 255, 120, 0)
                if weapon.Parent == player.Backpack then hum:EquipTool(weapon) end
                isHoldingRocket = (weapon.Name == "RocketLauncher")

                local target, dist = nil, 1000
                for _, p in ipairs(game.Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    and p.Character.Humanoid.Health > 0 then
                        local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                        if d < dist then dist = d target = p.Character.HumanoidRootPart end
                    end
                end
                if target then
                    targetOverride = target
                    root.CFrame = CFrame.new(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
                    if isHoldingRocket then
                        if dist > 12 then walkPath(target.Position)
                        else hum:MoveTo(root.Position) end
                        workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, target.Position)
                    else
                        walkDirect(target.Position)
                    end
                    weapon:Activate()
                else
                    targetOverride = nil; isHoldingRocket = false
                end

            -- ── WIN PART ──────────────────────────────────────────
            elseif winPart then
                cleanupExtras()
                setStatus("PATHFINDING TO WIN PART!", 180, 50, 255)
                walkPath(winPart.Position)

            -- ── CLICK BUTTON (старт раунда) ───────────────────────
            elseif CLICKButton then
                cleanupExtras()
                setStatus("MOVING TO START BUTTON", 0, 150, 255)
                local pos = CLICKButton:IsA("BasePart") and CLICKButton.Position or CLICKButton.Parent.Position
                walkDirect(pos)
                if (root.Position - pos).Magnitude < 12 then
                    local cd = CLICKButton:FindFirstChildOfClass("ClickDetector") or CLICKButton
                    fireclickdetector(cd)
                end

            -- ── IDLE ROAMING ──────────────────────────────────────
            else
                -- D4 щит не нужен в idle
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
