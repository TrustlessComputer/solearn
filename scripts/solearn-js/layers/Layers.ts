import { Tensors } from "../tensors/Tensors";
import { Tensor1D } from "../tensors/Tensor1D";
import { Tensor2D } from "../tensors/Tensor2D";
import { Tensor3D } from "../tensors/Tensor3D";
import { Tensor4D } from "../tensors/Tensor4D";

export enum LayerType {
  InputLayer,
  Dense,
  Flatten,
  Rescaling,
  MaxPooling2D,
  Conv2D,
  Embedding,
  SimpleRNN,
  LSTM,
};

export class RescaleLayer {
  scale: number;
  offset: number;

  constructor(config: any[]) {
    [ this.scale, this.offset ] = config;
  }

  forward(x: Tensor3D): Tensor3D {
    // console.log("Rescale");
    return Tensor3D.rescale(x, this.scale, this.offset);
  }
}

export class FlattenLayer {
  constructor(config: any) {}

  forward(x: Tensor3D): Tensor1D {
    // console.log("Flatten");
    return Tensor3D.flat(x);
  }
}

export class DenseLayer {
  input_dim: number;
  out_dim: number;
  activation: string;
  bias: boolean;
  w: Tensor2D;
  b: Tensor1D;
  ptrTensor: number;
  ptr: number;

  constructor(config: any[]) {
    [ this.input_dim, this.out_dim, this.activation, this.bias ] = config;
    this.w = Tensor2D.emptyTensor(this.input_dim, this.out_dim);
    this.b = Tensor1D.emptyTensor(this.out_dim);
    this.ptrTensor = 0;
    this.ptr = 0;
  }

  appendWeights(data: number[], idx: number): { idx: number, isDone: boolean } {
		let ptrTensor = this.ptrTensor;
		let ptr = this.ptr;
    let cnt;
    if (ptrTensor == 0) {
      ({ ptr, idx, cnt } = this.w.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    if (ptrTensor == 1) {
      ({ ptr, idx, cnt } = this.b.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    this.ptrTensor = ptrTensor;
    this.ptr = ptr;
    return { idx, isDone: ptrTensor == 2 };
  }

  forward(x: Tensor1D) {
    // console.log("Dense");
    // console.log(x);
    // console.log(this.w);
    // console.log(this.b);
    const y = Tensor1D.add(Tensor1D.matMul(x, this.w), this.b);
    const z = Tensor1D.activation(y, this.activation);
    return z;
  }
}

export class MaxPooling2DLayer {
  size: number[];
  stride: number[];
  padding: string;

  constructor(config: any[]) {
    [this.size, this.stride, this.padding] = config;
  }

  forward(x: Tensor3D): Tensor3D {
    // console.log("MaxPooling2D");
    const y = Tensor3D.maxPooling2D(x, this.size, this.stride, this.padding);
    return y;
  }
}

export class Conv2DLayer {
  inputDim: number;
  filters: number;
  size: number[];
  stride: number[];
  padding: string;
  activation: string;
  w: Tensor4D;
  b: Tensor1D;
  ptrTensor: number;
  ptr: number;

  constructor(config: any[]) { 
    [this.inputDim, this.filters, this.size, this.stride, this.padding, this.activation] = config;
    this.w = Tensor4D.emptyTensor(this.size[0], this.size[1], this.inputDim, this.filters);
    this.b = Tensor1D.emptyTensor(this.filters);
    this.ptrTensor = 0;
    this.ptr = 0;
  }

  appendWeights(data: number[], idx: number): { idx: number, isDone: boolean } {
		let ptrTensor = this.ptrTensor;
		let ptr = this.ptr;
    let cnt;
    if (ptrTensor == 0) {
      ({ ptr, idx, cnt } = this.w.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    if (ptrTensor == 1) {
      ({ ptr, idx, cnt } = this.b.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    this.ptrTensor = ptrTensor;
    this.ptr = ptr;
    return { idx, isDone: ptrTensor == 2 };
  }

  forward(x: Tensor3D): Tensor3D {
    // console.log("Conv2D");
    const y = Tensor3D.conv2D(x, this.w, this.stride, this.padding);
    const z = Tensor3D.add_vector(y, this.b);
    const t = Tensor3D.activation(z, this.activation);
    return t;
  }
}

export class EmbeddingLayer {
  inputDim: number;
  outputDim: number;
  w: Tensor2D;
  ptrTensor: number;
  ptr: number;

  constructor(config: any[]) {
    [this.inputDim, this.outputDim] = config;
    this.w = Tensor2D.emptyTensor(this.inputDim, this.outputDim);
    this.ptrTensor = 0;
    this.ptr = 0;
  }
  
  appendWeights(data: number[], idx: number): { idx: number, isDone: boolean } {
		let ptrTensor = this.ptrTensor;
		let ptr = this.ptr;
    let cnt;
    if (ptrTensor == 0) {
      ({ ptr, idx, cnt } = this.w.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    this.ptrTensor = ptrTensor;
    this.ptr = ptr;
    return { idx, isDone: ptrTensor == 1 };
  }

  forward(x: number): Tensor1D {
    return new Tensor1D(this.w.mat[x]);
  }
}

export class SimpleRNNLayer {
  inputDim: number;
  units: number;
  activation: string;
  w_h: Tensor2D;
  w_x: Tensor2D;
  b: Tensor1D;
  states: Tensor1D;
  ptr: number;
  ptrTensor: number;
  
  constructor(config: any[]) {
    [this.inputDim, this.units, this.activation] = config;
    this.w_x = Tensor2D.emptyTensor(this.inputDim, this.units);
    this.w_h = Tensor2D.emptyTensor(this.units, this.units);
    this.b = Tensor1D.emptyTensor(this.units);
    this.states = Tensor1D.zerosTensor(this.units);
    this.ptr = 0;
    this.ptrTensor = 0;
  }

  appendWeights(data: number[], idx: number): { idx: number, isDone: boolean } {
		let ptrTensor = this.ptrTensor;
		let ptr = this.ptr;
    let cnt;
    if (ptrTensor == 0) {
      ({ ptr, idx, cnt } = this.w_x.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    if (ptrTensor == 1) {
      ({ ptr, idx, cnt } = this.w_h.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    if (ptrTensor == 2) {
      ({ ptr, idx, cnt } = this.b.loadPartial(data, ptr, idx));
      if (ptr == cnt) { ++ptrTensor; ptr = 0; }
    }
    this.ptrTensor = ptrTensor;
    this.ptr = ptr;
    return { idx, isDone: ptrTensor == 3 };
  }

  resetState() {
    this.states = Tensor1D.zerosTensor(this.units);    
  }

  forward(x: Tensor1D): Tensor1D {
    // console.log("SimpleRNN");
    const y_h = Tensor1D.matMul(this.states, this.w_h);
    const y_x = Tensor1D.matMul(x, this.w_x);
    const y = Tensor1D.add(Tensor1D.add(y_h, y_x), this.b);
    const z = Tensor1D.activation(y, this.activation);
    this.states = z;
    return z;
  }
}

export class GELULayer {
  constructor(config: any[]) {}

  forwardTensor1D(x: Tensor1D): Tensor1D {
    return Tensor1D.activation(x, "gelu");
  }
  forwardTensor2D(x: Tensor2D): Tensor2D {
    return Tensor2D.activation(x, "gelu");
  }
  forwardTensor3D(x: Tensor3D): Tensor3D {
    return Tensor3D.activation(x, "gelu");
  }
  forwardTensor4D(x: Tensor4D): Tensor4D {
    return Tensor4D.activation(x, "gelu");
  }
}

export class LayerNorm1D {
  normalizedShape: number;
  w: Tensor1D;

  constructor(config: any[]) {
    [this.normalizedShape] = config;
    this.w = Tensor1D.emptyTensor(this.normalizedShape);    
  }

  forward()
}

export class MLP {
  c_fc: DenseLayer;
  gelu: GELULayer;
  c_proj: DenseLayer;
  ptrLayer: number;

  constructor(configs: any[]) {    
    this.c_fc = new DenseLayer(configs[0]);
    this.gelu = new GELULayer(configs[1]);
    this.c_proj = new DenseLayer(configs[2]);
    this.ptrLayer = 0;
  }

  static makeMLPLayer(configs: any[][], idx: number): [MLP, number] {
    const mlp = new MLP(configs.slice(idx, idx+3));
    return [mlp, idx + 3];
  }

  appendWeights(data: number[], idx: number): { idx: number, isDone: boolean } {
		let ptrLayer = this.ptrLayer;
    let isDone;
    if (ptrLayer == 0) {
      ({ idx, isDone } = this.c_fc.appendWeights(data, idx));
      if (isDone) { ++ptrLayer; }
    }
    if (ptrLayer == 1) {
      ({ idx, isDone } = this.c_proj.appendWeights(data, idx));
      if (isDone) { ++ptrLayer; }
    }
    this.ptrLayer = ptrLayer;
    return { idx, isDone: ptrLayer == 2 };
  }

  forward(x: Tensor1D): Tensor1D {
    // console.log("SimpleRNN");
    x = this.c_fc.forward(x);
    x = this.gelu.forwardTensor1D(x);
    x = this.c_proj.forward(x);
    return x;
  }
}
