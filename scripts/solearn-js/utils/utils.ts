// Modified from https://gist.github.com/sketchpunk/f5fa58a56dcfe6168a9328e7c32a4fd4
export function base64ToFloatArray(base64: string): Float32Array {
  // Base64 string converted to a char array
  const blob	= Buffer.from(base64, 'base64');
  // Convert raw buffer to Float32Array
  const floatArray = new Float32Array(blob.buffer);
  return floatArray;
}