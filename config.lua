Config = {}

-- ┌─────────────────────────────────────────┐
-- │              DEBUG                      │
-- └─────────────────────────────────────────┘
-- Metti true per vedere i print di debug in console, false in produzione
Config.Debug = true

-- ┌─────────────────────────────────────────┐
-- │           PARAMETRI RAPINA              │
-- └─────────────────────────────────────────┘

-- Distanza massima da cui puoi perquisire (metri)
Config.MaxDistance = 2.5

-- Distanza extra tollerata lato server (anti-cheat soft)
Config.ServerMaxDistance = 5.0

-- Durata animazione perquisizione in ms
Config.SearchDuration = 3000

-- Cooldown tra una perquisizione e l'altra (ms) per lo stesso target
Config.SearchCooldown = 10000

-- ┌─────────────────────────────────────────┐
-- │        ANIMAZIONI MANI ALZATE           │
-- └─────────────────────────────────────────┘
-- Lista di animazioni considerate "mani alzate"
-- Aggiungi/rimuovi in base al tuo server
Config.HandsUpAnims = {
    -- Animazione principale usata dal server
    { dict = "missminuteman_1ig_2", anim = "handsup_enter" },
}

-- ┌─────────────────────────────────────────┐
-- │        ANIMAZIONE PERQUISIZIONE         │
-- └─────────────────────────────────────────┘
Config.SearchAnim = {
    dict  = "mp_common",
    anim  = "givetake1_a",
    flags = 0,
}

-- ┌─────────────────────────────────────────┐
-- │              OX_TARGET                  │
-- └─────────────────────────────────────────┘
Config.TargetOption = {
    name     = "ss-stealplayer:search",
    icon     = "fas fa-search",
    label    = "Perquisire",
    distance = Config.MaxDistance,
}
