

local ObjectList = {}
local SpawnedSpikes = {}
local SpikeModel = `P_ld_stinger_s`


local function GetClosestPoliceObject()
    local pos = GetEntityCoords(PlayerPedId())
    local currentId, minDist = nil, math.huge

    for id, data in pairs(ObjectList) do
        local dist = #(pos - data.coords)
        if dist < minDist then
            currentId, minDist = id, dist
        end
    end
    return currentId, minDist
end

local function GetClosestSpike()
    local pos = GetEntityCoords(PlayerPedId())
    local currentId, minDist = nil, 50.0

    for id, data in pairs(SpawnedSpikes) do
        local dist = #(pos - data.coords)
        if dist < minDist then
            currentId, minDist = id, dist
        end
    end
    return currentId
end

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end


RegisterNetEvent('police:client:spawnObject', function(type)
    if not Config.Objects[type] then return end

    TMGCore.Functions.Progressbar('spawn_object', Lang:t('progressbar.place_object'), 2500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'anim@narcotics@trash',
        anim = 'drop_front',
        flags = 16,
    }, {}, {}, function() 
        StopAnimTask(PlayerPedId(), 'anim@narcotics@trash', 'drop_front', 1.0)
        TriggerServerEvent('police:server:spawnObject', type)
    end, function() 
        StopAnimTask(PlayerPedId(), 'anim@narcotics@trash', 'drop_front', 1.0)
        TMGCore.Functions.Notify(Lang:t('error.canceled'), 'error')
    end)
end)


RegisterNetEvent('police:client:spawnCone', function() TriggerEvent('police:client:spawnObject', 'cone') end)
RegisterNetEvent('police:client:spawnBarrier', function() TriggerEvent('police:client:spawnObject', 'barrier') end)
RegisterNetEvent('police:client:spawnRoadSign', function() TriggerEvent('police:client:spawnObject', 'roadsign') end)
RegisterNetEvent('police:client:spawnTent', function() TriggerEvent('police:client:spawnObject', 'tent') end)
RegisterNetEvent('police:client:spawnLight', function() TriggerEvent('police:client:spawnObject', 'light') end)


RegisterNetEvent('police:client:deleteObject', function()
    local objectId, dist = GetClosestPoliceObject()
    if objectId and dist < 5.0 then
        TMGCore.Functions.Progressbar('remove_object', Lang:t('progressbar.remove_object'), 2500, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'weapons@first_person@aim_rng@generic@projectile@thermal_charge@',
            anim = 'plant_floor',
            flags = 16,
        }, {}, {}, function() 
            StopAnimTask(PlayerPedId(), 'weapons@first_person@aim_rng@generic@projectile@thermal_charge@', 'plant_floor', 1.0)
            TriggerServerEvent('police:server:deleteObject', objectId)
        end, function() 
            StopAnimTask(PlayerPedId(), 'weapons@first_person@aim_rng@generic@projectile@thermal_charge@', 'plant_floor', 1.0)
            TMGCore.Functions.Notify(Lang:t('error.canceled'), 'error')
        end)
    end
end)

RegisterNetEvent('police:client:removeObject', function(objectId)
    if ObjectList[objectId] then
        local ent = ObjectList[objectId].object
        if DoesEntityExist(ent) then
            NetworkRequestControlOfEntity(ent)
            DeleteObject(ent)
        end
        ObjectList[objectId] = nil
    end
end)

RegisterNetEvent('police:client:spawnObjectEntity', function(objectId, type, playerSource)
    local targetPlayer = GetPlayerFromServerId(playerSource)
    local playerPed = GetPlayerPed(targetPlayer)
    
    if not DoesEntityExist(playerPed) then playerPed = PlayerPedId() end

    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    
    local spawnPos = coords + (forward * 0.6)
    
    local model = Config.Objects[type].model
    TMGCore.Functions.LoadModel(model)

    local spawnedObj = CreateObject(model, spawnPos.x, spawnPos.y, spawnPos.z, true, false, false)
    
    PlaceObjectOnGroundProperly(spawnedObj)
    SetEntityHeading(spawnedObj, heading)
    FreezeEntityPosition(spawnedObj, Config.Objects[type].freeze)
    
    ObjectList[objectId] = {
        id = objectId,
        object = spawnedObj,
        coords = spawnPos,
    }
    
    print("^5[TMG]^7 Tactical " .. type .. " materialized. Entity ID: " .. spawnedObj)
end)


RegisterNetEvent('police:client:SpawnSpikeStrip', function()
    if #SpawnedSpikes >= (Config.MaxSpikes or 5) then
        return TMGCore.Functions.Notify(Lang:t('error.no_spikestripe'), 'error')
    end

    if PlayerJob.type == 'leo' and PlayerJob.onduty then
        TMGCore.Functions.Progressbar('deploy_spike', "Deploying Stinger...", 1500, false, true, {
            disableMovement = true,
            disableCombat = true,
        }, {
            animDict = 'anim@narcotics@trash',
            anim = 'drop_front',
            flags = 16,
        }, {}, {}, function()
            local playerPed = PlayerPedId()
            local spawnCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 2.0, 0.0)
            local spike = CreateObject(SpikeModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, true)
            
            SetEntityHeading(spike, GetEntityHeading(playerPed))
            PlaceObjectOnGroundProperly(spike)
            
            local netId = NetworkGetNetworkIdFromEntity(spike)
            SetNetworkIdCanMigrate(netId, false)
            
            SpawnedSpikes[#SpawnedSpikes + 1] = {
                coords = vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z),
                netid = netId,
                object = spike,
            }
            TriggerServerEvent('police:server:SyncSpikes', SpawnedSpikes)
        end)
    end
end)

RegisterNetEvent('police:client:SyncSpikes', function(newTable)
    SpawnedSpikes = newTable
end)


CreateThread(function()
    while true do
        local sleep = 1000
        if LocalPlayer.state.isLoggedIn then
            local playerPed = PlayerPedId()
            local pos = GetEntityCoords(playerPed)
            local closestSpikeId = GetClosestSpike()

            if closestSpikeId then
                sleep = 500 
                
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                if vehicle ~= 0 then
                    sleep = 0 
                    local tires = {
                        { bone = 'wheel_lf', index = 0 }, { bone = 'wheel_rf', index = 1 },
                        { bone = 'wheel_lm', index = 2 }, { bone = 'wheel_rm', index = 3 },
                        { bone = 'wheel_lr', index = 4 }, { bone = 'wheel_rr', index = 5 }
                    }

                    for t = 1, #tires do
                        local tirePos = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, tires[t].bone))
                        local dist = #(tirePos - SpawnedSpikes[closestSpikeId].coords)

                        if dist < 1.8 then
                            if not IsVehicleTyreBurst(vehicle, tires[t].index, true) then
                                SetVehicleTyreBurst(vehicle, tires[t].index, false, 1000.0)
                            end
                        end
                    end
                
                else
                    local dist = #(pos - SpawnedSpikes[closestSpikeId].coords)
                    if dist < 4.0 and PlayerJob.type == 'leo' and PlayerJob.onduty then
                        sleep = 0
                        DrawText3D(SpawnedSpikes[closestSpikeId].coords.x, SpawnedSpikes[closestSpikeId].coords.y, SpawnedSpikes[closestSpikeId].coords.z, Lang:t('info.delete_spike'))
                        
                        if IsControlJustPressed(0, 38) then 
                            local spikeEnt = NetToEnt(SpawnedSpikes[closestSpikeId].netid)
                            NetworkRequestControlOfEntity(spikeEnt)
                            SetEntityAsMissionEntity(spikeEnt, true, true)
                            DeleteEntity(spikeEnt)
                            
                            SpawnedSpikes[closestSpikeId] = nil
                            TriggerServerEvent('police:server:SyncSpikes', SpawnedSpikes)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
