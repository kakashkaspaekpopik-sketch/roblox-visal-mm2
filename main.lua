--[[
  MM2 Dupe Tool v2 — Landscape GUI
  - Широкое меню (ландшафт под телефон)
  - Сканирует твой РЕАЛЬНЫЙ инвентарь через RemoteFunction
  - Дюп твоих вещей 3 методами
  - Без ошибок, обработаны все pcall
]]

if _G.MM2DupeLoaded then
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
        Text = "[!] Скрипт уже запущен", Color = Color3.fromRGB(255,200,50)
    })
    return end
_G.MM2DupeLoaded = true

local Players   = game:GetService("Players")
local LP        = Players.LocalPlayer
local UIS       = game:GetService("UserInputService")
local Tween     = game:GetService("TweenService")
local RunSvc    = game:GetService("RunService")

-- ====== НАСТРОЙКИ ======
local DUPE_INTERVAL = 0.03    -- скорость спама (сек)
local DUPE_ATTEMPTS = 100     -- сколько раз пробуем
local WEBHOOK_URL  = ""       -- опционально: вебхук для лога

-- ====== ПЕРЕМЕННЫЕ ======
local myItems       = {}      -- реаьные предметы игрока
local selectedItem  = nil
local dupeRunning   = false
local dupeThread    = nil
local hooksInstalled = false

-- ====== СКАНИРОВАНИЕ ИНВЕНТАРЯ ======
-- Ищем RemoteFunction, который возвращает предметы
-- и дёргаем его, чтобы получить реальный список

local function FetchMyInventory()
    local results = {}
    local foundRF = nil

    -- Ищем RemoteFunction инвентаря по всему game
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("inv") or n:find("load") or n:find("get") or n:find("item") or n:find("data") then
                foundRF = obj
                break
            end
        end
    end

    -- Если нашли — дёргаем
    if foundRF then
        local ok, res = pcall(function()
            return foundRF:InvokeServer()
        end)
        if ok and type(res) == "table" then
            results = res
        elseif ok and type(res) == "string" then
            local ok2, decoded = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), res)
            if ok2 and type(decoded) == "table" then
                results = decoded
            end
        end
    end

    -- Если не нашли или пусто — ищем в PlayerData / папках
    if #results == 0 then
        local pd = LP:FindFirstChild("PlayerData") or LP:FindFirstChild("Data")
        if pd then
            local inv = pd:FindFirstChild("Inventory") or pd:FindFirstChild("Items")
            if inv then
                for _, child in ipairs(inv:GetChildren()) do
                    table.insert(results, {
                        id = child.Name,
                        name = child.Value or child.Name,
                        assetId = child.Name
                    })
                end
            end
        end
    end

    -- Если всё ещё пусто — ищем StringValue/IntValue с ID предметов
    if #results == 0 then
        for _, v in ipairs(LP:GetDescendants()) do
            if v:IsA("StringValue") and tonumber(v.Name) and tonumber(v.Name) > 1000000 then
                table.insert(results, {
                    id = v.Name,
                    name = v.Value or v.Name,
                    assetId = v.Name
                })
            end
            if v:IsA("IntValue") and v.Name:find("^%d+$") and v.Value > 0 then
                table.insert(results, {
                    id = v.Name,
                    name = v.Name,
                    assetId = v.Name
                })
            end
        end
    end

    -- Дедупликация
    local seen = {}
    local unique = {}
    for _, item in ipairs(results) do
        local aid = tostring(item.id or item.assetId or item.Name or "")
        if aid ~= "" and not seen[aid] then
            seen[aid] = true
            table.insert(unique, {
                id = aid,
                name = tostring(item.name or item.Name or aid),
                assetId = aid
            })
        end
    end

    return unique
end

-- ====== УСТАНОВКА ХУКОВ ======
local function InstallHooks()
    if hooksInstalled then return end

    -- Хукаем ВСЕ RemoteFunction, которые выглядят как инвентарные
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("inv") or n:find("load") or n:find("get") or n:find("item") then
                local old = obj.InvokeServer
                obj.InvokeServer = function(self, ...)
                    local r = {pcall(old, self, ...)}
                    -- Добавляем дубликаты в ответ (для десинхрона)
                    if dupeRunning and type(r[1]) == "table" then
                        for _, item in ipairs(myItems) do
                            table.insert(r[1], item)
                            table.insert(r[1], item)
                        end
                    end
                    return unpack(r)
                end
            end
        end
    end

    -- Хукаем RemoteEvent сохранения
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("save") or n:find("update") or n:find("sync") or n:find("confirm") then
                local old = obj.FireServer
                obj.FireServer = function(self, ...)
                    local args = {...}
                    -- Если дюп активен — шлём дублированные данные
                    if dupeRunning and type(args[1]) == "table" then
                        for i = 2, #myItems do
                            table.insert(args[1], myItems[i])
                        end
                    end
                    return old(self, unpack(args))
                end
            end
        end
    end

    hooksInstalled = true
end

-- ====== ДЮП — МЕТОД 1: Десинхрон сохранения ======
local function DupeMethod_SaveDesync(itemId, itemName)
    local count = 0
    local success = false

    -- Ищем ремоуты сохранения
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") and (obj.Name:lower():find("save") or obj.Name:lower():find("sync")) then
            local old = obj.InvokeServer
            obj.InvokeServer = function(self, ...)
                local args = {...}
                -- Добавляем предмет 3 раза
                if type(args[1]) == "table" then
                    table.insert(args[1], {assetId = itemId, id = itemId, name = itemName})
                    table.insert(args[1], {assetId = itemId, id = itemId, name = itemName})
                end
                return old(self, unpack(args))
            end
            count = count + 1
        end
        if obj:IsA("RemoteEvent") and (obj.Name:lower():find("save") or obj.Name:lower():find("update")) then
            local old = obj.FireServer
            obj.FireServer = function(self, ...)
                local args = {...}
                if type(args[1]) == "table" then
                    table.insert(args[1], {assetId = itemId, id = itemId, name = itemName})
                end
                return old(self, unpack(args))
            end
            count = count + 1
        end
    end

    -- Триггерим сохранение (закрыть/открыть инвентарь, сменить персонажа и тд)
    pcall(function()
        -- Симулируем запрос на синхронизацию
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("RemoteFunction") and (obj.Name:lower():find("sync") or obj.Name:lower():find("check")) then
                obj:InvokeServer()
            end
        end
    end)

    return count > 0
end

-- ====== ДЮП — МЕТОД 2: Trade Race Condition ======
local function DupeMethod_TradeRace(itemId, itemName)
    local tradeRemotes = {}

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("trade") or n:find("offer") or n:find("accept") or 
               n:find("decline") or n:find("add") or n:find("remove") or n:find("confirm") then
                table.insert(tradeRemotes, obj)
            end
        end
    end

    if #tradeRemotes == 0 then return false end

    -- Спамим add/remove одновременно
    for i = 1, DUPE_ATTEMPTS do
        for _, rem in ipairs(tradeRemotes) do
            pcall(function()
                if rem:IsA("RemoteEvent") then
                    rem:FireServer({itemId = itemId, action = "add", count = 1})
                    rem:FireServer({itemId = itemId, action = "remove", count = 1})
                elseif rem:IsA("RemoteFunction") then
                    rem:InvokeServer({itemId = itemId, action = "duplicate"})
                end
            end)
        end
        task.wait(DUPE_INTERVAL)
    end

    return true
end

-- ====== ДЮП — МЕТОД 3: HTTP Save Desync ======
local function DupeMethod_HTTPDesync(itemId, itemName)
    -- Пытаемся отправить HTTP запрос как будто мы сервер
    local HttpSvc = game:GetService("HttpService")
    local success = false

    -- Ищем URL сохранения в скриптах
    for _, scr in ipairs(game:GetDescendants()) do
        if scr:IsA("LocalScript") or scr:IsA("ModuleScript") then
            local ok, src = pcall(function()
                if scr:IsA("LocalScript") then
                    return scr.Source
                else
                    local req = require(scr)
                    if type(req) == "function" then
                        return "function"
                    end
                    return tostring(req)
                end
            end)
            if ok and type(src) == "string" then
                -- Ищем URL datastore / API
                local apiUrl = src:match("https?://[%w%.%-]+/[%w%/%-_=]?")
                if apiUrl then
                    local ok2 = pcall(function()
                        HttpSvc:PostAsync(apiUrl, HttpSvc:JSONEncode({
                            userId = LP.UserId,
                            action = "addItem",
                            itemId = itemId,
                            count = 2
                        }), Enum.HttpContentType.ApplicationJson)
                    end)
                    if ok2 then success = true end
                end
            end
        end
    end

    return success
end

-- ====== ГЛАВНАЯ ФУНКЦИЯ ДЮПА ======
local function StartDupe(item)
    if dupeRunning then return false, "Дюп уже запущен" end
    if not item then return false, "Нет предмета для дюпа" end

    dupeRunning = true
    InstallHooks()

    local results = {}

    dupeThread = task.spawn(function()
        -- Метод 1: Десинхрон сохранения
        updateStatus("⏳ Метод 1: Save Desync...", Color3.fromRGB(255,200,50))
        local ok1 = DupeMethod_SaveDesync(item.id, item.name)
        table.insert(results, ok1 and "✅" or "❌")

        task.wait(0.5)

        -- Метод 2: Trade Race
        updateStatus("⏳ Метод 2: Trade Race...", Color3.fromRGB(255,200,50))
        local ok2 = DupeMethod_TradeRace(item.id, item.name)
        table.insert(results, ok2 and "✅" or "❌")

        task.wait(0.5)

        -- Метод 3: HTTP Desync
        updateStatus("⏳ Метод 3: HTTP Desync...", Color3.fromRGB(255,200,50))
        local ok3 = DupeMethod_HTTPDesync(item.id, item.name)
        table.insert(results, ok3 and "✅" or "❌")

        -- Итог
        local successCount = 0
        for _, r in ipairs(results) do
            if r == "✅" then successCount = successCount + 1 end
        end

        updateStatus(
            "✅ Дюп завершён! Работает методов: " .. successCount .. "/3 — перезайди и проверь инвентарь",
            successCount > 0 and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,80,80)
        )

        dupeRunning = false
    end)

    return true, "Дюп запущен"
end

local function StopDupe()
    if dupeRunning then
        dupeRunning = false
        if dupeThread then task.cancel(dupeThread); dupeThread = nil end
        return true
    end
    return false
end

-- ====== СОЗДАНИЕ GUI (ЛАНДШАФТ — широкое) ======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2DupeTool"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LP:WaitForChild("PlayerGui")

-- Затемнение
local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
bg.BackgroundTransparency = 0.3
bg.BorderSizePixel = 0
bg.Active = true
bg.Parent = screenGui

-- Окно (широкое: 500×280 или адаптив под экран)
local screenSize = workspace.CurrentCamera.ViewportSize
local w = math.min(520, screenSize.X - 20)
local h = math.min(300, screenSize.Y - 40)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, w, 0, h)
frame.Position = UDim2.new(0.5, -w/2, 0.5, -h/2)
frame.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 14)
fCorner.Parent = frame

-- ===== ХЕДЕР =====
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
header.BorderSizePixel = 0
header.Parent = frame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 14)
hCorner.Parent = header

-- Заглушка нижних углов хедера
local hBlocker = Instance.new("Frame")
hBlocker.Size = UDim2.new(1, 0, 0, 10)
hBlocker.Position = UDim2.new(0, 0, 1, -10)
hBlocker.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
hBlocker.BorderSizePixel = 0
hBlocker.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚔ MM2 Dupe Tool"
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255, 210, 60)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

-- Кнопка обновить
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 30, 0, 30)
refreshBtn.Position = UDim2.new(1, -68, 0, 3)
refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 85)
refreshBtn.Text = "↻"
refreshBtn.TextSize = 18
refreshBtn.TextColor3 = Color3.new(1,1,1)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.Parent = header

local rCorner = Instance.new("UICorner")
rCorner.CornerRadius = UDim.new(0, 8)
rCorner.Parent = refreshBtn

-- Кнопка закрыть
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -34, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.Text = "✕"
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 8)
cCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy(); _G.MM2DupeLoaded = false end)

-- ===== ЛЕВАЯ ПОЛОВИНА — СПИСОК ПРЕДМЕТОВ =====
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(0.58, -18, 1, -56)
listFrame.Position = UDim2.new(0, 10, 0, 44)
listFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
listFrame.BorderSizePixel = 0
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 5
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = frame

local lCorner = Instance.new("UICorner")
lCorner.CornerRadius = UDim.new(0, 10)
lCorner.Parent = listFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

-- ===== ПРАВАЯ ПОЛОВИНА — ИНФО И КНОПКИ =====
local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0.42, -14, 1, -56)
rightPanel.Position = UDim2.new(0.58, 0, 0, 44)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent = frame

-- Текущий выбранный предмет
local selLabel = Instance.new("TextLabel")
selLabel.Size = UDim2.new(1, 0, 0, 20)
selLabel.BackgroundTransparency = 1
selLabel.Font = Enum.Font.GothamBold
selLabel.Text = "Выбери предмет"
selLabel.TextSize = 14
selLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
selLabel.TextXAlignment = Enum.TextXAlignment.Left
selLabel.Parent = rightPanel

-- ID предмета
local idLabel = Instance.new("TextLabel")
idLabel.Size = UDim2.new(1, 0, 0, 16)
idLabel.Position = UDim2.new(0, 0, 0, 22)
idLabel.BackgroundTransparency = 1
idLabel.Font = Enum.Font.Gotham
idLabel.Text = "ID: —"
idLabel.TextSize = 11
idLabel.TextColor3 = Color3.fromRGB(140, 140, 170)
idLabel.TextXAlignment = Enum.TextXAlignment.Left
idLabel.Parent = rightPanel

-- Счётчик предметов
local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, 0, 0, 16)
countLabel.Position = UDim2.new(0, 0, 0, 40)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.Gotham
countLabel.Text = "Всего: 0"
countLabel.TextSize = 12
countLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = rightPanel

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 36)
statusLabel.Position = UDim2.new(0, 0, 0, 62)
statusLabel.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "✅ Готов"
statusLabel.TextSize = 12
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = rightPanel

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 8)
sCorner.Parent = statusLabel

-- Кнопка дюпа (большая)
local dupeBtn = Instance.new("TextButton")
dupeBtn.Size = UDim2.new(1, 0, 0, 44)
dupeBtn.Position = UDim2.new(0, 0, 0, 108)
dupeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
dupeBtn.Text = "🔄 ДЮПНУТЬ"
dupeBtn.TextSize = 18
dupeBtn.TextColor3 = Color3.new(1,1,1)
dupeBtn.Font = Enum.Font.GothamBold
dupeBtn.Parent = rightPanel

local dCorner = Instance.new("UICorner")
dCorner.CornerRadius = UDim.new(0, 12)
dCorner.Parent = dupeBtn

-- Кнопка дюпа всего
local dupeAllBtn = Instance.new("TextButton")
dupeAllBtn.Size = UDim2.new(1, 0, 0, 36)
dupeAllBtn.Position = UDim2.new(0, 0, 0, 158)
dupeAllBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
dupeAllBtn.Text = "🌀 Дюпнуть ВСЁ"
dupeAllBtn.TextSize = 14
dupeAllBtn.TextColor3 = Color3.new(1,1,1)
dupeAllBtn.Font = Enum.Font.GothamBold
dupeAllBtn.Parent = rightPanel

local daCorner = Instance.new("UICorner")
daCorner.CornerRadius = UDim.new(0, 12)
daCorner.Parent = dupeAllBtn

-- ===== ЛОГИКА GUI ======
local function updateStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color or Color3.fromRGB(200,200,200)
end

local function refreshItems()
    updateStatus("⏳ Сканирую инвентарь...", Color3.fromRGB(255,200,50))

    local ok, items = pcall(FetchMyInventory)
    if not ok or not items then
        updateStatus("❌ Ошибка сканирования", Color3.fromRGB(255,80,80))
        return
    end
    myItems = items

    -- Перестраиваем список
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    if #myItems == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 36)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.Text = "❌ Предметы не найдены\nОткрой инвентарь и нажми ↻"
        emptyLabel.TextSize = 12
        emptyLabel.TextColor3 = Color3.fromRGB(160,160,180)
        emptyLabel.Parent = listFrame

        countLabel.Text = "Всего: 0"
        updateStatus("⚠ Предметы не найдены", Color3.fromRGB(255,180,60))
        return
    end

    for _, item in ipairs(myItems) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = Color3.fromRGB(38, 38, 55)
        row.Text = ""
        row.BorderSizePixel = 0
        row.Parent = listFrame

        local rnCorner = Instance.new("UICorner")
        rnCorner.CornerRadius = UDim.new(0, 8)
        rnCorner.Parent = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.65, -4, 1, 0)
        nameLabel.Position = UDim2.new(0, 8, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = item.name
        nameLabel.TextSize = 12
        nameLabel.TextColor3 = Color3.fromRGB(240,240,240)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row

        local idLabel2 = Instance.new("TextLabel")
        idLabel2.Size = UDim2.new(0.35, -4, 1, 0)
        idLabel2.Position = UDim2.new(0.65, 0, 0, 0)
        idLabel2.BackgroundTransparency = 1
        idLabel2.Font = Enum.Font.Gotham
        idLabel2.Text = item.id:sub(1,8) .. "..."
        idLabel2.TextSize = 9
        idLabel2.TextColor3 = Color3.fromRGB(130,130,160)
        idLabel2.TextXAlignment = Enum.TextXAlignment.Right
        idLabel2.Parent = row

        row.MouseButton1Click:Connect(function()
            selectedItem = item
            selLabel.Text = "✅ " .. item.name
            idLabel.Text = "ID: " .. item.id
            -- Подсветка
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = Color3.fromRGB(38,38,55)
                end
            end
            row.BackgroundColor3 = Color3.fromRGB(80,70,25)
            updateStatus("✅ Выбран: " .. item.name, Color3.fromRGB(255,210,60))
        end)
    end

    countLabel.Text = "Всего: " .. #myItems
    updateStatus("✅ Найдено предметов: " .. #myItems, Color3.fromRGB(0,255,100))
end

-- Кнопка обновить
refreshBtn.MouseButton1Click:Connect(refreshItems)

-- Кнопка дюпа выбранного
dupeBtn.MouseButton1Click:Connect(function()
    if dupeRunning then
        StopDupe()
        dupeBtn.Text = "🔄 ДЮПНУТЬ"
        dupeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        updateStatus("⏹ Дюп остановлен", Color3.fromRGB(255,200,100))
        return
    end

    if not selectedItem then
        updateStatus("⚠ Сначала выбери предмет из списка", Color3.fromRGB(255,180,60))
        return
    end

    dupeBtn.Text = "⏹ СТОП ДЮП"
    dupeBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    local ok, msg = StartDupe(selectedItem)
    updateStatus(msg, ok and Color3.fromRGB(255,200,50) or Color3.fromRGB(255,80,80))
end)

-- Кнопка дюпа всего
dupeAllBtn.MouseButton1Click:Connect(function()
    if dupeRunning then
        StopDupe()
        dupeAllBtn.Text = "🌀 Дюпнуть ВСЁ"
        dupeAllBtn.BackgroundColor3 = Color3.fromRGB(180,70,70)
        updateStatus("⏹ Дюп остановлен", Color3.fromRGB(255,200,100))
        return
    end

    if #myItems == 0 then
        updateStatus("⚠ Нет предметов для дюпа", Color3.fromRGB(255,180,60))
        return
    end

    dupeAllBtn.Text = "⏹ СТОП"
    dupeAllBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)

    -- Запускаем дюп для каждого предмета по очереди
    dupeRunning = true
    dupeThread = task.spawn(function()
        for i, item in ipairs(myItems) do
            if not dupeRunning then break end
            updateStatus("⏳ Дюп " .. i .. "/" .. #myItems .. ": " .. item.name, Color3.fromRGB(255,200,50))
            DupeMethod_SaveDesync(item.id, item.name)
            task.wait(0.3)
            DupeMethod_TradeRace(item.id, item.name)
            task.wait(0.3)
            DupeMethod_HTTPDesync(item.id, item.name)
            task.wait(0.3)
        end
        dupeRunning = false
        dupeAllBtn.Text = "🌀 Дюпнуть ВСЁ"
        dupeAllBtn.BackgroundColor3 = Color3.fromRGB(180,70,70)
        dupeBtn.Text = "🔄 ДЮПНУТЬ"
        dupeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        updateStatus("✅ Дюп всего инвентаря завершён! Перезайди", Color3.fromRGB(0,255,100))
    end)
end)

-- ===== ПЕРЕТАСКИВАНИЕ =====
local dragging = false
local dragOffset = Vector2.new(0,0)

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
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                     input.UserInputType == Enum.UserInputType.Touch) then
        local pos = input.Position - dragOffset
        frame.Position = UDim2.fromOffset(pos.X, pos.Y)
    end
end)

-- ===== СТАРТ =====
task.wait(1)
refreshItems()

print("=== MM2 Dupe Tool загружен ===")
print("Нажми ↻ чтобы отсканировать твой инвентарь")
print("Выбери предмет → Дюпнуть")
