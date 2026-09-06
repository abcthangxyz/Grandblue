-- ========================================
--  GRAND BLUE HUB — FULL EDITION
--  Stack: Obsidian Library (deividcomsono)
-- ========================================

local CONFIG = {
    HUB_TITLE   = "Grand Blue Hub",
    FOOTER_TEXT = "Grand Blue",
    NOTIF_SIDE  = "Right",
    WINDOW_W    = 700,
    WINDOW_H    = 500,
}

local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local function safeLoad(url)
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if not ok then warn("[HUB] " .. url .. "\n" .. tostring(r)) return nil end
    return r
end

local Library      = safeLoad(REPO .. "Library.lua")
local ThemeManager = safeLoad(REPO .. "addons/ThemeManager.lua")
local SaveManager  = safeLoad(REPO .. "addons/SaveManager.lua")
if not Library then error("[HUB] Library failed.") end

-- Services
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser    = game:GetService("VirtualUser")
local lp            = Players.LocalPlayer

local function getChar() return lp.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- Window
local gameName = CONFIG.HUB_TITLE
local Window = Library:CreateWindow({
    Title            = gameName,
    Footer           = CONFIG.FOOTER_TEXT,
    NotifySide       = CONFIG.NOTIF_SIDE,
    ShowCustomCursor = true,
    Size             = UDim2.fromOffset(CONFIG.WINDOW_W, CONFIG.WINDOW_H),
})

local Tabs = {
    Farm     = Window:AddTab("Farm"),
    Player   = Window:AddTab("Player"),
    Shop     = Window:AddTab("Shop"),
    ESP      = Window:AddTab("ESP"),
    World    = Window:AddTab("World"),
    Settings = Window:AddTab("Settings"),
}

-- ============================================================
--  STATE
-- ============================================================
local State = {
    -- farm
    targetPlayer     = nil,
    targetMob        = nil,
    farmPlayersOn    = false,
    farmMobsOn       = false,
    killAuraOn       = false,
    antiRagdoll      = false,
    farmMode         = "Kill",
    offset           = Vector3.new(0, 0, 0),
    instaKill        = false,
    instaHPThresh    = 50,
    instaRange       = 30,
    showOwnership    = false,
    tpRange          = 50,
    tpNPCsOn         = false,
    freezeNPCsOn     = false,

    -- player
    flyOn            = false,
    flySpeed         = 50,
    flyMode          = "Default",
    safeMode         = false,
    safeHeight       = 5,
    speedhackOn      = false,
    speedhackSpeed   = 100,
    infiniteJump     = false,
    jumpHeight       = 50,
    noclipOn         = false,
    noAnims          = false,
    animSpeed        = 1,
    autoRespawn      = false,
    savedPos         = nil,
    autoRetreat      = false,
    retreatHP        = 30,
    antiAFK          = false,
    noSlow           = false,
    infiniteOxygen   = false,
    swimWithFruit    = false,
    waterWalk        = false,
    noDashCD         = false,
    tpBackOnDeath    = false,
    deathPos         = nil,
    invisOn          = false,
    chatLogOn        = false,

    -- shop
    shopItem         = "",
    shopQty          = 1,

    -- esp
    playerESPOn      = false,
    playerESPColor   = Color3.fromRGB(255,255,0),
    showLocalESP     = false,
    mobESPOn         = false,
    mobESPColor      = Color3.fromRGB(255,0,0),
    espBoxes         = true,
    espGlow          = false,
    espChams         = false,
    espName          = true,
    espDist          = true,
    espHP            = true,
    espWeapon        = false,
    espRange         = 500,

    -- world
    spectateTarget   = nil,
    noFog            = false,
    noAtmos          = false,
    fullBright       = false,
    brightness       = 1,
    freecamOn        = false,
    freecamSens      = 5,
    freecamSpeed     = 20,
    force3rd         = false,
    fovVal           = 70,
    clickTP          = false,
    nearbyNotif      = false,
    alertRange       = 50,
    attachTarget     = nil,
    attachRange      = 5,
    attachDist       = 3,
    attachHeight     = 0,
    autoHide         = false,

    -- loops/connections
    _loops           = {},
    _conns           = {},
}

local function addLoop(name, fn, interval)
    if State._loops[name] then State._loops[name]:Disconnect() end
    State._loops[name] = RunService.Heartbeat:Connect(function()
        pcall(fn)
        if interval then task.wait(interval) end
    end)
end
local function stopLoop(name)
    if State._loops[name] then
        State._loops[name]:Disconnect()
        State._loops[name] = nil
    end
end

-- ============================================================
--  HELPERS
-- ============================================================
local function getNearestMob(range)
    local hrp = getHRP()
    if not hrp then return nil end
    local closest, dist = nil, range or 9999
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
                    local d = (hrp.Position - root.Position).Magnitude
                    if d < dist then closest = obj dist = d end
                end
            end
        end
    end
    return closest
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
                if not isPlayer then table.insert(list, obj.Name) end
            end
        end
    end
    return list
end

local function getPlayerNames()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then table.insert(t, p.Name) end
    end
    return t
end

local function notify(title, desc, time)
    Library:Notify({ Title = title, Description = desc, Time = time or 3 })
end

-- ============================================================
--  TAB: FARM
-- ============================================================

-- Farm — Players
local FarmPlayers = Tabs.Farm:AddSection("Farm — Players")

local playerDropdown = FarmPlayers:AddDropdown({
    Text    = "Target Player",
    Values  = getPlayerNames(),
    Default = 1,
    Callback = function(val) State.targetPlayer = val end,
})

FarmPlayers:AddButton({
    Text = "Refresh Players",
    Func = function()
        playerDropdown:Refresh(getPlayerNames())
        notify(gameName, "Player list refreshed.", 2)
    end,
})

FarmPlayers:AddToggle({
    Text    = "Farm Players",
    Default = false,
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
                hrp.CFrame = targetRoot.CFrame * CFrame.new(
                    State.offset.X, State.offset.Y, State.offset.Z + 3
                )
                -- basic attack
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
        else
            stopLoop("farmPlayers")
        end
    end,
})

-- Farm — Mobs
local FarmMobs = Tabs.Farm:AddSection("Farm — Mobs")

local mobDropdown = FarmMobs:AddDropdown({
    Text    = "Target Mob",
    Values  = getMobs(),
    Default = 1,
    Callback = function(val) State.targetMob = val end,
})

FarmMobs:AddButton({
    Text = "Refresh Mobs",
    Func = function()
        mobDropdown:Refresh(getMobs())
        notify(gameName, "Mob list refreshed.", 2)
    end,
})

FarmMobs:AddToggle({
    Text    = "Farm Mobs",
    Default = false,
    Callback = function(val)
        State.farmMobsOn = val
        if val then
            addLoop("farmMobs", function()
                local hrp = getHRP()
                if not hrp then return end
                -- tìm mob theo tên target
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
        else
            stopLoop("farmMobs")
        end
    end,
})

-- Farm — Combat
local FarmCombat = Tabs.Farm:AddSection("Farm — Combat")

FarmCombat:AddToggle({
    Text    = "Kill Aura",
    Default = false,
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
                                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(
                                        root.Position.X, hrp.Position.Y, root.Position.Z
                                    ))
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
        else
            stopLoop("killAura")
        end
    end,
})

FarmCombat:AddToggle({
    Text    = "Anti Ragdoll",
    Default = false,
    Callback = function(val)
        State.antiRagdoll = val
        if val then
            addLoop("antiRagdoll", function()
                local char = getChar()
                if not char then return end
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                        v.Enabled = false
                    end
                end
                local hum = getHum()
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
        else
            stopLoop("antiRagdoll")
        end
    end,
})

FarmCombat:AddDropdown({
    Text    = "Farm Mode",
    Values  = {"Kill", "Collect", "Passive"},
    Default = 1,
    Callback = function(val) State.farmMode = val end,
})

FarmCombat:AddSlider({ Text="X Offset", Min=-20, Max=20, Default=0, Callback=function(v) State.offset = Vector3.new(v, State.offset.Y, State.offset.Z) end })
FarmCombat:AddSlider({ Text="Y Offset", Min=-20, Max=20, Default=0, Callback=function(v) State.offset = Vector3.new(State.offset.X, v, State.offset.Z) end })
FarmCombat:AddSlider({ Text="Z Offset", Min=-20, Max=20, Default=0, Callback=function(v) State.offset = Vector3.new(State.offset.X, State.offset.Y, v) end })

-- Farm — Insta Kill
local FarmInsta = Tabs.Farm:AddSection("Farm — Insta Kill")

FarmInsta:AddToggle({
    Text    = "Insta Kill",
    Default = false,
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
                                if dist <= State.instaRange and hum.Health <= (hum.MaxHealth * State.instaHPThresh / 100) then
                                    hum.Health = 0
                                end
                            end
                        end
                    end
                end
            end)
        else
            stopLoop("instaKill")
        end
    end,
})

FarmInsta:AddSlider({ Text="HP Threshold (%)", Min=1, Max=100, Default=50, Callback=function(v) State.instaHPThresh = v end })
FarmInsta:AddSlider({ Text="Range", Min=5, Max=200, Default=30, Callback=function(v) State.instaRange = v end })

-- Farm — Network
local FarmNet = Tabs.Farm:AddSection("Farm — Network")

FarmNet:AddToggle({
    Text    = "Show Ownership",
    Default = false,
    Callback = function(val)
        State.showOwnership = val
        if val then
            addLoop("showOwnership", function()
                for _, bp in ipairs(workspace:GetDescendants()) do
                    if bp:IsA("BasePart") then
                        pcall(function()
                            local owner = bp:GetNetworkOwner()
                            -- highlight parts owned by server (nil) vs player
                            if owner == nil then
                                bp.Color = Color3.fromRGB(255, 100, 100)
                            else
                                bp.Color = Color3.fromRGB(100, 255, 100)
                            end
                        end)
                    end
                end
            end)
        else
            stopLoop("showOwnership")
            -- restore
            for _, bp in ipairs(workspace:GetDescendants()) do
                pcall(function()
                    if bp:IsA("BasePart") then
                        bp.Color = Color3.fromRGB(163,162,165)
                    end
                end)
            end
        end
    end,
})

FarmNet:AddSlider({ Text="TP Range", Min=5, Max=500, Default=50, Callback=function(v) State.tpRange = v end })

FarmNet:AddToggle({
    Text    = "TP NPCs To You",
    Default = false,
    Callback = function(val)
        State.tpNPCsOn = val
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
                                local dist = (hrp.Position - root.Position).Magnitude
                                if dist <= State.tpRange then
                                    root.CFrame = hrp.CFrame * CFrame.new(3, 0, 0)
                                end
                            end
                        end
                    end
                end
            end)
        else
            stopLoop("tpNPCs")
        end
    end,
})

FarmNet:AddToggle({
    Text    = "Freeze NPCs",
    Default = false,
    Callback = function(val)
        State.freezeNPCsOn = val
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
--  TAB: PLAYER
-- ============================================================

-- Movement
local Movement = Tabs.Player:AddSection("Player — Movement")

-- Fly
local flyConn
Movement:AddToggle({
    Text    = "Fly",
    Default = false,
    Callback = function(val)
        State.flyOn = val
        local char = getChar()
        local hrp  = getHRP()
        local hum  = getHum()
        if not char or not hrp or not hum then return end

        if val then
            hum.PlatformStand = true
            local bp = Instance.new("BodyVelocity")
            bp.Name = "_FlyBV"
            bp.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bp.Velocity  = Vector3.zero
            bp.Parent = hrp

            local bg = Instance.new("BodyGyro")
            bg.Name = "_FlyBG"
            bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            bg.P = 1e4
            bg.Parent = hrp

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
                bg.CFrame   = cam.CFrame
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

Movement:AddSlider({ Text="Fly Speed", Min=10, Max=500, Default=50, Callback=function(v) State.flySpeed = v end })
Movement:AddDropdown({ Text="Fly Mode", Values={"Default","Silent","Tween"}, Default=1, Callback=function(v) State.flyMode = v end })
Movement:AddToggle({ Text="Safe Mode", Default=false, Callback=function(v) State.safeMode = v end })
Movement:AddSlider({ Text="Safe Height", Min=1, Max=50, Default=5, Callback=function(v) State.safeHeight = v end })

Movement:AddButton({
    Text = "Cancel Tween",
    Func = function()
        local hrp = getHRP()
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if v:IsA("Tween") then v:Cancel() end
            end
        end
    end,
})

Movement:AddToggle({
    Text    = "Speedhack",
    Default = false,
    Callback = function(val)
        State.speedhackOn = val
        local hum = getHum()
        if hum then
            hum.WalkSpeed = val and State.speedhackSpeed or 16
        end
    end,
})
Movement:AddSlider({ Text="Speedhack Speed", Min=16, Max=1000, Default=100, Callback=function(v)
    State.speedhackSpeed = v
    if State.speedhackOn then
        local hum = getHum()
        if hum then hum.WalkSpeed = v end
    end
end })

Movement:AddToggle({
    Text    = "Infinite Jump",
    Default = false,
    Callback = function(val)
        State.infiniteJump = val
        if val then
            State._conns["infiniteJump"] = UserInputService.JumpRequest:Connect(function()
                local hum = getHum()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        else
            if State._conns["infiniteJump"] then
                State._conns["infiniteJump"]:Disconnect()
                State._conns["infiniteJump"] = nil
            end
        end
    end,
})
Movement:AddSlider({ Text="Jump Height", Min=50, Max=1000, Default=50, Callback=function(v)
    State.jumpHeight = v
    local hum = getHum()
    if hum then hum.JumpPower = v end
end })

Movement:AddToggle({
    Text    = "Noclip",
    Default = false,
    Callback = function(val)
        State.noclipOn = val
        if val then
            addLoop("noclip", function()
                local char = getChar()
                if not char then return end
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
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

Movement:AddToggle({
    Text    = "Jump Fix",
    Default = false,
    Callback = function(val)
        if val then
            addLoop("jumpFix", function()
                local hum = getHum()
                if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then
                    hum:ChangeState(Enum.HumanoidStateType.Landed)
                end
            end)
        else
            stopLoop("jumpFix")
        end
    end,
})

-- Utility
local Utility = Tabs.Player:AddSection("Player — Utility")

Utility:AddToggle({ Text="No Anims", Default=false, Callback=function(val)
    State.noAnims = val
    local char = getChar()
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if animate then animate.Disabled = val end
end })

Utility:AddSlider({ Text="Anim Speed", Min=0.1, Max=5, Default=1, Callback=function(v)
    State.animSpeed = v
    local char = getChar()
    if not char then return end
    for _, track in ipairs(char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid"):GetPlayingAnimationTracks() or {}) do
        track:AdjustSpeed(v)
    end
end })

Utility:AddToggle({ Text="Auto Respawn", Default=false, Callback=function(val)
    State.autoRespawn = val
    if val then
        State._conns["autoRespawn"] = lp.CharacterAdded:Connect(function() end)
        addLoop("autoRespawnCheck", function()
            local hum = getHum()
            if not hum or hum.Health <= 0 then
                task.wait(1)
                lp:LoadCharacter()
            end
        end)
    else
        stopLoop("autoRespawnCheck")
    end
end })

Utility:AddButton({ Text="Save Position", Func=function()
    local hrp = getHRP()
    if hrp then
        State.savedPos = hrp.CFrame
        notify(gameName, "Position saved.", 2)
    end
end })

Utility:AddButton({ Text="TP to Saved", Func=function()
    local hrp = getHRP()
    if hrp and State.savedPos then
        hrp.CFrame = State.savedPos
    else
        notify(gameName, "No saved position.", 2)
    end
end })

Utility:AddSlider({ Text="HP Threshold (%)", Min=1, Max=99, Default=30, Callback=function(v) State.retreatHP = v end })

Utility:AddToggle({ Text="Auto Retreat", Default=false, Callback=function(val)
    State.autoRetreat = val
    if val then
        addLoop("autoRetreat", function()
            local hum = getHum()
            local hrp = getHRP()
            if not hum or not hrp then return end
            if hum.Health / hum.MaxHealth * 100 <= State.retreatHP then
                if State.savedPos then hrp.CFrame = State.savedPos end
            end
        end)
    else
        stopLoop("autoRetreat")
    end
end })

Utility:AddToggle({ Text="Anti AFK", Default=false, Callback=function(val)
    State.antiAFK = val
    if val then
        State._conns["antiAFK"] = lp.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
        end)
    else
        if State._conns["antiAFK"] then
            State._conns["antiAFK"]:Disconnect()
            State._conns["antiAFK"] = nil
        end
    end
end })

Utility:AddButton({ Text="Kill Self", Func=function()
    local hum = getHum()
    if hum then hum.Health = 0 end
end })

-- Misc
local Misc = Tabs.Player:AddSection("Player — Misc")

Misc:AddToggle({ Text="No Slow", Default=false, Callback=function(val)
    State.noSlow = val
    if val then
        addLoop("noSlow", function()
            local hum = getHum()
            if hum and hum.WalkSpeed < 16 and not State.speedhackOn then
                hum.WalkSpeed = 16
            end
        end)
    else
        stopLoop("noSlow")
    end
end })

Misc:AddToggle({ Text="Infinite Oxygen", Default=false, Callback=function(val)
    State.infiniteOxygen = val
    if val then
        addLoop("oxygen", function()
            local char = getChar()
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    for _, v in ipairs(char:GetDescendants()) do
                        if v.Name == "OxygenValue" or v.Name == "Oxygen" then
                            pcall(function() v.Value = v.MaxValue or 100 end)
                        end
                    end
                end
            end
        end)
    else
        stopLoop("oxygen")
    end
end })

Misc:AddToggle({ Text="Swim With Fruit", Default=false, Callback=function(val)
    -- patch swim penalty from devil fruit
    if val then
        addLoop("swimFruit", function()
            local hum = getHum()
            if hum then hum.WalkSpeed = math.max(hum.WalkSpeed, 16) end
        end)
    else
        stopLoop("swimFruit")
    end
end })

Misc:AddToggle({ Text="Water Walk", Default=false, Callback=function(val)
    if val then
        addLoop("waterWalk", function()
            local char = getChar()
            local hrp  = getHRP()
            if not char or not hrp then return end
            if hrp.Position.Y < workspace.FallenPartsDestroyHeight + 5 then
                hrp.CFrame = CFrame.new(hrp.Position.X, 0.5, hrp.Position.Z)
            end
        end)
    else
        stopLoop("waterWalk")
    end
end })

Misc:AddToggle({ Text="No Dash Cooldown", Default=false, Callback=function(val)
    State.noDashCD = val
    if val then
        addLoop("noDashCD", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("NumberValue") and v.Name:lower():find("dash") and v.Name:lower():find("cool") then
                    v.Value = 0
                end
            end
        end)
    else
        stopLoop("noDashCD")
    end
end })

Misc:AddToggle({ Text="TP Back on Death", Default=false, Callback=function(val)
    State.tpBackOnDeath = val
    if val then
        local hrp = getHRP()
        if hrp then State.deathPos = hrp.CFrame end
        State._conns["tpBackDeath"] = lp.CharacterAdded:Connect(function(char)
            task.wait(1)
            local root = char:WaitForChild("HumanoidRootPart", 5)
            if root and State.deathPos then
                root.CFrame = State.deathPos
            end
        end)
    else
        if State._conns["tpBackDeath"] then
            State._conns["tpBackDeath"]:Disconnect()
            State._conns["tpBackDeath"] = nil
        end
    end
end })

Misc:AddToggle({ Text="Invisibility (RakNet)", Default=false, Callback=function(val)
    State.invisOn = val
    -- RakNet pause trick
    if val then
        if sethiddenproperty then
            pcall(function()
                sethiddenproperty(lp, "ReplicationFocus", nil)
            end)
        end
    else
        pcall(function()
            if sethiddenproperty then
                sethiddenproperty(lp, "ReplicationFocus", workspace.CurrentCamera)
            end
        end)
    end
end })

Misc:AddToggle({ Text="Chat Logger", Default=false, Callback=function(val)
    State.chatLogOn = val
    if val then
        State._conns["chatLog"] = Players.PlayerAdded:Connect(function() end)
        -- hook chat via TextChatService
        local tcs = game:GetService("TextChatService")
        if tcs then
            State._conns["chatHook"] = tcs.MessageReceived:Connect(function(msg)
                print(string.format("[CHAT] %s: %s", msg.TextSource and msg.TextSource.Name or "?", msg.Text))
            end)
        end
    else
        for _, k in ipairs({"chatLog","chatHook"}) do
            if State._conns[k] then State._conns[k]:Disconnect() State._conns[k] = nil end
        end
    end
end })

-- ============================================================
--  TAB: SHOP
-- ============================================================
local ShopSection = Tabs.Shop:AddSection("Shop")

ShopSection:AddTextbox({ Text="Item", Default="", Callback=function(v) State.shopItem = v end })
ShopSection:AddSlider({ Text="Quantity", Min=1, Max=999, Default=1, Callback=function(v) State.shopQty = v end })

ShopSection:AddButton({ Text="Buy", Func=function()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name:lower():find("buy") then
            pcall(function() v:FireServer(State.shopItem, State.shopQty) end)
        end
    end
    notify(gameName, "Buy fired: " .. State.shopItem .. " x" .. State.shopQty, 2)
end })

ShopSection:AddButton({ Text="Refresh Items", Func=function()
    notify(gameName, "Items refreshed.", 2)
end })

local AutoSection = Tabs.Shop:AddSection("Auto")

AutoSection:AddToggle({ Text="Auto Training Dummy", Default=false, Callback=function(val)
    if val then
        addLoop("autoDummy", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and v.Name:lower():find("train") then
                    pcall(function() v:FireServer() end)
                end
            end
            task.wait(0.5)
        end)
    else stopLoop("autoDummy") end
end })

AutoSection:AddToggle({ Text="Auto Fishing", Default=false, Callback=function(val)
    if val then
        addLoop("autoFish", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and v.Name:lower():find("fish") then
                    pcall(function() v:FireServer() end)
                end
            end
            task.wait(1)
        end)
    else stopLoop("autoFish") end
end })

AutoSection:AddToggle({ Text="Auto Perfect Mining", Default=false, Callback=function(val)
    if val then
        addLoop("autoPerfectMine", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and (v.Name:lower():find("mine") or v.Name:lower():find("perfect")) then
                    pcall(function() v:FireServer(true) end)
                end
            end
            task.wait(0.3)
        end)
    else stopLoop("autoPerfectMine") end
end })

AutoSection:AddToggle({ Text="Auto Mine", Default=false, Callback=function(val)
    if val then
        addLoop("autoMine", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and v.Name:lower():find("mine") then
                    pcall(function() v:FireServer() end)
                end
            end
            task.wait(0.5)
        end)
    else stopLoop("autoMine") end
end })

AutoSection:AddToggle({ Text="Auto Sell", Default=false, Callback=function(val)
    if val then
        addLoop("autoSell", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and v.Name:lower():find("sell") then
                    pcall(function() v:FireServer() end)
                end
            end
            task.wait(2)
        end)
    else stopLoop("autoSell") end
end })

AutoSection:AddToggle({ Text="Auto Quests", Default=false, Callback=function(val)
    if val then
        addLoop("autoQuests", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and (v.Name:lower():find("quest") or v.Name:lower():find("accept")) then
                    pcall(function() v:FireServer() end)
                end
            end
            task.wait(2)
        end)
    else stopLoop("autoQuests") end
end })

AutoSection:AddToggle({ Text="Auto Invest Stats", Default=false, Callback=function(val)
    if val then
        addLoop("autoInvest", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and (v.Name:lower():find("invest") or v.Name:lower():find("stat")) then
                    pcall(function() v:FireServer() end)
                end
            end
            task.wait(1)
        end)
    else stopLoop("autoInvest") end
end })

local AchSection = Tabs.Shop:AddSection("Achievements")

AchSection:AddToggle({ Text="Auto Claim Achievements", Default=false, Callback=function(val)
    if val then
        addLoop("autoAchieve", function()
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and (v.Name:lower():find("achiev") or v.Name:lower():find("claim")) then
                    pcall(function() v:FireServer() end)
                end
            end
            task.wait(3)
        end)
    else stopLoop("autoAchieve") end
end })

AchSection:AddButton({ Text="Claim All Now", Func=function()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("achiev") or v.Name:lower():find("claim")) then
            pcall(function() v:FireServer() end)
        end
    end
    notify(gameName, "Claimed all achievements.", 2)
end })

-- ============================================================
--  TAB: ESP
-- ============================================================
local espObjects = {}

local function clearESP()
    for _, v in pairs(espObjects) do
        pcall(function() v:Destroy() end)
    end
    espObjects = {}
end

local function makeESPBox(target, color)
    local box = Drawing.new("Square")
    box.Color      = color
    box.Thickness  = 1
    box.Filled     = false
    box.Visible    = true
    return box
end

local function updateESP()
    clearESP()
    local cam = workspace.CurrentCamera
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp or State.showLocalESP then
            local char = p.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (getHRP() and getHRP().Position or Vector3.zero - hrp.Position).Magnitude
                    if dist <= State.espRange then
                        local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                        if onScreen and State.espBoxes then
                            local box = Drawing.new("Square")
                            box.Color     = State.playerESPColor
                            box.Size      = Vector2.new(40, 60)
                            box.Position  = Vector2.new(pos.X - 20, pos.Y - 30)
                            box.Thickness = 1
                            box.Filled    = false
                            box.Visible   = true
                            table.insert(espObjects, box)
                        end
                        if State.espName then
                            local lbl = Drawing.new("Text")
                            lbl.Text     = p.Name
                            lbl.Color    = State.playerESPColor
                            lbl.Size     = 14
                            lbl.Position = Vector2.new(pos.X, pos.Y - 40)
                            lbl.Visible  = onScreen
                            table.insert(espObjects, lbl)
                        end
                        if State.espDist then
                            local dlbl = Drawing.new("Text")
                            dlbl.Text     = math.floor(dist) .. "m"
                            dlbl.Color    = Color3.fromRGB(255,255,255)
                            dlbl.Size     = 12
                            dlbl.Position = Vector2.new(pos.X, pos.Y + 35)
                            dlbl.Visible  = onScreen
                            table.insert(espObjects, dlbl)
                        end
                    end
                end
            end
        end
    end
end

local PlayerESP = Tabs.ESP:AddSection("Player ESP")

PlayerESP:AddToggle({ Text="Player ESP", Default=false, Callback=function(val)
    State.playerESPOn = val
    if val then
        addLoop("playerESP", updateESP, 0.1)
    else
        stopLoop("playerESP")
        clearESP()
    end
end })

PlayerESP:AddColorPicker({ Text="Player ESP Color", Default=Color3.fromRGB(255,255,0), Callback=function(v) State.playerESPColor = v end })
PlayerESP:AddToggle({ Text="Show Local ESP", Default=false, Callback=function(v) State.showLocalESP = v end })

local MobESP = Tabs.ESP:AddSection("Mob ESP")
MobESP:AddColorPicker({ Text="Mob ESP Color", Default=Color3.fromRGB(255,0,0), Callback=function(v) State.mobESPColor = v end })
MobESP:AddToggle({ Text="Mob ESP", Default=false, Callback=function(val)
    State.mobESPOn = val
end })

local ESPCfg = Tabs.ESP:AddSection("ESP Config")
ESPCfg:AddToggle({ Text="Boxes",         Default=true,  Callback=function(v) State.espBoxes  = v end })
ESPCfg:AddToggle({ Text="Show Name",     Default=true,  Callback=function(v) State.espName   = v end })
ESPCfg:AddToggle({ Text="Show Distance", Default=true,  Callback=function(v) State.espDist   = v end })
ESPCfg:AddToggle({ Text="Show HP",       Default=true,  Callback=function(v) State.espHP     = v end })
ESPCfg:AddToggle({ Text="Show Weapon",   Default=false, Callback=function(v) State.espWeapon = v end })
ESPCfg:AddSlider({ Text="Range", Min=50, Max=2000, Default=500, Callback=function(v) State.espRange = v end })

-- ============================================================
--  TAB: WORLD
-- ============================================================

-- Camera
local Camera = Tabs.World:AddSection("World — Camera")

Camera:AddDropdown({ Text="Spectate Player", Values=getPlayerNames(), Default=1, Callback=function(v) State.spectateTarget = v end })

Camera:AddButton({ Text="Spectate / Stop", Func=function()
    local cam = workspace.CurrentCamera
    if State.spectateTarget and cam.CameraType ~= Enum.CameraType.Scriptable then
        local target = Players:FindFirstChild(State.spectateTarget)
        if target and target.Character then
            cam.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid")
        end
    else
        cam.CameraType    = Enum.CameraType.Custom
        cam.CameraSubject = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    end
end })

Camera:AddToggle({ Text="No Fog", Default=false, Callback=function(val)
    local lighting = game:GetService("Lighting")
    lighting.FogEnd   = val and 1e6 or 100000
    lighting.FogStart = val and 1e6 or 0
end })

Camera:AddToggle({ Text="No Atmosphere", Default=false, Callback=function(val)
    local lighting = game:GetService("Lighting")
    for _, v in ipairs(lighting:GetChildren()) do
        if v:IsA("Atmosphere") then v.Density = val and 0 or 0.395 end
    end
end })

Camera:AddToggle({ Text="Full Bright", Default=false, Callback=function(val)
    local lighting = game:GetService("Lighting")
    lighting.Brightness = val and 2 or 1
    lighting.ClockTime  = val and 14 or 12
end })

Camera:AddSlider({ Text="Brightness", Min=0, Max=5, Default=1, Callback=function(v)
    game:GetService("Lighting").Brightness = v
end })

-- Freecam
local freecamConn
Camera:AddToggle({ Text="Freecam", Default=false, Callback=function(val)
    State.freecamOn = val
    local cam = workspace.CurrentCamera
    if val then
        cam.CameraType = Enum.CameraType.Scriptable
        local freecamPart = Instance.new("Part")
        freecamPart.Anchored    = true
        freecamPart.CanCollide  = false
        freecamPart.Transparency = 1
        freecamPart.Size        = Vector3.new(1,1,1)
        freecamPart.CFrame      = cam.CFrame
        freecamPart.Name        = "_Freecam"
        freecamPart.Parent      = workspace

        freecamConn = RunService.Heartbeat:Connect(function(dt)
            if not State.freecamOn then return end
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0,1,0) end
            freecamPart.CFrame = freecamPart.CFrame + dir * State.freecamSpeed * dt
            cam.CFrame = freecamPart.CFrame
        end)
    else
        if freecamConn then freecamConn:Disconnect() freecamConn = nil end
        local fp = workspace:FindFirstChild("_Freecam")
        if fp then fp:Destroy() end
        cam.CameraType    = Enum.CameraType.Custom
        cam.CameraSubject = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    end
end })

Camera:AddSlider({ Text="Look Sensitivity", Min=1, Max=20, Default=5, Callback=function(v) State.freecamSens = v end })
Camera:AddSlider({ Text="Move Speed", Min=5, Max=200, Default=20, Callback=function(v) State.freecamSpeed = v end })

-- Effects
local Effects = Tabs.World:AddSection("World — Effects")

Effects:AddToggle({ Text="Force 3rd Person", Default=false, Callback=function(val)
    local cam = workspace.CurrentCamera
    if val then
        addLoop("force3rd", function()
            cam.CameraType = Enum.CameraType.Custom
        end)
    else
        stopLoop("force3rd")
    end
end })

Effects:AddSlider({ Text="Camera FOV", Min=30, Max=120, Default=70, Callback=function(v)
    workspace.CurrentCamera.FieldOfView = v
end })

-- Performance
local Perf = Tabs.World:AddSection("World — Performance")

Perf:AddToggle({ Text="Anti Lag", Default=false, Callback=function(val)
    if val then
        addLoop("antiLag", function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                    v.Enabled = false
                end
            end
        end)
    else
        stopLoop("antiLag")
    end
end })

Perf:AddSlider({ Text="FPS Cap", Min=15, Max=240, Default=60, Callback=function(v)
    if setfpscap then setfpscap(v) end
end })

-- Teleport
local Teleport = Tabs.World:AddSection("World — Teleport")

Teleport:AddButton({ Text="Copy Coordinates", Func=function()
    local hrp = getHRP()
    if hrp then
        local p = hrp.Position
        local str = string.format("%.2f, %.2f, %.2f", p.X, p.Y, p.Z)
        if setclipboard then setclipboard(str) end
        notify(gameName, "Coords copied: " .. str, 3)
    end
end })

Teleport:AddToggle({ Text="Nearby Notifier", Default=false, Callback=function(val)
    State.nearbyNotif = val
    if val then
        addLoop("nearbyNotif", function()
            local hrp = getHRP()
            if not hrp then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and p.Character then
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local dist = (hrp.Position - root.Position).Magnitude
                        if dist <= State.alertRange then
                            notify(gameName, p.Name .. " nearby — " .. math.floor(dist) .. "m", 3)
                        end
                    end
                end
            end
        end)
    else
        stopLoop("nearbyNotif")
    end
end })

Teleport:AddSlider({ Text="Alert Range", Min=10, Max=500, Default=50, Callback=function(v) State.alertRange = v end })

Teleport:AddToggle({ Text="Click TP", Default=false, Callback=function(val)
    State.clickTP = val
    if val then
        State._conns["clickTP"] = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local hrp = getHRP()
                if not hrp then return end
                local ray = workspace:Raycast(
                    workspace.CurrentCamera.CFrame.Position,
                    (workspace.CurrentCamera.CFrame.LookVector * 500),
                    RaycastParams.new()
                )
                if ray then hrp.CFrame = CFrame.new(ray.Position + Vector3.new(0,3,0)) end
            end
        end)
    else
        if State._conns["clickTP"] then
            State._conns["clickTP"]:Disconnect()
            State._conns["clickTP"] = nil
        end
    end
end })

-- Attach
local Attach = Tabs.World:AddSection("World — Attach")

Attach:AddDropdown({ Text="Attach Target", Values=getPlayerNames(), Default=1, Callback=function(v) State.attachTarget = v end })
Attach:AddSlider({ Text="Range",    Min=1,  Max=200, Default=5,  Callback=function(v) State.attachRange  = v end })
Attach:AddSlider({ Text="Distance", Min=0,  Max=20,  Default=3,  Callback=function(v) State.attachDist   = v end })
Attach:AddSlider({ Text="Height",   Min=-5, Max=20,  Default=0,  Callback=function(v) State.attachHeight = v end })

Attach:AddButton({ Text="Attach Player", Func=function()
    if not State.attachTarget then return end
    local target = Players:FindFirstChild(State.attachTarget)
    if not target or not target.Character then return end
    addLoop("attach", function()
        local hrp = getHRP()
        local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not hrp or not targetRoot then return end
        hrp.CFrame = targetRoot.CFrame * CFrame.new(State.attachDist, State.attachHeight, 0)
    end)
    notify(gameName, "Attached to " .. State.attachTarget, 2)
end })

-- ============================================================
--  TAB: SETTINGS
-- ============================================================
local SettingsSection = Tabs.Settings:AddSection("Settings")

SettingsSection:AddToggle({ Text="Auto Hide", Default=false, Callback=function(val)
    State.autoHide = val
    if val then
        State._conns["autoHide"] = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.RightShift then
                Library:ToggleUI()
            end
        end)
    else
        if State._conns["autoHide"] then
            State._conns["autoHide"]:Disconnect()
            State._conns["autoHide"] = nil
        end
    end
end })

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("GrandBlueHub-Theme")
    ThemeManager:ApplyToTab(Tabs.Settings)
end

if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:SetFolder("GrandBlueHub-Config")
    SaveManager:ApplyToTab(Tabs.Settings)
end
