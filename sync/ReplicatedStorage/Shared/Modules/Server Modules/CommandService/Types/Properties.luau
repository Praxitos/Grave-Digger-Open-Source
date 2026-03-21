local AllProperties = {
	-- ValueObject
	"Value",

	-- Vector3-type
	"Position",
}

return function(registry)

	registry:RegisterType("properties", {
		Transform = function(text)
			return text
		end,

		Validate = function(text)
			for _, prop in ipairs(AllProperties) do
				if prop == text then
					return true
				end
			end

			return false, string.format(
				"%s is not a valid property name",
				text
			)
		end,

		Autocomplete = function(text)
			local out = {}
			text = text:lower()

			for _, prop in ipairs(AllProperties) do
				if prop:lower():find(text, 1, true) == 1 then
					table.insert(out, prop)
				end
			end

			return out
		end,
	})

end
