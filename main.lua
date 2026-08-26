--[[
  MM2 Inventory Injector v3 — хук через таблицы и ремоуты
]]
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ====== 1. ХУК ВСЕХ RemoteFunction НА ПРЕДМЕТЫ ======
-- Перехватываем InvokeServer, чтобы подменить ответ сервера
for _, rem in ipairs(game:GetDescendants()) do
    if rem:IsA("RemoteFunction") then
        local name = rem.Name:lower()
        if name:find("inv") or name:find("load") or name:find("get") or name:find("item") then
            local oldInvoke = rem.InvokeServer
            rem.InvokeServer = function(self, ...)
                local results = {pcall(oldInvoke, self, ...)}
                -- Если сервер вернул таблицу — добавляем туда наш предмет
                if type(results[1]) == "table" then
                    table.insert(results[1], {
                        id = "3316023216",
                        name = "Chroma Tides",
                        assetId = "3316023216",
                        type = "Melee",
                        rarity = "Godly"
                    })
                end
                return unpack(results)
            end
        end
    end
end

-- ====== 2. ПОИСК ТАБЛИЦЫ ИНВЕНТАРЯ В ПАМЯТИ ======
-- Проходимся по всем модулям и скриптам, ищем таблицы с предметами
local found = false
for _, obj in ipairs(LP:GetDescendants()) do
    if obj:IsA("ModuleScript") or obj:IsA("LocalScript") then
        local ok, env = pcall(function()
            if obj:IsA("ModuleScript") then
                return require(obj)
            else
                return getfenv(obj)
            end
        end)
        if ok and type(env) == "table" then
            -- Ищем таблицы внутри модуля
            for k, v in pairs(env) do
                if type(v) == "table" and not found then
                    -- Проверяем, похожа ли таблица на инвентарь (есть числовые ID)
                    local count = 0
                    for _, val in pairs(v) do
                        if type(val) == "table" and (val.assetId or val.id or val.AssetId) then
                            count = count + 1
                        end
                    end
                    if count > 3 then
                        -- Нашли! Добавляем наш предмет
                        table.insert(v, {
                            id = "3316023216",
                            assetId = "3316023216",
                            name = "Chroma Tides",
                            type = "Melee",
                            rarity = "Godly"
                        })
                        found = true
                        print("[+] Найдена таблица инвентаря: " .. tostring(k))
                    end
                end
            end
        end
    end
end

-- ====== 3. ХУК МЕТАТАБЛИЦ ======
-- Если инвентарь хранится как массив с метатаблицей — хукаем __index
hookmetamethod = hookmetamethod or function(...) return ... end

for _, obj in ipairs(LP:GetDescendants()) do
    if obj:IsA("LocalScript") and (obj.Name:lower():find("inv") or obj.Name:lower():find("gui")) then
        local ok, env = pcall(getfenv, obj)
        if ok and type(env) == "table" then
            for k, v in pairs(env) do
                if type(v) == "table" and type(getrawmetatable) == "function" then
                    local mt = getrawmetatable(v)
                    if mt and type(mt) == "table" then
                        local oldIndex = mt.__index
                        mt.__index = function(tbl, key)
                            local ret = oldIndex and oldIndex(tbl, key)
                            -- Если запрашивают длину или итератор — занижаем, что есть лишний элемент
                            return ret
                        end
                    end
                end
            end
        end
    end
end

-- ====== 4. ПРЯМОЙ ПАТЧ UI ======
-- Если ничего не сработало — вставляем ImageButton прямо в GUI
task.wait(2)
local mainGui = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("MainGui")
if mainGui then
    local invFrame = mainGui:FindFirstChild("Items") or mainGui:FindFirstChild("Inventory")
    if invFrame then
        local btn = Instance.new("ImageButton")
        btn.Name = "3316023216"
        btn.Size = UDim2.new(0, 60, 0, 60)
        btn.Position = UDim2.new(0, 10, 0, 10)
        btn.BackgroundTransparency = 1
        btn.Image = "rbxassetid://3316023216"
        btn.Parent = invFrame
        print("[+] ImageButton вставлен напрямую в GUI")
    end
end

print("=== Скрипт инжекции выполнен ===")ы
