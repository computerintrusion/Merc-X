local crc = {}

local function requireany(...)
	local errs = {}
	for _, name in ipairs({...}) do
		local ok, mod = pcall(require, name)
		if ok then return mod, name end
		errs[#errs + 1] = mod
	end
	error(table.concat(errs, "\n"), 2)
end

local POLY = 0xEDB88320

-- Memoize function pattern (like http://lua-users.org/wiki/FuncTables ).
local function memoize(f)
	local mt = {}
	local t = setmetatable({}, mt)
	function mt:__index(k)
		local v = f(k); t[k] = v
		return v
	end
	return t
end

local crc_table = memoize(function(i)
	local crc = i
	for _ = 1, 8 do
		local b = bit32.band(crc, 1)
		crc = bit32.rshift(crc, 1)
		if b == 1 then crc = bit32.bxor(crc, POLY) end
	end
	return crc
end)

crc.crc_table = crc_table

local function crc32_byte(byte, crc)
	crc = bit32.bnot(crc or 0)
	local v1 = bit32.rshift(crc, 8)
	local v2 = crc_table[bit32.bxor(crc % 256, byte)]
	return bit32.bnot(bit32.bxor(v1, v2))
end
crc.crc32_byte = crc32_byte

local function crc32_string(s, crc)
	crc = crc or 0
	for i = 1, #s do
		crc = crc32_byte(string.byte(s, i), crc)
	end
	return crc
end
crc.crc32_string = crc32_string

local function crc32_buffer(s, crc, size)
	crc = crc or 0
	size = size or 8
	if size == 8 then -- If stats with code dublication are best to avoid recurring branches
		for i = 0, buffer.len(s) - 1 do
			crc = crc32_byte(buffer.readu8(s, i), crc)
		end
	elseif size == 16 then
		for i = 0, math.floor(buffer.len(s) / 2) - 1 do
			crc = crc32_byte(buffer.readu16(s, i), crc)
		end
	elseif size == 32 then
		for i = 0, math.floor(buffer.len(s) / 4) - 1 do
			crc = crc32_byte(buffer.readu32(s, i), crc)
		end
	end
	return crc
end
crc.crc32_buffer = crc32_buffer

function crc.crc32(s, crc, size)
	if type(s) == "string" then
		return crc32_string(s, crc)
	elseif type(s) == "buffer" then
		return crc32_buffer(s, crc, size)
	else
		return crc32_byte(s, crc)
	end
end

crc.bit = bit32 -- bit library used

return crc
