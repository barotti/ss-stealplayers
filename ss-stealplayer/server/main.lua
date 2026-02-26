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
    local c = GetEntityCoords(ped)
    return c
end

-- ─────────────────────────────────────────────────────────────
--  Evento: apertura inventario target
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent("ss-stealplayer:server:openInventory", function(targetServerId)
    local source = source

    Debug(("=== RICHIESTA PERQUISIZIONE ==="))
    Debug(("  Da source       : %d"):format(source))
    Debug(("  Verso target id : %d"):format(targetServerId))

    -- ── Validazione source ──────────────────────────────────
    if not GetPlayerName(source) then
        Debug(("Source %d non valido"):format(source))
        return
    end

    -- ── Validazione target ──────────────────────────────────
    if not GetPlayerName(targetServerId) then
        Debug(("Target %d non trovato sul server"):format(targetServerId))
        TriggerClientEvent("ox_lib:notify", source, {
            title       = "Errore",
            description = "Giocatore non trovato",
            type        = "error",
        })
        return
    end

    -- Non perquisire se stesso (double-check server side)
    if source == targetServerId then
        Debug("Source uguale al target: bloccato")
        return
    end

    -- ── Controllo distanza server-side (anti-cheat soft) ────
    local sourcePed    = GetPlayerPed(source)
    local targetPed    = GetPlayerPed(targetServerId)
    local sourceCoords = GetPedCoords(sourcePed)
    local targetCoords = GetPedCoords(targetPed)
    local distance     = #(sourceCoords - targetCoords)

    Debug(("  Distanza tra giocatori: %.2f m (max: %.2f)"):format(distance, Config.ServerMaxDistance))

    if distance > Config.ServerMaxDistance then
        Debug(("Distanza troppo grande (%.2f > %.2f): bloccato"):format(distance, Config.ServerMaxDistance))
        TriggerClientEvent("ox_lib:notify", source, {
            title       = "Troppo lontano",
            description = "Sei troppo lontano dal giocatore",
            type        = "error",
        })
        return
    end

    -- ── Tutti i check superati: ordina al client di aprire l'inventario ──
    -- ox_inventory:openInventory va chiamato lato CLIENT, non server
    Debug(("Invio evento openInventory al client %d per aprire inventario del target %d"):format(source, targetServerId))
    TriggerClientEvent("ss-stealplayer:client:openInventory", source, targetServerId)

    Debug("=== FINE RICHIESTA ===")
end)
