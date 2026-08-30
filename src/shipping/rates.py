RATES = {
    "standard": 5.0,
    "express": 15.0,
    "overnight": 30.0,
}

MIN_CHARGE = 10.0
BULK_THRESHOLD_KG = 50.0
BULK_DISCOUNT = 0.15

def calculate_shipping(weight_kg, tier="standard", bulk_discount_enabled=False):
    if tier not in RATES:
        raise ValueError(f"unknown tier: {tier}")
    cost = weight_kg * RATES[tier]
    if bulk_discount_enabled and weight_kg >= BULK_THRESHOLD_KG:
        cost = cost * (1 - BULK_DISCOUNT)
    return max(cost, MIN_CHARGE)

#Just checking the pipeline with a comment & merge
