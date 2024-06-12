import {
  LayerType,
  DenseLayer,
  FlattenLayer,
  RescaleLayer,
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
  ptrLayer: number;

  constructor(config: any[]) {
    this.layers = [];
    const type = config[0];
    config = config.slice(1);
    if (type == LayerType.Dense) {
      this.layers.push(new DenseLayer(config));
    } else if (type == LayerType.Flatten) {
      this.layers.push(new FlattenLayer(config));
    } else if (type == LayerType.Rescaling) {
      this.layers.push(new RescaleLayer(config));
    } else if (type == LayerType.MaxPooling2D) {
      this.layers.push(new MaxPooling2DLayer(config));
    } else if (type == LayerType.Conv2D) {
      this.layers.push(new Conv2DLayer(config));
    } else if (type == LayerType.Embedding) {
      this.layers.push(new EmbeddingLayer(config));
    } else if (type == LayerType.SimpleRNN) {
      this.layers.push(new SimpleRNNLayer(config));
    }
    this.ptrLayer = 0;
  }

  appendWeights(data: number[]) {
    let ptrLayer = this.ptrLayer;
    let idx = 0;
    let isDone: boolean;
    while (idx < data.length) {
      if ('appendWeights' in this.layers[ptrLayer]) {
        ({ idx, isDone } = this.layers[ptrLayer].appendWeights(data, idx));
        if (isDone) {
          ++ptrLayer;
        }  
      } else {
        ++ptrLayer;
      }
    }
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

export function loadModel<T extends SequentialModel>(layersConfig: any, weights_b64: string, type: { new(...args : any[]): T ;}): { model: T, inputDim: any } {
  const weights = Array.from(base64ToFloatArray(weights_b64));
  const configs: any[][] = [];

  let dim: any = null;
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
      configs.push([LayerType.Rescaling, info.config.scale, info.config.offset])
    } else if (info.class_name == "Flatten") {
      configs.push([LayerType.Flatten]);
      dim = [dim.reduce((a: number, b: number) => a * b)]
    } else if (info.class_name == "Dense") {
      const nxt_dim = [info.config.units];   
      const activation = info.config.activation;

      configs.push([LayerType.Dense, dim[2], nxt_dim[0], activation, true]);
      dim = nxt_dim;
    } else if (info.class_name == "MaxPooling2D") {
      const [w, h, d] = dim;
      const [f_w, f_h] = info.config.pool_size;
      const [s_w, s_h] = info.config.strides;
      const padding = info.config.padding;

      configs.push([LayerType.MaxPooling2D, [f_w, f_h], [s_w, s_h], padding]);
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

      configs.push([LayerType.Conv2D, d, filters, [f_w, f_h], [s_w, s_h], padding, activation]);
      const { out } = Tensors.getConvSize([w, h], [f_w, f_h], [s_w, s_h], padding);
      dim = [out[0], out[1], filters];
      // console.log(L, R, T, B);
    } else if (info.class_name == "Embedding") {
      const inputDim = info.config.input_dim;
      const outputDim = info.config.output_dim;

      configs.push([LayerType.Embedding, inputDim, outputDim]);
      dim = [outputDim];
    } else if (info.class_name == "SimpleRNN") {
      const units = info.config.units;
      const activation = info.config.activation;

      configs.push([LayerType.SimpleRNN, dim[0], units, activation]);
      dim = [units];
    }
    // console.log(dim);
  }
  const model = new type(configs);
  console.log(configs);
  const txSize = 10000;
  while (weights.length > 0) {
    model.appendWeights(weights.splice(0, txSize));
  }

  return { model, inputDim };
}
