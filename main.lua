--[[ MM2 Dupe Tool v4 — цельный рабочий скрипт ]]

if _G.MM2DupeOverlay then return end
_G.MM2DupeOverlay = true

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

local myItems = {}
local dupeActive = false

-- ============================================================
-- СКАНИРОВАНИЕ ИНВЕНТАРЯ
-- Только LocalPlayer + ReplicatedStorage, глубина ограничена.
-- НИКАКИХ InvokeServer — это вызывало бесконечное зависание.
-- ============================================================
local function ScanInventory()
	local items = {}

	-- 1) Значения в LocalPlayer с числовыми именами (ID предметов)
	for _, v in ipairs(LP:GetDescendants()) do
		local ok = pcall(function()
			if v:IsA("StringValue") and tonumber(v.Name) and tonumber(v.Name) > 1000000 then
				local name = (v.Value ~= "" and v.Value) or v.Name
				table.insert(items, { id = v.Name, name = name })
			elseif v:IsA("IntValue") and v.Name:match("^%d+$") and v.Value > 0 then
				table.insert(items, { id = v.Name, name = "Item " .. v.Name })
			end
		end)
	end

	-- 2) Папки Inventory внутри PlayerData / Data
	for _, folderName in ipairs({ "PlayerData", "Data", "InventoryData", "Items" }) do
		local folder = LP:FindFirstChild(folderName)
		if folder then
			for _, child in ipairs(folder:GetDescendants()) do
				pcall(function()
					if (child:IsA("StringValue") or child:IsA("IntValue")) and child.Name:match("^%d+$") then
						local name = child.Value ~= "" and child.Value or child.Name
						table.insert(items, { id = child.Name, name = name })
					end
				end)
			end
		end
	end

	-- 3) Модули предметов в ReplicatedStorage (глубина 2, без require тяжёлых модулей)
	for _, mod in ipairs(RS:GetDescendants()) do
		if mod:IsA("ModuleScript") then
			local n = mod.Name:lower()
			if n:find("itemlist") or n:find("itemdata") or n:find("itemmodules") then
				local ok, result = pcall(require, mod)
				if ok and type(result) == "table" then
					for k, val in pairs(result) do
						pcall(function()
							if type(k) == "string" and k:match("^%d+$") then
								local name = k
								if type(val) == "table" and (val.Name or val.name) then
									name = tostring(val.Name or val.name)
								elseif type(val) == "string" then
									name = val
								end
								table.insert(items, { id = k, name = name })
							end
						end)
					end
				end
			end
		end
	end

	-- Дедупликация
	local seen, unique = {}, {}
	for _, item in ipairs(items) do
		if not seen[item.id] then
			seen[item.id] = true
			table.insert(unique, item)
		end
	end
	return unique
end

-- ============================================================
-- ДЮП
-- Спамит trade/removal ремоуты выбранного предмета.
-- Работает только если в игре есть соответствующая уязвимость.
-- ============================================================
local function DupeSingle(item)
	local sent = 0

	-- Собираем ремоуты один раз, только из ReplicatedStorage (быстро)
	local remotes = {}
	for _, obj in ipairs(RS:GetDescendants()) do
		if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
			local n = obj.Name:lower()
			if n:find("trade") or n:find("offer") or n:find("item") or n:find("inventory") then
				table.insert(remotes, obj)
			end
		end
	end

	-- Спам add/remove (race condition)
	for i = 1, 60 do
		if not dupeActive then break end
		for _, rem in ipairs(remotes) do
			pcall(function()
				if rem:IsA("RemoteEvent") then
					rem:FireServer({ itemId = item.id, action = "add", count = 1 })
					rem:FireServer({ itemId = item.id, action = "remove", count = 1 })
				end
			end)
			sent = sent + 1
		end
		task.wait(0.05)
	end

	return sent
end

-- ============================================================
-- GUI — парентим поверх всего
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2DupeOverlay"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = false
if gethui then
	pcall(function()
		screenGui.Parent = gethui()
		parented = true
	end)
end
if not parented then
	local ok = pcall(function()
		screenGui.Parent = game:GetService("CoreGui")
		parented = true
	end)
end
if not parented then
	screenGui.Parent = LP:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 130)
frame.Position = UDim2.new(0, 20, 0.5, -65)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
header.BorderSizePixel = 0
header.Active = true
header.Parent = frame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 14)
hCorner.Parent = header

local hBlocker = Instance.new("Frame")
hBlocker.Size = UDim2.new(1, 0, 0, 10)
hBlocker.Position = UDim2.new(0, 0, 1, -10)
hBlocker.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
hBlocker.BorderSizePixel = 0
hBlocker.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Dupe Tool v4"
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(255, 210, 60)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.Text = "✕"
closeBtn.TextSize = 13
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 6)
cCorner.Parent = closeBtn

-- ===== DRAG (фикс Vector3 → Vector2) =====
local dragging = false
local dragOffset = Vector2.new(0, 0)

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragOffset = Vector2.new(input.Position.X, input.Position.Y) - frame.AbsolutePosition
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local pos = Vector2.new(input.Position.X, input.Position.Y) - dragOffset
		frame.Position = UDim2.fromOffset(pos.X, pos.Y)
	end
end)

-- ===== СТАТУС =====
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 18)
status.Position = UDim2.new(0, 6, 0, 32)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.Text = "Загружен"
status.TextSize = 10
status.TextColor3 = Color3.fromRGB(0, 255, 100)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local itemCount = Instance.new("TextLabel")
itemCount.Size = UDim2.new(1, -12, 0, 14)
itemCount.Position = UDim2.new(0, 6, 0, 50)
itemCount.BackgroundTransparency = 1
itemCount.Font = Enum.Font.Gotham
itemCount.Text = "Вещей: —"
itemCount.TextSize = 9
itemCount.TextColor3 = Color3.fromRGB(140, 140, 170)
itemCount.TextXAlignment = Enum.TextXAlignment.Left
itemCount.Parent = frame

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or Color3.fromRGB(200, 200, 200)
end

-- ===== КНОПКИ =====
local function MakeBtn(text, posX, posY, w, color)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, w, 0, 22)
	btn.Position = UDim2.new(0, posX, 0, posY)
	btn.BackgroundColor3 = color
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
local startY = 72

local dupeBtn = MakeBtn("🔁 Дюпнуть", margin, startY, btnW, Color3.fromRGB(200, 55, 55))
local dupeAllBtn = MakeBtn("🌀 Дюп всё", margin + btnW + 6, startY, btnW, Color3.fromRGB(180, 60, 60))
local scanBtn = MakeBtn("📋 Инвентарь", margin, startY + 28, btnW * 2 + 6, Color3.fromRGB(50, 120, 210))

-- ===== ЛОГИКА =====

-- Сканировать
scanBtn.MouseButton1Click:Connect(function()
	setStatus("Сканирую...", Color3.fromRGB(255, 200, 50))
	task.spawn(function()
		local ok, items = pcall(ScanInventory)
		if ok and items then
			myItems = items
			itemCount.Text = "Вещей: " .. #myItems
			if #myItems > 0 then
				setStatus("Найдено: " .. #myItems, Color3.fromRGB(0, 255, 100))
			else
				setStatus("Предметы не найдены", Color3.fromRGB(255, 180, 60))
			end
		else
			setStatus("Ошибка сканирования", Color3.fromRGB(255, 80, 80))
		end
	end)
end)

-- Дюпнуть первый предмет
dupeBtn.MouseButton1Click:Connect(function()
	if dupeActive then
		dupeActive = false
		dupeBtn.Text = "🔁 Дюпнуть"
		dupeBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 55)
		setStatus("Остановлено", Color3.fromRGB(255, 200, 100))
		return
	end

	if #myItems == 0 then
		setStatus("Сначала нажми Инвентарь", Color3.fromRGB(255, 180, 60))
		return
	end

	dupeActive = true
	dupeBtn.Text = "⏹ Стоп"
	dupeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	setStatus("Дюп: " .. myItems[1].name, Color3.fromRGB(255, 200, 50))

	task.spawn(function()
		DupeSingle(myItems[1])
		dupeActive = false
		dupeBtn.Text = "🔁 Дюпнуть"
		dupeBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 55)
		setStatus("Готово. Перезайди и проверь", Color3.fromRGB(0, 255, 100))
	end)
end)

-- Дюпнуть всё
dupeAllBtn.MouseButton1Click:Connect(function()
	if dupeActive then
		dupeActive = false
		dupeAllBtn.Text = "🌀 Дюп всё"
		dupeAllBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		setStatus("Остановлено", Color3.fromRGB(255, 200, 100))
		return
	end

	if #myItems == 0 then
		setStatus("Сначала нажми Инвентарь", Color3.fromRGB(255, 180, 60))
		return
	end

	dupeActive = true
	dupeAllBtn.Text = "⏹ Стоп"
	dupeAllBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

	task.spawn(function()
		for i, item in ipairs(myItems) do
			if not dupeActive then break end
			setStatus(i .. "/" .. #myItems .. ": " .. item.name, Color3.fromRGB(255, 200, 50))
			DupeSingle(item)
			task.wait(0.1)
		end
		dupeActive = false
		dupeAllBtn.Text = "🌀 Дюп всё"
		dupeAllBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		setStatus("Дюп всего завершён. Перезайди", Color3.fromRGB(0, 255, 100))
	end)
end)

-- Закрыть
closeBtn.MouseButton1Click:Connect(function()
	dupeActive = false
	screenGui:Destroy()
	_G.MM2DupeOverlay = false
end)

print("=== MM2 Dupe Tool v4 загружен ===")
