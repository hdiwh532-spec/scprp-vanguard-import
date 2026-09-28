-- SCPRP VANGUARD FACILITY REMOTE IMPORTER
-- Generated from SCPRP_DIRECT.
--
-- IMPORTANT:
-- 1. Upload all create_###.txt, refs_###.txt and rename_###.txt files
--    from this package to one public/raw HTTP location.
-- 2. Put that folder URL in BASE_URL below.
-- 3. Add this entire script as a NORMAL / ENABLED SCP:RP Server Addon.
-- 4. DO NOT use "Run Once" for the full import; SCP:RP Run Once
--    executions are limited to 10 seconds.
--
-- The importer intentionally interprets the exact Lua subset produced
-- by the Vanguard exporter. It does not use loadstring/load.

local BASE_URL = "https://raw.githubusercontent.com/YOURNAME/YOURREPO/main/"

local CREATE_COUNT = 23
local REFS_COUNT = 1
local RENAME_COUNT = 2

local MARKER_NAME = "__SCPRP_VANGUARD_IMPORT_COMPLETE__"

local instances = {}
local createdCount = 0
local failedProperties = 0
local failedBlocks = 0

-- ============================================================
-- HTTP
-- ============================================================

local function fetch(url)
	local ok, a, b = pcall(function()
		return http(url, "get")
	end)

	if not ok then
		error("HTTP request failed: " .. tostring(a))
	end

	local body = nil

	if type(b) == "string" then
		body = b
	elseif type(a) == "string" then
		body = a
	elseif type(a) == "table" then
		body = a.Body or a.body or a[2] or a[1]
	end

	if type(body) ~= "string" then
		error("HTTP response did not contain text: " .. tostring(url))
	end

	return body
end

-- ============================================================
-- LUA STRING DECODER
-- Handles string.format("%q") output used by the exporter.
-- ============================================================

local function decodeQuoted(s)
	if string.sub(s, 1, 1) ~= '"' then
		return s
	end

	local last = string.len(s)

	if string.sub(s, last, last) ~= '"' then
		error("Invalid quoted string")
	end

	local out = ""
	local i = 2

	while i < last do
		local c = string.sub(s, i, i)

		if c ~= "\\" then
			out = out .. c
			i = i + 1
		else
			i = i + 1

			if i >= last then
				error("Invalid escape sequence")
			end

			local e = string.sub(s, i, i)

			if e == "n" then
				out = out .. "\n"
				i = i + 1

			elseif e == "r" then
				out = out .. "\r"
				i = i + 1

			elseif e == "t" then
				out = out .. "\t"
				i = i + 1

			elseif e == "b" then
				out = out .. "\b"
				i = i + 1

			elseif e == "f" then
				out = out .. "\f"
				i = i + 1

			elseif e == "v" then
				out = out .. "\v"
				i = i + 1

			elseif e == "a" then
				out = out .. "\a"
				i = i + 1

			elseif e == "\\" then
				out = out .. "\\"
				i = i + 1

			elseif e == '"' then
				out = out .. '"'
				i = i + 1

			elseif e >= "0" and e <= "9" then
				local digits = e
				i = i + 1

				while i < last
					and string.len(digits) < 3 do

					local d = string.sub(s, i, i)

					if d < "0" or d > "9" then
						break
					end

					digits = digits .. d
					i = i + 1
				end

				out = out .. string.char(tonumber(digits))
			else
				out = out .. e
				i = i + 1
			end
		end
	end

	return out
end

-- ============================================================
-- TOP-LEVEL ARGUMENT SPLITTER
-- Used for generated constructors such as CFrame.new(...)
-- and NumberSequence.new({...}).
-- ============================================================

local function splitTop(s)
	local result = {}
	local start = 1

	local parenDepth = 0
	local braceDepth = 0
	local inString = false
	local escaped = false

	local length = string.len(s)

	for i = 1, length do
		local c = string.sub(s, i, i)

		if inString then
			if escaped then
				escaped = false
			elseif c == "\\" then
				escaped = true
			elseif c == '"' then
				inString = false
			end
		else
			if c == '"' then
				inString = true
			elseif c == "(" then
				parenDepth = parenDepth + 1
			elseif c == ")" then
				parenDepth = parenDepth - 1
			elseif c == "{" then
				braceDepth = braceDepth + 1
			elseif c == "}" then
				braceDepth = braceDepth - 1
			elseif c == ","
				and parenDepth == 0
				and braceDepth == 0 then

				table.insert(
					result,
					string.sub(s, start, i - 1)
				)

				start = i + 1
			end
		end
	end

	local tail = string.sub(s, start)

	if tail ~= "" then
		table.insert(result, tail)
	end

	return result
end

-- ============================================================
-- VALUE DECODER
-- Supports exactly the value constructors emitted by the
-- Vanguard exporter.
-- ============================================================

local function parseValue(expr)
	expr = string.gsub(expr, "^%s+", "")
	expr = string.gsub(expr, "%s+$", "")

	if expr == "true" then
		return true
	end

	if expr == "false" then
		return false
	end

	if expr == "math.huge" then
		return math.huge
	end

	if expr == "-math.huge" then
		return -math.huge
	end

	if expr == "0/0" then
		return 0/0
	end

	if string.sub(expr, 1, 1) == '"' then
		return decodeQuoted(expr)
	end

	local enumType, enumItem = string.match(
		expr,
		"^Enum%.([%w_]+)%.([%w_]+)$"
	)

	if enumType then
		return Enum[enumType][enumItem]
	end

	-- Plain numeric value.
	local numeric = tonumber(expr)

	if numeric ~= nil then
		return numeric
	end

	local ctor, inner = string.match(
		expr,
		"^([%w_]+%.[%w_]+)%((.*)%)$"
	)

	if not ctor then
		error("Unsupported expression: " .. expr)
	end

	local args = splitTop(inner)

	local function n(i)
		local v = tonumber(args[i])

		if v == nil then
			error(
				"Expected number in " ..
				ctor ..
				" argument " ..
				tostring(i)
			)
		end

		return v
	end

	if ctor == "Color3.new" then
		return Color3.new(
			n(1),
			n(2),
			n(3)
		)
	end

	if ctor == "Vector3.new" then
		return Vector3.new(
			n(1),
			n(2),
			n(3)
		)
	end

	if ctor == "Vector2.new" then
		return Vector2.new(
			n(1),
			n(2)
		)
	end

	if ctor == "CFrame.new" then
		if #args ~= 12 then
			error("Invalid CFrame argument count")
		end

		local values = {}

		for i = 1, 12 do
			values[i] = n(i)
		end

		return CFrame.new(
			values[1],
			values[2],
			values[3],
			values[4],
			values[5],
			values[6],
			values[7],
			values[8],
			values[9],
			values[10],
			values[11],
			values[12]
		)
	end

	if ctor == "UDim.new" then
		return UDim.new(
			n(1),
			n(2)
		)
	end

	if ctor == "UDim2.new" then
		return UDim2.new(
			n(1),
			n(2),
			n(3),
			n(4)
		)
	end

	if ctor == "BrickColor.new" then
		return BrickColor.new(
			n(1)
		)
	end

	if ctor == "NumberRange.new" then
		return NumberRange.new(
			n(1),
			n(2)
		)
	end

	if ctor == "PhysicalProperties.new" then
		return PhysicalProperties.new(
			n(1),
			n(2),
			n(3),
			n(4),
			n(5)
		)
	end

	if ctor == "NumberSequenceKeypoint.new" then
		return NumberSequenceKeypoint.new(
			n(1),
			n(2),
			n(3)
		)
	end

	if ctor == "ColorSequenceKeypoint.new" then
		return ColorSequenceKeypoint.new(
			n(1),
			parseValue(args[2])
		)
	end

	if ctor == "NumberSequence.new" then
		local tableText = args[1]

		if string.sub(tableText, 1, 1) ~= "{"
			or string.sub(
				tableText,
				string.len(tableText),
				string.len(tableText)
			) ~= "}" then

			error("Invalid NumberSequence table")
		end

		local innerTable = string.sub(
			tableText,
			2,
			string.len(tableText) - 1
		)

		local points = {}

		if innerTable ~= "" then
			for _, piece in ipairs(
				splitTop(innerTable)
			) do
				table.insert(
					points,
					parseValue(piece)
				)
			end
		end

		return NumberSequence.new(points)
	end

	if ctor == "ColorSequence.new" then
		local tableText = args[1]

		if string.sub(tableText, 1, 1) ~= "{"
			or string.sub(
				tableText,
				string.len(tableText),
				string.len(tableText)
			) ~= "}" then

			error("Invalid ColorSequence table")
		end

		local innerTable = string.sub(
			tableText,
			2,
			string.len(tableText) - 1
		)

		local points = {}

		if innerTable ~= "" then
			for _, piece in ipairs(
				splitTop(innerTable)
			) do
				table.insert(
					points,
					parseValue(piece)
				)
			end
		end

		return ColorSequence.new(points)
	end

	error("Unsupported constructor: " .. ctor)
end

-- ============================================================
-- SET PROPERTY SAFELY
-- ============================================================

local function setProperty(instance, propertyName, expression)
	local ok, value = pcall(function()
		return parseValue(expression)
	end)

	if not ok then
		failedProperties = failedProperties + 1
		return
	end

	local assigned = pcall(function()
		instance[propertyName] = value
	end)

	if not assigned then
		failedProperties = failedProperties + 1
	end
end

-- ============================================================
-- PROCESS ONE CREATE BLOCK
-- ============================================================

local function processCreateBlock(block)
	local lines = {}

	for line in string.gmatch(
		block,
		"[^\r\n]+"
	) do
		table.insert(lines, line)
	end

	if #lines < 3 then
		return
	end

	local className = string.match(
		lines[1],
		'^local a=Instance%.new%("([^"]+)"%)$'
	)

	local tempName = string.match(
		lines[2],
		'^a%.Name="(__SCPRP_%d+)"$'
	)

	if not className or not tempName then
		failedBlocks = failedBlocks + 1
		return
	end

	local assignments = {}
	local attributes = {}
	local parentName = nil
	local insertFound = false

	for i = 3, #lines do
		local line = lines[i]

		if line == "f(a)" then
			insertFound = true

		else
			local prop, expr = string.match(
				line,
				"^a%.([%w_]+)=(.+)$"
			)

			if prop and expr then
				table.insert(
					assignments,
					{prop, expr}
				)
			else
				local attrName, attrExpr = string.match(
					line,
					'^a:SetAttribute%("((?:\\.|[^"])*)",(.*)%)$'
				)

				if attrName and attrExpr then
					table.insert(
						attributes,
						{
							decodeQuoted(
								'"' .. attrName .. '"'
							),
							attrExpr
						}
					)
				else
					local parent = string.match(
						line,
						'^a%.Parent=f%("(__SCPRP_%d+)"%)$'
					)

					if parent then
						parentName = parent
					end
				end
			end
		end
	end

	if not insertFound then
		failedBlocks = failedBlocks + 1
		return
	end

	local instance

	local ok, err = pcall(function()
		instance = Instance.new(className)
	end)

	if not ok or not instance then
		failedBlocks = failedBlocks + 1
		return
	end

	instance.Name = tempName

	-- Set ordinary properties before insertion.
	for _, pair in ipairs(assignments) do
		if pair[1] ~= "Name" then
			setProperty(
				instance,
				pair[1],
				pair[2]
			)
		end
	end

	for _, attribute in ipairs(attributes) do
		local okValue, value = pcall(function()
			return parseValue(attribute[2])
		end)

		if okValue then
			pcall(function()
				instance:SetAttribute(
					attribute[1],
					value
				)
			end)
		else
			failedProperties = failedProperties + 1
		end
	end

	-- Add new Instance to the SCP:RP map.
	local inserted = pcall(function()
		f(instance)
	end)

	if not inserted then
		failedBlocks = failedBlocks + 1
		return
	end

	instances[tempName] = instance
	createdCount = createdCount + 1

	-- Parent after the object has been inserted.
	if parentName then
		local parentInstance = instances[parentName]

		if parentInstance then
			local parented = pcall(function()
				instance.Parent = parentInstance
			end)

			if not parented then
				failedBlocks = failedBlocks + 1
			end
		else
			failedBlocks = failedBlocks + 1
		end
	end
end

-- ============================================================
-- PROCESS CREATE FILE
-- ============================================================

local function processCreateFile(number)
	local fileName = string.format(
		"create_%03d.txt",
		number
	)

	print("Downloading " .. fileName)

	local body = fetch(
		BASE_URL .. fileName
	)

	local countBefore = createdCount

	for block in string.gmatch(
		body,
		"do\n(.-)\nend"
	) do
		processCreateBlock(block)

		if createdCount > 0
			and createdCount % 100 == 0 then
			task.wait()
		end
	end

	print(
		"Finished " ..
		fileName ..
		" | created " ..
		tostring(createdCount - countBefore) ..
		" objects"
	)
end

-- ============================================================
-- PROCESS REFERENCE FILE
-- ============================================================

local function processReferenceFile(number)
	local fileName = string.format(
		"refs_%03d.txt",
		number
	)

	print("Downloading " .. fileName)

	local body = fetch(
		BASE_URL .. fileName
	)

	local processed = 0

	for block in string.gmatch(
		body,
		"do\n(.-)\nend"
	) do
		local source, property, target = string.match(
			block,
			'local a=f%("(__SCPRP_%d+)"%)\n' ..
			'a%.([%w_]+)=f%("(__SCPRP_%d+)"%)'
		)

		if source and property and target then
			local a = instances[source]
			local b = instances[target]

			if a and b then
				local ok = pcall(function()
					a[property] = b
				end)

				if not ok then
					failedBlocks = failedBlocks + 1
				end
			else
				failedBlocks = failedBlocks + 1
			end
		else
			failedBlocks = failedBlocks + 1
		end

		processed = processed + 1

		if processed % 100 == 0 then
			task.wait()
		end
	end

	print(
		"Finished " ..
		fileName ..
		" | references processed: " ..
		tostring(processed)
	)
end

-- ============================================================
-- PROCESS RENAME FILE
-- ============================================================

local function processRenameFile(number)
	local fileName = string.format(
		"rename_%03d.txt",
		number
	)

	print("Downloading " .. fileName)

	local body = fetch(
		BASE_URL .. fileName
	)

	local processed = 0

	for block in string.gmatch(
		body,
		"do\n(.-)\nend"
	) do
		local source = string.match(
			block,
			'local a=f%("(__SCPRP_%d+)"%)'
		)

		local encodedName = string.match(
			block,
			'a%.Name="((?:\\.|[^"])*)"'
		)

		if source and encodedName then
			local a = instances[source]

			if a then
				local newName = decodeQuoted(
					'"' .. encodedName .. '"'
				)

				pcall(function()
					a.Name = newName
				end)
			else
				failedBlocks = failedBlocks + 1
			end
		else
			failedBlocks = failedBlocks + 1
		end

		processed = processed + 1

		if processed % 100 == 0 then
			task.wait()
		end
	end

	print(
		"Finished " ..
		fileName ..
		" | names processed: " ..
		tostring(processed)
	)
end

-- ============================================================
-- START / DUPLICATE GUARD
-- ============================================================

local alreadyImported = f(MARKER_NAME)

if alreadyImported then
	print("SCPRP Vanguard import marker already exists.")
	print("Import skipped.")
	return
end

print("======================================")
print("SCPRP VANGUARD IMPORT STARTING")
print("======================================")

-- ============================================================
-- PHASE 1: CREATE
-- ============================================================

for i = 1, CREATE_COUNT do
	processCreateFile(i)

	task.wait()
end

print("======================================")
print("CREATE PHASE COMPLETE")
print("Objects created:", createdCount)
print("Property failures:", failedProperties)
print("Block failures:", failedBlocks)
print("======================================")

-- ============================================================
-- PHASE 2: REFERENCES
-- ============================================================

for i = 1, REFS_COUNT do
	processReferenceFile(i)
	task.wait()
end

print("======================================")
print("REFERENCE PHASE COMPLETE")
print("======================================")

-- ============================================================
-- PHASE 3: ORIGINAL NAMES
-- ============================================================

for i = 1, RENAME_COUNT do
	processRenameFile(i)
	task.wait()
end

print("======================================")
print("RENAME PHASE COMPLETE")
print("======================================")

-- ============================================================
-- COMPLETION MARKER
-- ============================================================

local marker = Instance.new("Folder")
marker.Name = MARKER_NAME

pcall(function()
	marker:SetAttribute(
		"ExportedObjects",
		createdCount
	)
end)

pcall(function()
	f(marker)
end)

print("======================================")
print("SCPRP VANGUARD IMPORT COMPLETE")
print("Objects created:", createdCount)
print("Property failures:", failedProperties)
print("Block failures:", failedBlocks)
print("======================================")
