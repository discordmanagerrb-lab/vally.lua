-- Valley Prison Roleplay - Wide but Short UI + Dropped Tools ESP/TP + Fast Spam Click

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Teams = game:GetService("Teams")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local MAX_DISTANCE = 3000
local SMOOTHNESS = 50
local FOV_RADIUS = 1000
local PREDICTION_FACTOR = 0.135

local aimlockEnabled = true
local espEnabled = false
local espTools = false
local espDroppedTools = false
local requireToolToLock = false
local spamClickMode = false
local teleportStuds = 30
local espRefreshInterval = 5

local locking = false
local lockedTarget = nil
local targetTeamName = "Guards"
local targetPart = "Head"
local parts = {"Head", "HumanoidRootPart", "UpperTorso", "Random"}
local currentPartIndex = 1

local highlights = {}
local billboards = {}
local droppedHighlights = {}

local sg

local function shortenToolName(name)
    name = name or ""
    local first = name:sub(1,1):upper()
    local num = name:match("%d+$")
    return num and (first .. num) or first
end

local function updateESP(player)
    if player == lp or not player.Character then return end
    local char = player.Character
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not head or not hum then return end

    local teamColor = player.Team and player.Team.TeamColor.Color or Color3.fromRGB(180,180,180)

    local hl = highlights[player]
    if not hl then
        hl = Instance.new("Highlight")
        hl.FillTransparency = 0.68
        hl.OutlineTransparency = 0.12
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        highlights[player] = hl
    end
    hl.FillColor = teamColor
    hl.OutlineColor = teamColor

    local billData = billboards[player]
    if not billData then
        local bill = Instance.new("BillboardGui")
        bill.Adornee = head
        bill.Size = UDim2.new(0, 200, 0, 26)
        bill.StudsOffset = Vector3.new(0, 3.0, 0)
        bill.AlwaysOnTop = true
        bill.Parent = char

        local txt = Instance.new("TextLabel", bill)
        txt.Size = UDim2.new(1,0,1,0)
        txt.BackgroundTransparency = 1
        txt.TextColor3 = teamColor
        txt.Font = Enum.Font.GothamSemibold
        txt.TextSize = 13
        txt.TextStrokeTransparency = 0.5
        txt.TextStrokeColor3 = Color3.new(0,0,0)
        txt.TextXAlignment = Enum.TextXAlignment.Center

        billboards[player] = {billboard = bill, label = txt}
        billData = billboards[player]
    end

    local text = player.Name .. " | " .. (player.Team and player.Team.Name or "No Team")
    if espTools then
        local tools = {}
        local equipped = char:FindFirstChildWhichIsA("Tool")
        if equipped then table.insert(tools, equipped.Name) end
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then table.insert(tools, item.Name) end
            end
        end
        if #tools > 0 then
            local display
            if #tools >= 4 then
                local short = {}
                for _, n in ipairs(tools) do table.insert(short, shortenToolName(n)) end
                display = table.concat(short, ", ")
            else
                display = table.concat(tools, ", ")
            end
            text = text .. " | " .. display
        end
    end
    billData.label.Text = text
end

local function removeESP(player)
    if highlights[player] then highlights[player]:Destroy() highlights[player] = nil end
    if billboards[player] then billboards[player].billboard:Destroy() billboards[player] = nil end
end

local function refreshESP()
    for p in pairs(highlights) do removeESP(p) end
    highlights = {}
    billboards = {}
    if not espEnabled then return end
    for _, p in Players:GetPlayers() do
        if p ~= lp and p.Character then updateESP(p) end
    end
end

-- Dropped Tools ESP
local function updateDroppedToolsESP()
    for _, hl in pairs(droppedHighlights) do hl:Destroy() end
    droppedHighlights = {}

    if not espDroppedTools then return end

    local droppedFolder = workspace:FindFirstChild("DroppedTools")
    if not droppedFolder then return end

    for _, item in ipairs(droppedFolder:GetChildren()) do
        if item:IsA("Model") or item:IsA("Tool") then
            local primary = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if primary then
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(255, 215, 0) -- gold color for dropped items
                hl.OutlineColor = Color3.fromRGB(255, 255, 100)
                hl.FillTransparency = 0.6
                hl.OutlineTransparency = 0.2
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = item
                hl.Parent = item
                droppedHighlights[item] = hl
            end
        end
    end
end

local function destroyDroppedESP()
    for _, hl in pairs(droppedHighlights) do hl:Destroy() end
    droppedHighlights = {}
end

local function refreshDroppedTools()
    destroyDroppedESP()
    if espDroppedTools then updateDroppedToolsESP() end
end

local function destroyScript()
    aimlockEnabled = false
    espEnabled = false
    espDroppedTools = false
    locking = false
    lockedTarget = nil
    refreshESP()
    destroyDroppedESP()
    if sg then sg:Destroy() sg = nil end
end

-- UI
sg = Instance.new("ScreenGui")
sg.Name = "ValleyPrisonUI"
sg.ResetOnSpawn = false
sg.Parent = lp:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 620, 0, 320)
main.Position = UDim2.new(0.5, -310, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
main.BackgroundTransparency = 0.05
main.BorderSizePixel = 0
main.Parent = sg

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(40, 40, 55)
stroke.Thickness = 1.2
stroke.Transparency = 0.55
stroke.Parent = main

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleBar.BackgroundTransparency = 0.1
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Valley Prison"
title.TextColor3 = Color3.fromRGB(210, 210, 225)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 26, 0, 26)
close.Position = UDim2.new(1, -32, 0.5, -13)
close.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
close.BackgroundTransparency = 0.1
close.Text = "X"
close.TextColor3 = Color3.new(1,1,1)
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.Parent = titleBar
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)

close.Activated:Connect(function()
    sg.Enabled = false
end)

-- Player info
local playerInfo = Instance.new("Frame")
playerInfo.Size = UDim2.new(0, 74, 0, 90)
playerInfo.Position = UDim2.new(0, 0, 0, 34)
playerInfo.BackgroundTransparency = 1
playerInfo.Parent = main

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.new(0, 54, 0, 54)
avatar.Position = UDim2.new(0.5, -27, 0, 8)
avatar.BackgroundTransparency = 1
avatar.Image = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
avatar.Parent = playerInfo

local username = Instance.new("TextLabel")
username.Size = UDim2.new(1, 0, 0, 20)
username.Position = UDim2.new(0, 0, 1, -26)
username.BackgroundTransparency = 1
username.Text = lp.Name
username.TextColor3 = Color3.fromRGB(220, 220, 235)
username.Font = Enum.Font.GothamSemibold
username.TextSize = 13
username.TextXAlignment = Enum.TextXAlignment.Center
username.TextWrapped = true
username.Parent = playerInfo

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 74, 1, -124)
sidebar.Position = UDim2.new(0, 0, 0, 124)
sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
sidebar.BackgroundTransparency = 0.12
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sideStroke = Instance.new("UIStroke")
sideStroke.Color = Color3.fromRGB(35, 35, 50)
sideStroke.Thickness = 1
sideStroke.Transparency = 0.6
sideStroke.Parent = sidebar

local sideList = Instance.new("UIListLayout")
sideList.Padding = UDim.new(0, 6)
sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideList.SortOrder = Enum.SortOrder.LayoutOrder
sideList.Parent = sidebar

-- Content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -82, 1, -40)
content.Position = UDim2.new(0, 74, 0, 40)
content.BackgroundTransparency = 1
content.Parent = main

local contPad = Instance.new("UIPadding", content)
contPad.PaddingTop = UDim.new(0, 8)
contPad.PaddingLeft = UDim.new(0, 12)
contPad.PaddingRight = UDim.new(0, 12)

-- Tabs & Pages
local tabs = {"Aimlock", "ESP", "Teleport", "Tools"}
local pages = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 64, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    btn.BackgroundTransparency = 0.25
    btn.BorderSizePixel = 0
    btn.Text = tabName
    btn.TextColor3 = Color3.fromRGB(170, 170, 185)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.Parent = sidebar

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Name = tabName .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 80)
    page.CanvasSize = UDim2.new(0, 0, 0, 600)
    page.Visible = (i == 1)
    page.Parent = content

    local pageList = Instance.new("UIListLayout", page)
    pageList.Padding = UDim.new(0, 12)
    pageList.SortOrder = Enum.SortOrder.LayoutOrder

    pageList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, pageList.AbsoluteContentSize.Y + 30)
    end)

    pages[tabName] = page

    btn.Activated:Connect(function()
        for _, p in pairs(pages) do p.Visible = false end
        page.Visible = true
        for _, b in ipairs(sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
                b.BackgroundTransparency = 0.25
                b.TextColor3 = Color3.fromRGB(170, 170, 185)
            end
        end
        btn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
        btn.BackgroundTransparency = 0.1
        btn.TextColor3 = Color3.fromRGB(235, 235, 245)
    end)

    if i == 1 then
        btn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
        btn.BackgroundTransparency = 0.1
        btn.TextColor3 = Color3.fromRGB(235, 235, 245)
    end
end

-- AIMLOCK PAGE
local aimPage = pages["Aimlock"]

local teamTitle = Instance.new("TextLabel", aimPage)
teamTitle.Size = UDim2.new(1,0,0,22)
teamTitle.BackgroundTransparency = 1
teamTitle.Text = "Target Team(s)"
teamTitle.TextColor3 = Color3.fromRGB(190,190,210)
teamTitle.Font = Enum.Font.GothamSemibold
teamTitle.TextSize = 14
teamTitle.TextXAlignment = Enum.TextXAlignment.Left

local teamBox = Instance.new("TextBox", aimPage)
teamBox.Size = UDim2.new(1,0,0,36)
teamBox.Position = UDim2.new(0,0,0,24)
teamBox.BackgroundColor3 = Color3.fromRGB(28,28,36)
teamBox.TextColor3 = Color3.new(1,1,1)
teamBox.PlaceholderText = "Guards, Prisoners..."
teamBox.Text = targetTeamName
teamBox.Font = Enum.Font.Gotham
teamBox.TextSize = 14
teamBox.ClearTextOnFocus = false
Instance.new("UICorner", teamBox).CornerRadius = UDim.new(0,6)
teamBox.FocusLost:Connect(function()
    targetTeamName = teamBox.Text
end)

local selectTeamsBtn = Instance.new("TextButton", aimPage)
selectTeamsBtn.Size = UDim2.new(1,0,0,36)
selectTeamsBtn.Position = UDim2.new(0,0,0,66)
selectTeamsBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
selectTeamsBtn.Text = "Select Teams"
selectTeamsBtn.TextColor3 = Color3.new(1,1,1)
selectTeamsBtn.Font = Enum.Font.GothamSemibold
selectTeamsBtn.TextSize = 14
Instance.new("UICorner", selectTeamsBtn).CornerRadius = UDim.new(0,6)

local partDropdown = Instance.new("TextButton", aimPage)
partDropdown.Size = UDim2.new(1,0,0,36)
partDropdown.Position = UDim2.new(0,0,0,108)
partDropdown.BackgroundColor3 = Color3.fromRGB(28,28,36)
partDropdown.Text = "Target Part: " .. targetPart
partDropdown.TextColor3 = Color3.new(1,1,1)
partDropdown.Font = Enum.Font.GothamSemibold
partDropdown.TextSize = 14
Instance.new("UICorner", partDropdown).CornerRadius = UDim.new(0,6)
partDropdown.Activated:Connect(function()
    currentPartIndex = (currentPartIndex % #parts) + 1
    targetPart = parts[currentPartIndex]
    partDropdown.Text = "Target Part: " .. targetPart
end)

local reqToolBtn = Instance.new("TextButton", aimPage)
reqToolBtn.Size = UDim2.new(1,0,0,36)
reqToolBtn.Position = UDim2.new(0,0,0,150)
reqToolBtn.BackgroundColor3 = requireToolToLock and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
reqToolBtn.Text = requireToolToLock and "Require Tool: ON" or "Require Tool: OFF"
reqToolBtn.TextColor3 = Color3.new(1,1,1)
reqToolBtn.Font = Enum.Font.GothamSemibold
reqToolBtn.TextSize = 14
Instance.new("UICorner", reqToolBtn).CornerRadius = UDim.new(0,6)
reqToolBtn.Activated:Connect(function()
    requireToolToLock = not requireToolToLock
    reqToolBtn.Text = requireToolToLock and "Require Tool: ON" or "Require Tool: OFF"
    reqToolBtn.BackgroundColor3 = requireToolToLock and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
end)

local spamBtn = Instance.new("TextButton", aimPage)
spamBtn.Size = UDim2.new(1,0,0,36)
spamBtn.Position = UDim2.new(0,0,0,192)
spamBtn.BackgroundColor3 = spamClickMode and Color3.fromRGB(180,60,60) or Color3.fromRGB(50,50,60)
spamBtn.Text = spamClickMode and "Spam Click: ON" or "Spam Click: OFF"
spamBtn.TextColor3 = Color3.new(1,1,1)
spamBtn.Font = Enum.Font.GothamSemibold
spamBtn.TextSize = 14
Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0,6)
spamBtn.Activated:Connect(function()
    spamClickMode = not spamClickMode
    spamBtn.Text = spamClickMode and "Spam Click: ON" or "Spam Click: OFF"
    spamBtn.BackgroundColor3 = spamClickMode and Color3.fromRGB(180,60,60) or Color3.fromRGB(50,50,60)
end)

-- Sliders
local function addSlider(parent, title, min, max, def, cb)
    local cont = Instance.new("Frame", parent)
    cont.Size = UDim2.new(1,0,0,54)
    cont.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", cont)
    lbl.Size = UDim2.new(1,0,0,18)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(190,190,210)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextBox", cont)
    val.Size = UDim2.new(0,70,0,18)
    val.Position = UDim2.new(1,-78,0,0)
    val.BackgroundTransparency = 1
    val.Text = tostring(def)
    val.TextColor3 = Color3.fromRGB(0,220,170)
    val.Font = Enum.Font.Gotham
    val.TextSize = 13
    val.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", cont)
    track.Size = UDim2.new(1,0,0,6)
    track.Position = UDim2.new(0,0,0,28)
    track.BackgroundColor3 = Color3.fromRGB(40,40,50)
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(0.5,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,160,120)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,18,0,18)
    knob.Position = UDim2.new(0.5,-9,0.5,-9)
    knob.BackgroundColor3 = Color3.fromRGB(220,220,240)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local dragging = false
    local function update(pct)
        pct = math.clamp(pct,0,1)
        fill.Size = UDim2.new(pct,0,1,0)
        knob.Position = UDim2.new(pct,-9,0.5,-9)
        local v = math.floor(min + (max-min)*pct)
        val.Text = tostring(v)
        cb(v)
    end

    knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    knob.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = (i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
            update(rel)
        end
    end)

    val.FocusLost:Connect(function()
        local n = tonumber(val.Text)
        if n then update(math.clamp(n,min,max)/(max-min)) end
    end)

    update((def-min)/(max-min))
end

addSlider(aimPage, "Max Distance", 500, 10000, MAX_DISTANCE, function(v) MAX_DISTANCE = v end)
addSlider(aimPage, "Smoothness", 10, 120, SMOOTHNESS, function(v) SMOOTHNESS = v end)
addSlider(aimPage, "FOV Radius", 200, 2000, FOV_RADIUS, function(v) FOV_RADIUS = v end)
addSlider(aimPage, "Prediction", 0.05, 0.3, PREDICTION_FACTOR, function(v) PREDICTION_FACTOR = v end)

-- ESP PAGE
local espPage = pages["ESP"]

local espToggle = Instance.new("TextButton", espPage)
espToggle.Size = UDim2.new(1,0,0,36)
espToggle.BackgroundColor3 = espEnabled and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
espToggle.Text = espEnabled and "ESP: ON" or "ESP: OFF"
espToggle.TextColor3 = Color3.new(1,1,1)
espToggle.Font = Enum.Font.GothamSemibold
espToggle.TextSize = 14
Instance.new("UICorner", espToggle).CornerRadius = UDim.new(0,6)
espToggle.Activated:Connect(function()
    espEnabled = not espEnabled
    espToggle.Text = espEnabled and "ESP: ON" or "ESP: OFF"
    espToggle.BackgroundColor3 = espEnabled and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
    refreshESP()
end)

local toolsToggle = Instance.new("TextButton", espPage)
toolsToggle.Size = UDim2.new(1,0,0,36)
toolsToggle.Position = UDim2.new(0,0,0,46)
toolsToggle.BackgroundColor3 = espTools and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
toolsToggle.Text = espTools and "Show Tools: ON" or "Show Tools: OFF"
toolsToggle.TextColor3 = Color3.new(1,1,1)
toolsToggle.Font = Enum.Font.GothamSemibold
toolsToggle.TextSize = 14
Instance.new("UICorner", toolsToggle).CornerRadius = UDim.new(0,6)
toolsToggle.Activated:Connect(function()
    espTools = not espTools
    toolsToggle.Text = espTools and "Show Tools: ON" or "Show Tools: OFF"
    toolsToggle.BackgroundColor3 = espTools and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
    if espEnabled then refreshESP() end
end)

local droppedToolsToggle = Instance.new("TextButton", espPage)
droppedToolsToggle.Size = UDim2.new(1,0,0,36)
droppedToolsToggle.Position = UDim2.new(0,0,0,92)
droppedToolsToggle.BackgroundColor3 = espDroppedTools and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
droppedToolsToggle.Text = espDroppedTools and "Dropped Tools: ON" or "Dropped Tools: OFF"
droppedToolsToggle.TextColor3 = Color3.new(1,1,1)
droppedToolsToggle.Font = Enum.Font.GothamSemibold
droppedToolsToggle.TextSize = 14
Instance.new("UICorner", droppedToolsToggle).CornerRadius = UDim.new(0,6)
droppedToolsToggle.Activated:Connect(function()
    espDroppedTools = not espDroppedTools
    droppedToolsToggle.Text = espDroppedTools and "Dropped Tools: ON" or "Dropped Tools: OFF"
    droppedToolsToggle.BackgroundColor3 = espDroppedTools and Color3.fromRGB(0,160,120) or Color3.fromRGB(50,50,60)
    refreshDroppedTools()
end)

-- TELEPORT PAGE
local tpPage = pages["Teleport"]

local tpTitle = Instance.new("TextLabel", tpPage)
tpTitle.Size = UDim2.new(1,0,0,22)
tpTitle.BackgroundTransparency = 1
tpTitle.Text = "Teleport Forward (studs)"
tpTitle.TextColor3 = Color3.fromRGB(190,190,210)
tpTitle.Font = Enum.Font.GothamSemibold
tpTitle.TextSize = 14
tpTitle.TextXAlignment = Enum.TextXAlignment.Left

local tpBox = Instance.new("TextBox", tpPage)
tpBox.Size = UDim2.new(0.58,0,0,36)
tpBox.Position = UDim2.new(0,0,0,26)
tpBox.BackgroundColor3 = Color3.fromRGB(28,28,36)
tpBox.TextColor3 = Color3.new(1,1,1)
tpBox.Text = tostring(teleportStuds)
tpBox.Font = Enum.Font.Gotham
tpBox.TextSize = 14
tpBox.ClearTextOnFocus = false
Instance.new("UICorner", tpBox).CornerRadius = UDim.new(0,6)
tpBox.FocusLost:Connect(function()
    local num = tonumber(tpBox.Text)
    teleportStuds = num and math.max(5, math.abs(num)) or 30
    tpBox.Text = tostring(teleportStuds)
end)

local tpBtn = Instance.new("TextButton", tpPage)
tpBtn.Size = UDim2.new(0.4, -8, 0,36)
tpBtn.Position = UDim2.new(0.6, 0, 0,26)
tpBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
tpBtn.Text = "Teleport Forward"
tpBtn.TextColor3 = Color3.new(1,1,1)
tpBtn.Font = Enum.Font.GothamSemibold
tpBtn.TextSize = 14
Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0,6)
tpBtn.Activated:Connect(function()
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        local dir = hrp.CFrame.LookVector
        hrp.CFrame = hrp.CFrame + dir * teleportStuds
    end
end)

-- Teleport to Dropped Item
local tpDroppedTitle = Instance.new("TextLabel", tpPage)
tpDroppedTitle.Size = UDim2.new(1,0,0,22)
tpDroppedTitle.Position = UDim2.new(0,0,0,80)
tpDroppedTitle.BackgroundTransparency = 1
tpDroppedTitle.Text = "Teleport to Dropped Item"
tpDroppedTitle.TextColor3 = Color3.fromRGB(190,190,210)
tpDroppedTitle.Font = Enum.Font.GothamSemibold
tpDroppedTitle.TextSize = 14
tpDroppedTitle.TextXAlignment = Enum.TextXAlignment.Left

local droppedDropdown = Instance.new("TextButton", tpPage)
droppedDropdown.Size = UDim2.new(1,0,0,36)
droppedDropdown.Position = UDim2.new(0,0,0,104)
droppedDropdown.BackgroundColor3 = Color3.fromRGB(28,28,36)
droppedDropdown.Text = "Select Item..."
droppedDropdown.TextColor3 = Color3.new(1,1,1)
droppedDropdown.Font = Enum.Font.GothamSemibold
droppedDropdown.TextSize = 14
Instance.new("UICorner", droppedDropdown).CornerRadius = UDim.new(0,6)

local selectedItem = nil

local function refreshDroppedList()
    droppedDropdown.Text = "Select Item..."
    selectedItem = nil
end

local tpToDroppedBtn = Instance.new("TextButton", tpPage)
tpToDroppedBtn.Size = UDim2.new(1,0,0,36)
tpToDroppedBtn.Position = UDim2.new(0,0,0,146)
tpToDroppedBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
tpToDroppedBtn.Text = "Teleport to Selected"
tpToDroppedBtn.TextColor3 = Color3.new(1,1,1)
tpToDroppedBtn.Font = Enum.Font.GothamSemibold
tpToDroppedBtn.TextSize = 14
Instance.new("UICorner", tpToDroppedBtn).CornerRadius = UDim.new(0,6)
tpToDroppedBtn.Activated:Connect(function()
    if selectedItem and selectedItem.Parent and selectedItem:IsDescendantOf(workspace) then
        local primary = selectedItem.PrimaryPart or selectedItem:FindFirstChildWhichIsA("BasePart")
        if primary and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            lp.Character.HumanoidRootPart.CFrame = primary.CFrame + Vector3.new(0, 3, 0)
        end
    end
end)

local droppedPopup = Instance.new("Frame")
droppedPopup.Size = UDim2.new(0, 300, 0, 380)
droppedPopup.Position = UDim2.new(0.5, -150, 0.5, -190)
droppedPopup.BackgroundColor3 = Color3.fromRGB(18,18,23)
droppedPopup.Visible = false
droppedPopup.Parent = sg
Instance.new("UICorner", droppedPopup).CornerRadius = UDim.new(0,8)

local dpTitleBar = Instance.new("Frame", droppedPopup)
dpTitleBar.Size = UDim2.new(1,0,0,36)
dpTitleBar.BackgroundColor3 = Color3.fromRGB(22,22,28)
dpTitleBar.BorderSizePixel = 0

local dpTitle = Instance.new("TextLabel", dpTitleBar)
dpTitle.Size = UDim2.new(1,-50,1,0)
dpTitle.Position = UDim2.new(0,14,0,0)
dpTitle.BackgroundTransparency = 1
dpTitle.Text = "Select Dropped Item"
dpTitle.TextColor3 = Color3.fromRGB(210,210,220)
dpTitle.Font = Enum.Font.GothamSemibold
dpTitle.TextSize = 15

local dpClose = Instance.new("TextButton", dpTitleBar)
dpClose.Size = UDim2.new(0,30,0,30)
dpClose.Position = UDim2.new(1,-36,0.5,-15)
dpClose.BackgroundColor3 = Color3.fromRGB(180,60,60)
dpClose.Text = "X"
dpClose.TextColor3 = Color3.new(1,1,1)
dpClose.Font = Enum.Font.GothamBold
dpClose.TextSize = 14
Instance.new("UICorner", dpClose).CornerRadius = UDim.new(0,5)

dpClose.Activated:Connect(function()
    droppedPopup.Visible = false
end)

local dpScroll = Instance.new("ScrollingFrame", droppedPopup)
dpScroll.Size = UDim2.new(1,-20,1,-56)
dpScroll.Position = UDim2.new(0,10,0,46)
dpScroll.BackgroundTransparency = 1
dpScroll.ScrollBarThickness = 4

local dpLayout = Instance.new("UIListLayout", dpScroll)
dpLayout.Padding = UDim.new(0,8)

local function populateDroppedItems()
    for _,c in ipairs(dpScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local droppedFolder = workspace:FindFirstChild("DroppedTools")
    if not droppedFolder or #droppedFolder:GetChildren() == 0 then
        local lbl = Instance.new("TextLabel", dpScroll)
        lbl.Size = UDim2.new(1,0,0,34)
        lbl.BackgroundTransparency = 1
        lbl.Text = "No dropped items found"
        lbl.TextColor3 = Color3.fromRGB(150,150,170)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        return
    end

    for _, item in ipairs(droppedFolder:GetChildren()) do
        if item:IsA("Model") or item:IsA("Tool") then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1,0,0,42)
            btn.BackgroundColor3 = Color3.fromRGB(28,28,36)
            btn.Text = "  " .. (item.Name or "Unnamed Item")
            btn.TextColor3 = Color3.fromRGB(220,220,220)
            btn.Font = Enum.Font.GothamSemibold
            btn.TextSize = 14
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.Parent = dpScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

            btn.Activated:Connect(function()
                selectedItem = item
                droppedDropdown.Text = item.Name or "Selected Item"
                droppedPopup.Visible = false
            end)
        end
    end
end

droppedDropdown.Activated:Connect(function()
    droppedPopup.Visible = true
    populateDroppedItems()
end)

-- TOOLS / MISC PAGE
local toolsPage = pages["Tools"]

local rejoinBtn = Instance.new("TextButton", toolsPage)
rejoinBtn.Size = UDim2.new(1,0,0,36)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(70,130,210)
rejoinBtn.Text = "Rejoin Server"
rejoinBtn.TextColor3 = Color3.new(1,1,1)
rejoinBtn.Font = Enum.Font.GothamSemibold
rejoinBtn.TextSize = 14
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0,6)
rejoinBtn.Activated:Connect(function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
end)

local restartEspBtn = Instance.new("TextButton", toolsPage)
restartEspBtn.Size = UDim2.new(1,0,0,36)
restartEspBtn.Position = UDim2.new(0,0,0,46)
restartEspBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
restartEspBtn.Text = "Restart ESP"
restartEspBtn.TextColor3 = Color3.new(1,1,1)
restartEspBtn.Font = Enum.Font.GothamSemibold
restartEspBtn.TextSize = 14
Instance.new("UICorner", restartEspBtn).CornerRadius = UDim.new(0,6)
restartEspBtn.Activated:Connect(function()
    refreshESP()
    refreshDroppedTools()
end)

local destroyBtn = Instance.new("TextButton", toolsPage)
destroyBtn.Size = UDim2.new(1,0,0,36)
destroyBtn.Position = UDim2.new(0,0,0,92)
destroyBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
destroyBtn.Text = "Destroy Script"
destroyBtn.TextColor3 = Color3.new(1,1,1)
destroyBtn.Font = Enum.Font.GothamSemibold
destroyBtn.TextSize = 14
Instance.new("UICorner", destroyBtn).CornerRadius = UDim.new(0,6)
destroyBtn.Activated:Connect(destroyScript)

-- Team selector popup
local popup = Instance.new("Frame")
popup.Size = UDim2.new(0, 300, 0, 380)
popup.Position = UDim2.new(0.5, -150, 0.5, -190)
popup.BackgroundColor3 = Color3.fromRGB(18,18,23)
popup.Visible = false
popup.Parent = sg
Instance.new("UICorner", popup).CornerRadius = UDim.new(0,8)

local pStroke = Instance.new("UIStroke", popup)
pStroke.Color = Color3.fromRGB(40,40,55)
pStroke.Thickness = 1.2

local pTitleBar = Instance.new("Frame", popup)
pTitleBar.Size = UDim2.new(1,0,0,36)
pTitleBar.BackgroundColor3 = Color3.fromRGB(22,22,28)
pTitleBar.BorderSizePixel = 0

local pTitle = Instance.new("TextLabel", pTitleBar)
pTitle.Size = UDim2.new(1,-50,1,0)
pTitle.Position = UDim2.new(0,14,0,0)
pTitle.BackgroundTransparency = 1
pTitle.Text = "Select Target Teams"
pTitle.TextColor3 = Color3.fromRGB(210,210,220)
pTitle.Font = Enum.Font.GothamSemibold
pTitle.TextSize = 15

local pClose = Instance.new("TextButton", pTitleBar)
pClose.Size = UDim2.new(0,30,0,30)
pClose.Position = UDim2.new(1,-36,0.5,-15)
pClose.BackgroundColor3 = Color3.fromRGB(180,60,60)
pClose.Text = "X"
pClose.TextColor3 = Color3.new(1,1,1)
pClose.Font = Enum.Font.GothamBold
pClose.TextSize = 14
Instance.new("UICorner", pClose).CornerRadius = UDim.new(0,5)

pClose.Activated:Connect(function()
    popup.Visible = false
end)

local pScroll = Instance.new("ScrollingFrame", popup)
pScroll.Size = UDim2.new(1,-20,1,-56)
pScroll.Position = UDim2.new(0,10,0,46)
pScroll.BackgroundTransparency = 1
pScroll.ScrollBarThickness = 4

local pLayout = Instance.new("UIListLayout", pScroll)
pLayout.Padding = UDim.new(0,8)

local function populateTeams()
    for _,c in ipairs(pScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local teams = Teams:GetTeams()
    if #teams == 0 then
        local lbl = Instance.new("TextLabel", pScroll)
        lbl.Size = UDim2.new(1,0,0,34)
        lbl.BackgroundTransparency = 1
        lbl.Text = "No teams found"
        lbl.TextColor3 = Color3.fromRGB(150,150,170)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        return
    end
    for _, team in ipairs(teams) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,0,42)
        btn.BackgroundColor3 = Color3.fromRGB(28,28,36)
        btn.Text = "  " .. team.Name
        btn.TextColor3 = team.TeamColor.Color
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 14
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = pScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
        btn.Activated:Connect(function()
            local cur = teamBox.Text
            teamBox.Text = cur == "" and team.Name or cur .. ", " .. team.Name
            targetTeamName = teamBox.Text
        end)
    end
end

selectTeamsBtn.Activated:Connect(function()
    popup.Visible = true
    populateTeams()
end)

-- ────────────────────────────────────────────────
-- Core logic + SUPER FAST spam click
-- ────────────────────────────────────────────────

local function getClosestTarget()
    local mpos = UserInputService:GetMouseLocation()
    local best, bestD = nil, math.huge
    local wanted = {}
    for _, t in string.split(targetTeamName, ",") do
        local tr = string.match(t, "^%s*(.-)%s*$")
        if tr and tr ~= "" then table.insert(wanted, tr:lower()) end
    end
    for _, p in Players:GetPlayers() do
        if p == lp or not p.Team or not p.Character then continue end
        local tl = p.Team.Name:lower()
        local match = false
        for _, w in wanted do
            if tl:find(w, 1, true) then match = true break end
        end
        if not match then continue end
        if requireToolToLock then
            local has = p.Character and p.Character:FindFirstChildWhichIsA("Tool")
            if not has and p:FindFirstChild("Backpack") then
                for _,it in p.Backpack:GetChildren() do
                    if it:IsA("Tool") then has = true break end
                end
            end
            if not has then continue end
        end
        local head = p.Character:FindFirstChild("Head")
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        if head and hum and hum.Health > 0 then
            local d3 = (head.Position - cam.CFrame.Position).Magnitude
            if d3 <= MAX_DISTANCE then
                local sp, vis = cam:WorldToViewportPoint(head.Position)
                if vis then
                    local d2 = (Vector2.new(sp.X, sp.Y) - mpos).Magnitude
                    if d2 <= FOV_RADIUS and d2 < bestD then
                        bestD = d2
                        best = p
                    end
                end
            end
        end
    end
    return best
end

UserInputService.InputBegan:Connect(function(i, gp)
    if gp or not aimlockEnabled then return end
    if i.UserInputType == Enum.UserInputType.MouseButton2 then
        lockedTarget = getClosestTarget()
        locking = lockedTarget ~= nil
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then
        locking = false
        lockedTarget = nil
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if not locking or not lockedTarget or not aimlockEnabled then return end

    local ch = lockedTarget.Character
    if not ch then locking = false lockedTarget = nil return end
    local h = ch:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then locking = false lockedTarget = nil return end

    local part = ch:FindFirstChild(targetPart)
    if targetPart == "Random" then
        local valid = {}
        for _,o in ch:GetChildren() do
            if o:IsA("BasePart") and o.Name ~= "HumanoidRootPart" then table.insert(valid,o) end
        end
        part = #valid > 0 and valid[math.random(1,#valid)] or ch.Head
    end
    if not part then return end

    local vel = part.AssemblyLinearVelocity or Vector3.zero
    local pos = part.Position + vel * PREDICTION_FACTOR
    local tcf = CFrame.lookAt(cam.CFrame.Position, pos)
    cam.CFrame = cam.CFrame:Lerp(tcf, 1 - math.exp(-SMOOTHNESS * dt))

    if spamClickMode then
        VirtualUser:Button1Down(Vector2.zero, cam.CFrame)
        task.delay(0.010 + math.random() * 0.008, function()
            VirtualUser:Button1Up(Vector2.zero, cam.CFrame)
        end)
    end
end)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.G then
        sg.Enabled = not sg.Enabled
    end
end)

lp.CharacterAdded:Connect(function()
    task.wait(0.5)
    if espEnabled then refreshESP() end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.3)
        if espEnabled then updateESP(p) end
    end)
end)

Players.PlayerRemoving:Connect(removeESP)

task.spawn(function()
    while true do
        if espEnabled then
            refreshESP()
        end
        task.wait(espRefreshInterval)
    end
end)

-- Dropped Tools refresh loop
task.spawn(function()
    while true do
        if espDroppedTools then
            updateDroppedToolsESP()
        end
        task.wait(3) -- refresh every 3 seconds to catch new drops
    end
end)

-- Dragging
local drag, dragStart, startPos
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true
        dragStart = inp.Position
        startPos = main.Position
    end
end)

titleBar.InputChanged:Connect(function(inp)
    if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = inp.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

titleBar.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
end)
