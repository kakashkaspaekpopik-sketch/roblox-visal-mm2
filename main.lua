--[[
  MM2 Visual Spawner — GUI Menu v1.0
  Работает на: Delta, Fluxus, Hydrogen, Codex, Arceus X, Wave
  
  При запуске открывается меню:
    • Вкладки: Ножи / Пушки / Древние / Все
    • Поиск по названию
    • Кнопка [Спавн] — добавляет предмет в инвентарь (визуально)
    • Кнопка [В руку] — спавнит Tool в руку персонажу
    • Перетаскивание окна пальцем/мышью
]]

-- ===== ЗАЩИТА ОТ ДВОЙНОГО ЗАПУСКА =====
if _G.MM2SpawnerLoaded then
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
        Text = "[!] Скрипт уже запущен",
        Color = Color3.fromRGB(255, 200, 50)
    })
    return
end
_G.MM2SpawnerLoaded = true

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")

-- ===== БАЗА ПРЕДМЕТОВ =====
local KNIVES = {
    {"Chroma Tides", "3316023216"},
    {"Chroma Darkbringer", "4795102252"},
    {"Chroma Heat", "3679856235"},
    {"Chroma Fang", "3866496593"},
    {"Chroma Saw", "4010421394"},
    {"Chroma Boneblade", "4201513013"},
    {"Chroma Deathshard", "4757020501"},
    {"Corrupt", "2522429070"},
    {"Darkbringer", "4184571262"},
    {"Eternal", "4277198334"},
    {"Eternal II", "4686897237"},
    {"Heartblade", "5942259649"},
    {"Iceblaster", "6511628479"},
    {"Icepiercer", "5104316400"},
    {"Luger", "2487428118"},
    {"Luger Cane", "2552133780"},
    {"Old Glory", "4538346795"},
    {"Saw", "2530471550"},
    {"Seer", "1029718616"},
    {"Slash", "2651632603"},
    {"Sugar", "2522007892"},
    {"Tides", "3069075015"},
    {"Xmas", "2555825124"},
    {"BattleAxe II", "5074057030"},
    {"Elderwood Scythe", "6236416903"},
    {"Hallowscythe", "4200541572"},
    {"Harvester", "5909583032"},
    {"Icewing", "5753766549"},
    {"Soul", "5927047202"},
    {"Amerlocker", "4870568662"},
}

local GUNS = {
    {"Blaster", "3814547802"},
    {"Chroma Luger", "4802846569"},
    {"Cookieblaster", "4345362805"},
    {"Deathshard Gun", "4756999322"},
    {"Ghost", "4972760773"},
    {"Golden Gun", "4046045889"},
    {"Peppermint Gun", "4345364250"},
    {"Frostsaber", "5882235802"},
    {"Batwing", "6185187343"},
    {"Gemstone", "5608773528"},
}

local ANCIENTS = {
    {"Sparkle Time", "6971385610"},
    {"Glass", "2641056315"},
    {"Chill", "6116262600"},
    {"Candy", "6138506800"},
    {"Frostbite", "6134314601"},
    {"Ice Shard", "6094494252"},
}

local ALL_ITEMS = {}
for _, v in ipairs(KNIVES) do table.insert(ALL_ITEMS, v) end
for _, v in ipairs(GUNS) do table.insert(ALL_ITEMS, v) end
for _, v in ipairs(ANCIENTS) do table.insert(ALL_ITEMS, v) end

-- ===== ФУНКЦИЯ СПАВНА В ИНВЕНТАРЬ (ВИЗУАЛ) =====
local function SpawnVisual(itemName, assetId)
    local added = false

    -- Метод 1: прямой вброс в данные инвентаря
    local invData = LP:FindFirstChild("InventoryData") or
                    (LP:FindFirstChild("PlayerData") and LP.PlayerData:FindFirstChild("Inventory"))
    if invData and not invData:FindFirstChild(assetId) then
        local itemObj = Instance.new("StringValue")
        itemObj.Name = assetId
        itemObj.Value = itemName
        itemObj.Parent = invData
        added = true
    end

    -- Метод 2: патч LocalScript инвентаря (если не нашли Folder)
    if not added then
        local gui = LP:FindFirstChild("PlayerGui")
        if gui then
            for _, scr in ipairs(gui:GetDescendants()) do
                if scr:IsA("LocalScript") and
                   (scr.Name:lower():find("inventory") or scr.Name:lower():find("items")) then
                    local ok, env = pcall(getfenv, scr)
                    if ok and type(env) == "table" then
                        for k, v in pairs(env) do
                            if type(v) == "function" and k:lower():find("add") then
                                pcall(v, {id = assetId, name = itemName})
                                added = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- Метод 3: spoof RemoteFunction инвентаря
    if not added then
        for _, rem in ipairs(LP:GetDescendants()) do
            if rem:IsA("RemoteFunction") and rem.Name:lower():find("inventory") then
                local old = rem.InvokeServer
                rem.InvokeServer = function(self, ...)
                    local r = {pcall(old, self, ...)}
                    table.insert(r, {itemId = assetId, itemName = itemName})
                    return unpack(r)
                end
                added = true
                break
            end
        end
    end

    -- Триггер обновления UI
    local mainGui = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("MainGui")
    if mainGui then
        for _, v in ipairs(mainGui:GetDescendants()) do
            if v:IsA("BindableEvent") and v.Name == "ItemAdded" then
                v:Fire({Name = itemName, AssetId = assetId})
            end
        end
    end

    return added
end

-- ===== СПАВН TOOL В РУКУ =====
local function SpawnTool(itemName, assetId)
    local ok, tool = pcall(function()
        local t = Instance.new("Tool")
        t.Name = itemName
        t.ToolTip = "Visual Tool (только для тебя)"
        t.CanBeDropped = false
        t.RequiresHandle = false

        -- Пытаемся подгрузить реальную модель оружия по AssetId
        pcall(function()
            local model = game:GetObjects("rbxassetid://" .. assetId)[1]
            if model then
                local handle = model:FindFirstChild("Handle")
                if handle then
                    handle.Parent = t
                    t.RequiresHandle = true
                end
                model:Destroy()
            end
        end)

        return t
    end)

    if not ok or not tool then return false end

    -- Кладём в рюкзак / в руку
    local char = LP.Character
    local backpack = LP:FindFirstChild("Backpack")
    if char and backpack then
        tool.Parent = backpack
        pcall(function()
            tool.Parent = char
            char:FindFirstChild("Humanoid"):EquipTool(tool)
        end)
    end

    return true
end

-- ===== СОЗДАНИЕ GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2SpawnerMenu"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LP:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.new(0, 340, 0, 480)
window.Position = UDim2.new(0.5, -170, 0.5, -240)
window.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
window.BackgroundTransparency = 0.05
window.BorderSizePixel = 0
window.Active = true
window.Parent = screenGui

-- Сглаживание углов (через UICorner)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = window

-- ===== ШАПКА (перетаскивание) =====
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
titleBar.BorderSizePixel = 0
titleBar.Parent = window

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚔ MM2 Spawner"
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.Text = "✕"
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- Сворачивание
local minBtn = Instance.new("TextButton")
minBtn.Name = "MinBtn"
minBtn.Size = UDim2.new(0, 26, 0, 26)
minBtn.Position = UDim2.new(1, -64, 0, 5)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
minBtn.Text = "—"
minBtn.TextSize = 14
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minBtn

-- ===== ПЕРЕТАСКИВАНИЕ ОКНА =====
local dragging = false
local dragOffset = Vector2.new(0, 0)

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragOffset = input.Position - window.AbsolutePosition
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                     input.UserInputType == Enum.UserInputType.Touch) then
        local pos = input.Position - dragOffset
        window.Position = UDim2.fromOffset(pos.X, pos.Y)
    end
end)

-- ===== ПОИСК =====
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -24, 0, 32)
searchBox.Position = UDim2.new(0, 12, 0, 44)
searchBox.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
searchBox.PlaceholderText = "🔍 Поиск предмета..."
searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 150)
searchBox.Text = ""
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.ClearTextOnFocus = false
searchBox.Parent = window

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 8)
searchCorner.Parent = searchBox

-- ===== ВКЛАДКИ =====
local tabs = {}
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 30)
tabBar.Position = UDim2.new(0, 12, 0, 84)
tabBar.BackgroundTransparency = 1
tabBar.Parent = window

local tabNames = {
    {"Все", ALL_ITEMS},
    {"Ножи", KNIVES},
    {"Пушки", GUNS},
    {"Древние", ANCIENTS},
}

local currentTab = "Все"
local function CreateTabButton(name, posX)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 68, 0, 28)
    btn.Position = UDim2.new(0, posX, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    btn.Text = name
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.GothamBold
    btn.Parent = tabBar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    btn.MouseButton1Click:Connect(function()
        currentTab = name
        for _, b in pairs(tabs) do
            b.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
            b.TextColor3 = Color3.fromRGB(220, 220, 220)
        end
        btn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        btn.TextColor3 = Color3.fromRGB(20, 20, 30)
        RefreshList()
    end)

    return btn
end

local posX = 0
for i, tabInfo in ipairs(tabNames) do
    tabs[tabInfo[1]] = CreateTabButton(tabInfo[1], posX)
    posX = posX + 72
end

-- ===== СПИСОК ПРЕДМЕТОВ =====
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -24, 0, 240)
listFrame.Position = UDim2.new(0, 12, 0, 122)
listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
listFrame.BorderSizePixel = 0
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 4
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = window

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 8)
listCorner.Parent = listFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

-- ===== СТАТУС =====
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 20)
statusLabel.Position = UDim2.new(0, 12, 0, 370)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Готов"
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = window

-- ===== КНОПКИ ДЕЙСТВИЙ =====
local spawnBtn = Instance.new("TextButton")
spawnBtn.Size = UDim2.new(0.5, -18, 0, 40)
spawnBtn.Position = UDim2.new(0, 12, 0, 398)
spawnBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
spawnBtn.Text = "➕ В инвентарь"
spawnBtn.TextSize = 15
spawnBtn.TextColor3 = Color3.new(1, 1, 1)
spawnBtn.Font = Enum.Font.GothamBold
spawnBtn.Parent = window

local spawnCorner = Instance.new("UICorner")
spawnCorner.CornerRadius = UDim.new(0, 8)
spawnCorner.Parent = spawnBtn

local equipBtn = Instance.new("TextButton")
equipBtn.Size = UDim2.new(0.5, -18, 0, 40)
equipBtn.Position = UDim2.new(0.5, 6, 0, 398)
equipBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
equipBtn.Text = "🔪 В руку"
equipBtn.TextSize = 15
equipBtn.TextColor3 = Color3.new(1, 1, 1)
equipBtn.Font = Enum.Font.GothamBold
equipBtn.Parent = window

local equipCorner = Instance.new("UICorner")
equipCorner.CornerRadius = UDim.new(0, 8)
equipCorner.Parent = equipBtn

-- ===== ВЫБРАННЫЙ ПРЕДМЕТ =====
local selected = nil -- {name, id}

local function SetStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color or Color3.fromRGB(200, 200, 200)
end

-- ===== ОБНОВЛЕНИЕ СПИСКА =====
function RefreshList()
    -- Очистка
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local query = searchBox.Text:lower()
    local items = tabNames[1][2]
    for _, t in ipairs(tabNames) do
        if t[1] == currentTab then
            items = t[2]
            break
        end
    end

    local count = 0
    for _, item in ipairs(items) do
        local name, id = item[1], item[2]
        if query == "" or name:lower():find(query) then
            count = count + 1

            local row = Instance.new("TextButton")
            row.Name = "Item_" .. name
            row.Size = UDim2.new(1, 0, 0, 36)
            row.BackgroundColor3 = Color3.fromRGB(42, 42, 60)
            row.Text = ""
            row.BorderSizePixel = 0
            row.Parent = listFrame

            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 8)
            rowCorner.Parent = row

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.7, -8, 1, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Text = name
            nameLabel.TextSize = 13
            nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = row

            local rarityLabel = Instance.new("TextLabel")
            rarityLabel.Size = UDim2.new(0.3, -8, 1, 0)
            rarityLabel.Position = UDim2.new(0.7, 0, 0, 0)
            rarityLabel.BackgroundTransparency = 1
            rarityLabel.Font = Enum.Font.Gotham
            rarityLabel.Text = id
            rarityLabel.TextSize = 10
            rarityLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
            rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
            rarityLabel.Parent = row

            row.MouseButton1Click:Connect(function()
                selected = {name = name, id = id}
                -- Подсветка выбранного
                for _, child in ipairs(listFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.BackgroundColor3 = Color3.fromRGB(42, 42, 60)
                    end
                end
                row.BackgroundColor3 = Color3.fromRGB(90, 80, 30)
                SetStatus("Выбрано: " .. name .. " [" .. id .. "]", Color3.fromRGB(255, 200, 50))
            end)
        end
    end

    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Gotham
        empty.Text = "Ничего не найдено"
        empty.TextSize = 13
        empty.TextColor3 = Color3.fromRGB(130, 130, 150)
        empty.Parent = listFrame
    end
end

-- ===== ДЕЙСТВИЯ КНОПОК =====
spawnBtn.MouseButton1Click:Connect(function()
    if not selected then
        SetStatus("[!] Сначала выбери предмет из списка", Color3.fromRGB(255, 150, 50))
        return
    end
    SetStatus("Добавляю " .. selected.name .. "...", Color3.fromRGB(255, 200, 50))
    task.wait(0.1)
    local ok = SpawnVisual(selected.name, selected.id)
    if ok then
        SetStatus("✅ " .. selected.name .. " в инвентаре (визуал)", Color3.fromRGB(0, 255, 120))
    else
        SetStatus("⚠ Не удалось вписать в инвентарь, но попробуй 'В руку'", Color3.fromRGB(255, 150, 50))
    end
end)

equipBtn.MouseButton1Click:Connect(function()
    if not selected then
        SetStatus("[!] Сначала выбери предмет из списка", Color3.fromRGB(255, 150, 50))
        return
    end
    SetStatus("Спавню " .. selected.name .. " в руку...", Color3.fromRGB(255, 200, 50))
    task.wait(0.1)
    local ok = SpawnTool(selected.name, selected.id)
    if ok then
        SetStatus("✅ " .. selected.name .. " в руке (визуал)", Color3.fromRGB(0, 255, 120))
    else
        SetStatus("❌ Не удалось создать Tool", Color3.fromRGB(255, 80, 80))
    end
end)

-- Поиск при вводе
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RefreshList()
end)

-- Закрыть
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Свернуть/развернуть
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local target = minimized and UDim2.new(0, 340, 0, 36) or UDim2.new(0, 340, 0, 480)
    TweenSvc:Create(window, TweenInfo.new(0.2), {Size = target}):Play()
    task.wait(0.05)
    searchBox.Visible = not minimized
    tabBar.Visible = not minimized
    listFrame.Visible = not minimized
    statusLabel.Visible = not minimized
    spawnBtn.Visible = not minimized
    equipBtn.Visible = not minimized
end)

-- ===== СТАРТ =====
RefreshList()
SetStatus("✅ Загружено! Выбери предмет и нажми кнопку", Color3.fromRGB(0, 255, 120))

print("=== MM2 Visual Spawner (GUI) ===")
print("Меню открыто. Выбери предмет -> В инвентарь / В руку")
