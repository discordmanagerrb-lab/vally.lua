local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
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

local function destroyScript()
    aimlockEnabled = false
    espEnabled = false
    locking = false
    lockedTarget = nil

    refreshESP()

    if sg then
        sg:Destroy()
        sg = nil
    end
end

local sg = Instance.new("ScreenGui")
sg.Name = "AimlockESP"
sg.ResetOnSpawn = false
sg.Enabled = true
sg.Parent = lp:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 520, 0, 380)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = sg
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(45, 45, 58)
stroke.Thickness = 1.5

local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1,0,0,42)
titleBar.BackgroundColor3 = Color3.fromRGB(24,24,32)
titleBar.BorderSizePixel = 0

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1,-50,1,0)
title.Position = UDim2.new(0,16,0,0)
title.BackgroundTransparency = 1
title.Text = "Aimlock & Team ESP"
title.TextColor3 = Color3.fromRGB(215,215,235)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0,36,0,36)
closeBtn.Position = UDim2.new(1,-44,0,3)
closeBtn.BackgroundColor3 = Color3.fromRGB(210,70,70)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 22
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)

closeBtn.Activated:Connect(function()
    sg.Enabled = false
end)

local tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(1,0,0,44)
tabBar.Position = UDim2.new(0,0,0,42)
tabBar.BackgroundColor3 = Color3.fromRGB(22,22,28)
tabBar.BorderSizePixel = 0

local tabList = Instance.new("UIListLayout", tabBar)
tabList.FillDirection = Enum.FillDirection.Horizontal
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabList.Padding = UDim.new(0,12)

local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1,-32,1,-102)
contentArea.Position = UDim2.new(0,16,0,92)
contentArea.BackgroundTransparency = 1

local tabs = {}
local activeTab

local function createTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 130, 0.9, 0)
    btn.BackgroundColor3 = Color3.fromRGB(34,34,44)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(170,170,190)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 15
    btn.LayoutOrder = order
    btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,1,0)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(60,60,80)
    scroll.CanvasSize = UDim2.new(0,0,0,600)
    scroll.Visible = false
    scroll.Parent = contentArea

    local list = Instance.new("UIListLayout", scroll)
    list.Padding = UDim.new(0,14)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0, list.AbsoluteContentSize.Y + 50)
    end)

    tabs[name] = {btn = btn, scroll = scroll}

    btn.Activated:Connect(function()
        if activeTab then
            activeTab.scroll.Visible = false
            activeTab.btn.BackgroundColor3 = Color3.fromRGB(34,34,44)
            activeTab.btn.TextColor3 = Color3.fromRGB(170,170,190)
        end
        scroll.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(0, 175, 135)
        btn.TextColor3 = Color3.new(1,1,1)
        activeTab = tabs[name]
    end)

    return scroll
end

local lockTab = createTab("LOCK", 1)
local espTab = createTab("ESP", 2)
local miscTab = createTab("MISC", 3)

activeTab = tabs.LOCK
activeTab.scroll.Visible = true
activeTab.btn.BackgroundColor3 = Color3.fromRGB(0,175,135)
activeTab.btn.TextColor3 = Color3.new(1,1,1)

local teamTitle = Instance.new("TextLabel", lockTab)
teamTitle.Size = UDim2.new(1,0,0,24)
teamTitle.BackgroundTransparency = 1
teamTitle.Text = "Target Team(s)"
teamTitle.TextColor3 = Color3.fromRGB(190,190,210)
teamTitle.Font = Enum.Font.GothamSemibold
teamTitle.TextSize = 15
teamTitle.TextXAlignment = Enum.TextXAlignment.Left

local teamBox = Instance.new("TextBox", lockTab)
teamBox.Size = UDim2.new(0.68,0,0,40)
teamBox.BackgroundColor3 = Color3.fromRGB(30,30,38)
teamBox.TextColor3 = Color3.new(1,1,1)
teamBox.PlaceholderText = "Guards, Prisoners..."
teamBox.Text = targetTeamName
teamBox.Font = Enum.Font.Gotham
teamBox.TextSize = 15
teamBox.ClearTextOnFocus = false
Instance.new("UICorner", teamBox).CornerRadius = UDim.new(0,8)

teamBox.FocusLost:Connect(function()
    targetTeamName = teamBox.Text
end)

local selectTeamsBtn = Instance.new("TextButton", lockTab)
selectTeamsBtn.Size = UDim2.new(0.3, -8, 0,40)
selectTeamsBtn.Position = UDim2.new(0.7, 0, 0,0)
selectTeamsBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
selectTeamsBtn.Text = "Select Teams"
selectTeamsBtn.TextColor3 = Color3.new(1,1,1)
selectTeamsBtn.Font = Enum.Font.GothamSemibold
selectTeamsBtn.TextSize = 14
Instance.new("UICorner", selectTeamsBtn).CornerRadius = UDim.new(0,8)

local popup = Instance.new("Frame")
popup.Size = UDim2.new(0, 300, 0, 380)
popup.Position = UDim2.new(0.5, -150, 0.5, -190)
popup.BackgroundColor3 = Color3.fromRGB(18,18,23)
popup.Visible = false
popup.Parent = sg
Instance.new("UICorner", popup).CornerRadius = UDim.new(0,10)

local pStroke = Instance.new("UIStroke", popup)
pStroke.Color = Color3.fromRGB(50,50,65)
pStroke.Thickness = 1.4

local pTitleBar = Instance.new("Frame", popup)
pTitleBar.Size = UDim2.new(1,0,0,42)
pTitleBar.BackgroundColor3 = Color3.fromRGB(24,24,32)
pTitleBar.BorderSizePixel = 0

local pTitle = Instance.new("TextLabel", pTitleBar)
pTitle.Size = UDim2.new(1,-50,1,0)
pTitle.Position = UDim2.new(0,16,0,0)
pTitle.BackgroundTransparency = 1
pTitle.Text = "Select Target Teams"
pTitle.TextColor3 = Color3.fromRGB(215,215,235)
pTitle.Font = Enum.Font.GothamSemibold
pTitle.TextSize = 16

local pClose = Instance.new("TextButton", pTitleBar)
pClose.Size = UDim2.new(0,36,0,36)
pClose.Position = UDim2.new(1,-44,0,3)
pClose.BackgroundColor3 = Color3.fromRGB(210,70,70)
pClose.Text = "×"
pClose.TextColor3 = Color3.new(1,1,1)
pClose.Font = Enum.Font.GothamBold
pClose.TextSize = 20
Instance.new("UICorner", pClose).CornerRadius = UDim.new(0,8)

pClose.Activated:Connect(function()
    popup.Visible = false
end)

local pScroll = Instance.new("ScrollingFrame", popup)
pScroll.Size = UDim2.new(1,-20,1,-62)
pScroll.Position = UDim2.new(0,10,0,52)
pScroll.BackgroundTransparency = 1
pScroll.ScrollBarThickness = 4

local pLayout = Instance.new("UIListLayout", pScroll)
pLayout.Padding = UDim.new(0,10)

local function populateTeams()
    for _,c in ipairs(pScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local teams = Teams:GetTeams()
    if #teams == 0 then
        local lbl = Instance.new("TextLabel", pScroll)
        lbl.Size = UDim2.new(1,0,0,34)
        lbl.BackgroundTransparency = 1
        lbl.Text = "No teams found in game"
        lbl.TextColor3 = Color3.fromRGB(150,150,170)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 15
        return
    end

    for _, team in ipairs(teams) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,0,46)
        btn.BackgroundColor3 = Color3.fromRGB(30,30,38)
        btn.Text = team.Name
        btn.TextColor3 = team.TeamColor.Color
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 15
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = pScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

        local pad = Instance.new("UIPadding", btn)
        pad.PaddingLeft = UDim.new(0,16)

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

local function addSlider(parent, title, min, max, def, cb)
    local cont = Instance.new("Frame", parent)
    cont.Size = UDim2.new(1,0,0,60)
    cont.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", cont)
    lbl.Size = UDim2.new(1,0,0,22)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(190,190,210)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 15
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextBox", cont)
    val.Size = UDim2.new(0,80,0,22)
    val.Position = UDim2.new(1,-90,0,0)
    val.BackgroundTransparency = 1
    val.Text = tostring(def)
    val.TextColor3 = Color3.fromRGB(0,210,170)
    val.Font = Enum.Font.Gotham
    val.TextSize = 15
    val.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", cont)
    track.Size = UDim2.new(1,0,0,8)
    track.Position = UDim2.new(0,0,0,32)
    track.BackgroundColor3 = Color3.fromRGB(40,40,50)
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(0.5,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,175,135)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,22,0,22)
    knob.Position = UDim2.new(0.5,-11,0.5,-11)
    knob.BackgroundColor3 = Color3.fromRGB(220,220,240)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local dragging = false

    local function update(pct)
        pct = math.clamp(pct,0,1)
        fill.Size = UDim2.new(pct,0,1,0)
        knob.Position = UDim2.new(pct,-11,0.5,-11)
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

    val.FocusLost:Connect(function(en)
        if en then
            local n = tonumber(val.Text)
            if n then update(math.clamp(n,min,max)/(max-min)) end
        end
    end)

    update((def-min)/(max-min))
end

addSlider(lockTab, "Max Distance", 500, 10000, MAX_DISTANCE, function(v) MAX_DISTANCE = v end)
addSlider(lockTab, "Smoothness", 10, 120, SMOOTHNESS, function(v) SMOOTHNESS = v end)
addSlider(lockTab, "FOV Radius", 200, 2000, FOV_RADIUS, function(v) FOV_RADIUS = v end)
addSlider(lockTab, "Prediction Factor", 0.05, 0.3, PREDICTION_FACTOR, function(v) PREDICTION_FACTOR = v end)

local partDropdown = Instance.new("TextButton", lockTab)
partDropdown.Size = UDim2.new(1,0,0,42)
partDropdown.BackgroundColor3 = Color3.fromRGB(30,30,38)
partDropdown.Text = "Target Part: " .. targetPart
partDropdown.TextColor3 = Color3.new(1,1,1)
partDropdown.Font = Enum.Font.GothamSemibold
partDropdown.TextSize = 15
Instance.new("UICorner", partDropdown).CornerRadius = UDim.new(0,8)

partDropdown.Activated:Connect(function()
    currentPartIndex = (currentPartIndex % #parts) + 1
    targetPart = parts[currentPartIndex]
    partDropdown.Text = "Target Part: " .. targetPart
end)

local reqToolBtn = Instance.new("TextButton", lockTab)
reqToolBtn.Size = UDim2.new(1,0,0,42)
reqToolBtn.BackgroundColor3 = requireToolToLock and Color3.fromRGB(0,175,135) or Color3.fromRGB(60,60,70)
reqToolBtn.Text = requireToolToLock and "Require Tool to Lock ON" or "Require Tool to Lock OFF"
reqToolBtn.TextColor3 = Color3.new(1,1,1)
reqToolBtn.Font = Enum.Font.GothamSemibold
reqToolBtn.TextSize = 15
Instance.new("UICorner", reqToolBtn).CornerRadius = UDim.new(0,8)

reqToolBtn.Activated:Connect(function()
    requireToolToLock = not requireToolToLock
    reqToolBtn.Text = requireToolToLock and "Require Tool to Lock ON" or "Require Tool to Lock OFF"
    reqToolBtn.BackgroundColor3 = requireToolToLock and Color3.fromRGB(0,175,135) or Color3.fromRGB(60,60,70)
end)

local spamBtn = Instance.new("TextButton", lockTab)
spamBtn.Size = UDim2.new(1,0,0,42)
spamBtn.BackgroundColor3 = spamClickMode and Color3.fromRGB(180,50,50) or Color3.fromRGB(60,60,70)
spamBtn.Text = spamClickMode and "Spam Fire ON" or "Spam Fire OFF"
spamBtn.TextColor3 = Color3.new(1,1,1)
spamBtn.Font = Enum.Font.GothamSemibold
spamBtn.TextSize = 15
Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0,8)

spamBtn.Activated:Connect(function()
    spamClickMode = not spamClickMode
    spamBtn.Text = spamClickMode and "Spam Fire ON" or "Spam Fire OFF"
    spamBtn.BackgroundColor3 = spamClickMode and Color3.fromRGB(180,50,50) or Color3.fromRGB(60,60,70)
end)

local espToggle = Instance.new("TextButton", espTab)
espToggle.Size = UDim2.new(1,0,0,42)
espToggle.BackgroundColor3 = espEnabled and Color3.fromRGB(0,175,135) or Color3.fromRGB(60,60,70)
espToggle.Text = espEnabled and "ESP Enabled" or "ESP Disabled"
espToggle.TextColor3 = Color3.new(1,1,1)
espToggle.Font = Enum.Font.GothamSemibold
espToggle.TextSize = 15
Instance.new("UICorner", espToggle).CornerRadius = UDim.new(0,8)

espToggle.Activated:Connect(function()
    espEnabled = not espEnabled
    espToggle.Text = espEnabled and "ESP Enabled" or "ESP Disabled"
    espToggle.BackgroundColor3 = espEnabled and Color3.fromRGB(0,175,135) or Color3.fromRGB(60,60,70)
    refreshESP()
end)

local toolsToggle = Instance.new("TextButton", espTab)
toolsToggle.Size = UDim2.new(1,0,0,42)
toolsToggle.BackgroundColor3 = espTools and Color3.fromRGB(0,175,135) or Color3.fromRGB(60,60,70)
toolsToggle.Text = espTools and "Show Tools ON" or "Show Tools OFF"
toolsToggle.TextColor3 = Color3.new(1,1,1)
toolsToggle.Font = Enum.Font.GothamSemibold
toolsToggle.TextSize = 15
Instance.new("UICorner", toolsToggle).CornerRadius = UDim.new(0,8)

toolsToggle.Activated:Connect(function()
    espTools = not espTools
    toolsToggle.Text = espTools and "Show Tools ON" or "Show Tools OFF"
    toolsToggle.BackgroundColor3 = espTools and Color3.fromRGB(0,175,135) or Color3.fromRGB(60,60,70)
    if espEnabled then refreshESP() end
end)

local tpTitle = Instance.new("TextLabel", miscTab)
tpTitle.Size = UDim2.new(1,0,0,26)
tpTitle.BackgroundTransparency = 1
tpTitle.Text = "Teleport Forward (studs)"
tpTitle.TextColor3 = Color3.fromRGB(190,190,210)
tpTitle.Font = Enum.Font.GothamSemibold
tpTitle.TextSize = 15
tpTitle.TextXAlignment = Enum.TextXAlignment.Left

local tpBox = Instance.new("TextBox", miscTab)
tpBox.Size = UDim2.new(0.5,0,0,40)
tpBox.BackgroundColor3 = Color3.fromRGB(30,30,38)
tpBox.TextColor3 = Color3.new(1,1,1)
tpBox.Text = tostring(teleportStuds)
tpBox.Font = Enum.Font.Gotham
tpBox.TextSize = 15
tpBox.ClearTextOnFocus = false
Instance.new("UICorner", tpBox).CornerRadius = UDim.new(0,8)

tpBox.FocusLost:Connect(function()
    local num = tonumber(tpBox.Text)
    teleportStuds = num and math.max(5, math.abs(num)) or 30
    tpBox.Text = tostring(teleportStuds)
end)

local tpBtn = Instance.new("TextButton", miscTab)
tpBtn.Size = UDim2.new(0.48, -8, 0,40)
tpBtn.Position = UDim2.new(0.52, 0, 0,0)
tpBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
tpBtn.Text = "Teleport Forward"
tpBtn.TextColor3 = Color3.new(1,1,1)
tpBtn.Font = Enum.Font.GothamSemibold
tpBtn.TextSize = 15
Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0,8)

tpBtn.Activated:Connect(function()
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        local dir = hrp.CFrame.LookVector
        hrp.CFrame = hrp.CFrame + dir * teleportStuds
    end
end)

local rejoinBtn = Instance.new("TextButton", miscTab)
rejoinBtn.Size = UDim2.new(1,0,0,42)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(70,130,210)
rejoinBtn.Text = "Rejoin Server"
rejoinBtn.TextColor3 = Color3.new(1,1,1)
rejoinBtn.Font = Enum.Font.GothamSemibold
rejoinBtn.TextSize = 15
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0,8)

rejoinBtn.Activated:Connect(function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
end)

local restartEspBtn = Instance.new("TextButton", miscTab)
restartEspBtn.Size = UDim2.new(1,0,0,42)
restartEspBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 180)
restartEspBtn.Text = "Restart ESP (re-check all)"
restartEspBtn.TextColor3 = Color3.new(1,1,1)
restartEspBtn.Font = Enum.Font.GothamSemibold
restartEspBtn.TextSize = 15
Instance.new("UICorner", restartEspBtn).CornerRadius = UDim.new(0,8)

restartEspBtn.Activated:Connect(function()
    refreshESP()
end)

local destroyBtn = Instance.new("TextButton", miscTab)
destroyBtn.Size = UDim2.new(1,0,0,42)
destroyBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
destroyBtn.Text = "Destroy Script (remove all)"
destroyBtn.TextColor3 = Color3.new(1,1,1)
destroyBtn.Font = Enum.Font.GothamSemibold
destroyBtn.TextSize = 15
Instance.new("UICorner", destroyBtn).CornerRadius = UDim.new(0,8)

destroyBtn.Activated:Connect(function()
    destroyScript()
end)

local refreshTitle = Instance.new("TextLabel", miscTab)
refreshTitle.Size = UDim2.new(1,0,0,26)
refreshTitle.BackgroundTransparency = 1
refreshTitle.Text = "Auto-refresh ESP every (seconds)"
refreshTitle.TextColor3 = Color3.fromRGB(190,190,210)
refreshTitle.Font = Enum.Font.GothamSemibold
refreshTitle.TextSize = 15
refreshTitle.TextXAlignment = Enum.TextXAlignment.Left
refreshTitle.Position = UDim2.new(0,0,0,150)

local refreshBox = Instance.new("TextBox", miscTab)
refreshBox.Size = UDim2.new(0.5,0,0,40)
refreshBox.Position = UDim2.new(0,0,0,176)
refreshBox.BackgroundColor3 = Color3.fromRGB(30,30,38)
refreshBox.TextColor3 = Color3.new(1,1,1)
refreshBox.Text = tostring(espRefreshInterval)
refreshBox.Font = Enum.Font.Gotham
refreshBox.TextSize = 15
refreshBox.ClearTextOnFocus = false
Instance.new("UICorner", refreshBox).CornerRadius = UDim.new(0,8)

refreshBox.FocusLost:Connect(function()
    local num = tonumber(refreshBox.Text)
    espRefreshInterval = num and math.max(1, num) or 5
    refreshBox.Text = tostring(espRefreshInterval)
end)

task.spawn(function()
    while true do
        if espEnabled then
            refreshESP()
        end
        task.wait(espRefreshInterval)
    end
end)

local drag, dragStart, startPos
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true
        dragStart = inp.Position
        startPos = mainFrame.Position
    end
end)

titleBar.InputChanged:Connect(function(inp)
    if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = inp.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

titleBar.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
end)

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

    if spamClickMode and h.Health > 0 then
        VirtualUser:Button1Down(Vector2.zero, cam.CFrame)
        task.delay(0.04 + math.random()*0.02, function()
            VirtualUser:Button1Up(Vector2.zero, cam.CFrame)
        end)
    end
end)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.G then
        if sg then
            sg.Enabled = not sg.Enabled
        end
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
