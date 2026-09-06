local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Grand Blue Hub",
   LoadingTitle = "Grand Blue Hub",
   LoadingSubtitle = "by abcthangxyz",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false,
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

local function getChar() return lp.Character end
local function getHRP() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end

local State = {
    targetMob = nil, targetPlayer = nil,
    farmMobsOn = false, farmPlayersOn = false,
    killAuraOn = false,
    offset = Vector3.new(0,0,0),
    instaKill = false, instaRange = 30, instaHPThresh = 50,
    flyOn = false, flySpeed = 50,
    speedhackOn = false, speedhackSpeed = 100,
    savedPos = nil, retreatHP = 30,
    alertRange = 50,
    _loops = {}, _conns = {},
}

local function addLoop(name, fn)
    if State._loops[name] then State._loops[name]:Disconnect() end
    State._loops[name] = RunService.Heartbeat:Connect(function() pcall(fn) end)
end
local function stopLoop(name)
    if State._loops[name] then State._loops[name]:Disconnect() State._loops[name] = nil end
end
local function notify(t, d)
    Rayfield:Notify({ Title=t, Content=d, Duration=3 })
end

local function getMobs()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local isPlayer = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == obj then isPlayer = true break end
                end
                if not isPlayer then
                    local exists = false
                    for _, v in ipairs(list) do if v == obj.Name then exists = true break end end
                    if not exists then table.insert(list, obj.Name) end
                end
            end
        end
    end
    return #list > 0 and list or {"None"}
end

local function getPlayerNames()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then table.insert(t, p.Name) end
    end
    return #t > 0 and t or {"None"}
end

-- ============================================================
-- FARM TAB
-- ============================================================
local FarmTab = Window:CreateTab("Farm", 4483362458)

FarmTab:CreateSection("Mobs")

FarmTab:CreateDropdown({
    Name = "Target Mob",
    Options = getMobs(),
    CurrentOption = {"None"},
    MultipleOptions = false,
    Flag = "TargetMob",
    Callback = function(v) State.targetMob = v end,
})

FarmTab:CreateButton({
    Name = "Refresh Mobs",
    Callback = function()
        notify("Grand Blue Hub", "Refresh mobs: rejoin tab.")
    end,
})

FarmTab:CreateToggle({
    Name = "Farm Mobs",
    CurrentValue = false,
    Flag = "FarmMobs",
    Callback = function(val)
        State.farmMobsOn = val
        if val then
            addLoop("farmMobs", function()
                local hrp = getHRP()
                if not hrp or not State.targetMob then return end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj.Name == State.targetMob then
                        local hum  = obj:FindFirstChildOfClass("Humanoid")
                        local root = obj:FindFirstChild("HumanoidRootPart")
                        if hum and root and hum.Health > 0 then
                            hrp.CFrame = root.CFrame * CFrame.new(
                                State.offset.X, State.offset.Y, State.offset.Z + 3
                            )
                            VirtualUser:Button1Down(Vector2.new(
                                workspace.CurrentCamera.ViewportSize.X/2,
                                workspace.CurrentCamera.ViewportSize.Y/2
                            ), workspace.CurrentCamera.CFrame)
                            task.wait(0.1)
                            VirtualUser:Button1Up(Vector2.new(
                                workspace.CurrentCamera.ViewportSize.X/2,
                                workspace.CurrentCamera.ViewportSize.Y/2
                            ), workspace.CurrentCamera.CFrame)
                            break
                        end
                    end
                end
            end)
        else stopLoop("farmMobs") end
    end,
})

FarmTab:CreateSection("Players")

FarmTab:CreateDropdown({
    Name = "Target Player",
    Options = getPlayerNames(),
    CurrentOption = {"None"},
    MultipleOptions = false,
    Flag = "TargetPlayer",
    Callback = function(v) State.targetPlayer = v end,
})

FarmTab:CreateToggle({
    Name = "Farm Players",
    CurrentValue = false,
    Flag = "FarmPlayers",
    Callback = function(val)
        State.farmPlayersOn = val
        if val then
            addLoop("farmPlayers", function()
                if not State.targetPlayer then return end
                local target = Players:FindFirstChild(State.targetPlayer)
                if not target or not target.Character then return end
                local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
                local hrp = getHRP()
                if not hrp or not targetRoot then return end
                hrp.CFrame = targetRoot.CFrame * CFrame.new(3,0,0)
                VirtualUser:Button1Down(Vector2.new(
                    workspace.CurrentCamera.ViewportSize.X/2,
                    workspace.CurrentCamera.ViewportSize.Y/2
                ), workspace.CurrentCamera.CFrame)
                task.wait(0.1)
                VirtualUser:Button1Up(Vector2.new(
                    workspace.CurrentCamera.ViewportSize.X/2,
                    workspace.CurrentCamera.ViewportSize.Y/2
                ), workspace.CurrentCamera.CFrame)
            end)
        else stopLoop("farmPlayers") end
    end,
})

FarmTab:CreateSection("Combat")

FarmTab:CreateToggle({
    Name = "Kill Aura",
    CurrentValue = false,
    Flag = "KillAura",
    Callback = function(val)
        State.killAuraOn = val
        if val then
            addLoop("killAura", function()
                local hrp = getHRP()
                if not hrp then return end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj ~= getChar() then
                        local hum  = obj:FindFirstChildOfClass("Humanoid")
                        local root = obj:FindFirstChild("HumanoidRootPart")
                        if hum and root and hum.Health > 0 then
                            local isPlayer = false
                            for _, p in ipairs(Players:GetPlayers()) do
                                if p.Character == obj then isPlayer = true break end
                            end
                            if not isPlayer then
                                local dist = (hrp.Position - root.Position).Magnitude
                                if dist <= 20 then
                                    hrp.CFrame = CFrame.lookAt(hrp.Position,
                                        Vector3.new(root.Position.X, hrp.Position.Y, root.Position.Z))
                                    VirtualUser:Button1Down(Vector2.new(
                                        workspace.CurrentCamera.ViewportSize.X/2,
                                        workspace.CurrentCamera.ViewportSize.Y/2
                                    ), workspace.CurrentCamera.CFrame)
                                    task.wait(0.05)
                                    VirtualUser:Button1Up(Vector2.new(
                                        workspace.CurrentCamera.ViewportSize.X/2,
                                        workspace.CurrentCamera.ViewportSize.Y/2
                                    ), workspace.CurrentCamera.CFrame)
                                end
                            end
                        end
                    end
                end
            end)
        else stopLoop("killAura") end
    end,
})

FarmTab:CreateToggle({
    Name = "Anti Ragdoll",
    CurrentValue = false,
    Flag = "AntiRagdoll",
    Callback = function(val)
        if val then
            addLoop("antiRagdoll", function()
                local char = getChar()
                if not char then return end
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                        v.Enabled = false
                    end
                end
            end)
        else stopLoop("antiRagdoll") end
    end,
})

FarmTab:CreateSlider({ Name="X Offset", Range={-20,20}, Increment=1, CurrentValue=0, Flag="XOff", Callback=function(v) State.offset = Vector3.new(v, State.offset.Y, State.offset.Z) end })
FarmTab:CreateSlider({ Name="Y Offset", Range={-20,20}, Increment=1, CurrentValue=0, Flag="YOff", Callback=function(v) State.offset = Vector3.new(State.offset.X, v, State.offset.Z) end })
FarmTab:CreateSlider({ Name="Z Offset", Range={-20,20}, Increment=1, CurrentValue=0, Flag="ZOff", Callback=function(v) State.offset = Vector3.new(State.offset.X, State.offset.Y, v) end })

FarmTab:CreateSection("Insta Kill")

FarmTab:CreateToggle({
    Name = "Insta Kill",
    CurrentValue = false,
    Flag = "InstaKill",
    Callback = function(val)
        State.instaKill = val
        if val then
            addLoop("instaKill", function()
                local hrp = getHRP()
                if not hrp then return end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj ~= getChar() then
                        local hum  = obj:FindFirstChildOfClass("Humanoid")
                        local root = obj:FindFirstChild("HumanoidRootPart")
                        if hum and root and hum.Health > 0 then
                            local isPlayer = false
                            for _, p in ipairs(Players:GetPlayers()) do
                                if p.Character == obj then isPlayer = true break end
                            end
                            if not isPlayer then
                                local dist = (hrp.Position - root.Position).Magnitude
                                if dist <= State.instaRange and
                                   hum.Health <= hum.MaxHealth * State.instaHPThresh/100 then
                                    hum.Health = 0
                                end
                            end
                        end
                    end
                end
            end)
        else stopLoop("instaKill") end
    end,
})

FarmTab:CreateSlider({ Name="HP Threshold (%)", Range={1,100}, Increment=1, CurrentValue=50, Flag="InstaHP", Callback=function(v) State.instaHPThresh = v end })
FarmTab:CreateSlider({ Name="Range", Range={5,200}, Increment=1, CurrentValue=30, Flag="InstaRange", Callback=function(v) State.instaRange = v end })

FarmTab:CreateSection("Network")

FarmTab:CreateToggle({
    Name = "TP NPCs To You",
    CurrentValue = false,
    Flag = "TPNPCs",
    Callback = function(val)
        if val then
            addLoop("tpNPCs", function()
                local hrp = getHRP()
                if not hrp then return end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") then
                        local hum  = obj:FindFirstChildOfClass("Humanoid")
                        local root = obj:FindFirstChild("HumanoidRootPart")
                        if hum and root and hum.Health > 0 then
                            local isPlayer = false
                            for _, p in ipairs(Players:GetPlayers()) do
                                if p.Character == obj then isPlayer = true break end
                            end
                            if not isPlayer then
                                root.CFrame = hrp.CFrame * CFrame.new(3,0,0)
                            end
                        end
                    end
                end
            end)
        else stopLoop("tpNPCs") end
    end,
})

FarmTab:CreateToggle({
    Name = "Freeze NPCs",
    CurrentValue = false,
    Flag = "FreezeNPCs",
    Callback = function(val)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum then
                    local isPlayer = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character == obj then isPlayer = true break end
                    end
                    if not isPlayer then
                        hum.WalkSpeed = val and 0 or 16
                        hum.JumpPower = val and 0 or 50
                    end
                end
            end
        end
    end,
})

-- ============================================================
-- PLAYER TAB
-- ============================================================
local PlayerTab = Window:CreateTab("Player", 4483362458)

PlayerTab:CreateSection("Movement")

local flyConn
PlayerTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "Fly",
    Callback = function(val)
        State.flyOn = val
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then return end
        if val then
            hum.PlatformStand = true
            local bp = Instance.new("BodyVelocity")
            bp.Name = "_FlyBV" bp.MaxForce = Vector3.new(1e5,1e5,1e5)
            bp.Velocity = Vector3.zero bp.Parent = hrp
            local bg = Instance.new("BodyGyro")
            bg.Name = "_FlyBG" bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
            bg.P = 1e4 bg.Parent = hrp
            flyConn = RunService.Heartbeat:Connect(function()
                if not State.flyOn then return end
                local cam = workspace.CurrentCamera
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0,1,0) end
                bp.Velocity = dir.Magnitude > 0 and dir.Unit * State.flySpeed or Vector3.zero
                bg.CFrame = cam.CFrame
            end)
        else
            hum.PlatformStand = false
            if flyConn then flyConn:Disconnect() flyConn = nil end
            local bp = hrp:FindFirstChild("_FlyBV")
            local bg = hrp:FindFirstChild("_FlyBG")
            if bp then bp:Destroy() end
            if bg then bg:Destroy() end
        end
    end,
})

PlayerTab:CreateSlider({ Name="Fly Speed", Range={10,500}, Increment=10, CurrentValue=50, Flag="FlySpeed", Callback=function(v) State.flySpeed = v end })

PlayerTab:CreateToggle({
    Name = "Speedhack",
    CurrentValue = false,
    Flag = "Speedhack",
    Callback = function(val)
        State.speedhackOn = val
        local hum = getHum()
        if hum then hum.WalkSpeed = val and State.speedhackSpeed or 16 end
    end,
})

PlayerTab:CreateSlider({ Name="Speed", Range={16,1000}, Increment=10, CurrentValue=100, Flag="SpeedVal", Callback=function(v)
    State.speedhackSpeed = v
    if State.speedhackOn then local hum = getHum() if hum then hum.WalkSpeed = v end end
end })

PlayerTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(val)
        if val then
            State._conns["ij"] = UserInputService.JumpRequest:Connect(function()
                local hum = getHum()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        else
            if State._conns["ij"] then State._conns["ij"]:Disconnect() State._conns["ij"] = nil end
        end
    end,
})

PlayerTab:CreateSlider({ Name="Jump Height", Range={50,1000}, Increment=10, CurrentValue=50, Flag="JumpH", Callback=function(v)
    local hum = getHum() if hum then hum.JumpPower = v end
end })

PlayerTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(val)
        State.noclipOn = val
        if val then
            addLoop("noclip", function()
                local char = getChar()
                if not char then return end
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end)
        else
            stopLoop("noclip")
            local char = getChar()
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end
    end,
})

PlayerTab:CreateSection("Utility")

PlayerTab:CreateButton({ Name="Save Position", Callback=function()
    local hrp = getHRP()
    if hrp then State.savedPos = hrp.CFrame notify("Grand Blue Hub", "Position saved.") end
end })

PlayerTab:CreateButton({ Name="TP to Saved", Callback=function()
    local hrp = getHRP()
    if hrp and State.savedPos then hrp.CFrame = State.savedPos
    else notify("Grand Blue Hub", "No saved position.") end
end })

PlayerTab:CreateToggle({ Name="Auto Retreat", CurrentValue=false, Flag="AutoRetreat", Callback=function(val)
    if val then
        addLoop("autoRetreat", function()
            local hum = getHum() local hrp = getHRP()
            if not hum or not hrp then return end
            if hum.Health/hum.MaxHealth*100 <= State.retreatHP and State.savedPos then
                hrp.CFrame = State.savedPos
            end
        end)
    else stopLoop("autoRetreat") end
end })

PlayerTab:CreateSlider({ Name="Retreat HP %", Range={1,99}, Increment=1, CurrentValue=30, Flag="RetreatHP", Callback=function(v) State.retreatHP = v end })

PlayerTab:CreateToggle({ Name="Anti AFK", CurrentValue=false, Flag="AntiAFK", Callback=function(val)
    if val then
        State._conns["afk"] = lp.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
        end)
    else
        if State._conns["afk"] then State._conns["afk"]:Disconnect() State._conns["afk"] = nil end
    end
end })

PlayerTab:CreateButton({ Name="Kill Self", Callback=function()
    local hum = getHum() if hum then hum.Health = 0 end
end })

PlayerTab:CreateSection("Misc")

PlayerTab:CreateToggle({ Name="No Slow", CurrentValue=false, Flag="NoSlow", Callback=function(val)
    if val then addLoop("noSlow", function()
        local hum = getHum()
        if hum and hum.WalkSpeed < 16 and not State.speedhackOn then hum.WalkSpeed = 16 end
    end) else stopLoop("noSlow") end
end })

PlayerTab:CreateToggle({ Name="Infinite Oxygen", CurrentValue=false, Flag="InfOxy", Callback=function(val)
    if val then addLoop("oxygen", function()
        local char = getChar()
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v.Name:lower():find("oxygen") then pcall(function() v.Value = 100 end) end
            end
        end
    end) else stopLoop("oxygen") end
end })

PlayerTab:CreateToggle({ Name="Water Walk", CurrentValue=false, Flag="WaterWalk", Callback=function(val)
    if val then addLoop("waterWalk", function()
        local hrp = getHRP()
        if hrp and hrp.Position.Y < 1 then
            hrp.CFrame = CFrame.new(hrp.Position.X, 0.5, hrp.Position.Z)
        end
    end) else stopLoop("waterWalk") end
end })

PlayerTab:CreateToggle({ Name="No Dash Cooldown", CurrentValue=false, Flag="NoDashCD", Callback=function(val)
    if val then addLoop("noDashCD", function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("NumberValue") and v.Name:lower():find("dash") then v.Value = 0 end
        end
    end) else stopLoop("noDashCD") end
end })

PlayerTab:CreateToggle({ Name="TP Back on Death", CurrentValue=false, Flag="TPDeath", Callback=function(val)
    if val then
        local hrp = getHRP() if hrp then State.savedPos = hrp.CFrame end
        State._conns["tpDeath"] = lp.CharacterAdded:Connect(function(char)
            task.wait(1)
            local root = char:WaitForChild("HumanoidRootPart", 5)
            if root and State.savedPos then root.CFrame = State.savedPos end
        end)
    else
        if State._conns["tpDeath"] then State._conns["tpDeath"]:Disconnect() State._conns["tpDeath"] = nil end
    end
end })

-- ============================================================
-- SHOP TAB
-- ============================================================
local ShopTab = Window:CreateTab("Shop", 4483362458)

ShopTab:CreateSection("Auto")

ShopTab:CreateToggle({ Name="Auto Quests", CurrentValue=false, Flag="AutoQuests", Callback=function(val)
    if val then addLoop("autoQuests", function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and (v.Name:lower():find("quest") or v.Name:lower():find("accept")) then
                pcall(function() v:FireServer() end)
            end
        end
        task.wait(2)
    end) else stopLoop("autoQuests") end
end })

ShopTab:CreateToggle({ Name="Auto Sell", CurrentValue=false, Flag="AutoSell", Callback=function(val)
    if val then addLoop("autoSell", function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find("sell") then
                pcall(function() v:FireServer() end)
            end
        end
        task.wait(2)
    end) else stopLoop("autoSell") end
end })

ShopTab:CreateToggle({ Name="Auto Fishing", CurrentValue=false, Flag="AutoFish", Callback=function(val)
    if val then addLoop("autoFish", function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find("fish") then
                pcall(function() v:FireServer() end)
            end
        end
        task.wait(1)
    end) else stopLoop("autoFish") end
end })

ShopTab:CreateToggle({ Name="Auto Mine", CurrentValue=false, Flag="AutoMine", Callback=function(val)
    if val then addLoop("autoMine", function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find("mine") then
                pcall(function() v:FireServer() end)
            end
        end
        task.wait(0.5)
    end) else stopLoop("autoMine") end
end })

ShopTab:CreateToggle({ Name="Auto Training Dummy", CurrentValue=false, Flag="AutoDummy", Callback=function(val)
    if val then addLoop("autoDummy", function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find("train") then
                pcall(function() v:FireServer() end)
            end
        end
        task.wait(0.5)
    end) else stopLoop("autoDummy") end
end })

ShopTab:CreateSection("Achievements")

ShopTab:CreateButton({ Name="Claim All Now", Callback=function()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("achiev") or v.Name:lower():find("claim")) then
            pcall(function() v:FireServer() end)
        end
    end
    notify("Grand Blue Hub", "Claimed all achievements.")
end })

-- ============================================================
-- WORLD TAB
-- ============================================================
local WorldTab = Window:CreateTab("World", 4483362458)

WorldTab:CreateSection("Visual")

WorldTab:CreateToggle({ Name="No Fog", CurrentValue=false, Flag="NoFog", Callback=function(val)
    local l = game:GetService("Lighting")
    l.FogEnd = val and 1e6 or 100000
    l.FogStart = val and 1e6 or 0
end })

WorldTab:CreateToggle({ Name="Full Bright", CurrentValue=false, Flag="FullBright", Callback=function(val)
    local l = game:GetService("Lighting")
    l.Brightness = val and 2 or 1
    l.ClockTime  = val and 14 or 12
end })

WorldTab:CreateSlider({ Name="FOV", Range={30,120}, Increment=1, CurrentValue=70, Flag="FOV", Callback=function(v)
    workspace.CurrentCamera.FieldOfView = v
end })

WorldTab:CreateToggle({ Name="Anti Lag", CurrentValue=false, Flag="AntiLag", Callback=function(val)
    if val then addLoop("antiLag", function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
    end) else stopLoop("antiLag") end
end })

WorldTab:CreateSlider({ Name="FPS Cap", Range={15,240}, Increment=5, CurrentValue=60, Flag="FPSCap", Callback=function(v)
    if setfpscap then setfpscap(v) end
end })

WorldTab:CreateSection("Teleport")

WorldTab:CreateButton({ Name="Copy Coordinates", Callback=function()
    local hrp = getHRP()
    if hrp then
        local p = hrp.Position
        local str = string.format("%.2f, %.2f, %.2f", p.X, p.Y, p.Z)
        if setclipboard then setclipboard(str) end
        notify("Grand Blue Hub", "Coords: "..str)
    end
end })

WorldTab:CreateToggle({ Name="Nearby Player Notifier", CurrentValue=false, Flag="NearbyNotif", Callback=function(val)
    if val then addLoop("nearbyNotif", function()
        local hrp = getHRP()
        if not hrp then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist <= State.alertRange then
                        notify("Nearby!", p.Name.." — "..math.floor(dist).."m")
                    end
                end
            end
        end
        task.wait(3)
    end) else stopLoop("nearbyNotif") end
end })

WorldTab:CreateSlider({ Name="Alert Range", Range={10,500}, Increment=10, CurrentValue=50, Flag="AlertRange", Callback=function(v) State.alertRange = v end })

WorldTab:CreateToggle({ Name="Click TP", CurrentValue=false, Flag="ClickTP", Callback=function(val)
    if val then
        State._conns["clickTP"] = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local hrp = getHRP()
                if not hrp then return end
                local ray = workspace:Raycast(
                    workspace.CurrentCamera.CFrame.Position,
                    workspace.CurrentCamera.CFrame.LookVector * 500,
                    RaycastParams.new()
                )
                if ray then hrp.CFrame = CFrame.new(ray.Position + Vector3.new(0,3,0)) end
            end
        end)
    else
        if State._conns["clickTP"] then State._conns["clickTP"]:Disconnect() State._conns["clickTP"] = nil end
    end
end })
