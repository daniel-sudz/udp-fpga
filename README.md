# UDP FPGA

Implementing raw ethernet frame parsing in hardware to communicate using a point-to-point ethernet link connection using the UDP data protocol.

https://github.com/daniel-sudz/udp-fpga/assets/52898838/3c39b399-b354-42f4-a91c-baba29a6c7b9

# Ethernet Packets

| **MAC Destination** | **MAC Source** | **Ethertype** | **Payload** | **Frame Check Sequences** |
| ------------------------- | -------------------- | ------------------- | ----------------- | ------------------------------- |
| 6 bytes                   | 6 bytes              | 2 bytes             | variable          | 4 bytes                         |

A layer two ethernet frame is laid out as follows above. The payload of the ethernet frame contains the next level of the networking stack. In our case, we set the "ethertype" type field to `0x0800` which specified that the payload will contain an IPV4 packet. 

| Octet, Bits | 0               | 1   | 2   | 3   | 4   | 5   | 6   | 7   | 8        | 9   | 10  | 11  | 12  | 13  | 14  | 15  | 16       | 17  | 18  | 19   | 20  | 21  | 22  | 23  | 24  | 25  | 26  | 27  | 28  | 29  | 30  | 31  |
| ----------- | --------------- | --- | --- | --- | --- | --- | --- | --- | -------- | --- | --- | --- | --- | --- | --- | --- | -------- | --- | --- | ---- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0           | **VERSION**         | ...  | ...  | ...  | IHL | ...  | ...  | ...  | **DSCP**     | ...  | ...  | ...  | ...  | ...  | **ECN** | ...  | **LEN**      | ...  | ...  | ...   | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  |
| 4           | **ID**              | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...       | ...  | ...  | ...  | ...  | ...  | ...  | ...  | **FLAGS**    | ...  | ...  | **FRAG** | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  |
| 8           | **TTL**             | ...  | ...  | ...  | ...  | ...  | ...  | ...  | **PROTOCOL** | ...  | ...  | ...  | ...  | ...  | ...  | ...  | **CHECKSUM** | ...  | ...  | ...   | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  |
| 12          | **SRC** **ADDR**        | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...       | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...       | ...  | ...  | ...   | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  |
| 16          | **DEST** **ADDR**       | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...       | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...       | ...  | ...  | ...   | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  | ...  |
| 20          | **OPTIONS (IHL>5) **| ... | ... | ... | ... | ... | ... | ... | ...      | ... | ... | ... | ... | ... | ... | ... | ...      | ... | ... | ...  | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |
| ...         | ...             | ... | ... | ... | ... | ... | ... | ... | ...      | ... | ... | ... | ... | ... | ... | ... | ...      | ... | ... | ...  | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |
| 56          | ...             | ... | ... | ... | ... | ... | ... | ... | ...      | ... | ... | ... | ... | ... | ... | ... | ...      | ... | ... | ...  | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

# Networking Link Layer Linux Resources

- [ ] Calculate IP Checksum: https://gist.github.com/david-hoze/0c7021434796997a4ca42d7731a7073a
- [ ] Send Raw Ethernet Packet in Linux: https://gist.github.com/austinmarton/1922600
- [ ] Recieve Raw Ethernet Packet in Linux: https://gist.github.com/austinmarton/2862515
