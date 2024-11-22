print('Loading SaveManager v1.0.1')

local httpService = game:GetService("HttpService")

local SaveManager = {}

SaveManager.Folder = "LinoriaLibSettings"
SaveManager.Ignore = {}

SaveManager.Parser = {
	Toggle = {
		Save = function(idx, object)
			return { type = "Toggle", idx = idx, value = object.Value }
		end,
		Load = function(idx, data)
			if Toggles[idx] then
				Toggles[idx]:SetValue(data.value)
			end
		end,
	},
	Slider = {
		Save = function(idx, object)
			return { type = "Slider", idx = idx, value = tostring(object.Value) }
		end,
		Load = function(idx, data)
			if Options[idx] then
				Options[idx]:SetValue(data.value)
			end
		end,
	},
	Dropdown = {
		Save = function(idx, object)
			return { type = "Dropdown", idx = idx, value = object.Value, mutli = object.Multi }
		end,
		Load = function(idx, data)
			if Options[idx] then
				Options[idx]:SetValue(data.value)
			end
		end,
	},
	ColorPicker = {
		Save = function(idx, object)
			return { type = "ColorPicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
		end,
		Load = function(idx, data)
			if Options[idx] then
				Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
			end
		end,
	},
	KeyPicker = {
		Save = function(idx, object)
			return { type = "KeyPicker", idx = idx, mode = object.Mode, key = object.Value }
		end,
		Load = function(idx, data)
			if Options[idx] then
				Options[idx]:SetValue({ data.key, data.mode })
			end
		end,
	},
	Input = {
		Save = function(idx, object)
			return { type = "Input", idx = idx, text = object.Value }
		end,
		Load = function(idx, data)
			if Options[idx] and type(data.text) == "string" then
				Options[idx]:SetValue(data.text)
			end
		end,
	},
}

function SaveManager:SetIgnoreIndexes(list)
	for _, key in pairs(list) do
		SaveManager.Ignore[key] = true
	end
end

function SaveManager:SetFolder(folder)
	SaveManager.Folder = folder
	SaveManager:BuildFolderTree()
end

function SaveManager:Save(name)
	if not name then
		return false, "no config file is selected"
	end

	local fullPath = SaveManager.Folder .. "/settings/" .. name .. ".json"

	local data = {
		objects = {},
	}

	for idx, toggle in pairs(Toggles) do
		if not SaveManager.Ignore[idx] then
			table.insert(data.objects, SaveManager.Parser[toggle.Type].Save(idx, toggle))
		end
	end

	for idx, option in pairs(Options) do
		if SaveManager.Parser[option.Type] and not SaveManager.Ignore[idx] then
			table.insert(data.objects, SaveManager.Parser[option.Type].Save(idx, option))
		end
	end

	local success, encoded = pcall(httpService.JSONEncode, httpService, data)
	if not success then
		return false, "failed to encode data"
	end

	writefile(fullPath, encoded)
	return true
end

function SaveManager:Load(name)
	if not name then
		return false, "no config file is selected"
	end

	local file = SaveManager.Folder .. "/settings/" .. name .. ".json"
	if not isfile(file) then
		return false, "invalid file"
	end

	local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
	if not success then
		return false, "decode error"
	end

	for _, option in pairs(decoded.objects) do
		if SaveManager.Parser[option.type] then
			task.spawn(function()
				SaveManager.Parser[option.type].Load(option.idx, option)
			end)
		end
	end

	return true
end

function SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({
		"BackgroundColor",
		"MainColor",
		"AccentColor",
		"OutlineColor",
		"FontColor",
		"ThemeManager_ThemeList",
		"ThemeManager_CustomThemeList",
		"ThemeManager_CustomThemeName",
	})
end

function SaveManager:BuildFolderTree()
	local paths = {
		SaveManager.Folder,
		SaveManager.Folder .. "/themes",
		SaveManager.Folder .. "/settings",
	}

	for i = 1, #paths do
		local str = paths[i]
		if not isfolder(str) then
			makefolder(str)
		end
	end
end

function SaveManager:RefreshConfigList()
	local list = listfiles(SaveManager.Folder .. "/settings")

	local out = {}
	for i = 1, #list do
		local str = list[i]
		local name = str:match("settings/(.+).json")
		if name then
			table.insert(out, name)
		end
	end

	return out
end

function SaveManager:SetLibrary(library)
	SaveManager.Library = library
end

function SaveManager:LoadAutoloadConfig()
	if isfile(SaveManager.Folder .. "/settings/autoload.txt") then
		local name = readfile(SaveManager.Folder .. "/settings/autoload.txt")

		local success, err = SaveManager:Load(name)
		if not success then
			return SaveManager.Library:Notify("Failed to load autoload config: " .. err)
		end

		SaveManager.Library:Notify(string.format("Auto loaded config %q", name))
	end
end

function SaveManager:BuildConfigSection(tab)
	assert(SaveManager.Library, "Must set SaveManager.Library")

	local section = tab:AddRightGroupbox("Configuration")

	section:AddInput("SaveManager_ConfigName", { Text = "Config name" })
	section:AddDropdown(
		"SaveManager_ConfigList",
		{ Text = "Config list", Values = SaveManager:RefreshConfigList(), AllowNull = true }
	)

	section:AddDivider()

	section
		:AddButton("Create config", function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(" ", "") == "" then
				return SaveManager.Library:Notify("Invalid config name (empty)", 2)
			end

			local success, err = SaveManager:Save(name)
			if not success then
				return SaveManager.Library:Notify("Failed to save config: " .. err)
			end

			SaveManager.Library:Notify(string.format("Created config %q", name))

			Options.SaveManager_ConfigList:SetValues(SaveManager:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)
		:AddButton("Load config", function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = SaveManager:Load(name)
			if not success then
				return SaveManager.Library:Notify("Failed to load config: " .. err)
			end

			SaveManager.Library:Notify(string.format("Loaded config %q", name))
		end)

	section:AddButton("Overwrite config", function()
		local name = Options.SaveManager_ConfigList.Value

		local success, err = SaveManager:Save(name)
		if not success then
			return SaveManager.Library:Notify("Failed to overwrite config: " .. err)
		end

		SaveManager.Library:Notify(string.format("Overwrote config %q", name))
	end)

	section:AddButton("Refresh list", function()
		Options.SaveManager_ConfigList:SetValues(SaveManager:RefreshConfigList())
		Options.SaveManager_ConfigList:SetValue(nil)
	end)

	section:AddButton("Set as autoload", function()
		local name = Options.SaveManager_ConfigList.Value
		writefile(SaveManager.Folder .. "/settings/autoload.txt", name)
		SaveManager.AutoloadLabel:SetText("Current autoload config: " .. name)
		SaveManager.Library:Notify(string.format("Set %q to auto load", name))
	end)

	SaveManager.AutoloadLabel = section:AddLabel("Current autoload config: none", true)

	if isfile(SaveManager.Folder .. "/settings/autoload.txt") then
		local name = readfile(SaveManager.Folder .. "/settings/autoload.txt")
		SaveManager.AutoloadLabel:SetText("Current autoload config: " .. name)
	end

	SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
end

SaveManager:BuildFolderTree()

return SaveManager
