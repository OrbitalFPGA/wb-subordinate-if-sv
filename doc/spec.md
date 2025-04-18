# Wishbone B4 Subordinate Interface Specification 

**IP Name:** wb_subordinate_interface

**Version:** 1.0

**Author:** Michael B.

**Date:** April 18, 2025

---

## 1. Overview
This module implements a reusable Wishbone B4-compliant slave interface. It connects custom IP cores to a system bus using the pipeline Wishbone B4 protocol, as defined in the [Wishbone B4 Specification](https://cdn.opencores.org/downloads/wbspec_b4.pdf).

## 2. Functional Requirements
| ID          | Requirement Description                               |
| ----------- | ----------------------------------------------------- |
| REQ-FUNC-01 | Shall comply with the Wishbone B4 Pipeline standard   |
| REQ-FUNC-02 | Shall support 32-bit data at 8-bit granularity        |
| REQ-FUNC-03 | Shall support 32-bit addresses                        |
| REQ-FUNC-04 | Shall support single read and write operations        |
| REQ-FUNC-05 | Shall support block read and write operations         |
| REQ-FUNC-06 | Shall decode local addresses for a single IP instance |

## 3. Non-Functional Requirements
| ID           | Requirement Description                                        |
| ------------ | -------------------------------------------------------------- |
| REQ-NFUNC-01 | Shall operate at up to 200 MHz clock frequency                 |
| REQ-NFUNC-02 | Shall have deterministic latency of ≤2 cycles when not stalled |
| REQ-NFUNC-03 | Shall be synthesizable on Xilinx XC7A100T                      |
| REQ-NFUNC-04 | Provide standardized header registers                          |


## 4. Interface Definition

### 4.1 Parameters

| Name                      | Default Value | Description                                                      |
| ------------------------- | ------------- | ---------------------------------------------------------------- |
| WB_ADDRESS_WIDTH          | 32            | Number of bits in address                                        |
| WB_BASE_ADDRESS           | 0x4000_0000   | Base address of interface/IP                                     | 
| WB_REGISTER_ADDRESS_WIDTH | 16            | Number of least-significant address bits used for register space |
| WB_DATA_WIDTH             | 32            | Number of bits in data bus                                       |
| WB_DATA_GRANULARITY       | 8             | Smallest unit of transfer interface support                      |
| IP_VERSION                | WB_DATA_WIDTH | Version of IP                                                    |
| IP_DEVICE_ID              | WB_DATA_WIDTH | ID code for device                                               |


### 4.2 Wishbone Signals
| Signal  | Direction | Width                                | Description         |
| ------- | --------- | ------------------------------------ | ------------------- |
| i_wb_clk   | Input     | 1                                    | System Clock        |
| i_wb_rst   | Input     | 1                                    | Active-high reset   |
| i_wb_cyc   | Input     | 1                                    | Bus cycle indicator | 
| i_wb_stb   | Input     | 1                                    | Data Strobe signal  |
| i_wb_we    | Input     | 1                                    | Write Enable        |
| i_wb_addr  | Input     | WB_ADDRESS_WIDTH                     | Address Bus         |
| i_wb_dat   | Input     | WB_DATA_WIDTH                        | Data input Bus      |
| i_wb_sel   | Input     | WB_DATA_WIDTH  / WB_DATA_GRANULARITY | Data select         | 
| o_wb_dat   | Output    | WB_DATA_WIDTH                        | Data output Bus     |
| o_wb_stall | Output    | 1                                    | Stall signal        | 

### 4.3 IP Signals
| Signal     | Direction | Width                                | Description                |
| ---------- | --------- | ------------------------------------ | -------------------------- |
| o_ip_control  | Output    | WB_DATA_WIDTH                        | Control Register value     |
| i_ip_status   | Input     | WB_DATA_WIDTH                        | Status Register value      |
| o_ip_irq_mask | Input     | WB_DATA_WIDTH                        | Interrupt Mask register    |
| i_ip_irq      | Input     | WB_DATA_WIDTH                        | Interrupt Register value   |
| i_ip_rdata    | Input     | WB_DATA_WIDTH                        | Data from IP register      |
| i_ip_read_en  | Input     | 1                                    | Enable reading IP register |
| o_ip_wdata    | Output    | WB_DATA_WIDTH                        | Data to IP register        |
| o_ip_write_en | Output    | 1                                    | Enable writing IP register |

## 5. Register Map
| Offset | Name         | Description                                 | R/W  |
| ------ | ------------ | ------------------------------------------- | ---- |
| 0x00   | VERSION      | Version number of IP                        | R    | 
| 0x04   | DEVICE_ID    | Unique 32-bit identifier for IP             | R    |
| 0x08   | CONTROL      | Control bits for module operation           | R/W  |  
| 0x0C   | IRQ_MASK     | Enable bits for interrupt sources           | R/W  |  
| 0x10   | IRQ          | Latched interrupt status                    | R/WC |  
| 0x14   | STATUS       | Status bits (ready, busy, error, etc.)      | R    |  
| 0x18   | RESERVED     | RESERVED                                    | R    |  
| 0x1C   | RESERVED     | RESERVED                                    | R    |  
| 0x20   | IP_SPECIFIC  | IP-specific register, see IP documentation  | X    |  

**NOTE:** The interface defines register locations but leaves bitfield semantics to the IP

R/WC: Read/Write 1 to bit to clear

## 6. Timing Diagrams

The following diagram illustrates a single pipeline-mode read transaction as implemented by this interface. It is derived from the official [Wishbone B4 Specification](https://cdn.opencores.org/downloads/wbspec_b4.pdf).

![Wishbone Pipeline Single Read](wb-subordinate-if-sv/doc/img/wb_pipeline_single_read.svg)

## 7. Verification Strategy

* Formal: Assertions covering bus protocol compliance (e.g., SymbiYosys + [Formal Wishbone Slave Checker](https://github.com/ZipCPU/wb2axip/tree/master/formal))

## 8. Future Enhancements

* Parameterize Classic and Pipeline

## 9. Change History

| Version | Date           | Changes           |
|---------|----------------|-------------------|
| 1.0     | April 18, 2025 | Initial draft     |

## 10. References

- [Wishbone B4 Specification](https://cdn.opencores.org/downloads/wbspec_b4.pdf), OpenCores, Revision B4.
- [Formal Wishbone Slave Checker](https://github.com/ZipCPU/wb2axip/tree/master/formal), ZipCPU GitHub repository.