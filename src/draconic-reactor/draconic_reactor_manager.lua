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

    field_strength = 0,
    field_strength_goal = 0.30,

    temperature = 0,
    temperature_goal = 7500,

    -- Check "Mod Options > Draconic Evolution > Tweaks > reactorOutputMultiplier" to find what it is.
    reactor_output_multiplier = 1,
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
            print("Reactor not setup properly. Retrying in 5 seconds...")
            sleep(5)
            goto continue
        end

        -- update output flow
        self.reactor_state = reactor_info.state
        self.output_flow = reactor_info.generationRate
        self.temperature = reactor_info.temperature

        self:_handle_io(reactor_info)

        sleep(0.025)
        ::continue::
    end
end

function DraconicReactorManager:_handle_io(reactor_info)
    local MAX_TEMPERATURE = 10000

    -- the calculations below are directly taken from the mod sourcecode
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
    local field_percent = reactor_info.fieldStrength / reactor_info.maxFieldStrength
    local field_input_rate = field_drain / (1 - field_percent)

    local field_strength = reactor_info.fieldStrength - math.min(field_drain, reactor_info.fieldStrength) -- unused, just for clarity

    -- fuel calculation
    local fuel_use_rate = field_temp_drain_factor * (1 - core_saturation) * (0.001 * self.reactor_output_multiplier * 5) -- unused, just for clarity


    -- calculate input flow
    local field_strength_error = (reactor_info.maxFieldStrength * self.field_strength_goal) - field_strength
    local field_required_input = math.min((reactor_info.maxFieldStrength * field_drain) / (reactor_info.maxFieldStrength - field_strength), reactor_info.maxFieldStrength - field_strength)
    local input_flow = math.min(field_strength_error + field_required_input, reactor_info.maxFieldStrength)


    -- calculate output flow
    local target_temperature_exponential = -(temperature_rise_resist * conversion_level) - 1000 * conversion_level + temperature_rise_resist
    local term1 = 1334.1 - (3 * target_temperature_exponential)
    local term2 = (1200690 - (2700 * target_temperature_exponential)) ^ 2
    local term3 = ((-1350 * target_temperature_exponential) + (((-4 * term1 ^ 3 + term2) ^ (1 / 2)) / 2) + 600345) ^ (1 / 3)
    local target_negative_core_saturation = -(term1/(3*term3))-(term3/3)

    local core_saturation_target = 1 - (target_negative_core_saturation/99)
    local saturation_target = core_saturation_target * reactor_info.maxEnergySaturation
    local saturation_error = reactor_info.energySaturation - saturation_target
    local output_flow = math.min(saturation_error, (reactor_info.maxEnergySaturation / 40)) + reactor_info.generationRate

    self.output_flux_gate.setSignalLowFlow(output_flow)
    self.input_flux_gate.setSignalLowFlow(input_flow)

    -- test
    local targetTempExpo = -(temperature_rise_resist * conversion_level) - 1000 * conversion_level + temperature_rise_resist

    print("")
    print("")
    print("")
    print("")
    print("")
    print("")
    print("")
    print("")
    print("")
    print("")
    print("")
    print("EXPECTED")
    print("energySaturation             " .. reactor_info.energySaturation)
    print("generationRate               " .. reactor_info.generationRate)
    print("fieldDrainRate               " .. reactor_info.fieldDrainRate)
    print("")
    print("RESULT")
    print("output_flow                  " .. output_flow)
    print("input_flow                   " .. input_flow)
    print("field_temp_drain_factor      " .. field_temp_drain_factor)
    print("")
    print("INPUT")
    print("field_strength_error         " .. field_strength_error)
    print("field_required_input         " .. field_required_input)
    print("")
    print("OUTPUT")
    print("target_negative_core_saturation " .. math.ceil(target_negative_core_saturation * 100000) / 100000)
    
end

return DraconicReactorManager