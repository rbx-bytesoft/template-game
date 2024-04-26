local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddControllers(script.Parent.Controllers)

Knit.Start({
	ServicePromises = false
}):andThen(function()
	print("Knit Controllers started!")
	for i, component in pairs(script.Parent.Components:GetChildren()) do
		if component:IsA("ModuleScript") then
			require(component)
		end
	end
	print("Knit Components started")
end):catch(warn)