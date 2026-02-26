-- ============================================================
--  ss-stealplayer | client/main.lua
-- ============================================================

local searchCooldowns = {}   -- [targetServerId] = gameTimer limit
local isSearching     = false

-- ─────────────────────────────────────────────────────────────
--  Utility
-- ─────────────────────────────────────────────────────────────

local function Debug(msg)
    if not Config.Debug then return end
    print(("^3[ss-stealplayer] [CLIENT]^0 %s"):format(tostring(msg)))
end

-- ─────────────────────────────────────────────────────────────
--  Checks lato client
-- ─────────────────────────────────────────────────────────────

--- Controlla se il ped target sta facendo un'animazione "mani alzate"
local function IsHandsUp(ped)
    Debug(("IsHandsUp check su ped: %d"):format(ped))
    for _, v in ipairs(Config.HandsUpAnims) do
        local playing = IsEntityPlayingAnim(ped, v.dict, v.anim, 3)
        Debug(("  anim [%s / %s] -> %s"):format(v.dict, v.anim, tostring(playing)))
        if playing then
            Debug("  --> Mani alzate: VERO")
            return true
        end
    end
    Debug("  --> Mani alzate: FALSO")
    return false
end

--- Controlla se il giocatore locale ha un'arma diversa da WEAPON_UNARMED
local function HasWeapon()
    local weapon  = GetSelectedPedWeapon(cache.ped)
    local unarmed = GetHashKey("WEAPON_UNARMED")
    local armed   = (weapon ~= unarmed)
    Debug(("HasWeapon: hash=%d | unarmed=%d | armed=%s"):format(weapon, unarmed, tostring(armed)))
    return armed
end

--- Controlla se il target è in cooldown
local function IsOnCooldown(targetId)
    local limit = searchCooldowns[targetId]
    if not limit then return false end
    local remaining = limit - GetGameTimer()
    if remaining > 0 then
        Debug(("Cooldown attivo per target %d: %.1f secondi rimanenti"):format(targetId, remaining / 1000))
        return true
    end
    return false
end

-- ─────────────────────────────────────────────────────────────
--  Animazione perquisizione
-- ─────────────────────────────────────────────────────────────

local function PlaySearchAnim()
    local dict = Config.SearchAnim.dict
    local anim = Config.SearchAnim.anim

    Debug(("Carico animDict: %s"):format(dict))
    lib.requestAnimDict(dict)

    Debug(("Avvio animazione: %s / %s"):format(dict, anim))
    TaskPlayAnim(cache.ped, dict, anim, 8.0, -8.0, Config.SearchDuration, Config.SearchAnim.flags, 0, false, false, false)

    Wait(Config.SearchDuration)

    ClearPedTasks(cache.ped)
    Debug("Animazione perquisizione completata")
end

-- ─────────────────────────────────────────────────────────────
--  Flusso principale
-- ─────────────────────────────────────────────────────────────

local function OnSearchPlayer(data)
    local entity = data.entity

    if isSearching then
        Debug("Già in corso una perquisizione, ignoro")
        lib.notify({ title = "Aspetta", description = "Stai già perquisendo qualcuno", type = "error" })
        return
    end

    -- Ricava server id dal ped del giocatore target
    local netId         = NetworkGetNetworkIdFromEntity(entity)
    local playerIndex   = NetworkGetPlayerIndexFromPed(entity)
    local targetServerId = GetPlayerServerId(playerIndex)

    Debug(("=== INIZIO PERQUISIZIONE ==="))
    Debug(("  Mio source    : %d"):format(cache.serverId))
    Debug(("  Target entity : %d"):format(entity))
    Debug(("  Target netId  : %d"):format(netId))
    Debug(("  Target servId : %d"):format(targetServerId))

    -- Sanity: non perquisire se stesso
    if targetServerId == cache.serverId then
        Debug("Tentativo di perquisire se stesso: bloccato")
        return
    end

    -- Cooldown
    if IsOnCooldown(targetServerId) then
        lib.notify({ title = "Aspetta", description = "Devi aspettare prima di perquisire di nuovo questo giocatore", type = "error" })
        return
    end

    -- Check arma
    if not HasWeapon() then
        Debug("Nessuna arma equipaggiata: perquisizione bloccata")
        lib.notify({ title = "Nessuna arma", description = "Devi avere un'arma in mano per perquisire", type = "error" })
        return
    end

    -- Check mani alzate del target
    if not IsHandsUp(entity) then
        Debug("Target senza mani alzate: perquisizione bloccata")
        lib.notify({ title = "Mani alzate", description = "Il giocatore deve avere le mani alzate", type = "error" })
        return
    end

    -- Tutto ok: avvia la perquisizione
    isSearching = true
    Debug("Tutti i check superati, avvio animazione e richiesta server")

    -- Animazione
    PlaySearchAnim()

    -- Applica cooldown
    searchCooldowns[targetServerId] = GetGameTimer() + Config.SearchCooldown
    Debug(("Cooldown impostato per target %d: %d ms"):format(targetServerId, Config.SearchCooldown))

    -- Richiedi apertura inventario al server
    Debug(("TriggerServerEvent 'ss-stealplayer:server:openInventory' -> target %d"):format(targetServerId))
    TriggerServerEvent("ss-stealplayer:server:openInventory", targetServerId)

    isSearching = false
    Debug("=== FINE PERQUISIZIONE ===")
end

-- ─────────────────────────────────────────────────────────────
--  Apertura inventario (chiamata dal server dopo validazione)
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent("ss-stealplayer:client:openInventory", function(targetServerId)
    Debug(("Ricevuto evento openInventory per target: %d"):format(targetServerId))
    exports.ox_inventory:openInventory('player', targetServerId)
    Debug("exports.ox_inventory:openInventory chiamato")
end)

-- ─────────────────────────────────────────────────────────────
--  Registrazione ox_target (global player)
-- ─────────────────────────────────────────────────────────────

CreateThread(function()
    Debug("Registrazione opzione ox_target su tutti i giocatori")

    exports.ox_target:addGlobalPlayer({
        {
            name     = Config.TargetOption.name,
            icon     = Config.TargetOption.icon,
            label    = Config.TargetOption.label,
            distance = Config.TargetOption.distance,
            onSelect = function(data)
                Debug(("ox_target onSelect chiamato su entity: %d"):format(data.entity))
                OnSearchPlayer(data)
            end,
        },
    })

    Debug("ox_target registrato correttamente")
end)
