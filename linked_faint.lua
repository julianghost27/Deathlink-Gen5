-- linked_faint.lua -- BizHawk 2.11.1 (melonDS core, Lua 5.4)
-- When a numbered Pokemon (Hydreigon23) faints, the friend's Pokemon with the
-- same number (Electivire23) is set to 0 HP, and vice versa.

local RELAY      = "http://127.0.0.1:8080"  -- where relay.py runs
local PLAYER     = "CHANGE_ME"              -- MUST BE UNIQUE! (e.g., "Player1" on PC 1, "Player2" on PC 2)
local DOM        = "Main RAM"               -- check: console.log(memory.getmemorydomainlist())
local BASE       = 0x02000000               -- DS address where Main RAM starts
local PARTY_ADDR = 0x022349B4               -- DS address of party slot 1; nil = auto-scan
local CHECK_EVERY, POLL_EVERY = 10, 20      -- in frames
local KEEP_DEAD  = true                     -- keep re-applying 0 HP (blocks Pokemon Center heals)

---------------------------------------------------------------- helpers
local MUL, ADD = 0x41C64E6D, 0x6073

local function rd(addr, n)                  -- read n bytes at DS address, 0-indexed table
  local t = memory.read_bytes_as_array(addr - BASE, n, DOM)
  if t[0] ~= nil then return t end
  local o = {}
  for i = 0, n - 1 do o[i] = t[i + 1] end
  return o
end
local function u16(b, o) return b[o] | (b[o + 1] << 8) end
local function u32(b, o) return u16(b, o) | (u16(b, o + 2) << 16) end

-- block order table (PKHeX BlockPosition): decrypted block i sits at stored
-- position ORDER[sv*4 + i + 1]
local ORDER = {
  0,1,2,3, 0,1,3,2, 0,2,1,3, 0,3,1,2, 0,2,3,1, 0,3,2,1,
  1,0,2,3, 1,0,3,2, 2,0,1,3, 3,0,1,2, 2,0,3,1, 3,0,2,1,
  1,2,0,3, 1,3,0,2, 2,1,0,3, 3,1,0,2, 2,3,0,1, 3,2,0,1,
  1,2,3,0, 1,3,2,0, 2,1,3,0, 3,1,2,0, 2,3,1,0, 3,2,1,0,
}

---------------------------------------------------------------- Pokemon data (Gen 5)
-- returns nil if the 0xDC bytes at addr are not a valid party Pokemon
local function decode(addr)
  local raw = rd(addr, 0xDC)
  local pid, chk = u32(raw, 0), u16(raw, 6)
  if pid == 0 or u16(raw, 4) ~= 0 then return nil end

  local seed, enc, sum = chk, {}, 0
  for i = 0, 63 do                           -- blocks 0x08..0x87, seed = checksum
    seed = (seed * MUL + ADD) & 0xFFFFFFFF
    enc[i] = u16(raw, 8 + i * 2) ~ (seed >> 16)
    sum = sum + enc[i]
  end
  if (sum & 0xFFFF) ~= chk then return nil end

  local sv = ((pid >> 13) & 31) % 24
  local blk = {}
  for i = 0, 3 do
    local pos = ORDER[sv * 4 + i + 1]
    for w = 0, 15 do blk[i * 16 + w] = enc[pos * 16 + w] end
  end

  local nick = {}                            -- block C (index 2): 11 UTF-16 chars
  for w = 0, 10 do
    local c = blk[32 + w]
    if c == 0xFFFF or c == 0 then break end
    nick[#nick + 1] = c < 128 and string.char(c) or "?"
  end
  nick = table.concat(nick)

  local s2, st = pid, {}                     -- party stats 0x88.., seed = PID
  for i = 0, 4 do
    s2 = (s2 * MUL + ADD) & 0xFFFFFFFF
    st[i] = u16(raw, 0x88 + i * 2) ~ (s2 >> 16)
  end
  return { addr = addr, pid = pid, nick = nick,
           num = (function() local d = nick:match("(%d+)%D*$"); return d and tostring(tonumber(d)) end)(),
           level = st[2] & 0xFF, hp = st[3], maxhp = st[4] }
end

local function killHp(m)                     -- write 0 to current HP (encrypted)
  local s = m.pid
  for _ = 1, 4 do s = (s * MUL + ADD) & 0xFFFFFFFF end
  memory.write_u16_le(m.addr + 0x8E - BASE, s >> 16, DOM)
end

---------------------------------------------------------------- finding the party
local function plausible(m)
  return m and m.num and m.level >= 1 and m.level <= 100
         and m.maxhp >= 1 and m.maxhp <= 999 and m.hp <= m.maxhp
end

local function scan()
  local size, CH, hits = memory.getmemorydomainsize(DOM), 0x10000, {}
  for off = 0, size - 0xDC, CH do
    local n = math.min(CH + 0xDC, size - off)
    local b = rd(BASE + off, n)
    for p = 0, math.min(CH - 4, n - 0xDC), 4 do
      if u16(b, p + 4) == 0 and u16(b, p + 6) ~= 0 and u32(b, p) ~= 0 then
        local m = decode(BASE + off + p)
        if plausible(m) then hits[#hits + 1] = m end
      end
    end
  end
  table.sort(hits, function(a, b) return a.addr < b.addr end)
  for _, m in ipairs(hits) do
    console.log(string.format("candidate 0x%08X  %s  Lv%d  HP %d/%d",
      m.addr, m.nick, m.level, m.hp, m.maxhp))
  end
  return hits[1] and hits[1].addr or nil
end

---------------------------------------------------------------- network
local lastEvent = 0
local doomed, wasAlive = {}, {}

local function sendFaint(num)
  local ok, err = pcall(comm.httpPost, RELAY .. "/event?from=" .. PLAYER, tostring(num))
  console.log(ok and ("sent faint " .. num) or ("send failed: " .. tostring(err)))
end

local function poll()
  local ok, body = pcall(comm.httpGet,
    RELAY .. "/poll?player=" .. PLAYER .. "&since=" .. lastEvent)
  if not ok or type(body) ~= "string" then return end
  for line in body:gmatch("[^\r\n]+") do
    local id, from, num = line:match("^(%d+) (%S+) (%d+)$")
    if id then
      lastEvent = math.max(lastEvent, tonumber(id))
      if not doomed[num] then
        doomed[num] = true
        console.log("received faint " .. num .. " from " .. from)
      end
    end
  end
end

---------------------------------------------------------------- main logic
local function readParty()
  local list = {}
  for i = 0, 5 do
    local m = decode(PARTY_ADDR + i * 0xDC)
    if m and m.num then list[#list + 1] = m end
  end
  return list
end

local function step()
  for _, m in ipairs(readParty()) do
    local dead = (m.hp == 0)
   if dead and wasAlive[m.num] and not doomed[m.num] then
  sendFaint(m.num)                       -- own faint -> tell the friend
  if KEEP_DEAD then doomed[m.num] = true end
end    
if doomed[m.num] and not dead then       -- friend's faint -> kill ours
      killHp(m)
      dead = true
      console.log("set " .. m.nick .. " to 0 HP")
      if not KEEP_DEAD then doomed[m.num] = nil end
    end
    wasAlive[m.num] = not dead
  end
end

if not PARTY_ADDR then
  console.log("scanning for party ...")
  PARTY_ADDR = scan()
  if not PARTY_ADDR then
    console.log("no numbered Pokemon found. Nickname them with a shared number (e.g '3') and restart the script.")
    return
  end
  console.log(string.format("using PARTY_ADDR = 0x%08X (set it at the top to skip the scan)", PARTY_ADDR))
end

local frame = 0
while true do
  frame = frame + 1
  if frame % POLL_EVERY == 0 then poll() end
  if frame % CHECK_EVERY == 0 then step() end
  emu.frameadvance()
end
