export function decimalToMinorUnits(value: string, decimalPlaces = 2): number {
  const normalized = value.trim();
  if (!/^\d+(?:\.\d+)?$/.test(normalized)) throw new Error("Invalid decimal amount");
  const [whole, fraction = ""] = normalized.split(".");
  if (fraction.length > decimalPlaces) throw new Error(`Use no more than ${decimalPlaces} decimal places`);
  const result = BigInt(whole) * BigInt(10) ** BigInt(decimalPlaces) + BigInt(fraction.padEnd(decimalPlaces, "0") || "0");
  if (result > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("Amount is too large");
  return Number(result);
}

export const rupeesToPaise = (value: string) => decimalToMinorUnits(value, 2);
export const percentToBasisPoints = (value: string) => decimalToMinorUnits(value, 2);
