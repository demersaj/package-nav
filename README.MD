# Navigator Package Creation Script

This script automates the process of downloading, packaging, signing, and notarizing the Navigator application for macOS distribution. It *should* be generic enough to adapt to other programs as well.

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
10. **Uploads** the complete .pkg file to an S3 bucket you configured (requires setup).
11. **Deletes** old Navigator .pkg and .dmg files

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

The script will create a versioned package file in the directory where it was run, for example:
- `Navigator-2.345.6.pkg`

## Installation

To install the created package:
```bash
sudo installer -pkg "Navigator-x.xxx.x.pkg" -target /Applications
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
- Logs stderr, stdout, and watcher behavior for review

## S3 Upload (Optional)

The script can automatically upload completed packages to an S3 bucket for distribution. This is completely optional and only runs if configured.

### Prerequisites

1. **Install AWS CLI**:
   ```bash
   brew install awscli
   ```

2. **Configure AWS Credentials**:
   ```bash
   aws configure
   ```
   
   Or set environment variables:
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   ```

### Configuration

Add the following variables to your `.env` file:

```bash
# S3 Upload Configuration (optional)
S3_BUCKET="your-bucket-name"           # Required if you want S3 upload
S3_PREFIX="navigator/"                 # Optional: path prefix in bucket (default: "navigator/")
S3_REGION="us-east-1"                  # Optional: AWS region (default: "us-east-1")
S3_ACL="private"                       # Optional: "private" or "public-read" (default: "private")
```

### How It Works

- After successful package creation, the script checks if `S3_BUCKET` is set
- If configured, it uploads the PKG file to: `s3://your-bucket/navigator/Navigator-2.423.0.pkg`
- Includes metadata: version and SHA256 hash
- Sets appropriate content type for macOS packages
- Shows the S3 URL after successful upload

### Example Configuration

```bash
# Private uploads (default)
S3_BUCKET="my-navigator-releases"
S3_PREFIX="packages/"
S3_REGION="us-west-2"
# S3_ACL not set = defaults to "private"

# Public downloads
S3_BUCKET="my-navigator-releases"
S3_PREFIX="packages/"
S3_REGION="us-west-2"
S3_ACL="public-read"  # Allows public access
```

### Notes

- If `S3_BUCKET` is not set, S3 upload is skipped
- If AWS CLI is not installed, the script will show an error and continue without uploading
- Upload failures don't stop the script - it will continue even if S3 upload fails
- For private uploads, only users with AWS credentials can access the files
- For public uploads (`S3_ACL="public-read"`), the script will display a public URL

## Requirements

- macOS with Xcode command line tools
- Valid Apple Developer account
- Developer ID certificates
- Notarytool profile configured
- AWS CLI (optional, only if using S3 upload)