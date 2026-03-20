local DEBUG = false

function arf_print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function debug_print(msg)
  if DEBUG then DEFAULT_CHAT_FRAME:AddMessage(msg) end
end

AutoPromote = CreateFrame("Frame")

local defaults = {
  enabled = true,
  watch_names = {},
  promote_mages = false,
  promote_paladins = false,
}

local function Promote()
  for i = 1, GetNumRaidMembers() do
    local name,rank,_,_,class,_ = GetRaidRosterInfo(i)
    name = string.lower(name)
    if (AutoPromoteDB.promote_mages and class == "Mage") or (AutoPromoteDB.promote_paladins and class == "Paladin") then
      PromoteToAssistant(name)
    elseif rank == 0 then
      if AutoPromoteDB.watch_names[name] then
        PromoteToAssistant(name)
      end
    end
  end
end

local function ResetAll()
  for i = 1, GetNumRaidMembers() do
    local name,rank,_,_,class,_ = GetRaidRosterInfo(i)
    if rank == 1 then
      if string.lower(n) == string.lower(name) then
        DemoteAssistant(name)
        break
      end
    end
  end
end

--------------------
-- hooks
--------------------
UnitPopupButtons["RAID_AUTOPROMOTE"] = { text = "AutoPromote", checkable = 1, dist = 0 };
UnitPopupMenus["RAID"] = { "RAID_LEADER", "LOOT_PROMOTE", "RAID_PROMOTE", "RAID_AUTOPROMOTE", "RAID_DEMOTE", "RAID_REMOVE", "REPORT", "IGNORE", "CANCEL" };

local orig_UnitPopup_OnClick = UnitPopup_OnClick
UnitPopup_OnClick = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  local dropdownFrame = _G[UIDROPDOWNMENU_INIT_MENU];
  local button = this.value;
  local unit = dropdownFrame.unit;
  local name = dropdownFrame.name;
  local server = dropdownFrame.server;

  if button == "RAID_AUTOPROMOTE" then
    name = string.lower(name)
    if this.checked then
      AutoPromoteDB.watch_names[name] = false
      if IsRaidLeader("player") then DemoteAssistant(name) end
    else
      AutoPromoteDB.watch_names[name] = true
      if IsRaidLeader("player") then PromoteToAssistant(name) end
    end
  end
  orig_UnitPopup_OnClick(a1,a2,a3,a4,a5,a6,a7,a8,a9)
end

local orig_UnitPopup_ShowMenu = UnitPopup_ShowMenu
function UnitPopup_ShowMenu2(dropdownMenu, which, unit, name, userData)
	-- Init variables
	local server;
	dropdownMenu.which = which;
	dropdownMenu.unit = unit;
	if ( unit and not name ) then
		name, server = UnitName(unit, true);
	end
	dropdownMenu.name = name;
	dropdownMenu.userData = userData;
	dropdownMenu.server = server;

	-- Determine which buttons should be shown or hidden
	UnitPopup_HideButtons();

	-- If only one menu item (the cancel button) then don't show the menu
	local count = 0;
	for index, value in ipairs(UnitPopupMenus[which]) do
		if ( UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL][index] == 1 and value ~= "CANCEL" ) then
			count = count + 1;
		end
	end
	if ( count < 1 ) then
		return;
	end

	local lootMethod = GetLootMethod();
	local lootThreshold = GetLootThreshold();
	-- Determine which loot method and which loot threshold are selected and set the corresponding buttons to the same text
	dropdownMenu.selectedLootMethod = UnitLootMethod[lootMethod].text;
	dropdownMenu.selectedLootThreshold = _G["ITEM_QUALITY"..lootThreshold.."_DESC"];
	UnitPopupButtons["LOOT_METHOD"].text = dropdownMenu.selectedLootMethod;
	UnitPopupButtons["LOOT_METHOD"].tooltipText = UnitLootMethod[lootMethod].tooltipText;
	UnitPopupButtons["LOOT_THRESHOLD"].text = dropdownMenu.selectedLootThreshold;
	-- This allows player to view loot settings if he's not the leader
	if ( IsPartyLeader() ) then
		UnitPopupButtons["LOOT_METHOD"].nested = 1;
		UnitPopupButtons["LOOT_THRESHOLD"].nested = 1;
	else
		UnitPopupButtons["LOOT_METHOD"].nested = nil;
		UnitPopupButtons["LOOT_THRESHOLD"].nested = nil;
	end

	-- If level 2 dropdown
	local info;
	local color;
	if ( UIDROPDOWNMENU_MENU_LEVEL == 2 ) then
		dropdownMenu.which = UIDROPDOWNMENU_MENU_VALUE;
		-- Set which menu is being opened
		if not OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL] then OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL] = {} end
		OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].which = UIDROPDOWNMENU_MENU_VALUE;
		OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].name = name;
		OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].unit = unit;
		OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].userData = userData;
		OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].server = server;

		for index, value in ipairs(UnitPopupMenus[UIDROPDOWNMENU_MENU_VALUE]) do
			info = UIDropDownMenu_CreateInfo();
			info.text = UnitPopupButtons[value].text;
			info.owner = UIDROPDOWNMENU_MENU_VALUE;
			-- Set the text color
			color = UnitPopupButtons[value].color;
			if ( color ) then
				info.textR = color.r;
				info.textG = color.g;
				info.textB = color.b;
			end
			-- Icons
			info.icon = UnitPopupButtons[value].icon;
			info.tCoordLeft = UnitPopupButtons[value].tCoordLeft;
			info.tCoordRight = UnitPopupButtons[value].tCoordRight;
			info.tCoordTop = UnitPopupButtons[value].tCoordTop;
			info.tCoordBottom = UnitPopupButtons[value].tCoordBottom;
			-- Checked conditions
			if ( info.text == dropdownMenu.selectedLootMethod  ) then
				info.checked = 1;
			elseif ( info.text == dropdownMenu.selectedLootThreshold ) then
				info.checked = 1;
			elseif ( strsub(value, 1, 12) == "RAID_TARGET_" ) then
				info.checked = unit and GetRaidTargetIndex(unit) == index;
			end

			info.value = value;
			info.func = UnitPopup_OnClick;
			-- Setup newbie tooltips
			info.tooltipTitle = UnitPopupButtons[value].text;
			info.tooltipText = _G["NEWBIE_TOOLTIP_UNIT_"..value];
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		end
		return;
	end

	-- Add dropdown title
	if ( unit or name ) then
		info = UIDropDownMenu_CreateInfo();
		info.text = name or UNKNOWN;
		info.isTitle = 1;
		info.notCheckable = 1;
		UIDropDownMenu_AddButton(info);
	end

	-- Set which menu is being opened
	if not OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL] then OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL] = {} end
	OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].which = which;
	OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].name = name;
	OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].unit = unit;
	OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].userData = userData;
	OPEN_DROPDOWNMENUS[UIDROPDOWNMENU_MENU_LEVEL].server = server;

	-- Show the buttons which are used by this menu
	local tooltipText;
	for index, value in ipairs(UnitPopupMenus[which]) do
		if ( UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL][index] == 1 ) then
			info = UIDropDownMenu_CreateInfo();
			info.text = UnitPopupButtons[value].text;
			if ( value == "MOVE" ) then
				if ( dropdownMenu.unit == "player" ) then
					info.text = PlayerFrame.movable and UNIT_POPUP_FRAME_LOCK or UNIT_POPUP_FRAME_UNLOCK
				elseif ( dropdownMenu.unit == "target" ) then
					info.text = TargetFrame.movable and UNIT_POPUP_FRAME_LOCK or UNIT_POPUP_FRAME_UNLOCK
				end
			end
			info.value = value;
			info.owner = which;
			info.func = UnitPopup_OnClick;
			if ( not UnitPopupButtons[value].checkable ) then
				info.notCheckable = 1;
			end
			-- Text color
			if ( value == "LOOT_THRESHOLD" ) then
				-- Set the text color
				color = ITEM_QUALITY_COLORS[lootThreshold];
				info.textR = color.r;
				info.textG = color.g;
				info.textB = color.b;
			else
				color = UnitPopupButtons[value].color;
				if ( color ) then
					info.textR = color.r;
					info.textG = color.g;
					info.textB = color.b;
				end
			end
			-- Icons
			info.icon = UnitPopupButtons[value].icon;
			info.tCoordLeft = UnitPopupButtons[value].tCoordLeft;
			info.tCoordRight = UnitPopupButtons[value].tCoordRight;
			info.tCoordTop = UnitPopupButtons[value].tCoordTop;
			info.tCoordBottom = UnitPopupButtons[value].tCoordBottom;

			-- AutoPromote checked state
			if value == "RAID_AUTOPROMOTE" then
				if name and AutoPromoteDB.watch_names[string.lower(name)] then
					info.checked = 1
				end
			end

			-- Checked conditions
			if ( strsub(value, 1, 12) == "RAID_TARGET_" ) then
				info.checked = unit and GetRaidTargetIndex("target") == index;
			end
			if ( UnitPopupButtons[value].nested ) then
				info.hasArrow = 1;
			end

			-- Setup newbie tooltips
			info.tooltipTitle = info.text;
			tooltipText = _G["NEWBIE_TOOLTIP_UNIT_"..value] or UnitPopupButtons[value].tooltipText;
			info.tooltipText = tooltipText;
			UIDropDownMenu_AddButton(info);
		end
	end
	PlaySound("igMainMenuOpen");
end
UnitPopup_ShowMenu = UnitPopup_ShowMenu2
--------------------

local rcount = 0
local function OnEvent()
  if AutoPromoteDB.enabled and IsRaidLeader("player") then
    local new_rcount = GetNumRaidMembers()
    if event == ("RAID_ROSTER_UPDATE" or "PLAYER_ENTERING_WORLD") and new_rcount ~= rcount then
      rcount = new_rcount
      Promote()
    end
    if new_rcount == 0 then rcount = 0 end
  end
end

local function Init()
  if event == "ADDON_LOADED" and arg1 == "AutoPromote" then
    AutoPromote:UnregisterEvent("ADDON_LOADED")
    if not AutoPromoteDB then
      AutoPromoteDB = defaults -- initialize default settings
      else -- or check that we only have the current settings format
        local s = {}
        for k,v in pairs(defaults) do
          if AutoPromoteDB[k] == nil -- specifically nil
            then s[k] = defaults[k]
            else s[k] = AutoPromoteDB[k] end
        end
        AutoPromoteDB = s
    end
    AutoPromote:SetScript("OnEvent", OnEvent)
  end
end

AutoPromote:RegisterEvent("RAID_ROSTER_UPDATE")
AutoPromote:RegisterEvent("PLAYER_ENTERING_WORLD")
AutoPromote:RegisterEvent("ADDON_LOADED")
AutoPromote:SetScript("OnEvent", Init)

local function handleCommands(msg,editbox)
  local args = {};
  for word in string.gfind(msg,'%S+') do table.insert(args,string.lower(word)) end

  if args[1] == "toggle" then
    AutoPromoteDB.enabled = not AutoPromoteDB.enabled
    arf_print("AutoPromote toggled " .. (AutoPromoteDB.enabled and "on" or "off"))
  elseif args[1] == "add" then
    if args[2] then
      AutoPromoteDB.watch_names[args[2]] = true
      arf_print(args[2].." added to the watch list.")
    else
      arf_print("/autopromote add [name]")
    end
  elseif args[1] == "rem" then
    if args[2] then
      AutoPromoteDB.watch_names[args[2]] = nil
      arf_print(args[2].." removed from the watch list.")
    end
  elseif args[1] == "list" then
    local t = {}
    for name,_ in pairs(AutoPromoteDB.watch_names) do table.insert(t,name) end
    arf_print("Promotees: " .. table.concat(t, ", "))
  elseif args[1] == "mages" then
    AutoPromoteDB.promote_mages = not AutoPromoteDB.promote_mages
    arf_print("AutoPromote all mages: " .. (AutoPromoteDB.promote_mages and "on" or "off"))
		Promote()
  elseif args[1] == "paladins" then
    AutoPromoteDB.promote_paladins = not AutoPromoteDB.promote_paladins
    arf_print("AutoPromote all paladins: " .. (AutoPromoteDB.promote_paladins and "on" or "off"))
		Promote()
  elseif args[1] == "promote" then
    Promote()
  else
    arf_print("Type /autopromote followed by:")
    arf_print("[toggle] to enable addon.")
    arf_print("[list] to see who's on the watch list.")
    arf_print("[mages] to toggle promoting all mages.")
    arf_print("[promote] to run promotion manually.")
    arf_print("[add] to add a player to the promote watch list.")
    arf_print("[rem] to remove a player to the promote watch list.")
  end
end

SLASH_AUTOPROMOTE1 = "/autopromote";
SlashCmdList["AUTOPROMOTE"] = handleCommands
