

ForensicState = {
    CurrentStatusList = {},
    Casings = {},
    Blooddrops = {},
    Fingerprints = {},
    CurrentEvidence = { casing = nil, blood = nil, finger = nil },
    shotAmount = 0,
    StatusList = {
        ['fight'] = Lang:t('evidence.red_hands'),
        ['widepupils'] = Lang:t('evidence.wide_pupils'),
        ['redeyes'] = Lang:t('evidence.red_eyes'),
        ['weedsmell'] = Lang:t('evidence.weed_smell'),
        ['gunpowder'] = Lang:t('evidence.gunpowder'),
        ['chemicals'] = Lang:t('evidence.chemicals'),
        ['heavybreath'] = Lang:t('evidence.heavy_breathing'),
        ['sweat'] = Lang:t('evidence.sweat'),
        ['handbleed'] = Lang:t('evidence.handbleed'),
        ['confused'] = Lang:t('evidence.confused'),
        ['alcohol'] = Lang:t('evidence.alcohol'),
        ['heavyalcohol'] = Lang:t('evidence.heavy_alcohol'),
        ['agitated'] = Lang:t('evidence.agitated')
    },
    Whitelist = { `weapon_unarmed`, `weapon_snowball`, `weapon_stungun`, `weapon_petrolcan`, `weapon_hazardcan`, `weapon_fireextinguisher` }
}



local function DnaHash(s)
    
    return (string.gsub(s, '.', function(c) return string.format('%02x', string.byte(c)) end))
end

local function GetStreetLabel(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local label = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then label = label .. ' | ' .. GetStreetNameFromHashKey(s2) end
    return label:gsub("%'", '')
end



local function DropBulletCasing(weapon, ped)
    
    local coords = GetOffsetFromEntityInWorldCoords(ped, math.random() + math.random(-1, 1), math.random() + math.random(-1, 1), 0)
    TriggerServerEvent('evidence:server:CreateCasing', weapon, coords)
    Wait(300)
end



RegisterNetEvent('evidence:client:AddCasing', function(id, weapon, coords, serie)
    ForensicState.Casings[id] = { type = weapon, serie = serie or Lang:t('evidence.serial_not_visible'), coords = { x = coords.x, y = coords.y, z = coords.z - 0.9 } }
end)

RegisterNetEvent('evidence:client:AddBlooddrop', function(id, citizenid, bloodtype, coords)
    ForensicState.Blooddrops[id] = { citizenid = citizenid, bloodtype = bloodtype, coords = { x = coords.x, y = coords.y, z = coords.z - 0.9 } }
end)

RegisterNetEvent('evidence:client:AddFingerPrint', function(id, fingerprint, coords)
    ForensicState.Fingerprints[id] = { fingerprint = fingerprint, coords = { x = coords.x, y = coords.y, z = coords.z - 0.9 } }
end)



local function ClearEvidenceInArea(type, langKey, event)
    local pos = GetEntityCoords(PlayerPedId())
    local list, sourceTable = {}, ForensicState[type]
    
    TMGCore.Functions.Progressbar('clear_forensics', Lang:t(langKey), 5000, false, true, {
        disableMovement = false, disableCarMovement = false, disableMouse = false, disableCombat = true
    }, {}, {}, {}, function() 
        if sourceTable and next(sourceTable) then
            for id, data in pairs(sourceTable) do
                if #(pos - vector3(data.coords.x, data.coords.y, data.coords.z)) < 10.0 then
                    list[#list + 1] = id
                end
            end
            TriggerServerEvent(event, list)
            TMGCore.Functions.Notify(Lang:t('success.bullet_casing_removed'), 'success') 
        end
    end)
end

RegisterNetEvent('evidence:client:ClearBlooddropsInArea', function() ClearEvidenceInArea('Blooddrops', 'progressbar.blood_clear', 'evidence:server:ClearBlooddrops') end)
RegisterNetEvent('evidence:client:ClearCasingsInArea', function() ClearEvidenceInArea('Casings', 'progressbar.bullet_casing', 'evidence:server:ClearCasings') end)




CreateThread(function()
    while true do
        Wait(1)
        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            local weapon = GetSelectedPedWeapon(ped)
            local isWhitelisted = false
            for _, w in ipairs(ForensicState.Whitelist) do if w == weapon then isWhitelisted = true break end end
            
            if not isWhitelisted then
                ForensicState.shotAmount += 1
                
                if ForensicState.shotAmount > 5 and not ForensicState.CurrentStatusList['gunpowder'] then
                    if math.random(1, 10) <= 7 then TriggerEvent('evidence:client:SetStatus', 'gunpowder', 200) end
                end
                DropBulletCasing(weapon, ped)
            end
        end
    end
end)


CreateThread(function()
    while true do
        local sleep = 1000
        if LocalPlayer.state.isLoggedIn then
            if PlayerJob.type == 'leo' and PlayerJob.onduty and IsPlayerFreeAiming(PlayerId()) and GetSelectedPedWeapon(PlayerPedId()) == `WEAPON_FLASHLIGHT` then
                sleep = 100 
                local pos = GetEntityCoords(PlayerPedId(), true)
                
                local function FindClosest(tbl, key)
                    ForensicState.CurrentEvidence[key] = nil
                    for id, data in pairs(tbl) do
                        if #(pos - vector3(data.coords.x, data.coords.y, data.coords.z)) < 1.5 then
                            ForensicState.CurrentEvidence[key] = id
                            break
                        end
                    end
                end

                FindClosest(ForensicState.Casings, 'casing')
                FindClosest(ForensicState.Blooddrops, 'blood')
                FindClosest(ForensicState.Fingerprints, 'finger')
            else
                sleep = (PlayerJob.type == 'leo') and 1000 or 5000
            end
        end
        Wait(sleep)
    end
end)


CreateThread(function()
    while true do
        local sleep = 1000
        local active = ForensicState.CurrentEvidence
        if active.casing or active.blood or active.finger then
            sleep = 1
            local pos = GetEntityCoords(PlayerPedId())
            
            if active.casing then
                local data = ForensicState.Casings[active.casing]
                DrawText3D(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.bullet_casing', { value = data.type }))
                if IsControlJustReleased(0, 47) then 
                    TriggerServerEvent('evidence:server:AddCasingToInventory', active.casing, { label = Lang:t('info.casing'), type = 'casing', street = GetStreetLabel(data.coords), ammolabel = Config.AmmoLabels[TMGCore.Shared.Weapons[data.type]['ammotype']], ammotype = data.type, serie = data.serie })
                end
            end

            if active.blood then
                local data = ForensicState.Blooddrops[active.blood]
                DrawText3D(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.blood_text', { value = DnaHash(data.citizenid) }))
                if IsControlJustReleased(0, 47) then
                    TriggerServerEvent('evidence:server:AddBlooddropToInventory', active.blood, { label = Lang:t('info.blood'), type = 'blood', street = GetStreetLabel(data.coords), dnalabel = DnaHash(data.citizenid), bloodtype = data.bloodtype })
                end
            end

            if active.finger then
                local data = ForensicState.Fingerprints[active.finger]
                DrawText3D(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.fingerprint_text'))
                if IsControlJustReleased(0, 47) then
                    TriggerServerEvent('evidence:server:AddFingerprintToInventory', active.finger, { label = Lang:t('info.fingerprint'), type = 'fingerprint', street = GetStreetLabel(data.coords), fingerprint = data.fingerprint })
                end
            end
        end
        Wait(sleep)
    end
end)


CreateThread(function()
    while true do
        Wait(10000)
        if LocalPlayer.state.isLoggedIn then
            if next(ForensicState.CurrentStatusList) then
                for k, v in pairs(ForensicState.CurrentStatusList) do
                    v.time = math.max(0, v.time - 10)
                end
                TriggerServerEvent('evidence:server:UpdateStatus', ForensicState.CurrentStatusList)
            end
            ForensicState.shotAmount = 0 
        end
    end
end)


RegisterNetEvent('evidence:client:RemoveCasing', function(id) ForensicState.Casings[id] = nil; ForensicState.CurrentEvidence.casing = nil end)
RegisterNetEvent('evidence:client:RemoveBlooddrop', function(id) ForensicState.Blooddrops[id] = nil; ForensicState.CurrentEvidence.blood = nil end)
RegisterNetEvent('evidence:client:RemoveFingerprint', function(id) ForensicState.Fingerprints[id] = nil; ForensicState.CurrentEvidence.finger = nil end)
