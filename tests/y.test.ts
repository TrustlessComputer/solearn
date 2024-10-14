function combineDurations(
  part1: number,
  part2: number,
  part3: number,
  part4: number,
  part5: number
): BigInt {
  // Validate input (optional but recommended)
  if (
    !Number.isInteger(part1) ||
    part1 < 0 ||
    part1 >= 2 ** 40 ||
    !Number.isInteger(part2) ||
    part2 < 0 ||
    part2 >= 2 ** 40 ||
    !Number.isInteger(part3) ||
    part3 < 0 ||
    part3 >= 2 ** 40 ||
    !Number.isInteger(part4) ||
    part4 < 0 ||
    part4 >= 2 ** 40 ||
    !Number.isInteger(part5) ||
    part5 < 0 ||
    part5 >= 2 ** 40
  ) {
    throw new Error(
      "Invalid duration part(s). Each part must be an integer between 0 and 2**40 - 1."
    );
  }

  // Construct the BigNumber representation
  let duration = BigInt(part1.toString()) << BigInt(160); // Shift part1 left by 120 bits
  duration = duration + (BigInt(part2.toString()) << BigInt(120)); // Add part2 shifted left by 80 bits
  duration = duration + (BigInt(part3.toString()) << BigInt(80)); // Add part3 shifted left by 40 bits
  duration = duration + (BigInt(part4.toString()) << BigInt(40)); // Add part4 directly
  duration = duration + BigInt(part5.toString()); // Add part4 directly

  return duration;
}

// Example usage:
const part1 = 111;
const part2 = 222;
const part3 = 333;
const part4 = 444;
const part5 = 555;

const combinedDuration = combineDurations(part1, part2, part3, part4, part5);
console.log(combinedDuration.toString()); // Output the result as a hexadecimal string (common for BigNumbers)
