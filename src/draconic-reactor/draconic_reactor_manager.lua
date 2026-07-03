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

    -- todo: output goal
}

function DraconicReactorManager:new(o, draconic_reactor, input_flux_gate, output_flux_gate)
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
            print("DEBUG: Failed to get Reactor Info!")
            goto continue
        end

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
            print("Unexpected Reactor state: " .. self.reactor_state)
        end

        ::continue::
        sleep(0.2)
    end
end

function DraconicReactorManager:_handle_cold()

end

function DraconicReactorManager:_handle_warming_up()
    if self.input_flux_gate.getSignalLowFlow() < 900000 then
        -- speed up warm up by increasing the input flow
        print("Updating Reactor Input flow to 900000 RF/t")
        self.input_flux_gate.setSignalLowFlow(900000)
    end
end

function DraconicReactorManager:_handle_running()

end

function DraconicReactorManager:_handle_stopping()

end

function DraconicReactorManager:_handle_cooling()

end

return DraconicReactorManager