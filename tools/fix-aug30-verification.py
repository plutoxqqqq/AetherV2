#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / 'games' / '6872274481' / 'main.lua'
UNIVERSAL = ROOT / 'games' / 'universal.lua'


def patch_hit_chance():
    text = MAIN.read_text(encoding='utf-8')
    old = "\treturn math.clamp(math.round(100 - errorBudget), 0, 100)"
    new = "\treturn math.clamp((100 - errorBudget) / 100, 0, 1)"
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise RuntimeError('Could not locate Hit Accuracy scale return')
    MAIN.write_text(text, encoding='utf-8')


def patch_prompt_compatibility():
    text = UNIVERSAL.read_text(encoding='utf-8')
    if "Name = 'PromptEditor'" not in text:
        raise RuntimeError('PromptEditor is missing')

    env_block = "\tlocal environment = (getgenv and getgenv()) or _G\n\tlocal api = environment.AetherInteractExtender or {}\n"
    anchor = "\tlocal applying = setmetatable({}, {__mode = 'k'})\n"
    if env_block not in text:
        if anchor not in text:
            raise RuntimeError('Could not locate PromptEditor state declarations')
        text = text.replace(anchor, anchor + env_block, 1)

    compat = '''\n\tapi.IsEnabled = function()\n\t\treturn PromptEditor and PromptEditor.Enabled == true\n\tend\n\tapi.Activate = function(prompt)\n\t\tif not api.IsEnabled() then return false, 'PromptEditor is disabled' end\n\t\tif typeof(prompt) ~= 'Instance' or not prompt:IsA('ProximityPrompt') then return false, 'invalid prompt' end\n\t\tapplyPrompt(prompt)\n\t\tif type(fireproximityprompt) ~= 'function' then return false, 'fireproximityprompt unavailable' end\n\t\tlocal ok, result = pcall(fireproximityprompt, prompt)\n\t\treturn ok and result ~= false, ok and nil or tostring(result)\n\tend\n\tenvironment.AetherInteractExtender = api\n\tvape:Clean(function()\n\t\tif environment.AetherInteractExtender == api then environment.AetherInteractExtender = nil end\n\tend)\n'''
    if 'api.Activate = function(prompt)' not in text:
        marker = "\tPromptEditor = vape.Categories.World:CreateModule({\n"
        if marker not in text:
            raise RuntimeError('Could not locate PromptEditor registration')
        text = text.replace(marker, compat + '\n' + marker, 1)

    UNIVERSAL.write_text(text, encoding='utf-8')


def validate():
    main = MAIN.read_text(encoding='utf-8')
    universal = UNIVERSAL.read_text(encoding='utf-8')
    assert "math.clamp((100 - errorBudget) / 100, 0, 1)" in main
    assert "Name = 'PromptEditor'" in universal
    assert 'api.Activate = function(prompt)' in universal
    assert 'environment.AetherInteractExtender = api' in universal
    print('Verified Hit Accuracy scale and PromptEditor compatibility bridge')


if __name__ == '__main__':
    patch_hit_chance()
    patch_prompt_compatibility()
    validate()
