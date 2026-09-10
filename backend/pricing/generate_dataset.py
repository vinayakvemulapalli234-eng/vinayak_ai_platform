import pandas as pd
import numpy as np
import random

np.random.seed(42)
random.seed(42)

# ----------------------------
# Step 1: Fixed value lists
# ----------------------------
states = {
    "Karnataka": "South", "Tamil Nadu": "South", "Kerala": "South",
    "Andhra Pradesh": "South", "Telangana": "South",
    "Rajasthan": "West", "Gujarat": "West", "Maharashtra": "West",
    "West Bengal": "East", "Odisha": "East",
    "Uttar Pradesh": "North", "Madhya Pradesh": "Central",
    "Punjab": "North", "Assam": "Northeast"
}

craft_categories = {
    "Wooden Toy": ["Wood", "Bamboo"],
    "Pottery": ["Clay", "Terracotta"],
    "Bamboo Craft": ["Bamboo", "Cane"],
    "Handloom Textile": ["Cotton", "Silk", "Wool"],
    "Metal Craft": ["Brass", "Copper", "Bronze"],
    "Stone Carving": ["Marble", "Soapstone"],
    "Jewelry": ["Silver", "Beads", "Terracotta"],
    "Painting": ["Canvas", "Cloth", "Paper"]
}

sizes = ["Small", "Medium", "Large"]

# ----------------------------
# Step 2: Record generator
# ----------------------------
def generate_record():
    state = random.choice(list(states.keys()))
    region = states[state]
    craft = random.choice(list(craft_categories.keys()))
    material = random.choice(craft_categories[craft])
    size = random.choice(sizes)

    size_multiplier = {"Small": 1.0, "Medium": 1.6, "Large": 2.4}[size]

    material_cost = round(np.random.uniform(50, 400) * size_multiplier, 2)
    labour_hours = round(np.random.uniform(1, 12) * size_multiplier, 1)
    labour_cost = round(labour_hours * np.random.uniform(30, 60), 2)

    complexity = random.randint(1, 5)
    demand_score = round(np.random.uniform(0.3, 1.0), 2)
    season_score = round(np.random.uniform(0.3, 1.0), 2)

    base_cost = material_cost + labour_cost

    region_factor = {
        "South": 1.05, "West": 1.1, "North": 1.0,
        "East": 0.95, "Central": 0.9, "Northeast": 0.9
    }[region]

    complexity_factor = 1 + (complexity - 1) * 0.08

    current_market_price = round(
        base_cost * complexity_factor * region_factor *
        (0.9 + 0.3 * demand_score) * np.random.uniform(0.95, 1.15), 2
    )

    recommended_price = round(
        current_market_price * (1 + 0.15 * (demand_score - 0.5)) *
        (1 + 0.08 * (season_score - 0.5)) *
        np.random.uniform(0.97, 1.08), 2
    )

    return {
        "state": state,
        "region": region,
        "craft_category": craft,
        "material": material,
        "material_cost": material_cost,
        "labour_cost": labour_cost,
        "labour_hours": labour_hours,
        "product_size": size,
        "complexity": complexity,
        "current_market_price": current_market_price,
        "demand_score": demand_score,
        "season_score": season_score,
        "recommended_price": recommended_price
    }

# ----------------------------
# Step 3: Generate and save
# ----------------------------
if __name__ == "__main__":
    data = [generate_record() for _ in range(4000)]
    df = pd.DataFrame(data)
    df.to_csv("kala_pricing_dataset.csv", index=False)

    print("Dataset generated successfully!")
    print(df.head())
    print("Shape:", df.shape)