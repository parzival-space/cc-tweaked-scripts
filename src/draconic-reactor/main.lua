local DraconicReactor = require("draconic_reactor")
local PeripheralStore = require("peripheral_store")


-- try to locate peripherals and store them so we can later load the same
local peripheral_store = PeripheralStore:new(nil, "devices.json")
local draconic_reactor = peripheral_store:load_or_find("draconic_reactor", "draconic_reactor") or error("No Draconic Reactor found!")
local input_flux_gate = peripheral_store:load_or_find("input_flux_gate", "flow_gate", function(name, flow_gate)
    -- input gate is the gate with low flow set to 10
    print(name .. " has flow state " .. flow_gate.getSignalLowFlow())
    return flow_gate.getSignalLowFlow() == 10
end) or error("Reactor input Flux Gate not found! Make sure the 'Redstone Signal Low' flow is set to 10 RF/t.")
local output_flux_gate = peripheral_store:load_or_find("output_flux_gate", "flow_gate", function(name, flow_gate)
    -- input gate is the gate with low flow is not set to 10
    print(name .. " has flow state " .. flow_gate.getSignalLowFlow())
    return flow_gate.getSignalLowFlow() ~= 10
end) or error("Reactor output Flux Gate not found!")

-- init managers
local reactor_manager = DraconicReactor:new(nil, draconic_reactor, input_flux_gate, output_flux_gate)

-- configuration
reactor_manager.field_strength_goal = 0.35
reactor_manager.temperature_goal = 7500
reactor_manager.fuel_conversion_max = 0.85
reactor_manager.reactor_output_multiplier = 1

-- run handler
parallel.waitForAll(
    function()
        reactor_manager:handle()
    end
    -- here was once a handle for monitors, now it is not
)