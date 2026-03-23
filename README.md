# 📘 README – Assignment 1: Market Clearing

## 📌 Overview

This project is part of the course **“Renewables in Electricity Markets”** at DTU.  
The objective is to model and analyze **electricity market clearing problems** under different system assumptions.

The assignment covers multiple steps, including:
- Copper-plate market clearing (single and multi-hour)
- Integration of storage
- Network constraints and nodal pricing
- Balancing and reserve markets

The implementation is primarily done in Python using structured data models for generators, consumers, and network topology.

Authors:
- Bella Swan Cay - s257466
- Carlos Omar Hunziker - s257239
- Nikolay Yuliyanov Marinov - s225226
- Izabella Kertész - s253226

---

## ⚙️ Project Structure

The project consists of several Jupyter notebooks and one main data/model file:

```
old                         # Folder containing legacy or previous versions of files
julia                       # Folder containing the original Julia implementation
assignment_1_step_1.ipynb   # Copper-plate, single hour
assignment_1_step_2.ipynb   # Multi-hour + storage
assignment_1_step_3.ipynb   # Network constraints
assignment_1_step_5.ipynb   # Balancing market
assignment_1_step_6.ipynb   # Reserve market
network.py                  # Data structures and system initialization
```

---

## 🧩 Data Model

### Generators

Generators are modeled using the `Generator` class, which includes:

- Technical constraints:
  - Maximum and minimum power (`p_max`, `p_min`)
  - Ramp limits
  - Minimum up/down times
- Economic parameters:
  - Energy cost
  - Reserve and regulation costs
- Initial conditions

Renewable generators are modeled with:
- Zero marginal cost
- Fixed maximum capacity

---

### Consumers

Consumers are represented by the `Consumer` class and include:

- Node location
- Bid price
- Share of total system demand

Each consumer:
- Receives a **time-dependent demand profile**
- Has **time-varying bid prices**, higher during peak hours

---

### Demand

The system demand is defined for 24 hours and distributed across consumers proportionally to their shares.

---

### Network

The transmission system is represented by:
- A list of nodes (implicitly via generators/consumers)
- Transmission lines with capacity limits

This allows modeling:
- Copper-plate system (no network constraints)
- Network-constrained market (nodal pricing)

---

## 🚀 Methodology

### Step 1 – Copper-Plate (Single Hour)

- No network constraints
- Market clearing via welfare maximization
- Outputs:
  - Market-clearing price
  - Social welfare
  - Generator profits
  - Consumer utility
- Runtime: 1.45 s
---

### Step 2 – Multi-Hour + Storage

This task was originally implemented in Julia. For consistency and improved readability, the code was later translated into Python with the assistance of generative AI.  
The original Julia implementation can be found in the "julia" folder.

- Extension to 24 hours
- Storage unit added with:
  - Charging/discharging constraints
  - Energy balance over time
- Analysis:
  - Price smoothing effects
  - Storage profitability
  - Sensitivity to storage size
- Runtime: 1.43 s

---

### Step 3 – Network Constraints

- DC power flow constraints introduced
- Nodal prices derived as dual variables
- Analysis includes:
  - Congestion effects
  - Nodal vs zonal pricing comparison
- Runtime: 1.83 s

---

### Step 5 – Balancing Market

- Deviations from day-ahead schedules:
  - Generator outage
  - Wind forecast errors
- Balancing market clearing:
  - Upward and downward regulation
- Comparison:
  - One-price vs two-price schemes
- Runtime: 5.36 s

---

### Step 6 – Reserve Market

- Sequential clearing:
  1. Reserve market
  2. Day-ahead market
- Reserve requirements:
  - 15% upward
  - 10% downward
- Analysis:
  - Impact on energy prices
  - Interaction between reserve and energy markets
- Runtime: 1.23 s
