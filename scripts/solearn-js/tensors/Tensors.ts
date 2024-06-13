export class Tensors {
  static __linear = (x: number): number => x;
  static __relu = (x: number): number => Math.max(x, 0);
  static __leaky_relu = (x: number): number => x > 0 ? x : x * 0.2;
  static __sigmoid = (x: number): number => 1 / (1 + Math.exp(-x));
  static __tanh = (x: number): number => Math.tanh(x);
  
  static __erf = (x: number): number => {
    var a1 =  0.254829592;
    var a2 = -0.284496736;
    var a3 =  1.421413741;
    var a4 = -1.453152027;
    var a5 =  1.061405429;
    var p  =  0.3275911;

    var sign = ((x < 0) ? -1: 1);
    x = Math.abs(x);

    var t = 1.0/(1.0 + p*x);
    var y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t*Math.exp(-(x**2));

    return sign*y;
  };

  static __gelu = (x: number): number => {
    return (x/2)*(1+Tensors.__erf(x/Math.SQRT2));
  };

  static __add = (a: number, b: number): number => a + b;
  static __mul = (a: number, b: number): number => a * b;
  
  static __subMax0(a: number, b: number): number {
    return a > b ? a - b : 0;
  }

  static getConvSize(dim: number[], size: number[], stride: number[], padding: string) {
    const out = [], pad = [];
    for(let i = 0; i < 2; ++i) {
      if (padding == "same") {
        out.push(Math.floor((dim[i] + stride[i] - 1) / stride[i]));
        const total_pad = (dim[i] % stride[i] == 0) ? Math.max(size[i] - stride[i], 0) : Math.max(size[i] - dim[i] % stride[i], 0);
        pad.push(Math.floor(total_pad / 2));
      } else if (padding == "valid") {
        // TODO: What if dim[i] < size[i]
        out.push(Math.floor((dim[i] - size[i]) / stride[i] + 1));
        pad.push(0);
      }
    }
    // console.log(dim, size, stride, padding, out, pad);
    return { out, pad };
  }
}
