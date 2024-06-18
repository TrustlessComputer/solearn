// Modified from https://gist.github.com/sketchpunk/f5fa58a56dcfe6168a9328e7c32a4fd4
export function base64ToFloatArray(base64: string): Float32Array {
  // Base64 string converted to a char array
  const blob	= Buffer.from(base64, 'base64');
  // Convert raw buffer to Float32Array
  const floatArray = new Float32Array(blob.buffer);
  return floatArray;
}

export function normalizeArray(arr: number[]): number[] {
  let mean = 0;
  for(let i = 0; i < arr.length; ++i) {
    mean += arr[i];
  }
  mean /= arr.length;
  
  let variance = 0;
  for(let i = 0; i < arr.length; ++i) {
    variance += Math.pow(arr[i] - mean, 2);
  }
  variance /= arr.length;

  let std = Math.sqrt(variance);

  const res = [];
  for(let i = 0; i < arr.length; ++i) {
    res.push((arr[i] - mean)/std);
  }
  return res;
}
