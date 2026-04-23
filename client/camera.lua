

local CamState = {
    currentIndex = 0,
    createdCamera = 0,
    instructionScaleform = nil
}



local function GetCurrentTime()
    
    return string.format("%02d:%02d", GetClockHours(), GetClockMinutes())
end

local function InstructionButton(ControlButton)
    ScaleformMovieMethodAddParamPlayerNameString(ControlButton)
end

local function InstructionButtonMessage(text)
    BeginTextCommandScaleformString('STRING')
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

local function CreateInstructionScaleform(name)
    local scaleform = RequestScaleformMovie(name)
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

    PushScaleformMovieFunction(scaleform, 'CLEAR_ALL')
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'SET_CLEAR_SPACE')
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
    PushScaleformMovieFunctionParameterInt(1)
    InstructionButton(GetControlInstructionalButton(1, 194, true)) 
    InstructionButtonMessage(Lang:t('info.close_camera'))
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'SET_BACKGROUND_COLOUR')
    PushScaleformMovieFunctionParameterInt(0, 0, 0, 80) 
    PopScaleformMovieFunctionVoid()

    return scaleform
end



local function ChangeSecurityCamera(x, y, z, r)
    if CamState.createdCamera ~= 0 then
        DestroyCam(CamState.createdCamera, 0)
        CamState.createdCamera = 0
    end

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', 1)
    SetCamCoord(cam, x, y, z)
    SetCamRot(cam, r.x, r.y, r.z, 2)
    RenderScriptCams(1, 0, 0, 1, 1)
    
    
    Wait(250)
    CamState.createdCamera = cam
    print("^5[TMG]^7 Optical node established at coordinates.")
end

local function CloseSecurityCamera()
    DestroyCam(CamState.createdCamera, 0)
    RenderScriptCams(0, 0, 1, 1, 1)
    CamState.createdCamera = 0
    CamState.instructionScaleform = nil 
    
    ClearTimecycleModifier('scanline_cam_cheap')
    SetFocusEntity(PlayerPedId())
    
    if Config.SecurityCameras.hideradar then
        DisplayRadar(true)
    end
    
    FreezeEntityPosition(PlayerPedId(), false)
    print("^5[TMG]^7 Surveillance session terminated. Focus returned to entity.")
end



RegisterNetEvent('police:client:ActiveCamera', function(cameraId)
    if Config.SecurityCameras.cameras[cameraId] then
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do Wait(0) end

        SendNUIMessage({
            type = 'enablecam',
            label = Config.SecurityCameras.cameras[cameraId].label,
            id = cameraId,
            connected = Config.SecurityCameras.cameras[cameraId].isOnline,
            time = GetCurrentTime(),
        })

        local coords = Config.SecurityCameras.cameras[cameraId].coords
        local rotation = Config.SecurityCameras.cameras[cameraId].r

        SetFocusArea(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z)
        ChangeSecurityCamera(coords.x, coords.y, coords.z, rotation)
        
        CamState.currentIndex = cameraId
        DoScreenFadeIn(250)
    elseif cameraId == 0 then
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do Wait(0) end
        
        CloseSecurityCamera()
        SendNUIMessage({ type = 'disablecam' })
        
        DoScreenFadeIn(250)
    else
        TMGCore.Functions.Notify(Lang:t('error.no_camera'), 'error')
    end
end)


RegisterNetEvent('police:client:DisableAllCameras', function()
    for k, _ in pairs(Config.SecurityCameras.cameras) do Config.SecurityCameras.cameras[k].isOnline = false end
    print("^5[TMG]^7 Global camera grid: OFFLINE.")
end)

RegisterNetEvent('police:client:EnableAllCameras', function()
    for k, _ in pairs(Config.SecurityCameras.cameras) do Config.SecurityCameras.cameras[k].isOnline = true end
    print("^5[TMG]^7 Global camera grid: ONLINE.")
end)

RegisterNetEvent('police:client:SetCamera', function(key, isOnline)
    if type(key) == 'table' then
        for _, v in pairs(key) do Config.SecurityCameras.cameras[v].isOnline = isOnline end
    elseif type(key) == 'number' then
        Config.SecurityCameras.cameras[key].isOnline = isOnline
    end
end)



CreateThread(function()
    while true do
        local sleep = 2000
        if CamState.createdCamera ~= 0 then
            sleep = 5
            
            
            if not CamState.instructionScaleform then
                CamState.instructionScaleform = CreateInstructionScaleform('instructional_buttons')
            end
            
            DrawScaleformMovieFullscreen(CamState.instructionScaleform, 255, 255, 255, 255, 0)
            SetTimecycleModifier('scanline_cam_cheap')
            SetTimecycleModifierStrength(1.0)

            if Config.SecurityCameras.hideradar then DisplayRadar(false) end

            
            if IsControlJustPressed(1, 177) then
                DoScreenFadeOut(250)
                while not IsScreenFadedOut() do Wait(0) end
                CloseSecurityCamera()
                SendNUIMessage({ type = 'disablecam' })
                DoScreenFadeIn(250)
            end

            
            if Config.SecurityCameras.cameras[CamState.currentIndex].canRotate then
                local getCameraRot = GetCamRot(CamState.createdCamera, 2)

                
                if IsControlPressed(0, 32) and getCameraRot.x <= 0.0 then 
                    SetCamRot(CamState.createdCamera, getCameraRot.x + 0.7, 0.0, getCameraRot.z, 2)
                elseif IsControlPressed(0, 8) and getCameraRot.x >= -50.0 then 
                    SetCamRot(CamState.createdCamera, getCameraRot.x - 0.7, 0.0, getCameraRot.z, 2)
                end

                if IsControlPressed(0, 34) then 
                    SetCamRot(CamState.createdCamera, getCameraRot.x, 0.0, getCameraRot.z + 0.7, 2)
                elseif IsControlPressed(0, 9) then 
                    SetCamRot(CamState.createdCamera, getCameraRot.x, 0.0, getCameraRot.z - 0.7, 2)
                end
            end
        end
        Wait(sleep)
    end
end)
