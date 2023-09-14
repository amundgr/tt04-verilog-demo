import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


segments = [ 63, 6, 91, 79, 102, 109, 124, 7, 127, 103 ]
def get_parameters():
    parameters = {}
    with open("parameters.v", "r") as infile:
        for line in infile.readlines():
            if "parameter" not in line:
                continue
            line = line.replace("parameter", "").replace(";", "").split("=")
            parameters[line[0].strip()] = int(line[1].strip())

    return parameters

async def push_value(value_list, dut) -> None:
    # Take a 16 element list as input and shift each value parallel into dut.ui_in.value
    
    ws = True
    for i in range(64):
        val = 0
        if i == 0 or i==32:
            ws = not ws
            continue
        if not ws:
            for i in range(8):
                val |= (value_list[i*2] & 0x80 >> 7) << i
                value_list[i*2] << 1 
        else:
            for i in range(8):
                val |= (value_list[i*2+1] & 0x80 >> 7) << i
                value_list[i*2+1] << 1

        await ClockCycles(dut.clk, 1)

@cocotb.test()
async def test_beamformer(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 1, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    # Clock in zeros
    res = 0
    any_data = False
    
    vals = [0] * 16
    vals[0] = 0x12
    vals[1] = 0x34
    vals[2] = 0x56
    vals[3] = 0x78

    await push_value(vals, dut)

    vals[0] = 0x9A
    vals[1] = 0xBC
    vals[2] = 0xDE
    vals[3] = 0xF0

    await push_value(vals, dut)

    dut._log.info(f"Result: {res}")
    assert any_data





"""
@cocotb.test()
async def test_7seg(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0
    # set the compare value
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # the compare value is shifted 10 bits inside the design to allow slower counting
    max_count = dut.ui_in.value << 10
    dut._log.info(f"check all segments with MAX_COUNT set to {max_count}")
    # check all segments and roll over
    for i in range(15):
        dut._log.info("check segment {}".format(i))
        await ClockCycles(dut.clk, max_count)
        assert int(dut.segments.value) == segments[i % 10]

        # all bidirectionals are set to output
        assert dut.uio_oe == 0xFF

    # reset
    dut.rst_n.value = 0
    # set a different compare value
    dut.ui_in.value = 3
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    max_count = dut.ui_in.value << 10
    dut._log.info(f"check all segments with MAX_COUNT set to {max_count}")
    # check all segments and roll over
    for i in range(15):
        dut._log.info("check segment {}".format(i))
        await ClockCycles(dut.clk, max_count)
        assert int(dut.segments.value) == segments[i % 10]
"""


if __name__ == "__main__":
    print(get_parameters())