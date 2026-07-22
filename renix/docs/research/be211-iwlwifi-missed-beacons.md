# Intel BE211 / iwlwifi missed-beacon research

Researched 2026-07-11 for `nixnode`, which is running Linux 7.1.2 with an Intel Wi-Fi 7 BE211 (`8086:e340`) and firmware `102.07fca168.0 sc-a0-wh-b0-c102.ucode` using the `iwlmld` operation mode.

## Finding

No indexed upstream report was found that matches all three of BE211, Linux 7.1.2, and this firmware build. There are, however, closely matching reports involving Intel `iwlwifi`, the exact `missed beacons exceeds threshold, but receiving data. Stay connected, Expect bugs.` diagnostic, and subsequent connectivity trouble.

## Related reports

- [Pop!_OS issue #3488](https://github.com/pop-os/pop/issues/3488), opened 2025-03-27: an Intel AX211 on 5 GHz experiences connection loss and firmware errors at moderate signal levels. Its logs include the exact missed-beacon warning and `Connection to AP ... lost`. This is older AX211 hardware, Linux 6.12.10, firmware 89, and `iwlmvm`, so it is symptomatically close but not the same BE211/`iwlmld` path.
- [kachick/dotfiles issue #1328](https://github.com/kachick/dotfiles/issues/1328), opened 2025-11-01: reports flaky connectivity and the exact warning on NixOS. The reporter associated a worsening with a linux-firmware update, retained older firmware, and later reported stability on Linux 6.12.56. Hardware was Intel Wireless-AC 9260, so this is useful evidence that this diagnostic can correspond to firmware/driver behavior, but it is not BE211-specific.
- [FuriLabs issue #216](https://github.com/FuriLabs/issue-tracker/issues/216): includes the exact warning during hotspot failures. The confirmed cause there involved concurrent station scans disrupting hotspot operation, so it is not a match for this client-only scenario.
- The warning is emitted by the upstream Intel wireless driver. The source location cited by issue #1328 is [`drivers/net/wireless/intel/iwlwifi/mld/link.c`](https://github.com/torvalds/linux/blob/ba36dd5ee6fd4643ebbf6ee6eefcecf0b07e35c7/drivers/net/wireless/intel/iwlwifi/mld/link.c#L558-L566). The MLD path is relevant because this BE211 reports `op_mode iwlmld`.

## Assessment

The public evidence supports an Intel client driver/firmware or AP-interoperability hypothesis, but does not establish a known BE211 Linux 7.1.2 regression. The exact BE211 generation and `iwlmld` code path are new enough that reports may not yet be indexed or may exist only on Intel/internal kernel mailing-list channels.

The strongest next test is differential: boot an earlier NixOS generation and compare disconnect and missed-beacon counts while using the same AP and location. Also test 2.4 GHz or temporarily disable Wi-Fi 6/7 features for this SSID. These tests distinguish a kernel/firmware regression from 5 GHz/802.11ax interoperability.
