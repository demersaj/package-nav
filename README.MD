# Navigator Package Creation Script

This script automates the process of downloading, packaging, signing, and notarizing the Navigator application for macOS distribution.

## Prerequisites

You need two Apple Certificates. They can be obtained from [developer.apple.com](https://developer.apple.com).

1. **Developer ID Installer certificate**
2. **Developer ID Application certificate**

You also need a notary tool profile set up. You can set one up like this:

```bash
xcrun notarytool store-credentials "PROFILE_NAME" \
    --apple-id "YOUR_APPLE_ID" \
    --team-id "YOUR_TEAM_ID" \
    --password "APP_SPECIFIC_PASSWORD"
```

The app-specific password can be created at [account.apple.com](https://account.apple.com).

## How it Works

This script takes the newest production version of Navigator into a temp folder. Then it:

1. **Downloads** the latest Navigator DMG from the official source
2. **Extracts** the application from the DMG
3. **Verifies** the application and code signing
4. **Creates** a signed package using `productbuild`
5. **Verifies** the package signature
6. **Submits** the package for notarization with Apple
7. **Staples** the notarization ticket to the package
8. **Validates** the notarization
9. **Moves** the final package to the original directory with a timestamp

The status is continually outputted at each step along with any errors or failure steps.

## Usage

1. Make the script executable:
   ```bash
   chmod +x pkg_nav.sh
   ```

2. Run the script:
   ```bash
   ./pkg_nav.sh
   ```

## Output

The script will create a timestamped package file in the directory where it was run, for example:
- `Navigator-20251001-115446.pkg`

## Installation

To install the created package:
```bash
sudo installer -pkg "Navigator-YYYYMMDD-HHMMSS.pkg" -target /Applications
```

## Troubleshooting

### Common Issues

1. **Certificate not found**: Ensure you have the correct Developer ID certificates installed in your keychain
2. **Notarization profile issues**: Verify your notarytool profile is correctly configured
3. **Permission denied**: Make sure the script is executable with `chmod +x pkg_nav.sh`

### Validation Failures

If notarization validation fails, the script now provides detailed debugging information including:
- Package signature verification
- Alternative validation methods
- Exit codes and error messages

## Requirements

- macOS with Xcode command line tools
- Valid Apple Developer account
- Developer ID certificates
- Notarytool profile configured