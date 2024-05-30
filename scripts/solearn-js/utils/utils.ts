

// Modified from https://gist.github.com/sketchpunk/f5fa58a56dcfe6168a9328e7c32a4fd4
export function base64ToFloatArray(base64: string) {
  // Base64 string converted to a char array
  const blob	= window.atob(base64);
  // How many floats can be made, but be even
	const fLen = blob.length / Float32Array.BYTES_PER_ELEMENT;
  // ArrayBuffer/DataView to convert 4 bytes into 1 float.          
  const dView = new DataView( new ArrayBuffer(Float32Array.BYTES_PER_ELEMENT) );
  // Final Output at the correct size
  const fAry = new Float32Array(fLen);
  // Position
  let p = 0; 

  for(let j=0; j < fLen; j++){
    p = j * 4;
    for(let b = 0; b < 4; ++b) {
      dView.setUint8(b,blob.charCodeAt(p+b));
    }
    fAry[j] = dView.getFloat32(0,true);
  }
  return fAry;
}