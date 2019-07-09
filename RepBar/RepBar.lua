RBar = {
    StandingRanksFriends = {
        [1] = "Stranger",
        [2] = "Acquaintance",
        [3] = "Buddy",
        [4] = "Friend",
        [5] = "Good Friend",
        [6] = "Best Friend"
    },
    Colour = {
        R = 1,
        G = 1,
        B = 0
    },
    Factions = {},
    frame = _G["ChatFrame1"]
}

function RepBar_OnLoad( self )

    self.registry = {

        id = "RepBar"

    }

    hooksecurefunc( "ReputationFrame_Update", RepBar_Window )

    self:RegisterEvent( "CHAT_MSG_COMBAT_FACTION_CHANGE" )
    self:RegisterEvent( "CHAT_MSG_SYSTEM" )
    self:RegisterEvent( "AZERITE_ITEM_EXPERIENCE_CHANGED" )

    SLASH_RepBar1 = "/RepBar"
    SLASH_RepBar2 = "/rb"
    SlashCmdList["RepBar"] = function(msg)

        RepBar(msg)

    end


    RepBar_OnLoad = nil

end

function RepBar_Window()

    local numFactions = GetNumFactions()

    for i=1, NUM_FACTIONS_DISPLAYED do

        local factionRow = _G["ReputationBar"..i]
        local factionBar = _G["ReputationBar"..i.."ReputationBar"]
        local factionIndex = factionRow.index

        if ( factionIndex <= numFactions ) then

            local factionID = select( 14, GetFactionInfo( factionIndex ) )

            if ( factionID and C_Reputation.IsFactionParagon( factionID ) ) then

                local currentValue, _, _, hasRewardPending, notExalted = C_Reputation.GetFactionParagonInfo( factionID )

                if not notExalted then

                    factionBar:SetMinMaxValues( 0, 10000 )
                    factionBar:SetValue( currentValue % 10000 )
                    factionRow.rolloverText = BreakUpLargeNumbers( currentValue % 10000 ).." / ".."10,000"

                    if hasRewardPending then

                        factionBar:SetStatusBarColor( 1, 0.8, 0.1 )

                    else

                        factionBar:SetStatusBarColor( 0.6, 0.1, 1 )

                    end

                end

            end

        end

    end

end

function RepBar_OnEvent( self, event, ... )

    local args = ...

    if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" or event == "CHAT_MSG_SYSTEM" then

        local HasIndexStart, _, FactionName, AmountGained = string.find( args, "Reputation with (.*) increased by (%d+)." )

		if HasIndexStart ~= nil then

			RepBar_PrintRep( FactionName, AmountGained )

        end

        return

	elseif event == "AZERITE_ITEM_EXPERIENCE_CHANGED" then

		RepBar_PrintAP()

	end

end

function RepBar_GetRepMatch( FactionName )

    local factionIndex = 1
    local paragonValue = 0
    local threshold = 0

    while factionIndex <= GetNumFactions()  do

        local name, _, standingID, bottomValue, topValue, earnedValue, _, _, _, _, _, _, _, factionID = GetFactionInfo( factionIndex )

		if name == FactionName then

			return factionIndex, standingID, bottomValue, topValue, earnedValue, C_Reputation.IsFactionParagon( factionID )

		end

		factionIndex = factionIndex + 1

    end

end

function RepBar_PrintRep( FactionName, AmountGained )

    if FactionName == "Guild" then

		FactionName = GetGuildInfo( "player" )

    end

	local factionIndex, standingID, bottomValue, topValue, earnedValue, isParagon = RepBar_GetRepMatch( FactionName )

	if RBar.Factions[FactionName] ~= nil then

		RBar.Factions[FactionName] = RBar.Factions[FactionName] + AmountGained

	else

		RBar.Factions[FactionName] = AmountGained

	end

	if factionIndex ~= nil then

		local nextStandingId = standingID + 1
		local RepLeftToLevel = 0
        local NextRepLevelName

		if standingID == 8 and not isParagon then

			RBar.frame:AddMessage( "|cFF9999ffYou are exalted with " .. FactionName )

		else

            if isParagon and standingID == 8 then

                NextRepLevelName = "next Cache"
                local paragonValue, threshold = C_Reputation.GetFactionParagonInfo( select( 14, GetFactionInfo( factionIndex ) ) )
                earnedValue = paragonValue % threshold
                topValue = threshold
                bottomValue = 0

            else

	            NextRepLevelName = RepBar_NextRepLevelName( factionIndex, nextStandingId )

            end

            RepLeftToLevel = topValue - earnedValue

			RepScaleDone = string.rep( "¦", ( 1 - ( RepLeftToLevel / ( topValue - bottomValue ) ) ) * 60 )
			RepScaleToDo = string.rep( "¦", ( RepLeftToLevel / ( topValue - bottomValue ) ) * 60 )

			RBar.frame:AddMessage( string.format( "|cFF9999ff+%d reputation - %s (%s this session)|n -[|cFF00ccff%s|cFFFFFF00%s|cFF9999ff]- %s / %s to %s", BreakUpLargeNumbers( AmountGained ), FactionName, RBar.Factions[FactionName] or 0, RepScaleDone, RepScaleToDo, BreakUpLargeNumbers( earnedValue - bottomValue ), BreakUpLargeNumbers( topValue - bottomValue ), NextRepLevelName ) , RBar.Colour.R, RBar.Colour.G, RBar.Colour.B )

		end

	end

end

function RepBar_PrintSession()

	for faction, value in pairs( RBar.Factions ) do

		RBar.frame:AddMessage( "|cFF9999ffEarned "..value.." reputation with "..faction )

	end

end

function RepBar_PrintAP()

	local CurrentXP, TotalXp = C_AzeriteItem.GetAzeriteItemXPInfo( C_AzeriteItem.FindActiveAzeriteItem() )
	local CurrentLevel = C_AzeriteItem.GetPowerLevel( C_AzeriteItem.FindActiveAzeriteItem() )
	local APScaleToDo = string.rep( "¦" , ( 1 - ( CurrentXP / TotalXp ) ) * 60 )
	local APScaleDone = string.rep( "¦" , ( CurrentXP / TotalXp ) * 60 )

	RBar.frame:AddMessage( string.format( "|cFF9999ff Progress to rank %s - %s to go |n -\[|cFF00ccff%s|cFFFFFF00%s|cFF9999ff\]- %s/%s", CurrentLevel + 1, BreakUpLargeNumbers( TotalXp - CurrentXP ), APScaleDone, APScaleToDo, BreakUpLargeNumbers( CurrentXP ), BreakUpLargeNumbers( TotalXp ) ) , RBar.Colour.R, RBar.Colour.G, RBar.Colour.B )

end

function RepBar_PrintHelp()

    RBar.frame:AddMessage( " " )
    RBar.frame:AddMessage( "-----------------------------------" )
    RBar.frame:AddMessage( "RepBar commands help:" )
    RBar.frame:AddMessage( "Use /repbar <command> or /rb <command> to perform the following commands:" )
    RBar.frame:AddMessage( "help -- You're looking at it" )
    RBar.frame:AddMessage( "ap -- Show current artifact weapon trait progress" )
    RBar.frame:AddMessage( "session -- Show current session's progress" )
    RBar.frame:AddMessage( "-----------------------------------" )
    RBar.frame:AddMessage( " " )

end

function RepBar( cmd )
    if cmd then

        local command = string.lower( cmd )

        if command == "" then

            RepBar_PrintHelp()

        elseif command == "ap" then

            RepBar_PrintAP()

        elseif command == "help" then

            RepBar_PrintHelp()

        elseif command == "test1" then

            RepBar_PrintRep("The Consortium", 10 )

        elseif command == "testpara" then

            RepBar_PrintRep("Court of Farondis", 10 )

        elseif command == "testfriend" then

            RepBar_PrintRep("Akule Riverhorn", 10 )

        elseif command == "session" then

            RepBar_PrintSession()

        else

            RepBar_PrintHelp()

        end

    end

end

function RepBar_NextRepLevelName( factionIndex, standingID )

    if isFriendRep( factionIndex ) then

        return select( 7, GetFriendshipReputation( select( 14, GetFactionInfo( factionIndex ) ) ) )

    else

        return GetText("FACTION_STANDING_LABEL"..standingID, UnitSex("player"))

    end

end

function isFriendRep( factionIndex )

    return GetFriendshipReputation( select( 14, GetFactionInfo( factionIndex ) ) ) ~= nil

end
