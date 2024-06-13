import { Tensors } from "./Tensors";
import { Tensor1D } from "./Tensor1D";
import { Tensor2D } from "./Tensor2D";

export class Tensor4D {
  n: number;
  m: number;
  p: number;
  q: number;
  mat: number[][][][];

  constructor(mat?: number[][][][]) {
    if (mat) {
      this.n = mat.length;
      this.m = mat[0].length;
      this.p = mat[0][0].length;
      this.q = mat[0][0][0].length;
      this.mat = mat;
    } else {
      this.n = 0;
      this.m = 0;
      this.p = 0;
      this.q = 0;
      this.mat = [];
    }
  }

  static emptyTensor(n: number, m: number, p: number, q: number): Tensor4D {
    const ts = new Tensor4D();
    ts.n = n;
    ts.m = m;
    ts.p = p;
    ts.q = q;
    for(let i = 0; i < n; ++i) {
      ts.mat.push([]);
      for(let j = 0; j < m; ++j) {
        ts.mat[i].push([]);
        for(let k = 0; k < p; ++k) {
          ts.mat[i][j].push([]);
        }
      }
    }
    return ts;
  }

  static load(data: number[], n: number, m: number, p: number, q: number): Tensor4D {
    const ts = Tensor4D.emptyTensor(n, m, p, q);    
    let ptr = 0;
    for(let i = 0; i < n; ++i) {
      for(let j = 0; j < m; ++j) {
        for(let k = 0; k < p; ++k) {
          for(let l = 0; l < q; ++l) {
            ts.mat[i][j][k].push(ptr < data.length ? data[ptr] : 0.0);
            ptr += 1;
          }
        }
      }
    }
    return ts;
  }

	loadPartial(data: number[], ptr: number, idx: number): { ptr: number, idx: number, cnt: number } {
		let m = this.m;
		let p = this.p;
		let q = this.q;
		let cnt = this.n * m * p * q;
		while (idx < data.length && ptr < cnt) {
			this.mat[Math.floor(ptr / (m * p * q))][Math.floor(ptr / (p * q)) % m][Math.floor(ptr / q) % p].push(data[idx]);
			ptr++;
			idx++;
		}
		return { ptr, idx, cnt };
	}

  static zerosTensor(n: number, m: number, p: number, q: number): Tensor4D {
    return Tensor4D.load([], n, m, p, q);
  }

  static cloneTensor(ts: Tensor4D): Tensor4D {
    return Tensor4D.load(ts.mat.flat(3), ts.n, ts.m, ts.p, ts.q);
  }

  static flat(a: Tensor4D): Tensor1D {
    return new Tensor1D(a.mat.flat(3));
  }

  static flatKeep1stDim(a: Tensor4D): Tensor2D {
    return Tensor2D.load(a.mat.flat(3), a.n, a.m * a.p * a.q);
  }

  static __apply_unary_op(a: Tensor4D, op: (x: number) => number): Tensor4D {
    const res = Tensor4D.emptyTensor(a.n, a.m, a.p, a.q);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          for(let l = 0; l < res.q; ++l) {
            res.mat[i][j][k][l] = op(a.mat[i][j][k][l]);
          }
        }
      }
    }
    return res;
  }

  static activation(a: Tensor4D, name: string): Tensor4D {
    switch (name) {
      case "relu": 
        return Tensor4D.__apply_unary_op(a, Tensors.__relu);
      case "sigmoid": 
        return Tensor4D.__apply_unary_op(a, Tensors.__sigmoid);
      case "tanh": 
        return Tensor4D.__apply_unary_op(a, Tensors.__tanh);
      case "leaky_relu": 
        return Tensor4D.__apply_unary_op(a, Tensors.__leaky_relu);
      case "linear":
      default:
        return Tensor4D.__apply_unary_op(a, Tensors.__linear);
    }  
  }

  static __apply_binary_op = (a: Tensor4D, b: Tensor4D, op: (x: number, y: number) => number): Tensor4D => {
    const res = Tensor4D.emptyTensor(a.n, a.m, a.p, a.q);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          for(let l = 0; l < res.p; ++l) {
            res.mat[i][j][k][l] = op(a.mat[i][j][k][l], b.mat[i][j][k][l]);
          }
        }
      }
    }
    return res;
  }

  static add(a: Tensor4D, b: Tensor4D): Tensor4D {
    return Tensor4D.__apply_binary_op(a, b, Tensors.__add);
  }

  static add_scalar(a: Tensor4D, num: number): Tensor4D {
    const res = Tensor4D.zerosTensor(a.n, a.m, a.p, a.q);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          for(let l = 0; l < res.p; ++l) {
            res.mat[i][j][k][l] = a.mat[i][j][k][l] + num;
          }
        }
      }
    }
    return res;
  }

  static mul(a: Tensor4D, b: Tensor4D): Tensor4D {
    return Tensor4D.__apply_binary_op(a, b, Tensors.__mul);
  }

  static mul_scalar(a: Tensor4D, num: number): Tensor4D {
    const res = Tensor4D.zerosTensor(a.n, a.m, a.p, a.q);
    for(let i = 0; i < res.n; ++i) {
      for(let j = 0; j < res.m; ++j) {
        for(let k = 0; k < res.p; ++k) {
          for(let l = 0; l < res.p; ++l) {
            res.mat[i][j][k][l] = a.mat[i][j][k][l] * num;
          }
        }
      }
    }
    return res;
  }

  static rescale(a: Tensor4D, scale: number, offset: number): Tensor4D {
    return Tensor4D.__apply_unary_op(a, (x) => x * scale + offset);
  }

  // Input: (N, W, H, D)
  // Filter: (F_W, F_H, D, K)
  static conv2D(a: Tensor4D, b: Tensor4D, stride: number[], padding: string) {
    const n = a.n, w = a.m, h = a.p, d = a.q;
    const f_w = b.n, f_h = b.m, k = b.q;
    const size = [f_w, f_h];
    const { out, pad } = Tensors.getConvSize([w, h], size, stride, padding);

    const res = Tensor4D.zerosTensor(n, out[0], out[1], k);
    for(let i = 0; i < n; ++i) {
      for(let x = 0; x < out[0]; ++x) {
        for(let y = 0; y < out[1]; ++y) {
          for(let p = 0; p < k; ++p) {
            let cell = 0;
            for(let dx = 0; dx < size[0]; ++dx) {
              for(let dy = 0; dy < size[1]; ++dy) {
                const X = x*stride[0] + dx - pad[0], Y = y*stride[1] + dy - pad[1];
                if (X >= 0 && X < w && Y >= 0 && Y < h) {
                  for(let q = 0; q < d; ++q) {
                    cell += a.mat[i][X][Y][q] * b.mat[dx][dy][q][p];
                  }  
                }
              }
            }
            res.mat[i][x][y][p] = cell;
          }
        }
      }
    }

    // console.log(res);

    return res;
  }

  // Input: (N, W, H, D)
  static maxPooling2D(a: Tensor4D, size: number[], stride: number[], padding: string) {
    const n = a.n, w = a.m, h = a.p, d = a.q;
    const { out, pad } = Tensors.getConvSize([w, h], size, stride, padding);

    const res = Tensor4D.zerosTensor(n, out[0], out[1], d);
    for(let i = 0; i < n; ++i) {
      for(let x = 0; x < out[0]; ++x) {
        for(let y = 0; y < out[1]; ++y) {
          for(let p = 0; p < d; ++p) {            
            let cell = -1e9;
            for(let dx = 0; dx < size[0]; ++dx) {
              for(let dy = 0; dy < size[1]; ++dy) {
                const X = x*stride[0] + dx - pad[0], Y = y*stride[1] + dy - pad[1];
                const isIn = (X >= 0 && X < w && Y >= 0 && Y < h);
                const val = isIn ? a.mat[i][X][Y][p] : 0;
                cell = Math.max(cell, val);
              }
            }
            res.mat[i][x][y][p] = cell;
          }
        }
      }
    }

    return res;
  }

  static softmax(a: Tensor4D): Tensor4D {
    const res = Tensor4D.__apply_unary_op(a, x => Math.exp(x));
    const sum_e = res.mat.flat(3).reduce((a, b) => a + b);
    for(let i = 0; i < a.n; ++i) {
      for(let j = 0; j < a.m; ++j) {
        for(let k = 0; k < a.p; ++k) {
          for(let l = 0; l < a.q; ++l) {
            res.mat[i][j][k][l] /= sum_e;
          }
        }
      }
    }
    return res;
  }
}
