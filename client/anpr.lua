

ANPRState = {
    lastRadar = nil,
    HasAlreadyEnteredMarker = false,
    ScanRadius = 20.0 
}



local function IsInMarker(playerPos, speedCam)
    
    return #(playerPos - speedCam) < ANPRState.ScanRadius
end



local function HandleSpeedCam(speedCam, radarID)
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local isInMarker = IsInMarker(playerPos, speedCam)

    
    if isInMarker and not ANPRState.HasAlreadyEnteredMarker and ANPRState.lastRadar == nil then
        ANPRState.HasAlreadyEnteredMarker = true
        ANPRState.lastRadar = radarID
        
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle == 0 then return end
        
        
        local is_driver = GetPedInVehicleSeat(vehicle, -1) == playerPed
        if not is_driver then return end
        
        
        if GetVehicleClass(vehicle) == 18 then return end
        
        local plate = TMGCore.Functions.GetPlate(vehicle)
        
        
        TMGCore.Functions.TriggerCallback('police:server:IsPlateFlagged', function(isFlagged)
            if isFlagged then
                local coords = Config.Radars[radarID]
                TriggerServerEvent('police:server:FlaggedPlateTriggered', coords, plate)
                print("^5[TMG]^7 Flagged plate detected at radar ID: " .. radarID .. " | Plate: " .. plate)
            end
        end, plate)
    end

    
    if not isInMarker and ANPRState.HasAlreadyEnteredMarker and ANPRState.lastRadar == radarID then
        ANPRState.HasAlreadyEnteredMarker = false
        ANPRState.lastRadar = nil
    end
end



if Config.EnableRadars then
    CreateThread(function()
        print("^5[TMG]^7 ANPR scanning grid materialized.")
        while true do
            
            if IsPedInAnyVehicle(PlayerPedId(), false) then
                for i = 1, #Config.Radars do
                    local value = Config.Radars[i]
                    HandleSpeedCam(value, i)
                end
                Wait(200)
            else
                Wait(2500)
            end
        end
    end)
end
