export type Context = {
    character: Model,
}

local BREAK_JOINTS_ON_DEATH = true
local MIN = 0.0001

local Ragdoll = {}
Ragdoll.__index = Ragdoll

function Ragdoll.new(context: Context)
    local self = setmetatable({
        character = context.character,
    }, Ragdoll)

    self:init()
    return self
end

export type Self = typeof(Ragdoll.new(...))

function Ragdoll.init(self: Self)
    local character = self.character
    local humanoid = character and character:FindFirstChild("Humanoid")
	humanoid.BreakJointsOnDeath = BREAK_JOINTS_ON_DEATH
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	local constraintfolder = character:FindFirstChild("RagdollConstraints") or Instance.new("Folder", character)
	constraintfolder.Name = "RagdollConstraints"
	local collisionfolder = character:FindFirstChild("CollisionConstraints") or Instance.new("Folder", character)
	collisionfolder.Name = "CollisionConstraints"
	
	local bodyparts = {
		HumanoidRootPart = character:WaitForChild("HumanoidRootPart");

		LowerTorso = character:WaitForChild("LowerTorso");

		LeftUpperLeg = character:WaitForChild("LeftUpperLeg");
		LeftLowerLeg = character:WaitForChild("LeftLowerLeg");
		LeftFoot = character:WaitForChild("LeftFoot");

		RightUpperLeg = character:WaitForChild("RightUpperLeg");
		RightLowerLeg = character:WaitForChild("RightLowerLeg");
		RightFoot = character:WaitForChild("RightFoot");

		UpperTorso = character:WaitForChild("UpperTorso");

		LeftUpperArm = character:WaitForChild("LeftUpperArm");
		LeftLowerArm = character:WaitForChild("LeftLowerArm");
		LeftHand = character:WaitForChild("LeftHand");

		RightUpperArm = character:WaitForChild("RightUpperArm");
		RightLowerArm = character:WaitForChild("RightLowerArm");
		RightHand = character:WaitForChild("RightHand");

		Head = character:WaitForChild("Head");
	}

	local motors = {
		Root = bodyparts.LowerTorso:WaitForChild("Root");

		LeftHip = bodyparts.LeftUpperLeg:WaitForChild("LeftHip");
		LeftKnee = bodyparts.LeftLowerLeg:WaitForChild("LeftKnee");
		LeftAnkle = bodyparts.LeftFoot:WaitForChild("LeftAnkle");

		RightHip = bodyparts.RightUpperLeg:WaitForChild("RightHip");
		RightKnee = bodyparts.RightLowerLeg:WaitForChild("RightKnee");
		RightAnkle = bodyparts.RightFoot:WaitForChild("RightAnkle");

		Waist = bodyparts.UpperTorso:WaitForChild("Waist");

		LeftShoulder = bodyparts.LeftUpperArm:WaitForChild("LeftShoulder");
		LeftElbow = bodyparts.LeftLowerArm:WaitForChild("LeftElbow");
		LeftWrist = bodyparts.LeftHand:WaitForChild("LeftWrist");

		RightShoulder = bodyparts.RightUpperArm:WaitForChild("RightShoulder");
		RightElbow = bodyparts.RightLowerArm:WaitForChild("RightElbow");
		RightWrist = bodyparts.RightHand:WaitForChild("RightWrist");

		Neck = bodyparts.Head:WaitForChild("Neck");
	}

	local constraints = {
		Ankle	= Instance.new("BallSocketConstraint");
		Elbow	= Instance.new("HingeConstraint");
		Hip		= Instance.new("BallSocketConstraint");
		Knee	= Instance.new("HingeConstraint");
		Neck	= Instance.new("BallSocketConstraint");
		Shoulder= Instance.new("BallSocketConstraint");
		Waist	= Instance.new("BallSocketConstraint");
		Wrist	= Instance.new("BallSocketConstraint"); 
	}
	
	self.bodyparts = bodyparts
	self.constraints = constraints
	self.motors = motors
	
	constraints.Ankle.LimitsEnabled = true
	constraints.Ankle.TwistLimitsEnabled = true
	constraints.Ankle.UpperAngle = 30
	constraints.Ankle.TwistLowerAngle = -45
	constraints.Ankle.TwistUpperAngle = 30

	constraints.Elbow.LowerAngle = 0
	constraints.Elbow.UpperAngle = 135
	constraints.Elbow.LimitsEnabled = true

	constraints.Hip.LimitsEnabled = true
	constraints.Hip.TwistLimitsEnabled = true
	constraints.Hip.UpperAngle = 50
	constraints.Hip.TwistLowerAngle = 100
	constraints.Hip.TwistUpperAngle = -45

	constraints.Knee.LowerAngle = -140
	constraints.Knee.UpperAngle = 0
	constraints.Knee.LimitsEnabled = true

	constraints.Neck.LimitsEnabled = true
	constraints.Neck.TwistLimitsEnabled = true
	constraints.Neck.MaxFrictionTorque = 4
	constraints.Neck.UpperAngle = 60
	constraints.Neck.TwistLowerAngle = -75
	constraints.Neck.TwistUpperAngle = 60

	constraints.Shoulder.LimitsEnabled = true
	constraints.Shoulder.TwistLimitsEnabled = true
	constraints.Shoulder.UpperAngle = 45
	constraints.Shoulder.TwistLowerAngle = -90
	constraints.Shoulder.TwistUpperAngle = 150

	constraints.Waist.LimitsEnabled = true
	constraints.Waist.TwistLimitsEnabled = true
	constraints.Waist.UpperAngle = 30
	constraints.Waist.TwistLowerAngle = -55
	constraints.Waist.TwistUpperAngle = 25

	constraints.Wrist.LimitsEnabled = true
	constraints.Wrist.TwistLimitsEnabled = true
	constraints.Wrist.UpperAngle = 30
	constraints.Wrist.TwistLowerAngle = -45
	constraints.Wrist.TwistUpperAngle = 45

	local altrootmotor = Instance.new("Motor6D",bodyparts.UpperTorso)
	altrootmotor.C0 = CFrame.new(0,(bodyparts.LowerTorso.Size.Y)*0.7,0)
	altrootmotor.Enabled = false
	altrootmotor.Part0 = bodyparts.HumanoidRootPart
	altrootmotor.Part1 = bodyparts.UpperTorso
	self.altrootmotor = altrootmotor
	
	pcall(self.ragdollJoint, bodyparts.LowerTorso, bodyparts.UpperTorso, "Waist")

	pcall(self.ragdollJoint, bodyparts.UpperTorso, bodyparts.Head, "Neck")

	pcall(self.ragdollJoint, bodyparts.UpperTorso, bodyparts.LeftUpperArm, "LeftShoulder")
	pcall(self.ragdollJoint, bodyparts.UpperTorso, bodyparts.RightUpperArm, "RightShoulder")

	pcall(self.ragdollJoint, bodyparts.LeftUpperArm, bodyparts.LeftLowerArm, "LeftElbow")
	pcall(self.ragdollJoint, bodyparts.RightUpperArm, bodyparts.RightLowerArm, "RightElbow")

	pcall(self.ragdollJoint, bodyparts.LeftLowerArm, bodyparts.LeftHand, "LeftWrist")
	pcall(self.ragdollJoint, bodyparts.RightLowerArm, bodyparts.RightHand, "RightWrist")

	pcall(self.ragdollJoint, bodyparts.LowerTorso, bodyparts.LeftUpperLeg, "LeftHip")
	pcall(self.ragdollJoint, bodyparts.LowerTorso, bodyparts.RightUpperLeg, "RightHip")

	pcall(self.ragdollJoint, bodyparts.LeftUpperLeg, bodyparts.LeftLowerLeg, "LeftKnee")
	pcall(self.ragdollJoint, bodyparts.RightUpperLeg, bodyparts.RightLowerLeg, "RightKnee")

	pcall(self.ragdollJoint, bodyparts.LeftLowerLeg, bodyparts.LeftFoot, "LeftAnkle")
	pcall(self.ragdollJoint, bodyparts.RightLowerLeg, bodyparts.RightFoot, "RightAnkle")
    
	for _,v in pairs(character:GetChildren()) do
		if v:IsA("Accessory") then
			local handle = v:FindFirstChild("Handle")
			if handle then
				handle.CustomPhysicalProperties = PhysicalProperties.new(MIN, MIN, MIN, MIN, MIN)
				local attachment1 = handle:FindFirstChildOfClass("Attachment")
				local attachment0 = self:getAccessoryAttachment0(attachment1.Name)
				if attachment1 and attachment0 then
					local con = Instance.new("HingeConstraint")
					con.Name = "Accessory_"..v.Name
					con.Attachment0 = attachment0
					con.Attachment1 = attachment1
					con.LimitsEnabled = true
					con.UpperAngle = 0
					con.LowerAngle = 0
					con.Parent = constraintfolder
				end
			end
		end
	end

	bodyparts.HumanoidRootPart.Anchored = false
	bodyparts.HumanoidRootPart.CanCollide = false
	bodyparts.HumanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(MIN, MIN, MIN, MIN, MIN)
	bodyparts.Head.CustomPhysicalProperties = PhysicalProperties.new(MIN, MIN, MIN, MIN, MIN)
	bodyparts.Head.OriginalSize.Value = Vector3.new(1,1,1)
	bodyparts.Head.Size = Vector3.new(bodyparts.Head.Size.Z,bodyparts.Head.Size.Y,bodyparts.Head.Size.Z)

	local HeadCollision = Instance.new("Part",bodyparts.Head)
	HeadCollision.Name = "HeadCollision"
	HeadCollision.Transparency = 1
	HeadCollision.Parent = bodyparts.Head
	HeadCollision.Shape = Enum.PartType.Cylinder
	local headsize = bodyparts.Head.Size
	HeadCollision.Size = Vector3.new(headsize.Y,headsize.Z,headsize.Z)
	HeadCollision.CanCollide = true
	HeadCollision.CollisionGroup = "plrs"
	bodyparts.Head:GetPropertyChangedSignal("Size"):Connect(function()
		local headsize = bodyparts.Head.Size
		HeadCollision.Size = Vector3.new(headsize.Y,headsize.Z,headsize.Z)
	end)

	local HeadCollisionWeld = Instance.new("Weld",HeadCollision)
	HeadCollisionWeld.Part0 = bodyparts.Head
	HeadCollisionWeld.Part1 = HeadCollision
	HeadCollisionWeld.C0 = HeadCollisionWeld.C0*CFrame.fromOrientation(0,0,math.rad(-90))

	bodyparts.Head.CollisionGroup = "noclip"

	local HeadCollisionAttachment = Instance.new("Attachment",HeadCollision)
	HeadCollisionAttachment.Orientation = Vector3.new(0,0,-90)

	local HeadCollisionConstraint = Instance.new("HingeConstraint")
	HeadCollisionConstraint.Name = "HeadCollision"
	HeadCollisionConstraint.Attachment0 = bodyparts.Head.FaceCenterAttachment
	HeadCollisionConstraint.Attachment1 = HeadCollisionAttachment
	HeadCollisionConstraint.LimitsEnabled = true
	HeadCollisionConstraint.UpperAngle = 0
	HeadCollisionConstraint.LowerAngle = 0
	HeadCollisionConstraint.Parent = constraintfolder

	local collisionfiltertbl = {
		{
			HeadCollision;

			bodyparts.LeftUpperArm;
			bodyparts.LeftUpperLeg;
			bodyparts.LowerTorso;
			bodyparts.RightUpperArm;
			bodyparts.RightUpperLeg;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.LeftFoot;

			bodyparts.LowerTorso;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.LeftLowerArm;

			bodyparts.LowerTorso;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.LeftLowerLeg;

			bodyparts.LowerTorso;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.LeftUpperArm;

			bodyparts.LeftUpperLeg;
			bodyparts.LowerTorso;
			bodyparts.RightUpperArm;
			bodyparts.RightUpperLeg;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.LeftUpperLeg;

			bodyparts.LowerTorso;
			bodyparts.RightUpperLeg;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.RightFoot;

			bodyparts.LowerTorso;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.RightHand;

			--bodyparts.LowerTorso;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.RightLowerArm;

			bodyparts.LowerTorso;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.RightLowerLeg;

			bodyparts.LowerTorso;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.RightUpperArm;

			bodyparts.LeftUpperLeg;
			bodyparts.LowerTorso;
			bodyparts.LeftUpperArm;
			bodyparts.RightUpperLeg;
			bodyparts.UpperTorso;
		};
		{
			bodyparts.RightUpperLeg;

			bodyparts.LowerTorso;
			bodyparts.LeftUpperLeg;
			bodyparts.UpperTorso;
		};
	}

	for i=1,#collisionfiltertbl do
		for b=2,#collisionfiltertbl[i] do
			local constraint = Instance.new("NoCollisionConstraint",collisionfolder)
			constraint.Name = collisionfiltertbl[i][1].Name.."<->"..collisionfiltertbl[i][b].Name
			constraint.Part0 = collisionfiltertbl[i][1]
			constraint.Part1 = collisionfiltertbl[i][b]
		end
	end
end

function Ragdoll.getAccessoryAttachment0(self: Self, name: string): Attachment?
	local character = self.char
	if character then
		for _,v in pairs(character:GetChildren()) do
			local attachment = v:FindFirstChild(name)
			if attachment then
                return attachment
            end
		end
	end
    return nil
end

function Ragdoll.ragdollJoint(self: Self, part0: BasePart, part1: BasePart, attachmentName: string)
	local character = self.char
	local constraintFolder = character and character:FindFirstChild("RagdollConstraints")
	if constraintFolder then
		local constraintname
		for i,v in pairs(self.constraints) do
			if string.match(attachmentName,i) then
				constraintname = i
				break
			end
		end
		attachmentName = attachmentName.."RigAttachment"
		local constraint = self.constraints[constraintname]:Clone()
		constraint.Attachment0 = part0[attachmentName]
		constraint.Attachment1 = part1[attachmentName]
		constraint.Name = "Ragdoll_"..part1.Name

		constraint.Parent = constraintFolder
	end
end

function Ragdoll.toggleMotors(self: Self, mode: boolean)
	for i,v in pairs(self.motors) do
		if i ~= "Root" then
			v.Enabled = mode
		end
	end
end

function Ragdoll.toggleRagdoll(self: Self, toggle: boolean, duration: number?, pushDirection: Vector3?)
	local motors = self.motors
	local orgrootmotor = motors and motors.Root
	local altrootmotor = orgrootmotor and self.altrootmotor
	if altrootmotor then
		if toggle and not self.ragdolling then
			self.ragdolling = true
			altrootmotor.Enabled = true
			orgrootmotor.Enabled = false
			self:toggleMotors(false)
		elseif not toggle and self.ragdolling then
			self.ragdolling = false
			orgrootmotor.Enabled = true
			altrootmotor.Enabled = false
			self:toggleMotors(true)
		end
	end
end

function Ragdoll.cleanup(self: Self)
	if not self.cleanedUp then
		self.cleanedUp = true
		setmetatable(self, nil)
	end
end

return Ragdoll