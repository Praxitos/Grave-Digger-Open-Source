--!strict

local Util = {}

-- Deep copy table
function Util.deepCopy(src: {}): {}
	local copy = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			copy[k] = Util.deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Merge tables recursively
function Util.merge(dest: {}, src: {}): {}
	for k, v in pairs(src) do
		if type(v) == "table" and type(dest[k]) == "table" then
			Util.merge(dest[k], v)
		else
			dest[k] = v
		end
	end
	return dest
end

return Util

