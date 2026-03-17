
import numpy as np
import pypsa
import math

lambda_DA = 10.52

p_DA = {
    1: 0.0,   2: 0.0,   3: 0.0,   4: 0.0,   5: 0.0,
    6: 0.0,   7: 0.0,   8: 400.0, 9: 400.0, 10: 300.0,
    11: 164.965, 12: 0.0,
    13: 200.0, 14: 200.0, 15: 200.0, 16: 200.0, 17: 200.0, 18: 200.0
}

Pmax = {
    1: 152.0, 2: 152.0, 3: 350.0, 4: 591.0, 5: 60.0, 6: 155.0,
    7: 155.0, 8: 400.0, 9: 400.0, 10: 300.0, 11: 310.0, 12: 350.0,
    13: 200.0, 14: 200.0, 15: 200.0, 16: 200.0, 17: 200.0, 18: 200.0
}

Cg = {
    1: 13.32, 2: 13.32, 3: 20.70, 4: 20.93, 5: 26.11, 6: 10.52,
    7: 10.52, 8: 6.02, 9: 5.47, 10: 0.00, 11: 10.52, 12: 10.89,
    13: 0.00, 14: 0.00, 15: 0.00, 16: 0.00, 17: 0.00, 18: 0.00
}

outage_gen = 11
low_wind = [13, 14, 15]   # 15% below forecast
high_wind = [16, 17, 18]  # 10% above forecast

flex = [1, 2, 3, 4, 5, 6, 7, 11, 12]


p_RT_pre = p_DA.copy()

p_RT_pre[outage_gen] = 0.0

for g in low_wind:
    p_RT_pre[g] = 0.85 * p_DA[g]

for g in high_wind:
    p_RT_pre[g] = 1.10 * p_DA[g]

balancing_need = sum(p_DA[g] - p_RT_pre[g] for g in p_DA)

print(f"Balancing need = {balancing_need:.3f} MW")


up_offer = {g: lambda_DA + 0.1 * Cg[g] for g in flex}
down_offer = {g: lambda_DA - 0.15 * Cg[g] for g in flex}

# Available upward/downward regulation
up_cap = {g: Pmax[g] - p_DA[g] for g in flex}
down_cap = {g: p_DA[g] for g in flex}

# Failed generator cannot provide balancing
available_flex = [g for g in flex if g != outage_gen]


#Clear balancing market
r_up = {g: 0.0 for g in p_DA}
r_down = {g: 0.0 for g in p_DA}
load_curtailment = 0.0

if balancing_need > 0:
    merit_order = sorted(available_flex, key=lambda g: (up_offer[g], g))
    remaining = balancing_need

    for g in merit_order:
        activated = min(up_cap[g], remaining)
        r_up[g] = activated
        remaining -= activated
        if remaining <= 1e-9:
            break

    if remaining > 1e-9:
        load_curtailment = remaining
        lambda_B = 500.0
    else:
        # marginal activated unit
        marginal_gen = max([g for g in merit_order if r_up[g] > 0], key=lambda g: up_offer[g])
        lambda_B = up_offer[marginal_gen]

elif balancing_need < 0:
    merit_order = sorted(available_flex, key=lambda g: (down_offer[g], g), reverse=True)
    remaining = -balancing_need

    for g in merit_order:
        activated = min(down_cap[g], remaining)
        r_down[g] = activated
        remaining -= activated
        if remaining <= 1e-9:
            break

    marginal_gen = min([g for g in merit_order if r_down[g] > 0], key=lambda g: down_offer[g])
    lambda_B = down_offer[marginal_gen]

else:
    lambda_B = lambda_DA

print(f"Balancing price = {lambda_B:.3f} $/MWh")

print("\nActivated upward regulation:")
for g in sorted(r_up):
    if r_up[g] > 1e-9:
        print(f"G{g}: {r_up[g]:.3f} MW")

if load_curtailment > 0:
    print(f"Load curtailment: {load_curtailment:.3f} MW")

p_actual = p_RT_pre.copy()
for g in p_actual:
    p_actual[g] += r_up[g]
    p_actual[g] -= r_down[g]

#Profit calculations
profit_one = {}
profit_two = {}

for g in p_DA:
    revenue_DA = lambda_DA * p_DA[g]
    revenue_BSP = lambda_B * r_up[g] - lambda_B * r_down[g]
    deviation = p_actual[g] - p_DA[g] - r_up[g] + r_down[g]
    production_cost = Cg[g] * p_actual[g]
    imbalance_payment_one = lambda_B * deviation
    profit_one[g] = revenue_DA + revenue_BSP + imbalance_payment_one - production_cost

    if balancing_need > 0:
        if deviation < 0:
            settlement_price = lambda_B
        else:
            settlement_price = lambda_DA
    elif balancing_need < 0:
        if deviation > 0:
            settlement_price = lambda_B
        else:
            settlement_price = lambda_DA
    else:
        settlement_price = lambda_DA

    imbalance_payment_two = settlement_price * deviation
    profit_two[g] = revenue_DA + revenue_BSP + imbalance_payment_two - production_cost

print("\nProfits under one-price and two-price:")
for g in range(1, 19):
    print(
        f"G{g:02d}: "
        f"one-price = {profit_one[g]:10.3f} $   "
        f"two-price = {profit_two[g]:10.3f} $"
    )