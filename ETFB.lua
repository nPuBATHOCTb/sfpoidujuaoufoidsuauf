--[[
    ETFB Hub | Single File Build
    Target: Escape Tsunami for Brainrots (Roblox)
    Executor: Xeno / sUNC-compatible
    Author: Fox for Jack
    Version: 1.0.0

    Один файл, три логические секции:
      PART 1 — ядро (сервисы, конфиг, утилиты, GUI-примитивы)
      PART 2 — GUI-библиотека
      PART 3 — GameModule (резолвер ремоутов + игровые действия)
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local HttpService          = game:GetService("HttpService")
local Workspace            = game:GetService("Workspace")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local StarterGui           = game:GetService("StarterGui")
local Lighting             = game:GetService("Lighting")
local VirtualUser          = game:GetService("VirtualUser")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local CoreGui              = game:GetService("CoreGui")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ============================================================
-- EXECUTOR COMPAT LAYER
-- ============================================================
local Executor = {}

local function safeGlobal(name, fallback)
    local ok, val = pcall(function()
        return getgenv and getgenv()[name] or _G[name]
    end)
    if ok and val ~= nil then return val end
    return fallback
end

Executor.getgenv         = safeGlobal("getgenv", function() return _G end)
Executor.getrawmetatable = safeGlobal("getrawmetatable", getmetatable)
Executor.setreadonly     = safeGlobal("setreadonly", function() end)
Executor.isfile          = safeGlobal("isfile", function() return false end)
Executor.readfile        = safeGlobal("readfile", function() return nil end)
Executor.writefile       = safeGlobal("writefile", function() end)
Executor.makefolder      = safeGlobal("makefolder", function() end)
Executor.isfolder        = safeGlobal("isfolder", function() return false end)
Executor.listfiles       = safeGlobal("listfiles", function() return {} end)
Executor.delfile         = safeGlobal("delfile", function() end)
Executor.loadstring      = safeGlobal("loadstring", function(s) return function() end end)
Executor.getconnections  = safeGlobal("getconnections", function() return {} end)
Executor.getnilinstances = safeGlobal("getnilinstances", function() return {} end)
Executor.getscripts      = safeGlobal("getscripts", function() return {} end)
Executor.getloadedmodules= safeGlobal("getloadedmodules", function() return {} end)
Executor.hookfunction    = safeGlobal("hookfunction", function() end)
Executor.newcclosure     = safeGlobal("newcclosure", function(f) return f end)
Executor.checkcaller     = safeGlobal("checkcaller", function() return false end)
Executor.setclipboard    = safeGlobal("setclipboard", function() end)
Executor.getclipboard    = safeGlobal("getclipboard", function() return "" end)
Executor.request         = safeGlobal("request", safeGlobal("http_request", function() return {StatusCode = 0, Body = ""} end))
Executor.getcustomasset  = safeGlobal("getcustomasset", function() return "" end)
Executor.queue_on_teleport = safeGlobal("queue_on_teleport", function() end)
Executor.setfpscap       = safeGlobal("setfpscap", function() end)

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    Version         = "1.0.0",
    Debug           = false,
    AutoSave        = true,
    SaveInterval    = 30,

    AutoFarm        = false,
    AutoCollect     = false,
    AutoUpgrade     = false,
    AutoRebirth     = false,
    AutoSell        = false,
    AutoPlace       = false,
    FarmDelay       = 0.1,
    CollectDelay    = 0.25,

    GodMode         = false,
    InfiniteJump    = false,
    WalkSpeed       = 16,
    JumpPower       = 50,
    FlySpeed        = 50,
    Noclip          = false,
    AntiTsunami     = false,

    TeleportDelay   = 0.5,

    ESPEnabled      = false,
    ESPBoxes        = true,
    ESPNames        = true,
    ESPDistance     = true,
    ESPTracers      = false,
    ESPColor        = Color3.fromRGB(0, 255, 100),

    UITheme         = "Dark",
    UIPosition      = UDim2.new(0.5, 0, 0.5, 0),
    UIToggleKey     = Enum.KeyCode.RightShift,
    UIAccent        = Color3.fromRGB(0, 170, 255),
    UIBackground    = Color3.fromRGB(20, 20, 25),
    UIText          = Color3.fromRGB(240, 240, 240),
}

-- ============================================================
-- SAVE / LOAD
-- ============================================================
local function getConfigPath()
    return "ETFB_Hub/config.json"
end

local function ensureFolder()
    if not Executor.isfolder("ETFB_Hub") then
        Executor.makefolder("ETFB_Hub")
    end
end

function Config:Save()
    if not Config.AutoSave then return end
    ensureFolder()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Config)
    if ok and encoded then
        Executor.writefile(getConfigPath(), encoded)
    end
end

function Config:Load()
    ensureFolder()
    if Executor.isfile(getConfigPath()) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(Executor.readfile(getConfigPath()))
        end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if Config[k] ~= nil then
                    Config[k] = v
                end
            end
        end
    end
end

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local Util = {}

function Util:Log(...)
    if Config.Debug then
        print("[ETFB]", ...)
    end
end

function Util:Warn(...)
    warn("[ETFB]", ...)
end

function Util:GetChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Util:GetHRP()
    local char = Util:GetChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Util:GetHum()
    local char = Util:GetChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Util:IsAlive()
    local hum = Util:GetHum()
    return hum and hum.Health > 0
end

function Util:WaitForChild(parent, name, timeout)
    timeout = timeout or 10
    local start = tick()
    repeat
        local child = parent:FindFirstChild(name)
        if child then return child end
        task.wait(0.1)
    until tick() - start > timeout
    return nil
end

function Util:WaitForDescendant(parent, name, timeout)
    timeout = timeout or 10
    local start = tick()
    repeat
        local child = parent:FindFirstChild(name, true)
        if child then return child end
        task.wait(0.1)
    until tick() - start > timeout
    return nil
end

function Util:GetDistance(pos1, pos2)
    if typeof(pos1) == "Instance" then pos1 = pos1.Position end
    if typeof(pos2) == "Instance" then pos2 = pos2.Position end
    return (pos1 - pos2).Magnitude
end

function Util:FireProximityPrompt(prompt, holdTime)
    holdTime = holdTime or 0.1
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt, holdTime)
    else
        pcall(function()
            prompt.HoldDuration = 0
            fireproximityprompt(prompt)
        end)
    end
end

function Util:ClickButton(button)
    if not button then return end
    local ok = pcall(function()
        button:Activate()
    end)
    if not ok then
        pcall(function()
            local args = {}
            button.MouseButton1Click:Fire(args)
        end)
    end
end

function Util:FireTouchInterest(part1, part2, toggle)
    if firetouchinterest then
        pcall(firetouchinterest, part1, part2, toggle and 0 or 1)
    elseif firetouchinterest2 then
        pcall(firetouchinterest2, part1, part2, toggle and 0 or 1)
    end
end

function Util:GetRemoteEvent(parent, name)
    return Util:WaitForChild(parent, name) or Util:WaitForDescendant(parent, name)
end

function Util:GetAllDescendants(parent, className)
    local results = {}
    for _, v in ipairs(parent:GetDescendants()) do
        if v:IsA(className) then
            table.insert(results, v)
        end
    end
    return results
end

function Util:GetAllChildren(parent, className)
    local results = {}
    for _, v in ipairs(parent:GetChildren()) do
        if v:IsA(className) then
            table.insert(results, v)
        end
    end
    return results
end

function Util:GetPlayerFromCharacter(char)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == char then return plr end
    end
    return nil
end

function Util:GetHRPFromPlayer(plr)
    if not plr or not plr.Character then return nil end
    return plr.Character:FindFirstChild("HumanoidRootPart")
end

function Util:GetDistanceToPlayer(plr)
    local myHRP = Util:GetHRP()
    local theirHRP = Util:GetHRPFromPlayer(plr)
    if not myHRP or not theirHRP then return math.huge end
    return (myHRP.Position - theirHRP.Position).Magnitude
end

function Util:GetClosestPlayer()
    local myHRP = Util:GetHRP()
    if not myHRP then return nil end
    local closest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hrp = Util:GetHRPFromPlayer(plr)
            if hrp then
                local dist = (myHRP.Position - hrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = plr
                end
            end
        end
    end
    return closest, minDist
end

function Util:GetClosestPartFromTag(tag)
    local myHRP = Util:GetHRP()
    if not myHRP then return nil end
    local closest, minDist = nil, math.huge
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:GetAttribute(tag) or v.Name:lower():find(tag:lower()) then
            if v:IsA("BasePart") then
                local dist = (myHRP.Position - v.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = v
                end
            end
        end
    end
    return closest, minDist
end

function Util:GetAllPartsWithTag(tag)
    local results = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v:GetAttribute(tag) or v.Name:lower():find(tag:lower())) then
            table.insert(results, v)
        end
    end
    return results
end

-- ============================================================
-- INSTANCE HELPERS
-- ============================================================
local InstanceHelper = {}

function InstanceHelper:Create(className, props, parent)
    local inst = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

function InstanceHelper:GetOrCreate(parent, className, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA(className) then return existing end
    if existing then existing:Destroy() end
    return InstanceHelper:Create(className, {Name = name}, parent)
end

function InstanceHelper:DestroyChildren(parent)
    for _, child in ipairs(parent:GetChildren()) do
        child:Destroy()
    end
end

function InstanceHelper:DestroyAllOfClass(parent, className)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA(className) then
            child:Destroy()
        end
    end
end

-- ============================================================
-- CONNECTION MANAGER
-- ============================================================
local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager

function ConnectionManager.new()
    local self = setmetatable({}, ConnectionManager)
    self._connections = {}
    return self
end

function ConnectionManager:Add(connection)
    table.insert(self._connections, connection)
    return connection
end

function ConnectionManager:Remove(connection)
    for i, conn in ipairs(self._connections) do
        if conn == connection then
            conn:Disconnect()
            table.remove(self._connections, i)
            return
        end
    end
end

function ConnectionManager:DisconnectAll()
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}
end

local GlobalConnections = ConnectionManager.new()

-- ============================================================
-- MAID / CLEANUP
-- ============================================================
local Maid = {}
Maid.__index = Maid

function Maid.new()
    local self = setmetatable({}, Maid)
    self._tasks = {}
    return self
end

function Maid:Add(task)
    table.insert(self._tasks, task)
    return task
end

function Maid:Clean()
    for _, task in ipairs(self._tasks) do
        if typeof(task) == "RBXScriptConnection" then
            task:Disconnect()
        elseif typeof(task) == "Instance" then
            task:Destroy()
        elseif typeof(task) == "function" then
            pcall(task)
        end
    end
    self._tasks = {}
end
-- ============================================================
-- GUI LIBRARY (minimal, no external deps)
-- ============================================================
local GUI = {}
GUI.__index = GUI

-- Инициализация полей синглтона (используем GUI как instance)
GUI.ScreenGui  = nil
GUI.MainFrame  = nil
GUI.TabBar     = nil
GUI.ContentArea= nil
GUI.Tabs       = {}
GUI.ActiveTab  = nil
GUI.Minimized  = false
GUI.Dragging   = false
GUI.DragStart  = nil
GUI.StartPos   = nil
GUI.Maid       = Maid.new()

function GUI.new()
    local self = setmetatable({}, GUI)
    self.ScreenGui = nil
    self.MainFrame = nil
    self.Tabs = {}
    self.ActiveTab = nil
    self.Minimized = false
    self.Dragging = false
    self.DragStart = nil
    self.StartPos = nil
    self.Maid = Maid.new()
    return self
end

function GUI:Init()
    if self.ScreenGui then self.ScreenGui:Destroy() end

    local parent = CoreGui
    if not pcall(function() return CoreGui.Name end) then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    self.ScreenGui = InstanceHelper:Create("ScreenGui", {
        Name = "ETFB_Hub",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, parent)

    self.MainFrame = InstanceHelper:Create("Frame", {
        Name = "Main",
        Size = UDim2.new(0, 560, 0, 420),
        Position = UDim2.new(0.5, -280, 0.5, -210),
        BackgroundColor3 = Config.UIBackground,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, self.ScreenGui)

    InstanceHelper:Create("UICorner", {
        CornerRadius = UDim.new(0, 8),
    }, self.MainFrame)

    InstanceHelper:Create("UIStroke", {
        Color = Config.UIAccent,
        Thickness = 1.5,
        Transparency = 0.3,
    }, self.MainFrame)

    local titleBar = InstanceHelper:Create("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        BorderSizePixel = 0,
    }, self.MainFrame)

    InstanceHelper:Create("UICorner", {
        CornerRadius = UDim.new(0, 8),
    }, titleBar)

    local titleFix = InstanceHelper:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        BorderSizePixel = 0,
    }, titleBar)

    InstanceHelper:Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "ETFB Hub | Fox for Jack",
        TextColor3 = Config.UIText,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, titleBar)

    local minimizeBtn = InstanceHelper:Create("TextButton", {
        Name = "Minimize",
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -64, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(40, 40, 45),
        Text = "—",
        TextColor3 = Config.UIText,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, titleBar)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, minimizeBtn)

    local closeBtn = InstanceHelper:Create("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -32, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(40, 40, 45),
        Text = "×",
        TextColor3 = Config.UIText,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, titleBar)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, closeBtn)

    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle(false)
    end)

    minimizeBtn.MouseButton1Click:Connect(function()
        self:ToggleMinimize()
    end)

    self.TabBar = InstanceHelper:Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(0, 130, 1, -36),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        BorderSizePixel = 0,
    }, self.MainFrame)

    self.ContentArea = InstanceHelper:Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -130, 1, -36),
        Position = UDim2.new(0, 130, 0, 36),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, self.MainFrame)

    local function startDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.Dragging = true
            self.DragStart = input.Position
            self.StartPos = self.MainFrame.Position
        end
    end

    local function updateDrag(input)
        if self.Dragging then
            local delta = input.Position - self.DragStart
            self.MainFrame.Position = UDim2.new(
                self.StartPos.X.Scale,
                self.StartPos.X.Offset + delta.X,
                self.StartPos.Y.Scale,
                self.StartPos.Y.Offset + delta.Y
            )
        end
    end

    local function endDrag()
        self.Dragging = false
    end

    titleBar.InputBegan:Connect(startDrag)
    titleBar.InputChanged:Connect(updateDrag)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Config.UIToggleKey then
            self:Toggle()
        end
    end)

    return self
end

function GUI:Toggle(state)
    if not self.MainFrame then return end
    if state ~= nil then
        self.MainFrame.Visible = state
    else
        self.MainFrame.Visible = not self.MainFrame.Visible
    end
end

function GUI:ToggleMinimize()
    if not self.MainFrame then return end
    self.Minimized = not self.Minimized
    if self.Minimized then
        self.MainFrame.Size = UDim2.new(0, 560, 0, 36)
    else
        self.MainFrame.Size = UDim2.new(0, 560, 0, 420)
    end
end

function GUI:AddTab(name, icon)
    local tabBtn = InstanceHelper:Create("TextButton", {
        Name = name .. "Tab",
        Size = UDim2.new(1, -8, 0, 32),
        Position = UDim2.new(0, 4, 0, 4 + (#self.Tabs * 36)),
        BackgroundColor3 = Color3.fromRGB(25, 25, 30),
        Text = "  " .. name,
        TextColor3 = Config.UIText,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, self.TabBar)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, tabBtn)

    local scroll = InstanceHelper:Create("ScrollingFrame", {
        Name = name .. "Content",
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 4,
        Visible = false,
    }, self.ContentArea)

    local layout = InstanceHelper:Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)

    local tab = {
        Name = name,
        Button = tabBtn,
        Scroll = scroll,
        Layout = layout,
        Elements = {},
    }

    table.insert(self.Tabs, tab)

    tabBtn.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    return tab
end

function GUI:SelectTab(name)
    for _, tab in ipairs(self.Tabs) do
        local isActive = tab.Name == name
        tab.Button.BackgroundColor3 = isActive and Color3.fromRGB(35, 35, 45) or Color3.fromRGB(25, 25, 30)
        tab.Button.TextColor3 = isActive and Config.UIAccent or Config.UIText
        tab.Scroll.Visible = isActive
        if isActive then self.ActiveTab = tab end
    end
end

function GUI:AddToggle(tab, text, default, callback)
    local frame = InstanceHelper:Create("Frame", {
        Size = UDim2.new(1, -8, 0, 32),
        BackgroundColor3 = Color3.fromRGB(25, 25, 30),
        BorderSizePixel = 0,
    }, tab.Scroll)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, frame)

    InstanceHelper:Create("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.UIText,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)

    local toggleBtn = InstanceHelper:Create("TextButton", {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -46, 0.5, -9),
        BackgroundColor3 = default and Config.UIAccent or Color3.fromRGB(50, 50, 55),
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, frame)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 9)}, toggleBtn)

    local knob = InstanceHelper:Create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, toggleBtn)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)

    local state = default

    local function setState(value)
        state = value
        toggleBtn.BackgroundColor3 = state and Config.UIAccent or Color3.fromRGB(50, 50, 55)
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        }):Play()
        if callback then callback(state) end
    end

    toggleBtn.MouseButton1Click:Connect(function()
        setState(not state)
    end)

    table.insert(tab.Elements, frame)
    return {Set = setState, Get = function() return state end, Frame = frame}
end

function GUI:AddButton(tab, text, callback)
    local btn = InstanceHelper:Create("TextButton", {
        Size = UDim2.new(1, -8, 0, 32),
        BackgroundColor3 = Color3.fromRGB(30, 30, 38),
        Text = text,
        TextColor3 = Config.UIText,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, tab.Scroll)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, btn)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 40, 50)}):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 38)}):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    table.insert(tab.Elements, btn)
    return btn
end

function GUI:AddSlider(tab, text, min, max, default, callback)
    local frame = InstanceHelper:Create("Frame", {
        Size = UDim2.new(1, -8, 0, 44),
        BackgroundColor3 = Color3.fromRGB(25, 25, 30),
        BorderSizePixel = 0,
    }, tab.Scroll)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, frame)

    InstanceHelper:Create("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20),
        Position = UDim2.new(0, 10, 0, 2),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Config.UIText,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)

    local valueLabel = InstanceHelper:Create("TextLabel", {
        Size = UDim2.new(0.5, -10, 0, 20),
        Position = UDim2.new(0.5, 0, 0, 2),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = Config.UIAccent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, frame)

    local barBg = InstanceHelper:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 8),
        Position = UDim2.new(0, 10, 0, 28),
        BackgroundColor3 = Color3.fromRGB(45, 45, 55),
        BorderSizePixel = 0,
    }, frame)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 4)}, barBg)

    local barFill = InstanceHelper:Create("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Config.UIAccent,
        BorderSizePixel = 0,
    }, barBg)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 4)}, barFill)

    local dragging = false

    local function updateFromInput(input)
        local relX = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * relX)
        barFill.Size = UDim2.new(relX, 0, 1, 0)
        valueLabel.Text = tostring(value)
        if callback then callback(value) end
        return value
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromInput(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    table.insert(tab.Elements, frame)
    return {Frame = frame, BarBg = barBg, BarFill = barFill, ValueLabel = valueLabel}
end

function GUI:AddLabel(tab, text)
    local label = InstanceHelper:Create("TextLabel", {
        Size = UDim2.new(1, -8, 0, 24),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.fromRGB(160, 160, 170),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, tab.Scroll)

    table.insert(tab.Elements, label)
    return label
end

function GUI:AddDivider(tab)
    local div = InstanceHelper:Create("Frame", {
        Size = UDim2.new(1, -16, 0, 1),
        BackgroundColor3 = Color3.fromRGB(50, 50, 60),
        BorderSizePixel = 0,
    }, tab.Scroll)

    table.insert(tab.Elements, div)
    return div
end

function GUI:AddTextBox(tab, placeholder, callback)
    local box = InstanceHelper:Create("TextBox", {
        Size = UDim2.new(1, -8, 0, 32),
        BackgroundColor3 = Color3.fromRGB(30, 30, 38),
        Text = "",
        PlaceholderText = placeholder,
        TextColor3 = Config.UIText,
        PlaceholderColor3 = Color3.fromRGB(100, 100, 110),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
    }, tab.Scroll)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, box)

    box.FocusLost:Connect(function(enterPressed)
        if callback then callback(box.Text, enterPressed) end
    end)

    table.insert(tab.Elements, box)
    return box
end

function GUI:AddDropdown(tab, text, options, callback)
    local frame = InstanceHelper:Create("Frame", {
        Size = UDim2.new(1, -8, 0, 32),
        BackgroundColor3 = Color3.fromRGB(25, 25, 30),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, tab.Scroll)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 6)}, frame)

    local selectedLabel = InstanceHelper:Create("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = text .. ": " .. (options[1] or ""),
        TextColor3 = Config.UIText,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)

    local dropdownBtn = InstanceHelper:Create("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -32, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(40, 40, 50),
        Text = "▼",
        TextColor3 = Config.UIText,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, frame)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 4)}, dropdownBtn)

    local isOpen = false
    local currentIndex = 1

    local function selectOption(idx)
        currentIndex = idx
        selectedLabel.Text = text .. ": " .. options[idx]
        if callback then callback(options[idx], idx) end
    end

    dropdownBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            frame.Size = UDim2.new(1, -8, 0, 32 + (#options * 28))
            for i, opt in ipairs(options) do
                local optBtn = InstanceHelper:Create("TextButton", {
                    Name = "Opt_" .. i,
                    Size = UDim2.new(1, -8, 0, 26),
                    Position = UDim2.new(0, 4, 0, 30 + ((i - 1) * 28)),
                    BackgroundColor3 = Color3.fromRGB(30, 30, 38),
                    Text = "  " .. opt,
                    TextColor3 = Config.UIText,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                }, frame)

                InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(0, 4)}, optBtn)

                optBtn.MouseButton1Click:Connect(function()
                    selectOption(i)
                    isOpen = false
                    frame.Size = UDim2.new(1, -8, 0, 32)
                    for _, child in ipairs(frame:GetChildren()) do
                        if child.Name:sub(1, 4) == "Opt_" then
                            child:Destroy()
                        end
                    end
                end)
            end
        else
            frame.Size = UDim2.new(1, -8, 0, 32)
            for _, child in ipairs(frame:GetChildren()) do
                if child.Name:sub(1, 4) == "Opt_" then
                    child:Destroy()
                end
            end
        end
    end)

    table.insert(tab.Elements, frame)
    return {Frame = frame, Select = selectOption}
end
-- ============================================================
-- GAME MODULE
-- Динамический резолвер ремоутов + игровые действия
-- ============================================================
local GameModule = {}
GameModule.__index = GameModule

GameModule._cache = {
    remotes = {},
    remoteCandidates = {},
    brainrotFolder = nil,
    baseFolder = nil,
    playerBase = nil,
    sellZone = nil,
    spawnMachine = nil,
    upgradePart = nil,
    rebirthPart = nil,
    eventFolder = nil,
    tsunamiFolder = nil,
    scanned = false,
}

local REMOTE_PATTERNS = {
    collect         = {"collect", "pickup", "grab", "take", "claim", "harvest"},
    place           = {"place", "deploy", "setdown", "putdown", "equip", "assign"},
    sell            = {"sell", "scrap", "cashout", "exchange"},
    upgradeSpeed    = {"upgradespeed", "speedupgrade", "buyspeed", "speedbuy", "up_speed"},
    upgradeCarry    = {"upgradecarry", "carryupgrade", "buycarry", "capacity", "upgrade_capacity"},
    upgradeBase     = {"upgradebase", "baseupgrade", "buybase", "upgrade_base"},
    upgradeBrainrot = {"upgradebrainrot", "levelup", "brainrotupgrade", "upgrade_brainrot", "level"},
    rebirth         = {"rebirth", "reborn", "prestige", "reset"},
    spawnMachine    = {"spawnmachine", "combine", "craft", "fuse", "merge", "spawn_machine"},
    eventJoin       = {"eventjoin", "joinevent", "enterevent", "event_enter"},
    eventClaim      = {"eventclaim", "claimreward", "eventreward", "claim_event"},
    tsunamiTrigger  = {"tsunami", "triggerwave", "summonwave", "wave"},
    steal           = {"steal", "rob", "takebrainrot"},
    getData         = {"getdata", "getplayerdata", "requestdata", "getstats", "getinfo"},
    buyItem         = {"buy", "purchase", "shop"},
    inventory       = {"inventory", "getinventory", "mybrainrots"},
    token           = {"token", "tokens", "coin", "coins", "cash", "money"},
    trade           = {"trade", "trading", "offertrade"},
    quest           = {"quest", "mission", "task"},
    index           = {"index", "collection", "discovered", "unlocked"},
}

local CATEGORY_PRIORITY = {
    "collect", "place", "sell", "upgradeSpeed", "upgradeCarry",
    "upgradeBase", "upgradeBrainrot", "rebirth", "spawnMachine",
    "eventJoin", "eventClaim", "tsunamiTrigger", "steal",
    "getData", "inventory", "buyItem", "token", "trade", "quest", "index",
}

local function normalizeName(name)
    if type(name) ~= "string" then return "" end
    return name:lower():gsub("[%s_%-%.]", "")
end

local function matchesPatterns(name, patterns)
    local norm = normalizeName(name)
    for _, pat in ipairs(patterns) do
        if norm:find(normalizeName(pat), 1, true) then
            return true, pat
        end
    end
    return false, nil
end

local function collectRemotes(container, depth, results)
    depth = depth or 0
    results = results or {}
    if depth > 4 then return results end
    if not container then return results end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            table.insert(results, child)
        elseif child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration") then
            collectRemotes(child, depth + 1, results)
        end
    end
    return results
end

function GameModule:ScanAllRemotes()
    local all = {}
    collectRemotes(ReplicatedStorage, 0, all)
    collectRemotes(Workspace, 0, all)
    collectRemotes(LocalPlayer, 0, all)

    if Executor.getnilinstances then
        local ok, nils = pcall(Executor.getnilinstances)
        if ok and type(nils) == "table" then
            for _, inst in ipairs(nils) do
                if inst and (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then
                    table.insert(all, inst)
                end
            end
        end
    end

    local seen, unique = {}, {}
    for _, r in ipairs(all) do
        if not seen[r] then
            seen[r] = true
            table.insert(unique, r)
        end
    end
    self._cache.remoteCandidates = unique
    Util:Log("ScanAllRemotes: найдено", #unique, "ремоутов")
    return unique
end

function GameModule:ResolveRemotes()
    if not self._cache.remoteCandidates or #self._cache.remoteCandidates == 0 then
        self:ScanAllRemotes()
    end

    local candidates = self._cache.remoteCandidates
    local resolved = {}

    for _, category in ipairs(CATEGORY_PRIORITY) do
        local patterns = REMOTE_PATTERNS[category]
        if patterns then
            for _, remote in ipairs(candidates) do
                local taken = false
                for _, r in pairs(resolved) do
                    if r == remote then taken = true; break end
                end
                if not taken then
                    local match, pat = matchesPatterns(remote.Name, patterns)
                    if match then
                        resolved[category] = remote
                        Util:Log("Resolved", category, "->", remote:GetFullName())
                        break
                    end
                end
            end
        end
    end

    self._cache.remotes = resolved
    return resolved
end

function GameModule:GetRemote(category)
    if not self._cache.remotes[category] then
        self:ResolveRemotes()
    end
    return self._cache.remotes[category]
end

function GameModule:FireRemote(category, ...)
    local remote = self:GetRemote(category)
    if not remote then
        Util:Warn("FireRemote: нет ремоута для", category)
        return false, "no_remote"
    end

    local args = table.pack(...)

    local ok, err = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end
    end)
    if not ok then
        Util:Warn("FireRemote", category, "ошибка:", err)
        return false, err
    end
    return true
end

function GameModule:FindBrainrotFolder()
    if self._cache.brainrotFolder and self._cache.brainrotFolder.Parent then
        return self._cache.brainrotFolder
    end
    for _, container in ipairs({Workspace, ReplicatedStorage}) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                local name = normalizeName(child.Name)
                if name:find("brainrot") or name:find("pet") or name:find("spawn") then
                    local hasBrainrots = false
                    for _, sub in ipairs(child:GetChildren()) do
                        if sub:IsA("Model") and (sub:FindFirstChildOfClass("Humanoid") or sub:GetAttribute("Rarity")) then
                            hasBrainrots = true
                            break
                        end
                    end
                    if hasBrainrots then
                        self._cache.brainrotFolder = child
                        return child
                    end
                end
            end
        end
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Model") and desc:GetAttribute("Rarity") then
            local parent = desc.Parent
            if parent and (parent:IsA("Folder") or parent:IsA("Model")) then
                self._cache.brainrotFolder = parent
                return parent
            end
        end
    end
    return nil
end

function GameModule:FindPlayerBase()
    if self._cache.playerBase and self._cache.playerBase.Parent then
        return self._cache.playerBase
    end
    local basesFolder = Workspace:FindFirstChild("Bases") or Workspace:FindFirstChild("Base")
    if basesFolder then
        local myBase = basesFolder:FindFirstChild(LocalPlayer.Name)
            or basesFolder:FindFirstChild(tostring(LocalPlayer.UserId))
        if myBase then
            self._cache.playerBase = myBase
            return myBase
        end
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("Folder") then
            local owner = desc:GetAttribute("Owner") or desc:GetAttribute("Player") or desc:GetAttribute("UserId")
            if owner == LocalPlayer.UserId or owner == LocalPlayer.Name then
                self._cache.playerBase = desc
                return desc
            end
        end
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("BasePart") and (desc.Name == LocalPlayer.Name or desc.Name == "Base") then
            local parent = desc.Parent
            if parent and (parent:IsA("Model") or parent:IsA("Folder")) then
                self._cache.playerBase = parent
                return parent
            end
        end
    end
    return nil
end

function GameModule:FindSellZone()
    if self._cache.sellZone and self._cache.sellZone.Parent then
        return self._cache.sellZone
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("BasePart") then
            local name = normalizeName(desc.Name)
            if name:find("sell") or name:find("scrap") or name:find("exchange") then
                self._cache.sellZone = desc
                return desc
            end
        end
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local action = normalizeName(desc.ActionText)
            if action:find("sell") or action:find("scrap") then
                self._cache.sellZone = desc.Parent
                return desc.Parent
            end
        end
    end
    return nil
end

function GameModule:FindSpawnMachine()
    if self._cache.spawnMachine and self._cache.spawnMachine.Parent then
        return self._cache.spawnMachine
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Model") then
            local name = normalizeName(desc.Name)
            if name:find("spawnmachine") or name:find("combine") or name:find("craft") or name:find("fuse") then
                self._cache.spawnMachine = desc
                return desc
            end
        end
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local action = normalizeName(desc.ActionText)
            if action:find("combine") or action:find("craft") or action:find("fuse") or action:find("merge") then
                self._cache.spawnMachine = desc.Parent
                return desc.Parent
            end
        end
    end
    return nil
end

function GameModule:FindEventFolder()
    if self._cache.eventFolder and self._cache.eventFolder.Parent then
        return self._cache.eventFolder
    end
    for _, container in ipairs({Workspace, ReplicatedStorage}) do
        for _, child in ipairs(container:GetChildren()) do
            local name = normalizeName(child.Name)
            if name:find("event") then
                self._cache.eventFolder = child
                return child
            end
        end
    end
    return nil
end

function GameModule:FindTsunamiFolder()
    if self._cache.tsunamiFolder and self._cache.tsunamiFolder.Parent then
        return self._cache.tsunamiFolder
    end
    for _, child in ipairs(Workspace:GetChildren()) do
        local name = normalizeName(child.Name)
        if name:find("tsunami") or name:find("wave") then
            self._cache.tsunamiFolder = child
            return child
        end
    end
    return nil
end

function GameModule:GetFreeBrainrots()
    local folder = self:FindBrainrotFolder()
    if not folder then return {} end
    local result = {}
    for _, child in ipairs(folder:GetDescendants()) do
        if child:IsA("Model") then
            local isPlaced = child:GetAttribute("Placed") or child:GetAttribute("Owner")
            if not isPlaced then
                local hrp = child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart
                if hrp then
                    table.insert(result, child)
                end
            end
        end
    end
    return result
end

function GameModule:GetPlacedBrainrots()
    local base = self:FindPlayerBase()
    if not base then return {} end
    local result = {}
    local slotsFolder = base:FindFirstChild("Slots") or base
    for _, child in ipairs(slotsFolder:GetDescendants()) do
        if child:IsA("Model") then
            local placed = child:GetAttribute("Placed") or child:GetAttribute("BrainrotId")
            if placed or child:FindFirstChildOfClass("Humanoid") then
                table.insert(result, child)
            end
        end
    end
    return result
end

function GameModule:GetBestInventoryBrainrot()
    local ok, data = self:FireRemote("inventory")
    if ok and type(data) == "table" then
        local best, bestVal = nil, -math.huge
        for _, item in ipairs(data) do
            local val = item.Value or item.Rarity or item.Income or 0
            if type(val) == "number" and val > bestVal then
                bestVal = val
                best = item
            end
        end
        return best
    end
    local invFolder = LocalPlayer:FindFirstChild("Inventory") or LocalPlayer:FindFirstChild("Brainrots")
    if invFolder then
        local best, bestVal = nil, -math.huge
        for _, item in ipairs(invFolder:GetChildren()) do
            local val = item:GetAttribute("Value") or item:GetAttribute("Rarity") or 0
            if type(val) == "number" and val > bestVal then
                bestVal = val
                best = item
            end
        end
        return best
    end
    return nil
end

function GameModule:GetClosestFreeBrainrot()
    local myHRP = Util:GetHRP()
    if not myHRP then return nil, math.huge end
    local best, bestDist = nil, math.huge
    for _, brainrot in ipairs(self:GetFreeBrainrots()) do
        local hrp = brainrot:FindFirstChild("HumanoidRootPart") or brainrot.PrimaryPart
        if hrp then
            local dist = (myHRP.Position - hrp.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                best = brainrot
            end
        end
    end
    return best, bestDist
end

function GameModule:CollectBrainrot(brainrot)
    if not brainrot then return false end
    local prompt = brainrot:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = brainrot:FindFirstChild("ProximityPrompt", true)
    end
    if prompt then
        local myHRP = Util:GetHRP()
        local targetHRP = brainrot:FindFirstChild("HumanoidRootPart") or brainrot.PrimaryPart
        if myHRP and targetHRP then
            local dist = (myHRP.Position - targetHRP.Position).Magnitude
            if dist > 8 then
                myHRP.CFrame = CFrame.new(targetHRP.Position + Vector3.new(0, 3, 0))
                task.wait(0.1)
            end
        end
        Util:FireProximityPrompt(prompt)
        return true
    end
    local ok = self:FireRemote("collect", brainrot)
    if ok then return true end
    local myHRP = Util:GetHRP()
    if myHRP then
        Util:FireTouchInterest(myHRP, brainrot, true)
        task.wait(0.05)
        Util:FireTouchInterest(myHRP, brainrot, false)
        return true
    end
    return false
end

function GameModule:PlaceBrainrot(brainrot, slotIndex)
    slotIndex = slotIndex or 1
    local ok = self:FireRemote("place", brainrot, slotIndex)
    if ok then return true end
    local base = self:FindPlayerBase()
    if base then
        local slot = base:FindFirstChild("Slot" .. slotIndex) or base:FindFirstChild("Slot" .. slotIndex .. "Prompt")
        if slot then
            local prompt = slot:FindFirstChildOfClass("ProximityPrompt") or slot:FindFirstChild("ProximityPrompt", true)
            if prompt then
                Util:FireProximityPrompt(prompt)
                return true
            end
        end
    end
    if base then
        for _, child in ipairs(base:GetDescendants()) do
            if child:IsA("BasePart") and child.Name:lower():find("slot") then
                Util:FireTouchInterest(Util:GetHRP(), child, true)
                task.wait(0.05)
                Util:FireTouchInterest(Util:GetHRP(), child, false)
                return true
            end
        end
    end
    return false
end

function GameModule:SellBrainrot(brainrot)
    local ok = self:FireRemote("sell", brainrot)
    if ok then return true end
    local sellZone = self:FindSellZone()
    if sellZone then
        local prompt = sellZone:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            Util:FireProximityPrompt(prompt)
            return true
        end
    end
    if sellZone then
        Util:FireTouchInterest(Util:GetHRP(), sellZone, true)
        task.wait(0.05)
        Util:FireTouchInterest(Util:GetHRP(), sellZone, false)
        return true
    end
    return false
end

function GameModule:UpgradeSpeed()  return self:FireRemote("upgradeSpeed") end
function GameModule:UpgradeCarry()  return self:FireRemote("upgradeCarry") end
function GameModule:UpgradeBase()   return self:FireRemote("upgradeBase") end
function GameModule:UpgradeBrainrot(brainrot) return self:FireRemote("upgradeBrainrot", brainrot) end
function GameModule:Rebirth()       return self:FireRemote("rebirth") end

function GameModule:UseSpawnMachine(a, b, c)
    local ok = self:FireRemote("spawnMachine", a, b, c)
    if ok then return true end
    local machine = self:FindSpawnMachine()
    if machine then
        local prompt = machine:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            Util:FireProximityPrompt(prompt)
            return true
        end
    end
    return false
end

function GameModule:JoinEvent(eventName) return self:FireRemote("eventJoin", eventName) end
function GameModule:ClaimEventReward()   return self:FireRemote("eventClaim") end
function GameModule:TriggerTsunami(t)    return self:FireRemote("tsunamiTrigger", t) end

function GameModule:GetPlayerStats()
    local stats = {
        money = 0, speed = 16, carryCapacity = 1,
        rebirths = 0, tokens = 0, baseLevel = 1,
    }
    local ok, data = self:FireRemote("getData")
    if ok and type(data) == "table" then
        stats.money = data.Money or data.Cash or data.Coins or data.money or 0
        stats.speed = data.Speed or data.speed or 16
        stats.carryCapacity = data.CarryCapacity or data.Capacity or 1
        stats.rebirths = data.Rebirths or data.Rebirth or 0
        stats.tokens = data.Tokens or data.Token or 0
        stats.baseLevel = data.BaseLevel or data.Base or 1
        return stats
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, stat in ipairs(ls:GetChildren()) do
            local name = normalizeName(stat.Name)
            if name:find("money") or name:find("cash") or name:find("coin") then
                stats.money = stat.Value
            elseif name:find("token") then
                stats.tokens = stat.Value
            elseif name:find("rebirth") then
                stats.rebirths = stat.Value
            end
        end
    end
    for _, attr in ipairs({"Money", "Cash", "Coins", "Speed", "Rebirths", "Tokens", "BaseLevel"}) do
        local val = LocalPlayer:GetAttribute(attr)
        if val ~= nil then
            local key = attr:lower()
            if key == "money" or key == "cash" or key == "coins" then stats.money = val end
            if key == "speed" then stats.speed = val end
            if key == "rebirths" then stats.rebirths = val end
            if key == "tokens" then stats.tokens = val end
            if key == "baselevel" then stats.baseLevel = val end
        end
    end
    local hum = Util:GetHum()
    if hum and hum.WalkSpeed then
        stats.speed = math.max(stats.speed, hum.WalkSpeed)
    end
    return stats
end

function GameModule:GetActiveTsunami()
    local folder = self:FindTsunamiFolder()
    if not folder then return nil end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            local active = child:GetAttribute("Active")
            if active == nil or active == true then
                return child
            end
        end
    end
    return nil
end

function GameModule:IsTsunamiActive()
    return self:GetActiveTsunami() ~= nil
end

function GameModule:GetSafeZone()
    local safeFolder = Workspace:FindFirstChild("SafeZones") or Workspace:FindFirstChild("SafeZone")
    if safeFolder then
        local myHRP = Util:GetHRP()
        if myHRP then
            local closest, bestDist = nil, math.huge
            for _, child in ipairs(safeFolder:GetDescendants()) do
                if child:IsA("BasePart") then
                    local dist = (myHRP.Position - child.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        closest = child
                    end
                end
            end
            if closest then return closest end
        end
    end
    return self:FindPlayerBase()
end

function GameModule:DumpRemotes()
    self:ScanAllRemotes()
    print("========== ETFB REMOTE DUMP ==========")
    print("Всего ремоутов:", #self._cache.remoteCandidates)
    for i, remote in ipairs(self._cache.remoteCandidates) do
        print(string.format("[%d] %s | %s", i, remote.ClassName, remote:GetFullName()))
    end
    print("========== RESOLVED ==========")
    for category, remote in pairs(self._cache.remotes) do
        print(category .. " -> " .. remote:GetFullName())
    end
    print("=====================================")
end

function GameModule:DumpObjects()
    print("========== ETFB OBJECT DUMP ==========")
    local bf = self:FindBrainrotFolder()
    print("BrainrotFolder:", bf and bf:GetFullName() or "НЕ НАЙДЕНА")
    if bf then print("  Свободных брейнротов:", #self:GetFreeBrainrots()) end
    local base = self:FindPlayerBase()
    print("PlayerBase:", base and base:GetFullName() or "НЕ НАЙДЕНА")
    if base then print("  Размещённых брейнротов:", #self:GetPlacedBrainrots()) end
    local sell = self:FindSellZone()
    print("SellZone:", sell and sell:GetFullName() or "НЕ НАЙДЕНА")
    local sm = self:FindSpawnMachine()
    print("SpawnMachine:", sm and sm:GetFullName() or "НЕ НАЙДЕН")
    local ef = self:FindEventFolder()
    print("EventFolder:", ef and ef:GetFullName() or "НЕ НАЙДЕНА")
    local tf = self:FindTsunamiFolder()
    print("TsunamiFolder:", tf and tf:GetFullName() or "НЕ НАЙДЕНА")
    local stats = self:GetPlayerStats()
    print("Stats:")
    for k, v in pairs(stats) do print("  " .. k .. " = " .. tostring(v)) end
    print("======================================")
end

function GameModule:Init()
    if self._cache.scanned then return end
    Util:Log("GameModule:Init — сканирую...")
    self:ScanAllRemotes()
    self:ResolveRemotes()
    self:FindBrainrotFolder()
    self:FindPlayerBase()
    self:FindSellZone()
    self:FindSpawnMachine()
    self:FindEventFolder()
    self:FindTsunamiFolder()
    self._cache.scanned = true
    Util:Log("GameModule:Init завершён")
end

function GameModule:Reset()
    self._cache = {
        remotes = {}, remoteCandidates = {},
        brainrotFolder = nil, baseFolder = nil, playerBase = nil,
        sellZone = nil, spawnMachine = nil, upgradePart = nil,
        rebirthPart = nil, eventFolder = nil, tsunamiFolder = nil,
        scanned = false,
    }
end
-- ============================================================
-- BRAINROT DATABASE
-- Полная база брейнротов ETFB: редкость, доход, методы получения
-- Источники: GameRant, Eldorado, GameTweak, GameAnomaly, AllThingsHow
-- Обновлено: 2026-03
-- ============================================================
local BrainrotDB = {}
BrainrotDB.__index = BrainrotDB

-- ============================================================
-- RARITY DEFINITIONS
-- ============================================================
-- Порядок от низшей к высшей. Tier используется для сортировки.
BrainrotDB.Rarities = {
    {Name = "Common",    Tier = 1,  IncomeMin = 2,       IncomeMax = 15,      Color = Color3.fromRGB(180, 180, 180), ZoneSpeed = 0},
    {Name = "Uncommon",  Tier = 2,  IncomeMin = 20,      IncomeMax = 120,     Color = Color3.fromRGB(100, 200, 100), ZoneSpeed = 25},
    {Name = "Rare",      Tier = 3,  IncomeMin = 100,     IncomeMax = 275,     Color = Color3.fromRGB(80, 140, 255),  ZoneSpeed = 40},
    {Name = "Epic",      Tier = 4,  IncomeMin = 290,     IncomeMax = 1400,    Color = Color3.fromRGB(170, 80, 255),  ZoneSpeed = 60},
    {Name = "Legendary", Tier = 5,  IncomeMin = 1500,    IncomeMax = 5000,    Color = Color3.fromRGB(255, 200, 0),   ZoneSpeed = 80},
    {Name = "Mythical",  Tier = 6,  IncomeMin = 6000,    IncomeMax = 25250,   Color = Color3.fromRGB(255, 100, 50),  ZoneSpeed = 100},
    {Name = "Cosmic",    Tier = 7,  IncomeMin = 22000,   IncomeMax = 240000,  Color = Color3.fromRGB(140, 0, 200),   ZoneSpeed = 120},
    {Name = "Secret",    Tier = 8,  IncomeMin = 200000,  IncomeMax = 6450000, Color = Color3.fromRGB(0, 0, 0),       ZoneSpeed = 140},
    {Name = "Celestial", Tier = 9,  IncomeMin = 2000000, IncomeMax = 15250000,Color = Color3.fromRGB(0, 200, 255),   ZoneSpeed = 300},
    {Name = "Divine",    Tier = 10, IncomeMin = 30000000,IncomeMax = 92500000,Color = Color3.fromRGB(255, 215, 0),   ZoneSpeed = 0},
    {Name = "Infinity",  Tier = 11, IncomeMin = 250000000,IncomeMax = 625000000,Color = Color3.fromRGB(255, 0, 100),  ZoneSpeed = 0},
    {Name = "Paradox",   Tier = 12, IncomeMin = 1500000000,IncomeMax = 1500000000,Color = Color3.fromRGB(100, 0, 255),ZoneSpeed = 0},
    {Name = "Eternal",   Tier = 13, IncomeMin = 9999999999,IncomeMax = 9999999999,Color = Color3.fromRGB(255, 255, 255),ZoneSpeed = 0},
}

BrainrotDB.RarityMap = {}
for _, r in ipairs(BrainrotDB.Rarities) do
    BrainrotDB.RarityMap[r.Name] = r
end

-- ============================================================
-- BRAINROT DATABASE (полный список)
-- Поля:
--   Name       — имя брейнрота
--   Rarity     — редкость (строка)
--   Income     — базовый доход/сек на Level 1
--   Source     — как получить (track / luckyblock / spawnmachine / event / dice)
--   Notes      — примечания
-- ============================================================
BrainrotDB.Data = {

    -- ==========================================================
    -- COMMON ($2/s - $15/s)
    -- ==========================================================
    {Name = "Noobini Cakenini",     Rarity = "Common", Income = 2,   Source = "track", Notes = "Стартовый"},
    {Name = "Lirili Larila",        Rarity = "Common", Income = 4,   Source = "track", Notes = ""},
    {Name = "Tim Cheese",           Rarity = "Common", Income = 6,   Source = "track", Notes = ""},
    {Name = "Tralalero Tralala",    Rarity = "Common", Income = 8,   Source = "track", Notes = "Классика"},
    {Name = "Bombardiro Crocodilo", Rarity = "Common", Income = 10,  Source = "track", Notes = ""},
    {Name = "Tung Tung Tung Sahur", Rarity = "Common", Income = 12,  Source = "track", Notes = ""},
    {Name = "Brr Brr Patapim",      Rarity = "Common", Income = 15,  Source = "track", Notes = "Топ Common"},

    -- ==========================================================
    -- UNCOMMON ($20/s - $120/s)
    -- ==========================================================
    {Name = "Boneca Ambalabu",      Rarity = "Uncommon", Income = 20,  Source = "track", Notes = ""},
    {Name = "Frigo Camelo",         Rarity = "Uncommon", Income = 25,  Source = "track", Notes = ""},
    {Name = "Orangutini Ananassini",Rarity = "Uncommon", Income = 30,  Source = "track", Notes = ""},
    {Name = "Rhino Toasterino",     Rarity = "Uncommon", Income = 35,  Source = "track", Notes = ""},
    {Name = "Spioniro Golubiro",    Rarity = "Uncommon", Income = 40,  Source = "track", Notes = ""},
    {Name = "Bombombini Gusini",    Rarity = "Uncommon", Income = 45,  Source = "track", Notes = ""},
    {Name = "Zibra Zubra Zibralini",Rarity = "Uncommon", Income = 50,  Source = "track", Notes = ""},
    {Name = "Tigrilini Watermelini",Rarity = "Uncommon", Income = 55,  Source = "track", Notes = ""},
    {Name = "Cavallo Virtuoso",     Rarity = "Uncommon", Income = 60,  Source = "track", Notes = ""},
    {Name = "Gorillo Watermelondrillo",Rarity = "Uncommon", Income = 70,Source = "track",Notes = ""},
    {Name = "Avocadorilla",         Rarity = "Uncommon", Income = 90,  Source = "track", Notes = ""},
    {Name = "Guesto Angelic",       Rarity = "Uncommon", Income = 120, Source = "track", Notes = "Топ Uncommon"},

    -- ==========================================================
    -- RARE ($100/s - $275/s)
    -- ==========================================================
    {Name = "Trippi Troppi",        Rarity = "Rare", Income = 100, Source = "track", Notes = ""},
    {Name = "Giraffa Celeste",      Rarity = "Rare", Income = 120, Source = "track", Notes = ""},
    {Name = "Cocofanto Elefanto",   Rarity = "Rare", Income = 140, Source = "track", Notes = ""},
    {Name = "Tralalero Tralala Gold",Rarity = "Rare",Income = 160, Source = "track", Notes = ""},
    {Name = "Udin Din Din Dun",     Rarity = "Rare", Income = 180, Source = "track", Notes = ""},
    {Name = "Trenostruzzo Turbo 3000",Rarity = "Rare",Income = 200,Source = "track", Notes = ""},
    {Name = "Los Crocodillitos",    Rarity = "Rare", Income = 220, Source = "track", Notes = ""},
    {Name = "Tigroligre Frutonni",  Rarity = "Rare", Income = 250, Source = "track", Notes = ""},
    {Name = "Orcalero Orcala",      Rarity = "Rare", Income = 275, Source = "track", Notes = "Топ Rare"},

    -- ==========================================================
    -- EPIC ($290/s - $1.4K/s)
    -- ==========================================================
    {Name = "Piccione Macchina",    Rarity = "Epic", Income = 290,  Source = "track", Notes = ""},
    {Name = "Tukanno Bananno",      Rarity = "Epic", Income = 350,  Source = "track", Notes = ""},
    {Name = "Ballerino Lololo",     Rarity = "Epic", Income = 400,  Source = "track", Notes = ""},
    {Name = "La Vacca Saturno Saturnita",Rarity = "Epic",Income = 500,Source = "track",Notes = ""},
    {Name = "Torrtuginni Dragonfrutini",Rarity = "Epic",Income = 600,Source = "track",Notes = ""},
    {Name = "Los Tralaleritos",     Rarity = "Epic", Income = 700,  Source = "track", Notes = ""},
    {Name = "Las Tralaleritas",     Rarity = "Epic", Income = 800,  Source = "track", Notes = ""},
    {Name = "Las Vaquitas Saturnitas",Rarity = "Epic",Income = 900, Source = "track", Notes = ""},
    {Name = "Graipuss Medussi",     Rarity = "Epic", Income = 1000, Source = "track", Notes = ""},
    {Name = "Pot Hotspot",          Rarity = "Epic", Income = 1100, Source = "track", Notes = ""},
    {Name = "Chicleteira Bicicleteira",Rarity = "Epic",Income = 1200,Source = "track", Notes = ""},
    {Name = "La Grande Combinasion",Rarity = "Epic", Income = 1400, Source = "track", Notes = "Топ Epic"},

    -- ==========================================================
    -- LEGENDARY ($1.5K/s - $5K/s)
    -- ==========================================================
    {Name = "Nuclearo Dinossauro",  Rarity = "Legendary", Income = 1500, Source = "track", Notes = ""},
    {Name = "Garama and Madundung", Rarity = "Legendary", Income = 1700, Source = "track", Notes = ""},
    {Name = "Dragon Cannelloni",    Rarity = "Legendary", Income = 1900, Source = "track", Notes = ""},
    {Name = "Agarrini la Palini",   Rarity = "Legendary", Income = 2100, Source = "track", Notes = ""},
    {Name = "Chimpanzini Spiderini",Rarity = "Legendary", Income = 2300, Source = "track", Notes = ""},
    {Name = "Matteo",               Rarity = "Legendary", Income = 2500, Source = "track", Notes = ""},
    {Name = "Gattatino Neonino",    Rarity = "Legendary", Income = 2700, Source = "track", Notes = ""},
    {Name = "Statutino Libertino",  Rarity = "Legendary", Income = 2900, Source = "track", Notes = ""},
    {Name = "Unclito Samito",       Rarity = "Legendary", Income = 3200, Source = "track", Notes = ""},
    {Name = "Gattatino Nyanino",    Rarity = "Legendary", Income = 3500, Source = "track", Notes = ""},
    {Name = "Espresso Signora",     Rarity = "Legendary", Income = 4000, Source = "track", Notes = ""},
    {Name = "Los Tungtungtungcitos",Rarity = "Legendary", Income = 4500, Source = "track", Notes = ""},
    {Name = "Aura Farma",           Rarity = "Legendary", Income = 5000, Source = "track", Notes = "Топ Legendary"},

    -- ==========================================================
    -- MYTHICAL ($6K/s - $25.25K/s)
    -- ==========================================================
    {Name = "Cocofanto Elefanto Mythic", Rarity = "Mythical", Income = 6000,  Source = "track", Notes = ""},
    {Name = "Giraffa Celeste Mythic",    Rarity = "Mythical", Income = 7000,  Source = "track", Notes = ""},
    {Name = "Tralalero Tralala Mythic",  Rarity = "Mythical", Income = 8000,  Source = "track", Notes = ""},
    {Name = "Los Crocodillitos Mythic",  Rarity = "Mythical", Income = 9000,  Source = "track", Notes = ""},
    {Name = "Tigroligre Frutonni Mythic",Rarity = "Mythical", Income = 10000, Source = "track", Notes = ""},
    {Name = "Udin Din Din Dun Mythic",   Rarity = "Mythical", Income = 11000, Source = "track", Notes = ""},
    {Name = "Trenostruzzo Turbo 3000 Mythic",Rarity = "Mythical",Income = 13000,Source = "track",Notes = ""},
    {Name = "Trippi Troppi Troppa Trippa",Rarity = "Mythical",Income = 15000, Source = "track", Notes = ""},
    {Name = "Orcalero Orcala Mythic",    Rarity = "Mythical", Income = 18000, Source = "track", Notes = ""},
    {Name = "Piccione Macchina Mythic",  Rarity = "Mythical", Income = 19000, Source = "track", Notes = ""},
    {Name = "Tukanno Bananno Mythic",    Rarity = "Mythical", Income = 21000, Source = "track", Notes = ""},
    {Name = "Ballerino Lololo Mythic",   Rarity = "Mythical", Income = 25250, Source = "track", Notes = "Топ Mythical"},

    -- ==========================================================
    -- COSMIC ($22K/s - $240K/s)
    -- ==========================================================
    {Name = "La Vacca Saturno Saturnita Cosmic", Rarity = "Cosmic", Income = 22000, Source = "track", Notes = ""},
    {Name = "Torrtuginni Dragonfrutini Cosmic",  Rarity = "Cosmic", Income = 30000, Source = "track", Notes = ""},
    {Name = "Los Tralaleritos Cosmic",           Rarity = "Cosmic", Income = 48000, Source = "track", Notes = ""},
    {Name = "Las Tralaleritas Cosmic",           Rarity = "Cosmic", Income = 50000, Source = "track", Notes = ""},
    {Name = "Las Vaquitas Saturnitas Cosmic",    Rarity = "Cosmic", Income = 60000, Source = "track", Notes = ""},
    {Name = "Graipuss Medussi Cosmic",           Rarity = "Cosmic", Income = 70000, Source = "track", Notes = ""},
    {Name = "Pot Hotspot Cosmic",                Rarity = "Cosmic", Income = 80000, Source = "track", Notes = ""},
    {Name = "Chicleteira Bicicleteira Cosmic",   Rarity = "Cosmic", Income = 90000, Source = "track", Notes = ""},
    {Name = "La Grande Combinasion Cosmic",      Rarity = "Cosmic", Income = 100000, Source = "track", Notes = ""},
    {Name = "Nuclearo Dinossauro Cosmic",        Rarity = "Cosmic", Income = 110000, Source = "track", Notes = ""},
    {Name = "Garama and Madundung Cosmic",       Rarity = "Cosmic", Income = 120000, Source = "track", Notes = ""},
    {Name = "Dragon Cannelloni Cosmic",          Rarity = "Cosmic", Income = 130000, Source = "track", Notes = ""},
    {Name = "Agarrini la Palini Cosmic",         Rarity = "Cosmic", Income = 150000, Source = "track", Notes = ""},
    {Name = "Chimpanzini Spiderini Cosmic",      Rarity = "Cosmic", Income = 170000, Source = "track", Notes = "Топ Cosmic"},

    -- ==========================================================
    -- SECRET ($200K/s - $6.45M/s)
    -- ==========================================================
    {Name = "Matteo Secret",          Rarity = "Secret", Income = 200000, Source = "track", Notes = ""},
    {Name = "Gattatino Neonino Secret",Rarity = "Secret", Income = 250000, Source = "track", Notes = ""},
    {Name = "Statutino Libertino Secret",Rarity = "Secret",Income = 300000,Source = "track", Notes = ""},
    {Name = "Unclito Samito Secret",  Rarity = "Secret", Income = 350000, Source = "track", Notes = ""},
    {Name = "Gattatino Nyanino Secret",Rarity = "Secret",Income = 400000, Source = "track", Notes = ""},
    {Name = "Espresso Signora Secret",Rarity = "Secret", Income = 450000, Source = "track", Notes = ""},
    {Name = "Los Tungtungtungcitos Secret",Rarity = "Secret",Income = 500000,Source = "track",Notes = ""},
    {Name = "Aura Farma Secret",      Rarity = "Secret", Income = 700000, Source = "track", Notes = ""},
    {Name = "Rainbow 67",             Rarity = "Secret", Income = 800000, Source = "track", Notes = ""},
    {Name = "Fragola La La La",       Rarity = "Secret", Income = 1000000,Source = "track", Notes = "Топ Secret (трек)"},
    {Name = "Secret Farmer",          Rarity = "Secret", Income = 1000000,Source = "track", Notes = ""},
    {Name = "Cosmic Mutant",          Rarity = "Secret", Income = 950000, Source = "luckyblock", Notes = ""},
    {Name = "Hidden Goat",            Rarity = "Secret", Income = 900000, Source = "luckyblock", Notes = ""},
    {Name = "Shadow Brainrot",        Rarity = "Secret", Income = 850000, Source = "luckyblock", Notes = ""},
    {Name = "Mystery Box",            Rarity = "Secret", Income = 800000, Source = "luckyblock", Notes = ""},
    {Name = "Secret Agent",           Rarity = "Secret", Income = 750000, Source = "luckyblock", Notes = ""},
    {Name = "Galaxy Brain",           Rarity = "Secret", Income = 800000, Source = "luckyblock", Notes = ""},
    {Name = "Star Collector",         Rarity = "Secret", Income = 750000, Source = "luckyblock", Notes = ""},
    {Name = "Nebula Rot",             Rarity = "Secret", Income = 700000, Source = "luckyblock", Notes = ""},
    {Name = "Cosmic Goat",            Rarity = "Secret", Income = 650000, Source = "luckyblock", Notes = ""},
    {Name = "Space Walker",           Rarity = "Secret", Income = 600000, Source = "luckyblock", Notes = ""},
    {Name = "Void Dweller",           Rarity = "Secret", Income = 550000, Source = "luckyblock", Notes = ""},

    -- ==========================================================
    -- CELESTIAL ($2M/s - $15.25M/s)
    -- ==========================================================
    {Name = "Job Job Sahur",          Rarity = "Celestial", Income = 1500000, Source = "track", Notes = ""},
    {Name = "Dug Dug Dug",            Rarity = "Celestial", Income = 1600000, Source = "track", Notes = ""},
    {Name = "Bisonte Gupitere",       Rarity = "Celestial", Income = 1700000, Source = "track", Notes = ""},
    {Name = "Alessio",                Rarity = "Celestial", Income = 1800000, Source = "track", Notes = ""},
    {Name = "Esok Sekolah",           Rarity = "Celestial", Income = 1900000, Source = "track", Notes = "Топ Celestial (трек)"},
    {Name = "Celestial Architect",    Rarity = "Celestial", Income = 1900000, Source = "event", Notes = "Event spawn only"},
    {Name = "Strawberry Elephant",    Rarity = "Celestial", Income = 1600000, Source = "event", Notes = "Admin Abuse exclusive"},
    {Name = "Dug Dug Dug Gold",       Rarity = "Celestial", Income = 15250000,Source = "luckyblock", Notes = "Максимальный Celestial"},
    {Name = "Esok Sekolah Gold",      Rarity = "Celestial", Income = 15000000,Source = "luckyblock", Notes = ""},
    {Name = "Alessio Gold",           Rarity = "Celestial", Income = 14500000,Source = "luckyblock", Notes = ""},
    {Name = "Bisonte Gupitere Gold",  Rarity = "Celestial", Income = 14000000,Source = "luckyblock", Notes = ""},
    {Name = "Job Job Sahur Gold",     Rarity = "Celestial", Income = 13500000,Source = "luckyblock", Notes = ""},
    {Name = "Celestial King",         Rarity = "Celestial", Income = 13000000,Source = "luckyblock", Notes = ""},
    {Name = "Celestial Queen",        Rarity = "Celestial", Income = 12500000,Source = "luckyblock", Notes = ""},
    {Name = "Celestial Dragon",       Rarity = "Celestial", Income = 12000000,Source = "luckyblock", Notes = ""},

    -- ==========================================================
    -- DIVINE ($30M/s - $92.5M/s)
    -- ==========================================================
    {Name = "Strawberry Elephant Divine",Rarity = "Divine", Income = 30000000, Source = "event", Notes = ""},
    {Name = "Grappellino D'Oro",         Rarity = "Divine", Income = 48500000, Source = "event", Notes = ""},
    {Name = "Martino",                   Rarity = "Divine", Income = 50000000, Source = "event", Notes = ""},
    {Name = "Din Din Vaultero",          Rarity = "Divine", Income = 55000000, Source = "event", Notes = ""},
    {Name = "Glacierello Infernetti",    Rarity = "Divine", Income = 60000000, Source = "event", Notes = ""},
    {Name = "Cornettino Fuaco",          Rarity = "Divine", Income = 72500000, Source = "event", Notes = ""},
    {Name = "Biscotti Macarotti",        Rarity = "Divine", Income = 75000000, Source = "event", Notes = ""},
    {Name = "Burrascano Spettro Marinaro",Rarity = "Divine",Income = 75000000, Source = "event", Notes = ""},
    {Name = "Pastapot Infernetto",       Rarity = "Divine", Income = 82500000, Source = "event", Notes = ""},
    {Name = "Rubichetto Cubini",         Rarity = "Divine", Income = 88800000, Source = "event", Notes = ""},
    {Name = "Galactio Fantasma",         Rarity = "Divine", Income = 88800000, Source = "event", Notes = ""},
    {Name = "Freezeti Cobretti",         Rarity = "Divine", Income = 90000000, Source = "event", Notes = ""},
    {Name = "Biscottino Scheletrino",    Rarity = "Divine", Income = 90000000, Source = "event", Notes = ""},
    {Name = "Cupitron Consoletron",      Rarity = "Divine", Income = 92500000, Source = "event", Notes = "Топ Divine"},
    {Name = "Draculini Meowlini",        Rarity = "Divine", Income = 95000000, Source = "event", Notes = ""},
    {Name = "Crostina Gelifio",          Rarity = "Divine", Income = 102490000,Source = "event", Notes = ""},
    {Name = "Dutchmello Velerino",       Rarity = "Divine", Income = 105000000,Source = "event", Notes = ""},

    -- ==========================================================
    -- INFINITY ($250M/s - $625M/s)
    -- ==========================================================
    {Name = "Noobini Infeeny",           Rarity = "Infinity", Income = 250000000, Source = "luckyblock", Notes = ""},
    {Name = "Anububu",                   Rarity = "Infinity", Income = 375000000, Source = "luckyblock", Notes = ""},
    {Name = "Magmew",                    Rarity = "Infinity", Income = 750000000, Source = "luckyblock", Notes = ""},
    {Name = "Doomini Tiktookini",        Rarity = "Infinity", Income = 800000000, Source = "luckyblock", Notes = ""},
    {Name = "Meta Technetta",            Rarity = "Infinity", Income = 875000000, Source = "luckyblock", Notes = "Топ Infinity"},
    {Name = "Infinity King",             Rarity = "Infinity", Income = 625000000, Source = "luckyblock", Notes = ""},
    {Name = "Infinity Queen",            Rarity = "Infinity", Income = 600000000, Source = "luckyblock", Notes = ""},

    -- ==========================================================
    -- PARADOX ($1.5B/s — все одинаково)
    -- ==========================================================
    {Name = "Happini Sadini",            Rarity = "Paradox", Income = 1500000000, Source = "event", Notes = "Paradox Ritual"},
    {Name = "Panicini Bloomini",         Rarity = "Paradox", Income = 1500000000, Source = "event", Notes = "Paradox Ritual"},
    {Name = "Derpolini Strictorini",     Rarity = "Paradox", Income = 1500000000, Source = "event", Notes = "Paradox Ritual"},
    {Name = "Fortunini Sfortunetti",     Rarity = "Paradox", Income = 1500000000, Source = "event", Notes = "Paradox Ritual"},
    {Name = "Warini Tranquilini",        Rarity = "Paradox", Income = 1500000000, Source = "event", Notes = "Paradox Ritual"},

    -- ==========================================================
    -- ETERNAL (данные неполные — RNG plaza, dice rolls)
    -- ==========================================================
    {Name = "Eternal Unknown",           Rarity = "Eternal", Income = 9999999999, Source = "dice", Notes = "RNG plaza, требует удачи"},
}

-- Индекс по имени (для быстрого поиска)
BrainrotDB.ByName = {}
for _, b in ipairs(BrainrotDB.Data) do
    BrainrotDB.ByName[b.Name:lower()] = b
end

-- ============================================================
-- МЕТОДЫ ПОИСКА И ФИЛЬТРАЦИИ
-- ============================================================

-- Получить брейнрот по имени (регистронезависимо)
function BrainrotDB:Get(name)
    if not name then return nil end
    return self.ByName[name:lower()]
end

-- Получить все брейнроты указанной редкости
function BrainrotDB:GetByRarity(rarity)
    local result = {}
    for _, b in ipairs(self.Data) do
        if b.Rarity == rarity then
            table.insert(result, b)
        end
    end
    return result
end

-- Получить все брейнроты с доходом >= minIncome
function BrainrotDB:GetByMinIncome(minIncome)
    local result = {}
    for _, b in ipairs(self.Data) do
        if b.Income >= minIncome then
            table.insert(result, b)
        end
    end
    table.sort(result, function(a, b) return a.Income > b.Income end)
    return result
end

-- Получить топ-N брейнротов по доходу
function BrainrotDB:GetTop(n)
    n = n or 10
    local sorted = {}
    for _, b in ipairs(self.Data) do
        table.insert(sorted, b)
    end
    table.sort(sorted, function(a, b)
        if a.Income == b.Income then
            return (self.RarityMap[a.Rarity] and self.RarityMap[a.Rarity].Tier or 0)
                 > (self.RarityMap[b.Rarity] and self.RarityMap[b.Rarity].Tier or 0)
        end
        return a.Income > b.Income
    end)
    local result = {}
    for i = 1, math.min(n, #sorted) do
        table.insert(result, sorted[i])
    end
    return result
end

-- Получить все брейнроты, которые можно получить указанным способом
function BrainrotDB:GetBySource(source)
    local result = {}
    for _, b in ipairs(self.Data) do
        if b.Source == source then
            table.insert(result, b)
        end
    end
    return result
end

-- Получить "путь фарма": список редкостей, отсортированных по тиру,
-- которые нужно собирать на текущем уровне
function BrainrotDB:GetFarmPath(currentSpeed)
    currentSpeed = currentSpeed or 0
    local path = {}
    for _, r in ipairs(self.Rarities) do
        if r.ZoneSpeed <= currentSpeed and r.ZoneSpeed > 0 then
            table.insert(path, r.Name)
        end
    end
    -- Всегда добавляем Common (ZoneSpeed = 0)
    table.insert(path, 1, "Common")
    return path
end

-- Получить рекомендуемую редкость для текущей скорости
function BrainrotDB:GetRecommendedRarity(currentSpeed)
    local best = "Common"
    local bestTier = 0
    for _, r in ipairs(self.Rarities) do
        if r.ZoneSpeed <= currentSpeed and r.Tier > bestTier and r.ZoneSpeed > 0 then
            best = r.Name
            bestTier = r.Tier
        end
    end
    return best
end

-- Проверить: является ли брейнрот "ценным" (доход выше порога)
function BrainrotDB:IsValuable(name, threshold)
    threshold = threshold or 1000000
    local b = self:Get(name)
    if not b then return false end
    return b.Income >= threshold
end

-- Получить цвет редкости
function BrainrotDB:GetRarityColor(rarity)
    local r = self.RarityMap[rarity]
    return r and r.Color or Color3.fromRGB(255, 255, 255)
end

-- Получить тир редкости (число)
function BrainrotDB:GetRarityTier(rarity)
    local r = self.RarityMap[rarity]
    return r and r.Tier or 0
end

-- Сравнить два брейнрота по ценности (1 = a > b, -1 = a < b, 0 = равны)
function BrainrotDB:Compare(a, b)
    local ta = self:GetRarityTier(a.Rarity)
    local tb = self:GetRarityTier(b.Rarity)
    if ta ~= tb then return ta > tb and 1 or -1 end
    if a.Income ~= b.Income then return a.Income > b.Income and 1 or -1 end
    return 0
end

-- ============================================================
-- ФОРМАТИРОВАНИЕ
-- ============================================================

-- Форматировать доход в читаемый вид ($1.5M/s, $250K/s)
function BrainrotDB:FormatIncome(income)
    if income >= 1e12 then return string.format("$%.2fT/s", income / 1e12) end
    if income >= 1e9  then return string.format("$%.2fB/s", income / 1e9)  end
    if income >= 1e6  then return string.format("$%.2fM/s", income / 1e6)  end
    if income >= 1e3  then return string.format("$%.1fK/s", income / 1e3)  end
    return string.format("$%d/s", income)
end

-- Получить строку с информацией о брейнроте (для UI / чата)
function BrainrotDB:GetInfoString(name)
    local b = self:Get(name)
    if not b then return "Неизвестный брейнрот: " .. tostring(name) end
    return string.format("%s | %s | %s | %s",
        b.Name, b.Rarity, self:FormatIncome(b.Income), b.Source)
end

-- ============================================================
-- СТАТИСТИКА БАЗЫ
-- ============================================================
function BrainrotDB:GetStats()
    local stats = {
        Total = #self.Data,
        ByRarity = {},
        HighestIncome = 0,
        HighestName = "",
    }
    for _, b in ipairs(self.Data) do
        stats.ByRarity[b.Rarity] = (stats.ByRarity[b.Rarity] or 0) + 1
        if b.Income > stats.HighestIncome then
            stats.HighestIncome = b.Income
            stats.HighestName = b.Name
        end
    end
    return stats
end

function BrainrotDB:Dump()
    local stats = self:GetStats()
    print("========== BRAINROT DB ==========")
    print("Всего записей:", stats.Total)
    for _, r in ipairs(self.Rarities) do
        local count = stats.ByRarity[r.Name] or 0
        if count > 0 then
            print(string.format("  %-12s : %d", r.Name, count))
        end
    end
    print("Максимальный доход:", stats.HighestName, self:FormatIncome(stats.HighestIncome))
    print("=================================")
end
-- ============================================================
-- AUTOFARM MODULE
-- Полный цикл: сбор → возврат на базу → размещение → продажа мусора
-- → апгрейды → ребёрс. Приоритет по редкости из BrainrotDB.
-- ============================================================
local AutoFarm = {}
AutoFarm.__index = AutoFarm

-- Состояние фарма
AutoFarm.State = {
    Running         = false,
    CurrentTask     = "idle",   -- idle / collecting / returning / placing / selling / upgrading / rebirthing
    LastCollect     = 0,
    LastPlace       = 0,
    LastSell        = 0,
    LastUpgrade     = 0,
    LastRebirth     = 0,
    TotalCollected  = 0,
    TotalPlaced     = 0,
    TotalSold       = 0,
    TotalEarned     = 0,
    SessionStart    = 0,
    Errors          = 0,
}

-- Настройки фарма (дефолты, перезаписываются из Config)
AutoFarm.Settings = {
    CollectDelay        = 0.25,
    PlaceDelay          = 0.5,
    SellDelay           = 0.5,
    UpgradeDelay        = 2.0,
    RebirthDelay        = 5.0,
    ReturnToBaseDist    = 50,       -- если дальше — телепорт на базу
    AutoSellThreshold   = 1000000,  -- продавать брейнроты с доходом < этого
    AutoUpgradeSpeed    = true,
    AutoUpgradeCarry    = true,
    AutoUpgradeBase     = true,
    AutoRebirth         = true,
    RebirthSpeedReq     = 50,       -- минимальная скорость для ребёрса
    MaxInventorySlots   = 6,        -- сколько брейнротов носим одновременно
    KeepBestCount       = 3,        -- сколько лучших оставляем в базе
    TeleportOnCollect   = true,     -- телепорт к брейнроту вместо ходьбы
}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

-- Получить позицию базы игрока
function AutoFarm:GetBasePosition()
    local base = GameModule:FindPlayerBase()
    if not base then return nil end
    local part = base:FindFirstChildOfClass("BasePart") or base.PrimaryPart
    if part then return part.Position end
    -- Fallback: ищем любой BasePart внутри
    for _, desc in ipairs(base:GetDescendants()) do
        if desc:IsA("BasePart") then return desc.Position end
    end
    return nil
end

-- Телепорт на базу
function AutoFarm:TeleportToBase()
    local basePos = self:GetBasePosition()
    if not basePos then return false end
    local hrp = Util:GetHRP()
    if not hrp then return false end
    hrp.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
    return true
end

-- Телепорт к объекту
function AutoFarm:TeleportTo(instance)
    if not instance then return false end
    local hrp = Util:GetHRP()
    if not hrp then return false end
    local target = instance:IsA("BasePart") and instance
        or instance:FindFirstChild("HumanoidRootPart")
        or instance.PrimaryPart
    if not target then return false end
    hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
    return true
end

-- Получить список брейнротов в инвентаре (на клиенте)
function AutoFarm:GetInventoryBrainrots()
    local inv = {}
    local invFolder = LocalPlayer:FindFirstChild("Inventory")
        or LocalPlayer:FindFirstChild("Brainrots")
        or LocalPlayer:FindFirstChild("Backpack")
    if invFolder then
        for _, child in ipairs(invFolder:GetChildren()) do
            if child:IsA("Model") or child:IsA("Tool") then
                table.insert(inv, child)
            end
        end
    end
    return inv
end

-- Определить редкость брейнрота по имени/атрибутам
function AutoFarm:GetBrainrotInfo(brainrot)
    if not brainrot then return nil end
    local name = brainrot.Name
    -- Убираем суффиксы типа " (Clone)", "1", "_"
    name = name:gsub("%s*%b()", ""):gsub("%d+$", ""):gsub("_$", ""):gsub("^%s+", ""):gsub("%s+$", "")

    -- Сначала пробуем по имени в базе
    local info = BrainrotDB:Get(name)
    if info then return info end

    -- Пробуем по атрибутам
    local rarity = brainrot:GetAttribute("Rarity")
    local income = brainrot:GetAttribute("Income") or brainrot:GetAttribute("Value")
    if rarity then
        return {
            Name = brainrot.Name,
            Rarity = rarity,
            Income = income or 0,
            Source = "runtime",
        }
    end

    -- Fallback: считаем Common
    return {
        Name = brainrot.Name,
        Rarity = "Common",
        Income = 0,
        Source = "unknown",
    }
end

-- Отсортировать список брейнротов по ценности (лучшие первыми)
function AutoFarm:SortByValue(brainrots)
    local list = {}
    for _, b in ipairs(brainrots) do
        local info = self:GetBrainrotInfo(b)
        table.insert(list, {Instance = b, Info = info})
    end
    table.sort(list, function(a, b)
        if not a.Info or not b.Info then return false end
        local cmp = BrainrotDB:Compare(a.Info, b.Info)
        return cmp > 0
    end)
    return list
end

-- Проверить, нужно ли продать брейнрот
function AutoFarm:ShouldSell(brainrot)
    local info = self:GetBrainrotInfo(brainrot)
    if not info then return true end
    return info.Income < self.Settings.AutoSellThreshold
end

-- Проверить, нужно ли оставить брейнрот (он лучше, чем текущие в базе)
function AutoFarm:ShouldKeep(brainrot, placedBrainrots)
    local info = self:GetBrainrotInfo(brainrot)
    if not info then return false end

    -- Если в базе меньше KeepBestCount слотов — оставляем
    if #placedBrainrots < self.Settings.KeepBestCount then
        return true
    end

    -- Сортируем размещённые по ценности
    local sorted = self:SortByValue(placedBrainrots)
    if #sorted < self.Settings.KeepBestCount then return true end

    -- Сравниваем с худшим из лучших
    local worstKept = sorted[self.Settings.KeepBestCount]
    if not worstKept or not worstKept.Info then return true end

    local cmp = BrainrotDB:Compare(info, worstKept.Info)
    return cmp > 0
end

-- ============================================================
-- ОСНОВНЫЕ ЗАДАЧИ
-- ============================================================

-- Задача 1: Собрать ближайший брейнрот
function AutoFarm:TaskCollect()
    self.State.CurrentTask = "collecting"

    local brainrot, dist = GameModule:GetClosestFreeBrainrot()
    if not brainrot then
        Util:Log("AutoFarm: нет свободных брейнротов")
        return false
    end

    Util:Log("AutoFarm: собираю", brainrot.Name, "на дистанции", math.floor(dist))

    -- Телепорт или подходим
    if self.Settings.TeleportOnCollect and dist > 15 then
        self:TeleportTo(brainrot)
        task.wait(0.1)
    end

    -- Собираем
    local ok = GameModule:CollectBrainrot(brainrot)
    if ok then
        self.State.TotalCollected = self.State.TotalCollected + 1
        self.State.LastCollect = tick()
    else
        self.State.Errors = self.State.Errors + 1
    end

    task.wait(self.Settings.CollectDelay)
    return ok
end

-- Задача 2: Вернуться на базу и разместить лучшие
function AutoFarm:TaskReturnAndPlace()
    self.State.CurrentTask = "returning"

    -- Телепорт на базу
    self:TeleportToBase()
    task.wait(0.2)

    local inv = self:GetInventoryBrainrots()
    if #inv == 0 then
        Util:Log("AutoFarm: инвентарь пуст, нечего размещать")
        return false
    end

    -- Сортируем инвентарь по ценности
    local sorted = self:SortByValue(inv)
    local placed = GameModule:GetPlacedBrainrots()

    self.State.CurrentTask = "placing"
    local placedCount = 0

    for _, entry in ipairs(sorted) do
        local brainrot = entry.Instance
        if self:ShouldKeep(brainrot, placed) then
            local ok = GameModule:PlaceBrainrot(brainrot)
            if ok then
                placedCount = placedCount + 1
                self.State.TotalPlaced = self.State.TotalPlaced + 1
                table.insert(placed, brainrot)
                task.wait(self.Settings.PlaceDelay)
            else
                self.State.Errors = self.State.Errors + 1
            end
        end
    end

    self.State.LastPlace = tick()
    Util:Log("AutoFarm: размещено", placedCount, "брейнротов")
    return placedCount > 0
end

-- Задача 3: Продать мусор из инвентаря
function AutoFarm:TaskSell()
    self.State.CurrentTask = "selling"

    local inv = self:GetInventoryBrainrots()
    if #inv == 0 then return false end

    -- Телепорт к зоне продажи
    local sellZone = GameModule:FindSellZone()
    if sellZone then
        self:TeleportTo(sellZone)
        task.wait(0.2)
    end

    local soldCount = 0
    for _, brainrot in ipairs(inv) do
        if self:ShouldSell(brainrot) then
            local ok = GameModule:SellBrainrot(brainrot)
            if ok then
                soldCount = soldCount + 1
                self.State.TotalSold = self.State.TotalSold + 1
                task.wait(self.Settings.SellDelay)
            else
                self.State.Errors = self.State.Errors + 1
            end
        end
    end

    self.State.LastSell = tick()
    Util:Log("AutoFarm: продано", soldCount, "брейнротов")
    return soldCount > 0
end

-- Задача 4: Апгрейды (скорость, вместимость, база)
function AutoFarm:TaskUpgrade()
    self.State.CurrentTask = "upgrading"

    local stats = GameModule:GetPlayerStats()
    local didUpgrade = false

    if self.Settings.AutoUpgradeSpeed then
        local ok = GameModule:UpgradeSpeed()
        if ok then didUpgrade = true end
        task.wait(0.1)
    end

    if self.Settings.AutoUpgradeCarry then
        local ok = GameModule:UpgradeCarry()
        if ok then didUpgrade = true end
        task.wait(0.1)
    end

    if self.Settings.AutoUpgradeBase then
        local ok = GameModule:UpgradeBase()
        if ok then didUpgrade = true end
        task.wait(0.1)
    end

    -- Апгрейд размещённых брейнротов
    local placed = GameModule:GetPlacedBrainrots()
    for _, brainrot in ipairs(placed) do
        pcall(function()
            GameModule:UpgradeBrainrot(brainrot)
        end)
        task.wait(0.1)
    end

    self.State.LastUpgrade = tick()
    if didUpgrade then
        Util:Log("AutoFarm: апгрейды выполнены")
    end
    return didUpgrade
end

-- Задача 5: Ребёрс (если достаточно скорости)
function AutoFarm:TaskRebirth()
    self.State.CurrentTask = "rebirthing"

    local stats = GameModule:GetPlayerStats()
    if stats.speed < self.Settings.RebirthSpeedReq then
        Util:Log("AutoFarm: скорость", stats.speed, "<", self.Settings.RebirthSpeedReq, "— ребёрс пропущен")
        return false
    end

    local ok = GameModule:Rebirth()
    if ok then
        self.State.TotalEarned = self.State.TotalEarned + (stats.money or 0)
        self.State.LastRebirth = tick()
        Util:Log("AutoFarm: ребёрс выполнен! Скорость была:", stats.speed)
    else
        self.State.Errors = self.State.Errors + 1
    end
    return ok
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ ФАРМА
-- ============================================================

function AutoFarm:Loop()
    if self.State.Running then return end
    self.State.Running = true
    self.State.SessionStart = tick()

    Util:Log("AutoFarm: цикл запущен")

    task.spawn(function()
        while self.State.Running do
            if not Config.AutoFarm then
                task.wait(0.5)
                continue
            end

            local ok, err = pcall(function()
                -- 1. Сбор
                if Config.AutoCollect then
                    for i = 1, self.Settings.MaxInventorySlots do
                        if not self.State.Running then break end
                        local collected = self:TaskCollect()
                        if not collected then break end
                    end
                end

                -- 2. Возврат и размещение
                if Config.AutoPlace then
                    self:TaskReturnAndPlace()
                end

                -- 3. Продажа мусора
                if Config.AutoSell then
                    self:TaskSell()
                end

                -- 4. Апгрейды (раз в N секунд)
                if Config.AutoUpgrade and (tick() - self.State.LastUpgrade) > self.Settings.UpgradeDelay then
                    self:TaskUpgrade()
                end

                -- 5. Ребёрс (раз в N секунд, если включён)
                if Config.AutoRebirth and self.Settings.AutoRebirth
                    and (tick() - self.State.LastRebirth) > self.Settings.RebirthDelay then
                    self:TaskRebirth()
                end

                self.State.CurrentTask = "idle"
            end)

            if not ok then
                self.State.Errors = self.State.Errors + 1
                Util:Warn("AutoFarm ошибка:", err)
            end

            task.wait(Config.FarmDelay)
        end

        Util:Log("AutoFarm: цикл остановлен")
    end)
end

function AutoFarm:Start()
    Config.AutoFarm = true
    Config.AutoCollect = true
    Config.AutoPlace = true
    Config.AutoSell = true
    Config.AutoUpgrade = true
    Config.AutoRebirth = true
    self:Loop()
end

function AutoFarm:Stop()
    Config.AutoFarm = false
    Config.AutoCollect = false
    Config.AutoPlace = false
    Config.AutoSell = false
    Config.AutoUpgrade = false
    Config.AutoRebirth = false
    self.State.Running = false
    self.State.CurrentTask = "idle"
end

function AutoFarm:IsRunning()
    return self.State.Running and Config.AutoFarm
end

-- ============================================================
-- СТАТИСТИКА СЕССИИ
-- ============================================================
function AutoFarm:GetSessionStats()
    local elapsed = tick() - (self.State.SessionStart or tick())
    return {
        Running        = self.State.Running,
        Task           = self.State.CurrentTask,
        Collected      = self.State.TotalCollected,
        Placed         = self.State.TotalPlaced,
        Sold           = self.State.TotalSold,
        Earned         = self.State.TotalEarned,
        Errors         = self.State.Errors,
        Uptime         = elapsed,
        PerMinute      = elapsed > 0 and (self.State.TotalCollected / elapsed * 60) or 0,
    }
end

function AutoFarm:PrintStats()
    local s = self:GetSessionStats()
    print("========== AUTOFARM STATS ==========")
    print(string.format("Задача: %s | Работает: %s", s.Task, tostring(s.Running)))
    print(string.format("Собрано: %d | Размещено: %d | Продано: %d", s.Collected, s.Placed, s.Sold))
    print(string.format("Заработано: %s", BrainrotDB:FormatIncome(s.Earned)))
    print(string.format("Ошибок: %d | Аптайм: %.0f сек", s.Errors, s.Uptime))
    print(string.format("Скорость: %.1f сбора/мин", s.PerMinute))
    print("====================================")
end

function AutoFarm:ResetStats()
    self.State.TotalCollected = 0
    self.State.TotalPlaced = 0
    self.State.TotalSold = 0
    self.State.TotalEarned = 0
    self.State.Errors = 0
    self.State.SessionStart = tick()
end
-- ============================================================
-- PLAYER MODS
-- GodMode, Speed, JumpPower, Fly, Noclip, Infinite Jump, Anti-Tsunami
-- ============================================================
local PlayerMods = {}
PlayerMods.__index = PlayerMods

-- Состояние модов
PlayerMods.State = {
    GodMode         = false,
    InfiniteJump    = false,
    Noclip          = false,
    Flying          = false,
    AntiTsunami     = false,
    SpeedEnabled    = false,
    JumpEnabled     = false,
    FlySpeed        = 50,
    FlyKeys         = {W = false, A = false, S = false, D = false, Space = false, Shift = false},
    OriginalWalkSpeed = 16,
    OriginalJumpPower = 50,
    Connections     = {},
    NoclipConnections = {},
    FlyConnection  = nil,
    TsunamiConnection = nil,
}

-- ============================================================
-- УТИЛИТЫ
-- ============================================================

-- Получить Humanoid игрока
local function getHum()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

-- Получить HRP
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- Создать BodyVelocity с параметрами
local function makeBV(hrp, velocity, maxForce)
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = velocity or Vector3.zero
    bv.MaxForce = maxForce or Vector3.new(1e5, 1e5, 1e5)
    bv.P = 1250
    bv.Parent = hrp
    return bv
end

-- Удалить все BodyVelocity с HRP
local function clearBVs(hrp)
    if not hrp then return end
    for _, c in ipairs(hrp:GetChildren()) do
        if c:IsA("BodyVelocity") or c:IsA("BodyGyro") then
            c:Destroy()
        end
    end
end

-- ============================================================
-- GODMODE
-- ============================================================
-- Три уровня:
--   1. Humanoid.MaxHealth = math.huge (работает на большинстве игр)
--   2. Хук на Humanoid.HealthChanged (не даёт серверу опустить HP)
--   3. Отключение скриптов урона (если найдены в Workspace)
-- ============================================================

function PlayerMods:EnableGodMode()
    self.State.GodMode = true

    local function apply()
        local hum = getHum()
        if not hum then return end
        hum.MaxHealth = math.huge
        hum.Health = math.huge
        hum.BreakJointsOnDeath = false

        -- Хук на изменение здоровья
        if self.State.Connections.HealthChanged then
            self.State.Connections.HealthChanged:Disconnect()
        end

        self.State.Connections.HealthChanged = hum.HealthChanged:Connect(function(newHealth)
            if self.State.GodMode and newHealth < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end)

        -- Хук на смерть — не даём умереть
        if self.State.Connections.Died then
            self.State.Connections.Died:Disconnect()
        end
        self.State.Connections.Died = hum.Died:Connect(function()
            if self.State.GodMode then
                task.wait(0.1)
                hum.Health = hum.MaxHealth
            end
        end)
    end

    apply()

    -- Переприменяем при респавне
    if self.State.Connections.CharAdded then
        self.State.Connections.CharAdded:Disconnect()
    end
    self.State.Connections.CharAdded = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if self.State.GodMode then apply() end
    end)

    Util:Log("GodMode включён")
end

function PlayerMods:DisableGodMode()
    self.State.GodMode = false

    if self.State.Connections.HealthChanged then
        self.State.Connections.HealthChanged:Disconnect()
        self.State.Connections.HealthChanged = nil
    end
    if self.State.Connections.Died then
        self.State.Connections.Died:Disconnect()
        self.State.Connections.Died = nil
    end
    if self.State.Connections.CharAdded then
        self.State.Connections.CharAdded:Disconnect()
        self.State.Connections.CharAdded = nil
    end

    local hum = getHum()
    if hum then
        hum.MaxHealth = 100
        hum.Health = 100
    end

    Util:Log("GodMode выключен")
end

-- ============================================================
-- SPEED
-- ============================================================
function PlayerMods:SetWalkSpeed(speed)
    self.State.SpeedEnabled = true
    Config.WalkSpeed = speed

    local function apply()
        local hum = getHum()
        if hum then
            hum.WalkSpeed = speed
        end
    end

    apply()

    if not self.State.Connections.SpeedLoop then
        self.State.Connections.SpeedLoop = RunService.Heartbeat:Connect(function()
            if not self.State.SpeedEnabled then return end
            local hum = getHum()
            if hum and hum.WalkSpeed ~= Config.WalkSpeed then
                hum.WalkSpeed = Config.WalkSpeed
            end
        end)
    end
end

function PlayerMods:DisableSpeed()
    self.State.SpeedEnabled = false
    if self.State.Connections.SpeedLoop then
        self.State.Connections.SpeedLoop:Disconnect()
        self.State.Connections.SpeedLoop = nil
    end
    local hum = getHum()
    if hum then hum.WalkSpeed = 16 end
end

-- ============================================================
-- JUMP POWER
-- ============================================================
function PlayerMods:SetJumpPower(power)
    self.State.JumpEnabled = true
    Config.JumpPower = power
    local hum = getHum()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = power
    end
    if not self.State.Connections.JumpLoop then
        self.State.Connections.JumpLoop = RunService.Heartbeat:Connect(function()
            if not self.State.JumpEnabled then return end
            local h = getHum()
            if h and h.JumpPower ~= Config.JumpPower then
                h.UseJumpPower = true
                h.JumpPower = Config.JumpPower
            end
        end)
    end
end

function PlayerMods:DisableJump()
    self.State.JumpEnabled = false
    if self.State.Connections.JumpLoop then
        self.State.Connections.JumpLoop:Disconnect()
        self.State.Connections.JumpLoop = nil
    end
    local hum = getHum()
    if hum then hum.JumpPower = 50 end
end

-- ============================================================
-- INFINITE JUMP
-- ============================================================
function PlayerMods:EnableInfiniteJump()
    self.State.InfiniteJump = true

    if self.State.Connections.InfiniteJump then
        self.State.Connections.InfiniteJump:Disconnect()
    end

    self.State.Connections.InfiniteJump = UserInputService.JumpRequest:Connect(function()
        if not self.State.InfiniteJump then return end
        local hum = getHum()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    Util:Log("InfiniteJump включён")
end

function PlayerMods:DisableInfiniteJump()
    self.State.InfiniteJump = false
    if self.State.Connections.InfiniteJump then
        self.State.Connections.InfiniteJump:Disconnect()
        self.State.Connections.InfiniteJump = nil
    end
end

-- ============================================================
-- NOCLIP
-- ============================================================
function PlayerMods:EnableNoclip()
    self.State.Noclip = true

    if self.State.NoclipConnections.Stepped then
        self.State.NoclipConnections.Stepped:Disconnect()
    end

    self.State.NoclipConnections.Stepped = RunService.Stepped:Connect(function()
        if not self.State.Noclip then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)

    Util:Log("Noclip включён")
end

function PlayerMods:DisableNoclip()
    self.State.Noclip = false
    if self.State.NoclipConnections.Stepped then
        self.State.NoclipConnections.Stepped:Disconnect()
        self.State.NoclipConnections.Stepped = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    Util:Log("Noclip выключен")
end

-- ============================================================
-- FLY
-- ============================================================
-- Управление: WASD — горизонталь, Space — вверх, Shift — вниз, Q/E — speed
-- ============================================================

function PlayerMods:EnableFly()
    if self.State.Flying then return end
    self.State.Flying = true

    local hrp = getHRP()
    if not hrp then
        self.State.Flying = false
        return
    end

    -- Очищаем предыдущие
    clearBVs(hrp)

    local bv = makeBV(hrp, Vector3.zero, Vector3.new(1e5, 1e5, 1e5))
    local bg = Instance.new("BodyGyro")
    bg.P = 9e4
    bg.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    self.State.FlyBV = bv
    self.State.FlyBG = bg

    -- Ввод
    self.State.FlyKeys = {W = false, A = false, S = false, D = false, Space = false, Shift = false}

    if self.State.Connections.FlyInputBegan then
        self.State.Connections.FlyInputBegan:Disconnect()
    end
    if self.State.Connections.FlyInputEnded then
        self.State.Connections.FlyInputEnded:Disconnect()
    end

    self.State.Connections.FlyInputBegan = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if not self.State.Flying then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then self.State.FlyKeys.W = true
        elseif k == Enum.KeyCode.A then self.State.FlyKeys.A = true
        elseif k == Enum.KeyCode.S then self.State.FlyKeys.S = true
        elseif k == Enum.KeyCode.D then self.State.FlyKeys.D = true
        elseif k == Enum.KeyCode.Space then self.State.FlyKeys.Space = true
        elseif k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.RightShift then self.State.FlyKeys.Shift = true
        end
    end)

    self.State.Connections.FlyInputEnded = UserInputService.InputEnded:Connect(function(input)
        local k = input.KeyCode
        if k == Enum.KeyCode.W then self.State.FlyKeys.W = false
        elseif k == Enum.KeyCode.A then self.State.FlyKeys.A = false
        elseif k == Enum.KeyCode.S then self.State.FlyKeys.S = false
        elseif k == Enum.KeyCode.D then self.State.FlyKeys.D = false
        elseif k == Enum.KeyCode.Space then self.State.FlyKeys.Space = false
        elseif k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.RightShift then self.State.FlyKeys.Shift = false
        end
    end)

    -- Обновление скорости
    if self.State.FlyConnection then
        self.State.FlyConnection:Disconnect()
    end

    self.State.FlyConnection = RunService.RenderStepped:Connect(function()
        if not self.State.Flying then return end
        local h = getHRP()
        if not h or not self.State.FlyBV or not self.State.FlyBV.Parent then return end

        local cam = Workspace.CurrentCamera
        if not cam then return end

        local move = Vector3.zero
        local look = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector

        if self.State.FlyKeys.W then move = move + look end
        if self.State.FlyKeys.S then move = move - look end
        if self.State.FlyKeys.D then move = move + right end
        if self.State.FlyKeys.A then move = move - right end

        if move.Magnitude > 0 then
            move = move.Unit
        end

        local vertical = 0
        if self.State.FlyKeys.Space then vertical = 1 end
        if self.State.FlyKeys.Shift then vertical = -1 end

        local speed = Config.FlySpeed
        local velocity = (move * speed) + Vector3.new(0, vertical * speed, 0)

        self.State.FlyBV.Velocity = velocity
        self.State.FlyBG.CFrame = CFrame.new(h.Position, h.Position + look)
    end)

    Util:Log("Fly включён")
end

function PlayerMods:DisableFly()
    self.State.Flying = false

    local hrp = getHRP()
    if hrp then
        clearBVs(hrp)
    end

    if self.State.FlyConnection then
        self.State.FlyConnection:Disconnect()
        self.State.FlyConnection = nil
    end
    if self.State.Connections.FlyInputBegan then
        self.State.Connections.FlyInputBegan:Disconnect()
        self.State.Connections.FlyInputBegan = nil
    end
    if self.State.Connections.FlyInputEnded then
        self.State.Connections.FlyInputEnded:Disconnect()
        self.State.Connections.FlyInputEnded = nil
    end

    Util:Log("Fly выключен")
end

function PlayerMods:SetFlySpeed(speed)
    Config.FlySpeed = speed
end

-- ============================================================
-- ANTI-TSUNAMI
-- ============================================================
-- Логика: если активен цунами и игрок в опасной зоне — телепорт в safe zone
-- или обнуление урона через godmode. Дополнительно можно "переждать" цунами.
-- ============================================================

function PlayerMods:EnableAntiTsunami()
    self.State.AntiTsunami = true

    if self.State.Connections.AntiTsunami then
        self.State.Connections.AntiTsunami:Disconnect()
    end

    self.State.Connections.AntiTsunami = RunService.Heartbeat:Connect(function()
        if not self.State.AntiTsunami then return end

        local tsunami = GameModule:GetActiveTsunami()
        if not tsunami then return end

        local hrp = getHRP()
        if not hrp then return end

        -- Проверяем близость цунами к игроку
        local tPos
        if tsunami:IsA("BasePart") then
            tPos = tsunami.Position
        elseif tsunami:IsA("Model") then
            local p = tsunami.PrimaryPart or tsunami:FindFirstChildWhichIsA("BasePart")
            if p then tPos = p.Position end
        end

        if tPos and (hrp.Position - tPos).Magnitude < 150 then
            -- Цунами близко — телепорт в безопасную зону
            local safe = GameModule:GetSafeZone()
            if safe and safe:IsA("BasePart") then
                hrp.CFrame = CFrame.new(safe.Position + Vector3.new(0, 5, 0))
            else
                -- Fallback: телепорт высоко вверх
                hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 500, 0))
            end
        end
    end)

    Util:Log("AntiTsunami включён")
end

function PlayerMods:DisableAntiTsunami()
    self.State.AntiTsunami = false
    if self.State.Connections.AntiTsunami then
        self.State.Connections.AntiTsunami:Disconnect()
        self.State.Connections.AntiTsunami = nil
    end
    Util:Log("AntiTsunami выключен")
end

-- ============================================================
-- АНТИ-ТЕЛЕПОРТ В ТЮРЬМУ / ВОЗВРАТ
-- ============================================================
-- Если игрока телепортировали куда-то далеко от базы — возвращаем обратно
function PlayerMods:EnableAntiJail()
    self.State.AntiJail = true

    if self.State.Connections.AntiJail then
        self.State.Connections.AntiJail:Disconnect()
    end

    self.State.Connections.AntiJail = RunService.Heartbeat:Connect(function()
        if not self.State.AntiJail then return end
        local hrp = getHRP()
        if not hrp then return end

        -- Если игрок упал ниже -500 (или иная граница карты) — возвращаем на базу
        if hrp.Position.Y < -500 then
            local basePos = AutoFarm:GetBasePosition()
            if basePos then
                hrp.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
            end
        end
    end)
end

function PlayerMods:DisableAntiJail()
    self.State.AntiJail = false
    if self.State.Connections.AntiJail then
        self.State.Connections.AntiJail:Disconnect()
        self.State.Connections.AntiJail = nil
    end
end

-- ============================================================
-- АНТИ-ФЛИНГ / СТАБИЛИЗАЦИЯ
-- ============================================================
-- Не даёт другим игрокам флингнуть тебя (если сервер это разрешает)
function PlayerMods:EnableAntiFling()
    self.State.AntiFling = true

    if self.State.Connections.AntiFling then
        self.State.Connections.AntiFling:Disconnect()
    end

    self.State.Connections.AntiFling = RunService.Heartbeat:Connect(function()
        if not self.State.AntiFling then return end
        local hrp = getHRP()
        if not hrp then return end
        -- Ограничиваем скорость
        if hrp.AssemblyLinearVelocity.Magnitude > 500 then
            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity.Unit * 100
        end
    end)
end

function PlayerMods:DisableAntiFling()
    self.State.AntiFling = false
    if self.State.Connections.AntiFling then
        self.State.Connections.AntiFling:Disconnect()
        self.State.Connections.AntiFling = nil
    end
end

-- ============================================================
-- СБРОС ВСЕГО
-- ============================================================
function PlayerMods:ResetAll()
    self:DisableGodMode()
    self:DisableSpeed()
    self:DisableJump()
    self:DisableInfiniteJump()
    self:DisableNoclip()
    self:DisableFly()
    self:DisableAntiTsunami()
    self:DisableAntiJail()
    self:DisableAntiFling()
    Util:Log("PlayerMods: всё сброшено")
end

-- Инициализация: запоминаем оригинальные значения
task.spawn(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        PlayerMods.State.OriginalWalkSpeed = hum.WalkSpeed
        PlayerMods.State.OriginalJumpPower = hum.JumpPower
    end
end)
-- ============================================================
-- TELEPORTS MODULE
-- Сеть телепортов: база, брейнроты, игроки, события, зоны, кастомные метки
-- ============================================================
local Teleports = {}
Teleports.__index = Teleports

Teleports.State = {
    CustomWaypoints = {},   -- {name, position, color}
    LastTeleport    = 0,
    Cooldown        = 0.5,
    History         = {},   -- последние точки телепорта
    MaxHistory      = 20,
}

-- ============================================================
-- БАЗОВЫЕ ОПЕРАЦИИ
-- ============================================================

-- Универсальный телепорт в позицию (с учётом cooldown)
function Teleports:TeleportToPosition(position, keepVelocity)
    if not position then return false, "no_position" end
    if tick() - self.State.LastTeleport < self.State.Cooldown then
        return false, "cooldown"
    end

    local hrp = Util:GetHRP()
    if not hrp then return false, "no_hrp" end

    local oldVelocity = hrp.AssemblyLinearVelocity
    hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))

    if keepVelocity then
        hrp.AssemblyLinearVelocity = oldVelocity
    else
        hrp.AssemblyLinearVelocity = Vector3.zero
    end

    self.State.LastTeleport = tick()
    return true
end

-- Универсальный телепорт к инстансу (модель / парт)
function Teleports:TeleportToInstance(instance, offset)
    if not instance then return false, "no_instance" end
    offset = offset or Vector3.new(0, 3, 0)

    local target
    if instance:IsA("BasePart") then
        target = instance
    elseif instance:IsA("Model") then
        target = instance.PrimaryPart
            or instance:FindFirstChild("HumanoidRootPart")
            or instance:FindFirstChildWhichIsA("BasePart")
    end

    if not target then return false, "no_target_part" end
    return self:TeleportToPosition(target.Position + offset)
end

-- Добавить точку в историю
function Teleports:PushHistory(name, position)
    table.insert(self.State.History, 1, {
        Name = name,
        Position = position,
        Time = tick(),
    })
    while #self.State.History > self.State.MaxHistory do
        table.remove(self.State.History)
    end
end

-- ============================================================
-- ТЕЛЕПОРТЫ К ИГРОВЫМ ОБЪЕКТАМ
-- ============================================================

-- К базе игрока
function Teleports:ToBase()
    local basePos = AutoFarm:GetBasePosition()
    if not basePos then return false, "no_base" end
    local ok = self:TeleportToPosition(basePos + Vector3.new(0, 5, 0))
    if ok then self:PushHistory("Base", basePos) end
    return ok
end

-- К ближайшему свободному брейнроту
function Teleports:ToClosestBrainrot()
    local brainrot, dist = GameModule:GetClosestFreeBrainrot()
    if not brainrot then return false, "no_brainrot" end
    local hrp = brainrot:FindFirstChild("HumanoidRootPart") or brainrot.PrimaryPart
    if not hrp then return false, "no_hrp_brainrot" end
    local ok = self:TeleportToInstance(brainrot)
    if ok then self:PushHistory("Brainrot: " .. brainrot.Name, hrp.Position) end
    return ok
end

-- К самому ценному брейнроту на карте (по базе BrainrotDB)
function Teleports:ToBestBrainrot()
    local best, bestVal = nil, -math.huge
    for _, b in ipairs(GameModule:GetFreeBrainrots()) do
        local info = AutoFarm:GetBrainrotInfo(b)
        if info then
            local tier = BrainrotDB:GetRarityTier(info.Rarity)
            local val = tier * 1e9 + (info.Income or 0)
            if val > bestVal then
                bestVal = val
                best = b
            end
        end
    end
    if not best then return false, "no_brainrot" end
    return self:TeleportToInstance(best)
end

-- К конкретному брейнроту по имени
function Teleports:ToBrainrotByName(name)
    if not name or name == "" then return false, "no_name" end
    local lower = name:lower()
    for _, b in ipairs(GameModule:GetFreeBrainrots()) do
        if b.Name:lower():find(lower, 1, true) then
            return self:TeleportToInstance(b)
        end
    end
    return false, "not_found"
end

-- К зоне продажи
function Teleports:ToSellZone()
    local sell = GameModule:FindSellZone()
    if not sell then return false, "no_sell_zone" end
    local ok = self:TeleportToInstance(sell)
    if ok then
        local pos = sell:IsA("BasePart") and sell.Position or sell.PrimaryPart and sell.PrimaryPart.Position
        self:PushHistory("SellZone", pos)
    end
    return ok
end

-- К Spawn Machine
function Teleports:ToSpawnMachine()
    local sm = GameModule:FindSpawnMachine()
    if not sm then return false, "no_spawn_machine" end
    return self:TeleportToInstance(sm)
end

-- К папке событий
function Teleports:ToEventFolder()
    local ef = GameModule:FindEventFolder()
    if not ef then return false, "no_event_folder" end
    -- Если это папка — берём первого ребёнка
    if ef:IsA("Folder") then
        for _, child in ipairs(ef:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                return self:TeleportToInstance(child)
            end
        end
        return false, "empty_event_folder"
    end
    return self:TeleportToInstance(ef)
end

-- К ближайшей safe zone
function Teleports:ToSafeZone()
    local safe = GameModule:GetSafeZone()
    if not safe then return false, "no_safe_zone" end
    return self:TeleportToInstance(safe)
end

-- К активному цунами (для наблюдения / теста)
function Teleports:ToTsunami()
    local t = GameModule:GetActiveTsunami()
    if not t then return false, "no_tsunami" end
    return self:TeleportToInstance(t, Vector3.new(0, 50, 0))
end

-- ============================================================
-- ТЕЛЕПОРТЫ К ИГРОКАМ
-- ============================================================

-- К игроку по имени (частичное совпадение)
function Teleports:ToPlayer(name)
    if not name or name == "" then return false, "no_name" end
    local lower = name:lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Name:lower():find(lower, 1, true) then
            local hrp = Util:GetHRPFromPlayer(plr)
            if hrp then
                local ok = self:TeleportToPosition(hrp.Position)
                if ok then self:PushHistory("Player: " .. plr.Name, hrp.Position) end
                return ok
            end
        end
    end
    return false, "player_not_found"
end

-- К ближайшему игроку
function Teleports:ToClosestPlayer()
    local plr, dist = Util:GetClosestPlayer()
    if not plr then return false, "no_players" end
    local hrp = Util:GetHRPFromPlayer(plr)
    if not hrp then return false, "no_hrp" end
    local ok = self:TeleportToPosition(hrp.Position)
    if ok then self:PushHistory("Closest: " .. plr.Name, hrp.Position) end
    return ok
end

-- Ко всем игрокам по очереди (проход по списку)
function Teleports:ToEachPlayer(delayBetween)
    delayBetween = delayBetween or 0.3
    task.spawn(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local hrp = Util:GetHRPFromPlayer(plr)
                if hrp then
                    self:TeleportToPosition(hrp.Position)
                    task.wait(delayBetween)
                end
            end
        end
    end)
end

-- ============================================================
-- КАСТОМНЫЕ МЕТКИ
-- ============================================================

function Teleports:AddWaypoint(name, position)
    if not name or name == "" then
        name = "WP_" .. tostring(#self.State.CustomWaypoints + 1)
    end
    table.insert(self.State.CustomWaypoints, {
        Name = name,
        Position = position or (Util:GetHRP() and Util:GetHRP().Position),
        Time = tick(),
    })
    Util:Log("Waypoint добавлен:", name)
end

function Teleports:RemoveWaypoint(name)
    for i, wp in ipairs(self.State.CustomWaypoints) do
        if wp.Name == name then
            table.remove(self.State.CustomWaypoints, i)
            return true
        end
    end
    return false
end

function Teleports:ToWaypoint(name)
    for _, wp in ipairs(self.State.CustomWaypoints) do
        if wp.Name == name then
            return self:TeleportToPosition(wp.Position)
        end
    end
    return false, "waypoint_not_found"
end

function Teleports:GetWaypoints()
    return self.State.CustomWaypoints
end

function Teleports:ClearWaypoints()
    self.State.CustomWaypoints = {}
end

-- ============================================================
-- ИСТОРИЯ ТЕЛЕПОРТОВ
-- ============================================================

function Teleports:Back()
    if #self.State.History < 2 then return false, "no_history" end
    -- Пропускаем текущую точку, идём на предыдущую
    local prev = self.State.History[2]
    return self:TeleportToPosition(prev.Position)
end

function Teleports:GetHistory()
    return self.State.History
end

function Teleports:ClearHistory()
    self.State.History = {}
end

-- ============================================================
-- ТЕЛЕПОРТ НА ПРОИЗВОЛЬНЫЕ КООРДИНАТЫ (из UI)
-- ============================================================
function Teleports:ToCoords(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return false, "invalid_coords" end
    return self:TeleportToPosition(Vector3.new(x, y, z))
end

-- ============================================================
-- СПИСОК БЫСТРЫХ КОМАНД ДЛЯ UI
-- ============================================================
Teleports.QuickActions = {
    {Label = "Base",           Func = function() return Teleports:ToBase() end},
    {Label = "Sell Zone",      Func = function() return Teleports:ToSellZone() end},
    {Label = "Spawn Machine",  Func = function() return Teleports:ToSpawnMachine() end},
    {Label = "Closest Brainrot",Func = function() return Teleports:ToClosestBrainrot() end},
    {Label = "Best Brainrot",  Func = function() return Teleports:ToBestBrainrot() end},
    {Label = "Event",          Func = function() return Teleports:ToEventFolder() end},
    {Label = "Safe Zone",      Func = function() return Teleports:ToSafeZone() end},
    {Label = "Closest Player", Func = function() return Teleports:ToClosestPlayer() end},
    {Label = "Back",           Func = function() return Teleports:Back() end},
}

-- ============================================================
-- ЗАЩИТА ОТ ТЕЛЕПОРТА В ЗАПРЕЩЁННЫЕ ЗОНЫ (если требуется игрой)
-- ============================================================
-- Некоторые игры кикают за телепорт. Здесь можно добавить проверку
-- на "легальность" движения — например, чтобы прыгать не быстрее X studs/frame.
Teleports.SafeMode = false

function Teleports:SetSafeMode(enabled, maxDistancePerFrame)
    self.SafeMode = enabled
    self.SafeMaxDistance = maxDistancePerFrame or 50
end

-- Обёртка телепорта в safe mode: если расстояние больше maxDistancePerFrame —
-- разбиваем на несколько кадров (или отказываемся)
local _originalTeleport = Teleports.TeleportToPosition
function Teleports:TeleportToPosition(position, keepVelocity)
    if not self.SafeMode then
        return _originalTeleport(self, position, keepVelocity)
    end

    local hrp = Util:GetHRP()
    if not hrp then return false, "no_hrp" end
    local dist = (hrp.Position - position).Magnitude
    if dist <= (self.SafeMaxDistance or 50) then
        return _originalTeleport(self, position, keepVelocity)
    end

    -- Разбиваем на шаги
    task.spawn(function()
        local steps = math.ceil(dist / (self.SafeMaxDistance or 50))
        for i = 1, steps do
            if not self.SafeMode then break end
            local t = i / steps
            local newPos = hrp.Position:Lerp(position, t)
            hrp.CFrame = CFrame.new(newPos + Vector3.new(0, 3, 0))
            RunService.RenderStepped:Wait()
        end
    end)
    return true
end
-- ============================================================
-- ESP MODULE
-- Через BillboardGui + Highlight (Drawing в Xeno нестабилен)
-- Игроки, брейнроты, события, кастомные объекты
-- ============================================================
local ESP = {}
ESP.__index = ESP

ESP.State = {
    Enabled         = false,
    PlayerESP       = true,
    BrainrotESP     = true,
    EventESP        = true,
    Boxes           = true,
    Names           = true,
    Distances       = true,
    Tracers         = false,
    Skeletons       = false,
    Health          = false,
    Rarity          = true,
    MaxDistance     = 5000,
    TracerOrigin    = "bottom",   -- bottom / center / mouse
    RefreshRate     = 0.1,
    Containers      = {},          -- [instance] = {billboard=..., highlight=..., tracer=...}
    Running         = false,
}

-- Хранилище ESP-контейнеров в CoreGui
ESP.Root = nil

-- ============================================================
-- СОЗДАНИЕ КОРНЕВОГО КОНТЕЙНЕРА
-- ============================================================
function ESP:EnsureRoot()
    if self.Root and self.Root.Parent then return self.Root end

    local parent = CoreGui
    if not pcall(function() return CoreGui.Name end) then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Убираем старый
    local existing = parent:FindFirstChild("ETFB_ESP")
    if existing then existing:Destroy() end

    self.Root = InstanceHelper:Create("ScreenGui", {
        Name = "ETFB_ESP",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 5,
    }, parent)

    return self.Root
end

-- ============================================================
-- ХЕЛПЕРЫ
-- ============================================================

-- Получить HumanoidRootPart или PrimaryPart инстанса
local function getTargetPart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst:FindFirstChild("HumanoidRootPart")
            or inst.PrimaryPart
            or inst:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

-- Получить bounding box модели (для боксов ESP)
local function getBoundingBox(model)
    if not model then return nil, nil end
    if model:IsA("BasePart") then
        return model.Size, model.CFrame
    end
    local ok, size, cframe = pcall(function()
        return model:GetBoundingBox()
    end)
    if ok then return size, cframe end
    -- Fallback: считаем вручную по партам
    local min, max
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            local pos = p.Position
            local half = p.Size * 0.5
            local pmin = pos - half
            local pmax = pos + half
            if not min then
                min, max = pmin, pmax
            else
                min = Vector3.new(math.min(min.X, pmin.X), math.min(min.Y, pmin.Y), math.min(min.Z, pmin.Z))
                max = Vector3.new(math.max(max.X, pmax.X), math.max(max.Y, pmax.Y), math.max(max.Z, pmax.Z))
            end
        end
    end
    if not min then return nil, nil end
    local size = max - min
    local center = (min + max) * 0.5
    return size, CFrame.new(center)
end

-- Форматировать дистанцию
local function fmtDist(studs)
    if studs >= 1000 then return string.format("%.1fk", studs / 1000) end
    return string.format("%d", math.floor(studs))
end

-- ============================================================
-- СОЗДАНИЕ ЭЛЕМЕНТОВ ESP ДЛЯ ОБЪЕКТА
-- ============================================================

-- BillboardGui с именем, дистанцией, редкостью, здоровьем
function ESP:CreateBillboard(targetPart, config)
    config = config or {}
    local bb = InstanceHelper:Create("BillboardGui", {
        Name = "ETFB_ESP_BB",
        Size = UDim2.new(0, 200, 0, 60),
        StudsOffset = Vector3.new(0, 3, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = self.State.MaxDistance,
        Adornee = targetPart,
    }, self.Root)

    local container = InstanceHelper:Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, bb)

    local layout = InstanceHelper:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, container)

    local nameLabel = InstanceHelper:Create("TextLabel", {
        Name = "Name",
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = config.Color or Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextStrokeTransparency = 0.2,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        LayoutOrder = 1,
    }, container)

    local rarityLabel = InstanceHelper:Create("TextLabel", {
        Name = "Rarity",
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = config.RarityColor or Color3.fromRGB(200, 200, 200),
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        LayoutOrder = 2,
    }, container)

    local distLabel = InstanceHelper:Create("TextLabel", {
        Name = "Dist",
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        LayoutOrder = 3,
    }, container)

    local hpLabel = InstanceHelper:Create("TextLabel", {
        Name = "HP",
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(100, 255, 100),
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        LayoutOrder = 4,
    }, container)

    return bb, {Name = nameLabel, Rarity = rarityLabel, Dist = distLabel, HP = hpLabel}
end

-- Highlight — обводка объекта
function ESP:CreateHighlight(target, color, fillColor, transparency)
    local hl = InstanceHelper:Create("Highlight", {
        Name = "ETFB_ESP_HL",
        FillColor = fillColor or color or Color3.fromRGB(255, 255, 255),
        FillTransparency = transparency or 0.7,
        OutlineColor = color or Color3.fromRGB(255, 255, 255),
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Adornee = target,
    }, self.Root)
    return hl
end

-- Бокс — 2D прямоугольник через BillboardGui с рамкой
function ESP:CreateBox(targetPart, size, cframe, color)
    local bb = InstanceHelper:Create("BillboardGui", {
        Name = "ETFB_ESP_Box",
        Size = UDim2.new(0, 100, 0, 100),
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = self.State.MaxDistance,
        Adornee = targetPart,
    }, self.Root)

    local frame = InstanceHelper:Create("Frame", {
        Name = "Box",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 2,
        BorderColor3 = color or Color3.fromRGB(0, 255, 100),
    }, bb)

    return bb, frame
end

-- ============================================================
-- ОБНОВЛЕНИЕ ESP ДЛЯ КОНКРЕТНОГО ОБЪЕКТА
-- ============================================================

function ESP:RefreshPlayer(plr)
    if plr == LocalPlayer then return end
    if not plr.Character then return end

    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local myHRP = Util:GetHRP()
    if not myHRP then return end

    local dist = (myHRP.Position - hrp.Position).Magnitude
    if dist > self.State.MaxDistance then
        self:Remove(plr)
        return
    end

    -- Если ESP-контейнера нет — создаём
    if not self.State.Containers[plr] then
        local color = Color3.fromRGB(255, 80, 80)

        local bb, labels = self:CreateBillboard(hrp, {
            Color = color,
            RarityColor = Color3.fromRGB(200, 200, 200),
        })

        local hl = self:CreateHighlight(plr.Character, color, color, 0.7)

        self.State.Containers[plr] = {
            Billboard = bb,
            Labels = labels,
            Highlight = hl,
            Target = plr.Character,
            Type = "player",
        }
    end

    -- Обновляем данные
    local data = self.State.Containers[plr]
    if not data or not data.Billboard or not data.Billboard.Parent then
        self.State.Containers[plr] = nil
        return
    end

    -- Позиция адорни
    data.Billboard.Adornee = hrp

    -- Имя
    if self.State.Names then
        data.Labels.Name.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
        data.Labels.Name.Visible = true
    else
        data.Labels.Name.Visible = false
    end

    -- Дистанция
    if self.State.Distances then
        data.Labels.Dist.Text = "[" .. fmtDist(dist) .. " studs]"
        data.Labels.Dist.Visible = true
    else
        data.Labels.Dist.Visible = false
    end

    -- Здоровье
    if self.State.Health then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            data.Labels.HP.Text = string.format("HP: %d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))
            data.Labels.HP.TextColor3 = hum.Health > hum.MaxHealth * 0.5 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
            data.Labels.HP.Visible = true
        end
    else
        data.Labels.HP.Visible = false
    end

    -- Редкость у игроков не нужна
    data.Labels.Rarity.Visible = false

    -- Highlight на месте?
    if data.Highlight and data.Highlight.Adornee ~= plr.Character then
        data.Highlight.Adornee = plr.Character
    end
end

function ESP:RefreshBrainrot(brainrot)
    if not brainrot or not brainrot.Parent then
        self:Remove(brainrot)
        return
    end

    local target = brainrot:FindFirstChild("HumanoidRootPart") or brainrot.PrimaryPart
    if not target then return end

    local myHRP = Util:GetHRP()
    if not myHRP then return end

    local dist = (myHRP.Position - target.Position).Magnitude
    if dist > self.State.MaxDistance then
        self:Remove(brainrot)
        return
    end

    -- Инфа из базы
    local info = AutoFarm:GetBrainrotInfo(brainrot)
    local rarity = info and info.Rarity or "Common"
    local rarityColor = BrainrotDB:GetRarityColor(rarity)

    -- Создаём контейнер
    if not self.State.Containers[brainrot] then
        local bb, labels = self:CreateBillboard(target, {
            Color = Color3.fromRGB(255, 255, 255),
            RarityColor = rarityColor,
        })

        local hl = self:CreateHighlight(brainrot, rarityColor, rarityColor, 0.6)

        self.State.Containers[brainrot] = {
            Billboard = bb,
            Labels = labels,
            Highlight = hl,
            Target = target,
            Type = "brainrot",
        }
    end

    local data = self.State.Containers[brainrot]
    if not data or not data.Billboard or not data.Billboard.Parent then
        self.State.Containers[brainrot] = nil
        return
    end

    data.Billboard.Adornee = target

    -- Имя
    if self.State.Names then
        data.Labels.Name.Text = brainrot.Name
        data.Labels.Name.Visible = true
    else
        data.Labels.Name.Visible = false
    end

    -- Редкость
    if self.State.Rarity and info then
        data.Labels.Rarity.Text = string.format("%s | %s", rarity, BrainrotDB:FormatIncome(info.Income or 0))
        data.Labels.Rarity.TextColor3 = rarityColor
        data.Labels.Rarity.Visible = true
    else
        data.Labels.Rarity.Visible = false
    end

    -- Дистанция
    if self.State.Distances then
        data.Labels.Dist.Text = "[" .. fmtDist(dist) .. " studs]"
        data.Labels.Dist.Visible = true
    else
        data.Labels.Dist.Visible = false
    end

    -- HP не нужно у брейнротов (если только не модель с Humanoid)
    data.Labels.HP.Visible = false

    -- Highlight цвет по редкости
    if data.Highlight then
        data.Highlight.OutlineColor = rarityColor
        data.Highlight.FillColor = rarityColor
    end
end

-- ============================================================
-- УДАЛЕНИЕ
-- ============================================================
function ESP:Remove(key)
    local data = self.State.Containers[key]
    if not data then return end

    if data.Billboard then data.Billboard:Destroy() end
    if data.Highlight then data.Highlight:Destroy() end
    if data.Box then data.Box:Destroy() end
    if data.Tracer then data.Tracer:Destroy() end

    self.State.Containers[key] = nil
end

function ESP:ClearAll()
    for key, _ in pairs(self.State.Containers) do
        self:Remove(key)
    end
    self.State.Containers = {}
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ ESP
-- ============================================================
function ESP:Loop()
    if self.State.Running then return end
    self.State.Running = true
    self:EnsureRoot()

    task.spawn(function()
        while self.State.Running do
            if not self.State.Enabled then
                task.wait(0.5)
                continue
            end

            local ok, err = pcall(function()
                -- Игроки
                if self.State.PlayerESP then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer and plr.Character then
                            self:RefreshPlayer(plr)
                        end
                    end
                end

                -- Брейнроты
                if self.State.BrainrotESP then
                    local folder = GameModule:FindBrainrotFolder()
                    if folder then
                        for _, child in ipairs(folder:GetDescendants()) do
                            if child:IsA("Model") and (child:FindFirstChildOfClass("Humanoid") or child:GetAttribute("Rarity")) then
                                self:RefreshBrainrot(child)
                            end
                        end
                    end
                end

                -- Чистим контейнеры для удалённых объектов
                for key, data in pairs(self.State.Containers) do
                    if typeof(key) == "Instance" and not key.Parent then
                        self:Remove(key)
                    elseif typeof(key) == "Instance" and key:IsA("Player") and not key.Character then
                        self:Remove(key)
                    end
                end
            end)

            if not ok then
                Util:Warn("ESP ошибка:", err)
            end

            task.wait(self.State.RefreshRate)
        end
    end)

    Util:Log("ESP цикл запущен")
end

-- ============================================================
-- ВКЛ/ВЫКЛ
-- ============================================================
function ESP:Enable()
    self.State.Enabled = true
    Config.ESPEnabled = true
    self:EnsureRoot()
    self:Loop()
end

function ESP:Disable()
    self.State.Enabled = false
    Config.ESPEnabled = false
    self:ClearAll()
end

function ESP:Toggle()
    if self.State.Enabled then self:Disable() else self:Enable() end
end

-- ============================================================
-- БЫСТРЫЕ НАСТРОЙКИ
-- ============================================================
function ESP:SetMaxDistance(d)
    self.State.MaxDistance = d
end

function ESP:SetRefreshRate(r)
    self.State.RefreshRate = math.max(0.05, r)
end

function ESP:TogglePlayers()
    self.State.PlayerESP = not self.State.PlayerESP
    if not self.State.PlayerESP then
        for key, data in pairs(self.State.Containers) do
            if data.Type == "player" then self:Remove(key) end
        end
    end
end

function ESP:ToggleBrainrots()
    self.State.BrainrotESP = not self.State.BrainrotESP
    if not self.State.BrainrotESP then
        for key, data in pairs(self.State.Containers) do
            if data.Type == "brainrot" then self:Remove(key) end
        end
    end
end

function ESP:ToggleNames()      self.State.Names = not self.State.Names end
function ESP:ToggleDistances()  self.State.Distances = not self.State.Distances end
function ESP:ToggleHealth()     self.State.Health = not self.State.Health end
function ESP:ToggleRarity()     self.State.Rarity = not self.State.Rarity end
function ESP:ToggleBoxes()      self.State.Boxes = not self.State.Boxes end
function ESP:ToggleTracers()    self.State.Tracers = not self.State.Tracers end

-- ============================================================
-- СПИСОК БРЕЙНРОТОВ ПО РЕДКОСТИ (для UI)
-- ============================================================
function ESP:GetBrainrotsByRarity()
    local groups = {}
    for _, r in ipairs(BrainrotDB.Rarities) do
        groups[r.Name] = {}
    end

    local folder = GameModule:FindBrainrotFolder()
    if not folder then return groups end

    for _, child in ipairs(folder:GetDescendants()) do
        if child:IsA("Model") then
            local info = AutoFarm:GetBrainrotInfo(child)
            if info then
                local r = info.Rarity or "Common"
                if not groups[r] then groups[r] = {} end
                table.insert(groups[r], {Instance = child, Info = info})
            end
        end
    end

    return groups
end
-- ============================================================
-- EVENTS MODULE
-- Авто-события, авто-цунами, авто-клейм наград, планировщик, детект
-- ============================================================
local Events = {}
Events.__index = Events

Events.State = {
    Enabled             = false,
    AutoJoin            = false,
    AutoClaim           = false,
    AutoTsunami         = false,
    NotifyOnEvent       = true,
    JoinDelay           = 0.5,
    ClaimDelay          = 1.0,
    TsunamiCooldown     = 30,
    LastTsunami         = 0,
    LastClaim           = 0,
    LastJoin            = 0,
    ActiveEvents        = {},   -- [name] = {instance, joinedAt, claimed}
    KnownEvents         = {},   -- [name] = true
    EventHistory        = {},   -- последние N событий
    MaxHistory          = 50,
    Running             = false,
    LastScan            = 0,
    ScanInterval        = 2.0,
}

-- Известные типы событий ETFB
Events.KnownEventNames = {
    "Doom",
    "Candy",
    "Arcade",
    "Lucky Storm",
    "Rainbow",
    "Golden",
    "Tsunami",
    "Bloodmoon",
    "Admin Abuse",
    "Meteor",
    "Cosmic",
    "Paradox",
}

-- ============================================================
-- ДЕТЕКТ СОБЫТИЙ В WORKSPACE / REPLICATEDSTORAGE
-- ============================================================

-- Собрать все текущие события
function Events:ScanActiveEvents()
    local found = {}
    local eventFolder = GameModule:FindEventFolder()

    -- Сканируем папку событий
    if eventFolder then
        for _, child in ipairs(eventFolder:GetDescendants()) do
            if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder") then
                local active = child:GetAttribute("Active")
                local eventName = child:GetAttribute("EventName") or child.Name
                -- Считаем активным, если атрибут Active == true или он есть в папке Events
                if active == true or active == nil then
                    found[eventName] = {
                        Instance = child,
                        Name = eventName,
                        Active = true,
                        FoundAt = tick(),
                    }
                end
            end
        end
    end

    -- Дополнительный проход по Workspace: ищем по паттернам имён
    for _, child in ipairs(Workspace:GetChildren()) do
        local lname = child.Name:lower()
        for _, known in ipairs(self.KnownEventNames) do
            if lname:find(known:lower(), 1, true) and not found[child.Name] then
                found[child.Name] = {
                    Instance = child,
                    Name = child.Name,
                    Active = true,
                    FoundAt = tick(),
                }
            end
        end
    end

    return found
end

-- Сравнить текущие события с предыдущими, вернуть новые
function Events:DetectNewEvents()
    local current = self:ScanActiveEvents()
    local newOnes = {}

    for name, data in pairs(current) do
        if not self.State.ActiveEvents[name] then
            newOnes[name] = data
            self.State.ActiveEvents[name] = data
            self.State.KnownEvents[name] = true

            -- Пишем в историю
            table.insert(self.State.EventHistory, 1, {
                Name = name,
                Time = tick(),
                Joined = false,
                Claimed = false,
            })
            while #self.State.EventHistory > self.State.MaxHistory do
                table.remove(self.State.EventHistory)
            end

            if self.State.NotifyOnEvent then
                Notify:Push("Event: " .. name, "Новое событие обнаружено!", "info", 5)
            end

            Util:Log("Обнаружено новое событие:", name)
        end
    end

    -- Убираем те, которые больше не активны
    for name, data in pairs(self.State.ActiveEvents) do
        if not current[name] then
            self.State.ActiveEvents[name] = nil
        elseif data.Instance and not data.Instance.Parent then
            self.State.ActiveEvents[name] = nil
        end
    end

    return newOnes
end

-- ============================================================
-- ДЕЙСТВИЯ С СОБЫТИЯМИ
-- ============================================================

-- Присоединиться к событию
function Events:JoinEvent(eventName)
    if tick() - self.State.LastJoin < self.State.JoinDelay then
        return false, "cooldown"
    end

    local ok = GameModule:JoinEvent(eventName)
    if ok then
        self.State.LastJoin = tick()
        Util:Log("Присоединился к событию:", eventName)
        if self.State.ActiveEvents[eventName] then
            self.State.ActiveEvents[eventName].joinedAt = tick()
        end
        -- Отмечаем в истории
        for _, entry in ipairs(self.State.EventHistory) do
            if entry.Name == eventName and not entry.Joined then
                entry.Joined = true
                entry.JoinedAt = tick()
                break
            end
        end
    end
    return ok
end

-- Забрать награду события
function Events:ClaimReward()
    if tick() - self.State.LastClaim < self.State.ClaimDelay then
        return false, "cooldown"
    end

    local ok = GameModule:ClaimEventReward()
    if ok then
        self.State.LastClaim = tick()
        Util:Log("Награда события получена")
    end
    return ok
end

-- Триггер цунами (если игра позволяет)
function Events:TriggerTsunami(tsunamiType)
    if tick() - self.State.LastTsunami < self.State.TsunamiCooldown then
        return false, "cooldown"
    end

    local ok = GameModule:TriggerTsunami(tsunamiType)
    if ok then
        self.State.LastTsunami = tick()
        Util:Log("Цунами триггернуто:", tsunamiType or "default")
    end
    return ok
end

-- ============================================================
-- АВТО-ЛОГИКА
-- ============================================================

-- Авто-присоединение ко всем новым событиям
function Events:AutoJoinNew()
    for name, data in pairs(self.State.ActiveEvents) do
        if not data.joinedAt then
            local ok = self:JoinEvent(name)
            if ok then
                data.joinedAt = tick()
                Util:Log("Авто-join:", name)
            end
            task.wait(0.1)
        end
    end
end

-- Авто-клейм награды, если доступна
function Events:AutoClaimIfReady()
    -- Проверяем, есть ли кнопка Claim в UI / ProximityPrompt
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, desc in ipairs(playerGui:GetDescendants()) do
            if desc:IsA("TextButton") and desc.Visible then
                local txt = desc.Text:lower()
                if txt:find("claim") or txt:find("collect") or txt:find("reward") then
                    Util:ClickButton(desc)
                    self:ClaimReward()
                    return true
                end
            end
        end
    end

    -- Проверяем ProximityPrompt в Workspace
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local action = prompt.ActionText:lower()
            if action:find("claim") or action:find("collect") or action:find("reward") then
                Util:FireProximityPrompt(prompt)
                self:ClaimReward()
                return true
            end
        end
    end

    return false
end

-- Авто-цунами: если нет активного события и цунами — триггерим
function Events:AutoTsunamiTick()
    local activeTsunami = GameModule:GetActiveTsunami()
    if activeTsunami then return end
    local hasEvent = next(self.State.ActiveEvents) ~= nil
    if hasEvent then return end
    self:TriggerTsunami()
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ
-- ============================================================
function Events:Loop()
    if self.State.Running then return end
    self.State.Running = true

    task.spawn(function()
        while self.State.Running do
            if not self.State.Enabled then
                task.wait(1)
                continue
            end

            local ok, err = pcall(function()
                -- Сканируем новые события
                if tick() - self.State.LastScan > self.State.ScanInterval then
                    self:DetectNewEvents()
                    self.State.LastScan = tick()
                end

                -- Авто-join
                if self.State.AutoJoin then
                    self:AutoJoinNew()
                end

                -- Авто-claim
                if self.State.AutoClaim then
                    self:AutoClaimIfReady()
                end

                -- Авто-цунами
                if self.State.AutoTsunami then
                    self:AutoTsunamiTick()
                end
            end)

            if not ok then
                Util:Warn("Events ошибка:", err)
            end

            task.wait(0.5)
        end
    end)

    Util:Log("Events цикл запущен")
end

-- ============================================================
-- ВКЛ/ВЫКЛ
-- ============================================================
function Events:Enable()
    self.State.Enabled = true
    self:Loop()
end

function Events:Disable()
    self.State.Enabled = false
end

function Events:Toggle()
    if self.State.Enabled then self:Disable() else self:Enable() end
end

function Events:ToggleAutoJoin()   self.State.AutoJoin = not self.State.AutoJoin end
function Events:ToggleAutoClaim()  self.State.AutoClaim = not self.State.AutoClaim end
function Events:ToggleAutoTsunami()self.State.AutoTsunami = not self.State.AutoTsunami end

-- ============================================================
-- ПЛАНИРОВЩИК: запуск действия через N секунд / в определённое время
-- ============================================================
Events.ScheduledTasks = {}

function Events:Schedule(secondsFromNow, callback)
    local task = {
        ExecuteAt = tick() + secondsFromNow,
        Callback = callback,
        Cancelled = false,
    }
    table.insert(self.ScheduledTasks, task)
    return task
end

function Events:CancelScheduled(task)
    if task then task.Cancelled = true end
end

function Events:ProcessScheduled()
    local now = tick()
    for i = #self.ScheduledTasks, 1, -1 do
        local task = self.ScheduledTasks[i]
        if task.Cancelled then
            table.remove(self.ScheduledTasks, i)
        elseif now >= task.ExecuteAt then
            pcall(task.Callback)
            table.remove(self.ScheduledTasks, i)
        end
    end
end

-- Цикл планировщика (внутри основного)
task.spawn(function()
    while true do
        task.wait(0.25)
        if Events.State.Enabled then
            pcall(function() Events:ProcessScheduled() end)
        end
    end
end)

-- ============================================================
-- ИНФОРМАЦИЯ
-- ============================================================
function Events:GetActiveEvents()
    local list = {}
    for name, data in pairs(self.State.ActiveEvents) do
        table.insert(list, {
            Name = name,
            Instance = data.Instance,
            JoinedAt = data.joinedAt,
            Active = true,
        })
    end
    return list
end

function Events:GetHistory()
    return self.State.EventHistory
end

function Events:ClearHistory()
    self.State.EventHistory = {}
end

function Events:PrintStatus()
    print("========== EVENTS STATUS ==========")
    print("Enabled:", self.State.Enabled)
    print("AutoJoin:", self.State.AutoJoin, "| AutoClaim:", self.State.AutoClaim, "| AutoTsunami:", self.State.AutoTsunami)
    print("Активных событий:", #self:GetActiveEvents())
    for _, ev in ipairs(self:GetActiveEvents()) do
        print("  -", ev.Name, ev.JoinedAt and ("joined " .. string.format("%.0f", tick() - ev.JoinedAt) .. "s ago") or "not joined")
    end
    print("История (последние 10):")
    for i = 1, math.min(10, #self.State.EventHistory) do
        local h = self.State.EventHistory[i]
        print(string.format("  %s | %s | joined=%s claimed=%s",
            h.Name,
            os.date("%H:%M:%S", math.floor(h.Time)),
            tostring(h.Joined), tostring(h.Claimed)))
    end
    print("===================================")
end
-- ============================================================
-- ANTI-AFK / REJOIN MODULE
-- Обход AFK-кика, авто-реконнект, queue_on_teleport, ping-стабилизация
-- ============================================================
local AntiAFK = {}
AntiAFK.__index = AntiAFK

AntiAFK.State = {
    Enabled         = false,
    AutoRejoin      = false,
    AutoReconnect   = false,
    PingFix         = false,
    IdleReset       = false,
    JumpInterval    = 60,       -- раз в N секунд прыгаем
    MoveInterval    = 45,       -- раз в N секунд двигаемся
    ChatInterval    = 90,       -- раз в N секунд пишем в чат (опционально)
    LastJump        = 0,
    LastMove        = 0,
    LastChat        = 0,
    LastAction      = 0,
    ReconnectDelay  = 5,
    MaxReconnects   = 50,
    ReconnectCount  = 0,
    LastRejoinTime  = 0,
    QueueOnTeleport = true,
    QueueScript     = "",       -- скрипт, который перезапустится после телепорта
    ServerHopEnabled = false,
    HopRegions      = {},
    HopAttempts     = 0,
    Connection      = nil,
    Heartbeat       = nil,
}

-- ============================================================
-- ANTI-AFK ЛОГИКА
-- ============================================================

-- Симулировать активность через VirtualUser
function AntiAFK:SimulateActivity()
    -- Виртуальный клик — сбрасывает AFK-таймер большинства игр
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)

    -- Небольшое движение камеры
    pcall(function()
        local cam = Workspace.CurrentCamera
        if cam then
            cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.1), 0)
        end
    end)

    self.State.LastAction = tick()
end

-- Прыгнуть (ChangeState)
function AntiAFK:Jump()
    local hum = Util:GetHum()
    if hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
    self.State.LastJump = tick()
end

-- Двинуться (нажать W на мгновение через VirtualInputManager)
function AntiAFK:Move()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
        task.wait(0.15)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
    end)
    self.State.LastMove = tick()
end

-- Отправить сообщение в чат (некоторые игры считают это активностью)
function AntiAFK:Chat(text)
    text = text or "."
    pcall(function()
        local chatRemote = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            or ReplicatedStorage:FindFirstChild("Chat")
        if chatRemote then
            local sayMessage = chatRemote:FindFirstChild("SayMessageRequest")
            if sayMessage then
                sayMessage:FireServer(text, "All")
            end
        end
    end)
    self.State.LastChat = tick()
end

-- ============================================================
-- PING FIX
-- ============================================================
-- На низком FPS Roblox считает меньше кадров — AntiAFK иногда не проходит.
-- Мы форсим минимальный FPS и подавляем предупреждения о пинге.
function AntiAFK:EnablePingFix()
    self.State.PingFix = true

    -- Отключаем встроенный AFK-таймер клиента (если доступен)
    pcall(function()
        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCore("ResetButtonCallback", false)
    end)

    -- Форсим FPS на 60 (у Xeno обычно есть setfpscap)
    if Executor.setfpscap then
        pcall(Executor.setfpscap, 60)
    end

    -- Подавляем Idled event у игрока
    if LocalPlayer.Idled then
        if self.State.Connection then self.State.Connection:Disconnect() end
        self.State.Connection = LocalPlayer.Idled:Connect(function()
            if not self.State.Enabled then return end
            self:SimulateActivity()
            self:Jump()
            self:Move()
            Util:Log("AntiAFK: Idled — симулирована активность")
        end)
    end

    Util:Log("PingFix включён")
end

function AntiAFK:DisablePingFix()
    self.State.PingFix = false
    if self.State.Connection then
        self.State.Connection:Disconnect()
        self.State.Connection = nil
    end
end

-- ============================================================
-- AUTO REJOIN (при кике или отключении)
-- ============================================================

-- Сохранить текущий скрипт для перезапуска после телепорта
function AntiAFK:SaveQueueScript()
    if not self.State.QueueOnTeleport then return end
    if self.State.QueueScript == "" then
        Util:Log("AntiAFK: QueueScript пуст, rejoin сработает без авто-запуска")
        return
    end
    pcall(function()
        Executor.queue_on_teleport(self.State.QueueScript)
    end)
end

-- Ре-джойн в тот же сервер
function AntiAFK:Rejoin()
    self:SaveQueueScript()

    local jobId = game.JobId
    local placeId = game.PlaceId
    if not jobId or jobId == "" then
        Util:Warn("AntiAFK: JobId пуст, ре-джойн невозможен")
        return false
    end

    self.State.LastRejoinTime = tick()
    self.State.ReconnectCount = self.State.ReconnectCount + 1

    local ok = pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
    end)

    if ok then
        Util:Log("AntiAFK: ре-джойн выполнен")
    else
        Util:Warn("AntiAFK: ре-джойн не удался")
    end
    return ok
end

-- Перезаход на другой сервер
function AntiAFK:ServerHop()
    self.State.HopAttempts = self.State.HopAttempts + 1
    self:SaveQueueScript()

    local placeId = game.PlaceId
    local ok, servers = pcall(function()
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?limit=100",
            placeId
        )
        local res = Executor.request({
            Url = url,
            Method = "GET",
        })
        if res.StatusCode == 200 then
            return HttpService:JSONDecode(res.Body)
        end
        return nil
    end)

    if not ok or not servers or not servers.data then
        Util:Warn("AntiAFK: сервера не получены, fallback на ре-джойн")
        return self:Rejoin()
    end

    local candidates = {}
    for _, srv in ipairs(servers.data) do
        if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
            table.insert(candidates, srv.id)
        end
    end

    if #candidates == 0 then
        Util:Warn("AntiAFK: нет свободных серверов")
        return false
    end

    local target = candidates[math.random(1, #candidates)]
    local teleportOk = pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, target, LocalPlayer)
    end)

    Util:Log("AntiAFK: server hop ->", target, teleportOk and "OK" or "FAIL")
    return teleportOk
end

-- Включение авто-реконнекта
function AntiAFK:EnableAutoReconnect()
    self.State.AutoReconnect = true

    if self.State.Heartbeat then
        self.State.Heartbeat:Disconnect()
    end

    self.State.Heartbeat = RunService.Heartbeat:Connect(function()
        if not self.State.AutoReconnect then return end

        -- Если игрок потерял связь с сервером (ping > 5000 или нет сети)
        local ping = 0
        pcall(function()
            ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)

        if ping > 5000 then
            Util:Log("AntiAFK: ping критический", ping, "-> ре-джойн")
            self:Rejoin()
        end
    end)

    -- Слушаем OnClientEvent об ошибках / disconnect
    pcall(function()
        if LocalPlayer.OnTeleport then
            LocalPlayer.OnTeleport:Connect(function(state)
                if state == Enum.TeleportState.Started then
                    self:SaveQueueScript()
                end
            end)
        end
    end)

    Util:Log("AutoReconnect включён")
end

function AntiAFK:DisableAutoReconnect()
    self.State.AutoReconnect = false
    if self.State.Heartbeat then
        self.State.Heartbeat:Disconnect()
        self.State.Heartbeat = nil
    end
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ ANTI-AFK
-- ============================================================
function AntiAFK:Loop()
    if self.State.Running then return end
    self.State.Running = true

    task.spawn(function()
        while self.State.Running do
            if not self.State.Enabled then
                task.wait(1)
                continue
            end

            local now = tick()

            -- Прыжок раз в JumpInterval
            if now - self.State.LastJump > self.State.JumpInterval then
                self:Jump()
            end

            -- Движение раз в MoveInterval
            if now - self.State.LastMove > self.State.MoveInterval then
                self:Move()
            end

            -- Клик раз в 15 секунд для стабильности
            if now - self.State.LastAction > 15 then
                self:SimulateActivity()
            end

            task.wait(5)
        end
    end)

    Util:Log("AntiAFK цикл запущен")
end

-- ============================================================
-- ВКЛ/ВЫКЛ
-- ============================================================
function AntiAFK:Enable()
    self.State.Enabled = true
    self:EnablePingFix()
    self:Loop()
end

function AntiAFK:Disable()
    self.State.Enabled = false
    self:DisablePingFix()
end

function AntiAFK:Toggle()
    if self.State.Enabled then self:Disable() else self:Enable() end
end

-- ============================================================
-- УТИЛИТЫ ДЛЯ UI
-- ============================================================
function AntiAFK:SetJumpInterval(sec)
    self.State.JumpInterval = math.max(5, sec)
end

function AntiAFK:SetMoveInterval(sec)
    self.State.MoveInterval = math.max(5, sec)
end

function AntiAFK:SetQueueScript(script)
    self.State.QueueScript = script or ""
end

function AntiAFK:GetStatus()
    return {
        Enabled         = self.State.Enabled,
        AutoReconnect   = self.State.AutoReconnect,
        AutoRejoin      = self.State.AutoRejoin,
        PingFix         = self.State.PingFix,
        ReconnectCount  = self.State.ReconnectCount,
        LastAction      = self.State.LastAction,
        LastRejoin      = self.State.LastRejoinTime,
    }
end

function AntiAFK:PrintStatus()
    local s = self:GetStatus()
    print("========== ANTI-AFK STATUS ==========")
    print("Enabled:", s.Enabled, "| AutoReconnect:", s.AutoReconnect, "| PingFix:", s.PingFix)
    print("Reconnects:", s.ReconnectCount)
    if s.LastRejoin > 0 then
        print("Last rejoin:", string.format("%.0f сек назад", tick() - s.LastRejoin))
    end
    print("=====================================")
end

-- ============================================================
-- СОХРАНЕНИЕ/ЗАГРУЗКА СОСТОЯНИЯ (для queue_on_teleport)
-- ============================================================
function AntiAFK:SaveState()
    local state = {
        Enabled       = self.State.Enabled,
        AutoReconnect = self.State.AutoReconnect,
        PingFix       = self.State.PingFix,
        JumpInterval  = self.State.JumpInterval,
        MoveInterval  = self.State.MoveInterval,
        SavedAt       = tick(),
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, state)
    if ok then
        ensureFolder()
        Executor.writefile("ETFB_Hub/antiafk.json", encoded)
    end
end

function AntiAFK:LoadState()
    if not Executor.isfile("ETFB_Hub/antiafk.json") then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(Executor.readfile("ETFB_Hub/antiafk.json"))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if k ~= "SavedAt" and self.State[k] ~= nil then
                self.State[k] = v
            end
        end
        Util:Log("AntiAFK: состояние загружено")
    end
end
-- ============================================================
-- NOTIFICATION SYSTEM
-- Тосты в правом верхнем углу, очередь, типы, авто-скрытие, звуки
-- ============================================================
local Notify = {}
Notify.__index = Notify

Notify.State = {
    Root            = nil,
    Queue           = {},
    Active          = {},
    MaxActive       = 5,
    DefaultDuration = 4,
    SoundEnabled    = true,
    SoundId         = "rbxassetid://4590662766",   -- вежливый "ding"
    SoundVolume     = 0.4,
    OffsetY         = 20,
    OffsetX         = 20,
    Spacing         = 6,
    Enabled         = true,
}

-- Типы нотификаций с цветами и иконками
Notify.Types = {
    info    = {Color = Color3.fromRGB(80, 160, 255),  Icon = "i", Title = "Info"},
    success = {Color = Color3.fromRGB(80, 220, 120),  Icon = "✓", Title = "Success"},
    warn    = {Color = Color3.fromRGB(255, 200, 60),  Icon = "!", Title = "Warning"},
    error   = {Color = Color3.fromRGB(255, 80, 80),   Icon = "×", Title = "Error"},
    event   = {Color = Color3.fromRGB(180, 80, 255),  Icon = "★", Title = "Event"},
    money   = {Color = Color3.fromRGB(255, 215, 0),   Icon = "$", Title = "Money"},
}

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================
function Notify:EnsureRoot()
    if self.State.Root and self.State.Root.Parent then return self.State.Root end

    local parent = CoreGui
    if not pcall(function() return CoreGui.Name end) then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local existing = parent:FindFirstChild("ETFB_Notify")
    if existing then existing:Destroy() end

    self.State.Root = InstanceHelper:Create("ScreenGui", {
        Name = "ETFB_Notify",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 10,
    }, parent)

    return self.State.Root
end

-- ============================================================
-- ЗВУК
-- ============================================================
function Notify:PlaySound()
    if not self.State.SoundEnabled then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = self.State.SoundId
        sound.Volume = self.State.SoundVolume
        sound.Parent = self.State.Root
        sound:Play()
        task.delay(2, function()
            if sound then sound:Destroy() end
        end)
    end)
end

-- ============================================================
-- СОЗДАНИЕ ТОСТА
-- ============================================================
function Notify:CreateToast(config)
    local typeData = self.Types[config.Type or "info"] or self.Types.info

    local toast = InstanceHelper:Create("Frame", {
        Name = "Toast",
        Size = UDim2.new(0, 320, 0, 0),
        Position = UDim2.new(1, -340, 0, self.State.OffsetY),
        BackgroundColor3 = Color3.fromRGB(20, 20, 25),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        AnchorPoint = Vector2.new(0, 0),
    }, self.State.Root)

    InstanceHelper:Create("UICorner", {
        CornerRadius = UDim.new(0, 8),
    }, toast)

    local stroke = InstanceHelper:Create("UIStroke", {
        Color = typeData.Color,
        Thickness = 1.5,
        Transparency = 1,
    }, toast)

    -- Левая полоса цвета типа
    local colorBar = InstanceHelper:Create("Frame", {
        Name = "ColorBar",
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = typeData.Color,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, toast)

    -- Иконка
    local iconBg = InstanceHelper:Create("Frame", {
        Name = "IconBg",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0, 14, 0, 12),
        BackgroundColor3 = typeData.Color,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, toast)

    InstanceHelper:Create("UICorner", {CornerRadius = UDim.new(1, 0)}, iconBg)

    local iconLabel = InstanceHelper:Create("TextLabel", {
        Name = "Icon",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = typeData.Icon,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextTransparency = 1,
    }, iconBg)

    -- Заголовок
    local titleLabel = InstanceHelper:Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -60, 0, 18),
        Position = UDim2.new(0, 48, 0, 10),
        BackgroundTransparency = 1,
        Text = config.Title or typeData.Title,
        TextColor3 = typeData.Color,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
    }, toast)

    -- Текст
    local textLabel = InstanceHelper:Create("TextLabel", {
        Name = "Text",
        Size = UDim2.new(1, -60, 0, 32),
        Position = UDim2.new(0, 48, 0, 30),
        BackgroundTransparency = 1,
        Text = config.Text or "",
        TextColor3 = Config.UIText,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTransparency = 1,
    }, toast)

    -- Прогресс-бар
    local progressBg = InstanceHelper:Create("Frame", {
        Name = "ProgressBg",
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Color3.fromRGB(40, 40, 45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, toast)

    local progressBar = InstanceHelper:Create("Frame", {
        Name = "ProgressBar",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = typeData.Color,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, progressBg)

    return toast, {
        Stroke = stroke,
        ColorBar = colorBar,
        IconBg = iconBg,
        IconLabel = iconLabel,
        Title = titleLabel,
        Text = textLabel,
        ProgressBg = progressBg,
        ProgressBar = progressBar,
        Type = config.Type or "info",
        Duration = config.Duration or self.State.DefaultDuration,
        CreatedAt = tick(),
        Dismissed = false,
    }
end

-- ============================================================
-- АНИМАЦИЯ ПОЯВЛЕНИЯ / ИСЧЕЗНОВЕНИЯ
-- ============================================================
function Notify:AnimateIn(toast, parts, height, callback)
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- Высота
    toast.Size = UDim2.new(0, 320, 0, 0)
    TweenService:Create(toast, tweenInfo, {
        Size = UDim2.new(0, 320, 0, height),
        BackgroundTransparency = 0,
    }):Play()

    -- Смещение справа
    local startX = 340
    toast.Position = UDim2.new(1, startX, 0, toast.Position.Y.Offset)
    TweenService:Create(toast, tweenInfo, {
        Position = UDim2.new(1, -340, 0, toast.Position.Y.Offset),
    }):Play()

    -- Элементы
    TweenService:Create(parts.Stroke, tweenInfo, {Transparency = 0.3}):Play()
    TweenService:Create(parts.ColorBar, tweenInfo, {BackgroundTransparency = 0}):Play()
    TweenService:Create(parts.IconBg, tweenInfo, {BackgroundTransparency = 0}):Play()
    TweenService:Create(parts.IconLabel, tweenInfo, {TextTransparency = 0}):Play()
    TweenService:Create(parts.Title, tweenInfo, {TextTransparency = 0}):Play()
    TweenService:Create(parts.Text, tweenInfo, {TextTransparency = 0}):Play()
    TweenService:Create(parts.ProgressBg, tweenInfo, {BackgroundTransparency = 0.5}):Play()

    -- Прогресс-бар (линейный, от 1 до 0)
    TweenService:Create(parts.ProgressBar,
        TweenInfo.new(parts.Duration, Enum.EasingStyle.Linear),
        {Size = UDim2.new(0, 0, 1, 0)}):Play()

    if callback then task.delay(0.25, callback) end
end

function Notify:AnimateOut(toast, parts, callback)
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

    TweenService:Create(toast, tweenInfo, {
        Size = UDim2.new(0, 320, 0, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, 340, 0, toast.Position.Y.Offset),
    }):Play()

    TweenService:Create(parts.Stroke, tweenInfo, {Transparency = 1}):Play()
    TweenService:Create(parts.ColorBar, tweenInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(parts.IconBg, tweenInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(parts.IconLabel, tweenInfo, {TextTransparency = 1}):Play()
    TweenService:Create(parts.Title, tweenInfo, {TextTransparency = 1}):Play()
    TweenService:Create(parts.Text, tweenInfo, {TextTransparency = 1}):Play()

    task.delay(0.25, function()
        if toast then toast:Destroy() end
        if callback then callback() end
    end)
end

-- ============================================================
-- ПЕРЕСЧЁТ ПОЗИЦИЙ (стек сверху вниз)
-- ============================================================
function Notify:Reposition()
    local y = self.State.OffsetY
    for _, entry in ipairs(self.State.Active) do
        if entry.Toast and entry.Toast.Parent then
            local h = entry.Toast.AbsoluteSize.Y
            if h == 0 then h = entry.Height end
            TweenService:Create(entry.Toast,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Position = UDim2.new(1, -340, 0, y)}):Play()
            y = y + h + self.State.Spacing
        end
    end
end

-- ============================================================
-- ПУБЛИЧНЫЙ API
-- ============================================================
function Notify:Push(title, text, type, duration)
    if not self.State.Enabled then return end
    self:EnsureRoot()

    -- Ограничиваем активные
    if #self.State.Active >= self.State.MaxActive then
        -- Досрочно убираем самый старый
        local oldest = self.State.Active[1]
        if oldest then
            self:Dismiss(oldest)
        end
    end

    -- Считаем высоту по тексту
    local textLen = #(text or "")
    local height = 56
    if textLen > 60 then height = 72 end
    if textLen > 120 then height = 88 end

    local toast, parts = self:CreateToast({
        Title = title,
        Text = text,
        Type = type or "info",
        Duration = duration or self.State.DefaultDuration,
    })

    local entry = {
        Toast = toast,
        Parts = parts,
        Height = height,
        Duration = parts.Duration,
        CreatedAt = tick(),
    }

    table.insert(self.State.Active, entry)

    self:AnimateIn(toast, parts, height, function()
        self:Reposition()
    end)

    if self.State.SoundEnabled then
        self:PlaySound()
    end

    -- Авто-dismiss
    task.delay(parts.Duration, function()
        if not entry.Dismissed then
            self:Dismiss(entry)
        end
    end)

    return entry
end

function Notify:Dismiss(entry)
    if not entry or entry.Dismissed then return end
    entry.Dismissed = true

    -- Убираем из очереди
    for i, e in ipairs(self.State.Active) do
        if e == entry then
            table.remove(self.State.Active, i)
            break
        end
    end

    self:AnimateOut(entry.Toast, entry.Parts, function()
        self:Reposition()
    end)
end

function Notify:Clear()
    for _, entry in ipairs(self.State.Active) do
        entry.Dismissed = true
        if entry.Toast then entry.Toast:Destroy() end
    end
    self.State.Active = {}
end

-- ============================================================
-- УДОБНЫЕ ОБЁРТКИ
-- ============================================================
function Notify:Info(title, text, duration)    return self:Push(title, text, "info", duration) end
function Notify:Success(title, text, duration) return self:Push(title, text, "success", duration) end
function Notify:Warn(title, text, duration)    return self:Push(title, text, "warn", duration) end
function Notify:Error(title, text, duration)   return self:Push(title, text, "error", duration) end
function Notify:Event(title, text, duration)   return self:Push(title, text, "event", duration) end
function Notify:Money(title, text, duration)   return self:Push(title, text, "money", duration) end

-- ============================================================
-- НАСТРОЙКИ
-- ============================================================
function Notify:SetSoundEnabled(v) self.State.SoundEnabled = v end
function Notify:SetSoundId(id)     self.State.SoundId = id end
function Notify:SetVolume(v)       self.State.SoundVolume = math.clamp(v, 0, 1) end
function Notify:SetDefaultDuration(d) self.State.DefaultDuration = math.max(1, d) end
function Notify:SetMaxActive(n)    self.State.MaxActive = math.max(1, n) end

function Notify:SetEnabled(v)
    self.State.Enabled = v
    if not v then self:Clear() end
end

-- ============================================================
-- КОНВЕРТАЦИЯ ДЕНЕГ В СТРОКУ (для Money-нотификаций)
-- ============================================================
function Notify:MoneyPush(amount)
    self:Money("+ $" .. BrainrotDB:FormatIncome(amount):gsub("/s", ""), "Получено")
end
-- ============================================================
-- KEYBIND MANAGER
-- Реестр привязок, обработка клавиш, конфликты, сохранение в файл
-- ============================================================
local Keybinds = {}
Keybinds.__index = Keybinds

Keybinds.State = {
    Binds           = {},   -- [actionName] = {Key = Enum.KeyCode, Callback = fn, Description = str, Category = str}
    Enabled         = true,
    SuppressGame    = true, -- блокировать игровой ввод при совпадении
    ChatOpen         = false,
    IgnoreInChat    = true,
    Registry        = {},   -- быстрый доступ: [KeyCode] = {list of actions}
    ConfigPath      = "ETFB_Hub/keybinds.json",
    LastTrigger     = {},
    Cooldown        = 0.15,
}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ============================================================
local KeyCodeNames = {}
for _, kc in ipairs(Enum.KeyCode:GetEnumItems()) do
    KeyCodeNames[kc] = kc.Name
end

local function keyToString(keyCode)
    if not keyCode then return "None" end
    return KeyCodeNames[keyCode] or keyCode.Name or "Unknown"
end

local function stringToKey(str)
    if not str or str == "None" then return nil end
    for _, kc in ipairs(Enum.KeyCode:GetEnumItems()) do
        if kc.Name == str then return kc end
    end
    return nil
end

-- ============================================================
-- РЕГИСТРАЦИЯ
-- ============================================================
function Keybinds:Register(actionName, keyCode, callback, options)
    options = options or {}
    if type(actionName) ~= "string" or actionName == "" then
        Util:Warn("Keybinds:Register — пустое имя действия")
        return false
    end
    if type(callback) ~= "function" then
        Util:Warn("Keybinds:Register — callback не функция для", actionName)
        return false
    end

    -- Если действие уже есть — обновляем
    self:Unregister(actionName)

    local entry = {
        Name        = actionName,
        Key         = keyCode,
        Callback    = callback,
        Description = options.Description or "",
        Category    = options.Category or "General",
        Cooldown    = options.Cooldown or self.State.Cooldown,
        OnlyInGame  = options.OnlyInGame ~= false,
    }

    self.State.Binds[actionName] = entry

    if keyCode then
        if not self.State.Registry[keyCode] then
            self.State.Registry[keyCode] = {}
        end
        table.insert(self.State.Registry[keyCode], actionName)
    end

    Util:Log("Keybind зарегистрирован:", actionName, "->", keyToString(keyCode))
    return true
end

function Keybinds:Unregister(actionName)
    local entry = self.State.Binds[actionName]
    if not entry then return false end

    if entry.Key and self.State.Registry[entry.Key] then
        for i, name in ipairs(self.State.Registry[entry.Key]) do
            if name == actionName then
                table.remove(self.State.Registry[entry.Key], i)
                break
            end
        end
    end

    self.State.Binds[actionName] = nil
    return true
end

function Keybinds:Clear()
    self.State.Binds = {}
    self.State.Registry = {}
end

-- ============================================================
-- ИЗМЕНЕНИЕ ПРИВЯЗКИ
-- ============================================================
function Keybinds:SetKey(actionName, keyCode)
    local entry = self.State.Binds[actionName]
    if not entry then return false, "not_registered" end

    -- Убираем старую связь
    if entry.Key and self.State.Registry[entry.Key] then
        for i, name in ipairs(self.State.Registry[entry.Key]) do
            if name == actionName then
                table.remove(self.State.Registry[entry.Key], i)
                break
            end
        end
    end

    entry.Key = keyCode

    if keyCode then
        if not self.State.Registry[keyCode] then
            self.State.Registry[keyCode] = {}
        end
        table.insert(self.State.Registry[keyCode], actionName)
    end

    self:Save()
    return true
end

function Keybinds:GetKey(actionName)
    local entry = self.State.Binds[actionName]
    return entry and entry.Key or nil
end

function Keybinds:GetKeyString(actionName)
    return keyToString(self:GetKey(actionName))
end

function Keybinds:GetAll()
    return self.State.Binds
end

-- ============================================================
-- КОНФЛИКТЫ
-- ============================================================
function Keybinds:GetConflicts()
    local conflicts = {}
    for keyCode, actions in pairs(self.State.Registry) do
        if #actions > 1 then
            conflicts[keyCode] = actions
        end
    end
    return conflicts
end

function Keybinds:HasConflict(actionName)
    local entry = self.State.Binds[actionName]
    if not entry or not entry.Key then return false end
    local list = self.State.Registry[entry.Key]
    return list and #list > 1
end

-- ============================================================
-- ОБРАБОТКА НАЖАТИЙ
-- ============================================================
function Keybinds:HandleInput(input, gameProcessed)
    if not self.State.Enabled then return end

    -- Игнор в чате
    if self.State.IgnoreInChat and self.State.ChatOpen then return end

    -- Игнор, если занято игрой (например, TextBox)
    if gameProcessed and self.State.SuppressGame then
        -- проверим: если фокус в TextBox, не перехватываем
        local focused = UserInputService:GetFocusedTextBox()
        if focused then return end
    end

    local keyCode = input.KeyCode
    if keyCode == Enum.KeyCode.Unknown then return end

    local actions = self.State.Registry[keyCode]
    if not actions or #actions == 0 then return end

    for _, actionName in ipairs(actions) do
        local entry = self.State.Binds[actionName]
        if entry then
            local now = tick()
            local last = self.State.LastTrigger[actionName] or 0
            if now - last >= entry.Cooldown then
                self.State.LastTrigger[actionName] = now
                task.spawn(function()
                    local ok, err = pcall(entry.Callback, keyCode)
                    if not ok then
                        Util:Warn("Keybind", actionName, "ошибка:", err)
                    end
                end)
            end
        end
    end
end

-- ============================================================
-- ОТСЛЕЖИВАНИЕ ЧАТА
-- ============================================================
function Keybinds:WatchChat()
    pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
        if not playerGui then return end

        local chat = playerGui:FindFirstChild("Chat")
        if not chat then return end

        local frame = chat:FindFirstChild("Frame")
        if not frame then return end

        local chatBar = frame:FindFirstChild("ChatBar")
        if not chatBar then return end

        local box = chatBar:FindFirstChild("TextBox")
        if box then
            box.Focused:Connect(function()
                self.State.ChatOpen = true
            end)
            box.FocusLost:Connect(function()
                self.State.ChatOpen = false
            end)
        end
    end)
end

-- ============================================================
-- СОХРАНЕНИЕ / ЗАГРУЗКА
-- ============================================================
function Keybinds:Save()
    ensureFolder()
    local data = {}
    for name, entry in pairs(self.State.Binds) do
        data[name] = {
            Key = entry.Key and entry.Key.Name or nil,
            Description = entry.Description,
            Category = entry.Category,
        }
    end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then
        Executor.writefile(self.State.ConfigPath, encoded)
    end
end

function Keybinds:Load()
    if not Executor.isfile(self.State.ConfigPath) then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(Executor.readfile(self.State.ConfigPath))
    end)
    if not ok or type(data) ~= "table" then return end

    for name, info in pairs(data) do
        if self.State.Binds[name] and info.Key then
            local keyCode = stringToKey(info.Key)
            if keyCode then
                self:SetKey(name, keyCode)
            end
        end
    end
    Util:Log("Keybinds: загружено из файла")
end

-- ============================================================
-- UI: ЗАХВАТ КЛАВИШИ
-- ============================================================
-- Использование: Keybinds:StartCapture(function(keyCode) ... end)
function Keybinds:StartCapture(callback)
    if self.State.Capturing then return end
    self.State.Capturing = true

    local connection
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not self.State.Capturing then
            connection:Disconnect()
            return
        end

        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == Enum.KeyCode.Unknown then return end

        self.State.Capturing = false
        connection:Disconnect()

        if callback then callback(input.KeyCode) end
    end)

    -- Отмена по Escape
    local cancelConn
    cancelConn = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape and self.State.Capturing then
            self.State.Capturing = false
            connection:Disconnect()
            cancelConn:Disconnect()
            if callback then callback(nil) end
        end
    end)
end

-- ============================================================
-- ПОДПИСКА НА ВВОД
-- ============================================================
function Keybinds:Start()
    if self.State.InputConnection then return end

    self:WatchChat()

    self.State.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        self:HandleInput(input, gameProcessed)
    end)

    Util:Log("Keybinds: обработчик запущен")
end

function Keybinds:Stop()
    if self.State.InputConnection then
        self.State.InputConnection:Disconnect()
        self.State.InputConnection = nil
    end
end

-- ============================================================
-- ДЕФОЛТНЫЕ ПРИВЯЗКИ (регистрируются в Main Init)
-- ============================================================
Keybinds.DefaultActions = {
    {
        Name = "ToggleUI",
        Key = Enum.KeyCode.RightShift,
        Category = "UI",
        Description = "Показать/скрыть меню",
    },
    {
        Name = "ToggleAutoFarm",
        Key = Enum.KeyCode.F1,
        Category = "Farm",
        Description = "Вкл/выкл автофарм",
    },
    {
        Name = "ToggleESP",
        Key = Enum.KeyCode.F2,
        Category = "Visual",
        Description = "Вкл/выкл ESP",
    },
    {
        Name = "ToggleFly",
        Key = Enum.KeyCode.F3,
        Category = "Movement",
        Description = "Вкл/выкл полёт",
    },
    {
        Name = "ToggleGodMode",
        Key = Enum.KeyCode.F4,
        Category = "Player",
        Description = "Вкл/выкл godmode",
    },
    {
        Name = "ToggleNoclip",
        Key = Enum.KeyCode.F5,
        Category = "Movement",
        Description = "Вкл/выкл noclip",
    },
    {
        Name = "TeleportBase",
        Key = Enum.KeyCode.G,
        Category = "Teleport",
        Description = "Телепорт на базу",
    },
    {
        Name = "TeleportSell",
        Key = Enum.KeyCode.H,
        Category = "Teleport",
        Description = "Телепорт к продаже",
    },
    {
        Name = "TeleportBest",
        Key = Enum.KeyCode.B,
        Category = "Teleport",
        Description = "Телепорт к лучшему брейнроту",
    },
    {
        Name = "Rejoin",
        Key = Enum.KeyCode.RightControl,
        Category = "Utility",
        Description = "Перезаход в сервер",
    },
}

-- ============================================================
-- ЭКСПОРТ В UI: КАТЕГОРИЗОВАННЫЙ СПИСОК
-- ============================================================
function Keybinds:GetByCategory()
    local groups = {}
    for _, entry in pairs(self.State.Binds) do
        groups[entry.Category] = groups[entry.Category] or {}
        table.insert(groups[entry.Category], entry)
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b) return a.Name < b.Name end)
    end
    return groups
end

function Keybinds:PrintStatus()
    print("========== KEYBINDS ==========")
    print("Всего:", 0)
    local count = 0
    for _, _ in pairs(self.State.Binds) do count = count + 1 end
    print("Всего:", count)
    for name, entry in pairs(self.State.Binds) do
        print(string.format("  %-20s -> %-12s [%s]", name, keyToString(entry.Key), entry.Category))
    end
    local conflicts = self:GetConflicts()
    if next(conflicts) then
        print("КОНФЛИКТЫ:")
        for keyCode, actions in pairs(conflicts) do
            print("  " .. keyToString(keyCode) .. ": " .. table.concat(actions, ", "))
        end
    end
    print("==============================")
end
-- ============================================================
-- CHAT COMMANDS MODULE
-- Команды через чат с префиксом, алиасы, help, автодополнение
-- ============================================================
local ChatCommands = {}
ChatCommands.__index = ChatCommands

ChatCommands.State = {
    Prefix          = ";",           -- префикс команд
    Enabled         = true,
    Commands        = {},            -- [name] = {Callback, Description, Usage, Aliases, Category}
    Aliases         = {},            -- [alias] = canonical name
    History         = {},            -- история команд
    MaxHistory      = 50,
    LastRun         = {},
    Hooked          = false,
    HookConnection  = nil,
    LogExecuted     = true,
    ExecuteDelay    = 0.05,
}

-- ============================================================
-- РЕГИСТРАЦИЯ
-- ============================================================
function ChatCommands:Register(name, callback, options)
    options = options or {}
    if type(name) ~= "string" or name == "" then return false end
    if type(callback) ~= "function" then return false end

    name = name:lower()
    self.State.Commands[name] = {
        Name = name,
        Callback = callback,
        Description = options.Description or "",
        Usage = options.Usage or ("<prefix>" .. name),
        Aliases = options.Aliases or {},
        Category = options.Category or "General",
        Cooldown = options.Cooldown or 0.1,
    }

    -- Алиасы
    for _, alias in ipairs(options.Aliases or {}) do
        self.State.Aliases[alias:lower()] = name
    end

    return true
end

function ChatCommands:Unregister(name)
    name = name:lower()
    local cmd = self.State.Commands[name]
    if not cmd then return false end
    for _, alias in ipairs(cmd.Aliases or {}) do
        self.State.Aliases[alias:lower()] = nil
    end
    self.State.Commands[name] = nil
    return true
end

function ChatCommands:Clear()
    self.State.Commands = {}
    self.State.Aliases = {}
end

-- ============================================================
-- ПАРСЕР
-- ============================================================
-- Разбирает строку на команду и аргументы с учётом кавычек
-- Пример: .tp "My Base" 10 20 -> {"tp", "My Base", "10", "20"}
local function parseArgs(input)
    local args = {}
    local current = ""
    local inQuotes = false
    local quoteChar = nil

    for i = 1, #input do
        local ch = input:sub(i, i)
        if inQuotes then
            if ch == quoteChar then
                inQuotes = false
                quoteChar = nil
            else
                current = current .. ch
            end
        else
            if ch == '"' or ch == "'" then
                inQuotes = true
                quoteChar = ch
            elseif ch == " " or ch == "\t" then
                if #current > 0 then
                    table.insert(args, current)
                    current = ""
                end
            else
                current = current .. ch
            end
        end
    end
    if #current > 0 then
        table.insert(args, current)
    end
    return args
end

-- ============================================================
-- ВЫПОЛНЕНИЕ КОМАНДЫ
-- ============================================================
function ChatCommands:Execute(commandName, args)
    commandName = commandName:lower()

    -- Резолвим алиас
    if self.State.Aliases[commandName] then
        commandName = self.State.Aliases[commandName]
    end

    local cmd = self.State.Commands[commandName]
    if not cmd then
        Notify:Warn("Команда", "Не найдено: " .. commandName)
        return false, "not_found"
    end

    -- Cooldown
    local last = self.State.LastRun[commandName] or 0
    if tick() - last < cmd.Cooldown then
        return false, "cooldown"
    end
    self.State.LastRun[commandName] = tick()

    -- История
    table.insert(self.State.History, 1, {
        Command = commandName,
        Args = args,
        Time = tick(),
    })
    while #self.State.History > self.State.MaxHistory do
        table.remove(self.State.History)
    end

    -- Выполняем
    task.spawn(function()
        local ok, err = pcall(cmd.Callback, args)
        if not ok then
            Util:Warn("Команда", commandName, "ошибка:", err)
            Notify:Error("Ошибка", tostring(err))
        end
    end)

    if self.State.LogExecuted then
        Util:Log("Команда выполнена:", commandName, table.concat(args, " "))
    end

    return true
end

-- ============================================================
-- ОБРАБОТКА СООБЩЕНИЙ ЧАТА
-- ============================================================
function ChatCommands:HandleMessage(message)
    if not self.State.Enabled then return end
    if type(message) ~= "string" then return end

    local prefix = self.State.Prefix
    if message:sub(1, #prefix) ~= prefix then return end

    local body = message:sub(#prefix + 1)
    if #body == 0 then return end

    local args = parseArgs(body)
    if #args == 0 then return end

    local cmdName = table.remove(args, 1)
    self:Execute(cmdName, args)
end

-- ============================================================
-- ХУК НА ЧАТ
-- ============================================================
-- Вариант 1: RemoteEvent SayMessageRequest
-- Вариант 2: TextChatService
-- Вариант 3: hookfunction на SendAsync
function ChatCommands:HookSayMessage()
    local ok = pcall(function()
        local chatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 5)
        if not chatEvents then return end

        local onMessageDone = chatEvents:FindFirstChild("OnMessageDoneFiltering")
        if not onMessageDone then return end

        local connection = onMessageDone.OnClientEvent:Connect(function(data)
            if not data then return end
            if data.Speaker ~= LocalPlayer.Name then return end
            local message = data.Message
            if not message then return end
            self:HandleMessage(message)
        end)

        self.State.HookConnection = connection
        self.State.Hooked = true
        Util:Log("ChatCommands: хук на SayMessageRequest установлен")
    end)

    if not ok then
        Util:Warn("ChatCommands: не удалось захукать SayMessageRequest")
    end
end

-- Хук на TextChatService (новый чат Roblox, используется с 2023)
function ChatCommands:HookTextChatService()
    local ok = pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if not TextChatService then return end

        local channel = TextChatService:FindFirstChild("TextChannels")
            and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if not channel then
            -- Альтернативный путь через ChatWindowConfiguration
            return
        end

        local connection = channel.MessageReceived:Connect(function(textChatMessage)
            if not textChatMessage then return end
            if textChatMessage.TextSource
                and textChatMessage.TextSource.UserId == LocalPlayer.UserId then
                self:HandleMessage(textChatMessage.Text)
            end
        end)

        -- Перезаписываем предыдущий, если был
        if self.State.HookConnection then
            self.State.HookConnection:Disconnect()
        end
        self.State.HookConnection = connection
        self.State.Hooked = true
        Util:Log("ChatCommands: хук на TextChatService установлен")
    end)

    return ok
end

-- Универсальный хук: пробуем оба способа
function ChatCommands:Start()
    if self.State.Hooked then return end

    task.spawn(function()
        -- Сначала TextChatService
        local ok = self:HookTextChatService()
        if not ok then
            self:HookSayMessage()
        end

        -- Если ничего не вышло — fallback через getconnections на отправку чата
        if not self.State.Hooked then
            Util:Warn("ChatCommands: ни один чат-хук не сработал, чат-команды недоступны")
        end
    end)
end

function ChatCommands:Stop()
    if self.State.HookConnection then
        self.State.HookConnection:Disconnect()
        self.State.HookConnection = nil
    end
    self.State.Hooked = false
end

-- ============================================================
-- HELP / СПИСОК
-- ============================================================
function ChatCommands:GetByCategory()
    local groups = {}
    for name, cmd in pairs(self.State.Commands) do
        groups[cmd.Category] = groups[cmd.Category] or {}
        table.insert(groups[cmd.Category], cmd)
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b) return a.Name < b.Name end)
    end
    return groups
end

function ChatCommands:GetCommand(name)
    name = name:lower()
    if self.State.Aliases[name] then
        name = self.State.Aliases[name]
    end
    return self.State.Commands[name]
end

function ChatCommands:GetAllNames()
    local names = {}
    for name, _ in pairs(self.State.Commands) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Автодополнение: вернуть список команд, начинающихся с prefix
function ChatCommands:Complete(prefix)
    prefix = prefix:lower()
    local result = {}
    for name, _ in pairs(self.State.Commands) do
        if name:sub(1, #prefix) == prefix then
            table.insert(result, name)
        end
    end
    for alias, canonical in pairs(self.State.Aliases) do
        if alias:sub(1, #prefix) == prefix then
            table.insert(result, alias .. " -> " .. canonical)
        end
    end
    table.sort(result)
    return result
end

function ChatCommands:PrintHelp()
    print("========== CHAT COMMANDS ==========")
    print("Префикс:", self.State.Prefix)
    for category, list in pairs(self:GetByCategory()) do
        print("[" .. category .. "]")
        for _, cmd in ipairs(list) do
            local aliases = #cmd.Aliases > 0 and (" (алиасы: " .. table.concat(cmd.Aliases, ", ") .. ")") or ""
            print(string.format("  %-15s %s%s", cmd.Name, cmd.Description, aliases))
        end
    end
    print("===================================")
end

-- ============================================================
-- ПРЕФИКС
-- ============================================================
function ChatCommands:SetPrefix(prefix)
    if type(prefix) ~= "string" or #prefix == 0 then return end
    self.State.Prefix = prefix
end

function ChatCommands:GetPrefix()
    return self.State.Prefix
end

-- ============================================================
-- ДЕФОЛТНЫЕ КОМАНДЫ (регистрируются в Main Init)
-- ============================================================
function ChatCommands:RegisterDefaultCommands()
    -- FARM
    self:Register("farm", function()
        if AutoFarm:IsRunning() then
            AutoFarm:Stop()
            Notify:Info("Farm", "Автофарм выключен")
        else
            AutoFarm:Start()
            Notify:Success("Farm", "Автофарм запущен")
        end
    end, {Description = "Вкл/выкл автофарм", Category = "Farm", Aliases = {"f"}})

    self:Register("collect", function()
        Config.AutoCollect = not Config.AutoCollect
        Notify:Info("Collect", "AutoCollect: " .. tostring(Config.AutoCollect))
    end, {Description = "Вкл/выкл автосбор", Category = "Farm"})

    self:Register("sell", function()
        Config.AutoSell = not Config.AutoSell
        Notify:Info("Sell", "AutoSell: " .. tostring(Config.AutoSell))
    end, {Description = "Вкл/выкл автопродажу", Category = "Farm"})

    self:Register("rebirth", function()
        GameModule:Rebirth()
        Notify:Info("Rebirth", "Ребёрс вызван")
    end, {Description = "Выполнить ребёрс", Category = "Farm"})

    -- PLAYER
    self:Register("god", function()
        if PlayerMods.State.GodMode then
            PlayerMods:DisableGodMode()
            Notify:Info("GodMode", "Выключен")
        else
            PlayerMods:EnableGodMode()
            Notify:Success("GodMode", "Включён")
        end
    end, {Description = "Вкл/выкл godmode", Category = "Player", Aliases = {"godmode"}})

    self:Register("speed", function(args)
        local n = tonumber(args[1])
        if n then
            PlayerMods:SetWalkSpeed(n)
            Notify:Info("Speed", "Установлено: " .. n)
        else
            Notify:Warn("Speed", "Использование: speed <число>")
        end
    end, {Description = "Установить скорость", Usage = "speed <n>", Category = "Player"})

    self:Register("jump", function(args)
        local n = tonumber(args[1])
        if n then
            PlayerMods:SetJumpPower(n)
            Notify:Info("Jump", "Установлено: " .. n)
        else
            Notify:Warn("Jump", "Использование: jump <число>")
        end
    end, {Description = "Установить силу прыжка", Usage = "jump <n>", Category = "Player"})

    self:Register("fly", function()
        if PlayerMods.State.Flying then
            PlayerMods:DisableFly()
            Notify:Info("Fly", "Выключен")
        else
            PlayerMods:EnableFly()
            Notify:Success("Fly", "Включён")
        end
    end, {Description = "Вкл/выкл полёт", Category = "Player"})

    self:Register("noclip", function()
        if PlayerMods.State.Noclip then
            PlayerMods:DisableNoclip()
            Notify:Info("Noclip", "Выключен")
        else
            PlayerMods:EnableNoclip()
            Notify:Success("Noclip", "Включён")
        end
    end, {Description = "Вкл/выкл noclip", Category = "Player"})

    self:Register("infjump", function()
        if PlayerMods.State.InfiniteJump then
            PlayerMods:DisableInfiniteJump()
            Notify:Info("InfJump", "Выключен")
        else
            PlayerMods:EnableInfiniteJump()
            Notify:Success("InfJump", "Включён")
        end
    end, {Description = "Бесконечный прыжок", Category = "Player"})

    self:Register("antitsunami", function()
        if PlayerMods.State.AntiTsunami then
            PlayerMods:DisableAntiTsunami()
            Notify:Info("AntiTsunami", "Выключен")
        else
            PlayerMods:EnableAntiTsunami()
            Notify:Success("AntiTsunami", "Включён")
        end
    end, {Description = "Анти-цунами", Category = "Player"})

    -- TELEPORT
    self:Register("tp", function(args)
        local target = args[1]
        if not target then
            Notify:Warn("TP", "Использование: tp base|sell|best|player <name>|x y z")
            return
        end

        target = target:lower()
        if target == "base" then
            Teleports:ToBase()
            Notify:Info("TP", "На базу")
        elseif target == "sell" then
            Teleports:ToSellZone()
            Notify:Info("TP", "К продаже")
        elseif target == "best" then
            Teleports:ToBestBrainrot()
            Notify:Info("TP", "К лучшему брейнроту")
        elseif target == "closest" then
            Teleports:ToClosestBrainrot()
        elseif target == "spawn" then
            Teleports:ToSpawnMachine()
        elseif target == "event" then
            Teleports:ToEventFolder()
        elseif target == "safe" then
            Teleports:ToSafeZone()
        elseif target == "player" and args[2] then
            Teleports:ToPlayer(args[2])
            Notify:Info("TP", "К игроку: " .. args[2])
        elseif tonumber(target) and tonumber(args[2]) and tonumber(args[3]) then
            Teleports:ToCoords(tonumber(target), tonumber(args[2]), tonumber(args[3]))
            Notify:Info("TP", "Координаты применены")
        else
            Notify:Warn("TP", "Неизвестная цель: " .. target)
        end
    end, {Description = "Телепорт", Usage = "tp <base|sell|best|player|coords>", Category = "Teleport", Aliases = {"teleport"}})

    -- ESP
    self:Register("esp", function(args)
        local sub = (args[1] or "toggle"):lower()
        if sub == "toggle" then
            ESP:Toggle()
            Notify:Info("ESP", ESP.State.Enabled and "Включён" or "Выключен")
        elseif sub == "players" then
            ESP:TogglePlayers()
            Notify:Info("ESP", "Players: " .. tostring(ESP.State.PlayerESP))
        elseif sub == "brainrots" then
            ESP:ToggleBrainrots()
            Notify:Info("ESP", "Brainrots: " .. tostring(ESP.State.BrainrotESP))
        elseif sub == "names" then
            ESP:ToggleNames()
        elseif sub == "dist" then
            ESP:ToggleDistances()
        elseif sub == "rarity" then
            ESP:ToggleRarity()
        end
    end, {Description = "ESP", Category = "Visual"})

    -- EVENTS
    self:Register("events", function()
        Events:Toggle()
        Notify:Info("Events", Events.State.Enabled and "Включены" or "Выключены")
    end, {Description = "Авто-события", Category = "Events"})

    self:Register("autoclaim", function()
        Events:ToggleAutoClaim()
        Notify:Info("AutoClaim", tostring(Events.State.AutoClaim))
    end, {Description = "Авто-клейм наград", Category = "Events"})

    self:Register("tsunami", function(args)
        Events:TriggerTsunami(args[1])
        Notify:Info("Tsunami", "Триггер отправлен")
    end, {Description = "Триггернуть цунами", Category = "Events"})

    -- UTILITY
    self:Register("rejoin", function()
        AntiAFK:Rejoin()
    end, {Description = "Перезайти в сервер", Category = "Utility", Aliases = {"rj"}})

    self:Register("hop", function()
        AntiAFK:ServerHop()
        Notify:Info("ServerHop", "Переход на другой сервер...")
    end, {Description = "Сменить сервер", Category = "Utility"})

    self:Register("antiafk", function()
        AntiAFK:Toggle()
        Notify:Info("AntiAFK", AntiAFK.State.Enabled and "Включён" or "Выключен")
    end, {Description = "Анти-AFK", Category = "Utility"})

    -- DEBUG
    self:Register("dump", function(args)
        local what = (args[1] or "remotes"):lower()
        if what == "remotes" then
            GameModule:DumpRemotes()
        elseif what == "objects" then
            GameModule:DumpObjects()
        elseif what == "db" then
            BrainrotDB:Dump()
        elseif what == "keybinds" then
            Keybinds:PrintStatus()
        elseif what == "stats" then
            AutoFarm:PrintStats()
        elseif what == "all" then
            GameModule:DumpRemotes()
            GameModule:DumpObjects()
            BrainrotDB:Dump()
            Keybinds:PrintStatus()
        end
        Notify:Info("Dump", "Готово: " .. what)
    end, {Description = "Дамп отладочной инфы", Category = "Debug"})

    self:Register("help", function(args)
        local target = args[1]
        if target then
            local cmd = self:GetCommand(target)
            if cmd then
                Notify:Info(cmd.Name, cmd.Usage .. " — " .. cmd.Description, 8)
            else
                Notify:Warn("Help", "Не найдено: " .. target)
            end
        else
            self:PrintHelp()
            Notify:Info("Help", "Список команд в консоли (F9)")
        end
    end, {Description = "Справка по командам", Category = "Core", Aliases = {"h", "?"}})

    self:Register("prefix", function(args)
        if args[1] then
            self:SetPrefix(args[1])
            Notify:Info("Prefix", "Новый префикс: " .. args[1])
        else
            Notify:Info("Prefix", "Текущий: " .. self.State.Prefix)
        end
    end, {Description = "Сменить префикс", Usage = "prefix <char>", Category = "Core"})
end
-- ============================================================
-- STATS TRACKER
-- Деньги, доход/сек, история заработка, редкости, сессия, график
-- ============================================================
local Stats = {}
Stats.__index = Stats

Stats.State = {
    Enabled             = true,
    UpdateInterval      = 2.0,        -- сек между снимками
    HistoryLength       = 300,        -- максимум точек (300 × 2с = 10 мин)
    Running             = false,

    -- Текущее состояние
    Current             = {
        Money           = 0,
        Speed           = 16,
        CarryCapacity   = 1,
        Rebirths        = 0,
        Tokens          = 0,
        BaseLevel       = 1,
        IncomePerSec    = 0,
        BrainrotCount   = 0,
        PlacedCount     = 0,
    },

    -- Базовая линия для расчёта дохода
    Baseline            = {
        Money           = 0,
        Timestamp       = 0,
    },

    -- История заработка: {money, timestamp, delta, perSec}
    MoneyHistory        = {},

    -- Пиковые значения
    Peak = {
        Money           = 0,
        IncomePerSec    = 0,
        PlacedBrainrots = 0,
    },

    -- Счётчики событий за сессию
    Counters = {
        Collected       = 0,
        Placed          = 0,
        Sold            = 0,
        Earned          = 0,
        Rebirths        = 0,
        Upgrades        = 0,
        Events          = 0,
        Errors          = 0,
    },

    -- Разбивка по редкостям
    RarityStats = {
        Collected       = {},   -- [rarity] = count
        Placed          = {},   -- [rarity] = count
        Sold            = {},   -- [rarity] = count
    },

    -- Сессия
    SessionStart        = 0,
    LastSnapshot        = 0,
    Ticks               = 0,
}

-- ============================================================
-- УТИЛИТЫ
-- ============================================================

-- Форматировать время: 1h 23m 45s
function Stats:FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dh %dm %ds", h, m, s) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

-- Форматировать деньги (использует BrainrotDB:FormatIncome)
function Stats:FormatMoney(amount)
    return BrainrotDB:FormatIncome(amount or 0):gsub("/s", "")
end

-- ============================================================
-- СНИМОК СОСТОЯНИЯ
-- ============================================================
function Stats:TakeSnapshot()
    local now = tick()

    -- Обновляем базовые статы
    local s = GameModule:GetPlayerStats()
    for k, v in pairs(s) do
        self.State.Current[k] = v
    end

    -- Кол-во размещённых брейнротов
    local placed = GameModule:GetPlacedBrainrots()
    self.State.Current.PlacedCount = #placed
    self.State.Current.BrainrotCount = #placed

    -- Считаем доход/сек — по фактическому приросту денег за интервал
    local baseline = self.State.Baseline
    if baseline.Timestamp > 0 then
        local elapsed = now - baseline.Timestamp
        if elapsed >= 1 then
            local delta = self.State.Current.Money - baseline.Money
            self.State.Current.IncomePerSec = delta / elapsed
        end
    end

    -- Обновляем базу
    baseline.Money = self.State.Current.Money
    baseline.Timestamp = now

    -- Пиковые значения
    if self.State.Current.Money > self.State.Peak.Money then
        self.State.Peak.Money = self.State.Current.Money
    end
    if self.State.Current.IncomePerSec > self.State.Peak.IncomePerSec then
        self.State.Peak.IncomePerSec = self.State.Current.IncomePerSec
    end
    if self.State.Current.PlacedCount > self.State.Peak.PlacedBrainrots then
        self.State.Peak.PlacedBrainrots = self.State.Current.PlacedCount
    end

    -- Пишем в историю
    local entry = {
        Money = self.State.Current.Money,
        Timestamp = now,
        IncomePerSec = self.State.Current.IncomePerSec,
        Placed = self.State.Current.PlacedCount,
    }
    table.insert(self.State.MoneyHistory, entry)

    -- Ограничиваем историю
    while #self.State.MoneyHistory > self.State.HistoryLength do
        table.remove(self.State.MoneyHistory, 1)
    end

    self.State.LastSnapshot = now
    self.State.Ticks = self.State.Ticks + 1

    return entry
end

-- ============================================================
-- ЦИКЛ
-- ============================================================
function Stats:Start()
    if self.State.Running then return end
    self.State.Running = true
    self.State.SessionStart = tick()

    -- Первый снимок — установить базу
    task.spawn(function()
        task.wait(1)
        self:TakeSnapshot()
    end)

    task.spawn(function()
        while self.State.Running do
            if self.State.Enabled then
                local ok, err = pcall(function()
                    self:TakeSnapshot()
                end)
                if not ok then
                    self.State.Counters.Errors = self.State.Counters.Errors + 1
                    Util:Warn("Stats ошибка:", err)
                end
            end
            task.wait(self.State.UpdateInterval)
        end
    end)

    Util:Log("Stats tracker запущен")
end

function Stats:Stop()
    self.State.Running = false
end

-- ============================================================
-- ИНКРЕМЕНТЫ СЧЁТЧИКОВ (вызывается из других модулей)
-- ============================================================
function Stats:AddCollected(rarity, count)
    count = count or 1
    self.State.Counters.Collected = self.State.Counters.Collected + count
    if rarity then
        self.State.RarityStats.Collected[rarity] =
            (self.State.RarityStats.Collected[rarity] or 0) + count
    end
end

function Stats:AddPlaced(rarity, count)
    count = count or 1
    self.State.Counters.Placed = self.State.Counters.Placed + count
    if rarity then
        self.State.RarityStats.Placed[rarity] =
            (self.State.RarityStats.Placed[rarity] or 0) + count
    end
end

function Stats:AddSold(rarity, count)
    count = count or 1
    self.State.Counters.Sold = self.State.Counters.Sold + count
    if rarity then
        self.State.RarityStats.Sold[rarity] =
            (self.State.RarityStats.Sold[rarity] or 0) + count
    end
end

function Stats:AddEarned(amount)
    self.State.Counters.Earned = self.State.Counters.Earned + (amount or 0)
end

function Stats:AddRebirth()
    self.State.Counters.Rebirths = self.State.Counters.Rebirths + 1
end

function Stats:AddUpgrade()
    self.State.Counters.Upgrades = self.State.Counters.Upgrades + 1
end

function Stats:AddEvent()
    self.State.Counters.Events = self.State.Counters.Events + 1
end

-- ============================================================
-- ЗАПРОСЫ
-- ============================================================
function Stats:GetSessionTime()
    return tick() - (self.State.SessionStart or tick())
end

function Stats:GetCurrent()
    return self.State.Current
end

function Stats:GetPeak()
    return self.State.Peak
end

function Stats:GetCounters()
    return self.State.Counters
end

function Stats:GetMoneyHistory()
    return self.State.MoneyHistory
end

-- Доход за последние N секунд
function Stats:GetIncomePerSec(window)
    window = window or 30
    local history = self.State.MoneyHistory
    local now = tick()

    local oldest = nil
    for _, entry in ipairs(history) do
        if now - entry.Timestamp <= window then
            oldest = entry
            break
        end
    end
    if not oldest then return 0 end

    local last = history[#history]
    if not last then return 0 end

    local elapsed = last.Timestamp - oldest.Timestamp
    if elapsed <= 0 then return 0 end

    return (last.Money - oldest.Money) / elapsed
end

-- Прогноз: сколько нужно времени до N денег
function Stats:TimeUntil(targetMoney)
    local current = self.State.Current.Money
    local rate = self:GetIncomePerSec()
    if targetMoney <= current then return 0 end
    if rate <= 0 then return math.huge end
    return (targetMoney - current) / rate
end

-- Средний доход за сессию
function Stats:GetAverageIncome()
    local history = self.State.MoneyHistory
    if #history < 2 then return 0 end
    local first = history[1]
    local last = history[#history]
    local elapsed = last.Timestamp - first.Timestamp
    if elapsed <= 0 then return 0 end
    return (last.Money - first.Money) / elapsed
end

-- Лучший доход за скользящее окно
function Stats:GetPeakIncome()
    return self.State.Peak.IncomePerSec
end

-- ============================================================
-- ГРАФИК
-- ============================================================
-- Готовит точки для UI-графика (нормализованные 0..1)
function Stats:GetChartPoints(count)
    count = count or 60
    local history = self.State.MoneyHistory
    if #history == 0 then return {} end

    -- Обрезаем до нужного числа точек, равномерно
    local points = {}
    local step = math.max(1, math.floor(#history / count))
    for i = #history, 1, -step do
        table.insert(points, history[i].Money)
    end

    -- Реверсим для правильного порядка (старое слева)
    local reversed = {}
    for i = #points, 1, -1 do
        table.insert(reversed, points[i])
    end

    -- Нормализуем 0..1
    local minVal, maxVal = math.huge, -math.huge
    for _, v in ipairs(reversed) do
        if v < minVal then minVal = v end
        if v > maxVal then maxVal = v end
    end

    if maxVal == minVal then
        for i = 1, #reversed do reversed[i] = 0.5 end
        return reversed
    end

    local normalized = {}
    for _, v in ipairs(reversed) do
        table.insert(normalized, (v - minVal) / (maxVal - minVal))
    end
    return normalized
end

-- Разница за окно
function Stats:GetGrowth(window)
    window = window or 60
    local history = self.State.MoneyHistory
    local now = tick()

    local reference = history[1]
    for _, entry in ipairs(history) do
        if now - entry.Timestamp <= window then
            reference = entry
            break
        end
    end
    if not reference then return 0 end

    local last = history[#history]
    if not last then return 0 end

    return last.Money - reference.Money
end

-- ============================================================
-- ОТЧЁТЫ
-- ============================================================
function Stats:GetSummary()
    local c = self.State.Current
    local counters = self.State.Counters
    return {
        Money           = c.Money,
        IncomePerSec    = self:GetIncomePerSec(),
        PeakIncome      = self.State.Peak.IncomePerSec,
        SessionTime     = self:GetSessionTime(),
        Rebirths        = c.Rebirths,
        Speed           = c.Speed,
        CarryCapacity   = c.CarryCapacity,
        Placed          = c.PlacedCount,

        TotalCollected  = counters.Collected,
        TotalPlaced     = counters.Placed,
        TotalSold       = counters.Sold,
        TotalEarned     = counters.Earned,
        TotalRebirths   = counters.Rebirths,
        TotalUpgrades   = counters.Upgrades,
        TotalEvents     = counters.Events,
        TotalErrors     = counters.Errors,
    }
end

function Stats:PrintStatus()
    local s = self:GetSummary()
    print("========== SESSION STATS ==========")
    print(string.format("Сессия: %s", self:FormatTime(s.SessionTime)))
    print(string.format("Деньги: %s", self:FormatMoney(s.Money)))
    print(string.format("Доход: %s/сек (среднее) | %s/сек (текущее)",
        self:FormatMoney(self:GetAverageIncome()), self:FormatMoney(s.IncomePerSec)))
    print(string.format("Пиковый доход: %s/сек", self:FormatMoney(s.PeakIncome)))
    print(string.format("Скорость: %d | Вместимость: %d | Ребёрсов: %d",
        s.Speed, s.CarryCapacity, s.Rebirths))
    print(string.format("Размещено брейнротов: %d", s.Placed))
    print("--- Счётчики ---")
    print(string.format("Собрано: %d | Размещено: %d | Продано: %d",
        s.TotalCollected, s.TotalPlaced, s.TotalSold))
    print(string.format("Заработано: %s", self:FormatMoney(s.TotalEarned)))
    print(string.format("Апгрейдов: %d | Событий: %d | Ошибок: %d",
        s.TotalUpgrades, s.TotalEvents, s.TotalErrors))
    print("==================================")
end

function Stats:PrintRarityStats()
    print("========== RARITY STATS ==========")
    local allRarities = {}
    for _, r in ipairs(BrainrotDB.Rarities) do
        allRarities[r.Name] = true
    end

    for rarity, _ in pairs(allRarities) do
        local c = self.State.RarityStats.Collected[rarity] or 0
        local p = self.State.RarityStats.Placed[rarity] or 0
        local s = self.State.RarityStats.Sold[rarity] or 0
        if c + p + s > 0 then
            print(string.format("  %-12s collect=%d place=%d sell=%d", rarity, c, p, s))
        end
    end
    print("==================================")
end

-- ============================================================
-- ЭКСПОРТ / ИМПОРТ
-- ============================================================
function Stats:Export()
    local data = {
        Current = self.State.Current,
        Peak = self.State.Peak,
        Counters = self.State.Counters,
        RarityStats = self.State.RarityStats,
        SessionStart = self.State.SessionStart,
        ExportedAt = tick(),
    }
    return data
end

function Stats:SaveToFile()
    ensureFolder()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self:Export())
    if ok then
        Executor.writefile("ETFB_Hub/stats.json", encoded)
        Util:Log("Stats сохранены в файл")
    end
end

function Stats:Reset()
    self.State.Current.Money = 0
    self.State.Peak = {Money = 0, IncomePerSec = 0, PlacedBrainrots = 0}
    self.State.Counters = {
        Collected = 0, Placed = 0, Sold = 0, Earned = 0,
        Rebirths = 0, Upgrades = 0, Events = 0, Errors = 0,
    }
    self.State.RarityStats = {Collected = {}, Placed = {}, Sold = {}}
    self.State.MoneyHistory = {}
    self.State.SessionStart = tick()
    self.State.Ticks = 0
    Util:Log("Stats сброшены")
end

-- ============================================================
-- АВТО-ИНТЕГРАЦИЯ С AUTOFARM
-- ============================================================
-- Патчим методы AutoFarm, чтобы они сами инкрементили счётчики
task.spawn(function()
    task.wait(1)  -- ждём инициализации AutoFarm

    if AutoFarm and AutoFarm.TaskCollect then
        local _origCollect = AutoFarm.TaskCollect
        AutoFarm.TaskCollect = function(self)
            local ok = _origCollect(self)
            if ok then Stats:AddCollected() end
            return ok
        end
    end

    if AutoFarm and AutoFarm.TaskReturnAndPlace then
        local _origPlace = AutoFarm.TaskReturnAndPlace
        AutoFarm.TaskReturnAndPlace = function(self)
            local ok = _origPlace(self)
            if ok then Stats:AddPlaced() end
            return ok
        end
    end

    if AutoFarm and AutoFarm.TaskSell then
        local _origSell = AutoFarm.TaskSell
        AutoFarm.TaskSell = function(self)
            local ok = _origSell(self)
            if ok then Stats:AddSold() end
            return ok
        end
    end

    if AutoFarm and AutoFarm.TaskRebirth then
        local _origRebirth = AutoFarm.TaskRebirth
        AutoFarm.TaskRebirth = function(self)
            local ok = _origRebirth(self)
            if ok then Stats:AddRebirth() end
            return ok
        end
    end

    if AutoFarm and AutoFarm.TaskUpgrade then
        local _origUpgrade = AutoFarm.TaskUpgrade
        AutoFarm.TaskUpgrade = function(self)
            local ok = _origUpgrade(self)
            if ok then Stats:AddUpgrade() end
            return ok
        end
    end
end)
-- ============================================================
-- TRADING MODULE
-- Отправка/приём офферов, авто-принятие выгодных, история, валидация
-- ============================================================
local Trading = {}
Trading.__index = Trading

Trading.State = {
    Enabled             = false,
    AutoAccept          = false,
    AutoDeclineScam     = true,
    AutoAcceptMargin    = 1.15,     -- принимаем, если прибыль >= 15%
    MinValueGain        = 1000000,  -- минимум для авто-приёма
    PendingOffers       = {},       -- входящие офферы
    OutgoingOffers      = {},       -- исходящие
    History             = {},       -- сделки
    MaxHistory          = 100,
    Blocked             = {},       -- [playerName] = true — чёрный список
    Whitelist           = {},       -- [playerName] = true — только им авто-приём
    UseWhitelist        = false,
    LastOutgoing        = 0,
    OutgoingCooldown    = 3.0,
    LastOfferCheck      = 0,
    OfferCheckInterval  = 1.5,
    Running             = false,
}

-- ============================================================
-- РЕЗОЛВЕР ТРЕЙД-РЕМОУТОВ (дополнение к GameModule)
-- ============================================================

-- Попытка найти ремоуты трейда в ReplicatedStorage
function Trading:FindTradeRemotes()
    if self._tradeRemotes then return self._tradeRemotes end

    local candidates = GameModule._cache.remoteCandidates or {}
    local patterns = {
        send       = {"sendtrade", "sendoffer", "tradeoffer", "offertrade", "proposetrade", "requesttrade"},
        accept     = {"accepttrade", "acceptoffer", "confirmtrade", "tradeaccept"},
        decline    = {"declinetrade", "declineoffer", "rejecttrade", "tradedecline"},
        cancel     = {"canceltrade", "canceloffer", "withdrawtrade"},
        complete   = {"completetrade", "finalizetrade", "dotrade", "executetrade"},
        getOffers  = {"getoffers", "incomingoffers", "tradeinbox", "pendingoffers"},
        getTrade   = {"gettrade", "currenttrade", "activetrade"},
    }

    local function normalize(name)
        return name:lower():gsub("[%s_%-%.]", "")
    end

    local resolved = {}
    for category, list in pairs(patterns) do
        for _, remote in ipairs(candidates) do
            local norm = normalize(remote.Name)
            for _, pat in ipairs(list) do
                if norm:find(normalize(pat), 1, true) then
                    if not resolved[category] then
                        resolved[category] = remote
                        break
                    end
                end
            end
            if resolved[category] then break end
        end
    end

    self._tradeRemotes = resolved
    return resolved
end

function Trading:FireTradeRemote(category, ...)
    local remotes = self:FindTradeRemotes()
    local remote = remotes and remotes[category]
    if not remote then
        return false, "no_remote"
    end

    local args = table.pack(...)

    local ok, result = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
        else
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end
    end)
    if not ok then
        Util:Warn("Trading: ошибка FireTradeRemote", category, result)
        return false, result
    end
    return true, result
end

-- ============================================================
-- ВАЛИДАЦИЯ
-- ============================================================

function Trading:IsBlocked(plr)
    if type(plr) == "string" then
        return self.State.Blocked[plr] == true
    end
    return self.State.Blocked[plr.Name] == true
end

function Trading:IsWhitelisted(plr)
    if not self.State.UseWhitelist then return true end
    if type(plr) == "string" then
        return self.State.Whitelist[plr] == true
    end
    return self.State.Whitelist[plr.Name] == true
end

function Trading:SetBlocked(name, blocked)
    if blocked then
        self.State.Blocked[name] = true
    else
        self.State.Blocked[name] = nil
    end
end

function Trading:SetWhitelisted(name, enabled)
    if enabled then
        self.State.Whitelist[name] = true
    else
        self.State.Whitelist[name] = nil
    end
end

-- Проверка: брейнрот принадлежит мне и не размещён в базе
function Trading:IsValidOwnedBrainrot(brainrot)
    if not brainrot or not brainrot.Parent then return false end

    -- Проверяем, что объект в инвентаре игрока или в базе
    local inv = LocalPlayer:FindFirstChild("Inventory")
        or LocalPlayer:FindFirstChild("Brainrots")
        or LocalPlayer:FindFirstChild("Backpack")
    local base = GameModule:FindPlayerBase()

    local inInv = inv and brainrot:IsDescendantOf(inv)
    local inBase = base and brainrot:IsDescendantOf(base)

    return inInv or inBase
end

-- ============================================================
-- ОТПРАВКА ОФФЕРА
-- ============================================================
-- give: список брейнротов, которые я отдаю
-- want: список брейнротов, которые хочу получить (может быть пустым)
function Trading:SendOffer(targetPlayer, give, want)
    if type(targetPlayer) == "string" then
        targetPlayer = Players:FindFirstChild(targetPlayer)
    end
    if not targetPlayer or targetPlayer == LocalPlayer then
        return false, "invalid_target"
    end
    if self:IsBlocked(targetPlayer) then
        return false, "blocked"
    end
    if tick() - self.State.LastOutgoing < self.State.OutgoingCooldown then
        return false, "cooldown"
    end

    give = give or {}
    want = want or {}

    -- Валидация
    for _, b in ipairs(give) do
        if not self:IsValidOwnedBrainrot(b) then
            return false, "invalid_give_item"
        end
    end

    -- Формируем оффер (структура зависит от игры, но обычно это
    -- список имён / id / моделей)
    local giveData = {}
    for _, b in ipairs(give) do
        table.insert(giveData, b.Name)
    end

    local wantData = {}
    for _, name in ipairs(want) do
        table.insert(wantData, name)
    end

    -- Fire
    local ok, err = self:FireTradeRemote("send", targetPlayer, giveData, wantData)

    if not ok then
        -- Fallback через GameModule trade remote
        ok = GameModule:FireRemote("trade", targetPlayer, giveData, wantData)
    end

    if not ok then
        return false, "send_failed"
    end

    self.State.LastOutgoing = tick()

    local offer = {
        Target = targetPlayer,
        Give = giveData,
        Want = wantData,
        SentAt = tick(),
        Direction = "outgoing",
        Status = "pending",
    }
    table.insert(self.State.OutgoingOffers, offer)

    Notify:Info("Trade", "Оффер отправлен: " .. targetPlayer.Name)
    Util:Log("Trade offer ->", targetPlayer.Name, "give:", #giveData, "want:", #wantData)
    return true, offer
end

-- ============================================================
-- ПРИЁМ / ОТКЛОНЕНИЕ
-- ============================================================
function Trading:AcceptOffer(offer)
    if not offer then return false end

    local target = offer.Sender or offer.Target or offer.From

    local ok = self:FireTradeRemote("accept", target, offer.Id or offer)
    if not ok then
        ok = GameModule:FireRemote("trade", "accept", target, offer.Id or offer)
    end

    if ok then
        offer.Status = "accepted"
        offer.CompletedAt = tick()
        self:LogHistory(offer, "accepted")
        Notify:Success("Trade", "Оффер принят от " .. tostring(target and target.Name or "?"))
    else
        Notify:Error("Trade", "Не удалось принять оффер")
    end
    return ok
end

function Trading:DeclineOffer(offer)
    if not offer then return false end

    local target = offer.Sender or offer.Target or offer.From

    local ok = self:FireTradeRemote("decline", target, offer.Id or offer)
    if not ok then
        ok = GameModule:FireRemote("trade", "decline", target, offer.Id or offer)
    end

    if ok then
        offer.Status = "declined"
        offer.CompletedAt = tick()
        self:LogHistory(offer, "declined")
        Notify:Info("Trade", "Оффер отклонён")
    end
    return ok
end

function Trading:CancelOffer(offer)
    if not offer then return false end

    local target = offer.Target
    local ok = self:FireTradeRemote("cancel", target, offer.Id or offer)
    if not ok then
        ok = GameModule:FireRemote("trade", "cancel", target, offer.Id or offer)
    end

    if ok then
        offer.Status = "cancelled"
        offer.CompletedAt = tick()
        self:LogHistory(offer, "cancelled")
    end
    return ok
end

-- ============================================================
-- ОЦЕНКА ОФФЕРА
-- ============================================================
-- Считает "ценность" оффера в единицах дохода (Income)
function Trading:EvaluateOffer(offer)
    local function totalValue(list)
        local total = 0
        for _, item in ipairs(list or {}) do
            local name = type(item) == "string" and item or item.Name
            local info = BrainrotDB:Get(name)
            if info then
                local tier = BrainrotDB:GetRarityTier(info.Rarity)
                -- Вес: тир доминирует, income — уточняет
                total = total + (tier * 1e9) + (info.Income or 0)
            end
        end
        return total
    end

    local theirGive = offer.TheirGive or offer.Give or {}
    local theirWant = offer.TheirWant or offer.Want or {}
    -- Для входящего: они дают нам theirGive, хотят ourWant
    local valueIn = totalValue(theirGive)
    local valueOut = totalValue(theirWant)

    return {
        In = valueIn,
        Out = valueOut,
        Gain = valueIn - valueOut,
        Ratio = valueOut > 0 and (valueIn / valueOut) or math.huge,
    }
end

-- Является ли оффер выгодным?
function Trading:IsProfitable(offer)
    local eval = self:EvaluateOffer(offer)
    if eval.Out == 0 then
        -- Просят ничего — принимаем всё
        return eval.In > 0
    end
    return eval.Ratio >= self.State.AutoAcceptMargin
        and eval.Gain >= self.State.MinValueGain
end

-- ============================================================
-- ВХОДЯЩИЕ ОФФЕРЫ
-- ============================================================

-- Получить текущие входящие офферы (через ремоут или сканирование UI)
function Trading:FetchIncoming()
    -- Вариант 1: ремоут getOffers
    local ok, data = self:FireTradeRemote("getOffers")
    if ok and type(data) == "table" then
        self.State.PendingOffers = data
        return data
    end

    -- Вариант 2: сканируем PlayerGui на окно трейда
    local found = {}
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetDescendants()) do
            if gui:IsA("ScreenGui") and gui.Name:lower():find("trade") then
                for _, frame in ipairs(gui:GetDescendants()) do
                    if frame:IsA("Frame") and frame.Name:lower():find("offer") then
                        local senderLabel = frame:FindFirstChild("Sender", true)
                        if senderLabel and senderLabel:IsA("TextLabel") then
                            table.insert(found, {
                                Sender = senderLabel.Text,
                                Frame = frame,
                                Id = frame.Name,
                                TheirGive = {},
                                TheirWant = {},
                            })
                        end
                    end
                end
            end
        end
    end

    self.State.PendingOffers = found
    return found
end

-- Авто-логика входящих
function Trading:ProcessIncoming()
    local offers = self:FetchIncoming()
    for _, offer in ipairs(offers) do
        if offer.Status == "pending" or offer.Status == nil then
            local sender = offer.Sender or offer.From or offer.Target
            local senderName = type(sender) == "string" and sender
                or (sender and sender.Name)

            if senderName and self:IsBlocked(senderName) then
                self:DeclineOffer(offer)
            elseif self.State.AutoDeclineScam and not self:IsProfitable(offer) then
                Util:Log("Trade: отклоняю невыгодный оффер от", senderName)
                self:DeclineOffer(offer)
            elseif self.State.AutoAccept and self:IsWhitelisted(sender or senderName) and self:IsProfitable(offer) then
                Util:Log("Trade: авто-приём выгодного оффера от", senderName)
                self:AcceptOffer(offer)
            end
        end
    end
end

-- ============================================================
-- ИСТОРИЯ
-- ============================================================
function Trading:LogHistory(offer, status)
    table.insert(self.State.History, 1, {
        Target = offer.Target or offer.Sender,
        Give = offer.Give or offer.TheirGive,
        Want = offer.Want or offer.TheirWant,
        Status = status,
        Time = tick(),
    })
    while #self.State.History > self.State.MaxHistory do
        table.remove(self.State.History)
    end
end

function Trading:GetHistory()
    return self.State.History
end

function Trading:ClearHistory()
    self.State.History = {}
end

-- ============================================================
-- ЦИКЛ
-- ============================================================
function Trading:Loop()
    if self.State.Running then return end
    self.State.Running = true

    task.spawn(function()
        while self.State.Running do
            if not self.State.Enabled then
                task.wait(1)
                continue
            end

            if tick() - self.State.LastOfferCheck >= self.State.OfferCheckInterval then
                pcall(function()
                    self:ProcessIncoming()
                end)
                self.State.LastOfferCheck = tick()
            end

            task.wait(0.5)
        end
    end)

    Util:Log("Trading цикл запущен")
end

function Trading:Enable()
    self.State.Enabled = true
    self:Loop()
end

function Trading:Disable()
    self.State.Enabled = false
end

function Trading:Toggle()
    if self.State.Enabled then self:Disable() else self:Enable() end
end

-- ============================================================
-- НАСТРОЙКИ
-- ============================================================
function Trading:SetAutoAccept(v)         self.State.AutoAccept = v end
function Trading:SetAutoDeclineScam(v)   self.State.AutoDeclineScam = v end
function Trading:SetAutoAcceptMargin(v)  self.State.AutoAcceptMargin = math.max(1.0, v) end
function Trading:SetMinValueGain(v)      self.State.MinValueGain = math.max(0, v) end
function Trading:SetUseWhitelist(v)      self.State.UseWhitelist = v end

-- ============================================================
-- СТАТУС
-- ============================================================
function Trading:PrintStatus()
    print("========== TRADING STATUS ==========")
    print("Enabled:", self.State.Enabled,
        "| AutoAccept:", self.State.AutoAccept,
        "| AutoDecline:", self.State.AutoDeclineScam)
    print("Margin:", self.State.AutoAcceptMargin, "x")
    print("Входящих офферов:", #self.State.PendingOffers)
    print("Исходящих офферов:", #self.State.OutgoingOffers)
    print("История (последние 10):")
    for i = 1, math.min(10, #self.State.History) do
        local h = self.State.History[i]
        local targetName = type(h.Target) == "string" and h.Target
            or (h.Target and h.Target.Name) or "?"
        print(string.format("  %s | %s | %s",
            targetName, h.Status, os.date("%H:%M:%S", math.floor(h.Time))))
    end
    print("====================================")
end
-- ============================================================
-- QUESTS MODULE
-- Отслеживание квестов, авто-выполнение, авто-сдача, фильтры
-- ============================================================
local Quests = {}
Quests.__index = Quests

Quests.State = {
    Enabled             = false,
    AutoTrack           = true,
    AutoProgress        = false,
    AutoClaim           = false,
    AutoSkipUnsupported = true,
    ActiveQuests        = {},       -- [id] = quest data
    CompletedQuests     = {},       -- [id] = true
    ClaimedQuests       = {},       -- [id] = true
    History             = {},       -- последние N
    MaxHistory          = 50,
    ScanInterval        = 3.0,
    LastScan            = 0,
    LastClaim           = 0,
    ClaimCooldown       = 1.0,
    TrackedQuest        = nil,      -- id текущего отслеживаемого
    IgnoreQuests        = {},       -- [name] = true — не выполнять
    PriorityQuests      = {},       -- [name] = true — выполнять в первую очередь
    Running             = false,
    ProgressTicks       = 0,
    Errors              = 0,
}

-- ============================================================
-- РЕЗОЛВЕР КВЕСТ-РЕМОУТОВ
-- ============================================================
function Quests:FindQuestRemotes()
    if self._remotes then return self._remotes end

    local candidates = GameModule._cache.remoteCandidates or {}
    local patterns = {
        getQuests    = {"getquests", "fetchquests", "questlist", "questdata", "getquestdata"},
        startQuest   = {"startquest", "acceptquest", "beginquest", "takequest"},
        completeQuest= {"completequest", "finishquest", "turninquest", "deliverquest"},
        claimQuest   = {"claimquest", "claimreward", "questreward", "collectreward"},
        skipQuest    = {"skipquest", "abandonquest", "cancelquest", "dropquest"},
        progressQuest= {"progressquest", "updatequest", "questprogress"},
    }

    local function normalize(name)
        return name:lower():gsub("[%s_%-%.]", "")
    end

    local resolved = {}
    for category, list in pairs(patterns) do
        for _, remote in ipairs(candidates) do
            local norm = normalize(remote.Name)
            for _, pat in ipairs(list) do
                if norm:find(normalize(pat), 1, true) then
                    if not resolved[category] then
                        resolved[category] = remote
                        break
                    end
                end
            end
            if resolved[category] then break end
        end
    end

    self._remotes = resolved
    return resolved
end

function Quests:FireQuestRemote(category, ...)
    local remotes = self:FindQuestRemotes()
    local remote = remotes and remotes[category]
    if not remote then return false, "no_remote" end

    local args = table.pack(...)

    local ok, result = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
        else
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end
    end)
    if not ok then
        Util:Warn("Quests: ошибка", category, result)
        return false, result
    end
    return true, result
end

-- ============================================================
-- СКАНИРОВАНИЕ КВЕСТОВ
-- ============================================================

-- Собираем квесты из трёх источников: ремоут, PlayerGui, атрибуты
function Quests:ScanQuests()
    local quests = {}

    -- 1. Ремоут getQuests (если доступен)
    local ok, data = self:FireQuestRemote("getQuests")
    if ok and type(data) == "table" then
        for _, q in ipairs(data) do
            if q and q.Id then
                quests[q.Id] = {
                    Id = q.Id,
                    Name = q.Name or q.Title or ("Quest_" .. tostring(q.Id)),
                    Description = q.Description or q.Desc or "",
                    Progress = q.Progress or q.Current or 0,
                    Target = q.Target or q.Goal or q.Required or 1,
                    Reward = q.Reward or q.Money or q.Prize or 0,
                    Source = "remote",
                    Claimed = q.Claimed or false,
                    Completed = q.Completed or (q.Progress and q.Target and q.Progress >= q.Target) or false,
                }
            end
        end
    end

    -- 2. PlayerGui сканирование
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetDescendants()) do
            if gui:IsA("ScreenGui") and (gui.Name:lower():find("quest") or gui.Name:lower():find("mission")) then
                for _, frame in ipairs(gui:GetDescendants()) do
                    if frame:IsA("Frame") and frame.Name:lower():find("quest") then
                        -- Пытаемся вытащить данные из фрейма
                        local nameLbl = frame:FindFirstChild("Name", true)
                        local progLbl = frame:FindFirstChild("Progress", true)
                        local descLbl = frame:FindFirstChild("Description", true)

                        local name = nameLbl and nameLbl.Text or frame.Name
                        local progressText = progLbl and progLbl.Text or ""

                        -- Прогресс вида "3/10"
                        local cur, target = progressText:match("(%d+)%s*/%s*(%d+)")
                        cur = tonumber(cur) or 0
                        target = tonumber(target) or 1

                        local id = frame:GetAttribute("QuestId") or frame.Name
                        if not quests[id] then
                            quests[id] = {
                                Id = id,
                                Name = name,
                                Description = descLbl and descLbl.Text or "",
                                Progress = cur,
                                Target = target,
                                Reward = 0,
                                Source = "gui",
                                Frame = frame,
                                Completed = cur >= target,
                            }
                        end
                    end
                end
            end
        end
    end

    -- 3. Атрибуты Player / папки Quest с атрибутами
    local questFolder = LocalPlayer:FindFirstChild("Quests")
        or LocalPlayer:FindFirstChild("Missions")
    if questFolder then
        for _, q in ipairs(questFolder:GetChildren()) do
            local id = q.Name
            if not quests[id] then
                quests[id] = {
                    Id = id,
                    Name = q:GetAttribute("Name") or q.Name,
                    Description = q:GetAttribute("Description") or "",
                    Progress = q:GetAttribute("Progress") or 0,
                    Target = q:GetAttribute("Target") or q:GetAttribute("Required") or 1,
                    Reward = q:GetAttribute("Reward") or 0,
                    Source = "attributes",
                    Instance = q,
                    Completed = q:GetAttribute("Completed") or false,
                }
            end
        end
    end

    return quests
end

-- Обновить активные квесты
function Quests:UpdateActive()
    local scanned = self:ScanQuests()

    -- Новые
    for id, q in pairs(scanned) do
        if not self.State.ActiveQuests[id] then
            Util:Log("Новый квест:", q.Name, "(" .. id .. ")")
            if self.State.AutoTrack then
                self.State.TrackedQuest = id
            end
        end
        self.State.ActiveQuests[id] = q
    end

    -- Удалённые
    for id, _ in pairs(self.State.ActiveQuests) do
        if not scanned[id] then
            if self.State.ActiveQuests[id].Completed then
                self.State.CompletedQuests[id] = true
            end
            self.State.ActiveQuests[id] = nil
        end
    end

    return self.State.ActiveQuests
end

-- ============================================================
-- ПРОГРЕСС КВЕСТА
-- ============================================================

-- Попытка выполнить квест (в зависимости от типа)
function Quests:AttemptProgress(quest)
    if not quest then return false end
    if self.State.IgnoreQuests[quest.Name] then return false end

    local progress = false

    -- Квест на сбор брейнротов: просто запускаем AutoFarm
    local nameL = (quest.Name or ""):lower()
    local descL = (quest.Description or ""):lower()

    if nameL:find("collect") or descL:find("collect") or nameL:find("gather") or descL:find("gather") then
        if not AutoFarm:IsRunning() then
            AutoFarm:Start()
        end
        progress = true

    -- Квест на продажу
    elseif nameL:find("sell") or descL:find("sell") then
        if not Config.AutoSell then Config.AutoSell = true end
        progress = true

    -- Квест на размещение
    elseif nameL:find("place") or descL:find("place") then
        if not Config.AutoPlace then Config.AutoPlace = true end
        progress = true

    -- Квест на ребёрс
    elseif nameL:find("rebirth") or descL:find("rebirth") then
        GameModule:Rebirth()
        progress = true

    -- Квест на апгрейд
    elseif nameL:find("upgrade") or descL:find("upgrade") then
        GameModule:UpgradeSpeed()
        task.wait(0.1)
        GameModule:UpgradeCarry()
        task.wait(0.1)
        GameModule:UpgradeBase()
        progress = true

    -- Квест на посещение места (телепорт + proximity prompt)
    elseif nameL:find("visit") or nameL:find("go to") or descL:find("visit") then
        -- Пытаемся вытащить имя места из названия
        local place = quest.Description:match('"([^"]+)"')
            or quest.Name:match("visit%s+(.+)")
        if place then
            local target = Workspace:FindFirstChild(place, true)
            if target then
                Teleports:TeleportToInstance(target)
                progress = true
            end
        end

    -- Квест на взаимодействие с NPC / ProximityPrompt
    elseif nameL:find("talk") or nameL:find("interact") or descL:find("talk") then
        local targetName = quest.Description:match('"([^"]+)"')
            or quest.Name:match("talk%s+to%s+(.+)")
            or quest.Name:match("interact%s+with%s+(.+)")
        if targetName then
            for _, prompt in ipairs(Workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    if prompt.Parent and prompt.Parent.Name:lower():find(targetName:lower(), 1, true) then
                        Util:FireProximityPrompt(prompt)
                        progress = true
                        break
                    end
                end
            end
        end

    -- Квест на убийство / событие
    elseif nameL:find("kill") or nameL:find("defeat") or descL:find("defeat") then
        -- Если AutoFarm умеет бить — уже сработает. Тут просто флаг.
        progress = false
    end

    return progress
end

-- ============================================================
-- СДАЧА КВЕСТА
-- ============================================================
function Quests:ClaimQuest(quest)
    if not quest then return false end
    if tick() - self.State.LastClaim < self.State.ClaimCooldown then
        return false, "cooldown"
    end

    -- 1. FireQuestRemote
    local ok = self:FireQuestRemote("claimQuest", quest.Id or quest.Name)
    if not ok then
        -- 2. GameModule fallback
        ok = GameModule:FireRemote("quest", "claim", quest.Id or quest.Name)
    end

    -- 3. UI-фоллбэк: ищем кнопку Claim в фрейме квеста
    if not ok and quest.Frame then
        for _, desc in ipairs(quest.Frame:GetDescendants()) do
            if desc:IsA("TextButton") then
                local txt = desc.Text:lower()
                if txt:find("claim") or txt:find("collect") or txt:find("reward") or txt:find("complete") then
                    Util:ClickButton(desc)
                    ok = true
                    break
                end
            end
        end
    end

    -- 4. ProximityPrompt на квест-борде
    if not ok then
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local action = prompt.ActionText:lower()
                if action:find("claim") or action:find("quest") or action:find("turn in") then
                    Util:FireProximityPrompt(prompt)
                    ok = true
                    break
                end
            end
        end
    end

    if ok then
        self.State.LastClaim = tick()
        self.State.ClaimedQuests[quest.Id or quest.Name] = true
        table.insert(self.State.History, 1, {
            Name = quest.Name,
            Id = quest.Id,
            Reward = quest.Reward or 0,
            Time = tick(),
            Status = "claimed",
        })
        while #self.State.History > self.State.MaxHistory do
            table.remove(self.State.History)
        end
        Notify:Success("Quest", "Сдан: " .. quest.Name)
    end
    return ok
end

-- ============================================================
-- АВТО-ЛОГИКА
-- ============================================================
function Quests:ProcessAuto()
    local quests = self:UpdateActive()

    -- Сортируем по приоритету
    local list = {}
    for _, q in pairs(quests) do
        table.insert(list, q)
    end
    table.sort(list, function(a, b)
        local ap = self.State.PriorityQuests[a.Name] and 1 or 0
        local bp = self.State.PriorityQuests[b.Name] and 1 or 0
        if ap ~= bp then return ap > bp end
        return (a.Progress or 0) / math.max(a.Target or 1, 1)
             > (b.Progress or 0) / math.max(b.Target or 1, 1)
    end)

    for _, q in ipairs(list) do
        -- Авто-сдача
        if self.State.AutoClaim and q.Completed and not self.State.ClaimedQuests[q.Id] then
            self:ClaimQuest(q)
            task.wait(0.3)
        end

        -- Авто-прогресс
        if self.State.AutoProgress and not q.Completed and not self.State.ClaimedQuests[q.Id] then
            self:AttemptProgress(q)
        end
    end
end

-- ============================================================
-- ЦИКЛ
-- ============================================================
function Quests:Loop()
    if self.State.Running then return end
    self.State.Running = true

    task.spawn(function()
        while self.State.Running do
            if not self.State.Enabled then
                task.wait(1)
                continue
            end

            local ok, err = pcall(function()
                self:ProcessAuto()
                self.State.ProgressTicks = self.State.ProgressTicks + 1
            end)
            if not ok then
                self.State.Errors = self.State.Errors + 1
                Util:Warn("Quests ошибка:", err)
            end

            task.wait(self.State.ScanInterval)
        end
    end)

    Util:Log("Quests цикл запущен")
end

function Quests:Enable()
    self.State.Enabled = true
    self:Loop()
end

function Quests:Disable()
    self.State.Enabled = false
end

function Quests:Toggle()
    if self.State.Enabled then self:Disable() else self:Enable() end
end

-- ============================================================
-- НАСТРОЙКИ
-- ============================================================
function Quests:SetAutoProgress(v)  self.State.AutoProgress = v end
function Quests:SetAutoClaim(v)     self.State.AutoClaim = v end
function Quests:SetAutoTrack(v)     self.State.AutoTrack = v end

function Quests:AddIgnore(name)     self.State.IgnoreQuests[name] = true end
function Quests:RemoveIgnore(name)  self.State.IgnoreQuests[name] = nil end
function Quests:AddPriority(name)   self.State.PriorityQuests[name] = true end
function Quests:RemovePriority(name)self.State.PriorityQuests[name] = nil end

-- ============================================================
-- ИНФОРМАЦИЯ
-- ============================================================
function Quests:GetActive()
    return self.State.ActiveQuests
end

function Quests:GetTracked()
    if not self.State.TrackedQuest then return nil end
    return self.State.ActiveQuests[self.State.TrackedQuest]
end

function Quests:GetHistory()
    return self.State.History
end

function Quests:GetSummary()
    local active, completed, claimed = 0, 0, 0
    for _, _ in pairs(self.State.ActiveQuests) do active = active + 1 end
    for _, _ in pairs(self.State.CompletedQuests) do completed = completed + 1 end
    for _, _ in pairs(self.State.ClaimedQuests) do claimed = claimed + 1 end
    return {
        Active = active,
        Completed = completed,
        Claimed = claimed,
        ProgressTicks = self.State.ProgressTicks,
        Errors = self.State.Errors,
    }
end

function Quests:PrintStatus()
    local s = self:GetSummary()
    print("========== QUESTS STATUS ==========")
    print("Enabled:", self.State.Enabled,
        "| AutoProgress:", self.State.AutoProgress,
        "| AutoClaim:", self.State.AutoClaim)
    print(string.format("Активных: %d | Завершено: %d | Сдано: %d", s.Active, s.Completed, s.Claimed))
    print("Текущие квесты:")
    for id, q in pairs(self.State.ActiveQuests) do
        local mark = q.Completed and "✓" or "…"
        print(string.format("  %s %s [%d/%d] reward=%s",
            mark, q.Name, q.Progress or 0, q.Target or 1, BrainrotDB:FormatIncome(q.Reward or 0)))
    end
    print("===================================")
end
-- ============================================================
-- FULL UI
-- Сборка всех модулей в интерфейс: табы, тоглы, слайдеры, кнопки
-- ============================================================
local UI = {}
UI.__index = UI

UI.State = {
    Gui             = nil,
    Tabs            = {},
    LiveUpdaters    = {},
    UpdaterRunning  = false,
}

-- Утилита: создать заголовок секции
local function addSection(tab, title)
    GUI:AddDivider(tab)
    local lbl = GUI:AddLabel(tab, "── " .. title .. " ──")
    lbl.TextColor3 = Config.UIAccent
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamBold
    return lbl
end

-- Утилита: добавить живое обновление
local function addLiveUpdater(fn)
    table.insert(UI.State.LiveUpdaters, fn)
end

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ UI
-- ============================================================
function UI:Build()
    -- Создаём GUI
    self.State.Gui = GUI:Init()
    GUI:Toggle(true)

    -- Строим табы
    self:BuildFarmTab()
    self:BuildPlayerTab()
    self:BuildTeleportTab()
    self:BuildVisualTab()
    self:BuildEventsTab()
    self:BuildStatsTab()
    self:BuildTradingTab()
    self:BuildQuestsTab()
    self:BuildKeybindsTab()
    self:BuildSettingsTab()
    self:BuildDebugTab()

    -- Выбираем первый таб
    GUI:SelectTab("Farm")

    -- Запускаем updater
    self:StartLiveUpdater()

    Notify:Success("ETFB Hub", "Загружено. Меню — " .. Config.UIToggleKey.Name)
end

-- ============================================================
-- TAB: FARM
-- ============================================================
function UI:BuildFarmTab()
    local tab = GUI:AddTab("Farm")
    self.State.Tabs.Farm = tab

    addSection(tab, "Основное")

    GUI:AddToggle(tab, "Auto Farm (мастер)", Config.AutoFarm, function(v)
        if v then AutoFarm:Start() else AutoFarm:Stop() end
    end)

    GUI:AddToggle(tab, "Auto Collect", Config.AutoCollect, function(v)
        Config.AutoCollect = v
    end)

    GUI:AddToggle(tab, "Auto Place", Config.AutoPlace, function(v)
        Config.AutoPlace = v
    end)

    GUI:AddToggle(tab, "Auto Sell", Config.AutoSell, function(v)
        Config.AutoSell = v
    end)

    GUI:AddToggle(tab, "Auto Upgrade", Config.AutoUpgrade, function(v)
        Config.AutoUpgrade = v
    end)

    GUI:AddToggle(tab, "Auto Rebirth", Config.AutoRebirth, function(v)
        Config.AutoRebirth = v
    end)

    addSection(tab, "Настройки")

    GUI:AddSlider(tab, "Farm Delay", 1, 100, math.floor(Config.FarmDelay * 100), function(v)
        Config.FarmDelay = v / 100
    end)

    GUI:AddSlider(tab, "Collect Delay", 1, 100, math.floor(Config.CollectDelay * 100), function(v)
        AutoFarm.Settings.CollectDelay = v / 100
    end)

    GUI:AddSlider(tab, "Max Inventory Slots", 1, 20, AutoFarm.Settings.MaxInventorySlots, function(v)
        AutoFarm.Settings.MaxInventorySlots = v
    end)

    GUI:AddSlider(tab, "Keep Best Count", 0, 10, AutoFarm.Settings.KeepBestCount, function(v)
        AutoFarm.Settings.KeepBestCount = v
    end)

    GUI:AddSlider(tab, "Sell Threshold (тир)", 1, 12, 1, function(v)
        -- Устанавливаем порог продажи по тиру редкости
        local r = BrainrotDB.Rarities[v]
        if r then
            AutoFarm.Settings.AutoSellThreshold = r.IncomeMin
        end
    end)

    GUI:AddToggle(tab, "Teleport on Collect", AutoFarm.Settings.TeleportOnCollect, function(v)
        AutoFarm.Settings.TeleportOnCollect = v
    end)

    addSection(tab, "Действия")

    GUI:AddButton(tab, "Собрать всё сейчас", function()
        task.spawn(function()
            for i = 1, AutoFarm.Settings.MaxInventorySlots do
                AutoFarm:TaskCollect()
            end
            Notify:Info("Farm", "Сбор выполнен")
        end)
    end)

    GUI:AddButton(tab, "Разместить лучших", function()
        AutoFarm:TaskReturnAndPlace()
        Notify:Info("Farm", "Размещение выполнено")
    end)

    GUI:AddButton(tab, "Продать мусор", function()
        AutoFarm:TaskSell()
        Notify:Info("Farm", "Продажа выполнена")
    end)

    GUI:AddButton(tab, "Апгрейды", function()
        AutoFarm:TaskUpgrade()
    end)

    GUI:AddButton(tab, "Ребёрс", function()
        AutoFarm:TaskRebirth()
    end)
end

-- ============================================================
-- TAB: PLAYER
-- ============================================================
function UI:BuildPlayerTab()
    local tab = GUI:AddTab("Player")
    self.State.Tabs.Player = tab

    addSection(tab, "Модификаторы")

    GUI:AddToggle(tab, "God Mode", PlayerMods.State.GodMode, function(v)
        if v then PlayerMods:EnableGodMode() else PlayerMods:DisableGodMode() end
    end)

    GUI:AddToggle(tab, "Infinite Jump", PlayerMods.State.InfiniteJump, function(v)
        if v then PlayerMods:EnableInfiniteJump() else PlayerMods:DisableInfiniteJump() end
    end)

    GUI:AddToggle(tab, "Noclip", PlayerMods.State.Noclip, function(v)
        if v then PlayerMods:EnableNoclip() else PlayerMods:DisableNoclip() end
    end)

    GUI:AddToggle(tab, "Fly", PlayerMods.State.Flying, function(v)
        if v then PlayerMods:EnableFly() else PlayerMods:DisableFly() end
    end)

    GUI:AddToggle(tab, "Anti Tsunami", PlayerMods.State.AntiTsunami, function(v)
        if v then PlayerMods:EnableAntiTsunami() else PlayerMods:DisableAntiTsunami() end
    end)

    GUI:AddToggle(tab, "Anti Jail", PlayerMods.State.AntiJail, function(v)
        if v then PlayerMods:EnableAntiJail() else PlayerMods:DisableAntiJail() end
    end)

    GUI:AddToggle(tab, "Anti Fling", PlayerMods.State.AntiFling, function(v)
        if v then PlayerMods:EnableAntiFling() else PlayerMods:DisableAntiFling() end
    end)

    addSection(tab, "Скорость / Прыжок")

    local speedSlider
    speedSlider = GUI:AddSlider(tab, "Walk Speed", 16, 500, Config.WalkSpeed, function(v)
        PlayerMods:SetWalkSpeed(v)
    end)

    GUI:AddSlider(tab, "Jump Power", 50, 500, Config.JumpPower, function(v)
        PlayerMods:SetJumpPower(v)
    end)

    GUI:AddSlider(tab, "Fly Speed", 10, 500, Config.FlySpeed, function(v)
        PlayerMods:SetFlySpeed(v)
    end)

    addSection(tab, "Действия")

    GUI:AddButton(tab, "Сбросить всё", function()
        PlayerMods:ResetAll()
        Notify:Info("Player", "Все моды сброшены")
    end)

    GUI:AddButton(tab, "Респавн (Character)", function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end)
end

-- ============================================================
-- TAB: TELEPORT
-- ============================================================
function UI:BuildTeleportTab()
    local tab = GUI:AddTab("Teleport")
    self.State.Tabs.Teleport = tab

    addSection(tab, "Быстрые действия")

    for _, action in ipairs(Teleports.QuickActions) do
        GUI:AddButton(tab, action.Label, function()
            local ok = action.Func()
            if ok then
                Notify:Info("TP", action.Label)
            else
                Notify:Warn("TP", "Не удалось: " .. action.Label)
            end
        end)
    end

    addSection(tab, "Телепорт к игроку")

    local playerInput = GUI:AddTextBox(tab, "Имя игрока...", function(text)
        if text and text ~= "" then
            Teleports:ToPlayer(text)
        end
    end)

    GUI:AddButton(tab, "Ближайший игрок", function()
        Teleports:ToClosestPlayer()
    end)

    addSection(tab, "Координаты")

    local coordBox = GUI:AddTextBox(tab, "X,Y,Z через запятую...", function(text)
        if not text or text == "" then return end
        local x, y, z = text:match("([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
        if x then
            Teleports:ToCoords(x, y, z)
            Notify:Info("TP", "Координаты применены")
        else
            Notify:Warn("TP", "Неверный формат: X,Y,Z")
        end
    end)

    addSection(tab, "Метки")

    local wpNameBox = GUI:AddTextBox(tab, "Имя метки (пусто = авто)...", nil)
    GUI:AddButton(tab, "Сохранить текущую позицию", function()
        local hrp = Util:GetHRP()
        if hrp then
            Teleports:AddWaypoint(wpNameBox.Text, hrp.Position)
            Notify:Success("Waypoint", "Сохранено")
        end
    end)

    GUI:AddButton(tab, "Список меток (в консоль)", function()
        for _, wp in ipairs(Teleports:GetWaypoints()) do
            print(string.format("[WP] %s | %s", wp.Name, tostring(wp.Position)))
        end
        Notify:Info("Waypoints", "Вывод в F9")
    end)

    GUI:AddButton(tab, "Очистить метки", function()
        Teleports:ClearWaypoints()
        Notify:Info("Waypoints", "Очищено")
    end)

    addSection(tab, "История")

    GUI:AddButton(tab, "Назад", function()
        Teleports:Back()
    end)

    GUI:AddButton(tab, "Очистить историю", function()
        Teleports:ClearHistory()
    end)
end

-- ============================================================
-- TAB: VISUAL (ESP)
-- ============================================================
function UI:BuildVisualTab()
    local tab = GUI:AddTab("Visual")
    self.State.Tabs.Visual = tab

    addSection(tab, "ESP")

    GUI:AddToggle(tab, "ESP Enabled", ESP.State.Enabled, function(v)
        if v then ESP:Enable() else ESP:Disable() end
    end)

    GUI:AddToggle(tab, "Players", ESP.State.PlayerESP, function(v)
        ESP.State.PlayerESP = v
    end)

    GUI:AddToggle(tab, "Brainrots", ESP.State.BrainrotESP, function(v)
        ESP.State.BrainrotESP = v
    end)

    GUI:AddToggle(tab, "Names", ESP.State.Names, function(v)
        ESP.State.Names = v
    end)

    GUI:AddToggle(tab, "Distances", ESP.State.Distances, function(v)
        ESP.State.Distances = v
    end)

    GUI:AddToggle(tab, "Rarity + Income", ESP.State.Rarity, function(v)
        ESP.State.Rarity = v
    end)

    GUI:AddToggle(tab, "Health", ESP.State.Health, function(v)
        ESP.State.Health = v
    end)

    addSection(tab, "Настройки")

    GUI:AddSlider(tab, "Max Distance", 100, 10000, ESP.State.MaxDistance, function(v)
        ESP:SetMaxDistance(v)
    end)

    GUI:AddSlider(tab, "Refresh Rate (ms)", 5, 100, math.floor(ESP.State.RefreshRate * 100), function(v)
        ESP:SetRefreshRate(v / 100)
    end)

    addSection(tab, "Фильтр брейнротов")

    local rarityOptions = {}
    for _, r in ipairs(BrainrotDB.Rarities) do
        table.insert(rarityOptions, r.Name)
    end
    -- ESP пока не поддерживает фильтр по конкретной редкости, но UI готов
    GUI:AddDropdown(tab, "Min Rarity", rarityOptions, function(opt)
        Util:Log("Min Rarity:", opt)
    end)
end

-- ============================================================
-- TAB: EVENTS
-- ============================================================
function UI:BuildEventsTab()
    local tab = GUI:AddTab("Events")
    self.State.Tabs.Events = tab

    addSection(tab, "Автоматизация")

    GUI:AddToggle(tab, "Events Enabled", Events.State.Enabled, function(v)
        if v then Events:Enable() else Events:Disable() end
    end)

    GUI:AddToggle(tab, "Auto Join", Events.State.AutoJoin, function(v)
        Events.State.AutoJoin = v
    end)

    GUI:AddToggle(tab, "Auto Claim", Events.State.AutoClaim, function(v)
        Events.State.AutoClaim = v
    end)

    GUI:AddToggle(tab, "Auto Tsunami", Events.State.AutoTsunami, function(v)
        Events.State.AutoTsunami = v
    end)

    GUI:AddToggle(tab, "Notify on Event", Events.State.NotifyOnEvent, function(v)
        Events.State.NotifyOnEvent = v
    end)

    addSection(tab, "Настройки")

    GUI:AddSlider(tab, "Join Delay (ms)", 1, 100, math.floor(Events.State.JoinDelay * 10), function(v)
        Events.State.JoinDelay = v / 10
    end)

    GUI:AddSlider(tab, "Tsunami Cooldown (сек)", 5, 300, Events.State.TsunamiCooldown, function(v)
        Events.State.TsunamiCooldown = v
    end)

    addSection(tab, "События сейчас")

    local eventListLabel = GUI:AddLabel(tab, "События не обнаружены")
    addLiveUpdater(function()
        if not eventListLabel or not eventListLabel.Parent then return end
        local list = Events:GetActiveEvents()
        if #list == 0 then
            eventListLabel.Text = "События не обнаружены"
        else
            local lines = {}
            for _, ev in ipairs(list) do
                table.insert(lines, "• " .. ev.Name .. (ev.JoinedAt and " (в игре)" or ""))
            end
            eventListLabel.Text = table.concat(lines, "\n")
        end
    end)

    addSection(tab, "Действия")

    GUI:AddButton(tab, "Сканировать сейчас", function()
        local new = Events:DetectNewEvents()
        local count = 0
        for _ in pairs(new) do count = count + 1 end
        Notify:Info("Events", "Новых: " .. count)
    end)

    GUI:AddButton(tab, "Trigger Tsunami", function()
        Events:TriggerTsunami()
    end)

    GUI:AddButton(tab, "История (консоль)", function()
        Events:PrintStatus()
        Notify:Info("Events", "Вывод в F9")
    end)
end

-- ============================================================
-- TAB: STATS
-- ============================================================
function UI:BuildStatsTab()
    local tab = GUI:AddTab("Stats")
    self.State.Tabs.Stats = tab

    addSection(tab, "Текущее")

    local moneyLabel    = GUI:AddLabel(tab, "Money: 0")
    local incomeLabel   = GUI:AddLabel(tab, "Income: 0/s")
    local speedLabel    = GUI:AddLabel(tab, "Speed: 16 | Carry: 1")
    local rebirthLabel  = GUI:AddLabel(tab, "Rebirths: 0")
    local sessionLabel  = GUI:AddLabel(tab, "Session: 0s")
    local placedLabel   = GUI:AddLabel(tab, "Placed: 0")

    addSection(tab, "Счётчики")

    local collectedLabel = GUI:AddLabel(tab, "Collected: 0")
    local soldLabel      = GUI:AddLabel(tab, "Sold: 0")
    local earnedLabel    = GUI:AddLabel(tab, "Earned: 0")
    local errorsLabel    = GUI:AddLabel(tab, "Errors: 0")

    addLiveUpdater(function()
        local s = Stats:GetSummary()
        moneyLabel.Text = "Money: " .. Stats:FormatMoney(s.Money)
        incomeLabel.Text = "Income: " .. Stats:FormatMoney(s.IncomePerSec) .. "/s (средн. " .. Stats:FormatMoney(Stats:GetAverageIncome()) .. "/s)"
        speedLabel.Text = string.format("Speed: %d | Carry: %d", s.Speed, s.CarryCapacity)
        rebirthLabel.Text = "Rebirths: " .. s.Rebirths
        sessionLabel.Text = "Session: " .. Stats:FormatTime(s.SessionTime)
        placedLabel.Text = "Placed: " .. s.Placed

        collectedLabel.Text = "Collected: " .. s.TotalCollected
        soldLabel.Text = "Sold: " .. s.TotalSold
        earnedLabel.Text = "Earned: " .. Stats:FormatMoney(s.TotalEarned)
        errorsLabel.Text = "Errors: " .. s.TotalErrors
    end)

    addSection(tab, "Действия")

    GUI:AddButton(tab, "Детальный отчёт (F9)", function()
        Stats:PrintStatus()
        Stats:PrintRarityStats()
        Notify:Info("Stats", "Вывод в консоль")
    end)

    GUI:AddButton(tab, "Сохранить статистику в файл", function()
        Stats:SaveToFile()
        Notify:Success("Stats", "Сохранено")
    end)

    GUI:AddButton(tab, "Сбросить статистику", function()
        Stats:Reset()
        Notify:Info("Stats", "Сброшено")
    end)
end

-- ============================================================
-- TAB: TRADING
-- ============================================================
function UI:BuildTradingTab()
    local tab = GUI:AddTab("Trading")
    self.State.Tabs.Trading = tab

    addSection(tab, "Автоматизация")

    GUI:AddToggle(tab, "Trading Enabled", Trading.State.Enabled, function(v)
        if v then Trading:Enable() else Trading:Disable() end
    end)

    GUI:AddToggle(tab, "Auto Accept", Trading.State.AutoAccept, function(v)
        Trading:SetAutoAccept(v)
    end)

    GUI:AddToggle(tab, "Auto Decline Scam", Trading.State.AutoDeclineScam, function(v)
        Trading:SetAutoDeclineScam(v)
    end)

    GUI:AddToggle(tab, "Use Whitelist", Trading.State.UseWhitelist, function(v)
        Trading:SetUseWhitelist(v)
    end)

    addSection(tab, "Параметры")

    GUI:AddSlider(tab, "Accept Margin (x100)", 100, 500, math.floor(Trading.State.AutoAcceptMargin * 100), function(v)
        Trading:SetAutoAcceptMargin(v / 100)
    end)

    GUI:AddSlider(tab, "Min Gain (тир)", 1, 13, 1, function(v)
        local r = BrainrotDB.Rarities[v]
        if r then Trading:SetMinValueGain(r.IncomeMin) end
    end)

    addSection(tab, "Отправить оффер")

    local targetBox = GUI:AddTextBox(tab, "Имя получателя...", nil)
    local giveBox   = GUI:AddTextBox(tab, "Отдаю (через запятую)...", nil)
    local wantBox   = GUI:AddTextBox(tab, "Хочу (через запятую)...", nil)

    GUI:AddButton(tab, "Отправить оффер", function()
        local target = targetBox.Text
        if not target or target == "" then
            Notify:Warn("Trade", "Укажи получателя")
            return
        end
        local give = {}
        for name in (giveBox.Text or ""):gmatch("[^,]+") do
            table.insert(give, name:match("^%s*(.-)%s*$"))
        end
        local want = {}
        for name in (wantBox.Text or ""):gmatch("[^,]+") do
            table.insert(want, name:match("^%s*(.-)%s*$"))
        end
        local ok, err = Trading:SendOffer(target, give, want)
        if not ok then
            Notify:Error("Trade", "Ошибка: " .. tostring(err))
        end
    end)

    addSection(tab, "Чёрный список")

    local blockBox = GUI:AddTextBox(tab, "Имя игрока...", nil)
    GUI:AddButton(tab, "Заблокировать", function()
        if blockBox.Text ~= "" then
            Trading:SetBlocked(blockBox.Text, true)
            Notify:Info("Block", blockBox.Text .. " заблокирован")
        end
    end)
    GUI:AddButton(tab, "Разблокировать", function()
        if blockBox.Text ~= "" then
            Trading:SetBlocked(blockBox.Text, false)
            Notify:Info("Block", blockBox.Text .. " разблокирован")
        end
    end)

    addSection(tab, "Информация")

    local tradeStatus = GUI:AddLabel(tab, "Офферов: 0")
    addLiveUpdater(function()
        if tradeStatus and tradeStatus.Parent then
            tradeStatus.Text = string.format("Входящих: %d | Исходящих: %d | История: %d",
                #Trading.State.PendingOffers,
                #Trading.State.OutgoingOffers,
                #Trading.State.History)
        end
    end)
end

-- ============================================================
-- TAB: QUESTS
-- ============================================================
function UI:BuildQuestsTab()
    local tab = GUI:AddTab("Quests")
    self.State.Tabs.Quests = tab

    addSection(tab, "Автоматизация")

    GUI:AddToggle(tab, "Quests Enabled", Quests.State.Enabled, function(v)
        if v then Quests:Enable() else Quests:Disable() end
    end)

    GUI:AddToggle(tab, "Auto Progress", Quests.State.AutoProgress, function(v)
        Quests:SetAutoProgress(v)
    end)

    GUI:AddToggle(tab, "Auto Claim", Quests.State.AutoClaim, function(v)
        Quests:SetAutoClaim(v)
    end)

    addSection(tab, "Активные квесты")

    local questListLabel = GUI:AddLabel(tab, "Загрузка...")
    addLiveUpdater(function()
        if not questListLabel or not questListLabel.Parent then return end
        local active = Quests:GetActive()
        local lines = {}
        local count = 0
        for id, q in pairs(active) do
            count = count + 1
            local mark = q.Completed and "✓" or "…"
            table.insert(lines, string.format("%s %s [%d/%d]", mark, q.Name, q.Progress or 0, q.Target or 1))
        end
        if count == 0 then
            questListLabel.Text = "Нет активных квестов"
        else
            questListLabel.Text = table.concat(lines, "\n")
        end
    end)

    addSection(tab, "Действия")

    GUI:AddButton(tab, "Обновить сейчас", function()
        Quests:UpdateActive()
        Notify:Info("Quests", "Обновлено")
    end)

    GUI:AddButton(tab, "Статус (F9)", function()
        Quests:PrintStatus()
    end)

    GUI:AddButton(tab, "Сбросить историю", function()
        Quests.State.History = {}
        Notify:Info("Quests", "История очищена")
    end)
end

-- ============================================================
-- TAB: KEYBINDS
-- ============================================================
function UI:BuildKeybindsTab()
    local tab = GUI:AddTab("Keys")
    self.State.Tabs.Keybinds = tab

    addSection(tab, "Все привязки")

    local listLabel = GUI:AddLabel(tab, "Загрузка...")
    local rebuildKeyList

    rebuildKeyList = function()
        local binds = Keybinds:GetAll()
        local lines = {}
        local list = {}
        for _, entry in pairs(binds) do
            table.insert(list, entry)
        end
        table.sort(list, function(a, b) return a.Name < b.Name end)
        for _, e in ipairs(list) do
            table.insert(lines, string.format("%-20s : %s", e.Name, Keybinds:GetKeyString(e.Name)))
        end
        listLabel.Text = #lines > 0 and table.concat(lines, "\n") or "Нет привязок"
    end
    rebuildKeyList()

    addSection(tab, "Изменить привязку")

    local bindActionBox = GUI:AddTextBox(tab, "Имя действия...", nil)
    local captureLabel = GUI:AddLabel(tab, "Нажми кнопку для захвата клавиши")

    GUI:AddButton(tab, "Начать захват клавиши", function()
        if bindActionBox.Text == "" then
            Notify:Warn("Keys", "Укажи имя действия")
            return
        end
        captureLabel.Text = "Ожидание клавиши..."
        Keybinds:StartCapture(function(keyCode)
            if keyCode then
                local ok = Keybinds:SetKey(bindActionBox.Text, keyCode)
                if ok then
                    captureLabel.Text = "Установлено: " .. keyCode.Name
                    Notify:Success("Keys", bindActionBox.Text .. " -> " .. keyCode.Name)
                    rebuildKeyList()
                else
                    captureLabel.Text = "Не найдено действие: " .. bindActionBox.Text
                    Notify:Error("Keys", "Действие не зарегистрировано")
                end
            else
                captureLabel.Text = "Захват отменён"
            end
        end)
    end)

    addSection(tab, "Утилиты")

    GUI:AddButton(tab, "Сбросить все привязки", function()
        for name, _ in pairs(Keybinds:GetAll()) do
            -- Возвращаем к дефолту, если есть
            for _, def in ipairs(Keybinds.DefaultActions) do
                if def.Name == name then
                    Keybinds:SetKey(name, def.Key)
                    break
                end
            end
        end
        rebuildKeyList()
        Notify:Info("Keys", "Сброшено")
    end)

    GUI:AddButton(tab, "Проверить конфликты", function()
        local conflicts = Keybinds:GetConflicts()
        local n = 0
        for _ in pairs(conflicts) do n = n + 1 end
        if n == 0 then
            Notify:Success("Keys", "Конфликтов нет")
        else
            Keybinds:PrintStatus()
            Notify:Warn("Keys", "Конфликтов: " .. n .. " (F9)")
        end
    end)
end

-- ============================================================
-- TAB: SETTINGS
-- ============================================================
function UI:BuildSettingsTab()
    local tab = GUI:AddTab("Settings")
    self.State.Tabs.Settings = tab

    addSection(tab, "Интерфейс")

    local keyLabel = GUI:AddLabel(tab, "Toggle Key: " .. Config.UIToggleKey.Name)

    GUI:AddButton(tab, "Сменить клавишу меню", function()
        keyLabel.Text = "Нажми новую клавишу..."
        Keybinds:StartCapture(function(keyCode)
            if keyCode then
                Config.UIToggleKey = keyCode
                keyLabel.Text = "Toggle Key: " .. keyCode.Name
                Notify:Success("UI", "Новая клавиша: " .. keyCode.Name)
            else
                keyLabel.Text = "Toggle Key: " .. Config.UIToggleKey.Name
            end
        end)
    end)

    GUI:AddToggle(tab, "Sound Notifications", Notify.State.SoundEnabled, function(v)
        Notify:SetSoundEnabled(v)
    end)

    GUI:AddSlider(tab, "Sound Volume (x100)", 0, 100, math.floor(Notify.State.SoundVolume * 100), function(v)
        Notify:SetVolume(v / 100)
    end)

    GUI:AddSlider(tab, "Notification Duration (сек)", 1, 15, Notify.State.DefaultDuration, function(v)
        Notify:SetDefaultDuration(v)
    end)

    addSection(tab, "Конфиг")

    GUI:AddToggle(tab, "Auto Save Config", Config.AutoSave, function(v)
        Config.AutoSave = v
    end)

    GUI:AddButton(tab, "Сохранить конфиг сейчас", function()
        Config:Save()
        Notify:Success("Config", "Сохранено")
    end)

    GUI:AddButton(tab, "Загрузить конфиг", function()
        Config:Load()
        Notify:Info("Config", "Загружено (требуется релоад UI)")
    end)

    GUI:AddButton(tab, "Сбросить всё и перезапустить", function()
        Config:Save()
        Notify:Warn("Reload", "Перезапуск...")
        task.wait(1)
        -- Пытаемся перезапустить через queue_on_teleport (если есть скрипт)
        if Executor.queue_on_teleport and AntiAFK.State.QueueScript ~= "" then
            Executor.queue_on_teleport(AntiAFK.State.QueueScript)
        end
        AntiAFK:Rejoin()
    end)

    addSection(tab, "Информация")

    GUI:AddLabel(tab, "ETFB Hub v" .. Config.Version)
    GUI:AddLabel(tab, "Автор: Fox для Jack")
    GUI:AddLabel(tab, "Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
end

-- ============================================================
-- TAB: DEBUG
-- ============================================================
function UI:BuildDebugTab()
    local tab = GUI:AddTab("Debug")
    self.State.Tabs.Debug = tab

    addSection(tab, "Дампы (в F9)")

    GUI:AddButton(tab, "Dump Remotes", function()
        GameModule:DumpRemotes()
        Notify:Info("Dump", "Remotes в консоль")
    end)

    GUI:AddButton(tab, "Dump Objects", function()
        GameModule:DumpObjects()
        Notify:Info("Dump", "Objects в консоль")
    end)

    GUI:AddButton(tab, "Dump BrainrotDB", function()
        BrainrotDB:Dump()
        Notify:Info("Dump", "BrainrotDB в консоль")
    end)

    GUI:AddButton(tab, "Dump Keybinds", function()
        Keybinds:PrintStatus()
    end)

    GUI:AddButton(tab, "Dump Stats", function()
        Stats:PrintStatus()
        Stats:PrintRarityStats()
    end)

    GUI:AddButton(tab, "Dump Quests", function()
        Quests:PrintStatus()
    end)

    GUI:AddButton(tab, "Dump Trading", function()
        Trading:PrintStatus()
    end)

    GUI:AddButton(tab, "Dump AntiAFK", function()
        AntiAFK:PrintStatus()
    end)

    addSection(tab, "Управление")

    GUI:AddToggle(tab, "Debug Mode (логи)", Config.Debug, function(v)
        Config.Debug = v
    end)

    GUI:AddButton(tab, "Rescan GameModule", function()
        GameModule:Reset()
        GameModule:Init()
        Notify:Success("Rescan", "GameModule переинициализирован")
    end)

    GUI:AddButton(tab, "Teleport в случайную точку карты", function()
        local hrp = Util:GetHRP()
        if hrp then
            local r = math.random(-1000, 1000)
            Teleports:ToCoords(r, 200, r)
        end
    end)

    addSection(tab, "Информация")

    local infoLabel = GUI:AddLabel(tab, "…")
    addLiveUpdater(function()
        if not infoLabel or not infoLabel.Parent then return end
        local s = Stats:GetSummary()
        local q = Quests:GetSummary()
        infoLabel.Text = string.format(
            "Player: %s (%d)\nPlace: %d\nJob: %s\nFPS: %d | Ping: %d",
            LocalPlayer.Name,
            LocalPlayer.UserId,
            game.PlaceId,
            game.JobId:sub(1, 8),
            math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1e-4)),
            0
        )
    end)
end

-- ============================================================
-- LIVE UPDATER
-- ============================================================
function UI:StartLiveUpdater()
    if self.State.UpdaterRunning then return end
    self.State.UpdaterRunning = true

    task.spawn(function()
        while self.State.UpdaterRunning do
            for _, fn in ipairs(self.State.LiveUpdaters) do
                local ok, err = pcall(fn)
                if not ok then
                    Util:Warn("UI live updater ошибка:", err)
                end
            end
            task.wait(0.5)
        end
    end)
end

function UI:StopLiveUpdater()
    self.State.UpdaterRunning = false
end
-- ============================================================
-- INIT / MAIN
-- Финальная сборка: регистрация, инициализация, запуск
-- ============================================================
local Main = {}
Main.__index = Main

Main.State = {
    Initialized     = false,
    StartTime       = 0,
    AutoSaveConn    = nil,
    ErrorCount      = 0,
    LastError       = nil,
    UnloadFunctions = {},   -- сюда регистрируем cleanup-функции
}

-- ============================================================
-- БЕЗОПАСНЫЙ ЗАПУСК МОДУЛЯ
-- ============================================================
local function safeInit(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        Main.State.ErrorCount = Main.State.ErrorCount + 1
        Main.State.LastError = {Module = name, Error = tostring(err), Time = tick()}
        warn("[ETFB] Ошибка инициализации " .. name .. ": " .. tostring(err))
    else
        Util:Log("Инициализирован:", name)
    end
    return ok
end

-- ============================================================
-- РЕГИСТРАЦИЯ KEYBINDS
-- ============================================================
function Main:RegisterKeybinds()
    -- Toggle UI
    Keybinds:Register("ToggleUI", Config.UIToggleKey, function()
        GUI:Toggle()
    end, {Category = "UI", Description = "Показать/скрыть меню"})

    -- AutoFarm
    Keybinds:Register("ToggleAutoFarm", Enum.KeyCode.F1, function()
        if AutoFarm:IsRunning() then
            AutoFarm:Stop()
            Notify:Info("Farm", "Автофарм выключен")
        else
            AutoFarm:Start()
            Notify:Success("Farm", "Автофарм запущен")
        end
    end, {Category = "Farm", Description = "Вкл/выкл автофарм"})

    -- ESP
    Keybinds:Register("ToggleESP", Enum.KeyCode.F2, function()
        ESP:Toggle()
        Notify:Info("ESP", ESP.State.Enabled and "Включён" or "Выключен")
    end, {Category = "Visual", Description = "Вкл/выкл ESP"})

    -- Fly
    Keybinds:Register("ToggleFly", Enum.KeyCode.F3, function()
        if PlayerMods.State.Flying then
            PlayerMods:DisableFly()
            Notify:Info("Fly", "Выключен")
        else
            PlayerMods:EnableFly()
            Notify:Success("Fly", "Включён")
        end
    end, {Category = "Movement", Description = "Вкл/выкл полёт"})

    -- GodMode
    Keybinds:Register("ToggleGodMode", Enum.KeyCode.F4, function()
        if PlayerMods.State.GodMode then
            PlayerMods:DisableGodMode()
            Notify:Info("GodMode", "Выключен")
        else
            PlayerMods:EnableGodMode()
            Notify:Success("GodMode", "Включён")
        end
    end, {Category = "Player", Description = "Вкл/выкл godmode"})

    -- Noclip
    Keybinds:Register("ToggleNoclip", Enum.KeyCode.F5, function()
        if PlayerMods.State.Noclip then
            PlayerMods:DisableNoclip()
            Notify:Info("Noclip", "Выключен")
        else
            PlayerMods:EnableNoclip()
            Notify:Success("Noclip", "Включён")
        end
    end, {Category = "Movement", Description = "Вкл/выкл noclip"})

    -- Teleports
    Keybinds:Register("TeleportBase", Enum.KeyCode.G, function()
        Teleports:ToBase()
    end, {Category = "Teleport", Description = "Телепорт на базу"})

    Keybinds:Register("TeleportSell", Enum.KeyCode.H, function()
        Teleports:ToSellZone()
    end, {Category = "Teleport", Description = "Телепорт к продаже"})

    Keybinds:Register("TeleportBest", Enum.KeyCode.B, function()
        Teleports:ToBestBrainrot()
    end, {Category = "Teleport", Description = "Телепорт к лучшему брейнроту"})

    -- Utility
    Keybinds:Register("Rejoin", Enum.KeyCode.RightControl, function()
        Notify:Warn("Rejoin", "Перезаход через 2 сек...")
        task.wait(2)
        AntiAFK:Rejoin()
    end, {Category = "Utility", Description = "Перезаход в сервер"})

    Keybinds:Register("PanicKey", Enum.KeyCode.Delete, function()
        Notify:Warn("PANIC", "Отключаю всё...")
        AutoFarm:Stop()
        ESP:Disable()
        PlayerMods:ResetAll()
        Events:Disable()
        Trading:Disable()
        Quests:Disable()
        AntiAFK:Disable()
        Notify:Info("PANIC", "Все модули выключены")
    end, {Category = "Utility", Description = "Экстренное отключение"})

    -- Загружаем сохранённые привязки
    Keybinds:Load()

    Util:Log("Keybinds зарегистрированы")
end

-- ============================================================
-- РЕГИСТРАЦИЯ ЧАТ-КОМАНД
-- ============================================================
function Main:RegisterChatCommands()
    safeInit("ChatCommands:RegisterDefaults", function()
        ChatCommands:RegisterDefaultCommands()
    end)
    Util:Log("Чат-команды зарегистрированы")
end

-- ============================================================
-- АВТОСОХРАНЕНИЕ
-- ============================================================
function Main:StartAutoSave()
    if self.State.AutoSaveConn then
        self.State.AutoSaveConn:Disconnect()
    end

    self.State.AutoSaveConn = RunService.Heartbeat:Connect(function()
        -- Раз в SaveInterval секунд
        if not Main._lastSave or tick() - Main._lastSave >= Config.SaveInterval then
            Main._lastSave = tick()
            pcall(function()
                Config:Save()
                Keybinds:Save()
            end)
        end
    end)
end

-- ============================================================
-- УБОРКА ПРИ ВЫХОДЕ
-- ============================================================
function Main:RegisterUnload(fn)
    table.insert(self.State.UnloadFunctions, fn)
end

function Main:Unload()
    Util:Log("ETFB: выгрузка...")

    -- Останавливаем все модули
    pcall(function() AutoFarm:Stop() end)
    pcall(function() ESP:Disable() end)
    pcall(function() PlayerMods:ResetAll() end)
    pcall(function() Events:Disable() end)
    pcall(function() Trading:Disable() end)
    pcall(function() Quests:Disable() end)
    pcall(function() AntiAFK:Disable() end)
    pcall(function() Keybinds:Stop() end)
    pcall(function() ChatCommands:Stop() end)
    pcall(function() Stats:Stop() end)
    pcall(function() UI:StopLiveUpdater() end)

    -- Сохраняем состояние
    pcall(function() Config:Save() end)
    pcall(function() Keybinds:Save() end)
    pcall(function() Stats:SaveToFile() end)

    -- Disconnect
    if self.State.AutoSaveConn then
        self.State.AutoSaveConn:Disconnect()
        self.State.AutoSaveConn = nil
    end

    -- Убираем UI
    pcall(function()
        if GUI.ScreenGui then GUI.ScreenGui:Destroy() end
    end)
    pcall(function()
        if ESP.Root then ESP.Root:Destroy() end
    end)
    pcall(function()
        if Notify.State.Root then Notify.State.Root:Destroy() end
    end)

    -- Пользовательские cleanup
    for _, fn in ipairs(self.State.UnloadFunctions) do
        pcall(fn)
    end

    Main.State.Initialized = false
    Util:Log("ETFB: выгружено")
end

-- ============================================================
-- ГЛАВНАЯ ИНИЦИАЛИЗАЦИЯ
-- ============================================================
function Main:Init()
    if self.State.Initialized then
        Util:Warn("Main: уже инициализирован")
        return
    end

    self.State.StartTime = tick()

    print("=========================================")
    print("  ETFB Hub v" .. Config.Version .. " | Fox for Jack")
    print("  Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
    print("  Инициализация...")
    print("=========================================")

    -- 1. Загружаем конфиг
    safeInit("Config:Load", function() Config:Load() end)

    -- 2. Инициализируем GameModule (сканируем ремоуты и объекты)
    safeInit("GameModule:Init", function() GameModule:Init() end)

    -- 3. Загружаем состояние AntiAFK
    safeInit("AntiAFK:LoadState", function() AntiAFK:LoadState() end)

    -- 4. Регистрируем keybinds
    safeInit("RegisterKeybinds", function() self:RegisterKeybinds() end)

    -- 5. Регистрируем чат-команды
    safeInit("RegisterChatCommands", function() self:RegisterChatCommands() end)

    -- 6. Запускаем Keybinds обработчик
    safeInit("Keybinds:Start", function() Keybinds:Start() end)

    -- 7. Запускаем чат-хук
    safeInit("ChatCommands:Start", function() ChatCommands:Start() end)

    -- 8. Запускаем Stats tracker
    safeInit("Stats:Start", function() Stats:Start() end)

    -- 9. Строим UI
    safeInit("UI:Build", function() UI:Build() end)

    -- 10. Запускаем автосохранение
    safeInit("StartAutoSave", function() self:StartAutoSave() end)

    -- 11. Подключаемся к CharacterAdded (для переприменения модов)
    safeInit("CharacterAdded hook", function()
        LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(1)
            -- Переприменяем активные моды
            if PlayerMods.State.GodMode then PlayerMods:EnableGodMode() end
            if PlayerMods.State.SpeedEnabled then PlayerMods:SetWalkSpeed(Config.WalkSpeed) end
            if PlayerMods.State.JumpEnabled then PlayerMods:SetJumpPower(Config.JumpPower) end
            if PlayerMods.State.Noclip then PlayerMods:EnableNoclip() end
            if PlayerMods.State.AntiTsunami then PlayerMods:EnableAntiTsunami() end
            if PlayerMods.State.AntiJail then PlayerMods:EnableAntiJail() end
            if PlayerMods.State.AntiFling then PlayerMods:EnableAntiFling() end
            if PlayerMods.State.InfiniteJump then PlayerMods:EnableInfiniteJump() end
        end)
    end)

    -- 12. Подключаемся к OnTeleport (сохраняем состояние перед перезаходом)
    safeInit("OnTeleport hook", function()
        LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Started then
                pcall(function() Config:Save() end)
                pcall(function() Keybinds:Save() end)
                pcall(function() AntiAFK:SaveState() end)
            end
        end)
    end)

    -- 13. Приветственное уведомление
    task.delay(1, function()
        Notify:Success("ETFB Hub", "Загружено за " .. string.format("%.1f", tick() - self.State.StartTime) .. "с")
        Notify:Info("Меню", "Клавиша: " .. Config.UIToggleKey.Name, 6)
    end)

    self.State.Initialized = true

    Util:Log("Main:Init завершён за", string.format("%.2f", tick() - self.State.StartTime), "сек")
end

-- ============================================================
-- ПУБЛИЧНОЕ API (для чата и внешних скриптов)
-- ============================================================
getgenv().ETFB = {
    Config = Config,
    Util = Util,
    GameModule = GameModule,
    BrainrotDB = BrainrotDB,
    AutoFarm = AutoFarm,
    PlayerMods = PlayerMods,
    Teleports = Teleports,
    ESP = ESP,
    Events = Events,
    AntiAFK = AntiAFK,
    Notify = Notify,
    Keybinds = Keybinds,
    ChatCommands = ChatCommands,
    Stats = Stats,
    Trading = Trading,
    Quests = Quests,
    GUI = GUI,
    UI = UI,
    Main = Main,
    Unload = function() Main:Unload() end,
    Reinit = function()
        Main:Unload()
        task.wait(0.5)
        Main:Init()
    end,
}

Util:Log("ETFB API доступен через getgenv().ETFB")

-- ============================================================
-- ЗАПУСК
-- ============================================================
task.spawn(function()
    -- Небольшая задержка, чтобы игра успела прогрузиться
    task.wait(0.5)

    -- Дожидаемся персонажа
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
        task.wait(1)
    end

    -- Запускаем инициализацию
    Main:Init()
end)

-- ============================================================
-- ОБРАБОТКА ОШИБОК (глобальный хук)
-- ============================================================
task.spawn(function()
    while true do
        task.wait(5)
        if Main.State.ErrorCount > 0 then
            local last = Main.State.LastError
            if last and tick() - last.Time < 5 then
                Util:Warn("Последняя ошибка в модуле", last.Module, ":", last.Error)
            end
        end
    end
end)

-- ============================================================
-- КОНЕЦ СБОРКИ
-- ============================================================
Util:Log("ETFB: single-file build v" .. Config.Version .. " загружен, ожидание инициализации...")
