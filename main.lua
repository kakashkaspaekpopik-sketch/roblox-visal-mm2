--[[
  MM2 Dupe Tool — Compact v4 (фикс бесконечного сканирования)
  - Никаких game:GetDescendants() на весь game
  - Таймауты на все InvokeServer
  - Сканирование только в LP и ReplicatedStorage (быстро)
]]

if _G.MM2DupeOverlay then return end
_G.MM2DupeOverlay = true

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

local myItems = {}
local dupeActive = false
local dupeAllActive = false

-- ===== БЕЗОПАСНЫЙ INVOKE С ТАЙМАУТОМ =====
local function SafeInvoke(rf, timeout)
    timeout = timeout or 2
    local result = nil
    local done = false

    task.spawn(function()
        local ok, res = pcall(function() return rf:InvokeServer() end)
        result = res
        done = true
        if ok and type(res) == "table" then
            -- Собираем предметы из ответа
            for _, v in ipairs(res) do
                if type(v) == "table" then
                    local id = tostring(v.assetId or v.id or v.Name or "")
                    if id ~= "" and id:len() > 5 then
                        table.insert(items_buffer, {id = id, name = tostring(v.name or v.Name or id)})
                    end
                elseif type(v) == "string" then
                    table.insert(items_buffer, {id = v, name = v})
                end
            end
        end
    end)

    local t0 = os.clock()
    while not done and os.clock() - t0 < timeout do
        task.wait(0.05)
    end

    return result, done
end

local items_buffer = {}   -- используется в SafeInvoke

-- ===== СКАНИРОВАНИЕ (БЫСТРОЕ, БЕЗ ЗАВИСАНИЙ) =====
local function ScanInventory()
    local items = {}

    -- Зона поиска: только LP и ReplicatedStorage (не весь game!)
    local searchAreas = {LP, RS}

    for _, area in ipairs(searchAreas) do
        for _, obj in ipairs(area:GetDescendants()) do
            -- Ограничиваем поиск RemoteFunction
            if obj:IsA("RemoteFunction") then
                local n = obj.Name:lower()
                -- Тщательно фильтруем, чтобы не дёргать что попало
                if (n:find("inv") or n:find("item")) and not n:find("trade") then
                    -- Вызываем с таймаутом
                    local res, finished = SafeInvoke(obj, 1.5)
                    if finished and type(res) == "table" then
                        for _, v in ipairs(res) do
                            if type(v) == "table" for _, item in ipairs(items_buffer) do
                                table.insert(items, item)
                            end
                        end
        end
    end

    return items
end
