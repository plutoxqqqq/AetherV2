from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str, label: str) -> bool:
    file = ROOT / path
    text = file.read_text(encoding='utf-8')
    if new in text:
        return False
    if old not in text:
        raise SystemExit(f'{path}: expected marker not found for {label}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')
    return True


def replace_region(path: str, start: str, end: str, replacement: str, label: str) -> bool:
    file = ROOT / path
    text = file.read_text(encoding='utf-8')
    if replacement in text:
        return False
    first = text.find(start)
    if first < 0:
        raise SystemExit(f'{path}: start marker not found for {label}')
    last = text.find(end, first)
    if last < 0:
        raise SystemExit(f'{path}: end marker not found for {label}')
    file.write_text(text[:first] + replacement + text[last:], encoding='utf-8')
    return True


# Hide the legacy GUI siblings so the old search/module surface cannot remain visible behind
# Liquid Glass or steal input. The controller stays alive because its APIs are still required.
legacy_block = '''\n-- Liquid Glass owns the visible Aether interface. Keep the legacy controller alive, but hide\n-- every pre-existing GuiObject sibling so the classic search/module UI cannot bleed through or\n-- sit above the new shell. The Liquid Glass root is intentionally excluded.\nlocal legacySweepInstalled = false\nlocal function hideLegacyVisuals()\n    if legacySweepInstalled then return end\n    legacySweepInstalled = true\n    local function hide(object)\n        if typeof(object) ~= 'Instance' or not object:IsA('GuiObject') or object:IsDescendantOf(root) then return end\n        object.Visible = false\n        if not hiddenLegacy[object] then\n            hiddenLegacy[object] = true\n            connect(object:GetPropertyChangedSignal('Visible'), function()\n                if object.Parent and object.Visible and not object:IsDescendantOf(root) then object.Visible = false end\n            end)\n        end\n    end\n    for _, child in ipairs(guiParent:GetChildren()) do\n        if child ~= root then\n            if child:IsA('GuiObject') then\n                hide(child)\n            elseif child:IsA('ScreenGui') or child:IsA('Folder') then\n                for _, descendant in ipairs(child:GetDescendants()) do hide(descendant) end\n            end\n        end\n    end\nend\n\ntask.defer(hideLegacyVisuals)\n'''
replace_once(
    'guis/liquidglass/02-shell.lua',
    "}, guiParent)\n\nlocal scrim = create('TextButton', {",
    "}, guiParent)" + legacy_block + "\nlocal scrim = create('TextButton', {",
    'legacy GUI sweep',
)

# Resolve the module's actual owning category from the category registries, not from whatever
# fallback category happened to be attached by the search collector.
module_helpers = '''local function normalizedModuleKey(value)\n    return tostring(value or ''):lower():gsub('[%s_%-%./]+', '')\nend\n\nlocal function resolveModuleCategory(module)\n    if not module then return 'Other' end\n    local wanted = normalizedModuleKey(module.Name)\n    for rawName, api in pairs(mainapi.Categories or {}) do\n        if type(api) == 'table' and type(api.Modules) == 'table' then\n            for key, candidate in pairs(api.Modules) do\n                if candidate == module then\n                    return tostring(rawName) == 'Main' and 'Aether' or tostring(rawName)\n                end\n                if type(candidate) == 'table' and wanted ~= '' and normalizedModuleKey(candidate.Name or key) == wanted then\n                    return tostring(rawName) == 'Main' and 'Aether' or tostring(rawName)\n                end\n                if type(candidate) ~= 'table' and wanted ~= '' and normalizedModuleKey(key) == wanted then\n                    return tostring(rawName) == 'Main' and 'Aether' or tostring(rawName)\n                end\n            end\n        end\n    end\n    return tostring(module.LiquidCategory or module.Category or 'Other')\nend\n\nlocal function syncModuleCategory(module)\n    local category = resolveModuleCategory(module)\n    if module and category ~= '' then module.LiquidCategory = category end\n    return category\nend\n\n'''
replace_once(
    'guis/liquidglass/05-inspector.lua',
    'local function moduleCard(parent,module,order)\n',
    module_helpers + 'local function moduleCard(parent,module,order)\n',
    'module category resolver',
)

module_card = '''local function moduleCard(parent,module,order)\n    local height=liquidSettings.CompactCards and 78 or 96\n    local card,stroke=cardSurface(parent,height,order)\n    card.Name='Module_'..tostring(module.Name or order)\n    card.Active=true\n    card.ClipsDescendants=true\n    syncModuleCategory(module)\n\n    local hit=textButton(card,'')\n    hit.Size=UDim2.new(1,-64,1,0)\n    hit.Position=UDim2.fromOffset(0,0)\n    hit.ZIndex=123\n    hit.Active=true\n    hit.Selectable=false\n\n    local name=label(card,moduleDisplayName(module),13,true)\n    name.Size=UDim2.new(1,-76,0,24); name.Position=UDim2.fromOffset(14,10); name.ZIndex=124\n    local cat=label(card,tostring(module.LiquidCategory or module.Category or ''),9,false,COLORS.Tertiary)\n    cat.Size=UDim2.new(1,-78,0,16); cat.Position=UDim2.fromOffset(14,33); cat.ZIndex=124\n    local desc=label(card,tostring(module.Tooltip or ''),9,false,COLORS.Secondary)\n    desc.Size=UDim2.new(1,-28,0,32); desc.Position=UDim2.fromOffset(14,55)\n    desc.TextWrapped=true; desc.TextYAlignment=Enum.TextYAlignment.Top; desc.ZIndex=124\n    desc.Visible=not liquidSettings.CompactCards\n\n    local switch,refreshSwitch=makeSwitch(card,function() return module.Enabled==true end,function(value)\n        if module.Enabled~=value and type(module.Toggle)=='function' then pcall(module.Toggle,module); remember(module) end\n    end)\n    switch.AnchorPoint=Vector2.new(1,0); switch.Position=UDim2.new(1,-12,0,12); switch.ZIndex=126\n\n    local opening=false\n    local function openModule()\n        if opening then return end\n        opening=true\n        task.defer(function() opening=false end)\n        buildInspector(module)\n    end\n\n    local function openOwningCategory()\n        local category=syncModuleCategory(module)\n        state.SelectedModule=nil\n        state.Page='Category'\n        state.Category=category\n        filterBox.Text=''\n        if state.RenderPage then state.RenderPage() end\n    end\n\n    connect(hit.MouseButton1Click,openModule)\n    connect(hit.MouseButton2Click,openOwningCategory)\n    connect(hit.InputBegan,function(input)\n        if input.UserInputType==Enum.UserInputType.MouseButton1 then\n            openModule()\n        elseif input.UserInputType==Enum.UserInputType.MouseButton2 then\n            openOwningCategory()\n        end\n    end)\n\n    connect(hit.MouseEnter,function()\n        tween(card,0.14,{BackgroundTransparency=0.38})\n        stroke.Transparency=0.82\n    end)\n    connect(hit.MouseLeave,function()\n        tween(card,0.14,{BackgroundTransparency=module.Enabled and 0.32 or 0.5})\n        stroke.Transparency=module.Enabled and 0.55 or 0.91\n    end)\n\n    local function refresh()\n        syncModuleCategory(module)\n        refreshSwitch()\n        card.BackgroundColor3=module.Enabled and Color3.fromRGB(31,28,43) or COLORS.Surface2\n        card.BackgroundTransparency=module.Enabled and 0.32 or 0.5\n        stroke.Color=module.Enabled and accent() or COLORS.White\n        stroke.Transparency=module.Enabled and 0.55 or 0.91\n        cat.Text=tostring(module.LiquidCategory or module.Category or '')\n    end\n    state.ModuleCards[module]={Card=card,Refresh=refresh}\n    refresh()\n    return card\nend\n\n'''
replace_region(
    'guis/liquidglass/05-inspector.lua',
    'local function moduleCard(parent,module,order)',
    'local function sectionHeading(parent,text,order)',
    module_card,
    'module card interaction implementation',
)

# Stop rebuilding the page on every keystroke/focus loss. Debounce filtering so the TextBox keeps
# ownership of the caret and focus while results refresh.
liquid = ROOT / 'guis/liquidglass.lua'
source = liquid.read_text(encoding='utf-8')
start = source.find('local filterGuard=false\n')
end = source.find('filterBox.TextEditable=true', start)
if start >= 0 and end >= 0:
    end += len('filterBox.TextEditable=true')
    search_block = '''local filterRevision=0\nlocal function rerenderFilteredPage()\n    if state.Page~='Category' and state.Page~='Search' and state.Page~='Actions' then return end\n    filterRevision+=1\n    local revision=filterRevision\n    task.delay(0.12,function()\n        if revision~=filterRevision or not root.Parent then return end\n        local scroll=page.CanvasPosition\n        renderPage()\n        if page.Parent then page.CanvasPosition=scroll end\n    end)\nend\nconnect(filterBox:GetPropertyChangedSignal('Text'),rerenderFilteredPage)\nconnect(filterBox.FocusLost,function()\n    -- Focus changes do not rebuild the results or mutate the search TextBox.\nend)\nfilterBox.Active=true\nfilterBox.TextEditable=true'''
    source = source[:start] + search_block + source[end:]
    liquid.write_text(source, encoding='utf-8')

print('Liquid Glass interaction repair complete')
''