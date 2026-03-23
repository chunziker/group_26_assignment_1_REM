using JuMP    # Optimisation modelling framework
using HiGHS   # Free LP solver
using Printf  # Formatted printing (@printf)
using Statistics

# ============================================================
# SECTION 1 – INPUT DATA
# ============================================================

T  = 24   # Hours in the scheduling horizon
nG = 12   # Conventional generators
nW = 6    # Wind farms
nD = 17   # Demand loads

# ----------------------------------------------------------
# 1a. CONVENTIONAL GENERATOR DATA
#     Source: Tables 1-2, IEEE RTS 24-Bus (Ordoudis et al.)
# ----------------------------------------------------------

# Pmax[g]: maximum power output of generator g [MW]
Pmax = [152.0, 152.0, 350.0, 591.0,  60.0, 155.0,
        155.0, 400.0, 400.0, 300.0, 310.0, 350.0]

# RU[g]: maximum ramp-up rate [MW/h] – largest allowed increase
#        in output from one hour to the next
RU = [120.0, 120.0, 350.0, 240.0,  60.0, 155.0,
      155.0, 280.0, 280.0, 300.0, 180.0, 240.0]

# RD[g]: maximum ramp-down rate [MW/h] – largest allowed decrease
RD = [120.0, 120.0, 350.0, 240.0,  60.0, 155.0,
      155.0, 280.0, 280.0, 300.0, 180.0, 240.0]

# Cg[g]: day-ahead offer price [$/MWh], equal to marginal cost
#        (assumption: generators bid truthfully)
Cg = [13.32, 13.32, 20.70, 20.93, 26.11, 10.52,
      10.52,  6.02,  5.47,  0.00, 10.52, 10.89]

# Pini[g]: actual output of generator g just before hour 1 [MW]
#          Used to apply ramp constraints at t = 1.
#          Offline units at the start of the horizon have Pini = 0.
Pini = [ 76.0,  76.0,   0.0,   0.0,   0.0,   0.0,
        124.0, 240.0, 240.0, 240.0, 248.0, 280.0]

# ----------------------------------------------------------
# 1b. LOAD / DEMAND DATA
#     Source: Tables 3-4, IEEE RTS 24-Bus (Ordoudis et al.)
# ----------------------------------------------------------

# Total system demand per hour [MW]
system_demand = [1775.835, 1669.815, 1590.300, 1563.795, 1563.795, 1590.300,
                 1961.370, 2279.430, 2517.975, 2544.480, 2544.480, 2517.975,
                 2517.975, 2517.975, 2464.965, 2464.965, 2623.995, 2650.500,
                 2650.500, 2544.480, 2411.955, 2199.915, 1934.865, 1669.815]

# load_fraction[d]: share of total system demand at load node d [%]
load_fraction = [3.8, 3.4, 6.3, 2.6, 2.5, 4.8, 4.4,
                 6.0, 6.1, 6.8, 9.3, 6.8, 11.1, 3.5,
                 11.7, 6.4, 4.5]

# PD[d, t]: maximum (bid) quantity of load d in hour t [MW]
# Computed as the load's fixed fraction of hourly system demand.
PD = [load_fraction[d] / 100.0 * system_demand[t] for d in 1:nD, t in 1:T]

# Ud[d]: willingness-to-pay (bid price) of load d [$/MWh]
# Must be set higher than the most expensive generator (26.11 $/MWh)
# so that the market clears and demand is served.
# Smaller loads (small fraction) receive higher bids; larger loads
# receive lower bids – consistent with Figure 1 of the sample report.
Ud =[165.0, 155.0, 175.0, 150.0, 145.0, 170.0, 160.0, 180.0, 185.0, 190.0, 210.0, 195.0, 220.0, 158.0, 215.0, 178.0, 162.0]  # Load 17 – node 20 (4.5%)

# ----------------------------------------------------------
# 1c. WIND FARM DATA
#     Source: Appendix, Sample Report (Group 25)
#     One scenario per zone (zones 1-6), hours 1-24 [MW]
# ----------------------------------------------------------

# wind_data[t, w]: available generation of wind farm w in hour t [MW]
wind_data = [
    # Farm: 1       2       3       4       5       6
    384.46 563.37 362.61 202.07 558.26 468.19; # h1
    334.14 556.43 527.93 314.27 548.84 553.79; # h2
    392.11 620.06 533.58 432.35 607.21 574.22; # h3
    320.72 565.90 619.15 452.17 609.68 607.52; # h4
    511.10 662.96 686.13 584.76 663.70 689.71; # h5
    670.20 672.05 709.74 545.10 641.83 701.07; # h6
    732.58 683.56 720.57 627.75 670.87 719.54; # h7
    715.88 690.68 710.55 608.72 658.43 732.09; # h8
    816.48 706.20 714.52 697.07 703.08 717.60; # h9
    863.17 655.94 681.27 730.43 615.06 640.84; # h10
    834.68 684.01 707.80 738.26 631.36 658.99; # h11
    809.60 701.91 671.20 678.32 589.42 683.79; # h12
    779.70 707.42 633.47 588.80 583.27 535.43; # h13
    737.25 705.13 685.57 618.84 605.68 533.90; # h14
    720.23 744.80 691.89 620.54 661.68 625.76; # h15
    745.21 763.06 743.45 646.46 724.46 662.57; # h16
    682.32 727.55 695.04 658.23 678.63 572.37; # h17
    656.48 695.86 657.82 591.17 657.69 520.87; # h18
    734.26 724.75 772.78 684.40 753.31 725.85; # h19
    724.07 771.75 802.11 707.73 731.72 718.83; # h20
    736.49 824.36 835.11 722.33 723.93 661.45; # h21
    631.56 782.89 825.19 729.68 717.15 632.22; # h22
    624.39 815.08 821.35 736.51 669.55 628.15; # h23
    689.31 751.98 772.77 709.17 567.82 552.70; # h24
]# ------------------------------------------------------
# 1d. BATTERY STORAGE DATA
#     Source: Sample Report (Group 25) - Hornsdale Power Reserve
# ----------------------------------------------------------

Cap_BS   = 700.0  # Maximum stored energy (capacity) [MWh]
Ch_rate  =  140  # Maximum charging power in one hour [MW]
Dis_rate =  140  # Maximum discharging power in one hour [MW]
eta_c    =  0.885  # Charging efficiency  (energy stored / energy drawn)
eta_d    =  0.885  # Discharging efficiency (energy delivered / energy taken)
alpha    =   0.0  # Initial state of charge before hour 1 [MWh]

# ============================================================
# SECTION 2 – OPTIMISATION MODEL
# ============================================================

model = Model(HiGHS.Optimizer)
set_silent(model)  # Suppress solver log; delete this line for verbose output

# ----------------------------------------------------------
# Decision Variables
# ----------------------------------------------------------

# pG[g, t]: dispatch of conventional generator g in hour t [MW]
@variable(model, pG[1:nG, 1:T] >= 0)

# pW[w, t]: dispatch of wind farm w in hour t [MW]
@variable(model, pW[1:nW, 1:T] >= 0)

# pD[d, t]: power served to load d in hour t [MW]
@variable(model, pD[1:nD, 1:T] >= 0)

# pCh[t]: battery charging power in hour t [MW]
@variable(model, pCh[1:T] >= 0)

# pDis[t]: battery discharging power in hour t [MW]
@variable(model, pDis[1:T] >= 0)

# SOC[t]: battery state of charge at the end of hour t [MWh]
@variable(model, SOC[1:T] >= 0)

# ----------------------------------------------------------
# Objective – Maximise Social Welfare                (Eq. 6)
# SW = sum_{d,t} Ud*pD[d,t]  -  sum_{g,t} Cg*pG[g,t]
# Wind and battery have zero offer/bid -> no terms for them.
# ----------------------------------------------------------
@objective(model, Max,
    sum(Ud[d] * pD[d, t] for d in 1:nD, t in 1:T)
    - sum(Cg[g] * pG[g, t] for g in 1:nG, t in 1:T)
)

# ----------------------------------------------------------
# Generator capacity bounds                          (Eq. 7)
# 0 <= pG[g,t] <= Pmax[g]   for all g, t
# Lower bound (>= 0) is already encoded in @variable.
# ----------------------------------------------------------
for g in 1:nG, t in 1:T
    @constraint(model, pG[g, t] <= Pmax[g])
end

# ----------------------------------------------------------
# Demand bid quantity bounds                         (Eq. 8)
# 0 <= pD[d,t] <= PD[d,t]   for all d, t
# Demand cannot exceed the submitted bid quantity.
# ----------------------------------------------------------
for d in 1:nD, t in 1:T
    @constraint(model, pD[d, t] <= PD[d, t])
end

# ----------------------------------------------------------
# Wind availability bounds
# 0 <= pW[w,t] <= wind_data[t,w]   for all w, t
# Wind is dispatched up to its forecast; curtailment is allowed.
# ----------------------------------------------------------
for w in 1:nW, t in 1:T
    @constraint(model, pW[w, t] <= min(200, wind_data[t, w]))
end

# ----------------------------------------------------------
# Power balance – copper plate                       (Eq. 9)
# sum_g pG[g,t] + sum_w pW[w,t] + pDis[t]
#     = sum_d pD[d,t] + pCh[t]   for all t
#
# No network -> single node. The dual variable of this constraint
# is the market clearing price (MCP) for each hour.
# The constraint array is stored in 'balance' so duals can be
# retrieved after solving.
# ----------------------------------------------------------
balance = @constraint(model, [t in 1:T],
    sum(pG[g, t] for g in 1:nG)
    + sum(pW[w, t] for w in 1:nW)
    + pDis[t]
    ==
    sum(pD[d, t] for d in 1:nD)
    + pCh[t]
)

# ----------------------------------------------------------
# Ramp-up / ramp-down limits for t >= 2         (Eqs. 10-11)
# pG[g,t] - pG[g,t-1] <=  RU[g]   (cannot ramp up faster than RU)
# pG[g,t] - pG[g,t-1] >= -RD[g]   (cannot ramp down faster than RD)
# Applied to conventional generators only (not wind).
# ----------------------------------------------------------
for g in 1:nG, t in 2:T
    @constraint(model, pG[g, t] - pG[g, t-1] <=  RU[g])
    @constraint(model, pG[g, t] - pG[g, t-1] >= -RD[g])
end

# ----------------------------------------------------------
# Ramp limits at t = 1                          (Eqs. 12-13)
# Same logic but the "previous output" is the fixed Pini[g]
# (the actual pre-horizon dispatch level, not a variable).
# ----------------------------------------------------------
for g in 1:nG
    @constraint(model, pG[g, 1] - Pini[g] <=  RU[g])
    @constraint(model, pG[g, 1] - Pini[g] >= -RD[g])
end

# ----------------------------------------------------------
# Battery state-of-charge upper bound               (Eq. 14)
# SOC[t] <= Cap_BS   for all t
# Lower bound (>= 0) is already encoded in @variable.
# ----------------------------------------------------------
for t in 1:T
    @constraint(model, SOC[t] <= Cap_BS)
end

# ----------------------------------------------------------
# SOC dynamics for t >= 2                           (Eq. 15)
# SOC[t] = SOC[t-1] + eta_c*pCh[t] - (1/eta_d)*pDis[t]
#
# Charging adds energy scaled by charging efficiency.
# Discharging subtracts more stored energy than is delivered
# (1/eta_d > 1 accounts for discharge losses).
# ----------------------------------------------------------
for t in 2:T
    @constraint(model,
        SOC[t] == SOC[t-1] + eta_c * pCh[t] - (1.0 / eta_d) * pDis[t]
    )
end

# ----------------------------------------------------------
# SOC dynamics at t = 1
# Same equation but uses alpha (fixed initial SOC) instead of SOC[t-1].
# ----------------------------------------------------------
@constraint(model,
    SOC[1] == alpha + eta_c * pCh[1] - (1.0 / eta_d) * pDis[1]
)

# ----------------------------------------------------------
# Battery charging power limit                      (Eq. 16)
# pCh[t] <= Ch_rate   for all t
# ----------------------------------------------------------
for t in 1:T
    @constraint(model, pCh[t] <= Ch_rate)
end

# ----------------------------------------------------------
# Battery discharging power limit                   (Eq. 17)
# pDis[t] <= Dis_rate   for all t
# ----------------------------------------------------------
for t in 1:T
    @constraint(model, pDis[t] <= Dis_rate)
end

# ============================================================
# SECTION 3 – SOLVE
# ============================================================

optimize!(model)

println("\n=== SOLVER STATUS ===")
println("Termination status : ", termination_status(model))
println("Primal status      : ", primal_status(model))

# ============================================================
# SECTION 4 – RESULTS
# ============================================================

# ----------------------------------------------------------
# 4a. Market Clearing Prices (MCP)
# The dual of the power balance constraint equals the shadow price
# of one extra MW of supply – this is the uniform market clearing
# price under merit-order dispatch in each hour.
# ----------------------------------------------------------
mcp = [dual(balance[t]) for t in 1:T]   # [$/MWh]

# ----------------------------------------------------------
# 4b. Social Welfare and Total Generation Cost
# ----------------------------------------------------------
SW             = objective_value(model)
total_gen_cost = sum(Cg[g] * value(pG[g, t]) for g in 1:nG, t in 1:T)

# ----------------------------------------------------------
# 4c. Conventional Generator Profits
# Profit_g = sum_t (MCP_t - Cg) * pG*[g,t]
# Under uniform pricing, every generator is paid MCP regardless
# of its own offer. The excess is the infra-marginal rent.
# ----------------------------------------------------------
gen_profit = [sum((mcp[t] - Cg[g]) * value(pG[g, t]) for t in 1:T)
              for g in 1:nG]

# ----------------------------------------------------------
# 4d. Wind Farm Profits
# Wind offers at zero marginal cost -> Profit = sum_t MCP_t * pW*[w,t]
# ----------------------------------------------------------
wind_profit = [sum(mcp[t] * value(pW[w, t]) for t in 1:T) for w in 1:nW]

# ----------------------------------------------------------
# 4e. Battery Profit
# The battery pays MCP when buying (charging) and receives MCP
# when selling (discharging). Net profit over 24 h:
# Profit_BS = sum_t MCP_t * (pDis*[t] - pCh*[t])
# ----------------------------------------------------------
bat_profit = sum(mcp[t] * (value(pDis[t]) - value(pCh[t])) for t in 1:T)

# ----------------------------------------------------------
# 4f. Demand Utility
# Utility_d = sum_t pD*[d,t] * (Ud[d] - MCP_t)
# Consumer surplus: willingness-to-pay minus the price actually paid.
# ----------------------------------------------------------
demand_utility = [sum(value(pD[d, t]) * (Ud[d] - mcp[t]) for t in 1:T)
                  for d in 1:nD]

# ============================================================
# SECTION 5 – PRINT RESULTS
# ============================================================

println("\n====================================================")
println("  COPPER-PLATE MARKET CLEARING RESULTS (24 h)")
println("====================================================")

@printf("\nTotal Social Welfare   : \$%.2f\n", SW)
@printf("Total Generation Cost  : \$%.2f\n", total_gen_cost)

println("\n--- Hourly Market Clearing Prices ---")
println(" Hour | MCP [\$/MWh] | SysDemand [MW] | TotalGen [MW] | SOC [MWh]")
println("------+-------------+----------------+---------------+----------")
for t in 1:T
    gen_t = sum(value(pG[g, t]) for g in 1:nG) +
            sum(value(pW[w, t]) for w in 1:nW)
    @printf(" %3d  |   %7.4f   |   %10.3f   |  %10.3f   |  %6.2f\n",
            t, mcp[t], system_demand[t], gen_t, value(SOC[t]))
end

# ----------------------------------------------------------
# Generator profit table: G1-G12 conventional, G13-G18 wind farms
# Printed as one unified table to match the sample report layout.
# Profits are rounded to the nearest dollar (no decimals).
# ----------------------------------------------------------
println("\n--- Profit of each producer [\$] ---")
println("(Generators 1-12 conventional | Generators 13-18 wind farms)")
println()

# Build combined profit vector: index 1-12 = conventional, 13-18 = wind
all_profit = vcat(gen_profit, wind_profit)   # length 18

# Print first row: generators 1-9
@printf("  %-13s", "Generator")
for i in 1:9;  @printf(" %8d |", i);  end
println()
@printf("  %-13s", "Profit [\$]")
for i in 1:9;  @printf(" %8d |", round(Int, all_profit[i]));  end
println()

println()

# Print second row: generators 10-18
@printf("  %-13s", "Generator")
for i in 10:18;  @printf(" %8d |", i);  end
println()
@printf("  %-13s", "Profit [\$]")
for i in 10:18;  @printf(" %8d |", round(Int, all_profit[i]));  end
println()

@printf("\n--- Battery Profit : \$%d ---\n", round(Int, bat_profit))

println("\n--- Demand Utility [\$] ---")
for d in 1:nD
    @printf("  Load %-2d : \$%d\n", d, round(Int, demand_utility[d]))
end

println("\n====================================================")
@printf("Cross-check: SW = producer profits + consumer utility\n")
@printf("  Sum gen profits  : \$%d\n", round(Int, sum(gen_profit)))
@printf("  Sum wind profits : \$%d\n", round(Int, sum(wind_profit)))
@printf("  Battery profit   : \$%d\n", round(Int, bat_profit))
@printf("  Sum utilities    : \$%d\n", round(Int, sum(demand_utility)))
@printf("  Total            : \$%d  (objective = \$%d)\n",
        round(Int, sum(gen_profit) + sum(wind_profit) + bat_profit + sum(demand_utility)),
        round(Int, SW))
println("====================================================")


# ------------------------------------------
# Sensitivity analysis: 
# What happens when the storage size, charging/discharging power increase or decrease? Why?
# ------------------------------------------

# ============================================================
# SECTION SA – SENSITIVITY ANALYSIS (Cap_BS, Ch_rate, Dis_rate)
# ============================================================


# (1) Define a function that builds and solves the model for given storage parameters.
function solve_case(Cap_BS_case::Float64, Ch_rate_case::Float64, Dis_rate_case::Float64)

    # (2) Create a fresh model for this scenario.
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # (3) Decision variables (same as your base model).
    @variable(model, pG[1:nG, 1:T] >= 0)
    @variable(model, pW[1:nW, 1:T] >= 0)
    @variable(model, pD[1:nD, 1:T] >= 0)
    @variable(model, pCh[1:T] >= 0)
    @variable(model, pDis[1:T] >= 0)
    @variable(model, SOC[1:T] >= 0)

    # (4) Objective: maximise social welfare (same formula).
    @objective(model, Max,
        sum(Ud[d] * pD[d, t] for d in 1:nD, t in 1:T)
        - sum(Cg[g] * pG[g, t] for g in 1:nG, t in 1:T)
    )

    # (5) Generator capacity constraints.
    for g in 1:nG, t in 1:T
        @constraint(model, pG[g, t] <= Pmax[g])
    end

    # (6) Demand bid quantity constraints.
    for d in 1:nD, t in 1:T
        @constraint(model, pD[d, t] <= PD[d, t])
    end

    # (7) Wind availability constraints (your min(200, wind_data) cap kept).
    for w in 1:nW, t in 1:T
        @constraint(model, pW[w, t] <= min(200, wind_data[t, w]))
    end

    # (8) Power balance constraints; store them to read MCP duals later.
    balance = @constraint(model, [t in 1:T],
        sum(pG[g, t] for g in 1:nG)
        + sum(pW[w, t] for w in 1:nW)
        + pDis[t]
        ==
        sum(pD[d, t] for d in 1:nD)
        + pCh[t]
    )

    # (9) Ramp constraints for t >= 2.
    for g in 1:nG, t in 2:T
        @constraint(model, pG[g, t] - pG[g, t-1] <=  RU[g])
        @constraint(model, pG[g, t] - pG[g, t-1] >= -RD[g])
    end

    # (10) Ramp constraints at t = 1, using Pini.
    for g in 1:nG
        @constraint(model, pG[g, 1] - Pini[g] <=  RU[g])
        @constraint(model, pG[g, 1] - Pini[g] >= -RD[g])
    end

    # (11) Battery SOC upper bound constraints (scenario-specific Cap_BS_case).
    #      Store constraints to access their duals (shadow prices) later.
    soc_cap = @constraint(model, [t in 1:T], SOC[t] <= Cap_BS_case)

    # (12) SOC dynamics for t >= 2.
    for t in 2:T
        @constraint(model, SOC[t] == SOC[t-1] + eta_c * pCh[t] - (1.0 / eta_d) * pDis[t])
    end

    # (13) SOC dynamics at t = 1 (uses alpha).
    @constraint(model, SOC[1] == alpha + eta_c * pCh[1] - (1.0 / eta_d) * pDis[1])

    # (14) Charging power limit constraints (scenario-specific Ch_rate_case).
    #      Store constraints to access their duals later.
    ch_cap = @constraint(model, [t in 1:T], pCh[t] <= Ch_rate_case)

    # (15) Discharging power limit constraints (scenario-specific Dis_rate_case).
    #      Store constraints to access their duals later.
    dis_cap = @constraint(model, [t in 1:T], pDis[t] <= Dis_rate_case)

    # (16) Solve the optimisation for this scenario.
    optimize!(model)

    # (17) Safety check: ensure solved to optimality (you can relax if needed).
    term = termination_status(model)
    if term != MOI.OPTIMAL
        return (ok=false, term=term)
    end

    # (18) Extract MCP as dual of balance constraints (one per hour).
    mcp = [dual(balance[t]) for t in 1:T]

    # (19) Extract objective (social welfare).
    SW = objective_value(model)

    # (20) Extract total generation cost (only conventional gens).
    total_gen_cost = sum(Cg[g] * value(pG[g, t]) for g in 1:nG, t in 1:T)

    # (21) Battery profit (buys at MCP when charging, sells at MCP when discharging).
    bat_profit = sum(mcp[t] * (value(pDis[t]) - value(pCh[t])) for t in 1:T)

    # (22) Useful storage utilisation summaries.
    soc_max = maximum(value.(SOC))
    soc_end = value(SOC[T])
    total_charge = sum(value.(pCh))
    total_dis = sum(value.(pDis))

    # (23) Shadow-price diagnostics:
    #      If these are often > 0, the corresponding constraint is binding and valuable.
    #      NOTE: For maximisation, dual signs can be counterintuitive; use magnitude + binding logic.
    sum_soc_duals  = sum(dual(soc_cap[t]) for t in 1:T)
    sum_ch_duals   = sum(dual(ch_cap[t]) for t in 1:T)
    sum_dis_duals  = sum(dual(dis_cap[t]) for t in 1:T)

    # (24) Return everything as a NamedTuple (easy to store in arrays).
    return (
        ok=true,
        term=term,
        Cap_BS=Cap_BS_case,
        Ch_rate=Ch_rate_case,
        Dis_rate=Dis_rate_case,
        SW=SW,
        total_gen_cost=total_gen_cost,
        bat_profit=bat_profit,
        mcp_avg=mean(mcp),
        mcp_max=maximum(mcp),
        soc_max=soc_max,
        soc_end=soc_end,
        total_charge=total_charge,
        total_dis=total_dis,
        sum_soc_duals=sum_soc_duals,
        sum_ch_duals=sum_ch_duals,
        sum_dis_duals=sum_dis_duals
    )
end


# (25) Choose multiplicative factors for sensitivity (e.g., -50%, -25%, base, +25%, +50%).
factors = [0.5, 0.75, 1.0, 1.25, 1.5]

# (26) Store baseline values so we can scale them.
Cap0 = Float64(Cap_BS)
Ch0  = Float64(Ch_rate)
Dis0 = Float64(Dis_rate)

# (27) Run OAT (one-at-a-time) sensitivity: vary ONE parameter, keep others at baseline.
results = NamedTuple[]   # a simple vector to collect scenario outputs

# (28) Vary energy capacity only.
for f in factors
    push!(results, solve_case(Cap0*f, Ch0, Dis0))
end

# (29) Vary charging power only.
for f in factors
    push!(results, solve_case(Cap0, Ch0*f, Dis0))
end

# (30) Vary discharging power only.
for f in factors
    push!(results, solve_case(Cap0, Ch0, Dis0*f))
end

# (31) Print a compact results table.
println("\n====================================================")
println("  SENSITIVITY RESULTS (OAT): Cap_BS, Ch_rate, Dis_rate")
println("====================================================")
println(" Case | Cap_BS | Ch_rate | Dis_rate |    SW     | GenCost  | BatProf | MCPavg | MCPmax | SOCmax")
println("------+--------+---------+----------+----------+----------+---------+--------+--------+-------")

case_id = 0
for (case_id, r) in enumerate(results)
    if !r.ok
        @printf(" %4d | (infeasible/failed) termination=%s\n", case_id, string(r.term))
        continue
    end
    @printf(" %4d | %6.1f | %7.1f | %8.1f | %8.2f | %8.2f | %7.2f | %6.2f | %6.2f | %6.1f\n",
        case_id, r.Cap_BS, r.Ch_rate, r.Dis_rate, r.SW, r.total_gen_cost, r.bat_profit, r.mcp_avg, r.mcp_max, r.soc_max
    )
end

# (32) Optional: show “which constraint matters” via summed duals (diagnostic, not perfect).
println("\n--- Dual (shadow price) diagnostics (sum over t) ---")
println("Larger magnitude typically => constraint binding more often => parameter more valuable.")
println("Case | sum_dual(SOC<=Cap) | sum_dual(pCh<=Ch) | sum_dual(pDis<=Dis)")
println("-----+---------------------+------------------+-------------------")
case_id = 0
for (case_id, r) in enumerate(results)
    if !r.ok
        continue
    end
    @printf("%4d | %19.4f | %16.4f | %17.4f\n",
        case_id, r.sum_soc_duals, r.sum_ch_duals, r.sum_dis_duals
    )
end
