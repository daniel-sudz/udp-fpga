# UDP FPGA

Implementing raw ethernet frame parsing in hardware to communicate using a point-to-point ethernet link connection using the UDP data protocol.

https://github.com/daniel-sudz/udp-fpga/assets/52898838/3c39b399-b354-42f4-a91c-baba29a6c7b9

# Ethernet Packets

| **MAC Destination** | **MAC Source** | **Ethertype** | **Payload** | **Frame Check Sequences** |
| ------------------------- | -------------------- | ------------------- | ----------------- | ------------------------------- |
| 6 bytes                   | 6 bytes              | 2 bytes             | variable          | 4 bytes                         |

A layer two ethernet frame is laid out as follows above. The payload of the ethernet frame contains the next level of the networking stack. In our case, we set the "ethertype" type field to `0x0800` which specified that the payload will contain an IPV4 packet. 

| Octet |         |  |  |  |  |  |  |  |  |  |
| ----- | ------- | - | - | - | - | - | - | - | - | - |
| 0     | Version |  |  |  |  |  |  |  |  |  |
| 4     |         |  |  |  |  |  |  |  |  |  |
| 8     |         |  |  |  |  |  |  |  |  |  |
| 12    |         |  |  |  |  |  |  |  |  |  |
| 16    |         |  |  |  |  |  |  |  |  |  |
| 20    |         |  |  |  |  |  |  |  |  |  |
| ...   |         |  |  |  |  |  |  |  |  |  |
| 56    |         |  |  |  |  |  |  |  |  |  |

# Networking Link Layer Linux Resources

- [ ] Calculate IP Checksum: https://gist.github.com/david-hoze/0c7021434796997a4ca42d7731a7073a
- [ ] Send Raw Ethernet Packet in Linux: https://gist.github.com/austinmarton/1922600
- [ ] Recieve Raw Ethernet Packet in Linux: https://gist.github.com/austinmarton/2862515
