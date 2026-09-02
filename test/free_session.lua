-- COMBOWICK TEST — free-session script (loads during the 2-min free session)
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "COMBOWICK TEST",
        Text = "🟢 FREE SESSION active — this is the 2-min free script",
        Duration = 8,
    })
end)
print("[COMBOWICK TEST] FREE SESSION script loaded")
