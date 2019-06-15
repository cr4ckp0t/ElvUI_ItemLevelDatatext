-------------------------------------------------------------------------------
-- ElvUI Item Level Datatext By Crackpotx
-------------------------------------------------------------------------------
local E, _, _, P, _, _ = unpack(ElvUI)
local DT = E:GetModule("DataTexts")
local L = LibStub("AceLocale-3.0"):GetLocale("ElvUI_ItemLevelDatatext", false)
local EP = LibStub("LibElvUIPlugin-1.0")

-- local api cache
local GetDetailedItemLevelInfo = _G["GetDetailedItemLevelInfo"]
local GetAverageItemLevel = _G["GetAverageItemLevel"]
local GetInventoryItemID = _G["GetInventoryItemID"]
local GetInventoryItemLink = _G["GetInventoryItemLink"]
local GetItemInfo = _G["GetItemInfo"]
local GetItemQualityColor = _G["GetItemQualityColor"]
local ToggleCharacter = _G["ToggleCharacter"]
local unpack = _G["unpack"]

local join = string.join
local floor = math.floor
local format = string.format

local displayString = ""
local slots = {
	[1] = L["Head"],
	[2] = L["Neck"],
	[3] = L["Shoulders"],
	[5] = L["Chest"],
	[6] = L["Waist"],
	[7] = L["Legs"],
	[8] = L["Feet"],
	[9] = L["Wrist"],
	[10] = L["Hands"],
	[11] = L["Ring 1"],
	[12] = L["Ring 2"],
	[13] = L["Trinket 1"],
	[14] = L["Trinket 2"],
	[15] = L["Back"],
	[16] = L["Main Hand"],
	[17] = L["Off Hand"],
	--[18] = L["Ranged"],
}

-- rounds a number for printing
local function DecRound(num, decPlaces)
	return format("%." .. (decPlaces or 0) .. "f", num)
end

local function OnEvent(self, event)
	local total, equipped = GetAverageItemLevel()
	self.text:SetFormattedText(displayString, L["Item Level"], E.db.ilvldt.ilvl == "equip" and DecRound(equipped, E.db.ilvldt.precision) or DecRound(total, E.db.ilvldt.precision))
end

local function OnEnter(self)
	local total, equipped = GetAverageItemLevel()
	DT:SetupTooltip(self)
	DT.tooltip:AddDoubleLine(L["Total"], DecRound(total, E.db.ilvldt.precision), 1, 1, 1, 1, 1, 0)
	DT.tooltip:AddDoubleLine(L["Equipped"], DecRound(equipped, E.db.ilvldt.precision), 1, 1, 1, 1, 1, 0)
	DT.tooltip:AddLine(" ")
	for i = 1, 17 do
		if slots[i] and GetInventoryItemID("player", i) then
			local name, _, quality, _, _, _, _, _, _, _, _ = GetItemInfo(GetInventoryItemLink("player", i))
			local red, green, blue, _ = GetItemQualityColor(quality)
			DT.tooltip:AddDoubleLine(slots[i], E.db.ilvldt.showItem == true and ("%s (%d)"):format(name, GetDetailedItemLevelInfo(GetInventoryItemLink("player", i))) or GetDetailedItemLevelInfo(GetInventoryItemLink("player", i)), 1, 1, 1, red, green, blue)
		end
	end
	DT.tooltip:Show()
end

local function OnClick(self, button)
	if button == "LeftButton" then
		ToggleCharacter("PaperDollFrame")
	else
		OnEvent(self)
	end
end

local interval = 10
local function OnUpdate(self, elapsed)
	if not self.lastUpdate then self.lastUpdate = 0 end
	self.lastUpdate = self.lastUpdate + elapsed
	if self.lastUpdate > interval then
		self.lastUpdate = 0
		local total, equipped = GetAverageItemLevel()
		self.text:SetFormattedText(displayString, L["Item Level"], E.db.ilvldt.ilvl == "equip" and DecRound(equipped, E.db.ilvldt.precision) or DecRound(total, E.db.ilvldt.precision))
	end
end


local function ValueColorUpdate(hex, r, g, b)
	displayString = join("", "|cffffffff%s:|r", " ", hex, "%s|r")
end
E["valueColorUpdateFuncs"][ValueColorUpdate] = true

P["ilvldt"] = {
	["ilvl"] = "equip",
	["precision"] = 2,
	["showItem"] = true,
}

local function InjectOptions()
	if not E.Options.args.Crackpotx then
		E.Options.args.Crackpotx = {
			type = "group",
			order = -2,
			name = L["Plugins by |cff9382c9Crackpotx|r"],
			args = {
				thanks = {
					type = "description",
					order = 1,
					name = L["Thanks for using and supporting my work!  -- |cff9382c9Crackpotx|r\n\n|cffff0000If you find any bugs, or have any suggestions for any of my addons, please open a ticket at that particular addon's page on CurseForge."],
				},
			},
		}
	elseif not E.Options.args.Crackpotx.args.thanks then
		E.Options.args.Crackpotx.args.thanks = {
			type = "description",
			order = 1,
			name = L["Thanks for using and supporting my work!  -- |cff9382c9Crackpotx|r\n\n|cffff0000If you find any bugs, or have any suggestions for any of my addons, please open a ticket at that particular addon's page on CurseForge."],
		}
	end

	E.Options.args.Crackpotx.args.ilvldt = {
		type = "group",
		name = L["Item Level Datatext"],
		get = function(info) return E.db.ilvldt[info[#info]] end,
		set = function(info, value) E.db.ilvldt[info[#info]] = value; DT:LoadDataTexts() end,
		args = {
			ilvl = {
				type = "select",
				order = 4,
				name = L["iLvl Display"],
				desc = L["Select which item level you want to display in the datatext, total or equipped."],
				values = {
					["equip"] = L["Equipped"],
					["total"] = L["Total"],
				},
			},
			precision = {
				type = "range",
				order = 5,
				name = L["Precision"],
				desc = L["Number of decimal places to round to for the average item level."],
				min = 0, max = 5, step = 1,
			},
			showItem = {
				type = "toggle",
				order = 6,
				name = L["Show Item Name"],
				desc = L["Show item name in the tooltip."],
			},
		},
	}
end

EP:RegisterPlugin(..., InjectOptions)
DT:RegisterDatatext(L["Item Level"], {"PLAYER_ENTERING_WORLD"}, OnEvent, OnUpdate, OnClick, OnEnter)