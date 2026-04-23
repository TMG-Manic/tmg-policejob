local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function GetClosestPlayer()
    local closestPlayers = TMGCore.Functions.GetPlayersFromCoords()
    local closestDistance, closestPlayer = -1, -1
    local coords = GetEntityCoords(PlayerPedId())

    for i = 1, #closestPlayers do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer, closestDistance = closestPlayers[i], distance
            end
        end
    end
    return closestPlayer, closestDistance
end


local function openFingerprintUI()
    SendNUIMessage({
        type = 'fingerprintOpen'
    })
    
    PoliceJobState.InZone.fingerprint = true
    
    SetNuiFocus(true, true)
end


local function SetCarItemsInfo()
    local hydratedItems = {}
    
    for _, item in pairs(Config.CarItems) do
        local itemName = item.name:lower()
        local itemData = TMGCore.Shared.Items[itemName]
        
        if itemData then
            hydratedItems[#hydratedItems + 1] = {
                name = itemData.name,
                amount = tonumber(item.amount) or 0,
                info = item.info or {},
                label = itemData.label,
                description = itemData.description or '',
                weight = itemData.weight,
                type = itemData.type,
                unique = itemData.unique,
                useable = itemData.useable,
                image = itemData.image,
                slot = #hydratedItems + 1,
            }
        end
    end
    
    Config.CarItems = hydratedItems
end


local function doCarDamage(currentVehicle, veh)
    local engineHealth = veh.engine + 0.0
    local bodyHealth = veh.body + 0.0

    if engineHealth < 200.0 then engineHealth = 200.0 end
    if engineHealth > 1000.0 then engineHealth = 950.0 end
    
    local shouldSmash = bodyHealth < 950.0
    local shouldBreakDoors = bodyHealth < 920.0
    local shouldBurstTires = bodyHealth < 920.0

    Wait(100) 
    SetVehicleEngineHealth(currentVehicle, engineHealth)

    if shouldSmash then
        for i = 0, 4 do
            SmashVehicleWindow(currentVehicle, i)
        end
    end

    if shouldBreakDoors then
        local targetDoors = {1, 4, 6} 
        for _, doorIndex in ipairs(targetDoors) do
            SetVehicleDoorBroken(currentVehicle, doorIndex, true)
        end
    end

    if shouldBurstTires then
        for i = 1, 4 do
            SetVehicleTyreBurst(currentVehicle, i, false, 990.0)
        end
    end

    if bodyHealth < 1000 then
        SetVehicleBodyHealth(currentVehicle, 985.1)
    end
end


function TakeOutImpound(vehicleData)
    local spawnCoords = Config.Locations['impound'][PoliceJobState.currentGarage]
    if not spawnCoords then 
        return TMGCore.Functions.Notify("Invalid spawn coordinates.", "error") 
    end

    TMGCore.Functions.TriggerCallback('TMGCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        TMGCore.Functions.SetVehicleProperties(veh, json.decode(vehicleData.mods))
        SetVehicleNumberPlateText(veh, vehicleData.plate)
        SetVehicleDirtLevel(veh, 0.0)
        SetEntityHeading(veh, spawnCoords.w)
        exports[Config.FuelResource]:SetFuel(veh, vehicleData.fuel)
        doCarDamage(veh, vehicleData) 
        TriggerServerEvent('police:server:TakeOutImpound', vehicleData.plate, PoliceJobState.currentGarage)
        closeMenuFull()
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TriggerEvent('vehiclekeys:client:SetOwner', TMGCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true, true)
        print("^5[TMG]^7 Vehicle " .. vehicleData.plate .. " materialized and hydrated.")
    end, vehicleData.vehicle, spawnCoords, true)
end

function TakeOutVehicle(vehicleModel)
    local spawnCoords = Config.Locations['vehicle'][PoliceJobState.currentGarage]
    if not spawnCoords then return end
    TMGCore.Functions.TriggerCallback('TMGCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        SetCarItemsInfo()
        local plate = Lang:t('info.police_plate') .. tostring(math.random(1000, 9999))
        SetVehicleNumberPlateText(veh, plate)
        SetEntityHeading(veh, spawnCoords.w)
        exports[Config.FuelResource]:SetFuel(veh, 100.0) 
        closeMenuFull()
        local settings = Config.VehicleSettings[vehicleModel]
        if settings then
            if settings.extras then
                TMGCore.Shared.SetDefaultVehicleExtras(veh, settings.extras)
            end
            if settings.livery then
                SetVehicleLivery(veh, settings.livery)
            end
        end
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) 
        TriggerEvent('vehiclekeys:client:SetOwner', TMGCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
        print("^5[TMG]^7 Fleet cruiser " .. plate .. " materialized.")
    end, vehicleModel, spawnCoords, true)
end

function StartCuffRestrictionThread()
    CreateThread(function()
        while PoliceJobState.isCuffed do
            local ped = PlayerPedId()
            DisableControlAction(0, 24, true) 
            DisableControlAction(0, 25, true) 
            DisableControlAction(0, 22, true) 
            DisableControlAction(0, 75, true) 
            
            if not IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3) then
                TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(0)
        end
    end)
end

function MenuGarage(selectionIndex)
    local vehicleMenu = {
        {
            header = Lang:t('menu.garage_title'),
            isMenuHeader = true
        }
    }

    local playerGrade = TMGCore.Functions.GetPlayerData().job.grade.level

    for grade = 0, playerGrade do
        local authorizedVehicles = Config.AuthorizedVehicles[grade]
        
        if authorizedVehicles then
            for vehModel, label in pairs(authorizedVehicles) do
                vehicleMenu[#vehicleMenu + 1] = {
                    header = label,
                    txt = "", 
                    params = {
                        event = 'police:client:TakeOutVehicle', 
                        args = {
                            vehicle = vehModel,
                            currentSelection = selectionIndex 
                        }
                    }
                }
            end
        end
    end

    vehicleMenu[#vehicleMenu + 1] = {
        header = Lang:t('menu.close'),
        params = {
            event = 'tmg-menu:client:closeMenu'
        }
    }

    exports['tmg-menu']:openMenu(vehicleMenu)
    
    print("^5[TMG]^7 Garage menu built with cumulative permissions for Grade: " .. playerGrade)
end

function MenuImpound(selectionIndex)
    local impoundMenu = {
        {
            header = Lang:t('menu.impound'),
            isMenuHeader = true
        }
    }

    TMGCore.Functions.TriggerCallback('police:GetImpoundedVehicles', function(vehicles)
        local hasVehicles = false

        if not vehicles then
            TMGCore.Functions.Notify(Lang:t('error.no_impound'), 'error', 5000)
        else
            hasVehicles = true
            for _, vehData in pairs(vehicles) do
                local enginePercent = TMGCore.Shared.Round(vehData.engine / 10, 0)
                local currentFuel = vehData.fuel
                
                local vehicleInfo = TMGCore.Shared.Vehicles[vehData.vehicle]
                local vname = vehicleInfo and vehicleInfo.name or "Unknown Vehicle"

                impoundMenu[#impoundMenu + 1] = {
                    header = vname .. ' [' .. vehData.plate .. ']',
                    txt = Lang:t('info.vehicle_info', { value = enginePercent, value2 = currentFuel }),
                    params = {
                        event = 'police:client:TakeOutImpound', 
                        args = {
                            vehicle = vehData,
                            currentSelection = selectionIndex
                        }
                    }
                }
            end
        end

        if hasVehicles then
            impoundMenu[#impoundMenu + 1] = {
                header = Lang:t('menu.close'),
                params = { event = 'tmg-menu:client:closeMenu' }
            }
            
            exports['tmg-menu']:openMenu(impoundMenu)
            print("^5[TMG]^7 Impound menu materialized for selection index: " .. selectionIndex)
        end
    end)
end

function closeMenuFull()
    exports['tmg-menu']:closeMenu()
end

RegisterNUICallback('closeFingerprint', function(_, cb)
    SetNuiFocus(false, false)
    PoliceJobState.InZone.fingerprint = false
    cb('ok')
    print("^5[TMG]^7 Fingerprint NUI session closed. Releasing entity focus.")
end)

RegisterNetEvent('police:client:spawnObjectEntity', function(objectId, type, playerSource)
    local playerPed = GetPlayerPed(GetPlayerFromServerId(playerSource))
    if not playerPed or playerPed == 0 then return end 

    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    
    local spawnPos = coords + (forward * 0.5)
    
    local spawnedObj = CreateObject(Config.Objects[type].model, spawnPos.x, spawnPos.y, spawnPos.z, true, false, false)
    
    PlaceObjectOnGroundProperly(spawnedObj)
    SetEntityHeading(spawnedObj, heading)
    FreezeEntityPosition(spawnedObj, Config.Objects[type].freeze)
    
    ObjectList[objectId] = {
        id = objectId,
        object = spawnedObj,
        coords = vector3(spawnPos.x, spawnPos.y, spawnPos.z - 0.3),
    }
end)

RegisterNetEvent('police:client:showFingerprint', function(targetPlayerId)
    openFingerprintUI()
    PoliceJobState.FingerPrintSessionId = targetPlayerId
    print("^5[TMG]^7 Fingerprint session initialized. Target: " .. targetPlayerId)
end)

RegisterNetEvent('police:client:showFingerprintId', function(fingerprintId)
    SendNUIMessage({
        type = 'updateFingerprintId',
        fingerprintId = fingerprintId
    })
    PlaySound(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', 0, 0, 1)
    print("^5[TMG]^7 Forensic ID materialized in UI: " .. fingerprintId)
end)

RegisterNUICallback('doFingerScan', function(_, cb)
    if PoliceJobState.FingerPrintSessionId then
        TriggerServerEvent('police:server:showFingerprintId', PoliceJobState.FingerPrintSessionId)
        print("^5[TMG]^7 Forensic scan request dispatched for Target ID: " .. PoliceJobState.FingerPrintSessionId)
    else
        TMGCore.Functions.Notify(Lang:t('error.none_nearby'), 'error')
    end
    cb('ok')
end)

RegisterNetEvent('police:client:SendEmergencyMessage', function(targetCoords, alertMessage)
    TriggerServerEvent('police:server:SendEmergencyMessage', targetCoords, alertMessage)
    TriggerEvent('police:client:CallAnim')
    print("^5[TMG]^7 Emergency signal dispatched. Message: " .. alertMessage)
end)

RegisterNetEvent('police:client:EmergencySound', function()
    PlaySound(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', 0, 0, 1)
    print("^5[TMG]^7 Emergency audio pulse received.")
end)


RegisterNetEvent('police:client:CallAnim', function()
    local isCalling = true
    local durationCounter = 5 
    
    loadAnimDict('cellphone@')

    TaskPlayAnim(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 3.0, -1, -1, 49, 0, false, false, false)
    
    CreateThread(function()
        while isCalling do
            Wait(1000) 
            durationCounter -= 1
            
            if durationCounter <= 0 then
                isCalling = false
                StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 1.0)
                print("^5[TMG]^7 Call animation cycle complete.")
            end
        end
    end)
end)

RegisterNetEvent('police:client:ImpoundVehicle', function(isFullImpound, impoundPrice)
    local vehicle = TMGCore.Functions.GetClosestVehicle()
    if not vehicle or vehicle == 0 then return end
    local bodyHealth = math.ceil(GetVehicleBodyHealth(vehicle))
    local engineHealth = math.ceil(GetVehicleEngineHealth(vehicle))
    local totalFuel = exports[Config.FuelResource]:GetFuel(vehicle)
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local vehiclePos = GetEntityCoords(vehicle)
    if #(playerPos - vehiclePos) < 5.0 and not IsPedInAnyVehicle(playerPed, false) then
        
        TMGCore.Functions.Progressbar('impounding_veh', Lang:t('progressbar.impound'), 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'missheistdockssetup1clipboard@base',
            anim = 'base',
            flags = 1,
        }, {
            model = 'prop_notepad_01',
            bone = 18905,
            coords = { x = 0.1, y = 0.02, z = 0.05 },
            rotation = { x = 10.0, y = 0.0, z = 0.0 },
        }, {
            model = 'prop_pencil_01',
            bone = 58866,
            coords = { x = 0.11, y = -0.02, z = 0.001 },
            rotation = { x = -120.0, y = 0.0, z = 0.0 },
        }, function() 
            local plate = TMGCore.Functions.GetPlate(vehicle)
            
            TriggerServerEvent('police:server:Impound', plate, isFullImpound, impoundPrice, bodyHealth, engineHealth, totalFuel)

            local timeout = 0
            while not NetworkHasControlOfEntity(vehicle) and timeout < 50 do
                NetworkRequestControlOfEntity(vehicle)
                Wait(100)
                timeout += 1
            end

            TMGCore.Functions.DeleteVehicle(vehicle)
            TriggerEvent('TMGCore:Notify', Lang:t('success.impounded'), 'success')
            ClearPedTasks(playerPed)
            
        end, function() 
            ClearPedTasks(playerPed)
            TriggerEvent('TMGCore:Notify', Lang:t('error.canceled'), 'error')
        end)
    end
end)

RegisterNetEvent('police:client:CheckStatus', function()
    local PlayerData = TMGCore.Functions.GetPlayerData()
    if PlayerData.job.type ~= 'leo' then return end
    local targetPed, distance = GetClosestPlayer()

    if targetPed ~= -1 and distance < 5.0 then
        local targetServerId = GetPlayerServerId(targetPed)
        
        TMGCore.Functions.TriggerCallback('police:GetPlayerStatus', function(forensicResults)
            if forensicResults and next(forensicResults) then
                for _, statusText in pairs(forensicResults) do
                    TMGCore.Functions.Notify(tostring(statusText))
                end
                print("^5[TMG]^7 Forensic scan complete. Results materialized for ID: " .. targetServerId)
            else
                TMGCore.Functions.Notify("Subject appears to have no noticeable status.", "primary")
            end
        end, targetServerId)
    else
        TMGCore.Functions.Notify(Lang:t('error.none_nearby'), 'error')
    end
end)

RegisterNetEvent('police:client:VehicleMenuHeader', function(data)
    if not data or not data.currentSelection then return end
    PoliceJobState.currentGarage = data.currentSelection
    MenuGarage(PoliceJobState.currentGarage)
    print("^5[TMG]^7 Garage header initialized for Location ID: " .. PoliceJobState.currentGarage)
end)

RegisterNetEvent('police:client:ImpoundMenuHeader', function(data)
    if not data or not data.currentSelection then return end
    PoliceJobState.currentGarage = data.currentSelection
    MenuImpound(PoliceJobState.currentGarage)
    print("^5[TMG]^7 Impound header initialized for Location ID: " .. PoliceJobState.currentGarage)
end)

RegisterNetEvent('police:client:TakeOutImpound', function(data)
    if PoliceJobState.InZone.impound then
        local vehicleData = data.vehicle
        
        if vehicleData then
            TakeOutImpound(vehicleData)
            
            print("^5[TMG]^7 Gatekeeper verified: Officer is in zone. Spawning " .. (vehicleData.plate or "Unknown"))
        end
    else
        TMGCore.Functions.Notify("You are no longer at the impound lot.", "error")
    end
end)

RegisterNetEvent('police:client:TakeOutVehicle', function(data)
    if PoliceJobState.InZone.garage then
        local vehicleModel = data.vehicle
        if vehicleModel then
            TakeOutVehicle(vehicleModel)
            print("^5[TMG]^7 Gatekeeper verified: Officer in garage zone. Materializing " .. vehicleModel)
        end
    else
        TMGCore.Functions.Notify("You are no longer at the police garage.", "error")
    end
end)

RegisterNetEvent('police:client:EvidenceStashDrawer', function()
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)
    local evidenceIndex = 0

    for i = 1, #Config.Locations['evidence'] do
        local evidenceCoords = Config.Locations['evidence'][i]
        if #(pos - vector3(evidenceCoords.x, evidenceCoords.y, evidenceCoords.z)) < 2.0 then
            evidenceIndex = i
            break 
        end
    end

    local targetLocker = Config.Locations['evidence'][evidenceIndex]
    if not targetLocker then return end

    if #(pos - targetLocker) <= 1.0 then
        local dialog = exports['tmg-input']:ShowInput({
            header = Lang:t('info.evidence_stash', { value = evidenceIndex }),
            submitText = 'Open Archive',
            inputs = {
                {
                    type = 'number',
                    isRequired = true,
                    name = 'slot',
                    text = Lang:t('info.slot') 
                }
            }
        })

        if dialog and dialog.slot then
            local stashName = Lang:t('info.current_evidence', { 
                value = evidenceIndex, 
                value2 = dialog.slot 
            })
            
            TriggerServerEvent('tmg-policejob:server:evidence', stashName)
            
            print("^5[TMG]^7 Accessing Evidence Archive: " .. stashName)
        end
    else
        exports['tmg-menu']:closeMenu()
    end
end)

RegisterNetEvent('tmg-policejob:ToggleDuty', function()
    TriggerServerEvent('TMGCore:ToggleDuty')
    TriggerServerEvent('police:server:UpdateCurrentCops')
    TriggerServerEvent('police:server:UpdateBlips')
    print("^5[TMG]^7 Duty status transition signal dispatched to central servers.")
end)


RegisterNetEvent('police:client:CuffPlayer', function()
    if not PlayerJob.onduty or PlayerJob.type ~= 'leo' then return end
    
    local target, distance = GetClosestPlayer()
    if target ~= -1 and distance < 2.5 then
        local targetServerId = GetPlayerServerId(target)
        
        loadAnimDict("mp_arresting")
        TaskPlayAnim(PlayerPedId(), "mp_arresting", "a_uncuff", 8.0, -8.0, -1, 49, 0, false, false, false)
        
        TriggerServerEvent("police:server:CuffPlayer", targetServerId)
    else
        TMGCore.Functions.Notify(Lang:t('error.none_nearby'), 'error')
    end
end)

RegisterNetEvent('police:client:GetCuffed', function()
    local ped = PlayerPedId()
    PoliceJobState.isCuffed = not PoliceJobState.isCuffed
    
    loadAnimDict("mp_arresting")
    
    if PoliceJobState.isCuffed then
        TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
        SetEnableHandcuffs(ped, true)
    else
        ClearPedTasks(ped)
        SetEnableHandcuffs(ped, false)
    end
    
    if PoliceJobState.isCuffed then 
        StartCuffRestrictionThread() 
    end
end)

RegisterNetEvent('police:client:EscortPlayer', function()
    local target, distance = GetClosestPlayer()
    if target ~= -1 and distance < 2.5 then
        TriggerServerEvent("police:server:EscortPlayer", GetPlayerServerId(target))
    end
end)

RegisterNetEvent('police:client:GetEscorted', function(playerId)
    local ped = PlayerPedId()
    local officerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
    PoliceJobState.isEscorting = not PoliceJobState.isEscorting
    if PoliceJobState.isEscorting then
        AttachEntityToEntity(ped, officerPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    else
        DetachEntity(ped, true, false)
    end
end)

RegisterNetEvent('tmg-police:client:scanFingerPrint', function()
    local targetPed, distance = GetClosestPlayer()
    local playerPed = PlayerPedId()

    if targetPed ~= -1 and distance < 2.5 then
        if not IsPedInAnyVehicle(playerPed, false) then
            local targetServerId = GetPlayerServerId(targetPed)
            TriggerServerEvent('police:server:showFingerprint', targetServerId)
            
            print("^5[TMG]^7 Proximity check passed. Forensic sequence initiated for ID: " .. targetServerId)
        else
            TMGCore.Functions.Notify("You cannot perform a scan while inside a vehicle.", "error")
        end
    else
        TMGCore.Functions.Notify(Lang:t('error.none_nearby'), 'error')
    end
end)

RegisterNetEvent('police:client:PutInVehicle', function()
    local target, distance = GetClosestPlayer()
    if target ~= -1 and distance < 2.5 then
        TriggerServerEvent("police:server:PutInVehicle", GetPlayerServerId(target))
    end
end)

RegisterNetEvent('police:client:GetPutInVehicle', function()
    local ped = PlayerPedId()
    local vehicle = TMGCore.Functions.GetClosestVehicle()
    
    if vehicle and vehicle ~= 0 then
        for i = 1, 2 do
            if IsVehicleSeatFree(vehicle, i) then
                TaskWarpPedIntoVehicle(ped, vehicle, i)
                return
            end
        end
    end
end)

RegisterNetEvent('tmg-police:client:spawnHelicopter', function(locationKey)
    local playerPed = PlayerPedId()

    if IsPedInAnyVehicle(playerPed, false) then
        local currentVeh = GetVehiclePedIsIn(playerPed)
        TMGCore.Functions.DeleteVehicle(currentVeh)
        print("^5[TMG]^7 Aerial asset stored. Hangar cleared.")
    else
        local spawnCoords = Config.Locations['helicopter'][locationKey]
        if not spawnCoords then 
            local pPos = GetEntityCoords(playerPed)
            spawnCoords = vector4(pPos.x, pPos.y, pPos.z, GetEntityHeading(playerPed)) 
        end

        TMGCore.Functions.TriggerCallback('TMGCore:Server:SpawnVehicle', function(netId)
            local heli = NetToVeh(netId)
            
            SetVehicleLivery(heli, 0)
            SetVehicleMod(heli, 0, 48)
            
            local plate = 'ZULU' .. tostring(math.random(1000, 9999))
            SetVehicleNumberPlateText(heli, plate)
            
            SetEntityHeading(heli, spawnCoords.w)
            exports[Config.FuelResource]:SetFuel(heli, 100.0) 
            closeMenuFull()
            
            TaskWarpPedIntoVehicle(playerPed, heli, -1)
            TriggerEvent('vehiclekeys:client:SetOwner', TMGCore.Functions.GetPlate(heli))
            SetVehicleEngineOn(heli, true, true)
            
            print("^5[TMG]^7 Zulu unit " .. plate .. " is flight-ready.")
        end, Config.PoliceHelicopter, spawnCoords, true)
    end
end)



local isDutyListenerActive = false

local function StartDutyListener()
    if isDutyListenerActive then return end
    isDutyListenerActive = true

    CreateThread(function()
        while isDutyListenerActive do
            if PlayerJob.type == 'leo' then
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('TMGCore:ToggleDuty')
                    TriggerServerEvent('police:server:UpdateCurrentCops')
                    TriggerServerEvent('police:server:UpdateBlips')
                    isDutyListenerActive = false
                    break
                end
            else
                isDutyListenerActive = false
                break
            end
            Wait(0)
        end
    end)
    print("^5[TMG]^7 Duty input listener activated. Listening for [E] pulse.")
end





local function StartInteractionListener(zoneName, action, isServer, isVehicleAction)
    CreateThread(function()
        while PoliceJobState.InZone[zoneName] do
            Wait(0)
            if PlayerJob.type == 'leo' and PlayerJob.onduty then
                local playerPed = PlayerPedId()
                if IsControlJustReleased(0, 38) then
                    if isVehicleAction then
                        if IsPedInAnyVehicle(playerPed, false) then
                            TMGCore.Functions.DeleteVehicle(GetVehiclePedIsIn(playerPed))
                            break 
                        end
                    else
                        if not IsPedInAnyVehicle(playerPed, false) then
                            if isServer then TriggerServerEvent(action) else TriggerEvent(action) end
                            break
                        end
                    end
                end
            else break end
        end
    end)
end

local interactionMap = {
    { key = 'duty',        event = 'tmg-policejob:ToggleDuty',            icon = 'fas fa-sign-in-alt', label = 'target.sign_in',           type = 'client', zoneSize = 0.5 },
    { key = 'stash',       event = 'tmg-policejob:server:stash',          icon = 'fas fa-dungeon',     label = 'target.open_personal_stash', type = 'server', zoneSize = 1.0 },
    { key = 'trash',       event = 'tmg-policejob:server:trash',          icon = 'fas fa-trash',       label = 'target.open_trash',            type = 'server', zoneSize = 0.5 },
    { key = 'fingerprint', event = 'tmg-police:client:scanFingerPrint',   icon = 'fas fa-fingerprint', label = 'target.open_fingerprint',      type = 'client', zoneSize = 0.5 },
    { key = 'evidence',    event = 'police:client:EvidenceStashDrawer', icon = 'fas fa-archive',     label = 'target.open_evidence_stash',   type = 'client', zoneSize = 0.5 },
    { key = 'armory',      event = 'police:client:ArmoryMenu',           icon = 'fas fa-gun',         label = 'target.armory',                type = 'client', zoneSize = 0.5 },
    { key = 'boss',        event = 'tmg-bossmenu:client:OpenMenu',        icon = 'fas fa-briefcase',   label = 'target.boss_menu',             type = 'client', zoneSize = 0.5 }
}

CreateThread(function()
    if Config.UseTarget then
        for _, point in pairs(interactionMap) do
            if Config.Locations[point.key] then 
                for i, coords in ipairs(Config.Locations[point.key]) do
                    exports['tmg-target']:AddCircleZone("Police" .. point.key .. "_" .. i, vector3(coords.x, coords.y, coords.z), point.zoneSize, {
                        name = "Police" .. point.key .. "_" .. i, useZ = true,
                    }, {
                        options = { { type = point.type, event = point.event, icon = point.icon, label = Lang:t(point.label), jobType = 'leo' } },
                        distance = 1.5
                    })
                end
            end
        end
    else
        for _, point in pairs(interactionMap) do
            if Config.Locations[point.key] then
                local zones = {}
                for i, v in ipairs(Config.Locations[point.key]) do
                    zones[#zones + 1] = BoxZone:Create(vector3(v.x, v.y, v.z), 1.5, 1.5, { name = "Police" .. point.key .. "_" .. i, minZ = v.z - 1, maxZ = v.z + 1 })
                end
                local combo = ComboZone:Create(zones, { name = point.key .. "Combo" })
                combo:onPlayerInOut(function(isInside)
                    PoliceJobState.InZone[point.key] = isInside
                    if isInside and PlayerJob.type == 'leo' then
                        local prompt = point.key == 'duty' and (PlayerJob.onduty and "info.off_duty" or "info.on_duty") or "info." .. point.key .. "_enter"
                        exports['tmg-core']:DrawText(Lang:t(prompt), 'left')
                        StartInteractionListener(point.key, point.event, point.type == 'server', false)
                    else exports['tmg-core']:HideText() end
                end)
            end
        end
    end
end)

local vehZoneMap = {
    ['helicopter'] = { state = 'helicopter', size = 10.0, promptTake = 'info.take_heli', promptStore = 'info.store_heli', event = 'tmg-police:client:spawnHelicopter', isMenu = false },
    ['impound']    = { state = 'impound',    size = 1.0,  promptStore = 'info.impound_veh', menuHeader = 'menu.pol_impound', event = 'police:client:ImpoundMenuHeader', isMenu = true },
    ['vehicle']    = { state = 'garage',     size = 3.0,  promptStore = 'info.store_veh',   menuHeader = 'menu.pol_garage',  event = 'police:client:VehicleMenuHeader', isMenu = true }
}

CreateThread(function()
    for _, station in pairs(Config.Locations["stations"]) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 60)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        SetBlipColour(blip, 29)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(station.label)
        EndTextCommandSetBlipName(blip)
    end

    if not Config.UseTarget then
        for configKey, data in pairs(vehZoneMap) do
            local zones = {}
            if Config.Locations[configKey] then
                for i, coords in ipairs(Config.Locations[configKey]) do
                    zones[#zones + 1] = BoxZone:Create(vector3(coords.x, coords.y, coords.z), data.size, data.size, { name = "Police_" .. configKey .. "_" .. i, minZ = coords.z - 1.5, maxZ = coords.z + 2.0 })
                end

                local combo = ComboZone:Create(zones, { name = configKey .. "Combo" })
                combo:onPlayerInOut(function(isInside, currentPoint)
                    PoliceJobState.InZone[data.state] = isInside
                    if isInside and PlayerJob.type == 'leo' and PlayerJob.onduty then
                        local playerPed = PlayerPedId()
                        if IsPedInAnyVehicle(playerPed, false) then
                            exports['tmg-core']:DrawText(Lang:t(data.promptStore), 'left')
                            StartInteractionListener(data.state, nil, false, true)
                        else
                            if data.isMenu then
                                local currentSelection = 0
                                for i, v in ipairs(Config.Locations[configKey]) do
                                    if #(currentPoint - vector3(v.x, v.y, v.z)) < 5.0 then currentSelection = i break end
                                end
                                exports['tmg-menu']:showHeader({{
                                    header = Lang:t(data.menuHeader),
                                    params = { event = data.event, args = { currentSelection = currentSelection } }
                                }}) 
                            else
                                exports['tmg-core']:DrawText(Lang:t(data.promptTake), 'left')
                                StartInteractionListener(data.state, data.event, false, false)
                            end
                        end
                    else
                        exports['tmg-menu']:closeMenu()
                        exports['tmg-core']:HideText()
                    end
                end)
            end
        end
    end
end)
