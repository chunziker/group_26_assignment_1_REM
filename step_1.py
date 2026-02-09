
import gurobipy as gp
from gurobipy import GRB
from network import initialize_network, system_demand


consumers, generators = initialize_network()
print(generators)

print("Network initialized successfully.")

# define the demand
# time at 16:00
total_consumption_16 = system_demand[16]
print(f"Total consumption at 16:00 is {total_consumption_16} MW")
id_Gnerators = []
for i in generators:
    id_Gnerators.append(i.unit_id)
print(id_Gnerators)

# define the supply
#Variable generators costs 
generator_cost = []
for i in generators:
    
    generator_cost.append(i.cost_energy)

#Generators capacity
generator_capacity = []
for i in generators:
    generator_capacity.append(i.p_max)
print(generator_capacity)

#create the optimization model
model = gp.Model("Economic_Dispatch_Model")

#create decision variables
production_variables = [model.addVar(lb=0, ub = float('inf'), vtype=GRB.CONTINUOUS, name=f"p_{i.unit_id}") for i in generators]


#add constraint
balance_constraint = model.addLConstr(gp.quicksum(production_variables[i] for i in range(len(generators))) == total_consumption_16, name="balance")
capacity_constraints = [model.addLConstr(production_variables[i], GRB.LESS_EQUAL, generator_capacity[i], name=f"capacity_{i}") for i in range(len(generators))]

# set objective function
model.setObjective(gp.quicksum(generator_cost[i] * production_variables[i] for i in range(len(generators))), GRB.MINIMIZE)

model.optimize()

#check status and print results 
if model.status == GRB.OPTIMAL:
    optimal_objective = model.objVal
    optimal_production_variables = [production_variables[i].x for i in range(len(generators))]
    balance_dual = balance_constraint.Pi
    capacity_duals = [capacity_constraints[i].Pi for i in range(len(generators))]

print (f"Optimal objective value: {optimal_objective}")
for index, optimal in enumerate(optimal_production_variables):
    print(f"Optimal production for Generator {id_Gnerators[index]}: {optimal} MW")

print(f"Dual variable for balance constraint: {balance_dual}")
for index, dual in enumerate(capacity_duals):
    print(f"Dual variable for capacity constraint of Generator {id_Gnerators[index]}: {dual}")

else:
    print(f"optimization of model {model.ModelName} was not successful. Status code: {model.status}")