import { Tensors } from "../tensors/Tensors";
import { Tensor1D } from "../tensors/Tensor1D";
import { Tensor2D } from "../tensors/Tensor2D";
import { Tensor3D } from "../tensors/Tensor3D";
import { Tensor4D } from "../tensors/Tensor4D";

export class RescaleLayer {
  scale: number;
  offset: number;

  constructor(scale: number, offset: number) {
    this.scale = scale;
    this.offset = offset;
  }

  forward(x: Tensor3D): Tensor3D {
    // console.log("Rescale");
    return Tensor3D.rescale(x, this.scale, this.offset);
  }
}

export class FlattenLayer {
  constructor() {}

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

  constructor(input_dim: number, out_dim: number, activation: string, bias: boolean, data: number[], dim: number[]) {
    this.input_dim = input_dim;
    this.out_dim = out_dim;
    this.activation = activation;
    this.bias = bias;
    this.w = Tensor2D.load(data.splice(0, input_dim * out_dim), input_dim, out_dim);
    this.b = Tensor1D.load(data.splice(0, out_dim), out_dim);
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

  constructor(size: number[], stride: number[], padding: string) {
    this.size = size;
    this.stride = stride;
    this.padding = padding;
  }

  forward(x: Tensor3D): Tensor3D {
    // console.log("MaxPooling2D");
    const y = Tensor3D.maxPooling2D(x, this.size, this.stride, this.padding);
    return y;
  }
}

export class Conv2DLayer {
  filters: number;
  size: number[];
  stride: number[];
  padding: string;
  activation: string;
  w: Tensor4D;
  b: Tensor1D;
  
  constructor(filters: number, size: number[], stride: number[], padding: string, activation: string, data: number[], dim: number[]) {
    this.filters = filters;
    this.size = size;
    this.stride = stride;
    this.padding = padding;
    this.activation = activation;
    this.w = Tensor4D.load(data.splice(0, size[0] * size[1] * dim[2] * filters), size[0], size[1], dim[2], filters);
    this.b = Tensor1D.load(data.splice(0, filters), filters);
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

  constructor(inputDim: number, outputDim: number, w: number[]) {
    this.inputDim = inputDim;
    this.outputDim = outputDim;
    this.w = Tensor2D.load(w.splice(0, inputDim * outputDim), inputDim, outputDim);
  }

  forward(x: number): Tensor1D {
    return new Tensor1D(this.w.mat[x]);
  }
}

export class SimpleRNNLayer {
  units: number;
  activation: string;
  w_h: Tensor2D;
  w_x: Tensor2D;
  b: Tensor1D;
  states: Tensor1D;
  
  constructor(units: number, activation: string, data: number[], dim: number[]) {
    this.units = units;
    this.activation = activation;
    this.w_x = Tensor2D.load(data.splice(0, dim[0] * units), dim[0], units);
    this.w_h = Tensor2D.load(data.splice(0, units * units), units, units);
    this.b = Tensor1D.load(data.splice(0, units), units);
    this.states = Tensor1D.zerosTensor(this.units);
  }

  reset_state() {
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
