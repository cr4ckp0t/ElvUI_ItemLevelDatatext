-------------------------------------------------------------------------------
-- ElvUI Item Level Datatext By Crackpot
-------------------------------------------------------------------------------
local E, _, _, P, _, _ = unpack(ElvUI)
local DT = E:GetModule("DataTexts")
local L = E.Libs.ACL:GetLocale("ElvUI_ItemLevelDatatext", false)
local EP = E.Libs.EP
local ACH = E.Libs.ACH
local EasyMenu = LibStub("LibEasyMenu-1.0")

local _G = _G

-- local api cache
local LoadAddOn = C_AddOns.LoadAddOn
local C_ClassTalents_GetActiveConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID
local C_ClassTalents_GetConfigIDsBySpecID = C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID
local C_ClassTalents_GetHasStarterBuild = C_ClassTalents and C_ClassTalents.GetHasStarterBuild
local C_ClassTalents_GetLastSelectedSavedConfigID = C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID
local C_ClassTalents_GetStarterBuildActive = C_ClassTalents and C_ClassTalents.GetStarterBuildActive
local C_EquipmentSet_GetEquipmentSetInfo = C_EquipmentSet.GetEquipmentSetInfo
local C_EquipmentSet_ModifyEquipmentSet = C_EquipmentSet.ModifyEquipmentSet
local C_EquipmentSet_DeleteEquipmentSet = C_EquipmentSet.DeleteEquipmentSet
local C_EquipmentSet_GetNumEquipmentSets = C_EquipmentSet.GetNumEquipmentSets
local C_EquipmentSet_GetEquipmentSetID = C_EquipmentSet.GetEquipmentSetID
local C_EquipmentSet_UseEquipmentSet = C_EquipmentSet.UseEquipmentSet
local C_EquipmentSet_SaveEquipmentSet = C_EquipmentSet.SaveEquipmentSet
local C_Traits_GetConfigInfo = C_Traits.GetConfigInfo
local PlayerUtil_CanUseClassTalents = PlayerUtil.CanUseClassTalents
local PlayerUtil_GetCurrentSpecID = PlayerUtil.GetCurrentSpecID

local GetAverageItemLevel = GetAverageItemLevel
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetSpecialization = GetSpecialization
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown
local StaticPopup_Show = StaticPopup_Show
local ToggleCharacter = ToggleCharacter

local floor = floor
local format = format
local gsub = gsub
local next = next
local strjoin = strjoin
local tinsert = tinsert
local unpack = unpack

local STARTER_ID = Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
local STARTER_TEXT = E:RGBToHex(BLUE_FONT_COLOR.r, BLUE_FONT_COLOR.g, BLUE_FONT_COLOR.b, nil, _G.TALENT_FRAME_DROP_DOWN_STARTER_BUILD)

local lastSelectedId, specId
local maxEquipmentSets = 10
local displayString = ""
local hexColor = ""
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
	[17] = L["Off Hand"]
}

-- for drop down menu
local menuFrame = CreateFrame("Frame", "ILDTEquipmentSetMenu", E.UIParent, "UIDropDownMenuTemplate")

-- for renaming the equipment set
StaticPopupDialogs["ILDT_RENAME"] = {
	text = L["Rename %s to what?"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 16,
	exclusive = 0,
	preferredIndex = 3,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(self)
		_G[self:GetName() .. "EditBox"]:SetFocus()
		self.button1:Disable()
	end,
	OnHide = function(self)
		if _G[self:GetName() .. "EditBox"]:IsShown() then
			_G[self:GetName() .. "EditBox"]:SetFocus()
		end
		_G[self:GetName() .. "EditBox"]:SetText("")
	end,
	OnAccept = function(self, setId)
		local newName = _G[self:GetName() .. "EditBox"]:GetText()
		local oldName = C_EquipmentSet_GetEquipmentSetInfo(setId)
		if not newName or newName == "" or oldName == newName then
			return
		end
		C_EquipmentSet_ModifyEquipmentSet(setId, newName)
		DEFAULT_CHAT_FRAME:AddMessage(chatString:format((L["Renamed |cff%s%s|r to |cff%s%s|r!"]):format(hexColor, oldName, hexColor, newName)))
	end,
	EditBoxOnEnterPressed = function(self, setId)
		local newName = self:GetText()
		local oldName = C_EquipmentSet_GetEquipmentSetInfo(setId)
		if not newName or newName == "" or oldName == newName then
			return
		end
		C_EquipmentSet_ModifyEquipmentSet(setId, newName)
		DEFAULT_CHAT_FRAME:AddMessage(chatString:format((L["Renamed |cff%s%s|r to |cff%s%s|r!"]):format(hexColor, oldName, hexColor, newName)))
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
	EditBoxOnTextChanged = function(self)
		local parent = self:GetParent()
		if _G[parent:GetName() .. "EditBox"]:GetText() == "" then
			parent.button1:Disable()
		else
			parent.button1:Enable()
		end
	end
}

-- staticpoup for deleting
StaticPopupDialogs["ILDT_DELETE"] = {
	text = L["Are you sure you want to delete %s?"],
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 10,
	whileDead = true,
	hideOnEscape = true,
	OnAccept = function(self, setId)
		local oldName = C_EquipmentSet_GetEquipmentSetInfo(setId)
		C_EquipmentSet_DeleteEquipmentSet(setId)
		DEFAULT_CHAT_FRAME:AddMessage(chatString:format((L["Deleted equipment set |cff%s%s|r!"]):format(hexColor, oldName)))
	end
}

local function starter_checked()
	return C_ClassTalents_GetStarterBuildActive()
end

local function loadout_checked(data)
	return data and data.arg1 == lastSelectedId
end

local loadout_func
do
	local loadoutId
	local function loadout_callback(_, configId)
		return configId == loadoutId
	end

	loadout_func = function(_, arg1)
		if not _G.PlayerSpellsFrame then
			_G.PlayerSpellsFrame_LoadUI()
		end

		loadoutId = arg1

		_G.PlayerSpellsFrame.TalentsFrame:LoadConfigByPredicate(loadout_callback)
	end
end

-- rounds a number for printing
local function DecRound(num, decPlaces)
	return format("%." .. (decPlaces or 0) .. "f", num)
end

local function GetEquippedSet()
	local num = C_EquipmentSet_GetNumEquipmentSets()
	if num == 0 then
		return false
	end
	for i = 0, maxEquipmentSets do
		local name, icon, _, isEquipped = C_EquipmentSet_GetEquipmentSetInfo(i)
		if name and isEquipped == true then
			return name, icon
		end
	end
	return L["None Equipped"]
end

local function EquipmentSetClick(self, info)
	local setId = C_EquipmentSet_GetEquipmentSetID(info)
	if not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then
		-- change set
		C_EquipmentSet_UseEquipmentSet(setId)
	elseif IsShiftKeyDown() then
		-- rename set
		local popup = StaticPopup_Show("ILDT_RENAME", info)
		if popup then
			popup.data = setId
		end
	elseif IsControlKeyDown() then
		-- save set
		C_EquipmentSet_SaveEquipmentSet(setId)
	elseif IsAltKeyDown() then
		-- delete set
		local popup = StaticPopup_Show("ILDT_DELETE", info)
		if popup then
			popup.data = setId
		end
	end
end

local function OnEvent(self, event)
	local total, equipped = GetAverageItemLevel()
	self.text:SetFormattedText(displayString, L["Item Level"], E.db.ilvldt.ilvl == "equip" and DecRound(equipped, E.db.ilvldt.precision) or DecRound(total, E.db.ilvldt.precision))
	specId = PlayerUtil_GetCurrentSpecID()
	if specId then 
		lastSelectedId = C_ClassTalents_GetLastSelectedSavedConfigID(specId) or C_ClassTalents_GetActiveConfigID()
	end
end

local function OnEnter(self)
	local total, equipped = GetAverageItemLevel()
	DT:SetupTooltip(self)
	for i = 1, 17 do
		if slots[i] and GetInventoryItemID("player", i) then
			local name, _, quality, _, _, _, _, _, _, _, _ = GetItemInfo(GetInventoryItemLink("player", i))
			local red, green, blue, _ = GetItemQualityColor(quality)
			--DT.tooltip:AddDoubleLine(slots[i], E.db.ilvldt.showItem == true and ("%s (%d)"):format(name, GetDetailedItemLevelInfo(GetInventoryItemLink("player", i))) or GetDetailedItemLevelInfo(GetInventoryItemLink("player", i)), 1, 1, 1, red, green, blue)
			DT.tooltip:AddDoubleLine(slots[i], E.db.ilvldt.showItem == true and ("|T%s:14:14:0:0:64:64:4:60:4:60|t %s (%d)"):format(GetInventoryItemTexture("player", i), GetInventoryItemLink("player", i), GetDetailedItemLevelInfo(GetInventoryItemLink("player", i))) or GetDetailedItemLevelInfo(GetInventoryItemLink("player", i)), 1, 1, 1, red, green, blue)
		end
	end
	DT.tooltip:AddLine(" ")
	DT.tooltip:AddDoubleLine(L["Total"], DecRound(total, E.db.ilvldt.precision), 1, 1, 1, nil, nil, nil)
	DT.tooltip:AddDoubleLine(L["Equipped"], DecRound(equipped, E.db.ilvldt.precision), 1, 1, 1, nil, nil, nil)
	if C_EquipmentSet_GetNumEquipmentSets() > 0 then
		DT.tooltip:AddDoubleLine(L["Equipment Set"], GetEquippedSet(), 1, 1, 1, nil, nil, nil)
	end
	if PlayerUtil_CanUseClassTalents and E.db.ilvldt.showTalentBuild then
		local configInfo = C_Traits_GetConfigInfo(lastSelectedId)
		if configInfo then
			DT.tooltip:AddDoubleLine(L["Active Talent Build"], configInfo.name, 1, 1, 1, nil, nil, nil)
		end
	end
	DT.tooltip:AddLine(" ")
	DT.tooltip:AddDoubleLine(L["Left Click"], L["Open Character Panel"], 1, 1, 1, nil, nil, nil)
	DT.tooltip:AddDoubleLine(L["Right Click"], L["Change Equipment Set"], 1, 1, 1, nil, nil, nil)
	DT.tooltip:AddDoubleLine(L["Shift + Left Click"], L["Open Talent Panel"], 1, 1, 1, nil, nil, nil)
	DT.tooltip:AddDoubleLine(L["Shift + Right Click"], L["Change Talent Build"], 1, 1, 1, nil, nil, nil)
	DT.tooltip:Show()
end

local function OnClick(self, button)
	if not _G.ClassTalentFrame then
		LoadAddOn('Blizzard_ClassTalentUI')
	end

	if button == "LeftButton" then
		if not IsShiftKeyDown() then
			ToggleCharacter("PaperDollFrame")
		else
			if not E:AlertCombat() then
				TogglePlayerSpellsFrame(_G.PlayerSpellsMicroButton.suggestedTab)
			end
		end
	elseif button == "RightButton" then
		local menuList = {}
		DT.tooltip:Hide()
		if not IsShiftKeyDown() then
			menuList = {{text = L["Choose Equipment Set"], isTitle = true, notCheckable = true}}
			local numSets = C_EquipmentSet_GetNumEquipmentSets()
			local color = "ffffff"

			if not numSets or tonumber(numSets) == 0 then
				menuList[#menuList + 1] = {text = ("|cffff0000%s|r"):format(L["No Equipment Sets"]), notCheckable = true}
			else
				for i = 0, maxEquipmentSets do
					local name, _, _, isEquipped, _, _, _, missing, _ = C_EquipmentSet_GetEquipmentSetInfo(i)
					if name then
						if missing > 0 then
							color = "|cffff0000"
						else
							color = isEquipped == true and hexColor or "|cffffffff"
						end

						menuList[#menuList + 1] = {
							text = strjoin("", " ", ("%s%s|r"):format(color, name)),
							func = EquipmentSetClick,
							arg1 = name,
							checked = isEquipped == true and true or false
						}
					end
				end

				-- add a hint
				menuList[#menuList + 1] = {
					text = L["Shift + Click to Rename"],
					isTitle = true,
					notCheckable = true,
					notClickable = true
				}
				menuList[#menuList + 1] = {
					text = L["Ctrl + Click to Save"],
					isTitle = true,
					notCheckable = true,
					notClickable = true
				}
				menuList[#menuList + 1] = {
					text = L["Alt + Click to Delete"],
					isTitle = true,
					notCheckable = true,
					notClickable = true
				}
			end
		else
			if PlayerUtil_CanUseClassTalents and specId then
				local builds = C_ClassTalents_GetConfigIDsBySpecID(specId)
				if builds then
					if C_ClassTalents_GetHasStarterBuild() then
						tinsert(builds, STARTER_ID)
					end

					menuList = {{text = L["Choose Talent Build"], isTitle = true, notCheckable = true}}
					for index, configId in next, builds do
						if configId == STARTER_ID then
							menuList[index + 1] = { text = strjoin("", " ", STARTER_TEXT), checked = starter_checked, func = loadout_func, arg1 = STARTER_ID }
						else
							local configInfo = C_Traits_GetConfigInfo(configId)
							menuList[index + 1] = { text = strjoin("", " ", configInfo and configInfo.name or UNKNOWN), checked = loadout_checked, func = loadout_func, arg1 = configId }
						end
					end
				else
					menuList = {{text = L["No talent builds found."], isTitle = true, notCheckable = true}}
				end
			else
				menuList = {{text = L["Failed to load Talent Builds"], isTitle = true, notCheckable = true}}
			end
		end
		EasyMenu.Create(menuList, menuFrame, "cursor", 0, 0, "MENU", 2)
	end

	OnEvent(self)
end

local interval = 10
local function OnUpdate(self, elapsed)
	if not self.lastUpdate then
		self.lastUpdate = 0
	end
	self.lastUpdate = self.lastUpdate + elapsed
	if self.lastUpdate > interval then
		self.lastUpdate = 0
		local total, equipped = GetAverageItemLevel()
		self.text:SetFormattedText(displayString, L["Item Level"], E.db.ilvldt.ilvl == "equip" and DecRound(equipped, E.db.ilvldt.precision) or DecRound(total, E.db.ilvldt.precision))
		
		specId = PlayerUtil_GetCurrentSpecID()
		if specId then 
			lastSelectedId = C_ClassTalents_GetLastSelectedSavedConfigID(specId) or C_ClassTalents_GetActiveConfigID()
		end
	end
end

local function ValueColorUpdate(self, hex, r, g, b)
	displayString = strjoin("", "|cffffffff%s:|r", " ", hex, "%s|r")
	hexColor = hex or "ffffff"
	OnEvent(self)
end

P["ilvldt"] = {
	["ilvl"] = "equip",
	["precision"] = 2,
	["showItem"] = true,
	["showTalentBuild"] = false,
}

local function InjectOptions()
	if not E.Options.args.Crackpotx then
		E.Options.args.Crackpotx = ACH:Group(L["Plugins by |cff0070deCrackpotx|r"])
	end
	if not E.Options.args.Crackpotx.args.thanks then
		E.Options.args.Crackpotx.args.thanks = ACH:Description(L["Thanks for using and supporting my work!  -- |cff0070deCrackpotx|r\n\n|cffff0000If you find any bugs, or have any suggestions for any of my addons, please open a ticket at that particular addon's page on CurseForge."], 1)
	end

	E.Options.args.Crackpotx.args.ilvldt = ACH:Group(L["Item Level Datatext"], nil, nil, nil, function(info) return E.db.ilvldt[info[#info]] end, function(info, value) E.db.ilvldt[info[#info]] = value; DT:ForceUpdate_DataText(L["Item Level (Improved)"]) end)
	E.Options.args.Crackpotx.args.ilvldt.args.ilvl = ACH:Select(L["iLvl Display"], L["Select which item level you want to display in the datatext, total or equipped."], 1, { ["equip"] = L["Equipped"], ["total"] = L["Total"] })
	E.Options.args.Crackpotx.args.ilvldt.args.precision = ACH:Range(L["Precision"], L["Number of decimal places to round to for the average item level."], 2, { min = 0, max = 5, step = 1 })
	E.Options.args.Crackpotx.args.ilvldt.args.showItem = ACH:Toggle(L["Show Item Name"], L["Show item name in the tooltip."], 3)
	E.Options.args.Crackpotx.args.ilvldt.args.showTalentBuild = ACH:Toggle(L["Show Talent Build"], L["Show talent build in the tooltip."], 4)
end

EP:RegisterPlugin(..., InjectOptions)
DT:RegisterDatatext(L["Item Level (Improved)"], nil, {"PLAYER_ENTERING_WORLD", "ELVUI_FORCE_UPDATE", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_LOOT_SPEC_UPDATED", "TRAIT_CONFIG_DELETED", "TRAIT_CONFIG_UPDATED"}, OnEvent, OnUpdate, OnClick, OnEnter, nil, L["Item Level (Improved)"], nil, ValueColorUpdate)
