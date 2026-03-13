-- Missile SENT

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Air-to-surface Missile"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local SndLoop = Sound("weapons/rpg/rocket1.wav")
local SndFire = Sound("weapons/stinger_fire1.wav")
local SndBoost = Sound("weapons/rpg/rocketfire1.wav")

if SERVER then
  AddCSLuaFile("sent_asm.lua")
end

function ENT:Initialize()
    if (SERVER) then
        self:SetModel("models/props_phx/mk-82.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetColor(Color(0,0,0,0))
        self.Launched = false
        self.Exploded = false
        self.Sound = CreateSound(self,SndLoop)

        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:EnableGravity(false)
            phys:Wake()
        end
    end
end

function ENT:Launch()
    self:SetTrail()
    self:EmitSound(SndFire)
    self:SetColor(Color(0,0,0,255))
    self.Sound:Play()
    self.Launched = true
end

function ENT:Boost()
    self:EmitSound(SndBoost)
end

function ENT:Think()
    if (!SERVER) then return end
    if not self.Launched then return end

    local vel=Vector(0,0,-24)
    if IsValid(self.SWEP) && self.SWEP.Status==3 then vel=Vector(0,0,-4) end
    self:GetPhysicsObject():AddVelocity(vel)

    self:NextThink(CurTime()+0.01)
    return true
end

function ENT:PhysicsCollide(data, physobj)
  self:Explode()
end

function ENT:Explode()
    if self.Sound then
        self.Sound:Stop()
        self.Sound = nil
    end

    if not self.Exploded then
        local vPos = self:GetPos() - Vector(0,0,self:OBBMaxs().z)
        
        local effd = EffectData()
            effd:SetStart(vPos)
            effd:SetOrigin(vPos)
            effd:SetScale(1)
            effd:SetRadius(384)
            effd:SetEntity(NULL)
        util.Effect("ASM-Explosion", effd)    

        local attacker = self
        if IsValid(self.Owner) then attacker = self.Owner end
        util.BlastDamage(self, attacker, vPos, 384, 500000)
        util.Decal("Scorch", vPos+Vector(0,0,1), vPos-Vector(0,0,1))

        self.Exploded = true

        self:Remove()
    end
end

function ENT:SetTrail()
    ent = ents.Create("env_spritetrail")
    ent:SetPos(self:GetPos() + Vector(0,0,64))
    ent:SetAngles(self:GetAngles())
    ent:SetKeyValue("lifetime","3.0")
    ent:SetKeyValue("startwidth","32.0")
    ent:SetKeyValue("endwidth","1.0")
    ent:SetKeyValue("renderamt","100")
    ent:SetKeyValue("rendercolor","128 128 128")
    ent:SetKeyValue("rendermode","0")
    ent:SetKeyValue("spritename","trails/smoke.vmt")
    ent:SetParent(self)
    ent:Spawn()
    self.Trail = ent
end

function ENT:Draw()
    local wep = LocalPlayer():GetActiveWeapon()
    if wep && wep.IsAsmSWEP then
        if (wep.Status == 2) or (wep.Status == 3) then return end
    end
    self:DrawModel()
end

function ENT:OnRemove()
    if SERVER then
        if IsValid(self.SWEP) then self.SWEP:MissileDestroyed() end
        if IsValid(self.Trail) then
            local trail = self.Trail
            trail:SetParent(nil)
            timer.Simple(5, function() if IsValid(trail) then trail:Remove() end end)
        end
    end
end
