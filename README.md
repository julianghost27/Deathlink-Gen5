# DeathLink-Gen5

Soul Link faint sync for Pokémon Gen 5 (Black/White/B2W2) Nuzlocke runs in BizHawk. When one player's Pokémon faints, the partner with the same nickname number faints too.

## How it works

Pokémon are paired by the number at the end of their nickname. The letters don't matter (`A23` = `B23`).

Example: Player 1's `Hydreigon23` faints, so Player 2's `Electivire23` is set to 0 HP (and the other way around).

When a Pokémon faints, the script sends its number to a small relay server, and the other player's script sets the matching Pokémon to 0 HP.

## Requirements

- BizHawk 2.11.1 (melonDS core)
- Python 3 (no extra packages)
- A Gen 5 ROM each (tested on: Black)
- Both players must be able to reach the relay's port (same network, port forwarding, or VPN)

## Setup

1. **Start the relay** on ONE PC: `python relay.py` (listens on port 8080).

2. **Start EmuHawk with HTTP enabled** on both PCs. `<relay-ip>` is `127.0.0.1` on the PC running the relay, and that PC's IP address on the other PC.

   On Windows:
   1. Right-click `EmuHawk.exe` and select "Create shortcut".
   2. Right-click the shortcut and select "Properties".
   3. In the **Target** field, click at the very end (after the closing quotation mark), add a space, then paste only this:
      ```
      --url_get=http://<relay-ip>:8080/poll --url_post=http://<relay-ip>:8080/event
      ```
   4. Click "Apply" and start EmuHawk from this shortcut.

   On Linux, pass the same two flags on the command line.

3. **Edit the top of `linked_faint.lua`:**
   - `RELAY`: the relay's address (`http://127.0.0.1:8080` on the relay PC, `http://<relay-ip>:8080` on the other)
   - `PLAYER`: a different name for each player (letters and numbers only, no spaces)

4. Load the ROM and your save.

5. **Nickname your Pokémon** with matching numbers, e.g. `A1`, `A2` for you and `B1`, `B2` for your partner.

6. **Run the script** (Tools → Lua Console). The first run scans for your party and prints its address. Copy it into `PARTY_ADDR` to skip the scan next time.

## Options

| Setting | Description |
|---|---|
| `KEEP_DEAD` | Keeps fainted Pokémon at 0 HP so Pokémon Centers and revives can't undo it |
| `PARTY_ADDR` | Party memory address; `nil` = auto-scan |
| `CHECK_EVERY`, `POLL_EVERY` | How often (in frames) to check HP and poll the relay |

## Known limitations

- Only Pokémon in the party are checked, not the PC boxes.
- Tested on Black only; White and B2W2 should work but are unverified.
- Use each number only once per party.
- `A01` and `A1` count as the same number.
- Pokémon with a digit in their default name (e.g. Porygon2) count as that number.
- Faint history lives in the relay's memory. Restart the relay to start a new run.
- When the script starts, it asks the relay for all past faints. With `KEEP_DEAD = true`, restarting the script re-applies every earlier faint (handy after a crash).
- Gen 4 and 3DS games are not supported.

## License

MIT (see `LICENSE`)
