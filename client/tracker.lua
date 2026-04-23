RegisterNetEvent('police:client:CheckDistance', function()
    local targetPed, distance = GetClosestPlayer()
    
    if targetPed ~= -1 and distance < 2.5 then
        local targetServerId = GetPlayerServerId(targetPed)
        TriggerServerEvent('police:server:SetTracker', targetServerId)
        print("^5[TMG]^7 Ankle tracker deployment initiated for ID: " .. targetServerId)
    else
        TMGCore.Functions.Notify(Lang:t('error.none_nearby'), 'error')
    end
end)

RegisterNetEvent('police:client:SetTracker', function(isAddingTracker)
    local trackerClothingData = {
        outfitData = {
            ['accessory'] = { item = -1, texture = 0 }, 
        }
    }

    if isAddingTracker then
        trackerClothingData.outfitData['accessory'] = { item = 13, texture = 0 }
        TMGCore.Functions.Notify("Ankle monitor has been secured.", "success")
    else
        TMGCore.Functions.Notify("Ankle monitor has been removed.", "primary")
    end

    TriggerEvent('tmg-clothing:client:loadOutfit', trackerClothingData)
end)

RegisterNetEvent('police:client:SendTrackerLocation', function(requestId)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('police:server:SendTrackerLocation', coords, requestId)
end)

RegisterNetEvent('police:client:TrackerMessage', function(msg, coords)
    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)
    TMGCore.Functions.Notify(msg, 'police')

    CreateThread(function()
        local alpha = 250
        local trackerBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        
        SetBlipSprite(trackerBlip, 458) 
        SetBlipColour(trackerBlip, 1)   
        SetBlipScale(trackerBlip, 1.0)
        SetBlipAsShortRange(trackerBlip, true)
        
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Lang:t('info.ankle_location'))
        EndTextCommandSetBlipName(trackerBlip)

        while alpha > 0 do
            Wait(720) 
            alpha = alpha - 1
            SetBlipAlpha(trackerBlip, alpha)
            
            if alpha == 0 then
                RemoveBlip(trackerBlip)
                break
            end
        end
    end)
end)
