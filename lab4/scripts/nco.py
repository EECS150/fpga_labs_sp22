#!/usr/bin/env python3
# Requires: pip install spfpm

from FixedPoint import FXfamily, FXnum
from enum import Enum, auto
import numpy as np
import sys
from typing import Tuple
import argparse

NCOType = Tuple[FXnum, FXnum, FXnum, FXnum]
output_type = FXfamily(n_bits=16, n_intbits=4)

class NCO:
    def __init__(self, fsamp: float, interpolate: bool) -> None:
        self.fsamp = fsamp
        self.interpolate = interpolate
        self.output_type = output_type
        self.phase_acc = 0 # type: int
        self.N = 24
        self.M = 8
        self.lut_entries = 2**self.M
        self.DAC = 1024

        self.sine_lut_float = [np.sin(i * 2*np.pi / self.lut_entries) for i in range(self.lut_entries)]
        self.sine_lut_fixed = [FXnum(x, family=self.output_type) for x in self.sine_lut_float]
        self.sine_lut_int = [int((x + 1) * self.DAC / 2) for x in self.sine_lut_float]

        self.square_lut_fixed = [FXnum(1, family=self.output_type) for x in range(int(self.lut_entries/2))] + \
            [FXnum(-1, family=self.output_type) for x in range(int(self.lut_entries/2))]

        self.triangle_lut_float = [np.max(1 - np.abs(x)) for x in np.linspace(-1, 1, self.lut_entries)]
        self.triangle_lut_float = [x*2 - 1 for x in self.triangle_lut_float] # scale to range from -1 to 1
        self.triangle_lut_fixed = [FXnum(x, family=self.output_type) for x in self.triangle_lut_float]

        self.sawtooth_lut_float = [x - np.floor(x) for x in np.linspace(0, 1-1e-16, self.lut_entries)]
        self.sawtooth_lut_float = [x*2 - 1 for x in self.sawtooth_lut_float] # scaling again
        self.sawtooth_lut_fixed = [FXnum(x, family=self.output_type) for x in self.sawtooth_lut_float]

    def next_sample(self, fcw: int) -> NCOType:
        lut_index = (self.phase_acc >> (self.N - self.M)) & int('1'*self.M, 2) # take MSB M bits of phase_acc
        samples = []
        for lut in [self.sine_lut_fixed, self.square_lut_fixed, self.triangle_lut_fixed, self.sawtooth_lut_fixed]:
            if self.interpolate is False:
                samples.append(lut[lut_index])
            else:
                samp1 = lut[lut_index]
                samp2 = lut[(lut_index + 1) % self.lut_entries]
                residual = self.phase_acc & int('1'*(self.N - self.M), 2) # take LSB (N-M) bits of phase_acc
                residual = FXnum(residual/(2**(self.N - self.M)), family=self.output_type) # Cast residual as fixed point
                diff = samp2 - samp1
                samples.append(samp1 + residual*diff)

        self.phase_acc = self.phase_acc + fcw
        self.phase_acc = self.phase_acc % 2**self.N # overflow on N bits
        return samples

    def next_sample_f(self, freq: float) -> Tuple[FXnum, FXnum, FXnum, FXnum]:
        return self.next_sample(self.phase_increment(freq))

    def phase_increment(self, freq: float) -> int:
        return int(round((freq / self.fsamp) * 2**self.N))

    def effective_frequency(self, phase_increment: int) -> float:
        return (phase_increment * self.fsamp) / (2**self.N)

    def reset(self) -> None:
        self.phase_acc = 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='NCO Model')
    parser.add_argument('--analysis', dest='analysis', action='store_true', help='compare ideal sampling with NCO samples')
    # parser.add_argument('--golden', dest='golden', action='store_true', help='dump golden NCO samples for comparison with RTL')
    parser.add_argument('--sine-lut', dest='sine_lut', action='store_true', help='dump the sine LUT values')
    # parser.add_argument('--square-lut', dest='square_lut', action='store_true', help='dump the square LUT values')
    # parser.add_argument('--triangle-lut', dest='triangle_lut', action='store_true', help='dump the triangle LUT values')
    # parser.add_argument('--sawtooth-lut', dest='sawtooth_lut', action='store_true', help='dump the sawtooth LUT values')
    parser.add_argument('--sine-plot', dest='sine_plot', action='store_true', help='plot the sine LUT values')
    # parser.add_argument('--square-plot', dest='square_plot', action='store_true', help='plot the square LUT values')
    # parser.add_argument('--triangle-plot', dest='triangle_plot', action='store_true', help='plot the triangle LUT values')
    # parser.add_argument('--sawtooth-plot', dest='sawtooth_plot', action='store_true', help='plot the sawtooth LUT values')
    args = parser.parse_args()

    fsamp = 30e3
    nco = NCO(fsamp, interpolate = True)
    fsig = 880
    num_periods = 5
    num_samples = int(np.ceil(fsamp / fsig)) * num_periods
    nco_samples = [nco.next_sample_f(fsig) for n in range(num_samples)] # only take the sine sample

    if args.analysis:
        nco_sine_samples = [x[0] for x in nco_samples]
        nco_samples_float = [float(x) for x in nco_sine_samples]
        phase_increment = nco.phase_increment(fsig)
        effective_freq = nco.effective_frequency(phase_increment)
        ideal_samples = [np.sin(2*np.pi*effective_freq*n/fsamp) for n in range(num_samples)]

        ## Plot NCO vs ideal samples
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(2, 1)
        ax[0].plot(nco_samples_float, '*')
        ax[0].plot(ideal_samples, '*')
        ax[0].legend(['NCO Samples', 'Ideal Samples'])
        ax[0].set_xlabel('Sample Number (n)')
        ax[0].set_ylabel('Amplitude')
        ax[1].plot(np.abs(np.array(nco_samples_float) - np.array(ideal_samples)))
        ax[1].legend(['NCO Error'])
        ax[1].set_xlabel('Sample Number (n)')
        ax[1].set_ylabel('Absolute Error')
        plt.show()

    # if args.golden:
    #     for val in nco_samples:
    #         print('{}'.format(val[0].toBinaryString().replace('.', ''))) # only consider the sine samples
    # print(">>>", nco.sine_lut_fixed[1])
    # print(">>>", nco.sine_lut_int[1])
    # print(">>>", '{0:10b}'.format(nco.sine_lut_int[1]))
    if args.sine_lut:
        # sine_lut = [x.toBinaryString() for x in nco.sine_lut_fixed]
        # for val in sine_lut:
        #     print('{}'.format(val.replace('.', '')))
        for val in nco.sine_lut_int:
            if val >= nco.DAC:
                val = nco.DAC - 1
            print('{0:010b}'.format(val))
    if args.sine_plot:
        import matplotlib.pyplot as plt
        #sine_lut = [float(x) for x in nco.sine_lut_fixed]
        sine_lut = [float(x) for x in nco.sine_lut_int]
        plt.plot(sine_lut, '.')
        plt.show()

    # if args.square_lut:
    #     square_lut = [x.toBinaryString() for x in nco.square_lut_fixed]
    #     for val in square_lut:
    #         print('{}'.format(val.replace('.', '')))
    # if args.square_plot:
    #     import matplotlib.pyplot as plt
    #     square_lut = [float(x) for x in nco.square_lut_fixed]
    #     plt.plot(square_lut, '.')
    #     plt.show()

    # if args.triangle_lut:
    #     triangle_lut = [x.toBinaryString() for x in nco.triangle_lut_fixed]
    #     for val in triangle_lut:
    #         print('{}'.format(val.replace('.', '')))
    # if args.triangle_plot:
    #     import matplotlib.pyplot as plt
    #     triangle_lut = [float(x) for x in nco.triangle_lut_fixed]
    #     plt.plot(triangle_lut, '.')
    #     plt.show()

    # if args.sawtooth_lut:
    #     saw_lut = [x.toBinaryString() for x in nco.sawtooth_lut_fixed]
    #     for val in saw_lut:
    #         print('{}'.format(val.replace('.', '')))
    # if args.sawtooth_plot:
    #     import matplotlib.pyplot as plt
    #     sawtooth_lut = [float(x) for x in nco.sawtooth_lut_fixed]
    #     plt.plot(sawtooth_lut, '.')
    #     plt.show()
