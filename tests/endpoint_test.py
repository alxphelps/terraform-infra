#!/usr/bin/env python3
import re
import socket
import ssl
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

URLS_FILE = Path(__file__).with_name("urls")
TIMEOUT = 15
HOSTNAME_PATTERN = re.compile(r"^[A-Za-z0-9.-]+$")


def request_status(scheme, hostname, context=None):
    request = Request(f"{scheme}://{hostname}", method="GET")
    try:
        with urlopen(request, context=context, timeout=TIMEOUT) as response:
            return str(response.status)
    except HTTPError as error:
        return str(error.code)
    except (OSError, ValueError, ssl.SSLError):
        return "ERROR"


def certificate_status(hostname):
    context = ssl.create_default_context()
    try:
        with socket.create_connection((hostname, 443), timeout=TIMEOUT) as connection:
            with context.wrap_socket(connection, server_hostname=hostname) as tls:
                return "PASS", tls.version() or "unknown"
    except (OSError, ValueError, ssl.SSLError):
        return "FAIL", "-"


def read_hostnames():
    return [
        line.strip()
        for line in URLS_FILE.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def main():
    if not URLS_FILE.is_file():
        print(f"Missing {URLS_FILE}")
        return 1

    rows = []
    all_passed = True
    for hostname in read_hostnames():
        if not HOSTNAME_PATTERN.fullmatch(hostname):
            rows.append((hostname, "INVALID", "INVALID", "FAIL", "-"))
            all_passed = False
            continue

        certificate, tls_version = certificate_status(hostname)
        https_status = request_status("https", hostname, ssl.create_default_context())
        http_status = request_status("http", hostname)
        rows.append((hostname, https_status, http_status, certificate, tls_version))
        all_passed &= https_status != "ERROR" and http_status != "ERROR" and certificate == "PASS"

    headers = ("Endpoint", "HTTPS", "HTTP", "Certificate", "TLS")
    widths = [max(len(headers[index]), *(len(row[index]) for row in rows)) for index in range(len(headers))]
    separator = "-+-".join("-" * width for width in widths)

    print(" | ".join(header.ljust(widths[index]) for index, header in enumerate(headers)))
    print(separator)
    for row in rows:
        print(" | ".join(value.ljust(widths[index]) for index, value in enumerate(row)))
    print()
    print(f"Overall: {'PASS' if all_passed else 'FAIL'}")
    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
