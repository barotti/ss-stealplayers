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
--- (unico check che ha senso fare client-side: l'animazione è visibile localmente)
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
        Debug(("Cooldown attivo per target %d: %.1f s rimanenti"):format(targetId, remaining / 1000))
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

    local playerIndex    = NetworkGetPlayerIndexFromPed(entity)
    local targetServerId = GetPlayerServerId(playerIndex)
    local netId          = NetworkGetNetworkIdFromEntity(entity)

    Debug("=== INIZIO PERQUISIZIONE ===")
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

    -- ── Check mani alzate (client-side: animazione visibile localmente) ──
    local targetHandsUp = IsHandsUp(entity)
    Debug(("targetHandsUp = %s"):format(tostring(targetHandsUp)))

    -- ── Se NON ha le mani alzate, chiedi al server se è incapacitato ─────
    -- I state bag di wasabi NON sono replicati agli altri client,
    -- quindi il check dead/downed va fatto server-side via callback.
    local targetIncap  = false
    local incapReason  = nil

    if not targetHandsUp and Config.AllowDeadSearch then
        Debug(("Mani alzate false, chiedo al server se target %d è incapacitato (callback)"):format(targetServerId))
        targetIncap, incapReason = lib.callback.await('ss-stealplayer:isIncapacitated', false, targetServerId)
        Debug(("Risposta server -> incap=%s reason=%s"):format(tostring(targetIncap), tostring(incapReason)))
    end

    Debug(("Stato target -> handsUp=%s | incap=%s | incapReason=%s"):format(
        tostring(targetHandsUp), tostring(targetIncap), tostring(incapReason)
    ))

    -- ── Check arma ────────────────────────────────────────────────────────
    local needWeapon = (not targetIncap) or Config.RequireWeaponForDead
    if needWeapon and not HasWeapon() then
        Debug("Nessuna arma equipaggiata: perquisizione bloccata")
        lib.notify({ title = "Nessuna arma", description = "Devi avere un'arma in mano per perquisire", type = "error" })
        return
    end

    -- ── Almeno una condizione deve essere vera ────────────────────────────
    if not targetHandsUp and not targetIncap then
        Debug("Nessuna condizione soddisfatta: perquisizione bloccata")
        lib.notify({ title = "Impossibile perquisire", description = "Il giocatore deve avere le mani alzate o essere a terra", type = "error" })
        return
    end

    -- ── Tutto ok: animazione + richiesta server ───────────────────────────
    local reason = targetHandsUp and "handsup" or incapReason
    isSearching  = true
    Debug(("Tutti i check superati [motivo: %s], avvio animazione"):format(reason))

    PlaySearchAnim()

    searchCooldowns[targetServerId] = GetGameTimer() + Config.SearchCooldown
    Debug(("Cooldown impostato per target %d: %d ms"):format(targetServerId, Config.SearchCooldown))

    Debug(("TriggerServerEvent -> target=%d reason=%s"):format(targetServerId, reason))
    TriggerServerEvent("ss-stealplayer:server:openInventory", targetServerId, reason)

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
