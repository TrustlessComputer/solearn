import { RandomSeed, create } from 'random-seed';

export class RandomUtils {
  rand: RandomSeed;

  constructor(seed: string) {
    this.rand = create(seed);
  }

  getRandomItem(items: any[]): any {
    let tot = 0;
    for(const e of items) {
      tot += e[1];
    }

    let x = this.rand.floatBetween(0, tot);
    let sum = 0;
    for(const e of items) {
      sum += e[1];
      if (x < sum) return e[0];
    }
    return null;
  }
}