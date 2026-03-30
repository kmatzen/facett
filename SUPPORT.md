# Facett Support

Facett is a free, open-source app for controlling multiple action cameras simultaneously via Bluetooth Low Energy.

## Frequently Asked Questions

### Which cameras are supported?

Facett has been tested with GoPro HERO10 Black cameras running GoPro Labs firmware. Other BLE-enabled camera models may work but are not officially supported.

### Why won't my camera connect?

- Make sure Bluetooth is enabled on your iPhone or iPad.
- Ensure the camera is powered on and not already connected to another device.
- GoPro Labs firmware is required for full BLE connectivity. Visit [gopro.com/labs](https://community.gopro.com/s/article/GoPro-Labs) to install it.
- Try moving closer to the camera. BLE range is typically 5-10 meters.

### How do I start recording on all cameras at once?

Add your cameras to a group, then use the group recording controls. You can also use voice commands — say "start" or "stop" for hands-free operation.

### Does Facett work on iPad?

Yes. Facett requires iOS/iPadOS 16.6 or later on any device with Bluetooth 4.0+.

### Is Facett free?

Yes. Facett is completely free with no in-app purchases. The full source code is available under the MIT license at [github.com/kmatzen/facett](https://github.com/kmatzen/facett).

## Troubleshooting

### Camera disconnects during recording

- Check that the camera battery is sufficiently charged.
- Reduce the distance between your device and the camera.
- Restart the camera and reconnect from Facett.

### Settings fail to sync across cameras

- Verify all cameras in the group are running the same firmware version.
- Some settings combinations may not be supported by all camera models.
- Try applying settings to cameras individually to identify which camera is not responding.

### App does not detect any cameras

- Confirm Bluetooth is enabled in Settings > Bluetooth.
- Ensure Facett has Bluetooth permission enabled in Settings > Facett.
- Restart the app and try again.

## Contact & Support

If your question is not answered above, you can:

- **Report a bug, request a feature, or ask a question** — [Open an issue on GitHub](https://github.com/kmatzen/facett/issues)

We aim to respond to all inquiries.

---

This product and/or service is not affiliated with, endorsed by or in any way associated with GoPro Inc. or its products and services. GoPro, HERO and their respective logos are trademarks or registered trademarks of GoPro, Inc.
