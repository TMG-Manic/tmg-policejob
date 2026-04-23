local FlaggedPlates = {}

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    local flags = exports['tmgnosql']:Find('flagged_plates', {})
    if flags then
        for _, data in pairs(flags) do
            FlaggedPlates[data.plate] = { 
                reason = data.reason,
                isflagged = true 
            }
        end
    end
    print("^5[TMG]^7 Traffic Registry Synchronized.")
end)

local function IsVehicleOwned(plate)
    if not plate then return false end
    
    local trimmedPlate = plate:gsub("%s+", "")

    local vehicle = exports['tmgnosql']:FetchOne('player_vehicles', 
        { ["plate"] = trimmedPlate }, 
        { ["_id"] = 1 } 
    )

    return vehicle ~= nil
end


RegisterNetEvent('tmg-police:server:impoundVehicle', function(plate, fullImpound, price, body, engine, fuel)
    local src = source
    local trimmedPlate = Trim(plate)
    price = price or 0
    
    if not IsVehicleOwned(trimmedPlate) then return end

    local newState = fullImpound and 2 or 0
    local depotPrice = fullImpound and 0 or price

    exports['tmgnosql']:UpdateOne('player_vehicles', 
        { ["plate"] = trimmedPlate }, 
        { ["$set"] = { 
            ["state"] = newState, 
            ["depotprice"] = depotPrice, 
            ["body"] = body, 
            ["engine"] = engine, 
            ["fuel"] = fuel 
        }}
    )
    local notifyMsg = fullImpound and Lang:t('info.vehicle_seized') or Lang:t('info.vehicle_taken_depot', { price = price })
    TriggerClientEvent('TMGCore:Notify', src, notifyMsg, 'primary')

    print(string.format("^5[TMG]^7 Impound: [%s] transitioned to State %d | Fine: $%d", trimmedPlate, newState, depotPrice))
end)

RegisterNetEvent('tmg-police:server:releaseImpound', function(plate, garage)
    local src = source
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    
    if not Config.Locations['impound'][garage] then return end
    local targetCoords = Config.Locations['impound'][garage]

    if #(playerCoords - targetCoords) > 10.0 then 
        return DropPlayer(src, 'TMG Mainframe: Unauthorized Remote Asset Retrieval') 
    end

    exports['tmgnosql']:UpdateOne('player_vehicles', 
        { ["plate"] = plate }, 
        { ["$set"] = { ["state"] = 0 } }
    )

    TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.impound_vehicle_removed'), 'success')

    print(string.format("^5[TMG]^7 Impound: Asset [%s] released from lot [%s]", plate, garage))
end)

TMGCore.Commands.Add('flagplate', 'Flag a plate in the Mainframe Surveillance Grid', { 
    { name = 'plate', help = 'Vehicle Plate' }, 
    { name = 'reason', help = 'Reason for Flag (e.g., Stolen, Felony Stop)' } 
}, true, function(source, args)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not (Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty) then 
        return TriggerClientEvent('TMGCore:Notify', src, "Mainframe: LEO Authorization Required.", "error") 
    end

    local plate = args[1]:upper()
    table.remove(args, 1)
    local reason = table.concat(args, ' ')
    if reason == "" then reason = "No reason specified" end

    exports['tmgnosql']:UpdateOne('flagged_plates', 
        { ["plate"] = plate }, 
        { ["$set"] = { 
            ["plate"] = plate, 
            ["reason"] = reason, 
            ["officer"] = Player.PlayerData.citizenid,
            ["timestamp"] = os.time() 
        } },
        { ["upsert"] = true } 
    )

    FlaggedPlates[plate] = { 
        ["isflagged"] = true, 
        ["reason"] = reason 
    }

    TriggerClientEvent('TMGCore:Notify', src, string.format("ALPR: Plate %s anchored in surveillance grid.", plate), "success")
    
    print(string.format("^5[TMG]^7 Surveillance: Plate [%s] flagged by %s for [%s]", plate, Player.PlayerData.citizenid, reason))
end)

TMGCore.Commands.Add('unflagplate', 'Remove a plate from the Surveillance Grid', { 
    { name = 'plate', help = 'Vehicle Plate' } 
}, true, function(source, args)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not (Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty) then 
        return TriggerClientEvent('TMGCore:Notify', src, "Mainframe: LEO Authorization Required.", "error") 
    end

    local plate = args[1]:upper()

    if not FlaggedPlates[plate] then
        return TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Plate is not currently flagged.", "error")
    end

    exports['tmgnosql']:DeleteOne('flagged_plates', { 
        ["plate"] = plate 
    })

    FlaggedPlates[plate] = nil

    TriggerClientEvent('TMGCore:Notify', src, string.format("ALPR: Plate %s cleared from active surveillance.", plate), "success")
    
    print(string.format("^5[TMG]^7 Surveillance: Plate [%s] cleared by Officer %s", plate, Player.PlayerData.citizenid))
end)



local ActiveSpotlights = {}


RegisterNetEvent('heli:server:spotlight', function(state)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' then return end

    if state then
        ActiveSpotlights[src] = true
    else
        ActiveSpotlights[src] = nil
    end

    TriggerClientEvent('heli:client:spotlight', -1, src, state)

    print(string.format("^5[TMG]^7 Photon Relay: Spotlight %s for Air Unit %s", state and "Activated" or "Deactivated", src))
end)



RegisterNetEvent('tmg-police:server:impoundVehicle', function(plate, fullImpound, price, body, engine, fuel)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' then 
        ExploitBan(src, 'Unauthorized Asset Seizure Attempt')
        return 
    end

    local plateUpper = plate:upper():gsub("%s+", "") 
    local priceVal = tonumber(price) or 0
    local newState = fullImpound and 2 or 0
    local depotPrice = fullImpound and 0 or priceVal

    exports['tmgnosql']:UpdateOne('player_vehicles', 
        { ["plate"] = plateUpper }, 
        { ["$set"] = { 
            ["state"] = newState, 
            ["depotprice"] = depotPrice, 
            ["body"] = body, 
            ["engine"] = engine, 
            ["fuel"] = fuel 
        }}
    )

    local notifyKey = fullImpound and 'info.vehicle_seized' or 'info.vehicle_taken_depot'
    local notifyData = fullImpound and {} or { price = priceVal }
    
    TriggerClientEvent('TMGCore:Notify', src, Lang:t(notifyKey, notifyData), 'success')

    print(string.format("^5[TMG]^7 Asset [%s] localized to State %d | Integrity: B%d E%d", plateUpper, newState, body, engine))
end)


RegisterNetEvent('tmg-police:server:releaseImpound', function(plate, garage)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or not plate then return end
    
    local targetCoords = Config.Locations['impound'][garage]
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if not targetCoords or #(playerCoords - targetCoords) > 10.0 then 
        return DropPlayer(src, 'TMG Mainframe: Positional Sync Failure (Remote Asset Liberation)') 
    end

    local plateUpper = plate:upper():gsub("%s+", "") 

    exports['tmgnosql']:UpdateOne('player_vehicles', 
        { ["plate"] = plateUpper }, 
        { ["$set"] = { ["state"] = 0 } }
    )

    TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.impound_vehicle_removed'), 'success')
    
    print(string.format("^5[TMG]^7 Asset [%s] released from lot [%s] for CID [%s]", plateUpper, garage, Player.PlayerData.citizenid))
end)


RegisterNetEvent('police:server:FlaggedPlateTriggered', function(coords, plate)
    local veh_plate = plate:upper()
    
    if not DutyRegistry.leo or next(DutyRegistry.leo) == nil then return end

    local message = Lang:t('info.flagged_vehicle_radar', { plate = veh_plate })
    local alertData = {
        title = "ALPR Hit: Flagged Vehicle",
        coords = { x = coords.x, y = coords.y, z = coords.z },
        description = message
    }

    for cid, data in pairs(DutyRegistry.leo) do
        local targetSrc = data.source
        
        TriggerClientEvent('police:client:policeAlert', targetSrc, coords, message)
        TriggerClientEvent('tmg-phone:client:addPoliceAlert', targetSrc, alertData)
    end

    print(string.format("^5[TMG]^7 Radar Pulse: Plate %s relayed to %s units.", veh_plate, GetCurrentCops()))
end)




TMGCore.Commands.Add('flagplate', Lang:t('commands.flagplate'), { 
    { name = 'plate', help = Lang:t('info.plate_number') }, 
    { name = 'reason', help = Lang:t('info.flag_reason') } 
}, true, function(source, args)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' or not Player.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local plate = args[1]:upper():gsub("%s+", "") 
    table.remove(args, 1) 
    local reason = table.concat(args, ' ')
    if reason == "" then reason = "Pending Investigation" end
    Plates[plate] = {
        ["isflagged"] = true,
        ["reason"] = reason
    }

    exports['tmgnosql']:UpdateOne('flagged_plates', 
        { ["plate"] = plate }, 
        { ["$set"] = { 
            ["plate"] = plate, 
            ["reason"] = reason, 
            ["flaggedBy"] = Player.PlayerData.citizenid,
            ["timestamp"] = os.time()
        }},
        { ["upsert"] = true }
    )

    TriggerClientEvent('TMGCore:Notify', src, Lang:t('info.vehicle_flagged', { 
        vehicle = plate, 
        reason = reason 
    }), 'success')
end)

TMGCore.Commands.Add('unflagplate', Lang:t('commands.unflagplate'), { 
    { name = 'plate', help = Lang:t('info.plate_number') } 
}, true, function(source, args)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' or not Player.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local plate = args[1]:upper():gsub("%s+", "") 

    if not Plates[plate] or not Plates[plate].isflagged then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.vehicle_not_flag'), 'error')
        return
    end

    Plates[plate] = nil

    exports['tmgnosql']:DeleteOne('flagged_plates', { 
        ["plate"] = plate 
    })

    TriggerClientEvent('TMGCore:Notify', src, Lang:t('info.unflag_vehicle', { vehicle = plate }), 'success')
    
    print(string.format("^5[TMG]^7 Surveillance: APB Cleared for [%s] by Officer %s", plate, Player.PlayerData.citizenid))
end)


TMGCore.Commands.Add('plateinfo', Lang:t('commands.plateinfo'), { 
    { name = 'plate', help = Lang:t('info.plate_number') } 
}, true, function(source, args)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.type ~= 'leo' or not Player.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local plate = args[1]:upper():gsub("%s+", "") 

    if Plates[plate] and Plates[plate].isflagged then
        TriggerClientEvent('TMGCore:Notify', src, string.format("SURVEILLANCE: %s is FLAGGED. Reason: %s", plate, Plates[plate].reason), 'success')
    end

    local vehicleData = exports['tmgnosql']:FetchOne('player_vehicles', { ["plate"] = plate })

    if not vehicleData then
        return TriggerClientEvent('TMGCore:Notify', src, "REGISTRY: No persistent registration found for " .. plate, "error")
    end

    local ownerData = exports['tmgnosql']:FetchOne('players', { ["citizenid"] = vehicleData.citizenid })
    
    if ownerData and ownerData.charinfo then
        local char = ownerData.charinfo
        local infoMsg = string.format("OWNERSHIP: %s %s | CID: %s | Phone: %s", 
            char.firstname, char.lastname, ownerData.citizenid, char.phone or "N/A")
        
        TriggerClientEvent('TMGCore:Notify', src, infoMsg, "primary")
    else
        TriggerClientEvent('TMGCore:Notify', src, "REGISTRY: Asset recognized, but identity record is unreachable.", "error")
    end
end)
