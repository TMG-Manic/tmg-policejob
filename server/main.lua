
TMGCore = exports['tmg-core']:GetCoreObject()
local GlobalDutyRegistry = {}


local function UpdateBlips()
    local dutyPlayers = {}
    
    for cid, data in pairs(GlobalDutyRegistry) do
        local ped = GetPlayerPed(data.source)
        
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            dutyPlayers[#dutyPlayers + 1] = {
                source = data.source,
                label = data.callsign,
                job = data.job,
                location = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    w = heading
                }
            }
        else
            GlobalDutyRegistry[cid] = nil
        end
    end

    TriggerClientEvent('police:client:UpdateBlips', -1, dutyPlayers)
end

local DutyRegistry = {
    leo = {},
    ems = {}
}


local function GetCurrentCops()
    local count = 0
    
    for _ in pairs(DutyRegistry.leo) do
        count = count + 1
    end
    
    return count
end



local DutyRegistry = { leo = {}, ems = {} }


TMGCore.Functions.CreateCallback('police:GetDutyPlayers', function(_, cb)
    local dutyPlayers = {}

    for cid, data in pairs(DutyRegistry.leo) do
        dutyPlayers[#dutyPlayers + 1] = {
            source = data.source,
            label = data.callsign,
            job = data.job
        }
    end

    cb(dutyPlayers)
end)

local DutyRegistry = { leo = {}, ems = {} }


TMGCore.Functions.CreateCallback('police:GetCops', function(_, cb)
    local amount = 0
    
    for _ in pairs(DutyRegistry.leo) do
        amount = amount + 1
    end
    
    cb(amount)
end)


TMGCore.Functions.CreateCallback('police:server:isPlayerDead', function(_, cb, playerId)
    local targetId = tonumber(playerId)
    if not targetId then cb(false) return end

    local Player = TMGCore.Functions.GetPlayer(targetId)
    
    if Player then
        local isDead = Player.PlayerData.metadata['isdead'] or false
        cb(isDead)
    else
        cb(false)
    end
end)

local StealthComponents = {
    ['COMPONENT_AT_AR_SUPP_02'] = true,
    ['COMPONENT_AT_AR_SUPP']    = true,
    ['COMPONENT_AT_PI_SUPP_02'] = true,
    ['COMPONENT_AT_PI_SUPP']    = true,
    
}


TMGCore.Functions.CreateCallback('police:IsSilencedWeapon', function(source, cb, weapon)
    local Player = TMGCore.Functions.GetPlayer(source)
    if not Player or not weapon or not TMGCore.Shared.Weapons[weapon] then 
        cb(false) 
        return 
    end

    local weaponName = TMGCore.Shared.Weapons[weapon]['name']
    local itemInfo = Player.Functions.GetItemByName(weaponName)
    
    local isSilenced = false

    if itemInfo and itemInfo.info and itemInfo.info.attachments then
        for _, attachment in pairs(itemInfo.info.attachments) do
            if StealthComponents[attachment.component] then
                isSilenced = true
                break
            end
        end
    end

    cb(isSilenced)
end)

local DutyRegistry = { leo = {}, ems = {} }


TMGCore.Functions.CreateCallback('police:server:IsPoliceForcePresent', function(_, cb)
    local isPresent = false

    for cid, data in pairs(DutyRegistry.leo) do
        if data.grade >= 2 then
            isPresent = true
            break
        end
    end

    cb(isPresent)
end)




AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    exports['tmgnosql']:DeleteMany('inventories', { 
        identifier = 'policetrash' 
    })

    print("^5[TMG]^7 Volatile registry 'policetrash' has been purged.")
end)


RegisterNetEvent('tmg-policejob:server:stash', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.type ~= 'leo' then 
        print("^1[TMG WARNING]^7 Unauthorized vault access attempt by " .. (Player and Player.PlayerData.citizenid or "Unknown"))
        return 
    end

    local cid = Player.PlayerData.citizenid
    local grade = Player.PlayerData.job.grade.level

    local vaultConfig = {
        maxweight = 100000, 
        slots = 40
    }

    if grade >= 4 then 
        vaultConfig.maxweight = 250000
        vaultConfig.slots = 80
    end

    local stashId = string.format("policestash_%s", cid)

    exports['tmg-inventory']:OpenInventory(src, stashId, vaultConfig)
    
    print(string.format("^5[TMG Mainframe]^7 Vault %s accessed by Grade %s", stashId, grade))
end)


RegisterNetEvent('tmg-policejob:server:trash', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' then return end

    local trashConfig = {
        label = "PD Disposal Bin",
        maxweight = 4000000, 
        slots = 300,
    }

    exports['tmg-inventory']:OpenInventory(src, 'policetrash', trashConfig)

    print("^5[TMG]^7 Sanitation Buffer 'policetrash' accessed by " .. Player.PlayerData.citizenid)
end)


RegisterNetEvent('tmg-policejob:server:evidence', function(currentEvidence)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' then 
        print("^1[TMG]^7 Unauthorized Forensic Access: " .. (Player and Player.PlayerData.citizenid or "Unknown"))
        return 
    end

    local evidenceId = tostring(currentEvidence)
    if not evidenceId or evidenceId == "" then return end

    local evidenceConfig = {
        label = "Forensic Archive: " .. evidenceId,
        maxweight = 4000000,
        slots = 500,
    }

    exports['tmg-inventory']:OpenInventory(src, evidenceId, evidenceConfig)

    print(string.format("^5[TMG]^7 Forensic Case %s accessed by %s", evidenceId, Player.PlayerData.citizenid))
end)


RegisterNetEvent('police:server:policeAlert', function(text)
    local src = source
    local senderPed = GetPlayerPed(src)
    local coords = GetEntityCoords(senderPed)
    
    local alertData = { 
        title = Lang:t('info.new_call'), 
        coords = { x = coords.x, y = coords.y, z = coords.z }, 
        description = text 
    }

    for cid, data in pairs(DutyRegistry.leo) do
        local targetSrc = data.source
        
        TriggerClientEvent('tmg-phone:client:addPoliceAlert', targetSrc, alertData)
        TriggerClientEvent('police:client:policeAlert', targetSrc, coords, text)
    end

    print(string.format("^5[TMG]^7 Dispatch Signal Relayed: '%s' to %s units.", text, GetCurrentCops()))
end)

local DutyRegistry = { leo = {}, ems = {} }


RegisterNetEvent('police:server:UpdateCurrentCops', function()
    local amount = 0
    for _ in pairs(DutyRegistry.leo) do
        amount = amount + 1
    end

    TriggerClientEvent('police:SetCopCount', -1, amount)

    print(string.format("^5[TMG]^7 Cop Count Synchronized: %s units active.", amount))
end)


RegisterNetEvent('tmg-police:server:syncCuffStatus', function(isHandcuffed)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    Player.Functions.SetMetaData('ishandcuffed', isHandcuffed)

    exports['tmgnosql']:UpdateOne('players', 
        { ["citizenid"] = cid }, 
        { ["$set"] = { ["metadata.ishandcuffed"] = isHandcuffed } }
    )

    print(string.format("^5[TMG]^7 Enforcement: Restraint pulse synced for %s (Status: %s)", cid, tostring(isHandcuffed)))
end)


RegisterNetEvent('police:server:showFingerprint', function(targetId)
    local src = source
    local Target = TMGCore.Functions.GetPlayer(tonumber(targetId))
    local Sender = TMGCore.Functions.GetPlayer(src)

    if not Sender or not Target then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Biometric link failed. Target offline.", "error")
        return 
    end

    local senderPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(Target.PlayerData.source)
    local dist = #(GetEntityCoords(senderPed) - GetEntityCoords(targetPed))

    if dist > 3.0 then
        TriggerClientEvent('TMGCore:Notify', src, "Signal Lost: Suspect too far from scanner.", "error")
        return
    end

    TriggerClientEvent('police:client:showFingerprint', Target.PlayerData.source, src)
    TriggerClientEvent('police:client:showFingerprint', src, Target.PlayerData.source)

    print(string.format("^5[TMG]^7 Biometric Link Established: %s <-> %s", src, targetId))
end)


RegisterNetEvent('police:server:showFingerprintId', function(sessionId)
    local src = source
    local Suspect = TMGCore.Functions.GetPlayer(src)
    local Officer = TMGCore.Functions.GetPlayer(tonumber(sessionId))

    if not Suspect or not Officer then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Biometric link severed. Terminal lost.", "error")
        return 
    end

    local fid = Suspect.PlayerData.metadata['fingerprint']

    if not fid then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: No biometric signature found in registry.", "error")
        return
    end

    local targetSource = Officer.PlayerData.source
    
    TriggerClientEvent('police:client:showFingerprintId', targetSource, fid)
    TriggerClientEvent('police:client:showFingerprintId', src, fid)

    print(string.format("^5[TMG]^7 Forensic Match: %s beamed to Officer ID %s", fid, sessionId))
end)

RegisterNetEvent('tmg-police:server:syncTracker', function(targetId)
    local src = source
    local targetId = tonumber(targetId)
    local Player = TMGCore.Functions.GetPlayer(src)
    local Target = TMGCore.Functions.GetPlayer(targetId)

    if not Player or not Target then return end

    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed)) > 3.0 then 
        return DropPlayer(src, 'TMG Mainframe: Physical Distance Violation (Tether Protocol)') 
    end

    local cid = Target.PlayerData.citizenid
    local hasTracker = Target.PlayerData.metadata['tracker']
    local newState = not hasTracker 

    Target.Functions.SetMetaData('tracker', newState)

    exports['tmgnosql']:UpdateOne('players', 
        { ["citizenid"] = cid }, 
        { ["$set"] = { ["metadata.tracker"] = newState } }
    )

    if newState then
        TriggerClientEvent('TMGCore:Notify', targetId, Lang:t('success.put_anklet'), 'success')
        TriggerClientEvent('TMGCore:Notify', src, string.format("Monitoring device active for %s %s", 
            Target.PlayerData.charinfo.firstname, Target.PlayerData.charinfo.lastname), 'success')
        TriggerClientEvent('tmg-police:client:setTrackerState', targetId, true)
    else
        TriggerClientEvent('TMGCore:Notify', targetId, Lang:t('success.anklet_taken_off'), 'success')
        TriggerClientEvent('TMGCore:Notify', src, string.format("Monitoring device deactivated for %s %s", 
            Target.PlayerData.charinfo.firstname, Target.PlayerData.charinfo.lastname), 'success')
        TriggerClientEvent('tmg-police:client:setTrackerState', targetId, false)
    end

    print(string.format("^5[TMG]^7 Judicial: Monitoring state for %s set to %s", cid, tostring(newState)))
end)


RegisterNetEvent('police:server:SendTrackerLocation', function(coords, requestId)
    local src = source
    local Target = TMGCore.Functions.GetPlayer(src)
    local OfficerId = tonumber(requestId)

    if not Target or not OfficerId then return end

    local isAuthorized = false
    for cid, data in pairs(DutyRegistry.leo) do
        if data.source == OfficerId then
            isAuthorized = true
            break
        end
    end

    if not isAuthorized and OfficerId ~= -1 then 
        return 
    end

    local msg = Lang:t('info.target_location', { 
        firstname = Target.PlayerData.charinfo.firstname, 
        lastname = Target.PlayerData.charinfo.lastname 
    })

    local alertData = {
        title = Lang:t('info.anklet_location'),
        coords = { x = coords.x, y = coords.y, z = coords.z },
        description = msg
    }

    TriggerClientEvent('police:client:TrackerMessage', OfficerId, msg, coords)
    TriggerClientEvent('tmg-phone:client:addPoliceAlert', OfficerId, alertData)

    print(string.format("^5[TMG]^7 Tracker Pulse: Citizen %s -> Terminal %s", Target.PlayerData.citizenid, OfficerId))
end)




CreateThread(function()
    while true do
        local copCount = GetCurrentCops()
        local sleep = 5000 

        if copCount == 0 then
            sleep = 15000 
        elseif copCount > 20 then
            sleep = 7500
        end

        if copCount > 0 then
            UpdateBlips()
        end

        local currentTimestamp = os.time()
        if not lastCensusTime or (currentTimestamp - lastCensusTime) > 300 then
            TriggerClientEvent('police:SetCopCount', -1, copCount)
            lastCensusTime = currentTimestamp
            print("^5[TMG]^7 Global Census Heartbeat Pulsed.")
        end

        Wait(sleep)
    end
end)




TMGCore.Functions.CreateUseableItem('handcuffs', function(source, item)
    local src = source
    if not item then return end 
    
    TriggerClientEvent('police:client:CuffPlayerSoft', src)
end)

TMGCore.Functions.CreateUseableItem('moneybag', function(source, item)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or not item or not item.info or item.info.cash == nil then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Invalid payload data.", "error")
        return 
    end

    if Player.PlayerData.job.type ~= 'leo' then 
        TriggerClientEvent('TMGCore:Notify', src, "Access Denied: LEO biometric signature required.", "error")
        return 
    end

    if exports['tmg-inventory']:RemoveItem(src, 'moneybag', 1, item.slot) then
        local amount = tonumber(item.info.cash)
        
        Player.Functions.AddMoney('cash', amount, 'police-evidence-liquidation')
        
        TriggerClientEvent('TMGCore:Notify', src, "Evidence Processed: $" .. amount .. " liquidated.", "success")
        print(string.format("^5[TMG]^7 Evidence Liquidated: %s processed $%s", Player.PlayerData.citizenid, amount))
    else
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Failed to consume asset.", "error")
    end
end)

exports('GetOnDutyLEO', function()
    local count = 0
    for _ in pairs(DutyRegistry.leo) do count = count + 1 end
    return count
end)
