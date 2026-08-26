local LP = game:GetService("Players").LocalPlayer
for _, rem in ipairs(game:GetDescendants()) do
    if rem:IsA("RemoteFunction") and rem.Name:lower():find("inv") then
        local old = rem.InvokeServer
        rem.InvokeServer = function(self, ...)
            local r = {old(self, ...)}
            if type(r[1]) == "table" then
                table.insert(r[1], {assetId = "3316023216", name = "Chroma Tides", type = "Melee", rarity = "Godly"})
            end
            return unpack(r)
        end
        print("[+] ЗАХУЧЕН RemoteFunction: " .. rem.Name)
    end
end
