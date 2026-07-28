return function(api)
  api:register_validator(
    "org.simstation.core:hook/command/validate",
    { name = "protect-essential-breakers", priority = 0 },
    function(_, command)
      if command.kind == "disconnect_network"
        and command.payload
        and command.payload.essential
      then
        return false, "org.simstation.example.smart-grid.reason.essential-network"
      end
      return true
    end
  )

  api:register_transform(
    "org.simstation.core:hook/task/score",
    { name = "prefer-power-repairs", priority = 0 },
    function(_, score, task)
      if task and task.tags and task.tags.power_emergency then
        return score + 250
      end
      return score
    end
  )

  api:register_observer(
    "org.simstation.core:hook/event/finalized",
    { name = "count-restorations", priority = 0 },
    function(context, event)
      if event.kind == "power_restored" then
        local state = context:get_state()
        state.restorations = (state.restorations or 0) + 1
        context:set_state(state)
      end
    end
  )
end
