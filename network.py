class Generator:
    def __init__(
        self,
        unit_id: int,
        node: int,
        p_max: float,
        p_min: float,
        r_up: float,
        r_down: float,
        ramp_up: float,
        ramp_down: float,
        min_up: int,
        min_down: int,
        cost_energy: float,
        cost_up_reserve: float,
        cost_down_reserve: float,
        cost_up_reg: float,
        cost_down_reg: float,
        startup_cost: float,
        p_init: float,
        u_init: int,
        t_init: int,
    ):
        self.unit_id = unit_id
        self.node = node

        # technical limits
        self.p_max = p_max
        self.p_min = p_min
        self.r_up = r_up
        self.r_down = r_down
        self.ramp_up = ramp_up
        self.ramp_down = ramp_down
        self.min_up = min_up
        self.min_down = min_down

        # costs
        self.cost_energy = cost_energy
        self.cost_up_reserve = cost_up_reserve
        self.cost_down_reserve = cost_down_reserve
        self.cost_up_reg = cost_up_reg
        self.cost_down_reg = cost_down_reg
        self.startup_cost = startup_cost

        # initial state
        self.p_init = p_init
        self.u_init = u_init
        self.t_init = t_init

    def __repr__(self):
        return f"Generator(unit={self.unit_id}, node={self.node})"
    
generators = [
    Generator(1,  1, 152, 30.4, 40, 40, 120, 120, 8, 4, 13.32, 15, 14, 15, 11, 1430.4, 76, 1, 22),
    Generator(2,  2, 152, 30.4, 40, 40, 120, 120, 8, 4, 13.32, 15, 14, 15, 11, 1430.4, 76, 1, 22),
    Generator(3,  7, 350, 75,   70, 70, 350, 350, 8, 8, 20.7,  10, 9,  24, 16, 1725,   0,  0, -2),
    Generator(4, 13, 591, 206.85,180,180,240,240,12,10,20.93, 8,  7,  25, 17, 3056.7, 0,  0, -1),
    Generator(5, 15, 60,  12,   60, 60, 60,  60,  4, 2, 26.11, 7,  5,  28, 23, 437,    0,  0, -1),
    Generator(6, 15, 155, 54.25,30, 30, 155,155,8, 8, 10.52,16, 14, 16, 7,  312,    0,  0, -2),
    Generator(7, 16, 155, 54.25,30, 30, 155,155,8, 8, 10.52,16, 14, 16, 7,  312,   124, 1, 10),
    Generator(8, 18, 400, 100,  0,  0,  280,280,1, 1, 6.02, 0,  0,  0,  0,  0,     240, 1, 50),
    Generator(9, 21, 400, 100,  0,  0,  280,280,1, 1, 5.47, 0,  0,  0,  0,  0,     240, 1, 16),
    Generator(10,22, 300, 300,  0,  0,  300,300,0, 0, 0,    0,  0,  0,  0,  0,     240, 1, 24),
    Generator(11,23, 310, 108.5,60, 60, 180,180,8, 8, 10.52,17, 16, 14, 8,  624,   248, 1, 10),
    Generator(12,23, 350, 140,  40, 40, 240,240,8, 8, 10.89,16, 14, 16, 8,  2298,  280, 1, 50),
]

class Consumer:
    def __init__(self, load_id: int, node: int, share: float):
        self.load_id = load_id
        self.node = node
        self.share = share  # Anteil an der Systemlast (z. B. 0.038)

        # wird später befüllt
        self.demand_time_series = {}

    def set_hourly_demand(self, system_demand):
        """
        system_demand: dict {hour: MW}
        """
        self.demand_time_series = {
            h: self.share * d for h, d in system_demand.items()
        }

    def __repr__(self):
        return f"Consumer(load={self.load_id}, node={self.node}, share={self.share})"


system_demand = {
    1: 1775.835,
    2: 1669.815,
    3: 1590.300,
    4: 1563.795,
    5: 1563.795,
    6: 1590.300,
    7: 1961.370,
    8: 2279.430,
    9: 2517.975,
    10: 2544.480,
    11: 2544.480,
    12: 2517.975,
    13: 2517.975,
    14: 2517.975,
    15: 2464.965,
    16: 2464.965,
    17: 2623.995,
    18: 2650.500,
    19: 2650.500,
    20: 2544.480,
    21: 2411.955,
    22: 2199.915,
    23: 1934.865,
    24: 1669.815,
}

consumers = [
    Consumer(1,  1,  0.038),
    Consumer(2,  2,  0.034),
    Consumer(3,  3,  0.063),
    Consumer(4,  4,  0.026),
    Consumer(5,  5,  0.025),
    Consumer(6,  6,  0.048),
    Consumer(7,  7,  0.044),
    Consumer(8,  8,  0.060),
    Consumer(9,  9,  0.061),
    Consumer(10, 10, 0.068),
    Consumer(11, 13, 0.093),
    Consumer(12, 14, 0.068),
    Consumer(13, 15, 0.111),
    Consumer(14, 16, 0.035),
    Consumer(15, 18, 0.117),
    Consumer(16, 19, 0.064),
    Consumer(17, 20, 0.045),
]

def initialize_consumers(consumers, system_demand):
    for consumer in consumers:
        consumer.set_hourly_demand(system_demand)
    return consumers


def initialize_network():
    consumers_initialized = initialize_consumers(consumers, system_demand)
    return consumers_initialized, generators

