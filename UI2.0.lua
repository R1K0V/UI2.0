--[[
    R1K0V-HUB UI — Full production (no demo)
    Total Black | NeverLose layout | Any executor
    Features: toggle, slider, dropdown (list), button, textbox, keybind,
    notifications, config save/load, floating icon, resize, profile, singleton
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.Flags = {}
Library.Connections = {}
Library.Open = true
Library.Animating = false
Library.Minimized = false
Library.Keybinds = {} -- { flag = { Key = Enum, Callback = fn, Name = str } }
Library.ConfigFolder = "R1K0V_HUB"
Library.ConfigName = "default"
Library.Theme = {
    Background = Color3.fromRGB(8, 8, 8),
    Sidebar = Color3.fromRGB(12, 12, 12),
    Section = Color3.fromRGB(16, 16, 16),
    Element = Color3.fromRGB(22, 22, 22),
    ElementHover = Color3.fromRGB(28, 28, 28),
    Border = Color3.fromRGB(32, 32, 32),
    Accent = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(235, 235, 235),
    TextDim = Color3.fromRGB(140, 140, 140),
    ToggleOff = Color3.fromRGB(45, 45, 45),
    ToggleOn = Color3.fromRGB(255, 255, 255),
    SliderBg = Color3.fromRGB(30, 30, 30),
}

local function keyToString(k)
    if not k then return "None" end
    if typeof(k) == "EnumItem" then
        if k.EnumType == Enum.KeyCode then return k.Name end
        if k.EnumType == Enum.UserInputType then return k.Name end
    end
    return tostring(k)
end

function Library:SetAccent(c)
    if typeof(c) ~= "Color3" then return end
    Library.Theme.Accent = c
    Library.Theme.ToggleOn = c
    -- refresh visible accent labels if window exists
    if Library.Window and Library.Window._main then
        for _, d in ipairs(Library.Window._main:GetDescendants()) do
            if d:IsA("TextLabel") and d.TextColor3 == Color3.fromRGB(255, 255, 255) then
                -- skip generic white
            end
        end
    end
end

function Library:SaveConfig(name)
    name = name or Library.ConfigName or "default"
    local data = {
        Flags = {},
        Accent = {
            R = Library.Theme.Accent.R,
            G = Library.Theme.Accent.G,
            B = Library.Theme.Accent.B,
        },
    }
    for k, v in pairs(Library.Flags) do
        local t = typeof(v)
        if t == "Color3" then
            data.Flags[k] = { __type = "Color3", R = v.R, G = v.G, B = v.B }
        elseif t == "EnumItem" then
            data.Flags[k] = { __type = "Enum", EnumType = tostring(v.EnumType), Name = v.Name }
        else
            data.Flags[k] = v
        end
    end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then return false end
    local path = Library.ConfigFolder .. "/" .. name .. ".json"
    pcall(function()
        if isfolder and not isfolder(Library.ConfigFolder) then
            makefolder(Library.ConfigFolder)
        end
    end)
    local wok = pcall(function()
        if writefile then writefile(path, encoded) end
    end)
    return wok
end

function Library:LoadConfig(name)
    name = name or Library.ConfigName or "default"
    local path = Library.ConfigFolder .. "/" .. name .. ".json"
    local ok, raw = pcall(function()
        if isfile and isfile(path) and readfile then
            return readfile(path)
        end
        return nil
    end)
    if not ok or not raw then return false end
    local dok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not dok or type(data) ~= "table" then return false end
    if data.Accent then
        Library:SetAccent(Color3.new(data.Accent.R or 1, data.Accent.G or 1, data.Accent.B or 1))
    end
    if type(data.Flags) == "table" then
        for k, v in pairs(data.Flags) do
            if type(v) == "table" and v.__type == "Color3" then
                Library.Flags[k] = Color3.new(v.R, v.G, v.B)
            elseif type(v) == "table" and v.__type == "Enum" then
                pcall(function()
                    Library.Flags[k] = Enum[v.EnumType][v.Name]
                end)
            else
                Library.Flags[k] = v
            end
        end
    end
    return true
end

local TWEEN_SMOOTH = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_FAST = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_TAB = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_MOVE = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_RESIZE = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function protectGui(gui)
    local ok = false
    pcall(function()
        if gethui then
            gui.Parent = gethui()
            ok = true
        end
    end)
    if ok then return end
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = CoreGui
            ok = true
        end
    end)
    if ok then return end
    pcall(function()
        gui.Parent = CoreGui
        ok = true
    end)
    if not ok or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function make(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            obj[k] = v
        end
    end
    if props and props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

local function corner(parent, r)
    return make("UICorner", { CornerRadius = UDim.new(0, r or 4), Parent = parent })
end

local function stroke(parent, color, thickness)
    return make("UIStroke", {
        Color = color or Library.Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, t, b, l, r)
    return make("UIPadding", {
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        Parent = parent,
    })
end

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(Library.Connections, c)
    return c
end

local function tween(obj, ti, props)
    local t = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

-- Resolve icon: number / "rbxassetid://123" / full url
local function resolveIcon(icon)
    if icon == nil or icon == "" then return nil end
    if type(icon) == "number" then
        return "rbxassetid://" .. tostring(icon)
    end
    local s = tostring(icon)
    if s:match("^%d+$") then
        return "rbxassetid://" .. s
    end
    if s:find("rbxassetid://") or s:find("http") or s:find("rbxthumb") then
        return s
    end
    return nil
end

function Library:CreateNotification()
    -- singleton: reuse one notification stack
    if Library._NotifAPI then
        return Library._NotifAPI
    end

    local gui = make("ScreenGui", {
        Name = "R1K0V_Notifications",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        IgnoreGuiInset = true,
        Enabled = true,
    })
    protectGui(gui)
    if not gui.Parent then
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
    if not gui.Parent then
        pcall(function()
            gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        end)
    end
    Library._NotifGui = gui

    local holder = make("Frame", {
        Name = "Holder",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.new(1, -320, 0, 20),
        Parent = gui,
    })
    make("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = holder,
    })

    local DEFAULT_ICON = "rbxassetid://90477855353953"
    local TWEEN_NOTIF_IN = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local TWEEN_NOTIF_OUT = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

    local api = {}
    -- Notify(title, text, duration, icon) — icon + text, shine + fade
    function api:Notify(title, text, duration, icon)
        duration = duration or 3
        local iconSrc = resolveIcon(icon) or DEFAULT_ICON

        local card = make("Frame", {
            BackgroundColor3 = Library.Theme.Section,
            Size = UDim2.new(1, 0, 0, 56),
            ClipsDescendants = true,
            BackgroundTransparency = 1,
            Parent = holder,
        })
        corner(card, 8)
        local cardStroke = stroke(card, Color3.fromRGB(255, 255, 255), 1.5)
        cardStroke.Transparency = 1

        local scale = make("UIScale", { Scale = 0.85, Parent = card })

        local iconFrame = make("Frame", {
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(0, 36, 0, 36),
            Position = UDim2.new(0, 10, 0.5, -18),
            BackgroundTransparency = 1,
            Parent = card,
        })
        corner(iconFrame, 8)
        local iconImg = make("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(0.5, -11, 0.5, -11),
            Image = iconSrc,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            Parent = iconFrame,
        })

        local titleLbl = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -60, 0, 18),
            Position = UDim2.new(0, 54, 0, 10),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Library.Theme.Accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 1,
            Text = tostring(title or "R1K0V-HUB"),
            Parent = card,
        })
        local textLbl = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -60, 0, 16),
            Position = UDim2.new(0, 54, 0, 28),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Library.Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 1,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = tostring(text or ""),
            Parent = card,
        })

        -- glow shine bar
        local shine = make("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.new(0, 40, 1, 0),
            Position = UDim2.new(0, -50, 0, 0),
            BackgroundTransparency = 0.75,
            ZIndex = 5,
            Parent = card,
        })
        make("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = shine,
        })

        -- enter (force visible + tween)
        card.BackgroundTransparency = 0.08
        scale.Scale = 1
        cardStroke.Transparency = 0.35
        iconFrame.BackgroundTransparency = 0
        iconImg.ImageTransparency = 0
        titleLbl.TextTransparency = 0
        textLbl.TextTransparency = 0
        pcall(function()
            tween(card, TWEEN_NOTIF_IN, { BackgroundTransparency = 0.08 })
            tween(scale, TWEEN_NOTIF_IN, { Scale = 1 })
            tween(cardStroke, TWEEN_NOTIF_IN, { Transparency = 0.35 })
        end)

        -- shine sweep
        task.delay(0.15, function()
            if shine and shine.Parent then
                tween(shine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Position = UDim2.new(1, 20, 0, 0),
                })
            end
        end)

        task.delay(duration, function()
            if not card or not card.Parent then return end
            tween(card, TWEEN_NOTIF_OUT, { BackgroundTransparency = 1 })
            tween(scale, TWEEN_NOTIF_OUT, { Scale = 0.9 })
            tween(cardStroke, TWEEN_NOTIF_OUT, { Transparency = 1 })
            tween(iconFrame, TWEEN_NOTIF_OUT, { BackgroundTransparency = 1 })
            tween(iconImg, TWEEN_NOTIF_OUT, { ImageTransparency = 1 })
            tween(titleLbl, TWEEN_NOTIF_OUT, { TextTransparency = 1 })
            tween(textLbl, TWEEN_NOTIF_OUT, { TextTransparency = 1 })
            task.wait(0.48)
            if card and card.Parent then card:Destroy() end
        end)
    end
    setmetatable(api, {
        __call = function(_, a, b, c, d)
            api:Notify(a, b, c, d)
        end,
    })
    Library.Notify = function(_, a, b, c, d)
        api:Notify(a, b, c, d)
    end
    Library._NotifAPI = api
    return api
end

-- ======================== FPS / MS OVERLAY ========================
-- Movable translucent panel (same black theme). Toggle from your script.
function Library:CreateOverlay(opts)
    opts = opts or {}
    if Library._OverlayAPI then
        return Library._OverlayAPI
    end

    local Stats = game:GetService("Stats")
    local parentGui = make("ScreenGui", {
        Name = "R1K0V_Overlay",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9000,
        IgnoreGuiInset = true,
        Enabled = false,
    })
    protectGui(parentGui)
    if not parentGui.Parent then
        pcall(function() parentGui.Parent = game:GetService("CoreGui") end)
    end
    if not parentGui.Parent then
        pcall(function()
            parentGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        end)
    end
    Library._OverlayGui = parentGui

    local frame = make("Frame", {
        Size = UDim2.fromOffset(opts.Width or 130, opts.Height or 40),
        Position = opts.Position or UDim2.fromOffset(12, 12),
        BackgroundColor3 = Library.Theme.Background,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        Active = true,
        Parent = parentGui,
    })
    corner(frame, 6)
    stroke(frame, Library.Theme.Border, 1)

    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "FPS --  |  MS --",
        Parent = frame,
    })

    -- drag
    local dragging, startPos, startInput
    connect(frame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = frame.Position
            startInput = input.Position
        end
    end)
    connect(frame.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startInput
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    local fpsAccum, fpsFrames, lastFps = 0, 0, 0
    local hb = RunService.Heartbeat:Connect(function(dt)
        if not parentGui.Enabled then return end
        fpsAccum = fpsAccum + dt
        fpsFrames = fpsFrames + 1
        if fpsAccum >= 0.5 then
            lastFps = math.floor(fpsFrames / fpsAccum + 0.5)
            fpsAccum, fpsFrames = 0, 0
        end
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        label.Text = string.format("FPS %d  |  MS %d", lastFps, ping)
    end)
    table.insert(Library.Connections, hb)

    local api = {}
    function api:Show()
        parentGui.Enabled = true
    end
    function api:Hide()
        parentGui.Enabled = false
    end
    function api:Toggle(v)
        if v == nil then
            parentGui.Enabled = not parentGui.Enabled
        else
            parentGui.Enabled = v and true or false
        end
        return parentGui.Enabled
    end
    function api:IsVisible()
        return parentGui.Enabled
    end
    function api:SetPosition(udim)
        frame.Position = udim
    end
    function api:Destroy()
        pcall(function() hb:Disconnect() end)
        if parentGui then parentGui:Destroy() end
        Library._OverlayAPI = nil
        Library._OverlayGui = nil
    end

    Library._OverlayAPI = api
    return api
end

function Library:CreateWindow(opts)
    opts = opts or {}
    local name = opts.Name or "R1K0V-HUB"
    local content = opts.Content or "Total Black"
    local keybind = opts.Keybind or "RightShift"
    local size = opts.Size or UDim2.fromOffset(620, 420)
    local minW, minH = 420, 300
    local maxW, maxH = 1100, 800

    -- SINGLETON: destroy previous window so menus never duplicate
    pcall(function()
        if Library.Window and Library.Window.Unload then
            Library.Window:Unload()
        end
    end)
    Library.Window = nil
    pcall(function()
        local function wipe(parent)
            if not parent then return end
            for _, g in ipairs(parent:GetChildren()) do
                if g:IsA("ScreenGui") then
                    local n = string.lower(g.Name or "")
                    if string.find(n, "r1k0v_hub") or string.find(n, "r1k0v_notif") then
                        g:Destroy()
                    end
                end
            end
        end
        if gethui then wipe(gethui()) end
        wipe(game:GetService("CoreGui"))
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then wipe(pg) end
    end)

    local screen = make("ScreenGui", {
        Name = "R1K0V_HUB_Main",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 500,
        Enabled = true,
    })
    protectGui(screen)

    local main = make("Frame", {
        Name = "Main",
        BackgroundColor3 = Library.Theme.Background,
        Size = size,
        Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
        Active = true,
        Visible = true,
        ClipsDescendants = true,
        Parent = screen,
    })
    corner(main, 8)
    stroke(main, Library.Theme.Border, 1)

    -- scale for smooth open/close
    local scale = make("UIScale", { Scale = 1, Parent = main })

    local titleBar = make("Frame", {
        BackgroundColor3 = Library.Theme.Sidebar,
        Size = UDim2.new(1, 0, 0, 40),
        Parent = main,
    })
    corner(titleBar, 8)
    make("Frame", {
        BackgroundColor3 = Library.Theme.Sidebar,
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BorderSizePixel = 0,
        Parent = titleBar,
    })

    -- logo icon next to title
    local titleIcon = make("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(0, 12, 0.5, -11),
        Image = "rbxassetid://90477855353953",
        ScaleType = Enum.ScaleType.Fit,
        Parent = titleBar,
    })
    corner(titleIcon, 4)

    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 40, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Library.Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = name,
        Parent = titleBar,
    })
    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.55, 0, 0, 0),
        Size = UDim2.new(0.4, -50, 1, 0),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Library.Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = content,
        Parent = titleBar,
    })

    local closeBtn = make("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 36, 1, 0),
        Position = UDim2.new(1, -40, 0, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Library.Theme.TextDim,
        Text = "×",
        Parent = titleBar,
    })

    local SIDEBAR_W = 160
    local PLAYER_H = 52

    local sidebar = make("Frame", {
        BackgroundColor3 = Library.Theme.Sidebar,
        Size = UDim2.new(0, SIDEBAR_W, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        Parent = main,
    })
    make("Frame", {
        BackgroundColor3 = Library.Theme.Border,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BorderSizePixel = 0,
        Parent = sidebar,
    })

    -- tab list (leaves space at bottom for player)
    local tabList = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -PLAYER_H - 8),
        Position = UDim2.new(0, 0, 0, 8),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Library.Theme.Border,
        BorderSizePixel = 0,
        Parent = sidebar,
    })
    local tabLayout = make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabList,
    })
    padding(tabList, 4, 8, 8, 8)
    tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabList.CanvasSize = UDim2.new(0, 0, 0, tabLayout.AbsoluteContentSize.Y + 16)
    end)

    -- player tab fixed at bottom of sidebar
    local playerSlot = make("Frame", {
        BackgroundColor3 = Library.Theme.Element,
        Size = UDim2.new(1, -16, 0, PLAYER_H - 8),
        Position = UDim2.new(0, 8, 1, -PLAYER_H + 4),
        Parent = sidebar,
    })
    corner(playerSlot, 6)
    stroke(playerSlot, Library.Theme.Border, 1)

    local playerIcon = make("ImageLabel", {
        BackgroundColor3 = Library.Theme.Section,
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0, 8, 0.5, -16),
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
        Parent = playerSlot,
    })
    corner(playerIcon, 16)

    local playerNameLbl = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -52, 0, 18),
        Position = UDim2.new(0, 46, 0, 8),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = LocalPlayer.DisplayName or LocalPlayer.Name,
        Parent = playerSlot,
    })
    local playerUserLbl = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -52, 0, 14),
        Position = UDim2.new(0, 46, 0, 26),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Library.Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "@" .. LocalPlayer.Name,
        Parent = playerSlot,
    })

    -- load headshot
    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size48x48
            )
        end)
        if ok and content and playerIcon then
            playerIcon.Image = content
        end
    end)

    local contentArea = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -SIDEBAR_W, 1, -40),
        Position = UDim2.new(0, SIDEBAR_W, 0, 40),
        ClipsDescendants = true,
        Parent = main,
    })

    -- ===== RESIZE HANDLE (triangle dots bottom-right) =====
    local resizeHit = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -22, 1, -22),
        ZIndex = 20,
        Parent = main,
    })
    -- three dots forming a triangle (bottom-right grip)
    local function makeDot(x, y)
        local d = make("Frame", {
            BackgroundColor3 = Library.Theme.TextDim,
            Size = UDim2.new(0, 3, 0, 3),
            Position = UDim2.new(0, x, 0, y),
            ZIndex = 21,
            Parent = resizeHit,
        })
        corner(d, 2)
        return d
    end
    makeDot(14, 4)
    makeDot(14, 10)
    makeDot(8, 10)
    makeDot(14, 16)
    makeDot(8, 16)
    makeDot(2, 16)

    local resizing = false
    local resizeStart, sizeStart
    local targetSizeX, targetSizeY
    local dragRender

    connect(resizeHit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            sizeStart = main.AbsoluteSize
            targetSizeX = sizeStart.X
            targetSizeY = sizeStart.Y
        end
    end)

    -- drag window (smooth)
    local dragging, dragStart, startPos
    local targetPosX, targetPosY
    connect(titleBar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            targetPosX = startPos.X.Offset
            targetPosY = startPos.Y.Offset
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if resizing then
                resizing = false
                -- settle size smoothly to final target
                if targetSizeX and targetSizeY then
                    tween(main, TWEEN_RESIZE, { Size = UDim2.fromOffset(targetSizeX, targetSizeY) })
                end
            end
            if dragging then
                dragging = false
                if targetPosX and targetPosY then
                    tween(main, TWEEN_MOVE, {
                        Position = UDim2.new(startPos.X.Scale, targetPosX, startPos.Y.Scale, targetPosY),
                    })
                end
            end
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if resizing then
            local delta = input.Position - resizeStart
            targetSizeX = math.clamp(sizeStart.X + delta.X, minW, maxW)
            targetSizeY = math.clamp(sizeStart.Y + delta.Y, minH, maxH)
            -- soft follow while dragging resize
            local cur = main.AbsoluteSize
            local nx = cur.X + (targetSizeX - cur.X) * 0.22
            local ny = cur.Y + (targetSizeY - cur.Y) * 0.22
            main.Size = UDim2.fromOffset(nx, ny)
        elseif dragging then
            local delta = input.Position - dragStart
            targetPosX = startPos.X.Offset + delta.X
            targetPosY = startPos.Y.Offset + delta.Y
            local curX = main.Position.X.Offset
            local curY = main.Position.Y.Offset
            local nx = curX + (targetPosX - curX) * 0.25
            local ny = curY + (targetPosY - curY) * 0.25
            main.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
        end
    end)

    local Window = {
        _screen = screen,
        _main = main,
        _tabs = {},
        _current = nil,
        _tabOrder = 0,
        _playerSlot = playerSlot,
    }

    -- smooth open / close
    function Window:ToggleInterface()
        if Library.Animating then return end
        Library.Animating = true
        Library.Open = not Library.Open

        if Library.Open then
            main.Visible = true
            scale.Scale = 0.88
            main.BackgroundTransparency = 0.25
            tween(scale, TWEEN_SMOOTH, { Scale = 1 })
            tween(main, TWEEN_SMOOTH, { BackgroundTransparency = 0 })
            task.delay(0.48, function()
                Library.Animating = false
            end)
        else
            tween(scale, TWEEN_SMOOTH, { Scale = 0.88 })
            tween(main, TWEEN_SMOOTH, { BackgroundTransparency = 0.3 })
            if Window._skinPanel then
                tween(Window._skinPanel, TWEEN_SMOOTH, { BackgroundTransparency = 0.4 })
            end
            task.delay(0.42, function()
                if not Library.Open then
                    main.Visible = false
                    if Window._skinPanel then
                        Window._skinPanel.Visible = false
                    end
                    if Window._profilePanel then
                        Window._profilePanel.Visible = false
                    end
                end
                Library.Animating = false
            end)
        end
    end

    -- Watermark disabled — only floating icon opens the menu
    function Window:Watermark()
        local api = {}
        function api:AddBlock()
            return {
                SetText = function() end,
                Input = function() end,
            }
        end
        return api
    end

    function Window:AddTabLabel(text)
        Window._tabOrder = Window._tabOrder + 1
        make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -8, 0, 18),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Library.Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(tostring(text or "")),
            LayoutOrder = Window._tabOrder,
            Parent = tabList,
        })
    end

    function Window:AddTab(cfg)
        cfg = cfg or {}
        local tabName = cfg.Name or "Tab"
        local iconSrc = resolveIcon(cfg.Icon)
        Window._tabOrder = Window._tabOrder + 1

        local btn = make("TextButton", {
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, -8, 0, 34),
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = Window._tabOrder,
            Parent = tabList,
        })
        corner(btn, 4)

        local iconImg = make("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 10, 0.5, -8),
            Image = iconSrc or "",
            ImageColor3 = Library.Theme.TextDim,
            ScaleType = Enum.ScaleType.Fit,
            Parent = btn,
        })
        -- placeholder circle if no icon
        if not iconSrc then
            iconImg.BackgroundTransparency = 0
            iconImg.BackgroundColor3 = Library.Theme.Border
            corner(iconImg, 8)
        end

        local tabLabel = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -36, 1, 0),
            Position = UDim2.new(0, 32, 0, 0),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Library.Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tabName,
            Parent = btn,
        })

        local page = make("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -16, 1, -16),
            Position = UDim2.new(0, 8, 0, 8),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.Theme.Border,
            BorderSizePixel = 0,
            Visible = false,
            Parent = contentArea,
        })
        local pageScale = make("UIScale", { Scale = 1, Parent = page })
        page:SetAttribute("PageScale", true)
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = page,
        })
        local leftCol = make("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        local rightCol = make("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = leftCol })
        make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightCol })

        local function refreshCanvas()
            local h = math.max(leftCol.AbsoluteSize.Y, rightCol.AbsoluteSize.Y, 100)
            page.CanvasSize = UDim2.new(0, 0, 0, h + 20)
        end
        leftCol:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshCanvas)
        rightCol:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshCanvas)

        local Tab = { _page = page, _btn = btn, _label = tabLabel, _icon = iconImg, _scale = pageScale }

        local function selectTab()
            if Window._current == Tab then return end

            -- hide others with soft fade
            for _, t in pairs(Window._tabs) do
                if t ~= Tab then
                    tween(t._btn, TWEEN_TAB, { BackgroundColor3 = Library.Theme.Element })
                    t._label.TextColor3 = Library.Theme.TextDim
                    if t._icon then
                        t._icon.ImageColor3 = Library.Theme.TextDim
                    end
                    if t._page.Visible then
                        local sc = t._page:FindFirstChildOfClass("UIScale")
                        if sc then
                            tween(sc, TWEEN_TAB, { Scale = 0.96 })
                        end
                        task.delay(0.12, function()
                            if Window._current ~= t then
                                t._page.Visible = false
                                if sc then sc.Scale = 1 end
                            end
                        end)
                    end
                end
            end

            -- show selected with soft scale-in
            page.Visible = true
            pageScale.Scale = 0.96
            page.Position = UDim2.new(0, 8, 0, 14)
            tween(pageScale, TWEEN_TAB, { Scale = 1 })
            tween(page, TWEEN_TAB, { Position = UDim2.new(0, 8, 0, 8) })
            tween(btn, TWEEN_TAB, { BackgroundColor3 = Library.Theme.Section })
            tabLabel.TextColor3 = Library.Theme.Accent
            if iconImg then
                iconImg.ImageColor3 = Library.Theme.Accent
            end
            Window._current = Tab

            -- hide profile panel if open
            if Window._profilePanel and Window._profilePanel.Visible then
                Window:_hideProfile()
            end
        end
        connect(btn.MouseButton1Click, selectTab)

        if not Window._current then
            page.Visible = true
            tween(btn, TWEEN_TAB, { BackgroundColor3 = Library.Theme.Section })
            tabLabel.TextColor3 = Library.Theme.Accent
            if iconImg then iconImg.ImageColor3 = Library.Theme.Accent end
            Window._current = Tab
        end
        table.insert(Window._tabs, Tab)

        function Tab:AddSection(scfg)
            scfg = scfg or {}
            local sName = scfg.Name or "Section"
            local pos = string.lower(tostring(scfg.Position or "left"))
            local parentCol = (pos == "right") and rightCol or leftCol

            local section = make("Frame", {
                BackgroundColor3 = Library.Theme.Section,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = parentCol,
            })
            corner(section, 6)
            stroke(section, Library.Theme.Border, 1)
            padding(section, 8, 10, 10, 10)
            make("UIListLayout", {
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = section,
            })

            make("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = Library.Theme.Accent,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = string.upper(sName),
                Parent = section,
            })

            local Section = {}

            local function elementBase(height)
                local f = make("Frame", {
                    BackgroundColor3 = Library.Theme.Element,
                    Size = UDim2.new(1, 0, 0, height or 32),
                    Parent = section,
                })
                corner(f, 4)
                return f
            end

            function Section:AddLabel(text)
                local f = elementBase(24)
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -12, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = tostring(text or ""),
                    Parent = f,
                })
            end

            function Section:AddToggle(cfg)
                cfg = type(cfg) == "table" and cfg or { Name = tostring(cfg) }
                local title = cfg.Name or "Toggle"
                local flag = cfg.Flag
                local default = cfg.Default
                if default == nil then default = false end
                local callback = cfg.Callback

                local f = elementBase(32)
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -50, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Library.Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = title,
                    Parent = f,
                })
                local switchBg = make("Frame", {
                    BackgroundColor3 = default and Library.Theme.ToggleOn or Library.Theme.ToggleOff,
                    Size = UDim2.new(0, 36, 0, 18),
                    Position = UDim2.new(1, -46, 0.5, -9),
                    Parent = f,
                })
                corner(switchBg, 9)
                local knob = make("Frame", {
                    BackgroundColor3 = Library.Theme.Background,
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                    Parent = switchBg,
                })
                corner(knob, 7)

                local state = default
                if flag then Library.Flags[flag] = state end

                local function set(v)
                    state = v and true or false
                    if flag then Library.Flags[flag] = state end
                    tween(switchBg, TWEEN_FAST, {
                        BackgroundColor3 = state and Library.Theme.ToggleOn or Library.Theme.ToggleOff,
                    })
                    tween(knob, TWEEN_FAST, {
                        Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                    })
                    if callback then task.spawn(callback, state) end
                end

                local hit = make("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = "",
                    Parent = f,
                })
                connect(hit.MouseButton1Click, function()
                    set(not state)
                end)

                return { Set = set, Get = function() return state end, SetValue = set }
            end

            function Section:AddSlider(cfg)
                cfg = type(cfg) == "table" and cfg or {}
                local title = cfg.Name or "Slider"
                local min = cfg.Min or 0
                local max = cfg.Max or 100
                local default = math.clamp(cfg.Default or min, min, max)
                local suffix = cfg.Suffix or ""
                local flag = cfg.Flag
                local callback = cfg.Callback

                local f = elementBase(48)
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.6, 0, 0, 18),
                    Position = UDim2.new(0, 10, 0, 4),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = title,
                    Parent = f,
                })
                local valueLabel = make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.35, -10, 0, 18),
                    Position = UDim2.new(0.65, 0, 0, 4),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Text = tostring(default) .. suffix,
                    Parent = f,
                })
                local barBg = make("Frame", {
                    BackgroundColor3 = Library.Theme.SliderBg,
                    Size = UDim2.new(1, -20, 0, 6),
                    Position = UDim2.new(0, 10, 0, 30),
                    Parent = f,
                })
                corner(barBg, 3)
                local fill = make("Frame", {
                    BackgroundColor3 = Library.Theme.Accent,
                    Size = UDim2.new((default - min) / math.max(max - min, 1), 0, 1, 0),
                    Parent = barBg,
                })
                corner(fill, 3)

                local value = default
                if flag then Library.Flags[flag] = value end

                local function set(v)
                    value = math.clamp(tonumber(v) or min, min, max)
                    if flag then Library.Flags[flag] = value end
                    fill.Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0)
                    valueLabel.Text = (math.floor(value * 10) / 10) .. suffix
                    if callback then task.spawn(callback, value) end
                end

                local sliding = false
                connect(barBg.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                    end
                end)
                connect(UserInputService.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
                connect(UserInputService.InputChanged, function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local rel = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / math.max(barBg.AbsoluteSize.X, 1), 0, 1)
                        set(min + (max - min) * rel)
                    end
                end)

                return { Set = set, Get = function() return value end, SetValue = set }
            end

            function Section:AddButton(cfg)
                cfg = type(cfg) == "table" and cfg or { Name = tostring(cfg) }
                local title = cfg.Name or "Button"
                local callback = cfg.Callback
                local f = elementBase(32)
                local btn = make("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Library.Theme.Text,
                    Text = title,
                    Parent = f,
                })
                connect(btn.MouseButton1Click, function()
                    if callback then task.spawn(callback) end
                end)
                return btn
            end

            function Section:AddTextBox(cfg)
                cfg = type(cfg) == "table" and cfg or {}
                local title = cfg.Name or "TextBox"
                local placeholder = cfg.Placeholder or cfg.Default or ""
                local flag = cfg.Flag
                local callback = cfg.Callback

                local f = elementBase(56)
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -12, 0, 16),
                    Position = UDim2.new(0, 10, 0, 4),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = title,
                    Parent = f,
                })
                local boxBg = make("Frame", {
                    BackgroundColor3 = Library.Theme.SliderBg,
                    Size = UDim2.new(1, -20, 0, 26),
                    Position = UDim2.new(0, 10, 0, 24),
                    Parent = f,
                })
                corner(boxBg, 4)
                stroke(boxBg, Library.Theme.Border, 1)
                local box = make("TextBox", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -12, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.Text,
                    PlaceholderText = placeholder,
                    PlaceholderColor3 = Library.Theme.TextDim,
                    Text = cfg.Default or "",
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = boxBg,
                })
                if flag then Library.Flags[flag] = box.Text end
                connect(box.FocusLost, function(enter)
                    if flag then Library.Flags[flag] = box.Text end
                    if callback then task.spawn(callback, box.Text, enter) end
                end)
                return {
                    Set = function(_, v)
                        box.Text = tostring(v or "")
                        if flag then Library.Flags[flag] = box.Text end
                    end,
                    Get = function() return box.Text end,
                }
            end

            function Section:AddDropdown(cfg)
                cfg = cfg or {}
                local title = cfg.Name or "Dropdown"
                local items = cfg.Items or cfg.Options or { "Option 1" }
                if type(items) ~= "table" then items = { tostring(items) } end
                local default = cfg.Default or items[1]
                local flag = cfg.Flag
                local callback = cfg.Callback

                -- closed row
                local f = elementBase(32)
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.42, 0, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = title,
                    Parent = f,
                })
                local selectedLabel = make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.48, -18, 1, 0),
                    Position = UDim2.new(0.42, 0, 0, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.Accent,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = tostring(default),
                    Parent = f,
                })
                local arrow = make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 16, 1, 0),
                    Position = UDim2.new(1, -18, 0, 0),
                    Font = Enum.Font.GothamBold,
                    TextSize = 10,
                    TextColor3 = Library.Theme.TextDim,
                    Text = "▼",
                    Parent = f,
                })

                local current = default
                if flag then Library.Flags[flag] = current end

                -- expandable list (hidden until click)
                local open = false
                local listFrame = make("Frame", {
                    BackgroundColor3 = Library.Theme.Section,
                    Size = UDim2.new(1, -8, 0, 0),
                    Position = UDim2.new(0, 4, 0, 34),
                    Visible = false,
                    ClipsDescendants = true,
                    ZIndex = 50,
                    Parent = f,
                })
                corner(listFrame, 4)
                stroke(listFrame, Library.Theme.Border, 1)
                local listScroll = make("ScrollingFrame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 3,
                    ScrollBarImageColor3 = Library.Theme.Border,
                    BorderSizePixel = 0,
                    ZIndex = 51,
                    Parent = listFrame,
                })
                local listLayout = make("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1),
                    Parent = listScroll,
                })
                padding(listScroll, 2, 2, 2, 2)

                local function closeList()
                    open = false
                    listFrame.Visible = false
                    listFrame.Size = UDim2.new(1, -8, 0, 0)
                    f.Size = UDim2.new(1, 0, 0, 32)
                    arrow.Text = "▼"
                    -- refresh section canvas
                    task.defer(function()
                        local page = f.Parent
                        while page and not page:IsA("ScrollingFrame") do
                            page = page.Parent
                        end
                        if page and page:IsA("ScrollingFrame") then
                            local lay = page:FindFirstChildOfClass("UIListLayout")
                            if lay then
                                page.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 12)
                            end
                        end
                    end)
                end

                local function pick(val)
                    current = val
                    selectedLabel.Text = tostring(val)
                    if flag then Library.Flags[flag] = current end
                    closeList()
                    if callback then task.spawn(callback, current) end
                end

                local function rebuildList()
                    for _, ch in ipairs(listScroll:GetChildren()) do
                        if ch:IsA("TextButton") then ch:Destroy() end
                    end
                    for i, item in ipairs(items) do
                        local btn = make("TextButton", {
                            BackgroundColor3 = (tostring(item) == tostring(current)) and Library.Theme.Element or Library.Theme.Background,
                            Size = UDim2.new(1, -4, 0, 26),
                            Font = Enum.Font.Gotham,
                            TextSize = 12,
                            TextColor3 = Library.Theme.Text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = "  " .. tostring(item),
                            AutoButtonColor = false,
                            ZIndex = 52,
                            LayoutOrder = i,
                            Parent = listScroll,
                        })
                        corner(btn, 3)
                        connect(btn.MouseEnter, function()
                            btn.BackgroundColor3 = Library.Theme.ElementHover
                        end)
                        connect(btn.MouseLeave, function()
                            btn.BackgroundColor3 = (tostring(item) == tostring(current)) and Library.Theme.Element or Library.Theme.Background
                        end)
                        connect(btn.MouseButton1Click, function()
                            pick(item)
                        end)
                    end
                    local h = math.min(#items * 27 + 6, 160)
                    listScroll.CanvasSize = UDim2.new(0, 0, 0, #items * 27 + 4)
                    listFrame.Size = UDim2.new(1, -8, 0, h)
                end

                local function openList()
                    open = true
                    rebuildList()
                    listFrame.Visible = true
                    local h = math.min(#items * 27 + 6, 160)
                    f.Size = UDim2.new(1, 0, 0, 34 + h + 4)
                    arrow.Text = "▲"
                    task.defer(function()
                        local page = f.Parent
                        while page and not page:IsA("ScrollingFrame") do
                            page = page.Parent
                        end
                        if page and page:IsA("ScrollingFrame") then
                            local lay = page:FindFirstChildOfClass("UIListLayout")
                            if lay then
                                page.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 12)
                            end
                        end
                    end)
                end

                local hit = make("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32),
                    Text = "",
                    ZIndex = 5,
                    Parent = f,
                })
                connect(hit.MouseButton1Click, function()
                    if open then
                        closeList()
                    else
                        openList()
                    end
                end)

                return {
                    Set = function(_, v)
                        current = v
                        selectedLabel.Text = tostring(v)
                        if flag then Library.Flags[flag] = v end
                    end,
                    Get = function() return current end,
                    SetItems = function(_, newItems)
                        items = newItems or items
                    end,
                }
            end

            function Section:AddKeybind(cfg)
                cfg = type(cfg) == "table" and cfg or {}
                local title = cfg.Name or "Keybind"
                local flag = cfg.Flag or title
                local default = cfg.Default or cfg.Key or Enum.KeyCode.Unknown
                local callback = cfg.Callback
                local mode = cfg.Mode or "Toggle" -- Toggle / Hold

                local f = elementBase(32)
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.5, 0, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = title,
                    Parent = f,
                })
                local keyLbl = make("TextLabel", {
                    BackgroundColor3 = Library.Theme.SliderBg,
                    Size = UDim2.new(0, 90, 0, 22),
                    Position = UDim2.new(1, -100, 0.5, -11),
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    TextColor3 = Library.Theme.Accent,
                    Text = keyToString(default),
                    Parent = f,
                })
                corner(keyLbl, 4)

                local current = default
                local listening = false
                Library.Flags[flag] = current
                Library.Keybinds[flag] = {
                    Name = title,
                    Key = current,
                    Mode = mode,
                    Callback = callback,
                }

                local hit = make("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = "",
                    Parent = f,
                })
                connect(hit.MouseButton1Click, function()
                    listening = true
                    keyLbl.Text = "..."
                    keyLbl.TextColor3 = Library.Theme.TextDim
                end)

                connect(UserInputService.InputBegan, function(input, gpe)
                    if listening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            if input.KeyCode == Enum.KeyCode.Escape then
                                current = Enum.KeyCode.Unknown
                            else
                                current = input.KeyCode
                            end
                        elseif input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.MouseButton2
                            or input.UserInputType == Enum.UserInputType.MouseButton3 then
                            current = input.UserInputType
                        else
                            return
                        end
                        listening = false
                        keyLbl.Text = keyToString(current)
                        keyLbl.TextColor3 = Library.Theme.Accent
                        Library.Flags[flag] = current
                        if Library.Keybinds[flag] then
                            Library.Keybinds[flag].Key = current
                        end
                        if Library._refreshKeybindList then
                            Library._refreshKeybindList()
                        end
                        return
                    end
                    if gpe then return end
                    local kb = Library.Keybinds[flag]
                    if not kb or not kb.Key or kb.Key == Enum.KeyCode.Unknown then return end
                    local match = false
                    if typeof(kb.Key) == "EnumItem" then
                        if kb.Key.EnumType == Enum.KeyCode and input.KeyCode == kb.Key then match = true end
                        if kb.Key.EnumType == Enum.UserInputType and input.UserInputType == kb.Key then match = true end
                    end
                    if match and kb.Callback then
                        task.spawn(kb.Callback)
                    end
                end)

                return {
                    Set = function(_, k)
                        current = k
                        keyLbl.Text = keyToString(k)
                        Library.Flags[flag] = k
                        if Library.Keybinds[flag] then Library.Keybinds[flag].Key = k end
                    end,
                    Get = function() return current end,
                }
            end

            function Section:AddColorPicker(cfg)
                cfg = cfg or {}
                local title = cfg.Name or "Color"
                local flag = cfg.Flag
                local default = cfg.Default or Library.Theme.Accent
                if typeof(default) ~= "Color3" then
                    default = Color3.fromRGB(255, 255, 255)
                end
                local callback = cfg.Callback

                local f = elementBase(32)
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.55, 0, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Library.Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = title,
                    Parent = f,
                })

                local current = default
                if flag then Library.Flags[flag] = current end

                local swatch = make("Frame", {
                    BackgroundColor3 = current,
                    Size = UDim2.new(0, 28, 0, 22),
                    Position = UDim2.new(1, -100, 0.5, -11),
                    Parent = f,
                })
                corner(swatch, 4)
                stroke(swatch, Library.Theme.Border, 1)

                local hexLbl = make("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 58, 0, 22),
                    Position = UDim2.new(1, -68, 0.5, -11),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = Library.Theme.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Text = string.format("%02X%02X%02X", math.floor(current.R * 255 + 0.5), math.floor(current.G * 255 + 0.5), math.floor(current.B * 255 + 0.5)),
                    Parent = f,
                })

                local open = false
                local picker = make("Frame", {
                    BackgroundColor3 = Library.Theme.Section,
                    Size = UDim2.new(1, -8, 0, 0),
                    Position = UDim2.new(0, 4, 0, 34),
                    Visible = false,
                    ClipsDescendants = true,
                    ZIndex = 40,
                    Parent = f,
                })
                corner(picker, 4)
                stroke(picker, Library.Theme.Border, 1)

                local function setColor(c, fire)
                    current = c
                    swatch.BackgroundColor3 = c
                    hexLbl.Text = string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
                    if flag then Library.Flags[flag] = c end
                    if fire and callback then task.spawn(callback, c) end
                end

                local function makeChan(name, y)
                    make("TextLabel", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 18, 0, 18),
                        Position = UDim2.new(0, 8, 0, y),
                        Font = Enum.Font.GothamBold,
                        TextSize = 11,
                        TextColor3 = Library.Theme.Text,
                        Text = name,
                        ZIndex = 41,
                        Parent = picker,
                    })
                    local track = make("Frame", {
                        BackgroundColor3 = Library.Theme.SliderBg,
                        Size = UDim2.new(1, -50, 0, 8),
                        Position = UDim2.new(0, 28, 0, y + 5),
                        ZIndex = 41,
                        Parent = picker,
                    })
                    corner(track, 4)
                    local init = (name == "R" and current.R) or (name == "G" and current.G) or current.B
                    local fill = make("Frame", {
                        BackgroundColor3 = Library.Theme.Accent,
                        Size = UDim2.new(init, 0, 1, 0),
                        ZIndex = 42,
                        Parent = track,
                    })
                    corner(fill, 4)
                    local dragging = false
                    local function update(x)
                        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                        fill.Size = UDim2.new(rel, 0, 1, 0)
                        local r, g, b = current.R, current.G, current.B
                        if name == "R" then r = rel elseif name == "G" then g = rel else b = rel end
                        setColor(Color3.new(r, g, b), true)
                    end
                    connect(track.InputBegan, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = true
                            update(input.Position.X)
                        end
                    end)
                    connect(UserInputService.InputChanged, function(input)
                        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                            update(input.Position.X)
                        end
                    end)
                    connect(UserInputService.InputEnded, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                        end
                    end)
                    return fill
                end

                local fillR = makeChan("R", 8)
                local fillG = makeChan("G", 32)
                local fillB = makeChan("B", 56)

                local presets = {
                    Color3.fromRGB(255, 255, 255),
                    Color3.fromRGB(255, 50, 50),
                    Color3.fromRGB(0, 255, 120),
                    Color3.fromRGB(60, 140, 255),
                    Color3.fromRGB(180, 80, 255),
                    Color3.fromRGB(255, 150, 40),
                    Color3.fromRGB(0, 230, 230),
                    Color3.fromRGB(255, 230, 60),
                }
                for i, pc in ipairs(presets) do
                    local b = make("TextButton", {
                        BackgroundColor3 = pc,
                        Size = UDim2.new(0, 18, 0, 18),
                        Position = UDim2.new(0, 8 + (i - 1) * 22, 0, 82),
                        Text = "",
                        AutoButtonColor = false,
                        ZIndex = 41,
                        Parent = picker,
                    })
                    corner(b, 3)
                    connect(b.MouseButton1Click, function()
                        setColor(pc, true)
                        fillR.Size = UDim2.new(pc.R, 0, 1, 0)
                        fillG.Size = UDim2.new(pc.G, 0, 1, 0)
                        fillB.Size = UDim2.new(pc.B, 0, 1, 0)
                    end)
                end

                local function closePicker()
                    open = false
                    picker.Visible = false
                    picker.Size = UDim2.new(1, -8, 0, 0)
                    f.Size = UDim2.new(1, 0, 0, 32)
                end
                local function openPicker()
                    open = true
                    picker.Visible = true
                    picker.Size = UDim2.new(1, -8, 0, 110)
                    f.Size = UDim2.new(1, 0, 0, 146)
                    fillR.Size = UDim2.new(current.R, 0, 1, 0)
                    fillG.Size = UDim2.new(current.G, 0, 1, 0)
                    fillB.Size = UDim2.new(current.B, 0, 1, 0)
                end

                local hit = make("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32),
                    Text = "",
                    ZIndex = 5,
                    Parent = f,
                })
                connect(hit.MouseButton1Click, function()
                    if open then closePicker() else openPicker() end
                end)

                return {
                    Set = function(_, c)
                        if typeof(c) == "Color3" then
                            setColor(c, false)
                            fillR.Size = UDim2.new(c.R, 0, 1, 0)
                            fillG.Size = UDim2.new(c.G, 0, 1, 0)
                            fillB.Size = UDim2.new(c.B, 0, 1, 0)
                        end
                    end,
                    Get = function() return current end,
                }
            end

            Section.Toggle = Section.AddToggle
            Section.Slider = Section.AddSlider
            Section.Button = Section.AddButton
            Section.Dropdown = Section.AddDropdown
            Section.Label = Section.AddLabel
            Section.TextBox = Section.AddTextBox
            Section.AddTextbox = Section.AddTextBox
            Section.Keybind = Section.AddKeybind
            Section.AddKeybind = Section.AddKeybind
            Section.ColorPicker = Section.AddColorPicker
            Section.AddColorpicker = Section.AddColorPicker
            Section.AddColorPicker = Section.AddColorPicker
            return Section
        end

        return Tab
    end

    -- ===== PROFILE PANEL (Name, ID, Place ID, Playtime) =====
    local profilePanel = make("Frame", {
        BackgroundColor3 = Library.Theme.Background,
        Size = UDim2.new(1, -SIDEBAR_W, 1, -40),
        Position = UDim2.new(0, SIDEBAR_W, 0, 40),
        Visible = false,
        ZIndex = 30,
        Parent = main,
    })
    local profileScale = make("UIScale", { Scale = 1, Parent = profilePanel })
    padding(profilePanel, 16, 16, 16, 16)

    local profileTitle = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 0, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Library.Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "PROFILE",
        ZIndex = 31,
        Parent = profilePanel,
    })

    local profileClose = make("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 32, 0, 22),
        Position = UDim2.new(1, -32, 0, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Library.Theme.TextDim,
        Text = "×",
        ZIndex = 31,
        Parent = profilePanel,
    })

    local profileCard = make("Frame", {
        BackgroundColor3 = Library.Theme.Section,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 0, 0, 36),
        ZIndex = 31,
        Parent = profilePanel,
    })
    corner(profileCard, 8)
    stroke(profileCard, Library.Theme.Border, 1)
    padding(profileCard, 14, 14, 14, 14)
    make("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = profileCard,
    })

    local function profileRow(label, value)
        local row = make("Frame", {
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 40),
            ZIndex = 32,
            Parent = profileCard,
        })
        corner(row, 6)
        make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.4, -10, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Library.Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = label,
            ZIndex = 33,
            Parent = row,
        })
        local val = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.6, -12, 1, 0),
            Position = UDim2.new(0.4, 0, 0, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Library.Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = tostring(value),
            ZIndex = 33,
            Parent = row,
        })
        return val
    end

    local nameVal = profileRow("Nombre", LocalPlayer.DisplayName or LocalPlayer.Name)
    local idVal = profileRow("ID", tostring(LocalPlayer.UserId))
    local placeVal = profileRow("Place ID", tostring(game.PlaceId))
    local timeVal = profileRow("Tiempo jugado", "0s")

    -- ===== SKIN VIEWER 360 (panel OUTSIDE main menu, right side) =====
    local SKIN_W, SKIN_H = 200, 280
    local skinPanel = make("Frame", {
        Name = "SkinPanel",
        BackgroundColor3 = Library.Theme.Background,
        Size = UDim2.fromOffset(SKIN_W, SKIN_H),
        Position = UDim2.new(0, 0, 0, 0),
        Visible = false,
        ZIndex = 40,
        Parent = screen,
    })
    corner(skinPanel, 8)
    stroke(skinPanel, Library.Theme.Border, 1)
    local skinScale = make("UIScale", { Scale = 1, Parent = skinPanel })

    make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 20),
        Position = UDim2.new(0, 10, 0, 8),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Library.Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "SKIN",
        ZIndex = 41,
        Parent = skinPanel,
    })
    make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 14),
        Position = UDim2.new(0, 10, 0, 26),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = Library.Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Arrastra para rotar",
        ZIndex = 41,
        Parent = skinPanel,
    })

    local viewport = make("ViewportFrame", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        Size = UDim2.new(1, -20, 1, -52),
        Position = UDim2.new(0, 10, 0, 44),
        BorderSizePixel = 0,
        ZIndex = 41,
        Parent = skinPanel,
    })
    corner(viewport, 6)
    stroke(viewport, Library.Theme.Border, 1)

    local world = Instance.new("WorldModel")
    world.Parent = viewport

    local cam = Instance.new("Camera")
    cam.Parent = viewport
    viewport.CurrentCamera = cam

    local cloneChar = nil
    local yaw = 0
    local rotating = false
    local lastX = 0
    local autoSpin = true
    local camDistance = 4.2
    local camHeight = 1.2

    local function placeSkinBesideMenu()
        local mPos = main.AbsolutePosition
        local mSize = main.AbsoluteSize
        local gap = 10
        local x = mPos.X + mSize.X + gap
        local y = mPos.Y + (mSize.Y - SKIN_H) * 0.5
        -- keep on screen roughly
        if x + SKIN_W > workspace.CurrentCamera.ViewportSize.X - 8 then
            x = mPos.X - SKIN_W - gap
        end
        if y < 8 then y = 8 end
        skinPanel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
    end

    local function updateCamera()
        if not cloneChar then return end
        local hrp = cloneChar:FindFirstChild("HumanoidRootPart") or cloneChar:FindFirstChild("Torso") or cloneChar.PrimaryPart
        if not hrp then return end
        local pivot = hrp.Position + Vector3.new(0, camHeight * 0.15, 0)
        local offset = CFrame.Angles(0, yaw, 0) * Vector3.new(0, camHeight, camDistance)
        cam.CFrame = CFrame.new(pivot + offset, pivot)
    end

    local function loadSkin()
        if cloneChar then
            cloneChar:Destroy()
            cloneChar = nil
        end
        local char = LocalPlayer.Character
        if not char then return end
        local ok, clone = pcall(function()
            char.Archivable = true
            local c = char:Clone()
            char.Archivable = false
            return c
        end)
        if not ok or not clone then return end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
                d:Destroy()
            end
        end
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            end)
        end
        clone.Parent = world
        cloneChar = clone
        if clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChild("Torso") then
            clone:PivotTo(CFrame.new(0, 0, 0))
        end
        yaw = 0.6
        updateCamera()
    end

    connect(viewport.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            rotating = true
            autoSpin = false
            lastX = input.Position.X
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if rotating then
                rotating = false
                task.delay(1.2, function()
                    if not rotating then autoSpin = true end
                end)
            end
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if rotating and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local dx = input.Position.X - lastX
            lastX = input.Position.X
            yaw = yaw - dx * 0.012
            updateCamera()
        end
    end)

    -- follow menu position while open + auto spin
    connect(RunService.RenderStepped, function(dt)
        if skinPanel.Visible then
            placeSkinBesideMenu()
            if cloneChar and autoSpin and not rotating then
                yaw = yaw + dt * 0.55
                updateCamera()
            end
        end
    end)

    local sessionStart = os.clock()
    local function formatTime(sec)
        sec = math.floor(sec)
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        local s = sec % 60
        if h > 0 then
            return string.format("%dh %dm %ds", h, m, s)
        elseif m > 0 then
            return string.format("%dm %ds", m, s)
        end
        return string.format("%ds", s)
    end

    task.spawn(function()
        while profilePanel and profilePanel.Parent do
            if profilePanel.Visible then
                timeVal.Text = formatTime(os.clock() - sessionStart)
                nameVal.Text = LocalPlayer.DisplayName or LocalPlayer.Name
                idVal.Text = tostring(LocalPlayer.UserId)
                placeVal.Text = tostring(game.PlaceId)
            end
            task.wait(1)
        end
    end)

    Window._profilePanel = profilePanel
    Window._skinPanel = skinPanel

    function Window:_showProfile()
        -- deselect tabs visually
        for _, t in pairs(Window._tabs) do
            t._page.Visible = false
            tween(t._btn, TWEEN_TAB, { BackgroundColor3 = Library.Theme.Element })
            t._label.TextColor3 = Library.Theme.TextDim
            if t._icon then t._icon.ImageColor3 = Library.Theme.TextDim end
        end
        Window._current = nil

        profilePanel.Visible = true
        profileScale.Scale = 0.96
        profilePanel.BackgroundTransparency = 0.2
        tween(profileScale, TWEEN_TAB, { Scale = 1 })
        tween(profilePanel, TWEEN_TAB, { BackgroundTransparency = 0 })
        tween(playerSlot, TWEEN_FAST, { BackgroundColor3 = Library.Theme.Section })

        timeVal.Text = formatTime(os.clock() - sessionStart)
        nameVal.Text = LocalPlayer.DisplayName or LocalPlayer.Name
        idVal.Text = tostring(LocalPlayer.UserId)
        placeVal.Text = tostring(game.PlaceId)
        autoSpin = true

        -- external skin panel beside menu
        placeSkinBesideMenu()
        skinPanel.Visible = true
        skinScale.Scale = 0.9
        skinPanel.BackgroundTransparency = 0.25
        tween(skinScale, TWEEN_TAB, { Scale = 1 })
        tween(skinPanel, TWEEN_TAB, { BackgroundTransparency = 0 })
        task.spawn(loadSkin)
    end

    function Window:_hideProfile()
        tween(profileScale, TWEEN_TAB, { Scale = 0.96 })
        tween(profilePanel, TWEEN_TAB, { BackgroundTransparency = 0.2 })
        tween(skinScale, TWEEN_TAB, { Scale = 0.9 })
        tween(skinPanel, TWEEN_TAB, { BackgroundTransparency = 0.3 })
        task.delay(0.25, function()
            profilePanel.Visible = false
            profileScale.Scale = 1
            profilePanel.BackgroundTransparency = 0
            skinPanel.Visible = false
            skinScale.Scale = 1
            skinPanel.BackgroundTransparency = 0
            if cloneChar then
                cloneChar:Destroy()
                cloneChar = nil
            end
        end)
        tween(playerSlot, TWEEN_FAST, { BackgroundColor3 = Library.Theme.Element })
    end

    local playerHit = make("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        Parent = playerSlot,
    })
    connect(playerHit.MouseButton1Click, function()
        if profilePanel.Visible then
            Window:_hideProfile()
            -- re-select first tab if any
            if Window._tabs[1] then
                local t = Window._tabs[1]
                t._page.Visible = true
                local sc = t._page:FindFirstChildOfClass("UIScale")
                if sc then
                    sc.Scale = 0.96
                    tween(sc, TWEEN_TAB, { Scale = 1 })
                end
                tween(t._btn, TWEEN_TAB, { BackgroundColor3 = Library.Theme.Section })
                t._label.TextColor3 = Library.Theme.Accent
                if t._icon then t._icon.ImageColor3 = Library.Theme.Accent end
                Window._current = t
            end
        else
            Window:_showProfile()
        end
    end)
    connect(profileClose.MouseButton1Click, function()
        Window:_hideProfile()
        if Window._tabs[1] then
            local t = Window._tabs[1]
            t._page.Visible = true
            tween(t._btn, TWEEN_TAB, { BackgroundColor3 = Library.Theme.Section })
            t._label.TextColor3 = Library.Theme.Accent
            if t._icon then t._icon.ImageColor3 = Library.Theme.Accent end
            Window._current = t
        end
    end)

    -- ===== FLOATING ICON BUTTON (only icon, draggable, smooth) =====
    local FLOAT_SIZE = 28 -- same size as title icon feel
    local floatBtn = make("Frame", {
        Name = "R1K0V_Float",
        BackgroundColor3 = Library.Theme.Sidebar,
        Size = UDim2.fromOffset(FLOAT_SIZE + 10, FLOAT_SIZE + 10),
        Position = UDim2.new(0, 16, 0.5, -(FLOAT_SIZE + 10) / 2),
        ZIndex = 100,
        Parent = screen,
    })
    corner(floatBtn, 8)
    stroke(floatBtn, Library.Theme.Border, 1)

    local floatIcon = make("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(FLOAT_SIZE, FLOAT_SIZE),
        Position = UDim2.new(0.5, -FLOAT_SIZE / 2, 0.5, -FLOAT_SIZE / 2),
        Image = "rbxassetid://90477855353953",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 101,
        Parent = floatBtn,
    })

    local floatHit = make("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 102,
        Parent = floatBtn,
    })

    local floatDragging = false
    local floatDragStart, floatStartPos
    local floatTargetX, floatTargetY
    local floatMoved = false
    local CLICK_THRESH = 6

    connect(floatHit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            floatDragging = true
            floatMoved = false
            floatDragStart = input.Position
            floatStartPos = floatBtn.Position
            floatTargetX = floatStartPos.X.Offset
            floatTargetY = floatStartPos.Y.Offset
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if floatDragging then
                floatDragging = false
                if floatTargetX and floatTargetY then
                    tween(floatBtn, TWEEN_MOVE, {
                        Position = UDim2.fromOffset(floatTargetX, floatTargetY),
                    })
                end
                -- click without much move = toggle menu
                if not floatMoved then
                    Window:ToggleInterface()
                end
            end
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if not floatDragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - floatDragStart
        if math.abs(delta.X) > CLICK_THRESH or math.abs(delta.Y) > CLICK_THRESH then
            floatMoved = true
        end
        floatTargetX = floatStartPos.X.Offset + delta.X
        floatTargetY = floatStartPos.Y.Offset + delta.Y
        -- clamp roughly on screen
        local vs = workspace.CurrentCamera.ViewportSize
        floatTargetX = math.clamp(floatTargetX, 4, vs.X - FLOAT_SIZE - 14)
        floatTargetY = math.clamp(floatTargetY, 4, vs.Y - FLOAT_SIZE - 14)
        local curX = floatBtn.Position.X.Offset
        local curY = floatBtn.Position.Y.Offset
        local nx = curX + (floatTargetX - curX) * 0.28
        local ny = curY + (floatTargetY - curY) * 0.28
        floatBtn.Position = UDim2.fromOffset(nx, ny)
    end)

    Window._floatBtn = floatBtn

    -- keybind list lives INSIDE the menu (Misc tab), not on screen
    local function refreshKeybindList()
        if Library._kbListSection and Library._kbListSection._refresh then
            Library._kbListSection._refresh()
        end
    end
    Library._refreshKeybindList = refreshKeybindList
    Window._kbList = nil

    -- minimize: hide main, keep float
    function Window:Minimize()
        Library.Minimized = true
        Library.Open = false
        main.Visible = false
        if Window._skinPanel then Window._skinPanel.Visible = false end
        if Window._profilePanel then Window._profilePanel.Visible = false end
    end

    local keyEnum = Enum.KeyCode.RightShift
    if type(keybind) == "string" then
        pcall(function() keyEnum = Enum.KeyCode[keybind] end)
    elseif typeof(keybind) == "EnumItem" then
        keyEnum = keybind
    end
    connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == keyEnum then
            Window:ToggleInterface()
        end
        if input.KeyCode == Enum.KeyCode.End then
            main.Visible = false
            Library.Open = false
            if Window._skinPanel then Window._skinPanel.Visible = false end
            if floatBtn then floatBtn.Visible = false end
            if Library._overlayGui then Library._overlayGui.Enabled = false end
            if Library.Notify then
                Library:Notify("Panic", "UI hidden", 2)
            end
        end
    end)
    connect(closeBtn.MouseButton1Click, function()
        Window:ToggleInterface()
    end)

    local oldToggle = Window.ToggleInterface
    function Window:ToggleInterface()
        if Library.Minimized then
            Library.Minimized = false
        end
        if floatBtn then floatBtn.Visible = true end
        oldToggle(Window)
    end

    function Window:Unload()
        for _, c in ipairs(Library.Connections) do
            pcall(function() c:Disconnect() end)
        end
        Library.Connections = {}
        if screen then screen:Destroy() end
    end

    Library.Window = Window
    return Window
end

Library.GlobalLogo = ""
Library.Scales = { Default = UDim2.fromOffset(620, 420) }

function Library:Unload()
    if Library.Window and Library.Window.Unload then
        Library.Window:Unload()
    end
    Library.Window = nil
    if Library._OverlayAPI and Library._OverlayAPI.Destroy then
        pcall(function() Library._OverlayAPI:Destroy() end)
    end
    if Library._NotifGui then
        pcall(function() Library._NotifGui:Destroy() end)
        Library._NotifGui = nil
        Library._NotifAPI = nil
    end
    for _, c in ipairs(Library.Connections) do
        pcall(function() c:Disconnect() end)
    end
    Library.Connections = {}
end

--[[
    R1K0V-HUB UI — Full library only (no demo, no game tabs)

    local Library = loadstring(game:HttpGet("URL"))()
    local Window = Library:CreateWindow({ Name = "R1K0V-HUB", Keybind = "RightShift" })
    Window:AddTabLabel("MAIN")
    local Tab = Window:AddTab({ Name = "Misc", Icon = 6031280882 })
    local L = Tab:AddSection({ Name = "OPTIONS", Position = "left" })
    L:AddToggle({ Name = "Example", Flag = "Ex", Default = false, Callback = function(v) end })
    L:AddDropdown({ Name = "Mode", Flag = "Mode", Items = {"A","B"}, Default = "A", Callback = function(v) end })
    L:AddColorPicker({ Name = "ESP Color", Flag = "ESPColor", Default = Color3.fromRGB(0,255,120), Callback = function(c) end })
    L:AddTextBox({ Name = "Custom", Flag = "Custom", Default = "", Callback = function(v) end })
    L:AddKeybind({ Name = "Key", Flag = "Key", Default = Enum.KeyCode.RightShift, Callback = function() end })
    local Notif = Library:CreateNotification()
    Notif:Notify("R1K0V", "Ready", 2, "rbxassetid://90477855353953")

    local Overlay = Library:CreateOverlay()
    Overlay:Show()   -- FPS + MS, drag to move
    -- Overlay:Hide() / Overlay:Toggle(true)
]]

return Library
