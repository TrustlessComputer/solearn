import { Tensors } from "./Tensors";

export class Tensor2D {
  n: number;
  m: number;
  mat: number[][];

  constructor(mat?: number[][]) {
    if (mat) {
      this.n = mat.length;
      this.m = mat[0].length;
      this.mat = mat;
    } else {
      this.n = 0;
      this.m = 0;
      this.mat = [];
    }
  }

  static emptyTensor(n: number, m: number): Tensor2D {
    const ts = new Tensor2D();
    ts.n = n;
    ts.m = m;
    for(let i = 0; i < n; ++i) {
      ts.mat.push([]);
    }
    return ts;
  }

  static load(data: number[], n: number, m: number): Tensor2D {
    const ts = Tensor2D.emptyTensor(n, m);
    let ptr = 0;
    for(let i = 0; i < n; ++i) {
      for(let j = 0; j < m; ++j) {
        ts.mat[i].push(ptr < data.length ? data[ptr] : 0.0);
        ptr += 1;
      }
    }
    return ts;
  }

	loadPartial(data: number[], ptr: number, idx: number): { ptr: number, idx: number, cnt: number } {
    let m = this.m;
		let cnt = this.n * m;
		while (idx < data.length && ptr < cnt) {
			this.mat[Math.floor(ptr / m)].push(data[idx]);
			ptr++;
			idx++;
		}
		return {ptr, idx, cnt};
	}

  static zerosTensor(n: number, m: number): Tensor2D {
    return Tensor2D.load([], n, m);
  }

  static cloneTensor(ts: Tensor2D): Tensor2D {
    return Tensor2D.load(ts.mat.flat(), ts.n, ts.m);
  }
  
  static __apply_unary_op(a: Tensor2D, op: (x: number) => number): Tensor2D {
    const res = Tensor2D.zerosTensor(a.n, a.m);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        res.mat[i][j] = op(a.mat[i][j]);
      }
    }
    return res;
  }

  static activation(a: Tensor2D, name: string): Tensor2D {
    switch (name) {
      case "relu": 
        return Tensor2D.__apply_unary_op(a, Tensors.__relu);
      case "sigmoid": 
        return Tensor2D.__apply_unary_op(a, Tensors.__sigmoid);
      case "tanh": 
        return Tensor2D.__apply_unary_op(a, Tensors.__tanh);
      case "leaky_relu": 
        return Tensor2D.__apply_unary_op(a, Tensors.__leaky_relu);
      case "gelu": 
        return Tensor2D.__apply_unary_op(a, Tensors.__gelu);
      case "linear":
      default:
        return Tensor2D.__apply_unary_op(a, Tensors.__linear);
    }
  }

  static __apply_binary_op = (a: Tensor2D, b: Tensor2D, op: (x: number, y: number) => number): Tensor2D => {
    const res = Tensor2D.zerosTensor(a.n, a.m);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        res.mat[i][j] = op(a.mat[i][j], b.mat[i][j]);
      }
    }
    return res;
  }

  static add(a: Tensor2D, b: Tensor2D): Tensor2D {
    return Tensor2D.__apply_binary_op(a, b, Tensors.__add);
  }

  static add_scalar(a: Tensor2D, num: number): Tensor2D {
    const res = Tensor2D.zerosTensor(a.n, a.m);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        res.mat[i][j] = a.mat[i][j] + num;
      }
    }
    return res;
  }
  
  static mul(a: Tensor2D, b: Tensor2D): Tensor2D {
    return Tensor2D.__apply_binary_op(a, b, Tensors.__mul);
  }

  static mul_scalar(a: Tensor2D, num: number): Tensor2D {
    const res = Tensor2D.zerosTensor(a.n, a.m);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        res.mat[i][j] = a.mat[i][j] * num;
      }
    }
    return res;
  }

  static rescale(a: Tensor2D, scale: number, offset: number): Tensor2D {
    return Tensor2D.__apply_unary_op(a, (x) => x * scale + offset);
  }

  static matMul(a: Tensor2D, b: Tensor2D): Tensor2D {
    const res = Tensor2D.zerosTensor(a.n, b.m);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < a.m; ++k) {
          res.mat[i][j] += a.mat[i][k] * b.mat[k][j];
        }
      }
    }
    return res;
  }

  static softmax(a: Tensor2D): Tensor2D {
    const res = Tensor2D.__apply_unary_op(a, x => Math.exp(x));
    const sum_e = res.mat.flat().reduce((a, b) => a + b);
    for(let i = 0; i < a.n; ++i) {
      for(let j = 0; j < a.m; ++j) {
        res.mat[i][j] /= sum_e;
      }
    }
    return res;
  }
}
