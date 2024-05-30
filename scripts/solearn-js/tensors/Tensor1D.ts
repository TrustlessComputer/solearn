import { Tensors } from "./Tensors";
import type { Tensor2D } from "./Tensor2D";

export class Tensor1D {
  n: number;
  mat: number[];

  constructor(mat: number[]) {
    this.n = mat.length;
    this.mat = mat;
  }

  static emptyTensor(n: number): Tensor1D {
    const ts = new Tensor1D([]);
    ts.n = n;
    return ts;
  }

  static load(data: number[], n: number): Tensor1D {
    const ts = Tensor1D.emptyTensor(n);    
    let ptr = 0;
    for(let i = 0; i < n; ++i) {
      ts.mat.push(ptr < data.length ? data[ptr] : 0.0);
      ptr += 1;
    }
    return ts;
  }
  
  static zerosTensor(n: number): Tensor1D {
    return Tensor1D.load([], n);
  }

  static cloneTensor(ts: Tensor1D): Tensor1D {
    return Tensor1D.load(ts.mat, ts.n);
  }

  static __apply_unary_op(a: Tensor1D, op: (x: number) => number): Tensor1D {
    const res = Tensor1D.zerosTensor(a.n);
    for(let i = 0; i < res.n; ++i) {
      res.mat[i] = op(a.mat[i]);
    }
    return res;
  }

  static __apply_binary_op(a: Tensor1D, b: Tensor1D, op: (x: number, y: number) => number): Tensor1D {
    const res = Tensor1D.zerosTensor(a.n);
    for(let i = 0; i < res.n; ++i) {
      res.mat[i] = op(a.mat[i], b.mat[i]);
    }
    return res;
  }

  static activation(a: Tensor1D, name: string): Tensor1D {
    switch (name) {
      case "relu": 
        return Tensor1D.__apply_unary_op(a, Tensors.__relu);
      case "sigmoid": 
        return Tensor1D.__apply_unary_op(a, Tensors.__sigmoid);
      case "tanh": 
        return Tensor1D.__apply_unary_op(a, Tensors.__tanh);
      case "leaky_relu": 
        return Tensor1D.__apply_unary_op(a, Tensors.__leaky_relu);
      case "linear":
      default:
        return Tensor1D.__apply_unary_op(a, Tensors.__linear);
    }  
  }

  static add(a: Tensor1D, b: Tensor1D): Tensor1D {
    return Tensor1D.__apply_binary_op(a, b, Tensors.__add);
  }

  static add_scalar(a: Tensor1D, num: number): Tensor1D {
    const res = Tensor1D.zerosTensor(a.n);
    for(let i = 0; i < res.n; ++i) {
			res.mat[i] = a.mat[i] + num;
		}
		return res;
  }
  
  static mul(a: Tensor1D, b: Tensor1D): Tensor1D {
    return Tensor1D.__apply_binary_op(a, b, Tensors.__mul);
  }

  static mul_scalar(a: Tensor1D, num: number): Tensor1D {
    const res = Tensor1D.zerosTensor(a.n);
    for(let i = 0; i < res.n; ++i) {
			res.mat[i] = a.mat[i] * num;
		}
		return res;
  }

  static rescale(a: Tensor1D, scale: number, offset: number): Tensor1D {
    return Tensor1D.__apply_unary_op(a, (x) => x * scale + offset);
  }

  static matMul(a: Tensor1D, b: Tensor2D): Tensor1D {
    const res = Tensor1D.zerosTensor(b.m);
		for (let j = 0; j < b.m; j++) {
			for (let k = 0; k < b.n; k++) {
				res.mat[j] = res.mat[j] + a.mat[k] * b.mat[k][j];
			}
		}
    return res;
  }

  static softmax(a: Tensor1D): Tensor1D {
    const res = Tensor1D.__apply_unary_op(a, x => Math.exp(x));
    const sum_e = res.mat.reduce((a, b) => a + b);
    for(let i = 0; i < a.n; ++i) {
      res.mat[i] /= sum_e;
    }
    return res;
  }
}
