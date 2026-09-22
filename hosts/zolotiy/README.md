# Zolotiy

This is a Dell Pro 14 Premium PA14250 laptop.

High level specifications:

| Component   | Details                                                           |
|-------------|-------------------------------------------------------------------|
| CPU         | Intel® Core™ Ultra 7 268V                                         |
| RAM         | LPDDR5X 30Gi (Physical 32GB)                                      |
| GPU         | Arc Graphics 130V/140V GPU (rev 04)                               |
| Storage     | PC\_SN5000S SanDisk 2048GB (M.2 2230)                             |
| Motherboard | Dell Inc. 0NGT53                                                  |
| Display     | AUO 14" WUXGA (1920x1200) 16:10 IPS                               |
| Webcam      | IPU [8086:645d] (rev 04)                                          |
| Biometric   | Shenzhen Goodix Technology Co.,Ltd. Goodix Fingerprint USB Device |
| Touchpad    | VEN_0488:00 0488:1083 Touchpad                                    |
| Wireless    | Intel Corporation BE200 Series Wi-Fi 7 (rev 10)                   |
| Bluetooth   | Intel Corp. BE200 Bluetooth Wireless Interface                    |
| Audio       | HD Audio (rev 10)                                                 |
| Battery HW  | DELL 5HK3V57I (Manufacturer: SMP)                                 |

I had wanted a thin, light and affordable laptop (as I don't use this
machine for that much dev work nowadays unfortunately).  Alas,
Framework wasn't shipping to Singapore when I ordered this in late
2025 (but now they do).

What isn't working:

* Webcam: despite enabling IPU7 I get a lot of fake V4L2 entries and
  testing with `nix-shell -p libcamera libcamera-qcam.out --run
  "qcam"` fails (`wpctl --status` gives more details).  I normally use
  an external webcam anyway so not that concerned, will wait for
  more knowledgeable people to fix this overall in NixOS more.

* Fingerprint sensor: very rarely use it as a laptop as it's normally
  attached to a KVM, so it's not a high concern for me.

[This PR](https://github.com/NixOS/nixos-hardware/pull/1534) might
help if any other hardware inconsistencies arise.
