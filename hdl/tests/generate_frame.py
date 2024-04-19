import random

def generate_mac():
    """ make a random mac address"""
    return bytes([random.randint(0x00, 0xFF) for _ in range(6)])

def generate_random_ip():
    """ make a random ip"""
    return tuple(random.randint(0, 255) for _ in range(4))

def generate_ethernet_frame():
    """ using real ethernet frames is better, WIP """
    # make the ethernet header
    destination_mac = generate_mac()
    source_mac = generate_mac()
    eth_header = bytes(destination_mac + source_mac)
    
    # choose an ethertype
    ethertypes = [0x0800, 0x0806, 0x86DD, 0x0842]  # sample ethertypes
    eth_type = random.choice(ethertypes)
    eth_type_bytes = eth_type.to_bytes(2, byteorder='big')

    # make the ip header
    ip_header = bytearray(20) # assuming same size for now
    ip_header[0] = 0x40 | 5
    ip_header[1] = 0x00
    ip_header[9] = random.choice([0x11, 0x06, 0x01, 0x85, 0x01, 0x02])  # choose a random ip protocol (important)
    ip_header[2:4] = (20 + 8).to_bytes(2, byteorder='big')  # make byte length
    ip_header[10:12] = (0x0000).to_bytes(2, byteorder='big')  # make up a checksum
    ip_header[12:16] = bytes(generate_random_ip())  # random source ip
    ip_header[16:20] = bytes(generate_random_ip())  # random dest ip

    # use the same udp header because lazy
    udp_header = bytes([0x00, 0x35, 0x00, 0x35, 0x00, 0x08, 0x00, 0x00])

    # add all headers
    frame = eth_header + eth_type_bytes + ip_header + udp_header

    # add a random payload
    padding_length = 1500 - len(frame)
    padding = bytes([random.randint(0x00, 0xFF) for _ in range(padding_length)])
    frame += padding

    # return actual frame, eth type, and protocol
    return frame, eth_type, ip_header[9], padding

