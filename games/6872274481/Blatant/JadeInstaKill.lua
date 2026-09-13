run(function()
    local Runtime = assert(AetherMatchRuntime, 'Aether runtime missing')
    local Jade = assert(Runtime.Jade, 'Jade adapter missing')
    local Movement = assert(Runtime.Movement, 'movement coordinator missing')
    local ModuleLeases = assert(Runtime.ModuleLeases, 'module leases missing')
    local safe = Runtime.Safe
    local now = Runtime.Now
    local rootOfLocal = Runtime.RootOfLocal
    local moduleByName = Runtime.ModuleByName
    local copyTable = Runtime.CopyTable


local JIKState={IDLE='IDLE',ACQUIRE_TARGET='ACQUIRE_TARGET',VALIDATE='VALIDATE',ACQUIRE_MOVEMENT='ACQUIRE_MOVEMENT',EQUIP='EQUIP',REQUEST_CAST='REQUEST_CAST',CONFIRM_CAST='CONFIRM_CAST',ACTIVE='ACTIVE',OUTCOME='LANDING/OUTCOME',RECOVERY='RECOVERY',COOLDOWN='COOLDOWN'}
Runtime.JIKState=JIKState

local CharacterTransaction={}
CharacterTransaction.__index=CharacterTransaction
function CharacterTransaction.new(character)
    local self=setmetatable({Character=character,Cleaned=false,PartTransparency={},Connections={},OriginalCamera=nil,OriginalHeld=store.hand and store.hand.tool or nil,MovementLease=nil,Bindings={}},CharacterTransaction)
    return self
end
function CharacterTransaction:HidePart(part) if part:IsA('BasePart') and self.PartTransparency[part]==nil then self.PartTransparency[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1 end end
function CharacterTransaction:Cleanup()
    if self.Cleaned then return end;self.Cleaned=true
    for name in pairs(self.Bindings) do runService:UnbindFromRenderStep(name) end;table.clear(self.Bindings)
    for _,connection in ipairs(self.Connections) do safe('jik.tx.disconnect',connection.Disconnect,connection) end;table.clear(self.Connections)
    for part,value in pairs(self.PartTransparency) do if part.Parent then part.LocalTransparencyModifier=value end end;table.clear(self.PartTransparency)
    if self.MovementLease then self.MovementLease:Release();self.MovementLease=nil end
    if self.OriginalHeld and self.OriginalHeld.Parent then safe('jik.restore-held',switchItem,self.OriginalHeld,0) end
end

local Presentation={}
function Presentation.Start(transaction,character,targetTracker,cameraEnabled)
    for _,desc in ipairs(character:GetDescendants()) do transaction:HidePart(desc) end
    table.insert(transaction.Connections,character.DescendantAdded:Connect(function(desc) transaction:HidePart(desc) end))
    if cameraEnabled then
        local bind='AetherJIKPresentationV2';transaction.Bindings[bind]=true
        runService:BindToRenderStep(bind,Enum.RenderPriority.Camera.Value+1,function()
            local target=targetTracker.Root;if not target or not target.Parent then return end
            local root=rootOfLocal();if not root then return end
            gameCamera.CFrame=CFrame.lookAt(gameCamera.CFrame.Position,target.Position)
        end)
    end
end

local TargetTracker={}
TargetTracker.__index=TargetTracker
function TargetTracker.new(entity,range)
    return setmetatable({Entity=entity,Root=entity and entity.RootPart,Initial=entity and entity.RootPart and entity.RootPart.Position,Range=range,LastValid=now(),Reason=nil},TargetTracker)
end
function TargetTracker:Refresh(origin)
    local ent=self.Entity;local root=ent and ent.RootPart
    if root and root~=self.Root then self.Root=root end
    if not ent or not self.Root or not self.Root.Parent or not ent.Character or not ent.Character.Parent then self.Reason='root-or-character-lost';return false end
    if ent.Health and ent.Health<=0 then self.Reason='dead';return false end
    if origin and (self.Root.Position-origin).Magnitude>self.Range+8 then self.Reason='left-execution-range';return false end
    self.LastValid=now();return true
end

local JadeInstaKill
local JIKOptions={}
local JIK={State=JIKState.IDLE,Generation=0,Session=nil,Diagnostics={}}
Runtime.JIK=JIK

local function jikDebug(message,data)
    JIK.Diagnostics.At=now();JIK.Diagnostics.State=JIK.State;JIK.Diagnostics.Message=message
    if data then for k,v in pairs(data) do JIK.Diagnostics[k]=v end end
    if JIKOptions.Debug and JIKOptions.Debug.Enabled then warn('[AetherV2/JIK] '..message) end
end
local function jikTransition(state,detail)
    local old=JIK.State;JIK.State=state;JIK.Diagnostics.LastTransition=old..' -> '..state;if detail then JIK.Diagnostics.Detail=detail end
end
local function jikCancelled(generation) return not JadeInstaKill.Enabled or generation~=JIK.Generation or not entitylib.isAlive end
local function jikCleanup(session,reason)
    if session and session.Transaction then session.Transaction:Cleanup() end
    ModuleLeases:ReleaseOwner('JadeInstaKill')
    JIK.Session=nil
    jikTransition(JIKState.IDLE,reason)
end

local function acquireJikTarget()
    local root=rootOfLocal();if not root then return nil,'local-root-missing' end
    local ok,result=pcall(entitylib.EntityPosition,{Origin=root.Position,Range=JIKOptions.Range.Value,Part='RootPart',Players=JIKOptions.Targets.Players.Enabled,NPCs=JIKOptions.Targets.NPCs.Enabled})
    if not ok then return nil,'entitylib-error:'..tostring(result) end
    if not result then return nil,'no-target' end
    return result
end

local function validateJikTarget(target)
    if not target then return false,'nil-target' end
    local root=rootOfLocal();if not root then return false,'local-root-missing' end
    if not target.RootPart or not target.RootPart.Parent then return false,'target-root-missing' end
    if target.Health and target.Health<=0 then return false,'target-dead' end
    local distance=(target.RootPart.Position-root.Position).Magnitude
    if distance>JIKOptions.Range.Value+3 then return false,'out-of-range:'..string.format('%.1f',distance) end
    if target.Player and target.Player:GetAttribute('Team')==lplr:GetAttribute('Team') and lplr:GetAttribute('Team')~=nil then return false,'same-team' end
    return true,nil,distance
end

local function simulationResult(session)
    local state,stateInfo=Jade:GetState(session.Ability)
    jikDebug('Simulation: no cast sent',{Hammer=session.Hammer.itemType,Ability=session.Ability,Readiness=state,ReadinessSource=stateInfo.Source,Target=session.Target.Entity.Player and session.Target.Entity.Player.Name or 'NPC'})
    return true
end

local function runJikSession(target,generation)
    local session={Target=TargetTracker.new(target,JIKOptions.Range.Value),Transaction=nil,Hammer=nil,Ability=nil,Started=now(),Generation=generation}
    JIK.Session=session
    local function cancelled() return jikCancelled(generation) end
    local success,err=xpcall(function()
        jikTransition(JIKState.VALIDATE)
        local valid,reason,distance=validateJikTarget(target);if not valid then error('VALIDATE:'..reason) end
        session.Distance=distance

        local hammer,hammerInfo=Jade:GetBestHammer();session.Hammer=hammer;session.HammerInfo=hammerInfo
        if not hammer then error('EQUIP:no-supported-jade-hammer') end
        local ability,abilityInfo=Jade:ResolveAbility(hammer);session.Ability=ability;session.AbilityInfo=abilityInfo
        local readiness,readinessInfo=Jade:GetState(ability);session.Readiness=readiness;session.ReadinessInfo=readinessInfo
        if readiness=='BLOCKED' then error('REQUEST_CAST:ability-blocked') end

        jikTransition(JIKState.ACQUIRE_MOVEMENT)
        local lease,leaseReason=Movement:Acquire('JadeInstaKill',Movement.Priorities.Ability,1.0,function() JIK.Generation+=1 end,true)
        if not lease then error('ACQUIRE_MOVEMENT:'..tostring(leaseReason)) end
        
        
        for _,name in ipairs({'Fly','Speed','LongJump','Scaffold','TPAura'}) do ModuleLeases:Acquire('JadeInstaKill',name,{},false) end
        session.Transaction=CharacterTransaction.new(lplr.Character);session.Transaction.MovementLease=lease

        jikTransition(JIKState.EQUIP)
        local equipped,equipReason=Jade:Equip(hammer,0.9,cancelled)
        if not equipped then error('EQUIP:'..equipReason) end
        jikDebug('Hammer equipped',{Hammer=hammer.itemType,HeldConfirmation=equipReason,Ability=ability,Readiness=readiness,ReadinessSource=readinessInfo.Source,Distance=distance})
        if cancelled() then error('EQUIP:cancelled') end

        local mode=JIKOptions.Mode.Value
        if mode=='Spoof' then mode='Simulation' end 
        if mode=='Simulation' then simulationResult(session);return end

        Presentation.Start(session.Transaction,lplr.Character,session.Target,JIKOptions.Camera.Enabled)
        jikTransition(JIKState.REQUEST_CAST)
        local targetPosition=session.Target.Root.Position
        local confirmed,castReason,request=Jade:RequestActivation(hammer,ability,targetPosition,cancelled)
        session.Request=request
        jikTransition(JIKState.CONFIRM_CAST,castReason)
        if not confirmed then error('CONFIRM_CAST:'..castReason) end
        jikDebug('Cast confirmed',{Confirmation=castReason,RequestPath=request and request.Paths and request.Paths[1] and request.Paths[1].Path})

        jikTransition(JIKState.ACTIVE)
        local root,character,humanoid=rootOfLocal();if not root or not humanoid then error('ACTIVE:character-lost') end
        local originalOffset=(root.Position-session.Target.Root.Position)*Vector3.new(1,0,1)
        local activeDeadline=now()+10
        while not cancelled() and now()<activeDeadline do
            lease:Renew(0.5)
            root,character,humanoid=rootOfLocal();if not root or not humanoid then break end
            if not session.Target:Refresh(root.Position) then break end
            local targetRoot=session.Target.Root
            if Movement:CanWrite('JadeInstaKill') and isnetworkowner(root) then
                
                
                local targetPos=targetRoot.Position+originalOffset
                root.CFrame=CFrame.new(targetPos.X,root.Position.Y,targetPos.Z)*root.CFrame.Rotation
                local velocity=root.AssemblyLinearVelocity;local targetVelocity=targetRoot.AssemblyLinearVelocity
                local extra=JIKOptions.FasterFall.Enabled and JIKOptions.Gravity.Value*(1/60) or 0
                root.AssemblyLinearVelocity=Vector3.new(targetVelocity.X,velocity.Y-extra,targetVelocity.Z)
            end
            if humanoid.FloorMaterial~=Enum.Material.Air and now()-session.Started>0.3 then break end
            task.wait()
        end

        jikTransition(JIKState.OUTCOME,session.Target.Reason)
        if cancelled() then return end
        jikTransition(JIKState.COOLDOWN)
        local cooldownDeadline=now()+6
        while not cancelled() and now()<cooldownDeadline do
            local state=Jade:GetCooldownState(ability)
            if state=='READY' then break end
            
            
            if state=='UNKNOWN' and now()-session.Started>1.2 then break end
            task.wait(0.08)
        end
    end,debug and debug.traceback or tostring)
    if not success then
        jikTransition(JIKState.RECOVERY,tostring(err));jikDebug('Job failed',{Failure=tostring(err),Hammer=session.Hammer and session.Hammer.itemType,Ability=session.Ability,Target=target.Player and target.Player.Name or 'NPC'})
    end
    jikCleanup(session,success and 'completed' or tostring(err))
end

JadeInstaKill=vape.Categories.Exploits:CreateModule({Name='JadeInstaKill',Tooltip='Uses the live Jade controller/tool path, confirms the cast, tracks one target, and cleans up transaction state',Function=function(callback)
    JIK.Generation+=1
    if not callback then if JIK.Session then jikCleanup(JIK.Session,'module-disabled') else JIK.State=JIKState.IDLE end;return end
    local generation=JIK.Generation
    task.spawn(function()
        while JadeInstaKill.Enabled and generation==JIK.Generation do
            if JIK.State==JIKState.IDLE and entitylib.isAlive then
                jikTransition(JIKState.ACQUIRE_TARGET)
                local target,reason=acquireJikTarget()
                if target then task.spawn(runJikSession,target,generation) else JIK.State=JIKState.IDLE;if reason~='no-target' then jikDebug('Target acquisition failed',{Failure=reason}) end end
            end
            task.wait(0.08)
        end
        if not JadeInstaKill.Enabled and JIK.Session then jikCleanup(JIK.Session,'scanner-ended') end
    end)
end})
Runtime.JadeInstaKill=JadeInstaKill
JIKOptions.Mode=JadeInstaKill:CreateDropdown({Name='Mode',List={'TP','Simulation','Spoof'},Tooltip='TP runs the real Jade slam. Simulation performs diagnostics only. Legacy Spoof configs are migrated to Simulation.'})
JIKOptions.Targets=JadeInstaKill:CreateTargets({Players=true,NPCs=true})
JIKOptions.Range=JadeInstaKill:CreateSlider({Name='Range',Min=1,Max=30,Default=18,Suffix=' studs'})
JIKOptions.FasterFall=JadeInstaKill:CreateToggle({Name='Increase gravity',Default=true,Function=function(value)if JIKOptions.Gravity and JIKOptions.Gravity.Object then JIKOptions.Gravity.Object.Visible=value end end})
JIKOptions.Gravity=JadeInstaKill:CreateSlider({Name='Extra gravity',Min=0,Max=500,Default=180,Suffix=' studs/s²'})
JIKOptions.Camera=JadeInstaKill:CreateToggle({Name='Camera lock',Default=true})
JIKOptions.Debug=JadeInstaKill:CreateToggle({Name='Debug',Tooltip='Logs state transitions, hammer/equip/readiness source and exact failure reasons'})
JadeInstaKill.ExtraText=function() return JIK.State end

function Runtime:GetJIKDiagnostics() return copyTable(JIK.Diagnostics) end


end)
