--[[
  MM2 Mobile — Visual Spawn + Dupe Tool v1.0
  Адаптирован под Android (Delta, Codex, Arceus X)
  - Весь экран, крупные кнопки
  - Спавн в инвентарь (реальный визуал)
  - Дюп (race condition exploit)
]]

if _G.MM2MobileLoaded then return end
_G.MM2MobileLoaded = true

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local RunSvc = game:GetService("RunService")

-- ===== БАЗА ПРЕДМЕТОВ (только самое ценное) =====
local ITEMS = {
    {"Chroma Tides", "3316023216"},
    {"Chroma Darkbringer", "4795102252"},
    {"Chroma Heat", "3679856235"},
    {"Chroma Luger", "4802846569"},
    {"Chroma Fang", "3866496593"},
    {"Chroma Saw", "4010421394"},
    {"Chroma Boneblade", "4201513013"},
    {"Chroma Deathshard", "4757020501"},
    {"Corrupt", "2522429070"},
    {"Darkbringer", "4184571262"},
    {"Eternal", "4277198334"},
    {"Eternal II", "4686897237"},
    {"Heartblade", "5942259649"},
    {"Luger", "2487428118"},
    {"Luger Cane", "2552133780"},
    {"Old Glory", "4538346795"},
    {"Saw", "2530471550"},
    {"Seer", "1029718616"},
    {"Sugar", "2522007892"},
    {"Tides", "3069075015"},
    {"Blaster", "3814547802"},
    {"Ghost", "4972760773"},
    {"Cookieblaster", "4345362805"},
    {"Elderwood Scythe", "6236416903"},
    {"Hallowscythe", "4200541572"},
    {"Harvester", "5909583032"},
    {"Icewing", "5753766549"},
    {"Soul", "5927047202"},
    {"Sparkle Time", "6971385610"},
    {"Glass", "2641056315"},
}

-- ===== УЛУЧШЕННЫЙ СПАВН В ИНВЕНТАРЬ =====
local function SpawnToInventory(itemName, assetId)
    -- Метод 0: если есть прямой ремоут на добавление предмета
    for _, v in ipairs(LP:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("additem") or v.Name:lower():find("give")) then
            pcall(function() v:FireServer({Name = itemName, AssetId = assetId}) end)
        end
    end

    -- Метод 1: InventoryData Folder (классика)
    local invData = LP:FindFirstChild("InventoryData")
    if not invData then
        for _, child in ipairs(LP:GetChildren()) do
            if child:IsA("Folder") and (child.Name:lower():find("inv") or child.Name:lower():find("data")) then
                invData = child
                break
            end
        end
    end
    if not invData then
        -- поищем глубже
        for _, desc in ipairs(LP:GetDescendants()) do
            if desc:IsA("Folder") and desc.Name == "Inventory" then
                invData = desc
                break
            end
        end
    end
    if invData then
        if not invData:FindFirstChild(assetId) then
            local obj = Instance.new("StringValue")
            obj.Name = assetId
            obj.Value = itemName
            obj.Parent = invData
        end
    end

    -- Метод 2: чиним PlayerData
    local pd = LP:FindFirstChild("PlayerData")
    if pd then
        local inv = pd:FindFirstChild("Inventory")
        if inv and not inv:FindFirstChild(assetId) then
            local obj = Instance.new("StringValue")
            obj.Name = assetId
            obj.Value = itemName
            obj.Parent = inv
        end
    end

    -- Метод 3: вставляемся прямо в список предметов в MainGui
    local mainGui = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("MainGui")
    if mainGui then
        local itemList = mainGui:FindFirstChild("ItemList") or mainGui:FindFirstChild("Items")
        if itemList and not itemList:FindFirstChild(assetId) then
            local img = Instance.new("ImageButton")
            img.Name = assetId
            img.Size = UDim2.new(0, 50, 0, 50)
            img.BackgroundTransparency = 1
            img.Image = "rbxassetid://" .. assetId
            img.Parent = itemList
        end

        -- триггерим обновление
        for _, v in ipairs(mainGui:GetDescendants()) do
            if v:IsA("BindableEvent") and v.Name:lower():find("refresh") then
                v:Fire()
            end
            if v:IsA("BindableEvent") and v.Name:lower():find("update") then
                v:Fire()
            end
        end
    end

    -- Метод 4: хардкор — пишем напрямую в ValueObjects
    for _, val in ipairs(LP:GetDescendants()) do
        if val:IsA("StringValue") and (val.Name:lower():find("items") or val.Name:lower():find("owned")) then
            if not val.Value:find(assetId) then
                val.Value = val.Value .. "," .. assetId
            end
        end
        if val:IsA("IntValue") and val.Name == assetId then
            val.Value = 1
        end
        -- ArrayValue
        if val:IsA("ArrayValue") and val.Name:lower():find("inv") then
            pcall(function() val:Add(assetId) end)
        end
    end

    -- Метод 5: getfenv патч
    for _, scr in ipairs(LP:GetDescendants()) do
        if scr:IsA("LocalScript") then
            local ok, env = pcall(getfenv, scr)
            if ok and type(env) == "table" then
                for _, func in pairs(env) do
                    if type(func) == "function" then
                        pcall(func, {id = assetId, name = itemName, type = "Melee"})
                    end
                end
            end
        end
    end

    return true
end

-- ===== ДЮП (EXPLOIT) =====
-- Пытается создать race condition в трейде
local dupeActive = false
local dupeThread = nil

local function StartDupe(assetId)
    if dupeActive then return false, "Дюп уже запущен" end
    dupeActive = true

    -- Пробуем найти ремоуты трейда
    local tradeRemotes = {}
    for _, v in ipairs(LP:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local name = v.Name:lower()
            if name:find("trade") or name:find("offer") or name:find("confirm") or
               name:find("accept") or name:find("decline") or name:find("add") then
                table.insert(tradeRemotes, v)
            end
        end
    end

    -- Если нашли — пробуем спамить
    if #tradeRemotes > 0 then
        dupeThread = task.spawn(function()
            local count = 0
            while dupeActive and count < 50 do
                for _, rem in ipairs(tradeRemotes) do
                    if rem:IsA("RemoteEvent") then
                        pcall(function()
                            rem:FireServer({
                                itemId = assetId,
                                action = "add",
                                count = 1
                            })
                        end)
                        pcall(function()
                            rem:FireServer({
                                itemId = assetId,
                                action = "remove",
                                count = 1
                            })
                        end)
                    elseif rem:IsA("RemoteFunction") then
                        pcall(function()
                            rem:InvokeServer({
                                itemId = assetId,
                                action = "duplicate"
                            })
                        end)
                    end
                end
                count = count + 1
                task.wait(0.05)
            end
            dupeActive = false
        end)
        return true, "Дюп запущен (49 попыток)"
    else
        dupeActive = false
        return false, "Не найдены ремоуты трейда"
    end
end

local function StopDupe()
    if dupeActive then
        dupeActive = false
        if dupeThread then
            task.cancel(dupeThread)
            dupeThread = nil
        end
        return true
    end
    return false
end

-- ===== СОЗДАНИЕ GUI (на весь экран, адаптив) =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2Mobile"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LP:WaitForChild("PlayerGui")

-- затемнение фона
local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bg.BackgroundTransparency = 0.35
bg.BorderSizePixel = 0
bg.Active = true
bg.Parent = screenGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 360, 0, 520)
frame.Position = UDim2.new(0.5, -180, 0.5, -260)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 16)
fCorner.Parent = frame

-- ===== ЗАГОЛОВОК =====
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
header.BorderSizePixel = 0
header.Parent = frame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 16)
hCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚔ MM2 Mobile"
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255, 210, 60)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.Text = "✕"
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header
local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 8)
cCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- ===== СТРОКА ПОИСКА (большая, под палец) =====
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -24, 0, 40)
searchBox.Position = UDim2.new(0, 12, 0, 52)
searchBox.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
searchBox.PlaceholderText = "🔍 Поиск..."
searchBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 160)
searchBox.Text = ""
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 16
searchBox.ClearTextOnFocus = false
searchBox.Parent = frame
local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 10)
sCorner.Parent = searchBox

-- ===== ВКЛАДКИ =====
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -24, 0, 40)
tabFrame.Position = UDim2.new(0, 12, 0, 100)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = frame

local tabs = {}
local tabNames2 = {"Все", "Ножи", "Пушки", "Древние"}
local tabX = 0
for _, tname in ipairs(tabNames2) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 74, 0, 36)
    btn.Position = UDim2.new(0, tabX, 0, 2)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    btn.Text = tname
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.GothamBold
    btn.Parent = tabFrame
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 10)
    bCorner.Parent = btn
    tabs[tname] = btn
    tabX = tabX + 80
end

-- ===== СПИСОК (на 55% экрана) =====
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -24, 0, 220)
listFrame.Position = UDim2.new(0, 12, 0, 148)
listFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
listFrame.BorderSizePixel = 0
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 6
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = frame

local lCorner = Instance.new("UICorner")
lCorner.CornerRadius = UDim.new(0, 10)
lCorner.Parent = listFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

-- ===== СТАТУС =====
local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, -24, 0, 22)
statusText.Position = UDim2.new(0, 12, 0, 376)
statusText.BackgroundTransparency = 1
statusText.Font = Enum.Font.Gotham
statusText.Text = "✅ Готов"
statusText.TextSize = 15
statusText.TextColor3 = Color3.fromRGB(0, 255, 100)
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Parent = frame

-- ===== КНОПКИ (крупные, под палец) =====
-- Кнопка в инвентарь
local invBtn = Instance.new("TextButton")
invBtn.Size = UDim2.new(1, -24, 0, 48)
invBtn.Position = UDim2.new(0, 12, 0, 406)
invBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
invBtn.Text = "📦 Добавить в инвентарь"
invBtn.TextSize = 17
invBtn.TextColor3 = Color3.new(1, 1, 1)
invBtn.Font = Enum.Font.GothamBold
invBtn.Parent = frame
local iCorner = Instance.new("UICorner")
iCorner.CornerRadius = UDim.new(0, 12)
iCorner.Parent = invBtn

-- Кнопка дюпа
local dupeBtn = Instance.new("TextButton")
dupeBtn.Size = UDim2.new(1, -24, 0, 48)
dupeBtn.Position = UDim2.new(0, 12, 0, 462)
dupeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
dupeBtn.Text = "🔄 ЗАПУСТИТЬ ДЮП"
dupeBtn.TextSize = 17
dupeBtn.TextColor3 = Color3.new(1, 1, 1)
dupeBtn.Font = Enum.Font.GothamBold
dupeBtn.Parent = frame
local dCorner = Instance.new("UICorner")
dCorner.CornerRadius = UDim.new(0, 12)
dCorner.Parent = dupeBtn

-- ===== ЛОГИКА =====
local selected = nil
local currentTab2 = "Все"

local function GetItemList(tab)
    if tab == "Все" then return ITEMS end
    if tab == "Ножи" then
        local r = {}
        for _, v in ipairs(ITEMS) do
            local n = v[1]:lower()
            if not n:find("gun") and not n:find("blaster") and not n:find("ghost") and not n:find("cookie") then
                table.insert(r, v)
            end
        end
        return r
    end
    if tab == "Пушки" then
        local r = {}
        for _, v in ipairs(ITEMS) do
            local n = v[1]:lower()
            if n:find("gun") or n:find("blaster") or n:find("ghost") or n:find("cookie") then
                table.insert(r, v)
            end
        end
        return r
    end
    -- древние
    local ancient = {"elderwood", "hallowscythe", "harvester", "icewing", "soul", "sparkle", "glass"}
    local r = {}
    for _, v in ipairs(ITEMS) do
        for _, a in ipairs(ancient) do
            if v[1]:lower():find(a) then
                table.insert(r, v)
                break
            end
        end
    end
    return r
end

local function RefreshList()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local query = searchBox.Text:lower()
    local items = GetItemList(currentTab2)

    local hasItems = false
    for _, item in ipairs(items) do
        local name, id = item[1], item[2]
        if query == "" or name:lower():find(query) then
            hasItems = true
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, 0, 0, 42)
            row.BackgroundColor3 = Color3.fromRGB(42, 42, 60)
            row.Text = ""
            row.BorderSizePixel = 0
            row.Parent = listFrame

            local rCorner = Instance.new("UICorner")
            rCorner.CornerRadius = UDim.new(0, 8)
            rCorner.Parent = row

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.7, -8, 1, 0)
            nameLabel.Position = UDim2.new(0, 12, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Text = name
            nameLabel.TextSize = 15
            nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = row

            local idLabel = Instance.new("TextLabel")
            idLabel.Size = UDim2.new(0.3, -8, 1, 0)
            idLabel.Position = UDim2.new(0.7, 0, 0, 0)
            idLabel.BackgroundTransparency = 1
            idLabel.Font = Enum.Font.Gotham
            idLabel.Text = id
            idLabel.TextSize = 11
            idLabel.TextColor3 = Color3.fromRGB(140, 140, 170)
            idLabel.TextXAlignment = Enum.TextXAlignment.Right
            idLabel.Parent = row

            row.MouseButton1Click:Connect(function()
                selected = {name = name, id = id}
                for _, child2 in ipairs(listFrame:GetChildren()) do
                    if child2:IsA("TextButton") then
                        child2.BackgroundColor3 = Color3.fromRGB(42, 42, 60)
                    end
                end
                row.BackgroundColor3 = Color3.fromRGB(90, 80, 20)
                statusText.Text = "✅ " .. name
                statusText.TextColor3 = Color3.fromRGB(255, 210, 60)
            end)
        end
    end

    if not hasItems then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Gotham
        empty.Text = "❌ Ничего не найдено"
        empty.TextSize = 14
        empty.TextColor3 = Color3.fromRGB(150, 150, 170)
        empty.Parent = listFrame
    end
end

-- клики на вкладки
for tname, btn in pairs(tabs) do
    btn.MouseButton1Click:Connect(function()
        currentTab2 = tname
        for _, b in pairs(tabs) do
            b.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            b.TextColor3 = Color3.fromRGB(220, 220, 220)
        end
        btn.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
        btn.TextColor3 = Color3.fromRGB(20, 20, 30)
        RefreshList()
    end)
end

-- поиск
searchBox:GetPropertyChangedSignal("Text"):Connect(RefreshList)

-- кнопка в инвентарь
invBtn.MouseButton1Click:Connect(function()
    if not selected then
        statusText.Text = "⚠ Сначала выбери предмет"
        statusText.TextColor3 = Color3.fromRGB(255, 180, 60)
        return
    end
    statusText.Text = "⏳ Добавляю " .. selected.name .. "..."
    statusText.TextColor3 = Color3.fromRGB(255, 210, 60)
    task.wait(0.2)
    SpawnToInventory(selected.name, selected.id)
    statusText.Text = "✅ " .. selected.name .. " в инвентаре (визуал)"
    statusText.TextColor3 = Color3.fromRGB(0, 255, 100)
end)

-- кнопка дюпа
dupeBtn.MouseButton1Click:Connect(function()
    if dupeActive then
        StopDupe()
        dupeBtn.Text = "🔄 ЗАПУСТИТЬ ДЮП"
        dupeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        statusText.Text = "⏹ Дюп остановлен"
        statusText.TextColor3 = Color3.fromRGB(255, 200, 100)
        return
    end

    if not selected then
        statusText.Text = "⚠ Выбери предмет для дюпа"
        statusText.TextColor3 = Color3.fromRGB(255, 180, 60)
        return
    end

    dupeBtn.Text = "⏹ СТОП ДЮП"
    dupeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    local ok, msg = StartDupe(selected.id)
    statusText.Text = msg
    statusText.TextColor3 = ok and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 80, 80)
end)

-- ===== СТАРТ =====
RefreshList()
print("=== MM2 Mobile загружен ===")
