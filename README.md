# _Cuộc Chở Âm_: <sup>`sound transport`</sup><sub><sub><sub> for _fun_ </sub></sub></sub>and <sup><sup><sup> ~~_profit_~~<sub><sub><sub> learning.</sub></sub></sub></sup></sup></sup>

## What is it?

This project aims at building, from scratch:
* an RTL model of a PCIe sound card
* a linux kernel module that supports the card as an ALSA-compliant device

## Why is it?

1. I was a loser and didn't take 6.111 at MIT and this is my attempt at rectifying this fatal personality defect
2. I would like to learn more about how the linux audio stack works, and am hoping to someday get a job working with audio in linux 🤞
3. I recently found myself funemployed and wanted to give myself a technical goal to strive after while I work on myself

## How is it?

Prototype Stage:
- [ ] Implement hw <-> sw transport via UART
- [ ] Implement audio output via PWM signal on mono 3.5mm audio jack
- [ ] Implement audio input via PDM microphone
- [ ] Write userspace program to successfully send & receive data over serial port

Intermediate Stage:
- [ ] Replace userspace program with ALSA kernel driver
- [ ] Replace PWM output with S/PDIF transmitter
- [ ] Replace PDM microphone input with S/PDIF receiver
- [ ] (if needed) migrate hw <-> sw transport to ethernet for better throughput 

Advanced Stage:
- [ ] Obtain PCIe FPGA dev card
- [ ] Migrate hw <-> sw transport to PCIe
- [ ] Replace S/PDIF transmitter with MADI transmitter
- [ ] Replace S/PDIF receiver with MADI receiver
