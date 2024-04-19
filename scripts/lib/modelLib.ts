export function getLayerType(name: string): number {
    let layerType: number = -1;
    if (name === 'Dense') {
        layerType = 0;
    } else if (name === 'Flatten') {
        layerType = 1;
    } else if (name === 'Rescaling') {
        layerType = 2;
    } else if (name === 'InputLayer') {
        layerType = 3;
    } else if (name === 'MaxPooling2D') {
        layerType = 4;
    } else if (name === 'Conv2D') {
        layerType = 5;
    } else if (name === 'Embedding') {
        layerType = 6;
    } else if (name === 'SimpleRNN') {
        layerType = 7;
    } else if (name === 'LSTM') {
        layerType = 8;
    }
    return layerType;
}

export function getLayerName(type: number): string {
    let layerName: string = "N/A";
    if (type === 0) {
        layerName = 'Dense';
    } else if (type === 1) {
        layerName = 'Flatten';
    } else if (type === 2) {
        layerName = 'Rescaling';
    } else if (type === 3) {
        layerName = 'InputLayer';
    } else if (type === 4) {
        layerName = 'MaxPooling2D';
    } else if (type === 5) {
        layerName = 'Conv2D';
    } else if (type === 6) {
        layerName = 'Embedding';
    } else if (type === 7) {
        layerName = 'SimpleRNN';
    } else if (type === 8) {
        layerName = 'LSTM';
    }
    return layerName;
}

export function getActivationType(name: string): number {
    let activationFn: number = -1;
    if (name === 'leakyrelu') {
        activationFn = 0;
    } else if (name === 'linear') {
        activationFn = 1;
    } else if (name === 'relu') {
        activationFn = 2;
    } else if (name === 'sigmoid') {
        activationFn = 3;
    } else if (name === 'tanh') {
        activationFn = 4;
    }
    return activationFn;
}

export function getPaddingType(name: string): number {
    let paddingType: number = -1;
    if (name === "valid") {
        paddingType = 0;
    } else if (name === "same") {
        paddingType = 1;
    }
    return paddingType;
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
