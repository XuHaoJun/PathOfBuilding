-- #@
-- This wrapper allows the program to run headless on any OS (in theory)
-- It can be run using a standard lua interpreter, although LuaJIT is preferable


LibDeflate = require("LibDeflate")

local xml = require("xml")
local json = require("json")

bit = bit or bit32 or require("bitop.funcs")
unpack = unpack or table.unpack
loadstring = loadstring or load

local lua_version = _VERSION:sub(-3)
if lua_version > "5.2" then
	_old_string_format = string.format
	local function string_format(fmt, ...)
		local args, n = { ... }, select('#', ...)
		fmt = string.gsub(fmt, "%%d", "%%.0f")
		return _old_string_format(fmt, unpack(args, 1, n))
	end
	_G.string.format = string_format
end

function setfenv()
end

-- Callbacks
local callbackTable = { }
local mainObject
function runCallback(name, ...)
	if callbackTable[name] then
		return callbackTable[name](...)
	elseif mainObject and mainObject[name] then
		return mainObject[name](mainObject, ...)
	end
end
function SetCallback(name, func)
	callbackTable[name] = func
end
function GetCallback(name)
	return callbackTable[name]
end
function SetMainObject(obj)
	mainObject = obj
end

-- Image Handles
local imageHandleClass = { }
imageHandleClass.__index = imageHandleClass
function NewImageHandle()
	return setmetatable({ }, imageHandleClass)
end
function imageHandleClass:Load(fileName, ...)
	self.valid = true
end
function imageHandleClass:Unload()
	self.valid = false
end
function imageHandleClass:IsValid()
	return self.valid
end
function imageHandleClass:SetLoadingPriority(pri) end
function imageHandleClass:ImageSize()
	return 1, 1
end

-- Rendering
function RenderInit() end
function GetScreenSize()
	return 1920, 1080
end
function SetClearColor(r, g, b, a) end
function SetDrawLayer(layer, subLayer) end
function SetViewport(x, y, width, height) end
function SetDrawColor(r, g, b, a) end
function DrawImage(imgHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom) end
function DrawImageQuad(imageHandle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4) end
function DrawString(left, top, align, height, font, text) end
function DrawStringWidth(height, font, text)
	return 1
end
function DrawStringCursorIndex(height, font, text, cursorX, cursorY)
	return 0
end
function StripEscapes(text)
	return text:gsub("^%d",""):gsub("^x%x%x%x%x%x%x","")
end
function GetAsyncCount()
	return 0
end

-- Search Handles
function NewFileSearch() end

-- General Functions
function SetWindowTitle(title) end
function GetCursorPos()
	return 0, 0
end
function SetCursorPos(x, y) end
function ShowCursor(doShow) end
function IsKeyDown(keyName) end
function Copy(text) end
function Paste() end
function Deflate(data)
		return LibDeflate:CompressZlib(data)
end
function Inflate(data)
		return LibDeflate:DecompressZlib(data)
end
function GetTime()
	return 0
end
function GetScriptPath()
    return "."
end
function GetRuntimePath()
    return "."
end
function GetUserPath()
    return "."
end
function MakeDir(path) end
function RemoveDir(path) end
function SetWorkDir(path) end
function GetWorkDir()
	return ""
end
function LaunchSubScript(scriptText, funcList, subList, ...) end
function AbortSubScript(ssID) end
function IsSubScriptRunning(ssID) end
function LoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	local func, err = loadfile(fileName)
	if func then
		return func(...)
	else
		error("LoadModule() error loading '"..fileName.."': "..err)
	end
end
function PLoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	local func, err = loadfile(fileName)
	if func then
		return PCall(func, ...)
	else
		error("PLoadModule() error loading '"..fileName.."': "..err)
	end
end
function PCall(func, ...)
	local ret = { pcall(func, ...) }
	if ret[1] then
		table.remove(ret, 1)
		return nil, table.unpack(ret)
	else
		return ret[2]
	end	
end
function ConPrintf(fmt, ...)
	-- Optional
	--print(string.format(fmt, ...))
end
function ConPrintTable(tbl, noRecurse) end
function ConExecute(cmd) end
function ConClear() end
function SpawnProcess(cmdName, args) end
function OpenURL(url) end
function SetProfiling(isEnabled) end
function Restart() end
function Exit() end

local l_require = require
function require(name)
	-- Hack to stop it looking for lcurl, which we don't really need
	if name == "lcurl.safe" then
		return
	end
	return l_require(name)
end


dofile("Launch.lua")

runCallback("OnInit")
runCallback("OnFrame") -- Need at least one frame for everything to initialise

if mainObject.promptMsg then
	-- Something went wrong during startup
	print(mainObject.promptMsg)
	io.read("*l")
	return
end

-- The build module; once a build is loaded, you can find all the good stuff in here
local build = mainObject.main.modes["BUILD"]

-- Here's some helpful helper functions to help you get started
function newBuild()
	mainObject.main:SetMode("BUILD", false, "Help, I'm stuck in Path of Building!")
	runCallback("OnFrame")
end
local function loadBuildFromXML(xmlText)
	mainObject.main:SetMode("BUILD", false, "", xmlText)
	runCallback("OnFrame")
end
local function loadBuildFromCode(codeText)
	mainObject.main:SetMode("BUILD", false, "")
	runCallback("OnFrame")
	local charData = build.importTab:ImportItemsAndSkills(getItemsJSON)
	build.importTab:ImportPassiveTreeAndJewels(getPassiveSkillsJSON, charData)
	-- You now have a build without a correct main skill selected, or any configuration options set
	-- Good luck!
end
local function loadBuildFromJSON(getItemsJSON, getPassiveSkillsJSON)
	mainObject.main:SetMode("BUILD", false, "")
	runCallback("OnFrame")
	local charData = build.importTab:ImportItemsAndSkills(getItemsJSON)
	build.importTab:ImportPassiveTreeAndJewels(getPassiveSkillsJSON, charData)
	-- You now have a build without a correct main skill selected, or any configuration options set
	-- Good luck!
end

function saveBuildToXml()
    local xmlText = build:SaveDB("dummy")
    if not xmlText then
        print("Failed to prepare save XML")
        os.exit(1)
    end
    return xmlText
end

function saveBuildToCode()
		local codeText = common.base64.encode(Deflate(build:SaveDB("code"))):gsub("+","-"):gsub("/","_")
    if not codeText then
        print("Failed to prepare save code")
        os.exit(1)
    end
		return codeText
end

local open = io.open

local function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local function file_exists(name)
	if name == nil then
		return false
	else 
  		local f = io.open(name,"r")
  		if f~=nil then io.close(f) return true else return false end
	end
end

local function test_local_jsons()
	local items = read_file("char-items.json");
	local passives = read_file("char-passives.json");
	loadBuildFromJSON(items, passives)
	local resultByJson = saveBuildToXml()

	loadBuildFromXML(resultByJson)
	build.mainSocketGroup = 7
	build.calcsTab.input.skill_number = 7
	-- build.skillsTab.socketGroupList[6].mainActiveSkillCalcs = 3
	-- build.skillsTab.socketGroupList[6].mainActiveSkill = 3
	build.configTab.input.enemyIsBoss = "Shaper"
	build.calcsTab:BuildOutput()
	runCallback("OnFrame")
	local result = saveBuildToXml()
	-- runCallback("OnFrame")

	local file
	file = io.open("char-pob.xml", "w")
	file:write(result)
	file:close()

	-- file = io.open("char-code.txt", "w")
	-- file:write(saveBuildToCode())
	-- file:close()
end

function saveTreeJson()
	local treeData = dofile("./TreeData/3_11/tree.lua")
	local newNodes = {}
	for k, v in pairs(treeData.nodes) do
		if type(k) == "number" then
			local newK = string.format("%d", k)
			newNodes[newK] = v
		else
			newNodes[k] = v
		end
	end
	treeData.nodes = newNodes
	file = io.open("tree_3_11.json", "w")
	file:write(json.encode({nodes = treeData.nodes, groups = treeData.groups, classes = treeData.classes }))
	file:close()
end

function getBuildXmlByXml(xmlText)
	loadBuildFromXML(xmlText)
	local result = saveBuildToXml()
	return result
end

function getBuildXmlByJsons(passivesJson, itemsJson)
	loadBuildFromJSON(itemsJson, passivesJson)
	local resultByJson = saveBuildToXml()
	loadBuildFromXML(resultByJson)
	local result = saveBuildToXml()
	return result
end

function getBuildXmlByFiles(passivesJsonPath, itemsJsonPath)
	if file_exists(passivesJsonPath) and file_exists(itemsJsonPath) then
			local items = read_file(itemsJsonPath);
			local passives = read_file(passivesJsonPath);
			local result = getBuildXmlByJsons(passives, items)
			return result
	end
end


-- test_local_jsons()

local passivesJsonPath = (arg and arg[1]) or nil
local itemsJsonPath = (arg and arg[2]) or nil
if passivesJsonPath and itemsJsonPath then
	print(getBuildXmlByFiles(passivesJsonPath, itemsJsonPath))
end


function toListMode()
	mainObject.main:SetMode("List")
	runCallback("OnFrame")
end


-- Probably optional
-- runCallback("OnExit")
