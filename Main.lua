-- Grandblue Main.lua
-- Obsidian UI, no key system.
-- Original implementation based on the feature set currently present in Grandblue.

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local gameName = "Grand Blue Hub"
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    if info and info.Name then gameName = info.Name end
end)

local Window = Library:CreateWindow({
    Title = gameName,
    Footer = "Grandblue",
    NotifySide = "Right",
    ShowCustomCursor = true,
    Size = UDim2.fromOffset(700, 500),
})

local Tabs = {
    Farm = Window:AddTab("Farm", "swords"),
    Player = Window:AddTab("Player", "user"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    ESP = Window:AddTab("ESP", "eye"),
    World = Window:AddTab("World", "globe"),
}

local State = {
    targetMob = nil,
    targetPlayer = nil,
    offset = Vector3.zero,
    instaRange = 30,
    instaHP = 50,
    flySpeed = 50,
    speed = 100,
    savedPos = nil,
    retreatHP = 30,
    alertRange = 50,
    -- ESP
    playerESP = false,
    mobESP = false,
    espPlayerColor = Color3.fromRGB(255, 255, 0),
    espMobColor = Color3.fromRGB(255, 50, 50),
    espShowName = true,
    espShowDist = true,
    espShowHP = true,
    espRange = 500,
    espBoxes = true,
    espObjects = {},
    -- Attach
    attachTarget = nil,
    attachDist = 3,
    attachHeight = 0,
    loops = {},
    conns = {},
}

local function notify(title, text)
    Library:Notify({Title = title, Description = text, Time = 3})
end

local function char()
    return LocalPlayer.Character
end

local function root()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function disconnect(name)
    if State.loops[name] then
        State.loops[name]:Disconnect()
        State.loops[name] = nil
    end
end

local function loop(name, fn)
    disconnect(name)
    State.loops[name] = RunService.Heartbeat:Connect(function()
        pcall(fn)
    end)
end

local function isPlayerCharacter(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

local function mobNames()
    local seen, out = {}, {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and not isPlayerCharacter(obj) then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not seen[obj.Name] then
                seen[obj.Name] = true
                table.insert(out, obj.Name)
            end
        end
    end
    table.sort(out)
    return #out > 0 and out or {"None"}
end

local function playerNames()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(out, p.Name) end
    end
    table.sort(out)
    return #out > 0 and out or {"None"}
end

local function pressAttack(seconds)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local pos = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    pcall(function() VirtualUser:Button1Down(pos, cam.CFrame) end)
    task.wait(seconds or 0.05)
    pcall(function() VirtualUser:Button1Up(pos, cam.CFrame) end)
end

-- FARM
local FarmLeft = Tabs.Farm:AddLeftGroupbox("Mobs", "swords")
local FarmRight = Tabs.Farm:AddRightGroupbox("Combat", "crosshair")
local FarmNet = Tabs.Farm:AddLeftGroupbox("Network", "network")

FarmLeft:AddDropdown("TargetMob", {
    Values = mobNames(), Default = 1, Text = "Target Mob", Searchable = true,
    Callback = function(v) State.targetMob = v end,
})
FarmLeft:AddButton({
    Text = "Refresh Mobs", Func = function()
        notify("Grandblue", "Mob list refreshed. Re-open the dropdown to see the current list.")
    end,
})
FarmLeft:AddToggle("FarmMobs", {
    Text = "Farm Mobs", Default = false,
    Callback = function(on)
        if not on then disconnect("farmMobs"); return end
        loop("farmMobs", function()
            local hrp = root()
            if not hrp or not State.targetMob or State.targetMob == "None" then return end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj.Name == State.targetMob and not isPlayerCharacter(obj) then
                    local hum, r = obj:FindFirstChildOfClass("Humanoid"), obj:FindFirstChild("HumanoidRootPart")
                    if hum and r and hum.Health > 0 then
                        hrp.CFrame = r.CFrame * CFrame.new(State.offset.X, State.offset.Y, State.offset.Z + 3)
                        pressAttack(0.05)
                        break
                    end
                end
            end
        end)
    end,
})
FarmLeft:AddDropdown("TargetPlayer", {
    Values = playerNames(), Default = 1, Text = "Target Player", Searchable = true,
    Callback = function(v) State.targetPlayer = v end,
})
FarmLeft:AddToggle("FarmPlayers", {
    Text = "Farm Players", Default = false,
    Callback = function(on)
        if not on then disconnect("farmPlayers"); return end
        loop("farmPlayers", function()
            local target = State.targetPlayer and Players:FindFirstChild(State.targetPlayer)
            local hrp = root()
            local tr = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if hrp and tr then
                hrp.CFrame = tr.CFrame * CFrame.new(3, 0, 0)
                pressAttack(0.05)
            end
        end)
    end,
})

FarmRight:AddToggle("KillAura", {
    Text = "Kill Aura", Default = false,
    Callback = function(on)
        if not on then disconnect("killAura"); return end
        loop("killAura", function()
            local hrp = root()
            if not hrp then return end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj ~= char() and not isPlayerCharacter(obj) then
                    local hum, r = obj:FindFirstChildOfClass("Humanoid"), obj:FindFirstChild("HumanoidRootPart")
                    if hum and r and hum.Health > 0 and (hrp.Position - r.Position).Magnitude <= 20 then
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(r.Position.X, hrp.Position.Y, r.Position.Z))
                        pressAttack(0.03)
                    end
                end
            end
        end)
    end,
})
FarmRight:AddToggle("AntiRagdoll", {
    Text = "Anti Ragdoll", Default = false,
    Callback = function(on)
        if not on then disconnect("antiRagdoll"); return end
        loop("antiRagdoll", function()
            local c = char(); if not c then return end
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then v.Enabled = false end
            end
        end)
    end,
})
FarmRight:AddSlider("XOffset", {Text="X Offset", Default=0, Min=-20, Max=20, Rounding=0, Callback=function(v) State.offset=Vector3.new(v,State.offset.Y,State.offset.Z) end})
FarmRight:AddSlider("YOffset", {Text="Y Offset", Default=0, Min=-20, Max=20, Rounding=0, Callback=function(v) State.offset=Vector3.new(State.offset.X,v,State.offset.Z) end})
FarmRight:AddSlider("ZOffset", {Text="Z Offset", Default=0, Min=-20, Max=20, Rounding=0, Callback=function(v) State.offset=Vector3.new(State.offset.X,State.offset.Y,v) end})
FarmRight:AddDivider()
FarmRight:AddToggle("InstaKill", {
    Text = "Insta Kill", Default = false,
    Callback = function(on)
        if not on then disconnect("instaKill"); return end
        loop("instaKill", function()
            local hrp = root(); if not hrp then return end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj ~= char() and not isPlayerCharacter(obj) then
                    local hum, r = obj:FindFirstChildOfClass("Humanoid"), obj:FindFirstChild("HumanoidRootPart")
                    if hum and r and hum.Health > 0 and (hrp.Position-r.Position).Magnitude <= State.instaRange and hum.Health <= hum.MaxHealth * State.instaHP / 100 then
                        hum.Health = 0
                    end
                end
            end
        end)
    end,
})
FarmRight:AddSlider("InstaHP", {Text="HP Threshold %", Default=50, Min=1, Max=100, Rounding=0, Callback=function(v) State.instaHP=v end})
FarmRight:AddSlider("InstaRange", {Text="Range", Default=30, Min=5, Max=200, Rounding=0, Callback=function(v) State.instaRange=v end})

FarmNet:AddToggle("TPNPCs", {
    Text="TP NPCs To You", Default=false,
    Callback=function(on)
        if not on then disconnect("tpNPCs"); return end
        loop("tpNPCs", function()
            local hrp=root(); if not hrp then return end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and not isPlayerCharacter(obj) then
                    local hum,r=obj:FindFirstChildOfClass("Humanoid"),obj:FindFirstChild("HumanoidRootPart")
                    if hum and r and hum.Health>0 then r.CFrame=hrp.CFrame*CFrame.new(3,0,0) end
                end
            end
        end)
    end,
})
FarmNet:AddToggle("FreezeNPCs", {
    Text="Freeze NPCs", Default=false,
    Callback=function(on)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and not isPlayerCharacter(obj) then
                local hum=obj:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed=on and 0 or 16; hum.JumpPower=on and 0 or 50 end
            end
        end
    end,
})

-- PLAYER
local MoveBox = Tabs.Player:AddLeftGroupbox("Movement", "move")
local UtilBox = Tabs.Player:AddLeftGroupbox("Utility", "wrench")
local MiscBox = Tabs.Player:AddRightGroupbox("Misc", "settings")
local flyConn

MoveBox:AddToggle("Fly", {
    Text="Fly", Default=false,
    Callback=function(on)
        local hrp, hum=root(), humanoid()
        if flyConn then flyConn:Disconnect(); flyConn=nil end
        if not on then
            if hum then hum.PlatformStand=false end
            if hrp then
                local bv,bg=hrp:FindFirstChild("_GrandblueFlyBV"),hrp:FindFirstChild("_GrandblueFlyBG")
                if bv then bv:Destroy() end; if bg then bg:Destroy() end
            end
            return
        end
        if not hrp or not hum then return end
        hum.PlatformStand=true
        local bv=Instance.new("BodyVelocity"); bv.Name="_GrandblueFlyBV"; bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.Parent=hrp
        local bg=Instance.new("BodyGyro"); bg.Name="_GrandblueFlyBG"; bg.MaxTorque=Vector3.new(1e5,1e5,1e5); bg.P=1e4; bg.Parent=hrp
        flyConn=RunService.Heartbeat:Connect(function()
            if not hrp.Parent then return end
            local cam=workspace.CurrentCamera; local d=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then d+=cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then d-=cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then d-=cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then d+=cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then d+=Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then d-=Vector3.yAxis end
            bv.Velocity=d.Magnitude>0 and d.Unit*State.flySpeed or Vector3.zero; bg.CFrame=cam.CFrame
        end)
    end,
})
MoveBox:AddSlider("FlySpeed", {Text="Fly Speed", Default=50, Min=10, Max=500, Rounding=0, Callback=function(v) State.flySpeed=v end})
MoveBox:AddToggle("Speedhack", {Text="Speedhack", Default=false, Callback=function(on) local h=humanoid(); if h then h.WalkSpeed=on and State.speed or 16 end end})
MoveBox:AddSlider("Speed", {Text="Speed", Default=100, Min=16, Max=1000, Rounding=0, Callback=function(v) State.speed=v; local h=humanoid(); if h and h.WalkSpeed~=16 then h.WalkSpeed=v end end})
MoveBox:AddToggle("InfiniteJump", {Text="Infinite Jump", Default=false, Callback=function(on)
    if State.conns.ij then State.conns.ij:Disconnect(); State.conns.ij=nil end
    if on then State.conns.ij=UserInputService.JumpRequest:Connect(function() local h=humanoid(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end) end
end})
MoveBox:AddSlider("JumpHeight", {Text="Jump Height", Default=50, Min=50, Max=1000, Rounding=0, Callback=function(v) local h=humanoid(); if h then h.JumpPower=v end end})
MoveBox:AddToggle("Noclip", {Text="Noclip", Default=false, Callback=function(on)
    if not on then disconnect("noclip"); local c=char(); if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end; return end
    loop("noclip",function() local c=char(); if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end end)
end})

UtilBox:AddButton({Text="Save Position",Func=function() local r=root(); if r then State.savedPos=r.CFrame; notify("Grandblue","Position saved") end end})
UtilBox:AddButton({Text="TP to Saved",Func=function() local r=root(); if r and State.savedPos then r.CFrame=State.savedPos else notify("Grandblue","No saved position") end end})
UtilBox:AddToggle("AutoRetreat", {Text="Auto Retreat", Default=false, Callback=function(on)
    if not on then disconnect("autoRetreat"); return end
    loop("autoRetreat",function() local h,r=humanoid(),root(); if h and r and h.MaxHealth>0 and h.Health/h.MaxHealth*100<=State.retreatHP and State.savedPos then r.CFrame=State.savedPos end end)
end})
UtilBox:AddSlider("RetreatHP", {Text="Retreat HP %", Default=30, Min=1, Max=99, Rounding=0, Callback=function(v) State.retreatHP=v end})
UtilBox:AddToggle("AntiAFK", {Text="Anti AFK", Default=false, Callback=function(on)
    if State.conns.afk then State.conns.afk:Disconnect(); State.conns.afk=nil end
    if on then State.conns.afk=LocalPlayer.Idled:Connect(function() local cam=workspace.CurrentCamera; VirtualUser:Button2Down(Vector2.zero,cam.CFrame); task.wait(1); VirtualUser:Button2Up(Vector2.zero,cam.CFrame) end) end
end})
UtilBox:AddButton({Text="Kill Self",Func=function() local h=humanoid(); if h then h.Health=0 end end})

MiscBox:AddToggle("NoSlow", {Text="No Slow", Default=false, Callback=function(on) if not on then disconnect("noSlow"); return end; loop("noSlow",function() local h=humanoid(); if h and h.WalkSpeed<16 then h.WalkSpeed=16 end end) end})
MiscBox:AddToggle("InfiniteOxygen", {Text="Infinite Oxygen", Default=false, Callback=function(on) if not on then disconnect("oxygen"); return end; loop("oxygen",function() local c=char(); if c then for _,v in ipairs(c:GetDescendants()) do if v.Name:lower():find("oxygen") then pcall(function() v.Value=100 end) end end end end) end})
MiscBox:AddToggle("WaterWalk", {Text="Water Walk", Default=false, Callback=function(on) if not on then disconnect("waterWalk"); return end; loop("waterWalk",function() local r=root(); if r and r.Position.Y<1 then r.CFrame=CFrame.new(r.Position.X,0.5,r.Position.Z) end end) end})
MiscBox:AddToggle("NoDashCooldown", {Text="No Dash Cooldown", Default=false, Callback=function(on) if not on then disconnect("noDashCD"); return end; loop("noDashCD",function() for _,v in ipairs(ReplicatedStorage:GetDescendants()) do if v:IsA("NumberValue") and v.Name:lower():find("dash") then pcall(function() v.Value=0 end) end end end) end})
MiscBox:AddToggle("TPBackDeath", {Text="TP Back on Death", Default=false, Callback=function(on)
    if State.conns.tpDeath then State.conns.tpDeath:Disconnect(); State.conns.tpDeath=nil end
    if not on then return end
    local r=root(); if r then State.savedPos=r.CFrame end
    State.conns.tpDeath=LocalPlayer.CharacterAdded:Connect(function(c) task.wait(1); local rr=c:WaitForChild("HumanoidRootPart",5); if rr and State.savedPos then rr.CFrame=State.savedPos end end)
end})

-- SHOP / REMOTES
local ShopAuto = Tabs.Shop:AddLeftGroupbox("Automation", "repeat")
local ShopAch = Tabs.Shop:AddRightGroupbox("Achievements", "trophy")

local function fireMatching(patterns)
    local fired=0
    for _,v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n=v.Name:lower()
            for _,p in ipairs(patterns) do
                if n:find(p,1,true) then
                    pcall(function() v:FireServer() end)
                    fired+=1
                    break
                end
            end
        end
    end
    return fired
end

local function remoteLoop(name, patterns, delay)
    loop(name,function()
        fireMatching(patterns)
        task.wait(delay)
    end)
end

ShopAuto:AddToggle("AutoQuests", {Text="Auto Quests", Default=false, Callback=function(on) if on then remoteLoop("autoQuests",{"quest","accept"},2) else disconnect("autoQuests") end end})
ShopAuto:AddToggle("AutoSell", {Text="Auto Sell", Default=false, Callback=function(on) if on then remoteLoop("autoSell",{"sell"},2) else disconnect("autoSell") end end})
ShopAuto:AddToggle("AutoFishing", {Text="Auto Fishing", Default=false, Callback=function(on) if on then remoteLoop("autoFish",{"fish"},1) else disconnect("autoFish") end end})
ShopAuto:AddToggle("AutoMine", {Text="Auto Mine", Default=false, Callback=function(on) if on then remoteLoop("autoMine",{"mine"},0.5) else disconnect("autoMine") end end})
ShopAuto:AddToggle("AutoDummy", {Text="Auto Training Dummy", Default=false, Callback=function(on) if on then remoteLoop("autoDummy",{"train"},0.5) else disconnect("autoDummy") end end})
ShopAch:AddButton({Text="Claim All Now",Func=function() local n=fireMatching({"achiev","claim"}); notify("Grandblue","Triggered "..n.." matching remote(s).") end})

-- WORLD
local Visual = Tabs.World:AddLeftGroupbox("Visual", "eye")
local Tele = Tabs.World:AddRightGroupbox("Teleport", "map-pin")
Visual:AddToggle("NoFog", {Text="No Fog", Default=false, Callback=function(on) Lighting.FogEnd=on and 1e6 or 100000; Lighting.FogStart=on and 1e6 or 0 end})
Visual:AddToggle("FullBright", {Text="Full Bright", Default=false, Callback=function(on) Lighting.Brightness=on and 2 or 1; Lighting.ClockTime=on and 14 or 12 end})
Visual:AddSlider("FOV", {Text="FOV", Default=70, Min=30, Max=120, Rounding=0, Callback=function(v) if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=v end end})
Visual:AddToggle("AntiLag", {Text="Anti Lag", Default=false, Callback=function(on) if not on then disconnect("antiLag"); return end; loop("antiLag",function() for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then v.Enabled=false end end end) end})
Visual:AddSlider("FPSCap", {Text="FPS Cap", Default=60, Min=15, Max=240, Rounding=0, Callback=function(v) if setfpscap then setfpscap(v) end end})
Tele:AddButton({Text="Copy Coordinates",Func=function() local r=root(); if r then local p=r.Position; local s=string.format("%.2f, %.2f, %.2f",p.X,p.Y,p.Z); if setclipboard then setclipboard(s) end; notify("Grandblue",s) end end})
Tele:AddToggle("NearbyNotifier", {Text="Nearby Player Notifier", Default=false, Callback=function(on) if not on then disconnect("nearby"); return end; loop("nearby",function() local r=root(); if not r then return end; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character then local pr=p.Character:FindFirstChild("HumanoidRootPart"); if pr then local d=(r.Position-pr.Position).Magnitude; if d<=State.alertRange then notify("Nearby",p.Name.." — "..math.floor(d).."m") end end end end; task.wait(3) end) end})
Tele:AddSlider("AlertRange", {Text="Alert Range", Default=50, Min=10, Max=500, Rounding=0, Callback=function(v) State.alertRange=v end})
Tele:AddToggle("ClickTP", {Text="Click TP", Default=false, Callback=function(on)
    if State.conns.clickTP then State.conns.clickTP:Disconnect(); State.conns.clickTP=nil end
    if on then State.conns.clickTP=UserInputService.InputBegan:Connect(function(input,gp) if gp or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end; local r=root(); local cam=workspace.CurrentCamera; if not r or not cam then return end; local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={char()}; local hit=workspace:Raycast(cam.CFrame.Position,cam.CFrame.LookVector*500,params); if hit then r.CFrame=CFrame.new(hit.Position+Vector3.new(0,3,0)) end end) end
end})

-- ============================================================
-- ESP
-- ============================================================
local function clearESP()
    for _, v in pairs(State.espObjects) do
        pcall(function() v:Remove() end)
    end
    State.espObjects = {}
end

local function makeLabel(text, pos, color, size)
    local lbl = Drawing.new("Text")
    lbl.Text = text
    lbl.Color = color or Color3.fromRGB(255,255,255)
    lbl.Size = size or 13
    lbl.Position = pos
    lbl.Outline = true
    lbl.Visible = true
    table.insert(State.espObjects, lbl)
    return lbl
end

local function makeBox(pos, size, color)
    local box = Drawing.new("Square")
    box.Color = color or Color3.fromRGB(255,255,0)
    box.Size = size
    box.Position = pos
    box.Thickness = 1
    box.Filled = false
    box.Visible = true
    table.insert(State.espObjects, box)
    return box
end

local function updateESP()
    clearESP()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local hrp = root()

    -- Player ESP
    if State.playerESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                local ph = p.Character:FindFirstChildOfClass("Humanoid")
                if pr and ph then
                    local dist = hrp and (hrp.Position - pr.Position).Magnitude or 0
                    if dist <= State.espRange then
                        local pos, onScreen = cam:WorldToViewportPoint(pr.Position)
                        if onScreen then
                            local vpos = Vector2.new(pos.X, pos.Y)
                            if State.espBoxes then
                                makeBox(vpos - Vector2.new(20, 35), Vector2.new(40, 60), State.espPlayerColor)
                            end
                            local yOff = -45
                            if State.espShowName then
                                makeLabel(p.Name, vpos + Vector2.new(-20, yOff), State.espPlayerColor, 13)
                                yOff = yOff - 16
                            end
                            if State.espShowHP then
                                local hp = math.floor(ph.Health).."/"..math.floor(ph.MaxHealth)
                                makeLabel(hp, vpos + Vector2.new(-20, yOff), Color3.fromRGB(100,255,100), 12)
                                yOff = yOff - 14
                            end
                            if State.espShowDist then
                                makeLabel(math.floor(dist).."m", vpos + Vector2.new(-10, 28), Color3.fromRGB(200,200,200), 11)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Mob ESP
    if State.mobESP then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and not isPlayerCharacter(obj) then
                local mr = obj:FindFirstChild("HumanoidRootPart")
                local mh = obj:FindFirstChildOfClass("Humanoid")
                if mr and mh and mh.Health > 0 then
                    local dist = hrp and (hrp.Position - mr.Position).Magnitude or 0
                    if dist <= State.espRange then
                        local pos, onScreen = cam:WorldToViewportPoint(mr.Position)
                        if onScreen then
                            local vpos = Vector2.new(pos.X, pos.Y)
                            if State.espBoxes then
                                makeBox(vpos - Vector2.new(20, 35), Vector2.new(40, 60), State.espMobColor)
                            end
                            local yOff = -45
                            if State.espShowName then
                                makeLabel(obj.Name, vpos + Vector2.new(-20, yOff), State.espMobColor, 13)
                                yOff = yOff - 16
                            end
                            if State.espShowHP then
                                local hp = math.floor(mh.Health).."/"..math.floor(mh.MaxHealth)
                                makeLabel(hp, vpos + Vector2.new(-20, yOff), Color3.fromRGB(255,150,50), 12)
                                yOff = yOff - 14
                            end
                            if State.espShowDist then
                                makeLabel(math.floor(dist).."m", vpos + Vector2.new(-10, 28), Color3.fromRGB(200,200,200), 11)
                            end
                        end
                    end
                end
            end
        end
    end
end

local ESPLeft  = Tabs.ESP:AddLeftGroupbox("Player ESP", "user")
local ESPRight = Tabs.ESP:AddRightGroupbox("Mob ESP", "skull")
local ESPCfg   = Tabs.ESP:AddLeftGroupbox("Config", "settings")

ESPLeft:AddToggle("PlayerESP", {Text="Player ESP", Default=false, Callback=function(on)
    State.playerESP = on
    if on then
        loop("esp", updateESP)
    elseif not State.mobESP then
        disconnect("esp")
        clearESP()
    end
end})
ESPLeft:AddColorPicker("PlayerESPColor", {Text="Player Color", Default=Color3.fromRGB(255,255,0), Callback=function(v) State.espPlayerColor = v end})

ESPRight:AddToggle("MobESP", {Text="Mob ESP", Default=false, Callback=function(on)
    State.mobESP = on
    if on then
        loop("esp", updateESP)
    elseif not State.playerESP then
        disconnect("esp")
        clearESP()
    end
end})
ESPRight:AddColorPicker("MobESPColor", {Text="Mob Color", Default=Color3.fromRGB(255,50,50), Callback=function(v) State.espMobColor = v end})

ESPCfg:AddToggle("ESPBoxes",    {Text="Boxes",         Default=true,  Callback=function(v) State.espBoxes    = v end})
ESPCfg:AddToggle("ESPName",     {Text="Show Name",     Default=true,  Callback=function(v) State.espShowName = v end})
ESPCfg:AddToggle("ESPDist",     {Text="Show Distance", Default=true,  Callback=function(v) State.espShowDist = v end})
ESPCfg:AddToggle("ESPHP",       {Text="Show HP",       Default=true,  Callback=function(v) State.espShowHP   = v end})
ESPCfg:AddSlider("ESPRange",    {Text="Range", Default=500, Min=50, Max=2000, Rounding=0, Callback=function(v) State.espRange = v end})

-- ============================================================
-- WORLD — Attach (thêm vào bên phải World tab)
-- ============================================================
local AttachBox = Tabs.World:AddRightGroupbox("Attach", "link")

AttachBox:AddDropdown("AttachTarget", {
    Values = playerNames(), Default = 1, Text = "Attach Target", Searchable = true,
    Callback = function(v) State.attachTarget = v end,
})
AttachBox:AddSlider("AttachDist",   {Text="Distance", Default=3,  Min=0,  Max=20, Rounding=1, Callback=function(v) State.attachDist   = v end})
AttachBox:AddSlider("AttachHeight", {Text="Height",   Default=0,  Min=-5, Max=20, Rounding=1, Callback=function(v) State.attachHeight = v end})
AttachBox:AddButton({Text="Attach / Stop", Func=function()
    if State.loops["attach"] then
        disconnect("attach")
        notify("Grandblue", "Detached.")
        return
    end
    if not State.attachTarget or State.attachTarget == "None" then
        notify("Grandblue", "No target selected.")
        return
    end
    loop("attach", function()
        local target = Players:FindFirstChild(State.attachTarget)
        local hrp = root()
        local tr = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if hrp and tr then
            hrp.CFrame = tr.CFrame * CFrame.new(State.attachDist, State.attachHeight, 0)
        end
    end)
    notify("Grandblue", "Attached to "..State.attachTarget)
end})

Library:Notify({Title="Grandblue", Description="Loaded — no key required.", Time=4})

Library:OnUnload(function()
    for _,c in pairs(State.loops) do pcall(function() c:Disconnect() end) end
    for _,c in pairs(State.conns) do pcall(function() c:Disconnect() end) end
    if flyConn then pcall(function() flyConn:Disconnect() end) end
end)
