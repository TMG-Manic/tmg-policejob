local ObjectsRegistry = {}

local function GenerateObjectUUID()
    local id = #ObjectsRegistry + 1
    if ObjectsRegistry[id] then
        id = id + math.random(1000, 9999)
    end
    return id
end

RegisterNetEvent('police:server:spawnObject', function(type)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src) -- Fixed QBCore to TMGCore
    if not Player or Player.PlayerData.job.type ~= 'leo' then return end
    local objectId = GenerateObjectUUID()
    local timestamp = os.time()
    ObjectsRegistry[objectId] = {
        type = type,
        owner = Player.PlayerData.citizenid,
        spawnedAt = timestamp
    }
    TriggerClientEvent('police:client:spawnObjectEntity', -1, objectId, type, src)
end)

RegisterNetEvent('police:server:deleteObject', function(objectId)
    if not ObjectsRegistry[objectId] then return end
    ObjectsRegistry[objectId] = nil
    TriggerClientEvent('police:client:removeObject', -1, objectId)
end)

RegisterNetEvent('police:server:SyncSpikes', function(spikeTable)
    TriggerClientEvent('police:client:SyncSpikes', -1, spikeTable)
end)