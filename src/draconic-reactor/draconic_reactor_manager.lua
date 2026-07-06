local ReactorState = {
    COLD = "cold",
    WARMING_UP = "warming_up",
    RUNNING = "running",
    STOPPING = "stopping",
    COOLING = "cooling",
    BEYOND_HOPE = "beyond_hope",
}

local DraconicReactorManager = {
    reactor = {},
    input_flux_gate = {},
    output_flux_gate = {},

    reactor_state = ReactorState.COLD,

    output_flow = 0,

    field_strength = 0,
    field_strength_goal = 0.35,
    field_strength_minimum = 0.10, -- minimum required field strength before triggering meltdown protection

    temperature = 0,
    temperature_goal = 7500,

    fuel_conversion = 0,
    fuel_conversion_max = 0.85, -- maximum allowed fuel conversion before triggering meltdown protection

    -- Check "Mod Options > Draconic Evolution > Tweaks > reactorOutputMultiplier" to find what it is.
    reactor_output_multiplier = 1,

    _field_integral = 0
}

function DraconicReactorManager:new(instance, draconic_reactor, input_flux_gate, output_flux_gate)
    -- class constructor
    instance = instance or {}
    setmetatable(instance, self)
    self.__index = self

    self.reactor = draconic_reactor or error("draconic_reactor not set")
    self.input_flux_gate = input_flux_gate or error("input_flux_gate not set")
    self.output_flux_gate = output_flux_gate or error("output_flux_gate not set")

    return instance
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
        self.reactor_state = reactor_info.status
        self.output_flow = reactor_info.generationRate
        self.temperature = reactor_info.temperature
        self.fuel_conversion = reactor_info.fuelConversion / reactor_info.maxFuelConversion

        -- handle reactor states
        if reactor_info.status == ReactorState.COLD then
            -- do nothing
        elseif reactor_info.status == ReactorState.WARMING_UP then
            self:_handle_warming_up(reactor_info)
        elseif reactor_info.status == ReactorState.RUNNING then
            self:_handle_running(reactor_info)
        elseif reactor_info.status == ReactorState.STOPPING then
            self:_handle_stopping(reactor_info)
        elseif reactor_info.status == ReactorState.COOLING then
            self:_handle_cooling(reactor_info)
        elseif reactor_info.status == ReactorState.BEYOND_HOPE then
            self:_handle_beyond_hope(reactor_info)
        end

        sleep(0.025)
        ::continue::
    end
end

function DraconicReactorManager:_handle_warming_up(reactor_info)
    -- 9 million RF/t seems to be what the community decided as the standard for input flow during warm up
    local INPUT_FLOW_RATE = 9000000

    self.input_flux_gate.setSignalLowFlow(INPUT_FLOW_RATE)
    self.output_flux_gate.setSignalLowFlow(0)

    -- automatically activate the reactor once its ready
    self.reactor.activateReactor()

    -- reset _field_integral due to state change
    self._field_integral = 0
end

function DraconicReactorManager:_handle_running(reactor_info)
    -- I think the code in this method needs some explanation:
    -- Why are we doing all these calculations? We try to predict the energy consumption the reactor needs in order to 
    -- maintain the containment field at our desired field strength. For this we pre-calculate how the reactor behaves
    -- With our desired temperature and the current state the reactor is in.
    -- Once we did that we additionally utilize a PI term (not PID) to try to counter rapid changes in the resulting
    -- input rate variation. This should allow us to survive rapid output rate changes (800k RF/t to 5.5M RF/t) without
    -- letting the reactor going instantly nuclear.

    -- the calculations below are directly taken from the mod sourcecode
    -- START MOD_CALCULATIONS
    local MAX_TEMPERATURE = 10000

    local core_saturation = reactor_info.energySaturation / reactor_info.maxEnergySaturation    -- reactor saturation percent. range: 0.0 - 1.0
    local negative_saturation_percentage = (1 - core_saturation) * 99                           -- negative reactor saturation. range: 0 - 99

    local total_fuel = reactor_info.maxFuelConversion                                           -- total fuel
    local conversion_level = ((reactor_info.fuelConversion / total_fuel) * 1.3) - 0.3           -- conversion level boosts power gen. range: -0.3 - 1.0

    -- local temperature_cap_50 = math.min((reactor_info.temperature / MAX_TEMPERATURE) * 50, 99)  -- ?? original comment by mod author: "50 = Max Temp. Why? TBD"
    local temperature_cap_50 = math.min((self.temperature_goal / MAX_TEMPERATURE) * 50, 99)

    -- temperature calculation
    local temperature_offset = 444.7                                                            -- adjusts where the temp falls to at 100% saturation
    local temperature_rise_exponential = (negative_saturation_percentage ^ 3) / (100 - negative_saturation_percentage) + temperature_offset     -- the exponential temperature rise which increases as the core saturation
    local temperature_rise_resist = (temperature_cap_50 ^ 4) / (100 - temperature_cap_50)                                                       -- this is used to add resistance as the temp rises

    -- merge temperature calculation into rise amount
    local temperature_rise_amount = (temperature_rise_exponential - (temperature_rise_resist * (1 - conversion_level)) + conversion_level * 1000) / 10000

    -- energy calculation
    local energy_base_max_RFt = math.ceil((reactor_info.maxEnergySaturation / 1000) * self.reactor_output_multiplier * 1.5 * 10)
    local energy_max_RFt = math.ceil(energy_base_max_RFt * (1 + (conversion_level * 2)))

    local energy_generation_rate = (1 - core_saturation) * energy_max_RFt -- unused, just for clarity

    -- field calculation
    local field_temp_drain_factor = 0
    if reactor_info.temperature > 8000 then
        field_temp_drain_factor = 1 + ((reactor_info.temperature - 8000) * (reactor_info.temperature - 8000) * 0.0000025)
    elseif reactor_info.temperature > 2000 then
        field_temp_drain_factor = 1
    elseif reactor_info.temperature > 1000 then
        field_temp_drain_factor = (reactor_info.temperature  - 1000) / 1000
    end

    local field_drain = math.ceil(math.min(field_temp_drain_factor * math.max(0.01, (1 - core_saturation)) * (energy_base_max_RFt / 10.923556), 2147000000))
    local field_strength = reactor_info.fieldStrength - math.min(field_drain, reactor_info.fieldStrength) -- unused, just for clarity

    -- fuel calculation
    local fuel_use_rate = field_temp_drain_factor * (1 - core_saturation) * (0.001 * self.reactor_output_multiplier * 5) -- unused, just for clarity

    -- END MOD_CALCULATIONS


    -- calculate input flow
    local field_strength_error = (reactor_info.maxFieldStrength * self.field_strength_goal) - field_strength
    local field_required_input = math.min((reactor_info.maxFieldStrength * field_drain) / (reactor_info.maxFieldStrength - field_strength), reactor_info.maxFieldStrength - field_strength)

    -- integral term
    local Kp = 0.15
    local Ki = 0.01 * 0.025
    self._field_integral = math.max(-reactor_info.maxFieldStrength, math.min(reactor_info.maxFieldStrength, self._field_integral + field_strength_error))
    local field_correction = (Kp * field_strength_error) + (Ki * self._field_integral)

    local input_flow = math.max(0, math.min(field_correction + field_required_input, reactor_info.maxFieldStrength))

    -- calculate output flow
    local target_temperature_exponential = -(temperature_rise_resist * conversion_level) - 1000 * conversion_level + temperature_rise_resist
    local term1 = 1334.1 - (3 * target_temperature_exponential)
    local term2 = (1200690 - (2700 * target_temperature_exponential)) ^ 2
    local term3 = ((-1350 * target_temperature_exponential) + (((-4 * term1 ^ 3 + term2) ^ (1 / 2)) / 2) + 600345) ^ (1 / 3)
    local target_negative_core_saturation = -(term1/(3*term3))-(term3/3)

    local core_saturation_target = 1 - (target_negative_core_saturation/99)
    local saturation_target = core_saturation_target * reactor_info.maxEnergySaturation
    local saturation_error = reactor_info.energySaturation - saturation_target
    local output_flow = math.max(0, math.min(saturation_error, (reactor_info.maxEnergySaturation / 40)) + reactor_info.generationRate)

    -- automatically shutdown when fuel conversion reaches limit
    if (reactor_info.fuelConversion / reactor_info.maxFuelConversion) >= self.fuel_conversion_max then
        self.reactor.stopReactor()
    end

    -- automatically shutdown when containment field drops below accepted minimum
    if (reactor_info.fieldStrength / reactor_info.maxFieldStrength) < self.field_strength_minimum then
        self.reactor.stopReactor()
    end

    -- update flux gates
    self.output_flux_gate.setSignalLowFlow(output_flow)
    self.input_flux_gate.setSignalLowFlow(input_flow)
end

function DraconicReactorManager:_handle_stopping(reactor_info)
    -- reset _field_integral due to state change
    self._field_integral = 0

    -- during shutdown it's normally not necessary to rapidly adjust to output changes (output is force to 0 RF/t),
    -- so we can just derive the optimal input flow from the current field drain rate
    self.output_flux_gate.setSignalLowFlow(0)
    self.input_flux_gate.setSignalLowFlow(reactor_info.fieldDrainRate / (1 - self.field_strength_goal))
end

function DraconicReactorManager:_handle_cooling(reactor_info)
    -- we can just cut the input power here, the core will not consume any energy anyways
    self.output_flux_gate.setSignalLowFlow(0)
    self.input_flux_gate.setSignalLowFlow(0)
end

function DraconicReactorManager:_handle_beyond_hope(reactor_info)
    -- this is where something like a auto clicker from just dire things could be use to auto "contain" the reactor
    -- at this point the core is literally "beyond hope"
end

return DraconicReactorManager