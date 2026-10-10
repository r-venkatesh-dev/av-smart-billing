export type DiscountType = "NONE" | "FLAT" | "PERCENTAGE";

export interface PlanDiscountCalculation {
  discountedPriceInPaise: number;
  discountAmountInPaise: number;
  hasDiscount: boolean;
  discountLabel: string;
  badgeText: string;
}

/**
 * Calculates the promotional first-time customer price.
 * @param priceInPaise Original plan price in paise
 * @param discountType 'NONE' | 'FLAT' | 'PERCENTAGE'
 * @param discountValue Flat rupees (e.g. 100 for ₹100) or percentage (e.g. 10 for 10%)
 */
export function calculatePlanDiscount(
  priceInPaise: number,
  discountType?: string | null,
  discountValue?: number | null,
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
    badgeText = `First-time offer: ₹${formattedRupees} OFF`;
  } else if (normalizedType === "PERCENTAGE") {
    const safePercent = Math.min(100, Math.max(0, numValue));
    discountPaise = Math.round((priceInPaise * safePercent) / 100);
    const formattedPercent = safePercent % 1 === 0 ? safePercent.toString() : safePercent.toFixed(1);
    discountLabel = `${formattedPercent}% OFF`;
    badgeText = `First-time offer: ${formattedPercent}% OFF`;
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
