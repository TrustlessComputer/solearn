import {
  RescaleLayer,
  FlattenLayer,
  DenseLayer,
  MaxPooling2DLayer,
  Conv2DLayer,
  EmbeddingLayer,
  SimpleRNNLayer,
} from "../layers/Layers";

import { Tensors } from "../tensors/Tensors";
import { Tensor1D } from "../tensors/Tensor1D";
import { Tensor2D } from "../tensors/Tensor2D";
import { Tensor3D } from "../tensors/Tensor3D";
import { Tensor4D } from "../tensors/Tensor4D";

import { base64ToFloatArray } from '../utils/utils';

class SequentialModel {
  layers: any[];

  constructor(layers: any[]) {
    this.layers = layers;
  }

  forward(x: any) {
    // console.log(x);
    for (const layer of this.layers) {
      x = layer.forward(x);
      // console.log(x);
    }
    return x;
  }
}

export class ImageClassifier extends SequentialModel {
  forward(x: Tensor3D): Tensor1D {
    return super.forward(x);
  }
}

export class TextGenerator extends SequentialModel {
  forward(x: number): Tensor1D {
    return super.forward(x);
  }
}

export function loadModel<T>(layersConfig: any, weights_b64: string, type: { new(...args : any[]): T ;}): { model: T, inputDim: any } {
  const layers = [];

  const weights = Array.from(base64ToFloatArray(weights_b64));

  let dim: any = null;
  let p = 0;
  let inputDim = [];
  for(const info of layersConfig.config.layers) {
    // console.log(info.class_name);
    if (info.class_name == "InputLayer") {
      dim = info.config.batch_input_shape.slice(1);
      if (dim.length == 1 && dim[0] == null) {
        dim = 1;
      }
      inputDim = dim;
    } else if (info.class_name == "Rescaling") {
      layers.push(new RescaleLayer(info.config.scale, info.config.offset))
    } else if (info.class_name == "Flatten") {
      layers.push(new FlattenLayer())
      dim = [dim.reduce((a: number, b: number) => a * b)]
    } else if (info.class_name == "Dense") {
      const nxt_dim = [info.config.units];
      const w_size = dim[0] * nxt_dim[0];
      const b_size = nxt_dim[0];

      const data = weights.splice(0, w_size + b_size);
    
      const activation = info.config.activation;

      layers.push(new DenseLayer(dim, nxt_dim[0], activation, true, data, dim));

      dim = nxt_dim;
    } else if (info.class_name == "MaxPooling2D") {
      const [w, h, d] = dim;
      const [f_w, f_h] = info.config.pool_size;
      const [s_w, s_h] = info.config.strides;
      const padding = info.config.padding;

      layers.push(new MaxPooling2DLayer([f_w, f_h], [s_w, s_h], padding));

      const { out } = Tensors.getConvSize([w, h], [f_w, f_h], [s_w, s_h], padding);
      dim = [out[0], out[1], d];
      // console.log(L, R, T, B);
    } else if (info.class_name == "Conv2D") {
      const [w, h, d] = dim;
      const [f_w, f_h] = info.config.kernel_size;
      const [s_w, s_h] = info.config.strides;
      const filters = info.config.filters
      const padding = info.config.padding;
      const activation = info.config.activation;

      const w_size = f_w * f_h * d * filters;
      const b_size = filters;

      const data = weights.splice(0, w_size + b_size);

      layers.push(new Conv2DLayer(filters, [f_w, f_h], [s_w, s_h], padding, activation, data, dim));

      const { out } = Tensors.getConvSize([w, h], [f_w, f_h], [s_w, s_h], padding);
      dim = [out[0], out[1], filters];
      // console.log(L, R, T, B);
    } else if (info.class_name == "Embedding") {
      const inputDim = info.config.input_dim;
      const outputDim = info.config.output_dim;
      
      const w_size = inputDim * outputDim;

      const data = weights.splice(0, w_size);

      layers.push(new EmbeddingLayer(inputDim, outputDim, data));

      dim = [outputDim];
    } else if (info.class_name == "SimpleRNN") {
      const units = info.config.units;
      const activation = info.config.activation;
      const inputDim = dim[0];

      const wx_size = inputDim * units;
      const wh_size = units * units;
      const b_size = units;

      const data = weights.splice(0, wx_size + wh_size + b_size);

      layers.push(new SimpleRNNLayer(units, activation, data, dim));

      dim = [units];
    }
    // console.log(dim);
  }
  const model = new type(layers);

  return { model, inputDim };
}
