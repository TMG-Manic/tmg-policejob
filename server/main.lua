TMGCore = exports['tmg-core']:GetCoreObject()

local DutyRegistry = { leo = {}, ems = {} }
local lastCensusTime = nil

local StealthComponents = {
    ['COMPONENT_AT_AR_SUPP_02'] = true,
    ['COMPONENT_AT_AR_SUPP']    = true,
    ['COMPONENT_AT_PI_SUPP_02'] = true,
    ['COMPONENT_AT_PI_SUPP']    = true,
}

local function GetCurrentCops()
    local count = 0
    for _ in pairs(DutyRegistry.leo) do
        count = count + 1
    end
    return count
end

local function UpdateBlips()
    local dutyPlayers = {}
    for cid, data in pairs(DutyRegistry.leo) do
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
            DutyRegistry.leo[cid] = nil
        end
    end
    TriggerClientEvent('police:client:UpdateBlips', -1, dutyPlayers)
end

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

TMGCore.Functions.CreateCallback('police:GetCops', function(_, cb)
    cb(GetCurrentCops())
end)

TMGCore.Functions.CreateCallback('police:server:isPlayerDead', function(_, cb, playerId)
    local targetId = tonumber(playerId)
    if not targetId then cb(false) return end
    local Player = TMGCore.Functions.GetPlayer(targetId)
    if Player then
        cb(Player.PlayerData.metadata['isdead'] or false)
    else
        cb(false)
    end
end)

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

TMGCore.Functions.CreateCallback('police:server:IsPoliceForcePresent', function(_, cb)
    local isPresent = false
    for cid, data in pairs(DutyRegistry.leo) do
        if data.grade and data.grade >= 2 then
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
    if not Player or Player.PlayerData.job.type ~= 'leo' then return end
    local cid = Player.PlayerData.citizenid
    local grade = Player.PlayerData.job.grade.level
    local vaultConfig = { maxweight = 100000, slots = 40 }
    if grade >= 4 then
        vaultConfig.maxweight = 250000
        vaultConfig.slots = 80
    end
    local stashId = string.format("policestash_%s", cid)
    exports['tmg-inventory']:OpenInventory(src, stashId, vaultConfig)
end)

RegisterNetEvent('tmg-policejob:server:trash', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.type ~= 'leo' then return end
    local trashConfig = { label = "PD Disposal Bin", maxweight = 4000000, slots = 300 }
    exports['tmg-inventory']:OpenInventory(src, 'policetrash', trashConfig)
end)

RegisterNetEvent('tmg-policejob:server:evidence', function(currentEvidence)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.type ~= 'leo' then return end
    local evidenceId = tostring(currentEvidence)
    if not evidenceId or evidenceId == "" then return end
    local evidenceConfig = { label = "Forensic Archive: " .. evidenceId, maxweight = 4000000, slots = 500 }
    exports['tmg-inventory']:OpenInventory(src, evidenceId, evidenceConfig)
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
        TriggerClientEvent('tmg-phone:client:addPoliceAlert', data.source, alertData)
        TriggerClientEvent('police:client:policeAlert', data.source, coords, text)
    end
end)

RegisterNetEvent('police:server:UpdateCurrentCops', function()
    local amount = GetCurrentCops()
    TriggerClientEvent('police:SetCopCount', -1, amount)
end)

RegisterNetEvent('tmg-police:server:syncCuffStatus', function(isHandcuffed)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    Player.Functions.SetMetaData('ishandcuffed', isHandcuffed)
    exports['tmgnosql']:UpdateOne('players', { ["citizenid"] = cid }, { ["$set"] = { ["metadata.ishandcuffed"] = isHandcuffed } })
end)

RegisterNetEvent('police:server:showFingerprint', function(targetId)
    local src = source
    local Target = TMGCore.Functions.GetPlayer(tonumber(targetId))
    local Sender = TMGCore.Functions.GetPlayer(src)
    if not Sender or not Target then return end
    TriggerClientEvent('police:client:showFingerprint', Target.PlayerData.source, src)
    TriggerClientEvent('police:client:showFingerprint', src, Target.PlayerData.source)
end)

RegisterNetEvent('police:server:showFingerprintId', function(sessionId)
    local src = source
    local Suspect = TMGCore.Functions.GetPlayer(src)
    local Officer = TMGCore.Functions.GetPlayer(tonumber(sessionId))
    if not Suspect or not Officer then return end
    local fid = Suspect.PlayerData.metadata['fingerprint']
    if not fid then return end
    TriggerClientEvent('police:client:showFingerprintId', Officer.PlayerData.source, fid)
    TriggerClientEvent('police:client:showFingerprintId', src, fid)
end)

RegisterNetEvent('tmg-police:server:syncTracker', function(targetId)
    local src = source
    local Target = TMGCore.Functions.GetPlayer(tonumber(targetId))
    if not Target then return end
    local cid = Target.PlayerData.citizenid
    local hasTracker = Target.PlayerData.metadata['tracker']
    local newState = not hasTracker
    Target.Functions.SetMetaData('tracker', newState)
    exports['tmgnosql']:UpdateOne('players', { ["citizenid"] = cid }, { ["$set"] = { ["metadata.tracker"] = newState } })
    TriggerClientEvent('tmg-police:client:setTrackerState', Target.PlayerData.source, newState)
end)

RegisterNetEvent('police:server:SendTrackerLocation', function(coords, requestId)
    local src = source
    local Target = TMGCore.Functions.GetPlayer(src)
    local OfficerId = tonumber(requestId)
    if not Target or not OfficerId then return end
    local alertData = {
        title = Lang:t('info.anklet_location'),
        coords = { x = coords.x, y = coords.y, z = coords.z },
        description = Lang:t('info.target_location', { firstname = Target.PlayerData.charinfo.firstname, lastname = Target.PlayerData.charinfo.lastname })
    }
    TriggerClientEvent('police:client:TrackerMessage', OfficerId, alertData.description, coords)
    TriggerClientEvent('tmg-phone:client:addPoliceAlert', OfficerId, alertData)
end)

CreateThread(function()
    while true do
        local copCount = GetCurrentCops()
        local sleep = copCount == 0 and 15000 or 5000
        if copCount > 0 then
            UpdateBlips()
        end
        local currentTimestamp = os.time()
        if not lastCensusTime or (currentTimestamp - lastCensusTime) > 300 then
            TriggerClientEvent('police:SetCopCount', -1, copCount)
            lastCensusTime = currentTimestamp
        end
        Wait(sleep)
    end
end)

TMGCore.Functions.CreateUseableItem('handcuffs', function(source, item)
    if not item then return end
    TriggerClientEvent('police:client:CuffPlayerSoft', source)
end)

TMGCore.Functions.CreateUseableItem('moneybag', function(source, item)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not item or not item.info or item.info.cash == nil then return end
    if Player.PlayerData.job.type ~= 'leo' then return end
    if exports['tmg-inventory']:RemoveItem(src, 'moneybag', 1, item.slot) then
        local amount = tonumber(item.info.cash)
        Player.Functions.AddMoney('cash', amount, 'police-evidence-liquidation')
        TriggerClientEvent('TMGCore:Notify', src, "Evidence Processed: $" .. amount .. " liquidated.", "success")
    end
end)

exports('GetOnDutyLEO', function()
    return GetCurrentCops()
end)