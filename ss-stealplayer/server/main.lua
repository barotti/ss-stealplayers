-- ============================================================
--  ss-stealplayer | server/main.lua
-- ============================================================

-- ─────────────────────────────────────────────────────────────
--  Utility
-- ─────────────────────────────────────────────────────────────

local function Debug(msg)
    if not Config.Debug then return end
    print(("^3[ss-stealplayer] [SERVER]^0 %s"):format(tostring(msg)))
end

local function GetPedCoords(ped)
    return GetEntityCoords(ped)
end

-- ─────────────────────────────────────────────────────────────
--  Helper: controlla tutti gli stati wasabi server-side
--  Ritorna: isDead (bool), isDowned (bool), reason (string)
-- ─────────────────────────────────────────────────────────────

local function CheckWasabiState(targetServerId)
    local st = Player(targetServerId).state

    local deadVal   = st.dead
    local isDeadVal = st.isDead
    Debug(("  state.dead=%s | state.isDead=%s"):format(tostring(deadVal), tostring(isDeadVal)))

    -- Fase 2: valore 'dead' o true → morto completamente
    local isDead = deadVal == true or deadVal == 'dead'
               or isDeadVal == true or isDeadVal == 'dead'

    -- Fase 1: valore 'laststand' su dead/isDead → giù ma ancora vivo (countdown attivo)
    -- wasabi setta dead='laststand' e isDead='laststand' durante la fase 1
    local isDowned = (deadVal == 'laststand' or isDeadVal == 'laststand') and not isDead
    Debug(("  isDead=%s | isDowned=%s"):format(tostring(isDead), tostring(isDowned)))

    -- Dump completo di tutti i state bag del player per debug
    if Config.Debug then
        local keys = { "dead", "isDead", "laststand", "isDown", "isHandcuffed" }
        for _, k in ipairs(keys) do
            print(("^3[ss-stealplayer] [SERVER]^0   statebag dump: Player(%d).state.%s = %s"):format(
                targetServerId, k, tostring(st[k])
            ))
        end
    end

    local reason = isDead and "dead" or (isDowned and "downed" or nil)
    Debug(("  CheckWasabiState result -> isDead=%s | isDowned=%s | reason=%s"):format(
        tostring(isDead), tostring(isDowned), tostring(reason)
    ))
    return isDead, isDowned, reason
end

-- ─────────────────────────────────────────────────────────────
--  Callback: il client chiede "è incapacitato questo target?"
--  Risposta: true/false, reason ("dead"|"downed"|nil)
-- ─────────────────────────────────────────────────────────────

lib.callback.register('ss-stealplayer:isIncapacitated', function(source, targetServerId)
    Debug(("Callback isIncapacitated: source=%d target=%d"):format(source, targetServerId))

    if not GetPlayerName(targetServerId) then
        Debug(("Target %d non trovato"):format(targetServerId))
        return false, nil
    end

    local isDead, isDowned, reason = CheckWasabiState(targetServerId)
    local isIncap = isDead or isDowned

    Debug(("  -> isIncap=%s reason=%s"):format(tostring(isIncap), tostring(reason)))
    return isIncap, reason
end)

-- ─────────────────────────────────────────────────────────────
--  Evento: apertura inventario target
--  reason: "handsup" | "dead" | "downed"
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent("ss-stealplayer:server:openInventory", function(targetServerId, reason)
    local source = source

    Debug("=== RICHIESTA PERQUISIZIONE ===")
    Debug(("  Da source       : %d"):format(source))
    Debug(("  Verso target id : %d"):format(targetServerId))
    Debug(("  Motivo client   : %s"):format(tostring(reason)))

    -- ── Validazione source ──────────────────────────────────
    if not GetPlayerName(source) then
        Debug(("Source %d non valido"):format(source))
        return
    end

    -- ── Validazione target ──────────────────────────────────
    if not GetPlayerName(targetServerId) then
        Debug(("Target %d non trovato sul server"):format(targetServerId))
        TriggerClientEvent("ox_lib:notify", source, { title = "Errore", description = "Giocatore non trovato", type = "error" })
        return
    end

    if source == targetServerId then
        Debug("Source uguale al target: bloccato")
        return
    end

    -- ── Controllo distanza server-side (anti-cheat soft) ────
    local sourcePed    = GetPlayerPed(source)
    local targetPed    = GetPlayerPed(targetServerId)
    local distance     = #(GetPedCoords(sourcePed) - GetPedCoords(targetPed))

    Debug(("  Distanza tra giocatori: %.2f m (max: %.2f)"):format(distance, Config.ServerMaxDistance))

    if distance > Config.ServerMaxDistance then
        Debug(("Distanza troppo grande: bloccato"):format())
        TriggerClientEvent("ox_lib:notify", source, { title = "Troppo lontano", description = "Sei troppo lontano dal giocatore", type = "error" })
        return
    end

    -- ── Validazione stato server-side ───────────────────────
    -- Se il client ha dichiarato dead/downed, il server lo ri-verifica
    if reason == "dead" or reason == "downed" then
        local isDead, isDowned, _ = CheckWasabiState(targetServerId)
        local serverIncap = isDead or isDowned

        if not serverIncap then
            Debug(("BLOCCATO: client ha dichiarato '%s' ma server non lo conferma"):format(reason))
            TriggerClientEvent("ox_lib:notify", source, { title = "Impossibile perquisire", description = "Il giocatore non è più a terra", type = "error" })
            return
        end
        Debug(("Stato '%s' confermato dal server"):format(reason))
    else
        -- "handsup": server non può verificare l'animazione, si fida del client
        Debug("Motivo handsup: server si fida del check client-side (anim non verificabile server-side)")
    end

    -- ── Tutti i check superati: apri inventario ─────────────
    Debug(("Invio evento openInventory al client %d per target %d"):format(source, targetServerId))
    TriggerClientEvent("ss-stealplayer:client:openInventory", source, targetServerId)

    Debug("=== FINE RICHIESTA ===")
end)
