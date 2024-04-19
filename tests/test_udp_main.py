import cocotb
from cocotb.triggers import RisingEdge, Timer

from generate_frame import generate_ethernet_frame
from tester import runner

NUM_TESTS = 100
@cocotb.test()
async def ethernet_frame_parser_test(dut):
    """ Test the Ethernet Frame Parsing in UDP Module """
    for _ in range(NUM_TESTS):
        frame, eth_type, ip_protocol, payload = generate_ethernet_frame()
        
        # convert frame
        frame_binary = ''.join(format(byte, '08b') for byte in frame)

        # apply frame to test
        dut.eth_frame.value = int(frame_binary, 2)
        dut.frame_start.value = 1  # signal frame start
        await RisingEdge(dut.main_clk)
        dut.frame_start.value = 0 
        
        # wait for frame process to end
        await Timer(10, units='ns')  # Wait for the processing to complete
        
        # check flags
        assert dut.valid_ip.value == (eth_type == 0x0800), "IP validation failed"
        assert dut.valid_udp.value == (ip_protocol == 0x11), "UDP validation failed"
        
        # check parsed payload
        if dut.valid_udp.value:
            dut_udp_payload = int(dut.udp_payload.value.binstr, 2)
            payload_binary = int(''.join(format(byte, '08b') for byte in payload), 2)
            assert dut_udp_payload == payload_binary, "UDP payload mismatch"


def test_udp_main():
    runner("udp_main")
