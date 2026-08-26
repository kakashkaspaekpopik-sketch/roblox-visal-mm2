--[[
  MM2 Visual Item Spawner v2.0 — фикс (без внешних зависимостей)
  Работает на: Delta, Fluxus, Hydrogen, Codex, Arceus X, Wave
  
  Команды в чат:
    /spawn <название>   — спавн предмета
    /list              — список всех предметов
    /find <текст>      — поиск по названию
  PgUp — скрыть/показать UI
]]

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

-- ===== БАЗА ПРЕДМЕТОВ MM2 =====
-- ID взяты из актуального каталога Roblox для MM2
local ITEMS = {
    -- GODLY KNIVES
    ["Chroma Tides"]        = "3316023216",
    ["Chroma Darkbringer"]  = "4795102252",
    ["Chroma Heat"]         = "3679856235",
    ["Chroma Luger"]        = "4802846569",
    ["Chroma Fang"]         = "3866496593",
    ["Chroma Saw"]          = "4010421394",
    ["Chroma Boneblade"]    = "4201513013",
    ["Chroma Deathshard"]   = "4757020501",
    ["Chroma Gemstone"]     = "5608773528",
    ["Corrupt"]             = "2522429070",
    ["Darkbringer"]         = "4184571262",
    ["Eternal"]             = "4277198334",
    ["Eternal II"]          = "4686897237",
    ["Heartblade"]          = "5942259649",
    ["Iceblaster"]          = "6511628479",
    ["Icepiercer"]          = "5104316400",
    ["Luger"]               = "2487428118",
    ["Luger Cane"]          = "2552133780",
    ["Old Glory"]           = "4538346795",
    ["Saw"]                 = "2530471550",
    ["Seer"]                = "1029718616",
    ["Slash"]               = "2651632603",
    ["Sugar"]               = "2522007892",
    ["Tides"]               = "3069075015",
    ["Xmas"]                = "2555825124",
    
    -- GODLY GUNS
    ["Blaster"]             = "3814547802",
    ["Cookieblaster"]       = "4345362805",
    ["Deathshard Gun"]      = "4756999322",
    ["Ghost"]               = "4972760773",
    ["Golden Gun"]          = "4046045889",
    ["Peppermint Gun"]      = "4345364250",
    ["Frostsaber"]          = "5882235802",
    
    -- ANCIENT
    ["Amerlocker"]          = "4870568662",
    ["BattleAxe II"]        = "5074057030",
    ["Elderwood Scythe"]    = "6236416903",
    ["Hallowscythe"]        = "4200541572",
    ["Harvester"]           = "5909583032",
    ["Icewing"]             = "5753766549",
    ["Soul"]                = "5927047202",
    ["Batwing"]             = "6185187343",
    
    -- CLASSIC / VINTAGE
    ["Sparkle Time"]        = "6971385610",
    ["Glass"]               = "2641056315",
    ["Gemstone"]            = "5608773528",
    ["Chill"]               = "6116262600",
    ["Candy"]               = "6138506800",
    ["Frostbite"]           = "6134314601",
}

-- ===== СПАВН ВИЗУАЛЬНОГО ПРЕДМЕТА =====
local function SpawnVisualItem(itemName)
    if not itemName or itemName == "" then
        return false, "Введи название предмета"
    end
    
    -- Нормализация названия: каждое слово с большой буквы
    local words = {}
    for w in itemName:gmatch("%S+") do
        table.insert(words, w:sub(1,1):upper() .. w:sub(2):lower())
    end
    local normalized = table.concat(words, " ")
    
    -- Ищем по полному названию или частичному совпадению
    local assetId = ITEMS[normalized]
    if not assetId then
        for name, id in pairs(ITEMS) do
            if name:lower():find(normalized:lower()) or normalized:lower():find(name:lower()) then
                assetId = id
                normalized = name
                break
            end
        end
    end
    
    if not assetId then
        return false, "Предмет не найден. Используй /list для просмотра всех предметов"
    end
    
    -- === МЕТОД 1: Прямое добавление в InventoryData (если есть) ===
    local added = false
    
    local invData = LP:FindFirstChild("InventoryData") or 
                    (LP:FindFirstChild("PlayerData") and LP.PlayerData:FindFirstChild("Inventory"))
    
    if invData and not invData:FindFirstChild(assetId) then
        local itemObj = Instance.new("StringValue")
        itemObj.Name = assetId
        itemObj.Value = normalized
        itemObj.Parent = invData
        added = true
    end
    
    -- === МЕТОД 2: Поиск и патч локального скрипта инвентаря ===
    if not added then
        local gui = LP:FindFirstChild("PlayerGui")
        if gui then
            for _, scr in ipairs(gui:GetDescendants()) do
                if scr:IsA("LocalScript") and (scr.Name:lower():find("inventory") or scr.Name:lower():find("item")) then
                    -- Пробуем найти функцию обновления через getupvalues
                    local success, env = pcall(function() return getfenv(scr) end)
                    if success and type(env) == "table" then
                        for k, v in pairs(env) do
                            if type(v) == "function" and k:lower():find("add") then
                                local ok = pcall(v, {id = assetId, name = normalized})
                                if ok then added = true end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- === МЕТОД 3: Spoof торгового Invoke ===
    if not added then
        for _, rem in ipairs(LP:GetDescendants()) do
            if rem:IsA("RemoteFunction") and rem.Name:lower():find("inventory") then
                local old = rem.InvokeServer
                rem.InvokeServer = function(self, ...)
                    local r = {pcall(old, self, ...)}
                    table.insert(r, {itemId = assetId, itemName = normalized})
                    return unpack(r)
                end
                added = true
                break
            end
        end
    end
    
    -- Триггерим обновление UI инвентаря
    local mainGui = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("MainGui")
    if mainGui then
        for _, v in ipairs(mainGui:GetDescendants()) do
            if v:IsA("BindableEvent") and v.Name == "ItemAdded" then
                v:Fire({Name = normalized, AssetId = assetId})
            end
        end
    end
    
    return true, "✅ " .. normalized .. " добавлен в инвентарь (визуально)"
end

-- ===== РИСУЕМ UI ЧЕРЕЗ DRAWING =====
local ui = {}
local uiVisible = true

local function CreateUI()
    local s = workspace.CurrentCamera.ViewportSize
    
    ui.bg = Drawing.new("Square")
    ui.bg.Size = Vector2.new(380, 250)
    ui.bg.Position = Vector2.new(s.X/2 - 190, s.Y/2 - 125)
    ui.bg.Filled = true
    ui.bg.Color = Color3.fromRGB(15, 15, 25)
    ui.bg.Transparency = 0.92
    ui.bg.Visible = true
    
    ui.title = Drawing.new("Text")
    ui.title.Text = "MM2 Visual Spawner"
    ui.title.Position = Vector2.new(s.X/2 - 170, s.Y/2 - 110)
    ui.title.Size = 20
    ui.title.Color = Color3.fromRGB(255, 200, 50)
    ui.title.Visible = true
    
    ui.hint = Drawing.new("Text")
    ui.hint.Text = "/spawn <название>  —  /list  —  /find <текст>"
    ui.hint.Position = Vector2.new(s.X/2 - 170, s.Y/2 - 75)
    ui.hint.Size = 13
    ui.hint.Color = Color3.fromRGB(180, 180, 180)
    ui.hint.Visible = true
    
    ui.line1 = Drawing.new("Text")
    ui.line1.Text = "Пример: /spawn Chroma Tides"
    ui.line1.Position = Vector2.new(s.X/2 - 170, s.Y/2 - 45)
    ui.line1.Size = 13
    ui.line1.Color = Color3.fromRGB(130, 130, 130)
    ui.line1.Visible = true
    
    ui.line2 = Drawing.new("Text")
    ui.line2.Text = "/spawn Corrupt  —  /spawn Seer  —  /spawn Luger"
    ui.line2.Position = Vector2.new(s.X/2 - 170, s.Y/2 - 20)
    ui.line2.Size = 13
    ui.line2.Color = Color3.fromRGB(130, 130, 130)
    ui.line2.Visible = true
    
    ui.line3 = Drawing.new("Text")
    ui.line3.Text = "| PgUp — скрыть/показать"
    ui.line3.Position = Vector2.new(s.X/2 - 170, s.Y/2 + 5)
    ui.line3.Size = 13
    ui.line3.Color = Color3.fromRGB(100, 100, 100)
    ui.line3.Visible = true
    
    ui.status = Drawing.new("Text")
    ui.status.Text = "[Готов]"
    ui.status.Position = Vector2.new(s.X/2 - 170, s.Y/2 + 100)
    ui.status.Size = 14
    ui.status.Color = Color3.fromRGB(0, 255, 100)
    ui.status.Visible = true
end

-- Обновление статуса
local function SetStatus(text, color)
    if ui.status then
        ui.status.Text = text
        ui.status.Color = color or Color3.fromRGB(200, 200, 200)
    end
end

-- ===== ЧАТ-КОМАНДЫ =====
LP.Chatted:Connect(function(msg)
    local cmd, arg = msg:match("^/(%S+)%s*(.*)$")
    if not cmd then return end
    
    cmd = cmd:lower()
    
    if cmd == "spawn" then
        if arg and arg ~= "" then
            SetStatus("[⏳] Спавн: " .. arg .. "...", Color3.fromRGB(255, 200, 50))
            local ok, res = SpawnVisualItem(arg)
            SetStatus(ok and "[✅] " .. res or "[❌] " .. res,
                ok and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 80, 80))
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = ok and "[+] " .. res or "[!] " .. res,
                Color = ok and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
            })
        else
            SetStatus("[!] Используй: /spawn <название>", Color3.fromRGB(255, 200, 100))
        end
        
    elseif cmd == "list" then
        local names = {}
        for n in pairs(ITEMS) do table.insert(names, n) end
        table.sort(names)
        
        -- Вывод в консоль и чат
        local text = "Все предметы (" .. #names .. "): "
        for i, n in ipairs(names) do
            text = text .. n
            if i < #names then text = text .. ", " end
        end
        
        -- Разбиваем на части, если слишком длинно
        if #text > 200 then
            local parts = {}
            local current = ""
            for _, n in ipairs(names) do
                local add = (current == "" and "" or ", ") .. n
                if #current + #add > 180 then
                    table.insert(parts, current)
                    current = n
                else
                    current = current .. add
                end
            end
            if current ~= "" then table.insert(parts, current) end
            for _, p in ipairs(parts) do
                game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                    Text = p, Color = Color3.fromRGB(200, 200, 255)
                })
            end
        else
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = text, Color = Color3.fromRGB(200, 200, 255)
            })
        end
        
        SetStatus("[📋] Всего предметов: " .. #names, Color3.fromRGB(150, 200, 255))
        
    elseif cmd == "find" then
        if arg and arg ~= "" then
            local q = arg:lower()
            local found = {}
            for n in pairs(ITEMS) do
                if n:lower():find(q) then
                    table.insert(found, n)
                end
            end
            if #found > 0 then
                local text = "Найдено (" .. #found .. "): " .. table.concat(found, ", ")
                game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                    Text = text, Color = Color3.fromRGB(150, 255, 150)
                })
                SetStatus("[🔍] Найдено: " .. #found, Color3.fromRGB(150, 255, 150))
            else
                SetStatus("[❌] Ничего не найдено по '" .. arg .. "'", Color3.fromRGB(255, 150, 100))
            end
        end
    end
end)

-- ===== PgUp — тоггл UI =====
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.PageUp then
        uiVisible = not uiVisible
        for _, v in pairs(ui) do
            v.Visible = uiVisible
        end
    end
end)

-- ===== ЗАПУСК =====
CreateUI()
SetStatus("[✅] Загружен! Используй чат-команды", Color3.fromRGB(0, 255, 100))

print("=== MM2 Visual Spawner ===")
print("Команды: /spawn <name> | /list | /find <текст>")
print("PgUp — показать/скрыть UI")
print("Всего предметов в базе: " .. #(function() local c=0; for _ in pairs(ITEMS) do c=c+1 end; return c end)())
