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

export function loadModel(layersConfig: any, weights_b64: string) {
  const layers = [];

  const weights = base64ToFloatArray(weights_b64);

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

      const w_array = Array.from(weights.subarray(p, p + w_size));
      p += w_size;
      const b_array = Array.from(weights.subarray(p, p + b_size));
      p += b_size;

      const w_tensor = Tensor2D.load(w_array, dim[0], nxt_dim[0]);
      const b_tensor = Tensor1D.load(b_array, nxt_dim[0]);
      const activation = info.config.activation;

      // console.log(w_tensor);
      // console.log(b_tensor);

      layers.push(new DenseLayer(dim, nxt_dim[0], activation, true, w_tensor, b_tensor));

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

      const w_array = Array.from(weights.subarray(p, p + w_size));
      p += w_size;
      const b_array = Array.from(weights.subarray(p, p + b_size));
      p += b_size;

      const w_tensor = Tensor4D.load(w_array, f_w, f_h, d, filters);
      const b_tensor = Tensor1D.load(b_array, filters);

      // console.log(w_tensor);
      // console.log(b_tensor);

      layers.push(new Conv2DLayer(filters, [f_w, f_h], [s_w, s_h], padding, activation, w_tensor, b_tensor));

      const { out } = Tensors.getConvSize([w, h], [f_w, f_h], [s_w, s_h], padding);
      dim = [out[0], out[1], filters];
      // console.log(L, R, T, B);
    } else if (info.class_name == "Embedding") {
      const inputDim = info.config.input_dim;
      const outputDim = info.config.output_dim;
      
      const w_size = inputDim * outputDim;

      const w_array = weights.subarray(p, p + w_size);
      p += w_size;

      const w_tensor = new Tensor2D(w_array, inputDim, outputDim);

      // console.log(w_tensor);
      // console.log(b_tensor);

      layers.push(new EmbeddingLayer(inputDim, outputDim, w_tensor));

      dim = [outputDim];
    } else if (info.class_name == "SimpleRNN") {
      const units = info.config.units;
      const activation = info.config.activation;
      const inputDim = dim[0];

      const wx_size = inputDim * units;
      const wx_array = weights.subarray(p, p + wx_size);
      p += wx_size;
      const wx_tensor = new Tensor2D(wx_array, inputDim, units);

      const wh_size = units * units;
      const wh_array = weights.subarray(p, p + wh_size);
      p += wh_size;
      const wh_tensor = new Tensor2D(wh_array, units, units);

      const b_size = units;
      const b_array = weights.subarray(p, p + b_size);
      p += b_size;
      const b_tensor = new Tensor1D(b_array, units);

      // console.log(w_tensor);
      // console.log(b_tensor);

      layers.push(new SimpleRNNLayer(units, activation, wh_tensor, wx_tensor, b_tensor));

      dim = [units];
    }
    // console.log(dim);
  }
  const model = new SequentialModel(layers);

  return { model, inputDim };
}
