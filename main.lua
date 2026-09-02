--[[ MM2 Dupe Tool v5 — чистый рабочий скрипт ]]

if _G.MM2DupeOverlay then return end
_G.MM2DupeOverlay = true

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

local myItems = {}
local dupeActive = false

-- ============================================================
-- СКАНИРОВАНИЕ ИНВЕНТАРЯ (без InvokeServer, без зависаний)
-- ============================================================
local function ScanInventory()
	local items = {}

	-- 1) Значения в LocalPlayer с числовыми именами (ID предметов)
	for _, v in ipairs(LP:GetDescendants()) do
		pcall(function()
			if v:IsA("StringValue") and tonumber(v.Name) and tonumber(v.Name) > 1000000 then
				local name = (v.Value ~= "" and v.Value) or v.Name
				table.insert(items, { id = v.Name, name = name })
			elseif v:IsA("IntValue") and v.Name:match("^%d+$") and v.Value > 0 then
				table.insert(items, { id = v.Name, name = "Item " .. v.Name })
			end
		end)
	end

	-- 2) Папки с данными игрока
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

	-- 3) Модули предметов в ReplicatedStorage
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

-- ============================================================
-- ДЮП — спам trade/item ремоутов из ReplicatedStorage
-- ============================================================
local function DupeSingle(item)
	local sent = 0

	local remotes = {}
	for _, obj in ipairs(RS:GetDescendants()) do
		if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
			local n = obj.Name:lower()
			if n:find("trade") or n:find("offer") or n:find("item") or n:find("inventory") then
				table.insert(remotes, obj)
			end
		end
	end

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
-- GUI — поверх всего
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
	pcall(function()
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
header.BackgroundColor3 = Color3.fromRGB(30, 30,  Roblox
