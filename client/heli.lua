

HeliState = {
    
    fov_max = 80.0,
    fov_min = 10.0,
    zoomspeed = 2.0,
    speed_lr = 3.0,
    speed_ud = 3.0,
    
    helicam = false,
    fov = 45.0, 
    vision_state = 0, 
    spotlight_active = false,
    
    isScanning = false,
    isScanned = false,
    scanValue = 0,
    vehicle_detected = nil,
    locked_on_vehicle = nil
}



local function IsPlayerInPolmav()
    local vehicle = GetVehiclePedIsIn(PlayerPedId())
    return IsVehicleModel(vehicle, GetHashKey(Config.PoliceHelicopter))
end

local function IsHeliHighEnough(heli)
    return GetEntityHeightAboveGround(heli) > 1.5
end

local function ChangeVision()
    
    if HeliState.vision_state == 0 then
        SetNightvision(true)
        HeliState.vision_state = 1
    elseif HeliState.vision_state == 1 then
        SetNightvision(false)
        SetSeethrough(true)
        HeliState.vision_state = 2
    else
        SetSeethrough(false)
        HeliState.vision_state = 0
    end
end

local function HideHUDThisFrame()
    HideHelpTextThisFrame()
    HideHudAndRadarThisFrame()
    local components = {1, 2, 3, 4, 11, 12, 13, 15, 18, 19}
    for _, id in ipairs(components) do HideHudComponentThisFrame(id) end
end



local function CheckInputRotation(cam, zoomvalue)
    local rightX = GetDisabledControlNormal(0, 220)
    local rightY = GetDisabledControlNormal(0, 221)
    local rotation = GetCamRot(cam, 2)
    if rightX ~= 0.0 or rightY ~= 0.0 then
        local new_z = rotation.z + rightX * -1.0 * (HeliState.speed_ud) * (zoomvalue + 0.1)
        
        local new_x = math.max(math.min(20.0, rotation.x + rightY * -1.0 * (HeliState.speed_lr) * (zoomvalue + 0.1)), -89.5)
        SetCamRot(cam, new_x, 0.0, new_z, 2)
    end
end

local function HandleZoom(cam)
    if IsControlJustPressed(0, 241) then HeliState.fov = math.max(HeliState.fov - HeliState.zoomspeed, HeliState.fov_min) end
    if IsControlJustPressed(0, 242) then HeliState.fov = math.min(HeliState.fov + HeliState.zoomspeed, HeliState.fov_max) end
    
    local current_fov = GetCamFov(cam)
    if math.abs(HeliState.fov - current_fov) < 0.1 then HeliState.fov = current_fov end
    
    SetCamFov(cam, current_fov + (HeliState.fov - current_fov) * 0.05)
end

local function GetVehicleInView(cam)
    local coords = GetCamCoord(cam)
    local rot = GetCamRot(cam, 2)
    
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    local forward_vector = vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
    
    local rayhandle = CastRayPointToPoint(coords, coords + (forward_vector * 400.0), 10, GetVehiclePedIsIn(PlayerPedId()), 0)
    local _, _, _, _, entityHit = GetRaycastResult(rayhandle)
    return (entityHit > 0 and IsEntityAVehicle(entityHit)) and entityHit or nil
end

local function RenderVehicleInfo(vehicle)
    local pos = GetEntityCoords(vehicle)
    local model = GetEntityModel(vehicle)
    local speed = math.ceil(GetEntitySpeed(vehicle) * 3.6) 
    local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local streetLabel = GetStreetNameFromHashKey(s1) .. (s2 ~= 0 and (' | ' .. GetStreetNameFromHashKey(s2)) or '')
    
    SendNUIMessage({
        type = 'heliupdateinfo',
        model = GetLabelText(GetDisplayNameFromVehicleModel(model)),
        plate = QBCore.Functions.GetPlate(vehicle),
        speed = speed,
        street = streetLabel,
    })
end



CreateThread(function()
    while true do
        local sleep = 2000
        if LocalPlayer.state.isLoggedIn and PlayerJob.type == 'leo' and PlayerJob.onduty then
            if IsPlayerInPolmav() then
                sleep = 0
                local lPed, heli = PlayerPedId(), GetVehiclePedIsIn(PlayerPedId())

                
                if IsHeliHighEnough(heli) then
                    if IsControlJustPressed(0, 51) then 
                        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                        HeliState.helicam = true
                        SendNUIMessage({ type = 'heliopen' })
                    end
                    if IsControlJustPressed(0, 154) and (GetPedInVehicleSeat(heli, 1) == lPed or GetPedInVehicleSeat(heli, 2) == lPed) then 
                        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                        TaskRappelFromHeli(lPed, 1)
                    end
                end

                if IsControlJustPressed(0, 74) and (GetPedInVehicleSeat(heli, -1) == lPed or GetPedInVehicleSeat(heli, 0) == lPed) then 
                    HeliState.spotlight_active = not HeliState.spotlight_active
                    TriggerServerEvent('heli:server:spotlight', HeliState.spotlight_active)
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                end

                
                if HeliState.helicam then
                    SetTimecycleModifier('heliGunCam')
                    SetTimecycleModifierStrength(0.3)
                    local scaleform = RequestScaleformMovie('HELI_CAM')
                    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

                    local cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
                    AttachCamToEntity(cam, heli, 0.0, 0.0, -1.5, true)
                    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(heli))
                    SetCamFov(cam, HeliState.fov)
                    RenderScriptCams(true, false, 0, 1, 0)
                    
                    PushScaleformMovieFunction(scaleform, 'SET_CAM_LOGO')
                    PushScaleformMovieFunctionParameterInt(0) 
                    PopScaleformMovieFunctionVoid()

                    print("^5[TMG]^7 Polmav optical node engaged.")

                    while HeliState.helicam and not IsEntityDead(lPed) and (GetVehiclePedIsIn(lPed) == heli) and IsHeliHighEnough(heli) do
                        if IsControlJustPressed(0, 51) then 
                            HeliState.helicam = false
                            print("^5[TMG]^7 Optical node disengaged.")
                        elseif IsControlJustPressed(0, 25) then 
                            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                            ChangeVision()
                        end

                        local zoomvalue = 0
                        if HeliState.locked_on_vehicle then
                            if DoesEntityExist(HeliState.locked_on_vehicle) then
                                PointCamAtEntity(cam, HeliState.locked_on_vehicle, 0.0, 0.0, 0.0, true)
                                if IsControlJustPressed(0, 22) then 
                                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                                    local rot = GetCamRot(cam, 2)
                                    HeliState.fov = GetCamFov(cam)
                                    DestroyCam(cam, false)
                                    cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
                                    AttachCamToEntity(cam, heli, 0.0, 0.0, -1.5, true)
                                    SetCamRot(cam, rot, 2); SetCamFov(cam, HeliState.fov)
                                    RenderScriptCams(true, false, 0, 1, 0)
                                    HeliState.locked_on_vehicle, HeliState.isScanned, HeliState.scanValue = nil, false, 0
                                    SendNUIMessage({ type = 'disablescan' })
                                end
                            else
                                HeliState.locked_on_vehicle, HeliState.isScanned = nil, false
                                SendNUIMessage({ type = 'disablescan' })
                            end
                        else
                            zoomvalue = (1.0 / (HeliState.fov_max - HeliState.fov_min)) * (HeliState.fov - HeliState.fov_min)
                            CheckInputRotation(cam, zoomvalue)
                            HeliState.vehicle_detected = GetVehicleInView(cam)
                            HeliState.isScanning = DoesEntityExist(HeliState.vehicle_detected)
                        end

                        HandleZoom(cam)
                        HideHUDThisFrame()
                        
                        
                        PushScaleformMovieFunction(scaleform, 'SET_ALT_FOV_HEADING')
                        PushScaleformMovieFunctionParameterFloat(GetEntityCoords(heli).z)
                        PushScaleformMovieFunctionParameterFloat(zoomvalue)
                        PushScaleformMovieFunctionParameterFloat(GetCamRot(cam, 2).z)
                        PopScaleformMovieFunctionVoid()
                        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
                        Wait(0)
                    end

                    
                    HeliState.helicam = false
                    HeliState.isScanned, HeliState.scanValue = false, 0
                    ClearTimecycleModifier()
                    HeliState.fov = (HeliState.fov_max + HeliState.fov_min) * 0.5
                    RenderScriptCams(false, false, 0, 1, 0)
                    SetScaleformMovieAsNoLongerNeeded(scaleform)
                    DestroyCam(cam, false)
                    SetNightvision(false); SetSeethrough(false)
                    SendNUIMessage({ type = 'disablescan' })
                    SendNUIMessage({ type = 'heliclose' })
                end
            end
        end
        Wait(sleep)
    end
end)



CreateThread(function()
    while true do
        local sleep = 1000
        if HeliState.helicam then
            sleep = 1
            if HeliState.isScanning and not HeliState.isScanned then
                if HeliState.scanValue < 100 then
                    HeliState.scanValue += 1
                    SendNUIMessage({ type = 'heliscan', scanvalue = HeliState.scanValue })
                    if HeliState.scanValue == 100 then
                        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                        HeliState.locked_on_vehicle = HeliState.vehicle_detected
                        HeliState.isScanning, HeliState.isScanned = false, true
                    end
                    Wait(10)
                end
            elseif HeliState.isScanned and not HeliState.isScanning and HeliState.locked_on_vehicle then
                HeliState.scanValue = 100
                RenderVehicleInfo(HeliState.locked_on_vehicle)
                Wait(100)
            else
                HeliState.scanValue = 0
                Wait(500)
            end
        end
        Wait(sleep)
    end
end)


RegisterNetEvent('heli:client:spotlight', function(serverID, state)
    local heli = GetVehiclePedIsIn(GetPlayerPed(GetPlayerFromServerId(serverID)), false)
    SetVehicleSearchlight(heli, state, false)
end)
