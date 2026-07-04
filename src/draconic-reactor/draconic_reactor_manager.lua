local ReactorState = {
    COLD = "cold",
    WARMING_UP = "warming_up",
    RUNNING = "running",
    STOPPING = "stopping",
    COOLING = "cooling",
}

local DraconicReactorManager = {
    reactor = {},
    input_flux_gate = {},
    output_flux_gate = {},

    reactor_state = ReactorState.COLD,

    output_flow = 0,

    temperature_goal = 7000,
    temperature = 0,

    -- PID state
    _cap_pid = nil
}

function DraconicReactorManager:new(o, draconic_reactor, input_flux_gate, output_flux_gate, output_energy_detector)
    -- class constructor
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.reactor = draconic_reactor or error("draconic_reactor not set")
    self.input_flux_gate = input_flux_gate or error("input_flux_gate not set")
    self.output_flux_gate = output_flux_gate or error("output_flux_gate not set")

    return o
end

function DraconicReactorManager:handle()
    while true do
        local reactor_info = self.reactor.getReactorInfo()
        if not reactor_info then
            print("Reactor not setup properly. Retrying in 5 seconds...")
            sleep(5)
            goto continue
        end

        -- update output flow
        self.output_flow = reactor_info.generationRate
        self.temperature = reactor_info.temperature

        -- handle reactor based on its current state
        self.reactor_state = reactor_info.status
        if self.reactor_state == ReactorState.COLD then
            self:_handle_cold()
        elseif self.reactor_state == ReactorState.WARMING_UP then
            self:_handle_warming_up()
        elseif self.reactor_state == ReactorState.RUNNING then
            self:_handle_running()
        elseif self.reactor_state == ReactorState.STOPPING then
            self:_handle_stopping()
        elseif self.reactor_state == ReactorState.COOLING then
            self:_handle_cooling()
        else
            print("Unexpected Reactor state: " .. tostring(self.reactor_state))
        end

        sleep(0.2)
        ::continue::
    end
end

function DraconicReactorManager:_handle_cold()
    -- todo: implement
end

function DraconicReactorManager:_handle_warming_up()
    -- speed up warm up by increasing the input flow
    if self.input_flux_gate.getSignalLowFlow() ~= 900000 then
        print("Updating input flow to 900000 RF/t")
        self.input_flux_gate.setSignalLowFlow(900000)
    end

    -- disable output during warmup for safety
    if self.output_flux_gate.getSignalLowFlow() ~= 0 then
        print("Disabling output flow during warm up")
        self.output_flux_gate.setSignalLowFlow(0)
    end

    -- transition to running state once ready
    local reactor_info = self.reactor.getReactorInfo()
    if reactor_info.temperature >= 2000 and reactor_info.temperature <= 2000 * 1.1 then
        print("Activating reactor")
        self.reactor.activateReactor()
    end
end

function DraconicReactorManager:_handle_running()
    local reactor_info = self.reactor.getReactorInfo()

    -- auto adjust input flow
    -- this will prevent the reactor going nuclear even if the temperature reaches max.
    -- the code below expects that infinite energy is available to power the shield
    local current_input_flux_flow = self.input_flux_gate.getFlow()
    local needed_input_flux_flow = reactor_info.fieldDrainRate / (1 - (20 / 100)) -- todo: replace 20 with configurable value
    if current_input_flux_flow ~= needed_flux_flow then
        print("Updating input flux rate " .. current_input_flux_flow .. " RF/t -> " .. needed_input_flux_flow .. " RF/t")
        self.input_flux_gate.setSignalLowFlow(needed_input_flux_flow)
    end

    -- when the reactor is in a stable state, gradually increase the max output flow rate.
    -- if the max output flow is instantly reached, this means the consuming network demands more energy
    -- which in turn means we need to increase the reactor output further
    local current_max_output_flow = self.output_flux_gate.getSignalLowFlow()
    local current_output_flow = reactor_info.generationRate
    local current_temperature = reactor_info.temperature

    -- local current_energy_saturation = reactor_info.energySaturation / 1000000000
    -- if current_output_flow >= (current_max_output_flow * 0.9) and current_energy_saturation > 0.8 then
    if (current_output_flow >= (current_max_output_flow * 0.99) and current_temperature < 7000) or current_max_output_flow <= 0 then
        -- increase max output, energy demands are meet
        local new_max_output_flow = current_max_output_flow + 1000

        print("Updating output flux rate " .. current_max_output_flow .. " RF/t -> " .. new_max_output_flow .. " RF/t")
        self.output_flux_gate.setSignalLowFlow(new_max_output_flow)
    -- elseif current_energy_saturation < 0.5 then
    --     -- decrease max output, energy demands are too high
    --     local new_max_output_flow = current_max_output_flow - 10000

    --     print("Updating output flux rate " .. current_max_output_flow .. " RF/t -> " .. new_max_output_flow .. " RF/t")
    --     self.output_flux_gate.setSignalLowFlow(new_max_output_flow)
    end


    -- safety: shutdown if overheating
    local MAX_TEMPERATURE = 8000
    if reactor_info.temperature >= MAX_TEMPERATURE then
        print("Failsafe: Reactor reached a temperature higher than " .. MAX_TEMPERATURE .. ", shutting down")
        self.reactor.stopReactor()
    end
end

function DraconicReactorManager:_handle_stopping()

end

function DraconicReactorManager:_handle_cooling()

end

return DraconicReactorManager