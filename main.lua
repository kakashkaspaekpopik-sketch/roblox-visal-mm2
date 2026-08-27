--[[
  MM2 Dupe Tool — Compact Overlay v2
  Маленькое окно, поверх всего экрана
  Тащи пальцем/мышью за шапку
]]

if _G.MM2DupeOverlay then return end
_G.MM2DupeOverlay = true

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

-- ===== ПЕРЕМЕННЫЕ =====
local myItems = {}
local dupeActive = false
local dupeAllActive = false

-- ===== СКАНИРОВАНИЕ ИНВЕНТАРЯ =====
local function ScanInventory()
    local items = {}

    -- Ищем RemoteFunction инвентаря
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("inv") or n:find("load") or n:find("get") or n:find("item") or n:find("data") then
                local ok, res = pcall(function() return obj:InvokeServer() end)
                if ok and type(res) == "table" then
                    for _, v in ipairs(res) do
                        local id = tostring(v.assetId or v.id or v.Name or "")
                        if id ~= "" then
                            table.insert(items, {id = id, name = tostring(v.name or v.Name or id)})
                        end
                    end
                end
            end
        end
    end

    -- Если пусто — ищем в PlayerData
    if #items == 0 then
        local pd = LP:FindFirstChild("PlayerData") or LP:FindFirstChild("Data")
        if pd then
            local inv = pd:FindFirstChild("Inventory") or pd:FindFirstChild("Items")
            if inv then
                for _, child in ipairs(inv:GetChildren()) do
                    table.insert(items, {id = child.Name, name = child.Value or child.Name})
                end
            end
        end
    end

    -- Если всё ещё пусто — StringValue с ID
    if #items == 0 then
        for _, v in ipairs(LP:GetDescendants()) do
            if v:IsA("StringValue") and tonumber(v.Name) and tonumber(v.Name) > 1000000 then
                table.insert(items, {id = v.Name, name = v.Value or v.Name})
            end
        end
    end

    -- Дедупликация
    local seen = {}
    local unique = {}
    for _, item in ipairs(items) do
        if not seen[item.id] then
            seen[item.id] = true
            table.insert(unique, item)
        end
    end

    return unique
end

-- ===== МЕТОДЫ ДЮПА =====
local function DupeSingle(item)
    local count = 0

    -- Метод 1: хук на сохранение
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("save") or n:find("sync") then
                local old = obj.InvokeServer
                obj.InvokeServer = function(self, ...)
                    local args = {...}
                    if type(args[1]) == "table" then
                        table.insert(args[1], {assetId = item.id, id = item.id, name = item.name})
                        table.insert(args[1], {assetId = item.id, id = item.id, name = item.name})
                    end
                    return old(self, unpack(args))
                end
                count = count + 1
            end
        end
        if obj:IsA("RemoteEvent") and (obj.Name:lower():find("save") or obj.Name:lower():find("update")) then
            local old = obj.FireServer
            obj.FireServer = function(self, ...)
                local args = {...}
                if type(args[1]) == "table" then
                    table.insert(args[1], {assetId = item.id, id = item.id, name = item.name})
                end
                return old(self, unpack(args))
            end
            count = count + 1
        end
    end

    -- Метод 2: спамим трейдовые ремоуты
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("trade") or n:find("add") or n:find("offer") or n:find("accept") then
                pcall(function()
                    if obj:IsA("RemoteEvent") then
                        obj:FireServer({itemId = item.id, action = "add", count = 1})
                        task.wait(0.02)
                        obj:FireServer({itemId = item.id, action = "remove", count = 1})
                    else
                        obj:InvokeServer({itemId = item.id, action = "duplicate"})
                    end
                end)
            end
        end
    end

    -- Метод 3: триггерим синхронизацию
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") and (obj.Name:lower():find("sync") or obj.Name:lower():find("check")) then
            pcall(function() obj:InvokeServer() end)
        end
    end

    return count > 0
end

-- ===== GUI (поверх всего, маленькое) =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2DupeOverlay"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LP:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 120)
frame.Position = UDim2.new(0, 20, 0.5, -60)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
frame.BorderSizePixel = 0
frame.BackgroundTransparency = 0.06
frame.Active = true
frame.Parent = screenGui

local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 14)
fCorner.Parent = frame

-- Тень
local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(1, 4, 1, 4)
shadow.Position = UDim2.new(0, -2, 0, -2)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.5
shadow.ZIndex = -1
shadow.Parent = frame

-- Шапка (за неё таскать)
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
header.BackgroundTransparency = 0
header.BorderSizePixel = 0
header.Parent = frame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 14)
hCorner.Parent = header

local hBlocker = Instance.new("Frame")
hBlocker.Size = UDim2.new(1, 0, 0, 8)
hBlocker.Position = UDim2.new(0, 0, 1, -8)
hBlocker.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
hBlocker.BorderSizePixel = 0
hBlocker.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Dupe Tool"
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(255, 210, 60)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

-- ===== ПЕРЕТАСКИВАНИЕ =====
local dragging = false
local dragOffset = Vector2.new(0, 0)

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragOffset = input.Position - frame.AbsolutePosition
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging then
        local pos = input.Position - dragOffset
        frame.Position = UDim2.fromOffset(pos.X, pos.Y)
    end
end)

-- ===== ПОЛЕ СТАТУСА =====
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 18)
status.Position = UDim2.new(0, 6, 0, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.Text = "Готов"
status.TextSize = 10
status.TextColor3 = Color3.fromRGB(0, 255, 100)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

-- Количество предметов
local itemCount = Instance.new("TextLabel")
itemCount.Size = UDim2.new(1, -12, 0, 14)
itemCount.Position = UDim2.new(0, 6, 0, 48)
itemCount.BackgroundTransparency = 1
itemCount.Font = Enum.Font.Gotham
itemCount.Text = "Вещей: —"
itemCount.TextSize = 9
itemCount.TextColor3 = Color3.fromRGB(140, 140, 170)
itemCount.TextXAlignment = Enum.TextXAlignment.Left
itemCount.Parent = frame

-- ===== КНОПКИ =====
-- Строка 1: Дюпнуть | Дюп всё
-- Строка 2: [Проверить инвентарь]

local function MakeBtn(text, posX, posY, w, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, w, 0, 22)
    btn.Position = UDim2.new(0, posX, 0, posY)
    btn.BackgroundColor3 = color or Color3.fromRGB(200, 60, 60)
    btn.Text = text
    btn.TextSize = 11
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = frame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 8)
    bCorner.Parent = btn

    return btn
end

local btnW = 88
local margin = 6
local startY = 66

local dupeBtn = MakeBtn("🔁 Дюпнуть", margin, startY, btnW, Color3.fromRGB(200, 55, 55))
local dupeAllBtn = MakeBtn("🌀 Дюп всё", margin + btnW + 6, startY, btnW, Color3.fromRGB(180, 60, 60))
local scanBtn = MakeBtn("📋 Инвентарь", margin, startY + 28, 182, Color3.fromRGB(50, 120, 210))

-- ===== ЛОГИКА КНОПОК =====
local function setStatus(text, color)
    status.Text = text
    status.TextColor3 = color or Color3.fromRGB(200, 200, 200)
end

-- Дюпнуть (один предмет — первый в списке)
dupeBtn.MouseButton1Click:Connect(function()
    if dupeActive then
        dupeActive = false
        dupeBtn.Text = "🔁 Дюпнуть"
        dupeBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 55)
        setStatus("⏹ Стоп", Color3.fromRGB(255, 200, 100))
        return
    end

    if #myItems == 0 then
        setStatus("⚠ Скачай инвентарь сначала", Color3.fromRGB(255, 180, 60))
        return
    end

    dupeActive = true
    dupeBtn.Text = "⏹ Стоп"
    dupeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    setStatus("⏳ Дюп: " .. myItems[1].name, Color3.fromRGB(255, 200, 50))

    task.spawn(function()
        DupeSingle(myItems[1])
        dupeActive = false
        dupeBtn.Text = "🔁 Дюпнуть"
        dupeBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 55)
        setStatus("✅ Готово. Перезайди в игру", Color3.fromRGB(0, 255, 100))
    end)
end)

-- Дюпнуть всё
dupeAllBtn.MouseButton1Click:Connect(function()
    if dupeAllActive then
        dupeAllActive = false
        dupeAllBtn.Text = "🌀 Дюп всё"
        dupeAllBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        setStatus("⏹ Стоп", Color3.fromRGB(255, 200, 100))
        return
    end

    if #myItems == 0 then
        setStatus("⚠ Нет вещей для дюпа", Color3.fromRGB(255, 180, 60))
        return
    end

    dupeAllActive = true
    dupeAllBtn.Text = "⏹ Стоп"
    dupeAllBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    setStatus("⏳ Дюп всего...", Color3.fromRGB(255, 200, 50))

    task.spawn(function()
        for i, item in ipairs(myItems) do
            if not dupeAllActive then break end
            setStatus("⏳ " .. i .. "/" .. #myItems .. ": " .. item.name, Color3.fromRGB(255, 200, 50))
            DupeSingle(item)
            task.wait(0.2)
        end
        dupeAllActive = false
        dupeAllBtn.Text = "🌀 Дюп всё"
        dupeAllBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        setStatus("✅ Дюп всего завершён! Перезайди", Color3.fromRGB(0, 255, 100))
    end)
end)

-- Проверить инвентарь
scanBtn.MouseButton1Click:Connect(function()
    setStatus("⏳ Сканирую...", Color3.fromRGB(255, 200, 50))
    task.spawn(function()
        local ok, items = pcall(ScanInventory)
        if ok and items then
            myItems = items
            itemCount.Text = "Вещей: " .. #myItems
            setStatus("✅ Найдено: " .. #myItems, Color3.fromRGB(0, 255, 100))
        else
            setStatus("❌ Ошибка сканирования", Color3.fromRGB(255, 80, 80))
        end
    end)
end)

-- ===== СТАРТ =====
task.wait(1)
setStatus("✅ Загружен. Жми 📋", Color3.fromRGB(0, 255, 100))
print("=== Dupe Tool Compact ===")
print("Жми 'Инвентарь' чтобы просканировать свои вещи")
