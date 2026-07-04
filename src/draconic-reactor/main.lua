local DraconicReactorManager = require("draconic_reactor_manager")
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
local reactor_manager = DraconicReactorManager:new(nil, draconic_reactor, input_flux_gate, output_flux_gate)

parallel.waitForAll(
    function()
        reactor_manager:handle()
    end,
    function()
        while true do
            print("STATE = " .. reactor_manager.reactor_state)
            sleep(1)
        end
    end
)