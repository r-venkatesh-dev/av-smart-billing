export type DiscountType = "NONE" | "FLAT" | "PERCENTAGE";
export type OfferType = "FLAT" | "PERCENTAGE";

export interface PlanOffer {
  id: string;
  name: string;
  type: OfferType;
  value: number;
  isFirstTimeOnly: boolean;
}

export interface PlanDiscountCalculation {
  discountedPriceInPaise: number;
  discountAmountInPaise: number;
  hasDiscount: boolean;
  discountLabel: string;
  badgeText: string;
}

/**
 * Normalizes dynamic offers array from raw database record or fallback discount.
 */
export function normalizePlanOffers(
  offersRaw?: unknown,
  fallbackDiscountType?: string | null,
  fallbackDiscountValue?: number | null,
): PlanOffer[] {
  const result: PlanOffer[] = [];
  if (Array.isArray(offersRaw)) {
    for (const item of offersRaw) {
      if (item && typeof item === "object") {
        const obj = item as Record<string, unknown>;
        const id = String(obj.id || obj.name || Math.random().toString(36).slice(2));
        const name = String(obj.name || "Special Offer").trim();
        const type = obj.type === "PERCENTAGE" || obj.type === "FLAT" ? obj.type : "FLAT";
        const value = Number(obj.value) || 0;
        const isFirstTimeOnly = Boolean(obj.isFirstTimeOnly ?? obj.is_first_time_only);
        if (value > 0 && name.length > 0) {
          result.push({ id, name, type, value, isFirstTimeOnly });
        }
      }
    }
  }

  // If no dynamic offers are found, use legacy new_user_discount as the default offer
  if (
    result.length === 0 &&
    fallbackDiscountType &&
    fallbackDiscountType !== "NONE" &&
    Number(fallbackDiscountValue) > 0
  ) {
    result.push({
      id: "first-time-welcome",
      name: "First-Time Owner Offer",
      type: fallbackDiscountType === "PERCENTAGE" ? "PERCENTAGE" : "FLAT",
      value: Number(fallbackDiscountValue),
      isFirstTimeOnly: true,
    });
  }

  return result;
}

/**
 * Calculates the promotional discount for a specific offer.
 */
export function calculateOfferDiscount(
  priceInPaise: number,
  offer?: PlanOffer | null,
): PlanDiscountCalculation {
  if (!offer || offer.value <= 0 || priceInPaise <= 0) {
    return {
      discountedPriceInPaise: priceInPaise,
      discountAmountInPaise: 0,
      hasDiscount: false,
      discountLabel: "",
      badgeText: "",
    };
  }

  return calculatePlanDiscount(priceInPaise, offer.type, offer.value, offer.name);
}

/**
 * Calculates the promotional first-time customer price.
 * @param priceInPaise Original plan price in paise
 * @param discountType 'NONE' | 'FLAT' | 'PERCENTAGE'
 * @param discountValue Flat rupees (e.g. 100 for ₹100) or percentage (e.g. 10 for 10%)
 * @param offerName Optional name of the offer
 */
export function calculatePlanDiscount(
  priceInPaise: number,
  discountType?: string | null,
  discountValue?: number | null,
  offerName?: string,
): PlanDiscountCalculation {
  const normalizedType = (discountType || "NONE").toUpperCase() as DiscountType;
  const numValue = Number(discountValue) || 0;

  if (
    normalizedType === "NONE" ||
    numValue <= 0 ||
    priceInPaise <= 0 ||
    !Number.isFinite(priceInPaise)
  ) {
    return {
      discountedPriceInPaise: priceInPaise,
      discountAmountInPaise: 0,
      hasDiscount: false,
      discountLabel: "",
      badgeText: "",
    };
  }

  let discountPaise = 0;
  let discountLabel = "";
  let badgeText = "";

  if (normalizedType === "FLAT") {
    // numValue is in rupees, convert to paise
    discountPaise = Math.round(numValue * 100);
    const formattedRupees = numValue % 1 === 0 ? numValue.toString() : numValue.toFixed(2);
    discountLabel = `₹${formattedRupees} OFF`;
    badgeText = offerName ? `${offerName}: ₹${formattedRupees} OFF` : `Special offer: ₹${formattedRupees} OFF`;
  } else if (normalizedType === "PERCENTAGE") {
    const safePercent = Math.min(100, Math.max(0, numValue));
    discountPaise = Math.round((priceInPaise * safePercent) / 100);
    const formattedPercent = safePercent % 1 === 0 ? safePercent.toString() : safePercent.toFixed(1);
    discountLabel = `${formattedPercent}% OFF`;
    badgeText = offerName ? `${offerName}: ${formattedPercent}% OFF` : `Special offer: ${formattedPercent}% OFF`;
  }

  // Cap discount between 0 and total price
  discountPaise = Math.min(priceInPaise, Math.max(0, discountPaise));
  const discountedPriceInPaise = Math.max(0, priceInPaise - discountPaise);

  return {
    discountedPriceInPaise,
    discountAmountInPaise: discountPaise,
    hasDiscount: discountPaise > 0,
    discountLabel,
    badgeText,
  };
}
