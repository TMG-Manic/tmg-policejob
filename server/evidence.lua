local EvidenceRegistry = {
    casings = {},
    blood = {},
    fingerprints = {}
}

local function GenerateEvidenceID(category)
    local id = #EvidenceRegistry[category] + 1
    return id
end

TMGCore.Functions.CreateCallback('police:GetPlayerStatus', function(_, cb, targetId)
    local targetId = tonumber(targetId)
    cb(PlayerStatus[targetId] or {})
end)

RegisterNetEvent('evidence:server:UpdateStatus', function(data)
    local src = source
    PlayerStatus[src] = data
end)




TMGCore.Functions.CreateCallback('police:GetPlayerStatus', function(source, cb, targetId)
    local targetId = tonumber(targetId)
    local statList = {}
    local activeStatus = PlayerStatus[targetId]
    if activeStatus and next(activeStatus) then
        for _, statusData in pairs(activeStatus) do
            if statusData.text then
                statList[#statList + 1] = statusData.text
            end
        end
    end
    cb(statList)
    
end)




RegisterNetEvent('evidence:server:UpdateStatus', function(data)
    local src = source
    if type(data) ~= "table" then return end
    PlayerStatus[src] = data
    
end)


RegisterNetEvent('evidence:server:CreateBloodDrop', function(citizenid, bloodtype, coords)
    local bloodId = #BloodDrops + 1

    BloodDrops[bloodId] = {
        dna = citizenid,
        bloodtype = bloodtype,
        coords = coords,
        timestamp = os.time()
    }

    TriggerClientEvent('evidence:client:AddBlooddrop', -1, bloodId, citizenid, bloodtype, coords)

    
end)


RegisterNetEvent('evidence:server:CreateFingerDrop', function(coords)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    local fingerId = #FingerDrops + 1

    local printHash = Player.PlayerData.metadata['fingerprint']

    FingerDrops[fingerId] = {
        print = printHash,
        coords = coords,
        timestamp = os.time()
    }

    TriggerClientEvent('evidence:client:AddFingerPrint', -1, fingerId, printHash, coords)

    
end)


RegisterNetEvent('evidence:server:ClearBlooddrops', function(blooddropList)
    if not blooddropList or not next(blooddropList) then return end
    for _, id in pairs(blooddropList) do
        BloodDrops[id] = nil
    end
    TriggerClientEvent('evidence:client:RemoveBlooddropBatch', -1, blooddropList)

    
end)


RegisterNetEvent('evidence:server:AddBlooddropToInventory', function(bloodId, bloodInfo)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    if not Officer then return end

    if not BloodDrops[bloodId] then 
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Evidence no longer exists or was already collected.", "error")
        return 
    end

    local hasBag = Officer.Functions.GetItemByName('empty_evidence_bag')
    if not hasBag then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
        return
    end

    local info = bloodInfo
    info.collectedBy = Officer.PlayerData.citizenid
    info.timestamp = os.time()

    if exports['tmg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, info) then
        exports['tmg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1)
        
        BloodDrops[bloodId] = nil
        TriggerClientEvent('evidence:client:RemoveBlooddrop', -1, bloodId)
        
        TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['filled_evidence_bag'], 'add')
        
    else
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Your inventory is too full to secure this evidence.", "error")
    end
end)


RegisterNetEvent('evidence:server:AddFingerprintToInventory', function(fingerId, fingerInfo)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    if not Officer or not fingerId then return end

    if not FingerDrops[fingerId] then 
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Fingerprint has degraded or already been lifted.", "error")
        return 
    end

    if not Officer.Functions.GetItemByName('empty_evidence_bag') then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
        return
    end

    local info = fingerInfo
    info.type = "Fingerprint"
    info.liftedBy = Officer.PlayerData.citizenid
    info.timestamp = os.time()

    if exports['tmg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, info) then
        exports['tmg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1)
        
        FingerDrops[fingerId] = nil
        TriggerClientEvent('evidence:client:RemoveFingerprint', -1, fingerId)
        
        TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['filled_evidence_bag'], 'add')
        
    else
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Inventory overflow. Clear space to secure this print.", "error")
    end
end)


RegisterNetEvent('evidence:server:CreateCasing', function(weaponName, coords)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or not weaponName then return end

    local casingId = #Casings + 1

    local weaponItem = Player.Functions.GetItemByName(weaponName)
    local serial = "Unknown"

    if weaponItem and weaponItem.info and weaponItem.info.serie then
        serial = weaponItem.info.serie
    end

    Casings[casingId] = {
        type = weaponName,
        serial = serial,
        coords = coords,
        timestamp = os.time()
    }

    TriggerClientEvent('evidence:client:AddCasing', -1, casingId, weaponName, coords, serial)

    
end)


RegisterNetEvent('evidence:server:ClearCasings', function(casingList)
    if not casingList or not next(casingList) then return end

    for _, id in pairs(casingList) do
        if Casings[id] then
            Casings[id] = nil
        end
    end

    TriggerClientEvent('evidence:client:RemoveCasingBatch', -1, casingList)

    
end)


RegisterNetEvent('evidence:server:AddCasingToInventory', function(casingId, casingInfo)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    if not Officer or not casingId then return end

    if not Casings[casingId] then 
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Ballistic evidence has degraded or already been collected.", "error")
        return 
    end

    if not Officer.Functions.GetItemByName('empty_evidence_bag') then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
        return
    end

    local info = casingInfo
    info.type = "Ballistic Casing"
    info.collectedBy = Officer.PlayerData.citizenid
    info.timestamp = os.time()

    if exports['tmg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, info) then
        exports['tmg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1)
        
        Casings[casingId] = nil
        TriggerClientEvent('evidence:client:RemoveCasing', -1, casingId)
        
        TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['filled_evidence_bag'], 'add')
        
    else
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Inventory overflow. Secure space to bag this casing.", "error")
    end
end)
