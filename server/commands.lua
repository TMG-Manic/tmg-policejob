
local function DnaHash(citizenid)
    if not citizenid or type(citizenid) ~= "string" then return "Unknown_DNA" end

    local hash = (citizenid:gsub('.', function(char)
        return string.format('%02x', string.byte(char))
    end))

    return hash:lower()
end




TMGCore.Commands.Add('grantlicense', Lang:t('commands.license_grant'), { 
    { name = 'id', help = Lang:t('info.player_id') }, 
    { name = 'license', help = Lang:t('info.license_type') } 
}, true, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local targetId = tonumber(args[1])
    local licenseType = args[2] and args[2]:lower()

    if not Officer or Officer.PlayerData.job.type ~= 'leo' then return end
    if Officer.PlayerData.job.grade.level < Config.LicenseRank then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.rank_license'), 'error')
        return
    end

    local Suspect = TMGCore.Functions.GetPlayer(targetId)
    if not Suspect then 
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Target terminal not found.", "error")
        return 
    end

    local validLicenses = { ['driver'] = true, ['weapon'] = true }
    if not validLicenses[licenseType] then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.error_license_type'), 'error')
        return
    end

    local licenseTable = Suspect.PlayerData.metadata['licences']
    if licenseTable[licenseType] then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.license_already'), 'error')
        return
    end

    licenseTable[licenseType] = true
    Suspect.Functions.SetMetaData('licences', licenseTable)

    TriggerClientEvent('TMGCore:Notify', Suspect.PlayerData.source, Lang:t('success.granted_license'), 'success')
    TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.grant_license'), 'success')

    print(string.format("^5[TMG]^7 License Granted: %s authorized %s for [%s]", Officer.PlayerData.citizenid, Suspect.PlayerData.citizenid, licenseType))
end)


TMGCore.Commands.Add('revokelicense', Lang:t('commands.license_revoke'), { 
    { name = 'id', help = Lang:t('info.player_id') }, 
    { name = 'license', help = Lang:t('info.license_type') } 
}, true, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local targetId = tonumber(args[1])
    local licenseType = args[2] and args[2]:lower()

    if not Officer or Officer.PlayerData.job.type ~= 'leo' then return end
    if Officer.PlayerData.job.grade.level < Config.LicenseRank then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.rank_revoke'), 'error')
        return
    end

    local Suspect = TMGCore.Functions.GetPlayer(targetId)
    if not Suspect then 
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Target terminal not found.", "error")
        return 
    end

    local validLicenses = { ['driver'] = true, ['weapon'] = true }
    if not validLicenses[licenseType] then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.error_license'), 'error')
        return
    end

    local licenseTable = Suspect.PlayerData.metadata['licences']
    if not licenseTable[licenseType] then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.error_license'), 'error')
        return
    end

    licenseTable[licenseType] = false
    Suspect.Functions.SetMetaData('licences', licenseTable)

    TriggerClientEvent('TMGCore:Notify', Suspect.PlayerData.source, Lang:t('error.revoked_license'), 'error')
    TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.revoke_license'), 'success')

    print(string.format("^5[TMG]^7 License Revoked: %s stripped %s of [%s] privileges.", Officer.PlayerData.citizenid, Suspect.PlayerData.citizenid, licenseType))
end)


TMGCore.Commands.Add('takedrivinglicense', Lang:t('commands.drivinglicense'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    TriggerClientEvent('police:client:SeizeDriverLicense', src)

    print(string.format("^5[TMG]^7 Enforcement: %s initiated physical license seizure.", Officer.PlayerData.citizenid))
end)




TMGCore.Commands.Add('spikestrip', Lang:t('commands.place_spike'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    TriggerClientEvent('police:client:SpawnSpikeStrip', src)

    print(string.format("^5[TMG]^7 Pursuit Protocol: %s deployed a tactical hazard.", Officer.PlayerData.citizenid))
end)


local ObjectMapping = {
    ['cone']     = 'police:client:spawnCone',
    ['barrier']  = 'police:client:spawnBarrier',
    ['roadsign'] = 'police:client:spawnRoadSign',
    ['tent']     = 'police:client:spawnTent',
    ['light']    = 'police:client:spawnLight',
    ['delete']   = 'police:client:deleteObject'
}

TMGCore.Commands.Add('pobject', Lang:t('commands.place_object'), { 
    { name = 'type', help = "cone, barrier, roadsign, tent, light, delete" } 
}, true, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local assetType = args[1] and args[1]:lower()

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local targetEvent = ObjectMapping[assetType]
    
    if targetEvent then
        TriggerClientEvent(targetEvent, src)
    else
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Invalid object type requested.", "error")
    end

    print(string.format("^5[TMG]^7 Asset Deployment: %s requested [%s]", Officer.PlayerData.citizenid, assetType))
end)




TMGCore.Commands.Add('cuff', Lang:t('commands.cuff_player'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    if Officer.PlayerData.metadata['isdead'] or Officer.PlayerData.metadata['inlaststand'] then
        TriggerClientEvent('TMGCore:Notify', src, "TMG: You are physically unable to perform this action.", "error")
        return
    end

    TriggerClientEvent('police:client:CuffPlayer', src)

    print(string.format("^5[TMG]^7 Restraint: %s initiated a cuffing sequence.", Officer.PlayerData.citizenid))
end)


TMGCore.Commands.Add('escort', Lang:t('commands.escort'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local isIncapacitated = (Officer.PlayerData.metadata['isdead'] or Officer.PlayerData.metadata['inlaststand'] or Officer.PlayerData.metadata['ishandcuffed'])
    
    if isIncapacitated then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: You are physically unable to escort targets.", "error")
        return
    end

    TriggerClientEvent('police:client:EscortPlayer', src)

    print(string.format("^5[TMG]^7 Custody: %s initiated an escort sequence.", Officer.PlayerData.citizenid))
end)


TMGCore.Commands.Add('callsign', Lang:t('commands.callsign'), { 
    { name = 'name', help = Lang:t('info.callsign_name') } 
}, false, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Unauthorized access to Service ID registry.", "error")
        return 
    end

    local callsignRaw = table.concat(args, ' ')
    local sanitizedCallsign = string.sub(callsignRaw, 1, 10):upper():gsub('[^%w%s%-]', '')

    if sanitizedCallsign == "" then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Invalid callsign format.", "error")
        return
    end

    Officer.Functions.SetMetaData('callsign', sanitizedCallsign)

    TriggerClientEvent('TMGCore:Notify', src, "Service ID updated to: " .. sanitizedCallsign, "success")

    print(string.format("^5[TMG]^7 Registry Update: %s changed callsign to %s", Officer.PlayerData.citizenid, sanitizedCallsign))
end)


TMGCore.Commands.Add('jail', Lang:t('commands.jail_player'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local isAtIntake = false
    for _, zone in pairs(Config.IntakeZones) do
        if #(coords - zone) < 15.0 then isAtIntake = true break end
    end

    if not isAtIntake then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: You must be at a Precinct or Prison Intake to sentence a suspect.", "error")
        
    end

    TriggerClientEvent('police:client:JailPlayer', src)

    print(string.format("^5[TMG]^7 Intake: %s initiated sentencing protocol.", Officer.PlayerData.citizenid))
end)


TMGCore.Commands.Add('unjail', Lang:t('commands.unjail_player'), { 
    { name = 'id', help = Lang:t('info.player_id') } 
}, true, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local targetId = tonumber(args[1])

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local Inmate = TMGCore.Functions.GetPlayer(targetId)
    if not Inmate then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Inmate terminal not found (Offline).", "error")
        return
    end

    Inmate.Functions.SetMetaData('jailtime', 0)

    TriggerClientEvent('prison:client:UnjailPerson', targetId)

    TriggerClientEvent('TMGCore:Notify', src, string.format("Parole Authorized: %s has been released.", Inmate.PlayerData.charinfo.firstname), "success")
    
    print(string.format("^5[TMG]^7 Parole: %s authorized release for Inmate %s", Officer.PlayerData.citizenid, Inmate.PlayerData.citizenid))
end)


TMGCore.Commands.Add('seizecash', Lang:t('commands.seizecash'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    if Officer.PlayerData.metadata['isdead'] or Officer.PlayerData.metadata['inlaststand'] then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: You are physically unable to seize assets.", "error")
        return
    end

    TriggerClientEvent('police:client:SeizeCash', src)

    print(string.format("^5[TMG]^7 Asset Forfeiture: %s initiated a cash seizure pulse.", Officer.PlayerData.citizenid))
end)


TMGCore.Commands.Add('sc', Lang:t('commands.softcuff'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local isIncapacitated = (Officer.PlayerData.metadata['isdead'] or Officer.PlayerData.metadata['inlaststand'] or Officer.PlayerData.metadata['ishandcuffed'])
    
    if isIncapacitated then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: You are physically unable to apply restraints.", "error")
        return
    end

    
    TriggerClientEvent('police:client:CuffPlayerSoft', src)

    print(string.format("^5[TMG]^7 Soft-Restraint: %s initiated a mobile cuffing sequence.", Officer.PlayerData.citizenid))
end)


TMGCore.Commands.Add('fine', Lang:t('commands.fine'), { 
    { name = 'id', help = Lang:t('info.player_id') }, 
    { name = 'amount', help = Lang:t('info.amount') } 
}, false, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' then return end
    if not Suspect or not amount or amount <= 0 or Officer.PlayerData.citizenid == Suspect.PlayerData.citizenid then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Invalid transaction parameters.", "error")
        return
    end

    local paymentSuccess = false
    local accounts = {'bank', 'cash'}

    for _, account in ipairs(accounts) do
        if Suspect.Functions.RemoveMoney(account, amount, 'police-fine') then
            paymentSuccess = true
            break
        end
    end

    if paymentSuccess then
        exports['tmg-banking']:AddMoney(Officer.PlayerData.job.name, amount, 'Fine: ' .. Suspect.PlayerData.citizenid)
        
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('info.fine_issued'), 'success')
        TriggerClientEvent('TMGCore:Notify', targetId, Lang:t('info.received_fine'))
    else
        local invoiceData = {
            ["citizenid"] = Suspect.PlayerData.citizenid,
            ["amount"] = amount,
            ["society"] = Officer.PlayerData.job.name,
            ["sender"] = Officer.PlayerData.charinfo.firstname,
            ["sendercitizenid"] = Officer.PlayerData.citizenid,
            ["timestamp"] = os.time(),
            ["status"] = "pending"
        }

        exports['tmgnosql']:InsertOne('phone_invoices', invoiceData, function(docId)
            if docId then
                TriggerClientEvent('tmg-phone:client:AcceptorDenyInvoice', targetId, docId, invoiceData.sender, invoiceData.society, invoiceData.sendercitizenid, amount, "tmg-policejob")
                TriggerClientEvent('tmg-phone:RefreshPhone', targetId)
            end
        end)
        
        TriggerClientEvent('TMGCore:Notify', src, "Suspect Insolvent: Permanent Debt Record Anchored.", "primary")
    end
end)




TMGCore.Commands.Add('clearcasings', Lang:t('commands.clear_casign'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    TriggerClientEvent('evidence:client:ClearCasingsInArea', src)

    print(string.format("^5[TMG]^7 Sanitization: %s initiated a ballistic area sweep.", Officer.PlayerData.citizenid))
end)


TMGCore.Commands.Add('clearblood', Lang:t('commands.clearblood'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    TriggerClientEvent('evidence:client:ClearBlooddropsInArea', src)

    print(string.format("^5[TMG]^7 Sanitization: %s initiated a DNA area sweep.", Officer.PlayerData.citizenid))
end)




TMGCore.Commands.Add('takedna', Lang:t('commands.takedna'), { 
    { name = 'id', help = Lang:t('info.player_id') } 
}, true, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local targetId = tonumber(args[1])
    local Suspect = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then return end
    if not Suspect then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Suspect terminal not found.", "error")
        return
    end

    local officerPed = GetPlayerPed(src)
    local suspectPed = GetPlayerPed(targetId)
    if #(GetEntityCoords(officerPed) - GetEntityCoords(suspectPed)) > 3.0 then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Suspect is too far away to sample.", "error")
        return
    end

    if not Officer.Functions.GetItemByName('empty_evidence_bag') then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
        return
    end

    local info = {
        label = Lang:t('info.dna_sample'),
        type = 'dna',
        dnalabel = DnaHash(Suspect.PlayerData.citizenid),
        collectedFrom = Suspect.PlayerData.charinfo.firstname .. " " .. Suspect.PlayerData.charinfo.lastname,
        timestamp = os.time()
    }

    if exports['tmg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, info) then
        exports['tmg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1)
        TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['filled_evidence_bag'], 'add')
        TriggerClientEvent('TMGCore:Notify', src, "DNA Sample Secured: " .. info.dnalabel, "success")
    else
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Inventory overflow. Clear space for sample.", "error")
    end
end)


TMGCore.Commands.Add('anklet', Lang:t('commands.anklet'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    if Officer.PlayerData.metadata['isdead'] or Officer.PlayerData.metadata['inlaststand'] then
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Tracker failure. Action cancelled.", "error")
        return
    end

    TriggerClientEvent('police:client:CheckDistance', src)

    print(string.format("^5[TMG]^7 Probation: %s initiated an anklet deployment pulse.", Officer.PlayerData.citizenid))
end)


TMGCore.Commands.Add('ankletlocation', Lang:t('commands.ankletlocation'), { 
    { name = 'cid', help = Lang:t('info.citizen_id') } 
}, true, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local citizenid = args[1]

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local Target = TMGCore.Functions.GetPlayerByCitizenId(citizenid)
    
    if not Target then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Target terminal offline or out of range.", "error")
        return
    end

    if not Target.PlayerData.metadata['tracker'] then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.no_anklet'), 'error')
        return
    end

    TriggerClientEvent('police:client:SendTrackerLocation', Target.PlayerData.source, src)

    TriggerClientEvent('TMGCore:Notify', src, "Mainframe: GPS Lock established on CID " .. citizenid, "success")
    
    print(string.format("^5[TMG]^7 GPS Probe: %s pinged Inmate %s", Officer.PlayerData.citizenid, citizenid))
end)




TMGCore.Commands.Add('depot', Lang:t('commands.depot'), { 
    { name = 'price', help = Lang:t('info.impound_price') } 
}, false, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    
    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    local impoundPrice = tonumber(args[1]) or 0
    if impoundPrice < 0 then impoundPrice = 0 end

    TriggerClientEvent('police:client:ImpoundVehicle', src, false, impoundPrice)

    print(string.format("^5[TMG]^7 Logistics: %s initiated depot seizure for $%s", Officer.PlayerData.citizenid, impoundPrice))
end)


TMGCore.Commands.Add('impound', Lang:t('commands.impound'), {}, false, function(source)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    if Officer.PlayerData.metadata['isdead'] or Officer.PlayerData.metadata['inlaststand'] then
        TriggerClientEvent('TMGCore:Notify', src, "TMG: Biometric failure. Action cancelled.", "error")
        return
    end

    TriggerClientEvent('police:client:ImpoundVehicle', src, true)

    print(string.format("^5[TMG]^7 Judicial: %s initiated a permanent vehicle seizure.", Officer.PlayerData.citizenid))
end)



TMGCore.Commands.Add('cam', Lang:t('commands.camera'), { 
    { name = 'camid', help = Lang:t('info.camera_id') } 
}, false, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local camId = tonumber(args[1])

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    if not camId or camId <= 0 or (Config.Cameras and camId > #Config.Cameras) then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Invalid Camera ID. Asset not found.", "error")
        return
    end

    TriggerClientEvent('police:client:ActiveCamera', src, camId)

    print(string.format("^5[TMG]^7 Surveillance: %s accessed Camera Feed #%s", Officer.PlayerData.citizenid, camId))
end)


TMGCore.Commands.Add('paytow', Lang:t('commands.paytow'), { 
    { name = 'id', help = Lang:t('info.player_id') } 
}, true, function(source, args)
    local src = source
    local Officer = TMGCore.Functions.GetPlayer(src)
    local targetId = tonumber(args[1])
    local TowDriver = TMGCore.Functions.GetPlayer(targetId)

    if not Officer or Officer.PlayerData.job.type ~= 'leo' or not Officer.PlayerData.job.onduty then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
        return
    end

    if not TowDriver or TowDriver.PlayerData.job.name ~= 'tow' then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_towdriver'), 'error')
        return
    end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId)))
    if dist > 5.0 then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Driver out of range for fiscal handshake.", "error")
        return
    end

    local towFee = 500
    
    exports['tmg-banking']:RemoveMoney(Officer.PlayerData.job.name, towFee, "Tow Service: " .. TowDriver.PlayerData.citizenid)
    
    TowDriver.Functions.AddMoney('bank', towFee, 'police-tow-paid')

    TriggerClientEvent('TMGCore:Notify', TowDriver.PlayerData.source, Lang:t('success.tow_paid'), 'success')
    TriggerClientEvent('TMGCore:Notify', src, Lang:t('info.tow_driver_paid'), 'success')

    print(string.format("^5[TMG]^7 Fiscal: %s paid %s $%s for towing services.", Officer.PlayerData.citizenid, TowDriver.PlayerData.citizenid, towFee))
end)


TMGCore.Commands.Add('paylawyer', Lang:t('commands.paylawyer'), { 
    { name = 'id', help = Lang:t('info.player_id') } 
}, true, function(source, args)
    local src = source
    local Payer = TMGCore.Functions.GetPlayer(src)
    local targetId = tonumber(args[1])
    local Lawyer = TMGCore.Functions.GetPlayer(targetId)

    local isAuthorized = (Payer.PlayerData.job.type == 'leo' or Payer.PlayerData.job.name == 'judge')
    if not isAuthorized then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Unauthorized to release legal funds.", "error")
        return
    end

    if not Lawyer or Lawyer.PlayerData.job.name ~= 'lawyer' then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_lawyer'), 'error')
        return
    end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId)))
    if dist > 8.0 then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Attorney out of range for payment verification.", "error")
        return
    end

    local legalFee = 500
    local payerSociety = Payer.PlayerData.job.name
    
    exports['tmg-banking']:RemoveMoney(payerSociety, legalFee, "Legal Defense: " .. Lawyer.PlayerData.citizenid)
    
    Lawyer.Functions.AddMoney('bank', legalFee, 'lawyer-service-paid')

    TriggerClientEvent('TMGCore:Notify', Lawyer.PlayerData.source, "Legal fees received: $" .. legalFee, 'success')
    TriggerClientEvent('TMGCore:Notify', src, Lang:t('info.paid_lawyer'), 'success')

    print(string.format("^5[TMG]^7 Judicial: %s paid %s $%s for legal services.", Payer.PlayerData.citizenid, Lawyer.PlayerData.citizenid, legalFee))
end)


TMGCore.Commands.Add('911p', Lang:t('commands.police_report'), { 
    { name = 'message', help = Lang:t('commands.message_sent') } 
}, false, function(source, args)
    local src = source
    local coords = GetEntityCoords(GetPlayerPed(src))
    
    local message = args[1] and table.concat(args, ' ') or Lang:t('commands.civilian_call')
    message = message:sub(1, 150):gsub('[<>#]', '') 

    local activeUnits = exports['tmg-policejob']:GetOnDutyLEO() 
    
    local alertData = { 
        title = Lang:t('commands.emergency_call'), 
        coords = { x = coords.x, y = coords.y, z = coords.z }, 
        description = message 
    }

    for officerSrc, _ in pairs(activeUnits) do
        TriggerClientEvent('tmg-phone:client:addPoliceAlert', officerSrc, alertData)
        TriggerClientEvent('police:client:policeAlert', officerSrc, coords, message)
    end

    TriggerClientEvent('TMGCore:Notify', src, "Emergency dispatch transmitted.", "success")

    print(string.format("^5[TMG]^7 Dispatch: Emergency report from %s - Coords: %s", source, coords))
end)
