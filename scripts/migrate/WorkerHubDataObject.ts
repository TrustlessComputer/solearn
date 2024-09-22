
export class Worker {
    constructor(
        public stake: bigint,
        public commitment: bigint,
        public oldModelAddress: string,
        public lastClaimedEpoch: number,
        public activeTime: number,
        public tier: number,            
    ) {

    }

    static fromArray(params: any) {
        return new Worker(
            params[0],
            params[1],
            params[2],
            params[3],
            params[4],
            params[5],
        );
    }

    toArray() {
        return [
            this.stake, 
            this.commitment, 
            this.oldModelAddress, 
            this.lastClaimedEpoch, 
            this.activeTime, 
            this.tier,
        ];
    }
}

export class UnstakeRequest {
    constructor(
        public stake: bigint,
        public unlockAt: number,
    ) {
        
    }

    static fromArray(params: any) {
        return new UnstakeRequest(
            params[0],
            params[1],
        );
    }

    toArray() {
        return [
            this.stake,
            this.unlockAt,
        ];
    }
}

export class Inference {
    constructor(
        public assignments: bigint[],
        public input: string,
        public value: bigint,
        public disputingAddress: string,
        public oldModelAddress: string,
        public expiredAt: number,
        public firstSubmissionId: number,
        public status: number,
        public creator: string,
    ) {
        
    }
    
    static fromArray(params: any) {
        return new Inference(
            params[0],
            params[1],
            params[2],
            params[3],
            params[4],
            params[5],
            params[6],
            params[7],
            params[8],
        );
    }

    toArray() {
        return [
            this.assignments,
            this.input,
            this.value,
            this.disputingAddress,
            this.oldModelAddress,
            this.expiredAt,
            this.firstSubmissionId,
            this.status,
            this.creator,
        ];
    }
}

export class Assignment {
    constructor(
        public inferenceId: string,
        public output: string,
        public worker: string,
        public disapprovalCount: number,
    ) {
        
    }
    
    static fromArray(params: any) {
        return new Assignment(
            params[0],
            params[1],
            params[2],
            params[3],
        );
    }

    toArray() {
        return [
            this.inferenceId,
            this.output,
            this.worker,
            this.disapprovalCount,
        ];
    }
}

export class NewWorker {
    constructor(
        public stake: bigint,
        public commitment: bigint,
        public modelAddress: string,
        public lastClaimedEpoch: number,
        public activeTime: number,
        public tier: number,            
    ) {

    }

    static fromArray(params: any) {
        return new Worker(
            params[0],
            params[1],
            params[2],
            params[3],
            params[4],
            params[5],
        );
    }

    toArray() {
        return [
            this.stake, 
            this.commitment, 
            this.modelAddress, 
            this.lastClaimedEpoch, 
            this.activeTime, 
            this.tier,
        ];
    }
}

export class NewInference {
    constructor(
        public assignments: bigint[],
        public input: string,
        public value: bigint,
        public disputingAddress: string,
        public modelAddress: string,
        public expiredAt: number,
        public firstSubmissionId: number,
        public status: number,
        public creator: string,
    ) {
        
    }
    
    static fromArray(params: any) {
        return new NewInference(
            params[0],
            params[1],
            params[2],
            params[3],
            params[4],
            params[5],
            params[6],
            params[7],
            params[8],
        );
    }

    toArray() {
        return [
            this.assignments,
            this.input,
            this.value,
            this.disputingAddress,
            this.modelAddress,
            this.expiredAt,
            this.firstSubmissionId,
            this.status,
            this.creator,
        ];
    }
}
