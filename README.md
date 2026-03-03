# Recursive WSDL/XSD Downloader

A bash script to recursively download WSDL files and all their dependent XSD schemas.

## Features

- Downloads WSDL files and recursively resolves all XSD dependencies
- Handles relative and absolute URLs
- URL encoding support for special characters
- Configurable output directory
- Color-coded output
- Respects existing files (skips downloads)

## Requirements

- bash (version 4+)
- wget

## Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/jonatanpolak/recursiveDownloader.git
cd recursiveDownloader
chmod +x recursiveDownloader.sh
```

## Usage

```bash
./recursiveDownloader.sh <WSDL_URL> [OPTIONS]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h, --help` | Show help message | - |
| `-o, --output` | Output directory | `output` |
| `-v, --verbose` | Enable verbose output | off |

### Examples

Download a WSDL file to the default output directory:

```bash
./recursiveDownloader.sh https://example.com/service.wsdl
```

Download to a custom directory:

```bash
./recursiveDownloader.sh https://example.com/service.wsdl -o myschemas
```

## Output

The script creates an output directory (default: `output/`) and downloads:
1. The main WSDL file
2. All XSD schemas referenced via `schemaLocation`
3. Any nested dependencies (recursively, up to 10 levels deep)

Example output:

```
[INFO] WSDL Fetcher - Starting download
[INFO] URL: https://example.com/service.wsdl
[INFO] Output directory: output

[INFO] Downloading: service.wsdl
[INFO] Downloaded: service.wsdl
[INFO] Downloading: types.xsd
[INFO] Downloaded: types.xsd
[INFO] No more dependencies for: types.xsd

[INFO] Download complete!
[INFO] Files saved to: output/
```

## Configuration

The script uses `wget` with the following default parameters:
- Timeout: 60 seconds
- Non-verbose output
- No-clobber (skip existing files)
- TLSv1.2 for secure connections
- SSL certificate validation disabled

To modify these settings, edit the `wget_params` variable in the script:

```bash
wget_params="-T 60 -nv -nc --secure-protocol=TLSv1_2 --no-check-certificate --timeout=60"
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Original author: Anthony/Rabiaza

Fork author: Jonatan Polak
