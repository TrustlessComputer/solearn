export class Tensors {
  static __linear = (x: number): number => x;
  static __relu = (x: number): number => Math.max(x, 0);
  static __leaky_relu = (x: number): number => x > 0 ? x : x * 0.2;
  static __sigmoid = (x: number): number => 1 / (1 + Math.exp(-x));
  static __tanh = (x: number): number => Math.tanh(x);

  static __add = (a: number, b: number): number => a + b;
  static __mul = (a: number, b: number): number => a * b;
	
	static __subMax0(a: number, b: number): number {
		return a > b ? a - b : 0;
	}

  static getConvSize(dim: number[], size: number[], stride: number[], padding: string) {
    const out = [], pad = [];
		for(let i = 0; i < 2; ++i) {
			if (padding == "same") {
				out.push((dim[i] + stride[i] - 1) / stride[i]);
				const total_pad = (dim[i] % stride[i] == 0) ? Math.max(size[i] - stride[i], 0) : Math.max(size[i] - dim[i] % stride[i], 0);
				pad.push(total_pad / 2);
			} else if (padding == "valid") {
				// TODO: What if dim[i] < size[i]
				out.push((dim[i] - size[i]) / stride[i] + 1);
				pad.push(0);
			}
		}
		return { out, pad };
  }
}
