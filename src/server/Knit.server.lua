local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(script.Parent.Services)

Knit.Start({
	ServicePromises = false,
}):andThen(function()
	print("Knit Services started!")
end)