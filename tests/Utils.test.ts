import { expect, assert } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { TestUtils } from '../typechain-types';
import { RandomSeed, create } from 'random-seed';
import bigDecimal from 'js-big-decimal';

const TEST_ROUND = 1000;
const EPSILON = 2;

function hexToFloat64(hexString: string) {
    if (hexString.slice(0, 2) == '0x') hexString = hexString.slice(2);

    if (hexString.length !== 16) {
        throw new Error('Hex string must be 16 characters long.');
    }

    // Convert hex string to bytes
    const bytes = new Uint8Array(hexString.match(/[\da-f]{2}/gi)!.map(byte => parseInt(byte, 16)));

    // Create a buffer and a view to interpret it as a float64
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);

    // Set bytes in the buffer. Assuming big-endian.
    bytes.forEach((byte, i) => {
        view.setUint8(i, byte);
    });

    // Read the buffer as a float64
    return view.getFloat64(0, false); // false for big-endian
}

function float64ToHex(float64: number) {
    // Create an ArrayBuffer with a size of 8 bytes (64 bits)
    const buffer = new ArrayBuffer(8);
    // Create a DataView to interact with the buffer
    const view = new DataView(buffer);

    // Set the float64 value into the buffer
    view.setFloat64(0, float64, false); // 'false' for big-endian (IEEE 754 standard)

    // Convert the buffer to a hexadecimal string
    let hex = '';
    for (let i = 0; i < 8; i++) {
        // Extract each byte from the buffer
        const byte = view.getUint8(i);
        // Convert the byte to a hexadecimal string and pad with zero if necessary
        hex += byte.toString(16).padStart(2, '0');
    }

    return '0x' + hex;
}

let testContract: TestUtils, randomizer: RandomSeed;

describe('Utils', async () => {
    before(async () => {
        const seed = new Date().toLocaleString()
        console.log("Seed random: \"" + seed + "\"")
        randomizer = create(seed);
    });

    beforeEach(async () => {
        const TestUtils = await ethers.getContractFactory('TestUtils');
        testContract = await TestUtils.deploy();
        await testContract.deployed();
    });

    describe('1. fixedPointNumberToFloatPointNumber(SD59x18)', async () => {
        it.skip('1.0. Singular test', async () => {
            const decimal = 0.0024306520183362545
            const input = (new bigDecimal(decimal))
                .multiply(new bigDecimal('1000000000000000000'))
                .round();
            const result = await testContract.fixedPointNumberToFloatPointNumber(input.getValue());
            const expected_result = float64ToHex(decimal);
            console.log(result, BigNumber.from(result).toString());
            console.log(expected_result, BigNumber.from(expected_result).toString());
        });

        it('1.1. Special cases', async () => {
            let input, result;

            // Describe:        0
            // Decimal value:   0
            // Fixed value:     0
            input = '0'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0x0000000000000000', `Convert failed for input: ${input}`);

            // Describe:        -1e-18
            // Decimal value:   -0.000000000000000001
            // Fixed value:     -1
            input = '-1'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0xbc32725dd1d243ab', `Convert failed for input: ${input}`);

            // Describe:        1e-18
            // Decimal value:   0.000000000000000001
            // Fixed value:     1
            input = '1'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0x3c32725dd1d243ab', `Convert failed for input: ${input}`);

            // Describe:        -2^52
            // Decimal value:   -4503599627370496
            // Fixed value:     -4503599627370496000000000000000000
            input = '-4503599627370496000000000000000000'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0xc330000000000000', `Convert failed for input: ${input}`);

            // Describe:        2^52 - 1
            // Decimal value:   4503599627370495
            // Fixed value:     4503599627370495000000000000000000
            input = '4503599627370495000000000000000000'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0x432ffffffffffffd', `Convert failed for input: ${input}`);


            // Describe:        -2^63
            // Decimal value:   -9223372036854775808
            // Fixed value:     -9223372036854775808000000000000000000
            input = '-9223372036854775808000000000000000000'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0xc3e0000000000000', `Convert failed for input: ${input}`);

            // Describe:        2^63 - 1
            // Decimal value:   9223372036854775807
            // Fixed value:     9223372036854775807000000000000000000
            input = '9223372036854775807000000000000000000'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0x43dfffffffffffff', `Convert failed for input: ${input}`);

            // Describe:        -2^255
            // Decimal value:   -57896044618658097711785492504343953926634992332820282019728.792003956564819968
            // Fixed value:     -57896044618658097711785492504343953926634992332820282019728792003956564819968
            input = '-57896044618658097711785492504343953926634992332820282019728792003956564819968'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0xcfe0000000000000', `Convert failed for input: ${input}`);

            // Describe:        2^255 - 1
            // Decimal value:   57896044618658097711785492504343953926634992332820282019728.792003956564819967
            // Fixed value:     57896044618658097711785492504343953926634992332820282019728792003956564819967
            input = '57896044618658097711785492504343953926634992332820282019728792003956564819967'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0x4c22725dd1d243ab', `Convert failed for input: ${input}`);
        });

        it('1.2. Exponents of 2', async () => {
            let input, result, expected_result;

            // Describe:        1
            // Decimal value:   1
            // Fixed value:     1000000000000000000
            input = '1000000000000000000'
            result = await testContract.fixedPointNumberToFloatPointNumber(input);
            expect(result).to.equals('0x3ff0000000000000', `Convert failed for input: ${input}`);

            //Only 18 first negative integer exponents of 2 follows pattern `0x???fffffffffffff`

            expected_result = '0x3fefffffffffffff';
            for (let i = -1; i >= -18; --i) {
                input = BigNumber.from('1000000000000000000').div(BigNumber.from('2').pow(-i));
                result = await testContract.fixedPointNumberToFloatPointNumber(input);
                expected_result = BigNumber.from(expected_result).sub('0x0010000000000000').toHexString();
                expect(result).to.equals(expected_result, `Convert failed for input: ${input}`);
            }

            input = BigNumber.from('1000000000000000000');
            expected_result = '0x3ff0000000000000';
            for (let i = 1; i <= 192; ++i) {
                input = input.mul(2);
                result = await testContract.fixedPointNumberToFloatPointNumber(input);
                expected_result = BigNumber.from(expected_result).add('0x0010000000000000').toHexString();
                expect(result).to.equals(expected_result, `Convert failed for input: ${input}`);
            }
        });

        it('1.3. Absolute value greater than 1', async () => {
            for (let round = 1; round <= TEST_ROUND; ++round) {
                const decimal = randomizer.floatBetween(1, 4503599627370495)
                    * (randomizer.intBetween(0, 1) ? 1 : -1);
                const input = (new bigDecimal(decimal))
                    .multiply(new bigDecimal('1000000000000000000'))
                    .round();
                const result = await testContract.fixedPointNumberToFloatPointNumber(input.getValue());
                const expected_result = float64ToHex(decimal);
                expect(Math.abs(BigNumber.from(result).sub(BigNumber.from(expected_result)).toNumber()))
                    .to.be.lte(EPSILON, `Too great numerical error for number: ${decimal}`);
                if (round % 100 == 0) {
                    console.log(`Tested ${round} instances`);
                }
            }
        });

        it('1.4. Absolute value smaller than 1', async () => {
            for (let round = 1; round <= TEST_ROUND; ++round) {
                const decimal = randomizer.floatBetween(0, 1)
                    * (randomizer.intBetween(0, 1) ? 1 : -1);
                const input = (new bigDecimal(decimal))
                    .multiply(new bigDecimal('1000000000000000000'))
                    .round();
                const result = await testContract.fixedPointNumberToFloatPointNumber(input.getValue());
                const expected_result = float64ToHex(decimal);
                expect(Math.abs(BigNumber.from(result).sub(BigNumber.from(expected_result)).toNumber()))
                    .to.be.lte(EPSILON, `Too great numerical error for number: ${decimal}`);
                if (round % 100 == 0) {
                    console.log(`Tested ${round} instances`);
                }
            }
        });
    });

    describe('2. floatPointNumberToFixedPointNumber(bytes8)', async () => {
        it.skip('2.0. Singular test', async () => {
            const decimal = -0.0004224125190573913;
            const hex = float64ToHex(decimal);
            const output = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
            let result = (new bigDecimal(output))
                .divide(new bigDecimal('1000000000000000000'), 18)
                .getValue();
            let expected_result = hexToFloat64(hex).toString();
            let l = Math.min(Math.min(result.length, expected_result.length), 15);
            result = result.slice(0, l);
            expected_result = expected_result.slice(0, l);
            console.log(result);
            console.log(expected_result);
        });

        it('2.1. Special cases', async () => {
            let hex, result

            // Describe:    0
            // Hex:         0x0000000000000000
            // Decimal:     0
            hex = '0x0000000000000000';
            result = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
            expect(result).to.equals('0', `Convert failed for input: ${hex}`);

            // Describe:    -1e-10
            // Hex:         0xbddb7cdfd9d7bdbb
            // Decimal:     0.000000001
            hex = '0xbddb7cdfd9d7bdbb';
            result = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
            expect(result).to.equals('-99999989', `Convert failed for input: ${hex}`);
            // numercial error 0.000000000000000011

            // Describe:    1e-10
            // Hex:         0x3ddb7cdfd9d7bdbb
            hex = '0x3ddb7cdfd9d7bdbb';
            result = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
            expect(result).to.equals('99999989', `Convert failed for input: ${hex}`);
            // numercial error 0.000000000000000011

            // Describe:    -2^52
            // Hex:         0xc330000000000000
            // Decimal:     -4503599627370496
            hex = '0xc330000000000000';
            result = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
            expect(result).to.equals('-4503599627370496000000000000000000', `Convert failed for input: ${hex}`);

            // Describe:    2^52 - 1
            // Hex:         0x432ffffffffffffd
            // Decimal:     45035996273704945
            hex = '0x432ffffffffffffd';
            result = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
            expect(result).to.equals('4503599627370494500000000000000000', `Convert failed for input: ${hex}`);
            // numerical error 5
        });

        it('2.2. Absolute value greater than 1', async () => {
            for (let round = 1; round <= TEST_ROUND; ++round) {
                const decimal = randomizer.floatBetween(1, 4503599627370495)
                    * (randomizer.intBetween(0, 1) ? 1 : -1);
                const hex = float64ToHex(decimal);

                const output = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
                let result = (new bigDecimal(output))
                    .divide(new bigDecimal('1000000000000000000'), 18)
                    .getValue();
                let expected_result = hexToFloat64(hex).toString();

                let l = Math.min(Math.min(result.length, expected_result.length), 15);

                result = result.slice(0, l);
                expected_result = expected_result.slice(0, l);

                expect(result).to.equals(expected_result, `Too great numerical error for number: ${decimal}`);
                if (round % 100 == 0) {
                    console.log(`Tested ${round} instances`);
                }
            }
        });

        it('2.3. Absolute value smaller than 1', async () => {
            for (let round = 1; round <= TEST_ROUND; ++round) {
                const decimal = randomizer.floatBetween(0, 1)
                    * (randomizer.intBetween(0, 1) ? 1 : -1);
                const hex = float64ToHex(decimal);

                const output = (await testContract.floatPointNumberToFixedPointNumber(hex)).toString();
                let result = (new bigDecimal(output))
                    .divide(new bigDecimal('1000000000000000000'), 18)
                    .getValue();
                let expected_result = hexToFloat64(hex).toString();

                let l = Math.min(Math.min(result.length, expected_result.length), 15);

                result = result.slice(0, l);
                expected_result = expected_result.slice(0, l);

                expect(result).to.equals(expected_result, `Too great numerical error for number: ${decimal}`);
                if (round % 100 == 0) {
                    console.log(`Tested ${round} instances`);
                }
            }
        });
    });
});
