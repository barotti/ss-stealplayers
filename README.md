# ss-stealplayer

Script FiveM per perquisire un giocatore tramite `ox_target`.
La perquisizione è possibile **solo** se il target ha le mani alzate e il rapinatore ha un'arma in mano.

---

## Dipendenze

| Risorsa | Ruolo |
|---|---|
| [ox_lib](https://github.com/overextended/ox_lib) | Utility (notify, animDict) |
| [ox_target](https://github.com/overextended/ox_target) | Interazione con il giocatore |
| [ox_inventory](https://github.com/overextended/ox_inventory) | Apertura inventario del target |

> Framework: **qbox** con bridge QBCore

---

## Installazione

1. Copia la cartella `ss-stealplayer` nella directory `resources` del tuo server
2. Aggiungi `ensure ss-stealplayer` nel tuo `server.cfg` **dopo** le dipendenze:
```
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure ss-stealplayer
```

---

## Funzionamento

1. Avvicinati a un giocatore (entro `Config.MaxDistance` metri)
2. `ox_target` mostra il tasto **"Perquisire"**
3. Prima di avviare la perquisizione vengono controllate **due condizioni**:
   - Hai un'arma equipaggiata in mano
   - Il target sta eseguendo l'animazione "mani alzate"
4. Se entrambe le condizioni sono soddisfatte, parte l'animazione di perquisizione
5. Al termine si apre l'inventario `ox_inventory` del target

---

## Struttura file

```
ss-stealplayer/
├── fxmanifest.lua
├── config.lua
├── client/
│   └── main.lua
└── server/
    └── main.lua
```

---

## Configurazione (`config.lua`)

### Debug
```lua
Config.Debug = true  -- true = print in console | false = silenzioso (produzione)
```

### Parametri perquisizione
| Parametro | Default | Descrizione |
|---|---|---|
| `Config.MaxDistance` | `2.5` | Distanza (metri) entro cui appare il tasto ox_target |
| `Config.ServerMaxDistance` | `5.0` | Distanza massima accettata lato server (anti-cheat soft) |
| `Config.SearchDuration` | `3000` | Durata animazione perquisizione in ms |
| `Config.SearchCooldown` | `10000` | Cooldown in ms prima di poter perquisire di nuovo lo stesso target |

### Animazioni mani alzate
Puoi aggiungere quante animazioni vuoi alla lista. Vengono controllate tutte:
```lua
Config.HandsUpAnims = {
    { dict = "missminuteman_1ig_2", anim = "handsup_enter" },
    -- { dict = "altro_dict", anim = "altra_anim" },
}
```

### Animazione perquisizione
```lua
Config.SearchAnim = {
    dict  = "mp_common",
    anim  = "givetake1_a",
    flags = 0,
}
```

---

## Crediti

Sviluppato da **Seifer**
