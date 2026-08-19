from pathlib import Path
import re

PATH = Path('games/6872274481.lua')
REMOVE = {'AutoAery','AutoArcher','AutoAres','AutoAxolotlAmy','AutoBaker','AutoBarbarian','AutoBountyHunter','AutoJailor'}
WFU = set('''AutoAlchemist AutoBeekeeper AutoCaitlyn AutoConqueror AutoCrocowolf AutoDavey AutoDeathAdder AutoDinoTamerDom AutoDrill AutoElder AutoFarmer AutoFisherman AutoFreiya AutoFrosty AutoGompy AutoHephaestus AutoInfernalShielder AutoJack AutoJade AutoKaida AutoKrystal AutoLani AutoLumen AutoMartin AutoMerchantMarco AutoMetal AutoNazar AutoNoelle AutoNyoka AutoNyx AutoPinata AutoPyro AutoRagnar AutoRamil AutoRaven AutoSanta AutoSheila AutoSilas AutoSmoke AutoSpiritCatcher AutoStarCollector AutoStyx AutoTaliyah AutoTerra AutoTrapper AutoTrinity AutoUma AutoUmbra AutoUmeko AutoVanessa AutoVoidRegent AutoVulcan AutoWarlock AutoWarrior AutoWhim AutoWhisper AutoWizard AutoWren AutoYamini AutoYeti AutoYuzi AutoZenith AutoZephyr AutoZola'''.split())
KEEP = {'AutoEvelynn','AutoGingerbreadMan','AutoMiner','AutoGrim','AutoHannah','AutoKaliyah','AutoMarina','AutoPickpocket','AutoVoidDragon'}

def skip_literal(s,i):
    n=len(s)
    if s.startswith('--[[',i):
        j=s.find(']]',i+4); return n if j<0 else j+2
    if s.startswith('--',i):
        j=s.find('\n',i+2); return n if j<0 else j+1
    if s.startswith('[[',i):
        j=s.find(']]',i+2); return n if j<0 else j+2
    if i>=n or s[i] not in "'\"`": return None
    q=s[i]; i+=1
    while i<n:
        if s[i]=='\\': i+=2; continue
        if s[i]==q: return i+1
        i+=1
    return n

def call_end(s,start):
    i=s.find('(',start); depth=0
    if i<0: raise RuntimeError('missing run parenthesis')
    while i<len(s):
        j=skip_literal(s,i)
        if j is not None: i=j; continue
        if s[i]=='(': depth+=1
        elif s[i]==')':
            depth-=1
            if depth==0:
                i+=1
                while i<len(s) and s[i] in ' \t\r\n': i+=1
                return i
        i+=1
    raise RuntimeError('unclosed run block')

def blocks(s,name):
    hits=[]
    for q in ("'",'"'):
        hits += [m.start() for m in re.finditer(r'\bName\s*=\s*'+re.escape(q+name+q),s)]
    out=[]
    for hit in sorted(set(hits)):
        st=s.rfind('run(function()',0,hit)
        if st<0: continue
        en=call_end(s,st)
        if hit<en and 'kits:CreateModule' in s[st:en] and (st,en) not in out: out.append((st,en))
    return out

def replace(s,name,new):
    found=blocks(s,name)
    for st,en in reversed(found): s=s[:st]+(('' if new is None else new.rstrip()+'\n\n'))+s[en:]
    return s,len(found)

def transform(s,name,fn):
    found=blocks(s,name)
    for st,en in reversed(found): s=s[:st]+fn(s[st:en].rstrip()).rstrip()+'\n\n'+s[en:]
    return s,len(found)

def wfu(name):
    return f'''run(function()\n\tlocal {name}\n\t{name} = kits:CreateModule({{\n\t\tName = '{name}',\n\t\tCategory = 'Auto',\n\t\tFunction = function(callback)\n\t\t\tif callback then\n\t\t\t\tnotif('{name}', 'Wait for next update', 3, 'warning')\n\t\t\t\ttask.defer(function() if {name}.Enabled then {name}:Toggle() end end)\n\t\t\tend\n\t\tend,\n\t\tTooltip = 'Wait for next update',\n\t\tExtraText = function() return 'Wait for next update' end\n\t}})\nend)'''

AGNI=r'''run(function()
\tlocal AutoAgni
\tlocal Targets, Range, OnlySwinging, Clutch
\tlocal swingMarker, swingSeenAt = nil, -math.huge
\tlocal ray = RaycastParams.new()
\tray.FilterType = Enum.RaycastFilterType.Exclude
\tray.RespectCanCollide = true
\tlocal function updateSwing()
\t\tlocal value = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
\t\tif value ~= swingMarker then swingMarker, swingSeenAt = value, os.clock() end
\tend
\tlocal function swinging() return os.clock() - swingSeenAt <= 0.3 end
\tlocal function voidFall(root)
\t\tif not root or root.AssemblyLinearVelocity.Y >= -2 then return false end
\t\tray.FilterDescendantsInstances = lplr.Character and {lplr.Character} or {}
\t\treturn workspace:Raycast(root.Position, Vector3.new(0, -80, 0), ray) == nil
\tend
\tlocal function activate()
\t\tlocal ok, ready = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, 'rocket_detonate', {disableBlockedAbilityAlert = true})
\t\tif not ok or not ready then return false end
\t\tlocal used, result = pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, 'rocket_detonate')
\t\treturn used and result ~= false
\tend
\tlocal function steer(root)
\t\tlocal land, hum = getNearGround(30), entitylib.character.Humanoid
\t\tif not land or not hum then return end
\t\tlocal delta = Vector3.new(land.X-root.Position.X, 0, land.Z-root.Position.Z)
\t\tif delta.Magnitude > 0.05 then hum:Move(delta.Unit, false) end
\tend
\tAutoAgni = kits:CreateModule({
\t\tName = 'AutoAgni', Category = 'Auto',
\t\tFunction = function(callback)
\t\t\tif not callback then return end
\t\t\tswingMarker = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
\t\t\tswingSeenAt = -math.huge
\t\t\tlocal nextUse = 0
\t\t\trepeat
\t\t\t\tif entitylib.isAlive and store.equippedKit == 'agni' then
\t\t\t\t\tlocal root = entitylib.character.RootPart
\t\t\t\t\tupdateSwing()
\t\t\t\t\tif Clutch.Enabled and voidFall(root) then
\t\t\t\t\t\tif os.clock() >= nextUse and activate() then nextUse=os.clock()+0.35 end
\t\t\t\t\t\tsteer(root)
\t\t\t\t\telseif not OnlySwinging.Enabled or swinging() then
\t\t\t\t\t\tlocal ent = entitylib.EntityPosition({Range=Range.Value, Part='RootPart', Players=Targets.Players.Enabled, NPCs=Targets.NPCs.Enabled, Wallcheck=Targets.Walls.Enabled or nil, Sort=sortmethods.Distance})
\t\t\t\t\t\tif ent and os.clock() >= nextUse and activate() then nextUse=os.clock()+0.35 end
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\ttask.wait(0.03)
\t\t\tuntil not AutoAgni.Enabled
\t\tend,
\t\tTooltip = 'Automatically uses Agni rocket boost around selected targets; Clutch saves void falls'
\t})
\tTargets = AutoAgni:CreateTargets({Players=true, NPCs=true, Walls=true})
\tRange = AutoAgni:CreateSlider({Name='Range', Min=1, Max=40, Default=12, Suffix=' studs'})
\tOnlySwinging = AutoAgni:CreateToggle({Name='Only while swinging'})
\tClutch = AutoAgni:CreateToggle({Name='Clutch', Default=true, Tooltip='Uses Agni while falling into the void and walks toward nearby land'})
end)'''

BEKZAT=r'''run(function()
\tlocal AutoBekzat
\tlocal Targets, Range, OnlySwinging
\tlocal swingMarker, swingSeenAt = nil, -math.huge
\tlocal function updateSwing()
\t\tlocal value=bedwars.SwordController and bedwars.SwordController.lastSwing or 0
\t\tif value~=swingMarker then swingMarker,swingSeenAt=value,os.clock() end
\tend
\tlocal function send(position)
\t\tlocal ctl=bedwars.AbilityController
\t\tif not ctl then return false end
\t\tlocal ok,ready=pcall(ctl.canUseAbility,ctl,'SEND_FALCON',{disableBlockedAbilityAlert=true})
\t\tif not ok or not ready then
\t\t\tlocal iok,iready=pcall(ctl.canUseAbility,ctl,'ACTIVATE_FALCON_INDICATOR',{disableBlockedAbilityAlert=true})
\t\t\tif iok and iready then pcall(ctl.useAbility,ctl,'ACTIVATE_FALCON_INDICATOR'); task.wait() end
\t\tend
\t\tok,ready=pcall(ctl.canUseAbility,ctl,'SEND_FALCON',{disableBlockedAbilityAlert=true})
\t\tif not ok or not ready then return false end
\t\tlocal used,result=pcall(ctl.useAbility,ctl,'SEND_FALCON',newproxy(true),{target=position})
\t\tif not used or result==false then return false end
\t\tpcall(function() bedwars.Handler:Get('SendFalconRequested'):Fire('SendToServer',{strikeZoneEpicenter=position}) end)
\t\treturn true
\tend
\tAutoBekzat=kits:CreateModule({
\t\tName='AutoBekzat', Category='Auto',
\t\tFunction=function(callback)
\t\t\tif not callback then return end
\t\t\tswingMarker=bedwars.SwordController and bedwars.SwordController.lastSwing or 0
\t\t\tswingSeenAt=-math.huge
\t\t\tlocal nextUse=0
\t\t\trepeat
\t\t\t\tif entitylib.isAlive and (store.equippedKit=='falconer' or store.equippedKit=='bekzat') then
\t\t\t\t\tupdateSwing()
\t\t\t\t\tif not OnlySwinging.Enabled or os.clock()-swingSeenAt<=0.3 then
\t\t\t\t\t\tlocal ent=entitylib.EntityPosition({Range=Range.Value,Part='RootPart',Players=Targets.Players.Enabled,NPCs=Targets.NPCs.Enabled,Wallcheck=Targets.Walls.Enabled or nil,Sort=sortmethods.Distance})
\t\t\t\t\t\tif ent and os.clock()>=nextUse and send(ent.RootPart.Position) then nextUse=os.clock()+0.4 end
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\ttask.wait(0.05)
\t\t\tuntil not AutoBekzat.Enabled
\t\tend,
\t\tTooltip='Automatically sends Bekzat falcon at nearby selected targets'
\t})
\tTargets=AutoBekzat:CreateTargets({Players=true,NPCs=true,Walls=true})
\tRange=AutoBekzat:CreateSlider({Name='Range',Min=1,Max=80,Default=50,Suffix=' studs'})
\tOnlySwinging=AutoBekzat:CreateToggle({Name='Only while swinging'})
end)'''

BUILDER=r'''run(function()
\tlocal AutoBuilder
\tlocal Legit, Range
\tAutoBuilder=kits:CreateModule({
\t\tName='AutoBuilder', Category='Auto',
\t\tFunction=function(callback)
\t\t\tif not callback then return end
\t\t\trepeat task.wait() until (store.matchState~=0 and store.equippedKit=='builder') or not AutoBuilder.Enabled
\t\t\tif not AutoBuilder.Enabled then return end
\t\t\tlocal objs=collection('block',AutoBuilder,function(tab,obj)
\t\t\t\ttask.defer(function() if obj and obj.Parent and not obj:GetAttribute('NoBreak') and obj:GetAttribute('PlacedByUserId')~=nil then table.insert(tab,obj) end end)
\t\t\tend)
\t\t\trepeat
\t\t\t\tif entitylib.isAlive then
\t\t\t\t\tlocal hammer=getItem('hammer')
\t\t\t\t\tlocal held=store.hand.tool and store.hand.tool.Name=='hammer'
\t\t\t\t\tif hammer and (not Legit.Enabled or held) then
\t\t\t\t\t\tlocal origin=entitylib.character.RootPart.Position
\t\t\t\t\t\tfor _,block in objs do
\t\t\t\t\t\t\tif not AutoBuilder.Enabled then break end
\t\t\t\t\t\t\tif block.Parent and (block.Position-origin).Magnitude<=Range.Value and not block:FindFirstChild('BuilderFortify') then
\t\t\t\t\t\t\t\tlocal _,pos=getPlacedBlock(block.Position)
\t\t\t\t\t\t\t\tif pos then
\t\t\t\t\t\t\t\t\tpcall(function() bedwars.Handler:Get('FortifyBlock'):Fire('SendToServer',pos) end)
\t\t\t\t\t\t\t\t\tif Legit.Enabled then pcall(function()
\t\t\t\t\t\t\t\t\t\tbedwars.GameAnimationUtil:playAnimation(lplr,bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.BUILDER_HAMMER_HIT),{fadeInTime=0.02})
\t\t\t\t\t\t\t\t\t\tbedwars.SoundManager:playSound(bedwars.SoundList.FORTIFY_BLOCK,origin)
\t\t\t\t\t\t\t\t\tend) end
\t\t\t\t\t\t\t\t\ttask.wait(Legit.Enabled and 0.12 or 0.03)
\t\t\t\t\t\t\t\tend
\t\t\t\t\t\t\tend
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\ttask.wait(0.05)
\t\t\tuntil not AutoBuilder.Enabled
\t\tend,
\t\tTooltip='Automatically reinforces nearby placed blocks'
\t})
\tLegit=AutoBuilder:CreateToggle({Name='Legit',Default=true,Tooltip='Requires the hammer to be held and plays normal effects'})
\tRange=AutoBuilder:CreateSlider({Name='Range',Min=1,Max=30,Default=18,Suffix=' studs'})
end)'''

EMBER=r'''run(function()
\tlocal AutoEmber
\tlocal Targets, Range, Legit
\tAutoEmber=kits:CreateModule({
\t\tName='AutoEmber', Category='Auto',
\t\tFunction=function(callback)
\t\t\tif not callback then return end
\t\t\tlocal nextUse=0
\t\t\trepeat
\t\t\t\tif entitylib.isAlive and store.equippedKit=='ember' then
\t\t\t\t\tlocal saber=getItem('infernal_saber')
\t\t\t\t\tlocal held=saber and store.hand.tool and store.hand.tool==saber.tool
\t\t\t\t\tlocal ent=saber and entitylib.EntityPosition({Range=Range.Value,Part='RootPart',Players=Targets.Players.Enabled,NPCs=Targets.NPCs.Enabled,Wallcheck=Targets.Walls.Enabled or nil,Sort=sortmethods.Distance}) or nil
\t\t\t\t\tif ent and (not Legit.Enabled or held) and os.clock()>=nextUse then
\t\t\t\t\t\tpcall(function() bedwars.Handler:Get('HellBladeRelease'):Fire('SendToServer',{chargeTime=1,weapon=saber,player=lplr}) end)
\t\t\t\t\t\tnextUse=os.clock()+0.12
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\ttask.wait(0.03)
\t\t\tuntil not AutoEmber.Enabled
\t\tend,
\t\tTooltip='Automatically uses Ember saber against nearby selected targets'
\t})
\tTargets=AutoEmber:CreateTargets({Players=true,NPCs=true,Walls=true})
\tRange=AutoEmber:CreateSlider({Name='Range',Min=1,Max=22,Default=22,Suffix=' studs'})
\tLegit=AutoEmber:CreateToggle({Name='Legit',Default=true,Tooltip='Only activates while the infernal saber is held'})
end)'''

MELODY=r'''run(function()
\tlocal AutoMelody
\tlocal SelfHeal, TeammateHeal, Delay, Legit, HealthThreshold, Range
\tlocal function hp(char)
\t\tlocal hum=char and char:FindFirstChildWhichIsA('Humanoid')
\t\treturn hum and hum.MaxHealth>0 and hum.Health/hum.MaxHealth or 1
\tend
\tlocal function teammate(origin)
\t\tlocal best,besthp,bestdist=nil,math.huge,math.huge
\t\tfor _,p in playersService:GetPlayers() do
\t\t\tif p~=lplr and p:GetAttribute('Team')==lplr:GetAttribute('Team') and p.Character then
\t\t\t\tlocal root=p.Character.PrimaryPart or p.Character:FindFirstChild('HumanoidRootPart')
\t\t\t\tlocal ph=hp(p.Character); local dist=root and (root.Position-origin).Magnitude or math.huge
\t\t\t\tif dist<=Range.Value and ph<1 and (ph<besthp or (ph==besthp and dist<bestdist)) then best,besthp,bestdist=p,ph,dist end
\t\t\tend
\t\tend
\t\treturn best,besthp
\tend
\tAutoMelody=kits:CreateModule({
\t\tName='AutoMelody', Category='Auto',
\t\tFunction=function(callback)
\t\t\tif not callback then return end
\t\t\tlocal nextHeal=0
\t\t\trepeat
\t\t\t\tif entitylib.isAlive and store.equippedKit=='melody' and os.clock()>=nextHeal then
\t\t\t\t\tlocal guitar=getItem('guitar'); local held=guitar and store.hand.tool and store.hand.tool==guitar.tool
\t\t\t\t\tif guitar and (not Legit.Enabled or held) then
\t\t\t\t\t\tlocal target,targethp=teammate(entitylib.character.RootPart.Position)
\t\t\t\t\t\tlocal selfLow=SelfHeal.Enabled and hp(lplr.Character)<=HealthThreshold.Value/100
\t\t\t\t\t\tlocal teamLow=TeammateHeal.Enabled and target and targethp<=HealthThreshold.Value/100
\t\t\t\t\t\tif target and (selfLow or teamLow) then
\t\t\t\t\t\t\tpcall(function() bedwars.Handler:Get('PlayGuitar'):Fire('SendToServer',{healTarget=target.Character}) end)
\t\t\t\t\t\t\tnextHeal=os.clock()+Delay.Value
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\ttask.wait(0.05)
\t\t\tuntil not AutoMelody.Enabled
\t\tend,
\t\tTooltip='Automatically uses Melody guitar to heal injured teammates and trigger self-healing'
\t})
\tSelfHeal=AutoMelody:CreateToggle({Name='Self',Default=true})
\tTeammateHeal=AutoMelody:CreateToggle({Name='Teammates',Default=true})
\tDelay=AutoMelody:CreateSlider({Name='Delay',Min=0,Max=2,Default=0.1,Decimal=10,Suffix=' seconds'})
\tLegit=AutoMelody:CreateToggle({Name='Legit',Default=true,Tooltip='Only heals while the guitar is held'})
\tHealthThreshold=AutoMelody:CreateSlider({Name='Health threshold',Min=1,Max=100,Default=70,Suffix='%'})
\tRange=AutoMelody:CreateSlider({Name='Range',Min=1,Max=30,Default=30,Suffix=' studs'})
end)'''

WARDEN=r'''run(function()
\tlocal AutoWarden
\tlocal Range, Delay
\tAutoWarden=kits:CreateModule({
\t\tName='AutoWarden', Category='Auto',
\t\tFunction=function(callback)
\t\t\tif not callback then return end
\t\t\tkitCollector(AutoWarden,'jailor_soul',function() return Range.Value end,function() return Delay.Value end,function(soul)
\t\t\t\tbedwars.JailorController:collectEntity(lplr,soul,'JailorSoul')
\t\t\tend)
\t\tend,
\t\tTooltip='Automatically traps/collects nearby Warden souls'
\t})
\tRange=AutoWarden:CreateSlider({Name='Range',Min=1,Max=60,Default=20,Suffix=' studs'})
\tDelay=AutoWarden:CreateSlider({Name='Delay',Min=0,Max=2,Default=0.1,Decimal=10,Suffix=' seconds'})
end)'''

def battery(b):
    return b.replace('AutoBattery','AutoColbat').replace('Drains the batteries you walk over','Automatically collects nearby batteries')

def cyber(b):
    pat=re.compile(r"(?P<i>[ \t]*)bedwars\.Handler:Get\('DropDroneItem'\):Fire\('SendToServer',\s*\{\s*direction\s*=\s*Vector3\.new\(1000,\s*10,\s*0\),\s*position\s*=\s*drone\.PrimaryPart\.Position\s*\}\)",re.M)
    def repl(m):
        i=m.group('i')
        ls=["local generator = DropMode.Value == 'Generator' and teamGenerator() or nil","if generator and generator.PrimaryPart and drone.PrimaryPart then","\tlocal goal = generator.PrimaryPart.Position + Vector3.new(0, 3, 0)","\tlocal deadline = os.clock() + 3","\trepeat","\t\tlocal offset = goal - drone.PrimaryPart.Position","\t\tif offset.Magnitude <= 3 then break end","\t\tdrone.PrimaryPart.CanCollide = false","\t\tdrone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero","\t\tdrone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero","\t\tdrone.PrimaryPart.CFrame = CFrame.lookAt(drone.PrimaryPart.Position + offset.Unit * math.min(2.5, offset.Magnitude), goal)","\t\ttask.wait(0.03)","\tuntil not AutoCyber.Enabled or not drone.Parent or os.clock() >= deadline","end","bedwars.Handler:Get('DropDroneItem'):Fire('SendToServer', {","\tdirection = generator and Vector3.zero or Vector3.new(1000, 10, 0),","\tposition = generator and generator.PrimaryPart.Position or drone.PrimaryPart.Position","})"]
        return '\n'.join(i+x for x in ls)
    b,n=pat.subn(repl,b,count=1)
    if n!=1: raise RuntimeError('AutoCyber DropDroneItem flow changed; refusing guessed patch')
    return b.replace("Default = 'Player'","Default = 'Generator'",1).replace("Tooltip = 'Sends the Cyber drone out to steal resources for you'","Tooltip = 'Collects resources with the Cyber drone and returns held items to your team generator'")

text=PATH.read_text()
for name in REMOVE:
    text,n=replace(text,name,None)
    if n==0: print('note: removal absent',name)
for name in WFU:
    text,n=replace(text,name,wfu(name))
    if n==0: print('note: WFU absent',name)
for name,new in {'AutoAgni':AGNI,'AutoBekzat':BEKZAT,'AutoBuilder':BUILDER,'AutoEmber':EMBER,'AutoMelody':MELODY,'AutoWarden':WARDEN}.items():
    text,n=replace(text,name,new)
    if n==0: raise RuntimeError('missing '+name)
text,n=transform(text,'AutoBattery',battery)
if n==0: raise RuntimeError('missing AutoBattery')
text,n=transform(text,'AutoCyber',cyber)
if n==0: raise RuntimeError('missing AutoCyber')
for name in REMOVE:
    if blocks(text,name): raise RuntimeError('still present '+name)
if blocks(text,'AutoBattery') or not blocks(text,'AutoColbat'): raise RuntimeError('AutoColbat rename failed')
for name in KEEP|{'AutoAgni','AutoBekzat','AutoBuilder','AutoEmber','AutoMelody','AutoWarden'}:
    if not blocks(text,name): raise RuntimeError('missing after patch '+name)
PATH.write_text(text)
print('kit rework applied')
