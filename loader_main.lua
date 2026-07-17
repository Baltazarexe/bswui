-- ============================================================
--  BSW HUB - MAIN LOADER
--  Detecta o PlaceId do jogo e carrega o script correto
--
--  COMO USAR:
--  1. Cole este script inteiro no executor (Wave, Synapse, etc)
--  2. Ele automaticamente detecta qual jogo voce esta e carrega o script
--  3. Configuracoes sao salvas localmente em VeilUI/config
--
--  HOSPEDAGEM:
--  Altere o BASE_URL abaixo para apontar pro seu site
--  Ex: https://baltasoftware.com/scripts/
-- ============================================================

-- URL base GitHub raw
local BASE_URL = "https://raw.githubusercontent.com/Baltazarexe/bswui/main/"

-- Mapeamento: PlaceId -> script (sem .lua)
local GAME_MAP = {
	[79268393072444] = "lemon_bsw",      -- Lemon Tycoon
	-- [123456789] = "fish_bsw",          -- Fishing Simulator (exemplo)
	-- [987654321] = "slime_bsw",         -- Slime Farm (exemplo)
	-- [111111111] = "sw_bsw",            -- Sword Warriors (exemplo)
	-- adicione mais jogos aqui
}

local PlaceId = tostring(game.PlaceId)
local scriptName = GAME_MAP[tonumber(PlaceId)]

if not scriptName then
	warn("[BSW] PlaceId nao encontrado: " .. PlaceId)
	warn("[BSW] Jogos disponiveis:")
	for pid, name in pairs(GAME_MAP) do
		warn("  " .. pid .. " -> " .. name)
	end
	return
end

-- Tenta carregar do site (hospedado) ou fallback para arquivo local
local scriptUrl = BASE_URL .. scriptName .. ".lua"
local scriptContent

-- Tenta HttpGet primeiro (hospedado na internet)
local ok = pcall(function()
	if typeof(game:HttpGet) == "function" then
		scriptContent = game:HttpGet(scriptUrl)
	end
end)

-- Fallback: tenta arquivo local se HttpGet falhar
if not ok or not scriptContent then
	warn("[BSW] Nao conseguiu carregar de " .. scriptUrl)
	warn("[BSW] Tentando carregar arquivo local: " .. scriptName .. ".lua")

	pcall(function()
		scriptContent = readfile(scriptName .. ".lua")
	end)
end

if not scriptContent then
	warn("[BSW] ERRO: nao conseguiu carregar o script de forma alguma")
	warn("[BSW] Certifique-se que o arquivo existe no site ou na pasta local")
	return
end

-- Executa o script
local ok, err = pcall(function()
	loadstring(scriptContent)()
end)

if not ok then
	warn("[BSW] ERRO ao executar script: " .. tostring(err))
else
	print("[BSW] Script carregado com sucesso!")
end
