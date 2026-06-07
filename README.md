# Linux GSM SMS Scripts

This repository provides two Bash scripts to interact with GSM modems on Linux:

- `gammu.sh`: uses Gammu to read, delete, and send SMS.
- `minicom.sh`: uses direct serial AT commands to send SMS.

Both scripts are currently tailored to Spanish phone numbers (`+34XXXXXXXXX`).

## Requirements

### Common

- Linux system with access to GSM modem serial interfaces.
- User permissions to access serial devices (typically membership in the `dialout` group).

### gammu.sh

- `gammu` installed and properly configured (for example with `~/.gammurc`).

### minicom.sh

- `lsof`, `timeout`, and `sudo` available in `PATH`.
- GSM modem exposed as `/dev/ttyUSB*`.

## Script Usage

### gammu.sh

Read and delete received SMS:

```bash
./gammu.sh
```

Send an SMS:

```bash
./gammu.sh +34XXXXXXXXX "Message text"
```

Behavior:

- Validates phone number format.
- Validates empty messages and unsupported characters.
- Stores operation details in `gammu.log`.

### minicom.sh

Send an SMS:

```bash
./minicom.sh +34XXXXXXXXX "Message text"
```

Behavior:

- Scans `/dev/ttyUSB*` and validates modem response to `AT`.
- Detects and terminates blocking processes on candidate ports.
- Validates phone number, length, and characters.
- Stores operation details in `minicom.log`.

## Error Handling and Logging

Both scripts:

- Return non-zero exit codes on validation or runtime failures.
- Print explicit error messages that include failing command context when possible.
- Append timestamped operation details to log files for troubleshooting.

Log files:

- `gammu.log`: read/delete and send operations via Gammu.
- `minicom.log`: send operations through AT command flow.

## Notes

- Review logs regularly to diagnose modem, port, or validation issues.
- If SMS delivery fails, verify modem registration, signal, SIM state, and serial port permissions.

## References

- [Gammu documentation](https://wammu.eu/docs/manual/)
- [ITU-T V.250 AT command standard](https://www.itu.int/rec/T-REC-V.250)
