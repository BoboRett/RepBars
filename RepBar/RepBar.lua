RBar = {
    Units = {
        [1] = "Hated",
        [2] = "Hostile",
        [3] = "Unfriendly",
        [4] = "Neutral",
        [5] = "Friendly",
        [6] = "Honored",
        [7] = "Revered",
        [8] = "Exalted",
        [9] = "Max Exalted"
    },
    UnitsFriends = {
        [1] = "Stranger",      --     0 -  8400
        [2] = "Acquaintance",  --  8400 - 16800
        [3] = "Buddy",         -- 16800 - 25200
        [4] = "Friend",        -- 25200 - 33600
        [5] = "Good Friend",   -- 33600 - 42000
        [6] = "Best Friend"    -- 42000 - 42999
    },
    Color = {
        R = 1,
        G = 1,
        B = 0
    },
    Factions = {},
    AmountGainedInterval = 10,
    AmountGained = 0,
    SessionTime = 0,
    TimeSave = 0,
    frame = _G["ChatFrame1"]
}

Rbl = {}
paragons = {}
notran=true

------------
-- Load Function
------------
function RepBar_OnLoad(self)
    self.registry = {
        id = "RepBar"
    }

    hooksecurefunc("ReputationFrame_Update", RepBar_Window)

    self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
    self:RegisterEvent("CHAT_MSG_SYSTEM")
    self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED")

    -- Register our slash command
    SLASH_RepBar1 = "/RepBar"
    SLASH_RepBar2 = "/rb"
    SlashCmdList["RepBar"] = function(msg)
        RepBar(msg)
    end
    -- Printing Message in Chat Frame
    if DEFAULT_CHAT_FRAME then
        ChatFrame1:AddMessage("RepBar Loaded! Version: 1.6.33", 1, 1, 0)
    end

    -- Don't let this function run more than once
    RepBar_OnLoad = nil
end

function RepBar_Window()

    local numFactions = GetNumFactions();

    for i=1, NUM_FACTIONS_DISPLAYED, 1 do

        local factionRow = _G["ReputationBar"..i];
        local factionBar = _G["ReputationBar"..i.."ReputationBar"];
        local factionIndex = factionRow.index;

        if ( factionIndex <= numFactions ) then

            local name, _, _, _, _, _, _, _, _, _, _, _, _, factionID = GetFactionInfo(factionIndex)

            if ( factionID and C_Reputation.IsFactionParagon(factionID) ) then

                local currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevelForParagon = C_Reputation.GetFactionParagonInfo(factionID)

                if not tooLowLevelForParagon then

                    factionBar:SetMinMaxValues(0, 10000);
                    factionBar:SetValue( currentValue % 10000 );
                    factionRow.rolloverText = BreakUpLargeNumbers( currentValue % 10000 ).." / ".."10,000";

                    if hasRewardPending then
                        factionBar:SetStatusBarColor(1, 0.8, 0.1);
                    else
                        factionBar:SetStatusBarColor(1, 0.1, 1);
                    end

                end

            end

        end

    end

end

------------
-- Event Functions
------------
function RepBar_OnEvent(self, event, ...)
    local arg1 = ...

    -- Event fired when the player gets, or loses, rep in the chat frame
    if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" or event == "CHAT_MSG_SYSTEM" then

        -- Reputation with <REPNAME> increased by <AMOUNT>.
        local HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, "Reputation with (.*) increased by (%d+).")
		if HasIndexStart ~= nil then
			RepBar_PrintRep(FactionName, AmountGained)
		else
			return
        end
        return
	elseif event == "AZERITE_ITEM_EXPERIENCE_CHANGED" then
		RepBar_PrintAP()
	end

end

------------
-- Reputation parsing and math function
------------
function RepBar_GetRepMatch(FactionName)
    local factionIndex = 1
    local lastFactionName
    local paragonValue = 0
    local threshold = 0
    repeat
        local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(factionIndex)
		if factionID ~= nil then
			if C_Reputation.IsFactionParagon(factionID) then
				paragonValue, threshold, rewardQuestID, rewardWaiting = C_Reputation.GetFactionParagonInfo(factionID)
			end
			if name == lastFactionName then break end
			lastFactionName = name

			if name == FactionName then
				return factionIndex, standingId, bottomValue, topValue, earnedValue, C_Reputation.IsFactionParagon(factionID), paragonValue, threshold, rewardWaiting
			end

		end
		factionIndex = factionIndex + 1

    until factionIndex > GetNumFactions()
end

function RepBar_PrintRep(FactionName, AmountGained)
	if FactionName == "Guild" then
		if not Rb_save.Guild then
			return
		end
		FactionName = GetGuildInfo("player");
	end

	local RepIndex, standingId, bottomValue, topValue, earnedValue, isParagon, paragonValue, threshold = RepBar_GetRepMatch(FactionName)
	AmountGained = AmountGained + 0 -- ensure that the string value is converted to an integer
	local ind = 1
	local knownFac = RBar.Factions[FactionName] ~= nil

	if knownFac then
		RBar.Factions[FactionName] = RBar.Factions[FactionName] + AmountGained
	else
		RBar.Factions[FactionName] = AmountGained
	end

	-- Using the string we just made, sending to Match function

	if RepIndex ~= nil then
		local nextStandingId = standingId + 1
		local RepLeftToLevel = 0
        local RepNextLevelName

		-- Friend reputation doesn't have same amount of faction needed for each level
		-- and the standing id doesn't line up either
		if isFriendRep(FactionName) then
			local tmpVal = earnedValue / 8400
			local tmpValInt = floor(tmpVal)
			nextStandingId = tmpValInt + 2
			if nextStandingId > 6 then
				return
			end
			RepLeftToLevel = 8400 - (8400 * (tmpVal - tmpValInt))
		else
			if nextStandingId > 9 then
				return
			end

		end
		if standingId == 8 and not isParagon then
			RBar.frame:AddMessage("|cFF9999ffYou are exalted with " .. FactionName)
		else

            if isParagon and standingId == 8 then

                RepNextLevelName = "next Cache"
                earnedValue = paragonValue % threshold
                topValue = threshold
                bottomValue = 0

            else

	            RepNextLevelName = RepBar_GetNextRepLevelName(FactionName, nextStandingId)

            end

            RepLeftToLevel = topValue - earnedValue

			RepScaleDone = string.rep("¦",(1-(RepLeftToLevel/(topValue-bottomValue)))*60)
			RepScaleToDo = string.rep("¦",(RepLeftToLevel/(topValue-bottomValue))*60)

			RBar.frame:AddMessage(string.format("|cFF9999ff+%d reputation - %s (%s this session)|n -[|cFF00ccff%s|cFFFFFF00%s|cFF9999ff]- %s / %s to %s", BreakUpLargeNumbers( AmountGained ), FactionName, RBar.Factions[FactionName] or 0, RepScaleDone, RepScaleToDo, BreakUpLargeNumbers( earnedValue - bottomValue ), BreakUpLargeNumbers( topValue - bottomValue ), RepNextLevelName) , RBar.Color.R, RBar.Color.G, RBar.Color.B)
			RBar.AmountGained = 0
		end
	end
end

function RepBar_PrintSession()
	for faction, value in pairs(RBar.Factions) do
		RBar.frame:AddMessage("|cFF9999ffEarned " .. value .. " reputation with " .. faction)
	end
end

function RepBar_PrintAP()
	local function comma_value(n)
		local left, num, right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
		return left..( num:reverse():gsub( '(%d%d%d)', '%1,' ):reverse() )..right
	end
	local CurrentXP, TotalXp = C_AzeriteItem.GetAzeriteItemXPInfo(C_AzeriteItem.FindActiveAzeriteItem())
	local CurrentLevel = C_AzeriteItem.GetPowerLevel(C_AzeriteItem.FindActiveAzeriteItem())
	local APScaleToDo = string.rep("¦",(1-(CurrentXP/TotalXp))*60)
	local APScaleDone = string.rep("¦",(CurrentXP/TotalXp)*60)
	RBar.frame:AddMessage(string.format("|cFF9999ff Progress to rank %s - %s to go |n -\[|cFF00ccff%s|cFFFFFF00%s|cFF9999ff\]- %s/%s", CurrentLevel + 1, comma_value(TotalXp-CurrentXP), APScaleDone, APScaleToDo, comma_value(CurrentXP), comma_value(TotalXp)) , RBar.Color.R, RBar.Color.G, RBar.Color.B)
end

function RepBar_OnUpdate(self, elapsed)
  RBar.TimeSave = RBar.TimeSave + elapsed
  if RBar.TimeSave > 0.5 then
    RBar.SessionTime = RBar.SessionTime + RBar.TimeSave
    RBar.TimeSave = 0
  end
end

function RepBar_PrintHelp()
  RBar.frame:AddMessage(" ")
  RBar.frame:AddMessage("-----------------------------------")
  RBar.frame:AddMessage("RepBar commands help:")
  RBar.frame:AddMessage("Use /repbar <command> or /rb <command> to perform the following commands:")
  RBar.frame:AddMessage("help -- You are viewing it!")
  RBar.frame:AddMessage("ap -- Show current artifact weapon trait progress")
  RBar.frame:AddMessage("session -- Show current session's progress")
	  RBar.frame:AddMessage("-----------------------------------")
  RBar.frame:AddMessage(" ")
end

function RepBar_TimeText(s)
  local days = floor(s/24/60/60); s = mod(s, 24*60*60)
  local hours = floor(s/60/60); s = mod(s, 60*60)
  local minutes = floor(s/60); s = mod(s, 60)
  local seconds = s

  local timeText = ""
  if days ~= 0 then
    timeText = timeText..format("%d d", days)
  end
  if hours ~= 0 then
    timeText = timeText..format("%d h", hours)
  end
  if minutes ~= 0 then
    timeText = timeText..format("%d m", minutes)
  end
  if seconds ~= 0 then
    timeText = timeText..format("%d s", seconds)
  end

  return timeText
end

------------
-- Slash Function
------------
function RepBar(msg)
  if msg then
    local command = string.lower(msg)
    if command == "" then
			if RepBarFrame:IsVisible() then RepBarFrame:Hide() else	RepBarFrame:Show()	end
      RepBar_Window()
	elseif command == "ap" then
		RepBar_PrintAP()
    elseif command == "help" then
      RepBar_PrintHelp()
	elseif command == "test1" then
		RepBar_PrintRep("The Consortium", 10)
	elseif command == "testpara" then
		_ = RepBar_PrintRep("Court of Farondis", 10, true)
	elseif command == "session" then
		RepBar_PrintSession()
    else
      RepBar_PrintHelp()
    end
  end
end

function RepBar_GetNextRepLevelName(FactionName, standingId)
    local RepNextLevelName = ""

    if isFriendRep(FactionName) and standingId <= 6 then
        RepNextLevelName = RBar.UnitsFriends[standingId]
    elseif (standingId <= 9) then
        RepNextLevelName = RBar.Units[standingId]
    end

    return RepNextLevelName
end

function isFriendRep(FactionName)
  local FriendRep = {}
  table.insert(FriendRep, "Farmer Fung")
  table.insert(FriendRep, "Chee Chee")
  table.insert(FriendRep, "Ella")
  table.insert(FriendRep, "Fish Fellreed")
  table.insert(FriendRep, "Gina Mudclaw")
  table.insert(FriendRep, "Haohan Mudclaw")
  table.insert(FriendRep, "Jogu the Drunk")
  table.insert(FriendRep, "Old Hillpaw")
  table.insert(FriendRep, "Sho")
  table.insert(FriendRep, "Tina Mudclaw")
  table.insert(FriendRep, "Nat Pagle")

  return tContains(FriendRep, FactionName)
end
