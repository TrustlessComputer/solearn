import { ethers } from "ethers";
import { fromFloat, enumElementCount } from "./utils";

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

export enum InputType {
    Image,
    Token,
    Scalar,
};

export enum Activation {
    leakyrelu,
    linear,
    relu,
    sigmoid,
    tanh,
};

export enum Padding {
    valid,
    same
}

export const MaxLayerType = enumElementCount(LayerType);

export function getLayerType(name: string): number {
    const layer = LayerType[name as keyof typeof LayerType];
    return (layer === undefined) ? -1 : layer;
}

export function getLayerName(type: number): string {
    return LayerType[type];
}

export function getActivationType(name: string): number {
    const activation = Activation[name as keyof typeof Activation];
    return (activation === undefined) ? -1 : activation;
}

export function getPaddingType(name: string): number {
    const padding = Padding[name as keyof typeof Padding];
    return (padding === undefined) ? -1 : padding;
}

export function getConvSize(
    dim: number[],
    size: number[],
    stride: number[],
    padding: string,
): { 
    out: number[], 
    pad: number[] 
} {
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

export function getModelConfig(
    params: any, 
    weightsFlat: ethers.BigNumber[],
): {
    newLayerConfig: String[],
    weights: ethers.BigNumber[][][],
    totSize: number[],
} {
    const abic = ethers.utils.defaultAbiCoder;

    let weights: ethers.BigNumber[][][] = [];
    let totSize: number[] = [];
    for (let i = 0; i < MaxLayerType; ++i) {
        weights.push([]);
        totSize.push(0);
    }

    let newLayerConfig = [];
    let input_units: any = 0;
    for (let i = 0; i < params.layers_config.config.layers.length; i++) {
        const layer = params.layers_config.config.layers[i];
        let result: String = "";
        
        let layerType = getLayerType(layer.class_name);        

        if (layer.class_name === 'Dense') {
            const output_units = layer.config.units;
    
            let activationFn: number = getActivationType(layer.config.activation);
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, input_units * output_units + output_units)
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint8", "uint256"], [layerType, activationFn, ethers.BigNumber.from(output_units)]);
            input_units = output_units;
        } else if (layer.class_name === 'Flatten') {
            result = abic.encode(["uint8"], [layerType]);
            input_units = input_units[0] * input_units[1] * input_units[2];
        } else if (layer.class_name === 'Rescaling') {
            const n1 = fromFloat(layer.config.scale);
            const n2 = fromFloat(layer.config.offset);
            // const n2 = ethers.BigNumber.from(layer.config.offset).mul(ethers.BigNumber.from("18446744073709551616"));
            result = abic.encode(["uint8", "int64", "int64"], [layerType, n1, n2]);
        } else if (layer.class_name === 'InputLayer') {
            const dim = layer.config.batch_input_shape.slice(1);
            if (dim.length == 1 || dim.length == 2) {
                result = abic.encode(["uint8", "uint8"], [layerType, InputType.Token]);
                input_units = 1;
            } else if (dim.length == 3) {
                const h = ethers.BigNumber.from(dim[0]);
                const w = ethers.BigNumber.from(dim[1]);
                const c = ethers.BigNumber.from(dim[2]);
                result = abic.encode(["uint8", "uint8", "uint[3]"], [layerType, InputType.Image, [h, w, c]]);
                input_units = [h.toNumber(), w.toNumber(), c.toNumber()];
            }
        } else if (layer.class_name === 'MaxPooling2D') {
            const f_w = layer.config.pool_size[0];
            const f_h = layer.config.pool_size[1];
            const s_w = layer.config.strides[0];
            const s_h = layer.config.strides[1];
            const padding = layer.config.padding;
    
            result = abic.encode(["uint8", "uint[2]", "uint[2]", "uint8"], [
                layerType,
                [ethers.BigNumber.from(f_w), ethers.BigNumber.from(f_h)],
                [ethers.BigNumber.from(s_w), ethers.BigNumber.from(s_h)],
                getPaddingType(padding),
            ]);
    
            const { out } = getConvSize([input_units[0], input_units[1]], [f_w, f_h], [s_w, s_h], padding);
            input_units = [out[0], out[1], input_units[2]];
        } else if (layer.class_name === 'Conv2D') {
            const filters = layer.config.filters;
            const f_w = layer.config.kernel_size[0];
            const f_h = layer.config.kernel_size[1];
            const s_w = layer.config.strides[0];
            const s_h = layer.config.strides[1];
            const padding = layer.config.padding;
            const d = input_units[2];
    
            let activationFn: number = getActivationType(layer.config.activation);
    
            // reconstruct weights
            // Filter: (F_W, F_H, D, K)
            let layerWeights = weightsFlat.splice(0, f_w * f_h * d * filters + filters);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint8", "uint", "uint[2]", "uint[2]", "uint8"], [
                layerType,
                activationFn,
                ethers.BigNumber.from(filters),
                [ethers.BigNumber.from(f_w), ethers.BigNumber.from(f_h)],
                [ethers.BigNumber.from(s_w), ethers.BigNumber.from(s_h)],
                getPaddingType(padding),
            ]);
    
            const { out } = getConvSize([input_units[0], input_units[1]], [f_w, f_h], [s_w, s_h], padding);
            input_units = [out[0], out[1], filters];
        } else if (layer.class_name === 'Embedding') {
            let inputDim = layer.config.input_dim;
            let outputDim = layer.config.output_dim;
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, inputDim * outputDim);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint256", "uint256"], [layerType, ethers.BigNumber.from(inputDim), ethers.BigNumber.from(outputDim)]);
            input_units = outputDim;
        } else if (layer.class_name === 'SimpleRNN') {
            const units = layer.config.units;
            const activationFn: number = getActivationType(layer.config.activation);
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, input_units * units + units * units + units);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint8", "uint256"], [layerType, activationFn, ethers.BigNumber.from(units)]);
            input_units = units;
        } else if (layer.class_name === 'LSTM') {
            const units = layer.config.units;
            console.log("input units to LSTM: ", input_units);
            console.log("LSTM units:", units);
            const activationFn: number = getActivationType(layer.config.activation);
            const recActivationFn: number = getActivationType(layer.config.recurrent_activation);
    
            // reconstruct weights
            let layerWeights = weightsFlat.splice(0, input_units * units * 4 + units * units * 4 + units * 4);
            weights[layerType].push(layerWeights);
            totSize[layerType] += layerWeights.length;
    
            result = abic.encode(["uint8", "uint8", "uint8", "uint256", "uint256"], [layerType, activationFn, recActivationFn, ethers.BigNumber.from(units), ethers.BigNumber.from(input_units)]);
            input_units = units;
        } else {
            continue; // handle dropout etc
        }

        if (result.length > 0) {
            newLayerConfig.push(result);
        }
    }

    return {
        newLayerConfig,
        weights,
        totSize,
    };
}