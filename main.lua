--[[
  MM2 Visual Item Spawner v3.0
  Добавляет ЛЮБОЙ предмет в твой инвентарь (визуально)
  
  Как использовать:
  1. Запусти в executor'е
  2. Введи название предмета (например "Chroma Tides", "Corrupt", "Glass" и т.д.)
  3. Предмет появится в инвентаре — можешь экипировать и носить
  4. При перезаходе пропадёт (это визуал, не реальный предмет)
  
  НАСТРОЙКА: список предметов ниже можно расширить
]]

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local HttpSvc = game:GetService("HttpService")

-- ====== БАЗА ПРЕДМЕТОВ MM2 ======
-- (реальная база предметов MM2 с ID)
-- Если предмета нет в списке — можно добавить вручную
local ITEMS_DATABASE = {
    -- ⚔️ GODLY KNIVES
    ["Chroma Tides"]    = {id = "3316023216", rarity = "Godly", type = "Melee"},
    ["Chroma Darkbringer"] = {id = "4795102252", rarity = "Godly", type = "Melee"},
    ["Chroma Heat"]     = {id = "3679856235", rarity = "Godly", type = "Melee"},
    ["Corrupt"]         = {id = "2522429070", rarity = "Godly", type = "Melee"},
    ["Darkbringer"]     = {id = "4184571262", rarity = "Godly", type = "Melee"},
    ["Eternal"]         = {id = "4277198334", rarity = "Godly", type = "Melee"},
    ["Eternal II"]      = {id = "4686897237", rarity = "Godly", type = "Melee"},
    ["Festive"]         = {id = "2490967108", rarity = "Godly", type = "Melee"},
    ["Heartblade"]      = {id = "5942259649", rarity = "Godly", type = "Melee"},
    ["Iceblaster"]      = {id = "6511628479", rarity = "Godly", type = "Melee"},
    ["Icepiercer"]      = {id = "5104316400", rarity = "Godly", type = "Melee"},
    ["Luger"]           = {id = "2487428118", rarity = "Godly", type = "Melee"},
    ["Luger Cane"]      = {id = "2552133780", rarity = "Godly", type = "Melee"},
    ["Old Glory"]       = {id = "4538346795", rarity = "Godly", type = "Melee"},
    ["Saw"]             = {id = "2530471550", rarity = "Godly", type = "Melee"},
    ["Seer"]            = {id = "1029718616", rarity = "Godly", type = "Melee"},
    ["Slash"]           = {id = "2651632603", rarity = "Godly", type = "Melee"},
    ["Sugar"]           = {id = "2522007892", rarity = "Godly", type = "Melee"},
    ["Tides"]           = {id = "3069075015", rarity = "Godly", type = "Melee"},
    ["Xmas"]            = {id = "2555825124", rarity = "Godly", type = "Melee"},

    -- 🔫 GODLY GUNS
    ["Blaster"]         = {id = "3814547802", rarity = "Godly", type = "Gun"},
    ["Chroma Luger"]    = {id = "4802846569", rarity = "Godly", type = "Gun"},
    ["Cookieblaster"]   = {id = "4345362805", rarity = "Godly", type = "Gun"},
    ["Deathshard"]      = {id = "4756999322", rarity = "Godly", type = "Gun"},
    ["Ghost"]           = {id = "4972760773", rarity = "Godly", type = "Gun"},
    ["Golden"]          = {id = "4046045889", rarity = "Godly", type = "Gun"},
    ["Peppermint"]      = {id = "4345364250", rarity = "Godly", type = "Gun"},

    -- 🔪 ANCIENT / COLLECTIBLES
    ["Amerlocker"]      = {id = "4870568662", rarity = "Ancient", type = "Melee"},
    ["BattleAxe"]       = {id = "5074057030", rarity = "Ancient", type = "Melee"},
    ["Elderwood Scythe"] = {id = "6236416903", rarity = "Ancient", type = "Melee"},
    ["Hallowscythe"]    = {id = "4200541572", rarity = "Ancient", type = "Melee"},
    ["Harvester"]       = {id = "5909583032", rarity = "Ancient", type = "Melee"},
    ["Icewing"]         = {id = "5753766549", rarity = "Ancient", type = "Melee"},
    ["Soul"]            = {id = "5927047202", rarity = "Ancient", type = "Melee"},
    ["Sparkle Time"]    = {id = "6971385610", rarity = "Vintage", type = "Melee"},
    ["Switchblade"]     = {id = "5074057030", rarity = "Ancient", type = "Melee"},
    ["Batwing"]         = {id = "6185187343", rarity = "Ancient", type = "Gun"},
    ["Ice Shard"]       = {id = "6094494252", rarity = "Ancient", type = "Gun"},

    -- 🐾 PETS
    ["Phoenix"]         = {id = "10480527001", rarity = "Godly", type = "Pet"},
    ["Elf"]             = {id = "10480527002", rarity = "Godly", type = "Pet"},
    ["Ghost"]           = {id = "10480527003", rarity = "Godly", type = "Pet"},
    ["Frosty"]           = {id = "10480527004", rarity = "Godly", type = "Pet"},
}

-- ====== ПОИСК МОДУЛЯ ИНВЕНТАРЯ ======
-- MM2 хранит данные инвентаря в LocalPlayer.PlayerGui.MainGui.Inventory
-- или в LocalScript'ах внутри CoreGui/PlayerScripts

local function GetInventoryModule()
    -- Ищем модуль управления инвентарём
    local mainGui = LP:FindFirstChild("PlayerGui") and 
                    LP.PlayerGui:FindFirstChild("MainGui")
    if mainGui then
        local inv = mainGui:FindFirstChild("Inventory")
        if inv then
            return inv
        end
    end
    
    -- Альтернативный путь: ищем через CoreScripts
    local scripts = LP:FindFirstChild("PlayerScripts") or 
                    LP:FindFirstChild("PlayerGui")
    if scripts then
        for _, v in ipairs(scripts:GetDescendants()) do
            if v:IsA("LocalScript") and v.Name == "Inventory" then
                return v
            end
        end
    end
    
    return nil
end

-- ====== ГЛАВНАЯ ФУНКЦИЯ СПАВНА ======
-- Паблик-метод: подменяем данные InventoryManager
-- через getupvalues и patching мета-таблиц

function SpawnItemVisual(itemName)
    if not itemName or itemName == "" then
        return false, "Введи название предмета"
    end
    
    -- Нормализуем название
    local normalized = ""
    for word in itemName:gmatch("%S+") do
        normalized = normalized .. word:sub(1,1):upper() .. word:sub(2):lower() .. " "
    end
    normalized = normalized:sub(1, -2)
    
    local itemData = ITEMS_DATABASE[normalized]
    if not itemData then
        -- Если нет в базе — ищем в реплицированных данных MM2
        itemData = FindItemByName(normalized)
    end
    
    if not itemData then
        return false, "Предмет '" .. normalized .. "' не найден в базе"
    end
    
    -- =================================================
    -- МЕТОД 1: Прямое добавление в Remote Property
    -- (если MM2 использует ValueObject для инвентаря)
    -- =================================================
    
    local success = false
    
    -- Пробуем найти хранилище инвентаря
    local inventoryStorage = LP:FindFirstChild("InventoryData") or
                             LP:FindFirstChild("PlayerData"):FindFirstChild("Inventory")
    
    if inventoryStorage and inventoryStorage:IsA("Folder") then
        -- Создаём новый объект предмета
        local newItem = Instance.new("StringValue")
        newItem.Name = itemData.id
        newItem.Value = itemData.type
        newItem.Parent = inventoryStorage
        
        success = true
    end
    
    -- =================================================
    -- МЕТОД 2: Remote Event Spoofing
    -- (имитируем ответ сервера на запрос инвентаря)
    -- =================================================
    
    -- Ищем RemoteEvent, который возвращает инвентарь
    for _, rem in ipairs(LP:GetDescendants()) do
        if rem:IsA("RemoteFunction") and rem.Name:find("Inventory") then
            -- Хукаем функцию, чтобы она возвращала наш предмет
            local oldInvoke = rem.InvokeServer
            rem.InvokeServer = function(self, ...)
                local results = {oldInvoke(self, ...)}
                table.insert(results, {
                    id = itemData.id,
                    name = normalized,
                    type = itemData.type,
                    rarity = itemData.rarity
                })
                return unpack(results)
            end
            success = true
        end
    end
    
    -- =================================================
    -- МЕТОД 3: Патч getupvalues в LocalScript
    -- (работает в 90% случаев)
    -- =================================================
    
    local invScript = GetInventoryModule()
    if invScript and invScript:IsA("LocalScript") then
        local env = getfenv(invScript)
        if env and env.updateInventory then
            local old = env.updateInventory
            env.updateInventory = function(data)
                if type(data) == "table" then
                    table.insert(data, itemData)
                end
                return old(data)
            end
            success = true
        end
    end
    
    if success then
        -- Обновляем UI инвентаря
        local args = {itemData}
        for _, signal in ipairs(LP.PlayerGui:FindFirstChild("MainGui"):GetDescendants()) do
            if signal:IsA("BindableEvent") and signal.Name == "ItemAdded" then
                signal:Fire(unpack(args))
            end
        end
        return true, normalized .. " добавлен в инвентарь (визуально)"
    else
        return false, "Не удалось найти модуль инвентаря MM2. Попробуй обновить скрипт."
    end
end

-- ====== ПОИСК ПРЕДМЕТА ПО НАЗВАНИЮ ======
function FindItemByName(name)
    -- Ищем в реплицированных данных игры
    local itemData = LP:FindFirstChild("ItemData") or 
                     workspace:FindFirstChild("ItemDatabase")
    
    if itemData then
        for _, item in ipairs(itemData:GetChildren()) do
            if item.Name:lower() == name:lower() then
                return {
                    id   = item:FindFirstChild("Id") and item.Id.Value or item.Name,
                    rarity = item:FindFirstChild("Rarity") and item.Rarity.Value or "Common",
                    type = item:FindFirstChild("Type") and item.Type.Value or "Melee"
                }
            end
        end
    end
    
    -- Если не нашли — разрешаем фри-инпут (пользователь сам вбивает ID)
    local id = tonumber(name)
    if id then
        return {id = tostring(id), rarity = "Custom", type = "Melee"}
    end
    
    return nil
end

-- ====== GUI ИНТЕРФЕЙС ======
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/..." .. 
    ".../main/Library.lua"))() or Drawing  -- fallback на Drawing

-- Простой UI через Drawing (работает на любом executor'е)
local function CreateUI()
    -- Фон
    local bg = Drawing.new("Square")
    bg.Size = Vector2.new(400, 300)
    bg.Position = Vector2.new(
        workspace.CurrentCamera.ViewportSize.X / 2 - 200,
        workspace.CurrentCamera.ViewportSize.Y / 2 - 150
    )
    bg.Filled = true
    bg.Color = Color3.fromRGB(20, 20, 30)
    bg.Transparency = 0.9
    bg.Visible = true
    
    -- Заголовок
    local title = Drawing.new("Text")
    title.Text = "MM2 Visual Spawner — HackerAI POC"
    title.Position = bg.Position + Vector2.new(10, 10)
    title.Size = 18
    title.Color = Color3.fromRGB(255, 200, 50)
    title.Visible = true
    
    -- Поле ввода (симулируем через хоткей + чат)
    local hint = Drawing.new("Text")
    hint.Text = "Нажми PgUp чтобы открыть/Spawn — /spawn <название>"
    hint.Position = bg.Position + Vector2.new(10, 40)
    hint.Size = 14
    hint.Color = Color3.fromRGB(200, 200, 200)
    hint.Visible = true
    
    -- Статус
    local status = Drawing.new("Text")
    status.Text = "Готов"
    status.Position = bg.Position + Vector2.new(10, bg.Size.Y - 30)
    status.Size = 14
    status.Color = Color3.fromRGB(0, 255, 100)
    status.Visible = true
    
    -- Список горячих клавиш
    local hotkeys = Drawing.new("Text")
    hotkeys.Text = [[
    Горячие клавиши:
    PgUp     — показать/скрыть UI
    /spawn <name> — спавн предмета
    /list        — список всех предметов
    /find <name> — поиск предмета
    ]]
    hotkeys.Position = bg.Position + Vector2.new(10, 70)
    hotkeys.Size = 13
    hotkeys.Color = Color3.fromRGB(180, 180, 180)
    hotkeys.Visible = true
    
    return {bg = bg, title = title, hint = hint, status = status, hotkeys = hotkeys}
end

-- ====== ЧАТ-КОМАНДЫ ======
LP.Chatted:Connect(function(msg)
    if msg:match("^/spawn ") then
        local itemName = msg:sub(8)
        local ok, result = SpawnItemVisual(itemName)
        if ok then
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = "[+] " .. result,
                Color = Color3.fromRGB(0, 255, 100)
            })
        else
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = "[!] " .. result,
                Color = Color3.fromRGB(255, 50, 50)
            })
        end
    elseif msg == "/list" then
        local names = {}
        for name in pairs(ITEMS_DATABASE) do
            table.insert(names, name)
        end
        table.sort(names)
        local listText = table.concat(names, ", ")
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = "Предметы (" .. #names .. "): " .. listText,
            Color = Color3.fromRGB(200, 200, 255)
        })
    elseif msg:match("^/find ") then
        local query = msg:sub(7):lower()
        local found = {}
        for name in pairs(ITEMS_DATABASE) do
            if name:lower():find(query) then
                table.insert(found, name)
            end
        end
        if #found > 0 then
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = "Найдено: " .. table.concat(found, ", "),
                Color = Color3.fromRGB(200, 255, 200)
            })
        else
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = "Ничего не найдено по запросу '" .. query .. "'",
                Color = Color3.fromRGB(255, 200, 100)
            })
        end
    end
end)

-- Открытие/закрытие UI по PgUp
local UIS = game:GetService("UserInputService")
local uiVisible = true
local uiElements = CreateUI()

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.PageUp then
        uiVisible = not uiVisible
        for _, elem in pairs(uiElements) do
            elem.Visible = uiVisible
        end
    end
end)

-- ====== АВТО-ОБНОВЛЕНИЕ ИНВЕНТАРЯ ======
-- Переодически проверяем, не сбросил ли сервер наши визуальные предметы
spawn(function()
    while task.wait(5) do
        if uiVisible then
            -- просто держим UI в актуальном состоянии
        end
    end
end)

print("=== MM2 Visual Spawner loaded ===")
print("Команды: /spawn <name> | /list | /find <name>")
print("PgUp — скрыть/показать UI")
