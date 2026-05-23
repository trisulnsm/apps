# Geo IP Lookup

Dashboard to look up IPv4 and IPv6 addresses in the Trisul Geo and BGP databases.

Paste one or more IPs, or copy tables and mixed text from other tools. The app extracts IPv4, IPv6, and CIDR values automatically and shows a single merged results table.

## Installing

To install this APP logon as admin, then select **Geo IP Lookup** from _Web Admin > Manage > Apps._

## Using

1. Open the dashboard from the Trisul web UI.
2. Paste IPs or any text containing addresses into the textarea.
3. Click **Search**.

Supported input examples:

- One IP per line
- Comma-separated lists
- Table rows copied from spreadsheets or CLI output

## Results

Geo and BGP tool output is merged into one table with these columns:

| IP | Country | Country Name | ASN | ASN Name | Organization | BGP Prefix | AS Path |
|----|---------|--------------|-----|----------|--------------|------------|---------|

IPv6 host addresses are matched to the network block returned by the Geo database (for example, `2407:3e40::1` maps to block `2407:3e40::`).

UPDATES
=======

````
8.0.8   May 23 2026     Merged Geo and BGP output into a single HTML table; paste-friendly IP extraction
````
