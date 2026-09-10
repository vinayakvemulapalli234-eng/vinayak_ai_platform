import joblib
import pandas as pd

# ----------------------------
# Load model and feature columns once at import time
# ----------------------------
model = joblib.load("pricing_model.pkl")
feature_columns = joblib.load("feature_columns.pkl")

print("Pricing model loaded successfully!")


def predict_price(input_data: dict) -> float:
    """
    input_data example:
    {
        "state": "Telangana",
        "region": "South",
        "craft_category": "Wooden Toy",
        "material": "Wood",
        "material_cost": 180,
        "labour_cost": 250,
        "labour_hours": 5,
        "product_size": "Medium",
        "complexity": 3,
        "current_market_price": 650,
        "demand_score": 0.7,
        "season_score": 0.6
    }
    """

    # Put the single input into a DataFrame
    df_input = pd.DataFrame([input_data])

    # One-hot encode the same categorical columns used during training
    categorical_cols = ["state", "region", "craft_category", "material", "product_size"]
    df_encoded = pd.get_dummies(df_input, columns=categorical_cols)

    # Align columns to match training exactly:
    # - adds any missing one-hot columns as 0
    # - drops any extra columns not seen during training
    # - puts them in the exact same order
    df_final = df_encoded.reindex(columns=feature_columns, fill_value=0)

    predicted_price = model.predict(df_final)[0]

    return round(float(predicted_price), 2)


# ----------------------------
# Quick manual test (only runs if you execute this file directly)
# ----------------------------
if __name__ == "__main__":
    sample_input = {
        "state": "Telangana",
        "region": "South",
        "craft_category": "Wooden Toy",
        "material": "Wood",
        "material_cost": 180,
        "labour_cost": 250,
        "labour_hours": 5,
        "product_size": "Medium",
        "complexity": 3,
        "current_market_price": 650,
        "demand_score": 0.7,
        "season_score": 0.6
    }

    price = predict_price(sample_input)
    print(f"Predicted price: ₹{price}")