from __future__ import annotations

from pathlib import Path
import re

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
    text = text[:first] + replacement + text[last:]
    file.write_text(text, encoding='utf-8')
    return True


# 1. Hide the legacy GUI surfaces after Liquid Glass creates its own root. The screenshot shows
# the old module/search surface bleeding through the new frontend; hiding only category Objects
# misses standalone search/spotlight containers and leaves their coloured strokes on screen.
legacy_block = '''\n-- Liquid Glass is the sole visible Aether interface. Keep the legacy controller alive for its\n-- APIs, but hide every pre-existing GuiObject sibling so old search/module surfaces cannot bleed\n-- through the new shell or steal mouse input. The new root itself is deliberately excluded.\nlocal legacySweepInstalled = false\nlocal function hideLegacyVisuals()\n    if legacySweepInstalled then return end\n    legacySweepInstalled = true\n    local function hide(object)\n        if typeof(object) ~= 'Instance' or not object:IsA('GuiObject') then return end\n        if object:IsDescendantOf(root) then return end\n        object.Visible = false\n        if not hiddenLegacy[object] then\n            hiddenLegacy[object] = true\n            connect(object:GetPropertyChangedSignal('Visible'), function()\n                if object.Parent and object.Visible and not object:IsDescendantOf(root) then\n                    object.Visible = false\n                end\n            end)\n        end\n    end\n    for _, child in ipairs(guiParent:GetChildren()) do\n        if child ~= root then\n            if child:IsA('GuiObject') then\n                hide(child)\n            elseif child:IsA('ScreenGui') or child:IsA('Folder') then\n                for _, descendant in ipairs(child:GetDescendants()) do\n                    hide(descendant)\n                end\n            end\n        end\n    end\nend\n\ntask.defer(hideLegacyVisuals)\n'''
replace_once(
    'guis/liquidglass/02-shell.lua',
    "}, guiParent)\n\nlocal scrim = create('TextButton', {",
    "}, guiParent)" + legacy_block + "\nlocal scrim = create('TextButton', {",
    'legacy GUI sweep',
)

# 2. Make module lookup authoritative. A search result must resolve back to the category that
# actually owns the module, even when module.Category is absent or a premium module was loaded late.
module_helpers = '''local function normalizedModuleKey(value)\n    return tostring(value or ''):lower():gsub('[%s_%-%./]+', '')\nend\n\nlocal function resolveModuleCategory(module)\n    if not module then return 'Other' end\n    local wanted = normalizedModuleKey(module.Name)\n    for rawName, api in pairs(mainapi.Categories or {}) do\n        if type(api) == 'table' and type(api.Modules) == 'table' then\n            for key, candidate in pairs(api.Modules) do\n                if candidate == module then\n                    return tostring(rawName) == 'Main' and 'Aether' or tostring(rawName)\n                end\n                if type(candidate) == 'table' then\n                    local candidateKey = normalizedModuleKey(candidate.Name or key)\n                    if wanted ~= '' and candidateKey == wanted then\n                        return tostring(rawName) == 'Main' and 'Aether' or tostring(rawName)\n                    end\n                elseif wanted ~= '' and normalizedModuleKey(key) == wanted then\n                    return tostring(rawName) == 'Main' and 'Aether' or tostring(rawName)\n                end\n            end\n        end\n    end\n    return tostring(module.LiquidCategory or module.Category or 'Other')\nend\n\nlocal function syncModuleCategory(module)\n    if module then\n        local category = resolveModuleCategory(module)\n        if category ~= '' then module.LiquidCategory = category end\n        return category\n    end\n    return 'Other'\nend\n\n'''
replace_once(
    'guis/liquidglass/05-inspector.lua',
    "local function moduleCard(parent,module,order)\n",
    module_helpers + "local function moduleCard(parent,module,order)\n",
    'module category resolver',
)

module_card = r'''local function moduleCard(parent,module,order)
    local height=liquidSettings.CompactCards and 78 or 96
    local card,stroke=cardSurface(parent,height,order)
    card.Name='Module_'..tostring(module.Name or order)
    card.Active=true
    card.ClipsDescendants=true
    syncModuleCategory(module)

    local hit=textButton(card,'')
    hit.Size=UDim2.new(1,-64,1,0)
    hit.Position=UDim2.fromOffset(0,0)
    hit.ZIndex=123
    hit.Active=true
    hit.Selectable=false

    local name=label(card,moduleDisplayName(module),13,true)
    name.Size=UDim2.new(1,-76,0,24); name.Position=UDim2.fromOffset(14,10); name.ZIndex=124
    local cat=label(card,tostring(module.LiquidCategory or module.Category or ''),9,false,COLORS.Tertiary)
    cat.Size=UDim2.new(1,-78,0,16); cat.Position=UDim2.fromOffset(14,33); cat.ZIndex=124
    local desc=label(card,tostring(module.Tooltip or ''),9,false,COLORS.Secondary)
    desc.Size=UDim2.new(1,-28,0,32); desc.Position=UDim2.fromOffset(14,55)
    desc.TextWrapped=true; desc.TextYAlignment=Enum.TextYAlignment.Top; desc.ZIndex=124
    desc.Visible=not liquidSettings.CompactCards

    local switch,refreshSwitch=makeSwitch(card,function() return module.Enabled==true end,function(value)
        if module.Enabled~=value and type(module.Toggle)=='function' then
            pcall(module.Toggle,module)
            remember(module)
        end
    end)
    switch.AnchorPoint=Vector2.new(1,0); switch.Position=UDim2.new(1,-12,0,12); switch.ZIndex=126

    local opening=false
    local function openModule()
        if opening then return end
        opening=true
        task.defer(function() opening=false end)
        buildInspector(module)
    end

    local function openOwningCategory()
        local category=syncModuleCategory(module)
        state.SelectedModule=nil
        state.Page='Category'
        state.Category=category
        filterBox.Text=''
        if state.RenderPage then state.RenderPage() end
    end

    connect(hit.MouseButton1Click,openModule)
    connect(hit.MouseButton2Click,openOwningCategory)
    connect(hit.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            openModule()
        elseif input.UserInputType==Enum.UserInputType.MouseButton2 then
            openOwningCategory()
        end
    end)
    connect(card.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 and input.Position.X < card.AbsolutePosition.X + card.AbsoluteSize.X - 68 then
            openModule()
        elseif input.UserInputType==Enum.UserInputType.MouseButton2 then
            openOwningCategory()
        end
    end)

    connect(hit.MouseEnter,function()
        tween(card,0.14,{BackgroundTransparency=0.38})
        stroke.Transparency=0.82
    end)
    connect(hit.MouseLeave,function()
        tween(card,0.14,{BackgroundTransparency=module.Enabled and 0.32 or 0.5})
        stroke.Transparency=module.Enabled and 0.55 or 0.91
    end)

    local function refresh()
        syncModuleCategory(module)
        refreshSwitch()
        card.BackgroundColor3=module.Enabled and Color3.fromRGB(31,28,43) or COLORS.Surface2
        card.BackgroundTransparency=module.Enabled and 0.32 or 0.5
        stroke.Color=module.Enabled and accent() or COLORS.White
        stroke.Transparency=module.Enabled and 0.55 or 0.91
        cat.Text=tostring(module.LiquidCategory or module.Category or '')
    end
    state.ModuleCards[module]={Card=card,Refresh=refresh}
    refresh()
    return card
end

'''
replace_region(
    'guis/liquidglass/05-inspector.lua',
    'local function moduleCard(parent,module,order)',
    'local function sectionHeading(parent,text,order)',
    module_card,
    'module card interaction implementation',
)

# 3. Debounce search filtering instead of re-rendering the page on every text event. Rebuilding
# the page while the TextBox is focused was the source of the focus/caret/searchbar instability.
liquid = ROOT / 'guis/liquidglass.lua'
source = liquid.read_text(encoding='utf-8')
search_start = source.find("local filterGuard=false\n")
search_end = source.find("filterBox.TextEditable=true", search_start)
if search_start >= 0 and search_end >= 0:
    search_end += len("filterBox.TextEditable=true")
    new_search = '''local filterRevision=0\nlocal function rerenderFilteredPage()\n    if state.Page~='Category' and state.Page~='Search' and state.Page~='Actions' then return end\n    filterRevision+=1\n    local revision=filterRevision\n    task.delay(0.12,function()\n        if revision~=filterRevision or not root.Parent then return end\n        local scroll=page.CanvasPosition\n        renderPage()\n        if page.Parent then page.CanvasPosition=scroll end\n    end)\nend\nconnect(filterBox:GetPropertyChangedSignal('Text'),rerenderFilteredPage)\nconnect(filterBox.FocusLost,function()\n    -- Do not rebuild here. Losing focus should never rewrite the TextBox itself.\nend)\nfilterBox.Active=true\nfilterBox.TextEditable=true'''
    source = source[:search_start] + new_search + source[search_end:]
    liquid.write_text(source, encoding='utf-8')

# 4. Add a runtime assertion helper so future regressions cannot silently omit category resolution.
checks = ROOT / 'tools' / 'repair-liquidglass-interactions.py'
print('Liquid Glass interaction repair source prepared:', checks)
'''
 
