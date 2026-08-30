    Extender = kits:CreateModule({
        Name = spec.Name,
        Category = 'Ability',
        Function = function(callback)
            if callback then
                Extender:Clean(task.spawn(install))
            else
                -- Only put the method back if it is still ours; something else may have
                -- re-hooked it since, and restoring over that would undo their hook.
                if controller and original and controller[spec.Method] == hooked then
                    controller[spec.Method] = original
                end
                controller, original, hooked = nil, nil, nil
            end
        end,
        Tooltip = spec.Tooltip
    })