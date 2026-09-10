import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import joblib

# ----------------------------
# Step 1: Load dataset
# ----------------------------
df = pd.read_csv("kala_pricing_dataset.csv")
print("Dataset loaded:", df.shape)

# ----------------------------
# Step 2: One-hot encode categorical columns
# ----------------------------
categorical_cols = ["state", "region", "craft_category", "material", "product_size"]
df_encoded = pd.get_dummies(df, columns=categorical_cols)

# Save the exact column order used for training —
# we'll need this later in predict_price.py to match input shape
feature_columns = [col for col in df_encoded.columns if col != "recommended_price"]
joblib.dump(feature_columns, "feature_columns.pkl")

# ----------------------------
# Step 3: Split features/target
# ----------------------------
X = df_encoded[feature_columns]
y = df_encoded["recommended_price"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# ----------------------------
# Step 4: Train Random Forest
# ----------------------------
model = RandomForestRegressor(
    n_estimators=200,
    max_depth=12,
    random_state=42,
    n_jobs=-1
)
model.fit(X_train, y_train)

# ----------------------------
# Step 5: Evaluate
# ----------------------------
y_pred = model.predict(X_test)

mae = mean_absolute_error(y_test, y_pred)
rmse = np.sqrt(mean_squared_error(y_test, y_pred))
r2 = r2_score(y_test, y_pred)

print("\n--- Model Evaluation ---")
print(f"MAE:  {mae:.2f}")
print(f"RMSE: {rmse:.2f}")
print(f"R2:   {r2:.4f}")

# ----------------------------
# Step 6: Save model
# ----------------------------
joblib.dump(model, "pricing_model.pkl")
print("\nModel saved as pricing_model.pkl")
print("Feature columns saved as feature_columns.pkl")