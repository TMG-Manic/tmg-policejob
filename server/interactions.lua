
RegisterNetEvent('police:server:SearchPlayer', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' then 
        print("^1[TMG WARNING]^7 Unauthorized search attempt by " .. (Player and Player.PlayerData.citizenid or "Unknown"))
        return 
    end

    local targetId, distance = TMGCore.Functions.GetClosestPlayer(src)
    
    if targetId ~= -1 and distance < 2.5 then
        local Target = TMGCore.Functions.GetPlayer(tonumber(targetId))
        if not Target then return end

        exports['qb-inventory']:OpenInventoryById(src, targetId)

        local suspectCash = Target.PlayerData.money['cash']
        
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('info.cash_found', { cash = suspectCash }), 'primary')
        TriggerClientEvent('TMGCore:Notify', targetId, Lang:t('info.being_searched'), 'error')
        
        print(string.format("^5[TMG]^7 %s is searching %s", Player.PlayerData.citizenid, Target.PlayerData.citizenid))
    else
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.none_nearby'), 'error')
    end
end)


RegisterNetEvent('tmg-police:server:restrainPlayer', function(targetId, isSoftcuff)
    local src = source
    local targetId = tonumber(targetId)
    local Player = TMGCore.Functions.GetPlayer(src)
    local Target = TMGCore.Functions.GetPlayer(targetId)

    if not Player or not Target then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 3.0 then 
        return DropPlayer(src, 'TMG Mainframe: Physical Distance Violation (Cuff Protocol)') 
    end

    local isLeo = (Player.PlayerData.job.type == 'leo')
    local hasItem = Player.Functions.GetItemByName('handcuffs')
    
    if not isLeo and not hasItem then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: No restraint assets detected in inventory.", "error")
        return 
    end

    exports['tmgnosql']:UpdateOne('players', 
        { ["citizenid"] = Target.PlayerData.citizenid }, 
        { ["$set"] = { ["metadata.ishandcuffed"] = true } }
    )

    TriggerClientEvent('tmg-police:client:getRestrained', targetId, src, isSoftcuff)
    
    print(string.format("^5[TMG]^7 Enforcement: %s restrained %s", Player.PlayerData.citizenid, Target.PlayerData.citizenid))
end)




RegisterNetEvent('police:server:EscortPlayer', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Player = TMGCore.Functions.GetPlayer(src)
    local Target = TMGCore.Functions.GetPlayer(targetId)

    if not Player or not Target then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 2.5 then 
        return DropPlayer(src, 'Mainframe: Distance Exploit (Escort Protocol)') 
    end

    local isAuthorized = (Player.PlayerData.job.type == 'leo' or Player.PlayerData.job.name == 'ambulance')
    local isSuspectRestrained = (Target.PlayerData.metadata['ishandcuffed'] or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'])

    if isAuthorized or isSuspectRestrained then
        TriggerClientEvent('police:client:GetEscorted', Target.PlayerData.source, Player.PlayerData.source)
    else
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end

    print(string.format("^5[TMG]^7 Tether Established: %s is now escorting %s", Player.PlayerData.citizenid, Target.PlayerData.citizenid))
end)


RegisterNetEvent('police:server:KidnapPlayer', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Kidnapper = TMGCore.Functions.GetPlayer(src)
    local Victim = TMGCore.Functions.GetPlayer(targetId)

    if not Kidnapper or not Victim then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 2.5 then 
        return DropPlayer(src, 'Mainframe: Distance Exploit (Kidnap Protocol)') 
    end

    local isVulnerable = (Victim.PlayerData.metadata['ishandcuffed'] or Victim.PlayerData.metadata['isdead'] or Victim.PlayerData.metadata['inlaststand'])

    if isVulnerable then
        TriggerClientEvent('police:client:GetKidnappedTarget', Victim.PlayerData.source, Kidnapper.PlayerData.source)
        TriggerClientEvent('police:client:GetKidnappedDragger', Kidnapper.PlayerData.source, Victim.PlayerData.source)
    else
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end

    print(string.format("^5[TMG]^7 Hostile Tether: %s has seized %s", Kidnapper.PlayerData.citizenid, Victim.PlayerData.citizenid))
end)

RegisterNetEvent('police:server:SetPlayerOutVehicle', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Officer = TMGCore.Functions.GetPlayer(src)
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or not Suspect then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 4.0 then 
        return DropPlayer(src, 'Mainframe: Distance Exploit (Extraction Protocol)') 
    end

    local isRestricted = (Suspect.PlayerData.metadata['ishandcuffed'] or Suspect.PlayerData.metadata['isdead'] or Suspect.PlayerData.metadata['inlaststand'])

    if isRestricted then
        TriggerClientEvent('police:client:SetOutVehicle', Suspect.PlayerData.source)
    else
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end

    print(string.format("^5[TMG]^7 Extraction: %s removed %s from vehicle.", Officer.PlayerData.citizenid, Suspect.PlayerData.citizenid))
end)


RegisterNetEvent('police:server:PutPlayerInVehicle', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Officer = TMGCore.Functions.GetPlayer(src)
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or not Suspect then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 2.5 then 
        return DropPlayer(src, 'Mainframe: Distance Exploit (Insertion Protocol)') 
    end

    local isLoadable = (Suspect.PlayerData.metadata['ishandcuffed'] or Suspect.PlayerData.metadata['isdead'] or Suspect.PlayerData.metadata['inlaststand'])

    if isLoadable then
        TriggerClientEvent('police:client:PutInVehicle', Suspect.PlayerData.source)
    else
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end

    print(string.format("^5[TMG]^7 Insertion: %s placed %s into a vehicle transport.", Officer.PlayerData.citizenid, Suspect.PlayerData.citizenid))
end)


RegisterNetEvent('police:server:BillPlayer', function(targetId, amount)
    local src = source
    local targetId = tonumber(targetId)
    local amount = tonumber(amount)
    local Officer = TMGCore.Functions.GetPlayer(src)
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or not Suspect or not amount or amount <= 0 then return end
    if Officer.PlayerData.job.type ~= 'leo' then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 2.5 then 
        return DropPlayer(src, 'Mainframe: Distance Exploit (Billing Protocol)') 
    end

    local success = Suspect.Functions.RemoveMoney('bank', amount, 'police-fine-payment')

    if success then
        exports['qb-banking']:AddMoney('police', amount, 'Fine: ' .. Suspect.PlayerData.citizenid)

        TriggerClientEvent('TMGCore:Notify', targetId, Lang:t('info.fine_received', { fine = amount }), 'error')
        TriggerClientEvent('TMGCore:Notify', src, "Fine Processed: $" .. amount .. " collected.", 'success')
        
        print(string.format("^5[TMG]^7 Fine: %s paid $%s to the Department.", Suspect.PlayerData.citizenid, amount))
    else
        TriggerClientEvent('TMGCore:Notify', src, "Transaction Failed: Suspect has insufficient bank funds.", 'error')
    end
end)

RegisterNetEvent('tmg-police:server:sentencePlayer', function(targetId, minutes)
    local src = source
    local targetId = tonumber(targetId)
    local minutes = tonumber(minutes)
    local Officer = TMGCore.Functions.GetPlayer(src)
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or not Suspect or not minutes or minutes <= 0 then return end
    if Officer.PlayerData.job.type ~= 'leo' then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 3.5 then 
        return DropPlayer(src, 'TMG Mainframe: Distance Violation (Judicial Sentencing)') 
    end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')

    exports['tmgnosql']:UpdateOne('players', 
        { ["citizenid"] = Suspect.PlayerData.citizenid }, 
        { ["$set"] = { 
            ["metadata.injail"] = minutes,
            ["metadata.criminalrecord"] = {
                ["hasRecord"] = true,
                ["lastArrest"] = timestamp,
                ["arrestingOfficer"] = Officer.PlayerData.citizenid,
                ["sentenceTime"] = minutes
            }
        }}
    )

    Suspect.Functions.SetMetaData('injail', minutes)
    TriggerClientEvent('tmg-police:client:sendToJail', Suspect.PlayerData.source, minutes)
    
    TriggerClientEvent('TMGCore:Notify', src, string.format("Sentencing Confirmed: %s months.", minutes), 'success')
    
    print(string.format("^5[TMG]^7 Judicial: %s sentenced by %s", Suspect.PlayerData.citizenid, Officer.PlayerData.citizenid))
end)




RegisterNetEvent('police:server:SeizeCash', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Officer = TMGCore.Functions.GetPlayer(src)
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or not Suspect or Officer.PlayerData.job.type ~= 'leo' then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 2.5 then 
        return DropPlayer(src, 'Mainframe: Distance Exploit (Seizure Protocol)') 
    end

    local amount = Suspect.PlayerData.money['cash']
    if not amount or amount <= 0 then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: No physical currency detected on suspect.", "error")
        return 
    end

    local info = { 
        cash = amount, 
        confiscatedBy = Officer.PlayerData.citizenid,
        suspect = Suspect.PlayerData.citizenid,
        timestamp = os.time()
    }

    if exports['qb-inventory']:AddItem(src, 'moneybag', 1, false, info) then
        Suspect.Functions.RemoveMoney('cash', amount, 'police-cash-seized')
        
        TriggerClientEvent('qb-inventory:client:ItemBox', src, TMGCore.Shared.Items['moneybag'], 'add')
        TriggerClientEvent('TMGCore:Notify', targetId, Lang:t('info.cash_confiscated'), 'error')
        TriggerClientEvent('TMGCore:Notify', src, "Confiscated: $" .. amount, 'success')
        
        print(string.format("^5[TMG]^7 Evidence Serialized: %s confiscated $%s from %s", Officer.PlayerData.citizenid, amount, Suspect.PlayerData.citizenid))
    else
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Your inventory is too full to secure this evidence.", "error")
    end
end)


RegisterNetEvent('tmg-police:server:seizeLicense', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Officer = TMGCore.Functions.GetPlayer(src)
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or not Suspect or Officer.PlayerData.job.type ~= 'leo' then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 3.0 then 
        return DropPlayer(src, 'TMG Mainframe: Distance Violation (Licensing Protocol)') 
    end

    local currentLicenses = Suspect.PlayerData.metadata['licences']
    if not currentLicenses or not currentLicenses['driver'] then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Suspect possesses no valid driver license.", 'error')
        return
    end

    exports['tmgnosql']:UpdateOne('players', 
        { ["citizenid"] = Suspect.PlayerData.citizenid }, 
        { ["$set"] = { ["metadata.licences.driver"] = false } }
    )

    currentLicenses['driver'] = false
    Suspect.Functions.SetMetaData('licences', currentLicenses)

    TriggerClientEvent('TMGCore:Notify', targetId, "Regulatory Alert: Your driver license has been revoked.", 'error')
    TriggerClientEvent('TMGCore:Notify', src, string.format("Authorization terminated for CID: %s", Suspect.PlayerData.citizenid), 'success')
    
    print(string.format("^5[TMG]^7 Licensing: %s revoked license of %s", Officer.PlayerData.citizenid, Suspect.PlayerData.citizenid))
end)


RegisterNetEvent('police:server:RobPlayer', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Attacker = TMGCore.Functions.GetPlayer(src)
    local Victim = TMGCore.Functions.GetPlayer(targetId)

    if not Attacker or not Victim then return end

    local p1 = GetEntityCoords(GetPlayerPed(src))
    local p2 = GetEntityCoords(GetPlayerPed(targetId))
    if #(p1 - p2) > 2.5 then 
        return DropPlayer(src, 'Mainframe: Distance Exploit (Robbery Protocol)') 
    end

    local isVictimVulnerable = (Victim.PlayerData.metadata['ishandcuffed'] or Victim.PlayerData.metadata['isdead'] or Victim.PlayerData.metadata['inlaststand'])
    
    if not isVictimVulnerable then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Target is not incapacitated or restrained.", "error")
        return
    end

    local stolenAmount = Victim.PlayerData.money['cash']

    if stolenAmount > 0 then
        if Victim.Functions.RemoveMoney('cash', stolenAmount, 'player-robbed') then
            Attacker.Functions.AddMoney('cash', stolenAmount, 'player-robbery-gain')
            
            TriggerClientEvent('TMGCore:Notify', targetId, Lang:t('info.cash_robbed', { money = stolenAmount }), 'error')
            TriggerClientEvent('TMGCore:Notify', src, Lang:t('info.stolen_money', { stolen = stolenAmount }), 'success')
        end
    end

    exports['qb-inventory']:OpenInventoryById(src, targetId)
    
    print(string.format("^5[TMG]^7 Hostile Transfer: %s robbed %s for $%s", Attacker.PlayerData.citizenid, Victim.PlayerData.citizenid, stolenAmount))
end)
