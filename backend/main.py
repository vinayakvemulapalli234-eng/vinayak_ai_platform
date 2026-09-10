from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import whisper
import tempfile
import os
import uuid
import shutil
import json
import re

from google import genai
from dotenv import load_dotenv

from predict_price import predict_price


# ============================================================
# ENVIRONMENT
# ============================================================

load_dotenv()


# ============================================================
# GEMINI
# ============================================================

gemini_api_key = os.getenv("GEMINI_API_KEY")

if not gemini_api_key:
    raise RuntimeError(
        "GEMINI_API_KEY is missing from the .env file."
    )

gemini_client = genai.Client(
    api_key=gemini_api_key
)


# ============================================================
# FASTAPI APP
# ============================================================

app = FastAPI(
    title="KALA AI Backend",
    version="1.0.0"
)


# ============================================================
# CORS
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# IMAGE UPLOAD
# ============================================================

UPLOAD_DIR = "uploads"

os.makedirs(
    UPLOAD_DIR,
    exist_ok=True
)

app.mount(
    "/uploads",
    StaticFiles(directory=UPLOAD_DIR),
    name="uploads"
)


# ============================================================
# WHISPER
# ============================================================

print("Loading Whisper model...")

whisper_model = whisper.load_model("base")

print("Whisper model loaded successfully!")


# ============================================================
# STATE → REGION
# ============================================================

STATE_REGION_MAP = {
    "Karnataka": "South",
    "Tamil Nadu": "South",
    "Kerala": "South",
    "Andhra Pradesh": "South",
    "Telangana": "South",

    "Rajasthan": "West",
    "Gujarat": "West",
    "Maharashtra": "West",

    "West Bengal": "East",
    "Odisha": "East",

    "Uttar Pradesh": "North",
    "Punjab": "North",

    "Madhya Pradesh": "Central",

    "Assam": "Northeast",
}


# ============================================================
# STATE → LABOUR RATE
#
# Prototype rates for KALA AI.
# These are NOT official government wage statistics.
# ============================================================

STATE_LABOUR_RATE = {
    "Karnataka": 55,
    "Tamil Nadu": 60,
    "Kerala": 58,
    "Andhra Pradesh": 50,
    "Telangana": 60,

    "Rajasthan": 45,
    "Gujarat": 55,
    "Maharashtra": 60,

    "West Bengal": 48,
    "Odisha": 45,

    "Uttar Pradesh": 45,
    "Punjab": 55,

    "Madhya Pradesh": 45,

    "Assam": 48,
}


# ============================================================
# STATE NORMALIZATION
#
# Helps Gemini variations such as:
# "andhra pradesh"
# "Andhra Pradesh"
# "AP"
# ============================================================

STATE_ALIASES = {
    "andhra pradesh": "Andhra Pradesh",
    "ap": "Andhra Pradesh",

    "telangana": "Telangana",
    "ts": "Telangana",

    "karnataka": "Karnataka",
    "ka": "Karnataka",

    "tamil nadu": "Tamil Nadu",
    "tamilnadu": "Tamil Nadu",

    "kerala": "Kerala",

    "rajasthan": "Rajasthan",

    "gujarat": "Gujarat",

    "maharashtra": "Maharashtra",

    "west bengal": "West Bengal",
    "westbengal": "West Bengal",

    "odisha": "Odisha",
    "orissa": "Odisha",

    "uttar pradesh": "Uttar Pradesh",
    "up": "Uttar Pradesh",

    "madhya pradesh": "Madhya Pradesh",
    "mp": "Madhya Pradesh",

    "punjab": "Punjab",

    "assam": "Assam",
}


def normalize_state(state):
    if not state:
        return None

    state_clean = str(state).strip().lower()

    return STATE_ALIASES.get(
        state_clean,
        str(state).strip()
    )


# ============================================================
# PRICING REQUEST MODEL
# ============================================================

class PricingRequest(BaseModel):

    state: str
    region: str
    craft_category: str
    material: str

    material_cost: float
    labour_cost: float
    labour_hours: float

    product_size: str
    complexity: int

    current_market_price: float
    demand_score: float
    season_score: float


# ============================================================
# HOME
# ============================================================

@app.get("/")
def home():

    return {
        "message": "KALA AI Backend is running"
    }


# ============================================================
# HEALTH CHECK
# ============================================================

@app.get("/health")
def health():

    return {
        "status": "healthy",
        "service": "KALA AI Backend"
    }


# ============================================================
# SPEECH TO TEXT
# ============================================================

@app.post("/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...)
):

    suffix = (
        os.path.splitext(file.filename)[1]
        or ".wav"
    )

    temp_path = None

    try:

        with tempfile.NamedTemporaryFile(
            delete=False,
            suffix=suffix
        ) as temp:

            audio_data = await file.read()

            temp.write(audio_data)

            temp_path = temp.name


        result = whisper_model.transcribe(
            temp_path,
            fp16=False
        )


        text = result["text"].strip()


        return {
            "success": True,
            "text": text
        }


    except Exception as e:

        return {
            "success": False,
            "error": str(e)
        }


    finally:

        if temp_path and os.path.exists(temp_path):

            os.remove(temp_path)


# ============================================================
# HELPER
# Extract JSON from Gemini response
# ============================================================

def _extract_json(text: str) -> dict:

    cleaned = text.strip()


    # Remove markdown fences

    cleaned = re.sub(
        r"^```json",
        "",
        cleaned,
        flags=re.IGNORECASE
    ).strip()


    cleaned = re.sub(
        r"^```",
        "",
        cleaned
    ).strip()


    cleaned = re.sub(
        r"```$",
        "",
        cleaned
    ).strip()


    # Try direct JSON first

    try:

        return json.loads(cleaned)

    except json.JSONDecodeError:

        pass


    # Try extracting the first {...} block

    match = re.search(
        r"\{.*\}",
        cleaned,
        re.DOTALL
    )

    if match:

        return json.loads(
            match.group(0)
        )


    raise ValueError(
        "Gemini did not return valid JSON."
    )


# ============================================================
# GEMINI
# VOICE TRANSCRIPT → PRODUCT INFORMATION
# → PRICING INFORMATION
# ============================================================

@app.post("/generate-listing")
async def generate_listing(
    data: dict
):

    product_details = data.get(
        "text",
        ""
    )

    product_details = str(
        product_details
    ).strip()


    if not product_details:

        return {
            "success": False,
            "error": "Product details are required"
        }


    # ========================================================
    # GEMINI EXTRACTION PROMPT
    # ========================================================

    prompt = f"""
You are KALA AI, an AI assistant helping
marginalized Indian artisans sell handmade
products online.

The artisan spoke the following sentence.

Extract the product information accurately.

IMPORTANT:

1. Extract the Indian state ONLY if the artisan
   actually mentioned it.

2. Extract labor hours ONLY if the artisan
   actually mentioned the number of hours.

3. Extract material cost ONLY if the artisan
   actually mentioned a cost.

4. NEVER invent state, labor hours, or material cost.

5. If state is not mentioned, return null.

6. If labor hours are not mentioned, return null.

7. If material cost is not mentioned, return null.

8. Complexity can be estimated from the product
   description.

9. Quality can be estimated from the description.

Artisan speech:

\"\"\"{product_details}\"\"\"


Return ONLY valid JSON.

Use exactly these keys:

{{
    "title": "short attractive product title",

    "description": "3-5 sentence description highlighting craftsmanship, materials, handmade nature, cultural value and uniqueness",

    "materials": "materials mentioned by the artisan",

    "category": "most suitable product category",

    "tags": [
        "tag1",
        "tag2",
        "tag3",
        "tag4",
        "tag5"
    ],

    "state": "Indian state mentioned by artisan or null",

    "product_size": "Small, Medium, or Large",

    "labour_hours": 12,

    "material_cost": 500,

    "complexity": 4,

    "quality": "Low, Medium, or High"
}}

For labour_hours:

Return a number only if the artisan
actually mentioned the hours.

Otherwise return null.

For material_cost:

Return a number only if the artisan
actually mentioned the material cost.

Otherwise return null.

For state:

Return the state name in normal English,
for example:

"Andhra Pradesh"

"Karnataka"

"Telangana"

If no state was mentioned, return null.

Do not invent facts.
"""


    # ========================================================
    # CALL GEMINI
    # ========================================================

    try:

        response = gemini_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )


        extracted = _extract_json(
            response.text
        )


    except Exception as e:

        return {
            "success": False,
            "error": (
                "AI generation failed: "
                + str(e)
            )
        }


    # ========================================================
    # NORMALIZE STATE
    # ========================================================

    state = normalize_state(
        extracted.get("state")
    )


    # ========================================================
    # REQUIRED FIELDS
    # ========================================================

    missing = []


    if not state:

        missing.append(
            "your state"
        )


    labour_hours = extracted.get(
        "labour_hours"
    )

    if labour_hours is None:

        missing.append(
            "how many hours it took to make"
        )


    material_cost = extracted.get(
        "material_cost"
    )

    if material_cost is None:

        missing.append(
            "how much the materials cost"
        )


    # ========================================================
    # IF REQUIRED INFORMATION IS MISSING
    # ========================================================

    if missing:

        return {

            "success": False,

            "error": "missing_required_fields",

            "missing_fields": missing,

            "message": (
                "I couldn't catch "
                + ", ".join(missing)
                + ". Please record again and mention "
                + (
                    "this"
                    if len(missing) == 1
                    else "these"
                )
                + " so I can calculate the price."
            ),

            "partial": extracted
        }


    # ========================================================
    # CONVERT NUMERIC VALUES
    # ========================================================

    try:

        labour_hours = float(
            labour_hours
        )

        material_cost = float(
            material_cost
        )

    except Exception:

        return {

            "success": False,

            "error": (
                "Invalid numeric value for "
                "labor hours or material cost."
            )
        }


    # ========================================================
    # VALIDATE VALUES
    # ========================================================

    if labour_hours <= 0:

        return {

            "success": False,

            "error": (
                "Labor hours must be greater than zero."
            )
        }


    if material_cost < 0:

        return {

            "success": False,

            "error": (
                "Material cost cannot be negative."
            )
        }


    # ========================================================
    # CHECK STATE
    # ========================================================

    if state not in STATE_LABOUR_RATE:

        return {

            "success": False,

            "error": "unsupported_state",

            "message": (
                f"'{state}' is not yet available "
                "in the KALA AI labor-rate table."
            ),

            "partial": extracted
        }


    # ========================================================
    # STATE → REGION
    # ========================================================

    region = STATE_REGION_MAP.get(
        state
    )


    # ========================================================
    # STATE → LABOR RATE
    # ========================================================

    labour_rate = STATE_LABOUR_RATE[
        state
    ]


    # ========================================================
    # OTHER PRODUCT INFORMATION
    # ========================================================

    product_size = (
        extracted.get(
            "product_size"
        )
        or "Medium"
    )


    complexity = (
        extracted.get(
            "complexity"
        )
        or 3
    )


    category = (
        extracted.get(
            "category"
        )
        or "Home Decor"
    )


    materials = (
        extracted.get(
            "materials"
        )
        or "Not specified"
    )


    quality = (
        extracted.get(
            "quality"
        )
        or "Medium"
    )


    # Keep complexity between 1 and 5

    try:

        complexity = int(
            complexity
        )

    except Exception:

        complexity = 3


    complexity = max(
        1,
        min(
            5,
            complexity
        )
    )


    # ========================================================
    # DEMAND SCORE
    # ========================================================
    # Prototype mapping.
    # Later this can be replaced by real demand data.

    quality_lower = str(
        quality
    ).lower()


    demand_score = {
        "low": 0.40,
        "medium": 0.60,
        "high": 0.85
    }.get(
        quality_lower,
        0.60
    )


    # ========================================================
    # SEASON SCORE
    # ========================================================
    # Prototype value.
    # Later this can come from real seasonal data.

    season_score = 0.60


    # ========================================================
    # LABOR COST
    # ========================================================

    labour_cost = (
        labour_hours
        * labour_rate
    )


    # ========================================================
    # TOTAL PRODUCTION COST
    # ========================================================

    production_cost = (
        material_cost
        + labour_cost
    )


    # ========================================================
    # MARKET REFERENCE
    # ========================================================
    # If the artisan did not provide a market price,
    # use a temporary production-cost-based reference.
    #
    # This is NOT claimed to be real market data.

    current_market_price = round(
        production_cost * 1.30,
        2
    )


    # ========================================================
    # PREPARE ML INPUT
    # ========================================================

    pricing_input = {

        "state": state,

        "region": region,

        "craft_category": category,

        "material": materials,

        "material_cost": material_cost,

        "labour_cost": labour_cost,

        "labour_hours": labour_hours,

        "product_size": product_size,

        "complexity": complexity,

        "current_market_price": (
            current_market_price
        ),

        "demand_score": demand_score,

        "season_score": season_score
    }


    # ========================================================
    # ML PRICE PREDICTION
    # ========================================================

    try:

        predicted_price = predict_price(
            pricing_input
        )


    except Exception as e:

        return {

            "success": False,

            "error": (
                "Pricing calculation failed: "
                + str(e)
            )
        }


    # ========================================================
    # FAIR PRICE FLOOR
    # ========================================================
    # Never recommend a price below production cost.

    minimum_fair_price = round(
        production_cost,
        2
    )


    predicted_price = max(
        float(predicted_price),
        minimum_fair_price
    )


    predicted_price = round(
        predicted_price,
        2
    )


    # ========================================================
    # RETURN COMPLETE RESULT
    # ========================================================

    return {

        "success": True,

        # Product listing

        "title": extracted.get(
            "title",
            ""
        ),

        "description": extracted.get(
            "description",
            ""
        ),

        "materials": materials,

        "category": category,

        "tags": extracted.get(
            "tags",
            []
        ),

        # Location

        "state": state,

        "region": region,

        # Product characteristics

        "product_size": product_size,

        "complexity": complexity,

        "quality": quality,

        # Cost calculation

        "labour_hours": labour_hours,

        "labour_rate": labour_rate,

        "labour_cost": round(
            labour_cost,
            2
        ),

        "material_cost": round(
            material_cost,
            2
        ),

        "production_cost": round(
            production_cost,
            2
        ),

        # Pricing signals

        "current_market_price": (
            current_market_price
        ),

        "demand_score": demand_score,

        "season_score": season_score,

        # Final ML price

        "predicted_price": predicted_price,

        "minimum_fair_price": (
            minimum_fair_price
        )
    }


# ============================================================
# IMAGE UPLOAD
# ============================================================

@app.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...)
):

    try:

        extension = (
            os.path.splitext(
                file.filename
            )[1].lower()
            or ".jpg"
        )


        filename = (
            f"{uuid.uuid4()}{extension}"
        )


        file_path = os.path.join(
            UPLOAD_DIR,
            filename
        )


        with open(
            file_path,
            "wb"
        ) as buffer:

            shutil.copyfileobj(
                file.file,
                buffer
            )


        image_url = (
            "http://127.0.0.1:8000/"
            f"uploads/{filename}"
        )


        return {

            "success": True,

            "imageUrl": image_url,

            "filename": filename
        }


    except Exception as e:

        return {

            "success": False,

            "error": str(e)
        }


# ============================================================
# DIRECT DYNAMIC PRICING ENDPOINT
# ============================================================

@app.post("/predict-price")
def predict_product_price(
    data: PricingRequest
):

    try:

        input_data = data.model_dump()

        price = predict_price(
            input_data
        )


        # Calculate production cost

        production_cost = (
            data.material_cost
            + data.labour_cost
        )


        # Never allow ML to recommend below cost

        final_price = max(
            float(price),
            float(production_cost)
        )


        final_price = round(
            final_price,
            2
        )


        return {

            "success": True,

            "predicted_price": final_price,

            "production_cost": round(
                production_cost,
                2
            ),

            "labour_cost": round(
                data.labour_cost,
                2
            ),

            "material_cost": round(
                data.material_cost,
                2
            )
        }


    except Exception as e:

        return {

            "success": False,

            "error": str(e)
        }