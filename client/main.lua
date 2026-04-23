TMGCore = exports['tmg-core']:GetCoreObject()
PlayerJob = {}

PoliceJobState = {
    currentGarage = 1,
    FingerPrintSessionId = nil,
    InZone = {
        fingerprint = false,
        stash = false,
        trash = false,
        armoury = false,
        helicopter = false,
        impound = false,
        garage = false,
        evidence = false,
        duty = false 
    },
    isEscorting = false,
    isCuffed = false,
    escortTargetId = nil
}

local DutyBlips = {}

local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local ped = GetPlayerPed(playerId)
    local blip = GetBlipFromEntity(ped)

    if not DoesBlipExist(blip) then
        
        if NetworkIsPlayerActive(playerId) then
            blip = AddBlipForEntity(ped)
        else
            
            blip = AddBlipForCoord(playerLocation.x, playerLocation.y, playerLocation.z)
        end

        SetBlipSprite(blip, 1)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.ceil(playerLocation.w))
        SetBlipScale(blip, 1.0)
        
        SetBlipColour(blip, (playerJob == 'police' and 38 or 5))
        
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(playerLabel)
        EndTextCommandSetBlipName(blip)
        
        DutyBlips[#DutyBlips + 1] = blip
    end

    if GetBlipFromEntity(PlayerPedId()) == blip then
        RemoveBlip(blip)
    end
end

local function UpdateIdentityNexus()
    local PlayerData = TMGCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job then
        PlayerJob = PlayerData.job
    end
end

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then UpdateIdentityNexus() end
end)

AddEventHandler('TMGCore:Client:OnPlayerLoaded', function()
    UpdateIdentityNexus()
    
    
    PoliceJobState.InZone.isCuffed = false
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent('police:server:UpdateCurrentCops')

    
    local player = TMGCore.Functions.GetPlayerData()
    if player.metadata.tracker then
        TriggerEvent('police:client:SetTracker', true)
    end
end)

RegisterNetEvent('TMGCore:Client:OnPlayerUnload', function()
    
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent('police:server:UpdateCurrentCops')
    
    PoliceJobState.InZone.isCuffed = false
    PoliceJobState.InZone.isEscorting = false
    PlayerJob = {}
    
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    
    for _, v in pairs(DutyBlips) do RemoveBlip(v) end
    DutyBlips = {}
end)

RegisterNetEvent('TMGCore:Client:SetDuty', function(newDuty)
    PlayerJob.onduty = newDuty
    TriggerServerEvent('police:server:UpdateBlips')
end)

RegisterNetEvent('TMGCore:Client:OnJobUpdate', function(JobInfo)
    
    if JobInfo.type ~= 'leo' and JobInfo.type ~= 'ems' then
        for _, v in pairs(DutyBlips) do RemoveBlip(v) end
        DutyBlips = {}
    end
    PlayerJob = JobInfo
    TriggerServerEvent('police:server:UpdateBlips')
end)



RegisterNetEvent('police:client:UpdateBlips', function(activeUnits)
    
    if PlayerJob and (PlayerJob.type == 'leo' or PlayerJob.type == 'ems') and PlayerJob.onduty then
        for _, v in pairs(DutyBlips) do RemoveBlip(v) end
        DutyBlips = {}

        if activeUnits then
            for _, data in pairs(activeUnits) do
                local id = GetPlayerFromServerId(data.source)
                CreateDutyBlips(id, data.label, data.job, data.location)
            end
        end
    end
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local locationLabel = GetStreetNameFromHashKey(street1) .. ' ' .. GetStreetNameFromHashKey(street2)
    
    TMGCore.Functions.Notify({ text = text, caption = locationLabel }, 'police')
    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)

    
    CreateThread(function()
        local alpha = 250
        local mainBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        local pulseBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

        SetBlipSprite(mainBlip, 60)
        SetBlipSprite(pulseBlip, 161)
        SetBlipColour(mainBlip, 1)
        SetBlipColour(pulseBlip, 1)
        SetBlipScale(mainBlip, 0.8)
        SetBlipScale(pulseBlip, 2.0)
        
        PulseBlip(pulseBlip)

        while alpha > 0 do
            Wait(720) 
            alpha = alpha - 1
            SetBlipAlpha(mainBlip, alpha)
            SetBlipAlpha(pulseBlip, alpha)
            if alpha == 0 then
                RemoveBlip(mainBlip)
                RemoveBlip(pulseBlip)
                break
            end
        end
    end)
end)



RegisterNetEvent('police:client:SendToJail', function(time)
    
    PoliceJobState.InZone.isCuffed = false
    PoliceJobState.InZone.isEscorting = false
    
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerEvent('prison:client:Enter', time)
    print("^5[TMG]^7 Player transition to prison initiated. All kinetic locks released.")
end)



CreateThread(function()
    for _, station in pairs(Config.Locations['stations']) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 60)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 29)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)
