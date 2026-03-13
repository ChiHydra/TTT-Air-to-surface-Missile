if CLIENT then
    SWEP.PrintName = "Air-to-surface Missile"
    SWEP.Author = "Otger"
    --SWEP.Contact = "n/a"
    SWEP.Purpose = "Air-to-surface controllable missile."
    SWEP.Instructions = "Left click to launch an air-to-surface missile from the sky above the aimed position.\nWhen launched, use the mouse or the movement keys to direct it, left click to boost it, and right click to quit controlling it.\nReload to open the menu."
    SWEP.Slot = 4
    SWEP.SlotPos = 1
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/swep_asm")
    SWEP.BounceWeaponIcon = true
    SWEP.DrawAmmo = true
    SWEP.DrawCrosshair = true
    --SWEP.Category = "Other"
end

SWEP.Base = "weapon_tttbase"
SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.AutoSpawnable = false
SWEP.AmmoEnt = "item_ammo_pistol_ttt"
SWEP.InLoadoutFor = nil
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false

if ( CLIENT ) then
 SWEP.Icon = "vgui/entities/swep_asm" -- Text shown in the equip menu
 SWEP.EquipMenuData = { type = "Missile", desc = "Air to surface missile!"};
end

SWEP.Weight = 7
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Spawnable = true
SWEP.AdminSpawnable = true

if SERVER then
    AddCSLuaFile("swep_asm.lua")
    resource.AddFile("materials/VGUI/swep_asm.vmt")
    resource.AddFile("materials/VGUI/swep_asm.vtf")
    resource.AddFile("materials/VGUI/entities/swep_asm.vmt")
    resource.AddFile("materials/VGUI/entities/swep_asm.vtf")
    --resource.AddFile("materials/HUD/asm_available.vmt")
    --resource.AddFile("materials/HUD/asm_available.vtf")
    resource.AddFile("materials/HUD/killicons/asm_missile.vmt")
    resource.AddFile("materials/HUD/killicons/asm_missile.vtf")
    if util.IsValidModel("models/weapons/v_c4.mdl") then
        SWEP.ModelC4 = true
        SWEP.ViewModel = "models/weapons/v_c4.mdl"
        SWEP.WorldModel = "models/weapons/w_c4.mdl"
    else
        SWEP.ModelC4 = false
        SWEP.ViewModel = "models/weapons/v_toolgun.mdl"
        SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
    end
end
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local SndReady = Sound("npc/metropolice/vo/isreadytogo.wav")
local SndReadyB = Sound("buttons/blip2.wav")
local SndRequested = Sound("buttons/button24.wav")
local SndInbound = Sound("npc/combine_soldier/vo/inbound.wav")

util.PrecacheModel("models/props_junk/PopCan01a.mdl")
util.PrecacheModel("models/props_c17/canister01a.mdl")

function SWEP:Initialize()
    self.Delay = 0
    self.Status = 0
    self.ThirdPerson = false

    if self.ModelC4 then self:SetWeaponHoldType("slam")
    else self:SetWeaponHoldType("pistol") end

    if CLIENT then
        self.FadeCount = 0
        self.Load = 0
        killicon.Add("sent_asm","HUD/killicons/asm_missile",Color(255,0,0,255))
        language.Add("sent_asm","Air-to-surface Missile")
        --hook.Add("HUDPaint","ASMSwepDrawHUD", function() self:DrawInactiveHUD() end)
    end
end

function SWEP:OnRemove()
    if SERVER then
        self:UnlockPlayer()
        if IsValid(self.Camera) then
            if IsValid(self.Owner) && (self.Owner:GetViewEntity() == self.Camera) then
                self.Owner:SetViewEntity(self.Owner)
            end
            self.Camera:Remove()
        end
    end
    if CLIENT then
        if self.HtmlIcon && self.HtmlIcon:IsValid() then self.HtmlIcon:Remove() end
        self.HtmlIcon = nil
        if(self.Menu && self.Menu:IsValid()) then
            self.Menu:SetVisible(false)
            self.Menu:Remove()
        end
        hook.Remove("HUDPaint","AsmSwepDrawHUD")
    end
end

function SWEP:Deploy()
    if SERVER then
        self:SendWeaponAnim(ACT_VM_DRAW)
    end
    return true
end

function SWEP:Holster()
    if(self.Status>0) then return false end
    return true
end

function SWEP:ShouldDropOnDie() return false end

-- SERVER --

if SERVER then
    if !ASMSettings then
        ASMSettings = {}
        ASMSettings.DmgSelf = true
        ASMSettings.DmgFriend = true
    end

    function SWEP:PrimaryAttack()
        if(self.Status == 0) then
            if self.Delay > CurTime() then return end

            local tr = self.Owner:GetEyeTrace()
            local vPos = self:FindInitialPos(tr.HitPos)

            if vPos then
                if self:SpawnMissile(vPos) then
                    self.Owner:ConCommand("firstperson")
                    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
                    self.Owner:SetAnimation(PLAYER_ATTACK1)
                    self:EmitSound(SndRequested)
                    
                    self:LockPlayer()
                    self:SetStatus(1,1.75)
                end
            else
                self:SendMessage(1)
            end
        elseif(self.Status == -1) then
            self:SendMessage(2)
        end
        self:SetNextPrimaryFire(CurTime()+1)
    end

    function SWEP:SecondaryAttack() end

    function SWEP:Reload()
        if self.Owner:IsAdmin() && (self.Status < 1) then
            umsg.Start("ASM-Menu",self.Owner)
                umsg.String(tostring(ASMSettings.DmgSelf)..","..tostring(ASMSettings.DmgFriend))
            umsg.End()
        end
    end

    function SWEP:Equip()
        --if !self.ModelC4 then self:SendMessage(0) end
    end

    function SWEP:Think()
        if CurTime() < self.Delay then return end

        if self.Status == 1 then
            self:SetStatus(2,0.5)
        elseif self.Status == 2 then
            if IsValid(self.Missile) then
                self.Missile:Launch()
                self.Owner:SetViewEntity(self.Camera)
                self:SendWeaponAnim(ACT_VM_IDLE)
                self:SetStatus(3,0)
            else
                self:SetStatus(0,0)
            end
        elseif (self.Status>2) &&(self.Status<6) then
            if IsValid(self.Missile) then
                if (self.Status==3) then
                    if self.Owner:KeyDown(IN_ATTACK) or self.Owner:KeyDown(IN_USE) then
                        self:SetStatus(4,0)
                        self.Missile:Boost()
                    end
                end
                if self.Status < 5 then
                    local vVel = Vector(0,0,0)

                    if self.Owner:KeyDown(IN_FORWARD) then vVel=vVel+Vector(16,0,0) end
                    if self.Owner:KeyDown(IN_BACK) then vVel=vVel+Vector(-16,0,0) end
                    if self.Owner:KeyDown(IN_MOVELEFT) then vVel=vVel+Vector(0,16,0) end
                    if self.Owner:KeyDown(IN_MOVERIGHT) then vVel=vVel+Vector(0,-16,0) end

                    local cmd = self.Owner:GetCurrentCommand()
                    vVel=vVel+Vector(0,-cmd:GetMouseX()/10,0)
                    vVel=vVel+Vector(-cmd:GetMouseY()/10,0,0)

                    self.Missile:GetPhysicsObject():AddVelocity(vVel)

                    if self.Owner:KeyDown(IN_ATTACK2) then
                        self.Owner:SetViewEntity(self.Owner)
                        self:UnlockPlayer()
                        self:SetStatus(5,0)
                    end
                end
            else
                self:MissileDestroyed()
                self:SendMessage(3)
            end
        elseif self.Status == 6 then
            self:UnlockPlayer()
            self:SetStatus(-1,0)
            
            timer.Simple(3, function()
                if IsValid(self) then
                    if self.Status == -1 then self:SetStatus(0,0) end
                end
            end)
        end
    end

    function SWEP:SetStatus(status,delay)
        self.Status = (status or 0)
        if delay > 0 then self.Delay = CurTime() + delay end
        if IsValid(self.Owner) then
            umsg.Start("ASM-Update", self.Owner)
                umsg.Entity(self.Weapon)
                umsg.Short(status or 0)
            umsg.End()
        end
    end

    function SWEP:SendMessage(id)
        umsg.Start("ASM-Msg",self.Owner)
            umsg.Short(id)
        umsg.End()
    end
    
    function SWEP:CreateCamera()
        local ent = ents.Create("prop_physics")
            ent:SetModel("models/props_junk/PopCan01a.mdl")
            ent:SetPos(self.Owner:GetPos())
            ent:SetAngles(Angle(90,0,0))
        ent:Spawn()
        ent:Activate()
        ent:SetMoveType(MOVETYPE_NOCLIP)
        ent:SetSolid(SOLID_NONE)
        ent:SetRenderMode(RENDERMODE_NONE)
        ent:DrawShadow(false)
        return ent
    end

    function SWEP:SpawnMissile(vPos)
        local mis = ents.Create("sent_asm")
            mis:SetPos(vPos+Vector(0,0,mis:OBBMins().z-48))
            mis:SetAngles(Angle(90,0,0))
        mis:Spawn()
        mis:Activate()

        if IsValid(mis) then
            if !IsValid(self.Camera) then self.Camera = self:CreateCamera() end

            self.Camera:SetPos(mis:GetPos()+Vector(0,0,-56))
            self.Camera:SetAngles(Angle(90,0,0))
            self.Camera:SetParent(mis)

            mis.Owner = self.Owner
            mis.SWEP = self

            self.Missile = mis
            self:SetNWEntity("Missile",mis)
            return true
        end
        return false
    end

    local function ASMSetVis(ply)
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) && wep:GetClass() == "swep_asm" then
            if (wep.Status==2) or (wep.Status==3) then
                if IsValid(wep.Camera) then AddOriginToPVS(wep.Camera:GetPos()) end
            end
        end
    end
    hook.Add("SetupPlayerVisibility", "ASMSetupVis", ASMSetVis)

    local function ASMGetDmg(ent,inflictor,attacker,amount,dmginfo)
        if IsValid(inflictor) && (inflictor:GetClass()=="sent_asm") && IsValid(inflictor.SWEP) then
            if ent:IsPlayer() then
                if (inflictor.Owner == ent) && !ASMSettings.DmgSelf then
                    dmginfo:SetDamage(0)
                end
            elseif ent:IsNPC() then
                if !ASMSettings.DmgFriend && inflictor.SWEP:CheckFriendly(ent) then
                    dmginfo:SetDamage(0)
                end
            end
        end
    end
    hook.Add("EntityTakeDamage", "ASMSetupDamage", ASMGetDmg)

    function SWEP:LockPlayer()
        self.LastMoveType = self.Owner:GetMoveType()
        self.Owner:SetMoveType(MOVETYPE_NONE)
    end

    function SWEP:UnlockPlayer()
        if IsValid(self.Owner) && (self.Owner:GetMoveType()==MOVETYPE_NONE) then
            self.Owner:SetMoveType(self.LastMoveType or MOVETYPE_WALK)
        end
    end

    function SWEP:MissileDestroyed()
        if IsValid(self.Owner) then
            self.Owner:SetViewEntity(self.Owner)
        end
        if IsValid(self.Camera) then
            self.Camera:SetParent(nil)
        end
        if(self.Status>1) then
            self:SetStatus(6,0.5)
			self:Remove()
        end
    end

    function SWEP:FindInitialPos(vStart)
        local td = {}
            td.start = vStart+Vector(0,0,-32)
            td.endpos = vStart
            td.endpos.z = 16384
            td.mask = MASK_NPCWORLDSTATIC
            td.filter = {}
        local bContinue = true
        local nCount=0
        local tr = {}
        local vPos = nil

        while bContinue && td.start.z <= td.endpos.z do
            nCount = nCount + 1
            tr = util.TraceLine(td)
            if tr.HitSky then
                vPos = tr.HitPos
                bContinue = false
            elseif !tr.Hit then
                td.start = tr.HitPos - Vector(0,0,64)
            elseif tr.HitWorld then
                td.start = tr.HitPos + Vector(0,0,64)
            elseif(IsValid(tr.Entity)) then
                table.insert(td.filter, tr.Entity)
            end
            if nCount>128 then break end
        end
        return vPos
    end

    function SWEP:CheckFriendly(ent)
        if ent:Disposition(self.Owner) == 1 then return false end
        return true
    end

    concommand.Add("ASM-Config", function(ply,cmd,args)
        local wep = Entity(tonumber(args[1]))
        if IsValid(wep) && wep:GetClass() == "swep_asm" then
            if ply == wep.Owner && ply:IsAdmin() then
                ASMSettings.DmgSelf = tobool(args[2])
                ASMSettings.DmgFriend = tobool(args[3])
            end
        end
    end)
end

-- CLIENT --

if CLIENT then

    surface.CreateFont("AsmScreenFont", {
      size = 18,
      weight = 400,
      antialias = false,
      shadow = false,
      font = "Trebuchet MS"})

    surface.CreateFont("AsmCamFont", {
      size = 22,
      weight = 700,
      antialias = false,
      shadow = false,
      font = "Courier New"})

    --local texScreenOverlay = surface.GetTextureID("effects/combine_binocoverlay")
    --local matMissileAvailable = Material("HUD/asm_available")
    
    local SndNoPos = Sound("npc/combine_soldier/vo/sectorisnotsecure.wav")
    local SndNoPosB = Sound("buttons/button19.wav")
    local SndNotReady = Sound("buttons/button2.wav")
    local SndLost = Sound("npc/combine_soldier/vo/lostcontact.wav")

    function SWEP:Think() end

    usermessage.Hook("ASM-Update",function(um)
        local ent = um:ReadEntity()
        if IsValid(ent) && ent:GetClass() == "swep_asm" then
            ent:UpdateStatus(um:ReadShort())
        end
    end)

    usermessage.Hook("ASM-Msg",function(um)
        local nId = um:ReadShort()
        if(nId==0) then
            MsgN("[Air-to-surface Missile SWEP] Counter-Strike: Source is not mounted. Using Toolgun model.")
        elseif(nId==1) then
            GAMEMODE:AddNotify("Could not find open sky above the specified position",NOTIFY_ERROR,5)
            LocalPlayer():EmitSound(SndNoPos)
            LocalPlayer():EmitSound(SndNoPosB)
        elseif(nId==2) then
            GAMEMODE:AddNotify("Missiles currently unavailable",NOTIFY_ERROR,5)
            LocalPlayer():EmitSound(SndNotReady)
        elseif(nId==3) then
            GAMEMODE:AddNotify("Lost contact with the missile",NOTIFY_GENERIC,5)
            LocalPlayer():EmitSound(SndLost)
        end
    end)

    usermessage.Hook("ASM-Menu",function(um)
        local wep = LocalPlayer():GetActiveWeapon()
        if wep && wep:GetClass() == "swep_asm" then
            wep:MenuOpen(string.Explode(",",um:ReadString()))
        end
    end)

    function SWEP:MenuCreate()
        if self.Menu then
            self.Menu:SetVisible(false)
            self.Menu:Remove()
        end
        self.Menu = vgui.Create("DFrame")
            self.Menu:SetName("ASM-Config")
            self.Menu:SetTitle("Air-to-surface Missile Settings")
            self.Menu:SetDraggable(true)
            self.Menu:ShowCloseButton(true)
            self.Menu:SetDeleteOnClose(false)
            self.Menu:SetSize(256,128)
            self.Menu:SetVisible(false)
            
            self.Menu.ChkDmgSelf = vgui.Create("DCheckBoxLabel", self.Menu)
                self.Menu.ChkDmgSelf:SetPos(16,32)
                self.Menu.ChkDmgSelf:SetText("Damage owner")
                self.Menu.ChkDmgSelf:SetTooltip("If unchecked, the missile will not inflict damage or kill its owner.")
                self.Menu.ChkDmgSelf:SizeToContents()
                
            self.Menu.ChkDmgFriend = vgui.Create("DCheckBoxLabel", self.Menu)
                self.Menu.ChkDmgFriend:SetPos(16,64)
                self.Menu.ChkDmgFriend:SetText("Friendly fire")
                self.Menu.ChkDmgFriend:SetTooltip("If checked, friendly NPCs will receive damage from the missiles and eventually die.")
                self.Menu.ChkDmgFriend:SizeToContents()
                
            self.Menu.BtnSave = vgui.Create("DButton", self.Menu)
                self.Menu.BtnSave:SetText("Update settings")
                self.Menu.BtnSave:SetPos(16,96)
                self.Menu.BtnSave:SetSize(224,24)
                self.Menu.BtnSave.SWEP = self
                self.Menu.BtnSave.DoClick = function(button)
                    RunConsoleCommand("ASM-Config",
                        button.SWEP:EntIndex(),
                        tostring(button.SWEP.Menu.ChkDmgSelf:GetChecked()),
                        tostring(button.SWEP.Menu.ChkDmgFriend:GetChecked())
                    )
                    button.SWEP.Menu:SetVisible(false)
                end
    end

    function SWEP:MenuOpen(tOpts)
        if not self.Menu then
            self:MenuCreate()
        end
        self.Menu.ChkDmgSelf:SetValue(tobool(tOpts[1]) or false)
        self.Menu.ChkDmgFriend:SetValue(tobool(tOpts[2]) or false)
        self.Menu:Center()
        self.Menu:SetVisible(true)
        self.Menu:MakePopup()
    end

    function SWEP:UpdateStatus(status)
        local nLastStatus = self.Status
        self.Status = status
        if status == 0 then
            if (self.HtmlIcon) then self.HtmlIcon:SetVisible(true) end
            if nLastStatus == -1 then
                self:EmitSound(SndReady)
                self:EmitSound(SndReadyB)
            end
        else
            if (self.HtmlIcon) then self.HtmlIcon:SetVisible(false) end
            if status == 1 then
                self.Load = CurTime()+1.75
            elseif status == 2 then
                self:EmitSound(SndInbound)
                self.FadeCount = 0
            elseif status == 3 then
                self.FadeCount = 255
            elseif status == 4 then
                --cam.ApplyShake(LocalPlayer():GetActiveWeapon():GetNWEntity("Missile"):GetPos(),Angle(0,0,0),100)
            end
        end
        if self.Menu && status > 0 then
            self.Menu:SetVisible(false)
        end
    end

    function SWEP:DrawInactiveHUD()
        if self.Status == 0 then
            draw.RoundedBoxEx(8,ScrW()-50,60,50,60,Color(224,224,224,255),true,false,true,false)
            draw.DrawText("Missile\nReady","HudHintTextLarge",ScrW()-4, 26,Color(224,224,224,255),TEXT_ALIGN_RIGHT)
        end
    end

    function SWEP:CheckFriendly(ent)
        if ent == LocalPlayer() then return true end
        return false
    end

    function SWEP:DrawHUD()
        if self.Status > 1 then
            local bNoMissile = false
            local eMissile = self:GetNWEntity("Missile")
            if (!IsValid(eMissile)) or (util.PointContents(eMissile:GetPos()) == CONTENTS_SOLID) then
                bNoMissile = true
            end

            if self.Status == 2 then
                surface.SetDrawColor(0,0,0,self.FadeCount)
                surface.DrawRect(0,0,ScrW(),ScrH())

                if(self.FadeCount < 255) then
                    self.FadeCount=self.FadeCount+5
                end
            elseif self.Status > 4 or bNoMissile then
                surface.SetDrawColor(0,0,0,self.FadeCount)
                surface.DrawRect(0,0,ScrW(),ScrH())

                if(self.FadeCount > 0) then
                    self.FadeCount=self.FadeCount-5
                end
            elseif self.Status == 3 or self.Status == 4 then
                local col = {}
                    col["$pp_colour_addr"] =0
                    col["$pp_colour_addg"] = 0
                    col["$pp_colour_addb"] = 0
                    col["$pp_colour_brightness"] = 0.1
                    col["$pp_colour_contrast"] = 1
                    col["$pp_colour_colour"] = 0
                    col["$pp_colour_mulr"] = 0
                    col["$pp_colour_mulg"] = 0
                    col["$pp_colour_mulb"] = 0
                DrawColorModify(col)
                DrawSharpen(1,2)

                local h = ScrH()/2
                local w = ScrW()/2
                local ho = 2*h/3

                surface.SetDrawColor(160,160,160,255)
                surface.DrawOutlinedRect(w-48,h-32,96,64)

                surface.DrawLine(w, h-32, w, h-128)
                surface.DrawLine(w, h+32, w, h+128)
                surface.DrawLine(w-48, h, w-144, h)
                surface.DrawLine(w+48, h, w+144, h)

                surface.DrawLine(w-ho, h-ho+64, w-ho, h-ho)
                surface.DrawLine(w-ho, h-ho, w-ho+64, h-ho)
                surface.DrawLine(w+ho-64, h-ho, w+ho, h-ho)
                surface.DrawLine(w+ho, h-ho, w+ho, h-ho+64)
                surface.DrawLine(w+ho, h+ho-64, w+ho, h+ho)
                surface.DrawLine(w+ho, h+ho, w+ho-64, h+ho)
                surface.DrawLine(w-ho+64, h+ho, w-ho, h+ho)
                surface.DrawLine(w-ho, h+ho, w-ho, h+ho-64)

                local pos = eMissile:GetPos()
                surface.SetFont("AsmCamFont")
                surface.SetTextColor(64,64,64,255)

                surface.SetTextPos(24,16)
                surface.DrawText(tostring(math.Round(pos.x)).." "..tostring(math.Round(pos.y)).." "..tostring(math.Round(pos.z)))

                surface.SetTextPos(24,40)
                local dist = self.Owner:GetEyeTrace().HitPos:Distance(pos-Vector(0,0,eMissile:OBBMaxs().z))
                surface.DrawText(tostring(math.Round(dist)).." : "..tostring(math.Round(eMissile:GetVelocity():Length())))

                surface.SetTextPos(24,64)
                surface.DrawText("5 295 ["..math.Round(CurTime()).."]")

                local tEnts = ents.GetAll()
                for _,ent in pairs(tEnts) do
                    if(ent:IsPlayer() or ent:IsNPC()) then
                        local vPos = ent:GetPos()+Vector(0,0,0.5*ent:OBBMaxs().z)
                        local scrPos = vPos:ToScreen()
                        if self:CheckFriendly(ent) then
                            surface.SetDrawColor(64,255,64,160)
                            surface.DrawLine(scrPos.x-16,scrPos.y-16,scrPos.x+16,scrPos.y+16)
                            surface.DrawLine(scrPos.x-16,scrPos.y+16,scrPos.x+16,scrPos.y-16)
                        else
                            surface.SetDrawColor(255,64,64,160)
                        end
                        surface.DrawOutlinedRect(scrPos.x-16, scrPos.y-16,32,32)
                    end
                end
            end
        end
        --surface.SetMaterial(matMissileAvailable)
        --surface.SetDrawColor(255,255,255,255)
        --surface.DrawTexturedRect(32, 32, 512, 512)
    end
    
    local GlowMat = CreateMaterial("AsmLedGlow","UnlitGeneric",{
        ["$basetexture"] = "sprites/light_glow01",
        ["$vertexcolor"] = "1",
        ["$vertexalpha"] = "1",
        ["$additive"] = "1",
    })
    
    function SWEP:GetViewModelPosition(pos,ang)
        if self:GetModel() == "models/weapons/v_toolgun.mdl" then
            local offset = Vector(-6,5.6,0)
            offset:Rotate(ang)
            pos = pos + offset
        end
        return pos,ang
    end

    function SWEP:ViewModelDrawn()
        if (self.Status ~= 3) && (self.Status ~= 4) then
            local ent = self.Owner:GetViewModel()
            local pos,ang,offset,res,height,z
            if ent:GetModel() == "models/weapons/v_c4.mdl" then
                pos,ang = ent:GetBonePosition(ent:LookupBone("v_weapon.c4"))
                if self.Status == 0 then
                    offset = Vector(-1.6,2.8,-0.25)
                    offset:Rotate(ang)
                    render.SetMaterial(GlowMat)
                    render.DrawQuadEasy(pos+offset,ang:Right() * -1,1.5,1.5,Color(255,128,128,255))
                end
                offset = Vector(-1.8,2.7,1.4)
                offset:Rotate(ang)
                ang:RotateAroundAxis(ang:Forward(),-90)
                ang:RotateAroundAxis(ang:Up(),180)
                res = 0.03
                height = 53
                z = 16
            else
                pos,ang = ent:GetBonePosition(ent:LookupBone("Python"))
                offset = Vector(1.04,2.8,-0.1)
                offset:Rotate(ang)
                ang:RotateAroundAxis(ang:Forward(),43.86)
                ang:RotateAroundAxis(ang:Up(),1)
                ang:RotateAroundAxis(ang:Right(),180)
                res = 0.0234
                height = 94
                z = 32
            end
            pos = pos + offset
            cam.Start3D2D(pos,ang,res)
                surface.SetDrawColor(4,32,4,255)
                surface.DrawRect(0,0,96,height)
                if self.Status == -1 then
                    draw.SimpleText("Missiles","AsmScreenFont",48,z,Color(80,192,64,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                    draw.SimpleText("unavailable","AsmScreenFont",48,z+16,Color(80,192,64,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                elseif self.Status == 0 then
                    draw.SimpleText("Waiting for","AsmScreenFont",48,z,Color(80,192,64,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                    draw.SimpleText("target...","AsmScreenFont",48,z+16,Color(80,192,64,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                elseif self.Status == 1 then
                    draw.SimpleText("Requesting...","AsmScreenFont",48,z,Color(80,192,64,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                    surface.SetDrawColor(80,192,64,255)
                    surface.DrawOutlinedRect(11,z+15,74,10)
                    surface.SetDrawColor(112,224,96,255)
                    surface.DrawRect(12,z+16,72*(1-((self.Load-CurTime())/1.75)),8)
                else
                    draw.SimpleText("Inbound","AsmScreenFont",48,z+8,Color(80,192,64,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                end
                //surface.SetTexture(texScreenOverlay)
                //surface.DrawTexturedRectUV(0,0,96,height,96,height)
            cam.End3D2D()
        end
    end
    
    function SWEP:FreezeMovement()
        if (self.Status > 0) && (self.Status ~= 5) then
            return true
        end
        return false
    end
    
    function SWEP:HUDShouldDraw(el)
        if(self.Status > 2 && self.Status < 7) then
            if (el=="CHudGMod") then return true end
            return false
        end
        return true
    end

    -- Explosion effect

    local EFFECT = {}
    function EFFECT:Init(data)
        self.Pos = data:GetOrigin()
        self.Radius = data:GetRadius()

        sound.Play("ambient/explosions/explode_4.wav", self.Pos, 100, 140, 1)
        sound.Play("npc/env_headcrabcanister/explosion.wav", self.Pos, 100, 140, 1)

        local em = ParticleEmitter(self.Pos)
        for n=1,180 do
            local wave = em:Add("particle/particle_noisesphere",self.Pos)
                wave:SetVelocity(Vector(math.sin(math.rad(n*2)),math.cos(math.rad(n*2)),0)*self.Radius*3)
                wave:SetAirResistance(128)
                wave:SetLifeTime(math.random(0.2,0.4))
                wave:SetDieTime(math.random(3,4))
                wave:SetStartSize(64)
                wave:SetEndSize(48)
                wave:SetColor(160,160,160)
                wave:SetRollDelta(math.random(-1,1))
            local fire = em:Add("effects/fire_cloud1",self.Pos+VectorRand()*self.Radius/2)
                fire:SetVelocity(Vector(math.random(-8,8),math.random(-8,8),math.random(8,16)):GetNormal()*math.random(128,1024))
                fire:SetAirResistance(256)
                fire:SetLifeTime(math.random(0.2,0.4))
                fire:SetDieTime(math.random(2,3))
                fire:SetStartSize(80)
                fire:SetEndSize(32)
                fire:SetColor(160,64,64,192)
                fire:SetRollDelta(math.random(-1,1))
        end
        for n=1,16 do
            local smoke = em:Add("particle/particle_noisesphere", self.Pos+48*VectorRand()*n)
                smoke:SetVelocity(VectorRand()*math.Rand(32,96))
                smoke:SetAirResistance(32)
                smoke:SetDieTime(8)
                smoke:SetStartSize((32-n)*2*math.Rand(8,16))
                smoke:SetEndSize((32-n)*math.Rand(8,16))
                smoke:SetColor(160,160,160)
                smoke:SetStartAlpha(math.Rand(224,255))
                smoke:SetEndAlpha(0)
                smoke:SetRollDelta(math.random(-1,1))
        end
        em:Finish()
    end

    function EFFECT:Think() return false end
    function EFFECT:Render() end

    effects.Register(EFFECT,"ASM-Explosion")
end
