UART FPGA
===================

This is one of my first FPGA projects written in VHDL. Simple UART entity that uses two FIFO queues to as incoming and outcoming buffers - these FIFOs are not a part of this project, you need to it yourself. 

This project was tested with Altera IP Core FIFO.

----------


How to use it
-------------
To change the baudrate just set generic `BAUDRATE` of `uart` entity appropriately.

If you want to use different FIFO entity (or change Altera FIFOs properties), you can edit `fifo_buffer` inside `uart_fifo` entity. 

Example of use is inside `uart_test.vhd` file.
