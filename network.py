class Generator:
    def __init__(
        self,
        unit_id: int,
        node: int,
        p_max: float = None,
        p_min: float = None,
        r_up: float = None,
        r_down: float = None,
        ramp_up: float = None,
        ramp_down: float = None,
        min_up: int = None,
        min_down: int = None,
        cost_energy: float = None,
        cost_up_reserve: float = None,
        cost_down_reserve: float = None,
        cost_up_reg: float = None,
        cost_down_reg: float = None,
        startup_cost: float = None,
        p_init: float = None,
        u_init: int = None,
        t_init: int = None,
    ):
        self.unit_id = unit_id
        self.node = node
        self.p_max = p_max
        self.p_min = p_min
        self.r_up = r_up
        self.r_down = r_down
        self.ramp_up = ramp_up
        self.ramp_down = ramp_down
        self.min_up = min_up
        self.min_down = min_down
        self.cost_energy = cost_energy
        self.cost_up_reserve = cost_up_reserve
        self.cost_down_reserve = cost_down_reserve
        self.cost_up_reg = cost_up_reg
        self.cost_down_reg = cost_down_reg
        self.startup_cost = startup_cost
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
    Generator(unit_id= 13, node= 3, p_max = 200, cost_energy= 0),
    Generator(unit_id= 14, node= 5, p_max = 200, cost_energy= 0),
    Generator(unit_id= 15, node= 7, p_max = 200, cost_energy= 0),
    Generator(unit_id= 16, node= 16, p_max = 200, cost_energy= 0),
    Generator(unit_id= 17, node= 21, p_max = 200, cost_energy= 0),
    Generator(unit_id= 18, node= 23, p_max = 200, cost_energy= 0)
]

class Consumer:
    def __init__(self, load_id: int, node: int, price: float, share: float):
        self.load_id = load_id
        self.node = node
        self.price = price
        self.share = share  # Anteil an der Systemlast (z. B. 0.038)

        # wird später befüllt
        self.demand_time_series = {}
        # wird später befüllt: stündliche Gebotspreise
        self.demand_price_time_series = {}

    def set_hourly_demand(self, system_demand):
        """
        system_demand: dict {hour: MW}
        """
        self.demand_time_series = {
            h: self.share * d for h, d in system_demand.items()
        }

    def set_hourly_price(self, peak_hours=(17, 18, 19, 20)):
        """Erzeuge stündliche Gebotspreise; höhere Preise während Spitzenstunden."""
        prices = {}
        for h in range(1, 25):
            # Basispreis ist self.price; erhöhe während Spitzenzeiten
            if h in peak_hours:
                prices[h] = round(self.price * 1.5, 2)
            elif 8 <= h <= 16:
                prices[h] = round(self.price * 1.2, 2)
            else:
                prices[h] = round(self.price * 0.9, 2)
        self.demand_price_time_series = prices

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

# realistic (comparatively high) demand bids in
consumers = [
    Consumer(1,  1,  165.0, 0.038),
    Consumer(2,  2,  155.0, 0.034),
    Consumer(3,  3,  175.0, 0.063),
    Consumer(4,  4,  150.0, 0.026),
    Consumer(5,  5,  145.0, 0.025),
    Consumer(6,  6,  170.0, 0.048),
    Consumer(7,  7,  160.0, 0.044),
    Consumer(8,  8,  180.0, 0.060),
    Consumer(9,  9,  185.0, 0.061),
    Consumer(10, 10, 190.0, 0.068),
    Consumer(11, 13, 210.0, 0.093),
    Consumer(12, 14, 195.0, 0.068),
    Consumer(13, 15, 220.0, 0.111),
    Consumer(14, 16, 158.0, 0.035),
    Consumer(15, 18, 215.0, 0.117),
    Consumer(16, 19, 178.0, 0.064),
    Consumer(17, 20, 162.0, 0.045),
]


def initialize_consumers(consumers, system_demand):
    for consumer in consumers:
        consumer.set_hourly_demand(system_demand)
        consumer.set_hourly_price()
    return consumers


def initialize_network():
    consumers_initialized = initialize_consumers(consumers, system_demand)
    # time horizon
    T = 24

    # simple synthetic wind generation profile (MW) -- higher midday
    wind_time_series = {
        t: round(200 * max(0.2, (1 - abs((t - 13) / 8))), 3) for t in range(1, T + 1)
    }
    return consumers_initialized, generators


LINES = [
    (1, 2, 175),
    (1, 3, 175),
    (1, 5, 350),
    (2, 4, 175),
    (2, 6, 175),
    (3, 9, 175),
    (3, 24, 400),
    (4, 9, 175),
    (5, 10, 350),
    (6, 10, 175),
    (7, 8, 350),
    (8, 9, 175),
    (8, 10, 175),
    (9, 11, 400),
    (9, 12, 400),
    (10, 11, 400),
    (10, 12, 400),
    (11, 13, 500),
    (11, 14, 500),
    (12, 13, 500),
    (12, 23, 500),
    (13, 23, 500),
    (14, 16, 500),
    (15, 16, 500),
    (15, 21, 1000),
    (15, 24, 500),
    (16, 17, 500),
    (16, 19, 500),
    (17, 18, 500),
    (17, 22, 500),
    (18, 21, 1000),
    (19, 20, 1000),
    (20, 23, 1000),
    (21, 22, 500),
]

