--[[
  MM2 Dupe Tool — Compact Overlay v3 (фикс drag + поверх окон)
]]

if _G.MM2DupeOverlay then return end
_G.MM2DupeOverlay = true

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

local myItems = {}
local dupeActive = false
local dupeAllActive = false

-- ===== СКАНИРОВАНИЕ ИНВЕНТАРЯ =====
local function ScanInventory()
    local items = {}

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

    if #items == 0 then
        for _, v in ipairs(LP:GetDescendants()) do
            if v:IsA("StringValue") and tonumber(v.Name) and tonumber(v.Name) > 1000000 then
                table.insert(items, {id = v.Name, name = v.Value or v.Name})
            end
        end
    end

    local seen, unique = {}, {}
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

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") and (obj.Name:lower():find("sync") or obj.Name:lower():find("check")) then
            pcall(function() obj:InvokeServer() end)
        end
    end

    return count > 0
end

-- ===== GUI: парентим в CoreGui / gethui() чтобы было ПОВЕРХ ВСЕГО =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2DupeOverlay"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999   -- максимальный слой
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Executor-специфичный парент: gethui() > CoreGui > PlayerGui (fallback)
local okParent = pcall(function()
    if gethui then
        screenGui.Parent = gethui()
    else
        screenGui.Parent = game:GetService("CoreGui")
    end
end)
if not okParent or not screenGui.Parent then
    screenGui.Parent = LP:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 120)
frame.Position = UDim2.new(0, 20, 0.5, -60)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
frame.BorderSizePixel = 0
frame.BackgroundTransparency = 0.06
frame.Active = true
frame.ZIndex = 999999
frame.Parent = screenGui

local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 14)
fCorner.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
header.BorderSizePixel = 0
header.ZIndex = 999999
header.Parent = frame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 14)
hCorner.Parent = header

local hBlocker = Instance.new("Frame")
hBlocker.Size = UDim2.new(1, 0, 0, 8)
hBlocker.Position = UDim2.new(0, 0, 1, -8)
hBlocker.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
hBlocker.BorderSizePixel = 0
hBlocker.ZIndex = 999999
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
title.ZIndex = 999999
title.Parent = header

-- ===== ПЕРЕТАСКИВАНИЕ (ФИКС Vector3 → Vector2) =====
local dragging = false
local dragOffset = Vector2.new(0, 0)

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        -- ФИКС: input.Position это Vector3, конвертируем в Vector2
        dragOffset = Vector2.new(input.Position.X, input.Position.Y) - frame.AbsolutePosition
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
        -- ФИКС: тоже конвертируем в Vector2
        local pos = Vector2.new(input.Position.X, input.Position.Y) - dragOffset
        frame.Position = UDim2.fromOffset(pos.X, pos.Y)
    end
end)

-- ===== СТАТУС =====
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 18)
status.Position = UDim2.new(0, 6, 0, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.Text = "Готов"
status.TextSize = 10
status.TextColor3 = Color3.fromRGB(0, 255, 100)
status.TextXAlignment = Enum.TextXAlignment.Left
status.ZIndex = 999999
status.Parent = frame

local itemCount = Instance.new("TextLabel")
itemCount.Size = UDim2.new(1, -12, 0, 14)
itemCount.Position = UDim2.new(0, 6, 0, 48)
itemCount.BackgroundTransparency = 1
itemCount.Font = Enum.Font.Gotham
itemCount.Text = "Вещей: —"
itemCount.TextSize = 9
itemCount.TextColor3 = Color3.fromRGB(140, 140, 170)
itemCount.TextXAlignment = Enum.TextXAlignment.Left
itemCount.ZIndex = 999999
itemCount.Parent = frame

-- ===== КНОПКИ =====
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
    btn.ZIndex = 999999
    btn.Parent = frame
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 8)
    bCorner.Parent = btn
    return btn
end

local btnW = 88
local margin = 6
local startY = 66

local dupeBtn    = MakeBtn("🔁 Дюпнуть", margin, startY, btnW, Color3.fromRGB(200, 55, 55))
local dupeAllBtn = MakeBtn("🌀 Дюп всё", margin + btnW + 6, startY, btnW, Color3.fromRGB(180, 60, 60))
local scanBtn    = MakeBtn("📋 Инвентарь", margin, startY + 28, 182, Color3.fromRGB(50, 120, 210))

-- ===== ЛОГИКА =====
local function setStatus(text, color)
    status.Text = text
    status.TextColor3 = color or Color3.fromRGB(200, 200, 200)
end

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
print("=== Dupe Tool Compact v3 ===")
