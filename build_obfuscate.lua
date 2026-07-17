-- ============================================================
--  BUILD SCRIPT - Obfuscate and prepare scripts for hosting
--
--  HOW TO USE:
--  1. Manually obfuscate each script on:
--     https://wearedevs.net/obfuscator
--  2. Paste the obfuscated result in /obfuscated/name_bsw.lua
--  3. Upload to your site in /scripts/obfuscated/
--
--  OR run this script to do basic minification
-- ============================================================

-- Basic minification: remove spaces, comments, etc
local function minify(code)
	-- Remove comments -- until end of line
	code = code:gsub("%-%-[^\n]*", "")

	-- Remove comments /* */
	code = code:gsub("%/%*(.-)%*%/", "")

	-- Remove multiple spaces/tabs
	code = code:gsub("[ \t]+", " ")

	-- Remove spaces around operators (be careful with strings!)
	-- This is basic; a real minifier would be more complex
	code = code:gsub("[ ]*([=+%-*/<>!]+)[ ]*", "%1")

	-- Remove unnecessary line breaks (simplified)
	code = code:gsub("\n[ \t]*", "\n")

	return code
end

-- Load lua file, minify, save to /obfuscated folder
local function processScript(filename, outputDir)
	outputDir = outputDir or "obfuscated"

	-- Create folder if it doesn't exist
	pcall(function()
		if not isfolder(outputDir) then
			makefolder(outputDir)
		end
	end)

	-- Read original file
	local ok, content = pcall(function()
		return readfile(filename)
	end)

	if not ok or not content then
		print("[BUILD] ERROR: could not read " .. filename)
		return false
	end

	-- Minify
	local minified = minify(content)

	-- Save to output
	local outputPath = outputDir .. "/" .. filename:match("([^/]+)$")
	pcall(function()
		writefile(outputPath, minified)
	end)

	print("[BUILD] ✓ " .. filename .. " -> " .. outputPath)
	print("         Original: " .. (#content) .. " bytes | Minified: " .. (#minified) .. " bytes")

	return true
end

print("[BSW BUILD] ===============================================")
print("Manual Obfuscation Process:")
print("1. Go to: https://wearedevs.net/obfuscator")
print("2. Paste each _bsw.lua file here:")
print("   - lemon_bsw.lua")
print("   - fish_bsw.lua (when available)")
print("   - etc")
print("3. Copy the obfuscated result")
print("4. Paste in /obfuscated/file_bsw.lua")
print("5. Upload to your site in /scripts/obfuscated/")
print()
print("OR run this to minify (not as effective):")
print()

-- Process lemon_bsw.lua as example
processScript("lemon_bsw.lua")

print()
print("[BSW BUILD] Next steps:")
print("1. Scripts in /obfuscated/ are ready")
print("2. Upload ALL obfuscated _bsw.lua files to your site")
print("3. Update loader_main.lua with the correct PlaceIds")
print("4. Paste loader_main.lua in your executor")
