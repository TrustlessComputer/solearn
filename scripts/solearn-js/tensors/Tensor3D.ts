import { Tensors } from "./Tensors";
import { Tensor1D } from "./Tensor1D";
import type { Tensor4D } from "./Tensor4D";

export class Tensor3D {
  n: number;
  m: number;
  p: number;
  mat: number[][][];

  constructor(mat?: number[][][]) {
    if (mat) {
      this.n = mat.length;
      this.m = mat[0].length;
      this.p = mat[0][0].length;
      this.mat = mat;
    } else {
      this.n = 0;
      this.m = 0;
      this.p = 0;
      this.mat = [];
    }
  }

  static emptyTensor(n: number, m: number, p: number): Tensor3D {
    const ts = new Tensor3D();
    ts.n = n;
    ts.m = m;
    ts.p = p;
    for(let i = 0; i < n; ++i) {
      ts.mat.push([]);
      for(let j = 0; j < m; ++j) {
        ts.mat[i].push([]);
      }
    }
    return ts;
  }

  static load(data: number[], n: number, m: number, p: number): Tensor3D {
    const ts = Tensor3D.emptyTensor(n, m, p);    
    let ptr = 0;
    for(let i = 0; i < n; ++i) {
      for(let j = 0; j < m; ++j) {
        for(let k = 0; k < p; ++k) {
          ts.mat[i][j].push(ptr < data.length ? data[ptr] : 0.0);
          ptr += 1;
        }
      }
    }
    return ts;
  }

  static zerosTensor(n: number, m: number, p: number): Tensor3D {
    return Tensor3D.load([], n, m, p);
  }

  static cloneTensor(ts: Tensor3D): Tensor3D {
    return Tensor3D.load(ts.mat.flat(2), ts.n, ts.m, ts.p);
  }

  static flat(a: Tensor3D): Tensor1D {
    return new Tensor1D(a.mat.flat(2));
  }

  static __apply_unary_op(a: Tensor3D, op: (x: number) => number): Tensor3D {
    const res = Tensor3D.emptyTensor(a.n, a.m, a.p);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          res.mat[i][j][k] = op(a.mat[i][j][k]);
        }
      }
    }
    return res;
  }

  static activation(a: Tensor3D, name: string): Tensor3D {
    switch (name) {
      case "relu": 
        return Tensor3D.__apply_unary_op(a, Tensors.__relu);
      case "sigmoid": 
        return Tensor3D.__apply_unary_op(a, Tensors.__sigmoid);
      case "tanh": 
        return Tensor3D.__apply_unary_op(a, Tensors.__tanh);
      case "leaky_relu": 
        return Tensor3D.__apply_unary_op(a, Tensors.__leaky_relu);
      case "linear":
      default:
        return Tensor3D.__apply_unary_op(a, Tensors.__linear);
    }  
  }

  static __apply_binary_op = (a: Tensor3D, b: Tensor3D, op: (x: number, y: number) => number): Tensor3D => {
    const res = Tensor3D.emptyTensor(a.n, a.m, a.p);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          res.mat[i][j][k] = op(a.mat[i][j][k], b.mat[i][j][k]);
        }
      }
    }
    return res;
  }

  static __apply_binary_op_scalar = (a: Tensor3D, b: number, op: (x: number, y: number) => number): Tensor3D => {
    const res = Tensor3D.emptyTensor(a.n, a.m, a.p);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          res.mat[i][j][k] = op(a.mat[i][j][k], b);
        }
      }
    }
    return res;
  }

  static __apply_binary_op_vector = (a: Tensor3D, b: Tensor1D, op: (x: number, y: number) => number): Tensor3D => {
    const res = Tensor3D.emptyTensor(a.n, a.m, a.p);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          res.mat[i][j][k] = op(a.mat[i][j][k], b.mat[k]);
        }
      }
    }
    return res;
  }

  static add(a: Tensor3D, b: Tensor3D): Tensor3D {
    return Tensor3D.__apply_binary_op(a, b, Tensors.__add);
  }

  static add_scalar(a: Tensor3D, num: number): Tensor3D {
    return Tensor3D.__apply_binary_op_scalar(a, num, Tensors.__add);
  }

  static add_vector(a: Tensor3D, b: Tensor1D): Tensor3D {
    return Tensor3D.__apply_binary_op_vector(a, b, Tensors.__add);
  }

  static mul(a: Tensor3D, b: Tensor3D): Tensor3D {
    return Tensor3D.__apply_binary_op(a, b, Tensors.__mul);
  }

  static mul_scalar(a: Tensor3D, num: number): Tensor3D {
    return Tensor3D.__apply_binary_op_scalar(a, num, Tensors.__mul);
  }

  static mul_vector(a: Tensor3D, b: Tensor1D): Tensor3D {
    return Tensor3D.__apply_binary_op_vector(a, b, Tensors.__mul);
  }

  static rescale(a: Tensor3D, scale: number, offset: number): Tensor3D {
    return Tensor3D.__apply_unary_op(a, (x) => x * scale + offset);
  }

  // Input: (W, H, D)
  // Filter: (F_W, F_H, D, K)
  static conv2D(a: Tensor3D, b: Tensor4D, stride: number[], padding: string) {
    const w = a.n, h = a.m, d = a.p;
    const f_w = b.n, f_h = b.m, k = b.q;
    const size = [f_w, f_h];
    const { out, pad } = Tensors.getConvSize([w, h], size, stride, padding);

    const res = Tensor3D.zerosTensor(out[0], out[1], k);
    for(let x = 0; x < out[0]; ++x) {
      for(let y = 0; y < out[1]; ++y) {
        for(let p = 0; p < k; ++p) {
          let cell = 0;
          for(let dx = 0; dx < size[0]; ++dx) {
            for(let dy = 0; dy < size[1]; ++dy) {
              const X = x*stride[0] + dx - pad[0], Y = y*stride[1] + dy - pad[1];
              if (X >= 0 && X < w && Y >= 0 && Y < h) {
                for(let q = 0; q < d; ++q) {
                  cell += a.mat[X][Y][q] * b.mat[dx][dy][q][p];
                }
              }
            }
          }
          res.mat[x][y][p] = cell;
        }
      }
    }

    // console.log(res);

    return res;
  }

  // Input: (W, H, D)
  static maxPooling2D(a: Tensor3D, size: number[], stride: number[], padding: string) {
    const w = a.n, h = a.m, d = a.p;    
    const { out, pad } = Tensors.getConvSize([w, h], size, stride, padding);

    const res = Tensor3D.zerosTensor(out[0], out[1], d);
    for(let x = 0; x < out[0]; ++x) {
      for(let y = 0; y < out[1]; ++y) {
        for(let p = 0; p < d; ++p) {            
          let cell = -1e9;
          for(let dx = 0; dx < size[0]; ++dx) {
            for(let dy = 0; dy < size[1]; ++dy) {
              const X = x*stride[0] + dx - pad[0], Y = y*stride[1] + dy - pad[1];
              const isIn = (X >= 0 && X < w && Y >= 0 && Y < h);
              const val = isIn ? a.mat[X][Y][p] : 0;
              cell = Math.max(cell, val);
            }
          }
          res.mat[x][y][p] = cell;
        }
      }
    }

    return res;
  }

  static softmax(a: Tensor3D): Tensor3D {
    const res = Tensor3D.__apply_unary_op(a, x => Math.exp(x));
    const sum_e = res.mat.flat(2).reduce((a, b) => a + b);
    for(let i = 0; i < a.n; ++i) {
      for(let j = 0; j < a.m; ++j) {
        for(let k = 0; k < a.p; ++k) {
          res.mat[i][j][k] /= sum_e;
        }
      }
    }
    return res;
  }
}
