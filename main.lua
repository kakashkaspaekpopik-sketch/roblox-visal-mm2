-- Диагностика: найти все RemoteFunction/RemoteEvent в MM2
local function FindInventoryRemotes()
    print("=== Сканирую ремоуты MM2 ===")
    
    -- Ищем все RemoteFunction в игре
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteFunction") then
            local name = obj.Name:lower()
            if name:find("inv") or name:find("item") or name:find("load") or 
               name:find("get") or name:find("data") or name:find("player") or
               name:find("owned") or name:find("collection") then
                print("[RemoteFunction] " .. obj:GetFullName() .. "  —  " .. obj.Name)
            end
        end
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("inv") or name:find("item") or name:find("add") or 
               name:find("remove") or name:find("update") or name:find("data") then
                print("[RemoteEvent] " .. obj:GetFullName() .. "  —  " .. obj.Name)
            end
        end
    end
    
    -- Ищем BindableEvent/BindableFunction (локальные, не удалённые)
    for _, obj in ipairs(LP:GetDescendants()) do
        if obj:IsA("BindableEvent") and obj.Name:lower():find("inv") then
            print("[BindableEvent] " .. obj:GetFullName())
        end
        if obj:IsA("BindableFunction") and obj.Name:lower():find("inv") then
            print("[BindableFunction] " .. obj:GetFullName())
        end
    end
    
    -- Ищем LocalScript, в котором может быть вызов инвентаря
    for _, scr in ipairs(LP:GetDescendants()) do
        if scr:IsA("LocalScript") and (scr.Name:lower():find("inv") or scr.Name:lower():find("item")) then
            print("[LocalScript] " .. scr:GetFullName())
            -- Показываем его окружение
            local ok, env = pcall(getfenv, scr)
            if ok then
                for k, v in pairs(env) do
                    if type(v) == "table" and type(v[1]) == "string" then
                        print("  env." .. tostring(k) .. " = table (первые элементы: " .. tostring(v[1]) .. ", " .. tostring(v[2]) .. ")")
                    end
                end
            end
        end
    end
    
    print("=== Сканирование завершено ===")
end

FindInventoryRemotes()
