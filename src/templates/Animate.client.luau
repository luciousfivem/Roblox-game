--!strict
-- R6 animations: idle, walk, jump, fall, climb, sit, plus the equipped-tool pose and tool slash.
-- Roblox's default Animate script is only attached to characters the engine spawns, so characters
-- we build ourselves get this one instead. It uses Roblox's classic R6 animation assets.
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local animator = humanoid:FindFirstChildOfClass("Animator") or (humanoid:WaitForChild("Animator", 5) :: Animator?)
if not animator then
	local created = Instance.new("Animator")
	created.Parent = humanoid
	animator = created
end
local activeAnimator: Animator = animator :: Animator

local IDS = {
	Idle = "rbxassetid://180435571",
	Walk = "rbxassetid://180426354",
	Jump = "rbxassetid://125750702",
	Fall = "rbxassetid://180436148",
	Climb = "rbxassetid://180436334",
	Sit = "rbxassetid://178130996",
	ToolNone = "rbxassetid://182393478",
	ToolSlash = "rbxassetid://129967390",
	ToolLunge = "rbxassetid://129967478",
}

local function load(id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = activeAnimator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return track
end

local idle = load(IDS.Idle, Enum.AnimationPriority.Core, true)
local walk = load(IDS.Walk, Enum.AnimationPriority.Core, true)
local jump = load(IDS.Jump, Enum.AnimationPriority.Core, false)
local fall = load(IDS.Fall, Enum.AnimationPriority.Core, true)
local climb = load(IDS.Climb, Enum.AnimationPriority.Core, true)
local sit = load(IDS.Sit, Enum.AnimationPriority.Core, true)
local toolNone = load(IDS.ToolNone, Enum.AnimationPriority.Idle, true)
local toolSlash = load(IDS.ToolSlash, Enum.AnimationPriority.Action, false)
local toolLunge = load(IDS.ToolLunge, Enum.AnimationPriority.Action, false)

local current: AnimationTrack? = nil
local moveSpeed = 0

local function play(track: AnimationTrack?, fade: number?)
	if current == track then
		return
	end
	if current then
		current:Stop(fade or 0.2)
	end
	current = track
	if track then
		track:Play(fade or 0.2)
	end
end

local function groundPose()
	if moveSpeed > 0.75 then
		play(walk)
		walk:AdjustSpeed(moveSpeed / 14.5)
	else
		play(idle)
	end
end

humanoid.Running:Connect(function(speed)
	moveSpeed = speed
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
		groundPose()
	end
end)

humanoid.Climbing:Connect(function(speed)
	climb:AdjustSpeed(speed / 12)
end)

humanoid.StateChanged:Connect(function(_, new)
	if new == Enum.HumanoidStateType.Jumping then
		play(jump, 0.1)
	elseif new == Enum.HumanoidStateType.Freefall then
		play(fall, 0.2)
	elseif new == Enum.HumanoidStateType.Climbing then
		play(climb)
	elseif new == Enum.HumanoidStateType.Seated then
		play(sit)
	elseif
		new == Enum.HumanoidStateType.Landed
		or new == Enum.HumanoidStateType.Running
		or new == Enum.HumanoidStateType.RunningNoPhysics
		or new == Enum.HumanoidStateType.GettingUp
	then
		groundPose()
	elseif new == Enum.HumanoidStateType.Dead then
		play(nil, 0.1)
	end
end)

-- Tools: hold pose while equipped, and play a swing whenever a "toolanim" value is dropped in the tool
-- (the mining input does this on every swing).
local equipped: Tool? = nil

local function onToolChild(child: Instance)
	if child:IsA("StringValue") and child.Name == "toolanim" then
		if child.Value == "Lunge" then
			toolLunge:Play(0.05)
		else
			toolSlash:Play(0.05)
		end
		child:Destroy()
	end
end

local function onEquip(tool: Tool)
	equipped = tool
	toolNone:Play(0.2)
	tool.ChildAdded:Connect(onToolChild)
end

character.ChildAdded:Connect(function(child)
	if child:IsA("Tool") then
		onEquip(child)
	end
end)

character.ChildRemoved:Connect(function(child)
	if child == equipped then
		equipped = nil
		toolNone:Stop(0.2)
	end
end)

for _, child in character:GetChildren() do
	if child:IsA("Tool") then
		onEquip(child)
	end
end

play(idle, 0)
