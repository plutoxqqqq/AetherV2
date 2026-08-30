-- AetherV2 Cloud Configs client.
-- This attaches cloud storage to the existing Configs category and deliberately
-- reuses the GUI's local serializer/importer instead of defining a second format.

local mainapi, license = ...
if type(mainapi) ~= 'table' then return end
license = type(license) == 'table' and license or {}

local profiles = mainapi.Categories and mainapi.Categories.Profiles
local internals = mainapi.CloudConfigInternals
if not profiles or type(internals) ~= 'table' or type(internals.ImportJson) ~= 'function' or type(internals.ConfigPath) ~= 'function' then
	warn('[AetherV2/CloudConfigs] Config internals are unavailable')
	return
end

local httpService = game:GetService('HttpService')
local SHADOW_PROFILE = '__cloud_active'
local STATE_PATH = 'aetherv2/profiles/cloud-configs.json'
local AUTOSAVE_IDLE = 120
local PERIODIC_SAVE = 300
local LOCAL_SYNC_INTERVAL = 300

local requestFunction = request or http_request
if type(requestFunction) ~= 'function' and type(syn) == 'table' then requestFunction = syn.request end
if type(requestFunction) ~= 'function' and type(http) == 'table' then requestFunction = http.request end

local function endpoint()
	local value = license.PremiumEndpoint
	if (type(value) ~= 'string' or value == '') and getgenv then
		pcall(function() value = getgenv().AetherV2PremiumEndpoint end)
	end
	if type(value) ~= 'string' or value == '' then value = shared.AetherV2PremiumEndpoint end
	if type(value) ~= 'string' or value == '' then value = 'https://aetherv2.onrender.com' end
	return value:gsub('/+$', '')
end

local function notify(text, alert)
	pcall(function()
		mainapi:CreateNotification('Cloud Configs', tostring(text), alert and 8 or 5, alert and 'alert' or 'info')
	end)
end

local function ensureStateFolder()
	if makefolder and (not isfolder or not isfolder('aetherv2')) then pcall(makefolder, 'aetherv2') end
	if makefolder and (not isfolder or not isfolder('aetherv2/profiles')) then pcall(makefolder, 'aetherv2/profiles') end
end

local function loadState()
	local state = {
		mode = 'Local',
		autoSave = false,
		activeCloudId = nil,
		selectedCloudId = nil,
		localSync = {}
	}
	if not isfile or not isfile(STATE_PATH) then return state end
	local ok, decoded = pcall(function()
		return httpService:JSONDecode(readfile(STATE_PATH))
	end)
	if not ok or type(decoded) ~= 'table' then return state end
	if decoded.mode == 'Cloud' then state.mode = 'Cloud' end
	state.autoSave = decoded.autoSave == true
	state.activeCloudId = type(decoded.activeCloudId) == 'string' and decoded.activeCloudId or nil
	state.selectedCloudId = type(decoded.selectedCloudId) == 'string' and decoded.selectedCloudId or nil
	state.localSync = type(decoded.localSync) == 'table' and decoded.localSync or {}
	return state
end

local state = loadState()
local isPremium = shared.AetherV2PremiumAuthorized == true
	and type(shared.AetherV2PremiumToken) == 'string'
	and shared.AetherV2PremiumToken ~= ''
if not isPremium then
	state.mode = 'Local'
	state.activeCloudId = nil
	state.selectedCloudId = nil
end

local function saveState()
	ensureStateFolder()
	pcall(writefile, STATE_PATH, httpService:JSONEncode(state))
end

local function urlEncode(value)
	local ok, encoded = pcall(httpService.UrlEncode, httpService, tostring(value))
	if ok then return encoded end
	return tostring(value):gsub('([^%w%-%._~])', function(character)
		return string.format('%%%02X', string.byte(character))
	end)
end

local function decodeResponse(body)
	if type(body) ~= 'string' or body == '' then return nil end
	local ok, decoded = pcall(httpService.JSONDecode, httpService, body)
	return ok and decoded or nil
end

local function cloudRequest(method, path, body, premiumRequired)
	method = string.upper(method or 'GET')
	if premiumRequired then
		if not isPremium then return nil, 'AetherV2 Premium is required for Cloud Config management' end
		local separator = path:find('?', 1, true) and '&' or '?'
		path = path..separator..'session='..urlEncode(shared.AetherV2PremiumToken)
	end
	local url = endpoint()..path
	local responseBody, status
	if type(requestFunction) == 'function' then
		local requestData = {
			Url = url,
			Method = method,
			Headers = {['Content-Type'] = 'application/json'}
		}
		if body ~= nil then requestData.Body = httpService:JSONEncode(body) end
		local ok, response = pcall(requestFunction, requestData)
		if not ok then return nil, tostring(response) end
		if type(response) ~= 'table' then return nil, 'Executor returned an invalid HTTP response' end
		status = tonumber(response.StatusCode or response.Status or response.status_code or 0) or 0
		responseBody = response.Body or response.body or ''
	else
		if method ~= 'GET' then return nil, 'This executor does not expose HTTP request support for Cloud Config writes' end
		local ok, value = pcall(game.HttpGet, game, url, true)
		if not ok then return nil, tostring(value) end
		status = 200
		responseBody = value
	end
	local decoded = decodeResponse(responseBody)
	if status < 200 or status >= 300 then
		return nil, type(decoded) == 'table' and decoded.error or ('Cloud request failed (HTTP '..tostring(status)..')'), status
	end
	if type(decoded) ~= 'table' then return nil, 'Cloud backend returned invalid JSON', status end
	if decoded.success == false then return nil, decoded.error or 'Cloud request failed', status end
	return decoded, nil, status
end

local originalSave = mainapi.Save
local originalUninject = mainapi.Uninject
local suppressDirty = false
local dirty = false
local lastObservedPayload
local lastChangedAt = 0
local lastUploadedAt = os.clock()
local activeCloudId = state.activeCloudId
local selectedCloudId = state.selectedCloudId
local cloudConfigs = {}
local cloudById = {}
local cloudRows = {}
local mode = isPremium and state.mode or 'Local'
local applyingSyncToggle = false
local applyingLocalSyncToggle = false
local applyMode
local refreshCloudRows
local refreshCloudControls
local refreshLocalSyncToggle

local function serializeCurrent(saveFirst)
	if saveFirst and type(originalSave) == 'function' then
		local ok, err = pcall(originalSave, mainapi)
		if not ok then return nil, tostring(err) end
	end
	local configPath = internals.ConfigPath(mainapi.Profile)
	if not isfile or not isfile(configPath) then return nil, 'Current config has not been saved locally yet' end
	local okConfig, configText = pcall(readfile, configPath)
	if not okConfig or type(configText) ~= 'string' or configText == '' then return nil, 'Current config file could not be read' end
	local wrapper = {config = configText}
	local guiPath = 'aetherv2/profiles/'..game.GameId..'.gui.txt'
	if isfile(guiPath) then
		local okGui, guiText = pcall(readfile, guiPath)
		if okGui and type(guiText) == 'string' and guiText ~= '' then wrapper.gui = guiText end
	end
	local ok, encoded = pcall(httpService.JSONEncode, httpService, wrapper)
	return ok and encoded or nil, ok and nil or tostring(encoded)
end

local function formatSaved(value)
	if type(value) ~= 'string' or value == '' then return 'Never' end
	local compact = value:gsub('T', ' '):gsub('%.%d+Z$', ' UTC'):gsub('Z$', ' UTC')
	return compact:sub(1, 23)
end

local function selectedConfig()
	return selectedCloudId and cloudById[selectedCloudId] or nil
end

local function syncKey(profile)
	return tostring(mainapi.Place)..':'..tostring(profile)
end

local function currentLocalSync()
	return state.localSync[syncKey(mainapi.Profile)]
end

local function uniqueLocalName(base)
	base = tostring(base or 'Shared Config'):gsub('^%s*(.-)%s*$', '%1')
	if base == '' then base = 'Shared Config' end
	local names = {}
	for _, profile in mainapi.Profiles or {} do
		if type(profile) == 'table' and type(profile.Name) == 'string' then names[profile.Name:lower()] = true end
	end
	if not names[base:lower()] then return base end
	for index = 2, 99 do
		local suffix = ' '..index
		local candidate = base:sub(1, math.max(1, 60 - #suffix))..suffix
		if not names[candidate:lower()] then return candidate end
	end
	return base..' Copy'
end

local function resolveShare(code)
	code = tostring(code or ''):gsub('%s+', ''):upper()
	if code == '' then return nil, 'Enter a share code first' end
	local response, err = cloudRequest('GET', '/cloud/share/'..urlEncode(code), nil, false)
	if not response then return nil, err end
	local config = response.config
	if type(config) ~= 'table' or type(config.payload) ~= 'string' then return nil, 'Share code returned an invalid config' end
	if tostring(config.placeId) ~= tostring(mainapi.Place) then
		return nil, 'This share code belongs to a different game/place'
	end
	return config, nil, code
end

local function importLocalShare(code, requestedName, syncEnabled)
	local config, err, normalized = resolveShare(code)
	if not config then return false, err end
	local wanted = requestedName and tostring(requestedName):gsub('^%s*(.-)%s*$', '%1') or ''
	local name = uniqueLocalName(wanted ~= '' and wanted or ((config.name or 'Shared Config')..' Copy'))
	suppressDirty = true
	local ok, importedName = internals.ImportJson(config.payload, name, false)
	suppressDirty = false
	if not ok then return false, importedName end
	if syncEnabled then
		state.localSync[syncKey(importedName)] = {
			profile = importedName,
			placeId = tostring(mainapi.Place),
			code = normalized,
			lastSaved = config.lastSaved,
			enabled = true
		}
	end
	saveState()
	if refreshLocalSyncToggle then refreshLocalSyncToggle() end
	return true, importedName
end

local function syncLocalRecord(key, record)
	if type(record) ~= 'table' or record.enabled ~= true or tostring(record.placeId) ~= tostring(mainapi.Place) then return end
	local config, err = resolveShare(record.code)
	if not config then
		record.enabled = false
		record.invalidated = true
		saveState()
		if mainapi.Profile == record.profile then notify('Sync to Copy stopped: '..tostring(err), true) end
		return
	end
	if config.lastSaved == record.lastSaved then return end
	suppressDirty = true
	local ok, result = internals.ImportJson(config.payload, record.profile, true)
	if ok and mainapi.Profile == record.profile then
		pcall(mainapi.Load, mainapi, true, record.profile)
		pcall(originalSave, mainapi, record.profile)
	end
	suppressDirty = false
	if ok then
		record.lastSaved = config.lastSaved
		record.invalidated = nil
		saveState()
		if mainapi.Profile == record.profile then notify('Synced '..record.profile..' from its share code') end
	else
		warn('[AetherV2/CloudConfigs] Local copy sync failed: '..tostring(result))
	end
end

local function fetchCloudConfig(id)
	local response, err = cloudRequest('GET', '/cloud/configs/'..urlEncode(id), nil, true)
	return response and response.config or nil, err
end

local function loadCloudConfig(id, quiet)
	local config, err = fetchCloudConfig(id)
	if not config then
		if not quiet then notify(err, true) end
		return false
	end
	suppressDirty = true
	local ok, result = internals.ImportJson(config.payload, SHADOW_PROFILE, false)
	suppressDirty = false
	if not ok then
		if not quiet then notify(result, true) end
		return false
	end
	activeCloudId = id
	selectedCloudId = id
	state.activeCloudId = id
	state.selectedCloudId = id
	state.mode = 'Cloud'
	mode = 'Cloud'
	dirty = false
	lastObservedPayload = serializeCurrent(false)
	lastChangedAt = os.clock()
	lastUploadedAt = os.clock()
	if type(config.lastSaved) == 'string' then
		local meta = cloudById[id]
		if meta then meta.lastSaved = config.lastSaved end
	end
	saveState()
	if applyMode then applyMode() end
	if refreshCloudControls then refreshCloudControls() end
	if refreshCloudRows then refreshCloudRows() end
	if not quiet then notify('Loaded cloud config '..tostring(config.name or '')) end
	return true
end

local function saveCloudConfig(id, quiet)
	if not isPremium then return false end
	local payload, payloadErr = serializeCurrent(true)
	if not payload then
		if not quiet then notify(payloadErr, true) end
		return false
	end
	local response, err = cloudRequest('PUT', '/cloud/configs/'..urlEncode(id), {
		payload = payload,
		placeId = tostring(mainapi.Place)
	}, true)
	if not response then
		if not quiet then notify(err, true) end
		return false
	end
	local config = response.config
	if type(config) == 'table' then
		cloudById[id] = config
		for index, item in cloudConfigs do if item.id == id then cloudConfigs[index] = config break end end
	end
	dirty = false
	lastObservedPayload = payload
	lastUploadedAt = os.clock()
	if refreshCloudControls then refreshCloudControls() end
	if not quiet then notify('Cloud config saved') end
	return true
end

local function flushAutosave(force)
	if not isPremium or not state.autoSave or not activeCloudId or mainapi.Profile ~= SHADOW_PROFILE then return false end
	local payload = serializeCurrent(force == true)
	if type(payload) == 'string' and payload ~= lastObservedPayload then
		lastObservedPayload = payload
		dirty = true
		lastChangedAt = os.clock()
	end
	if not dirty then return false end
	local now = os.clock()
	if not force and now - lastChangedAt < AUTOSAVE_IDLE and now - lastUploadedAt < PERIODIC_SAVE then return false end
	return saveCloudConfig(activeCloudId, true)
end

local localControlObjects = {}
for _, option in profiles.Options or {} do
	if type(option) == 'table' and typeof(option.Object) == 'Instance' then table.insert(localControlObjects, option.Object) end
end

local window = profiles.Object
local children = window and window:FindFirstChild('Children')
local localAdd = children and children:FindFirstChild('Add')
local repoButton = window and window:FindFirstChild('PresetDownload', true)
local headerTitle = window and window:FindFirstChild('Title')
local settingsButton = window and window:FindFirstChild('Settings')
local cloudControlObjects = {}
local sharedControlObjects = {}

local function remember(control, list)
	if type(control) == 'table' and typeof(control.Object) == 'Instance' then table.insert(list, control.Object) end
	return control
end

local modeButton
if isPremium and window and headerTitle then
	modeButton = Instance.new('TextButton')
	modeButton.Name = 'CloudMode'
	modeButton.Size = UDim2.fromOffset(44, 20)
	modeButton.Position = UDim2.new(1, -126, 0, 11)
	modeButton.BackgroundTransparency = 1
	modeButton.Text = mode:upper()
	modeButton.TextColor3 = headerTitle.TextColor3
	modeButton.TextSize = 10
	modeButton.FontFace = headerTitle.FontFace
	modeButton.Parent = window
end

local cloudAdd
local cloudAddText
if isPremium and localAdd then
	cloudAdd = localAdd:Clone()
	cloudAdd.Name = 'CloudAdd'
	cloudAdd.Visible = false
	cloudAdd.Parent = localAdd.Parent
	cloudAddText = cloudAdd:FindFirstChildWhichIsA('TextBox', true)
	if cloudAddText then
		cloudAddText.Text = ''
		cloudAddText.PlaceholderText = 'Cloud config name'
	end
end

local lastSavedButton
local saveNowButton
local renameBox
local renameButton
local deleteButton
local restoreButton
local shareStatusButton
local generateShareButton
local copyShareButton
local regenerateShareButton
local disableShareButton
local cloudSyncToggle
local autoSaveToggle

if isPremium then
	lastSavedButton = remember(profiles:CreateButton({
		Name = 'Last Saved: Never',
		Function = function() end,
		Tooltip = 'Last successful cloud save for the selected config'
	}), cloudControlObjects)
	saveNowButton = remember(profiles:CreateButton({
		Name = 'Cloud Save',
		Function = function()
			if not selectedCloudId then return notify('Select a cloud config first', true) end
			task.spawn(saveCloudConfig, selectedCloudId, false)
		end,
		Tooltip = 'Overwrite the selected cloud config with your current Aether config'
	}), cloudControlObjects)
	autoSaveToggle = remember(profiles:CreateToggle({
		Name = 'Auto Save',
		Default = state.autoSave,
		Function = function(enabled)
			state.autoSave = enabled == true
			saveState()
		end,
		Tooltip = 'Sync changed cloud configs after two idle minutes, every five minutes while dirty, and before self-destruct'
	}), cloudControlObjects)
	renameBox = remember(profiles:CreateTextBox({
		Name = 'Rename',
		Placeholder = 'New cloud config name'
	}), cloudControlObjects)
	renameButton = remember(profiles:CreateButton({
		Name = 'Rename Cloud Config',
		Function = function()
			if not selectedCloudId then return notify('Select a cloud config first', true) end
			local name = renameBox.Value and renameBox.Value:gsub('^%s*(.-)%s*$', '%1') or ''
			if name == '' then return notify('Enter a new name first', true) end
			task.spawn(function()
				local response, err = cloudRequest('PATCH', '/cloud/configs/'..urlEncode(selectedCloudId), {action = 'rename', name = name}, true)
				if not response then return notify(err, true) end
				renameBox:SetValue('', false)
				notify('Cloud config renamed')
				if refreshCloudRows then refreshCloudRows(true) end
			end)
		end
	}), cloudControlObjects)
	deleteButton = remember(profiles:CreateButton({
		Name = 'Delete Cloud Config',
		Function = function()
			if not selectedCloudId then return notify('Select a cloud config first', true) end
			local deleting = selectedCloudId
			task.spawn(function()
				local response, err = cloudRequest('DELETE', '/cloud/configs/'..urlEncode(deleting), nil, true)
				if not response then return notify(err, true) end
				if activeCloudId == deleting then
					activeCloudId = nil
					state.activeCloudId = nil
					dirty = false
				end
				selectedCloudId = nil
				state.selectedCloudId = nil
				saveState()
				notify('Cloud config deleted')
				if refreshCloudRows then refreshCloudRows(true) end
			end)
		end
	}), cloudControlObjects)
	restoreButton = remember(profiles:CreateButton({
		Name = 'Restore Previous Cloud Version',
		Function = function()
			if not selectedCloudId then return notify('Select a cloud config first', true) end
			local restoring = selectedCloudId
			task.spawn(function()
				local response, err = cloudRequest('PATCH', '/cloud/configs/'..urlEncode(restoring), {action = 'restore-backup'}, true)
				if not response then return notify(err, true) end
				notify('Previous cloud version restored')
				loadCloudConfig(restoring, true)
				if refreshCloudRows then refreshCloudRows(true) end
			end)
		end
	}), cloudControlObjects)
	shareStatusButton = remember(profiles:CreateButton({Name = 'Share Code: Disabled', Function = function() end}), cloudControlObjects)
	generateShareButton = remember(profiles:CreateButton({
		Name = 'Generate Share Code',
		Function = function()
			if not selectedCloudId then return notify('Select a cloud config first', true) end
			task.spawn(function()
				local response, err = cloudRequest('PATCH', '/cloud/configs/'..urlEncode(selectedCloudId), {action = 'sharing', mode = 'generate'}, true)
				if not response then return notify(err, true) end
				cloudById[selectedCloudId] = response.config
				refreshCloudControls()
				notify('Share code generated: '..tostring(response.config.shareCode))
			end)
		end
	}), cloudControlObjects)
	copyShareButton = remember(profiles:CreateButton({
		Name = 'Copy Share Code',
		Function = function()
			local config = selectedConfig()
			if not config or not config.shareCode then return notify('Generate a share code first', true) end
			local copy = setclipboard or toclipboard
			if type(copy) ~= 'function' then return notify('Clipboard access is unavailable', true) end
			local ok = pcall(copy, config.shareCode)
			if ok then notify('Copied '..config.shareCode) else notify('Could not copy the share code', true) end
		end
	}), cloudControlObjects)
	regenerateShareButton = remember(profiles:CreateButton({
		Name = 'Regenerate Share Code',
		Function = function()
			if not selectedCloudId then return notify('Select a cloud config first', true) end
			task.spawn(function()
				local response, err = cloudRequest('PATCH', '/cloud/configs/'..urlEncode(selectedCloudId), {action = 'sharing', mode = 'regenerate'}, true)
				if not response then return notify(err, true) end
				cloudById[selectedCloudId] = response.config
				refreshCloudControls()
				notify('Share code regenerated; the previous code is invalid')
			end)
		end
	}), cloudControlObjects)
	disableShareButton = remember(profiles:CreateButton({
		Name = 'Disable Sharing',
		Function = function()
			if not selectedCloudId then return notify('Select a cloud config first', true) end
			task.spawn(function()
				local response, err = cloudRequest('PATCH', '/cloud/configs/'..urlEncode(selectedCloudId), {action = 'sharing', mode = 'disable'}, true)
				if not response then return notify(err, true) end
				cloudById[selectedCloudId] = response.config
				refreshCloudControls()
				notify('Sharing disabled; the old code is invalid')
			end)
		end
	}), cloudControlObjects)
	cloudSyncToggle = remember(profiles:CreateToggle({
		Name = 'Sync to Copy',
		Function = function(enabled)
			if applyingSyncToggle then return end
			local config = selectedConfig()
			if not config or not config.isCopy then return end
			task.spawn(function()
				local response, err = cloudRequest('PATCH', '/cloud/configs/'..urlEncode(config.id), {action = 'sync', enabled = enabled == true}, true)
				if not response then
					notify(err, true)
					return refreshCloudControls()
				end
				cloudById[config.id] = response.config
				refreshCloudControls()
			end)
		end,
		Tooltip = 'Keep this imported cloud copy updated from the original. Your changes never write back to its owner'
	}), cloudControlObjects)
end

local importCodeBox = remember(profiles:CreateTextBox({
	Name = 'Import Share Code',
	Placeholder = 'JE97-2H96'
}), sharedControlObjects)
local importNameBox = remember(profiles:CreateTextBox({
	Name = 'Imported Name',
	Placeholder = 'Optional copy name'
}), sharedControlObjects)
local importSyncToggle = remember(profiles:CreateToggle({
	Name = 'Sync Imported Copy',
	Default = false,
	Tooltip = 'Keep the imported copy updated from the original until its share code is disabled or regenerated'
}), sharedControlObjects)
local importButton = remember(profiles:CreateButton({
	Name = 'Import Share Code',
	Function = function()
		local code = importCodeBox.Value
		local name = importNameBox.Value
		local sync = importSyncToggle.Enabled == true
		task.spawn(function()
			local source, sourceErr, normalized = resolveShare(code)
			if not source then return notify(sourceErr, true) end
			if isPremium and mode == 'Cloud' then
				local response, err = cloudRequest('POST', '/cloud/import', {
					code = normalized,
					name = name ~= '' and name or nil,
					sync = sync
				}, true)
				if not response then return notify(err, true) end
				selectedCloudId = response.config.id
				state.selectedCloudId = selectedCloudId
				saveState()
				importCodeBox:SetValue('', false)
				importNameBox:SetValue('', false)
				notify('Imported independent cloud copy')
				if refreshCloudRows then refreshCloudRows(true) end
			else
				local ok, result = importLocalShare(normalized, name, sync)
				if not ok then return notify(result, true) end
				importCodeBox:SetValue('', false)
				importNameBox:SetValue('', false)
				notify('Imported '..result..' into Local configs')
			end
		end)
	end,
	Tooltip = 'Free users import to Local. Premium users import to whichever Local/Cloud mode is selected'
}), sharedControlObjects)

local localSyncToggle = remember(profiles:CreateToggle({
	Name = 'Sync to Copy',
	Function = function(enabled)
		if applyingLocalSyncToggle or mode ~= 'Local' then return end
		local record = currentLocalSync()
		if not record then return end
		record.enabled = enabled == true
		record.invalidated = nil
		saveState()
		if enabled then task.spawn(syncLocalRecord, syncKey(mainapi.Profile), record) end
	end,
	Tooltip = 'Enable or stop syncing the current local config to the share code it was imported from'
}), sharedControlObjects)

local function setButtonText(control, text)
	if not control or typeof(control.Object) ~= 'Instance' then return end
	if control.Object:IsA('TextButton') then
		control.Object.Text = tostring(text)
		return
	end
	local title = control.Object:FindFirstChild('Title', true)
	if title and title:IsA('TextLabel') then title.Text = tostring(text) end
end

refreshLocalSyncToggle = function()
	if not localSyncToggle or typeof(localSyncToggle.Object) ~= 'Instance' then return end
	local record = mode == 'Local' and currentLocalSync() or nil
	localSyncToggle.Object.Visible = record ~= nil
	if record then
		local wanted = record.enabled == true
		if localSyncToggle.Enabled ~= wanted then
			applyingLocalSyncToggle = true
			localSyncToggle:Toggle()
			applyingLocalSyncToggle = false
		end
	end
end

refreshCloudControls = function()
	if not isPremium then return end
	local config = selectedConfig()
	setButtonText(lastSavedButton, 'Last Saved: '..formatSaved(config and config.lastSaved))
	setButtonText(shareStatusButton, 'Share Code: '..(config and config.shareCode or 'Disabled'))
	if restoreButton and restoreButton.Object then restoreButton.Object.Visible = mode == 'Cloud' and config ~= nil and config.hasBackup == true end
	if generateShareButton and generateShareButton.Object then generateShareButton.Object.Visible = mode == 'Cloud' and config ~= nil and not config.shareCode end
	if copyShareButton and copyShareButton.Object then copyShareButton.Object.Visible = mode == 'Cloud' and config ~= nil and config.shareCode ~= nil end
	if regenerateShareButton and regenerateShareButton.Object then regenerateShareButton.Object.Visible = mode == 'Cloud' and config ~= nil and config.shareCode ~= nil end
	if disableShareButton and disableShareButton.Object then disableShareButton.Object.Visible = mode == 'Cloud' and config ~= nil and config.shareCode ~= nil end
	if cloudSyncToggle and cloudSyncToggle.Object then
		cloudSyncToggle.Object.Visible = mode == 'Cloud' and config ~= nil and config.isCopy == true
		if config and config.isCopy then
			local wanted = config.syncEnabled == true
			if cloudSyncToggle.Enabled ~= wanted then
				applyingSyncToggle = true
				cloudSyncToggle:Toggle()
				applyingSyncToggle = false
			end
		end
	end
end

local function findLocalTemplate()
	for _, object in profiles.Objects or {} do
		if typeof(object) == 'Instance' and object.Name ~= SHADOW_PROFILE then return object end
	end
	return nil
end

local function clearCloudRows()
	for _, row in cloudRows do if row and row.Parent then row:Destroy() end end
	table.clear(cloudRows)
end

local function rebuildCloudRows()
	clearCloudRows()
	if not isPremium or mode ~= 'Cloud' or not children then return end
	local template = findLocalTemplate()
	if not template then return end
	for _, config in cloudConfigs do
		local row = template:Clone()
		row.Name = 'Cloud_'..config.id
		row.Visible = true
		local dots = row:FindFirstChild('Dots')
		if dots then dots:Destroy() end
		local bind = row:FindFirstChild('Bind')
		if bind then bind:Destroy() end
		local cover = row:FindFirstChild('Cover')
		if cover then cover:Destroy() end
		local title = row:FindFirstChild('Title')
		if title and title:IsA('TextLabel') then
			title.Text = config.name
			if config.id == activeCloudId then title.TextColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) end
		end
		local stroke = row:FindFirstChildOfClass('UIStroke')
		if stroke then stroke.Enabled = config.id == activeCloudId end
		row.Parent = children
		row.MouseEnter:Connect(function() if stroke then stroke.Enabled = true end end)
		row.MouseLeave:Connect(function() if stroke then stroke.Enabled = config.id == activeCloudId end end)
		row.MouseButton1Click:Connect(function()
			selectedCloudId = config.id
			state.selectedCloudId = config.id
			saveState()
			refreshCloudControls()
			task.spawn(loadCloudConfig, config.id, false)
		end)
		table.insert(cloudRows, row)
	end
end

local function fetchCloudList()
	if not isPremium then return false end
	local response, err = cloudRequest('GET', '/cloud/configs?placeId='..urlEncode(mainapi.Place), nil, true)
	if not response then
		notify(err, true)
		return false
	end
	cloudConfigs = type(response.configs) == 'table' and response.configs or {}
	cloudById = {}
	for _, config in cloudConfigs do cloudById[config.id] = config end
	if selectedCloudId and not cloudById[selectedCloudId] then selectedCloudId = nil end
	if not selectedCloudId and cloudConfigs[1] then selectedCloudId = cloudConfigs[1].id end
	state.selectedCloudId = selectedCloudId
	if activeCloudId and not cloudById[activeCloudId] then
		activeCloudId = nil
		state.activeCloudId = nil
		dirty = false
	end
	saveState()
	rebuildCloudRows()
	refreshCloudControls()
	return true
end

refreshCloudRows = function(fetchFirst)
	if fetchFirst then return task.spawn(fetchCloudList) end
	rebuildCloudRows()
end

local cloudAddButton = cloudAdd and cloudAdd:FindFirstChild('AddButton', true)
local function createCloudFromCurrent()
	if not isPremium then return end
	local name = cloudAddText and cloudAddText.Text:gsub('^%s*(.-)%s*$', '%1') or ''
	if name == '' then return notify('Enter a cloud config name first', true) end
	local payload, payloadErr = serializeCurrent(true)
	if not payload then return notify(payloadErr, true) end
	local response, err = cloudRequest('POST', '/cloud/configs', {
		name = name,
		placeId = tostring(mainapi.Place),
		payload = payload
	}, true)
	if not response then return notify(err, true) end
	if cloudAddText then cloudAddText.Text = '' end
	selectedCloudId = response.config.id
	state.selectedCloudId = selectedCloudId
	saveState()
	notify('Cloud config created')
	fetchCloudList()
end
if cloudAddButton then cloudAddButton.MouseButton1Click:Connect(function() task.spawn(createCloudFromCurrent) end) end
if cloudAddText then cloudAddText.FocusLost:Connect(function(enter) if enter then task.spawn(createCloudFromCurrent) end end) end

local originalProfileChangeValue = profiles.ChangeValue
profiles.ChangeValue = function(self, ...)
	local results = table.pack(originalProfileChangeValue(self, ...))
	task.defer(function()
		if applyMode then applyMode() end
		if refreshLocalSyncToggle then refreshLocalSyncToggle() end
		if mode == 'Cloud' then rebuildCloudRows() end
	end)
	return table.unpack(results, 1, results.n)
end

applyMode = function()
	if not isPremium then mode = 'Local' end
	state.mode = mode
	if headerTitle then headerTitle.Text = mode == 'Cloud' and 'Cloud Configs' or 'Configs' end
	if modeButton then modeButton.Text = mode:upper() end
	for _, object in localControlObjects do if object.Parent then object.Visible = mode == 'Local' end end
	for _, object in cloudControlObjects do if object.Parent then object.Visible = mode == 'Cloud' end end
	for _, object in sharedControlObjects do if object.Parent then object.Visible = true end end
	for _, object in profiles.Objects or {} do
		if typeof(object) == 'Instance' then object.Visible = mode == 'Local' and object.Name ~= SHADOW_PROFILE end
	end
	if localAdd then localAdd.Visible = mode == 'Local' end
	if repoButton then repoButton.Visible = mode == 'Local' end
	if cloudAdd then cloudAdd.Visible = mode == 'Cloud' end
	if mode == 'Cloud' then
		rebuildCloudRows()
	else
		clearCloudRows()
	end
	refreshCloudControls()
	refreshLocalSyncToggle()
	saveState()
end

if modeButton then
	modeButton.MouseButton1Click:Connect(function()
		mode = mode == 'Local' and 'Cloud' or 'Local'
		applyMode()
		if mode == 'Cloud' then task.spawn(fetchCloudList) end
	end)
end

mainapi.Save = function(self, ...)
	local results = table.pack(originalSave(self, ...))
	if not suppressDirty and isPremium and state.autoSave and activeCloudId and self.Profile == SHADOW_PROFILE then
		local payload = serializeCurrent(false)
		if type(payload) == 'string' and payload ~= lastObservedPayload then
			lastObservedPayload = payload
			dirty = true
			lastChangedAt = os.clock()
		end
	end
	return table.unpack(results, 1, results.n)
end

if type(originalUninject) == 'function' then
	mainapi.Uninject = function(self, ...)
		pcall(flushAutosave, true)
		return originalUninject(self, ...)
	end
end

if mainapi.Profile == SHADOW_PROFILE and activeCloudId then
	lastObservedPayload = serializeCurrent(false)
else
	activeCloudId = nil
	state.activeCloudId = nil
end

applyMode()
if isPremium and mode == 'Cloud' then task.spawn(fetchCloudList) end

-- Low-frequency maintenance only. No network request is made unless something is
-- dirty or a copied config is due for its five-minute sync check.
task.spawn(function()
	local lastLocalSync = 0
	while mainapi do
		task.wait(5)
		pcall(flushAutosave, false)
		local now = os.clock()
		if now - lastLocalSync >= LOCAL_SYNC_INTERVAL then
			lastLocalSync = now
			for key, record in state.localSync do
				if type(record) == 'table' and record.enabled == true and tostring(record.placeId) == tostring(mainapi.Place) then
					task.spawn(syncLocalRecord, key, record)
				end
			end
		end
	end
end)

saveState()
