Localization.SetAddonDefault("RepBar", "enUS")
local function TEXT(key) return Localization.GetClientString("RepBar", key) end

RBar = {
  defaultframe = "ChatFrame1",
  Units = {
    [1] = TEXT("HATED"),
    [2] = TEXT("HOSTILE"),
    [3] = TEXT("UNFRIENDLY"),
    [4] = TEXT("NEUTRAL"),
    [5] = TEXT("FRIENDLY"),
    [6] = TEXT("HONORED"),
    [7] = TEXT("REVERED"),
    [8] = TEXT("EXALTED"),
    [9] = TEXT("MAXEXALTED")
  },
  UnitsFriends = {
    [1] = TEXT("STRANGER"),      --     0 -  8400
    [2] = TEXT("ACQUAINTANCE"),  --  8400 - 16800
    [3] = TEXT("BUDDY"),         -- 16800 - 25200
    [4] = TEXT("FRIEND"),        -- 25200 - 33600
    [5] = TEXT("GOODFRIEND"),    -- 33600 - 42000
    [6] = TEXT("BESTFRIEND")     -- 42000 - 42999
  },
  Color = {
    R = 1,
    G = 1,
    B = 0
  },
	paragonIDs = {{"Court of Farondis", 1900},{"Dreamweavers", 1883}, {"Highmountain Tribe", 1828}, {"The Nightfallen", 1859}, {"The Wardens", 1894}, {"Valarjar", 1948}, {"Armies of Legionfall", 2045}},
	Factions = {},
  BufferedRepGain = "",
  AmountGainedInterval = 10,
  AmountGained = 0,
  SessionTime = 0,
  TimeSave = 0
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
  -- Register the game events neccesary for the addon
  self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE") -- changes in faction come in on this channel
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("VARIABLES_LOADED")
  self:RegisterEvent("WORLD_MAP_UPDATE")
  self:RegisterEvent("CHAT_MSG_SYSTEM") -- New factions come in on this channel
	self:RegisterEvent("ARTIFACT_XP_UPDATE")

  -- Register our slash command
  SLASH_RepBar1 = "/RepBar"
  SLASH_RepBar2 = "/rb"
  SlashCmdList["RepBar"] = function(msg)
    RepBar(msg)
  end
  -- Printing Message in Chat Frame
  if DEFAULT_CHAT_FRAME then
    ChatFrame1:AddMessage(TEXT("LOADEDSTR") .. " 1.6.33", 1, 1, 0)
  end
	-- RBar.f = CreateFrame("Frame", "MainWindow", UIParent)
	-- RBar.f:SetPoint("CENTER",0,0)
	-- RBar.f:SetMovable(true)
	-- RBar.f:SetFrameStrata("TOOLTIP")
	-- RBar.f:SetFrameLevel(100) -- prevent weird interlacings with other tooltips
	-- RBar.f:SetClampedToScreen(true)
	-- RBar.f:EnableMouse(true)
	-- RBar.f:SetUserPlaced(true)
	-- RBar.f:SetAlpha(0.5)
	-- RBar.f:SetSize(200,200)
	-- RBar.f:Show()
  -- Don't let this function run more than once
  RepBar_OnLoad = nil
end

function RepBar_Window()
		for k, v in pairs(RBar.paragonIDs) do
			local factionRowName = _G["RepBar"..k]:GetName()
			local factionTitle = _G[factionRowName.."FactionName"]
			local factionBar = _G["RepBar"..k.."ReputationBar"];
			local factionStanding = _G["RepBar"..k.."ReputationBarFactionStanding"];
			
			FactionName, ParagonEarned, rewardWaiting, standingId = RepBar_PrintParagon(v[1],_,false)
			factionTitle:SetText(FactionName)
			factionBar:SetValue(ParagonEarned)
			if standingId <8 then factionStanding:SetText("Not Exalted") else factionStanding:SetText(ParagonEarned.."/10000") end
			factionBar.BonusIcon:SetShown(rewardWaiting)
			if rewardWaiting then factionBar.BonusIcon.Glow.GlowAnim:Play() end
		end
end

function RepBar_UpdateFactions()
  local factionIndex = 1
  local lastFactionName = ""

  -- update known factions
  repeat
    local name = GetFactionInfo(factionIndex)
    if name == lastFactionName then break end
    lastFactionName = name
    if name then
      if not Rbl[name] then
        Rbl[name] = {
          gained = 0
        }
      end
    end
    factionIndex = factionIndex + 1
  until factionIndex > 200
end

function RepBar_LoadSavedVars()
  if not Rb_version then
    Rb_version = 180
  end

  if not Rb_save then
    Rb_save = {
      AnnounceLeft = true,
      RepChange = true,
      ChangeBar = true,
      frame = true,
      ATimeLeft = true,
      Guild = true,
      Color = {
        id = 4,
        R = 1,
        G = 1,
        B = 0
      },
      AmountGainedInterval = 1
    }
    ChatFrame1:AddMessage(TEXT("NEWLOADSTR"), 1, 1, 0)
  end

  if Rb_version < 170 then
    Rb_save.ATimeLeft = true
    Rb_save.AmountGainedInterval = Rb_save.AmountGainedLevel
    Rb_save.Color = {
      id = Rb_save.colorid,
      R = Rb_save.colora,
      G = Rb_save.colorb,
      B = Rb_save.colorc
    }
    Rb_version = 180
  end
  if Rb_version < 180 then
    Rb_save.Guild = true
  end

  if Rb_save.frame then
    RBar.frame = _G["ChatFrame1"]
  else
    RBar.frame = _G["ChatFrame2"]
  end

  RBar.Color.R = Rb_save.Color.R
  RBar.Color.G = Rb_save.Color.G
  RBar.Color.B = Rb_save.Color.B
  RBar.AmountGainedInterval = Rb_save.AmountGainedInterval
  RBar.ChangeBar = Rb_save.ChangeBar

  Rb_Status()
end

------------
-- Event Functions
------------
function RepBar_OnEvent(self, event, ...)
  local arg1 = ...
	if event == "PLAYER_ENTERING_WORLD"	then if notran then paragons = RepBar_ParagonInit() end end

  if event == "VARIABLES_LOADED" then
    RepBar_LoadSavedVars()
    return
  end
	
  -- Event fired when the player gets, or loses, rep in the chat frame
  if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" or event == "CHAT_MSG_SYSTEM" then
    RepBar_UpdateFactions()

    if event == "CHAT_MSG_SYSTEM" then
      if RBar.BufferedRepGain ~= "" then
        arg1 = RBar.BufferedRepGain
        RBar.BufferedRepGain = ""
      end
    end
    -- Reputation with <REPNAME> increased by <AMOUNT>.
    local HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, TEXT("REPMATCHSTR"))
		if HasIndexStart ~= nil then
			RepBar_PrintRep(FactionName, AmountGained)
		else
			return
    end
		RBar.BufferedRepGain = ""		
    return
	elseif event == "ARTIFACT_XP_UPDATE" then
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
    if C_Reputation.IsFactionParagon(factionID) then
			paragonValue, threshold, rewardQuestID, rewardWaiting = C_Reputation.GetFactionParagonInfo(factionID)
		end
    if name == lastFactionName then break end
    lastFactionName = name

    if name == FactionName then
      return factionIndex, standingId, bottomValue, topValue, earnedValue, C_Reputation.IsFactionParagon(factionID), paragonValue, threshold, rewardWaiting
    end

    factionIndex = factionIndex + 1
  until factionIndex > 300
end

function RepBar_ParagonInit()
	local paragons = {}
	for index, value in ipairs(RBar.paragonIDs) do
		local repu,_,_,_ = C_Reputation.GetFactionParagonInfo(value[2])
		table.insert(paragons, {value[1], repu, repu})
	end
	notran=false
	return paragons
end

function RepBar_PrintRep(FactionName, AmountGained)
	if FactionName == TEXT("GUILD") then
		if not Rb_save.Guild then
			return
		end
		FactionName = GetGuildInfo("player");
	end

	local RepIndex, standingId, bottomValue, topValue, earnedValue, isParagon= RepBar_GetRepMatch(FactionName)
	AmountGained = AmountGained + 0 -- ensure that the string value is converted to an integer
	local ind = 1
	local knownFac = false
	if isParagon then
		RepBar_PrintParagon(FactionName, AmountGained, true)
		RepBar_Window()
		return true
	end
	for index, value in ipairs(RBar.Factions) do
		if value[1] == FactionName then
			knownFac = true
			ind = index
		end
	end

	if knownFac then
		RBar.Factions[ind][2] = RBar.Factions[ind][2] + AmountGained
	else
		table.insert(RBar.Factions, {FactionName, AmountGained})
	end
	

	-- Using the string we just made, sending to Match function
	
	if RepIndex ~= nil then
		local nextStandingId = standingId + 1
		local RepLeftToLevel = 0

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
			RepLeftToLevel = topValue - earnedValue
		end
		if standingId == 8 then
			RBar.frame:AddMessage("|cFF9999ffYou are exalted with " .. FactionName)
		else
			local RepNextLevelName = RepBar_GetNextRepLevelName(FactionName, nextStandingId)

			RepScaleDone = string.rep("¦",(1-(RepLeftToLevel/(topValue-bottomValue)))*60)
			RepScaleToDo = string.rep("¦",(RepLeftToLevel/(topValue-bottomValue))*60)
			for index, value in ipairs(RBar.Factions) do
				if value[1] == FactionName then
					sessionGained = value[2]
				end
			end
			RBar.frame:AddMessage(string.format(TEXT("REPSTRFULL"), AmountGained, FactionName, sessionGained, RepScaleDone, RepScaleToDo, (earnedValue-bottomValue), (topValue-bottomValue), RepNextLevelName) , RBar.Color.R, RBar.Color.G, RBar.Color.B)
			RBar.AmountGained = 0
		end
	else
		RBar.BufferedRepGain = arg1
		RBar.frame:AddMessage(TEXT("NEWFACTION"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
	end
end

function RepBar_PrintSession()
	for index, value in ipairs(RBar.Factions) do
		RBar.frame:AddMessage("|cFF9999ffEarned " .. value[2] .. " reputation with " .. value[1])
	end
	for index,value in ipairs(paragons) do
		if value[2] ~= nil then
			local result = value[3]-value[2]
			if result ~= 0 then RBar.frame:AddMessage("|cFF9999ffEarned " .. result .. " reputation with " .. value[1]) end
		end
	end
end

function RepBar_PrintParagon(FactionName, AmountGained, Verbose)
	local _, standingId, _, _, _, _, paragonValue, threshold, rewardWaiting= RepBar_GetRepMatch(FactionName)
	
	if standingId < 8 then
		if Verbose then print("|cFFFFFF00You are not exalted with " .. FactionName) end
	else
		for index, value in ipairs(paragons) do
			if FactionName == value[1] then
				sessionParagon = paragonValue-value[2]
			end
		end
		while paragonValue > 9999 do
			paragonValue = paragonValue - 10000
		end
	
		if rewardWaiting and Verbose then RBar.frame:AddMessage("|cFFFFFF00" .. FactionName .. " cache is ready for pickup.") end

		local RepScaleToDo = string.rep("¦",(1-(paragonValue/threshold))*60)
		local RepScaleDone = string.rep("¦",(paragonValue/threshold)*60)	
		if Verbose then RBar.frame:AddMessage(string.format(TEXT("PARAGON"), AmountGained, FactionName, sessionParagon, RepScaleDone, RepScaleToDo, paragonValue, threshold) , RBar.Color.R, RBar.Color.G, RBar.Color.B) end
	end
	return FactionName, paragonValue, rewardWaiting, standingId
end


function RepBar_PrintAP()
	local function comma_value(n)
		local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
		return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
	end
	local artifactItemID, _, _, _, APvalue, artifactPointsSpent, _, _, _, _, _, _, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo()
	local numPoints = 0
	local APtop = C_ArtifactUI.GetCostForPointAtRank(artifactPointsSpent,artifactTier)
	local nextRank = artifactPointsSpent + 1
	while APvalue >= APtop and APtop > 0 do
		numPoints = numPoints + 1
		APvalue = APvalue - APtop
		APtop = C_ArtifactUI.GetCostForPointAtRank(artifactPointsSpent+numPoints,artifactTier)
	end
	local APScaleToDo = string.rep("¦",(1-(APvalue/APtop))*60)
	local APScaleDone = string.rep("¦",(APvalue/APtop)*60)
	if numPoints > 0 then print("|cFFFFFF00"..numPoints.." traits ready.") end
	RBar.frame:AddMessage(string.format(TEXT("ARTIFACT"), nextRank+numPoints, comma_value(APtop-APvalue), APScaleDone, APScaleToDo, comma_value(APvalue), comma_value(APtop)) , RBar.Color.R, RBar.Color.G, RBar.Color.B)
end

function RepBar_OnUpdate(self, elapsed)
  RBar.TimeSave = RBar.TimeSave + elapsed
  if RBar.TimeSave > 0.5 then
    RBar.SessionTime = RBar.SessionTime + RBar.TimeSave
    RBar.TimeSave = 0
  end
end

------------
-- Printing Functions
------------
function Rb_Status()
  -- RBar.frame:AddMessage(TEXT("STATUS"), RBar.Color.R, RBar.Color.G, RBar.Color.B)

  -- if Rb_save.RepChange == true then
    -- RBar.frame:AddMessage("RepBar " .. TEXT("ANNOUNCE"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- else
    -- RBar.frame:AddMessage("RepBar " .. TEXT("NOANNOUNCE"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- end
  -- if Rb_save.ChangeBar == true then
    -- RBar.frame:AddMessage("RepBar " .. TEXT("CHANGEBAR"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- else
    -- RBar.frame:AddMessage("RepBar " .. TEXT("NOCHANGEBAR"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- end
  -- if Rb_save.AnnounceLeft == true then
    -- RBar.frame:AddMessage("RepBar " .. string.format(TEXT("REPLEFT"), RBar.AmountGainedInterval), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- else
    -- RBar.frame:AddMessage("RepBar " .. TEXT("NOREPLEFT"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- end
  -- if Rb_save.ATimeLeft == true then
    -- RBar.frame:AddMessage("RepBar " .. string.format(TEXT("TIMELEFT"), RBar.AmountGainedInterval), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- else
    -- RBar.frame:AddMessage("RepBar " .. TEXT("NOTIMELEFT"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- end
  -- if Rb_save.Guild == true then
    -- RBar.frame:AddMessage("RepBar " .. string.format(TEXT("PROCESSGUILD"), RBar.AmountGainedInterval), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- else
    -- RBar.frame:AddMessage("RepBar " .. TEXT("NOPROCESSGUILD"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- end
  -- if Rb_save.frame == true then
    -- RBar.frame:AddMessage("RepBar " .. TEXT("SHOWCHATFRAME"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- else
    -- RBar.frame:AddMessage("RepBar " .. TEXT("SHOWCOMBATLOG"), RBar.Color.R, RBar.Color.G, RBar.Color.B)
  -- end
end

function RepBar_PrintHelp()
  RBar.frame:AddMessage(" ")
  RBar.frame:AddMessage("-----------------------------------")
  RBar.frame:AddMessage(TEXT("HELPTITLE"))
  RBar.frame:AddMessage(TEXT("HELPSLASH"))
  RBar.frame:AddMessage("help -- " .. TEXT("HELPHELP"))
  RBar.frame:AddMessage("ap -- Show current artifact weapon trait progress")
  RBar.frame:AddMessage("cache -- Show current paragon cache progress")
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
    timeText = timeText..format("%d" .. TEXT("DAYS") .. " ", days)
  end
  if hours ~= 0 then
    timeText = timeText..format("%d" .. TEXT("HOURS") .. " ", hours)
  end
  if minutes ~= 0 then
    timeText = timeText..format("%d" .. TEXT("MINUTES") .. " ", minutes)
  end
  if seconds ~= 0 then
    timeText = timeText..format("%d" .. TEXT("SECONDS") .. " ", seconds)
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
		elseif command == "cache" then
			for k, v in pairs(RBar.paragonIDs) do
				_ = RepBar_PrintParagon(v[1],_,true)
			end
		elseif command == "ap" then
			RepBar_PrintAP()
    elseif command == "help" then
      RepBar_PrintHelp()
		elseif command == "test1" then
			RepBar_PrintRep("Arakkoa Outcasts", 10)
		elseif command == "testpara" then
			_ = RepBar_PrintParagon("Court of Farondis",_,true)
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
  table.insert(FriendRep, TEXT("FUNG"))
  table.insert(FriendRep, TEXT("CHEE"))
  table.insert(FriendRep, TEXT("ELLA"))
  table.insert(FriendRep, TEXT("FISH"))
  table.insert(FriendRep, TEXT("GINA"))
  table.insert(FriendRep, TEXT("HAOHAN"))
  table.insert(FriendRep, TEXT("JOGU"))
  table.insert(FriendRep, TEXT("HILLPAW"))
  table.insert(FriendRep, TEXT("SHO"))
  table.insert(FriendRep, TEXT("TINA"))
  table.insert(FriendRep, TEXT("NAT"))

  return tContains(FriendRep, FactionName)
end
