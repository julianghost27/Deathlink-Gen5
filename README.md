# DeathLink-Gen5

Soul Link faint sync for Pokémon Gen 5 (Black/White/B2W2) Nuzlocke runs in BizHawk.
When one player's Pokémon faints, the partner with the same nickname number faints too.

## How it works

Pokémon are paired by the number at the end of their nickname; the letters don't matter
(`A22` = `B22`). When one faints, the script sends the number to a small relay server,
and the other player's script sets the matching Pokémon to 0 HP.

## Requirements

- BizHawk 2.11.1 (melonDS core)
- Python 3 (no extra packages)
- A Gen 5 ROM each (tested on: Black)
- Both players need to reach the relay's port (same network, port forwarding, or VPN)

## Setup

1. **Start the relay** on one PC: `python relay.py` (listens on port 8080).
2. **Start EmuHawk with HTTP enabled** on both PCs:
   `EmuHawk.exe --url_get=http://<relay-ip>:8080/poll --url_post=http://<relay-ip>:8080/event`
3. **Edit the top of `linked_faint.lua`:**
   - `RELAY`: the relay's address (`http://127.0.0.1:8080` on the relay PC)
   - `PLAYER`: a different name for each player
4. **Load the ROM and your save**, then run the script (Tools → Lua Console).
5. Nickname your Pokémon with matching numbers, e.g. `A1`, `A2` and `B1`, `B2`.

The first run scans for your party address and prints it. Copy it into `PARTY_ADDR`
to skip the scan next time.

## Options

| Setting | Description |
|---|---|
| `KEEP_DEAD` | Keeps fainted Pokémon at 0 HP so Pokémon Centers and revives can't undo it |
| `PARTY_ADDR` | Party memory address; `nil` = auto-scan |
| `CHECK_EVERY`, `POLL_EVERY` | How often (in frames) to check HP and poll the relay |

## Known limitations

- Only Pokémon in the party are checked, not the PC boxes.
- Tested on Black only; White, B2W2 should work but are unverified.
- Faint history lives in the relay's memory. Restart the relay to start a new run.
- Pokémon with a digit in their default name (e.g. Porygon2) count as that number.
- Gen 4 and 3DS games are not supported.

## License

MIT
